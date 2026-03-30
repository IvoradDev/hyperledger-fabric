#!/bin/bash
#
# Top-level script to bring up the full trading network.
#
# Usage:
#   ./run-network.sh        — bring up network + 2 channels + deploy chaincode
#   ./run-network.sh -i     — also call InitLedger to seed initial data
#   ./run-network.sh -d     — tear down the network
#
# What it does:
#   1. Tears down any existing network
#   2. Brings up orderer, 3 orgs × 3 peers, CouchDBs, CAs
#   3. Creates channel1 and channel2 (all peers join both)
#   4. Deploys 'trading' chaincode to channel1 and channel2
#   5. (Optional) Calls InitLedger to seed merchants, products, users

INIT=false
DOWN=false

while [[ $# -ge 1 ]]; do
  case "$1" in
  -i) INIT=true ;;
  -d) DOWN=true ;;
  esac
  shift
done

cd ./network

if [ "$DOWN" = true ]; then
  ./network.sh down
  exit 0
fi

# Tear down any leftover state
./network.sh down

# Bring up all containers
./network.sh up

# Create both channels — all 9 peers join each channel
./network.sh createChannel -c channel1
./network.sh createChannel -c channel2

# Deploy trading chaincode to both channels
./network.sh deployCC -c channel1 -ccn trading -ccp ./chaincode/trading-go -ccl go
./network.sh deployCC -c channel2 -ccn trading -ccp ./chaincode/trading-go -ccl go

# Optionally seed initial state
if [ "$INIT" = true ]; then
  echo "Initializing ledger on channel1..."
  ./network.sh deployCC -c channel1 -ccn trading -ccp ./chaincode/trading-go -ccl go -cci InitLedger
  echo "Initializing ledger on channel2..."
  ./network.sh deployCC -c channel2 -ccn trading -ccp ./chaincode/trading-go -ccl go -cci InitLedger
fi

echo ""
echo "Network is up. Channels: channel1, channel2. Chaincode: trading"
