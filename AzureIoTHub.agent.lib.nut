// MIT License
//
// Copyright 2015-2018 Electric Imp
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


// AzureIoTHub is an Electric Imp agent-side library for interfacing with Azure IoT Hub version “2016-11-14”

const AZURE_API_VERSION = "2016-11-14";
const AZURE_CLAIM_BASED_SECURITY_PATH = "$cbs";

const AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED          = 1000;
const AZURE_IOT_CLIENT_ERROR_ALREADY_CONNECTED      = 1001;
const AZURE_IOT_CLIENT_ERROR_NOT_ENABLED            = 1002;
const AZURE_IOT_CLIENT_ERROR_ALREADY_ENABLED        = 1003;
const AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW     = 1004;
const AZURE_IOT_CLIENT_ERROR_OP_TIMED_OUT           = 1005;
const AZURE_IOT_CLIENT_ERROR_GENERAL                = 1010;

const AZURE_IOT_CLIENT_DEFAULT_QOS                  = 0;
// Timeout for RetrieveTwin and UpdateTwin requests (sec)
const AZURE_IOT_CLIENT_DEFAULT_TIMEOUT              = 10;
// Maximum amount of parallel UpdateTwin requests
const AZURE_IOT_CLIENT_DEFAULT_TWIN_UPD_PARAL_REQS  = 3;
// Maximum amount of parallel SendMessage requests
const AZURE_IOT_CLIENT_DEFAULT_MSG_SEND_PARAL_REQS  = 3;


class AzureIoTHub {

    static VERSION = "3.0.0";

    // Helper Classes modeled after JS/Node SDK
    //------------------------------------------------------------------------------

    // This is a helper class used to parse the connection string for Azure IoT Hub.
    ConnectionString = class {

        static function Parse(connectionString) {
            local cn = {};

            // Clean up the string first
            if (typeof connectionString != "string") return cn;
            connectionString = strip(connectionString);
            if (connectionString.len() == 0) return cn;

            // Locate each = and ; in the connection string
            local pairs = split(connectionString, ";")
            foreach (pair in pairs) {
                local kv = split(pair, "=");
                if (kv.len() == 1) {
                    cn[kv[0]] <- null;
                } else if (kv.len() == 2) {
                    cn[kv[0]] <- kv[1];
                    if (kv[0] == "SharedAccessKey") {
                        cn[kv[0]] += "=";
                    }
                }
            }

            // Make sure we have these fields so we don't have to check for them later
            foreach (mandatory in ["HostName", "DeviceId"]) {
                if (!(mandatory in cn)) {
                    cn[mandatory] <- null;
                }
            }

            return cn;
        }
    }

    // This is a helper class used for authorization purposes.
    Authorization = class {

        static function aMinuteFromNow() {
            return time() + 60;
        }

        static function fifteenMinutesFromNow() {
            return time() + 900;
        }

        static function anHourFromNow() {
            return time() + 3600;
        }

        static function anDayFromNow() {
            return time() + 86400;
        }

        // encode URI component strict
        static function encodeUri(str) {
            // NOTE: This may not encode enough characters. If it is a problem, check
            //       it is encoding: !, ", *, ( and ).
            return http.urlencode({s=str}).slice(2);
        }

        static function stringToSign(resourceUri, expiry) {
            return resourceUri + "\n" + expiry;
        }

        static function hmacHash(password, stringToSign) {
            local decodedPassword = http.base64decode(password);
            local hmac = http.hash.hmacsha256(stringToSign, decodedPassword);
            return http.base64encode(hmac);
        }
    }

    // This is a helper class used to construct the Shared Access Signature required to authenticate on Azure IoT Hub.
    SharedAccessSignature = class {

        sr = null;
        sig = null;
        skn = null;
        se = null;

        constructor(resourceUri, keyName, key, expiry) {

            // The sr property shall have the value of resourceUri.
            sr = resourceUri;

            // <signature> shall be an HMAC-SHA256 hash of the value <stringToSign>, which is then base64-encoded.
            // <stringToSign> shall be a concatenation of resourceUri + "\n" + expiry.
            local hash = AzureIoTHub.Authorization.hmacHash(key, AzureIoTHub.Authorization.stringToSign(resourceUri, expiry));

            // The sig property shall be the result of URL-encoding the value <signature>.
            sig = AzureIoTHub.Authorization.encodeUri(hash);

            // If the keyName argument to the create method was falsy, skn shall not be defined.
            // <urlEncodedKeyName> shall be the URL-encoded value of keyName.
            // The skn property shall be the value <urlEncodedKeyName>.
            if (keyName) skn = AzureIoTHub.Authorization.encodeUri(keyName);

            // The se property shall have the value of expiry.
            se = expiry;
        }

        function toString() {
            // The toString method shall return a shared-access signature token of the form:
            // SharedAccessSignature sr=<resourceUri>&sig=<urlEncodedSignature>&se=<expiry>&skn=<urlEncodedKeyName>
            local sas = "SharedAccessSignature ";
            foreach (key in ["sr", "sig", "skn", "se"]) {
                // The skn segment is not part of the returned string if the skn property is not defined.
                if (this[key]) {
                    if (sas[sas.len() - 1] != ' ') sas += "&";
                    sas += key + "=" + this[key];
                }
            }

            return sas;
        }
    }

    // This is a helper class used to construct path strings for the AzureIoTHub.Registry class.
    Endpoint = class {

        static function devicePath(id) {
            return "/devices/" + id;
        }

        static function versionQueryString() {
            return ("?api-version=" + AZURE_API_VERSION);
        }
    }

    //------------------------------------------------------------------------------

