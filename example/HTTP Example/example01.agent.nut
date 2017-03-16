#require "azureiothub.class.nut:2.0.0"

////////// Application Variables //////////

const CONNECT_STRING = "HostName=eiproduction.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=mw/YhxSH3ZeeCqWEnRJAhst6UDah5zvRwMa1Um8WGrU=";

client <- null;
registry <- iothub.Registry(CONNECT_STRING);
hostName <- iothub.ConnectionString.Parse(CONNECT_STRING).HostName;
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
    client = iothub.Client(devConnectionString);
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
    event.time <- formatDate();
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