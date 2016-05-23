# Azure IoT Hub Client 1.2.1

The Azure IoT Hub client is an Electric Imp agent-side library for interfacing to the Azure IoT Hub version “2015-08-15-preview”. It currently only supports the device registry (create, update, delete, get, list) and sending device-to-cloud events. Receiving events is currently not functioning.

This library is ported from and designed to be as close as possible to the [NodeJS SDK](https://github.com/Azure/azure-iot-sdks/blob/master/node/). Refer to the [NodeJS SDK](https://github.com/Azure/azure-iot-sdks/blob/master/node/) for further information.

**To add this library to your project, add** `#require "azureiothub.class.nut:1.2.1"` **to the top of your agent code.**

[![Build Status](https://travis-ci.org/electricimp/AzureIoTHub.svg?branch=develop)](https://travis-ci.org/electricimp/AzureIoTHub)

## Authentication

The Azure Portal provides the Connection String, passed into the following constructor’s *connectionString* parameter. To use the Device Registry you will require owner-level permissions. To use the Client you need device-level permissions. The best way to get device-level permissions is from the Device Registry SDK.

0. Open the [Azure Portal](https://portal.azure.com/)
0. Select or create your Azure IoT Hub resource
0. Click on ‘Settings’
0. Click on ‘Shared Access Policies’
0. Select a policy which has all permissions (such as the *iothubowner*) or create a new policy then click on it
0. Copy the *Connection string--primary key* to the clipboard and paste it into the constructor.

## iothub.Registry Class Usage

### Constructor: iothub.Registry.fromConnectionString(*connectionString*)

This contructs a Registry object which exposes the Device Registry functions.

The *connectionString* parameter is provided by the [Azure Portal](https://portal.azure.com/) *(see above)*.

```squirrel
#require "azureiothub.class.nut:1.2.1"

// Instantiate a client.
const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";
registry <- iothub.Registry.fromConnectionString(CONNECT_STRING);
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
#require "azureiothub.class.nut:1.2.1"

const CONNECT_STRING = "HostName=<HUB_ID>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<KEY_HASH>";

client <- null;
local registry = iothub.Registry.fromConnectionString(CONNECT_STRING);
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
                    ::client <- iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                }
            }.bindenv(this));
        } else {
            server.error(err.message);
        }
    } else {
        server.log("Connected as " + deviceInfo.getBody().deviceId);
        ::client <- iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
    }
}.bindenv(this));

```

## iothub.Client Class Usage

### Constructor: iothub.Client.fromConnectionString(*connectionString*)

This contructs a (HTTP) Client object which exposes the event functions.

The *connectionString* parameter is provided by the [Azure Portal](https://portal.azure.com/) *(see above)*.

```squirrel
#require "azureiothub.class.nut:1.2.1"

// Instantiate a client.
client <- iothub.Client.fromConnectionString(DEVICE_CONNECT_STRING);
```

## iothub.Client Class Methods

### sendEvent(*message[, callback]*)

This method sends a single event (*message*) to the IoT Hub. The event should be an iothub.Message object which can be created from a string or any object that can be converted to JSON. The message object can also hold application properties as defined [here](https://msdn.microsoft.com/en-us/library/mt590784.aspx).

You may also provide a function reference via the *callback* parameter *(see below)*. This function will be called when the IoT Hub responds. If you don’t provide a callback, *sendEvent()* will block until completion.

**Example**

```squirrel
local message1 = iothub.Message("This is an event");
client.sendEvent(message1);

local message2 = iothub.Message({ "id": 1, "text": "Hello, world." });
client.sendEvent(message2);
```

### sendEventBatch(*messages[, callback]*)

Sends an array of events (messages) the Iot Hub. The messages parameter should be an array of iothub.Message objects which can be created from a string or any object that can be converted to JSON. The message objects can also hold application properties as defined [here](https://msdn.microsoft.com/en-us/library/mt590784.aspx).

You may also provide a function reference via the *callback* parameter *(see below)*. This function will be called when the IoT Hub responds. If you don’t provide a callback, *sendEventBatch()* will block until completion.

**Example**

```squirrel
local messages = [];
messages.push(iothub.Message("This is an event"));
messages.push(iothub.Message({ "id": 1, "text": "Hello, world." }));
client.sendEventBatch(messages);
```

### function receive(*callback*)

Long polls the Iot Hub waiting for cloud-to-device events targetted at this device. Whenever an event is received, the event is packaged into a iothub.Message object which is sent to the provided callback. The event must be acknowledged or rejected by executing the `sendFeedback()` function using the message as a parameter.

```squirrel
client.receive(function(err, message) {
    server.log(format("received an event: %s", message.getData()));
    client.sendFeedback(iothub.HTTP.FEEDBACK_ACTION_COMPLETE, message);
})
```

### function sendFeedback(*action, messages, [callback]*)

Sends a message feedback (acknowledgement or rejection) to the Iot Hub. This will prevent the IoT Hub from resending the message.
The action can be FEEDBACK_ACTION_ABANDON, FEEDBACK_ACTION_REJECT or FEEDBACK_ACTION_COMPLETE.

```squirrel
client.receive(function(err, message) {
    server.log(format("received an event: %s", message.getData()));
    client.sendFeedback(iothub.HTTP.FEEDBACK_ACTION_COMPLETE, message);
})
```


### Callbacks

The above callbacks will be called with the following parameters:

| Parameter | Value |
| --- | --- |
| *err* | This will be `null` if there was no error. Otherwise it will be a table containing two keys: *response*, the original **httpresponse** object, and *message*, an error report string |
| *response* | Empty |

### Example

This example code will receive an event table from the device and transmit it as an event to the Azure IoT Hub.

```squirrel
#require "azureiothub.class.nut:1.2.1"

client <- iothub.Client.fromConnectionString(DEVICE_CONNECT_STRING);
agentid <- split(http.agenturl(), "/").pop();

device.on("event", function(event) {
    event.agentid <- agentid;
    local message = iothub.Message(event);
    client.sendEvent(message, function(err, res) {
        if (err) {
             server.log("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
        } else {
            server.log("sendEvent successful");
        }
    });
})
```

## Testing

Repository contains [impUnit](https://github.com/electricimp/impUnit) tests and a configuration for [impTest](https://github.com/electricimp/impTest) tool.

### TL;DR

```bash
npm i

nano .imptest # edit device/model

IMP_BUILD_API_KEY=<build_api_key> \
AZURE_IOTHUB_HUB_NAME=<hub_name> \
AZURE_IOTHUB_SHARED_ACCESS_KEY=<key> \
AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME=<key_name> \
imptest test
```

### Running Tests

Tests can be launched with:

```bash
imptest test
```

By default configuration for the testing is read from [.imptest](https://github.com/electricimp/impTest/blob/develop/docs/imptest-spec.md).

To run test with your settings (for example while you are developing), create your copy of **.imptest** file and name it something like **.imptest.local**, then run tests with:

 ```bash
 imptest test -c .imptest.local
 ```

Tests will run with any imp.

### Prerequisites

#### Commands

Run `npm install` to install:

- Local copy of `iothub-explorer` command line tool

#### Environment Variables

Test cases expect the following environment variables:
- __AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME__ – shared access key name
- __AZURE_IOTHUB_SHARED_ACCESS_KEY__ – shared access key
- __AZURE_IOTHUB_HUB_NAME__ – IoT hub name

## Examples

There are further examples in the [GitHub repository](https://github.com/electricimp/AzureIoTHub/tree/v1.0.0).

## Development

This repository uses [git-flow](http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/).
Please make your pull requests to the __develop__ branch.

# License

This library is licensed under the [MIT License](./LICENSE.txt).
