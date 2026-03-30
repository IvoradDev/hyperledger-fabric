#!/bin/bash
#
# Sets anchor peers for an org on a channel.
# An anchor peer is the peer other orgs use for cross-org gossip communication.
# Called once per org per channel after peers join the channel.
# Must run inside the CLI container.

. scripts/envVar.sh
. scripts/configUpdate.sh

# createAnchorPeerUpdate <peer_index>
# Fetches current channel config, adds AnchorPeers entry for this org/peer,
# then computes the config update transaction.
createAnchorPeerUpdate() {
  infoln "Fetching channel config for channel $CHANNEL_NAME"
  fetchChannelConfig $ORG $CHANNEL_NAME ${CORE_PEER_LOCALMSPID}config.json

  infoln "Generating anchor peer update transaction for Org${ORG} on channel $CHANNEL_NAME"

  HOST="peer${1}.org${ORG}.example.com"
  PORT=$((6051 + $ORG * 1000 + $1 * 5))

  set -x
  jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'$HOST'","port": '$PORT'}]},"version": "0"}}' ${CORE_PEER_LOCALMSPID}config.json > ${CORE_PEER_LOCALMSPID}modified_config.json
  { set +x; } 2>/dev/null

  createConfigUpdate ${CHANNEL_NAME} ${CORE_PEER_LOCALMSPID}config.json ${CORE_PEER_LOCALMSPID}modified_config.json ${CORE_PEER_LOCALMSPID}anchors.tx
}

updateAnchorPeer() {
  peer channel update -o orderer.example.com:6050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL_NAME -f ${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile $ORDERER_CA >&log.txt
  res=$?
  cat log.txt
  verifyResult $res "Anchor peer update failed"
  successln "Anchor peer set for org '$CORE_PEER_LOCALMSPID' on channel '$CHANNEL_NAME'"
}

ORG=$1
CHANNEL_NAME=$2
PEER_NUMBER=$3

for (( j=0; j<($PEER_NUMBER); j++ )); do
  setGlobalsCLI $ORG $j
  createAnchorPeerUpdate $j
  updateAnchorPeer $j
done
