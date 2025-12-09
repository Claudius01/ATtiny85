Ci-après des informations avancées sur la mise en oeuvre de uOS dans un ATtiny85 cadencé à 16 MHz

1. Valeurs des fusibles
2. Caracréristiques de l'UART
3. Utilisation de l'EEPROM
4. 1st mise en oeuvre de uOS
5. Accueil d'un programme *addon* en extension de uOS

## 1. Valeurs des fusibles
Les 4 fusibles *Low Byte*, *Lock Byte*, *Extended Byte* et *High Byte* peuvent être programmés comme suit:

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

* Le fusible *Low Byte* est programmé à `0xF1`: La source de l'horloge est interne et pilotée par la PLL interne de 64 MHz
* 📔 Á noter que le fusible `CKOUT` peut être programmé, auquel cas la sortie `CLK` est disponible sur PB4 permettant de qualifier au moyen d'un scope la fréquence de fonctionnement de l'ATtiny85

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

Le fusible *Lock Byte* est laissé non programmé à `0xFF`: Aucune fonction de verrouillage de la mémoire n'est activée

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

Le fusible *Extended Byte* est laissé non programmé à `0xFF`: Les instructions SPM sont inhibées

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

Le fusible *High Byte* est programmé à `0xD7` ou `0xDF`:
* RESET externe autorisé
* *DebugWIRE* non autorisé
* Programmation type *Serial* et téléchargement de données autorisés
* *Timer Watchdog* toujours à *off*
* EEPROM préservée (0) ou non (1) à l'effacement de l'ATtiny85
* Niveau de déclenchement du détecteur de sous-tension non activé

## 2. Caracréristiques de l'UART
Le format et les vitesses des données transmises et reçues par l'UART sont:
   - 8 bits sans parité
   - Vitesses de 300 bauds, 600 bauds, 1200 bauds, 2400 bauds, 4800 bauds, 9600 bauds (par défaut) et 19200 bauds configurées dans l'EEPROM

## 3. Utilisation de l'EEPROM
uOS utilise l'octet à l'adresse `0x00A` pour déterminer la vitesse de l'UART parmi les 7 valeurs suivantes:

1. `0x00` pour 19200 bauds
2. `0x01` ou `0xFF` pour 9600 bauds (`0xFF` étant la valeur après un effacement de l'EEPROM)
3. `0x02` pour 4800 bauds
4. `0x03` pour 2400 bauds
5. `0x04` pour 1200 bauds
6. `0x05` pour 600 bauds
7. `0x06` pour 300 bauds

## 4. 1st mise en oeuvre de uOS

## 5. Accueil d'un programme *addon* en extension de uOS
- uOS permet le prolongement des appels hors de uOS pour accueillir un programme *addon* comme [DS18B20](../../DS18B20) sans avoir à le modifier et ajouter pour ce programme:
  * L'initialisation logicielle et matérielle
  * Le traitement en fond de tâche ou toutes les millisecondes
  * Le support de nouvelles commandes
  * L'action sur le bouton
  * etc.

- De plus, ce programme *addon* bénéficiera des ressources de uOS sans avoir à les réécrire comme:
  * L'UART/Tx et UART/Rx
  * La gestion des *timers*
  * Les commandes de uOS
  * L'appui bouton
  * etc.
