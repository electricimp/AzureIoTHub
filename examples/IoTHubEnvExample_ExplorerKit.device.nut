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

// All library require stametments must be at the beginning of the device code 

// Temperature Humidity Sensor driver
#require "HTS221.device.lib.nut:2.0.0"
// RGB LED driver
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

// Our Application Code 
class Application {

    static RED = 0x00;
    static YELLOW = 0x01;
    static GREEN = 0x02;

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

        // Configure RGB LED
        local spi = ExplorerKit_001.LED_SPI;
        led = WS2812(spi, 1);
        ExplorerKit_001.POWER_GATE_AND_WAKE_PIN.configure(DIGITAL_OUT, 1);

        // Open listener
        agent.on("blink", blinkLED.bindenv(this));

        // Give the agent time to connect to Azure
        // then start the loop
        imp.wakeup(5, loop.bindenv(this));
    }

    function loop() {
        // Take a temperaure reading
        tempHumid.read(function(result) {
            if ("error" in result) {
                server.error(result.error);
            } else {
                // Send reading to the agent
                agent.send("event", result);
            }
            // Schedule next reading
            imp.wakeup(READING_INTERVAL, loop.bindenv(this));
        }.bindenv(this));
    }

    function blinkLED(color) {
        local off = [0, 0, 0];
        local colorArr = null;

        switch (color) {
            case RED :
                colorArr = [50, 0, 0];
                break;
            case YELLOW :
                colorArr = [50, 45, 0];
                break;
            case GREEN : 
                colorArr = [0, 50, 0];
                break; 
        }

        // Turn the LED on
        led.fill(colorArr).draw();
        // Wait BLINK_SEC then turn LED off
        imp.wakeup(BLINK_SEC, function() {
            led.fill(off).draw();
        }.bindenv(this))
    }

}

// Start the application running
Application();
