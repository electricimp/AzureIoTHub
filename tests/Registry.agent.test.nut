/**
 * Test case to test AzureIoTHub.Registry
 */

const HUB_NAME = "#{env:AZURE_IOTHUB_HUB_NAME}";
const ACCESS_KEY = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY}";
const ACCESS_KEY_NAME = "#{env:AZURE_IOTHUB_SHARED_ACCESS_KEY_NAME}";

class RegistryTestCase extends ImpTestCase {

    _registry = null;
    _deviceId = null;
    _haveDevice = false;

    function _replace(haystack, needle, substitute) {
        local p = 0;

        while (p = haystack.find(needle)) {
          haystack = haystack.slice(0, p) + substitute + haystack.slice(p + 1);
        }

        return haystack;
    }

    function setUp() {
        this._deviceId = "device_" + this._replace(this.session, "-", "_") + "_" + math.rand();
        return this.createRegistry();
    }

    function createRegistry() {
        return Promise(function (resolve, reject) {
            local connectionString = "HostName=" + HUB_NAME
                + ".azure-devices.net;SharedAccessKeyName=" + ACCESS_KEY_NAME
                + ";SharedAccessKey=" + ACCESS_KEY;
            this._registry = AzureIoTHub.Registry(connectionString);
            (typeof _registry == "instance") ? resolve("Registry created") : reject("Error creating registry");
        }.bindenv(this));
    }

    function test1CreateDevice() {
        return Promise(function (resolve, reject) {
            this._registry.create({"deviceId" : this._deviceId}, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    resolve(this.test1CreateDevice());
                } else if (err) {
                    reject("create() error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    resolve("Created " + deviceInfo.getBody().deviceId);
                } else {
                    reject("create() error unknown")
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function test2UpdateDevice() {
        return Promise(function (resolve, reject) {
            this._registry.update({"deviceId" : this._deviceId}, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    resolve(this.test2UpdateDevice());
                } else if (err) {
                    reject("update() error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    resolve("Updated " + deviceInfo.getBody().deviceId);
                } else {
                    reject("update() error unknown")
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function test3ListDevices() {
        return Promise(function (resolve, reject) {
            this._registry.list(function(err, devices) {
                if (err && err.response.statuscode == 429) {
                    resolve(this.test3ListDevices());
                } else if (err) {
                    reject("list() error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (devices) {
                    try {
                        this.assertTrue(type(devices) == "array");

                        local found = false;

                        foreach (k, v in devices) {
                            if (v.getBody().deviceId == this._deviceId) {
                                found = true;
                                break;
                            }
                        }

                        this.assertTrue(found, "Device " + this._deviceId + " not found");

                        resolve("Device is listed, total: " + devices.len());

                    } catch (e) {
                        reject(e);
                    }
                } else {
                    reject("list() error unknown")
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function test4GetDevice() {
        return Promise(function (resolve, reject) {
            this._registry.get(this._deviceId, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    resolve(this.test4GetDevice());
                } else if (err) {
                    reject("get() error: " + err.message + " (" + err.response.statuscode + ")");
                } else if (deviceInfo) {
                    try {
                        this.assertEqual(deviceInfo.getBody().deviceId, this._deviceId)
                        resolve("Retrieved " + this._deviceId);
                    } catch (e) {
                        reject(e);
                    }
                } else {
                    reject("get() error unknown")
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    function tearDown() {
        return Promise(function (resolve, reject) {
            this._registry.remove(this._deviceId, function(err, deviceInfo) {
                if (err && err.response.statuscode == 429) {
                    resolve(this.tearDown());
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
