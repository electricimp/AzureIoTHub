# Test Instructions

The tests in the current directory are intended to check the behavior of the AzureIoTHub library.

They are written for and should be used with [impt](https://github.com/electricimp/imp-central-impt). See [impt Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for the details of how to configure and run the tests.

The tests for AzureIoTHub library require pre-setup described below.

## Configure Azure IoT Hub

1. [Sign up for Azure portal](TODO)

2. [Create an IoT Hub resource](TODO) and obtain the **Registry connection string**

3. [Register a device in IoT Hub](TODO) and obtain the **Device connection string**

## Set Environment Variables

- Set *AZURE_REGISTRY_CONN_STRING* environment variable to the value of **Registry connection string** you retrieved and saved in the previous steps.\
The value should look like `HostName=<Host Name>;SharedAccessKeyName=<Key Name>;SharedAccessKey=<SAS Key>`.
- Set *AZURE_DEVICE_CONN_STRING* environment variable to the value of **Device connection string** you retrieved and saved in the previous steps.\
The value should look like `HostName=<Host Name>;DeviceId=<Device Name>;SharedAccessKey=<Device Key>`.
- For integration with [Travis](https://travis-ci.org) set *EI_LOGIN_KEY* environment variable to the valid impCentral login key.

## Run Tests

- See [impt Testing Guide](https://github.com/electricimp/imp-central-impt/blob/master/TestingGuide.md) for the details of how to configure and run the tests.
- Run [impt](https://github.com/electricimp/imp-central-impt) commands from the [root directory of the lib](../). It contains a default test configuration file which should be updated by *impt* commands for your testing environment (at least the Device Group must be updated).
