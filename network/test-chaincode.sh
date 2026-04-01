#!/bin/bash
export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=${PWD}/config
export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

C_RESET='\033[0m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

PASS=0
FAIL=0

function setOrg() {
  local ORG=$1
  local PEER=${2:-0}
  local PORT=$((6051 + ORG * 1000 + PEER * 5))
  export CORE_PEER_LOCALMSPID="Org${ORG}MSP"
  export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org${ORG}.example.com/users/Admin@org${ORG}.example.com/msp
  export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org${ORG}.example.com/peers/peer${PEER}.org${ORG}.example.com/tls/ca.crt
  export CORE_PEER_ADDRESS="localhost:${PORT}"
}

function runQuery() {
  local LABEL=$1
  local CHANNEL=$2
  local FN=$3
  shift 3
  local ARGS=$@

  if [ -z "$ARGS" ]; then
    ARGS_JSON='{"Args":["'"$FN"'"]}'
  else
    ARGS_LIST=$(echo "$ARGS" | sed 's/ /","/g')
    ARGS_JSON='{"Args":["'"$FN"'","'"$ARGS_LIST"'"]}'
  fi

  echo -e "\n${C_BLUE}[QUERY] $LABEL${C_RESET}"
  RESULT=$(peer chaincode query -C $CHANNEL -n trading -c "$ARGS_JSON" 2>&1)
  if [ $? -eq 0 ]; then
    echo -e "${C_GREEN}PASS${C_RESET}: $RESULT" | head -c 300
    echo ""
    PASS=$((PASS + 1))
  else
    echo -e "${C_RED}FAIL${C_RESET}: $RESULT"
    FAIL=$((FAIL + 1))
  fi
}

function runInvoke() {
  local LABEL=$1
  local CHANNEL=$2
  local FN=$3
  shift 3
  local ARGS=$@

  local P1_ADDR="localhost:7051"
  local P1_TLS=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  local P2_ADDR="localhost:8051"
  local P2_TLS=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

  if [ -z "$ARGS" ]; then
    ARGS_JSON='{"Args":["'"$FN"'"]}'
  else
    ARGS_LIST=$(echo "$ARGS" | sed 's/ /","/g')
    ARGS_JSON='{"Args":["'"$FN"'","'"$ARGS_LIST"'"]}'
  fi

  echo -e "\n${C_BLUE}[INVOKE] $LABEL${C_RESET}"
  peer chaincode invoke \
    -o localhost:6050 --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile $ORDERER_CA \
    -C $CHANNEL -n trading \
    --peerAddresses $P1_ADDR --tlsRootCertFiles $P1_TLS \
    --peerAddresses $P2_ADDR --tlsRootCertFiles $P2_TLS \
    -c "$ARGS_JSON" 2>&1

  if [ $? -eq 0 ]; then
    echo -e "${C_GREEN}PASS${C_RESET}"
    PASS=$((PASS + 1))
    sleep 2
  else
    echo -e "${C_RED}FAIL${C_RESET}"
    FAIL=$((FAIL + 1))
  fi
}

function runExpectFail() {
  local LABEL=$1
  local CHANNEL=$2
  local FN=$3
  shift 3
  local ARGS=$@

  local P1_ADDR="localhost:7051"
  local P1_TLS=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
  local P2_ADDR="localhost:8051"
  local P2_TLS=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

  if [ -z "$ARGS" ]; then
    ARGS_JSON='{"Args":["'"$FN"'"]}'
  else
    ARGS_LIST=$(echo "$ARGS" | sed 's/ /","/g')
    ARGS_JSON='{"Args":["'"$FN"'","'"$ARGS_LIST"'"]}'
  fi

  echo -e "\n${C_YELLOW}[EXPECT FAIL] $LABEL${C_RESET}"
  peer chaincode invoke \
    -o localhost:6050 --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile $ORDERER_CA \
    -C $CHANNEL -n trading \
    --peerAddresses $P1_ADDR --tlsRootCertFiles $P1_TLS \
    --peerAddresses $P2_ADDR --tlsRootCertFiles $P2_TLS \
    -c "$ARGS_JSON" 2>&1

  if [ $? -ne 0 ]; then
    echo -e "${C_GREEN}PASS${C_RESET} (correctly rejected)"
    PASS=$((PASS + 1))
  else
    echo -e "${C_RED}FAIL${C_RESET} (should have been rejected)"
    FAIL=$((FAIL + 1))
  fi
}

setOrg 1

echo -e "${C_BLUE}==============================${C_RESET}"
echo -e "${C_BLUE} Trading Network Test Suite   ${C_RESET}"
echo -e "${C_BLUE}==============================${C_RESET}"

# --- Init ---
runInvoke "InitLedger on channel1" channel1 InitLedger
runInvoke "InitLedger on channel2" channel2 InitLedger

# --- Merchant Types ---
runQuery  "GetAllMerchantTypes" channel1 GetAllMerchantTypes
runQuery  "GetMerchantType MT1" channel1 GetMerchantType MT1
runInvoke "CreateMerchantType MT4" channel1 CreateMerchantType MT4 Pharmacy "Sells medicine and health products"
runQuery  "GetMerchantType MT4 (newly created)" channel1 GetMerchantType MT4

