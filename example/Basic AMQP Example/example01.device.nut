// Time to wait between readings
loopTimer <- 300;

// Gets an integer value from the imp's light sensor,
// and sends it to the agent
function getData() {
    local event = { "light": hardware.lightlevel(),
                    "power": hardware.voltage() }
    // Send event to agent
    agent.send("event", event);

    // Set timer for next event
    imp.wakeup(loopTimer, getData);
}

// Give the agent time to connect to Azure
// then start the loop
imp.wakeup(5, getData);