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
// - automatically registers the device (if not registered yet) via the Device Provisioning Service
//   using the provided Scope ID, Registration ID and Device symmetric key
// - connects the device to Azure IoT Hub using an automatically obtained Device Connection String
// - enables Twin functionality
// - retrieves the Twin's properties (both - Desired and Reported) from the cloud and logs them
// - logs all Desired properties received from the cloud, reads the value of the Desired property "test" and
//   sends it back to the cloud as a Reported property

const PROPERTY_NAME = "test";

class TwinsExample {
    _azureClient = null;
    _azureDPS = null;

    constructor(scopeId, registrationId, deviceKey) {
        _azureDPS = AzureIoTHub.DPS(scopeId, registrationId, deviceKey);
    }

    function start() {
        local registrationCalled = false;
        local onCompleted = null;
        onCompleted = function(err, resp, connStr) {
            if (err == 0) {
                if (registrationCalled) {
                    server.log("Device has been registered!");
                } else {
                    server.log("Device is registered already!");
                }
                _azureClient = AzureIoTHub.Client(connStr, _onConnected.bindenv(this), _onDisconnected.bindenv(this));
                _azureClient.connect();
            } else if (err == AZURE_DPS_ERROR_NOT_REGISTERED && !registrationCalled) {
                server.log("Device is not registered. Starting registration...");
                registrationCalled = true;
                _azureDPS.register(onCompleted);
            } else {
                server.error("Error occured: code = " + err + " response = " + http.jsonencode(resp));
            }
        }.bindenv(this);
        _azureDPS.getConnectionString(onCompleted);
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
            } else {
                _azureClient.retrieveTwinProperties(_onRetrieved.bindenv(this));
            }
        }.bindenv(this));
    }

    function _onDisconnected(err) {
        server.log("Disconnected!");
        server.log("Reconnecting...");
        _azureClient.connect();
    }

    function _onRetrieved(err, reportedProps, desiredProps) {
        if (err != 0) {
            server.error("AzureIoTHub retrieveTwinProperties failed: " + err);
            return;
        }
        server.log("Twin properties retrieved:");
        server.log("reported props:");
        _printTable(reportedProps);
        server.log("desired props:");
        _printTable(desiredProps);
    }

    function _onRequest(props) {
        server.log("Desired props received:");
        server.log("props:");
        _printTable(props);
        if (PROPERTY_NAME in props) {
            server.log("Updating reported properties...")
            local propUpd = {};
            propUpd[PROPERTY_NAME] <- props[PROPERTY_NAME];

            _azureClient.updateTwinProperties(propUpd, _onUpdated.bindenv(this));
        } else {
            server.log(format("No property \"%s\" in desired properties", PROPERTY_NAME));
        }
    }

    function _onUpdated(err, props) {
        if (err != 0) {
            server.error("AzureIoTHub updateTwinProperties failed: " + err);
            // Try to update again if the operation is timed out
            // Timeout error is just an example. Of course, you should analyze all the error codes
            // required for your application and take appropriate actions
            if (err == AZURE_IOT_CLIENT_ERROR_OP_TIMED_OUT) {
                server.error("Trying to update the properties again...");
                _azureClient.updateTwinProperties(props, _onUpdated.bindenv(this));
            }
        } else {
            server.log("Reported properties successfully updated");
        }
    }

    function _printTable(tbl) {
        foreach (k, v in tbl) {
            server.log(k + " : " + v);
        }
    }
}

// RUNTIME
// ---------------------------------------------------------------------------------

// AzureIoTHub constants
// ---------------------------------------------------------------------------------
const AZURE_DPS_SCOPE_ID = "<YOUR_AZURE_DPS_SCOPE_ID>";
const AZURE_DPS_REGISTRATION_ID = "<YOUR_AZURE_DPS_REGISTRATION_ID>";
const AZURE_DPS_DEVICE_KEY = "<YOUR_AZURE_DPS_DEVICE_KEY>";

// Start application
twinsExample <- TwinsExample(AZURE_DPS_SCOPE_ID, AZURE_DPS_REGISTRATION_ID, AZURE_DPS_DEVICE_KEY);
twinsExample.start();
