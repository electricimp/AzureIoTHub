// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

/* Notes
 *
 * This class implements some of the device-side functionality of the Azure IoT Hub.
 *
 * Code ported from: https://github.com/Azure/azure-iot-sdks/blob/master/node/
 * Documentation of REST interface: https://msdn.microsoft.com/en-us/library/mt548492.aspx
 * Useful developer overview of IoT Hub: https://azure.microsoft.com/en-us/documentation/articles/iot-hub-devguide/
 *
 */

//------------------------------------------------------------------------------
class iothub {

    static version = [1,1,0];

}

//------------------------------------------------------------------------------
class iothub.ConnectionString {

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


//------------------------------------------------------------------------------
class iothub.Endpoint {

    static function devicePath(id) {
        return "/devices/" + id;
    }

    static function eventPath(id) {
        return devicePath(id) + "/messages/events";
    }

    static function messagePath(id) {
        return devicePath(id) + "/messages/devicebound";
    }

    static function feedbackPath(id, lockToken) {
        return messagePath(id) + "/" + lockToken;
    }

    static function versionQueryString() {
        return "?api-version=2015-08-15-preview";
    }
}

//------------------------------------------------------------------------------
class iothub.Authorization {


    static function anHourFromNow() {
        return time() + 3600;
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

//------------------------------------------------------------------------------
class iothub.SharedAccessSignature {

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

//------------------------------------------------------------------------------
class iothub.HTTP {

    _config = null;

    static FEEDBACK_ACTION_ABANDON = "abandon";
    static FEEDBACK_ACTION_REJECT = "reject";
    static FEEDBACK_ACTION_COMPLETE = "complete";

    constructor(config) {
        _config = config;
    }

    function refreshSignature() {

        if ("sharedAccessExpiry" in _config && "connectionString" in _config) {
            if (time() >= _config.sharedAccessExpiry) {
                local cn = iothub.ConnectionString.Parse(_config.connectionString);
                local resourceUri = cn.HostName + "/devices/" + iothub.Authorization.encodeUriComponentStrict(cn.DeviceId);
                local sas = iothub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, iothub.Authorization.anHourFromNow());
                _config.sharedAccessSignature = sas.toString();
                _config.sharedAccessExpiry = sas.se;
                // server.log("Signature refreshed");
            }
        }
    }

    function sendEvent(message, done = null) {

        refreshSignature();
        local path = iothub.Endpoint.eventPath(_config.deviceId);
        local url = "https://" + _config.host + path + iothub.Endpoint.versionQueryString();
        local httpHeaders = {
            "Authorization": _config.sharedAccessSignature,
            "iothub-to": path
        };
        if(message.getMessageId() != null) {
            httpHeaders["iothub-messageId"] <- message.getMessageId();
        }
        if(message.getCorrelationId() != null) {
            httpHeaders["iothub-correlationId"] <- message.getCorrelationId();
        }
        foreach (k,v in message.getProperties()) {
            httpHeaders["IoTHub-app-" + k] <- v;
        }

        local request = http.post(url, httpHeaders, message.getData());
        request.sendasync(handleResponse(done));
        return this;
    }

    function sendEventBatch(messages, done = null) {

        refreshSignature();
        local path = iothub.Endpoint.eventPath(_config.deviceId);
        local url = "https://" + _config.host + path + iothub.Endpoint.versionQueryString();
        local httpHeaders = {
            "Authorization": _config.sharedAccessSignature,
            "iothub-to": path,
            "Content-Type": "application/vnd.microsoft.iothub.json"
        };

        local request = http.post(url, httpHeaders, constructBatchBody(messages));
        request.sendasync(handleResponse(done));
        return this;
    }

    function receive(done) {

        refreshSignature();
        local path = iothub.Endpoint.messagePath(_config.deviceId);
        local url = "https://" + _config.host + path + iothub.Endpoint.versionQueryString();
        local httpHeaders = {
            "Authorization": _config.sharedAccessSignature,
            "iothub-to": path
        };

        local request = http.get(url, httpHeaders);
        request.sendasync(function(response) {

            if (response.statuscode == 204 || response.statuscode == 429) {
                // Nothing there, try again soon
                imp.wakeup(1, function() {
                    receive(done);
                }.bindenv(this));
            } else {
                // Something there, handle it
                if (done) done(null, iothub.Message(response.body, response.headers));

                // Restart polling immediately
                receive(done);
            }

        }.bindenv(this));

        return this;
    }

    function sendFeedback(action, message, done = null) {

        refreshSignature();
        local path = iothub.Endpoint.feedbackPath(_config.deviceId, message.getProperty("lockToken"));
        local httpHeaders = {
            "Authorization": _config.sharedAccessSignature,
            "iothub-to": path,
            "If-Match": message.getProperty("lockToken")
        };
        local url = "https://" + _config.host + path;
        local method;
        if (action == FEEDBACK_ACTION_ABANDON) {
            url += "/abandon" + iothub.Endpoint.versionQueryString();
            method = "POST";
        } else if (action == FEEDBACK_ACTION_REJECT) {
            url += iothub.Endpoint.versionQueryString() + "&reject";
            method = "DELETE";
        } else {
            url += iothub.Endpoint.versionQueryString();
            method = "DELETE";
        }

        local request = http.request(method, url, httpHeaders, "");
        request.sendasync(handleResponse(done));
        return this;

    }

    function constructBatchBody(messages) {

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

    function handleResponse(done) {

        return function(response) {
            if (response.statuscode >= 200 && response.statuscode < 300) {
                if (done) done(null, response);
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

//------------------------------------------------------------------------------
class iothub.Device {

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

//------------------------------------------------------------------------------
class iothub.Message {

    _data = null;
    _properties = null;

    messageId = null;
    to = null;
    expiryTimeUtc = null;
    correlationId = null;

    constructor(data, headers={}) {
        if (typeof data == "string") {
            _data = data;
        } else {
            _data = http.jsonencode(data);
        }

        _properties = {};
        foreach (k,v in headers) {
            switch (k.tolower()) {
                case "iothub-messageid":
                    messageId = v;
                    break;
                case "iothub-to":
                    to = v;
                    break;
                case "iothub-expiry":
                    expiryTimeUtc = v;
                    break;
                case "iothub-correlationid":
                    correlationId = v;
                    break;
                case "etag":
                    _properties["lockToken"] <- http.jsondecode(v);
                    break;
            }
        }

    }

    function getData() {
        return _data;
    }

    function getProperties() {
        return _properties;
    }

    function setProperty(key, value) {
        _properties[key] <- value;
    }

    function getProperty(key) {
        return (key in _properties) ? _properties[key] : null;
    }

    function unsetProperty(key) {
        if (key in _properties) delete _properties[key];
    }
    function getMessageId() {
	return messageId;
    }
    function getCorrelationId() {
	return correlationId;
    }
}

//------------------------------------------------------------------------------
class iothub.Client {

    _transport = null;

    constructor(transport) {
        _transport = transport;
    }

    // Factory function
    static function fromConnectionString(connectionString, transport = null) {
        if (!transport) transport = iothub.HTTP;

        local cn = iothub.ConnectionString.Parse(connectionString);
        local resourceUri = cn.HostName + "/devices/" + iothub.Authorization.encodeUriComponentStrict(cn.DeviceId);
        local sas = iothub.SharedAccessSignature.create(resourceUri, null, cn.SharedAccessKey, iothub.Authorization.anHourFromNow());

        local config = {
            "host": cn.HostName,
            "deviceId": cn.DeviceId,
            "hubName": split(cn.HostName, ".")[0],
            "sharedAccessSignature": sas.toString(),
            "sharedAccessExpiry": sas.se,
            "connectionString": connectionString
        };
        return iothub.Client(transport(config));
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

    function sendFeedback(action, message, done = null) {
        _transport.sendFeedback(action, message, done);
        return this;
    }

}

//------------------------------------------------------------------------------
class iothub.RegistryHTTP {

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

//------------------------------------------------------------------------------
class iothub.Registry {

    _transport = null;

    constructor(transport) {
        _transport = transport;
    }

    // Factory function
    static function fromConnectionString(connectionString, transport = null) {
        if (!transport) transport = iothub.RegistryHTTP;

        local cn = iothub.ConnectionString.Parse(connectionString);
        local sas = iothub.SharedAccessSignature.create(cn.HostName, cn.SharedAccessKeyName, cn.SharedAccessKey, iothub.Authorization.anHourFromNow());

        local config = {
            "host": cn.HostName,
            "hubName": split(cn.HostName, ".")[0],
            "sharedAccessSignature": sas.toString(),
            "sharedAccessExpiry": sas.se,
            "connectionString": connectionString
        };
        return iothub.Registry(transport(config));
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
