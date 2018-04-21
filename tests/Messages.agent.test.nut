const AZURE_DEVICE_CONN_STRING = "@{AZURE_DEVICE_CONN_STRING}";

class MessagesTestCase extends ImpTestCase {
    _azureMqttClient = null;

    function setUp() {
        return _connect();
    }

    function tearDown() {
        _azureMqttClient.disconnect();
    }

    function testEnableDisableMessages() {
        return _enableMessageReceiving()
            .then(function (value) {
                return _disableMessageReceiving();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testEnableSendDisableMessages() {
        return _enableMessageReceiving()
            .then(function (value) {
                return _sendMessage();
            }.bindenv(this))
            .then(function (value) {
                return _disableMessageReceiving();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testEnableDisableDisableMessages() {
        return _enableMessageReceiving()
            .then(function (value) {
                return _disableMessageReceiving();
            }.bindenv(this))
            .then(function (reason) {
                return _disableMessageReceiving();
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

    function testEnableEnableDisableMessages() {
        return _enableMessageReceiving()
            .then(function (value) {
                return _enableMessageReceiving();
            }.bindenv(this))
            .then(function (value) {
                return Promise.reject("Should have returned EALREADYENABLED error");
            }.bindenv(this), function (reason) {
                if (reason != AzureIoTHub.Client.EALREADYENABLED) {
                    return Promise.reject("Should have returned EALREADYENABLED error");
                }
                return _disableMessageReceiving();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function testSendMessage() {
        return _sendMessage();
    }

    function testDisableMessages() {
        return _disableMessageReceiving()
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

    function _sendMessage() {
        local msg = AzureIoTHub.Message("test message", {"prop1" : "val1"});
        return Promise(function (resolve, reject) {
            _azureMqttClient.sendMessage(msg, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _enableMessageReceiving() {
        local onMsg = function (msg) {};
        return Promise(function (resolve, reject) {
            _azureMqttClient.enableMessageReceiving(onMsg, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _disableMessageReceiving() {
        return Promise(function (resolve, reject) {
            _azureMqttClient.enableMessageReceiving(null, function (err) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }
}
