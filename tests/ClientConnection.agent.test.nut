/**
 * Test case to test AzureIoTHub.Client connection
 */

const HUB_NAME = "#{env:AZURE_IOTHUB_HUB_NAME}";
const ACCESS_KEY = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY}"
const ACCESS_KEY_NAME = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME}"

class ClientEventsTestCase extends ImpTestCase {

    _client = null;
    _deviceId = ""; // conneceted device id
    _registry = null; // registry instance
    _receivedMessage = null; // message received

    function setUp() {
        this._deviceId = "device" + math.rand() + math.rand();
        return initClient();
    }

    /**
     * Open an AMQP connection for device
     */
    function initClient() {
        return Promise(function (resolve, reject) {
            local connectionString =
                "HostName=" + HUB_NAME + ".azure-devices.net;" +
                "SharedAccessKeyName=" + ACCESS_KEY_NAME + ";" +
                "SharedAccessKey=" + ACCESS_KEY;

            this._registry = AzureIoTHub.Registry(connectionString);
            local hostname = AzureIoTHub.ConnectionString.Parse(connectionString).HostName;

            this._registry.create({"deviceId" : this._deviceId}, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    imp.wakeup(10, function() { resolve(this.initClient()) }.bindenv(this));
                } else if (err) {
                    reject("createDevice error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    this._client = AzureIoTHub.Client(deviceInfo.connectionString(hostname));
                    resolve("Created " + deviceInfo.getBody().deviceId + " on " + hostname);
                } else {
                    reject("createDevice error unknown");
                }
            }.bindenv(this));

        }.bindenv(this));
    }

    function testConnect() {
        return Promise(function(resolve, reject) {
            this._client.connect(function(err) {
                if (err) {
                    reject("Connection error: " + err);
                } else {
                    resolve("Connection established");
                }
            }.bindenv(this));
        }.bindenv(this));
    }

     /**
     * Removes test device
     */
    function tearDown() {
        return Promise(function (resolve, reject) {
            this._client.disconnect();
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