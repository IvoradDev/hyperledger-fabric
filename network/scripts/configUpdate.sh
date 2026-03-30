#!/bin/bash
#
# Helpers for fetching and updating channel configuration.
# Used by setAnchorPeer.sh to push anchor peer updates to a channel.
# Must run inside the CLI container (requires configtxlator and jq).

. scripts/envVar.sh

# fetchChannelConfig <org> <channel_id> <output_json>
# Fetches the current channel config block and decodes it to JSON.
fetchChannelConfig() {
  ORG=$1
  CHANNEL=$2
  OUTPUT=$3

  setGlobals $ORG

  infoln "Fetching the most recent configuration block for channel $CHANNEL"
  set -x
  peer channel fetch config config_block.pb -o orderer.example.com:6050 --ordererTLSHostnameOverride orderer.example.com -c $CHANNEL --tls --cafile $ORDERER_CA
  { set +x; } 2>/dev/null

  infoln "Decoding config block to JSON and isolating config to ${OUTPUT}"
  set -x
  configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config >"${OUTPUT}"
  { set +x; } 2>/dev/null
}

# createConfigUpdate <channel_id> <original.json> <modified.json> <output.pb>
# Computes the diff between original and modified config, outputs a config update envelope.
createConfigUpdate() {
  CHANNEL=$1
  ORIGINAL=$2
  MODIFIED=$3
  OUTPUT=$4

  set -x
  configtxlator proto_encode --input "${ORIGINAL}" --type common.Config >original_config.pb
  configtxlator proto_encode --input "${MODIFIED}" --type common.Config >modified_config.pb
  configtxlator compute_update --channel_id "${CHANNEL}" --original original_config.pb --updated modified_config.pb >config_update.pb
  configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate >config_update.json
  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . >config_update_in_envelope.json
  configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope >"${OUTPUT}"
  { set +x; } 2>/dev/null
}

# signConfigtxAsPeerOrg <org> <configtx.pb>
signConfigtxAsPeerOrg() {
  ORG=$1
  CONFIGTXFILE=$2
  setGlobals $ORG
  set -x
  peer channel signconfigtx -f "${CONFIGTXFILE}"
  { set +x; } 2>/dev/null
}
