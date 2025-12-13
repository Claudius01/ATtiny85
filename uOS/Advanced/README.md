Ci-après des informations avancées sur la mise en oeuvre de uOS dans un ATtiny85 cadencé à 16 MHz

1. Valeurs des fusibles
2. Caracréristiques de l'UART
3. Utilisation de l'EEPROM
4. Mise en oeuvre de uOS
5. Accueil du programme de test **ATtiny85_uOS_Test_Addons.asm**

## 1. Valeurs des fusibles
Les 4 fusibles *Low Byte*, *Lock Byte*, *Extended Byte* et *High Byte* sont à programmer dans un 1st temps comme suit:

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
   - 8 bits sans parité, 1 bit start et 1 bit stop 
   - 7 vitesses de 300 bauds à 19200 bauds configurées dans l'EEPROM

## 3. Utilisation de l'EEPROM
uOS utilise l'octet à l'adresse `0x00A` pour déterminer la vitesse de l'UART parmi les 7 valeurs suivantes:

1. `0x00` pour 19200 bauds
2. `0x01` pour 9600 bauds 
3. `0x02` pour 4800 bauds
4. `0x03` pour 2400 bauds
5. `0x04` pour 1200 bauds
6. `0x05` pour 600 bauds
7. `0x06` pour 300 bauds

