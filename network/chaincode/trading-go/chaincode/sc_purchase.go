package chaincode

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func (s *SmartContract) PurchaseProduct(ctx contractapi.TransactionContextInterface, receiptID, userID, merchantID, productID string) (*Receipt, error) {

	u, err := getUser(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	m, err := getMerchant(ctx, merchantID)
	if err != nil {
		return nil, fmt.Errorf("merchant not found: %w", err)
	}
	p, err := getProduct(ctx, productID)
	if err != nil {
		return nil, fmt.Errorf("product not found: %w", err)
	}

	if p.MerchantID != merchantID {
		return nil, fmt.Errorf("product %s does not belong to merchant %s", productID, merchantID)
	}
	if p.Quantity <= 0 {
		return nil, fmt.Errorf("product %s is out of stock", productID)
	}
	if u.Balance < p.Price {
		return nil, fmt.Errorf("insufficient balance: user %s has %.2f but product costs %.2f", userID, u.Balance, p.Price)
	}

	existing, _ := ctx.GetStub().GetState(receiptKey(receiptID))
	if existing != nil {
		return nil, fmt.Errorf("receipt %s already exists", receiptID)
	}

	u.Balance -= p.Price
	m.Balance += p.Price

	p.Quantity--
	if p.Quantity == 0 {
		m.ProductIDs = removeFromSlice(m.ProductIDs, productID)
	}

	receipt := Receipt{
		ID:         receiptID,
		MerchantID: merchantID,
		UserID:     userID,
		ProductID:  productID,
		Amount:     p.Price,
		Date:       time.Now().Format("2006-01-02"),
		DocType:    "receipt",
	}

	u.ReceiptIDs = append(u.ReceiptIDs, receiptID)
	m.ReceiptIDs = append(m.ReceiptIDs, receiptID)

	if err := putState(ctx, receiptKey(receiptID), receipt); err != nil {
		return nil, err
	}
	if err := putState(ctx, userKey(userID), u); err != nil {
		return nil, err
	}
	if err := putState(ctx, merchantKey(merchantID), m); err != nil {
		return nil, err
	}
	if err := putState(ctx, productKey(productID), p); err != nil {
		return nil, err
	}

	return &receipt, nil
}

func (s *SmartContract) GetReceipt(ctx contractapi.TransactionContextInterface, id string) (*Receipt, error) {
	bytes, err := getState(ctx, receiptKey(id))
	if err != nil {
		return nil, err
	}
	var r Receipt
	if err := json.Unmarshal(bytes, &r); err != nil {
		return nil, fmt.Errorf("failed to unmarshal receipt: %w", err)
	}
	return &r, nil
}

func (s *SmartContract) GetMerchantReceipts(ctx contractapi.TransactionContextInterface, merchantID string) ([]*Receipt, error) {
	m, err := getMerchant(ctx, merchantID)
	if err != nil {
		return nil, err
	}
	var receipts []*Receipt
	for _, rid := range m.ReceiptIDs {
		bytes, err := getState(ctx, receiptKey(rid))
		if err != nil {
			return nil, err
		}
		var r Receipt
		if err := json.Unmarshal(bytes, &r); err != nil {
			return nil, fmt.Errorf("failed to unmarshal receipt %s: %w", rid, err)
		}
		receipts = append(receipts, &r)
	}
	return receipts, nil
}

func removeFromSlice(s []string, val string) []string {
	for i, v := range s {
		if v == val {
			return append(s[:i], s[i+1:]...)
		}
	}
	return s
}
