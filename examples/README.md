# Connect Electric Imp to Azure IoT Hub

In these examples, you begin by learning the basics of working with Electric Imp. We will use Electric Imp Libraries to seamlessly connect imp-enabled hardware to the cloud by using Azure IoT Hub. 

## Hardware Options

### [impExplorer&trade; Kit](https://store.electricimp.com/collections/featured-products/products/impexplorer-developer-kit?variant=31118866130)

The impExplorer Kit provides a set of sensors and peripherals which are ready to use. This project will take readings from the onboard temperature/humidity sensor and send the readings to IoT Hub.

### [impAccelerator™ Fieldbus Gateway](https://store.electricimp.com/products/impaccelerator-fieldbus-gateway?variant=31118564754)

The Fieldbus Gateway is designed for a variety of industrial use-cases. In this example we will use the MikroBUS socket and a thermocouple to expand the basic functionality of the board to take temperature readings to send to IoT Hub. 

#### Required Hardware

- [impAccelerator™ Fieldbus Gateway](https://store.electricimp.com/products/impaccelerator-fieldbus-gateway?variant=31118564754)
- [MikroBUS board](https://www.digikey.com/product-detail/en/mikroelektronika/MIKROE-1197/1471-1036-ND/4495401)
- [Thermocouple](https://www.digikey.com/product-detail/en/mikroelektronika/MIKROE-1197/1471-1036-ND/4495401)

#### Hardware Setup

You will need to remove the impAccelerator™ Fieldbus Gateway from the enclosure to expose the MikroBUS headers. The THERMO click board plugs into the MikroBUS headers. 

## IoT Hub Env Auto Register

This example implements automatic device registration through the IoT Hub device registration APIs. 

Find Auto Registration step by step instructions [here](./AutoRegister_StepByStep_Instructions.md)


## IoT Hub Env Manual Register

This example implements manual device registration through the IoT Hub UI. 

Find Manual Registration step by step instructions [here](./ManualRegister_StepByStep_Instructions.md)