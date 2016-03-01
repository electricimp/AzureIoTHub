# Azure IoT Hub Client 1.0.0 

The Azure IoT Hub client is an Electric Imp agent-side library for interfacing to the Azure IoT Hub version “2015-08-15-preview”. It currently only supports the device registry (create, update, delete, get, list) and sending device-to-cloud events. Receiving events is currently not functioning.

This class is ported from and designed to be as close as possible to the [NodeJS SDK](https://github.com/Azure/azure-iot-sdks/blob/master/node/). Refer to the [NodeJS SDK](https://github.com/Azure/azure-iot-sdks/blob/master/node/) for further information.

**To add this library to your project, add** `#require "iothub.agent.nut:1.0.0"` **to the top of your agent code.**

## iothub.Registry Class Usage

### Constructor: iothub.Registry.fromConnectionString(*ConnectionString*)

This contructs a Registry object which exposes the Device Registry functions.

The *ConnectionString* parameter is provided in the Azure Portal. 

```squirrel
#require "iothub.agent.nut:1.0.0"

// Instantiate a client.
const CONNECT_STRING = "HostName=<hubid>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<keyhash>";
registry <- iothub.Registry.fromConnectionString(CONNECT_STRING);
```

### function create(*[deviceInfo], [callback]*)

Creates a new device identity in the Iot Hub. The optional *deviceInfo* field is an iothub.Device object or table containing the keys specified [here](https://msdn.microsoft.com/en-us/library/mt548493.aspx). If it is not provided then the agentId will be used as the deviceId.

### function update(*deviceInfo, [callback]*)

Updates an existing device identity in the Iot Hub. The *deviceInfo* field is an iothub.Device object or table containing the keys specified [here](https://msdn.microsoft.com/en-us/library/mt548488.aspx). The deviceId and statusReason cannot be updated via this method.

### function remove(*[deviceId], callback*)

Deletes a single device identity from the IoT Hub. The *deviceId* string field is optional and will be set to the agentId if not provided.

### function get(*[deviceId], callback*)

Returns the properties of an existing device identity in the Iot Hub. The *deviceId* string field is optional and will be set to the agentId if not provided.

### function list(*callback*)

Returns the properties of all existing device identities in the Iot Hub.

### Callbacks

The callbacks will be called with the following parameters:

|   Field     |  Value                                                                                              |
|-------------|-----------------------------------------------------------------------------------------------------|
|   err       |  If there we no error: null                                                                         |
|             |  If there was an error: a table containing the http *response* object and an error *message* string |
|   response  |  For *create*, *update* and *get*: a [iothub.Device](https://msdn.microsoft.com/en-us/library/mt548491.aspx) object                                           |
|             |  For *list*: an array of [iothub.Device](https://msdn.microsoft.com/en-us/library/mt548491.aspx) objects                                                      |
|             |  For *remote*: nothing                                                                              |


### Example

This example code will register the device (using the agent id, which could be replaced with the imp deviceId) or create a new one then will instantiate the Client class for later use.

```squirrel
#require "iothub.agent.nut:1.0.0"

client <- null;
local registry = iothub.Registry.fromConnectionString(CONNECT_STRING);
local hostname = iothub.ConnectionString.Parse(CONNECT_STRING).HostName;

// Find this device in the registry
registry.get(function(err, deviceInfo) {

    if (err) {

        if (err.response.statuscode == 404) {
            
            // No such device, lets create it
            registry.create(function(err, deviceInfo) {
                
                if (err) {  
                    console.error(err.message);
                } else {
                    server.log("Created " + deviceInfo.getBody().deviceId);
                    ::client <- iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                }

            }.bindenv(this));

        } else {
            
            console.error(err.message);
            
        }

    } else {

        server.log("Connected as " + deviceInfo.getBody().deviceId);
        ::client <- iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
        
    }

}.bindenv(this));

```

## iothub.Client Class Usage

### Constructor: iothub.Client.fromConnectionString(*ConnectionString*)

This contructs a (HTTP) Client object which exposes the event functions.

The *ConnectionString* parameter is provided in the Azure Portal. 

```squirrel
#require "iothub.agent.nut:1.0.0"

// Instantiate a client.
client <- iothub.Client.fromConnectionString(DEVICE_CONNECT_STRING);
```

### function sendEvent(*message, [callback]*)

Sends a single event (message) the Iot Hub. The message should be a iothub.Message object which can be created from a string or any object that can be converted to JSON. The message object can also hold *properties* as defined [here](https://msdn.microsoft.com/en-us/library/mt590784.aspx).

```squirrel
local message1 = iothub.Message("this is an event");
client.sendEvent(message1);

local message2 = iothub.Message({ "id": 1, "text": "Hello, world." });
client.sendEvent(message2);
```

### function sendEventBatch(*messages, [callback]*)

Sends an array of events (messages) the Iot Hub. The messages parameter should be an array of iothub.Message objects which can be created from a string or any object that can be converted to JSON. The message objects can also hold *properties* as defined [here](https://msdn.microsoft.com/en-us/library/mt590784.aspx).

```squirrel
local messages = [];
messages.push( iothub.Message("this is an event") );
messages.push( iothub.Message({ "id": 1, "text": "Hello, world." }) );
client.sendEventBatch(messages);
```

### Callbacks

The callbacks will be called with the following parameters:

|   Field     |  Value                                                                                              |
|-------------|-----------------------------------------------------------------------------------------------------|
|   err       |  If there we no error: null                                                                         |
|             |  If there was an error: a table containing the http *response* object and an error *message* string |
|   response  |  Empty                                                                                              |


### Example

This example code will receive an event table from the device and transmit it as an event to Azure IoT Hub.

```squirrel
#require "iothub.agent.nut:1.0.0"

client <- iothub.Client.fromConnectionString(DEVICE_CONNECT_STRING);
agentid <- split(http.agenturl(), "/").pop();

device.on("event", function(event) {
    event.agentid <- agentid;
    local message = iothub.Message(event);
    client.sendEvent(message, function(err, res) {
        if (err) server.log("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
        else server.log("sendEvent successful");
    });
})
```

## Authentication

The Azure Portal provides the Connection String. To use the Device Registry you will require owner-level permissions. To use the Client you need device-level permissions. The best way to get device-level permissions is from the Device Registry SDK.

0. Open the Azure Portal (https://portal.azure.com)
0. Select or create your Azure IoT Hub resource
0. Click on Settings 
0. Click on shared access policies
0. Select a policy which has all permissions (such as the *iothubowner*) or create a new policy then click on it
0. Copy the *Connection string--primary key* to the clipboard and paste it in the agent code for this constructor.

## Examples

There are further examples in the [GitHub repository](https://github.com/electricimp/AzureIoTHub/tree/v1.0.0).

# License

This library is licensed under the [MIT License](./LICENSE.txt).
