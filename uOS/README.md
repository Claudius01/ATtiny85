# ⭕ uOS
Micro-OS est écrit entièrement en assembleur avec les fonctionnalités suivantes:
* Cadencement matériel fixé à 26 µS justifié par la gestion logicielle de l'UART jusqu'à 19200 bauds
* Gestion de 3 Leds et de l'appui simple sur le bouton:
    * Led verte allumée fugitivement pour l'activité en fond de tâche
    * Led jaune allumée fugitivement pour la détection de l'appui bouton
    * Led rouge allumée fugitivement ou en permanence suivant la source de l'erreur
    * Bouton pour l'effacement des erreurs persistantes
* Gestion de 16 *timers* logiciel sur 16 bits du type *callback* avec une résolution de 1 mS
    * 📔 Á noter que uOS utilise 6 *timers* pour:
         * L'activité en fond de tâche
         * L'allumage fugitf de la Led rouge en cas d'erreurs
         * L'allumage fugitif de la Led jaune suite à l'appui bouton
         * La détection de l'appui bouton
         * Les détections des anti-rebonds sur UART/RX qui est connecté au bouton
         * L'allumage fugitif de la Led verte 
* Gestion d'une liaison UART *full duplex* de 300 bauds à 19200 bauds définis dans l'EEPROM (9600 bauds par defaut) et reconfigurable à chaud
* Gestion des 2 interruptions *TIMER1_COMPA* et *PCINT0*
* Support des commandes permettant notamment:
    * Le *dump* du programme à partir d'une adresse donnée
    * Le calcul du [CRC8-MAXIM](https://crccalc.com/?crc=123456789&method=CRC-8/MAXIM-DOW&datatype=hex&outtype=hex) du programme *flashé* à des fins de vérification
    * La lecture et l'écriture dans la SRAM
    * La lecture et l'écriture dans l'EEPROM
    * La lecture de la signature et des fusibles
    * La reconfiguration de la vitesse de l'UART
    * Cf. le fichier [Commandes/Réponses](Tests/Commands+Responses.txt) pour la liste exhaustive avec des exemples

## 📎 Applications
uOS permet de développer des programmes utilisant ses ressources sans avoir à les réécrire comme:
* 📈 La gestion complète de 4 capteurs de température DS18B20 sur un bus 1-Wire (cf. ![Projet DS18B20](../DS18B20))

## 🛄 Organisation du projet
uOS est organisé au sein des fichiers suivants dont les sources sont fournis:
* **ATtiny85_uOS.asm** et **ATtiny85_uOS.h**
     * Programme principal exécuté au RESET et incluant tous les fichiers qui suivent
     * 📔 La chaine de production du '.hex' n'utilise pas d'éditeur de liens
* **ATtiny85_uOS_Macros.def**
     * Macros pour la gestion du port de sortie (Leds, UART/Tx, etc.)
* **ATtiny85_uOS_Misc.asm** et **ATtiny85_uOS_Misc.h**
     * Méthodes diverses
          * Initialisation de la SRAM
          * Initialisation des registres
          * Calcul du CRC8-MAXIM
          * Test Leds
          * etc. 
* **ATtiny85_uOS_Interrupts.asm** et **ATtiny85_uOS_Interrupts.h**
     * Prise en charge des 2 interruptions dans l'implémentation logicielle de l'UART
          * *TIMER1_COMPA* pour le cadencement matériel et gestion de l'UART
          * *PCINT0* pour la gestion des changements d'états de l'UART/Rx et du bouton
     * Prise en charge des 4 interruptions dans l'implémentation matérielle de l'UART
          * *TIMER1_COMPA* pour le cadencement matériel
          * *PCINT0* pour la gestion des changements d'états de l'UART/Rx et du bouton + gestion de l'USI
          * *TIMER0_COMPA* pour la vitesse de transmission de l'UART vs USI
          * *USI_OVF* pour l'émission et la réception des caractères sur l'UART vs USI
* **ATtiny85_uOS_Software_Uart.asm** et **ATtiny85_uOS_Software_Uart.h**
     * Gestion de l'UART/Rx et UART/Tx *full duplex* en logiciel au travers de 2 FIFO/Rx et FIFO/Tx (mode 'USE_USI' à 0)
     * A noter que l'utilisation de ce fichier est exclusive de **ATtiny85_uOS_Hardware_Uart.asm**
* **ATtiny85_uOS_Hardware_Uart.asm** et **ATtiny85_uOS_Hardware_Uart.h**
     * Gestion de l'UART/Rx et UART/Tx *half duplex* en matériel au travers de 2 FIFO/Rx et FIFO/Tx (mode 'USE_USI' à 1)
     * A noter que l'implémentation de l'*Universal Serial Interface* est un peu plus coûteuse en terme de code exécuté et que que l'utilisation de ce fichier est exclusive de **ATtiny85_uOS_Software_Uart.asm**
     * Pour plus de détails dans l'implémentation de l'USI, se reporter à la note d'application [AVR307: Half Duplex UART Using the USI Module](https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ApplicationNotes/ApplicationNotes/doc4300.pdf) 
* **ATtiny85_uOS_Eeprom.asm** et **ATtiny85_uOS_Eeprom.h**
     * Gestion de l'EEPROM en lecture et écriture
* **ATtiny85_uOS_Commands.asm** et **ATtiny85_uOS_Commands.h**
     * Gestion des commandes/réponses
* **ATtiny85_uOS_Print.asm** et **ATtiny85_uOS_Print.h**
     * Formatage des émissions (textes, données décimales et hexadécimales, ...)

## ⚓ Occupations mémoires
La production du programme est conditionnée aux 2 définitions `USE_USI=0|1` et `USE_MINIMALIST_ADDONS=0|1`

| Mode USI | Mode Minimaliste | Cible | Taille *flash* | Taille *SRAM* dont la *stack*|
| :---: | :---: | :---: | :---: | :---: |
| 0 | 0 | ATtiny85 |  46% | 60% |
| 0 | 1 | ATtiny45 |  47% | 47% |
| 1 | 0 | ATtiny85 |  45% | 61% |
| 1 | 1 | ATtiny45 |  51% | 48% |

* 📔 La version "minimaliste" permet d'être implémentée sur un **ATtiny45** avec les limitations:
     * Gestion de 8 *timers* au lieu de 16
     * Suppression de la gestion de l'UART/Rx
     * Suppression des commandes ne permettant plus d'examiner la mémoire *flash*, de lire et écrire dans la mémoire SRAM ni de programmer l'EEPROM

## 🛠️ Environnement de développement
* [Assembler for the Atmel AVR microcontroller family](https://github.com/Ro5bert/avra) légèrement modifié pour:
    * Accueillir les sauts **rjmp** et appels **rcall** relatifs
    * Ajouter des messages de *warning* comme:
        * "*ATtiny85_uOS+DS18B20.asm(1326) : Warning : Improve: Replace absolute by a relative branch (-2048 <= k <= 2047)*"
        * "*ATtiny85_uOS.asm(80) : Warning : Improve: Skip equal to 0*"
    * *Á compléter*
* Script *shell* [goGenerateProject.sh](goGenerateProject.sh) fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX Intel](https://fr.wikipedia.org/wiki/HEX_(Intel))
* Script *shell* [goGenerateProjectAllModes.sh](goGenerateProjectAllModes.sh) fourni pour l'assemblage du projet dans les 2 modes `USE_USI` et/ou `USE_MINIMALIST_ADDONS`
* Gestion des sources sous [CVS](https://tuteurs.ens.fr/logiciels/cvs/) permettant de faire évoluer le programme "prudemment" avec notamment:
    * Un retour arrière facilité
    * La différence entre différents développements versionnés
    * La pose d'un marqueur symbolique sur une révision d'un ou plusieurs fichiers
    * La création d'une branche sur le projet
    * etc.
* Développements sous Linux (distribution Ubuntu 24.04.3 LTS)

## ⏳ Évolutions envisagées
- Mise en veille du µC pour limiter la consommation dans le cas d'une alimentation au moyen de piles
- *Á compléter*
