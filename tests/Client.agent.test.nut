/**
 * Test case to test iothub.Client
 */

const HUB_NAME = "#{env:AZURE_IOTHUB_HUB_NAME}";
const ACCESS_KEY = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY}"
const ACCESS_KEY_NAME = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME}"

class ClientTestCase extends ImpTestCase {

    _client = null;
    _connectionString = "";
    _deviceId = "";

    function setUp() {
        return this.initClient();
    }

    /**
     * Initialize client
     */
    function initClient() {
        return Promise(function (resolve, reject) {

            this._connectionString =
                "HostName=" + HUB_NAME + ".azure-devices.net;" +
                "SharedAccessKeyName=" + ACCESS_KEY_NAME + ";" +
                "SharedAccessKey=" + ACCESS_KEY;

            local registry = iothub.Registry.fromConnectionString(this._connectionString);
            local hostname = iothub.ConnectionString.Parse(this._connectionString).HostName;

            registry.get(function (err, deviceInfo) {
                if (err) {
                    if (err.response.statuscode == 404) {
                        registry.create(function(err, deviceInfo) {
                            if (err && err.response.statuscode == 429) {
                                // todo add 10s delay
                                resolve(this.setUp());
                            } else if (err) {
                                reject("createDevice error: " + err.message + " (" + err.response.statuscode + ")");
                            } else if (deviceInfo) {
                                this._client = iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                                this._deviceId = deviceInfo.getBody().deviceId;
                                resolve("Created " + deviceInfo.getBody().deviceId + " on " + hostname);
                            } else {
                                reject("createDevice error unknown")
                            }
                        }.bindenv(this));
                    } else if (err.response.statuscode == 429) {
                        // todo add 10s delay
                        resolve(this.setUp());
                    } else {
                        reject("getDevice error: " + err.message + " (" + err.response.statuscode + ")");
                    }
                } else if (deviceInfo) {
                    this._client = iothub.Client.fromConnectionString(deviceInfo.connectionString(hostname));
                    this._deviceId = deviceInfo.getBody().deviceId;
                    resolve("Connected as " + deviceInfo.getBody().deviceId + " to " + hostname);
                } else {
                    reject("getDevice error unknown")
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


}
