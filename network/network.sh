#!/bin/bash
#
# Main network management script.
# Supports: up | down | createChannel | deployCC
#
# Usage examples:
#   ./network.sh up
#   ./network.sh createChannel -c channel1
#   ./network.sh deployCC -c channel1 -ccn trading -ccp ./chaincode/trading-go -ccl go
#   ./network.sh down

export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/configtx
export VERBOSE=false

export CONFIG_PATH=${PWD}/../config
export ORGANIZATION_NUMBER=3
export PEER_NUMBER=3

. scripts/utils.sh

function clearContainers() {
  CONTAINER_IDS=$(docker ps -a | awk '($2 ~ /dev-peer.*/) {print $1}')
  if [ -z "$CONTAINER_IDS" -o "$CONTAINER_IDS" == " " ]; then
    infoln "No containers available for deletion"
  else
    docker rm -f $CONTAINER_IDS
  fi
}

function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
  if [ -z "$DOCKER_IMAGE_IDS" -o "$DOCKER_IMAGE_IDS" == " " ]; then
    infoln "No images available for deletion"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}

function checkPrereqs() {
  peer version > /dev/null 2>&1
  if [[ $? -ne 0 || ! -d $CONFIG_PATH ]]; then
    errorln "Peer binary and configuration files not found."
    errorln "Run: ./install-fabric.sh binary docker"
    exit 1
  fi

  LOCAL_VERSION=$(peer version | sed -ne 's/^ Version: //p')
  DOCKER_IMAGE_VERSION=$(docker run --rm hyperledger/fabric-tools:$IMAGETAG peer version | sed -ne 's/^ Version: //p')
  infoln "LOCAL_VERSION=$LOCAL_VERSION"
  infoln "DOCKER_IMAGE_VERSION=$DOCKER_IMAGE_VERSION"

  if [ "$LOCAL_VERSION" != "$DOCKER_IMAGE_VERSION" ]; then
    warnln "Local fabric binaries and docker images are out of sync."
  fi
}

# createOrgs — generates crypto material for all orgs and the orderer.
# Uses Fabric CA (Certificate Authorities) by default.
function createOrgs() {
  if [ -d "organizations/peerOrganizations" ]; then
    rm -Rf organizations/peerOrganizations && rm -Rf organizations/ordererOrganizations
  fi

  if [ "$CRYPTO" == "cryptogen" ]; then
    which cryptogen
    if [ "$?" -ne 0 ]; then
      fatalln "cryptogen tool not found."
    fi
    infoln "Generating certificates using cryptogen tool"

    for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
      infoln "Creating Org${i} Identities"
      set -x
      cryptogen generate --config=./organizations/cryptogen/crypto-config-org${i}.yaml --output="organizations"
      res=$?
      { set +x; } 2>/dev/null
      if [ $res -ne 0 ]; then
        fatalln "Failed to generate certificates for Org${i}"
      fi
    done

    infoln "Creating Orderer Org Identities"
    set -x
    cryptogen generate --config=./organizations/cryptogen/crypto-config-orderer.yaml --output="organizations"
    res=$?
    { set +x; } 2>/dev/null
    if [ $res -ne 0 ]; then
      fatalln "Failed to generate orderer certificates"
    fi
  fi

  if [ "$CRYPTO" == "Certificate Authorities" ]; then
    infoln "Generating certificates using Fabric CA"
    IMAGE_TAG=${CA_IMAGETAG} docker compose -f $COMPOSE_FILE_CA up -d 2>&1

    . organizations/fabric-ca/registerEnroll.sh

    # Wait for CA servers to start
    while :
    do
      if [ ! -f "organizations/fabric-ca/org1/tls-cert.pem" ]; then
        sleep 1
      else
        break
      fi
    done

    for (( j=1; j<=$ORGANIZATION_NUMBER; j++ )); do
      infoln "Creating Org${j} Identities"
      createOrg $j
    done

    infoln "Creating Orderer Org Identities"
    createOrderer
  fi

  infoln "Generating connection profiles for orgs"
  ./organizations/ccp-generate.sh $ORGANIZATION_NUMBER
}

# createConsortium — generates the orderer genesis block using configtxgen.
# The genesis block bootstraps the ordering service.
function createConsortium() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatalln "configtxgen tool not found."
  fi

  infoln "Generating Orderer Genesis block"
  set -x
  configtxgen -profile ThreeOrgsOrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
  res=$?
  { set +x; } 2>/dev/null
  if [ $res -ne 0 ]; then
    fatalln "Failed to generate orderer genesis block"
  fi
}

# networkUp — starts all Docker containers (orderer, peers, CouchDBs).
function networkUp() {
  checkPrereqs
  if [ ! -d "organizations/peerOrganizations" ]; then
    createOrgs
    createConsortium
  fi

  COMPOSE_FILES="-f ${COMPOSE_FILE_BASE}"
  if [ "${DATABASE}" == "couchdb" ]; then
    COMPOSE_FILES="${COMPOSE_FILES} -f ${COMPOSE_FILE_COUCH}"
  fi

  IMAGE_TAG=$IMAGETAG docker compose ${COMPOSE_FILES} up -d 2>&1
  docker ps -a
  if [ $? -ne 0 ]; then
    fatalln "Unable to start network"
  fi
}

