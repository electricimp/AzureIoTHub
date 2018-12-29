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

const AZURE_DEVICE_CONN_STRING = "@{AZURE_DEVICE_CONN_STRING}";

class TokenAutoRefreshTestCase extends ImpTestCase {
    _azureMqttClient = null;

    function testSimple() {
        // Right after connection establishing the lib should start token refreshing
        // and here our request gets to the queue of pending requests.
        // Once refreshing ends the lib starts to process our request and wants to refresh token again.
        // As the request is async the token refreshing should be suspended till the end of the request processing.
        // Then the request is completed and token refreshing is started again. Now we want to disconnect.
        // The lib should finish token refreshing and after that run our disconnection request.
        return _connect()
            .then(function (value) {
                return _enableTwin();
            }.bindenv(this))
            .then(function (value) {
                return _disconnect();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testAdvanced() {
        return _connect()
            .then(function (value) {
                return _enableTwin();
            }.bindenv(this))
            .then(function (value) {
                return _retrieveUpdateTwin();
            }.bindenv(this))
            .then(function (value) {
                return _disableTwin();
            }.bindenv(this))
            .then(function (value) {
                return _disconnect();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function _connect() {
        return Promise(function (resolve, reject) {
            // We want to refresh token as frequently as possible
            local options = {"tokenTTL" : 0};
            _azureMqttClient = AzureIoTHub.Client(AZURE_DEVICE_CONN_STRING, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
                }.bindenv(this), null, options);
            _azureMqttClient.connect();
        }.bindenv(this));
    }

    function _disconnect() {
        return Promise(function (resolve, reject) {
            local onDisc = function(error) {
                _azureMqttClient._onDisconnectedCb = null;
                if (error != 0) {
                    return reject(error);
                }
                return resolve();
            }.bindenv(this);
            _azureMqttClient._onDisconnectedCb = onDisc;
            _azureMqttClient.disconnect();
        }.bindenv(this));
    }

    function _enableTwin() {
        local onReq = function (props) {};
        return Promise(function (resolve, reject) {
            _azureMqttClient.enableTwin(onReq, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _disableTwin() {
        return Promise(function (resolve, reject) {
            _azureMqttClient.enableTwin(null, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _retrieveUpdateTwin() {
        local props = {"testProp" : "testVal"};
        local done = 0;
        return Promise(function (resolve, reject) {
            _azureMqttClient.retrieveTwinProperties(function (err, repProps, desProps) {
                if (err != 0) {
                    return reject(err);
                }
                done++;
                if (done == 2) {
                    return resolve();
                }
            }.bindenv(this));
            _azureMqttClient.updateTwinProperties(props, function (err, props) {
                if (err != 0) {
                    return reject(err);
                }
                done++;
                if (done == 2) {
                    return resolve();
                }
            }.bindenv(this));
        }.bindenv(this));
    }
}