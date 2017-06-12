#require "AzureIoTHub.agent.lib.nut:2.0.0"

class Application {

    static TEMP_ALERT = 30;
    static YELLOW = [50, 45, 0];
    static GREEN = [0, 50, 0];

    connectionString = null;
    client = null;
    registry = null;
    hostName = null;
    agentID = null;
    connected = false;

    constructor(connectionString, deviceConnectionString = null) {
        agentID = split(http.agenturl(), "/").pop();

        if (deviceConnectionString) {
            // We have registered device using IoTHub Dashboard
            createClient(deviceConnectionString);
        } else {
            connectionString = connectionString;
            hostName = AzureIoTHub.ConnectionString.Parse(connectionString).HostName;
            registry = AzureIoTHub.Registry(connectionString);
            registerDevice();
        }

        device.on("event", eventHandler.bindenv(this));
    }

    function eventHandler(event) {
        local properties = {"temperatureAlert" : false};
        if ("temperature" in event && event.temperature > 30) properties.temperatureAlert = true;

        event.agentid <- agentID;
        event.time <- formatDate();
        
        local message = AzureIoTHub.Message(event, properties);

        // make sure device is connected, then send event
        if (connected) {
            server.log("Sending message: " + http.jsonencode(message.getBody()));
            client.sendEvent(message, function(err) {
                if (err) {
                     server.error("Failed to send message to Azure IoT Hub: " + err);
                } else {
                    device.send("blink", YELLOW);
                    server.log("Message sent to Azure IoT Hub");
                }
            }.bindenv(this));
        }
    }

    function registerDevice() {
        // Find this device in the registry
        registry.get(agentID, function(err, iotHubDev) {
            if (err) {
                if (err.response.statuscode == 404) {
                    // No such device, let's create it, connect & open receiver
                    registry.create(function(error, iotHubDevice) {
                        if (error) {
                            server.error(error.message);
                        } else {
                            server.log("Dev created " + iotHubDevice.getBody().deviceId);
                            createClient(iotHubDevice.connectionString(hostName));
                        }
                    }.bindenv(this));
                } else {
                    server.error(err.message);
                }
            } else {
                // Found device, let's connect & open receiver
                server.log("Device registered as " + iotHubDev.getBody().deviceId);
                createClient(iotHubDev.connectionString(hostName));
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
            server.log("Received message: " + message.getBody());
            device.send("blink", GREEN);
            // server.log(http.jsonencode(message.getProperties()));
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

// Start the Application
Application(IOTHUB_CONNECTION_STRING);