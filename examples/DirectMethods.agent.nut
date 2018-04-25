// MIT License
//
// Copyright 2018 Electric Imp
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

#require "AzureIoTHub.agent.lib.nut:3.0.0"

// AzureIoTHub library example.
// - automatically registers the device (if not registered yet) using the provided Registry Connection String
// - connects using an automatically obtained Device Connection String
// - enables Direct Methods functionality
// - logs all comming Direct Method calls, always responds success

class DirectMethodsExample {
    _azureClient = null;

    _connectionString = null;
    _deviceConnString = null;

    constructor(connectionString) {
        _connectionString = connectionString;
    }

    function start() {
        registerDevice(function (err) {
            if (err == null) {
                _azureClient = AzureIoTHub.Client(_deviceConnString,
                    _onConnected.bindenv(this), _onDisconnected.bindenv(this));
                _azureClient.connect();
            }
        }.bindenv(this));
    }

    function registerDevice(onCompleted) {
        local deviceID = imp.configparams.deviceid;
        local hostName = AzureIoTHub.ConnectionString.Parse(_connectionString).HostName;
        local registry = AzureIoTHub.Registry(_connectionString);
        // Find this device in the registry
        registry.get(deviceID, function(err, iotHubDev) {
            if (err) {
                if (err.response.statuscode == 404) {
                    // No such device, let's create it, connect & open receiver
                    registry.create({"deviceId" : deviceID}, function(error, iotHubDevice) {
                        if (error) {
                            server.error(error.message);
                            onCompleted(error);
                        } else {
                            _deviceConnString = iotHubDevice.connectionString(hostName);
                            server.log("Device created: " + iotHubDevice.getBody().deviceId);
                            onCompleted(null);
                        }
                    }.bindenv(this));
                } else {
                    server.error(err.message);
                    onCompleted(err);
                }
            } else {
                _deviceConnString = iotHubDev.connectionString(hostName);
                // Found device, let's connect & open receiver
                server.log("Device already registered as " + iotHubDev.getBody().deviceId);
                onCompleted(null);
            }
        }.bindenv(this));
    }

    function _onConnected(err) {
        if (err != 0) {
            server.error("AzureIoTHub connect failed: " + err);
            return;
        }
        server.log("Connected!");
        _azureClient.enableDirectMethods(_onMethod.bindenv(this), function (err) {
            if (err != 0) {
                server.error("AzureIoTHub enableDirectMethods failed: " + err);
            }
        });
    }

    function _onDisconnected(err) {
        server.log("Disconnected!");
        server.log("Reconnecting...");
        _azureClient.connect();
    }

    function _onMethod(name, params) {
        server.log("Direct method called:");
        server.log("name: " + name);
        if (params != null) {
            server.log("params:");
            _printTable(params);
        }
        local resp = AzureIoTHub.DirectMethodResponse(200, {"status": "done"});
        return resp;
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
const AZURE_REGISTRY_CONN_STRING = "<YOUR_AZURE_REGISTRY_CONN_STRING>";

// Start application
directMethodsExample <- DirectMethodsExample(AZURE_REGISTRY_CONN_STRING);
directMethodsExample.start();