    // This class is used to create Devices identity objects used by the AzureIoTHub.Registry class.
    // Registry methods will create device objects for you if you choose to pass in tables.
    Device = class {

        _body = null;

        constructor(devInfo = null) {

            if (typeof devInfo == "table") {
                // Make sure we have a device Id
                if (!("deviceId" in devInfo)) devInfo.deviceId <- split(http.agenturl(), "/").pop();
                _body = devInfo;
            } else {
                _body = {
                    "deviceId": split(http.agenturl(), "/").pop(),
                    "generationId": null,
                    "etag": null,
                    "connectionState": "Disconnected",
                    "status": "Enabled",
                    "statusReason": null,
                    "connectionStateUpdatedTime": null,
                    "statusUpdatedTime": null,
                    "lastActivityTime": null,
                    "cloudToDeviceMessageCount": 0,
                    "authentication": {
                        "symmetricKey": {
                            "primaryKey": null,
                            "secondaryKey": null
                        }
                    }
                };
            }
        }

        function connectionString(hostname) {
            // NOTE: This method did not appear in the original Node.js SDK
            return format("HostName=%s;DeviceId=%s;SharedAccessKey=%s", hostname, _body.deviceId, _body.authentication.symmetricKey.primaryKey);
        }

        function getBody() {
            return _body;
        }

        function _typeof() {
            return "device";
        }
    }

    // This class is used to create a message to send to Azure IoT Hub or on receiving from Azure IoT Hub.
    Message = class {

        _body = null;
        _properties = null;

        constructor(body, properties = null) {
            _body = body;
            _properties = properties;
        }

        function getProperties() {
            return _properties;
        }

        function getBody() {
            return _body;
        }

        function _typeof() {
            return "message";
        }
    }

    // This class is used to create a response to the received Direct Method call to send it back to Azure IoT Hub.
    DirectMethodResponse = class {
        _status = null;
        _body   = null;

        // DirectMethodResponse class constructor.
        //
        // Parameters:
        //     status : Integer             Status of the Direct Method execution. Fully application specific.
        //     options : Table              Key-value table with the returned data.
        //          (optional)              Every key is always a String with the name of the data field.
        //                                  The value is the corresponding value of the data field.
        //                                  Keys and values are fully application specific.
        //
        // Returns:                         AzureIoTHub.DirectMethodResponse instance created.
        constructor(status, body = null) {
            _status = status;
            _body = body;
        }
    }

    //------------------------------------------------------------------------------

    // Registration transport class
    RegistryHTTP = class {

        _config = null;

        constructor(config) {
            _config = config;
        }

        function refreshSignature() {

            // NOTE: This method did not appear in the original Node.js SDK
            if ("sharedAccessExpiry" in _config && "connectionString" in _config) {
                if (time() >= _config.sharedAccessExpiry) {
                    local cn = AzureIoTHub.ConnectionString.Parse(_config.connectionString);
                    local sas = AzureIoTHub.SharedAccessSignature(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow());
                    _config.sharedAccessSignature = sas.toString();
                    _config.sharedAccessExpiry = sas.se;
                }
            }
        }

        function createDevice(path, deviceInfo, done) {

            refreshSignature();
            local url = "https://" + _config.host + path;
            local httpHeaders = {
                "Authorization": _config.sharedAccessSignature,
                "iothub-name": _config.hubName,
                "Content-Type": "application/json; charset=utf-8"
            };

            local request = http.put(url, httpHeaders, http.jsonencode(deviceInfo));
            request.sendasync(handleResponse(done));
            return this;

        };

        function updateDevice(path, deviceInfo, done) {

            refreshSignature();
            local url = "https://" + _config.host + path;
            local httpHeaders = {
                "Authorization": _config.sharedAccessSignature,
                "iothub-name": _config.hubName,
                "Content-Type": "application/json; charset=utf-8"
                "If-Match": "*"
            };
            local request = http.put(url, httpHeaders, http.jsonencode(deviceInfo));
            request.sendasync(handleResponse(done));
            return this;
        }

        function getDevice(path, done) {

            refreshSignature();
            local url = "https://" + _config.host + path;
            local httpHeaders = {
                "Authorization": _config.sharedAccessSignature,
                "iothub-name": _config.hubName,
            };
            local request = http.get(url, httpHeaders);
            request.sendasync(handleResponse(done));
            return this;
        }

        function listDevices(path, done) {

            refreshSignature();
            local url = "https://" + _config.host + path;
            local httpHeaders = {
                "Authorization": _config.sharedAccessSignature,
                "iothub-name": _config.hubName,
            };
            local request = http.get(url, httpHeaders);
            request.sendasync(handleResponse(done));
            return this;
        }

        function deleteDevice(path, done) {

            refreshSignature();
            local url = "https://" + _config.host + path;
            local httpHeaders = {
                "Authorization": _config.sharedAccessSignature,
                "iothub-name": _config.hubName,
                "If-Match": "*"
            };
            local request = http.httpdelete(url, httpHeaders);
            request.sendasync(handleResponse(done));
            return this;
        }

        function handleResponse(done) {

            return function(response) {
                if (response.statuscode/100 == 2) {
                    if (done) done(null, response.body);
                } else {
                    local message = null;
                    try {
                        local body = http.jsondecode(response.body);
                        message = body.Message;
                    } catch (e) {
                        message = "Error " + response.statuscode;
                    }
                    if (done) done({ "response": response, "message": message}, null);
                }
            }.bindenv(this);
        }
    }

