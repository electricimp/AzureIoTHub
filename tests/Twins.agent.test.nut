const AZURE_DEVICE_CONN_STRING = "@{AZURE_DEVICE_CONN_STRING}";

class MessagesTestCase extends ImpTestCase {
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
                return Promise.reject("Should have returned ENOTENABLED error");
            }.bindenv(this), function (reason) {
                if (reason != AzureIoTHub.Client.ENOTENABLED) {
                    return Promise.reject("Should have returned ENOTENABLED error");
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
                return Promise.reject("Should have returned EALREADYENABLED error");
            }.bindenv(this), function (reason) {
                if (reason != AzureIoTHub.Client.EALREADYENABLED) {
                    return Promise.reject("Should have returned EALREADYENABLED error");
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
                return Promise.reject("Should have returned ENOTENABLED error");
            }.bindenv(this),
                function (reason) {
                if (reason != AzureIoTHub.Client.ENOTENABLED) {
                    return Promise.reject("Should have returned ENOTENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    function testUpdateTwin() {
        return _updateTwin()
            .then(function (value) {
                return Promise.reject("Should have returned ENOTENABLED error");
            }.bindenv(this),
                function (reason) {
                if (reason != AzureIoTHub.Client.ENOTENABLED) {
                    return Promise.reject("Should have returned ENOTENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }        

    function testDisableTwin() {
        return _disableTwin()
            .then(function (value) {
                return Promise.reject("Should have returned ENOTENABLED error");
            }.bindenv(this),
                function (reason) {
                if (reason != AzureIoTHub.Client.ENOTENABLED) {
                    return Promise.reject("Should have returned ENOTENABLED error");
                }
                return Promise.resolve(0);
            }.bindenv(this));
    }

    // function testRetrieveTwin() {
    //  return _retrieveTwin();
    // }

    // function testUpdateTwin() {
    //  return _updateTwin();
    // }

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
        local onReq = function (version, props) {};
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
            _azureMqttClient.updateTwinProperties(props, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }
}
