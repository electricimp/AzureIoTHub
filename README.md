# Azure IoT Hub 3.0.0 (Draft) #

Azure IoT Hub is an Electric Imp agent-side library for interfacing with Azure IoT Hub version “2016-11-14”. The library consists of the following classes:

- [AzureIoTHub.Registry](#azureiothubregistry) &mdash; Device management class, all requests use HTTP to connect to Azure IoT Hub.
  - [create()](#createdeviceinfo-callback) &mdash; Creates a a new device identity in Azure IoT Hub.
  - [update()](#updatedeviceinfo-callback) &mdash; Updates an existing device identity in Azure IoT Hub.
  - [remove()](#removedeviceid-callback) &mdash; Deletes a single device identity from Azure IoT Hub.
  - [get()](#getdeviceid-callback) &mdash; Returns the properties of an existing device identity in Azure IoT Hub.
  - [list()](#listcallback) &mdash; Returns a list of up to 1000 device identities in Azure IoT Hub.
- [AzureIoTHub.Device](#azureiothubdevice) &mdash; A device object used to manage registry device identities.
  - [conectionstring()](#connectionstringhostname) &mdash; Returns the device connection string.
  - [getbody()](#getbody) &mdash; Returns the device identity properties.
- [AzureIoTHub.Message](#azureiothubmessage) &mdash; A message object used to create events that are sent to Azure IoT Hub.
  - [getProperties()](#getproperties) &mdash; Returns a message’s application properties.
  - [getBody()](#getbody) &mdash; Returns the message's content.
- [AzureIoTHub.Client](#azureiothubclient) &mdash; 

**To add this library to your project, add** `#require "AzureIoTHub.agent.lib.nut:3.0.0"` **to the top of your agent code.**

[![Build Status](https://travis-ci.org/electricimp/AzureIoTHub.svg?branch=master)](https://travis-ci.org/electricimp/AzureIoTHub)

**Note** Azure IoT Hub device twins are currently available only to devices that access IoT Hub via the MQTT protocol. Since the AzureIoTHub Library uses AMQP, device twins are not accessible at this time. However, the programmable Electric Imp device and cloud agent architecture allows developers to easily implement not just static device twin concepts but advanced functionality including custom data models, device state caching/mirroring, properties and triggers, message queuing and batch processing, or remote callbacks. The AzureIoTHub Library is planned to be updated with IoT Hub device twin support once available with the AMQP protocol.

**Step-by-Step Azure IoT Hub Recipes**

In addition to the example code at the bottom of this page there are also two detailed step-by-step 'recipes' for connecting an Electric Imp-powered environmental sensor to Azure IoT Hub, complete with screenshots and diagrams. One recipe is for manual device registration, the other is for automatic device registration. See the [examples folder](./examples).

## Authentication ##

You will need a Microsoft Azure account. If you do not have one please sign up [here](https://azure.microsoft.com/en-us/resources/videos/sign-up-for-microsoft-azure/) before continuing.

To create either an *AzureIoTHub.Registry* or an *AzureIoTHub.Client* object, you require a relevant Connection String, which is provided by the Azure Portal.

### Registry Connection String ###

To get a Registry Connection String you will require owner-level permissions. Please use this option if you have not configured a device in the Azure Portal.

1. Open the [Azure Portal](https://portal.azure.com/).
2. Select or create your Azure IoT Hub resource.
3. Under the ‘Settings’ heading click on ‘Shared Access Policies’.
4. Select a policy which has all permissions (such as the *iothubowner*) or create a new policy then click on it
5. Copy the ‘Connection string--primary key’ to the clipboard and paste it into the *AzureIoTHub.Registry* constructor.

### Device Connection String ###

If your device is already registered in the Azure Portal you can use a Device Connection String to authorize your device. To get a Device Connection String, you need device-level permissions. Follow the steps below to find the Device Connection String in the Azure Portal, otherwise follow the above instructions to get the Registry Connection String and then use the *AzureIoTHub.Registry* class to authorize your device [*(see registry example below)*](#azureiothubregistry-example).

1. Open the [Azure Portal](https://portal.azure.com/).
2. Select or create your Azure IoT Hub resource.
3. Click on ‘Device Explorer’.
4. Select your device &mdash; you will need to know the device ID used to register the device with IoT Hub.
5. Copy the ‘Connection string--primary key’ to the clipboard and paste it into the *AzureIoTHub.Client* constructor.

## AzureIoTHub.Registry ##

The *AzureIoTHub.Registry* class is used to manage IoT Hub devices. This class allows your to create, remove, update, delete and list the IoT Hub devices in your Azure account.

### AzureIoTHub.Registry Class Usage ###

#### Constructor: AzureIoTHub.Registry(*connectionString*) ####

This constructs a *Registry* object which exposes the Device Registry functions. The *connectionString* parameter is provided by the Azure Portal [*(see above)*](#authentication).

```squirrel
#require "AzureIoTHub.agent.lib.nut:2.1.0"

// Instantiate a client using your connection string
const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=<KEY_NAME>;SharedAccessKey=<KEY_HASH>";
registry <- AzureIoTHub.Registry(CONNECT_STRING);
```

### AzureIoTHub.Registry Class Methods ###

All class methods make asynchronous HTTP requests to IoT Hub. The callback function will be executed when a response is received from IoT Hub and it takes the following two parameters:

| Parameter | Value |
| --- | --- |
| *err* | This will be `null` if there was no error. Otherwise it will be a table containing two keys: *response*, the original **httpresponse** object, and *message*, an error report string |
| *response* | For *create()*, *update()* and *get()*: an [AzureIoTHub.Device](#azureiothubdevice) object.<br>For *list()*: an array of [AzureIoTHub.Device](#azureiothubdevice) objects.<br>For *remove()*: nothing |

#### create(*[deviceInfo][, callback]*) ####

This method creates a new device identity in IoT Hub. The optional *deviceInfo* parameter is a table that must contain the required keys specified in the [Device Info Table](#device-info-table) or an [*AzureIoTHub.Device*](#azureiothubdevice) object. If the *deviceInfo* table’s *deviceId* key is not provided, the agent’s ID will be used. You may also provide an optional *callback* function that will be called when the IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods).

#### update(*deviceInfo[, callback]*) ####

This method updates an existing device identity in IoT Hub. The *deviceInfo* field is a table containing the keys specified in the [Device Info Table](#device-info-table) or an [AzureIoTHub.Device](#azureiothubdevice) object. If passing in a table please note it must include a *deviceId* key. The update function cannot change the values of any read-only properties including the *deviceId*, and the *statusReason* value cannot be updated via this method. You may provide an optional *callback* function that will be called when IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods).

#### remove(*deviceId[, callback]*) ####

This method deletes a single device identity from IoT Hub. The *deviceId* string parameter must be provided. You may also provide an optional *callback* function that will be called when IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods).

#### get(*deviceId, callback*) ####

This method requests the properties of an existing device identity in IoT Hub. This method has two required parameters: a string *deviceId*, and a *callback* function that will be called when IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods).

#### list(*callback*) ####

This method requests a list of device identities. When IoT Hub responds, an array of up to 1000 existing [AzureIoTHub.Device](#azureiothubdevice) objects will be passed to the *callback* function, [*(see above)*](#azureiothubregistry-class-methods).

## AzureIoTHub.Device ##

The *AzureIoTHub.Device* class is used to create Devices identity objects used by the *AzureIoTHub.Registry* class. Registry methods will create device objects for you if you choose to pass in tables. 

### AzureIoTHub.Device Class Usage ###

#### Constructor: AzureIoTHub.Device(*[deviceInfo]*) ####

The constructor creates a device object from the *deviceInfo* parameter. See the *Device Info Table* below for details on what to include in the *deviceInfo* table. If no *deviceInfo* is provided, the defaults below will be set. To create a device there must be a *deviceId*. If no *deviceId* is included in the *deviceInfo* table, the agent ID will be used. 

##### Device Info Table #####

| Key | Default Value | Options | Description |
| --- | --- | --- | --- |
| *deviceId* | Agent ID | Required, read-only on updates | A case-sensitive string (up to 128 characters long) of Ascii 7-bit alphanumeric characters plus -, :, ., +, %, \_, #, \*, ?, !, (, ), =, @, ;, $, ' and , |
| *generationId* | `null` | Read only | An IoT Hub-generated, case-sensitive string up to 128 characters long. This value is used to distinguish devices with the same *deviceId*, when they have been deleted and re-created |
| *etag* | `null` | Read only | A string representing a weak ETag for the device identity, as per RFC7232 |
| *connectionState* | "Disconnected" | Read only | A field indicating connection status: either "Connected" or "Disconnected". This field represents the IoT Hub view of the device connection status. **Important** This field should be used only for development/debugging purposes. The connection state is updated only for devices using MQTT or AMQP. It is based on protocol-level pings (MQTT pings, or AMQP pings), and it can have a maximum delay of only five minutes. For these reasons, there can be false positives, such as devices reported as connected but that are disconnected |
| *status* | "Enabled" | Required | An access indicator. Can be "Enabled" or "Disabled". If "Enabled", the device is allowed to connect. If "Disabled", this device cannot access any device-facing endpoint |
| *statusReason* | `null` | Optional | A 128-character string that stores the reason for the device status. All UTF-8 characters are allowed |
| *connectionStateUpdatedTime* | `null` | Read only | A temporal indicator, showing the date and time the connection state was last updated |
| *statusUpdatedTime* | `null` | Read only | A temporal indicator, showing the date and time of the last status update |
| *lastActivityTime* | `null` | Read only | A temporal indicator, showing the date and time the device last connected, received or sent a message |
| *cloudToDeviceMessageCount* | 0 | Read only | The number of cloud to device messages awaiting delivery |                               
| *authentication* | {"symmetricKey" : {"primaryKey" : `null`, "secondaryKey" : `null`}} | Optional | An authentication table containing information and security materials. The primary and a secondary key are stored in base64 format |

**Note** The default authentication parameters do not contain the authentication needed to create an *AzureIoTHub.Client* object.    

### AzureIoTHub.Device Class Methods ###

#### connectionString(*hostname*) ####

The *connectionString()* method takes one required parameter, *hostname*, and returns the *deviceConnectionString* from the stored *authentication* and *deviceId* properties. A *deviceConnectionString* is needed to create an *AzureIoTHub.Client* object. 

#### getBody() ####

The *getBody()* method returns the stored device properties. See the [Device Info Table](#device-info-table) for details of the possible keys.

### AzureIoTHub.Registry Example ###

This example code will create an IoT Hub device using an imp’s agent ID if one isn’t found in the IoT Hub device registry. It will then instantiate the *AzureIoTHub.Client* class for later use.

```squirrel
#require "AzureIoTHub.agent.lib.nut:2.1.0"

const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";

client <- null;
local agentId = split(http.agenturl(), "/").pop();

local registry = AzureIoTHub.Registry(CONNECT_STRING);
local hostname = AzureIoTHub.ConnectionString.Parse(CONNECT_STRING).HostName;

// Find this device in the registry
registry.get(agentId, function(err, iothubDevice) {
    if (err) {
        if (err.response.statuscode == 404) {
            // No such device, let's create one with default parameters
            registry.create(function(error, hubDevice) {
                if (error) {
                    server.error(error.message);
                } else {
                    server.log("Created " + hubDevice.getBody().deviceId);
                    // Create a client with the device authentication provided from the registry response
                    ::client <- AzureIoTHub.Client(hubDevice.connectionString(hostName));
                }
            }.bindenv(this));
        } else {
            server.error(err.message);
        }
    } else {
        // Found the device 
        server.log("Device registered as " + iothubDevice.getBody().deviceId);
        // Create a client with the device authentication provided from the registry response
        ::client <- AzureIoTHub.Client(iothubDevice.connectionString(hostname));
    }
}.bindenv(this));
```

## AzureIoTHub.Message ##

The *AzureIoTHub.Message* class is used to create an event object to send to IoT Hub.

### AzureIoTHub.Message Class Usage ###

#### Constructor: AzureIoTHub.Message(*message[, properties]*) ####

The constructor takes one required parameter, *message*, which can be created from a string or any object that can be converted to JSON. It may also take an optional parameter: a table of message properties.

```squirrel
local message1 = AzureIoTHub.Message("This is an event");
local message2 = AzureIoTHub.Message({ "id": 1, "text": "Hello, world." });
```

### AzureIoTHub.Message Class Methods ###

#### getProperties() ####

Use this method to retrieve an event’s application properties. This method returns a table.

```squirrel
local props = message2.getProperties();
```

#### getBody() ####

Use this method to retrieve an event’s message content. Messages that have been created locally will be of the same type as they were when created, but messages from *AzureIoTHub.Delivery* objects are blobs.

```squirrel
local body = message1.getBody();
```



## AzureIoTHub.Client ##

The *AzureIoTHub.Client* class is used to transfer data to and from Azure IoT Hub. To use this class, the device must be registered as an IoT Hub device in your Azure account.

*AzureIoTHub.Client* works over MQTT v3.1.1 protocol. It supports the following functionality:
- connecting and disconnecting to/from Azure IoT Hub. Azure IoT Hub supports only one connection per device.
- sending messages to Azure IoT Hub
- receiving messages from Azure IoT Hub (optionally enabled)
- device twin operations (optionally enabled)
- direct methods processing (optionally enabled)

### AzureIoTHub.Client Class Usage ###

### AzureIoTHub.Client Class Methods ###

#### Constructor: AzureIoTHub.Client(*deviceConnectionString*) ####

This constructs an AMQP-based *AzureIoTHub.Client* object which exposes the event functions. The *deviceConnectionString* parameter is provided by the Azure Portal [*(see above)*](#authentication). However, if your device was registered using the *AzureIoTHub.Registry* class, the *deviceConnectionString* parameter can be retrieved from the [*AzureIoTHub.Device*](#azureiothubdevice) object passed to the *AzureIoTHub.Registry.get()* or *AzureIoTHub.Registry.create()* method callbacks. For more guidance, please see the [AzureIoTHub.registry example above](#registry-example).

```squirrel
const DEVICE_CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;DeviceId=<DEVICE_ID>;SharedAccessKey=<DEVICE_KEY_HASH>";

// Instantiate a client
client <- AzureIoTHub.Client(DEVICE_CONNECT_STRING);
```

#### connect(*[onConnect, onDisconnect]*) ####

This method opens an AMQP connection to your device’s IoT Hub `"/messages/events"` path. A connection must be opened before messages can be sent or received. This method takes two optional parameters: *onConnect*, a function that will be executed when the connection has been established; and *onDisconnect*, a function that will be called when the connection is broken. 

The *onConnect* function takes one paramete of its own: *error*. If no errors were encountered, *error* will be `null`, otherwise it will contain an error message. 

The *onDisconnect* function takes one parameter of its own: *message*, which is a string containing information about the disconnection.  

```squirrel
function onConnect(error) {
    if (error) {
        server.error(error);
    } else {
        server.log("Connection open. Ready to send and receive messages.");
    }
}

function onDisconnect(message) {
    // Log reason for disconnection
    server.log(message);
    // Reset the connection
    client.disconnect();
    client.connect(onConnect, onDisconnect);
}

client.connect(onConnect, onDisconnect);
```

#### disconnect() ####

This method closes the AMQP connection to IoT Hub.

```squirrel
client.disconnect();
```

#### sendEvent(*message[, callback]*) ####

This method sends a single event, as *message*, to IoT Hub. The event should be an *AzureIoTHub.Message* object which can be created from a string or any object that can be converted to JSON. See [*AzureIoTHub.Message*](#azureiothubmessage) for more details.

You may also provide an optional *callback* function. This will be called when the transmission of the event to IoT Hub has occurred. The callback function takes one parameter: *err*. If no errors were encountered, *err* will be `null`, otherwise it will contain an error message.

```squirrel
// Send a string with no callback
local message1 = AzureIoTHub.Message("This is an event");
client.sendEvent(message1);

// Send a table with a callback
local message2 = AzureIoTHub.Message({ "id": 1, "text": "Hello, world." });
client.sendEvent(message2, function(err) {
    if (err) {
        server.error(err);
    } else {
        server.log("Event transmitted at " + time());
    }
});
```

#### receive(*callback*) ####

This method opens a listener for cloud-to-device events targeted at this device. To open a receiver, pass a function into the *callback* parameter. To close a receiver, set the *callback* parameter to `null`. 

The callback function has two parameters of its own, both of which are required: *error* and *delivery*. If an error is encountered or if the receiver session is unexpectedly closed, then the callback will be triggered and the *error* parameter will contain a message string. Otherwise *error* parameter will be `null`, and whenever an event is received, a *delivery* object will be passed to the provided callback’s *delivery* parameter. 

When a *delivery* is received it must be acknowledged or rejected by executing a feedback function on the delivery object. If no feedback function is called within the scope of the callback, the message will be automatically accepted. See [*AzureIoTHub.Delivery*](#azureiothubdelivery) for more details.

```squirrel
function receiveHandler(error, delivery) {
    if (error) {
        // Log the error
        server.error(error);
        // Reset the receiver
        client.receive(null);
        client.receive(receiveHandler);
        return;
    }

    local message = delivery.getMessage();
    if (message.getBody().tostring() == "OK") {
        delivery.complete();
    } else {
        delivery.reject();
    }
}

client.receive(receiveHandler);
```

## AzureIoTHub.Delivery ##

*AzureIoTHub.Delivery* objects are automatically created when an event is received from IoT Hub. You should never call the *AzureIoTHub.Delivery* constructor directly.

When an event is received it must be acknowledged or rejected by executing a ‘feedback’ method &mdash; *complete()*, *abandon()*, or *reject()* &mdash; on the delivery object. If no feedback method is called within the scope of the callback, the message will be automatically accepted.

### AzureIoTHub.Delivery Class Method ##

#### getMessage() ####

Use this method to retrieve the event from an IoT Hub delivery. This method returns a *AzureIoTHub.Message* object.

```squirrel
local expectedMsg = "EXPECTED MESSAGE CONTENT";

client.receive(function(err, delivery) {
    if (err) {
        server.error(err);
        return;
    }

    local message = delivery.getMessage();

    // message properties are tables, so encode it to log
    server.log( http.jsonencode(message.getProperties()) );
    
    // message body from deliveries are blobs
    server.log( message.getBody() );

    // send feedback
    if (message.getBody().tostring() == expectedMsg) {
        server.log("message accepted, mark as complete");
        delivery.complete();
    } else {
        server.log("unexpected message, rejected");
        delivery.reject();
    }
});
```

### AzureIoTHub.Delivery Feedback Methods ###

#### complete() ####

Use this feedback method to accept a delivery from IoT Hub. When this method is called, a positive acknowlegdement is sent and the delivery item is removed from the IoT Hub message queue.

#### abandon() ####

Use this feedback method to abandon a delivery from IoT Hub. When this method is called, it sends the delivery item back to IoT Hub to be re-queued. The message will be retried until the maximum delivery count has been reached (the default is 10), then it will be rejected.

#### reject() ####

Use this feedback method to reject a delivery from IoT Hub. When this method is called, a negative acknowlegdement is sent and the delivery item is removed from the IoT Hub message queue.

## Full Example ##

The following example code will register a device with Azure IoT Hub (if needed), then open a connection. When a connection is established, a receiver for IoT Hub cloud-to-device messages will be opened. You can send cloud-to-device messages with [iothub-explorer](https://github.com/Azure/iothub-explorer). 

This example also shows how to send device-to-cloud messages. A listener will be opened on the agent for messages coming from its paired imp-enabled device. If a connection to Azure has been established, the message from the imp will be transmitted as an event to IoT Hub. 

### Agent Code ###

```squirrel
#require "AzureIoTHub.agent.lib.nut:2.1.0"

////////// Application Variables //////////

const CONNECT_STRING = "HostName=<YOUR-HOST-NAME>.azure-devices.net;SharedAccessKeyName=<YOUR-KEY-NAME>;SharedAccessKey=<YOUR-KEY-HASH>";

client <- null;
registry <- AzureIoTHub.Registry(CONNECT_STRING);
hostName <- AzureIoTHub.ConnectionString.Parse(CONNECT_STRING).HostName;

agentid <- split(http.agenturl(), "/").pop();
connected <- false;


////////// Application Functions //////////

// Create a receive handler
function receiveHandler(err, delivery) {
    if (err) {
        server.error(err);
        return;
    }

    local message = delivery.getMessage();

    // send feedback
    if (typeof message.getBody() == "blob") {
        
        server.log( message.getBody() );
        server.log( http.jsonencode(message.getProperties()) );
        
        delivery.complete();
    } else {
        
        server.log( message.getBody() );
        server.log( http.jsonencode(message.getProperties()) );
        
        delivery.reject();
    }
}

// Create a client, open a connection and receive listener
function createClient(devConnectionString) {
    client = AzureIoTHub.Client(devConnectionString);
    client.connect(function(err) {
        if (err) {
            server.error(err);
        } else {
            connected = true;
            server.log("Device connected");
            client.receive(receiveHandler);
        }
    }.bindenv(this));
}

// Formats the date object as a UTC string
function formatDate(){
    local d = date();
    return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
}

////////// Runtime //////////

// Find this device in the registry
registry.get(agentid, function(err, iothubDevice) {
    if (err) {
        if (err.response.statuscode == 404) {
            // No such device, let's create it, connect & open receiver
            registry.create(function(error, hubDevice) {
                if (error) {
                    server.error(error.message);
                } else {
                    server.log("Dev created " + hubDevice.getBody().deviceId);
                    createClient(hubDevice.connectionString(hostName));
                }
            }.bindenv(this));
        } else {
            server.error(err.message);
        }
    } else {
        // Found device, let's connect & open receiver
        server.log("Device registered as " + iothubDevice.getBody().deviceId);
        createClient(iothubDevice.connectionString(hostName));
    }
});

// Open a listener for events from local device, pass them to IoT Hub if connection is established
device.on("event", function(event) {
    event.agentid <- agentid;
    event.time <- formatDate();
    local message = AzureIoTHub.Message(event);

    // make sure device is connected, then send event
    if (connected) {
        client.sendEvent(message, function(err) {
            if (err) {
                 server.error("sendEvent error: " + err);
            } else {
                server.log("sendEvent successful");
            }
        });
    }
});
```

### Device Code ###

```squirrel
// Time to wait between readings
const LOOP_TIME = 30;

// Time to connect to Azure
const START_TIME = 5;

// Gets an integer value from the imp's light sensor and sends it to the agent
function getData() {
    local event = { "light": hardware.lightlevel(),
                    "power": hardware.voltage() }
    
    // Send event to agent
    agent.send("event", event);

    // Set timer for next event
    imp.wakeup(LOOP_TIME, getData);
}

// Give the agent time to connect to Azure then start the loop
imp.wakeup(START_TIME, getData);
```

## License ##

This library is licensed under the [MIT License](./LICENSE).
