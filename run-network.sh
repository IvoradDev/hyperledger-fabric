#!/bin/bash
set -e

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

./network.sh down

./network.sh up

./network.sh createChannel -c channel1
./network.sh createChannel -c channel2

if [ "$INIT" = true ]; then
  ./network.sh deployCC -c channel1 -ccn trading -ccp ./chaincode/trading-go -ccl go -cci InitLedger
  ./network.sh deployCC -c channel2 -ccn trading -ccp ./chaincode/trading-go -ccl go -cci InitLedger
else
  ./network.sh deployCC -c channel1 -ccn trading -ccp ./chaincode/trading-go -ccl go
  ./network.sh deployCC -c channel2 -ccn trading -ccp ./chaincode/trading-go -ccl go
fi

echo ""
echo "Network is up. Channels: channel1, channel2. Chaincode: trading"
