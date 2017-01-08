# #pimatic-edimax plugin
module.exports = (env) ->
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  retry = require 'bluebird-retry'
  commons = require('pimatic-plugin-commons')(env)
  os = require 'os'

  class EdimaxPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      @debug = @config.debug ? false
      @base = commons.base @, 'EdimaxPlugin'
      deviceConfigDef = require("./device-config-schema")
      if @config.debug
        process.env.EDIMAX_DEBUG=true

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlugSimple", {
        configDef: deviceConfigDef.EdimaxSmartPlugSimple,
        createCallback: (@config, lastState) =>
          new EdimaxSmartPlugSimple(@config, @, lastState)
      })

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlug", {
        configDef: deviceConfigDef.EdimaxSmartPlug,
        createCallback: (@config, lastState) =>
          new EdimaxSmartPlug(@config, @, lastState)
      })

      @framework.deviceManager.on('discover', () =>
        smartPlug = require 'edimax-smartplug'

        # ping all devices in each net:
        @enumerateNetworkInterfaces().forEach( (networkInterface) =>
          basePart = networkInterface.address.match(/([0-9]+\.[0-9]+\.[0-9]+\.)[0-9]+/)[1]

          @framework.deviceManager.discoverMessage(
            'pimatic-edimax', "Scanning #{basePart}0/24"
          )
          smartPlug.discoverDevices({address: "#{basePart}#{255}"}).then (devices) =>
            id = null
            for device in devices
              if device.model in ['SP1101W', 'SP2101W']
                displayName = if device.displayName is "" then "edimax" else device.displayName
                id = @base.generateDeviceId @framework, displayName, id
                config =
                  class: if device.model is 'SP2101W' then 'EdimaxSmartPlug' else 'EdimaxSmartPlugSimple'
                  id: id
                  name:  "#{id}@#{device.addr}".replace(/\./g, '-')
                  deviceName: displayName
                  host: device.addr
                  interval: 30

                @framework.deviceManager.discoveredDevice(
                  'pimatic-edimax', config.name, config
                )
        )
      )

    # get all ip4 non local networks with /24 submask
    enumerateNetworkInterfaces: () ->
      result = []
      networkInterfaces = os.networkInterfaces()
      Object.keys(networkInterfaces).forEach( (name) ->
        networkInterfaces[name].forEach (networkInterface) ->
          if 'IPv4' isnt networkInterface.family or networkInterface.internal isnt false
            # skip over internal (i.e. 127.0.0.1) and non-ipv4 addresses
            return
          if networkInterface.netmask isnt "255.255.255.0"
            return
          result.push
            name: name
            address: networkInterface.address
        return
      )
      if result.length is 0
        # fallback to global broadcast
        result.push
          name: '255.255.255.255/32'
          address: '255.255.255.255'
      return result

  class EdimaxSmartPlugSimple extends env.devices.PowerSwitch
    # attributes
    attributes:
      state:
        description: "Current State"
        type: types.boolean
        labels: ['on', 'off']
      scheduleState:
        description: "Current Schedule State"
        type: types.boolean
        labels: ['active', 'off']
        acronym: 'Schedule'

    constructor: (@config, @plugin, lastState) ->
      @name = @config.name
      @id = @config.id
      @debug = @plugin.config.debug ? false
      @base = commons.base @, @config.class
      @smartPlug = require 'edimax-smartplug'


      intervalSeconds = (@config.interval or (@plugin.config.interval ? @plugin.config.__proto__.interval))
      @interval = 1000 * @base.normalize intervalSeconds, 10, 86400
      @options = {
        timeout: Math.min @interval, 10000
        name: @config.deviceName || @config.name,
        host: @config.host,
        username: @config.username,
        password: @config.password,
        agent: false
      }
      @powerMeteringSupported = false
      @recoverState = @config.recoverState
      @requestPromise = Promise.resolve()
      @scheduleState = false

      super()
      @_state = lastState?.state?.value or false
      @__lastError = "INIT"

      setTimeout(=>
        @_requestModelInfo()
      , 500
      )

    destroy: () ->
      @base.cancelUpdate()
      @requestPromise.cancel() if @requestPromise?
      super()

    _requestModelInfo: =>
      @requestPromise = retry(@_modelInfoHandler(@id, @options),
        {max_tries: -1, max_interval: 30000, interval: 1000, backoff: 2}).then((info) =>
        env.logger.info(@options.name + '@' + @options.host + ': ' + info.vendor +
            " " + info.model + ", fwVersion: " + info.fwVersion + ", deviceId: " + @id)

        if info.model is "SP2101W"
          @powerMeteringSupported = true

        @_requestUpdate()
      )

    _modelInfoHandler: (id, options)->
      return () =>
        @requestPromise = @smartPlug.getDeviceInfo(options).catch((error) =>
          @base.error "Unable to get model info of device: " + error.toString() + ", Retrying ..."
          #return Promise.reject error
          throw error
        )

    _requestUpdate: ->
      @smartPlug.getStatusValues(@powerMeteringSupported, @options).then((values) =>
        if @__lastError isnt "" and @recoverState
          @changeStateTo @_state
        else
          if values.state isnt @_state
            @_setState(values.state)
          if values.scheduleState isnt @scheduleState
            @scheduleState = values.scheduleState
            @base.setAttribute('scheduleState', values.scheduleState)

        @base.resetLastError()

        if @powerMeteringSupported
          @emit "meteringData", values
      ).catch((error) =>
        @base.error "Unable to get status values of device: " + error.toString()
      ).finally () =>
        @base.scheduleUpdate @_requestUpdate, @interval

    getState: () ->
      if @_state?
        return Promise.resolve @_state

      @requestPromise =  @smartPlug.getSwitchState(@options).then((switchState) =>
        @_state = switchState
        return Promise.resolve @_state
      ).catch((error) =>
        @base.error "Unable to get switch state of device: " + error.toString()
      )

    changeStateTo: (state) ->
      @requestPromise = @smartPlug.setSwitchState(state, @options).then(() =>
        @_setState(state)
        if @powerMeteringSupported
          @base.cancelUpdate()
          @_requestUpdate()

        return Promise.resolve()
      ).catch((error) =>
        errorMessage = "Unable to change switch state of device: " + error.toString()
        @base.rejectWithError Promise.reject, errorMessage
      )

    getScheduleState: () ->
      @smartPlug.getScheduleState(@options).then((schedState) =>
        @base.setAttribute('scheduleState', schedState)
        @scheduleState = schedState
        return Promise.resolve @scheduleState
      ).catch((error) =>
        @base.error "Unable to get schedule state of device: " + error.toString()
      )


  class EdimaxSmartPlug extends EdimaxSmartPlugSimple
    # attributes
    attributes:
      energyToday:
        description: "Energy Usage Today"
        type: types.number
        unit: 'kWh'
        acronym: 'KDY'
      energyWeek:
        description: "Energy Usage of Current Month"
        type: types.number
        unit: 'kWh'
        acronym: 'KWK'
      energyMonth:
        description: "Energy Usage of Current Month"
        type: types.number
        unit: 'kWh'
        acronym: 'KMT'
      currentPower:
        description: "Current Power"
        type: types.number
        unit: 'W'
        acronym: 'PAC'
      currentAmperage:
        description: "Current Amperage"
        type: types.number
        unit: 'A'
        acronym: 'AAC'

    _energyToday: lastState?.energyToday?.value or 0.0
    _energyWeek: lastState?.energyWeek?.value or 0.0
    _energyMonth: lastState?.energyMonth?.value or 0.0
# it does not make much sense to recover current power and amperage from DB values
    _currentPower: 0.0
    _currentAmperage: 0.0

    constructor: (@config, @plugin, lastState) ->
      @on 'meteringData', ((values) =>
        @base.setAttribute('energyToday', values.day)
        @base.setAttribute('energyWeek', values.week)
        @base.setAttribute('energyMonth', values.month)
        @base.setAttribute('currentPower', values.nowPower)
        @base.setAttribute('currentAmperage', values.nowCurrent)
      )
      super(@config, @plugin, lastState)

    destroy: () ->
      super()

    getEnergyToday: -> Promise.resolve @_energyToday
    getEnergyWeek: -> Promise.resolve @_energyWeek
    getEnergyMonth: -> Promise.resolve @_energyMonth
    getCurrentPower: -> Promise.resolve @_currentPower
    getCurrentAmperage: -> Promise.resolve @_currentAmperage


  # ###Finally
  # Create a instance of my plugin
  myPlugin = new EdimaxPlugin
  # and return it to the framework.
  return myPlugin
