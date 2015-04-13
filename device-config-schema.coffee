module.exports = {
  title: "pimatic-edimax device config schemas"
  EdimaxSmartPlugSimple: {
    title: "Edimax Smart Plug"
    description: "A WiFi Smart Plug which can be switched on and off."
    type: "object"
    extensions: ["xConfirm"]
    properties:
      deviceName:
        description: "The name of the Smart Plug as shown by the EdiPlug configuration app"
        type: "string"
      host:
        description: "Hostname or IP Address of the Smart Plug"
        type: "string"
      username:
        description: "Username for the REST API"
        type: "string"
        default: "admin"
      password:
        description: "Password for the REST API"
        type: "string"
        default: "1234"
      interval:
        description: "Polling interval for switch state in seconds"
        type: "number"
        default: 0
  }
  EdimaxSmartPlug: {
    title: "Edimax Smart Plug with Power Metering"
    description: "A WiFi Smart Plug which can be switched on and off and provides power metering."
    type: "object"
    extensions: ["xConfirm"]
    properties:
      deviceName:
        description: "The name of the Smart Plug as shown by the EdiPlug configuration app"
        type: "string"
      host:
        description: "Hostname or IP Address of the Smart Plug"
        type: "string"
      username:
        description: "Username for the REST API"
        type: "string"
        default: "admin"
      password:
        description: "Password for the REST API"
        type: "string"
        default: "1234"
      interval:
        description: "Polling interval for switch state in seconds"
        type: "number"
        default: 0
  }
}