/**
 * Test case to test iothub.Client send and receive events
 */

const HUB_NAME = "#{env:AZURE_IOTHUB_HUB_NAME}";
const ACCESS_KEY = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY}"
const ACCESS_KEY_NAME = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME}"

class ClientEventsTestCase extends ImpTestCase {

    _client = null;
    _deviceId = ""; // conneceted device id
    _registry = null; // registry instance

    function setUp() {
        this._deviceId = "device" + math.rand() + math.rand();
        return connectClient();
    }

    /**
     * Open an AMQP connection for device
     */
    function connectClient() {
        return Promise(function (resolve, reject) {
            local connectionString =
                "HostName=" + HUB_NAME + ".azure-devices.net;" +
                "SharedAccessKeyName=" + ACCESS_KEY_NAME + ";" +
                "SharedAccessKey=" + ACCESS_KEY;

            this._registry = iothub.Registry(connectionString);
            local hostname = iothub.ConnectionString.Parse(connectionString).HostName;

            this._registry.create({"deviceId" : this._deviceId}, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    imp.wakeup(10, function() { resolve(this.initClient()) }.bindenv(this));
                } else if (err) {
                    reject("createDevice error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    this._client = iothub.Client(deviceInfo.connectionString(hostname));
                    // connect
                    this._client.connect(function(err) {
                        if (err) {
                            reject("Connection error: " + err);
                        } else {
                            resolve("Connection established for device " + deviceInfo.getBody().deviceId);
                        }
                    }.bindenv(this));
                } else {
                    reject("createDevice error unknown");
                }
            }.bindenv(this)); // close _registry.create

        }.bindenv(this)); // close Promise
    }

    /**
     * Send message using iothub-explorer tool
     */
    function sendMessageWithIotHubExplorer(testMessage) {
        // login
        this.runCommand("iothub-explorer login \"HostName=${AZURE_IOTHUB_HUB_NAME}.azure-devices.net;SharedAccessKeyName=iothubowner;SharedAccessKey=${AZURE_IOTHUB_SHARED_ACCESS_KEY}\"");

        // send msg
        this.runCommand("iothub-explorer send " + this._deviceId + " \"" + testMessage + "\"");

        // logout
        this.runCommand("iothub-explorer logout; echo 'Logged out'");
    }

    /**
     * Check message number of messages in queue against expected number of messages
     */
    function checkMessageCount(expected, cb) {
        _registry.get(this._deviceId, function(err, deviceInfo) {
            if (err) {
                cb(err);
            } else {
                local msgCount = deviceInfo.getBody().cloudToDeviceMessageCount;
                if (msgCount == expected) {
                    cb(null);
                } else {
                    cb("Expected " + expected + " message count, got " + msgCount);
                }
            }
        }.bindenv(this));
    }

    /**
     * Change receive handler to accept all messages
     */
    function clearMessageQueue() {
        this._client.receive(function(err, delivery) {
            delivery.complete();
        }.bindenv(this));
    }

    /**
     * Test client::sendEvent()
     */
    function test1SendEvent() {
        return Promise(function (resolve, reject) {
            local message = { somevalue = "123" };
            this._client.sendEvent(iothub.Message(message), function(err) {
                if (err) {
                    reject("sendEvent error: " + err.message);
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
            this._client.receive(function(err, delivery) {
                try {
                    if (err) throw err;
                    local receivedMessage = delivery.getMessage();
                    // Convert receivedMessage to string, so we can compare to testMessage
                    this.assertEqual(testMessage, receivedMessage.getBody() + "");
                    // Clear message from the queue
                    delivery.complete();
                    resolve("Received message: " + receivedMessage.getBody());
                } catch (e) {
                    reject(e);
                }
            }.bindenv(this));

            // send message using iothub-explorer tool
            this.sendMessageWithIotHubExplorer(testMessage);
        }.bindenv(this));
    }

    /**
     * Send feedback complete
     * Send message using exeternal command "iothub-explorer"
     * @see https://github.com/Azure/azure-iot-sdks/blob/master/tools/iothub-explorer/readme.md
     * @see https://github.com/electricimp/impTest/blob/develop/docs/writing-tests.md#external-commands
     */
    function test3SendFeedbackComplete() {
        return Promise(function (resolve, reject) {
            // gen unique test message
            local testMessage = "message" + math.rand();

            // start receiving messages
            this._client.receive(function(err, delivery) {
                this.info("in complete receive")
                try {
                    if (err) throw err;
                    // check that we have a message in the queue
                    checkMessageCount(1, function(err) {
                        if (err) {
                            reject(err);
                        } else {
                            // accept message to clear it from the queue
                            delivery.complete();
                            // pause briefly before checking message queue again
                            imp.sleep(0.01);
                            // check that we have no messages in the queue
                            checkMessageCount(0, function(err) {
                                if (err) reject(err);
                                else resolve("Messesage Feedback Complete removed message from queue");
                            }.bindenv(this));
                        }
                    }.bindenv(this));
                } catch (e) {
                    reject(e);
                }
            }.bindenv(this));

            // send message using iothub-explorer tool
            this.sendMessageWithIotHubExplorer(testMessage);
        }.bindenv(this));
    }

    /**
     * Send feedback reject
     * Send message using exeternal command "iothub-explorer"
     * @see https://github.com/Azure/azure-iot-sdks/blob/master/tools/iothub-explorer/readme.md
     * @see https://github.com/electricimp/impTest/blob/develop/docs/writing-tests.md#external-commands
     */
    function test4SendFeedbackReject() {
        return Promise(function (resolve, reject) {
            // gen unique test message
            local testMessage = "message" + math.rand();

            // start receiving messages
            this._client.receive(function(err, delivery) {
                this.info("in reject receive")
                try {
                    if (err) throw err;
                    // check that we have a message in the queue
                    checkMessageCount(1, function(err) {
                        if (err) {
                            reject(err);
                        } else {
                            // reject message to clear it from the queue
                            delivery.reject();
                            // pause briefly before checking message queue again
                            imp.sleep(0.01);
                            // check that we have no messages in the queue
                            checkMessageCount(0, function(err) {
                                if (err) reject(err);
                                else resolve("Messesage Feedback Reject removed message from queue");
                            }.bindenv(this));
                        }
                    }.bindenv(this));
                } catch (e) {
                    reject(e);
                }
            }.bindenv(this));

            // send message using iothub-explorer tool
            this.sendMessageWithIotHubExplorer(testMessage);
        }.bindenv(this));
    }

    /**
     * Send feedback abandon
     * Send message using exeternal command "iothub-explorer"
     * @see https://github.com/Azure/azure-iot-sdks/blob/master/tools/iothub-explorer/readme.md
     * @see https://github.com/electricimp/impTest/blob/develop/docs/writing-tests.md#external-commands
     */
    function test5SendFeedbackAbandon() {
        return Promise(function (resolve, reject) {
            // gen unique test message
            local testMessage = "message" + math.rand();
            local acceptCounter = 0;

            // start receiving messages
            this._client.receive(function(err, delivery) {
                // abandoning a message triggers redelivery
                // accept the redelivered message
                if (acceptCounter > 0) {
                    // make sure not to clear before message check counts happen
                    imp.wakeup(0.1, function() {
                        delivery.complete();
                    }.bindenv(this))
                    return
                }

                // increment counter
                acceptCounter ++;
                try {
                    if (err) throw err;
                    // check that we have a message in the queue
                    checkMessageCount(1, function(err) {
                        if (err) {
                            reject(err);
                        } else {
                            // abandon message to clear it from the queue
                            delivery.abandon();
                            // pause briefly before checking message queue again
                            imp.sleep(0.01);
                            // check that we still have messages in the queue
                            checkMessageCount(1, function(err) {
                                if (err) {
                                    reject(err);
                                } else {
                                    clearMessageQueue();
                                    resolve("Messesage Feedback Abandon message re-queued");
                                }
                            }.bindenv(this));
                        }
                    }.bindenv(this));
                } catch (e) {
                    reject(e);
                }
            }.bindenv(this));

            // send message using iothub-explorer tool
            this.sendMessageWithIotHubExplorer(testMessage);
        }.bindenv(this));
    }

    // *
    // * Test client::sendEvent() with Message Id
    // */
    function test6SendEventwithMessageId() {
        return Promise(function (resolve, reject) {
            local message = { somevalue = "123" };
            local properties = {
              "IoTHub-MessageId": "id_" + math.rand()
            }
            this._client.sendEvent(iothub.Message(message,properties), function(err) {
                if (err) {
                    reject("sendEvent error: " + err.message);
                } else {
                    resolve("sendEvent successful");
                }
            });
            // add check of message id??
        }.bindenv(this));
    }

    /**
     * Tests client::sendEvent() with message Id and correlation Id
     */
    function test7SendEventwithMessageIdCorrelationId() {
        return Promise(function (resolve, reject) {
            // gen unique test message
            local message = { somevalue = "123" };
            local properties = {
              "IoTHub-MessageId": "messageid_" + math.rand(),
              "IoTHub-CorrelationId": "correlationid_" + math.rand()
            };
            this._client.sendEvent(iothub.Message(message,properties), function(err) {
                if (err) {
                    reject("sendEvent error: " + err.message);
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
