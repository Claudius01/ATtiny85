# ⭕ uOS
Micro-OS est écrit entièrement en assembleur avec les fonctionnalités suivantes:
* Cadencement matériel fixé à 26 µS justifié par la gestion logicielle de l'UART jusqu'à 19200 bauds
* Gestion de 3 Leds et de l'appui simple sur le bouton:
    * Led verte allumée fugitivement pour l'activité en fond de tâche
    * Led jaune allumée fugitivement pour la détection de l'appui bouton
    * Led rouge allumée fugitivement ou en permanence
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
     * Prise en charge des 2 interruptions *TIMER1_COMPA* (cadencement matériel et gestion de l'UART) et *PCINT0* (gestion des changements de UART/Rx et du bouton)
* **ATtiny85_uOS_Uart.asm** et **ATtiny85_uOS_Uart.h**
     * Gestion de l'UART au travers de 2 FIFO/Rx et FIFO/Tx
* **ATtiny85_uOS_Eeprom.asm** et **ATtiny85_uOS_Eeprom.h**
     * Gestion de l'EEPROM en lecture et écriture
* **ATtiny85_uOS_Commands.asm** et **ATtiny85_uOS_Commands.h**
     * Gestion des commandes/réponses
* **ATtiny85_uOS_Print.asm** et **ATtiny85_uOS_Print.h**
     * Formatage des émissions (textes, données décimales et hexadécimales, ...)

## 🏁 Fusibles
| Fuse Low Byte | Bit No | Description | Valeur | Action |
| :--- | :---: | :--- | :---: | :--- |
| CKDIV8 | 7 | Clock divided by 8 |  1 | non programmé |
| CKOUT | 6 | Clock output enabled |  1 | non programmé |
| SUT1 | 5 | Start-up time setting |  1 | non programmé |
| SUT0 | 4 | Start-up time setting |  1 | non programmé |
| CKSEL3 | 3 | Clock source setting | 0 | programmé |
| CKSEL2 | 2 | Clock source setting | 0 | programmé |
| CKSEL1 | 1 | Clock source setting | 0 | programmé |
| CKSEL0 | 0 | Clock source setting |  1 | non programmé |

Le fusible *Low Byte* est programmé à 0xF1: La source de l'horloge est interne et pilotée par la PLL interne de 64 MHz
📔 Á noter que le fusible `CKOUT` peut être programmé, auquel cas la sortie `CLK` est dispoblible sur PB4 permettant de qualifier au moyen d'un scope la vitesse de l'ATtiny85

| Fuse Lock Byte | Bit No | Description | Valeur | Action |
| :--- | :---: | :--- | :---: | :--- |
| - | 7 | - |  - | non programmé |
| - | 6 | - |  - | non programmé |
| - | 5 | - |  - | non programmé |
| - | 4 | - |  - | non programmé |
| - | 3 | - | - | non programmé |
| - | 2 | - | - | non programmé |
| LB2 | 1 | Lock bit | 1 | non programmé |
| LB1 | 0 | Lock bit |  1 | non programmé |

Le fusible *Lock Byte* est laissé non programmé à 0xFF: Aucune fonction de verrouillage de la mémoire n'est activée

| Fuse Extended Byte | Bit No | Description | Valeur | Action |
| :--- | :---: | :--- | :---: | :--- |
| - | 7 | - |  - | non programmé |
| - | 6 | - |  - | non programmé |
| - | 5 | - |  - | non programmé |
| - | 4 | - |  - | non programmé |
| - | 3 | - | - | non programmé |
| - | 2 | - | - | non programmé |
| - | 1 | - | 1 | non programmé |
| SELFPRGEN | 0 | Self-programming enabled |  1 | non programmé |

Le fusible *Extended Byte* est laissé non programmé à 0xFF: Les instructions SPM sont inhibées

| Fuse High Byte | Bit No | Description | Valeur | Action |
| :--- | :---: | :--- | :---: | :--- |
| RSTDISBL | 7 | External reset disabled |  1 | non programmé |
| DWEN | 6 | DebugWIRE enabled | 1 | non programmé |
| SPIEN | 5 | Serial program and data download enabled |  0 | programmé |
| WDTON | 4 | Watchdog timer always on |  1 | non programmé |
| EESAVE | 3 | EEPROM preserves chip erase | 0 | programmé |
| BODLEVEL2 | 2 | Brown-out Detector trigger level | 1 | non programmé |
| BODLEVEL1 | 1 | Brown-out Detector trigger level | 1 | non programmé |
| BODLEVEL0 | 0 | Brown-out Detector trigger level |  1 | non programmé |

Le fusible *High Byte* est programmé à 0xD7:
* RESET externe autorisé
* *DebugWIRE* non autorisé
* Programmation type *Serial* et téléchargement de données autorisés
* *Timer Watchdog* toujours à *off*
* EEPROM préservée à l'effacement de l'ATtiny85
* Niveau de déclenchement du détecteur de sous-tension non activé

## ⚓ Occupation mémoires
uOS occupe environ 44% de la mémoire *flash* et 60% de la mémoire SRAM de l'**ATtiny85**
* 📔 Une version "minimaliste" est à l'étude pour être implémentée sur un **ATtiny45** avec:
     * La gestion de 10 *timers* au lieu de 16
     * La suppression des commandes/réponses
     * La suppression de la gestion de l'UART/Rx
     * *Á compléter* en fonction de l'avancement des développements

## 🛠️ Environnement de développement
* [Assembler for the Atmel AVR microcontroller family](https://github.com/Ro5bert/avra) légèrement modifié pour:
    * Accueillir les sauts **rjmp** et appels **rcall** relatifs
    * Ajouter des messages de *warning* comme:
        * "*ATtiny85_uOS+DS18B20.asm(1326) : Warning : Improve: Replace absolute by a relative branch (-2048 <= k <= 2047)*"
        * "*ATtiny85_uOS.asm(80) : Warning : Improve: Skip equal to 0*"
    * *Á compléter*
* Script *shell* [goGenerateProject.sh](goGenerateProject.sh) fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX Intel](https://fr.wikipedia.org/wiki/HEX_(Intel))
* Gestion des sources sous [CVS](https://tuteurs.ens.fr/logiciels/cvs/) permettant de faire évoluer le programme "prudemment" avec notamment:
    * Un retour arrière facilité
    * La différence entre différents développements versionnés
    * La pose d'un marqueur symbolique sur une révision d'un ou plusieurs fichiers
    * La création d'une branche sur le projet
    * etc.
* Développements sous Linux (distribution Ubuntu 24.04.3 LTS)
* *Á compléter*

## ⏳ Évolutions envisagées
- Utilisation d'adresses en SRAM pour le *mapping* en prolongement des appels hors de uOS comme:
  * L'initialisation logicielle et matérielle
  * Le traitement en fond de tâche ou toutes les millisecondes
  * La gestion des *timers*
  * Le support de nouvelles commandes
  * etc.

et cela afin de ne pas conditionner le code ajouté à uOS par une directive d'assemblage

- Mise en veille du µC pour limiter la consommation dans le cas d'une alimentation au moyen de piles
- Utilisation de l'USI pour la gestion de l'UART en remplacement de la solution logicielle
- *Á compléter*
