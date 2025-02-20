#!/bin/bash

# Prompt the user for the log file name
read -p "Enter the log file name: " LOG_FILE

# Check if the user provided a name, otherwise use the default
if [ -z "$LOG_FILE" ]; then
  LOG_FILE="docker_stats.log"
fi

# Header for the log file (if it's the first run)
echo "Timestamp, Container ID, Name, CPU %, Memory Usage / Limit, Memory %, Net I/O, Block I/O, PIDs" > "$LOG_FILE"

# Loop to fetch stats every 5 seconds
while true; do
  # Get stats for all running containers and log it
  docker stats --no-stream --format "{{.ID}},{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}" | while read line; do
    # Add timestamp to each entry
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp, $line" >> "$LOG_FILE"
  done
  # Sleep for 5 seconds before the next check
  sleep 5
done
