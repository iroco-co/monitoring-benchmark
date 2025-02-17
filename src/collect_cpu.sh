#!/bin/bash
RRDPATH=$PWD/config
NB_MINUTES=10
STEP=1 # 1 seconde

NETWORK_INTERFACE="wlp2s0"

mkdir -p $RRDPATH

# Création de la base de données RRD pour le CPU 
# DS-> Data Source : user -> nom de la métrique, COUNTER -> type de données, 5 -> facteur de normalisation, 0 -> valeur minimale, U -> valeur maximale illimitée
# RRA -> Round Robin Archive : AVERAGE -> type de stockage, 0.5 -> facteur de normalisation, 1 -> nombre de données à moyenner, $((NB_MINUTES * 60)) -> nombre de points de données à stocker

rrdtool create $RRDPATH/cpu.rrd \
--step $STEP \
DS:user:COUNTER:5:0:U \
DS:nice:COUNTER:5:0:U \
DS:system:COUNTER:5:0:U \
DS:idle:COUNTER:5:0:U \
DS:iowait:COUNTER:5:0:U \
DS:irq:COUNTER:5:0:U \
DS:softirq:COUNTER:5:0:U \
RRA:AVERAGE:0.5:1:$((NB_MINUTES * 60))

rrdtool create $RRDPATH/memory.rrd \
--step $STEP \
DS:used:GAUGE:5:0:U \
DS:free:GAUGE:5:0:U \
DS:available:GAUGE:5:0:U \
RRA:AVERAGE:0.5:1:$((NB_MINUTES * 60))

rrdtool create $RRDPATH/network.rrd \
--step $STEP \
DS:rx:GAUGE:5:0:100 \
DS:tx:GAUGE:5:0:100 \
RRA:AVERAGE:0.5:1:$((NB_MINUTES * 60))


while true; do
  NETWORK_DATA=$(sar -n DEV 1 $STEP | grep $NETWORK_INTERFACE | tail -n 1 | awk '{print $5":"$6}' | sed 's/,/./g')
	echo $NETWORK_DATA
	rrdtool update $RRDPATH/network.rrd N:$NETWORK_DATA

	CPU_DATA=$(awk '/^cpu  /{print $2":"$3":"$4":"$5":"$6":"$7":"$8}' /proc/stat)
	rrdtool update $RRDPATH/cpu.rrd N:$CPU_DATA
	echo $CPU_DATA

	MEMORY_DATA=$(free | awk '/Mem/{print $3":"$4":"$7}')
	rrdtool update $RRDPATH/memory.rrd N:$MEMORY_DATA
	echo $MEMORY_DATA

	rrdtool graph $RRDPATH/cpu_usage.png \
	--width 800 --height 300 \
	--title "Utilisation CPU sur les 3 dernières minutes" \
	--vertical-label "Pourcentage" \
	--start -${NB_MINUTES}min --end now \
	--lower-limit 0 --upper-limit 100 \
	DEF:user=$RRDPATH/cpu.rrd:user:AVERAGE \
	DEF:nice=$RRDPATH/cpu.rrd:nice:AVERAGE \
	DEF:system=$RRDPATH/cpu.rrd:system:AVERAGE \
	DEF:idle=$RRDPATH/cpu.rrd:idle:AVERAGE \
	DEF:iowait=$RRDPATH/cpu.rrd:iowait:AVERAGE \
	DEF:irq=$RRDPATH/cpu.rrd:irq:AVERAGE \
	DEF:softirq=$RRDPATH/cpu.rrd:softirq:AVERAGE \
	'CDEF:total=user,nice,+,system,+,idle,+,iowait,+,irq,+,softirq,+' \
	'CDEF:user_pct=user,total,/,100,*' \
	'CDEF:nice_pct=nice,total,/,100,*' \
	'CDEF:system_pct=system,total,/,100,*' \
	'CDEF:idle_pct=idle,total,/,100,*' \
	'CDEF:iowait_pct=iowait,total,/,100,*' \
	'CDEF:irq_pct=irq,total,/,100,*' \
	'CDEF:softirq_pct=softirq,total,/,100,*' \
	AREA:user_pct#FF0000:"User     " \
	STACK:nice_pct#00FF00:"Nice     " \
	STACK:system_pct#0000FF:"System   " \
	STACK:iowait_pct#FFFF00:"I/O Wait " \
	STACK:irq_pct#00FFFF:"IRQ      " \
	STACK:softirq_pct#FF00FF:"Soft IRQ " \
	LINE1:idle_pct#000000:"Idle     "

	rrdtool graph $RRDPATH/memory_usage.png \
	--width 800 --height 300 \
	--title "Utilisation mémoire sur les 3 dernières minutes" \
	--vertical-label "Pourcentage" \
	--start -${NB_MINUTES}min --end now \
	--lower-limit 0 --upper-limit 100 \
	DEF:used=$RRDPATH/memory.rrd:used:AVERAGE \
	DEF:free=$RRDPATH/memory.rrd:free:AVERAGE \
	DEF:available=$RRDPATH/memory.rrd:available:AVERAGE \
	'CDEF:total=used,free,+,available,+' \
	'CDEF:used_pct=used,total,/,100,*' \
	'CDEF:free_pct=free,total,/,100,*' \
	'CDEF:available_pct=available,total,/,100,*' \
	AREA:used_pct#FF0000:"Used     " \
	STACK:free_pct#00FF00:"Free     " \
	STACK:available_pct#0000FF:"Available"

	rrdtool graph $RRDPATH/network_usage.png \
	--width 800 --height 300 \
	--title "Utilisation réseau sur les 3 dernières minutes" \
	--vertical-label "Kilobits par seconde" \
	--start -${NB_MINUTES}min --end now \
	DEF:rx=$RRDPATH/network.rrd:rx:AVERAGE \
	DEF:tx=$RRDPATH/network.rrd:tx:AVERAGE \
	LINE1:rx#FF0000:"Download" \
	LINE1:tx#0000FF:"Upload"
done
