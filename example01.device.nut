
// Create a function that will be called in a minute loop
function getData() {
    imp.wakeup(60, getData);
    
    local event = {
        "light": hardware.lightlevel(),
        "power": hardware.voltage()
    }
    agent.send("event", event);
}

// Now bootstrap the loop
imp.wakeup(10, getData);