    // This class allows your to create, remove, update, delete and list the IoT Hub devices in your Azure account.
    Registry = class {

        static ERROR_MISSING_CALLBACK    = "A callback function is required";
        static ERROR_MISSING_DEVICE_ID   = "A deviceId string required to complete request";
        static ERROR_MISSING_DEVICE_INFO = "A table with a deviceId key required to complete request";

        _transport = null;

        constructor(connectionString) {
            local config = fromConnectionString(connectionString);
            _transport = AzureIoTHub.RegistryHTTP(config);
        }

        function fromConnectionString(connectionString) {
            local cn = AzureIoTHub.ConnectionString.Parse(connectionString);
            local sas = AzureIoTHub.SharedAccessSignature(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow());

            local config = {
                "host": cn.HostName,
                "hubName": split(cn.HostName, ".")[0],
                "sharedAccessSignature": sas.toString(),
                "sharedAccessExpiry": sas.se,
                "connectionString": connectionString
            };
            return config;
        }

        function create(deviceInfo = null, done = null) {

            // NOTE: These default values are not from the original Node.js SDK
            if (typeof deviceInfo == "function") {
                done = deviceInfo;
                deviceInfo = {};
            }

            if (typeof deviceInfo == "device") {
                deviceInfo = deviceInfo.getBody();
            } else if (typeof deviceInfo != "table") {
                deviceInfo = {};
            }

            if (!("deviceId" in deviceInfo) || deviceInfo.deviceId == null) {
                deviceInfo.deviceId <- split(http.agenturl(), "/").pop();
            }

            local path = AzureIoTHub.Endpoint.devicePath(deviceInfo.deviceId) + AzureIoTHub.Endpoint.versionQueryString();
            _transport.createDevice(path, deviceInfo, function (err, body) {
                local dev = null;
                if (err) {
                    dev = body;
                } else if (body) {
                    dev = AzureIoTHub.Device(http.jsondecode(body));
                }
                if (done) done(err, dev);
            }.bindenv(this))

            return this;
        }

        function update(deviceInfo, done = null) {

            local error = null;

            // make sure we have a valid deviceInfo table 
            switch (typeof deviceInfo) {
                case "function" :
                    done = deviceInfo;
                    error = {"response" : null, "message" : ERROR_MISSING_DEVICE_INFO};
                    break;
                case "table":
                    if (!("deviceId" in deviceInfo)) {
                        error = {"response" : null, "message" : ERROR_MISSING_DEVICE_INFO};
                    }
                    break;
                case "device":
                    deviceInfo = deviceInfo.getBody();
                    break;
                default : 
                    error = {"response" : null, "message" : ERROR_MISSING_DEVICE_INFO};
            }
            
            if (error) {
                done(error, null);
                return this;
            } 

            local path = AzureIoTHub.Endpoint.devicePath(deviceInfo.deviceId) + AzureIoTHub.Endpoint.versionQueryString();
            _transport.updateDevice(path, deviceInfo, function (err, body) {
                local dev = null;
                if (err) {
                    dev = body;
                } else if (body) {
                    dev = AzureIoTHub.Device(http.jsondecode(body));
                }
                if (done) done(err, dev);
            }.bindenv(this))

            return this;
        }

        function get(deviceId, done) {

            if (typeof done != "function") throw ERROR_MISSING_CALLBACK;
            
            local devID = null;
            local error = null;

            // make sure we have a valid deviceId even if user 
            // passed in deviceInfo table or Device object
            switch (typeof deviceId) {
                case "string":
                    devID = deviceId;
                    break;
                case "table":
                    if ("deviceId" in deviceId) {
                        devID = deviceId.deviceId;
                    } else {
                        error = {"response" : null, "message" : ERROR_MISSING_DEVICE_ID};
                    }
                    break;     
                case "device":
                    devID = deviceId.getBody().deviceId;
                    break;
                default :
                    error = {"response" : null, "message" : ERROR_MISSING_DEVICE_ID};
            }

            if (error) {
                done(error, null);
                return this;
            } 

            local path = AzureIoTHub.Endpoint.devicePath(devID) + AzureIoTHub.Endpoint.versionQueryString();
            _transport.getDevice(path, function (err, body) {
                local dev = null;
                if (body) {
                    dev = AzureIoTHub.Device(http.jsondecode(body));
                }
                done(err, dev);
            }.bindenv(this))

            return this;
        }

        function list(done) {

            if (typeof done != "function") throw "A callback function must be passed in";

            local path = AzureIoTHub.Endpoint.devicePath("") + AzureIoTHub.Endpoint.versionQueryString();
            _transport.listDevices(path, function (err, body) {

                local devices = [];
                if (body) {
                    local jsonArray = http.jsondecode(body);
                    foreach (jsonElement in jsonArray) {
                        local devItem = AzureIoTHub.Device(jsonElement);
                        devices.push(devItem);
                    }
                }

                done(err, devices);
            }.bindenv(this))

            return this;
        }

        function remove(deviceId, done = null) {

            local devID = null;
            local error = null;

            // make sure we have a valid deviceId even if user 
            // passed in deviceInfo table or Device object
            switch (typeof deviceId) {
                case "function" :
                    done = deviceId;
                    error = {"response" : null, "message" : ERROR_MISSING_DEVICE_ID};
                    break;
                case "string":
                    devID = deviceId;
                    break;
                case "table":
                    if ("deviceId" in deviceId) {
                        devID = deviceId.deviceId;
                        break;
                    } else {
                        error = {"response" : null, "message" : ERROR_MISSING_DEVICE_ID};
                    }
                case "device":
                    devID = deviceId.getBody().deviceId;
                    break;
                default : 
                    error = {"response" : null, "message" : ERROR_MISSING_DEVICE_ID};
            }
            
            if (error) {
                done(error, null);
                return this;
            } 

            local path = AzureIoTHub.Endpoint.devicePath(devID) + AzureIoTHub.Endpoint.versionQueryString();
            _transport.deleteDevice(path, done);

            return this;
        }
    }

    //------------------------------------------------------------------------------

