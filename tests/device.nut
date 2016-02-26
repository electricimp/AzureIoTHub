#require "WS2812.class.nut:2.0.1"

/**
 * This file will be removed upon PR merge
 */

hardware.spi257.configure(MSB_FIRST, 7500);
local leds = WS2812(hardware.spi257, 5);

i <- 0;
d <- 1;

function step() {
    imp.wakeup(0.05, step);

    leds.fill([0, 0, 50], 0, 4)
        .set(i, [0, 255, 255])
        .draw();

    i += d;
    if (i == 4 || i == 0) d = -d;
}

step();
