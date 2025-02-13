#!/bin/bash

# Benchmark durée
DURATION=1 # min
DESTINATION=tir_${DURATION}min

# Création des fichiers de sortie
echo "Création du répertoire $(pwd)/${DESTINATION}"
mkdir -p ${DESTINATION}
touch ${DESTINATION}/mem_usage.txt
touch ${DESTINATION}/cpu_usage.txt
touch ${DESTINATION}/network_usage.txt

nb_sec=$(($DURATION * 60))


# Benchmark mémoire
free -s 1 -c $nb_sec | grep Mem > ${DESTINATION}/mem_usage.txt &

# Benchmark CPU
LC_NUMERIC=en_EN.UTF-8 top -b -d 1 -n $nb_sec | grep Cpu > ${DESTINATION}/cpu_usage.txt &

# Benchmark réseau
sar -n DEV 1 $nb_sec | grep wlp2s0 > ${DESTINATION}/network_usage.txt &

# Attendre nb_sec secondes
sleep $nb_sec

# Terminer tous les processus en arrière-plan
kill $(jobs -p)

echo "Benchmark terminé. Résultats enregistrés dans ${DESTINATION}/mem_usage.txt, ${DESTINATION}/cpu_usage.txt et ${DESTINATION}/network_usage.txt"
