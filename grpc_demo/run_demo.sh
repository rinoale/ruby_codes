#!/bin/bash
# Starts the server + tap, runs the client through the tap, then shuts everything down.
#   ./run_demo.sh          # full wire dump
#   TAP_QUIET=1 ./run_demo.sh   # hide PING/WINDOW_UPDATE housekeeping
cd "$(dirname "$0")" || exit 1

ruby server.rb &
SERVER=$!
ruby tap.rb &
TAP=$!
trap 'kill $SERVER $TAP 2>/dev/null' EXIT
sleep 3

ruby client.rb
sleep 1
