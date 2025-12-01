# ⭕ uOS
Micro-OS est écrit entièrement en assembleur avec les fonctionnalités suivantes:
* Cadencement matériel fixé à 26 µS
* Gestion de 3 Leds et de l'appui simple sur le bouton
* Gestion de 16 *timers* logiciel sur 16 bits du type *callback* avec une résolution de 1 mS
* Gestion d'une liaison UART *full duplex* de 300 bauds à 19200 bauds reconfigurable à chaud
* Prise en charge des 2 interruptions *TIMER1_COMPA* (cadencement matériel et gestion de l'UART) et *PCINT0* (gestion des changements de UART/Rx et du bouton)
* Support des commandes permettant notamment:
    * le *dump* et le calcul du [CRC8-MAXIM](https://crccalc.com/?crc=123456789&method=CRC-8/MAXIM-DOW&datatype=hex&outtype=hex) du programme *flashé* à des fins de vérification
    * la lecture et l'écriture dans la SRAM
    * la lecture et l'écriture dans l'EEPROM du µC
    * la lecture de la signature et des fusibles du µC
    * cf. § Commandes/Réponses pour la liste exhaustive avec des exemples
* *Á compléter*

## 📎 Applications
uOS permet de développer des programmes utilisant ses ressources sans avoir à les réécrire; à savoir:
* 📈 Gestion complète de 5 capteurs de température DS18B20 sur un bus 1-Wire (cf. ![Projet DS18B20](../DS18B20))
* *Á compléter*

## 🛄 Organisation du projet
uOS est organisé au sein des fichiers suivants dont les sources sont fournis:
* ATtiny85_uOS.asm et ATtiny85_uOS.h
     * Programme principal exécuté au RESET et incluant tous les fichiers qui suivent
     * 📔 La chaine de production du '.hex' n'utilise pas d'éditeur de liens

* ATtiny85_uOS_Macros.def
     * Macros pour la gestion du port de sortie (Leds, UART/Tx, etc.)

* ATtiny85_uOS_Misc.asm
     * Méthodes diverses

* ATtiny85_uOS_Interrupts.asm et ATtiny85_uOS_Interrupts.h
     * Prise en charge des 2 interruptions *TIMER1_COMPA* et *PCINT0*

* ATtiny85_uOS_Uart.asm et ATtiny85_uOS_Uart.h
     * Gestion de l'UART

* ATtiny85_uOS_Eeprom.asm et ATtiny85_uOS_Eeprom.h
     * Gestion de l'EEPROM

* ATtiny85_uOS_Commands.asm et ATtiny85_uOS_Commands.h
     * Gestion des commandes/réponses

* ATtiny85_uOS_Print.asm et ATtiny85_uOS_Print.h
     * Formatage des emissions

## 🛠️ Environnement de développement
* [Assembler for the Atmel AVR microcontroller family](https://github.com/Ro5bert/avra) légèrement modifié pour:
    * Accueillir pour l'ATtiny85 les sauts **rjmp** et appels **rcall** relatifs
    * Ajouter des messages de *warning* comme:
        * "*ATtiny85_uOS+DS18B20.asm(1326) : Warning : Improve: Replace absolute by a relative branch (-2048 <= k <= 2047)*"
        * "*ATtiny85_uOS.asm(80) : Warning : Improve: Skip equal to 0*"
    * *Á compléter*

* *Script shell* *goGenerateProject.sh* fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX (Intel)](https://fr.wikipedia.org/wiki/HEX_(Intel))
* Développement sous Linux (distribution Ubuntu 24.04.3 LTS)
* *Á compléter*