    // This class is used to transfer data to and from Azure IoT Hub.
    // To use this class, the device must be registered as an IoT Hub device in an Azure account.
    // AzureIoTHub.Client works over MQTT v3.1.1 protocol. It supports the following functionality:
    // - connecting and disconnecting to/from Azure IoT Hub. Azure IoT Hub supports only one connection per device.
    // - sending messages to Azure IoT Hub
    // - receiving messages from Azure IoT Hub (optionally enabled)
    // - device twin operations (optionally enabled)
    // - direct methods processing (optionally enabled)
    Client = class {

        _debugEnabled           = false;

        _isDisconnected         = true;
        _isDisconnecting        = false;
        _isConnected            = false;
        _isConnecting           = false;
        _isEnablingMsg          = false;
        _isEnablingTwin         = false;
        _isEnablingDMethod      = false;

        _connStrParsed          = null;
        _options                = null;
        _mqttclient             = null;
        _topics                 = null;

        // Long term user callbacks. Like onReceive, onRequest, onMethod
        _onConnectedCb          = null;
        _onDisconnectedCb       = null;
        _onMessageCb            = null;
        _onTwinReqCb            = null;
        _onMethodCb             = null;

        // Short term user callbacks. Like onDone, onRetrieved
        // User can send several messages in parallel, so we need a map reqId -> [<msg>, <callback>]
        _msgPendingQueue        = null;
        _msgEnabledCb           = null;
        _twinEnabledCb          = null;
        // Contains [<reqId>, <callback>, <timestamp>] or null
        _twinRetrievedCb        = null;
        // User can update twin several times in parallel, so we need a map reqId -> [<props>, <callback>, <timestamp>]
        _twinPendingRequests    = null;
        _dMethodEnabledCb       = null;

        _processQueueTimer      = null;

        _reqNum                 = 0;


        // MQTT Client class constructor.
        //
        // Parameters:
        //     deviceConnStr : String       Device connection string: includes the host name to connect, the device Id and the shared access string.
        //                                  It can be obtained from the Azure Portal.
        //                                  However, if the device was registered using the AzureIoTHub.Registry class,
        //                                  the deviceConnectionString parameter can be retrieved from the AzureIoTHub.Device instance passed
        //                                  to the AzureIoTHub.Registry.get() or AzureIoTHub.Registry.create() method callbacks.
        //                                  For more guidance, please see the AzureIoTHub.registry example (README.md).
        //     onConnected : Function       Callback called every time the device is connected.
        //                                  The callback signature:
        //                                  onConnected(error), where
        //                                      error : Integer     0 if the connection is successful, an error code otherwise.
        //     onDisconnected : Function    Callback called every time the device is disconnected
        //          (optional)              The callback signature:
        //                                  onDisconnected(error), where
        //                                      error : Integer     0 if the disconnection was caused by the disconnect() method,
        //                                                          an error code which explains a reason of the disconnection otherwise.
        //     options : Table              Key-value table with optional settings.
        //          (optional)
        //
        // Returns:                         AzureIoTHub.Client instance created.
        constructor(deviceConnStr, onConnected, onDisconnected = null, options = {}) {
            const MESSAGE_INDEX = 0;
            const REQ_ID_INDEX = 0;
            const TWIN_PROPERTIES_INDEX = 0;
            const CALLBACK_INDEX = 1;
            const TIMESTAMP_INDEX = 2;

            _msgPendingQueue = {};
            _twinPendingRequests = {};
            _options = {
                "qos" : AZURE_IOT_CLIENT_DEFAULT_QOS,
                "timeout" : AZURE_IOT_CLIENT_DEFAULT_TIMEOUT,
                "maxPendingTwinRequests" : AZURE_IOT_CLIENT_DEFAULT_TWIN_UPD_PARAL_REQS,
                "maxPendingSendRequests" : AZURE_IOT_CLIENT_DEFAULT_MSG_SEND_PARAL_REQS
            };

            _onConnectedCb      = onConnected;
            _onDisconnectedCb   = onDisconnected;

            _connStrParsed = AzureIoTHub.ConnectionString.Parse(deviceConnStr);
            _mqttclient = mqtt.createclient();
            _mqttclient.onconnect(_onConnected.bindenv(this));
            _mqttclient.onconnectionlost(_onDisconnected.bindenv(this));
            _mqttclient.onmessage(_onMessage.bindenv(this));

            foreach (optName, optVal in options) {
                _options[optName] <- optVal;
            }

            _initTopics(_connStrParsed.DeviceId);
        }

        // Opens a connection to Azure IoT Hub.
        //
        // Returns:                         Nothing.
        function connect() {
            if (_isConnected || _isConnecting) {
                _onConnectedCb(_isConnected ? AZURE_IOT_CLIENT_ERROR_ALREADY_CONNECTED : AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW);
                return;
            }
            _log("Connecting...");

            local devPath = "/" + _connStrParsed.DeviceId;
            local username = format("%s%s/api-version=%s", _connStrParsed.HostName, devPath, AZURE_API_VERSION);
            local resourcePath = format("/devices%s/api-version=%s", devPath, AZURE_API_VERSION);
            local resourceUri = AzureIoTHub.Authorization.encodeUri(_connStrParsed.HostName + resourcePath);
            local passwDeadTime = AzureIoTHub.Authorization.anHourFromNow();
            local sas = AzureIoTHub.SharedAccessSignature(resourceUri, null, _connStrParsed.SharedAccessKey, passwDeadTime).toString();

            local options = {
                "username" : username,
                "password" : sas
            };

            local url = "ssl://" + _connStrParsed.HostName;

            _isConnecting = true;

            _mqttclient.connect(url, _connStrParsed.DeviceId, options);
        }

        // Closes the connection to Azure IoT Hub. Does nothing if the connection is already closed.
        //
        // Returns:                         Nothing.
        function disconnect() {
            if ((!_isDisconnected || _isConnecting) && !_isDisconnecting) {
                _isDisconnecting = true;
                _mqttclient.disconnect(_onDisconnected.bindenv(this));
            }
        }

        // Checks if the client is connected to Azure IoT Hub.
        //
        // Returns:                         Boolean: true if the client is connected, false otherwise.
        function isConnected() {
            return _isConnected;
        }

        // Sends a message to Azure IoT Hub (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages).
        //
        // Parameters:
        //     msg : AzureIoTHub.Message    Message to send.
        //     onSent : Function            Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onSent(msg, error), where
        //                                      msg :               The original message passed to the sendMessage() method.
        //                                          AzureIoTHub.Message
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function sendMessage(msg, onSent = null) {
            if (!_isConnected || _isDisconnecting) {
                onSent && onSent(msg, _isConnected ? AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
                return;
            }

            local tooManyRequests = _msgPendingQueue.len() >= _options.maxPendingSendRequests;

            if (tooManyRequests) {
                onSent && onSent(msg, AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW);
                return;
            }

            local props = "";
            if (typeof msg != "message") {
                throw "Message should be an instance of AzureIoTHub.Message";
            }
            if (msg.getProperties() != null) {
                try {
                    props = http.urlencode(msg.getProperties());
                } catch (e) {
                    _logError("Exception at parsing the properties: " + e);
                    onSent && onSent(msg, AZURE_IOT_CLIENT_ERROR_GENERAL);
                    return;
                }
            }
            local topic = _topics.msgSend + props;
            local reqId = _reqNum++;

            local mqttMsg = _mqttclient.createmessage(topic, msg.getBody(), _options.qos);

            local msgSentCb = function (err) {
                if (reqId in _msgPendingQueue) {
                    delete _msgPendingQueue[reqId];
                    onSent && onSent(msg, err);
                }
            }.bindenv(this);

            _msgPendingQueue[reqId] <- [msg, onSent];
            mqttMsg.sendasync(msgSentCb);
        }

        // Enables or disables message receiving from Azure IoT Hub (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-cloud-to-device-messages).
        //
        // Parameters:
        //     onReceive : Function         Callback called every time a new message is received. null disables the feature.
        //                                  The callback signature:
        //                                  onReceive(message), where
        //                                      message :           Received message.
        //                                          AzureIoTHub.Message
        //     onDone : Function            Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onDone(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableIncomingMessages(onReceive, onDone = null) {
            local enabled = _onMessageCb != null;
            local disable = onReceive == null;

            if (!_readyToEnable(_isEnablingMsg, enabled, disable, onDone)) {
                return;
            }

            local doneCb = function (err) {
                if (_msgEnabledCb != null) {
                    _msgEnabledCb = null;
                    _isEnablingMsg = false;
                    if (err == 0) {
                        _onMessageCb = onReceive;
                        _ok(onDone);
                    } else {
                        _error(onDone, err);
                    }
                }
            }.bindenv(this);

            local topic = _topics.msgRecv + "#";
            _msgEnabledCb = onDone;
            _isEnablingMsg = true;

            if (disable) {
                // Should unsubscribe
                // TODO: Check EI's spec on unsubscribe callback
                _mqttclient.unsubscribe(topic, doneCb);
            } else {
                // Should send subscribe packet

                local subscribedCb = function (err, qos) {
                    doneCb(err);
                }.bindenv(this);

                _mqttclient.subscribe(topic, _options.qos, subscribedCb);
            }
        }

        // Enables or disables Azure IoT Hub Device Twins functionality (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins).
        //
        // Parameters:
        //     onRequest : Function         Callback called every time a new request with desired Device Twin properties is received. null disables the feature.
        //                                  The callback signature:
        //                                  onRequest(version, props), where
        //                                      props : Table       Key-value table with the desired properties.
        //                                                          Every key is always a String with the name of the property.
        //                                                          The value is the corresponding value of the property.
        //                                                          Keys and values are fully application specific.
        //     onDone : Function            Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onDone(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableTwin(onRequest, onDone = null) {
            local enabled = _onTwinReqCb != null;
            local disable = onRequest == null;

            if (!_readyToEnable(_isEnablingTwin, enabled, disable, onDone)) {
                return;
            }

            local doneTwinRecvCb = function (err) {
                if (_twinEnabledCb =! null) {
                    _twinEnabledCb = null;
                    _isEnablingTwin = false;
                    if (err == 0) {
                        _onTwinReqCb = onRequest;
                        _ok(onDone);
                    } else {
                        _error(onDone, err);
                    }
                }
            }.bindenv(this);

            local subscribedTwinRecvCb = function (err, qos) {
                doneTwinRecvCb(err);
            }.bindenv(this);

            local doneTwinNotifCb = function (err) {
                if (_twinEnabledCb != null) {
                    if (err == 0) {
                        local topic = _topics.twinRecv + "#";
                        if (disable) {
                            _mqttclient.unsubscribe(topic, doneTwinRecvCb);
                        } else {
                            _mqttclient.subscribe(topic, _options.qos, subscribedTwinRecvCb);
                        }
                    } else {
                        _twinEnabledCb = null;
                        _isEnablingTwin = false;
                        _error(onDone, err);
                    }
                }
            }.bindenv(this);

            local topic = _topics.twinNotif + "#";
            _twinEnabledCb = onDone;
            _isEnablingTwin = true;

            if (disable) {
                // Should unsubscribe
                // TODO: Check EI's spec on unsubscribe callback
                _mqttclient.unsubscribe(topic, doneTwinNotifCb);
            } else {
                // Should send subscribe packet for notifications and GET

                local subscribedTwinNotifCb = function (err, qos) {
                    doneTwinNotifCb(err);
                }.bindenv(this);

                _mqttclient.subscribe(topic, _options.qos, subscribedTwinNotifCb);
            }
        }

