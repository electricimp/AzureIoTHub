# Test Instructions #

The tests in the current directory are intended to check the behavior of the AzureIoTHub library.

They are written for and should be used with [impt](https://github.com/electricimp/imp-central-impt). See [impt Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for the details of how to configure and run the tests.

The tests for AzureIoTHub library require pre-setup described below.

## Configure Azure IoT Hub (for all tests except DPS) ##

1. [Login To Azure Portal](../examples/README.md#login-to-azure-portal)

2. [Create IoT Hub Resource](../examples/README.md#create-iot-hub-resource)

3. [Obtain Registry Connection String](../examples/README.md#obtain-registry-connection-string)

4. [Manually Register Device And Obtain Device Connection String](../examples/README.md#manually-register-device-and-obtain-device-connection-string)

## Configure Azure IoT Hub Device Provisioning Service (for DPS test) ##

1. [Login To Azure Portal](../examples/README.md#login-to-azure-portal)

2. [Create IoT Hub Resource](../examples/README.md#create-iot-hub-resource) (if not created yet)

3. [Create IoT Hub DPS Resource](../examples/README.md#create-iot-hub-dps-resource)

4. [Link An IoT Hub To DPS](../examples/README.md#link-an-iot-hub-to-dps)

5. [Create An Individual Enrollment](../examples/README.md#create-an-individual-enrollment)

## Set Environment Variables ##

- Only for **Registry** test. Set *AZURE_REGISTRY_CONN_STRING* environment variable to the value of **Registry Connection String** obtained earlier.\
The value should look like `HostName=<Host Name>;SharedAccessKeyName=<Key Name>;SharedAccessKey=<SAS Key>`.
- Only for **DPS** test. Set *AZURE_DPS_SCOPE_ID* environment variable to the value of **Scope ID** obtained earlier.\
The value should look like `0ne000366B8`.
- Only for **DPS** test. Set *AZURE_DPS_REGISTRATION_ID* environment variable to the value of **Registration ID** obtained earlier.
- Only for **DPS** test. Set *AZURE_DPS_DEVICE_KEY* environment variable to the value of **Device Symmetric Key** obtained earlier.\
The value should look like `n8pmmCJk8FBjliX2ltOoj1vatWUDmSQmjIpyA+mpVCLvakf56HQSoxJRKf47kvFqTD4mY/263DAscLwNbxVrqQ==`.
- For the other tests. Set *AZURE_DEVICE_CONN_STRING* environment variable to the value of **Device Connection String** obtained earlier.\
The value should look like `HostName=<Host Name>;DeviceId=<Device Name>;SharedAccessKey=<Device Key>`.
- For integration with [Travis](https://travis-ci.org) set *EI_LOGIN_KEY* environment variable to the valid impCentral login key.

## Run Tests ##

- See [impt Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for the details of how to configure and run the tests.
- Run [impt](https://github.com/electricimp/imp-central-impt) commands from the root directory of the lib. It contains a default test configuration file which should be updated by *impt* commands for your testing environment (at least the Device Group must be updated).
