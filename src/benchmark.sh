#!/bin/bash

# Benchmark durée
DURATION=$1 # sec
STEP=1 # sec

TIME_BEFORE=5 # sec
TIME_AFTER=5 # sec

DESTINATION=$PWD/tir_${DURATION}sec

VECTOR_CONFIG="./config/vector.toml"
COLLECTD_CONF="./config/collectd.conf"
COLLECTD_PID="./config/collectd.pid"

nb_sec=$(($DURATION * $STEP))
total_sec=$((($nb_sec+ $TIME_BEFORE + $TIME_AFTER)*2))


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
  echo "Création du répertoire $DESTINATION"
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
  exec ./src/collect_data.sh --duration $DURATION --time-before $TIME_BEFORE --time-after $TIME_AFTER --step $STEP  $DESTINATION > /dev/null 2>&1 &
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
echo "Preparation terminée. Début du benchmark pendant $total_sec ..."

# Benchmark Vector
echo "Démarrage du benchmark Vector pour une durée de $nb_sec secondes..."
start_benchmark
sleep $TIME_BEFORE

start_vector
sleep $nb_sec
stop_vector
sleep $TIME_AFTER

echo "Benchmark vector terminé."

# Benchmark Collectd
echo "Démarrage du benchmark Collectd pour une durée de $nb_sec secondes..."
sleep $TIME_BEFORE

start_collectd
sleep $nb_sec
stop_collectd
sleep $TIME_AFTER

echo "Benchmark collectd terminé."

echo "Generation des graphiques..."
sleep 3
kill $(jobs -p)
echo "Benchmark terminé."

