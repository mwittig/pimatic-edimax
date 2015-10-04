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
      intervalSeconds = (config.interval or (plugin.config.interval ? plugin.config.__proto__.interval))
      @interval = 1000 * @_normalize intervalSeconds, 10, 86400
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
      @_lastError = "INIT"

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
      return () =>
        return smartPlug.getDeviceInfo(options).catch((error) =>
          newError = "Unable to get model info of device " + id + ": " + error.toString() + ", Retrying ..."
          env.logger.error(newError) if @_lastError isnt newError or @debug
          @_lastError = newError
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
        if @_lastError isnt "" and @recoverState
          @changeStateTo @_state
        else
          if values.state isnt @_state
            @_setState(values.state)

        @_lastError = ""

        if @powerMeteringSupported
          @emit "meteringData", values
      ).catch((error) =>
        newError = "Unable to get status values of device " + id + ": " + error.toString()
        env.logger.error newError if @_lastError isnt newError or @debug
        @_lastError = newError
      )

    _normalize: (value, lowerRange, upperRange) ->
      if upperRange
        return Math.min (Math.max value, lowerRange), upperRange
      else
        return Math.max value lowerRange

    _setAttribute: (attributeName, value) ->
      if @[attributeName] isnt value
        @[attributeName] = value
        @emit attributeName, value

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
        errorMessage = "Unable to change switch state of device " + id + ": " + error.toString()
        env.logger.error errorMessage
        return Promise.reject errorMessage
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

    energyToday: lastState?.energyToday?.value or 0.0;
    energyWeek: lastState?.energyWeek?.value or 0.0;
    energyMonth: lastState?.energyMonth?.value or 0.0;
    # it does not make much sense to recover current power and amperage from DB values
    currentPower: 0.0;
    currentAmperage: 0.0;

    constructor: (@config, @plugin, lastState) ->
      @on 'meteringData', ((values) ->
        @_setAttribute('energyToday', values.day)
        @_setAttribute('energyWeek', values.week)
        @_setAttribute('energyMonth', values.month)
        @_setAttribute('currentPower', values.nowPower)
        @_setAttribute('currentAmperage', values.nowCurrent)
      )
      super(@config, @plugin, lastState)

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