        // Retrieves Device Twin properties (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties).
        //
        // Parameters:
        //     onRetrieved : Function       Callback called when the properties are retrieved.
        //                                  The callback signature:
        //                                  onRetrieved(error, reportedProps, desiredProps), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //                                      reportedProps :     Key-value table with the reported properties and their version.
        //                                          Table           This parameter should be ignored if error is not 0.
        //                                                          Every key is always a String with the name of the property.
        //                                                          The value is the corresponding value of the property.
        //                                                          Keys and values are fully application specific.
        //                                      desiredProps :      Key-value table with the desired properties and their version.
        //                                          Table           This parameter should be ignored if error is not 0.
        //                                                          Every key is always a String with the name of the property.
        //                                                          The value is the corresponding value of the property.
        //                                                          Keys and values are fully application specific.
        //
        // Returns:                         Nothing.
        function retrieveTwinProperties(onRetrieved) {
            local enabled = _onTwinReqCb != null;
            local isRetrieving = _twinRetrievedCb != null;

            if (!_isConnected || _isDisconnecting) {
                onRetrieved(_isConnected ? AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED, null, null);
                return;
            }

            if (!enabled) {
                onRetrieved(AZURE_IOT_CLIENT_ERROR_NOT_ENABLED, null, null);
                return;
            }

            // Only one retrieve operation at a time is allowed
            if (isRetrieving) {
                onRetrieved(AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW, null, null);
                return;
            }

            local reqId = _reqNum.tostring();
            local topic = _topics.twinGet + "?$rid=" + reqId;
            _reqNum++;

            local mqttMsg = _mqttclient.createmessage(topic, "", _options.qos);

            local msgSentCb = function (err) {
                if (_twinRetrievedCb != null) {
                    if (err == 0) {
                        _twinRetrievedCb = [reqId, onRetrieved, time()];
                        if (_processQueueTimer == null) {
                            _processQueueTimer = imp.wakeup(_options.timeout, _processQueue.bindenv(this));
                        }
                    } else {
                        _twinRetrievedCb = null;
                        onRetrieved(err, null, null);
                    }
                }
            }.bindenv(this);

            _twinRetrievedCb = [reqId, onRetrieved, null];
            mqttMsg.sendasync(msgSentCb);

        }

