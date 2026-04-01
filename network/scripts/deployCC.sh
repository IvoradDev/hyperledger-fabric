#!/bin/bash
#
# Deploys a chaincode to a channel using the Fabric v2 lifecycle:
#   package → install (all peers) → approve (each org) → commit → (optional) init
# Called by network.sh deployCC

source scripts/utils.sh

CHANNEL_NAME=${1:-"mychannel"}
CC_NAME=${2}
CC_SRC_PATH=${3}
CC_SRC_LANGUAGE=${4}
CC_VERSION=${5:-"1.0"}
CC_SEQUENCE=${6:-"1"}
CC_INIT_FCN=${7:-"NA"}
CC_END_POLICY=${8:-"NA"}
CC_COLL_CONFIG=${9:-"NA"}
DELAY=${10:-"3"}
MAX_RETRY=${11:-"5"}
VERBOSE=${12:-"false"}

println "executing with the following"
println "- CHANNEL_NAME: ${C_GREEN}${CHANNEL_NAME}${C_RESET}"
println "- CC_NAME: ${C_GREEN}${CC_NAME}${C_RESET}"
println "- CC_SRC_PATH: ${C_GREEN}${CC_SRC_PATH}${C_RESET}"
println "- CC_SRC_LANGUAGE: ${C_GREEN}${CC_SRC_LANGUAGE}${C_RESET}"
println "- CC_VERSION: ${C_GREEN}${CC_VERSION}${C_RESET}"
println "- CC_SEQUENCE: ${C_GREEN}${CC_SEQUENCE}${C_RESET}"
println "- CC_INIT_FCN: ${C_GREEN}${CC_INIT_FCN}${C_RESET}"

FABRIC_CFG_PATH=$CONFIG_PATH

if [ -z "$CC_NAME" ] || [ "$CC_NAME" = "NA" ]; then
  fatalln "No chaincode name provided."
elif [ -z "$CC_SRC_PATH" ] || [ "$CC_SRC_PATH" = "NA" ]; then
  fatalln "No chaincode path provided."
elif [ -z "$CC_SRC_LANGUAGE" ] || [ "$CC_SRC_LANGUAGE" = "NA" ]; then
  fatalln "No chaincode language provided."
elif [ ! -d "$CC_SRC_PATH" ]; then
  fatalln "Path to chaincode does not exist: $CC_SRC_PATH"
fi

CC_SRC_LANGUAGE=$(echo "$CC_SRC_LANGUAGE" | tr [:upper:] [:lower:])

if [ "$CC_SRC_LANGUAGE" = "go" ]; then
  CC_RUNTIME_LANGUAGE=golang
  infoln "Vendoring Go dependencies at $CC_SRC_PATH"
  pushd $CC_SRC_PATH
  GO111MODULE=on go mod vendor
  popd
  successln "Finished vendoring Go dependencies"
elif [ "$CC_SRC_LANGUAGE" = "javascript" ]; then
  CC_RUNTIME_LANGUAGE=node
elif [ "$CC_SRC_LANGUAGE" = "typescript" ]; then
  CC_RUNTIME_LANGUAGE=node
  pushd $CC_SRC_PATH
  npm install
  npm run build
  popd
else
  fatalln "Unsupported chaincode language: ${CC_SRC_LANGUAGE}"
fi

INIT_REQUIRED="--init-required"
if [ "$CC_INIT_FCN" = "NA" ]; then
  INIT_REQUIRED=""
fi

if [ "$CC_END_POLICY" = "NA" ]; then
  CC_END_POLICY=""
else
  CC_END_POLICY="--signature-policy $CC_END_POLICY"
fi

if [ "$CC_COLL_CONFIG" = "NA" ]; then
  CC_COLL_CONFIG=""
else
  CC_COLL_CONFIG="--collections-config $CC_COLL_CONFIG"
fi

. scripts/envVar.sh

