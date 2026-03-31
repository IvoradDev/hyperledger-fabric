package chaincode

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct {
	contractapi.Contract
}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {

	merchantTypes := []MerchantType{
		{ID: "MT1", Name: "Supermarket", Description: "Sells food and household goods", DocType: "merchantType"},
		{ID: "MT2", Name: "Electronics", Description: "Sells electronic devices and accessories", DocType: "merchantType"},
		{ID: "MT3", Name: "AutoParts", Description: "Sells car parts and accessories", DocType: "merchantType"},
	}
	for _, mt := range merchantTypes {
		if err := putState(ctx, merchantTypeKey(mt.ID), mt); err != nil {
			return err
		}
	}

	merchants := []Merchant{
		{
			ID: "M1", MerchantTypeID: "MT1", PIB: "111111111",
			Balance: 5000.00, ProductIDs: []string{}, ReceiptIDs: []string{},
			DocType: "merchant",
		},
		{
			ID: "M2", MerchantTypeID: "MT2", PIB: "222222222",
			Balance: 8000.00, ProductIDs: []string{}, ReceiptIDs: []string{},
			DocType: "merchant",
		},
		{
			ID: "M3", MerchantTypeID: "MT3", PIB: "333333333",
			Balance: 3000.00, ProductIDs: []string{}, ReceiptIDs: []string{},
			DocType: "merchant",
		},
	}
	for _, m := range merchants {
		if err := putState(ctx, merchantKey(m.ID), m); err != nil {
			return err
		}
	}

	products := []Product{
		{ID: "P1", MerchantID: "M1", Name: "Milk", ExpiryDate: "2026-06-01", Price: 1.20, Quantity: 100, DocType: "product"},
		{ID: "P2", MerchantID: "M1", Name: "Bread", ExpiryDate: "2026-04-05", Price: 0.90, Quantity: 50, DocType: "product"},
		{ID: "P3", MerchantID: "M2", Name: "Laptop", ExpiryDate: "", Price: 999.99, Quantity: 10, DocType: "product"},
		{ID: "P4", MerchantID: "M2", Name: "USB Cable", ExpiryDate: "", Price: 5.50, Quantity: 200, DocType: "product"},
		{ID: "P5", MerchantID: "M3", Name: "Brake Pads", ExpiryDate: "", Price: 45.00, Quantity: 30, DocType: "product"},
		{ID: "P6", MerchantID: "M3", Name: "Engine Oil", ExpiryDate: "2028-01-01", Price: 22.00, Quantity: 60, DocType: "product"},
	}
	for _, p := range products {
		if err := putState(ctx, productKey(p.ID), p); err != nil {
			return err
		}
		if err := addProductToMerchant(ctx, p.MerchantID, p.ID); err != nil {
			return err
		}
	}

	users := []User{
		{ID: "U1", Name: "Marko", Surname: "Markovic", Email: "marko@example.com", Balance: 500.00, ReceiptIDs: []string{}, DocType: "user"},
		{ID: "U2", Name: "Ana", Surname: "Anic", Email: "ana@example.com", Balance: 1200.00, ReceiptIDs: []string{}, DocType: "user"},
		{ID: "U3", Name: "Nikola", Surname: "Nikolic", Email: "nikola@example.com", Balance: 200.00, ReceiptIDs: []string{}, DocType: "user"},
		{ID: "U4", Name: "Jelena", Surname: "Jelic", Email: "jelena@example.com", Balance: 750.00, ReceiptIDs: []string{}, DocType: "user"},
	}
	for _, u := range users {
		if err := putState(ctx, userKey(u.ID), u); err != nil {
			return err
		}
	}

	return nil
}

func merchantTypeKey(id string) string { return "MERCHANTTYPE_" + id }
func merchantKey(id string) string     { return "MERCHANT_" + id }
func productKey(id string) string      { return "PRODUCT_" + id }
func userKey(id string) string         { return "USER_" + id }
func receiptKey(id string) string      { return "RECEIPT_" + id }

func putState(ctx contractapi.TransactionContextInterface, key string, v interface{}) error {
	bytes, err := json.Marshal(v)
	if err != nil {
		return fmt.Errorf("failed to marshal %s: %w", key, err)
	}
	return ctx.GetStub().PutState(key, bytes)
}

func getState(ctx contractapi.TransactionContextInterface, key string) ([]byte, error) {
	bytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("failed to read key %s: %w", key, err)
	}
	if bytes == nil {
		return nil, fmt.Errorf("key %s does not exist", key)
	}
	return bytes, nil
}

func addProductToMerchant(ctx contractapi.TransactionContextInterface, merchantID, productID string) error {
	m, err := getMerchant(ctx, merchantID)
	if err != nil {
		return err
	}
	m.ProductIDs = append(m.ProductIDs, productID)
	return putState(ctx, merchantKey(merchantID), m)
}

func getMerchant(ctx contractapi.TransactionContextInterface, id string) (*Merchant, error) {
	bytes, err := getState(ctx, merchantKey(id))
	if err != nil {
		return nil, err
	}
	var m Merchant
	if err := json.Unmarshal(bytes, &m); err != nil {
		return nil, fmt.Errorf("failed to unmarshal merchant %s: %w", id, err)
	}
	return &m, nil
}

func getUser(ctx contractapi.TransactionContextInterface, id string) (*User, error) {
	bytes, err := getState(ctx, userKey(id))
	if err != nil {
		return nil, err
	}
	var u User
	if err := json.Unmarshal(bytes, &u); err != nil {
		return nil, fmt.Errorf("failed to unmarshal user %s: %w", id, err)
	}
	return &u, nil
}

func getProduct(ctx contractapi.TransactionContextInterface, id string) (*Product, error) {
	bytes, err := getState(ctx, productKey(id))
	if err != nil {
		return nil, err
	}
	var p Product
	if err := json.Unmarshal(bytes, &p); err != nil {
		return nil, fmt.Errorf("failed to unmarshal product %s: %w", id, err)
	}
	return &p, nil
}
