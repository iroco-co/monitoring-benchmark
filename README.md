# monitoring-benchmark

Le bench doit etre réplicable sur une durée entre 10 min et 1h au besoin,

les outils à bench sont collectd et vector

nous voulons un environement isolé (c'est à dire avec un minimum de process en execution pour éviter les effets de bords et les mauvaises interpretations)

l'affichage graphique ne doit pas être pris en compte dans le bench

les valeurs à bench sont les suivantes:
  - l'utilisation mémoire (free -s 1 -c 600 | grep Mem)
  - l'utilisation CPU (LC_NUMERIC=en_EN.UTF-8 top -b -d 1 -n 600 | grep Cpu)
  - l'utilisation réseau (en entrée et en sortie) (sar -n DEV 1 600 | grep  wlp2s0)

les valeurs doivent être relevées toutes les 1 secondes 

le bench doit permetre de visualiser les valeurs avant, pendant et après le démarage de l'outil de monitoring.

Pour lancer le bensh, il suffit d'executer le script benshmark.sh avec la commande suivante:
```bash
/bin/bash benchmark.sh [duration(seconds)]
```
Le fichier est configurable pour changer les parametres de collecte via les variables initialisées.

## Collectd
  Collectd est un outil de monitoring qui permet de collecter des métriques système et de les exporter vers un serveur de monitoring.
  Il est très léger et stable.
  ### Installation
  ```
  sudo apt install collectd
  ```

## vector
  Vector fonctionne avec des agents de collecte qui envoient les métriques à un serveur de monitoring centralisé.

  ### Installation
  ```bash
  curl --proto '=https' --tlsv1.2 -sSfL https://sh.vector.dev | bash
  ```
  ### Configuration
  ```bash
  vector --config /path/to/vector.toml
  ```
  ### Lancement
  ```bash
  vector --config /path/to/vector.toml
  ```
  ### Visualisation
  ```bash
  vector top
  ```
  ### Documentation
  [https://vector.dev/docs/](https://vector.dev/docs/)
  

## Fichiers sources

Les fichiers de benchmark sont disponibles dans le dossier `src` de ce repository.

### collect_data.sh
```bash
/bin/bash src/collect_data.sh --nb-seconds [seconds] --step [seconds] --network-interface [network-interface] --base-time[base-time(seconds)] [destination]
```
Ce script permet de collecter les métriques système (CPU, mémoire, réseau) sur un temps donné. Il fonctionne avec rrdtool qui est un outil de stockage de données très léger et performant.
Il va donc générer un dossier source dans lequel il vas créer les fichiers rrd qui vont stocker les données collectées.
Il va également générer un fichier `vars` qui contient les de configuration nécessaires pour la génération de graphes.

### generate_graph.sh
```bash
/bin/bash src/generate_graph.sh [source_folder]
```
Ce script permet de générer les graphes à partir des fichiers `cpu.rrd`, `memory.rrd` et `network.rrd` du __source_foleder__ généré par le script `collect_data.sh`. Il va générer les graphes et les stocker dans ce même __source_foleder__.

### aggregate_graph.sh
```bash
/bin/bash src/aggregate_graph.sh [source_folder]
```
Ce script permet de générer des graphes cpu, memoire et network qui supperposent les courbes provenant de plusieurs collect_data différents. Il va aller chercher les fichiers `cpu.rrd`, `memory.rrd` et `network.rrd` de chaque folder du __source_folder__ et les superposer dans un graphe. Pour fonctionner, il a besoin d'un fichier `vars` dans son __source_folder__ qui contient les informations de configuration (BASE_TIME et NB_SECONDS).

### collectd_config.sh
```bash
/bin/bash src/collectd_config.sh --duration [duration(seconds)]--destination-server [ip_destination_server] --time-interval [time_interval(seconds)] [destination_folder]
```
Ce scripte permet de générer un fichier de configuration d'un observeur collectd avec les parametres passés en argument. Il va générer un fichier `collectd.conf` dans le __destination_folder__.

Pour executer collectd avec ce fichier de configuration, il suffit de lancer la commande suivante:
```bash
collectd -C [destination_folder]/collectd.conf -f
```

### vector_config.sh
```bash
  /bin/bash src/vector_config.sh --duration [duration(seconds)] --destination-server [ip_destination_server] --time-interval [time_interval(seconds)]  --network-interface [network_interface] --encoding-type [encoding_type] __destination_folder__
```
Ce script permet de générer un fichier de configuration d'un observeur vector avec les parametres passés en argument. Il va générer un fichier `vector.toml` dans le __destination_folder__.

Pour executer vector avec ce fichier de configuration, il suffit de lancer la commande suivante:
```bash
vector --config [destination_folder]/vector_[encoding_type].toml
```

### collectd_aggregator.sh
```bash
/bin/bash src/collectdaggregator.sh [source_folder]
```
Ce script permet de de générer un fichier de configuration d'un aggregateur collectd avec les parametres passés en argument. Il va générer un fichier `collectd.conf` dans le __source_folder__. Il va egalement lancer collectd avec cette configuration.

### vector_aggregator.sh
```bash
/bin/bash src/collectdaggregator.sh --decoding-codec [decoding_codec] [source_folder]
```

Ce script permet de de générer un fichier de configuration d'un aggregateur vector avec les parametres passés en argument. Il va générer un fichier `vector.toml` dans le __source_folder__. Il va egalement lancer vector avec cette configuration.
