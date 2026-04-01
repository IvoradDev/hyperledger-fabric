#!/bin/bash
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config
export CORE_PEER_TLS_ENABLED=true

CHANNEL=${1:-channel1}
shift
FUNCTION=$1
shift
ARGS=$@

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS="localhost:7051"

if [ -z "$ARGS" ]; then
  ARGS_JSON='{"Args":["'"$FUNCTION"'"]}'
else
  ARGS_LIST=$(echo "$ARGS" | sed 's/ /","/g')
  ARGS_JSON='{"Args":["'"$FUNCTION"'","'"$ARGS_LIST"'"]}'
fi

peer chaincode query -C $CHANNEL -n trading -c "$ARGS_JSON"
