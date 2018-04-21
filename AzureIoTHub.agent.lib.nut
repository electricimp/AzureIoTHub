// MIT License
//
// Copyright 2015-2017 Electric Imp
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
// THE SOFTWARE IS PROVIDED &quot;AS IS&quot;, WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

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

    static VERSION = "2.1.0";

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

    Delivery = class {

        _delivery = null;

        constructor(amqpDelivery) {
            _delivery = amqpDelivery;
        }

        function complete() {
            _delivery.accept();
        }

        function abandon() {
            _delivery.release();
        }

        function reject() {
            _delivery.reject();
        }

        function getMessage() {
            local msg = _delivery.message();
            return AzureIoTHub.Message(msg.body(), msg.properties());
        }

        function _typeof() {
            return "delivery";
        }
    }

    DirectMethodResponse = class {
        _status = null;
        _body   = null;

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

        static DEFAULT_CLIENT_OPTIONS = {"qos" : 0};

        static SDISCONNECTED        = 1;
        static SDISCONNECTING       = 2;
        static SCONNECTED           = 4;
        static SCONNECTING          = 8;
        static SENABLINGMSG         = 1024;
        static SENABLINGTWIN        = 2048;
        static SENABLINGMETH        = 4096;
        static SDISABLINGMSG        = 1048576;
        static SDISABLINGTWIN       = 2097152;
        static SDISABLINGMETH       = 4194304;

        static ENOTCONNECTED        = 1000;
        static EALREADYCONNECTED    = 1001;
        static ENOTENABLED          = 1002;
        static EALREADYENABLED      = 1003;
        static EGENERAL             = 1004;
        static EOPNOTALLOWEDNOW     = 1005;

        static RETRIEVE_REQ_TYPE    = 0;
        static UPDATE_REQ_TYPE      = 1;

        _debugEnabled               = true;

        _connStrParsed              = null;
        _options                    = null;
        _mqttclient                 = null;
        _state                      = null;
        _topics                     = null;

        _onConnectCb                = null;
        _onDisconnectCb             = null;
        _onMessageCb                = null;
        _onTwinReqCb                = null;
        _onMethodCb                 = null;

        _reqNum                     = 0;
        // Map reqID -> [<request type>, <callback>]
        // TODO: How to clean this table sometimes?
        _reqCbMap                   = {};

        constructor(deviceConnStr, onConnect, onDisconnect = null, options = {}) {
            _state = SDISCONNECTED;
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

        function connect() {
            if (_state == SDISCONNECTED) {
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

                _state =  SDISCONNECTED | SCONNECTING;

                _mqttclient.connect(url, _connStrParsed.DeviceId, options);
            } else {
                try {
                    // We are connected or connecting now
                    _onConnectCb(_state & SCONNECTED ? EALREADYCONNECTED : EOPNOTALLOWEDNOW);
                } catch (e) {
                    _error("Exception at onConnect user callback: " + e);
                }
            }
        }

        function disconnect() {
            // TODO: What if we are connecting or enabling some feature now?
            if (!(_state & (SDISCONNECTED | SDISCONNECTING | SCONNECTING))) {
                _state = _state | SDISCONNECTING;
                _mqttclient.disconnect(_onDisconnect.bindenv(this));
            }
        }

        function isConnected() {
            return _state & SCONNECTED > 0;
        }

        function sendMessage(msg, onComplete = null) {
            if ((_state & SCONNECTED) && !(_state & SDISCONNECTING)) {
                // TODO: http.urlencode follows RFC3986, but Azure expects RFC2396 string. Should we worry about it?
                local props = http.urlencode(msg.getProperties());
                local topic = _topics.msgSend + props;

                local mqttMsg = _mqttclient.createmessage(topic, msg.getBody(), _options.qos);

                local callback = function (rc) {
                    // TODO: What should we pass to onComplete?
                    _callOnComplete(onComplete, rc);
                }.bindenv(this);

                mqttMsg.sendasync(callback);
            } else {
                local err = _state & SCONNECTED ? EOPNOTALLOWEDNOW : ENOTCONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        function enableMessageReceiving(onReceive, onComplete = null){
            if ((_state & SCONNECTED) && !(_state & SDISCONNECTING)) {
                if (_state & (SENABLINGMSG | SDISABLINGMSG)) {
                    _callOnComplete(onComplete, EOPNOTALLOWEDNOW);
                } else if (_onMessageCb != null && onReceive == null) {
                    // Should unsubscribe
                    // TODO: Make sure we have successfully unsubscribed
                    _state = _state ^ SDISABLINGMSG;
                    _mqttclient.unsubscribe(_topics.msgRecv + "#");
                    _onMessageCb = null;
                    _state = _state ^ SDISABLINGMSG;
                    _callOnComplete(onComplete, 0);
                } else if (_onMessageCb != null) {
                    // Already subscribed
                    _callOnComplete(onComplete, EALREADYENABLED);
                } else if (onReceive == null) {
                    // Already disabled
                    _callOnComplete(onComplete, ENOTENABLED);
                } else {
                    // Should send subscribe packet
                    local topic = _topics.msgRecv + "#";

                    local callback = function (rc, qos) {
                        if (rc == 0) {
                            _log("SETTING _onMessageCb");
                            _onMessageCb = onReceive;
                        }
                        _state = _state ^ SENABLINGMSG;
                        // TODO: What should we pass to onComplete?
                        _callOnComplete(onComplete, rc);
                    }.bindenv(this);

                    _state = _state ^ SENABLINGMSG;
                    _mqttclient.subscribe(topic, _options.qos, callback);
                }
            } else {
                local err = _state & SCONNECTED ? EOPNOTALLOWEDNOW : ENOTCONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        function enableTwin(onRequest, onComplete = null) {
            if ((_state & SCONNECTED) && !(_state & SDISCONNECTING)) {
                if (_state & (SENABLINGTWIN | SDISABLINGTWIN)) {
                    _callOnComplete(onComplete, EOPNOTALLOWEDNOW);
                } else if (_onTwinReqCb != null && onRequest == null) {
                    // Should unsubscribe
                    // TODO: Make sure we have successfully unsubscribed
                    _state = _state ^ SDISABLINGTWIN;
                    _mqttclient.unsubscribe(_topics.twinNotif + "#");
                    _mqttclient.unsubscribe(_topics.twinRecv + "#");
                    _onTwinReqCb = null;
                    _state = _state ^ SDISABLINGTWIN;
                    _callOnComplete(onComplete, 0);
                } else if (_onTwinReqCb != null) {
                    // Already subscribed
                    _callOnComplete(onComplete, EALREADYENABLED);
                } else if (onRequest == null) {
                    // Already disabled
                    _callOnComplete(onComplete, ENOTENABLED);
                } else {
                    // Should send subscribe packet for notifications and GET

                    local callback2 = function (rc, qos) {
                        if (rc == 0) {
                            _log("SETTING _onTwinReqCb");
                            _onTwinReqCb = onRequest;
                        }
                        _state = _state ^ SENABLINGTWIN;
                        // TODO: What should we pass to onComplete?
                        _callOnComplete(onComplete, rc);
                    }.bindenv(this);

                    local callback1 = function (rc, qos) {
                        if (rc == 0) {
                            local topic = _topics.twinRecv + "#";
                            _mqttclient.subscribe(topic, _options.qos, callback2);
                        } else {
                            _state = _state ^ SENABLINGTWIN;
                            _callOnComplete(onComplete, rc);
                        }
                    }.bindenv(this);

                    local topic = _topics.twinNotif + "#";
                    _state = _state ^ SENABLINGTWIN;
                    _mqttclient.subscribe(topic, _options.qos, callback1);
                }
            } else {
                local err = _state & SDISCONNECTING ? EOPNOTALLOWEDNOW : ENOTCONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        function retrieveTwinProperties(onRetrieve) {
            if ((_state & SCONNECTED) && !(_state & SDISCONNECTING) && _onTwinReqCb != null) {
                local reqId = _reqNum.tostring();
                local topic = _topics.twinGet + "?$rid=" + reqId;
                _reqNum++;

                local mqttMsg = _mqttclient.createmessage(topic, "", _options.qos);

                local callback = function (rc) {
                    if (rc == 0) {
                        _reqCbMap[reqId] <- [RETRIEVE_REQ_TYPE, onRetrieve];
                    } else {
                       try {
                            // TODO: What should we pass to onRetrieve?
                            onRetrieve(rc, null, null);
                        } catch (e) {
                            _error("Exception at onRetrieve user callback: " + e);
                        }
                    }
                }.bindenv(this);

                mqttMsg.sendasync(callback);
            } else {
                local err = null;
                if (_onTwinReqCb == null) {
                    err = ENOTENABLED;
                } else {
                    // We are disconnected or disconnecting now
                    err = _state & SDISCONNECTING ? EOPNOTALLOWEDNOW : ENOTCONNECTED;
                }
                try {
                    onRetrieve(err, null, null);
                } catch (e) {
                    _error("Exception at onRetrieve user callback: " + e);
                }
            }
        }

        function updateTwinProperties(props, onComplete = null) {
            if ((_state & SCONNECTED) && !(_state & SDISCONNECTING) && _onTwinReqCb != null) {
                local reqId = _reqNum.tostring();
                local topic = _topics.twinUpd + "?$rid=" + reqId;
                _reqNum++;

                local mqttMsg = _mqttclient.createmessage(topic, http.jsonencode(props), _options.qos);

                local callback = function (rc) {
                    if (rc == 0) {
                        _reqCbMap[reqId] <- [UPDATE_REQ_TYPE, onComplete];
                    } else {
                        // TODO: What should we pass to onComplete?
                       _callOnComplete(onComplete, rc);
                    }
                }.bindenv(this);

                mqttMsg.sendasync(callback);
            } else {
                local err = null;
                if (_onTwinReqCb == null) {
                    err = ENOTENABLED;
                } else {
                    // We are disconnected or disconnecting now
                    err = _state & SDISCONNECTING ? EOPNOTALLOWEDNOW : ENOTCONNECTED;
                }
                _callOnComplete(onComplete, err);
            }
        }

        function enableDirectMethods(onMethod, onComplete = null) {
            if ((_state & SCONNECTED) && !(_state & SDISCONNECTING)) {
                if (_state & (SENABLINGMETH | SDISABLINGMETH)) {
                    _callOnComplete(onComplete, EOPNOTALLOWEDNOW);
                } else if (_onMethodCb != null && onMethod == null) {
                    // Should unsubscribe
                    // TODO: Make sure we have successfully unsubscribed
                    _state = _state ^ SDISABLINGMETH;
                    _mqttclient.unsubscribe(_topics.methNotif + "#");
                    _onMethodCb = null;
                    _state = _state ^ SDISABLINGMETH;
                    _callOnComplete(onComplete, 0);
                } else if (_onMethodCb != null) {
                    // Already subscribed
                    _callOnComplete(onComplete, EALREADYENABLED);
                } else if (onMethod == null) {
                    // Already disabled
                    _callOnComplete(onComplete, ENOTENABLED);
                } else {
                    // Should send subscribe packet for methods

                    local callback = function (rc, qos) {
                        if (rc == 0) {
                            _log("SETTING _onMethodCb");
                            _onMethodCb = onMethod;
                        }
                        _state = _state ^ SENABLINGMETH;
                        // TODO: What should we pass to onComplete?
                        _callOnComplete(onComplete, rc);
                    }.bindenv(this);

                    local topic = _topics.methNotif + "#";
                    _state = _state ^ SENABLINGMETH;
                    _mqttclient.subscribe(topic, _options.qos, callback);
                }
            } else {
                local err = _state & SDISCONNECTING ? EOPNOTALLOWEDNOW : ENOTCONNECTED;
                _callOnComplete(onComplete, err);
            }
        }

        function setDebug(enable) {
            _debugEnabled = enable;
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
            _state = rc == 0 ? SCONNECTED : SDISCONNECTED;
            try {
                // TODO: What should we pass to _onConnectCb?
                _onConnectCb(rc);
            } catch (e) {
                _error("Exception at onConnect user callback: " + e);
            }
        }

        function _onDisconnect() {
            _log("_onDisconnect");
            local reason = _state & SDISCONNECTING ? 0 : EGENERAL;
            _state = SDISCONNECTED;
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

            local props = {};

            // Cloud-to-device message received
            if (topic.find(_topics.msgRecv) != null) {
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
            // Desired properties were updated
            } else if (topic.find(_topics.twinNotif) != null) {
                local version = null;
                local parsedMsg = null;
                try {
                    version = split(topic, "=")[1];
                    parsedMsg = http.jsondecode(message);
                } catch (e) {
                    _error("Exception at parsing the message: " + e);
                    return;
                }
                try {
                    _onTwinReqCb(version, parsedMsg);
                } catch (e) {
                    _error("Exception at onRequest user callback: " + e);
                }
            // Twin's properties received
            } else if (topic.find(_topics.twinRecv) != null) {
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
                    return;
                }
                if (reqId in _reqCbMap) {
                    local reqType = _reqCbMap[reqId][0];
                    local cb = _reqCbMap[reqId][1];
                    delete _reqCbMap[reqId];
                    // Twin's properties received after GET request
                    if (reqType == RETRIEVE_REQ_TYPE) {
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
                            return;
                        }
                        try {
                            cb(0, repProps, desProps);
                        } catch (e) {
                            _error("Exception at onRetrieve user callback: " + e);
                        }
                    // Twin's properties received after UPDATE request
                    } else if (reqType == UPDATE_REQ_TYPE) {
                        // TODO: In fact Azure sends status=204 and empty body
                        _callOnComplete(cb, _statusIsOk(status) ? 0 : status);
                    }
                }
            // Direct method called
            } else if (topic.find(_topics.methNotif) != null) {
                local methodName = null;
                local reqId = null;
                local params = null;

                try {
                    methodName = split(topic, "/")[3];
                    reqId = split(topic, "=")[1];
                    params = http.jsondecode(message);
                } catch (e) {
                    _error("Exception at parsing the message: " + e);
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
            _state = SDISCONNECTED;
            _onMessageCb                = null;
            _onTwinReqCb                = null;
            _onMethodCb                 = null;
            _reqCbMap                   = {};
        }

        // Check HTTP status
        function _statusIsOk(status) {
            return status / 100 == 2 ? true : false;
        }

        // Metafunction to return class name when typeof <instance> is run
        function _typeof() {
            return "AzureIoTHubMQTTClient";
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
