# Azure IoT Hub 5.0.0 #

Azure IoT Hub is an Electric Imp agent-side library for interfacing with Azure IoT Hub API version "2016-11-14". Starting with version 3 the library integrates with Azure IoT Hub using the MQTT protocol (rather than AMQP previously) as there is certain functionality such as Device Twins and Direct Methods that IoT Hub only supports via MQTT.

**Note** The Azure IoT Hub MQTT integration is currently in public Beta. Before proceeding, please sign up for access to the Azure IoT Hub MQTT integration using [this link](https://connect.electricimp.com/azure-mqtt-integration-signup).

**Important** All Electric Imp devices can connect to Azure IoT Hub, regardless of which impCloud™ (AWS or Azure) they are linked to. For devices on the AWS impCloud, the connection to IoT Hub will occur cloud-to-cloud from AWS to Azure. For devices on the Azure impCloud, the connection to IoT Hub will occur within Azure. However, there is no difference between the functionality provided by the library in either of these scenarios.

The library consists of the following classes:

- [AzureIoTHub.Registry](#azureiothubregistry) &mdash; Device management class, all requests use HTTP to connect to Azure IoT Hub.
  - [create()](#createdeviceinfo-callback) &mdash; Creates a a new device identity in Azure IoT Hub.
  - [update()](#updatedeviceinfo-callback) &mdash; Updates an existing device identity in Azure IoT Hub.
  - [remove()](#removedeviceid-callback) &mdash; Deletes a single device identity from Azure IoT Hub.
  - [get()](#getdeviceid-callback) &mdash; Returns the properties of an existing device identity in Azure IoT Hub.
  - [list()](#listcallback) &mdash; Returns a list of up to 1000 device identities in Azure IoT Hub.
- [AzureIoTHub.Device](#azureiothubdevice) &mdash; A device object used to manage registry device identities.
  - [connectionString()](#connectionstringhostname) &mdash; Returns the device connection string.
  - [getBody()](#getbody) &mdash; Returns the device identity properties.
- [AzureIoTHub.Message](#azureiothubmessage) &mdash; Used as a wrapper for messages to/from Azure IoT Hub.
  - [getProperties()](#getproperties) &mdash; Returns a message’s properties.
  - [getBody()](#getbody) &mdash; Returns the message's content.
- [AzureIoTHub.DirectMethodResponse](#azureiothubdirectmethodresponse) &mdash; Used as a wrapper for Direct Methods responses.
- [AzureIoTHub.Client](#azureiothubclient) &mdash; Used to open MQTT connection to Azure IoT Hub, and to use Messages, Twins, Direct Methods functionality.
  - [connect()](#connect) &mdash; Opens a connection to Azure IoT Hub.
  - [disconnect()](#disconnect) &mdash; Closes the connection to Azure IoT Hub.
  - [isConnected()](#isconnected) &mdash; Checks if the client is connected to Azure IoT Hub.
  - [sendMessage()](#sendmessagemessage-onsent) &mdash; Sends a message to Azure IoT Hub.
  - [enableIncomingMessages()](#enableincomingmessagesonreceive-ondone) &mdash; Enables or disables message receiving from Azure IoT Hub.
  - [enableTwin()](#enabletwinonrequest-ondone) &mdash; Enables or disables Azure IoT Hub Device Twins functionality.
  - [retrieveTwinProperties()](#retrievetwinpropertiesonretrieved) &mdash; Retrieves Device Twin properties.
  - [updateTwinProperties()](#updatetwinpropertiesprops-onupdated) &mdash; Updates Device Twin reported properties.
  - [enableDirectMethods()](#enabledirectmethodsonmethod-ondone) &mdash; Enables or disables Azure IoT Hub Direct Methods.
  - [setDebug()](#setdebugvalue) &mdash; Enables or disables the client debug output.

**To add this library to your project, add** `#require "AzureIoTHub.agent.lib.nut:5.0.0"` **to the top of your agent code.**

[![Build Status](https://travis-ci.org/electricimp/AzureIoTHub.svg?branch=master)](https://travis-ci.org/electricimp/AzureIoTHub)

## Authentication ##

You will need a Microsoft Azure account. If you do not have one please sign up [here](https://azure.microsoft.com/en-us/resources/videos/sign-up-for-microsoft-azure/) before continuing.

To create either an *AzureIoTHub.Registry* or an *AzureIoTHub.Client* object, you require a relevant Connection String, which is provided by the Azure Portal.

### Registry Connection String ###

To get a Registry Connection String you will require owner-level permissions. Please use this option if you have not configured a device in the Azure Portal.

1. Open the [Azure Portal](https://portal.azure.com/).
2. Select or create your Azure IoT Hub resource.
3. Under the ‘Settings’ heading click on ‘Shared Access Policies’.
4. Select a policy which has read/write permissions (such as the *registryReadWrite*) or create a new policy then click on it
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
#require "AzureIoTHub.agent.lib.nut:5.0.0"

// Instantiate a client using your connection string
const AZURE_REGISTRY_CONN_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=<KEY_NAME>;SharedAccessKey=<KEY_HASH>";
registry <- AzureIoTHub.Registry(AZURE_REGISTRY_CONN_STRING);
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
#require "AzureIoTHub.agent.lib.nut:5.0.0"

const AZURE_REGISTRY_CONN_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";

client <- null;
local agentId = split(http.agenturl(), "/").pop();

local registry = AzureIoTHub.Registry(AZURE_REGISTRY_CONN_STRING);
local hostname = AzureIoTHub.ConnectionString.Parse(AZURE_REGISTRY_CONN_STRING).HostName;

function onConnected(err) {
    if (err != 0) {
        server.error("Connect failed: " + err);
        return;
    }
}

function createDevice() {
    registry.create({"deviceId" : agentId}, function(error, iotHubDevice) {
        if (error) {
            server.error(error.message);
        } else {
            server.log("Created " + iotHubDevice.getBody().deviceId);
            // Create a client with the device authentication provided from the registry response
            ::client <- AzureIoTHub.Client(iotHubDevice.connectionString(hostname), onConnected);
        }
    }.bindenv(this));
}

// Find this device in the registry
registry.get(agentId, function(err, iothubDevice) {
    if (err) {
        if (err.response.statuscode == 404) {
            // No such device, let's create one with default parameters
            createDevice();
        } else {
            server.error(err.message);
        }
    } else {
        // Found the device 
        server.log("Device registered as " + iothubDevice.getBody().deviceId);
        // Create a client with the device authentication provided from the registry response
        ::client <- AzureIoTHub.Client(iothubDevice.connectionString(hostname), onConnected);
    }
}.bindenv(this));
```

## AzureIoTHub.Message ##

This class is used as a wrapper for messages to/from Azure IoT Hub.

### Constructor: AzureIoTHub.Message(*message[, props]*) ###

This method returns a new AzureIoTHub.Message instance.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | [Any supported by the MQTT API](https://developer.electricimp.com/api/mqtt/mqttclient/createmessage). | Yes | Message body. |
| *props* | Table | Optional | Key-value table with the message properties. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |

#### Example ####

```squirrel
local message1 = AzureIoTHub.Message("This is a message");
local message2 = AzureIoTHub.Message(blob(256));
local message3 = AzureIoTHub.Message("This is a message with properties", {"property": "value"});
```

### getProperties() ###

This method returns a key-value table with the properties of the message. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Incoming messages contain properties set by Azure IoT Hub.

### getBody() ###

This method returns the message's body. Messages that have been created locally will be of the same type as they were when created, but messages came from Azure IoT Hub are of one of the [types supported by the MQTT API](https://developer.electricimp.com/api/mqtt/mqttclient/onmessage).

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

Only one instance of this class is allowed.

*AzureIoTHub.Client* works over MQTT v3.1.1 protocol. It supports the following functionality:
- connecting and disconnecting to/from Azure IoT Hub. Azure IoT Hub supports only one connection per device.
- sending messages to Azure IoT Hub
- receiving messages from Azure IoT Hub (optional functionality)
- device twin operations (optional functionality)
- direct methods processing (optional functionality)

Please keep in mind [Azure IoT Hub limitations](https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/iot-hub-limits.md).

All optional functionalities are disabled after a client instantiation. If an optional functionality is needed it should be enabled after the client is successfully connected. And it should be explicitly re-enabled after every re-connection of the client.
The client provides individual methods to enable every optional feature.

Most of the methods return nothing. A result of an operation may be obtained via a callback function specified in the method. Specific callbacks are described within every method. Many callbacks provide an [error code](#error-code) which specifies a concrete error (if any) happened during the operation. 

### Constructor: AzureIoTHub.Client(*deviceConnectionString[, onConnected[, onDisconnected[, options]]]*) ###

This method returns a new AzureIoTHub.Client instance.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceConnectionString* | String | Yes | Device connection string: includes the host name to connect, the device Id and the shared access string. It can be obtained from the Azure Portal [*(see above)*](#authentication). However, if the device was registered using the *AzureIoTHub.Registry* class, the *deviceConnectionString* parameter can be retrieved from the [*AzureIoTHub.Device*](#azureiothubdevice) instance passed to the *AzureIoTHub.Registry.get()* or *AzureIoTHub.Registry.create()* method callbacks. For more guidance, please see the [AzureIoTHub.registry example](#azureiothubregistry-example). |
| *[onConnected](#callback-onconnectederror)* | Function  | Optional | [Callback](#callback-onconnectederror) called every time the device is connected. |
| *[onDisconnected](#callback-ondisconnectederror)* | Function  | Optional | [Callback](#callback-ondisconnectederror) called every time the device is disconnected. |
| *[options](#optional-settings)* | Table  | Optional | [Key-value table](#optional-settings) with optional settings. |

#### Callback: onConnected(*error*) ####

This callback is called every time the device is connected.

This is a right place to enable optional functionalities, if needed.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the connection is successful, an [error code](#error-code) otherwise. |

#### Callback: onDisconnected(*error*) ####

This callback is called every time the device is disconnected.

This is a good place to call the [connect()](#connect) method again, if it was an unexpected disconnection.

Note: 

IoT Hub expires authentication tokens (currently, the library is configured to request tokens with a 1 hour life). When the token expires the client connection disconnects and the `onDisconnected(*error*)` handler is called. To reconnect with a new token you can simply execute the connect flow again (call [connect()](#connect).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the disconnection was caused by the [disconnect()](#disconnect) method, an [error code](#error-code) which explains a reason of the disconnection otherwise. |

#### Optional Settings ####

These settings affect the client's behavior and the operations. Every setting is optional and has a default.

| Key (String) | Value Type | Default | Description |
| --- | --- | --- | --- |
| "qos" | Integer | 0 | MQTT QoS. Azure IoT Hub supports QoS `0` and `1` only. |
| "keepAlive" | Integer | 60 | Keep-alive MQTT parameter, in seconds. For more information, see [here](https://developer.electricimp.com/api/mqtt/mqttclient/connect). |
| "twinsTimeout" | Integer | 10 | Timeout (in seconds) for [Retrieve Twin](#retrievetwinpropertiesonretrieved) and [Update Twin](#updatetwinpropertiesprops-onupdated) operations. |
| "dMethodsTimeout" | Integer | 30 | Timeframe (in seconds) to [reply to direct method](#callback-replydata-onreplysent) call. |
| "maxPendingTwinRequests" | Integer | 3 | Maximum amount of pending [Update Twin](#updatetwinpropertiesprops-onupdated) operations. |
| "maxPendingSendRequests" | Integer | 3 | Maximum amount of pending [Send Message](#sendmessagemessage-onsent) operations. |
| "tokenTTL" | Integer | 86400 | SAS token's time-to-live (in seconds). For more information, see [here](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-security#security-token-structure). |
| "tokenAutoRefresh" | Boolean | true | If `true`, the [SAS token auto-refresh feature](#automatic-sas-token-refreshing) is enabled, otherwise disabled. |

#### Example ####

```squirrel
const AZURE_DEVICE_CONN_STRING = "HostName=<HUB_ID>.azure-devices.net;DeviceId=<DEVICE_ID>;SharedAccessKey=<DEVICE_KEY_HASH>";

function onConnected(err) {
    if (err != 0) {
        server.error("Connect failed: " + err);
        return;
    }
    server.log("Connected");
    // Here is a good place to enable required features, like Twins or Direct Methods
}

function onDisconnected(err) {
    if (err != 0) {
        server.error("Disconnected unexpectedly with code: " + err);
        // Reconnect if disconnection is not initiated by application
        client.connect();
    } else {
        server.log("Disconnected by application");
    }
}

// Instantiate and connect a client
client <- AzureIoTHub.Client(AZURE_DEVICE_CONN_STRING, onConnected, onDisconnected);
client.connect();
```

### connect() ###

This method opens a connection to Azure IoT Hub.

The method returns nothing. A result of the connection opening may be obtained via the [*onConnected*](#callback-onconnectederror) callback specified in the client's constructor.

Azure IoT Hub supports only one connection per device.

All other methods (except [isConnected()](#isconnected)) of the client should be called when the client is connected.

### disconnect() ###

This method closes the connection to Azure IoT Hub. Does nothing if the connection is already closed.

The method returns nothing. When the disconnection is completed the [*onDisconnected*](#callback-ondisconnectederror) callback is called, if specified in the client's constructor.

### isConnected() ###

This method checks if the client is connected to Azure IoT Hub.

The method returns *Boolean*: `true` if the client is connected, `false` otherwise.

### sendMessage(*message[, onSent]*) ###

This method [sends a message to Azure IoT Hub](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages).

The method returns nothing. A result of the sending may be obtained via the [*onSent*](#callback-onsenterror-message) callback, if specified in this method.

It is allowed to send a new message while the previous send operation is not completed yet. 
Maximum amount of pending operations is defined by the [client settings](#optional-settings).

Due to limited support of the `retain` MQTT flag by Azure IoT Hub (described [here](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages)) this library doesn't currently support it.

If *message* parameter is `null` or has incompatible type, the method will throw an exception.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | Yes | Message to send. |
| *[onSent](#callback-onsenterror-message)* | Function  | Optional | [Callback](#callback-onsenterror-message) called when the message is considered as sent or an error happens. |

#### Callback: onSent(*error, message*) ####

This callback is called when the message is considered as sent or an error happens.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#errorcode)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | The original *message* passed to [sendMessage()](#sendmessagemessage-onsent) method. |

#### Example ####

```squirrel
// Send a string with no callback
message1 <- AzureIoTHub.Message("This is a string");
client.sendMessage(message1);

// Send a string with a callback
message2 <- AzureIoTHub.Message("This is another string");

function onSent(err, msg) {
    if (err != 0) {
        server.error("Message sending failed: " + err);
        server.log("Trying to send again...");
        // For example simplicity trying to resend the message in case of any error
        client.sendMessage(message2, onSent);
    } else {
        server.log("Message sent at " + time());
    }
}

client.sendMessage(message2, onSent);
```

### enableIncomingMessages(*onReceive[, onDone]*) ###

This method enables or disables [message receiving from Azure IoT Hub](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-cloud-to-device-messages).

To enable the feature, specify the [*onReceive*](#callback-onreceivemessage) callback. To disable the feature, specify `null` as that callback.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onReceive](#callback-onreceivemessage)* | Function  | Yes | [Callback](#callback-onreceivemessage) called every time a new message is received from Azure IoT Hub. `null` disables the feature. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Callback: onReceive(*message*) ####

This callback is called every time a new message is received from Azure IoT Hub.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | Received message. |

#### Example ####

```squirrel
function onReceive(msg) {
    server.log("Message received: " + msg.getBody());
}

function onDone(err) {
    if (err != 0) {
        server.error("Enabling message receiving failed: " + err);
    } else {
        server.log("Message receiving enabled successfully");
    }
}

client.enableIncomingMessages(onReceive, onDone);
```

### enableTwin(*onRequest[, onDone]*) ###

This method enables or disables [Azure IoT Hub Device Twins functionality](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins).

To enable the feature, specify the [*onRequest*](#callback-onrequestprops) callback. To disable the feature, specify `null` as that callback.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onRequest](#callback-onrequestprops)* | Function  | Yes | [Callback](#callback-onrequestprops) called every time a new request with desired Device Twin properties is received from Azure IoT Hub. `null` disables the feature. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Callback: onRequest(*props*) ####

This callback is called every time a new [request with desired Device Twin properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-desired-properties-update-notifications) is received from Azure IoT Hub.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *props* | Table | Key-value table with the desired properties and their version. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |

#### Example ####

```squirrel
function onRequest(props) {
    server.log("Desired properties received");
}

function onDone(err) {
    if (err != 0) {
        server.error("Enabling Twins functionality failed: " + err);
    } else {
        server.log("Twins functionality enabled successfully");
    }
}

client.enableTwin(onRequest, onDone);
```

### retrieveTwinProperties(*onRetrieved*) ###

This method [retrieves Device Twin properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties).

The method returns nothing. The retrieved properties may be obtained via the [*onRetrieved*](#callback-onretrievederror-reportedprops-desiredprops) callback specified in this method.

The method may be called only if Twins functionality is enabled.

It is NOT allowed to call this method while the previous retrieve operation is not completed yet. 

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onRetrieved](#callback-onretrievederror-reportedprops-desiredprops)* | Function  | Yes | [Callback](#callback-onretrievederror-reportedprops-desiredprops) called when the properties are retrieved. |

#### Callback: onRetrieved(*error, reportedProps, desiredProps*) ####

This callback is called when [Device Twin properties are retrieved](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |
| *reportedProps* | Table | Key-value table with the reported properties and their version. This parameter should be ignored if *error* is not `0`. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |
| *desiredProps* | Table | Key-value table with the desired properties and their version. This parameter should be ignored if *error* is not `0`. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |

#### Example ####

```squirrel
function onRetrieved(err, repProps, desProps) {
    if (err != 0) {
        server.error("Retrieving Twin properties failed: " + err);
        return;
    }
    server.log("Twin properties retrieved successfully");
}

// It is assumed that Twins functionality is enabled
client.retrieveTwinProperties(onRetrieved);
```

### updateTwinProperties(*props[, onUpdated]*) ###

This method [updates Device Twin reported properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties).

The method returns nothing. A result of the operation may be obtained via the [*onUpdated*](#callback-onupdatederror-props) callback, if specified in this method.

The method may be called only if Twins functionality is enabled.

It is allowed to call this method while the previous update operation is not completed yet. 
Maximum amount of pending operations is defined by the [client settings](#optional-settings).

If *props* parameter is `null` or has incompatible type, the method will throw an exception.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *props* | Table | Yes | Key-value table with the reported properties. Every key is always a *String* with the name of the property. The value is the corresponding value of the property. Keys and values are fully application specific. |
| *[onUpdated](#callback-onupdatederror-props)* | Function  | Optional | [Callback](#callback-onupdatederror-props) called when the operation is completed or an error happens. |

#### Callback: onUpdated(*error, props*) ####

This callback is called when [Device Twin properties are updated](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |
| *props* | Table | The original properties passed to the [updateTwinProperties()](#updatetwinpropertiesprops-onupdated) method. |

#### Example ####

```squirrel
props <- {"exampleProp": "val"};

function onUpdated(err, props) {
    if (err != 0) {
        server.error("Twin properties update failed: " + err);
    } else {
        server.log("Twin properties updated successfully");
    }
}

// It is assumed that Twins functionality is enabled
client.updateTwinProperties(props, onUpdated);
```

### enableDirectMethods(*onMethod[, onDone]*) ###

This method enables or disables [Azure IoT Hub Direct Methods](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods).

To enable the feature, specify the [*onMethod*](#callback-onmethodname-params-reply) callback. To disable the feature, specify `null` as that callback.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

The method returns nothing. A result of the operation may be obtained via the [*onDone*](#callback-ondoneerror) callback, if specified in this method.

| Parameter | Data Type | Required? | Description |
| --- | --- | --- | --- |
| *[onMethod](#callback-onmethodname-params-reply)* | Function  | Yes | [Callback](#callback-onmethodname-params-reply) called every time a direct method is called by Azure IoT Hub. `null` disables the feature. |
| *[onDone](#callback-ondoneerror)* | Function  | Optional | [Callback](#callback-ondoneerror) called when the operation is completed or an error happens. |

#### Callback: onMethod(*name, params, reply*) ####

This callback is called every time a [Direct Method](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#respond-to-a-direct-method) is called by Azure IoT Hub.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *name* | String | Name of the called Direct Method. |
| *params* | Table | Key-value table with the input parameters of the called Direct Method. Every key is always a *String* with the name of the input parameter. The value is the corresponding value of the input parameter. Keys and values are fully application specific. |
| *reply* | Function | This [callback](#callback-replydata-onreplysent) should be called to send a reply to the direct method call. |

#### Callback: reply(*data[, onReplySent]*) ####

This [callback](#callback-replydata-onreplysent) should be called by application to [send a reply to the direct method call](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#respond-to-a-direct-method).

| Parameter | Data Type | Description |
| --- | --- | --- |
| *data* | [AzureIoTHub.DirectMethodResponse](#azureiothubdirectmethodresponse) | Data to send in response to the direct method call. |
| *onReplySent* | Function | [Callback](#callback-onreplysenterror-data) called when the operation is completed or an error happens. |

#### Callback: onReplySent(*error, data*) ####

This callback is called every time a [Direct Method](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#respond-to-a-direct-method) is called by Azure IoT Hub.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |
| *data* | [AzureIoTHub.DirectMethodResponse](#azureiothubdirectmethodresponse) | The original data passed to the [reply()](#callback-replydata-onreplysent) callback. |

#### Example ####

```squirrel
function onReplySent(err, data) {
    if (err != 0) {
        server.error("Sending reply failed: " + err);
    } else {
        server.log("Reply was sent successfully");
    }
}

function onMethod(name, params, reply) {
    server.log("Direct Method called. Name = " + name);
    local responseStatusCode = 200;
    local responseBody = {"example" : "val"};
    local response = AzureIoTHub.DirectMethodResponse(responseStatusCode, responseBody);
    reply(response, onReplySent);
}

function onDone(err) {
    if (err != 0) {
        server.error("Enabling Direct Methods failed: " + err);
    } else {
        server.log("Direct Methods enabled successfully");
    }
}

client.enableDirectMethods(onMethod, onDone);
```

### setDebug(*value*) ###

This method enables (*value* is `true`) or disables (*value* is `false`) the client debug output (including error logging). It is disabled by default. The method returns nothing.

### Additional Info ###

#### Callback: onDone(*error*) #####

This callback is called when a method is completed. This is just a common description of the similar callbacks specified as an argument in several methods. An application may use different callbacks with the described signature for different methods. Or define one callback and pass it to different methods.

| Parameter | Data Type | Description |
| --- | --- | --- |
| *[error](#error-code)* | Integer | `0` if the operation is completed successfully, an [error code](#error-code) otherwise. |

#### Error Code ####

An *Integer* error code which specifies a concrete error (if any) happened during an operation.

| Error Code | Description |
| --- | --- |
| 0 | No error. |
| -99..-1 and 128 | [Codes returned by the MQTT API](https://developer.electricimp.com/api/mqtt) |
| 100-999 except 128 | [Azure IoT Hub errors](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support). |
| 1000 | The client is not connected. |
| 1001 | The client is already connected. |
| 1002 | The feature is not enabled. |
| 1003 | The feature is already enabled. |
| 1004 | The operation is not allowed now. Eg. the same operation is already in process. |
| 1005 | The operation is timed out. |
| 1010 | General error. |

### Automatic SAS Token Refreshing ###

[SAS Token](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-security#security-tokens) always has an expiration time. If the token is expired, Azure IoT Hub disconnects the device. To prevent the disconnection the token must be updated before its expiration.

The library implements the token updating algorithm. It is enabled by default.

The token updating algorithm is the following:
1. Using a timer wakes up when the current token is near to expiration.
1. Waits for all current MQTT operations to be finished.
1. Calculates a new token using the connection string.
1. Disconnects from the MQTT broker.
1. Connects to the MQTT broker again using the new token as an MQTT client's password.
1. Subscribes to the topics which were subscribed to before the reconnection.
1. Sets the timer for the new token expiration.

The library does all these operations automatically and invisibly to an application. The [onDisconnected()](#callback-ondisconnectederror) and [onConnected()](#callback-onconnectederror) callbacks are not called. All the API calls, made by the application at the time of updating, are scheduled in a queue and processed right after the token updating algorithm is successfully finished. If the token update fails, the [onDisconnected()](#callback-ondisconnectederror) callback is called (if the callback has been set).

To disable the automatic token updating algorithm you can set the `tokenAutoRefresh` [client's option](#optional-settings) in the [AzureIoTHub.Client constructor](#constructor-azureiothubclientdeviceconnectionstring-onconnected-ondisconnected-options) to `false`.

## Examples ##

Full working examples are provided in the [examples](./examples) directory and described [here](./examples/README.md).

## Testing ##

Tests for the library are provided in the [tests](./tests) directory and described [here](./tests/README.md).

## License ##

This library is licensed under the [MIT License](./LICENSE).
