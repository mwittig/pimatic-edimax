# pimatic-edimax


[![npm version](https://badge.fury.io/js/pimatic-edimax.svg)](http://badge.fury.io/js/pimatic-edimax)
[![Build Status](https://travis-ci.org/mwittig/pimatic-edimax.svg?branch=master)](https://travis-ci.org/mwittig/pimatic-edimax)
[![Dependency Status](https://david-dm.org/mwittig/pimatic-edimax/status.svg)](https://david-dm.org/mwittig/pimatic-edimax)
Pimatic Plugin for Edimax WiFi SP-1101W and SP-2101W Smart Plugs. 

## Contributions

If you like this plugin, please consider &#x2605; starring 
[the project](https://github.com/mwittig/pimatic-edimax). Contributions to the project are  welcome. 
You can simply fork the project and create a pull request with your contribution to start with. 

## Plugin Configuration

You can load the plugin by editing your `config.json` to include the following in the `plugins` section. The property
 `interval` specifies the time interval in seconds for polling the state information of the Smart Plugs. For debugging
 purposes you can also set the property `debug`to `true`. For normal operation the latter is not recommended.

    { 
       "plugin": "edimax",
       "debug": false,
       "interval": 30
    }
    
## Device Configuration


![screenshot](https://raw.githubusercontent.com/mwittig/pimatic-edimax/master/screenshot-1.png)

The plugin offers two device types:
                                                                   
* EdimaxSmartPlugSimple: This type of device provides basic power switching capabilities (ON/OFF). 
* EdimaxSmartPlug: This type of device additionally provides power metering suitable for Edimax SP-2101W.

You can either use the device editor to manually a Smart Plug device, or you can use the **automatic device discovery** 
function of pimatic to find smart plugs connected to your local network. 

As part of the device definition you need to provide the `deviceName` and `password` which have been set using the 
EdiPlug app provided by Edimax. Note, the `deviceName` refers to the `Name` field of the plug settings.

    {
      "id": "sp1",
      "class": "EdimaxSmartPlug",
      "name": "Schaltsteckdose",
      "deviceName": "edimax",
      "host": "192.168.178.65",
      "password": "1234"
    }
       
## Advanced Configuration

### Recover State
    
In my opinion Edimax Smart Plugs lack an essential feature, namely they do not fully recover their last state after a 
power failure. Say, the switch had been turned ON and you have power outage for a few minutes (you can simulate this by 
pulling the smart plug and plugging it to the mains socket again). In this case, the smart plug will remain OFF. How bad 
is this! To deal with this issue the `recoverState` feature (deactivated by default) has been added to automatically 
recover the state after a failure or pimatic has been started. Be warned, however: *Don't plug critical devices such 
as a freezer to the smart plug!* To enable the `recoverState` feature you need to set the property to true as 
shown below:

    {
      "id": "sp1",
      "class": "EdimaxSmartPlug",
      "name": "Schaltsteckdose",
      "deviceName": "edimax",
      "host": "192.168.178.65",
      "password": "1234",
      "recoverState": true
    }

### xLink and xAttributeOptions properties

If you wish to hide the sparkline (the mini-graph) of the attribute display or even hide an attributed this is possible 
 with pimatic v0.8.68 and higher using the `xAttributeOptions` property as shown in the following example. Using the 
 `xLink` property you can also add a hyperlink to the device display.
 
    {
        "id": "sp1",
        "class": "EdimaxSmartPlug",
        "name": "Schaltsteckdose",
        "deviceName": "edimax",
        "host": "192.168.178.65",
        "password": "1234",
        "recoverState": true
        "xLink": "http://fritz.box",
        "xAttributeOptions": [
            {
                "name": "energyToday",
                "displaySparkline": false
            },
            {
                "name": "energyWeek",
                "displaySparkline": false
            },
            {
                "name": "energyMonth",
                "hidden": true
            }
        ]
    }
    

## History

See [Release History](https://github.com/mwittig/pimatic-edimax/blob/master/HISTORY.md).

## License 

Copyright (c) 2015-2017, Marcus Wittig and contributors. All rights reserved.

[GPL-2.0](https://github.com/mwittig/pimatic-edimax/blob/master/LICENSE)