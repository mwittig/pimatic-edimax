pimatic-edimax
=================

[![npm version](https://badge.fury.io/js/pimatic-edimax.svg)](http://badge.fury.io/js/pimatic-edimax)

Pimatic Plugin for Edimax WiFi Smart Plugs.

Screenshot
-------------

Example of the device display as provided by the EdimaxSmartPlug

![screenshot](https://raw.githubusercontent.com/mwittig/pimatic-edimax/master/screenshot-1.png)

Configuration
-------------

You can load the plugin by editing your `config.json` to include the following in the `plugins` section. The property `
interval` specifies the time interval in seconds for polling the state information of the Smart Plugs.   

    { 
       "plugin": "edimax"
       "interval": 30
    }
    
Then you need to add a Smart Plug device in the `devices` section. The plugin offers two device types:
                                                                   
* EdimaxSmartPlugSimple: This type of device provides basic power switching capabilities (ON/OFF). 
* EdimaxSmartPlug: This type of device additionally provides power metering suitable for Edimax SP-2101W.

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
       
Advanced Configuration
-------------

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
    
TODO
----

* Investigate, whether or not it is possible to display and program switch schedules with pimatic

History
-------

* 20150413, V0.0.1
    * Initial Version
* 20150413, V0.0.2
    * Enhanced README
* 20150413, V0.0.3
    * Added support for power metering
    * Updated README
* 20150413, V0.0.4
    * Fixed package dependency which caused plugin startup to fail
* 20150416, V0.0.5
    * Improved robustness of the Smart Plug model detection. Now using bluebird-retry
    * Make sure polling is only performed if interval > 0
    * Allow for re-scheduling of updates if Smart Plug supports metering. This will trigger a new status 
      update request if `changeStateTo()` has been called. This way, metering values will be updated right away when the
      Smart Plug has been switched
    * Improved attribute change. Now, a change event is triggered only, if a value has actually changed rather than
      triggering the change event at each interval
    * Improved error handling. Now, errors will be logged properly.  
    * Updated to edimax-smartplug@0.0.6
    * README - fixed some typos
* 20150427, V0.0.6
    * Fixed description of attribute state 
    * Updated bluebird-retry to 0.0.4
    * Added screenshot
* 20150502, V0.0.7
    * Added support for `xOnLabel`, `xOffLabel`, `xLink`, and `xAttributeOptions` extensions as part of the device 
      configuration
    * Added `recoverState` feature
    * Energy values are now read from DB on plugin initialization
    * Reduced error log output. If `debug` is not set on the plugin, only new error states will be logged
    * Documentation of new features, added section on "Advanced Configuration" to README
* 20150508, V0.0.8
    * Fixed bug which caused blocking requests if smart plug not reachable
    * Updated dependencies