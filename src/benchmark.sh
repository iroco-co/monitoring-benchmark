#!/bin/bash

# Benchmark durée
DURATION=$1 # min

TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

DESTINATION=tir_${DURATION}min

VECTOR_CONFIG="./config/vector.toml"
COLLECTD_CONF="./config/collectd.conf"
COLLECTD_PID="./config/collectd.pid"

nb_sec=$(($DURATION * 1 + $TIME_BEFORE + $TIME_AFTER))


# Création des fichiers de sortie
cleanup() {
  rm -rf ${DESTINATION}
  echo "Nettoyage des fichiers de sortie..."
}

create_dir() {
  if [ -d ${DESTINATION} ]; then
    echo "Le répertoire ${DESTINATION} existe déjà. Suppression en cours..."
    cleanup
  fi
  echo "Création du répertoire $(pwd)/${DESTINATION}"
  mkdir -p ${DESTINATION}
  touch ${DESTINATION}/${1}_mem_usage.txt
  touch ${DESTINATION}/${1}_cpu_usage.txt
  touch ${DESTINATION}/${1}_network_usage.txt
}

stop_collectd() {
  if pgrep -x "collectd" > /dev/null; then
    echo "Une instance de Collectd tourne déjà. Arrêt en cours..."
    kill $(pgrep -x "collectd")
    echo "Arrêt de Collectd"
  fi
}

stop_vector() {
  if pgrep -x "vector" > /dev/null; then
    echo "Une instance de Vector tourne déjà. Arrêt en cours..."
    kill $(pgrep -x "vector")
    echo "Arrêt de Vector"
  fi
}

start_benchmark() {
  # Benchmark mémoire
  free -s 1 -c $nb_sec | grep Mem > ${DESTINATION}/${1}_mem_usage.txt &

  # Benchmark CPU
  LC_NUMERIC=en_EN.UTF-8 top -b -d 1 -n $nb_sec | grep Cpu > ${DESTINATION}/${1}_cpu_usage.txt &

  # Benchmark réseau
  sar -n DEV 1 $nb_sec | grep wlp2s0 > ${DESTINATION}/${1}_network_usage.txt &
}

start_vector() {
  vector --config-toml $VECTOR_CONFIG > /dev/null 2>&1 &
  echo "Vector démaré"
}

start_collectd() {
  collectd -C $COLLECTD_CONF -f > /dev/null 2>&1 &
  echo "Collectd démarré"
}


# Main
cleanup
stop_vector
stop_collectd
create_dir "vector"
create_dir "collectd"
kill $(jobs -p)
echo "Preparation terminée."

# Benchmark Vector
sleep 2
echo "Démarrage du benchmark Vector pour une durée de $nb_sec secondes..."
start_benchmark "vector"
sleep $TIME_BEFORE

start_vector
sleep $nb_sec
stop_vector
sleep $TIME_AFTER

kill $(jobs -p)
echo "Benchmark vector terminé."

# Benchmark Collectd
sleep 2
echo "Démarrage du benchmark Collectd pour une durée de $nb_sec secondes..."
start_benchmark "collectd"
sleep $TIME_BEFORE

start_collectd
sleep $nb_sec
stop_collectd
sleep $TIME_AFTER

kill $(jobs -p)

echo "Benchmark collectd terminé."
