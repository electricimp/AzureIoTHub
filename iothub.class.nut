// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

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

/// Azure iothub library

class iothub {

    static VERSION = "2.0.0";

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
            return time() + 3600 * 24;
        }

        static function encodeUriComponentStrict(str) {
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
            local sas = iothub.SharedAccessSignature();

            // The sr property shall have the value of resourceUri.
            sas.sr = resourceUri;

            // <signature> shall be an HMAC-SHA256 hash of the value <stringToSign>, which is then base64-encoded.
            // <stringToSign> shall be a concatenation of resourceUri + "\n" + expiry.
            local hash = iothub.Authorization.hmacHash(key, iothub.Authorization.stringToSign(resourceUri, expiry));

            // The sig property shall be the result of URL-encoding the value <signature>.
            sas.sig = iothub.Authorization.encodeUriComponentStrict(hash);

            // If the keyName argument to the create method was falsy, skn shall not be defined.
            // <urlEncodedKeyName> shall be the URL-encoded value of keyName.
            // The skn property shall be the value <urlEncodedKeyName>.
            if (keyName) sas.skn = iothub.Authorization.encodeUriComponentStrict(keyName);

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

        static function claimBasedSecurityPath() {
            return "$cbs";
        }

        static function versionQueryString() {
            return "?api-version=2016-02-03";
        }
    }

    //------------------------------------------------------------------------------

    Device = class {

        _body = null;

        constructor(jsonData = null) {

            if (jsonData) {
                _body = http.jsondecode(jsonData);
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
            return "Device";
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

        function createAMQPMessage() {
            // encode message body
            if (typeof _body == "table" || typeof _body == "array") _body = http.jsonencode(_body);
            // set properties to empty table, if no application properties set
            if (_properties == null ) _properties = {};
            return amqp.createmessage(_body, _properties);
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
                    local cn = iothub.ConnectionString.Parse(_config.connectionString);
                    local sas = iothub.SharedAccessSignature.create(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, iothub.Authorization.anHourFromNow());
                    _config.sharedAccessSignature = sas.toString();
                    _config.sharedAccessExpiry = sas.se;
                    // server.log("Signature refreshed");
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
                if (response.statuscode >= 200 && response.statuscode < 300) {
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

        _transport = null;

        constructor(connectionString) {
            local config = fromConnectionString(connectionString);
            _transport = iothub.RegistryHTTP(config);
        }

        function fromConnectionString(connectionString) {
            local cn = iothub.ConnectionString.Parse(connectionString);
            local sas = iothub.SharedAccessSignature.create(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, iothub.Authorization.anHourFromNow());

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
            if (typeof deviceInfo == "Device") deviceInfo = deviceInfo.getBody();
            else if (typeof deviceInfo != "table") deviceInfo = {};
            if (!("deviceId" in deviceInfo) || deviceInfo.deviceId == null) {
                deviceInfo.deviceId <- split(http.agenturl(), "/").pop();
            }

            local path = iothub.Endpoint.devicePath(deviceInfo.deviceId) + iothub.Endpoint.versionQueryString();
            _transport.createDevice(path, deviceInfo, function (err, body) {
                if (err) {
                    deviceInfo = null;
                } else if (body) {
                    deviceInfo = iothub.Device(body);
                }
                if (done) done(err, deviceInfo);
            }.bindenv(this))

            return this;
        }

        function update(deviceInfo, done = null) {

            if (typeof deviceInfo == "Device") deviceInfo = deviceInfo.getBody();

            local path = iothub.Endpoint.devicePath(deviceInfo.deviceId) + iothub.Endpoint.versionQueryString();
            _transport.updateDevice(path, deviceInfo, function (err, body) {
                if (err) {
                    deviceInfo = null;
                } else if (body) {
                    deviceInfo = iothub.Device(body);
                }
                if (done) done(err, deviceInfo);
            }.bindenv(this))

            return this;
        }

        function get(deviceId = null, done = null) {

            // NOTE: These default values are not from the original Node.js SDK
            if (typeof deviceId == "function") {
                done = deviceId;
                deviceId = null;
            }
            if (typeof deviceId != "string") {
                deviceId = split(http.agenturl(), "/").pop();
            }

            local path = iothub.Endpoint.devicePath(deviceId) + iothub.Endpoint.versionQueryString();
            _transport.getDevice(path, function (err, body) {
                local deviceInfo = null;
                if (body) {
                    deviceInfo = iothub.Device(body);
                }
                done(err, deviceInfo);
            }.bindenv(this))

            return this;
        }

        function list(done = null) {

            if (done == null) return null;

            local path = iothub.Endpoint.devicePath("") + iothub.Endpoint.versionQueryString();
            _transport.listDevices(path, function (err, body) {

                local devices = [];
                if (body) {
                    local jsonArray = http.jsondecode(body);
                    foreach (jsonElement in jsonArray) {
                        local devItem = iothub.Device(http.jsonencode(jsonElement));
                        devices.push(devItem);
                    }
                }

                done(err, devices);
            }.bindenv(this))

            return this;
        }

        function remove(deviceId = null, done = null) {

            // NOTE: These default values are not from the original Node.js SDK
            if (typeof deviceId == "function") {
                done = deviceId;
                deviceId = null;
            }
            if (typeof deviceId != "string") {
                deviceId = split(http.agenturl(), "/").pop();
            }

            local path = iothub.Endpoint.devicePath(deviceId) + iothub.Endpoint.versionQueryString();
            _transport.deleteDevice(path, done);

            return this;
        }
    }

    //------------------------------------------------------------------------------

    // Client transport class
    ClientAMQP = class {

        _config = null;
        _connection = null;
        _sessions = null;
        _senders = null;
        _receivers = null;
        _transfers = null;
        _handlers = null;
        _msgQueue = null;

        _connecting = false;
        _senderTokenError = false;
        _receiverTokenError = false;
        _debug = true;

        constructor(config) {
            _config = config;
            _resetConnectionTables();
        }

        // done has one param (error)
        function connect(done = null) {
            // set connecting flag
            _connecting = true;
            // set connection callback
            _handlers.onConnected <- done;

            // Don't open a connection if one is already open
            if( _isOpen(_connection) ) {
                if ( _isOpen(_sessions.auth) ) {
                    if ( _isOpen(_receivers.auth) ) {
                        if ( _isOpen(_senders.auth) ) {
                            if ( _isOpen(_sessions.event) ) {
                                if ( _isOpen(_senders.event) ) {
                                    _connectionCallback(null);
                                } else {
                                    _openEventSender();
                                }
                            } else {
                                _openEventSession();
                            }
                        } else {
                            _openAuthSender();
                        }
                    } else {
                        _openAuthReceiver();
                    }
                } else {
                    _openAuthSession();
                }
            } else {
                _connection = amqp.openconnection("amqps://" + _config.host, _amqpConnectionStatusHandler.bindenv(this));
            }
        }

        // done - no params
        function disconnect() {
            _connection.close();
            _resetConnectionTables();
        }

        // done cb params - err, transmission msg
        function sendEvent(message, done = null) {
            debugLog("in sendEvent")
            server.log("event session: " + _sessions.event.isopen())

            if ( !_isOpen(_sessions.event) ) {
                done("Cannot send while disconnected.", null);
            } else {
                if ( !_isOpen(_senders.event) ) {
                    debugLog("creating event sender session");
                    // add message to queue
                    _msgQueue.push({"msg" : message, "cb" : done});
                    // create a new sender & send message
                    _openEventSender();
                } else {
                    debugLog("event sender session open")
                    _sendEvent(message, done);
                }
            }
        }

        // done is called everytime a message is available, params - error, data
        function receive(done) {

            _handlers.onEvent <- done;

            if (done == null) {
                _receivers.event.close();
                return this;
            }

            if( !_isOpen(_sessions.event) ) {
                _handlers.onEvent("Cannot receive while disconnected.", null);
            } else {
                // TODO: test/handle if receiver already open
                _openEventReceiver();
            }
            return this;
        }

        // done cb params - err, transmission msg
        function sendEventBatch(messages, done = null) {
            local message = _constructBatchBody(messages);
            sendEvent(message, done);
        }

        // PRIVATE FUNCTIONS
        // ------------------------------------------------------------------------------------
        // ------------------------------------------------------------------------------------


        // Connection Handlers
        // ------------------------------------------------------------------------------------
        function _amqpConnectionStatusHandler(event, data) {
            debugLog("Connection event: " + event);
            switch(event) {
                case "CONNECTION_OPEN":
                    if (_connecting) _openAuthSession();
                    break;
                case "CONNECTION_CLOSED" :
                    break;
                case "CONNECTION_ERROR" :
                    if (_connecting) {
                        if (data == null) data = event;
                        _connectionCallback(data);
                    } else {
                        // TODO: replace this with error handling
                        debugLog(data);
                    }
                default:
                    // TODO: replace this with known events
                    debugLog(data);
                    break;
            }
        }

        function _amqpAuthSessionStatusHandler(event, data) {
            debugLog("Auth Session event: " + event);
            switch(event) {
                case "SESSION_OPEN":
                    _openAuthReceiver();
                    break;
                case "SESSION_CLOSED" :
                    break;
                case "SESSION_ERROR" :
                    if (_connecting) {
                        if (data == null) data = event;
                        _connectionCallback(data);
                    } else {
                        // TODO: replace this with error handling
                        debugLog(data);
                    }
                default:
                    // TODO: replace this with known events
                    debugLog(data);
                    break;
            }
        }

        // Note: auth receiver will open auth sender if needed, auth
        function _amqpAuthSenderStatusHandler(event, data) {
            debugLog("Auth Sender event: " + event);
            switch(event) {
                case "SENDER_OPEN":
                    _getPutToken( function() { debugLog("put token request sent") });
                    break;
                case "SENDER_CLOSED":
                    break;
                case "SENDER_ERROR":
                    if (_connecting) {
                        if (data == null) data = event;
                        _connectionCallback(data);
                    } else {
                        // TODO: replace this with error handling
                        debugLog(data);
                    }
                    break;
                default:
                    debugLog(data);
                    break;
            }
        }

        function _amqpAuthReceiverStatusHandler(event, data) {
            debugLog("Auth Receiver event: " + event);
            switch(event) {
                case "RECEIVER_OPEN":
                    if ( !_isOpen(_senders.auth) )  {
                        _openAuthSender();
                    } else {
                        _getPutToken( function() { debugLog("put token request sent") });
                    }
                    break;
                case "RECEIVER_CLOSED":
                    break;
                case "RECEIVER_ERROR":
                    if (_connecting) {
                        if (data == null) data = event;
                        _connectionCallback(data);
                    } else {
                        // TODO: replace this with error handling
                        debugLog(data);
                    }
                default:
                    // Should not need this, it's just a catch-all while in development
                    debugLog(data);
                    break;
            }
        }

        function _amqpEventSessionStatusHandler(event, data) {
            debugLog("Event Session event: " + event);

            switch(event) {
                case "SESSION_OPEN":
                    _openEventSender();
                    break;
                case "SESSION_CLOSED" :
                    break;
                case "SESSION_ERROR" :
                    if (_connecting) {
                        if (data == null) data = event;
                        _connectionCallback(data);
                    } else {
                        // TODO: replace this with error handling
                        debugLog(data);
                    }
                default:
                    // TODO: replace this with known events
                    debugLog(data);
                    break;
            }
        }

        function _amqpEventSenderStatusHandler(event, data) {
            debugLog("Msg Sender event: " + event);

            switch(event) {
                case "SENDER_OPEN":
                    if (_connecting) {
                        _connectionCallback(null);
                    }
                    if (_msgQueue.len() > 0) {
                        while (_msgQueue.len()) {
                            local item = _msgQueue.remove(0);
                            _sendEvent(item.msg, item.cb);
                        }
                    }
                    break;
                case "SENDER_CLOSED":
                    break;
                case "SENDER_ERROR":
                    if (_connecting) {
                        if (data == null) data = event;
                        _connectionCallback(data);
                    } else if (_msgQueue.len() > 0) {
                        while (_msgQueue.len()) {
                            local item = _msgQueue.remove(0);
                            if (item.cb) item.cb(event, item.msg);
                        }
                    } else {
                        // TODO: replace this with error handling
                        debugLog(data);
                        if (data.find("Token Expired") != null) {
                            _senderTokenError = true;
                            _updateConfigSASExpiry();
                            _getPutToken(function() {server.log("renewing token")});
                        }
                    }
                    break;
                default:
                    // Should not need this, it's just a catch-all while in development
                    debugLog(data);
                    break;
            }
        }

        function _amqpEventReceiverStatusHandler(event, data) {
            debugLog("Msg Receiver event: " + event);

            switch(event) {
                case "RECEIVER_OPEN":
                    break;
                case "RECEIVER_CLOSED":
                    break;
                case "RECEIVER_ERROR":
                    // TODO: replace this with error handling
                    debugLog(data);
                    if (data.find("Token Expired") != null) {
                        _receiverTokenError = true;
                        _updateConfigSASExpiry();
                        _getPutToken(function() {server.log("renewing token")});
                    }
                default:
                    // Should not need this, it's just a catch-all while in development
                    debugLog(data);
                    break;
            }
        }

        // Authorization
        // ------------------------------------------------------------------------------------

        function _authReceiverCB(deliveries) {
            debugLog("in auth receiver callback")
            local authorized = false;

            foreach(deliveryItem in deliveries) {
                deliveryItem.accept();
                local properties = deliveryItem.message().properties();

                if ("status-code" in properties && properties["status-code"] == 200 && "status-description" in properties && properties["status-description"] == "OK") {
                    authorized = true;

                    if (_senderTokenError) {
                        _openEventSender();
                        _senderTokenError = false;
                    } else if (_receiverTokenError) {
                        if ("onEvent" in _handlers && _handlers.onEvent != null) _openEventReceiver();
                        _receiverTokenError = false;
                    } else {
                        // We are connected and authorized, check event session status
                        if ( _isOpen(_sessions.event) ) {
                            if ( _isOpen(_senders.event) ) {
                                if (_connecting) _connectionCallback(null);
                            } else {
                                _openEventSender();
                            }
                        } else {
                            _openEventSession();
                        }
                    }

                }
            } // end foreach loop

            if (_connecting && !authorized) {
                _connectionCallback("Not authorised with Azure IOT Hub");
            }
        }

        function _getPutToken(done) {
            debugLog("get put token")

            local properties = {};
            properties["operation"] <- "put-token";
            properties["type"] <- "azure-devices.net:sastoken";
            properties["name"] <- _config.host + "/devices/" + _config.deviceId;

            // this message transfer will trigger response message when received by cloud
            // if auth receiver is open response will trigger _authReceiverCB
            local msg = amqp.createmessage(_config.sharedAccessSignature, properties);
            _transfers.auth <- _senders.auth.createtransfer(msg);
            _transfers.auth.sendasync(done.bindenv(this));
        }

        // updates the config SAS expiry time
        function _updateConfigSASExpiry() {
            if ("sharedAccessExpiry" in _config && "connectionString" in _config) {
                local cn = iothub.ConnectionString.Parse(_config.connectionString);
                local resourceUri = cn.HostName + "/devices/" + iothub.Authorization.encodeUriComponentStrict(cn.DeviceId);
                local sas = iothub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, iothub.Authorization.fifteenMinutesFromNow());
                _config.sharedAccessSignature = sas.toString();
                _config.sharedAccessExpiry = sas.se;
            }
        }

        // Helper Methods
        // ------------------------------------------------------------------------------------

        function _openAuthSession() {
            _sessions.auth <- _connection.opensession(_amqpAuthSessionStatusHandler.bindenv(this));
        }

        function _openAuthReceiver() {
            _receivers.auth <- _sessions.auth.openreceiver(iothub.Endpoint.claimBasedSecurityPath(), _amqpAuthReceiverStatusHandler.bindenv(this), _authReceiverCB.bindenv(this));
        }

        function _openAuthSender() {
            _senders.auth <- _sessions.auth.opensender(iothub.Endpoint.claimBasedSecurityPath(), _amqpAuthSenderStatusHandler.bindenv(this));
        }

        function _openEventSession() {
            _sessions.event <- _connection.opensession(_amqpEventSessionStatusHandler.bindenv(this));
        }

        function _openEventSender() {
            _senders.event <- _sessions.event.opensender(iothub.Endpoint.eventPath(_config.deviceId), _amqpEventSenderStatusHandler.bindenv(this));
        }

        function _openEventReceiver() {
            _receivers.event <- _sessions.event.openreceiver(iothub.Endpoint.messagePath(_config.deviceId), _amqpEventReceiverStatusHandler.bindenv(this), function(deliveries) {
                _handleDeliveries(deliveries, _handlers.onEvent);
            }.bindenv(this));
        }

        function _connectionCallback(error) {
            _connecting = false;
            if (_handlers.onConnected) {
                imp.wakeup(0, function() {
                    _handlers.onConnected(error);
                }.bindenv(this));
            }
        }

        function _isOpen(amqpObj) {
            return (amqpObj != null && amqpObj.isopen());
        }

        function _resetConnectionTables() {
            _sessions = _getDefaultConnectionTable();
            _transfers = _getDefaultConnectionTable();
            _senders = _getDefaultConnectionTable();
            _receivers = _getDefaultConnectionTable();
            _msgQueue = [];
            _handlers = {};
        }

        function _getDefaultConnectionTable() {
            return {"event" : null, "auth" : null};
        }

        function _handleDeliveries(deliveries, cb) {
            while (deliveries.len()) {
                local item = deliveries.remove(0);
                cb(null, item);
            }
        }

        function _constructBatchBody(messages) {
            local body = [];
            foreach (message in messages) {

                local msg = {
                    "body": http.base64encode(message.getData()),
                    "properties": message.getProperties()
                }
                body.push(msg);
            }
            return http.jsonencode(body);
        }

        function _sendEvent(message, done) {
            // create transfer and send
            _transfers.event <- _senders.event.createtransfer(message.createAMQPMessage());
            debugLog("send event transfer created")
            _transfers.event.sendasync(function() {
                debugLog("in send event transfer callback")
                if (done) done(null, "Event transmitted.");
            }.bindenv(this));
        }

        function debugLog(logMsg) {
            if (_debug) server.log(logMsg);
        }

    }

    Client = class {

        _transport = null;
        _config = null;

        constructor(deviceConnectionString) {
            local config = fromConnectionString(deviceConnectionString);
            _config = config;
            _transport = iothub.ClientAMQP(config);
        }

        function fromConnectionString(deviceConnectionString) {

            local cn = iothub.ConnectionString.Parse(deviceConnectionString);
            local resourceUri = cn.HostName + "/devices/" + iothub.Authorization.encodeUriComponentStrict(cn.DeviceId);
            local sas = iothub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, iothub.Authorization.fifteenMinutesFromNow());

            local config = {
                "host": cn.HostName,
                "deviceId": cn.DeviceId,
                "hubName": split(cn.HostName, ".")[0],
                "sharedAccessSignature": sas.toString(),
                "sharedAccessExpiry": sas.se,
                "connectionString": deviceConnectionString
            };

            return config;
        }

        function connect(done = null) {
            _transport.connect(done);
            return this;
        }

        function disconnect() {
            _transport.disconnect();
            return this;
        }

        function sendEvent(message, done = null) {
            _transport.sendEvent(message, done);
            return this;
        }

        function sendEventBatch(messages, done = null) {
            _transport.sendEventBatch(messages, done);
            return this;
        }

        function receive(done) {
            _transport.receive(done);
            return this;
        }

    }

}