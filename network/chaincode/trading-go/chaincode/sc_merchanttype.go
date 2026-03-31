package chaincode

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func (s *SmartContract) CreateMerchantType(ctx contractapi.TransactionContextInterface, id, name, description string) error {
	existing, _ := ctx.GetStub().GetState(merchantTypeKey(id))
	if existing != nil {
		return fmt.Errorf("merchant type %s already exists", id)
	}
	mt := MerchantType{ID: id, Name: name, Description: description, DocType: "merchantType"}
	return putState(ctx, merchantTypeKey(id), mt)
}

func (s *SmartContract) GetMerchantType(ctx contractapi.TransactionContextInterface, id string) (*MerchantType, error) {
	bytes, err := getState(ctx, merchantTypeKey(id))
	if err != nil {
		return nil, err
	}
	var mt MerchantType
	if err := json.Unmarshal(bytes, &mt); err != nil {
		return nil, fmt.Errorf("failed to unmarshal merchant type: %w", err)
	}
	return &mt, nil
}

func (s *SmartContract) GetAllMerchantTypes(ctx contractapi.TransactionContextInterface) ([]*MerchantType, error) {
	iterator, err := ctx.GetStub().GetStateByRange("MERCHANTTYPE_", "MERCHANTTYPE_~")
	if err != nil {
		return nil, err
	}
	defer iterator.Close()

	var results []*MerchantType
	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		var mt MerchantType
		if err := json.Unmarshal(kv.Value, &mt); err != nil {
			return nil, err
		}
		results = append(results, &mt)
	}
	return results, nil
}
