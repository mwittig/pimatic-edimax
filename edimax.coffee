# #pimatic-edimax plugin
module.exports = (env) ->
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  smartPlug = env.require 'edimax-smartplug'

  class EdimaxPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("EdimaxSmartPlug", {
        configDef: deviceConfigDef.EdimaxSmartPlug,
        createCallback: (config) =>
          new EdimaxSmartPlug(config, this)
      })


  class EdimaxSmartPlug extends env.devices.PowerSwitch
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
      super()

      # keep updating
      @requestUpdate()
      setInterval( =>
        @requestUpdate()
      , @interval
      )

    # poll device according to interval
    requestUpdate: ->
      smartPlug.getSwitchState(@options).then((switchState) =>
        if switchState isnt @_state
          @_setState(switchState)
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

  # ###Finally
  # Create a instance of my plugin
  myPlugin = new EdimaxPlugin
  # and return it to the framework.
  return myPlugin