# packageChaincode — creates a .tar.gz package from chaincode source
packageChaincode() {
  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz --path ${CC_SRC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode packaging has failed"
  successln "Chaincode is packaged"
}

# installChaincode <org> — installs the package on every peer in the org
installChaincode() {
  ORG=$1
  for (( j=0; j<($PEER_NUMBER); j++ )); do
    infoln "Installing chaincode on peer${j}.org${ORG}..."
    setGlobals $ORG $j
    set -x
    peer lifecycle chaincode install ${CC_NAME}.tar.gz >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    cat log.txt
    if [ $res -ne 0 ]; then
      grep -q "already successfully installed" log.txt && res=0
    fi
    verifyResult $res "Chaincode installation on peer${j}.org${ORG} has failed"
    successln "Chaincode installed on peer${j}.org${ORG}"
  done
}

# queryInstalled <org> — finds the package ID needed for approveformyorg
queryInstalled() {
  ORG=$1
  for (( j=0; j<($PEER_NUMBER); j++ )); do
    setGlobals $ORG $j
    set -x
    peer lifecycle chaincode queryinstalled >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    cat log.txt
    PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
    verifyResult $res "Query installed on peer${j}.org${ORG} has failed"
    successln "Query installed successful on peer${j}.org${ORG}"
  done
}

# approveForMyOrg <org> — org admin approves the chaincode definition
approveForMyOrg() {
  ORG=$1
  setGlobals $ORG
  set -x
  peer lifecycle chaincode approveformyorg -o localhost:6050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --package-id ${PACKAGE_ID} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition approved on peer0.org${ORG} failed"
  successln "Chaincode definition approved on peer0.org${ORG} on channel '$CHANNEL_NAME'"
}

# checkCommitReadiness <org> — polls until the org shows as approved
checkCommitReadiness() {
  ORG=$1
  shift 1
  setGlobals $ORG
  infoln "Checking commit readiness on peer0.org${ORG} on channel '$CHANNEL_NAME'..."
  local rc=1
  local COUNTER=1
  while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
    sleep $DELAY
    set -x
    peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME --name ${CC_NAME} --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} --output json >&log.txt
    res=$?
    { set +x; } 2>/dev/null
    let rc=0
    for var in "$@"; do
      grep "$var" log.txt &>/dev/null || let rc=1
    done
    COUNTER=$(expr $COUNTER + 1)
  done
  cat log.txt
  if test $rc -eq 0; then
    infoln "Commit readiness check successful on peer0.org${ORG}"
  else
    fatalln "After $MAX_RETRY attempts, commit readiness on peer0.org${ORG} is INVALID!"
  fi
}

# commitChaincodeDefinition — submits the approved definition to the channel
commitChaincodeDefinition() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke transaction failed on channel '$CHANNEL_NAME'"

  set -x
  peer lifecycle chaincode commit -o localhost:6050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA --channelID $CHANNEL_NAME --name ${CC_NAME} $PEER_CONN_PARMS --version ${CC_VERSION} --sequence ${CC_SEQUENCE} ${INIT_REQUIRED} ${CC_END_POLICY} ${CC_COLL_CONFIG} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Chaincode definition commit failed on channel '$CHANNEL_NAME'"
  successln "Chaincode definition committed on channel '$CHANNEL_NAME'"
}

# queryCommitted <org> — verifies chaincode is committed on all peers
queryCommitted() {
  ORG=$1
  for (( j=0; j<($PEER_NUMBER); j++ )); do
    setGlobals $ORG $j
    EXPECTED_RESULT="Version: ${CC_VERSION}, Sequence: ${CC_SEQUENCE}, Endorsement Plugin: escc, Validation Plugin: vscc"
    infoln "Querying chaincode definition on peer${j}.org${ORG} on channel '$CHANNEL_NAME'..."
    local rc=1
    local COUNTER=1
    while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
      sleep $DELAY
      set -x
      peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name ${CC_NAME} >&log.txt
      res=$?
      { set +x; } 2>/dev/null
      test $res -eq 0 && VALUE=$(cat log.txt | grep -o '^Version: '$CC_VERSION', Sequence: [0-9]*, Endorsement Plugin: escc, Validation Plugin: vscc')
      test "$VALUE" = "$EXPECTED_RESULT" && let rc=0
      COUNTER=$(expr $COUNTER + 1)
    done
    cat log.txt
    if test $rc -eq 0; then
      successln "Query chaincode definition successful on peer${j}.org${ORG}"
    else
      fatalln "After $MAX_RETRY attempts, query chaincode definition on peer${j}.org${ORG} is INVALID!"
    fi
  done
}

# chaincodeInvokeInit — calls the init function after commit (if specified)
chaincodeInvokeInit() {
  parsePeerConnectionParameters $@
  res=$?
  verifyResult $res "Invoke failed on channel '$CHANNEL_NAME'"

  set -x
  fcn_call='{"function":"'${CC_INIT_FCN}'","Args":[]}'
  infoln "invoke fcn call:${fcn_call}"
  peer chaincode invoke -o localhost:6050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile $ORDERER_CA -C $CHANNEL_NAME -n ${CC_NAME} $PEER_CONN_PARMS --isInit -c ${fcn_call} >&log.txt
  res=$?
  { set +x; } 2>/dev/null
  cat log.txt
  verifyResult $res "Invoke execution on $PEERS failed"
  successln "Invoke transaction successful on $PEERS on channel '$CHANNEL_NAME'"
}

## --- Main lifecycle flow ---

## 1. Package
packageChaincode

## 2. Install on all peers of all orgs
for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
  installChaincode $i
done

## 3. Query installed + Approve for each org
orgs=""
for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
  queryInstalled $i
  orgs="$orgs $i"
  approveForMyOrg $i
done

## 4. Commit the definition (all orgs endorse)
commitChaincodeDefinition $orgs

## 5. Verify committed on all peers
for (( i=1; i<=$ORGANIZATION_NUMBER; i++ )); do
  queryCommitted $i
done

## 6. Invoke init function if specified
if [ "$CC_INIT_FCN" = "NA" ]; then
  infoln "Chaincode initialization is not required"
else
  chaincodeInvokeInit $orgs
fi

exit 0
