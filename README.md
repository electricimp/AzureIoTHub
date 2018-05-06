# Azure IoT Hub 3.0.0 (Draft) #

Azure IoT Hub is an Electric Imp agent-side library for interfacing with Azure IoT Hub version “2016-11-14”. The library consists of the following classes:

TODO - update
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
#require "AzureIoTHub.agent.lib.nut:3.0.0"

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

TODO - update

```squirrel
#require "AzureIoTHub.agent.lib.nut:3.0.0"

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

TODO - update description.

This class is used to create a message to send to Azure IoT Hub.

### Constructor: AzureIoTHub.Message(*message[, props]*) ###

The constructor takes one required parameter, *message*, which can be created from a string or any object that can be converted to JSON. It may also take an optional parameter: a table of message properties.

```squirrel
local message1 = AzureIoTHub.Message("This is an event");
local message2 = AzureIoTHub.Message({ "id": 1, "text": "Hello, world." });
```

### getProperties() ###

Use this method to retrieve an event’s application properties. This method returns a table.

```squirrel
local props = message2.getProperties();
```

### getBody() ###

Use this method to retrieve an event’s message content. Messages that have been created locally will be of the same type as they were when created, but messages from *AzureIoTHub.Delivery* objects are blobs.

```squirrel
local body = message1.getBody();
```

## AzureIoTHub.DirectMethodResponse ##

This class is used to create a response to the received [Direct Method call](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods) to send it back to Azure IoT Hub.

### Constructor: AzureIoTHub.DirectMethodResponse(*status[, body]*) ###

This method returns a new AzureIoTHub.DirectMethodResponse instance.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *status* | Integer | Yes | Status of the Direct Method execution. Fully application specific. |
| *body* | Table | Optional | Key-value table with the returned data. Every key is always a *String* with the name of the data field. The value is the corresponding value of the data field. Keys and values are fully application specific. |

## AzureIoTHub.Client ##

This class is used to transfer data to and from Azure IoT Hub. To use this class, the device must be registered as an IoT Hub device in an Azure account.

*AzureIoTHub.Client* works over MQTT v3.1.1 protocol. It supports the following functionality:
- connecting and disconnecting to/from Azure IoT Hub. Azure IoT Hub supports only one connection per device.
- sending messages to Azure IoT Hub
- receiving messages from Azure IoT Hub (optionally enabled)
- device twin operations (optionally enabled)
- direct methods processing (optionally enabled)

### AzureIoTHub.Client Class Usage ###

TODO - add some general explanation here ? eg.
- need to re-enable optional features after disconnection.
- https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins#device-reconnection-flow
- 

Most of the methods return nothing. A result of an operation may be obtained via a callback function specified in the method. A typical [*onDone*](#callback-ondoneerror) callback provides an [error code](#error-code) which specifies a concrete error (if any) happened during the operation. Specific callbacks are described within every method.

#### Callback: onDone(*error*) #####

This callback is called when an operation is completed.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |

#### Error Code ####

An *Integer* error code which specifies a concrete error (if any) happened during an operation.

| Error Code | Description |
| --- | --- |
| 0 | No error. |
| 1000 | The client is disconnected. |
| 1001 | The client is already connected. |
| 1002 | The feature is not enabled. |
| 1003 | The feature is already enabled. |
| 1004 | General error. |
| 1005 | The operation is not allowed now. |
| 429 | Too many requests (throttled), as per [Azure IoT Hub throttling](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-quotas-throttling) |
| 5** | Azure IoT Hub server errors |
| TODO | codes returned by EI MQTT lib... |

### Constructor: AzureIoTHub.Client(*deviceConnectionString, onConnect[, onDisconnect[, options]]*) ###

This method returns a new AzureIoTHub.Client instance.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceConnectionString* | String | Yes | Device connection string: includes the host name to connect, the device Id and the shared access string. It can be obtained from the Azure Portal [*(see above)*](#authentication). However, if the device was registered using the *AzureIoTHub.Registry* class, the *deviceConnectionString* parameter can be retrieved from the [*AzureIoTHub.Device*](#azureiothubdevice) instance passed to the *AzureIoTHub.Registry.get()* or *AzureIoTHub.Registry.create()* method callbacks. For more guidance, please see the [AzureIoTHub.registry example](#azureiothubregistry-example). |
| *[onConnect](#callback-onconnecterror)* | Function  | Yes | [Callback](#callback-onconnecterror) called every time the device is connected. |
| *[onDisconnect](#callback-ondisconnecterror)* | Function  | Optional | [Callback](#callback-ondisconnecterror) called every time the device is disconnected. |
| *[options](#optional-settings)* | Table  | Optional | [Key-value table](#optional-settings) with optional settings. |

#### Callback: onConnect(*error*) ####

This callback is called every time the device is connected.

This is a right place to enable optional functionalities, if needed.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the connection is successful, an [error code](#error-code) otherwise. |

#### Callback: onDisconnect(*error*) ####

This callback is called every time the device is disconnected.

This is a good place to call the [connect()](#connect) method again, if it was an unexpected disconnection.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the disconnection was caused by the [disconnect()](#disconnect) method, an [error code](#error-code) which explains a reason of the disconnection otherwise. |

#### Optional Settings ####

These settings affect the client's behavior and the operations. Every setting is optional and has a default.

| Key (String) | Value Type | Default | Description |
| --- | --- | --- | --- |
| "qos" | Integer | 0 | MQTT QoS. Azure IoT Hub supports QoS `0` and `1` only. |
| "will-topic" | String | not specified | TODO |
| "will-message" | String | not specified | TODO |
| TODO |  |  |  |

#### Example ####

TODO - update - full example for constructor, connect, disconnect - a recommended practice

```squirrel
const DEVICE_CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;DeviceId=<DEVICE_ID>;SharedAccessKey=<DEVICE_KEY_HASH>";

