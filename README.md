pimatic-edimax
=================

[![npm version](https://badge.fury.io/js/pimatic-edimax.svg)](http://badge.fury.io/js/pimatic-edimax)

Pimatic Plugin for Edimax WiFi Smart Plugs.

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
      update request if changeStateTo() has been called. This way, metering values will be updated right away when the
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
