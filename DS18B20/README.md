# ⭕ DS18B20

Projet basé sur une platine d'essais pouvant gérer 5 capteurs de température [DS18B20](https://www.analog.com/media/en/technical-documentation/data-sheets/ds18b20.pdf) avec un [ATtiny85](https://ww1.microchip.com/downloads/en/devicedoc/atmel-2586-avr-8-bit-microcontroller-attiny25-attiny45-attiny85_datasheet.pdf) alimenté en 5V et cadencé à 20 MHz.

![Platine d'essais DS18B20](Platine-ATtiny85-DS18B20.png)

La gestion est faite au dessus de ![uOS](../uOS/README.md) avec les évolutions suivantes:
* La gestion du bus 1-Wire avec la "découverte" des capteurs qui peuvent être déconnectés/reconnectés du bus à chaud
* Led jaune allumée fugitivement pour en plus indiquer l'activité sur le bus 1-Wire
* Commandes:
     * Ajout de la commande "<C" pour la configuration des seuils et de la résolution de chaque capteur détecté
     * Ajout de la commande "<T" pour l'activation/déactivation des traces
     * Cf. § [Commandes/Réponses](Tests/Commands+Responses.txt) pour plus de détails
* Emission d'une trame complète préfixée par '$' avec un CRC8-MAXIM terminal suivi d'un '\n' contenant:
     * Un *header* avec:
         * Le numéro de type de la platine lu de l'EEPROM
         * L'*Id* de la platine lu de l'EEPROM
         * Le numéro de la trame
         * Le *timestamp* de la trame
         * Le nombre de capteurs détectés
     * Les informations propres à chaque capteur:
         * Son *Id* dans la liste
         * Son numéro de famille dans le monde 1-Wire (ici 0x28)
         * La température Tc mesurée
         * La température Th du seuil haut
         * La température Tl du seuil bas
         * La résolution de la mesure
         * L'état de l'alarme (Tc > Th ou Tc < Tl)
         * Un CRC8-MAXIM pour garantir l'intégrité des informations            
     * Cf. § [Commandes/Réponses](Tests/Commands+Responses.txt) pour plus de détails
* Après agrégation, ci-après le résultat d'une expérience sur 30 minutes avec 3 capteurs qui consiste à:
     * Mesurer la température d'un 1st capteur (sonde #1) plongé dans un récipient d'eau qui a été porté à ébullition
     * Mesurer la température d'un 2nd capteur (sonde #2) plongé dans un récipient rempli de glaçons
     * Mesurer la température d'un 3rd capteur (boitier TO-92) laissé à la température ambiante
     * Pour chaque capteur, une indication de l'alarme est présentée en supperposition sur le graphe suivant 

![Expérience avec 3 capteurs](UsbMonitor_DS18B20-20251118.png)

## 🛄 Organisation du projet
DS18B20 est organisé au sein des fichiers suivants dont les sources sont fournis:
* ATtiny85_uOS+DS18B20.asm et ATtiny85_uOS+DS18B20.h
     * Programme principal exécuté par uOS et incluant tous les fichiers qui suivent
     * 📔 La chaine de production du '.hex' n'utilise pas d'éditeur de liens
* ATtiny85_uOS+DS18B20_Timers.asm
     * Gestion de l'acquisition toutes les secondes et de l'émission de la trame de mesure
* ATtiny85_uOS+DS18B20_Commands.asm
     * Gestion de la commande "<C" pour la configuration des seuils et de la résolution
     * Gestion de la commande "<T" pour l'activation/déactivation des traces 
* ATtiny85_uOS+DS18B20_1_Wire.asm
     * Gestion du protocole 1-Wire
* ATtiny85_DS18B20_1_Wire_Commands.asm
     * Gestion des commandes du monde 1-Wire:
          * Commandes ROM standards (Read Rom [33h], Match Rom [55H] et Search ROM [F0h])
          * Commandes specifiques au DS18B20
               * Convert T [44h]
               * Read Scratchpad [BEh]
               * Copy Scratchpad [48h]
               * Write Scratchpad [4Eh]
               * Alarm Search [ECh]

## ⚓ Occupation mémoires
DS18B20 occupe environ 82% de la mémoire *flash* et 73% de la mémoire SRAM de l'ATtiny85
* 📔 Une version "minimaliste" est à l'étude pour être implémentée sur un ATtiny45 utilisant la version minimaliste de uOS avec:
     * La gestion de 2 capteurs
     * La suppression des commandes/réponses (seuils de température et résolution lus de l'EEPROM)
     * L'abandon des détections d'apparition des alarmes
     * *Á compléter*

* Script *shell* [goGenerateProject.sh](goGenerateProject.sh) fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX Intel](https://fr.wikipedia.org/wiki/HEX_(Intel))



