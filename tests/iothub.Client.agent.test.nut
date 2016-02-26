/**
 * Test case to test iothub.Client
 */

const HUB_NAME = "imptesthuba";
const ACCESS_KEY = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY}"
const ACCESS_KEY_NAME = "iothubowner"

class ClientTestCase extends ImpTestCase {
    _client = null;

    function setUp() {
        return Promise(function (resolve, reject) {

            local connectionString = "HostName=" + HUB_NAME
                + ".azure-devices.net;SharedAccessKeyName=" + ACCESS_KEY_NAME
                + ";SharedAccessKey=" + ACCESS_KEY;
            local registry = iothub.Registry.fromConnectionString(connectionString);
            local hostname = iothub.ConnectionString.Parse(connectionString).HostName;

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
                    resolve("Connected as " + deviceInfo.getBody().deviceId + " to " + hostname);
                } else {
                    reject("getDevice error unknown")
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function testSendEvent() {
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
}
