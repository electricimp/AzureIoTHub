// MIT License
//
// Copyright 2015-2017 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#require "AzureIoTHub.agent.lib.nut:2.1.0"

class Application {

    static TEMP_ALERT = 30;

    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;

    connectionString = null;
    client = null;
    registry = null;
    hostName = null;
    agentID = null;
    deviceID = null;
    connected = false;

    constructor(connectionString, deviceConnectionString = null) {
        agentID = split(http.agenturl(), "/").pop();
        deviceID = imp.configparams.deviceid;

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
        if ("temperature" in event && event.temperature > TEMP_ALERT) properties.temperatureAlert = true;

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
        registry.get(deviceID, function(err, iotHubDev) {
            if (err) {
                if (err.response.statuscode == 404) {
                    // No such device, let's create it, connect & open receiver
                    registry.create({"deviceId" : deviceID}, function(error, iotHubDevice) {
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
        if (typeof message.getBody() == "blob") {
            server.log("Received message: " + message.getBody().tostring());
            device.send("blink", GREEN);
            server.log(http.jsonencode(message.getProperties()));
            delivery.complete();
        } else {
            delivery.reject();
        }
    }

    // Formats the date object as a UTC string
    function formatDate() {
        local d = date();
        return format("%04d-%02d-%02d %02d:%02d:%02d", d.year, (d.month+1), d.day, d.hour, d.min, d.sec);
    }
}

////////// Application Variables //////////

const IOTHUB_CONNECTION_STRING = "HostName=<YOUR-HOST-NAME>.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=<YOUR-KEY-HASH>";

// Start the Application
Application(IOTHUB_CONNECTION_STRING);
