package chaincode

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func (s *SmartContract) CreateMerchant(ctx contractapi.TransactionContextInterface, id, merchantTypeID, pib string, balance float64) error {
	existing, _ := ctx.GetStub().GetState(merchantKey(id))
	if existing != nil {
		return fmt.Errorf("merchant %s already exists", id)
	}
	if _, err := s.GetMerchantType(ctx, merchantTypeID); err != nil {
		return fmt.Errorf("merchant type %s not found: %w", merchantTypeID, err)
	}
	m := Merchant{
		ID:             id,
		MerchantTypeID: merchantTypeID,
		PIB:            pib,
		Balance:        balance,
		ProductIDs:     []string{},
		ReceiptIDs:     []string{},
		DocType:        "merchant",
	}
	return putState(ctx, merchantKey(id), m)
}

func (s *SmartContract) GetMerchant(ctx contractapi.TransactionContextInterface, id string) (*Merchant, error) {
	return getMerchant(ctx, id)
}

func (s *SmartContract) GetAllMerchants(ctx contractapi.TransactionContextInterface) ([]*Merchant, error) {
	iterator, err := ctx.GetStub().GetStateByRange("MERCHANT_", "MERCHANT_~")
	if err != nil {
		return nil, err
	}
	defer iterator.Close()

	var results []*Merchant
	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		var m Merchant
		if err := json.Unmarshal(kv.Value, &m); err != nil {
			return nil, err
		}
		results = append(results, &m)
	}
	return results, nil
}

func (s *SmartContract) AddProductToMerchant(ctx contractapi.TransactionContextInterface, merchantID, productID string) error {
	if _, err := getMerchant(ctx, merchantID); err != nil {
		return err
	}
	if _, err := getProduct(ctx, productID); err != nil {
		return err
	}
	return addProductToMerchant(ctx, merchantID, productID)
}

func (s *SmartContract) DepositToMerchant(ctx contractapi.TransactionContextInterface, merchantID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("deposit amount must be positive, got %.2f", amount)
	}
	m, err := getMerchant(ctx, merchantID)
	if err != nil {
		return err
	}
	m.Balance += amount
	return putState(ctx, merchantKey(merchantID), m)
}
