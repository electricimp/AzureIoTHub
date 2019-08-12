// MIT License
//
// Copyright 2015-2019 Electric Imp
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

const AZURE_CLIENT_ERROR_NOT_CONNECTED          = 1000;
const AZURE_CLIENT_ERROR_ALREADY_CONNECTED      = 1001;
const AZURE_CLIENT_ERROR_NOT_ENABLED            = 1002;
const AZURE_CLIENT_ERROR_ALREADY_ENABLED        = 1003;
const AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW     = 1004;
const AZURE_CLIENT_ERROR_OP_TIMED_OUT           = 1005;
const AZURE_DPS_ERROR_NOT_REGISTERED            = 1010;
const AZURE_ERROR_GENERAL                       = 1100;

// MQTT QoS. Azure IoT Hub supports QoS 0 and 1 only
const AZURE_CLIENT_DEFAULT_QOS                  = 0;
// MQTT Keep-alive (in seconds)
const AZURE_CLIENT_DEFAULT_KEEP_ALIVE           = 60;
// Timeout (in seconds) for Retrieve Twin and Update Twin operations
const AZURE_CLIENT_DEFAULT_TWINS_TIMEOUT        = 10;
// Maximum amount of pending Update Twin operations
const AZURE_CLIENT_DEFAULT_TWIN_UPD_PARAL_REQS  = 3;
// Maximum amount of pending Send Message operations
const AZURE_CLIENT_DEFAULT_MSG_SEND_PARAL_REQS  = 3;
// SAS token's time-to-live (sec)
const AZURE_CLIENT_DEFAULT_TOKEN_TTL            = 86400;
// Timeframe (sec) to reply to direct method call
const AZURE_CLIENT_DEFAULT_DMETHODS_TIMEOUT     = 30;


class AzureIoTHub {

    static VERSION = "5.1.0";

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

        static function aDayFromNow() {
            // Add 'aDayFromNow()' - see https://electricimp.atlassian.net/browse/CSE-785
            return time() + 86400;
        }

