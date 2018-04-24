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

// TODO: Update the following comment
/* Notes
 *
 * This class implements some of the device-side functionality of the Azure IoT Hub.
 * Useful developer overview of IoT Hub: https://azure.microsoft.com/en-us/documentation/articles/iot-hub-devguide/
 *
 *  Code based on: https://github.com/Azure/azure-iot-sdks/blob/master/node/
 *  HTTP documentation of REST interface: https://msdn.microsoft.com/en-us/library/mt548492.aspx
 *  AMQP implementation for messaging differs from Node SDK
 *  Classes that do not conform to Node SDK are noted
 *
 */

/// Azure AzureIoTHub library

const AZURE_API_VERSION = "2016-11-14";
const AZURE_CLAIM_BASED_SECURITY_PATH = "$cbs";

class AzureIoTHub {

    static VERSION = "3.0.0";

    // Helper Classes modeled after JS/Node SDK
    //------------------------------------------------------------------------------

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

    SharedAccessSignature = class {

        sr = null;
        sig = null;
        skn = null;
        se = null;

        static function create(resourceUri, keyName, key, expiry) {

            // The create method shall create a new instance of SharedAccessSignature with properties: sr, sig, se, and optionally skn.
            local sas = AzureIoTHub.SharedAccessSignature();

            // The sr property shall have the value of resourceUri.
            sas.sr = resourceUri;

            // <signature> shall be an HMAC-SHA256 hash of the value <stringToSign>, which is then base64-encoded.
            // <stringToSign> shall be a concatenation of resourceUri + "\n" + expiry.
            local hash = AzureIoTHub.Authorization.hmacHash(key, AzureIoTHub.Authorization.stringToSign(resourceUri, expiry));

            // The sig property shall be the result of URL-encoding the value <signature>.
            sas.sig = AzureIoTHub.Authorization.encodeUri(hash);

            // If the keyName argument to the create method was falsy, skn shall not be defined.
            // <urlEncodedKeyName> shall be the URL-encoded value of keyName.
            // The skn property shall be the value <urlEncodedKeyName>.
            if (keyName) sas.skn = AzureIoTHub.Authorization.encodeUri(keyName);

            // The se property shall have the value of expiry.
            sas.se = expiry;

            return sas;
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

    Endpoint = class {

        static function devicePath(id) {
            return "/devices/" + id;
        }

        static function eventPath(id) {
            return devicePath(id) + "/messages/events";
        }

        static function messagePath(id) {
            return devicePath(id) + "/messages/devicebound";
        }

        static function versionQueryString() {
            return ("?api-version=" + AZURE_API_VERSION);
        }
    }

    //------------------------------------------------------------------------------

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

    Message = class {

        _body = null;
        // these are application set properties, not the message properties set by azure
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
                    local sas = AzureIoTHub.SharedAccessSignature.create(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow());
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
            local sas = AzureIoTHub.SharedAccessSignature.create(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, AzureIoTHub.Authorization.anHourFromNow());

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

    Client = class {

        static DEFAULT_CLIENT_OPTIONS = {
            "qos" : 0,
            // Timeout for RetrieveTwin and UpdateTwin requests (sec)
            "timeout" : 10,
            // Maximum amount of parallel UpdateTwin requests
            "twinUpdParallelReqs" : 3,
            // Maximum amount of parallel SendMessage requests
            "sendMsgParallelReqs" : 3
        };

        static S_DISCONNECTED       = 1;
        static S_DISCONNECTING      = 2;
        static S_CONNECTED          = 4;
        static S_CONNECTING         = 8;
        static S_ENABLING_MSG       = 1024;
        static S_ENABLING_TWIN      = 2048;
        static S_ENABLING_METH      = 4096;
        static S_DISABLING_MSG      = 131072;
        static S_DISABLING_TWIN     = 262144;
        static S_DISABLING_METH     = 524288;

        static E_NOT_CONNECTED      = 1000;
        static E_ALREADY_CONNECTED  = 1001;
        static E_NOT_ENABLED        = 1002;
        static E_ALREADY_ENABLED    = 1003;
        static E_OP_NOT_ALLOWED_NOW = 1004;
        static E_OP_TIMED_OUT       = 1005;
        static E_GENERAL            = 1010;

        _debugEnabled               = false;

        _connStrParsed              = null;
        _options                    = null;
        _mqttclient                 = null;
        _state                      = null;
        _topics                     = null;

        // Long term user callbacks. Like onReceive, onRequest, onMethod
        _onConnectCb                = null;
        _onDisconnectCb             = null;
        _onMessageCb                = null;
        _onTwinReqCb                = null;
        _onMethodCb                 = null;

        // Short term user callbacks. Like onComplete, onRetrieve
        // User can send several messages in parallel, so we need a map reqId -> <callback>
        _msgSentCbMap               = {};
        _msgEnabledCb               = null;
        _twinEnabledCb              = null;
        // Contains [<reqId>, <callback>, <timer>] or null
        _twinRetrCb                 = null;
        // User can update twin several times in parallel, so we need a map reqId -> [<callback>, <timer>]
        _twinUpdCbMap               = {};
        _methEnabledCb              = null;

        _reqNum                     = 0;


        // MQTT Client class constructor.
        //
        // Parameters:
        //     deviceConnStr : String       Device connection string: includes the host name to connect, the device Id and the shared access string.
        //                                  It can be obtained from the Azure Portal.
        //                                  However, if the device was registered using the AzureIoTHub.Registry class,
        //                                  the deviceConnectionString parameter can be retrieved from the AzureIoTHub.Device instance passed
        //                                  to the AzureIoTHub.Registry.get() or AzureIoTHub.Registry.create() method callbacks.
        //                                  For more guidance, please see the AzureIoTHub.registry example (README.md).
        //     onConnect : Function         Callback called every time the device is connected.
        //                                  The callback signature:
        //                                  onConnect(error), where
        //                                      error : Integer     0 if the connection is successful, an error code otherwise.
        //     onDisconnect : Function      Callback called every time the device is disconnected
        //          (optional)              The callback signature:
        //                                  onDisconnect(error), where
        //                                      error : Integer     0 if the disconnection was caused by the disconnect() method,
        //                                                          an error code which explains a reason of the disconnection otherwise.
        //     options : Table              Key-value table with optional settings.
        //          (optional)
        //
        // Returns:                         AzureIoTHub.Client instance created.
        constructor(deviceConnStr, onConnect, onDisconnect = null, options = {}) {
            _state = S_DISCONNECTED;
            _options = DEFAULT_CLIENT_OPTIONS;

            _onConnectCb      = onConnect;
            _onDisconnectCb   = onDisconnect;

            _connStrParsed = AzureIoTHub.ConnectionString.Parse(deviceConnStr);
            _mqttclient = mqtt.createclient();
            _mqttclient.onconnect(_onConnect.bindenv(this));
            _mqttclient.onconnectionlost(_onDisconnect.bindenv(this));
            _mqttclient.onmessage(_onMessage.bindenv(this));

            foreach (optName, optVal in options) {
                _options[optName] <- optVal;
            }

            _fillTopics(_connStrParsed.DeviceId);
        }

        // Opens a connection to Azure IoT Hub.
        //
        // Returns:                         Nothing.
        function connect() {
            if (_state == S_DISCONNECTED) {
                _log("Connecting...");

                local devPath = "/" + _connStrParsed.DeviceId;
                local username = _connStrParsed.HostName + devPath + format("/api-version=%s", AZURE_API_VERSION);
                local resourcePath = "/devices" + devPath + format("/api-version=%s", AZURE_API_VERSION);
                local resourceUri = AzureIoTHub.Authorization.encodeUri(_connStrParsed.HostName + resourcePath);
                local passwDeadTime = AzureIoTHub.Authorization.anHourFromNow();
                local sas = AzureIoTHub.SharedAccessSignature.create(
                    resourceUri, null, _connStrParsed.SharedAccessKey, passwDeadTime).toString();

                local options = {
                    "username" : username,
                    "password" : sas
                };

                local url = "ssl://" + _connStrParsed.HostName;

                _state =  S_DISCONNECTED | S_CONNECTING;

                _mqttclient.connect(url, _connStrParsed.DeviceId, options);
            } else {
                try {
                    // We are connected or connecting now
                    // TODO: Should we call this one and next all callbacks with imp.wakeup?
                    _onConnectCb(_state & S_CONNECTED ? E_ALREADY_CONNECTED : E_OP_NOT_ALLOWED_NOW);
                } catch (e) {
                    _error("Exception at onConnect user callback: " + e);
                }
            }
        }

        // Closes the connection to Azure IoT Hub. Does nothing if the connection is already closed.
        //
        // Returns:                         Nothing.
        function disconnect() {
            if (_state != S_DISCONNECTED && !(_state & S_DISCONNECTING)) {
                _state = _state | S_DISCONNECTING;
                _mqttclient.disconnect(_onDisconnect.bindenv(this));
            }
        }

        // Checks if the client is connected to Azure IoT Hub.
        //
        // Returns:                         Boolean: true if the client is connected, false otherwise.
        function isConnected() {
            return _state & S_CONNECTED > 0;
        }

        // Sends a message to Azure IoT Hub (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages).
        //
        // Parameters:
        //     msg : AzureIoTHub.Message    Message to send.
        //     onComplete : Function        Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onComplete(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function sendMessage(msg, onComplete = null) {
            if ((_state & S_CONNECTED) && !(_state & S_DISCONNECTING)) {
                if (_msgSentCbMap.len() >= _options.sendMsgParallelReqs) {
                    _callOnComplete(onComplete, E_OP_NOT_ALLOWED_NOW);
                    return;
                }
                // TODO: http.urlencode follows RFC3986, but Azure expects RFC2396 string. Should we worry about it?
                local props = http.urlencode(msg.getProperties());
                local topic = _topics.msgSend + props;
                local reqId = _reqNum;
                _reqNum++;

                local mqttMsg = _mqttclient.createmessage(topic, msg.getBody(), _options.qos);

                local callback = function (rc) {
                    if (reqId in _msgSentCbMap) {
                        delete _msgSentCbMap[reqId];
                        // TODO: What should we pass to onComplete?
                        _callOnComplete(onComplete, rc);
                    }
                }.bindenv(this);

                _msgSentCbMap[reqId] <- onComplete;
                mqttMsg.sendasync(callback);
            } else {
                local err = _state & S_CONNECTED ? E_OP_NOT_ALLOWED_NOW : E_NOT_CONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        // Enables or disables message receiving from Azure IoT Hub (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#receiving-cloud-to-device-messages).
        //
        // Parameters:
        //     onReceive : Function         Callback called every time a new message is received. null disables the feature.
        //                                  The callback signature:
        //                                  onReceive(message), where
        //                                      message :           Received message.
        //                                          AzureIoTHub.Message
        //     onComplete : Function        Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onComplete(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableMessageReceiving(onReceive, onComplete = null){
            if ((_state & S_CONNECTED) && !(_state & S_DISCONNECTING)) {
                if (_state & (S_ENABLING_MSG | S_DISABLING_MSG)) {
                    _callOnComplete(onComplete, E_OP_NOT_ALLOWED_NOW);
                } else if (_onMessageCb != null && onReceive == null) {
                    // Should unsubscribe
                    // TODO: Make sure we have successfully unsubscribed
                    // TODO: Handle the case with disconnection when unsubscribing
                    // TODO: Will be done once EI make callback for unsubscribe method
                    _state = _state ^ S_DISABLING_MSG;
                    _mqttclient.unsubscribe(_topics.msgRecv + "#");
                    _onMessageCb = null;
                    _state = _state ^ S_DISABLING_MSG;
                    _callOnComplete(onComplete, 0);
                } else if (_onMessageCb != null) {
                    // Already subscribed
                    _callOnComplete(onComplete, E_ALREADY_ENABLED);
                } else if (onReceive == null) {
                    // Already disabled
                    _callOnComplete(onComplete, E_NOT_ENABLED);
                } else {
                    // Should send subscribe packet
                    local topic = _topics.msgRecv + "#";

                    local callback = function (rc, qos) {
                        if (_msgEnabledCb != null) {
                            if (rc == 0) {
                                _onMessageCb = onReceive;
                            }
                            _msgEnabledCb = null;
                            _state = _state ^ S_ENABLING_MSG;
                            // TODO: What should we pass to onComplete?
                            _callOnComplete(onComplete, rc);
                        }
                    }.bindenv(this);

                    _msgEnabledCb = onComplete;
                    _state = _state ^ S_ENABLING_MSG;
                    _mqttclient.subscribe(topic, _options.qos, callback);
                }
            } else {
                local err = _state & S_CONNECTED ? E_OP_NOT_ALLOWED_NOW : E_NOT_CONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        // Enables or disables Azure IoT Hub Device Twins functionality (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins).
        //
        // Parameters:
        //     onRequest : Function         Callback called every time a new request with desired Device Twin properties is received. null disables the feature.
        //                                  The callback signature:
        //                                  onRequest(version, props), where
        //                                      version : Integer   Version of the Device Twin document which corresponds to the desired properties.
        //                                                          The version is always incremented by Azure IoT Hub when the document is updated.
        //                                      props : Table       Key-value table with the desired properties.
        //                                                          Every key is always a String with the name of the property.
        //                                                          The value is the corresponding value of the property.
        //                                                          Keys and values are fully application specific.
        //     onComplete : Function        Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onComplete(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableTwin(onRequest, onComplete = null) {
            if ((_state & S_CONNECTED) && !(_state & S_DISCONNECTING)) {
                if (_state & (S_ENABLING_TWIN | S_DISABLING_TWIN)) {
                    _callOnComplete(onComplete, E_OP_NOT_ALLOWED_NOW);
                } else if (_onTwinReqCb != null && onRequest == null) {
                    // Should unsubscribe
                    // TODO: Make sure we have successfully unsubscribed
                    // TODO: Handle the case with disconnection when unsubscribing
                    // TODO: Will be done once EI make callback for unsubscribe method
                    _state = _state ^ S_DISABLING_TWIN;
                    _mqttclient.unsubscribe(_topics.twinNotif + "#");
                    _mqttclient.unsubscribe(_topics.twinRecv + "#");
                    _onTwinReqCb = null;
                    _state = _state ^ S_DISABLING_TWIN;
                    _callOnComplete(onComplete, 0);
                } else if (_onTwinReqCb != null) {
                    // Already subscribed
                    _callOnComplete(onComplete, E_ALREADY_ENABLED);
                } else if (onRequest == null) {
                    // Already disabled
                    _callOnComplete(onComplete, E_NOT_ENABLED);
                } else {
                    // Should send subscribe packet for notifications and GET

                    local callback2 = function (rc, qos) {
                        if (_twinEnabledCb =! null) {
                            if (rc == 0) {
                                _onTwinReqCb = onRequest;
                            }
                            _twinEnabledCb = null;
                            _state = _state ^ S_ENABLING_TWIN;
                            // TODO: What should we pass to onComplete?
                            _callOnComplete(onComplete, rc);
                        }
                    }.bindenv(this);

                    local callback1 = function (rc, qos) {
                        if (_twinEnabledCb != null) {
                            if (rc == 0) {
                                local topic = _topics.twinRecv + "#";
                                _mqttclient.subscribe(topic, _options.qos, callback2);
                            } else {
                                _twinEnabledCb = null;
                                _state = _state ^ S_ENABLING_TWIN;
                                // TODO: What should we pass to onComplete?
                                _callOnComplete(onComplete, rc);
                            }
                        }
                    }.bindenv(this);

                    local topic = _topics.twinNotif + "#";
                    _twinEnabledCb = onComplete;
                    _state = _state ^ S_ENABLING_TWIN;
                    _mqttclient.subscribe(topic, _options.qos, callback1);
                }
            } else {
                local err = _state & S_DISCONNECTING ? E_OP_NOT_ALLOWED_NOW : E_NOT_CONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        // Retrieves Device Twin properties (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#retrieving-a-device-twins-properties).
        //
        // Parameters:
        //     onRetrieve : Function        Callback called when the properties are retrieved.
        //                                  The callback signature:
        //                                  onRetrieve(error, reportedProps, desiredProps), where
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
        function retrieveTwinProperties(onRetrieve) {
            if ((_state & S_CONNECTED) && !(_state & S_DISCONNECTING) && _onTwinReqCb != null) {
                // Only one retrieve operation at a time is allowed
                if (_twinRetrCb != null) {
                    try {
                        onRetrieve(E_OP_NOT_ALLOWED_NOW, null, null);
                    } catch (e) {
                        _error("Exception at onRetrieve user callback: " + e);
                    }
                    return;
                }
                local reqId = _reqNum.tostring();
                local topic = _topics.twinGet + "?$rid=" + reqId;
                _reqNum++;

                local mqttMsg = _mqttclient.createmessage(topic, "", _options.qos);

                local callback = function (rc) {
                    if (_twinRetrCb != null) {
                        if (rc == 0) {
                            local timer = imp.wakeup(_options.timeout, function () {
                                if (_twinRetrCb == null) {
                                    return;
                                }
                                _twinRetrCb = null;
                                try {
                                    onRetrieve(E_OP_TIMED_OUT, null, null);
                                } catch (e) {
                                    _error("Exception at onRetrieve user callback: " + e);
                                }
                            }.bindenv(this));
                            _twinRetrCb = [reqId, onRetrieve, timer];
                        } else {
                            try {
                                _twinRetrCb = null;
                                // TODO: What should we pass to onRetrieve?
                                onRetrieve(rc, null, null);
                            } catch (e) {
                                _error("Exception at onRetrieve user callback: " + e);
                            }
                        }
                    }
                }.bindenv(this);

                _twinRetrCb = [reqId, onRetrieve, null];
                mqttMsg.sendasync(callback);
            } else {
                local err = null;
                if (_onTwinReqCb == null) {
                    err = E_NOT_ENABLED;
                } else {
                    // We are disconnected or disconnecting now
                    err = _state & S_DISCONNECTING ? E_OP_NOT_ALLOWED_NOW : E_NOT_CONNECTED;
                }
                try {
                    onRetrieve(err, null, null);
                } catch (e) {
                    _error("Exception at onRetrieve user callback: " + e);
                }
            }
        }

        // Updates Device Twin reported properties (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#update-device-twins-reported-properties).
        //
        // Parameters:
        //     props : Table                Key-value table with the desired properties.
        //                                  Every key is always a String with the name of the property.
        //                                  The value is the corresponding value of the property.
        //                                  Keys and values are fully application specific.
        //     onComplete : Function        Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onComplete(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function updateTwinProperties(props, onComplete = null) {
            if ((_state & S_CONNECTED) && !(_state & S_DISCONNECTING) && _onTwinReqCb != null) {
                if (_twinUpdCbMap.len() >= _options.twinUpdParallelReqs) {
                    _callOnComplete(onComplete, E_OP_NOT_ALLOWED_NOW);
                    return;
                }
                local reqId = _reqNum.tostring();
                local topic = _topics.twinUpd + "?$rid=" + reqId;
                _reqNum++;

                local mqttMsg = _mqttclient.createmessage(topic, http.jsonencode(props), _options.qos);

                local callback = function (rc) {
                    if (reqId in _twinUpdCbMap) {
                        if (rc == 0) {
                            local timer = imp.wakeup(_options.timeout, function () {
                                if (!(reqId in _twinUpdCbMap)) {
                                    return;
                                }
                                delete _twinUpdCbMap[reqId];
                                _callOnComplete(onComplete, E_OP_TIMED_OUT);
                            }.bindenv(this));
                            _twinUpdCbMap[reqId] = [onComplete, timer];
                        } else {
                            delete _twinUpdCbMap[reqId];
                            // TODO: What should we pass to onComplete?
                           _callOnComplete(onComplete, rc);
                        }
                    }
                }.bindenv(this);

                _twinUpdCbMap[reqId] <- [onComplete, null];
                mqttMsg.sendasync(callback);
            } else {
                local err = null;
                if (_onTwinReqCb == null) {
                    err = E_NOT_ENABLED;
                } else {
                    // We are disconnected or disconnecting now
                    err = _state & S_DISCONNECTING ? E_OP_NOT_ALLOWED_NOW : E_NOT_CONNECTED;
                }
                _callOnComplete(onComplete, err);
            }
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
        //     onComplete : Function        Callback called when the operation is completed or an error happens.
        //                                  The callback must return an instance of the AzureIoTHub.DirectMethodResponse.
        //          (optional)              The callback signature:
        //                                  onComplete(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableDirectMethods(onMethod, onComplete = null) {
            if ((_state & S_CONNECTED) && !(_state & S_DISCONNECTING)) {
                if (_state & (S_ENABLING_METH | S_DISABLING_METH)) {
                    _callOnComplete(onComplete, E_OP_NOT_ALLOWED_NOW);
                } else if (_onMethodCb != null && onMethod == null) {
                    // Should unsubscribe
                    // TODO: Make sure we have successfully unsubscribed
                    // TODO: Handle the case with disconnection when unsubscribing
                    // TODO: Will be done once EI make callback for unsubscribe method
                    _state = _state ^ S_DISABLING_METH;
                    _mqttclient.unsubscribe(_topics.methNotif + "#");
                    _onMethodCb = null;
                    _state = _state ^ S_DISABLING_METH;
                    _callOnComplete(onComplete, 0);
                } else if (_onMethodCb != null) {
                    // Already subscribed
                    _callOnComplete(onComplete, E_ALREADY_ENABLED);
                } else if (onMethod == null) {
                    // Already disabled
                    _callOnComplete(onComplete, E_NOT_ENABLED);
                } else {
                    // Should send subscribe packet for methods

                    local callback = function (rc, qos) {
                        if (_methEnabledCb != null) {
                            if (rc == 0) {
                                _onMethodCb = onMethod;
                            }
                            _methEnabledCb = null;
                            _state = _state ^ S_ENABLING_METH;
                            // TODO: What should we pass to onComplete?
                            _callOnComplete(onComplete, rc);
                        }
                    }.bindenv(this);

                    local topic = _topics.methNotif + "#";

                    _methEnabledCb = onComplete;
                    _state = _state ^ S_ENABLING_METH;
                    _mqttclient.subscribe(topic, _options.qos, callback);
                }
            } else {
                local err = _state & S_DISCONNECTING ? E_OP_NOT_ALLOWED_NOW : E_NOT_CONNECTED;
                _callOnComplete(onComplete, err);
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

        function _fillTopics(deviceId) {
            _topics = {};
            _topics.msgSend <- format("devices/%s/messages/events/", deviceId);
            _topics.msgRecv <- format("devices/%s/messages/devicebound/", deviceId);
            _topics.twinRecv <- "$iothub/twin/res/";
            _topics.twinGet <- "$iothub/twin/GET/";
            _topics.twinUpd <- "$iothub/twin/PATCH/properties/reported/";
            _topics.twinNotif <- "$iothub/twin/PATCH/properties/desired/";
            _topics.methNotif <- "$iothub/methods/POST/";
            _topics.methResp <- "$iothub/methods/res/";
        }

        function _onConnect(rc) {
            _log("_onConnect: " + rc);
            _state = rc == 0 ? S_CONNECTED : S_DISCONNECTED;
            try {
                // TODO: What should we pass to _onConnectCb?
                _onConnectCb(rc);
            } catch (e) {
                _error("Exception at onConnect user callback: " + e);
            }
        }

        function _onDisconnect() {
            _log("Disconnected!");
            local reason = _state & S_DISCONNECTING ? 0 : E_GENERAL;
            _cleanup();
            if (_onDisconnectCb != null) {
                try {
                    _onDisconnectCb(reason);
                } catch (e) {
                    _error("Exception at onDisconnect user callback: " + e);
                }
            }
        }

        function _onMessage(msg) {
            local message = null;
            local topic = null;
            try {
                message = msg["message"];
                topic = msg["topic"];
                _log(format("_onMessage: topic=%s | body=%s", topic, message));
            } catch (e) {
                _error("Could not read message: " + e);
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
                _handleTwinReqResMsg(message, topic);
            // Direct method called
            } else if (topic.find(_topics.methNotif) != null) {
                _handleDirMethMsg(message, topic);
            }
        }

        function _handleCloudToDevMsg(message, topic) {
            local props = {};
            local splittedTopic = split(topic, "/");
            if (splittedTopic[splittedTopic.len() - 1] != "devicebound") {
                // We have properties sent with message
                props = http.urldecode(splittedTopic[splittedTopic.len() - 1]);
            }
            try {
                _onMessageCb(AzureIoTHub.Message(message, props));
            } catch (e) {
                _error("Exception at onReceive user callback: " + e);
            }
        }

        function _handleDesPropsMsg(message, topic) {
            local version = null;
            local parsedMsg = null;
            try {
                version = split(topic, "=")[1];
                parsedMsg = http.jsondecode(message);
            } catch (e) {
                _error("Exception at parsing the message: " + e);
                _logMsg(message, topic);
                return;
            }
            try {
                _onTwinReqCb(version, parsedMsg);
            } catch (e) {
                _error("Exception at onRequest user callback: " + e);
            }
        }

        function _handleTwinReqResMsg(message, topic) {
            local status = null;
            local reqId = null;
            local parsedMsg = null;
            try {
                local splitted = split(topic, "/");
                status = splitted[3].tointeger();
                reqId = http.urldecode(splitted[4])["?$rid"];
                if (_statusIsOk(status) && message != "") {
                    parsedMsg = http.jsondecode(message);
                }
            } catch (e) {
                _error("Exception at parsing the message: " + e);
                _logMsg(message, topic);
                return;
            }
            // Twin's properties received after UPDATE request
            if (reqId in _twinUpdCbMap) {
                local cb = _twinUpdCbMap[reqId][0];
                local timer = _twinUpdCbMap[reqId][1];
                delete _twinUpdCbMap[reqId];
                imp.cancelwakeup(timer);
                _callOnComplete(cb, _statusIsOk(status) ? 0 : status);
            // Twin's properties received after GET request
            } else if (_twinRetrCb != null && _twinRetrCb[0] == reqId) {
                local cb = _twinRetrCb[1];
                local timer = _twinRetrCb[2];
                _twinRetrCb = null;
                imp.cancelwakeup(timer);
                if (!_statusIsOk(status)) {
                    try {
                        cb(status, null, null);
                    } catch (e) {
                        _error("Exception at onRetrieve user callback: " + e);
                    }
                    return;
                }
                local repProps = null;
                local desProps = null;
                try {
                    repProps = parsedMsg["reported"];
                    desProps = parsedMsg["desired"];
                } catch (e) {
                    _error("Exception at parsing the message: " + e);
                    _logMsg(message, topic);
                    return;
                }
                try {
                    cb(0, repProps, desProps);
                } catch (e) {
                    _error("Exception at onRetrieve user callback: " + e);
                }
            } else {
                _log("Message with unknown request ID recceived: ");
                _logMsg(message, topic);
            }
        }

        function _handleDirMethMsg(message, topic) {
            local methodName = null;
            local reqId = null;
            local params = null;

            try {
                methodName = split(topic, "/")[3];
                reqId = split(topic, "=")[1];
                params = http.jsondecode(message);
            } catch (e) {
                _error("Exception at parsing the message: " + e);
                _logMsg(message, topic);
                return;
            }

            local resp = null;
            try {
                resp = _onMethodCb(methodName, params);
            } catch (e) {
                _error("Exception at onMethod user callback: " + e);
                return;
            }
            local topic = _topics.methResp + format("%i/?$rid=%s", resp._status, reqId);

            local mqttMsg = _mqttclient.createmessage(topic, http.jsonencode(resp._body), _options.qos);

            local callback = function (rc) {
                if (rc != 0) {
                    _error("Could not send Direct Method response. Return code = " + rc);
                }
            }.bindenv(this);

            mqttMsg.sendasync(callback);
        }

        function _callOnComplete(cb, err) {
            if (cb != null) {
                try {
                    cb(err);
                } catch (e) {
                    _error("Exception at onComplete user callback: " + e);
                }
            }
        }

        function _cleanup() {
            _state = S_DISCONNECTED;
            _onMessageCb                = null;
            _onTwinReqCb                = null;
            _onMethodCb                 = null;

            foreach (reqId, cb in _msgSentCbMap) {
                // TODO: Should we use imp.wakeup here?
                _callOnComplete(cb, E_NOT_CONNECTED);
            }
            // TODO: Is it ok? Or we should delete every slot of this map
            _msgSentCbMap = {};

            if (_msgEnabledCb != null) {
                // TODO: Should we use imp.wakeup here?
                _callOnComplete(_msgEnabledCb, E_NOT_CONNECTED);
                _msgEnabledCb = null;
            }
            if (_twinEnabledCb != null) {
                // TODO: Should we use imp.wakeup here?
                _callOnComplete(_twinEnabledCb, E_NOT_CONNECTED);
                _twinEnabledCb = null;
            }
            if (_twinRetrCb != null) {
                local cb = _twinRetrCb[1];
                local timer = _twinRetrCb[2];
                _twinRetrCb = null;
                if (timer != null) {
                    imp.cancelwakeup(timer);
                }
                try {
                    // TODO: Should we use imp.wakeup here?
                    cb(E_NOT_CONNECTED, null, null);
                } catch (e) {
                    _error("Exception at onRetrieve user callback: " + e);
                }
            }
            foreach (reqId, arr in _twinUpdCbMap) {
                local cb = arr[0];
                local timer = arr[1];
                if (timer != null) {
                    imp.cancelwakeup(timer);
                }
                // TODO: Should we use imp.wakeup here?
                _callOnComplete(cb, E_NOT_CONNECTED);
            }
            // TODO: Is it ok? Or we should delete every slot of this map
            _twinUpdCbMap = {};
            if (_methEnabledCb != null) {
                // TODO: Should we use imp.wakeup here?
                _callOnComplete(_methEnabledCb, E_NOT_CONNECTED);
                _methEnabledCb = null;
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
            _log("===BEGIN MQTT MESSAGE===");
            _log("Topic: " + message);
            _log("Message: " + topic);
            _log("===END MQTT MESSAGE===");
        }

        // Information level logger
        function _log(txt) {
            if (_debugEnabled) {
                server.log("[" + (typeof this) + "] " + txt);
            }
        }

        // Error level logger
        function _error(txt) {
            server.error("[" + (typeof this) + "] " + txt);
        }
    }

}