        // Updates Device Twin reported properties (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties).
        //
        // Parameters:
        //     props : Table                Key-value table with the desired properties.
        //                                  Every key is always a String with the name of the property.
        //                                  The value is the corresponding value of the property.
        //                                  Keys and values are fully application specific.
        //     onUpdated : Function         Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onUpdated(props, error), where
        //                                      props : Table       The original properties passed to the updateTwinProperties() method.
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function updateTwinProperties(props, onUpdated = null) {
            local enabled = _onTwinReqCb != null;
            local tooManyRequests = _twinPendingRequests.len() >= _options.maxPendingTwinRequests;

            if (!_isConnected || _isDisconnecting) {
                onUpdated && onUpdated(props, _isConnected ? AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
                return;
            }

            if (!enabled) {
                onUpdated && onUpdated(props, AZURE_IOT_CLIENT_ERROR_NOT_ENABLED);
                return;
            }

            if (tooManyRequests) {
                onUpdated && onUpdated(props, AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW);
                return;
            }

            local reqId = _reqNum.tostring();
            local topic = _topics.twinUpd + "?$rid=" + reqId;
            _reqNum++;

            if (typeof props != "table") {
                throw "Properties should be a table";
            }
            local jsonProps = null;
            try {
                jsonProps = http.jsonencode(props);
            } catch (e) {
                _logError("Exception at parsing the properties: " + e);
                onUpdated && onUpdated(props, AZURE_IOT_CLIENT_ERROR_GENERAL);
                return;
            }
            local mqttMsg = _mqttclient.createmessage(topic, jsonProps, _options.qos);

            local msgSentCb = function (err) {
                if (reqId in _twinPendingRequests) {
                    if (err == 0) {
                        _twinPendingRequests[reqId] = [props, onUpdated, time()];
                        if (_processQueueTimer == null) {
                            _processQueueTimer = imp.wakeup(_options.timeout, _processQueue.bindenv(this));
                        }
                    } else {
                        delete _twinPendingRequests[reqId];
                       onUpdated && onUpdated(props, err);
                    }
                }
            }.bindenv(this);

            _twinPendingRequests[reqId] <- [props, onUpdated, null];
            mqttMsg.sendasync(msgSentCb);
        }

        // Enables or disables Azure IoT Hub Direct Methods (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods).
        //
        // Parameters:
        //     onMethod : Function          Callback called every time a direct method is called. null disables the feature.
        //                                  The callback signature:
        //                                  onMethod(name, params), where
        //                                      name : String       Name of the called Direct Method.
        //                                      params : Table      Key-value table with the input parameters of the called Direct Method.
        //                                                          Every key is always a String with the name of the property.
        //                                                          The value is the corresponding value of the property.
        //                                                          Keys and values are fully application specific.
        //     onDone : Function            Callback called when the operation is completed or an error happens.
        //                                  The callback must return an instance of the AzureIoTHub.DirectMethodResponse.
        //          (optional)              The callback signature:
        //                                  onDone(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableDirectMethods(onMethod, onDone = null) {
            local enabled = _onMethodCb != null;
            local disable = onMethod == null;

            if (!_readyToEnable(_isEnablingDMethod, enabled, disable, onDone)) {
                return;
            }

            local doneCb = function (err) {
                if (_dMethodEnabledCb != null) {
                    _dMethodEnabledCb = null;
                    _isEnablingDMethod = false;
                    if (err == 0) {
                        _onMethodCb = onMethod;
                        _ok(onDone);
                    } else {
                        _error(onDone, err);
                    }
                }
            }.bindenv(this);

            local topic = _topics.dMethodNotif + "#";
            _dMethodEnabledCb = onDone;
            _isEnablingDMethod = true;

            if (disable) {
                // Should unsubscribe
                _mqttclient.unsubscribe(topic, doneCb);
            } else {
                // Should send subscribe packet for methods

                local subscribedCb = function (err, qos) {
                    doneCb(err);
                }.bindenv(this);

                _mqttclient.subscribe(topic, _options.qos, subscribedCb);
            }
        }

