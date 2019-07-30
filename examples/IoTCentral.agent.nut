// MIT License
//
// Copyright 2018-19 Electric Imp
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
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

#require "AzureIoTHub.agent.lib.nut:5.1.0"

// AzureIoTHub library example.
// - computes the Device Symmetric Key using the provided Group Key
// - automatically registers the device (if not registered yet) in IoT Central via the Device Provisioning Service
//   using the provided Scope ID, Registration ID and computed Device Symmetric Key
// - connects the device to Azure IoT Hub using an automatically obtained Device Connection String
// - enables Twin functionality
// - receives Settings updates from IoT Central (it is just an update of Desired properties)
// - confirms Settings updates by updating Reported properties
// - sends the value of a property "test" (from received Settings/Desired properties) as a telemetry data
//   by sending a device-to-cloud message

const PROPERTY_NAME = "test";

class IoTCentralExample {
    _azureClient = null;
    _azureDPS = null;

    constructor(scopeId, registrationId, groupKey) {
        local deviceKey = _computeDeviceKey(groupKey, registrationId);
        _azureDPS = AzureIoTHub.DPS(scopeId, registrationId, deviceKey);
    }

    function start() {
        local registrationStarted = false;
        local onDone = null;
        onDone = function(err, resp, connStr) {
            if (err == 0) {
                if (registrationStarted) {
                    server.log("Device has been registered!");
                } else {
                    server.log("Device is registered already!");
                }
                _azureClient = AzureIoTHub.Client(connStr, _onConnected.bindenv(this), _onDisconnected.bindenv(this));
                _azureClient.connect();
            } else if (err == AZURE_DPS_ERROR_NOT_REGISTERED && !registrationStarted) {
                server.log("Device is not registered. Starting registration...");
                registrationStarted = true;
                _azureDPS.register(onDone);
            } else {
                server.error("Error occured: code = " + err + " response = " + http.jsonencode(resp));
            }
        }.bindenv(this);
        _azureDPS.getConnectionString(onDone);
    }

    function _computeDeviceKey(groupKey, regId) {
        return http.base64encode(crypto.hmacsha256(regId, http.base64decode(groupKey)));
    }

    function _onConnected(err) {
        if (err != 0) {
            server.error("AzureIoTHub connect failed: " + err);
            return;
        }
        server.log("Connected!");
        _azureClient.enableTwin(_onRequest.bindenv(this), function (err) {
            if (err != 0) {
                server.error("AzureIoTHub enableTwin failed: " + err);
            }
        }.bindenv(this));
    }

    function _onDisconnected(err) {
        server.log("Disconnected!");
        server.log("Reconnecting...");
        _azureClient.connect();
    }

    function _sendTelemetry(value) {
        local msgBody = {
            [PROPERTY_NAME] = value
        };
        local message = AzureIoTHub.Message(http.jsonencode(msgBody));
        _azureClient.sendMessage(message, _onMessageSent.bindenv(this));
    }

    function _onMessageSent(err, msg) {
        if (err != 0) {
            server.error("AzureIoTHub sendMessage failed: " + err);
        } else {
            server.log("Telemetry successfully sent: " + msg.getBody());
        }
    }

    function _onRequest(props) {
        server.log("Settings update (desired properties) received:");
        server.log("props:");
        _printTable(props);
        if (PROPERTY_NAME in props && "value" in props[PROPERTY_NAME]) {
            server.log("Confirming the update (updating reported properties)...")
            local propUpd = {};
            propUpd[PROPERTY_NAME] <- {
                "value" : props[PROPERTY_NAME]["value"],
                "statusCode" : "200",
                "status" : "completed",
                "desiredVersion" : props["$version"]
            };

            // Sending the new value as telemetry
            _sendTelemetry(props[PROPERTY_NAME]["value"]);

            // Confirming the new value as a setting
            _azureClient.updateTwinProperties(propUpd, _onUpdated.bindenv(this));
        } else {
            server.log(format("No property \"%s\" in desired properties", PROPERTY_NAME));
        }
    }

    function _onUpdated(err, props) {
        if (err != 0) {
            server.error("AzureIoTHub updateTwinProperties failed: " + err);
        } else {
            server.log("The settings update was confirmed");
        }
    }

    function _printTable(tbl) {
        foreach (k, v in tbl) {
            server.log(k + " : " + http.jsonencode(v));
        }
    }
}

// RUNTIME
// ---------------------------------------------------------------------------------

// AzureIoTHub constants
// ---------------------------------------------------------------------------------
const AZURE_IOT_CENTRAL_SCOPE_ID = "<YOUR_AZURE_IOT_CENTRAL_SCOPE_ID>";
const AZURE_IOT_CENTRAL_DEVICE_ID = "<YOUR_AZURE_IOT_CENTRAL_DEVICE_ID>";
const AZURE_IOT_CENTRAL_GROUP_KEY = "<YOUR_AZURE_IOT_CENTRAL_GROUP_KEY>";

// Start application
iotCentralExample <- IoTCentralExample(AZURE_IOT_CENTRAL_SCOPE_ID, AZURE_IOT_CENTRAL_DEVICE_ID, AZURE_IOT_CENTRAL_GROUP_KEY);
iotCentralExample.start();
