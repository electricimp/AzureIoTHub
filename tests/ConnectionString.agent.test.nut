/**
 * Test case for AzureIoTHub.ConnectionString
 */

class ConnectionStringTestCase extends ImpTestCase {
    function test1() {
        local s = "HostName=hubname.azure-devices.net;SharedAccessKeyName=keynameSharedAccessKey=key";
        s = AzureIoTHub.ConnectionString.Parse(s);
        this.assertEqual("hubname.azure-devices.net", s.HostName);
        this.assertEqual(null, s.DeviceId);
    }
}
