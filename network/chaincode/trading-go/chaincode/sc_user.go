package chaincode

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func (s *SmartContract) CreateUser(ctx contractapi.TransactionContextInterface, id, name, surname, email string, balance float64) error {
	existing, _ := ctx.GetStub().GetState(userKey(id))
	if existing != nil {
		return fmt.Errorf("user %s already exists", id)
	}
	if balance < 0 {
		return fmt.Errorf("initial balance cannot be negative")
	}
	u := User{
		ID:         id,
		Name:       name,
		Surname:    surname,
		Email:      email,
		Balance:    balance,
		ReceiptIDs: []string{},
		DocType:    "user",
	}
	return putState(ctx, userKey(id), u)
}

func (s *SmartContract) GetUser(ctx contractapi.TransactionContextInterface, id string) (*User, error) {
	return getUser(ctx, id)
}

func (s *SmartContract) GetAllUsers(ctx contractapi.TransactionContextInterface) ([]*User, error) {
	iterator, err := ctx.GetStub().GetStateByRange("USER_", "USER_~")
	if err != nil {
		return nil, err
	}
	defer iterator.Close()

	var results []*User
	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		var u User
		if err := json.Unmarshal(kv.Value, &u); err != nil {
			return nil, err
		}
		results = append(results, &u)
	}
	return results, nil
}

func (s *SmartContract) DepositToUser(ctx contractapi.TransactionContextInterface, userID string, amount float64) error {
	if amount <= 0 {
		return fmt.Errorf("deposit amount must be positive, got %.2f", amount)
	}
	u, err := getUser(ctx, userID)
	if err != nil {
		return err
	}
	u.Balance += amount
	return putState(ctx, userKey(userID), u)
}

func (s *SmartContract) GetUserReceipts(ctx contractapi.TransactionContextInterface, userID string) ([]*Receipt, error) {
	u, err := getUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	var receipts []*Receipt
	for _, rid := range u.ReceiptIDs {
		bytes, err := getState(ctx, receiptKey(rid))
		if err != nil {
			return nil, err
		}
		var r Receipt
		if err := json.Unmarshal(bytes, &r); err != nil {
			return nil, err
		}
		receipts = append(receipts, &r)
	}
	return receipts, nil
}
