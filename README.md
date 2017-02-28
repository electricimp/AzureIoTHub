# Azure IoT Hub Client 2.0.0

The Azure IoT Hub client is an Electric Imp agent-side library for interfacing to the Azure IoT Hub version “2016-02-03”. It currently only supports the device registry (create, update, delete, get, list) and sending device-to-cloud events.

**To add this library to your project, add** `#require "azureiothub.class.nut:2.0.0"` **to the top of your agent code.**

## Authentication

The Azure Portal provides the Connection String, passed into the following constructor’s *connectionString* parameter. To use the Device Registry you will require owner-level permissions. To use the Client you need device-level permissions. The best way to get device-level permissions is from the Device Registry SDK.

0. Open the [Azure Portal](https://portal.azure.com/)
0. Select or create your Azure IoT Hub resource
0. Click on ‘Settings’
0. Click on ‘Shared Access Policies’
0. Select a policy which has all permissions (such as the *iothubowner*) or create a new policy then click on it
0. Copy the *Connection string--primary key* to the clipboard and paste it into the constructor.

## iothub.Registry Class Usage

The *Registry* class is used to manage IoTHub devices. This class allows your to create, remove, update, delete and list the IoTHub devices in your Azure account.

### Constructor: iothub.Registry(*connectionString*)

This contructs a Registry object which exposes the Device Registry functions.

The *connectionString* parameter is provided by the [Azure Portal](https://portal.azure.com/) *(see above)*.

```squirrel
#require "azureiothub.class.nut:2.0.0"

// Instantiate a client using your connection string.
const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";
registry <- iothub.Registry(CONNECT_STRING);
```

## iothub.Registry Class Methods

### create(*[deviceInfo][, callback]*)

This method creates a new device identity in the IoT Hub. The optional *deviceInfo* parameter is an iothub.Device object or table containing the keys specified [here](https://msdn.microsoft.com/en-us/library/mt548493.aspx). If the *deviceInfo* table’s *deviceId* key is not provided, the agent’s ID will be used.

You may also provide a function reference via the *callback* parameter *(see below)*. This function will be called when the IoT Hub responds. If you don’t provide a callback, *create()* will block until completion.

### update(*deviceInfo[, callback]*)

This method updates an existing device identity in the IoT Hub. The *deviceInfo* field is an iothub.Device object or table containing the keys specified [here](https://msdn.microsoft.com/en-us/library/mt548488.aspx). The table’s *deviceId* and *statusReason* values cannot be updated via this method.

You may also provide a function reference via the *callback* parameter *(see below)*. This function will be called when the IoT Hub responds. If you don’t provide a callback, *update()* will block until completion.

### remove(*[deviceId][, callback]*)

This method deletes a single device identity from the IoT Hub. The *deviceId* string parameter is optional and will be set to the agent’s ID if not provided.

You may also provide a function reference via the *callback* parameter *(see below)*. This function will be called when the IoT Hub responds. If you don’t provide a callback, *remove()* will block until completion.

### get(*[deviceId][, callback]*)

This method returns the properties of an existing device identity in the IoT Hub. The *deviceId* string parameter is optional and will be set to the agent’s ID if not provided.

You may also provide a function reference via the *callback* parameter *(see below)*. This function will be called when the IoT Hub responds. If you don’t provide a callback, *get()* will block until completion.

### list(*callback*)

Returns the properties of all existing device identities in the IoT Hub.

### Callbacks

Callback functions passed into the above methods should be defined with the following parameters:

| Parameter | Value |
| --- | --- |
| *err* | This will be `null` if there was no error. Otherwise it will be a table containing two keys: *response*, the original **httpresponse** object, and *message*, an error report string |
| *response* | For *create()*, *update()* and *get()*: an [iothub.Device](https://msdn.microsoft.com/en-us/library/mt548491.aspx) object.<br> For *list()*: an array of [iothub.Device](https://msdn.microsoft.com/en-us/library/mt548491.aspx) objects.<br>For *remote()*: nothing |

### Example

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
        server.log("Connected as " + deviceInfo.getBody().deviceId);
        ::client <- iothub.Client(deviceInfo.connectionString(hostname));
    }
}.bindenv(this));

```

## iothub.Client Class Usage

The *Client* class is used to send and receive events.  To use this class the device must be registered as an IoTHub device on your Azure account.

### Constructor: iothub.Client(*connectionString*)

This contructs a (AMQP) Client object which exposes the event functions.

The *connectionString* parameter is provided by the [Azure Portal](https://portal.azure.com/) *(see above)*.  If your device was registered using the *iothub.Registry* class the *connectionString* parameter can be retrived from the *deviceInfo* parameter passed to the *.get()* or *.create()* method callbacks. See the Registry example above.

```squirrel
#require "azureiothub.class.nut:2.0.0"

// Instantiate a client.
client <- iothub.Client(DEVICE_CONNECT_STRING);
```

## iothub.Client Class Methods

### connect(*[callback]*)

This method opens an AMQP connection to your device's IoTHub "/messages/events" path.  A connection must be opened before messages can be sent or received. This method takes one optional parameter: a callback function that will be executed when the connection has been established.  The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
client.connect(function(err) {
    if (err) {
        server.error(err);
    } else {
        server.log("Connection open. Ready to send and receive messages.");
    });
```

### disconnect()

This method closes the AMQP connection to IoTHub.

```squirrel
client.disconnect();
```

### sendEvent(*message[, callback]*)

This method sends a single event (*message*) to IoT Hub. The event should be an iothub.Message object which can be created from a string or any object that can be converted to JSON.  *(See iothub.Message class for more details)*

You may also provide an optional *callback* function. This function will be called when the trasmission of the event to IoT Hub has occurred. The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
local message1 = iothub.Message("This is an event");
client.sendEvent(message1);

local message2 = iothub.Message({ "id": 1, "text": "Hello, world." });
client.sendEvent(message2, function(err) {
    if (err) {
        server.error(err);
    } else {
        server.log("Event transmitted at " + time());
    }
});
```

### sendEventBatch(*messages[, callback]*)

Sends an array of events (messages) to Iot Hub. The messages parameter should be an array of iothub.Message objects which can be created from a string or any object that can be converted to JSON.

You may also provide an optional *callback* function. This function will be called when the trasmission of the event to IoT Hub has occurred. The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
local messages = [];
messages.push(iothub.Message("This is an event"));
messages.push(iothub.Message({ "id": 1, "text": "Hello, world." }));
client.sendEventBatch(messages);
```

### function receive(*callback*)

Opens a listener for cloud-to-device events targetted at this device. Whenever an event is received, a delivery object will be sent to the provided callback. *(See iothub.Delivery Class for more details)* The event must be acknowledged or rejected by executing a feedback function on the delivery object. If no feedback function is called within the scope of the callback the message will be automatically accepted.

| Delivery Functions | Description |
| -------------------------- | --------------- |
| complete    | feedback function to accept a message, the message is removed from the message queue and a positive ack is sent |
| reject      | feedback function that rejects a message, the message is removed from the message queue and a negative ack is sent |
| abandon   | feeback function that abandons a message, the message is then re-qeueued for delivery.  If the message is not acknowleged within a set number of retries (the defualt is 10) the message will be rejected |
| getMessage | returns message object |

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

### Example

This example code will receive an event table from the device and transmit it as an event to the Azure IoT Hub.

```squirrel
#require "azureiothub.class.nut:2.0.0"

client <- iothub.Client.fromConnectionString(DEVICE_CONNECT_STRING);
agentid <- split(http.agenturl(), "/").pop();

device.on("event", function(event) {
    event.agentid <- agentid;
    local message = iothub.Message(event);
    client.sendEvent(message, function(err) {
        if (err) {
             server.error("sendEvent error: " + err);
        } else {
            server.log("sendEvent successful");
        }
    });
});
```

## iothub.Message Class Usage

### Constructor: iothub.Message(*message, [properties]*)

The Message class is used to create messages that are sent to IoTHub.  The constructor takes one required parameter, *message* which can be created from a string or any object that can be converted to JSON, and an optional parameter, a *properties* table.

```squirrel
local message1 = iothub.Message("This is an event");
local message2 = iothub.Message({ "id": 1, "text": "Hello, world." });
```

## iothub.Message Class Methods

### getProperties()

Use this method to retrieve message's application properties.  This method returns a table.

```squirrel
local props = message2.getProperties();
```

### getBody()

Use this method to retrieve message's content.

```squirrel
local body = message1.getBody();
```

## iothub.Delivery Class Usage

### Constructor: iothub.Message(*amqpDeliveryItem*)

Delivery objects are automatically created when a data is received from IoTHub.  You should never call the iothub.Delivery constructor directly.

## iothub.Delivery Class Methods

### getMessage()

Use this method to retrieve message content from an IoTHub delivery.  This method returns a iothub.Message object.

```squirrel
client.receive(function(err, delivery) {
    if (err) {
        server.error(err);
        return;
    }

    local message = delivery.getMessage();
    server.log( http.jsonencode(message.getProperties()) );
    server.log( message.getBody() );

    delivery.complete();
})
```

### complete()

A feedback function to accept a delivery sent from IoTHub. When this method is called a positive ack is sent and the delivery item is removed from the IoTHub message queue. *(See iothub.client receive method for usage example)*

### abandon()

A feedback function to abandon a delivery sent from IoTHub. When called this method sends the delivery item back to IoTHub to be re-queued. The message will be retried until the max delivery count has been reached, then it will be rejected.

### reject()

A feedback function to reject a delivery sent from IoTHub. When this method is called a negative ack is sent and the delivery item is removed from the IoTHub message queue. *(See iothub.client receive method for usage example)*


# License

This library is licensed under the [MIT License](./LICENSE.txt).
