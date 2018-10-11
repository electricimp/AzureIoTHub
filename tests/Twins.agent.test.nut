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

class TwinsTestCase extends ImpTestCase {
    _azureMqttClient = null;

    function setUp() {
        return _connect();
    }

    function tearDown() {
        _azureMqttClient.disconnect();
    }

    function testEnableDisableTwin() {
        return _enableTwin()
            .then(function (value) {
                return _disableTwin();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testEnableRetrieveDisableTwin() {
        return _enableTwin()
            .then(function (value) {
                return _retrieveTwin();
            }.bindenv(this))
            .then(function (value) {
                return _disableTwin();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testEnableUpdateDisableTwin() {
        return _enableTwin()
            .then(function (value) {
                return _updateTwin();
            }.bindenv(this))
            .then(function (value) {
                return _disableTwin();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testEnableDisableDisableTwin() {
        return _enableTwin()
            .then(function (value) {
                return _disableTwin();
            }.bindenv(this))
            .then(function (reason) {
                return _disableTwin();
            }.bindenv(this))
            .then(function (value) {
                return Promise.reject("Should have returned NOT_ENABLED error");
            }.bindenv(this), function (reason) {
                if (reason != AZURE_IOT_CLIENT_ERROR_NOT_ENABLED) {
                    return Promise.reject("Should have returned NOT_ENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    function testEnableEnableDisableTwin() {
        return _enableTwin()
            .then(function (value) {
                return _enableTwin();
            }.bindenv(this))
            .then(function (value) {
                return Promise.reject("Should have returned ALREADY_ENABLED error");
            }.bindenv(this), function (reason) {
                if (reason != AZURE_IOT_CLIENT_ERROR_ALREADY_ENABLED) {
                    return Promise.reject("Should have returned ALREADY_ENABLED error");
                }
                return _disableTwin();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testRetrieveTwin() {
        return _retrieveTwin()
            .then(function (value) {
                return Promise.reject("Should have returned NOT_ENABLED error");
            }.bindenv(this),
                function (reason) {
                if (reason != AZURE_IOT_CLIENT_ERROR_NOT_ENABLED) {
                    return Promise.reject("Should have returned NOT_ENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    function testUpdateTwin() {
        return _updateTwin()
            .then(function (value) {
                return Promise.reject("Should have returned NOT_ENABLED error");
            }.bindenv(this),
                function (reason) {
                if (reason != AZURE_IOT_CLIENT_ERROR_NOT_ENABLED) {
                    return Promise.reject("Should have returned NOT_ENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }        

    function testDisableTwin() {
        return _disableTwin()
            .then(function (value) {
                return Promise.reject("Should have returned NOT_ENABLED error");
            }.bindenv(this),
                function (reason) {
                if (reason != AZURE_IOT_CLIENT_ERROR_NOT_ENABLED) {
                    return Promise.reject("Should have returned NOT_ENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    function _connect() {
        return Promise(function (resolve, reject) {
            _azureMqttClient = AzureIoTHub.Client(AZURE_DEVICE_CONN_STRING, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
                }.bindenv(this));
            _azureMqttClient.connect();
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

    function _retrieveTwin() {
        return Promise(function (resolve, reject) {
            _azureMqttClient.retrieveTwinProperties(function (err, repProps, desProps) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _updateTwin() {
        local props = {"testProp" : "testVal"};
        return Promise(function (resolve, reject) {
            _azureMqttClient.updateTwinProperties(props, function (props, err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }
}