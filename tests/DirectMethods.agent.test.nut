const AZURE_DEVICE_CONN_STRING = "@{AZURE_DEVICE_CONN_STRING}";

class DirectMethodsTestCase extends ImpTestCase {
    _azureMqttClient = null;

    function setUp() {
        return _connect();
    }

    function tearDown() {
        _azureMqttClient.disconnect();
    }

    function testEnableDisableMethods() {
        return _enableMethods()
            .then(function (value) {
                return _disableMethods();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testEnableDisableDisableMethods() {
        return _enableMethods()
            .then(function (value) {
                return _disableMethods();
            }.bindenv(this))
            .then(function (reason) {
                return _disableMethods();
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

    function testEnableEnableDisableMethods() {
        return _enableMethods()
            .then(function (value) {
                return _enableMethods();
            }.bindenv(this))
            .then(function (value) {
                return Promise.reject("Should have returned EALREADYENABLED error");
            }.bindenv(this), function (reason) {
                if (reason != AzureIoTHub.Client.EALREADYENABLED) {
                    return Promise.reject("Should have returned EALREADYENABLED error");
                }
                return _disableMethods();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testDisableMethods() {
        return _disableMethods()
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

    function _enableMethods() {
        local onMeth = function (name, params) {};
        return Promise(function (resolve, reject) {
            _azureMqttClient.enableDirectMethods(onMeth, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _disableMethods() {
        return Promise(function (resolve, reject) {
            _azureMqttClient.enableDirectMethods(null, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }
}
