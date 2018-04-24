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

class DirectMethodsExample {
    _azureClient = null;

    constructor(deviceConnStr) {
        _azureClient = AzureIoTHub.Client(deviceConnStr, 
            _onConnected.bindenv(this), _onDisconnected.bindenv(this));
    }

    function start() {
        _azureClient.connect();
    }

    // -------------------- PRIVATE METHODS -------------------- //

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
const AZURE_DEVICE_CONN_STRING = "<YOUR_AZURE_DEVICE_CONN_STRING>";

// Start application
directMethodsExample <- DirectMethodsExample(AZURE_DEVICE_CONN_STRING);
directMethodsExample.start();