        // Enables or disables the library debug output. Disabled by default.
        //
        // Parameters:
        //     value : Boolean              true to enable, false to disable
        //
        // Returns:                         Nothing.
        function setDebug(value) {
            _debugEnabled = value;
        }

        // -------------------- PRIVATE METHODS -------------------- //

        function _initTopics(deviceId) {
            _topics = {};
            _topics.msgSend <- format("devices/%s/messages/events/", deviceId);
            _topics.msgRecv <- format("devices/%s/messages/devicebound/", deviceId);
            _topics.twinRecv <- "$iothub/twin/res/";
            _topics.twinGet <- "$iothub/twin/GET/";
            _topics.twinUpd <- "$iothub/twin/PATCH/properties/reported/";
            _topics.twinNotif <- "$iothub/twin/PATCH/properties/desired/";
            _topics.dMethodNotif <- "$iothub/methods/POST/";
            _topics.dMethodResp <- "$iothub/methods/res/";
        }

        function _onConnected(err) {
            if (err == 0) {
                _isConnected = true;
                _isDisconnected = false;
            }
            _isConnecting = false;
            _onConnectedCb(err);
        }

        function _onDisconnected() {
            _log("Disconnected!");
            local reason = _isDisconnecting ? 0 : AZURE_IOT_CLIENT_ERROR_GENERAL;
            _cleanup();
            _onDisconnectedCb && _onDisconnectedCb(reason);
        }

        function _onMessage(msg) {
            local message = null;
            local topic = null;
            try {
                message = msg["message"];
                topic = msg["topic"];
                _log(format("_onMessage: topic=%s | body=%s", topic, message));
            } catch (e) {
                _logError("Could not read message: " + e);
                return;
            }

            // Cloud-to-device message received
            if (topic.find(_topics.msgRecv) != null) {
                _handleCloudToDevMsg(message, topic);
            // Desired properties were updated
            } else if (topic.find(_topics.twinNotif) != null) {
                _handleDesPropsMsg(message, topic);
            // Twin request result received
            } else if (topic.find(_topics.twinRecv) != null) {
                _handleTwinResponse(message, topic);
            // Direct method called
            } else if (topic.find(_topics.dMethodNotif) != null) {
                _handleDirMethodMsg(message, topic);
            }
        }

        function _handleCloudToDevMsg(message, topic) {
            local props = {};
            try {
                local splittedTopic = split(topic, "/");
                if (splittedTopic[splittedTopic.len() - 1] != "devicebound") {
                    // We have properties sent with message
                    props = http.urldecode(splittedTopic[splittedTopic.len() - 1]);
                }
            } catch (e) {
                _logError("Exception at parsing the topic of the message: " + e);
                _logMsg(message, topic);
                return;
            }
            _onMessageCb(AzureIoTHub.Message(message, props));
        }

        function _handleDesPropsMsg(message, topic) {
            // TODO: Check the EI's spec on message receiving
            message = message.tostring();
            local parsedMsg = null;
            try {
                parsedMsg = http.jsondecode(message);
            } catch (e) {
                _logError("Exception at parsing the message: " + e);
                _logMsg(message, topic);
                return;
            }
            _onTwinReqCb(parsedMsg);
        }

        function _handleTwinResponse(message, topic) {
            // TODO: Check the EI's spec on message receiving
            message = message.tostring();
            local status = null;
            local reqId = null;
            local parsedMsg = null;
            try {
                local splitted = split(topic, "/");
                status = splitted[3].tointeger();
                reqId = http.urldecode(splitted[4])["?$rid"];
                if (_statusIsOk(status) && message != null && message != "") {
                    parsedMsg = http.jsondecode(message);
                }
            } catch (e) {
                _logError("Exception at parsing the message: " + e);
                _logMsg(message, topic);
                return;
            }
            // Twin's properties received after UPDATE request
            if (reqId in _twinPendingRequests) {
                _handleTwinUpdateResponse(reqId, status);
            // Twin's properties received after GET request
            } else if (_twinRetrievedCb != null && _twinRetrievedCb[REQ_ID_INDEX] == reqId) {
                _handleTwinGetResponse(reqId, status, parsedMsg);
            } else {
                _log("Message with unknown request ID received: ");
                _logMsg(message, topic);
            }
        }

        function _handleTwinUpdateResponse(reqId, status) {
            local arr = delete _twinPendingRequests[reqId];
            // If no pending requests, cancel the timer
            if (_twinRetrievedCb == null && _twinPendingRequests.len() == 0) {
                imp.cancelwakeup(_processQueueTimer);
                _processQueueTimer = null;
            }
            local props = arr[TWIN_PROPERTIES_INDEX];
            local cb = arr[CALLBACK_INDEX];
            if (_statusIsOk(status)) {
                cb && cb(props, 0);
            } else {
                cb && cb(props, status);
            }
        }

        function _handleTwinGetResponse(reqId, status, parsedMsg) {
            local cb = _twinRetrievedCb[CALLBACK_INDEX];
            _twinRetrievedCb = null;
            // If no pending requests, cancel the timer
            if (_twinPendingRequests.len() == 0) {
                imp.cancelwakeup(_processQueueTimer);
                _processQueueTimer = null;
            }
            if (!_statusIsOk(status)) {
                cb(status, null, null);
                return;
            }
            local repProps = null;
            local desProps = null;
            try {
                repProps = parsedMsg["reported"];
                desProps = parsedMsg["desired"];
            } catch (e) {
                _logError("Exception at parsing the message: " + e);
                return;
            }
            cb(0, repProps, desProps);
        }

