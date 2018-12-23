# Azure IoT Hub 5.0.0 #

Azure IoT Hub is an Electric Imp agent-side library for interfacing with Azure IoT Hub API version "2016-11-14". Starting with version 3, the library integrates with Azure IoT Hub using the MQTT protocol (previous versions used AMQP) as there is certain functionality, such as Device Twins and Direct Methods, that IoT Hub only supports via MQTT. Starting with version 5, the library supports Azure IoT Hub [Device Provisioning Service](https://docs.microsoft.com/en-us/azure/iot-dps/about-iot-dps).

**Note** The Azure IoT Hub MQTT integration is currently in public Beta. Before proceeding, please sign up for access to the Azure IoT Hub MQTT integration using [this link](https://connect.electricimp.com/azure-mqtt-integration-signup).

**Important** All Electric Imp devices can connect to Azure IoT Hub, regardless of which impCloud™ (AWS or Azure) they are linked to. For devices on the AWS impCloud, the connection to IoT Hub will occur cloud-to-cloud from AWS to Azure. For devices on the Azure impCloud, the connection to IoT Hub will occur within Azure. However, there is no difference between the functionality provided by the library in either of these scenarios.

The library consists of the following classes and methods:

- [AzureIoTHub.Registry](#azureiothubregistry) &mdash; Device management class, all requests use HTTP to connect to Azure IoT Hub.
  - [*create()*](#createdeviceinfo-callback) &mdash; Creates a a new device identity in Azure IoT Hub.
  - [*update()*](#updatedeviceinfo-callback) &mdash; Updates an existing device identity in Azure IoT Hub.
  - [*remove()*](#removedeviceid-callback) &mdash; Deletes a single device identity from Azure IoT Hub.
  - [*get()*](#getdeviceid-callback) &mdash; Returns the properties of an existing device identity in Azure IoT Hub.
  - [*list()*](#listcallback) &mdash; Returns a list of up to 1000 device identities in Azure IoT Hub.
- [AzureIoTHub.Device](#azureiothubdevice) &mdash; A device object used to manage registry device identities.
  - [*connectionString()*](#connectionstringhostname) &mdash; Returns the Device Connection String.
  - [*getBody()*](#getbody) &mdash; Returns the device identity properties.
- [AzureIoTHub.DPS](#azureiothubdps) &mdash; Used to provision devices in Azure IoT Hub Device Provisioning Service.
  - [*register()*](#registeroncompleted) &mdash; Registers the device on IoT Hub Device Provisioning Service.
  - [*getConnectionString()*](#getconnectionstringoncompleted) &mdash; Returns the Device Connection String.
- [AzureIoTHub.Message](#azureiothubmessage) &mdash; Used as a wrapper for messages to/from Azure IoT Hub.
  - [*getProperties()*](#getproperties) &mdash; Returns a message’s properties.
  - [*getBody()*](#getbody) &mdash; Returns the message's content.
- [AzureIoTHub.DirectMethodResponse](#azureiothubdirectmethodresponse) &mdash; Used as a wrapper for Direct Methods responses.
- [AzureIoTHub.Client](#azureiothubclient) &mdash; Used to open MQTT connection to Azure IoT Hub, and to use Messages, Twins, Direct Methods functionality.
  - [*connect()*](#connect) &mdash; Opens a connection to Azure IoT Hub.
  - [*disconnect()*](#disconnect) &mdash; Closes the connection to Azure IoT Hub.
  - [*isConnected()*](#isconnected) &mdash; Checks if the client is connected to Azure IoT Hub.
  - [*sendMessage()*](#sendmessagemessage-onsent) &mdash; Sends a message to Azure IoT Hub.
  - [*enableIncomingMessages()*](#enableincomingmessagesonreceive-ondone) &mdash; Enables or disables message receiving from Azure IoT Hub.
  - [*enableTwin()*](#enabletwinonrequest-ondone) &mdash; Enables or disables Azure IoT Hub Device Twins functionality.
  - [*retrieveTwinProperties()*](#retrievetwinpropertiesonretrieved) &mdash; Retrieves Device Twin properties.
  - [*updateTwinProperties()*](#updatetwinpropertiesproperties-onupdated) &mdash; Updates Device Twin reported properties.
  - [*enableDirectMethods()*](#enabledirectmethodsonmethod-ondone) &mdash; Enables or disables Azure IoT Hub Direct Methods.
  - [*setDebug()*](#setdebugvalue) &mdash; Enables or disables the client debug output.

**To add this library to your project, add** `#require "AzureIoTHub.agent.lib.nut:5.0.0"` **to the top of your agent code.**

[![Build Status](https://travis-ci.org/electricimp/AzureIoTHub.svg?branch=master)](https://travis-ci.org/electricimp/AzureIoTHub)

## Examples ##

Full working examples are provided in the [examples](./examples) directory and described [here](./examples/README.md).

## Authentication ##

You will need a Microsoft Azure account. If you do not have one, please sign up [here](https://azure.microsoft.com/en-us/resources/videos/sign-up-for-microsoft-azure/) before continuing.

Communication with a concrete Azure IoT Hub happens using [AzureIoTHub.Client](#azureiothubclient) class. To instantiate an object of this class and authenticate the device in the Azure IoT Hub you need to have **Device Connection String**. It may be obtained by one of the following ways:

### Using Device Provisioning Service ###

Use this way when your solution has several Azure IoT Hubs and an instance of Azure [Device Provisioning Service](https://docs.microsoft.com/en-us/azure/iot-dps/about-iot-dps), which distributes your devices between the hubs. This is the main production-oriented way.

1. Open the [Azure Portal](https://portal.azure.com/). You need to have owner-level permissions.
2. Select or create your Azure IoT Hub resource(s).
3. Select or create your Azure IoT Hub Device Provisioning Service (DPS) resource.
4. Open the **Overview** page of your DPS, copy the **ID Scope** to the clipboard and paste it (as **scopeId** param) into the [AzureIoTHub.DPS](#azureiothubdps) constructor in your Squirrel application code.
5. Link your IoT Hub(s) to the DPS (if not linked yet) on the **Linked IoT hubs** page of your DPS.
6. Create an Individual Enrollment on the **Manage enrollments** page of your DPS (if not created yet). The enrollment must use the **Symmetric key** attestation mechanism.
7. Open your Individual Enrollment, copy the **Primary key** to the clipboard and paste it (as **deviceKey** param) into the [AzureIoTHub.DPS](#azureiothubdps) constructor in your Squirrel application code.
8. Put the **Registration ID** you used when creating the Individual Enrollment to [AzureIoTHub.DPS](#azureiothubdps) constructor (as **registrationId** param) in your Squirrel application code.
9. Using [*register()*](#registeroncompleted) method of the AzureIoTHub.DPS instance register your device in the IoT Hub and obtain a **Device Connection String**.
10. Pass the **Device Connection String** into the [AzureIoTHub.Client](#azureiothubclient) constructor.

Examples: [here](#azureiothubdps-example), [here](./examples#twins-example-setup-and-run) and [here](./examples#iot-central-example-setup-and-run). **TODO (Does the IoTCentral full example fit here?)**

### Using IoT Hub Registry ###

You may use this way when your solution has only one Azure IoT Hub or when you know in advance which device should be registered in which IoT Hub.

1. Open the [Azure Portal](https://portal.azure.com/). You need to have owner-level permissions.
2. Select or create your Azure IoT Hub resource.
3. Under **Settings** click **Shared Access Policies**.
4. Select a policy which has read/write permissions (such as the *registryReadWrite*) or create a new policy.
5. Copy the **Connection string--primary key** to the clipboard and paste it into the [AzureIoTHub.Registry](#azureiothubregistry) constructor in your Squirrel application code.
6. Using [*create()*](#createdeviceinfo-callback) method of the AzureIoTHub.Registry instance register your device in the IoT Hub and obtain the device description as an instance of the [AzureIoTHub.Device](#azureiothubdevice) class.
7. Using [*connectionString()*](#connectionstringhostname) method of the AzureIoTHub.Device instance get **Device Connection String** and pass it into the [AzureIoTHub.Client](#azureiothubclient) constructor.

Examples: [here](#azureiothubregistry-example) and [here](./examples#direct-methods-example-setup-and-run).

### Using Azure Portal ###

You may use this way if your device is already registered in an Azure IoT Hub. In this case you can obtain **Device Connection String** from Azure portal.

1. Open the [Azure Portal](https://portal.azure.com/). You need to have device-level permissions.
2. Select or create your Azure IoT Hub resource.
3. Click **Device Explorer**.
4. Select your device &mdash; you will need to know the device ID used to register the device with IoT Hub.
5. Copy the **Connection string--primary key** (this is the needed **Device Connection String**) to the clipboard and paste it into the [AzureIoTHub.Client](#azureiothubclient) constructor in your Squirrel application code.

Examples: [here](./examples#messages-example-setup-and-run).

## AzureIoTHub.Registry ##

The AzureIoTHub.Registry class is used to manage IoT Hub devices. This class allows your to create, remove, update, delete and list the IoT Hub devices in your Azure account. See [‘Authentication’](#authentication) section for more information.

## AzureIoTHub.Registry Class Usage ##

### Constructor: AzureIoTHub.Registry(*connectionString*) ###

This method instantiates an AzureIoTHub.Registry object which exposes the Device Registry functions.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *connectionString* | String | Yes | Provided by the Azure Portal *(see [‘Authentication’](#authentication), above)* |

#### Example ####

```squirrel
#require "AzureIoTHub.agent.lib.nut:5.0.0"

// Instantiate a client using your connection string
const AZURE_REGISTRY_CONN_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=<KEY_NAME>;SharedAccessKey=<KEY_HASH>";
registry <- AzureIoTHub.Registry(AZURE_REGISTRY_CONN_STRING);
```

## AzureIoTHub.Registry Class Methods ##

All class methods make asynchronous HTTP requests to IoT Hub. Each one can therefore take a callback function which will be executed when a response is received from IoT Hub. The callback provides the following parameters:

| Parameter | Value |
| --- | --- |
| *err* | This will be `null` if there was no error. Otherwise it will be a table containing two keys: *response*, the original **httpresponse** object, and *message*, an error report string |
| *response* | For *create()*, *update()* and *get()*: an [AzureIoTHub.Device](#azureiothubdevice) object.<br />For *list()*: an array of [AzureIoTHub.Device](#azureiothubdevice) objects.<br />For *remove()*: nothing |

### create(*[deviceInfo][, callback]*) ###

This method creates a new device identity in IoT Hub.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceInfo* | Table | No | Must contain the required keys specified in the [Device Info Table](#device-info-table) or an [*AzureIoTHub.Device*](#azureiothubdevice) object. If the *deviceInfo* table’s *deviceId* key is not provided, the agent’s ID will be used |
| *callback* | Function | No | A function to be called when the IoT Hub responds |

### update(*deviceInfo[, callback]*) ###

This method updates an existing device identity in IoT Hub. The update function cannot change the values of any read-only properties, including the *deviceId*, and the *statusReason* value cannot be updated via this method. 

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceInfo* | Table | Yes | Must contain the required keys specified in the [Device Info Table](#device-info-table) or an [*AzureIoTHub.Device*](#azureiothubdevice) object. It **must** include a *deviceId* key |
| *callback* | Function | No | A function to be called when the IoT Hub responds |

### remove(*deviceID[, callback]*) ###

This method deletes a single device identity from IoT Hub.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceID* | String | Yes | A device identifier |
| *callback* | Function | No | A function to be called when the IoT Hub responds |

### get(*deviceId, callback*) ###

This method requests the properties of an existing device identity in IoT Hub.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceID* | String | Yes | A device identifier |
| *callback* | Function | Yes | A function to be called when the IoT Hub responds |

### list(*callback*) ###

This method requests a list of device identities. When IoT Hub responds, an array of up to 1000 existing [AzureIoTHub.Device](#azureiothubdevice) objects will be passed to the *callback* function.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *callback* | Function | Yes | A function to be called when the IoT Hub responds |

## AzureIoTHub.Registry Example ##

This example code will create an IoT Hub device using an imp’s agent ID if one isn’t found in the IoT Hub device registry. It will then instantiate the [AzureIoTHub.Client](#azureiothubclient) class for later use.

```squirrel
#require "AzureIoTHub.agent.lib.nut:5.0.0"

const AZURE_REGISTRY_CONN_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";

client <- null;
local agentId = split(http.agenturl(), "/").pop();

local registry = AzureIoTHub.Registry(AZURE_REGISTRY_CONN_STRING);
local hostname = AzureIoTHub.ConnectionString.Parse(AZURE_REGISTRY_CONN_STRING).HostName;

function onConnected(err) {
    if (err != 0) {
        server.error("Connection failed: " + err);
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
            // No such device, so let's create one with default parameters
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

## AzureIoTHub.Device ##

The AzureIoTHub.Device class is used to create Devices identity objects used by the [AzureIoTHub.Registry](#azureiothubregistry) class. Registry methods will create device objects for you if you choose to pass in tables. 

### AzureIoTHub.Device Class Usage ###

#### Constructor: AzureIoTHub.Device(*[deviceInfo]*) ####

The constructor creates a device object from the *deviceInfo* parameter. See the *Device Info Table* below for details on what to include in the table. If no *deviceInfo* is provided, default settings will be used. 

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceInfo* | Table | No | Device specification information: see ‘Device Info Table’, below |

#### Device Info Table ####

| Key | Required? | Description |
| --- | --- | --- |
| *deviceId* | Yes, read-only on updates | A case-sensitive string (up to 128 characters long) of Ascii 7-bit alphanumeric characters plus -, :, ., +, %, \_, #, \*, ?, !, (, ), =, @, ;, $, ' and ,<br />Default: the device’s agent ID |
| *generationId* | Read only | An IoT Hub-generated, case-sensitive string up to 128 characters long. This value is used to distinguish devices with the same *deviceId*, when they have been deleted and re-created. Default: `null` |
| *etag* | Read only | A string representing a weak ETag for the device identity, as per RFC7232. Default: `null` |
| *connectionState* | Read only | A field indicating connection status: either `"Connected"` or `"Disconnected"`. This field represents the IoT Hub view of the device connection status. **Important** This field should be used only for development/debugging purposes. The connection state is updated only for devices using MQTT or AMQP. It is based on protocol-level pings (MQTT pings, or AMQP pings), and it can have a maximum delay of only five minutes. For these reasons, there can be false positives, such as devices reported as connected but that are disconnected. Default: `"Disconnected"` |
| *status* | Yes | An access indicator. Can be `"Enabled"` or `"Disabled"`. If `"Enabled"`, the device is allowed to connect. If `"Disabled"`, this device cannot access any device-facing endpoint. Default: `"Enabled"` |
| *statusReason* | Optional | A 128-character string that stores the reason for the device status. All UTF-8 characters are allowed. Default: `null` |
| *connectionStateUpdatedTime* | Read only | A temporal indicator, showing the date and time the connection state was last updated. Default: `null` |
| *statusUpdatedTime* | Read only | A temporal indicator, showing the date and time of the last status update. Default: `null` |
| *lastActivityTime* | Read only | A temporal indicator, showing the date and time the device last connected, received or sent a message. Default: `null` |
| *cloudToDeviceMessageCount* | Read only | The number of cloud to device messages awaiting delivery. Default: 0 |                               
| *authentication* | Optional | An authentication table containing information and security materials. The primary and a secondary key are stored in base64 format. Default: `{"symmetricKey" : {"primaryKey" : null, "secondaryKey" : null}}` |

**Note** The default authentication parameters do not contain the authentication needed to create an [AzureIoTHub.Client](#azureiothubclient) object.    

## AzureIoTHub.Device Class Methods ##

### connectionString(*hostname*) ###

This method retrieves the Device Connection String from the stored *authentication* and *deviceId* properties of the specified host. A Device Connection String is needed to create an [AzureIoTHub.Client](#azureiothubclient) object. 

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *hostname* | String | Yes | The name of the host, found within the Device Connection String |

#### Returns ####

String &mdash; The requested Device Connection String.

### getBody() ###

This method returns the stored device properties.

#### Returns ####

Table &mdash; The stored device properties. See the [Device Info Table](#device-info-table), above, for details of the possible keys the table may contain.

## AzureIoTHub.DPS ##

This class is used to provision devices in Azure IoT Hub [Device Provisioning Service](https://docs.microsoft.com/en-us/azure/iot-dps/about-iot-dps). It allows you to register a device and obtain its **Device Connection String**. See [‘Authentication’](#authentication) section for more information.

## AzureIoTHub.DPS Class Usage ##

### Constructor: AzureIoTHub.DPS(*scopeId, registrationId, deviceKey*) ###

This method returns a new AzureIoTHub.DPS instance.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *scopeId* | String | Yes | [Scope ID](https://docs.microsoft.com/en-us/azure/iot-dps/concepts-device#id-scope) of Azure IoT Hub DPS |
| *registrationId* | String | Yes | [Registration ID](https://docs.microsoft.com/en-us/azure/iot-dps/concepts-device#registration-id) of the device |
| *deviceKey* | String | Yes | [Device symmetric key](https://docs.microsoft.com/en-us/azure/iot-dps/concepts-symmetric-key-attestation) |

#### Example ####

```squirrel
const AZURE_DPS_SCOPE_ID  = "<Scope ID>";
const AZURE_DPS_REG_ID    = "<Registration ID>";
const AZURE_DPS_DEV_KEY   = "<Device key>";

// Create an instance
dps <- AzureIoTHub.DPS(AZURE_DPS_SCOPE_ID, AZURE_DPS_REG_ID, AZURE_DPS_DEV_KEY);
```

## AzureIoTHub.DPS Class Methods ##

### onCompleted Callback ###

This callback is executed when a AzureIoTHub.DPS method completes. All of the methods below make use of this callback, but it is important to understand that each of these methods registers their own callback. In other words, you may choose to implement as many different onDone handlers as there are AzureIoTHub.DPS methods capable of using one, or simply register a single callback with all of the methods. If you register a callback with one method, the handler will not be called by other methods: each method has to explicitly register its callback.

The callback has the following parameters:

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *error* | Integer | `0` if the operation is successful, otherwise an [error code](#error-codes) |
| *response* | Table | Key-value table with the response provided by Azure server. May be `null`. For information on the response format, please see [the Azure documentation](https://docs.microsoft.com/en-us/rest/api/iot-dps/runtimeregistration). May also contain error details |
| *connectionString* | String | Device connection string. `null` in case of an error |

### register(*onCompleted*) ###

[Registers](https://docs.microsoft.com/en-us/rest/api/iot-dps/runtimeregistration/registerdevice) the device using Azure IoT Hub Device Provisioning Service. If registration completes successfully and the device is assigned to an IoT Hub, this method returns **Device Connection String** via the [onCompleted handler](#oncompleted-callback).

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *[onCompleted](#oncompleted-callback)* | Function | Yes | A function to be called when the operation is completed or an error occurs |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onCompleted handler](#onCompleted-callback).

#### Example ####

```squirrel
function onCompleted(err, resp, connStr) {
    if (err != 0) {
        server.error("Registration failed: code = " + err + " response = " + http.jsonencode(resp));
    } else {
        server.log("Registration finished successfully. Connection string = " + connStr);
    }
}

dps.register(onCompleted);
```

### getConnectionString(*onCompleted*) ###

If the device is already [registered](https://docs.microsoft.com/en-us/rest/api/iot-dps/runtimeregistration/deviceregistrationstatuslookup) and assigned to an IoT Hub, this method returns **Device Connection String** via the [onCompleted handler](#oncompleted-callback). Otherwise returns the **The device is/was not registered** error (see [error codes](#error-codes)).

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *[onCompleted](#oncompleted-callback)* | Function | Yes | A function to be called when the operation is completed or an error occurs |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onDone handler](#ondone-callback).

#### Example ####

```squirrel
function onCompleted(err, resp, connStr) {
    if (err != 0) {
        server.error("Getting of the connection string failed: code = " + err + " response = " + http.jsonencode(resp));
    } else {
        server.log("Connection string = " + connStr);
    }
}

dps.getConnectionString(onCompleted);
```

## AzureIoTHub.DPS Example ##

```squirrel
#require "AzureIoTHub.agent.lib.nut:5.0.0"

const AZURE_DPS_SCOPE_ID = "<YOUR_AZURE_DPS_SCOPE_ID>";
const AZURE_DPS_REGISTRATION_ID = "<YOUR_AZURE_DPS_REGISTRATION_ID>";
const AZURE_DPS_DEVICE_KEY = "<YOUR_AZURE_DPS_DEVICE_KEY>";

client <- null;

local dps = AzureIoTHub.DPS(AZURE_DPS_SCOPE_ID, AZURE_DPS_REGISTRATION_ID, AZURE_DPS_DEVICE_KEY);

function onConnected(err) {
    if (err != 0) {
        server.error("Connection failed: " + err);
    }
}

local registrationCalled = false;
local onCompleted = null;
onCompleted = function(err, resp, connStr) {
    if (err == 0) {
        if (registrationCalled) {
            server.log("Device has been registered!");
        } else {
            server.log("Device is registered already!");
        }
        ::client <- AzureIoTHub.Client(connStr, onConnected);
    } else if (err == AZURE_DPS_ERROR_NOT_REGISTERED && !registrationCalled) {
        // The device is not registered
        server.log("Device is not registered. Starting registration...");
        registrationCalled = true;
        // Register the device
        dps.register(onCompleted);
    } else {
        server.error("Error occured: code = " + err + " response = " + http.jsonencode(resp));
    }
}.bindenv(this);

// Try to get a Device Connection String
dps.getConnectionString(onCompleted);
```

## AzureIoTHub.Message ##

This class is used as a wrapper for messages send to and received from Azure IoT Hub.

## AzureIoTHub.Message Class Usage ##

### Constructor: AzureIoTHub.Message(*message[, properties]*) ###

This method returns a new AzureIoTHub.Message instance.

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | [Any supported by the MQTT API](https://developer.electricimp.com/api/mqtt/mqttclient/createmessage) | Yes | The message body |
| *properties* | Table | Optional | The message properties. Keys (which are always strings) and values are entirely application specific |

#### Example ####

```squirrel
local message1 = AzureIoTHub.Message("This is a message");
local message2 = AzureIoTHub.Message(blob(256));
local message3 = AzureIoTHub.Message("This is a message with properties", {"property": "value"});
```

## AzureIoTHub.Message Class Methods ##

### getProperties() ###

This method provides the properties of the message. Incoming messages contain properties set by Azure IoT Hub.

#### Returns ####

Table &mdash; The application-specific message properties.

### getBody() ###

This method returns the message’s body. Messages that have been created locally will be of the same type as they were when created, but messages that were received from Azure IoT Hub are of one of the [types supported by the MQTT API](https://developer.electricimp.com/api/mqtt/mqttclient/onmessage).

#### Returns ####

Various &mdash; The message body.

## AzureIoTHub.DirectMethodResponse ##

This class is used to create a response to the received [Direct Method call](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods) to return it to Azure IoT Hub.

## AzureIoTHub.DirectMethodResponse Class Usage ##

### Constructor: AzureIoTHub.DirectMethodResponse(*status[, body]*) ###

This method returns a new AzureIoTHub.DirectMethodResponse instance.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *status* | Integer | Yes | The status of the Direct Method execution. Fully application specific |
| *body* | Table | Optional | The returned data. Every key is always a string. Keys and values are fully application specific |

## AzureIoTHub.Client ##

This class is used to transfer data to and from Azure IoT Hub. To use this class, the device must be registered as an IoT Hub device in an Azure account.

Only one instance of this class is allowed.

AzureIoTHub.Client uses the MQTT 3.1.1 protocol. It supports the following functionality:

- Connecting and disconnecting to/from Azure IoT Hub. Azure IoT Hub supports only one connection per device.
- Sending messages to Azure IoT Hub.
- Receiving messages from Azure IoT Hub (optional functionality).
- Device Twin operations (optional functionality).
- Direct Method processing (optional functionality).

Please keep in mind the [Azure IoT Hub limitations](https://github.com/MicrosoftDocs/azure-docs/blob/master/includes/iot-hub-limits.md).

All optional functionalities are disabled after a client instantiation. If an optional function is needed, it should be enabled after the client has successfully connected, and it should be explicitly re-enabled after every re-connection of the client. The class provides methods to enable every optional feature.

Most of the methods return nothing. A result of an operation may be obtained via a callback function specified in the method. Specific callbacks are described within every method. Many callbacks provide an [error code](#error-codes) which specifies a concrete error (if any) happened during the operation. 

## AzureIoTHub.Client Class Usage ##

### Constructor: AzureIoTHub.Client(*deviceConnectionString[, onConnected][, onDisconnected][, options]*) ###

This method returns a new AzureIoTHub.Client instance.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *deviceConnectionString* | String | Yes | A Device Connection String: includes the host name to connect, the device ID and the shared access string. See [‘Authentication’](#authentication) section for more information. |
| *[onConnected](#onconnected-callback)* | Function | Optional | A function to be called every time the device connects *(see below)* |
| *[onDisconnected](#ondisconnected-callback)* | Function | Optional | A function to be called every time the device is disconnected *(see below)* |
| *[options](#optional-settings)* | Table | Optional | Optional client configuration settings *(see below)* |

#### onConnected Callback ####

This callback is a good place to enable optional functionality, if needed.

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *[error](#error-codes)* | Integer | `0` if the connection was successful, otherwise an [error code](#error-codes) |

#### onDisconnected Callback ####

This callback is a good place to call the [*connect()*](#connect) method again, if an unexpected disconnection occurred.

**Note** Authentication token always has an expiration time. The library is configured to request tokens with a one-hour life. If the [SAS token auto-refresh](#refreshing-sas-tokens-automatically) feature is disabled and the current token has expired, the Azure IoT Hub disconnects the device and the *onDisconnected()* handler is called. To reconnect with a new token, you can simply execute the connection flow again by calling [*connect()*](#connect).

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *[error](#error-codes)* | Integer | `0` if the disconnection was caused by the [*disconnect()*](#disconnect) method, otherwise an [error code](#error-codes) |

#### Optional Settings ####

These settings affect the behavior of the client and the operations it performs. Every setting is optional and has a default.

| Key | Value Type | Description |
| --- | --- | --- |
| *qos* | Integer | An MQTT Quality of Service (QoS) setting. Azure IoT Hub supports QoS 0 and 1 only. Default: 0 |
| *keepAlive* | Integer | Keep-alive MQTT parameter, in seconds. See [here](https://developer.electricimp.com/api/mqtt/mqttclient/connect) for more information. Default: 60s |
| *twinsTimeout* | Integer | Timeout in seconds for [Retrieve Twin](#retrievetwinpropertiesonretrieved) and [Update Twin](#updatetwinpropertiesproperties-onupdated) operations.  Default: 10s |
| *dMethodsTimeout* | Integer | Timeframe (in seconds) to [reply to direct method](#callback-replydata-onreplysent) call. Default: 30s |
| *maxPendingTwinRequests* | Integer | Maximum number of pending [Update Twin](#updatetwinpropertiesproperties-onupdated) operations. Default: 3 |
| *maxPendingSendRequests* | Integer | Maximum number of pending [Send Message](#sendmessagemessage-onsent) operations. Default: 3 |
| *tokenTTL* | Integer | SAS token's time-to-live (in seconds). For more information, see [here](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-security#security-token-structure). Default: 86400s |
| *tokenAutoRefresh* | Boolean | If `true`, the [SAS token auto-refresh](#refreshing-sas-tokens-automatically) feature is enabled, otherwise disabled. Default: true |

#### Example ####

```squirrel
const AZURE_DEVICE_CONN_STRING = "HostName=<HUB_ID>.azure-devices.net;DeviceId=<DEVICE_ID>;SharedAccessKey=<DEVICE_KEY_HASH>";

function onConnected(err) {
    if (err != 0) {
        server.error("Connect failed: " + err);
        return;
    }
    server.log("Connected");
    
    // Here is a good place to enable required features, like Device Twins or Direct Methods
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

## AzureIoTHub.Client Class Methods ##

Azure IoT Hub supports only one connection per device.

All methods other than [*connect()*](#connect) and [*isConnected()*](#isconnected) should be called when the client is connected.

### onDone Callback ###

This callback is executed when a AzureIoTHub.Client method completes. Many of the methods below make use of this callback, but it is important to understand that each of these methods registers their own callback. In other words, you may choose to implement as many different onDone handlers as there are AzureIoTHub.Client methods capable of using one, or simply register a single callback with all of the methods. If you register a callback with one method, the handler will not be called by other methods: each method has to explicitly register its callback.

The callback has the following parameter:

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *[error](#error-codes)* | Integer | `0` if the operation is completed successfully, otherwise an [error code](#error-codes) |

### connect() ###

This method opens a connection to Azure IoT Hub.

#### Returns ####

Nothing &mdash; The result of the connection attempt may be obtained via the [onConnected handler](#onconnected-callback), if set.

### disconnect() ###

This method closes the connection to Azure IoT Hub. It does nothing if the connection is already closed.

#### Returns ####

Nothing &mdash; When the disconnection is completed the [onDisconnected handler](#ondisconnected-callback), if set, is called.

### isConnected() ###

This method checks if the client is connected to Azure IoT Hub.

#### Returns ####

Boolean &mdash; `true` if the client is connected, otherwise `false`.

### sendMessage(*message[, onSent]*) ###

This method [sends a message to Azure IoT Hub](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages).

You may send send one further message while the previous send operation is still in progress. The maximum number of pending operations is defined by the [client settings](#optional-settings).

The Azure IoT Hub provides only limited support of the `retain` MQTT flag (as described [here](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages)) so this library doesn't currently support `retain`.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | Yes | The message to send |
| *[onSent](#onsent-callback)* | Function | Optional | A function to be called when the message is considered as sent or an error occurs |

If `null` is passed into *message*, or the argument is of an incompatible type, the method will throw an exception.

#### onSent Callback ####

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *[error](#error-codes)* | Integer | `0` if the operation completed successfully, otherwise an [error code](#error-codes) |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | The original *message* passed to *sendMessage()* |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onSent handler](#onsent-callback), if specified in this method.

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

This method enables or disables the [receipt of messages from Azure IoT Hub](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-cloud-to-device-messages).

To enable the feature, pass a function into [*onReceive*](#onreceive-callback). To disable the feature, pass in `null`.

The feature is automatically disabled every time the client disconnects. It should be re-enabled after every new connection, if needed.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *[onReceive](#onreceive-callback)* | Function | Yes | A function to be called every time a new message is received from Azure IoT Hub, or `null` to disable message receipt |
| *[onDone](#ondone-callback)* | Function | Optional | A function to be called when the operation is completed or an error occurs |

#### onReceive Callback ####

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *message* | [AzureIoTHub.Message](#azureiothubmessage) | A received message |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onDone handler](#ondone-callback), if specified in this method.

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

To enable the feature, pass a function into [*onRequest*](#onrequest-callback). To disable the feature, pass in `null`.

The feature is automatically disabled every time the client disconnects. It should be re-enabled after every new connection, if needed.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *[onRequest](#onrequest-callback)* | Function  | Yes | A function to be called every time a new request with desired Device Twin properties is received from Azure IoT Hub, `null` to disable the feature |
| *[onDone](#ondone-callback)* | Function | Optional | A function to be called when the operation is completed or an error occurs |

#### onRequest Callback ####

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *properties* | Table | The desired properties and their version. Every key is a string. Keys and values are entirely application specific |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onDone handler](#ondone-callback), if specified in this method.

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

It may be called only if Device Twins functionality is enabled. Do not call this method until any previous retrieve operation has completed. 

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *[onRetrieved](#onretrieved-callback)* | Function | Yes | A function to be called when the properties have been retrieved |

#### onRetrieved Callback ####

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *[error](#error-codes)* | Integer | `0` if the operation is completed successfully, otherwise an [error code](#error-codes) |
| *reportedProperties* | Table | The reported properties and their version. This parameter should be ignored if *error* is not `0`. Every key is always a string. Keys and values are entirely application specific |
| *desiredProperties* | Table | The desired properties and their version. This parameter should be ignored if *error* is not `0`. Every key is always a string. Keys and values are entirely application specific |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onRetrieved handler](#onretrieved-callback).

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

### updateTwinProperties(*properties[, onUpdated]*) ###

This method [updates Device Twin reported properties](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties).

It may be called only if Device Twins functionality is enabled.

You can call this method again while the previous update operation is not yet complete. The maximum number of pending operations is defined by the [client settings](#optional-settings).

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *properties* | Table | Yes | The reported properties. Every key is always a string. Keys and values are entirely application specific |
| *[onUpdated](#onupdated-callback)* | Function | Optional | A function to be called when the operation is completed or an error occurs |

If the *properties* parameter is passed `null` or an item of incompatible type, the method will throw an exception.

#### onUpdated Callback ####

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *[error](#error-codes)* | Integer | `0` if the operation is completed successfully, otherwise an [error code](#error-codes) |
| *properties* | Table | The original properties passed to *updateTwinProperties()* |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onUpdated handler](#onupdated-callback), if set.

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

To enable the feature, pass a function into [*onMethod*](#onmethod-callback). To disable the feature, pass in `null`.

The feature is automatically disabled every time the client is disconnected. It should be re-enabled after every new connection, if needed.

#### Parameters ####

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *[onMethod](#onmethod-callback)* | Function  | Yes | A function to be called every time a Direct Method is called by Azure IoT Hub, or `null` to disable the feature |
| *[onDone](#ondone-callback)* | Function | Optional | A function to be called when the operation is completed or an error occurs |

#### Returns ####

Nothing &mdash; The result of the operation may be obtained via the [onDone handler](#ondone-callback).

#### onMethod Callback ####

| Parameter | Data&nbsp;Type | Description |
| --- | --- | --- |
| *name* | String | Name of the called Direct Method |
| *params* | Table | The input parameters of the called Direct Method. Every key is always a string. Keys and values are entirely application specific |
| *reply* | Function | A function to be called to [send a reply to the direct method call](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#respond-to-a-direct-method). Details below |

##### The onMethod Callback Reply Function #####

The function passed into the *onMethod* callback’s *reply* parameter has the following parameters of its own:

| Parameter | Data&nbsp;Type | Required? | Description |
| --- | --- | --- | --- |
| *data* | [AzureIoTHub.DirectMethodResponse](#azureiothubdirectmethodresponse) | Yes | Data to send in response to the direct method call |
| *onReplySent* | Function | No | A function to be called when the operation is complete or an error occurs. It returns nothing, and has the following parameters:<br />&bull; *error* &mdash; An integer which will be `0` if the operation is completed successfully, otherwise an [error code](#error-codes)<br />&bull; *data* &mdash; A reference to the data passed into the callback function |

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

This method enables (*value* is `true`) or disables (*value* is `false`) the client debug output (including error logging). It is disabled by default. 

#### Returns ####

Nothing.

## Refreshing SAS Tokens Automatically ##

[SAS Token](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-security#security-tokens) always has an expiration time. If the token is expired, Azure IoT Hub disconnects the device. To prevent the disconnection, the token must be updated before its expiration.

The library implements token updating, which is enabled by default.

The token updating algorithm is the following:
1. A timer fires when the current token is near to expiration.
1. The library waits for all current operations to be completed (see the note below).
1. The library generates a new token using the Device Connection String.
1. The library disconnects from Azure IoT Hub.
1. The library re-connects to Azure IoT Hub using the new token as the MQTT client's password.
1. The library subscribes to the topics to which it was subscribed before the reconnection.
1. The library sets a new timer to fire just before the new token is due to expire.

The library performs all these operations automatically and invisibly to an application. The [*onDisconnected*](#callbacks) and [*onConnected*](#callbacks) callbacks are not called. Any API calls made by the application during the update process are retained in a queue and processed once the token has been successfully updated. If the token can’t be updated, the [*onDisconnected*](#callbacks) callback is executed (if set).

To stop the token being updated automatically, you can set the *tokenAutoRefresh* option in the [AzureIoTHub.Client constructor](#constructor-azureiothubclientdeviceconnectionstring-onconnected-ondisconnected-options) to `false`.

**Note:** Some of the operations (like retrieving twin properties) are two-phase. This means that the library sends a message and waits for a response message from the server. During these operations the library doesn't start token refreshing but waits for them to finish first. This rule also works with direct methods: when the library receives a direct method call, it doesn't start token refreshing until that call is replied or timed out. So please keep this in mind setting the timeouts for these operations.

## Error Codes ##

The table below describes the error codes for all the library classes.
Error code - an integer number which specifies a concrete error (if any) which occurred during an operation.

| Error Code | Applicable classes | Description |
| --- | --- | --- |
| 0 | [DPS](#azureiothubdps), [Client](#azureiothubclient) | No error |
| -99..-1 and 128 | [Client](#azureiothubclient) | [Codes returned by the MQTT API](https://developer.electricimp.com/api/mqtt) |
| 1..99 | [DPS](#azureiothubdps) | [Internal errors of the HTTP API](https://developer.electricimp.com/api/httprequest/sendasync) |
| 100-999 except 128 | [DPS](#azureiothubdps), [Client](#azureiothubclient) | For the [Client](#azureiothubclient) class - [Azure IoT Hub errors](https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support). For the [DPS](#azureiothubdps) class - HTTP error codes from [Azure DPS REST API](https://docs.microsoft.com/en-us/rest/api/iot-dps/). |
| 1000 | [Client](#azureiothubclient) | The client is not connected |
| 1001 | [Client](#azureiothubclient) | The client is already connected |
| 1002 | [Client](#azureiothubclient) | The feature is not enabled |
| 1003 | [Client](#azureiothubclient) | The feature is already enabled |
| 1004 | [Client](#azureiothubclient) | The operation is not allowed at the moment, eg. the same operation is already in process |
| 1005 | [Client](#azureiothubclient) | The operation timed out |
| 1010 | [DPS](#azureiothubdps) | The device is/was not registered |
| 1100 | [DPS](#azureiothubdps), [Client](#azureiothubclient) | General error |

## Testing ##

Tests for the library are provided in the [tests](./tests) directory.

## License ##

This library is licensed under the [MIT License](./LICENSE).
