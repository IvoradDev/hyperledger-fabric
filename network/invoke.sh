#!/bin/bash
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/../config
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

CHANNEL=${1:-channel1}
shift
FUNCTION=$1
shift
ARGS=$@

PEER_ADDRESS="localhost:7051"
PEER_TLS=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER_TLS
export CORE_PEER_ADDRESS=$PEER_ADDRESS

PEER2_ADDRESS="localhost:8051"
PEER2_TLS=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

if [ -z "$ARGS" ]; then
  ARGS_JSON='{"Args":["'"$FUNCTION"'"]}'
else
  ARGS_LIST=$(echo "$ARGS" | sed 's/ /","/g')
  ARGS_JSON='{"Args":["'"$FUNCTION"'","'"$ARGS_LIST"'"]}'
fi

peer chaincode invoke \
  -o localhost:6050 \
  --ordererTLSHostnameOverride orderer.example.com \
  --tls --cafile $ORDERER_CA \
  -C $CHANNEL -n trading \
  --peerAddresses $PEER_ADDRESS --tlsRootCertFiles $PEER_TLS \
  --peerAddresses $PEER2_ADDRESS --tlsRootCertFiles $PEER2_TLS \
  -c "$ARGS_JSON"
