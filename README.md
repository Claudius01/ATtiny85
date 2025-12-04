# ATtiny85

Projets basés sur une platine d'essais autour d'un [ATtiny85](https://ww1.microchip.com/downloads/en/devicedoc/atmel-2586-avr-8-bit-microcontroller-attiny25-attiny45-attiny85_datasheet.pdf) pouvant gérer divers périphériques connectés sur un [bus I²C](https://fr.wikipedia.org/wiki/I2C) ou [1-Wire](https://fr.wikipedia.org/wiki/1-Wire)
- Capteur de température (cf. ![DS18B20](DS18B20))
- Capteur d'humidité
- Horloge RTC
- Mémoire EEPROM
- Potentiomètre numérique
- etc.

![Platine d'essais](Platine-ATtiny85.png)

- Projets utilisant la platine d'essais:
     - [uOS](uOS): Micro OS
     - [DS18B20](DS18B20): Gestion de 4 capteurs de température sur un bus 1-Wire
