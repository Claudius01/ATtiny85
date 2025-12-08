
## 🚩 Principes avancés
- uOS permet le prolongement des appels hors de uOS pour accueillir un programme *addon* comme [DS18B20](../../DS18B20) sans avoir à le modifier et ajouter pour ce programme:
  * L'initialisation logicielle et matérielle
  * Le traitement en fond de tâche ou toutes les millisecondes
  * Le support de nouvelles commandes
  * L'action sur le bouton
  * etc.

- De plus, ce programme *addon*  bénificera des ressources de uOS sans avoir à les réécrire comme:
  * L'UART/Tx et UART/Rx
  * La gestion des *timers*
  * Les commandes de uOS
  * etc.
