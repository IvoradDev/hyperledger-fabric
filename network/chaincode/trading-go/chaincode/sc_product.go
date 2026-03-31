package chaincode

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func (s *SmartContract) CreateProduct(ctx contractapi.TransactionContextInterface, id, merchantID, name, expiryDate string, price float64, quantity int) error {
	existing, _ := ctx.GetStub().GetState(productKey(id))
	if existing != nil {
		return fmt.Errorf("product %s already exists", id)
	}
	if _, err := getMerchant(ctx, merchantID); err != nil {
		return fmt.Errorf("merchant %s not found: %w", merchantID, err)
	}
	if price <= 0 {
		return fmt.Errorf("price must be positive, got %.2f", price)
	}
	if quantity < 0 {
		return fmt.Errorf("quantity cannot be negative, got %d", quantity)
	}

	p := Product{
		ID:         id,
		MerchantID: merchantID,
		Name:       name,
		ExpiryDate: expiryDate,
		Price:      price,
		Quantity:   quantity,
		DocType:    "product",
	}
	if err := putState(ctx, productKey(id), p); err != nil {
		return err
	}
	return addProductToMerchant(ctx, merchantID, id)
}

func (s *SmartContract) GetProduct(ctx contractapi.TransactionContextInterface, id string) (*Product, error) {
	return getProduct(ctx, id)
}

func (s *SmartContract) GetAllProducts(ctx contractapi.TransactionContextInterface) ([]*Product, error) {
	iterator, err := ctx.GetStub().GetStateByRange("PRODUCT_", "PRODUCT_~")
	if err != nil {
		return nil, err
	}
	defer iterator.Close()

	var results []*Product
	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		var p Product
		if err := json.Unmarshal(kv.Value, &p); err != nil {
			return nil, err
		}
		results = append(results, &p)
	}
	return results, nil
}

func (s *SmartContract) UpdateProductQuantity(ctx contractapi.TransactionContextInterface, productID string, quantity int) error {
	if quantity < 0 {
		return fmt.Errorf("quantity cannot be negative")
	}
	p, err := getProduct(ctx, productID)
	if err != nil {
		return err
	}
	p.Quantity = quantity
	return putState(ctx, productKey(productID), p)
}
