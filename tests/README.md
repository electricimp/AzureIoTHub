# Test Instructions

The tests in the current directory are intended to check the behavior of the AzureIoTHub library.

They are written for and should be used with [impt](https://github.com/electricimp/imp-central-impt). See [impt Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for the details of how to configure and run the tests.

The tests for AzureIoTHub library require pre-setup described below.

## Configure Azure IoT Hub

1. [Login To Azure Portal](../examples/README.md#login-to-azure-portal)

2. [Create IoT Hub Resource](../examples/README.md#create-iot-hub-resource)

3. [Obtain Registry Connection String](../examples/README.md#obtain-registry-connection-string)

4. [Manually Register Device And Obtain Device Connection String](../examples/README.md#manually-register-device-and-obtain-device-connection-string)

## Set Environment Variables

- Set *AZURE_REGISTRY_CONN_STRING* environment variable to the value of **Registry Connection String** obtained early.\
The value should look like `HostName=<Host Name>;SharedAccessKeyName=<Key Name>;SharedAccessKey=<SAS Key>`.
- Set *AZURE_DEVICE_CONN_STRING* environment variable to the value of **Device Connection String** obtained early.\
The value should look like `HostName=<Host Name>;DeviceId=<Device Name>;SharedAccessKey=<Device Key>`.
- For integration with [Travis](https://travis-ci.org) set *EI_LOGIN_KEY* environment variable to the valid impCentral login key.

## Run Tests

- See [impt Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for the details of how to configure and run the tests.
- Run [impt](https://github.com/electricimp/imp-central-impt) commands from the [root directory of the lib](../). It contains a default test configuration file which should be updated by *impt* commands for your testing environment (at least the Device Group must be updated).
