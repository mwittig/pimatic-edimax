# #pimatic-edimax plugin
module.exports = (env) ->
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  retry = require 'bluebird-retry'
  commons = require('pimatic-plugin-commons')(env)
  
  class EdimaxPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")
      if config.debug
        process.env.EDIMAX_DEBUG=true

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlugSimple", {
        configDef: deviceConfigDef.EdimaxSmartPlugSimple,
        createCallback: (config, lastState) =>
          new EdimaxSmartPlugSimple(config, @, lastState)
      })

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlug", {
        configDef: deviceConfigDef.EdimaxSmartPlug,
        createCallback: (config, lastState) =>
          new EdimaxSmartPlug(config, @, lastState)
      })


  class EdimaxSmartPlugSimple extends env.devices.PowerSwitch
    constructor: (@config, @plugin, lastState) ->
      @name = config.name
      @id = config.id
      @debug = plugin.config.debug ? false
      @base = commons.base @, config.class
      @smartPlug = require 'edimax-smartplug'


      intervalSeconds = (config.interval or (plugin.config.interval ? plugin.config.__proto__.interval))
      @interval = 1000 * @base.normalize intervalSeconds, 10, 86400
      @options = {
        timeout: Math.min @interval, 10000
        name: config.deviceName || config.name,
        host: config.host,
        username: config.username,
        password: config.password,
        agent: false
      }
      @powerMeteringSupported = false
      @recoverState = config.recoverState

      super()
      @_state = lastState?.state?.value or false;
      @__lastError = "INIT"

      setTimeout(=>
        @_requestModelInfo()
      , 500
      )


    _requestModelInfo: =>
      retry(@_modelInfoHandler(@id, @options),
        {max_tries: -1, max_interval: 30000, interval: 1000, backoff: 2}).done((info) =>
        env.logger.info(@options.name + '@' + @options.host + ': ' + info.vendor +
          " " + info.model + ", fwVersion: " + info.fwVersion + ", deviceId: " + @id)

        if info.model is "SP2101W"
          @powerMeteringSupported = true

        @_requestUpdate()
      )

    _modelInfoHandler: (id, options)->
      return () =>
        return @smartPlug.getDeviceInfo(options).catch((error) =>
          @base.error "Unable to get model info of device: " + error.toString() + ", Retrying ..."
          #return Promise.reject error
          throw error
        )

    _requestUpdate: ->
      id = @id
      @smartPlug.getStatusValues(@powerMeteringSupported, @options).then((values) =>
        if @__lastError isnt "" and @recoverState
          @changeStateTo @_state
        else
          if values.state isnt @_state
            @_setState(values.state)

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

      id = @id
      return @smartPlug.getSwitchState(@options).then((switchState) =>
        @_state = switchState
        return Promise.resolve @_state
      ).catch((error) =>
        @base.error "Unable to get switch state of device: " + error.toString()
      )

    changeStateTo: (state) ->
      id = @id
      return @smartPlug.setSwitchState(state, @options).then(() =>
        @_setState(state)
        if @powerMeteringSupported
          @base.cancelUpdate()
          @_requestUpdate()

        return Promise.resolve()
      ).catch((error) =>
        errorMessage = "Unable to change switch state of device: " + error.toString()
        @base.rejectWithError Promise.reject, errorMessage
      )

  class EdimaxSmartPlug extends EdimaxSmartPlugSimple
    # attributes
    attributes:
      state:
        description: "Current State"
        type: types.boolean
        labels: ['on', 'off']
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

    _energyToday: lastState?.energyToday?.value or 0.0;
    _energyWeek: lastState?.energyWeek?.value or 0.0;
    _energyMonth: lastState?.energyMonth?.value or 0.0;
    # it does not make much sense to recover current power and amperage from DB values
    _currentPower: 0.0;
    _currentAmperage: 0.0;

    constructor: (@config, @plugin, lastState) ->
      @on 'meteringData', ((values) =>
        @base.setAttribute('energyToday', values.day)
        @base.setAttribute('energyWeek', values.week)
        @base.setAttribute('energyMonth', values.month)
        @base.setAttribute('currentPower', values.nowPower)
        @base.setAttribute('currentAmperage', values.nowCurrent)
      )
      super(@config, @plugin, lastState)

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