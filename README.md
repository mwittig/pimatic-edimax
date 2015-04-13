pimatic-edimax
=================

Pimatic Plugin for Edimax WiFi Smart Plugs.

Configuration
-------------

You can load the plugin by editing your `config.json` to include the following in the `plugins` section. The property `
interval` specifies the time interval in seconds for polling the state information of the Smart Plugs.   

    { 
       "plugin": "interval"
       "interval": 30
    }
    
Then you need to add a Smart Plug device in the `devices` section. The plugin offers two device types:
                                                                   
* EdimaxSmartPlugSimple: This type of device provides basic power switch capabilities. 
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
