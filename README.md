# Azure IoT Hub

Azure IoT Hub is an Electric Imp agent-side library for interfacing with Azure IoT Hub version “2016-11-14”. The library consists of the following classes:

- [AzureIoTHub.Registry](#azureiothubregistry) &mdash; Device management class, all requests use HTTP to connect to Azure IoT Hub.
  - [create](#createdeviceinfo-callback) &mdash; Creates a a new device identity in Azure IoT Hub.
  - [update](#updatedeviceinfo-callback) &mdash; Updates an existing device identity in Azure IoT Hub.
  - [remove](#removedeviceid-callback) &mdash; Deletes a single device identity from Azure IoT Hub.
  - [get](#getdeviceid-callback) &mdash; Returns the properties of an existing device identity in Azure IoT Hub.
  - [list](#listcallback) &mdash; Returns a list of up to 1000 device identities in Azure IoT Hub.
- [AzureIoTHub.Device](#azureiothubdevice) &mdash; A device object used to manage registry device identities.
  - [conectionstring](#connectionstringhostname) &mdash; Returns the device connection string.
  - [getbody](#getbody) &mdash; Retuns the device identity properties.
- [AzureIoTHub.Client](#azureiothubclient) &mdash; Used to open AMQP connection to Azure IoT Hub, and to send & receive events.
  - [connect](#connectcallback) -&mdash; Opens an AMQP connection to Azure IoT Hub.
  - [disconnect](#disconnect) &mdash; Disconnects from Azure IoT Hub.
  - [sendEvent](#sendeventmessage-callback) - Sends a device-to-cloud event to Azure IoT Hub.
  - [receive](#receivecallback) - Opens a listener for cloud-to-device events targetted at this device.
- [AzureIoTHub.Message](#azureiothubmessage) - A message object used to create events that are sent to Azure IoT Hub.
  - [getProperties](#getproperties) &mdash; Returns a message's application properties.
  - [getBody](#getbody) &mdash; Returns the message's content.
- [AzureIoTHub.Delivery](#azureiothubdelivery) - A delivery object, created from events received from Azure IoT Hub.
  - [getMessage](#getmessage) &mdash; Returns an iothub.Message object.
  - [complete](#complete) &mdash; A feedback function used to accept an IoT Hub delivery.
  - [abandon](#abandon) &mdash; A feedback function used to re-queue an IoT Hub delivery.
  - [reject](#reject) &mdash; A feedback function used to reject an IoT Hub delivery.

**To add this library to your project, add** `#require "AzureIoTHub.agent.lib.nut:2.0.0"` **to the top of your agent code.**

**NOTE:** The latest release of AzureIoTHub Library version 2.0.0 uses an AMQP connection with Azure to send and receive events. AMQP is currently in alpha testing on the Electric Imp platform and while in this testing phase it will only be supported for Electric Imp Azure accounts. Sign up for a free Electric Imp Azure account [here](https://azure-ide.electricimp.com/login). Be sure to use this account to BlinkUp your device. The HTTP version of the library is still available if you would prefer to use your existing Electric Imp account, [AzureIoTHub Library version 1.2.1](https://github.com/electricimp/AzureIoTHub/tree/v1.2.1).

## Authentication

You will need a Microsoft Azure account. If you do not have one please sign up [here](https://azure.microsoft.com/en-us/resources/videos/sign-up-for-microsoft-azure/) before continuing.

The Azure Portal provides a *Connection String*. This is needed to create an AzureIoTHub.Registry or AzureIoTHub.Client object, follow the steps below to get either a *Registry Connection String* or *Device Connection String*.

To get the *Registry Connection String* you will require owner-level permissions. Please use this option if you have not configured a device in the Azure Portal.

1. Open the [Azure Portal](https://portal.azure.com/)
2. Select or create your Azure IoT Hub resource
3. Under the ‘Settings’ header click on ‘Shared Access Policies’
4. Select a policy which has all permissions (such as the *iothubowner*) or create a new policy then click on it
5. Copy the *Connection string--primary key* to the clipboard and paste it into the AzureIoTHub.Registry constructor.

If your device is already registered in the Azure Portal you can use the *Device Connection String* to authorize your device. To get the *Device Connection String* you need device-level permissions. Follow the steps below to find the *Device Connection String* in the Azure Portal, otherwire please follow the above instructions to get the *Registry Connection String* and then use the AzureIoTHub.Registry class [*(see registry example below)*](#registry-example) to authorize your device.

1. Open the [Azure Portal](https://portal.azure.com/)
2. Select or create your Azure IoT Hub resource
3. Click on ‘Device Explorer’
4. Select your device (You will need to know the device id used to register the device with IoT Hub)
5. Copy the *Connection string--primary key* to the clipboard and paste it into the AzureIoTHub.Client constructor.

## AzureIoTHub.Registry

The *Registry* class is used to manage IoTHub devices. This class allows your to create, remove, update, delete and list the IoTHub devices in your Azure account.

### AzureIoTHub.Registry Class Usage

#### Constructor: AzureIoTHub.Registry(*connectionString*)

This contructs a Registry object which exposes the Device Registry functions. The *connectionString* parameter is provided by the Azure Portal [*(see above)*](#authentication).

```squirrel
#require "AzureIoTHub.agent.lib.nut:2.0.0"

// Instantiate a client using your connection string
const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";
registry <- AzureIoTHub.Registry(CONNECT_STRING);
```

### AzureIoTHub.Registry Class Methods

All class methods make asynchronous HTTP requests to Azure IoT Hub. The callback function will be executed when a response is received from IoT Hub and it takes the following two parameters:

| Parameter | Value |
| --- | --- |
| *err* | This will be `null` if there was no error. Otherwise it will be a table containing two keys: *response*, the original **httpresponse** object, and *message*, an error report string |
| *response* | For *create()*, *update()* and *get()*: an [AzureIoTHub.Device](#azureiothubdevice) object.<br> For *list()*: an array of [AzureIoTHub.Device](#azureiothubdevice) objects.<br>For *remove()*: nothing |

#### create(*[deviceInfo][, callback]*)

This method creates a new device identity in IoT Hub. The optional *deviceInfo* parameter is a table that must contain the required keys specified in the [Device Info Table](#device-info-table) or an AzureIoTHub.Device object. If the *deviceInfo* table’s *deviceId* key is not provided, the agent’s ID will be used. You may also provide an optional *callback* function that will be called when the IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods) for details.

#### update(*deviceInfo[, callback]*)

This method updates an existing device identity in IoT Hub. The *deviceInfo* field is a table containing the keys specified in the [Device Info Table](#device-info-table) or an AzureIoTHub.Device object. If passing in a table please not it must include a *deviceId* key. The update function cannot change the values of any read-only properties, and the *statusReason* value cannot be updated via this method. You may provide an optional *callback* function that will be called when IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods) for details.

#### remove(*deviceId[, callback]*)

This method deletes a single device identity from IoT Hub. The *deviceId* string parameter must be provided. You may also provide an optional *callback* function that will be called when IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods) for details.

#### get(*deviceId, callback*)

This method requests the properties of an existing device identity in IoT Hub. This method has two required parameters: a string *deviceId*, and a *callback* function that will be called when IoT Hub responds [*(see above)*](#azureiothubregistry-class-methods) for details.

#### list(*callback*)

This method requests a list of device identities. When IoT Hub responds an array of up to 1000 existing device identities will be passed to the *callback* function, [*(see above)*](#azureiothubregistry-class-methods) for details.

## AzureIoTHub.Device

The Device class is used to create Devices used by the Registry class. Registry methods will create Device objects for you if you choose to pass in a deviceInfo table. 

### AzureIoTHub.Device Class Usage

#### Constructor: AzureIoTHub.Device(*[deviceInfo]*)

The constructor creates a Device object from the *deviceInfo* table passed in. The *deviceInfo* table must include a *deviceId*, if no *deviceId* is included the agent ID will be used. If no *deviceInfo* is provided the defaults below will be set:

##### Device Info Table
| Key                        | Default Value     | Options                        | Description |
| -------------------------- | ----------------- | ------------------------------ | ----------- |
| deviceId                   | agent ID          | required, read-only on updates | A case-sensitive string (up to 128 characters long) of ASCII 7-bit alphanumeric characters plus {'-', ':', '.', '+', '%', '_', '#', '*', '?', '!', '(', ')', ',', '=', '@', ';', '$', '''} |
| generationId               | `null`            | read-only                      | An IoT hub-generated, case-sensitive string up to 128 characters long. This value is used to distinguish devices with the same deviceId, when they have been deleted and re-created. |
| etag                       | `null`            | read-only                      | A string representing a weak ETag for the device identity, as per RFC7232. |
| connectionState            | "Disconnected"    | read-only                      | A field indicating connection status: either "Connected" or "Disconnected". This field represents the IoT Hub view of the device connection status. Important: This field should be used only for development/debugging purposes. The connection state is updated only for devices using MQTT or AMQP. Also, it is based on protocol-level pings (MQTT pings, or AMQP pings), and it can have a maximum delay of only 5 minutes. For these reasons, there can be false positives, such as devices reported as connected but that are disconnected. |
| status                     | "Enabled"         | required                       | An access indicator. Can be "Enabled" or "Disabled". If "Enabled", the device is allowed to connect. If Disabled, this device cannot access any device-facing endpoint. |
| statusReason               | `null`            | optional                       | A 128 character-long string that stores the reason for the device identity status. All UTF-8 characters are allowed. |
| connectionStateUpdatedTime | `null`            | read-only                      | A temporal indicator, showing the date and last time the connection state was updated. |
| statusUpdatedTime          | `null`            | read-only                      | A temporal indicator, showing the date and time of the last status update. |
| lastActivityTime           | `null`            | read-only                      | A temporal indicator, showing the date and last time the device connected, received, or sent a message. |
| cloudToDeviceMessageCount  | 0                 | read-only                      | Number of cloud to device messages awaiting delivery |                               
| authentication             | {"symmetricKey" : {"primaryKey" : `null`, "secondaryKey" : `null`}} | optional | An authentication table containing information and security materials. The primary and a secondary key are stored in base64 format. |

**Note:** The defualt authenication parameters do not contain the authenication needed to create an AzureIoTHub.Client.    

### AzureIoTHub.Device Class Methods

#### connectionString(*hostname*)

The *connectionString* method takes one required parameter *hostname* and returns the *deviceConnectionString* needed to create an AzureIoTHub.Client. 

#### getBody()

The *getBody* method returns the device identity properties (aka the Device Info table).


### Registry Example

This example code will register the device (using the agent’s ID, which could be replaced with the device’s ID) or create a new one. It will then instantiate the Client class for later use.

```squirrel
#require "AzureIoTHub.agent.lib.nut:2.0.0"

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

## AzureIoTHub.Client

The *Client* class is used to send and receive events.  To use this class the device must be registered as an IoTHub device on your Azure account.

### AzureIoTHub.Client Class Usage

#### Constructor: AzureIoTHub.Client(*deviceConnectionString*)

This contructs a (AMQP) Client object which exposes the event functions. The *deviceConnectionString* parameter is provided by the Azure Portal [*(see above)*](#authentication), or if your device was registered using the *AzureIoTHub.Registry* class the *deviceConnectionString* parameter can be retrived from the *deviceInfo* parameter passed to the *.get()* or *.create()* method callbacks. See the [registry example above](#registry-example).

```squirrel
const DEVICE_CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;DeviceId=<DEVICE_ID>;SharedAccessKey=<DEVICE_KEY_HASH>";

// Instantiate a client
client <- AzureIoTHub.Client(DEVICE_CONNECT_STRING);
```

### AzureIoTHub.Client Class Methods

#### connect(*[callback]*)

This method opens an AMQP connection to your device's IoTHub "/messages/events" path.  A connection must be opened before messages can be sent or received. This method takes one optional parameter: a callback function that will be executed when the connection has been established.  The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

```squirrel
client.connect(function(err) {
    if (err) {
        server.error(err);
    } else {
        server.log("Connection open. Ready to send and receive messages.");
    }
});
```

#### disconnect()

This method closes the AMQP connection to IoT Hub.

```squirrel
client.disconnect();
```

#### sendEvent(*message[, callback]*)

This method sends a single event (*message*) to IoT Hub. The event should be an AzureIoTHub.Message object which can be created from a string or any object that can be converted to JSON.  *(See AzureIoTHub.Message class for more details)*

You may also provide an optional *callback* function. This function will be called when the trasmission of the event to IoT Hub has occurred. The callback function takes one parameter: *err*. If no errors were encountered *err* will be `null` otherwise it will contain a error message.

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

#### receive(*callback*)

Opens a listener for cloud-to-device events targetted at this device. Whenever an event is received, a delivery object will be passed to the provided callback. The event must be acknowledged or rejected by executing a feedback function on the delivery object. If no feedback function is called within the scope of the callback the message will be automatically accepted. [*(See AzureIoTHub.Delivery Class for more details)*](#azureiothubdelivery)

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

## AzureIoTHub.Message

The Message class is used to create an event object to send to Azure IoT Hub.

### AzureIoTHub.Message Class Usage

#### Constructor: AzureIoTHub.Message(*message, [properties]*)

The constructor takes one required parameter, *message* which can be created from a string or any object that can be converted to JSON, and an optional parameter, a *properties* table.

```squirrel
local message1 = AzureIoTHub.Message("This is an event");
local message2 = AzureIoTHub.Message({ "id": 1, "text": "Hello, world." });
```

### AzureIoTHub.Message Class Methods

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

## AzureIoTHub.Delivery

Delivery objects are automatically created when an event is received from Azure IoT Hub. You should never call the AzureIoTHub.Delivery constructor directly.

When an event is received it must be acknowledged or rejected by executing a **feedback** function (*complete*, *abandon*, or *reject*) on the delivery object. If no **feedback** function is called within the scope of the callback the message will be automatically accepted.

### AzureIoTHub.Delivery Class Method

#### getMessage()

Use this method to retrieve the event from an IoT Hub delivery. This method returns a AzureIoTHub.Message object.

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

### AzureIoTHub.Delivery Feedback Methods

#### complete()

A **feedback** function, use to accept a delivery sent from IoT Hub. When this method is called a positive ack is sent and the delivery item is removed from the IoT Hub message queue.

#### abandon()

A **feedback** function, use to abandon a delivery sent from IoT Hub. When called this method sends the delivery item back to IoT Hub to be re-queued. The message will be retried until the max delivery count has been reached (the defualt is 10), then it will be rejected.

#### reject()

A **feedback** function, use to reject a delivery sent from IoT Hub. When this method is called a negative ack is sent and the delivery item is removed from the IoT Hub message queue.

## Full Example

This example code will register a device with Azure IoT Hub (if needed), then open a connection.  When a connection is established a receiver for Azure IoT Hub cloud to device messages will be opened. You can send cloud to device messages with [iothub-explorer](https://github.com/Azure/iothub-explorer). This example also shows how to send device to cloud messages. A listener will be opened on the agent for messages coming from the imp device. If a connection to Azure has been established the message from the imp device will be transmitted as an event to the Azure IoT Hub. 

### Agent Code

```squirrel
#require "AzureIoTHub.agent.lib.nut:2.0.0"

////////// Application Variables //////////

const CONNECT_STRING = "HostName=<YOUR-HOST-NAME>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<YOUR-KEY-HASH>";

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
    if (typeof message.getBody() == "string") {
        server.log( message.getBody() );
        server.log( http.jsonencode(message.getProperties()) );
        delivery.complete();
    } else {
        server.log(typeof message.getBody());
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

### Device Code

```squirrel
// Time to wait between readings
loopTimer <- 300;

// Gets an integer value from the imp's light sensor,
// and sends it to the agent
function getData() {
    local event = { "light": hardware.lightlevel(),
                    "power": hardware.voltage() }
    // Send event to agent
    agent.send("event", event);

    // Set timer for next event
    imp.wakeup(loopTimer, getData);
}

// Give the agent time to connect to Azure
// then start the loop
imp.wakeup(5, getData);
```

# License

This library is licensed under the [MIT License](./LICENSE).
