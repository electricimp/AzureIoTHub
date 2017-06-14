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

#require "HTS221.device.lib.nut:2.0.0"
#require "WS2812.class.nut:3.0.0"

// ExplorerKit Hardware Abstraction Layer
ExplorerKit_001 <- {
    "LED_SPI" : hardware.spi257,
    "SENSOR_AND_GROVE_I2C" : hardware.i2c89,
    "TEMP_HUMID_I2C_ADDR" : 0xBE,
    "ACCEL_I2C_ADDR" : 0x32,
    "PRESSURE_I2C_ADDR" : 0xB8,
    "POWER_GATE_AND_WAKE_PIN" : hardware.pin1,
    "AD_GROVE1_DATA1" : hardware.pin2,
    "AD_GROVE2_DATA1" : hardware.pin5
}

class Application {

    static READING_INTERVAL = 10;
    static BLINK_SEC = 0.5;

    tempHumid = null;
    led = null;

    constructor() {
        // Configure Temperature Humidity Sensor
        local i2c = ExplorerKit_001.SENSOR_AND_GROVE_I2C;
        i2c.configure(CLOCK_SPEED_400_KHZ);
        tempHumid = HTS221(i2c, ExplorerKit_001.TEMP_HUMID_I2C_ADDR);
        tempHumid.setMode(HTS221_MODE.ONE_SHOT);

        // Configure LED
        local spi = ExplorerKit_001.LED_SPI;
        led = WS2812(spi, 1);
        hardware.pin1.configure(DIGITAL_OUT, 1);

        // Open listener
        agent.on("blink", blinkLED.bindenv(this));

        // Give the agent time to connect to Azure
        // then start the loop
        imp.wakeup(5, loop.bindenv(this));
    }

    function loop() {
        tempHumid.read(function(result) {
            if ("error" in result) {
                server.error(result.error);
            } else {
                agent.send("event", result);
            }
            imp.wakeup(READING_INTERVAL, loop.bindenv(this));
        }.bindenv(this));
    }

    function blinkLED(color) {
        local off = [0, 0, 0];
        led.fill(color).draw();
        imp.wakeup(BLINK_SEC, function() {
            led.fill(off).draw();
        }.bindenv(this))
    }

}

Application();