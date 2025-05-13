#!/bin/bash

# Initialisation des variables
DECODING_CODEC="csv"                    # Type de décodage des données (csv, json, protobuf)
CONFIG_DIR="./config"                   # Répertoire de configuration             

usage() {
  echo "Usage: $0 --decoding-codec <decoding-codec> <conf-dir>"
  exit 1
}

# Analyse des options de ligne de commande
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --decoding-codec) DECODING_CODEC="$2"; shift ;;
    --help) usage ;;
    *) CONFIG_DIR="$1" ;;
  esac
  shift
done

if [ ! -d $CONFIG_DIR ]; then
    echo "Le répertoire de configuration $CONFIG_DIR n'existe pas"
    # Création du répertoire de configuration
    mkdir -p $CONFIG_DIR
    echo "Création du répertoire de configuration $CONFIG_DIR"
fi

config_file="${CONFIG_DIR}/vector_$DECODING_CODEC.toml"

port=6000

# Configuration de décodage en fonction du codec
decoding_config="""
decoding.codec = \"bytes\"
"""
output_codec="json"

if [ "$DECODING_CODEC" == "csv" ]; then
    port=6000
elif [ "$DECODING_CODEC" == "protobuf" ]; then
    port=6001
    decoding_config="""
decoding.codec = \"protobuf\"
decoding.protobuf.desc_file = \"$PWD/config/myproto.desc\"
decoding.protobuf.message_type = \"ExempleMessage\"
"""
elif [ "$DECODING_CODEC" == "json" ]; then
    port=6002  
    output_codec="raw_message"
else
    echo "Invalid decoding codec only csv, protobuf or json are supported"
    exit 1
fi

# Génération du fichier de configuration Vector
cat <<EOL > $config_file
[sources.vector_source]
type = "socket"
address = "0.0.0.0:${port}"
mode = "udp"
${decoding_config}

[sinks.out]
    type = "console"
    inputs = ["vector_source"]
    encoding.codec = "$output_codec"
EOL

# Démarrage de Vector
vector --config $config_file