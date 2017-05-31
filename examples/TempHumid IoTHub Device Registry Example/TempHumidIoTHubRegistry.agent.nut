#require "AzureIoTHub.agent.lib.nut:2.0.0"

class Application {

    connectionString = null;
    client = null;
    registry = null;
    hostName = null;
    agentID = null;
    connected = false;

    constructor(connectionString, deviceConnectionString = null) {
        this.connectionString = connectionString;
        hostName = AzureIoTHub.ConnectionString.Parse(connectionString).HostName;
        agentID = split(http.agenturl(), "/").pop();

        if (deviceConnectionString) {
            // We have registered device using IoTHub Dashboard
            createClient(deviceConnectionString);
        } else {
            registry = AzureIoTHub.Registry(connectionString);
            registerDevice();
        }

        device.on("event", eventHandler.bindenv(this));
    }

    function eventHandler(event) {
        event.agentid <- agentID;
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
    }

    function registerDevice() {
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
        }.bindenv(this));
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
                client.receive(receiveHandler.bindenv(this));
            }
        }.bindenv(this));
    }

    // Create a receive handler
    function receiveHandler(err, delivery) {
        if (err) {
            server.error(err);
            return;
        }

        local message = delivery.getMessage();

        // send feedback
        if (typeof message.getBody() == "string") {
            server.log(message.getBody());
            server.log(http.jsonencode(message.getProperties()));
            delivery.complete();
        } else {
            delivery.reject();
        }
    }

    // Formats the date object as a UTC string
    function formatDate(){
        local d = date();
        return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
    }
}

////////// Application Variables //////////

const IOTHUB_CONNECTION_STRING = "HostName=<YOUR-HOST-NAME>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<YOUR-KEY-HASH>";
const DEVICE_CONNECTION_STRING = "HostName=<YOUR-HOST-NAME>.azure-devices.net;DeviceId=<YOUR-DEEVICE-ID>;SharedAccessKey=<YOUR-KEY-HASH>";

// Start the Application
Application(IOTHUB_CONNECTION_STRING, DEVICE_CONNECTION_STRING);