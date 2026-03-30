#!/bin/bash
#
# Creates a Fabric channel, joins all peers from all 3 orgs, and sets anchor peers.
# Called by network.sh createChannel -c <channelName>

. scripts/envVar.sh
. scripts/utils.sh

CHANNEL_NAME="$1"
DELAY="$2"
MAX_RETRY="$3"
VERBOSE="$4"
: ${CHANNEL_NAME:="mychannel"}
: ${DELAY:="3"}
: ${MAX_RETRY:="5"}
: ${VERBOSE:="false"}

if [ ! -d "channel-artifacts" ]; then
  mkdir channel-artifacts
fi

# createChannelTx
# Uses configtxgen to create the channel creation transaction from the
# ThreeOrgsChannel profile defined in configtx.yaml.
createChannelTx() {
  set -x
  configtxgen -profile ThreeOrgsChannel -outputCreateChannelTx ./channel-artifacts/${CHANNEL_NAME}.tx -channelID $CHANNEL_NAME
  res=$?
  { set +x; } 2>/dev/null
  verifyResult $res "Failed to generate channel configuration transaction..."
}

# createChannel
# Submits the channel creation transaction to the orderer.
# Retries up to MAX_RETRY times in case the RAFT leader is not yet elected.
createChannel() {
  setGlobals 1
  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer channel create -o localhost:6050 -c $CHANNEL_NAME --ordererTLSHostnameOverride orderer.example.com -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock $BLOCKFILE --tls --cafile $ORDERER_CA >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=$res
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  verifyResult $res "Channel creation failed"
}

# joinChannel <org>
# Joins every peer in the given org to the channel.
joinChannel() {
  FABRIC_CFG_PATH=$CONFIG_PATH
  ORG=$1
  for (( j=0; j<($PEER_NUMBER); j++ )); do
    setGlobals $ORG $j
    local rc=1
    local COUNTER=1
    while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
      sleep $DELAY
      set -x
      peer channel join -b $BLOCKFILE >&log.txt
      res=$?
      { set +x; } 2>/dev/null
      let rc=$res
      COUNTER=$(expr $COUNTER + 1)
    done
    cat log.txt
    verifyResult $res "After $MAX_RETRY attempts, peer${j}.org${ORG} has failed to join channel '$CHANNEL_NAME'"
  done
}

setAnchorPeer() {
  ORG=$1
  docker exec cli ./scripts/setAnchorPeer.sh $ORG $CHANNEL_NAME $PEER_NUMBER
}

FABRIC_CFG_PATH=${PWD}/configtx

## Step 1 — generate channel creation transaction
infoln "Generating channel create transaction '${CHANNEL_NAME}.tx'"
createChannelTx

FABRIC_CFG_PATH=$CONFIG_PATH
BLOCKFILE="./channel-artifacts/${CHANNEL_NAME}.block"

## Step 2 — submit to orderer, get genesis block for the channel
infoln "Creating channel ${CHANNEL_NAME}"
createChannel
successln "Channel '$CHANNEL_NAME' created"

## Step 3 — join all peers from all 3 orgs
for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
  infoln "Joining org${i} peers to the channel..."
  joinChannel $i
done

## Step 4 — set anchor peers for each org (enables cross-org gossip)
for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
  infoln "Setting anchor peer for org${i}..."
  setAnchorPeer $i
done

successln "Channel '$CHANNEL_NAME' joined by all orgs"
