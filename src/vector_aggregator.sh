#!/bin/bash

# Initialize Vector Aggregator

# Define the configuration file path
CONFIG_FILE="${PWD}/config/vector.toml"

# Write the basic configuration to the file
cat <<EOL > $CONFIG_FILE
[sources.vector_source]
type = "socket"
address = "0.0.0.0:6000"
mode = "udp"
decoding.codec = "native"

[sinks.out]
    type = "console"
    inputs = ["vector_source"]
    encoding.codec = "json"
EOL

# Start the Vector service
vector --config $CONFIG_FILE