# --- Merchants ---
runQuery  "GetAllMerchants" channel1 GetAllMerchants
runQuery  "GetMerchant M1" channel1 GetMerchant M1
runInvoke "CreateMerchant M4" channel1 CreateMerchant M4 MT4 444444444 2000
runQuery  "GetMerchant M4 (newly created)" channel1 GetMerchant M4
runInvoke "DepositToMerchant M1" channel1 DepositToMerchant M1 500
runQuery  "GetMerchant M1 (balance increased)" channel1 GetMerchant M1

# --- Products ---
runQuery  "GetAllProducts" channel1 GetAllProducts
runQuery  "GetProduct P1" channel1 GetProduct P1
runInvoke "CreateProduct P7 for M4" channel1 CreateProduct P7 M4 Aspirin 2027-12-01 3.50 100
runQuery  "GetProduct P7 (newly created)" channel1 GetProduct P7

# --- Users ---
runQuery  "GetAllUsers" channel1 GetAllUsers
runQuery  "GetUser U1" channel1 GetUser U1
runInvoke "CreateUser U5" channel1 CreateUser U5 Stefan Stefanovic stefan@example.com 800
runQuery  "GetUser U5 (newly created)" channel1 GetUser U5
runInvoke "DepositToUser U3" channel1 DepositToUser U3 300
runQuery  "GetUser U3 (balance increased)" channel1 GetUser U3

# --- Purchase ---
runInvoke "PurchaseProduct - U2 buys Laptop from M2" channel1 PurchaseProduct R1 U2 M2 P3
runQuery  "GetReceipt R1" channel1 GetReceipt R1
runQuery  "GetUser U2 (balance decreased)" channel1 GetUser U2
runQuery  "GetMerchant M2 (balance increased)" channel1 GetMerchant M2
runQuery  "GetUserReceipts U2" channel1 GetUserReceipts U2
runQuery  "GetMerchantReceipts M2" channel1 GetMerchantReceipts M2

runInvoke "PurchaseProduct - U1 buys Milk from M1" channel1 PurchaseProduct R2 U1 M1 P1
runInvoke "PurchaseProduct - U4 buys Engine Oil from M3" channel1 PurchaseProduct R3 U4 M3 P6

# --- Channel 2 (same chaincode, separate ledger) ---
setOrg 2
runQuery  "GetAllMerchants on channel2 (via org2)" channel2 GetAllMerchants
runInvoke "PurchaseProduct on channel2 - U1 buys USB Cable" channel2 PurchaseProduct R4 U1 M2 P4
runQuery  "GetReceipt R4 on channel2" channel2 GetReceipt R4
setOrg 1

# --- Rich Queries (CouchDB) ---
runQuery  "SearchProductsByName 'Milk'" channel1 SearchProductsByName Milk
runQuery  "SearchProductsByName 'oil' (case-insensitive)" channel1 SearchProductsByName oil
runQuery  "SearchProductsByMerchantType MT2 (Electronics)" channel1 SearchProductsByMerchantType MT2
runQuery  "SearchProductsByPriceRange 1.00 10.00" channel1 SearchProductsByPriceRange 1.00 10.00
runQuery  "SearchProducts name='' type=MT1 min=0 max=5" channel1 SearchProducts "" MT1 0 5
runQuery  "SearchProducts name='brake' type='' min=0 max=0" channel1 SearchProducts brake "" 0 0
runQuery  "GetMerchantsByType MT3" channel1 GetMerchantsByType MT3
runQuery  "GetRichMerchantsWithProducts" channel1 GetRichMerchantsWithProducts
runQuery  "SearchUsersBySurname 'ic'" channel1 SearchUsersBySurname ic
runQuery  "GetUsersWithBalanceAbove 300" channel1 GetUsersWithBalanceAbove 300

# --- Error cases ---
runExpectFail "PurchaseProduct - user does not exist" channel1 PurchaseProduct R99 U99 M1 P1
runExpectFail "PurchaseProduct - product does not exist" channel1 PurchaseProduct R99 U1 M1 P99
runExpectFail "PurchaseProduct - merchant does not exist" channel1 PurchaseProduct R99 U1 M99 P1
runExpectFail "PurchaseProduct - insufficient balance (U3 has ~200, Laptop costs 999.99)" channel1 PurchaseProduct R99 U3 M2 P3
runExpectFail "PurchaseProduct - duplicate receipt ID" channel1 PurchaseProduct R1 U1 M1 P1
runExpectFail "CreateMerchant - duplicate ID" channel1 CreateMerchant M1 MT1 111111111 0
runExpectFail "CreateUser - duplicate ID" channel1 CreateUser U1 Marko Markovic marko@example.com 0
runExpectFail "DepositToMerchant - negative amount" channel1 DepositToMerchant M1 -100
runExpectFail "DepositToUser - zero amount" channel1 DepositToUser U1 0

# --- Summary ---
echo ""
echo -e "${C_BLUE}==============================${C_RESET}"
echo -e "  PASSED: ${C_GREEN}${PASS}${C_RESET}"
echo -e "  FAILED: ${C_RED}${FAIL}${C_RESET}"
echo -e "${C_BLUE}==============================${C_RESET}"
