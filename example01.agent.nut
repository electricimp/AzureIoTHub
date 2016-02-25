// *****************************************************************************
const CONNECT_STRING = "HostName=<hubid>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<keyhash>";

// This bootstraps the IoT Hub class by getting the deviceInfo or registering a new device.
// If successful it will return a IoTHub client object.
function bootstrap(done) {
    
    local registry = iothub.Registry.fromConnectionString(CONNECT_STRING);
    local hostname = iothub.ConnectionString.Parse(CONNECT_STRING).HostName;

    // Find this device
    registry.get(function(err, deviceInfo) {
    
        if (err) {
            if (err.response.statuscode == 404) {
                
                // No such device, lets create it
                registry.create(function(err, deviceInfo) {
                    
                    if (err && err.response.statuscode == 429) {
                        
                        // Retry in a few seconds
                        imp.wakeup(10, function() {
                            bootstrap(done);
                        }.bindenv(this))
                        
                    } else if (err) {
                        
                        server.log("createDevice error: " + err.message + " (" + err.response.statuscode + ")");
                        done(null);
                        
                    } else if (deviceInfo) {
                        
                        server.log("Created " + deviceInfo.getBody().deviceId + " on " + hostname);
                        local client = iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                        done(client);
                        
                    } else {
                        
                        server.log("createDevice error unknown")
                        done(null);
                        
                    }
                    
                });

            } else if (err.response.statuscode == 429) {
                
                // Retry in a few seconds
                imp.wakeup(10, function() {
                    bootstrap(done);
                }.bindenv(this))
            
            } else {
                
                server.log("getDevice error: " + err.message + " (" + err.response.statuscode + ")");
                done(null);
                
            }
            
            
        } else if (deviceInfo) {

            server.log("Connected as " + deviceInfo.getBody().deviceId + " to " + hostname);
            local client = iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
            done(client);
            
        } else {
            
            server.error("getDevice error unknown")
            done(null);
            
        }

    });
}

// Formats the date object as a UTC string
function formatDate(){
    local d = date();
    return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
}


// Bootstrap the class and wait for the device to send events
bootstrap(function(client) {

    if (!client) return server.error("Boostrap failed!");
    
    device.on("event", function(event) {

        event.timestamp <- formatDate();
        local message = iothub.Message(event);
        client.sendEvent(message, function(err, res) {
            if (err) server.log("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
            else server.log("sendEvent successful");
        });

    })

}.bindenv(this));