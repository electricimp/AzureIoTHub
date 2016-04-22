/**
 * Test case to test iothub.Client
 */

const HUB_NAME = "#{env:AZURE_IOTHUB_HUB_NAME}";
const ACCESS_KEY = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY}"
const ACCESS_KEY_NAME = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME}"

class ClientTestCase extends ImpTestCase {

    _client = null;
    _deviceId = ""; // conneceted device id
    _registry = null; // registry instance
    _receivedMessage = null; // message received

    function setUp() {
        this._deviceId = "device" + math.rand() + math.rand();
        return this.initClient();
    }

    /**
     * Initialize client
     */
    function initClient() {
        return Promise(function (resolve, reject) {

            local connectionString =
                "HostName=" + HUB_NAME + ".azure-devices.net;" +
                "SharedAccessKeyName=" + ACCESS_KEY_NAME + ";" +
                "SharedAccessKey=" + ACCESS_KEY;

            this._registry = iothub.Registry.fromConnectionString(connectionString);
            local hostname = iothub.ConnectionString.Parse(connectionString).HostName;

            this._registry.create({"deviceId" : this._deviceId}, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    imp.wakeup(10, function() { resolve(this.initClient()) }.bindenv(this));
                } else if (err) {
                    reject("createDevice error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    this._client = iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                    resolve("Created " + deviceInfo.getBody().deviceId + " on " + hostname);
                } else {
                    reject("createDevice error unknown")
                }
            }.bindenv(this));

        }.bindenv(this));
    }

    /**
     * Test client::sendEvent()
     */
    function test1SendEvent() {
        return Promise(function (resolve, reject) {
            local message = { somevalue = "123" };
            this._client.sendEvent(iothub.Message(message), function(err, res) {
                if (err) {
                    reject("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
                } else {
                    resolve("sendEvent successful");
                }
            });
        }.bindenv(this));
    }

    /**
     * Tests client::receive() by using exeternal command "iothub-explorer"
     * @see https://github.com/Azure/azure-iot-sdks/blob/master/tools/iothub-explorer/readme.md
     * @see https://github.com/electricimp/impTest/blob/develop/docs/writing-tests.md#external-commands
     */
    function test2Receive() {
        return Promise(function (resolve, reject) {
            // gen unique test message
            local testMessage = "message" + math.rand();

            // start receiving messages
            this._client.receive(function(err, message) {
                try {
                    if (err) throw err;
                    this._receivedMessage = message;
                    this.assertEqual(testMessage, message.getData() + "");
                    resolve("Received message: " + message.getData());
                } catch (e) {
                    reject(e);
                }
            }.bindenv(this));

            // send message using iothub-explorer tool
            this.sendMessageWithIotHubExplorer(testMessage);
        }.bindenv(this));
    }

    /**
     * Send message using iothub-explorer tool
     */
    function sendMessageWithIotHubExplorer(testMessage) {
        // login
        this.runCommand("./node_modules/.bin/iothub-explorer login \"HostName=${AZURE_IOTHUB_HUB_NAME}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=${AZURE_IOTHUB_SHARED_ACCESS_KEY}\"");

        // send msg
        this.runCommand("./node_modules/.bin/iothub-explorer send " + this._deviceId + " \"" + testMessage + "\"");

        // logout
        this.runCommand("./node_modules/.bin/iothub-explorer logout; echo 'Logged out'");
    }

    /**
     * Send feedback
     * Uses this._receivedMessage set from test2Receive()
     */
    function test3SendFeedback() {
        return Promise(function (resolve, reject) {
            this._client.sendFeedback(iothub.HTTP.FEEDBACK_ACTION_COMPLETE, this._receivedMessage, function(err, res) {
                if (err) {
                    reject("sendFeedback error: " + err.message + " (" + err.response.statuscode + ")");
                } else {
                    resolve("sendFeedback successful");
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    /**
     * Test client::sendEvent() with Message Id
     */
    function test4SendEventwithMessageId() {
        return Promise(function (resolve, reject) {
            local message = { somevalue = "123" };
            local headers = {
              "IoTHub-MessageId": "id_" + math.rand()
            }
            this._client.sendEvent(iothub.Message(message,headers), function(err, res) {
                if (err) {
                    reject("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
                } else {
                    resolve("sendEvent successful");
                }
            });
        }.bindenv(this));
    }

    /**
     * Test client::sendEvent() with Correlation Id
     */
    function test5SendEventwithCorrelationId() {
        return Promise(function (resolve, reject) {
            local message = { somevalue = "123" };
            local headers = {
              "IoTHub-CorrelationId": "correlationid_" + math.rand()
            }
            this._client.sendEvent(iothub.Message(message,headers), function(err, res) {
                if (err) {
                    reject("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
                } else {
                    resolve("sendEvent successful");
                }
            });
        }.bindenv(this));
    }

    /**
     * Tests client::sendEvent() with message Id and correlation Id
     */
    function test6SendEventwithMessageIdCorrelationId() {
        return Promise(function (resolve, reject) {
            // gen unique test message
            local message = { somevalue = "123" };
            local headers = {
              "IoTHub-MessageId": "messageid_" + math.rand(),
              "IoTHub-CorrelationId": "correlationid_" + math.rand()
            };
            this._client.sendEvent(iothub.Message(message,headers), function(err, res) {
                if (err) {
                    reject("sendEvent error: " + err.message + " (" + err.response.statuscode + ")");
                } else {
                    resolve("sendEvent successful");
                }
            });
        }.bindenv(this));
    }

    /**
     * Removes test device
     */
    function tearDown() {
        return Promise(function (resolve, reject) {
            this._registry.remove(this._deviceId, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    imp.wakeup(10, function() { resolve(this.tearDown()) }.bindenv(this));
                } else if (err) {
                    reject("remove() error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    resolve("Removed " + this._deviceId);
                } else {
                    reject("remove() error unknown")
                }
            }.bindenv(this));
        }.bindenv(this));
    }
}
