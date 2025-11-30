# uOS
Micro-OS est écrit entièrement en assembleur avec les fonctionnalités suivantes:
* Cadencement matériel fixé à 26 µS
* Gestion de 3 Leds et de l'appui simple sur le bouton
* Gestion de 16 *timers* logiciel sur 16 bits du type *callback* avec une résolution de 1 mS
* Gestion d'une liaison UART *full duplex* de 300 bauds à 19200 bauds reconfigurable à chaud
* Prise en charge des 2 interruptions *TIMER1_COMPA* (cadencement matériel et gestion de l'UART) et *PCINT0* (gestion de la réception UART et du bouton)
* Support de commandes permettant:
    * le *dump* et le calcul du CRC8-MAXIM du programme *flashé* à des fins de vérification
    * la lecture et l'écriture dans la SRAM
    * la lecture et l'écriture dans l'EEPROM du µC
    * la lecture de la signature et des fusibles du µC
    * cf. § Commandes/Réponses pour la liste exhaustive avec des exemples
* *Á compléter*

## 🛠️ Environnement de développement
* [Assembler for the Atmel AVR microcontroller family](https://github.com/Ro5bert/avra) légèrement modifié pour:
    * Accueillir pour l'ATtiny85 les sauts **rjmp** et appels **rcall** relatifs
    * Ajouter des messages de *warning* comme "*ATtiny85_uOS+DS18B20.asm(1326) : Warning : Improve: Replace absolute by a relative branch (-2048 <= k <= 2047)*"
    * *Á compléter*

* Script shell *goGenerateProject.sh* fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX (Intel)](https://fr.wikipedia.org/wiki/HEX_(Intel))
* Développement sous Linux (distribution Ubuntu 24.04.3 LTS)
* *Á compléter*
