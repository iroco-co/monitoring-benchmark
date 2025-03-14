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

le bench doit permetre de visualiser les valeurs avant, pendant et après le démarage de l'outil de monitoring

## Collectd
  Collectd est un outil de monitoring qui permet de collecter des métriques système et de les exporter vers un serveur de monitoring.
  le protocole réseau utilisé dépendra de la db utilisée (greptimedb, influxDB)
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
  