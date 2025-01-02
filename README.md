# monitoring-benchmark

Le bench doit etre réplicable sur une durée entre 10 min et 1h au besoin,

les outils à bench sont rrdtool et vector

nous voulons un environement isolé (c'est à dire avec un inimum de process en execution pour éviter les effets de bords et les mauvaises interpretations)

l'affichage graphique ne doit pas être pris en compte dans le bench

les valeurs à bench sont les suivantes:
  - l'utilisation mémoire (free -s 1 | grep Mem)
  - l'utilisation CPU (LC_NUMERIC=en_EN.UTF-8 top -b -d 1 -n 600 | grep Cpu)
  - l'utilisation réseau (en entrée et en sortie) (sar -n DEV 1 600 | grep  wlp2s0)

les valeurs doivent être relevées toutes les 1 secondes

le bench doit permetre de visualiser les valeurs avant, pendant et après le démarage de l'outil de monitoring

collectd doit être utilisé pour collecter les valeurs avec rrdtool