// Instantiate a client
client <- AzureIoTHub.Client(DEVICE_CONNECT_STRING);
```

### connect() ###

This method opens a connection to Azure IoT Hub.

The method returns nothing. A result of the connection opening may be obtained via the [*onConnect*](#callback-onconnecterror) callback specified in the client's constructor.

Azure IoT Hub supports only one connection per device.

All other methods of the client should be called when the client is connected.

### disconnect() ###

This method closes the connection to Azure IoT Hub. Does nothing if the connection is already closed.

The method returns nothing. When the disconnection is completed the [*onDisconnect*](#callback-ondisconnecterror) callback is called, if specified in the client's constructor.

### isConnected() ###

This method checks if the client is connected to Azure IoT Hub.

The method returns *Boolean*: `true` if the client is connected, `false` otherwise.

### sendMessage(*message[, onDone]*) ###

This method [sends a message to Azure IoT Hub](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages).

The method returns nothing. A result of the sending may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | Yes | Message to send. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the message is considered as sent or an error happens. |

#### Example ####

TODO - update

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

### enableMessageReceiving(*onReceive[, onDone]*) ###

This method enables or disables [message receiving from Azure IoT Hub](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-cloud-to-device-messages).

To enable the feature, specify the [*onReceive*](#callback-onreceivemessage) callback. To disable the feature, specify `null` as that callback.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onReceive](#callback-onreceivemessage)* | Function  | Yes | [Callback](#callback-onreceivemessage) called every time a new message is received. `null` disables the feature. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Callback: onReceive(*message*) ####

This callback is called every time a new message is received.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | Received message. |

#### Example ####

TODO

### enableTwin(*onRequest[, onDone]*) ###

This method enables or disables [Azure IoT Hub Device Twins functionality](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins).

To enable the feature, specify the [*onRequest*](#callback-onrequestversion-props) callback. To disable the feature, specify `null` as that callback.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onRequest](#callback-onrequestversion-props)* | Function  | Yes | [Callback](#callback-onrequestversion-props) called every time a new request with desired Device Twin properties is received. `null` disables the feature. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Callback: onRequest(*version, props*) ####

This callback is called every time a new [request with desired Device Twin properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-desired-properties-update-notifications) is received.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *version* | Integer | Version of the Device Twin document which corresponds to the desired properties. The version is always incremented by Azure IoT Hub when the document is updated. |
| *props* | Table | Key-value table with the desired properties. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |

#### Example ####

TODO - maybe cover updateTwinProperties() as well ?

### retrieveTwinProperties(*onRetrieve*) ###

This method [retrieves Device Twin properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties).

The method returns nothing. The retrieved properties may be obtained via the [*onRetrieve*](#callback-onretrieveerror-version-reportedprops-desiredprops) callback specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onRetrieve](#callback-onretrieveerror-version-reportedprops-desiredprops)* | Function  | Yes | [Callback](#callback-onretrieveerror-version-reportedprops-desiredprops) called when the properties are retrieved. |

#### Callback: onRetrieve(*error, reportedProps, desiredProps*) ####

This callback is called when [Device Twin properties are retrieved](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#errorcode)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |
| *reportedProps* | Table | Key-value table with the reported properties and their version. This parameter should be ignored if *error* is not `0`. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |
| *desiredProps* | Table | Key-value table with the desired properties and their version. This parameter should be ignored if *error* is not `0`. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |

#### Example ####

TODO 

### updateTwinProperties(*props[, onDone]*) ###

This method [updates Device Twin reported properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties).

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *props* | Table | Yes | Key-value table with the reported properties. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Example ####

TODO - not needed if already in the example for enableTwin()

### enableDirectMethods(*onMethod[, onDone]*) ###

This method enables or disables [Azure IoT Hub Direct Methods](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods).

To enable the feature, specify the [*onMethod*](#callback-onmethodname-params) callback. To disable the feature, specify `null` as that callback.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onMethod](#callback-onmethodname-params)* | Function  | Yes | [Callback](#callback-onmethodname-params) called every time a direct method is called. `null` disables the feature. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Callback: onMethod(*name, params*) ####

This callback is called every time a [Direct Method is called](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#respond-to-a-direct-method).

The callback **must** return an instance of the [AzureIoTHub.DirectMethodResponse](#azureiothubdirectmethodresponse).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *name* | String | Name of the called Direct Method. |
| *params* | Table | Key-value table with the input parameters of the called Direct Method. Every key is always a *String* with the name of the input parameter. The value is the corresponding value of the input parameter. Keys and values are fully application specific. |

#### Example ####

TODO 


## Examples ##

Full working examples are provided in the [examples](./examples) directory and described [here](./Examples/README.md).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory and described [here](./tests/README.md).

## License ##

This library is licensed under the [MIT License](./LICENSE).
