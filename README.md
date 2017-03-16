# Azure IoT Hub

Azure IoT Hub is an Electric Imp agent-side library for interfacing with Azure IoT Hub version “2016-11-14”. The library consists of the following classes:

- [iothub.Registry](#iothubregistry-class-usage) &mdash; Device management class, all requests use HTTP to connect to Azure IoT Hub.
  - [create](#createdeviceinfo-callback) &mdash; Creates a a new device identity in Azure IoT Hub.
  - [update](#updatedeviceinfo-callback) &mdash; Updates an existing device identity in Azure IoT Hub.
  - [remove](#removedeviceid-callback) &mdash; Deletes a single device identity from Azure IoT Hub.
  - [get](#getdeviceid-callback) &mdash; Returns the properties of an existing device identity in Azure IoT Hub.
  - [list](#listcallback) &mdash; Returns a list of up to 1000 device identities in Azure IoT Hub.
- [iothub.Client](#iothubclient-class-usage) &mdash; The client class is used to send and receive events. All events use AMQP to connect to Azure IoT Hub.
  - [connect](#connectcallback) -&mdash; Opens an AMQP connection to Azure IoT Hub.
  - [disconnect](#disconnect) &mdash; Disconnects from Azure IoT Hub.
  - [sendEvent](#sendeventmessage-callback) - Sends a device-to-cloud event to Azure IoT Hub.
  - [sendBatchEvent](#sendeventbatchmessages-callback) &mdash; Sends an array of device-to-cloud events to Azure IoT Hub.
  - [receive](#function-receivecallback) - Opens a listener for cloud-to-device events targetted at this device.
- [iothub.Message](#iothubmessage-class-usage) - A message object used to create events that are sent to Azure IoT Hub.
  - [getProperties](#getproperties) &mdash; Returns a message's application properties.
  - [getBody](#getbody) &mdash; Returns the message's content.
- [iothub.Delivery](#iothubdelivery-class-usage) - A delivery object, created from events received from Azure IoT Hub.
  - [getMessage](#getmessage) &mdash; Returns an iothub.Message object.
  - [complete](#complete) &mdash; A feedback function used to accept an IoT Hub delivery.
  - [abandon](#abandon) &mdash; A feedback function used to re-queue an IoT Hub delivery.
  - [reject](#reject) &mdash; A feedback function used to reject an IoT Hub delivery.

**To add this library to your project, add** `#require "azureiothub.class.nut:2.0.0"` **to the top of your agent code.**

## Authentication

The Azure Portal provides the *connectionString* parameter needed to create an iothub.Registry or iothub.Client object, see the instructions below to get either a registry or device Connection String.

To use the Device Registry you will require owner-level permissions.

0. Open the [Azure Portal](https://portal.azure.com/)
0. Select or create your Azure IoT Hub resource
0. Under the ‘Settings’ header click on ‘Shared Access Policies’
0. Select a policy which has all permissions (such as the *iothubowner*) or create a new policy then click on it
0. Copy the *Connection string--primary key* to the clipboard and paste it into the iothub.Registry constructor.

To use the Client you need device-level permissions. To get the *deviceConnectionString* you can use the iothub.Registry class [*(see registry example below)*](#registry-example) or follow the steps below to find in the Azure Portal.

0. Open the [Azure Portal](https://portal.azure.com/)
0. Select or create your Azure IoT Hub resource
0. Click on ‘Device Explorer’
0. Select your device (You will need the device id used to register the device with IoT Hub)
0. Copy the *Connection string--primary key* to the clipboard and paste it into the iothub.Client constructor.

## iothub.Registry

The *Registry* class is used to manage IoTHub devices. This class allows your to create, remove, update, delete and list the IoTHub devices in your Azure account.

### iothub.Registry Class Usage

#### Constructor: iothub.Registry(*connectionString*)

This contructs a Registry object which exposes the Device Registry functions. The *connectionString* parameter is provided by the [Azure Portal](https://portal.azure.com/) [*(see above)*](#authentication).

```squirrel
#require "azureiothub.class.nut:2.0.0"

// Instantiate a client using your connection string
const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";
registry <- iothub.Registry(CONNECT_STRING);
```

### iothub.Registry Class Methods

All class methods make asynchronous HTTP requests to Azure IoT Hub. An optional callback parameter can be passed into each method. The callback function will be executed when a response is received from IoT Hub and it takes the following two parameters:

| Parameter | Value |
| --- | --- |
| *err* | This will be `null` if there was no error. Otherwise it will be a table containing two keys: *response*, the original **httpresponse** object, and *message*, an error report string |
| *response* | For *create()*, *update()* and *get()*: an [iothub.Device](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-identity-registry) object.<br> For *list()*: an array of [iothub.Device](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-identity-registry) objects.<br>For *remote()*: nothing |

#### create(*[deviceInfo][, callback]*)

This method creates a new device identity in the IoT Hub. The optional *deviceInfo* parameter is an iothub.Device object or table containing the keys specified [here](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-identity-registry#device-identity-properties). If the *deviceInfo* table’s *deviceId* key is not provided, the agent’s ID will be used. You may also provide an optional *callback* function that will be called when the IoT Hub responds [*(see above)*](#iothubregistry-class-methods).

#### update(*deviceInfo[, callback]*)

This method updates an existing device identity in the IoT Hub. The *deviceInfo* field is an iothub.Device object or table containing the keys specified [here](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-identity-registry#device-identity-properties). The table’s *deviceId* and *statusReason* values cannot be updated via this method. You may also provide an optional *callback* function that will be called when the IoT Hub responds [*(see above)*](#iothubregistry-class-methods).

#### remove(*[deviceId][, callback]*)

This method deletes a single device identity from the IoT Hub. The *deviceId* string parameter is optional and will be set to the agent’s ID if not provided. You may also provide an optional *callback* function that will be called when the IoT Hub responds [*(see above)*](#iothubregistry-class-methods).

#### get(*[deviceId][, callback]*)

This method returns the properties of an existing device identity in the IoT Hub. The *deviceId* string parameter is optional and will be set to the agent’s ID if not provided. You may also provide an optional *callback* function that will be called when the IoT Hub responds [*(see above)*](#iothubregistry-class-methods).

#### list(*callback*)

Returns the properties up to 1000 existing device identities in the IoT Hub.

#### Registry Example

This example code will register the device (using the agent’s ID, which could be replaced with the device’s ID) or create a new one. It will then instantiate the Client class for later use.

```squirrel
#require "azureiothub.class.nut:2.0.0"

const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";

client <- null;
local registry = iothub.Registry(CONNECT_STRING);
local hostname = iothub.ConnectionString.Parse(CONNECT_STRING).HostName;

// Find this device in the registry
registry.get(function(err, deviceInfo) {
    if (err) {
        if (err.response.statuscode == 404) {
            // No such device, let's create it
            registry.create(function(err, deviceInfo) {
                if (err) {
                    server.error(err.message);
                } else {
                    server.log("Created " + deviceInfo.getBody().deviceId);
                    ::client <- iothub.Client(deviceInfo.connectionString(hostName));
                }
            }.bindenv(this));
        } else {
            server.error(err.message);
        }
    } else {
        server.log("Device registered as " + deviceInfo.getBody().deviceId);
        ::client <- iothub.Client(deviceInfo.connectionString(hostname));
    }
}.bindenv(this));

```

## iothub.Client

The *Client* class is used to send and receive events.  To use this class the device must be registered as an IoTHub device on your Azure account.

### iothub.Client Class Usage

#### Constructor: iothub.Client(*deviceConnectionString*)

This contructs a (AMQP) Client object which exposes the event functions. The *deviceConnectionString* parameter is provided by the [Azure Portal](https://portal.azure.com/) [*(see above)*](#authentication), or if your device was registered using the *iothub.Registry* class the *deviceConnectionString* parameter can be retrived from the *deviceInfo* parameter passed to the *.get()* or *.create()* method callbacks. See the [registry example above](#registry-example).

```squirrel
const DEVICE_CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;DeviceId=<DEVICE_ID>;SharedAccessKey=<DEVICE_KEY_HASH>";

// Instantiate a client
client <- iothub.Client(DEVICE_CONNECT_STRING);
```

### iothub.Client Class Methods

#### connect(*[callback]*)

This method opens an AMQP connection to your device's IoTHub "/messages/events" path.  A connection must be opened before messages can be sent or received. This method takes one optional parameter: a callback function that will be executed when the connection has been established.  The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
client.connect(function(err) {
    if (err) {
        server.error(err);
    } else {
        server.log("Connection open. Ready to send and receive messages.");
    });
```

#### disconnect()

This method closes the AMQP connection to IoTHub.

```squirrel
client.disconnect();
```

#### sendEvent(*message[, callback]*)

This method sends a single event (*message*) to IoT Hub. The event should be an iothub.Message object which can be created from a string or any object that can be converted to JSON.  *(See iothub.Message class for more details)*

You may also provide an optional *callback* function. This function will be called when the trasmission of the event to IoT Hub has occurred. The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
// Send a string with no callback
local message1 = iothub.Message("This is an event");
client.sendEvent(message1);

// Send a table with a callback
local message2 = iothub.Message({ "id": 1, "text": "Hello, world." });
client.sendEvent(message2, function(err) {
    if (err) {
        server.error(err);
    } else {
        server.log("Event transmitted at " + time());
    }
});
```

#### sendEventBatch(*messages[, callback]*)

Sends an array of events (*messages*) to Iot Hub. The *messages* parameter should be an array of iothub.Message objects which can be created from a string or any object that can be converted to JSON. *(See iothub.Message class for more details)*

You may also provide an optional *callback* function. This function will be called when the trasmission of the event to IoT Hub has occurred. The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
local messages = [];
messages.push(iothub.Message("This is an event"));
messages.push(iothub.Message({ "id": 1, "text": "Hello, world." }));
client.sendEventBatch(messages);
```

#### receive(*callback*)

Opens a listener for cloud-to-device events targetted at this device. Whenever an event is received, a delivery object will be passed to the provided callback. The event must be acknowledged or rejected by executing a feedback function on the delivery object. If no feedback function is called within the scope of the callback the message will be automatically accepted. [*(See iothub.Delivery Class for more details)*](#iothubdelivery)

```squirrel
client.receive(function(err, delivery) {
    if (err) {
        server.error(err);
        return;
    }

    local message = delivery.getMessage();
    if (message.getBody() == "OK") {
        delivery.complete();
    } else {
        delivery.reject();
    }
})
```

## iothub.Message

The Message class is used to create an event object to send to Azure IoT Hub.

### iothub.Message Class Usage

#### Constructor: iothub.Message(*message, [properties]*)

The constructor takes one required parameter, *message* which can be created from a string or any object that can be converted to JSON, and an optional parameter, a *properties* table.

```squirrel
local message1 = iothub.Message("This is an event");
local message2 = iothub.Message({ "id": 1, "text": "Hello, world." });
```

### iothub.Message Class Methods

#### getProperties()

Use this method to retrieve an event's application properties.  This method returns a table.

```squirrel
local props = message2.getProperties();
```

#### getBody()

Use this method to retrieve an event's message content.

```squirrel
local body = message1.getBody();
```

## iothub.Delivery

Delivery objects are automatically created when an event is received from Azure IoT Hub. You should never call the iothub.Delivery constructor directly. The event must be acknowledged or rejected by executing a **feedback** function (*complete*, *abandon*, or *reject*) on the delivery object. If no **feedback** function is called within the scope of the callback the message will be automatically accepted.

### iothub.Delivery Class Method

#### getMessage()

Use this method to retrieve the event from an IoTHub delivery. This method returns a iothub.Message object.

```squirrel
client.receive(function(err, delivery) {
    if (err) {
        server.error(err);
        return;
    }

    local message = delivery.getMessage();
    server.log( http.jsonencode(message.getProperties()) );
    server.log( message.getBody() );

    // send feedback
    if (message.getBody() == "EXPECTED MESSAGE CONTENT") {
        delivery.complete();
    } else {
        delivery.reject();
    }
})
```

### iothub.Delivery Feedback Methods

#### complete()

A **feedback** function, use to accept a delivery sent from IoTHub. When this method is called a positive ack is sent and the delivery item is removed from the IoTHub message queue.

#### abandon()

A **feedback** function, use to abandon a delivery sent from IoTHub. When called this method sends the delivery item back to IoTHub to be re-queued. The message will be retried until the max delivery count has been reached (the defualt is 10), then it will be rejected.

#### reject()

A **feedback** function, use to reject a delivery sent from IoTHub. When this method is called a negative ack is sent and the delivery item is removed from the IoTHub message queue.

##### Full Example

This example code will receive an event table from the device and transmit it as an event to the Azure IoT Hub.

```squirrel
#require "azureiothub.class.nut:2.0.0"

////////// Application Variables //////////

const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";

client <- null;
registry <- iothub.Registry(CONNECT_STRING);
hostname <- iothub.ConnectionString.Parse(CONNECT_STRING).HostName;
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
    if (typeof message.getBody() == "string") {
        server.log( message.getBody() );
        server.log( http.jsonencode(message.getProperties()) );
        delivery.complete();
    } else {
        delivery.reject();
    }
}

// Create a client, open a connection and receive listener
function createClient(devConnectionString) {
    client <- iothub.Client(devConnectionString);
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


////////// Runtime //////////

// Find this device in the registry
registry.get(function(err, deviceInfo) {
    if (err) {
        if (err.response.statuscode == 404) {
            // No such device, let's create it, connect & open receiver
            registry.create(function(err, deviceInfo) {
                if (err) {
                    server.error(err.message);
                } else {
                    server.log("Dev created " + deviceInfo.getBody().deviceId);
                    createClient(deviceInfo.connectionString(hostName));
                }
            }.bindenv(this));
        } else {
            server.error(err.message);
        }
    } else {
        // Found device, let's connect & open receiver
        server.log("Device registered as " + deviceInfo.getBody().deviceId);
        createClient(deviceInfo.connectionString(hostName));
    }
});

// Open a listener for events from local device, pass them to IoT Hub if connection is established
device.on("event", function(event) {
    event.agentid <- agentid;
    local message = iothub.Message(event);

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

# License

This library is licensed under the [MIT License](./LICENSE.txt).
