// MIT License
//
// Copyright 2018 Electric Imp
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

const AZURE_DPS_SCOPE_ID = "@{AZURE_DPS_SCOPE_ID}";
const AZURE_DPS_REGISTRATION_ID = "@{AZURE_DPS_REGISTRATION_ID}";
const AZURE_DPS_DEVICE_KEY = "@{AZURE_DPS_DEVICE_KEY}";

class DPSTestCase extends ImpTestCase {
    _azureDPS = null;

    function setUp() {
        _azureDPS = AzureIoTHub.DPS(AZURE_DPS_SCOPE_ID, AZURE_DPS_REGISTRATION_ID, AZURE_DPS_DEVICE_KEY);
    }

    function testRegister() {
        return _register();
    }

    function testGetConnStr() {
        return _getConnStr();
    }

    function testRegAndGetConnStr() {
        return _register()
            .then(function (value) {
                return _getConnStr();
            }.bindenv(this))
            .fail(function (reason) {
                return Promise.reject(reason);
            }.bindenv(this));
    }

    function _register() {
        return Promise(function (resolve, reject) {
            _azureDPS.register(function (err, resp, connStr) {
                if (err != 0) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }

    function _getConnStr() {
        return Promise(function (resolve, reject) {
            _azureDPS.getConnectionString(function (err, resp, connStr) {
                if (err != 0 && err != AZURE_DPS_ERROR_NOT_REGISTERED) {
                    return reject(err);
                }
                return resolve();
            }.bindenv(this));
        }.bindenv(this));
    }
}