function createChannel() {
  if [ ! -d "organizations/peerOrganizations" ]; then
    infoln "Bringing up network"
    networkUp
  fi
  scripts/createChannel.sh $CHANNEL_NAME $CLI_DELAY $MAX_RETRY $VERBOSE
}

function deployCC() {
  scripts/deployCC.sh $CHANNEL_NAME $CC_NAME $CC_SRC_PATH $CC_SRC_LANGUAGE $CC_VERSION $CC_SEQUENCE $CC_INIT_FCN $CC_END_POLICY $CC_COLL_CONFIG $CLI_DELAY $MAX_RETRY $VERBOSE
  if [ $? -ne 0 ]; then
    fatalln "Deploying chaincode failed"
  fi
}

function networkDown() {
  docker compose -f $COMPOSE_FILE_BASE -f $COMPOSE_FILE_COUCH -f $COMPOSE_FILE_CA down --volumes --remove-orphans
  if [ "$MODE" != "restart" ]; then
    clearContainers
    removeUnwantedImages
    docker run --rm -v $(pwd):/data busybox sh -c 'cd /data && rm -rf system-genesis-block/*.block organizations/peerOrganizations organizations/ordererOrganizations'
    for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
      docker run --rm -v $(pwd):/data busybox sh -c "cd /data && rm -rf organizations/fabric-ca/org${i}/msp organizations/fabric-ca/org${i}/tls-cert.pem organizations/fabric-ca/org${i}/ca-cert.pem organizations/fabric-ca/org${i}/IssuerPublicKey organizations/fabric-ca/org${i}/IssuerRevocationPublicKey organizations/fabric-ca/org${i}/fabric-ca-server.db"
    done
    docker run --rm -v $(pwd):/data busybox sh -c 'cd /data && rm -rf organizations/fabric-ca/ordererOrg/msp organizations/fabric-ca/ordererOrg/tls-cert.pem organizations/fabric-ca/ordererOrg/ca-cert.pem organizations/fabric-ca/ordererOrg/IssuerPublicKey organizations/fabric-ca/ordererOrg/IssuerRevocationPublicKey organizations/fabric-ca/ordererOrg/fabric-ca-server.db'
    docker run --rm -v $(pwd):/data busybox sh -c 'cd /data && rm -rf channel-artifacts log.txt *.tar.gz'
  fi
}

# ---- Defaults ----
CRYPTO="Certificate Authorities"
MAX_RETRY=5
CLI_DELAY=3
CHANNEL_NAME="mychannel"
CC_NAME="NA"
CC_SRC_PATH="NA"
CC_END_POLICY="NA"
CC_COLL_CONFIG="NA"
CC_INIT_FCN="NA"
CC_SRC_LANGUAGE="NA"
CC_VERSION="1.0"
CC_SEQUENCE=1
COMPOSE_FILE_BASE=docker/docker-compose-test-net.yaml
COMPOSE_FILE_COUCH=docker/docker-compose-couch.yaml
COMPOSE_FILE_CA=docker/docker-compose-ca.yaml
IMAGETAG="latest"
CA_IMAGETAG="latest"
DATABASE="couchdb"

# ---- Parse mode ----
if [[ $# -lt 1 ]]; then
  printHelp
  exit 0
else
  MODE=$1
  shift
fi

# ---- Parse flags ----
while [[ $# -ge 1 ]]; do
  key="$1"
  case $key in
  -h)
    printHelp $MODE
    exit 0
    ;;
  -c)
    CHANNEL_NAME="$2"
    shift
    ;;
  -ca)
    CRYPTO="Certificate Authorities"
    ;;
  -r)
    MAX_RETRY="$2"
    shift
    ;;
  -d)
    CLI_DELAY="$2"
    shift
    ;;
  -s)
    DATABASE="$2"
    shift
    ;;
  -ccl)
    CC_SRC_LANGUAGE="$2"
    shift
    ;;
  -ccn)
    CC_NAME="$2"
    shift
    ;;
  -ccv)
    CC_VERSION="$2"
    shift
    ;;
  -ccs)
    CC_SEQUENCE="$2"
    shift
    ;;
  -ccp)
    CC_SRC_PATH="$2"
    shift
    ;;
  -ccep)
    CC_END_POLICY="$2"
    shift
    ;;
  -cccg)
    CC_COLL_CONFIG="$2"
    shift
    ;;
  -cci)
    CC_INIT_FCN="$2"
    shift
    ;;
  -i)
    IMAGETAG="$2"
    shift
    ;;
  -cai)
    CA_IMAGETAG="$2"
    shift
    ;;
  -verbose)
    VERBOSE=true
    ;;
  *)
    errorln "Unknown flag: $key"
    printHelp
    exit 1
    ;;
  esac
  shift
done

# ---- Dispatch ----
if [ "$MODE" == "up" ]; then
  infoln "Starting network"
  networkUp
elif [ "$MODE" == "createChannel" ]; then
  infoln "Creating channel '${CHANNEL_NAME}'"
  createChannel
elif [ "$MODE" == "deployCC" ]; then
  infoln "Deploying chaincode on channel '${CHANNEL_NAME}'"
  deployCC
elif [ "$MODE" == "down" ]; then
  infoln "Stopping network"
  networkDown
else
  printHelp
  exit 1
fi
