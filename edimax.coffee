# #pimatic-edimax plugin
module.exports = (env) ->
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  smartPlug = env.require 'edimax-smartplug'

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

      smartPlug.getDeviceInfo(@options).then((info) =>
        env.logger.info(@options.name + '@' + @options.host + ': ' + info.vendor +
          " " + info.model + ", fwVersion: " + info.fwVersion + ", deviceId: " + @id)

        if info.model is "SP2101W"
          @powerMeteringSupported = true

        # keep updating
        @requestUpdate()
        setInterval( =>
          @requestUpdate()
        , @interval
        )
      )

    # poll device according to interval
    requestUpdate: ->
      smartPlug.getStatusValues(@powerMeteringSupported, @options).then((values) =>
        if values.state isnt @_state
          @_setState(values.state)

        if @powerMeteringSupported
          @emit "meteringData", values
      )

    getState: () ->
      return smartPlug.getSwitchState(@options).then((switchState) =>
        @_state = switchState
        return Promise.resolve @_state
      )

    changeStateTo: (state) ->
      return smartPlug.setSwitchState(state, @options).then(() =>
        @_setState(state)
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
        @emit "energyToday", values.day
        @emit "energyWeek", values.week
        @emit "energyMonth", values.month
        @emit "currentPower", values.nowPower
        @emit "currentAmperage", values.nowCurrent
      )
      super(@config, @plugin)

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