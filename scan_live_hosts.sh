#!/bin/bash

# Set the network range to scan
NETWORK_RANGE="192.168.56.0/24"  # Replace with your network range

# Set the output directory for the scan results
OUTPUT_DIR="/root/nmap_scans_grouped"
LIVE_HOSTS_FILE="${OUTPUT_DIR}/live_hosts.txt"
# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Define the nmap scans to run
SCANS=(
  "-Pn -sV --top-ports 50 --open" # quick scan
  "-Pn --script smb-vuln* -p139,445"  # search smb vuln
  "-Pn -sC -sV -p-"  # full scan
#  "-sU -sC -sV"  # udp scan
)

# Function to run scans
run_scans() {
  local TARGET=$1
  local FILENAME="${OUTPUT_DIR}/${TARGET}_nmap_scans.txt"
  for SCAN in "${SCANS[@]}"; do
    echo "Starting scan: nmap $SCAN $TARGET"
    nmap $SCAN $TARGET -oN - >> "$FILENAME"
    echo "Finished scan: nmap $SCAN $TARGET"
  done
}

export -f run_scans
export OUTPUT_DIR
export SCANS

# Run each scan in parallel and save the output to a separate file per IP address
while read -r TARGET; do
  run_scans "$TARGET" &
done < "$LIVE_HOSTS_FILE" | xargs -P 5 -I {} sh -c '{}'

# Wait for all background processes to finish
wait

# Consolidate the results using nmap-parse-output
while read -r TARGET; do
  FILENAME="${OUTPUT_DIR}/${TARGET}_nmap_scans.txt"
  if [ -f "$FILENAME" ]; then
    nmap-parse-output -o "${OUTPUT_DIR}/${TARGET}_consolidated.txt" "$FILENAME"
  else
    echo "File $FILENAME does not exist. Skipping consolidation for $TARGET."
  fi
done < "$LIVE_HOSTS_FILE"

