#!/bin/bash
#
# This file sets environment variables so the peer CLI knows which org/peer to
# talk to. Called before every peer command in createChannel.sh and deployCC.sh.

. scripts/utils.sh

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export PEER0_ORG3_CA=${PWD}/organizations/peerOrganizations/org3.example.com/peers/peer0.org3.example.com/tls/ca.crt

# setGlobals <org> [peer]
# Sets CORE_PEER_* env vars so the peer CLI acts as the given org/peer.
# Port formula: 6051 + org*1000 + peer*5
#   org1 peer0 = 7051, peer1 = 7056, peer2 = 7061
#   org2 peer0 = 8051, peer1 = 8056, peer2 = 8061
#   org3 peer0 = 9051, peer1 = 9056, peer2 = 9061
setGlobals() {
  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi

  infoln "Using organization ${USING_ORG}"
  export CORE_PEER_LOCALMSPID="Org${USING_ORG}MSP"
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${USING_ORG}.example.com/users/Admin@org${USING_ORG}.example.com/msp

  if [ $# -eq 2 ]; then
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${USING_ORG}.example.com/peers/peer${2}.org${USING_ORG}.example.com/tls/ca.crt
    export CORE_PEER_ADDRESS="localhost:$((6051 + $USING_ORG * 1000 + $2 * 5))"
  else
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${USING_ORG}.example.com/peers/peer0.org${USING_ORG}.example.com/tls/ca.crt
    export CORE_PEER_ADDRESS="localhost:$((6051 + $USING_ORG * 1000))"
  fi

  if [ "$VERBOSE" == "true" ]; then
    env | grep CORE
  fi
}

# setGlobalsCLI <org> [peer]
# Same as setGlobals but uses the Docker container hostname instead of localhost.
# Used inside the CLI container where peer hostnames are resolvable.
setGlobalsCLI() {
  setGlobals $1 $2

  local USING_ORG=""
  if [ -z "$OVERRIDE_ORG" ]; then
    USING_ORG=$1
  else
    USING_ORG="${OVERRIDE_ORG}"
  fi

  if [ $# -eq 2 ]; then
    export CORE_PEER_ADDRESS=peer${2}.org${USING_ORG}.example.com:$((6051 + $USING_ORG * 1000 + $2 * 5))
  else
    export CORE_PEER_ADDRESS=peer0.org${USING_ORG}.example.com:$((6051 + $USING_ORG * 1000))
  fi
}

# parsePeerConnectionParameters $@
# Builds --peerAddresses and --tlsRootCertFiles flags for all given orgs.
# Used in commitChaincodeDefinition to endorse from all orgs at once.
parsePeerConnectionParameters() {
  PEER_CONN_PARMS=""
  PEERS=""
  while [ "$#" -gt 0 ]; do
    setGlobals $1
    PEER="peer0.org$1"
    PEERS="$PEERS $PEER"
    PEER_CONN_PARMS="$PEER_CONN_PARMS --peerAddresses $CORE_PEER_ADDRESS"
    TLSINFO=$(eval echo "--tlsRootCertFiles \$PEER0_ORG$1_CA")
    PEER_CONN_PARMS="$PEER_CONN_PARMS $TLSINFO"
    shift
  done
  PEERS="$(echo -e "$PEERS" | sed -e 's/^[[:space:]]*//')"
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    fatalln "$2"
  fi
}
