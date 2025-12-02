# ⭕ DS18B20

Projet basé sur une platine d'essais pouvant gérer 5 capteurs de température [DS18B20](https://www.analog.com/media/en/technical-documentation/data-sheets/ds18b20.pdf) avec un ATtiny85 alimenté en 5V et cadencé à 20 MHz.

![Platine d'essais DS18B20](Platine-ATtiny85-DS18B20.png)

La gestion est faite au dessus de ![uOS](../uOS/README.md) avec les évolutions suivantes:

* Led jaune allumée fugitivement pour la détection de l'appui bouton et l'activité sur le bus 1-Wire

* Commandes:
     * Ajout de la commande "<C" pour la configuration des seuils de température et de la résolution de chaque capteur détecté
     * Ajout de la commande "<T" pour l'activation/déactivation des traces
     * Cf. § [Commandes/Réponses](Tests/Commands+Responses.txt) pour plus de détails

* Script *shell* [goGenerateProject.sh](goGenerateProject.sh) fourni pour l'assemblage et la génération du fichier '.hex' au format [HEX Intel](https://fr.wikipedia.org/wiki/HEX_(Intel))

* Gestion des sources sous [CVS](https://tuteurs.ens.fr/logiciels/cvs/) permettant de faire évoluer le programme "prudemment" avec notamment:
    * Un retour arrière facilité
    * La différence entre différents développements versionnés
    * La pose d'un marqueur symbolique sur une révision d'un ou plusieurs fichiers
    * La création d'une branche sur le projet
    * etc.

* Développements sous Linux (distribution Ubuntu 24.04.3 LTS)