        function _handleDirMethodMsg(message, topic) {
            // TODO: Check the EI's spec on message receiving
            message = message.tostring();
            local methodName = null;
            local reqId = null;
            local params = null;

            try {
                methodName = split(topic, "/")[3];
                reqId = split(topic, "=")[1];
                if (message != null && message != "") {
                    params = http.jsondecode(message);
                }
            } catch (e) {
                _logError("Exception at parsing the message: " + e);
                _logMsg(message, topic);
                return;
            }

            local resp = _onMethodCb(methodName, params);
            local topic = _topics.dMethodResp + format("%i/?$rid=%s", resp._status, reqId);

            local respJson = null;
            try {
                respJson = http.jsonencode(resp._body);
            } catch (e) {
                _logError("Exception at parsing the response body for Direct Method: " + e);
                return;
            }
            local mqttMsg = _mqttclient.createmessage(topic, respJson, _options.qos);

            local msgSentCb = function (err) {
                if (err != 0) {
                    _logError("Could not send Direct Method response. Return code = " + err);
                }
            }.bindenv(this);

            mqttMsg.sendasync(msgSentCb);
        }

        function _processQueue() {
            local cb = null;
            local timestamp = null;
            // If _twinRetrievedCb is not null it is guaranteed to be array of length 3
            local isPending = _twinRetrievedCb != null && _twinRetrievedCb[TIMESTAMP_INDEX] != null;

            if (isPending) {
                cb = _twinRetrievedCb[CALLBACK_INDEX];
                timestamp = _twinRetrievedCb[TIMESTAMP_INDEX];
                if (time() - timestamp >= _options.timeout) {
                    _twinRetrievedCb = null;
                    cb(AZURE_IOT_CLIENT_ERROR_OP_TIMED_OUT, null, null);
                }
            }

            foreach (reqId, arr in _twinPendingRequests) {
                local props = arr[TWIN_PROPERTIES_INDEX];
                cb = arr[CALLBACK_INDEX];
                timestamp = arr[TIMESTAMP_INDEX];
                isPending = timestamp != null;
                if (isPending &&
                    (time() - timestamp >= _options.timeout)) {
                    // TODO: Make sure it works correctly
                    delete _twinPendingRequests[reqId];
                    cb && cb(props, AZURE_IOT_CLIENT_ERROR_OP_TIMED_OUT);
                }
            }

            if (_twinRetrievedCb != null || _twinPendingRequests.len() > 0) {
                _processQueueTimer = imp.wakeup(_options.timeout, _processQueue.bindenv(this));
            } else {
                _processQueueTimer = null;
            }
        }

        function _readyToEnable(isEnabling, enabled, disable, callback) {
            if (!_isConnected || _isDisconnecting) {
                _error(callback, _isConnected ? AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
                return false;
            }

            if (isEnabling) {
                _error(callback, AZURE_IOT_CLIENT_ERROR_OP_NOT_ALLOWED_NOW);
                return false;
            }

            if (enabled && !disable) {
                _error(callback, AZURE_IOT_CLIENT_ERROR_ALREADY_ENABLED);
                return false;
            }

            if (disable && !enabled) {
                _error(callback, AZURE_IOT_CLIENT_ERROR_NOT_ENABLED);
                return false;
            }

            return true;
        }

        function _ok(cb) {
            cb && cb(0);
        }

        function _error(cb, err) {
            cb && cb(err);
        }

        function _cleanup() {
            _isDisconnected             = true;
            _isDisconnecting            = false;
            _isConnected                = false;
            _isConnecting               = false;
            _isEnablingMsg              = false;
            _isEnablingTwin             = false;
            _isEnablingDMethod          = false;

            _onMessageCb                = null;
            _onTwinReqCb                = null;
            _onMethodCb                 = null;

            if (_processQueueTimer != null) {
                imp.cancelwakeup(_processQueueTimer);
                _processQueueTimer = null;
            }

            foreach (reqId, arr in _msgPendingQueue) {
                local msg = arr[MESSAGE_INDEX];
                local cb = arr[CALLBACK_INDEX];
                cb && cb(msg, AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
            }
            _msgPendingQueue = {};

            if (_msgEnabledCb != null) {
                _error(_msgEnabledCb, AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
                _msgEnabledCb = null;
            }
            if (_twinEnabledCb != null) {
                _error(_twinEnabledCb, AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
                _twinEnabledCb = null;
            }
            if (_twinRetrievedCb != null) {
                local cb = _twinRetrievedCb[CALLBACK_INDEX];
                _twinRetrievedCb = null;
                cb(AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED, null, null);
            }
            foreach (reqId, arr in _twinPendingRequests) {
                local props = arr[TWIN_PROPERTIES_INDEX];
                local cb = arr[CALLBACK_INDEX];
                cb && cb(props, AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
            }
            _twinPendingRequests = {};
            if (_dMethodEnabledCb != null) {
                _error(_dMethodEnabledCb, AZURE_IOT_CLIENT_ERROR_NOT_CONNECTED);
                _dMethodEnabledCb = null;
            }
        }

        // Check HTTP status
        function _statusIsOk(status) {
            return status / 100 == 2;
        }

        // Metafunction to return class name when typeof <instance> is run
        function _typeof() {
            return "AzureIoTHubMQTTClient";
        }

        function _logMsg(message, topic) {
            local text = format("===BEGIN MQTT MESSAGE===\nTopic: %s\nMessage: %s\n===END MQTT MESSAGE===", topic, message);
            _log(text);
        }

        // Information level logger
        function _log(txt) {
            if (_debugEnabled) {
                server.log("[" + (typeof this) + "] " + txt);
            }
        }

        // Error level logger
        function _logError(txt) {
            if (_debugEnabled) {
                server.error("[" + (typeof this) + "] " + txt);
            }
        }
    }

}