Toute autre valeur sera interprétée comme 9600 bauds (`0xFF` étant la valeur après un effacement de l'EEPROM)

## 4. Première mise en oeuvre de uOS

## 5. Accueil du programme de test **ATtiny85_uOS_Test_Addons.asm**
- **ATtiny85_uOS_Test_Addons.asm** est un exemple de prolongement des appels hors de uOS pour accueillir un programme *addon* comme [DS18B20](../../DS18B20) sans avoir à le modifier et ajouter pour ce programme les 5 traitements:
  1. Initialisation logicielle et matérielle
  2. Traitement en fond de tâche
  3. Traitement toutes les millisecondes
  4. Support de nouvelles commandes
  5. Action sur le bouton

- Le but étant que ce programme *addon* bénéficie des ressources de uOS sans avoir à les réécrire comme:
  * L'UART/Tx et UART/Rx
  * La gestion des *timers*
  * Les commandes de uOS
  * L'appui bouton
  * etc.

Le programme *addon* doit commencer par le code comme suit:

`.cseg`<br>

`; Definitions de la table de vecteurs de "prolongation" des 5 traitements:`<br>
`; geres par uOS qui passe la main aux methodes specifiques a l'ADDON`<br>
`; - #0: Initialisation materielle et logicielle (prolongation du 'setup' de uOS)`<br>
`; - #1: Traitements en fond de tache`<br>
`; - #2: Traitements toutes les 1 mS`<br>
`; - #3: Traitements des nouvelles commandes non supportees par uOS`<br>
`; - #4: Traitements associes a l'appui bouton avant ceux effectues par uOS`<br>
`;`<br>
`; => Toujours definir les 5 adresses avec un 'rjmp' ou un 'ret'`<br>
`;    si pas de "prolongation" des traitements`<br>
`;`<br>
`; => Le nommage est libre et non utilise par uOS`<br>
`;    => Seul l'adresse du traitement est impose dans l'ordre defini plus haut`<br>
`; --------`<br>
`uos_test_setup:`<br>
`	rjmp		uos_test_setup_contd`<br>

`uos_test_background:`<br>
`	rjmp		uos_test_background_contd`<br>

`uos_test_1_ms:`<br>
`	rjmp		uos_test_1_ms_contd`<br>

`uos_test_commands:`<br>
`	rjmp		uos_test_commands_contd`<br>

`uos_test_button:`<br>
`	rjmp		uos_test_button_contd`<br>

`; Fin: Definitions de la table de vecteurs de "prolongation" des 5 traitements`<br>

Editer le fichier [ATtiny85_uOS_Test_Addons.asm](../ATtiny85_uOS_Test_Addons.asm) pour connaître les traitements `uos_test_setup`, `uos_test_background`, `uos_test_1_ms`, `uos_test_commands` et `uos_test_button`

Les traces d'exécution commentées suivantes présentent les passages dans les prolongements des 5 traitements

`15:23:52.676131 #   53: [[### ATtiny85_uOS $Revision: 1.28 $]]`  <= **Reset**<br> 
`15:23:52.688217 #   54: [[### EEPROM: 1.2.7]]`<br>
`15:23:52.697238 #   55: [[### Type: c1]]`<br>
`15:23:52.709133 #   56: [[### Id: 01]]`<br>
`15:23:52.721593 #   57: [[OSCCAL [91]]`<br>
`15:23:52.739126 #   58: [[uOS: Test setup]]`   <= **uos_test_setup**<br>
`15:23:53.804623 #   59: [[[0x001d][0x0002][0x8454]] uOS: Test 1 mS (1000 passages)]]`   <= **uos_test_1_ms**<br>
`15:23:54.843816 #   60: [[[0x001e][0x0002][0x8389]] uOS: Test 1 mS (1000 passages)]]`   <= **uos_test_background**<br>
`15:23:55.883029 #   61: [[[0x001f][0x0002][0x8389]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:23:56.920386 #   62: [[[0x0020][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:23:58.010291 #   63: <t>>> Type the command...`<br>
`15:23:58.019383 #   66: [[[0x0021][0x0002][0x83e4]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:23:58.023337 #   67: [[[03] uOS: Test command]]`   <= **uos_test_commands**<br>
`15:23:59.033455 #   71: [[[0x0022][0x0002][0x82d6]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:00.072796 #   72: [[[0x0023][0x0002][0x8389]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:01.110436 #   73: [[[0x0024][0x0002][0x8389]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:01.715721 #   74: [[### uOS: Button action]]`   <= **uos_test_button**<br>
`15:24:01.725541 #   75: [[uOS: Test button]]`   <= Passage dans uos_test_button<br>
`15:24:02.186620 #   76: [[[0x0025][0x0002][0x828b]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:03.189635 #   77: [[uOS: Test timer (10 Sec.)]]`  <= **Expiration timer** de 10 secondes<br>
`15:24:03.255166 #   78: [[[0x0026][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:04.299933 #   79: [[[0x0027][0x0002][0x843f]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:05.337224 #   80: [[[0x0028][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:06.374661 #   81: [[[0x0029][0x0002][0x83e4]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:07.413517 #   82: [[[0x002a][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:08.450643 #   83: [[[0x002b][0x0002][0x83e4]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:09.489760 #   84: [[[0x002c][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:10.527064 #   85: [[[0x002d][0x0002][0x83e4]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:11.566279 #   86: [[[0x002e][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:12.603659 #   87: [[[0x002f][0x0002][0x83e4]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:13.605926 #   88: [[uOS: Test timer (10 Sec.)]]`  <= **Expiration timer** de 10 secondes<br>
`15:24:13.672223 #   89: [[[0x0030][0x0002][0x83e5]] uOS: Test 1 mS (1000 passages)]]`<br>
`15:24:14.716860 #   90: [[[0x0031][0x0002][0x843f]] uOS: Test 1 mS (1000 passages)]]`<br>
`...`<br>

* Les passages dans **uos_test_1_ms** s'effectuent bien toutes les 1 mS
* Le passage dans **uos_test_background** incrémente un compteur de 32 bits remis à zéro toutes les secondes
     * ie. `0x000283e4` = 164836 correspond à un passage toutes les 6.07 µS soit environ 100 cycles d'instructions  à 16 Mhz pour tous les traitements en fond de tâche, de la gestion des *timers*, l'interprétation de la commande `<t` et la prise en compte de l'appui bouton
* Expiration et réarmement d'un *timer* toutes les 10 secondes comme à `15:24:03.189635` et à `15:24:13.605926`

