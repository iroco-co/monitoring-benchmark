#!/bin/bash

# Initialisation des variables
DURATION=10
NB_SECONDS_BEFORE=1
NB_SECONDS_AFTER=1
STEP=1
ITERATION=1
DESTINATION="$PWD/tir_@test"

NETWORK_INTERFACE="wlp2s0"


# Fonction pour afficher l'aide
usage() {
  echo "Usage: $0 --duration <seconds> --time-before <seconds> --time-after <seconds> --step <seconds> --iteration <number> --network-interface <network-interface> <destination>"
  exit 1
}

# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --duration) DURATION="$2"; shift ;;
    --time-before) NB_SECONDS_BEFORE="$2"; shift ;;
    --time-after) NB_SECONDS_AFTER="$2"; shift ;;
    --step) STEP="$2"; shift ;;
    --iteration) ITERATION="$2"; shift ;;
		--network-interface) NETWORK_INTERFACE="$2"; shift ;;
    --help) usage ;;
    *) DESTINATION="$1" ;;
  esac
  shift
done

NB_SECONDS=$((($DURATION + $NB_SECONDS_BEFORE + $NB_SECONDS_AFTER) * $ITERATION))

echo "Durée: $DURATION secondes"
echo "Temps avant: $NB_SECONDS_BEFORE secondes"
echo "Temps après: $NB_SECONDS_AFTER secondes"
echo "Pas de temps: $STEP"
echo "Nombre d'itérations: $ITERATION"
echo "Nombre total seconde: $NB_SECONDS"
echo "Interface réseau: $NETWORK_INTERFACE"
echo "Destination: $DESTINATION"

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
}

create_dir

# Création de la base de données RRD pour le CPU 
# DS-> Data Source : user -> nom de la métrique, COUNTER -> type de données, 5 -> facteur de normalisation, 0 -> valeur minimale, U -> valeur maximale illimitée
# RRA -> Round Robin Archive : AVERAGE -> type de stockage, 0.5 -> facteur de normalisation, 1 -> nombre de données à moyenner, $((NB_MINUTES * 60)) -> nombre de points de données à stocker


rrdtool create $DESTINATION/cpu.rrd \
--step $STEP \
DS:user:COUNTER:5:0:U \
DS:nice:COUNTER:5:0:U \
DS:system:COUNTER:5:0:U \
DS:idle:COUNTER:5:0:U \
DS:iowait:COUNTER:5:0:U \
DS:irq:COUNTER:5:0:U \
DS:softirq:COUNTER:5:0:U \
RRA:AVERAGE:0.5:1:$NB_SECONDS

rrdtool create $DESTINATION/memory.rrd \
--step $STEP \
DS:used:GAUGE:5:0:U \
DS:free:GAUGE:5:0:U \
DS:available:GAUGE:5:0:U \
RRA:AVERAGE:0.5:1:$NB_SECONDS

rrdtool create $DESTINATION/network.rrd \
--step $STEP \
DS:tx:GAUGE:5:0:15 \
RRA:AVERAGE:0.5:1:$NB_SECONDS

collect_network () {
	NETWORK_DATA=$(sar -n DEV 1 $STEP | grep $NETWORK_INTERFACE | tail -n 1 | awk '{print $6}' | sed 's/,/./g')
	echo network data $NETWORK_DATA
	rrdtool update $DESTINATION/network.rrd N:$NETWORK_DATA
}

collect_cpu () {
	CPU_DATA=$(awk '/^cpu  /{print $2":"$3":"$4":"$5":"$6":"$7":"$8}' /proc/stat)
	rrdtool update $DESTINATION/cpu.rrd N:$CPU_DATA
	echo $CPU_DATA
}

collect_memory () {
	MEMORY_DATA=$(free | awk '/Mem/{print $3":"$4":"$7}')
	rrdtool update $DESTINATION/memory.rrd N:$MEMORY_DATA
	echo $MEMORY_DATA
}



sec_counter=$NB_SECONDS
while [ $sec_counter -gt 0 ]; do
	sec_counter=$((sec_counter - 1))
	collect_network &
	collect_cpu &
	collect_memory &
	sleep 1
done

exec src/generate_graph.sh $NB_SECONDS $DESTINATION