        static function anDayFromNow() {
            // Retain old version for compatibility?
            return aDayFromNow();
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

    // This class is used as a wrapper for messages to/from Azure IoT Hub.
    Message = class {

        _body = null;
        _props = null;

        // Message class constructor.
        //
        // Parameters:
        //     body :                       Message body.
        //          Any supported by the MQTT API
        //     props : Table                Key-value table with the message properties.
        //          (optional)              Every key is always a String with the name of the property.
        //                                  The value is the corresponding value of the property.
        //                                  Keys and values are fully application specific.
        //
        // Returns:                         AzureIoTHub.Message instance created.
        constructor(body, props = null) {
            _body = body;
            _props = props;
        }

        // Returns a key-value table with the properties of the message.
        // Every key is always a String with the name of the property.
        // The value is the corresponding value of the property.
        // Incoming messages contain properties set by Azure IoT Hub.
        //
        // Returns:                         A key-value table with the properties of the message.
        function getProperties() {
            return _props;
        }

        // Returns the message's body.
        // Messages that have been created locally will be of the same type as they were when created,
        // but messages came from Azure IoT Hub are of one of the types supported by the MQTT API.
        //
        // Returns:                         The message's body.
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
        //     body : Table                 Key-value table with the returned data.
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

    // This class is used to provision devices in Azure IoT Hub Device Provisioning Service.
    // It allows you to register a device and obtain its Device Connection String.
    DPS = class {
        _scopeId    = null;
        _regId      = null;
        _deviceKey  = null;

        _headers    = null;
        _resUri     = null;
        _regIdBody  = null;

        // DPS class constructor.
        //
        // Parameters:
        //     scopeId : String             Scope ID of Azure IoT Hub DPS
        //     registrationId : String      Registration ID of the device
        //     deviceKey : String           Device symmetric key
        //
        // Returns:                         AzureIoTHub.DPS instance created.
        constructor(scopeId, registrationId, deviceKey) {
            const AZURE_DPS_API_VERSION = "2018-09-01-preview";
            const AZURE_DPS_REG_KEY_NAME = "registration";
            const AZURE_DPS_GLOBAL_HOST = "https://global.azure-devices-provisioning.net";

            // Looks like "https://global.azure-devices-provisioning.net/0ne000366B8/registrations/my-device/register?api-version=2018-09-01-preview"
            const AZURE_DPS_REG_ENDPOINT_FMT        = "%s/%s/registrations/%s/register?api-version=%s";
            // Looks like "https://global.azure-devices-provisioning.net/0ne000366B8/registrations/my-device/operations/4.176af959adcba99f.d5817a51-c64b-409b-83df-8425b610cbd2?api-version=2018-09-01-preview"
            const AZURE_DPS_OP_STATUS_ENDPOINT_FMT  = "%s/%s/registrations/%s/operations/%s?api-version=%s";
            // Looks like "https://global.azure-devices-provisioning.net/0ne000366B8/registrations/my-device?api-version=2018-09-01-preview"
            const AZURE_DPS_REG_STATUS_ENDPOINT_FMT = "%s/%s/registrations/%s?api-version=%s";

            const AZURE_DPS_SAS_TTL = 3600;
            // Default delay (sec) between polling requests
            const AZURE_DPS_DEFAULT_DELAY = 3.0;

            const AZURE_DPS_OK_CODE             = 200;
            const AZURE_DPS_ACCEPTED_CODE       = 202;
            const AZURE_DPS_NOT_FOUND_CODE      = 404;
            const AZURE_DPS_TOO_MANY_REQS_CODE  = 429;

            _headers = {
                "Accept" : "application/json",
                "Content-Type" : "application/json; charset=utf-8",
                "Connection" : "keep-alive",
                "UserAgent" : "prov_device_client/1.0",
                "Authorization" : null
            };

            _scopeId    = scopeId;
            _regId      = registrationId;
            _deviceKey  = deviceKey;

            _regIdBody = http.jsonencode({
                "registrationId" : _regId
            });
            _resUri = AzureIoTHub.Authorization.encodeUri(_scopeId + "/registrations/" + _regId);
        }


        // Registers the device using Azure IoT Hub Device Provisioning Service.
        //
        // Parameters:
        //     onCompleted : Function       A function to be called when the operation is completed or an error occurs
        //                                  The callback signature:
        //                                  onCompleted(error, response, connectionString), where
        //                                      error : Integer     0 if the operation is successful, otherwise an error code
        //                                      response : Table    Key-value table with the response provided by Azure server. May be null.
        //                                                          For information on the response format, please see the Azure documentation.
        //                                                          May also contain error details
        //                                      connectionString :  Device connection string. null in case of an error
        //                                          String
        //
        // Returns:                         Nothing.
        function register(onCompleted) {
            local sasExpTime = time() + AZURE_DPS_SAS_TTL;
            local sas = AzureIoTHub.SharedAccessSignature(_resUri, AZURE_DPS_REG_KEY_NAME, _deviceKey, sasExpTime).toString();

            _headers["Authorization"] = sas;

            local url = format(AZURE_DPS_REG_ENDPOINT_FMT, AZURE_DPS_GLOBAL_HOST, _scopeId, _regId, AZURE_DPS_API_VERSION);
            local request = http.put(url, _headers, _regIdBody);

            local onSent = function(resp) {
                local body = _parseBody(resp.body);

                if (resp.statuscode == AZURE_DPS_OK_CODE || resp.statuscode == AZURE_DPS_ACCEPTED_CODE) {
                    if ("operationId" in body) {
                        _regOperationStatus(body["operationId"], onCompleted);
                    } else {
                        server.error("Response body doesn't have the \"operationId\" field");
                        onCompleted(AZURE_ERROR_GENERAL, body, null);
                    }
                } else {
                    onCompleted(resp.statuscode, body, null);
                }
            }.bindenv(this);

            request.sendasync(onSent);
        }

        // If the device is already registered and assigned to an IoT Hub,
        // this method returns Device Connection String via the onCompleted handler.
        //
        // Parameters:
        //     onCompleted : Function       A function to be called when the operation is completed or an error occurs
        //                                  The callback signature:
        //                                  onCompleted(error, response, connectionString), where
        //                                      error : Integer     0 if the operation is successful, otherwise an error code
        //                                      response : Table    Key-value table with the response provided by Azure server. May be null.
        //                                                          For information on the response format, please see the Azure documentation.
        //                                                          May also contain error details
        //                                      connectionString :  Device connection string. null in case of an error
        //                                          String
        //
        // Returns:                         Nothing.
        function getConnectionString(onCompleted) {
            local sasExpTime = time() + AZURE_DPS_SAS_TTL;
            local sas = AzureIoTHub.SharedAccessSignature(_resUri, AZURE_DPS_REG_KEY_NAME, _deviceKey, sasExpTime).toString();

            _headers["Authorization"] = sas;

            local url = format(AZURE_DPS_REG_STATUS_ENDPOINT_FMT, AZURE_DPS_GLOBAL_HOST, _scopeId, _regId, AZURE_DPS_API_VERSION);
            local request = http.post(url, _headers, _regIdBody);

            local onSent = function(resp) {
                local body = _parseBody(resp.body);

                if (resp.statuscode == AZURE_DPS_OK_CODE) {
                    if (!("status" in body)) {
                        server.error("Response body doesn't have the \"status\" field");
                        onCompleted(AZURE_ERROR_GENERAL, body, null);
                        return;
                    }

                    if (body["status"] == "assigned") {
                        if ("assignedHub" in body) {
                            onCompleted(0, body, _connectionString(body["assignedHub"]));
                        } else {
                            server.error("Response body doesn't have the \"assignedHub\" field");
                            onCompleted(AZURE_ERROR_GENERAL, body, null);
                        }
                    } else {
                        onCompleted(AZURE_DPS_ERROR_NOT_REGISTERED, body, null);
                    }
                } else if (resp.statuscode == AZURE_DPS_NOT_FOUND_CODE) {
                    onCompleted(AZURE_DPS_ERROR_NOT_REGISTERED, body, null);
                } else {
                    onCompleted(resp.statuscode, body, null);
                }
            }.bindenv(this);

            request.sendasync(onSent);
        }

        // -------------------- PRIVATE METHODS -------------------- //

        function _regOperationStatus(operationId, onCompleted) {
            local url = format(AZURE_DPS_OP_STATUS_ENDPOINT_FMT, AZURE_DPS_GLOBAL_HOST, _scopeId, _regId, operationId, AZURE_DPS_API_VERSION);
            local request = http.get(url, _headers);
            local onSent = null;

            onSent = function(resp) {
                local body = _parseBody(resp.body);

                local retryAfter = AZURE_DPS_DEFAULT_DELAY;

                if (resp.statuscode == AZURE_DPS_OK_CODE || resp.statuscode == AZURE_DPS_ACCEPTED_CODE) {
                    if (!("status" in body)) {
                        server.error("Response body doesn't have the \"status\" field");
                        onCompleted(AZURE_ERROR_GENERAL, body, null);
                        return;
                    }

                    if (body["status"] == "assigned") {
                        if ("registrationState" in body && "assignedHub" in body["registrationState"]) {
                            onCompleted(0, body, _connectionString(body["registrationState"]["assignedHub"]));
                        } else {
                            server.error("Response body doesn't have the \"registrationState.assignedHub\" field");
                            onCompleted(AZURE_ERROR_GENERAL, body, null);
                        }
                        return;
                    } else if (body["status"] != "assigning") {
                        onCompleted(AZURE_DPS_ERROR_NOT_REGISTERED, body, null);
                        return;
                    }
                } else if (resp.statuscode != AZURE_DPS_TOO_MANY_REQS_CODE) {
                    onCompleted(resp.statuscode, body, null);
                    return;
                }

                if ("retry-after" in resp.headers) {
                    retryAfter = resp.headers["retry-after"].tointeger();
                }
                request = http.get(url, _headers);
                imp.wakeup(retryAfter, @() request.sendasync(onSent));
            }.bindenv(this);

            request.sendasync(onSent);
        }

        function _connectionString(iotHubAddr) {
            return format("HostName=%s;DeviceId=%s;SharedAccessKey=%s", iotHubAddr, _regId, _deviceKey);
        }

        function _parseBody(body) {
            local result = null;
            try {
                result = http.jsondecode(body);
            } catch (e) {
                server.error("Response body is not a valid JSON: " + e);
            }
            return result;
        }
    }


    //------------------------------------------------------------------------------

    // This class is used to transfer data to and from Azure IoT Hub.
    // To use this class, the device must be registered as an IoT Hub device in an Azure account.
    // AzureIoTHub.Client works over MQTT v3.1.1 protocol. It supports the following functionality:
    // - connecting and disconnecting to/from Azure IoT Hub. Azure IoT Hub supports only one connection per device.
    // - sending messages to Azure IoT Hub
    // - receiving messages from Azure IoT Hub (optional functionality)
    // - device twin operations (optional functionality)
    // - direct methods processing (optional functionality)
    Client = class {

        _debugEnabled           = false;

        _isDisconnected         = true;
        _isDisconnecting        = false;
        _isConnected            = false;
        _isConnecting           = false;
        _isRefreshingToken      = false;
        _isEnablingMsg          = false;
        _isEnablingTwin         = false;
        _isEnablingDMethod      = false;
        _shouldDisconnect       = false;

        _connStrParsed          = null;
        _resourceUri            = null;
        _url                    = null;
        _tokenExpiresAt         = null;
        // User-defined options (with defaults)
        _options                = null;
        // Options (like QoS) for MQTT messages
        _msgOptions             = null;
        _mqttclient             = null;
        // Options for MQTT connection
        _mqttOptions            = null;
        _topics                 = null;

        // Long term user callbacks. Like onReceive, onRequest, onMethod
        _onConnectedCb          = null;
        _onDisconnectedCb       = null;
        _onMessageCb            = null;
        _onTwinReqCb            = null;
        _onMethodCb             = null;

        // Short term user callbacks. Like onDone, onRetrieved
        // User can send several messages in parallel, so we need a map reqId -> [<msg>, <callback>]
        _msgBeingSent           = null;
        _msgEnabledCb           = null;
        _twinEnabledCb          = null;
        // Contains [<reqId>, <callback>, <timestamp>] or null
        _twinRetrievedCb        = null;
        // User can update twin several times in parallel, so we need a map reqId -> [<props>, <callback>, <timestamp>]
        _twinUpdateRequests     = null;
        _dMethodEnabledCb       = null;
        // Direct method calls that should be replied. Map reqId -> [<resp>, <callback>, <timestamp>]
        _dMethodCalls           = null;

        _processQueuesTimer     = null;

        _reqNum                 = 0;

        _refreshTokenTimer      = null;

        // Array of calls made while refreshing token
        _pendingCalls           = null;
        _refreshingPaused       = false;


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
        //          (optional)              The callback signature:
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
        constructor(deviceConnStr, onConnected = null, onDisconnected = null, options = {}) {
            const AZURE_CLIENT_MESSAGE_INDEX        = 0;
            const AZURE_CLIENT_REQ_ID_INDEX         = 0;
            const AZURE_CLIENT_TWIN_PROPS_INDEX     = 0;
            const AZURE_CLIENT_DMETHOD_RESP_INDEX   = 0;
            const AZURE_CLIENT_CALLBACK_INDEX       = 1;
            const AZURE_CLIENT_TIMESTAMP_INDEX      = 2;

            _msgBeingSent       = {};
            _twinUpdateRequests = {};
            _dMethodCalls       = {};
            _pendingCalls       = [];

            _options = {
                "qos" : AZURE_CLIENT_DEFAULT_QOS,
                "keepAlive" : AZURE_CLIENT_DEFAULT_KEEP_ALIVE,
                "twinsTimeout" : AZURE_CLIENT_DEFAULT_TWINS_TIMEOUT,
                "dMethodsTimeout" : AZURE_CLIENT_DEFAULT_DMETHODS_TIMEOUT,
                "maxPendingTwinRequests" : AZURE_CLIENT_DEFAULT_TWIN_UPD_PARAL_REQS,
                "maxPendingSendRequests" : AZURE_CLIENT_DEFAULT_MSG_SEND_PARAL_REQS,
                "tokenTTL" : AZURE_CLIENT_DEFAULT_TOKEN_TTL,
                "tokenAutoRefresh" : true
            };

            _onConnectedCb      = onConnected;
            _onDisconnectedCb   = onDisconnected;

            // TODO: Allow for registryConnStr?
            _connStrParsed = AzureIoTHub.ConnectionString.Parse(deviceConnStr);
            _mqttclient = mqtt.createclient();
            _mqttclient.onconnect(_onConnected.bindenv(this));
            _mqttclient.onconnectionlost(_onDisconnected.bindenv(this));
            _mqttclient.onmessage(_onMessage.bindenv(this));

            foreach (optName, optVal in options) {
                _options[optName] <- optVal;
            }

            _msgOptions = {
                "qos" : _options.qos
            };

            _initTopics(_connStrParsed.DeviceId);

            local devPath = "/" + _connStrParsed.DeviceId;
            local username = format("%s%s/api-version=%s", _connStrParsed.HostName, devPath, AZURE_API_VERSION);
            local resourcePath = format("/devices%s/api-version=%s", devPath, AZURE_API_VERSION);
            _resourceUri = AzureIoTHub.Authorization.encodeUri(_connStrParsed.HostName + resourcePath);
            _mqttOptions = {
                "username" : username,
                "password" : null,
                "keepalive" : _options.keepAlive
            };
            _url = "ssl://" + _connStrParsed.HostName;
        }

        // Opens a connection to Azure IoT Hub.
        //
        // Returns:                         Nothing.
        function connect() {
            _log("Call: connect()");
            if (_isConnected || _isConnecting) {
                _onConnectedCb && _onConnectedCb(_isConnected ? AZURE_CLIENT_ERROR_ALREADY_CONNECTED : AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW);
                return;
            }

            _log("Connecting...");
            _isConnecting = true;

            _updatePasswd();
            _mqttclient.connect(_url, _connStrParsed.DeviceId, _mqttOptions);
        }

        // Closes the connection to Azure IoT Hub. Does nothing if the connection is already closed.
        //
        // Returns:                         Nothing.
        function disconnect() {
            _log("Call: disconnect()");
            if ((!_isDisconnected || _isConnecting) && !_isDisconnecting) {
                _isDisconnecting = true;
                if (_isRefreshingToken) {
                    _log("Token refreshing is in progress now. Putting the request (disconnect) to the queue...");
                    _pendingCalls.append(@() _mqttclient.disconnect(_onDisconnected.bindenv(this)));
                    return;
                }
                if (_isConnecting) {
                    _shouldDisconnect = true;
                    return;
                } 
                _mqttclient.disconnect(_onDisconnected.bindenv(this));
            }
        }

        // Checks if the client is connected to Azure IoT Hub.
        //
        // Returns:                         Boolean: true if the client is connected, false otherwise.
        function isConnected() {
            _log("Call: isConnected()");
            return _isConnected;
        }

        // Sends a message to Azure IoT Hub (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-mqtt-support#sending-device-to-cloud-messages).
        //
        // Parameters:
        //     msg : AzureIoTHub.Message    Message to send.
        //     onSent : Function            Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onSent(error, msg), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //                                      msg :               The original message passed to sendMessage() method.
        //                                          AzureIoTHub.Message
        //
        // Returns:                         Nothing.
        function sendMessage(msg, onSent = null) {
            _log("Call: sendMessage()");
            if (!_isConnected || _isDisconnecting) {
                onSent && onSent(_isConnected ? AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_CLIENT_ERROR_NOT_CONNECTED, msg);
                return;
            }

            if (_isRefreshingToken) {
                _log("Token refreshing is in progress now. Putting the request (sendMessage) to the queue...");
                // We don't do bindenv here because we do it for the function which processes the _pendingCalls queue
                _pendingCalls.append(@() sendMessage(msg, onSent));
                return;
            }

            local tooManyRequests = _msgBeingSent.len() >= _options.maxPendingSendRequests;

            if (tooManyRequests) {
                onSent && onSent(AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW, msg);
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
                    _log("Exception at parsing the properties: " + e);
                    onSent && onSent(AZURE_ERROR_GENERAL, msg);
                    return;
                }
            }
            local topic = _topics.msgSend + props;
            local reqId = _reqNum++;

            local mqttMsg = _mqttclient.createmessage(topic, msg.getBody(), _msgOptions);

            local msgSentCb = function (err) {
                if (reqId in _msgBeingSent) {
                    delete _msgBeingSent[reqId];
                    _refreshingPaused && _continueRefreshing();
                    onSent && onSent(err, msg);
                }
            }.bindenv(this);

            _msgBeingSent[reqId] <- [msg, onSent];
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
            _log("Call: enableIncomingMessages()");
            local enabled = _onMessageCb != null;
            local disable = onReceive == null;

            if (!_readyToEnable(_isEnablingMsg, enabled, disable, onDone)) {
                return;
            }

            if (_isRefreshingToken) {
                _log("Token refreshing is in progress now. Putting the request (enableIncomingMessages) to the queue...");
                _pendingCalls.append(@() enableIncomingMessages(onReceive, onDone));
                return;
            }

            local doneCb = function (err, qos = null) {
                if (_isEnablingMsg) {
                    _msgEnabledCb = null;
                    _isEnablingMsg = false;
                    _refreshingPaused && _continueRefreshing();
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
                _mqttclient.unsubscribe(topic, doneCb);
            } else {
                // Should subscribe
                _mqttclient.subscribe(topic, _options.qos, doneCb);
            }
        }

        // Enables or disables Azure IoT Hub Device Twins functionality (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-device-twins).
        //
        // Parameters:
        //     onRequest : Function         Callback called every time a new request with desired Device Twin properties is received. null disables the feature.
        //                                  The callback signature:
        //                                  onRequest(props), where
        //                                      props : Table       Key-value table with the desired properties and their version.
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
            _log("Call: enableTwin()");
            local enabled = _onTwinReqCb != null;
            local disable = onRequest == null;

            if (!_readyToEnable(_isEnablingTwin, enabled, disable, onDone)) {
                return;
            }

            if (_isRefreshingToken) {
                _log("Token refreshing is in progress now. Putting the request (enableTwin) to the queue...");
                _pendingCalls.append(@() enableTwin(onRequest, onDone));
                return;
            }

            local doneTwinRecvCb = function (err, qos = null) {
                if (_isEnablingTwin) {
                    _twinEnabledCb = null;
                    _isEnablingTwin = false;
                    _refreshingPaused && _continueRefreshing();
                    if (err == 0) {
                        _onTwinReqCb = onRequest;
                        _ok(onDone);
                    } else {
                        _error(onDone, err);
                    }
                }
            }.bindenv(this);

            local doneTwinNotifCb = function (err, qos = null) {
                if (_isEnablingTwin) {
                    if (err == 0) {
                        local topic = _topics.twinRecv + "#";
                        if (disable) {
                            _mqttclient.unsubscribe(topic, doneTwinRecvCb);
                        } else {
                            _mqttclient.subscribe(topic, _options.qos, doneTwinRecvCb);
                        }
                    } else {
                        _twinEnabledCb = null;
                        _isEnablingTwin = false;
                        _refreshingPaused && _continueRefreshing();
                        _error(onDone, err);
                    }
                }
            }.bindenv(this);

            local topic = _topics.twinNotif + "#";
            _twinEnabledCb = onDone;
            _isEnablingTwin = true;

            if (disable) {
                // Should unsubscribe
                _mqttclient.unsubscribe(topic, doneTwinNotifCb);
            } else {
                // Should send subscribe packet for notifications and GET
                _mqttclient.subscribe(topic, _options.qos, doneTwinNotifCb);
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
            _log("Call: retrieveTwinProperties()");
            local enabled = _onTwinReqCb != null;
            local isRetrieving = _twinRetrievedCb != null;

            if (!_isConnected || _isDisconnecting) {
                onRetrieved(_isConnected ? AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_CLIENT_ERROR_NOT_CONNECTED, null, null);
                return;
            }

            if (!enabled) {
                onRetrieved(AZURE_CLIENT_ERROR_NOT_ENABLED, null, null);
                return;
            }

            // Only one retrieve operation at a time is allowed
            if (isRetrieving) {
                onRetrieved(AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW, null, null);
                return;
            }

            if (_isRefreshingToken) {
                _log("Token refreshing is in progress now. Putting the request (retrieveTwinProperties) to the queue...");
                _pendingCalls.append(@() retrieveTwinProperties(onRetrieved));
                return;
            }

            local reqId = _reqNum.tostring();
            local topic = _topics.twinGet + "?$rid=" + reqId;
            _reqNum++;

            local mqttMsg = _mqttclient.createmessage(topic, "", _msgOptions);

            local msgSentCb = function (err) {
                if (_twinRetrievedCb != null) {
                    if (err == 0) {
                        _twinRetrievedCb = [reqId, onRetrieved, time()];
                        if (_processQueuesTimer == null) {
                            _processQueuesTimer = imp.wakeup(_options.twinsTimeout, _processQueues.bindenv(this));
                        }
                    } else {
                        _twinRetrievedCb = null;
                        _refreshingPaused && _continueRefreshing();
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
        //     props : Table                Key-value table with the reported properties.
        //                                  Every key is always a String with the name of the property.
        //                                  The value is the corresponding value of the property.
        //                                  Keys and values are fully application specific.
        //     onUpdated : Function         Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onUpdated(error, props), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //                                      props : Table       The original properties passed to the updateTwinProperties() method.
        //
        // Returns:                         Nothing.
        function updateTwinProperties(props, onUpdated = null) {
            _log("Call: updateTwinProperties()");
            local enabled = _onTwinReqCb != null;
            local tooManyRequests = _twinUpdateRequests.len() >= _options.maxPendingTwinRequests;

            if (!_isConnected || _isDisconnecting) {
                onUpdated && onUpdated(_isConnected ? AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_CLIENT_ERROR_NOT_CONNECTED, props);
                return;
            }

            if (!enabled) {
                onUpdated && onUpdated(AZURE_CLIENT_ERROR_NOT_ENABLED, props);
                return;
            }

            if (tooManyRequests) {
                onUpdated && onUpdated(AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW, props);
                return;
            }

            if (_isRefreshingToken) {
                _log("Token refreshing is in progress now. Putting the request (updateTwinProperties) to the queue...");
                _pendingCalls.append(@() updateTwinProperties(props, onUpdated));
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
                _log("Exception at parsing the properties: " + e);
                onUpdated && onUpdated(AZURE_ERROR_GENERAL, props);
                return;
            }
            local mqttMsg = _mqttclient.createmessage(topic, jsonProps, _msgOptions);

            local msgSentCb = function (err) {
                if (reqId in _twinUpdateRequests) {
                    if (err == 0) {
                        _twinUpdateRequests[reqId] = [props, onUpdated, time()];
                        if (_processQueuesTimer == null) {
                            _processQueuesTimer = imp.wakeup(_options.twinsTimeout, _processQueues.bindenv(this));
                        }
                    } else {
                        delete _twinUpdateRequests[reqId];
                        _refreshingPaused && _continueRefreshing();
                        onUpdated && onUpdated(err, props);
                    }
                }
            }.bindenv(this);

            _twinUpdateRequests[reqId] <- [props, onUpdated, null];
            mqttMsg.sendasync(msgSentCb);
        }

        // Enables or disables Azure IoT Hub Direct Methods (https://docs.microsoft.com/en-us/azure/iot-hub/iot-hub-devguide-direct-methods).
        //
        // Parameters:
        //     onMethod : Function          Callback called every time a direct method is called. null disables the feature.
        //                                  The callback signature:
        //                                  onMethod(name, params, reply), where
        //                                      name : String       Name of the called Direct Method.
        //                                      params : Table      Key-value table with the input parameters of the called Direct Method.
        //                                                          Every key is always a String with the name of the property.
        //                                                          The value is the corresponding value of the property.
        //                                                          Keys and values are fully application specific.
        //                                      reply : Function    Function which should be called to reply to the call of Direct Method.
        //                                                          The function signature:
        //                                                          reply(data, onReplySent), where
        //                                                              data :          An instance of the AzureIoTHub.DirectMethodResponse.
        //                                                                  AzureIoTHub.DirectMethodResponse
        //                                                              onReplySent :   Callback called when the operation is completed or
        //                                                                  Function    an error happens.
        //                                                                  (optional)  The callback signature:
        //                                                                              onReplySent(error, data), where
        //                                                                                  error : Integer     0 if the operation is completed
        //                                                                                                      successfully, an error code otherwise.
        //                                                                                  data :              The original data passed to reply().
        //                                                                                      AzureIoTHub.DirectMethodResponse
        //     onDone : Function            Callback called when the operation is completed or an error happens.
        //          (optional)              The callback signature:
        //                                  onDone(error), where
        //                                      error : Integer     0 if the operation is completed successfully, an error code otherwise.
        //
        // Returns:                         Nothing.
        function enableDirectMethods(onMethod, onDone = null) {
            _log("Call: enableDirectMethods()");
            local enabled = _onMethodCb != null;
            local disable = onMethod == null;

            if (!_readyToEnable(_isEnablingDMethod, enabled, disable, onDone)) {
                return;
            }

            if (_isRefreshingToken) {
                _log("Token refreshing is in progress now. Putting the request (enableDirectMethods) to the queue...");
                _pendingCalls.append(@() enableDirectMethods(onMethod, onDone));
                return;
            }

            local doneCb = function (err, qos = null) {
                if (_isEnablingDMethod) {
                    _dMethodEnabledCb = null;
                    _isEnablingDMethod = false;
                    _refreshingPaused && _continueRefreshing();
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
                _mqttclient.subscribe(topic, _options.qos, doneCb);
            }
        }

        // Enables or disables the client debug output. Disabled by default.
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

        function _updatePasswd() {
            local sasExpTime = time() + _options.tokenTTL;
            local sas = AzureIoTHub.SharedAccessSignature(_resourceUri, null, _connStrParsed.SharedAccessKey, sasExpTime).toString();
            _tokenExpiresAt = sasExpTime;
            _mqttOptions.password = sas;
        }

        function _onConnected(err) {
            if (_isRefreshingToken) {
                if (err == 0) {
                    _log("Reconnected with new token!");
                    local onResubscribed = function(resubErr) {
                        _isRefreshingToken = false;
                        if (resubErr == 0) {
                            _refreshTokenTimer = imp.wakeup(_timeBeforeRefreshing(), _refreshToken.bindenv(this));
                            _runPendingCalls();
                        } else {
                            _log("Cannot resubscribe to the topics which was subscribed to before the reconnection: " + resubErr);
                            _mqttclient.disconnect(_onDisconnected.bindenv(this));
                        }
                    }.bindenv(this);
                    _resubscribe(onResubscribed);
                } else {
                    _isRefreshingToken = false;
                    _log("Can't connect while refreshing token. Return code: " + err);
                    _onDisconnected();
                }
                return;
            }

            if (_shouldDisconnect) {
                _log("Disconnect called while connecting.");
                if (err == 0) {
                    _log("Triggering disconnect.");
                    _isConnected = true;
                    _isDisconnected = false;
                    _mqttclient.disconnect(_onDisconnected.bindenv(this));
                } else {
                    _log("Connection attempt failed. Return code: " + err);
                }
                _shouldDisconnect = false;
                _isConnecting = false;
                return;
            } 

            if (err == 0) {
                _log("Connected!");
                _isConnected = true;
                _isDisconnected = false;
                if (_options.tokenAutoRefresh) {
                    _refreshTokenTimer = imp.wakeup(_timeBeforeRefreshing(), _refreshToken.bindenv(this));
                }
            }

            _isConnecting = false;
            _onConnectedCb && _onConnectedCb(err);
        }

        function _onDisconnected() {
            _log("Disconnected!");
            local reason = _isDisconnecting ? 0 : AZURE_ERROR_GENERAL;
            _cleanup();
            _onDisconnectedCb && _onDisconnectedCb(reason);
        }

        function _refreshToken() {
            if (_refreshTokenTimer != null) {
                imp.cancelwakeup(_refreshTokenTimer);
                _refreshTokenTimer = null;
            }

            _refreshingPaused = false;
            if (!_isConnected || _isDisconnecting) {
                _refreshTokenTimer = null;
                return;
            }

            _log("Trying to refresh token...");

            if (_isBusy()) {
                _refreshingPaused = true;
                _log("There are running operations now. Refresh token later.");
                return;
            }

            _log("Refreshing started");
            _isRefreshingToken = true;

            local onDisconnected = function() {
                _log("Disconnected");
                _updatePasswd();
                _mqttclient.connect(_url, _connStrParsed.DeviceId, _mqttOptions);
            }.bindenv(this);

            _mqttclient.disconnect(onDisconnected);
        }

        function _continueRefreshing() {
            if (!_isBusy()) {
                _refreshToken();
            }
        }

        function _isBusy() {
            local isEnabling = _isEnablingMsg || _isEnablingTwin || _isEnablingDMethod;
            local havePendingRequests = _msgBeingSent.len() > 0 || !_areQueuesEmpty();
            return havePendingRequests || isEnabling || _isRefreshingToken;
        }

        function _resubscribe(callback) {
            local topicsToSubscribe = [];
            _onMessageCb != null && topicsToSubscribe.append(_topics.msgRecv + "#");
            _onTwinReqCb != null && topicsToSubscribe.append(_topics.twinRecv + "#");
            _onTwinReqCb != null && topicsToSubscribe.append(_topics.twinNotif + "#");
            _onMethodCb  != null && topicsToSubscribe.append(_topics.dMethodNotif + "#");

            local n = topicsToSubscribe.len();
            if (n == 0) {
                _log("No topics to resubscribe");
                callback(0);
                return;
            }

            local i = 0;
            local subscribedCb = null;
            subscribedCb = function(err, qos) {
                if (err != 0) {
                    callback(err);
                } else if (i == n) {
                    _log("Resubscribed");
                    callback(0);
                } else {
                    _mqttclient.subscribe(topicsToSubscribe[i], _options.qos, subscribedCb);
                    i++;
                }
            }.bindenv(this);

            subscribedCb(0, 0);
        }

        function _runPendingCalls() {
            if (_pendingCalls.len() == 0) {
                return;
            }
            _log("There are " + _pendingCalls.len() + " pending requests. Starting to process them now...");
            foreach (call in _pendingCalls) {
                call();
            }
            _pendingCalls = [];
            _log("All pending requests were resumed");
        }

        function _timeBeforeRefreshing() {
            local refreshAfter = _tokenExpiresAt - time();
            return refreshAfter > 0 ? refreshAfter : 0;
        }

        function _onMessage(msg) {
            local message = null;
            local topic = null;
            try {
                message = msg["message"];
                topic = msg["topic"];
                if (_debugEnabled) {
                    _log(format("_onMessage: topic=%s | body=%s", topic, message.tostring()));
                }
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
                _logMsg(message.tostring(), topic);
                return;
            }
            _onMessageCb(AzureIoTHub.Message(message, props));
        }

        function _handleDesPropsMsg(message, topic) {
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
            if (reqId in _twinUpdateRequests) {
                _handleTwinUpdateResponse(reqId, status);
            // Twin's properties received after GET request
            } else if (_twinRetrievedCb != null && _twinRetrievedCb[AZURE_CLIENT_REQ_ID_INDEX] == reqId) {
                _handleTwinGetResponse(reqId, status, parsedMsg);
            } else {
                _logError("Message with unknown request ID received: " + reqId);
                _logMsg(message, topic);
            }
        }

        function _handleTwinUpdateResponse(reqId, status) {
            local arr = delete _twinUpdateRequests[reqId];
            // If no pending requests, cancel the timer
            _queuesMayBeEmpty();
            local props = arr[AZURE_CLIENT_TWIN_PROPS_INDEX];
            local cb = arr[AZURE_CLIENT_CALLBACK_INDEX];
            _refreshingPaused && _continueRefreshing();
            if (_statusIsOk(status)) {
                cb && cb(0, props);
            } else {
                cb && cb(status, props);
            }
        }

        function _handleTwinGetResponse(reqId, status, parsedMsg) {
            local cb = _twinRetrievedCb[AZURE_CLIENT_CALLBACK_INDEX];
            _twinRetrievedCb = null;
            // If no pending requests, cancel the timer
            _queuesMayBeEmpty();
            _refreshingPaused && _continueRefreshing();
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
                _log("Exception at parsing the message: " + e);
                cb(AZURE_ERROR_GENERAL, null, null);
                return;
            }
            cb(0, repProps, desProps);
        }

        function _handleDirMethodMsg(message, topic) {
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

            _dMethodCalls[reqId] <- [null, null, time()];

            if (_processQueuesTimer == null) {
                _processQueuesTimer = imp.wakeup(_options.dMethodsTimeout, _processQueues.bindenv(this));
            }
            _onMethodCb(methodName, params, _dMethodReply(reqId));
        }

        function _dMethodReply(reqId) {
            return function(resp, onReplySent = null) {
                if (!(reqId in _dMethodCalls)) {
                    onReplySent && onReplySent(AZURE_CLIENT_ERROR_OP_TIMED_OUT, resp);
                    return;
                }
                if (time() - _dMethodCalls[reqId][AZURE_CLIENT_TIMESTAMP_INDEX] > _options.dMethodsTimeout) {
                    _dMethodReplied(AZURE_CLIENT_ERROR_OP_TIMED_OUT, reqId, resp, onReplySent);
                    return;
                }

                local topic = _topics.dMethodResp + format("%i/?$rid=%s", resp._status, reqId);

                local respJson = null;
                try {
                    respJson = http.jsonencode(resp._body);
                } catch (e) {
                    _log("Exception at parsing the response body for Direct Method: " + e);
                    _dMethodReplied(AZURE_ERROR_GENERAL, reqId, resp, onReplySent);
                    return;
                }

                local mqttMsg = _mqttclient.createmessage(topic, respJson, _msgOptions);

                local msgSentCb = function (err) {
                    if (reqId in _dMethodCalls) {
                        _dMethodReplied(err, reqId, resp, onReplySent);
                    }
                }.bindenv(this);

                _dMethodCalls[reqId][AZURE_CLIENT_DMETHOD_RESP_INDEX] = resp;
                _dMethodCalls[reqId][AZURE_CLIENT_CALLBACK_INDEX] = onReplySent;

                mqttMsg.sendasync(msgSentCb);
            }.bindenv(this);
        }

        function _dMethodReplied(err, reqId, resp, callback) {
            delete _dMethodCalls[reqId];
            _queuesMayBeEmpty();
            _refreshingPaused && _continueRefreshing();
            callback && callback(err, resp);
        }

        function _queuesMayBeEmpty() {
            if (_areQueuesEmpty() && _processQueuesTimer != null) {
                imp.cancelwakeup(_processQueuesTimer);
                _processQueuesTimer = null;
            }
        }

        function _areQueuesEmpty() {
            return _twinRetrievedCb == null && _twinUpdateRequests.len() == 0 && _dMethodCalls.len() == 0;
        }

        function _processQueues() {
            if (_processQueuesTimer != null) {
                imp.cancelwakeup(_processQueuesTimer);
                _processQueuesTimer = null;
            }

            _cleanTwinsQueue();
            _cleanDMethodQueue();

            if (_areQueuesEmpty()) {
                _refreshingPaused && _continueRefreshing();
            } else if (_processQueuesTimer == null) {
                local minTimeout = _options.twinsTimeout < _options.dMethodsTimeout ? _options.twinsTimeout : _options.dMethodsTimeout;
                _processQueuesTimer = imp.wakeup(minTimeout, _processQueues.bindenv(this));
            }
        }

        function _cleanTwinsQueue() {
            local now = time();
            local cb = null;
            local timestamp = null;
            // If _twinRetrievedCb is not null it is guaranteed to be array of length 3
            local isPending = _twinRetrievedCb != null && _twinRetrievedCb[AZURE_CLIENT_TIMESTAMP_INDEX] != null;

            if (isPending) {
                cb = _twinRetrievedCb[AZURE_CLIENT_CALLBACK_INDEX];
                timestamp = _twinRetrievedCb[AZURE_CLIENT_TIMESTAMP_INDEX];
                if (now - timestamp >= _options.twinsTimeout) {
                    _twinRetrievedCb = null;
                    cb(AZURE_CLIENT_ERROR_OP_TIMED_OUT, null, null);
                }
            }

            local props = null;
            local callbacks = [];
            foreach (reqId, arr in _twinUpdateRequests) {
                timestamp = arr[AZURE_CLIENT_TIMESTAMP_INDEX];
                isPending = timestamp != null;
                if (isPending &&
                    (now - timestamp >= _options.twinsTimeout)) {
                    props = arr[AZURE_CLIENT_TWIN_PROPS_INDEX];
                    cb = arr[AZURE_CLIENT_CALLBACK_INDEX];
                    delete _twinUpdateRequests[reqId];
                    if (cb != null) {
                        callbacks.append(cb);
                        callbacks.append(props);
                    }
                }
            }
            for (local i = 0; i < callbacks.len(); i += 2) {
                cb = callbacks[i];
                props = callbacks[i + 1];
                cb(AZURE_CLIENT_ERROR_OP_TIMED_OUT, props);
            }
        }

        function _cleanDMethodQueue() {
            local now = time();
            local timestamp = null;
            foreach (reqId, arr in _dMethodCalls) {
                timestamp = arr[AZURE_CLIENT_TIMESTAMP_INDEX];
                // if arr[AZURE_CLIENT_DMETHOD_RESP_INDEX] is not null, the call is being replied now
                if (arr[AZURE_CLIENT_DMETHOD_RESP_INDEX] == null && (now - timestamp >= _options.dMethodsTimeout)) {
                    delete _dMethodCalls[reqId];
                }
            }
        }

        function _readyToEnable(isEnabling, enabled, disable, callback) {
            if (!_isConnected || _isDisconnecting) {
                _error(callback, _isConnected ? AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW : AZURE_CLIENT_ERROR_NOT_CONNECTED);
                return false;
            }

            if (isEnabling) {
                _error(callback, AZURE_CLIENT_ERROR_OP_NOT_ALLOWED_NOW);
                return false;
            }

            if (enabled && !disable) {
                _error(callback, AZURE_CLIENT_ERROR_ALREADY_ENABLED);
                return false;
            }

            if (disable && !enabled) {
                _error(callback, AZURE_CLIENT_ERROR_NOT_ENABLED);
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
            _isDisconnected     = true;
            _isDisconnecting    = false;
            _isConnected        = false;
            _isConnecting       = false;
            _isRefreshingToken  = false;
            _isEnablingMsg      = false;
            _isEnablingTwin     = false;
            _isEnablingDMethod  = false;

            _onMessageCb        = null;
            _onTwinReqCb        = null;
            _onMethodCb         = null;

            _refreshingPaused   = false;

            if (_refreshTokenTimer != null) {
                imp.cancelwakeup(_refreshTokenTimer);
                _refreshTokenTimer = null;
            }

            if (_processQueuesTimer != null) {
                imp.cancelwakeup(_processQueuesTimer);
                _processQueuesTimer = null;
            }

            if (_msgEnabledCb != null) {
                _error(_msgEnabledCb, AZURE_CLIENT_ERROR_NOT_CONNECTED);
                _msgEnabledCb = null;
            }
            if (_twinEnabledCb != null) {
                _error(_twinEnabledCb, AZURE_CLIENT_ERROR_NOT_CONNECTED);
                _twinEnabledCb = null;
            }
            if (_dMethodEnabledCb != null) {
                _error(_dMethodEnabledCb, AZURE_CLIENT_ERROR_NOT_CONNECTED);
                _dMethodEnabledCb = null;
            }

            foreach (reqId, arr in _msgBeingSent) {
                local msg = arr[AZURE_CLIENT_MESSAGE_INDEX];
                local cb = arr[AZURE_CLIENT_CALLBACK_INDEX];
                cb && cb(AZURE_CLIENT_ERROR_NOT_CONNECTED, msg);
            }
            _msgBeingSent = {};

            if (_twinRetrievedCb != null) {
                local cb = _twinRetrievedCb[AZURE_CLIENT_CALLBACK_INDEX];
                _twinRetrievedCb = null;
                cb(AZURE_CLIENT_ERROR_NOT_CONNECTED, null, null);
            }

            foreach (reqId, arr in _twinUpdateRequests) {
                local props = arr[AZURE_CLIENT_TWIN_PROPS_INDEX];
                local cb = arr[AZURE_CLIENT_CALLBACK_INDEX];
                cb && cb(AZURE_CLIENT_ERROR_NOT_CONNECTED, props);
            }
            _twinUpdateRequests = {};

            foreach (reqId, arr in _dMethodCalls) {
                local resp = arr[AZURE_CLIENT_DMETHOD_RESP_INDEX];
                local cb = arr[AZURE_CLIENT_CALLBACK_INDEX];
                cb && cb(AZURE_CLIENT_ERROR_NOT_CONNECTED, resp);
            }
            _dMethodCalls = {};

            _runPendingCalls();
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
            server.error("[" + (typeof this) + "] " + txt);
        }
    }

}
