#!/bin/bash

# Start the QEMU process in the background with a named pipe for the monitor
QEMU_PIPE="/tmp/qemu-monitor"
mkfifo $QEMU_PIPE

# Start QEMU with the named pipe for the monitor
./runq images/bb-trace -monitor pipe:$QEMU_PIPE &

# Get the PID of the QEMU process
QEMU_PID=$!

# Function to send commands to the QEMU monitor
send_command() {
  local cmd=$1
  echo "$cmd" > $QEMU_PIPE
}

# Wait for QEMU to start
sleep 5

# Run the save checkpoint command every 10 seconds and stop after 60 seconds
duration=60
interval=10
elapsed=0

while [ $elapsed -lt $duration ]; do
  sleep $interval
  send_command "flexus-save-ckpt"
  elapsed=$((elapsed + interval))
done

# Stop the QEMU process
send_command "quit"

# Clean up
rm $QEMU_PIPE
wait $QEMU_PID
