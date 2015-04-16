# #pimatic-edimax plugin
module.exports = (env) ->
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  smartPlug = require 'edimax-smartplug'
  retry = require 'bluebird-retry'

  class EdimaxPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlugSimple", {
        configDef: deviceConfigDef.EdimaxSmartPlugSimple,
        createCallback: (config) =>
          new EdimaxSmartPlugSimple(config, this)
      })

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlug", {
        configDef: deviceConfigDef.EdimaxSmartPlug,
        createCallback: (config) =>
          new EdimaxSmartPlug(config, this)
      })


  class EdimaxSmartPlugSimple extends env.devices.PowerSwitch
    constructor: (@config, @plugin) ->
      @name = config.name
      @id = config.id
      @interval = 1000 * (config.interval or plugin.config.interval)
      @options = {
        name: config.deviceName || config.name,
        host: config.host,
        username: config.username,
        password: config.password
      }
      @powerMeteringSupported = false
      super()
      @_state = false;

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

        @_scheduleUpdate()
      )

    _modelInfoHandler: (id, options)->
      return () ->
        return smartPlug.getDeviceInfo(options).catch((error) ->
          env.logger.error("Unable to get model info of device " + id + ": " + error.toString() + ", Retrying ...")
          #return Promise.reject error
          throw error
        )

    # poll device according to interval
    _scheduleUpdate: () ->
      if typeof @intervalObject isnt 'undefined'
        clearInterval(=>
          @intervalObject
        )

      # keep updating
      if @interval > 0
        @intervalObject = setInterval(=>
          @_requestUpdate()
        , @interval
        )

      # perform an update now
      @_requestUpdate()

    _requestUpdate: ->
      id = @id
      smartPlug.getStatusValues(@powerMeteringSupported, @options).then((values) =>
        if values.state isnt @_state
          @_setState(values.state)

        if @powerMeteringSupported
          @emit "meteringData", values
      ).catch((error) ->
        env.logger.error("Unable to get status values of device " + id + ": " + error.toString())
      )

    getState: () ->
      if @_state?
        return Promise.resolve @_state

      id = @id
      return smartPlug.getSwitchState(@options).then((switchState) =>
        @_state = switchState
        return Promise.resolve @_state
      ).catch((error) ->
        env.logger.error("Unable to get switch state of device " + id + ": " + error.toString())
      )

    changeStateTo: (state) ->
      id = @id
      return smartPlug.setSwitchState(state, @options).then(() =>
        @_setState(state)
        if @powerMeteringSupported
          @_scheduleUpdate()
        return Promise.resolve()
      ).catch((error) ->
        env.logger.error("Unable to change switch state of device " + id + ": " + error.toString())
      )

  class EdimaxSmartPlug extends EdimaxSmartPlugSimple
    # attributes
    attributes:
      state:
        description: "Current state of the guest wlan"
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

    energyToday: 0.0
    energyWeek: 0.0
    energyMonth: 0.0
    currentPower: 0.0
    currentAmperage: 0.0

    constructor: (@config, @plugin) ->
      @on 'meteringData', ((values) ->
        @_setAttribute('energyToday', values.day)
        @_setAttribute('energyWeek', values.week)
        @_setAttribute('energyMonth', values.month)
        @_setAttribute('currentPower', values.nowPower)
        @_setAttribute('currentAmperage', values.nowCurrent)
      )
      super(@config, @plugin)

    _setAttribute: (attributeName, value) ->
      if @[attributeName] isnt value
        @[attributeName] = value
        @emit attributeName, value

    getEnergyToday: -> Promise.resolve @energyToday
    getEnergyWeek: -> Promise.resolve @energyWeek
    getEnergyMonth: -> Promise.resolve @energyMonth
    getCurrentPower: -> Promise.resolve @currentPower
    getCurrentAmperage: -> Promise.resolve @currentAmperage


  # ###Finally
  # Create a instance of my plugin
  myPlugin = new EdimaxPlugin
  # and return it to the framework.
  return myPlugin