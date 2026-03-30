#!/bin/bash

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_BLUE='\033[0;34m'
C_YELLOW='\033[1;33m'

function printHelp() {
  USAGE="$1"
  if [ "$USAGE" == "up" ]; then
    println "Usage: "
    println "  network.sh \033[0;32mup\033[0m [Flags]"
    println "    Flags:"
    println "    -ca - Use Certificate Authorities to generate network crypto material"
    println "    -s <dbtype> - Peer state database: couchdb (default)"
    println "    -i <imagetag> - Docker image tag (default: latest)"
    println "    -verbose - Verbose mode"
  elif [ "$USAGE" == "createChannel" ]; then
    println "Usage: "
    println "  network.sh \033[0;32mcreateChannel\033[0m [Flags]"
    println "    Flags:"
    println "    -c <channel name> - Name of channel to create (default: mychannel)"
    println "    -r <max retry> - Max retry attempts (default: 5)"
    println "    -d <delay> - Delay between commands in seconds (default: 3)"
  elif [ "$USAGE" == "deployCC" ]; then
    println "Usage: "
    println "  network.sh \033[0;32mdeployCC\033[0m [Flags]"
    println "    Flags:"
    println "    -c <channel name> - Channel to deploy chaincode to"
    println "    -ccn <name> - Chaincode name"
    println "    -ccl <language> - Chaincode language: go, javascript, typescript"
    println "    -ccv <version> - Chaincode version (default: 1.0)"
    println "    -ccs <sequence> - Chaincode sequence (default: 1)"
    println "    -ccp <path> - Path to chaincode"
    println "    -cci <fcn> - Chaincode init function name"
  else
    println "Usage: "
    println "  network.sh <Mode> [Flags]"
    println "    Modes:"
    println "      \033[0;32mup\033[0m - Bring up orderer and peer nodes"
    println "      \033[0;32mcreateChannel\033[0m - Create and join a channel"
    println "      \033[0;32mdeployCC\033[0m - Deploy chaincode to a channel"
    println "      \033[0;32mdown\033[0m - Bring down the network"
  fi
}

function println() {
  echo -e "$1"
}

function errorln() {
  println "${C_RED}${1}${C_RESET}"
}

function successln() {
  println "${C_GREEN}${1}${C_RESET}"
}

function infoln() {
  println "${C_BLUE}${1}${C_RESET}"
}

function warnln() {
  println "${C_YELLOW}${1}${C_RESET}"
}

function fatalln() {
  errorln "$1"
  exit 1
}

export -f errorln
export -f successln
export -f infoln
export -f warnln
