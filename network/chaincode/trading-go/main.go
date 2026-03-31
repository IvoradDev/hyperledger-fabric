package main

import (
	"log"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/trading-go/chaincode"
)

func main() {
	tradingChaincode, err := contractapi.NewChaincode(&chaincode.SmartContract{})
	if err != nil {
		log.Panicf("Error creating trading chaincode: %v", err)
	}

	if err := tradingChaincode.Start(); err != nil {
		log.Panicf("Error starting trading chaincode: %v", err)
	}
}
