# Azure IoT Hub Examples #

This document describes the example applications provided with the [AzureIoTHub library](../README.md).

## Messages example ##

The example:
- connects the device to Azure IoT Hub using the provided Device Connection String
- enables cloud-to-device messages functionality
- logs all messages received from the cloud
- periodically (every 10 seconds) sends a message to the cloud. The message contains an integer value and the current timestamp. The value increases by 1 with every sending, it restarts from 1 every time the example is restarted.

Source code: [Messages.agent.nut](./Messages.agent.nut)

See [Messages Example Setup and Run](#messages-example-setup-and-run).

## Direct Methods Example ##

This example:
- automatically registers the device (if not registered yet) using the provided Registry Connection String
- connects the device to Azure IoT Hub using an automatically obtained Device Connection String
- enables Direct Methods functionality
- logs all Direct Method calls received from the cloud, always responds success

Source code: [DirectMethods.agent.nut](./DirectMethods.agent.nut)

See [Direct Methods Example Setup and Run](#direct-methods-example-setup-and-run).

## Twins Example ##

This example:
- automatically registers the device (if not registered yet) via the Device Provisioning Service using the provided Scope ID, Registration ID and Device symmetric key
- connects the device to Azure IoT Hub using an automatically obtained Device Connection String
- enables Twin functionality
- retrieves the Twin's properties (both - Desired and Reported) from the cloud and logs them
- logs all Desired properties received from the cloud, reads the value of the Desired property "test" and sends it back to the cloud as a Reported property

Source code: [Twins.agent.nut](./Twins.agent.nut)

See [Twins Example Setup and Run](#twins-example-setup-and-run).

## IoT Central Example ##

This example:
- computes the Device Symmetric Key using the provided Group Key
- automatically registers the device (if not registered yet) in IoT Central via the Device Provisioning Service using the provided Scope ID, Registration ID and computed Device Symmetric Key
- connects the device to Azure IoT Hub using an automatically obtained Device Connection String
- enables Twin functionality
- receives Settings updates from IoT Central (it is just an update of Desired properties)
- confirms Settings updates by updating Reported properties
- sends the value of a property "test" (from received Settings/Desired properties) as a telemetry data by sending a device-to-cloud message

Source code: [IoTCentral.agent.nut](./IoTCentral.agent.nut)

See [IoT Central Example Setup and Run](#iot-central-example-setup-and-run).

## Example Setup and Run ##

### Messages Example Setup and Run ###

1. [Login To Azure Portal](#login-to-azure-portal)

2. [Create IoT Hub Resource](#create-iot-hub-resource) (if not created yet)

3. [Manually Register Device And Obtain Device Connection String](#manually-register-device-and-obtain-device-connection-string)

4. [Set up your Imp device](https://developer.electricimp.com/gettingstarted)

5. In the [Electric Imp's IDE](https://ide.electricimp.com) create new Product and Development Device Group.

6. Assign a device to the newly created Device Group.

7. Copy the [Messages example source code](./Messages.agent.nut) and paste it into the IDE as the agent code.

8. Set *AZURE_DEVICE_CONN_STRING* constant in the agent example code to the **Device Connection String** you obtained and saved earlier.
The value should look like `HostName=<Host Name>;DeviceId=<Device Name>;SharedAccessKey=<Device Key>`.

![MessagesSetConst](./example_imgs/MessagesSetConst.png)

9. Click **Build and Force Restart**.

10. Check from the logs in the IDE that messages are successfully sent from the device (periodically)

![SendMessagesLogs](./example_imgs/SendMessagesLogs.png)

11. [Send Message To Device](#send-message-to-device) from the Azure Portal and check from the logs in the IDE that the message is received successfully

![ReceiveMessagesLogs](./example_imgs/ReceiveMessagesLogs.png)

### Direct Methods Example Setup and Run ###

1. [Login To Azure Portal](#login-to-azure-portal)

2. [Create IoT Hub Resource](#create-iot-hub-resource) (if not created yet)

3. [Obtain Registry Connection String](#obtain-registry-connection-string)

4. [Set up your Imp device](https://developer.electricimp.com/gettingstarted)

5. In the [Electric Imp's IDE](https://ide.electricimp.com) create new Product and Development Device Group.

6. Assign a device to the newly created Device Group.

7. Copy the [Direct Methods example source code](./DirectMethods.agent.nut) and paste it into the IDE as the agent code.

8. Set *AZURE_REGISTRY_CONN_STRING* constant in the agent example code to the **Registry Connection String** you obtained and saved earlier.
The value should look like `HostName=<Host Name>;SharedAccessKeyName=<Key Name>;SharedAccessKey=<SAS Key>`.

![DirectMethodsSetConst](./example_imgs/DirectMethodsSetConst.png)

9. Click **Build and Force Restart**.

10. Check from the logs in the IDE that the device is registered and connected

![StartDirectMethodsLogs](./example_imgs/StartDirectMethodsLogs.png)

11. [Call Direct Method](#call-direct-method) from the Azure Portal and check from the logs in the IDE that the call is received

![CallDirectMethodsLogs](./example_imgs/CallDirectMethodsLogs.png)

12. In the Azure Portal, check that the result of the call is received.

### Twins Example Setup and Run ###

1. [Login To Azure Portal](#login-to-azure-portal)

2. [Create IoT Hub Resource](#create-iot-hub-resource) (if not created yet)

3. [Create IoT Hub DPS Resource](#create-iot-hub-dps-resource) (if not created yet)

4. [Link The IoT Hub To DPS](#link-an-iot-hub-to-dps)

5. [Create An Individual Enrollment](#create-an-individual-enrollment)

6. [Set up your Imp device](https://developer.electricimp.com/gettingstarted)

7. In the [Electric Imp's IDE](https://ide.electricimp.com) create new Product and Development Device Group.

8. Assign a device to the newly created Device Group.

9. Copy the [Twins example source code](./Twins.agent.nut) and paste it into the IDE as the agent code.

10. Set constants in the agent example code:
 - *AZURE_DPS_SCOPE_ID*: set the **Scope ID** from the [step 3](#create-iot-hub-device-provisioning-service-resource)
 - *AZURE_DPS_REGISTRATION_ID*: set the **Registration ID** from the [step 5](#create-an-individual-enrollment)
 - *AZURE_DPS_DEVICE_KEY*: set the **Device Symmetric Key** from the [step 5](#create-an-individual-enrollment)

![TwinsSetConst](./example_imgs/TwinsSetConst.png)

11. Click **Build and Force Restart**.

12. Check from the logs in the IDE that the device is registered, connected, and twin's properties are retrieved

![RetrieveTwinLogs](./example_imgs/RetrieveTwinLogs.png)

13. [Update Twin Document](#retrieveupdate-twin-document) from the Azure Portal: add or change, if already exists, the desired property "test". Then check from the logs in the IDE that the desired properties are received and the reported properties are updated.

![UpdateTwinLogs](./example_imgs/UpdateTwinLogs.png)

14. In the Azure Portal, refresh the twin's document and check that the reported properties now contain the "test" property you set in the previous step.

### IoT Central Example Setup and Run ###

1. [Login To Azure IoT Central](#login-to-azure-iot-central)

2. [Create An Application](#create-an-application) (if not created yet)

3. [Setup A Device Template](#setup-a-device-template)

4. [Create A Device](#create-a-device)

5. [Obtain Scope ID And Group Key](#obtain-scope-id-and-group-key)

6. [Set up your Imp device](https://developer.electricimp.com/gettingstarted)

7. In the [Electric Imp's IDE](https://ide.electricimp.com) create new Product and Development Device Group.

8. Assign a device to the newly created Device Group.

9. Copy the [IoT Central example source code](./IoTCentral.agent.nut) and paste it into the IDE as the agent code.

10. Set constants in the agent example code:
 - *AZURE_IOT_CENTRAL_SCOPE_ID*: set the **Scope ID** from the [step 6](#obtain-scope-id-and-group-key)
 - *AZURE_IOT_CENTRAL_DEVICE_ID*: set the **Device ID** from the [step 5](#create-a-device)
 - *AZURE_IOT_CENTRAL_GROUP_KEY*: set the **Group Symmetric Key** from the [step 6](#obtain-scope-id-and-group-key)

![IoTCentralSetConst](./example_imgs/IoTCSetConst.png)

11. Click **Build and Force Restart**.

12. Check from the logs in the IDE that the device is registered and connected

![ConnectIoTCentralLogs](./example_imgs/ConnectIoTCLogs.png)

13. [Update Device Settings](#update-device-settings) in IoT Central and check from the logs that the settings update is received and confirmed

![SettingsUpdateIoTCentralLogs](./example_imgs/SettingsUpdateIoTCLogs.png)

14. [Check Telemetry](#check-telemetry) in IoT Central: you should see a new point on the graph with the number you used in the previous step. The graph update may take a few minutes.

![TelemetryGraphIoTCentralLogs](./example_imgs/TelemetryGraphIoTC.png)

## Azure IoT Hub How To ##

### Login To Azure Portal ###

Login to [Azure portal](https://portal.azure.com/).
If you are not registered, create an account with subscription (free subscription is enough for testing purposes).

### Create IoT Hub Resource ###

1. In the [Azure portal](https://portal.azure.com/), click **New > Internet of Things > IoT Hub**:

![Create IoT hub](./example_imgs/CreateIoTHub.png)

2. In the **IoT Hub** pane, enter the following information for your IoT hub:

 - **Subscription** Select your subscription. You may need to set up a free trial or "Pay-As-You-Go" subscription.

 - **Resource group** Create a resource group to host the IoT hub or use an existing one. See [Using resource groups to manage your Azure resources](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-portal).

 - **Region** Select the location closest to where the IoT hub was created.

 - **IoT Hub name** This is the name for your IoT hub. If the name you enter is valid, a green check mark appears.

![IoT Hub Create Resource](./example_imgs/IoTHubCreateResource1.png)

3. Click **Next: Size and scale** select the free F1 tier for **Pricing and scale tier**. This option is sufficient for this demo. See [pricing and scale tier](https://azure.microsoft.com/pricing/details/iot-hub/).

4. Click **Review + create**.

![IoT Hub Create Resource](./example_imgs/IoTHubCreateResource2.png)

5. Click **Create**. It could take a few minutes for your IoT hub to be created. You can see progress in the **Notifications** pane:

![Notifications](./example_imgs/IoTHubNotifications.png)

### Obtain Registry Connection String ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT hub.

2. Click **Shared access policies**.

3. In the **Shared access policies** pane, click the **registryReadWrite** policy, and then make a note of the **Connection string--primary key** of your IoT hub - this is the **Registry connection string** which may be needed to setup and run your application.

![Connection String](./example_imgs/IoTHubConnectionString.png)

### Manually Register Device And Obtain Device Connection String ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT hub.

2. Click **IoT Devices** in the **DEVICE MANAGEMENT** section.

3. Click **Add** to add a device to your IoT hub. Enter:

 - **Device ID** The ID of the new device. You can type here some arbitrary name.
 - **Authentication Type** Select **Symmetric Key**.
 - **Auto Generate Keys** Check this field.
 - **Connect device to IoT Hub** Click **Enable**.

 ![Device Explorer](./example_imgs/IoTHubDeviceExplorer.png)

4. Click **Save**.

5. After the device is created, open the device in the **IoT Devices** pane.

6. Make a note of the **Connection string--primary key** - this is the **Device connection string** which may be needed to setup and run your application.

![Device connection string](./example_imgs/IoTHubDeviceConnectionString.png)

### Send Message To Device ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT hub.

2. In the IoT hub, open the device you want to send a message to.

3. Click **Message To Device**.

 ![Device Message](./example_imgs/IoTHubSendMessageToDevice1.png)

4. Type some message in the **Message Body** field. Add some properties, if needed.

 ![Device Explorer](./example_imgs/IoTHubSendMessageToDevice2.png)

5. Click **Send Message** to send the message.

### Retrieve/Update Twin Document ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT hub.

2. In the IoT hub, open the device you want to get the twin's document of.

3. Click **Device Twin**.

 ![Device Twin](./example_imgs/IoTHubDeviceTwin1.png)

4. Here you can see and update the twin's document.

 ![Device Twin Retrieve](./example_imgs/IoTHubDeviceTwinRetrieve.png)

5. If you want to update the desired properties, make changes and click **Save**. For example:

 ![Device Twin Update](./example_imgs/IoTHubDeviceTwinUpdate.png)

**Note**: Use **Refresh** button to refresh the document and get the latest changes.

### Call Direct Method ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT hub.

2. In the IoT hub, open the device you want to call a direct method of.

 ![Device Message](./example_imgs/IoTHubDirectMethod.png)

3. Click **Direct Method**. Input some Method Name. Add some payload, if needed. Payload should be a valid JSON or nothing.

 ![Device Explorer](./example_imgs/IoTHubDirectMethodInvoke.png)

4. Click **Invoke Method**.

## Azure IoT Hub Device Provisioning Service (DPS) How To ##

### Create IoT Hub DPS Resource ###

1. In the [Azure portal](https://portal.azure.com/), click **New > Internet of Things > IoT Hub Device Provisioning Service**:

![Create DPS](./example_imgs/CreateDPS.png)

2. In the **IoT Hub Device Provisioning Service** pane, enter the following information for your IoT Hub DPS:

 - **Name** This is the name for your IoT Hub DPS. If the name you enter is valid, a green check mark appears.

 - **Subscription** Select your subscription. You may need to set up a free trial or "Pay-As-You-Go" subscription.

 - **Resource group** Choose the same resource group as for the IoT hub you created in the previous steps.

 - **Location** Select the same location as for the IoT hub.

![DPS Create Resource](./example_imgs/DPSCreateResource.png)

3. Click **Create**. It could take a few minutes for your IoT Hub DPS  to be created. You can see progress in the **Notifications** pane.

4. Once your DPS created, open its **Overview** pane and make a note of the **ID Scope** - this is the **Scope ID** which may be needed to setup and run your application.

![DPS Scope ID](./example_imgs/DPSScopeID.png)

### Link An IoT Hub To DPS ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT Hub DPS.

2. Click **Linked IoT hubs**.

3. Press the **Add** button.

4. In the **Add link to IoT hub** pane, enter the following information:

 - **Subscription** Select your subscription. You may need to set up a free trial or "Pay-As-You-Go" subscription.

 - **IoT hub** Choose the IoT hub you created in the previous steps.

 - **Access Policy** Select **iothubowner**.

![DPS Link An IoT Hub](./example_imgs/DPSLinkAnIoTHub.png)

5. Click **Save**.

### Create An Individual Enrollment ###

1. In the [Azure portal](https://portal.azure.com/), open your IoT Hub DPS.

2. Click **Manage enrollments**.

3. Press the **Add individual enrollment** button.

![DPS Create An Individual Enrollment](./example_imgs/DPSCreateIndEnrollment1.png)

4. In the **Add Enrollment** pane, enter the following information:

 - **Mechanism** This is the name for your IoT Hub DPS. If the name you enter is valid, a green check mark appears.

 - **Auto-generate keys** Check this field.

 - **Registration ID** The ID of the new device. You can type here some arbitrary name.

 - **Select the IoT hubs this group can be assigned to** Make sure the only IoT hub checked is the one you created in the previous steps.

5. Click **Save**.

![DPS Create An Individual Enrollment](./example_imgs/DPSCreateIndEnrollment2.png)

6. Click the **Individual enrollments** tab and open the enrollment you have just created.

![DPS Open Enrollment](./example_imgs/DPSOpenEnrollment.png)

7.Make a note of the **Primary Key** - this is the **Device Symmetric Key** which may be needed to setup and run your application.

![DPS Primary Key](./example_imgs/DPSPrimaryKey.png)

## Azure IoT Central How To ##

### Login To Azure IoT Central ###

Login to [Azure IoT Central](https://apps.azureiotcentral.com/).
If you are not registered, create an account with subscription (free subscription is enough for testing purposes).

### Create An Application ###

1. In [IoT Central](https://apps.azureiotcentral.com/), click **New Application**:

![IoT Central Create App](./example_imgs/IoTCCreateApp1.png)

2. In the application creation pane, enter the following information:

 - **Choose payment plan** Select **Trial**.

 - **Select an application template** Choose **Custom Application**.
 
 - **Application Name** and **URL** May be left default.

![IoT Central Create App](./example_imgs/IoTCCreateApp2.png)

3. Click **Create**.

### Setup A Device Template ###

1. On the **Home** page of your application in [IoT Central](https://apps.azureiotcentral.com/), click **Create Device Templates**:

![IoT Central Create Device Template](./example_imgs/IoTCCreateDevTempl1.png)

2. **Enter the name for your device template**: you can enter any arbitrary name.

![IoT Central Create Device Template](./example_imgs/IoTCCreateDevTempl2.png)

3. Click **Create**.

4. After creation you will be redirected to the template's page. Click **Edit Template**:

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl1.png)

5. In the menu appeared, click **New Measurement** and choose **Telemetry**

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl2.png)

6. In the **Create Telemetry** pane, enter the following information:

 - **Display Name** Enter any name. E.g. **test**.

 - **Field Name** Enter **test**.

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl3.png)

7. Click **Save**.

8. Press the **Done** button:

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl4.png)

9. Open the **Settings** tab and again press the **Edit Template** button:

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl5.png)

10. Click on **Number** in the left-side menu:

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl6.png)

11. In the **Configure Number** pane, enter the following information:

 - **Display Name** Enter any name. E.g. **test**.

 - **Field Name** Enter **test**.

![IoT Central Adjust Device Template](./example_imgs/IoTCAdjustDevTempl7.png)

12. Click **Save** and then **Done**.

### Create A Device ###

1. In your [IoT Central](https://apps.azureiotcentral.com/) application, open **Device Explorer**:

![IoT Central Open Device Explorer](./example_imgs/IoTCOpenDevExplorer.png)

2. Click the **Add** button (with an icon of a plus sign) and choose **Real**:

![IoT Central Create A Device](./example_imgs/IoTCCreateDevice1.png)

3. In the **Create New Device** pane, enter any arbitrary **Device ID** (e.g. **demo-device**) and make a note of it as it may be needed to setup and run your application.

![IoT Central Create A Device](./example_imgs/IoTCCreateDevice2.png)

4. Click **Create**.

### Obtain Scope ID And Group Key ###

1. In your [IoT Central](https://apps.azureiotcentral.com/) application, open **Administration**:

![IoT Central Open Administration](./example_imgs/IoTCOpenAdministration.png)

2. Click **Device Connection** and make a note of **Scope ID** and **Primary Key** - they are **Scope ID** and **Group Symmetric Key** which may be needed to setup and run your application.

![IoT Central Create A Device](./example_imgs/IoTCDeviceConnection.png)

### Update Device Settings ###

1. On the **Explorer** page of your application in [IoT Central](https://apps.azureiotcentral.com/), open the device you want to update settings of:

![IoT Central Open The Device](./example_imgs/IoTCOpenDevice.png)

2. Open the **Settings** tab and type the new value in the field you want to update:

![IoT Central Update Setting](./example_imgs/IoTCUpdSetting.png)

3. Click **Update**.

### Check Telemetry ###

1. On the **Device Explorer** page of your application in [IoT Central](https://apps.azureiotcentral.com/), open the device you want to check telemetry of:

![IoT Central Open The Device](./example_imgs/IoTCOpenDevice.png)

2. Look at the graph. There you can see telemetry updates or "Missing Data" message if no data to show.

![IoT Central Telemetry Graph](./example_imgs/IoTCTeleGraph.png)
