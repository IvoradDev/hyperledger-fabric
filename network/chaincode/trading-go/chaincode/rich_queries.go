package chaincode

import (
	"encoding/json"
	"fmt"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func executeQuery(ctx contractapi.TransactionContextInterface, queryString string) ([][]byte, error) {
	iterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, fmt.Errorf("failed to execute query: %w", err)
	}
	defer iterator.Close()

	var results [][]byte
	for iterator.HasNext() {
		kv, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		results = append(results, kv.Value)
	}
	return results, nil
}

func (s *SmartContract) SearchProductsByName(ctx contractapi.TransactionContextInterface, name string) ([]*Product, error) {
	query := fmt.Sprintf(`{
		"selector": {
			"docType": "product",
			"name": {"$regex": "(?i)%s"}
		}
	}`, name)

	rows, err := executeQuery(ctx, query)
	if err != nil {
		return nil, err
	}
	var results []*Product
	for _, row := range rows {
		var p Product
		if err := json.Unmarshal(row, &p); err != nil {
			return nil, err
		}
		results = append(results, &p)
	}
	return results, nil
}

func (s *SmartContract) SearchProductsByMerchantType(ctx contractapi.TransactionContextInterface, merchantTypeID string) ([]*Product, error) {
	merchantQuery := fmt.Sprintf(`{
		"selector": {
			"docType": "merchant",
			"merchantTypeId": "%s"
		},
		"fields": ["id"]
	}`, merchantTypeID)

	merchantRows, err := executeQuery(ctx, merchantQuery)
	if err != nil {
		return nil, err
	}
	if len(merchantRows) == 0 {
		return []*Product{}, nil
	}

	merchantIDs := make([]string, 0, len(merchantRows))
	for _, row := range merchantRows {
		var m struct{ ID string `json:"id"` }
		if err := json.Unmarshal(row, &m); err != nil {
			return nil, err
		}
		merchantIDs = append(merchantIDs, fmt.Sprintf(`"%s"`, m.ID))
	}

	inClause := "["
	for i, id := range merchantIDs {
		if i > 0 {
			inClause += ","
		}
		inClause += id
	}
	inClause += "]"

	productQuery := fmt.Sprintf(`{
		"selector": {
			"docType": "product",
			"merchantId": {"$in": %s}
		}
	}`, inClause)

	rows, err := executeQuery(ctx, productQuery)
	if err != nil {
		return nil, err
	}
	var results []*Product
	for _, row := range rows {
		var p Product
		if err := json.Unmarshal(row, &p); err != nil {
			return nil, err
		}
		results = append(results, &p)
	}
	return results, nil
}

func (s *SmartContract) SearchProductsByPriceRange(ctx contractapi.TransactionContextInterface, minPrice, maxPrice float64) ([]*Product, error) {
	if minPrice > maxPrice {
		return nil, fmt.Errorf("minPrice (%.2f) must be <= maxPrice (%.2f)", minPrice, maxPrice)
	}
	query := fmt.Sprintf(`{
		"selector": {
			"docType": "product",
			"price": {
				"$gte": %f,
				"$lte": %f
			}
		}
	}`, minPrice, maxPrice)

	rows, err := executeQuery(ctx, query)
	if err != nil {
		return nil, err
	}
	var results []*Product
	for _, row := range rows {
		var p Product
		if err := json.Unmarshal(row, &p); err != nil {
			return nil, err
		}
		results = append(results, &p)
	}
	return results, nil
}

func (s *SmartContract) SearchProducts(ctx contractapi.TransactionContextInterface, name, merchantTypeID string, minPrice, maxPrice float64) ([]*Product, error) {
	selector := `{"docType": "product"`

	if name != "" {
		selector += fmt.Sprintf(`, "name": {"$regex": "(?i)%s"}`, name)
	}
	if merchantTypeID != "" {
		merchantQuery := fmt.Sprintf(`{"selector": {"docType": "merchant", "merchantTypeId": "%s"}, "fields": ["id"]}`, merchantTypeID)
		merchantRows, err := executeQuery(ctx, merchantQuery)
		if err != nil {
			return nil, err
		}
		if len(merchantRows) == 0 {
			return []*Product{}, nil
		}
		inClause := "["
		for i, row := range merchantRows {
			var m struct{ ID string `json:"id"` }
			if err := json.Unmarshal(row, &m); err != nil {
				return nil, err
			}
			if i > 0 {
				inClause += ","
			}
			inClause += fmt.Sprintf(`"%s"`, m.ID)
		}
		inClause += "]"
		selector += fmt.Sprintf(`, "merchantId": {"$in": %s}`, inClause)
	}
	if minPrice > 0 || maxPrice > 0 {
		priceClause := "{"
		if minPrice > 0 {
			priceClause += fmt.Sprintf(`"$gte": %f`, minPrice)
		}
		if maxPrice > 0 {
			if minPrice > 0 {
				priceClause += ","
			}
			priceClause += fmt.Sprintf(`"$lte": %f`, maxPrice)
		}
		priceClause += "}"
		selector += fmt.Sprintf(`, "price": %s`, priceClause)
	}

	selector += "}"
	query := fmt.Sprintf(`{"selector": %s}`, selector)

	rows, err := executeQuery(ctx, query)
	if err != nil {
		return nil, err
	}
	var results []*Product
	for _, row := range rows {
		var p Product
		if err := json.Unmarshal(row, &p); err != nil {
			return nil, err
		}
		results = append(results, &p)
	}
	return results, nil
}

func (s *SmartContract) GetMerchantsByType(ctx contractapi.TransactionContextInterface, merchantTypeID string) ([]*Merchant, error) {
	query := fmt.Sprintf(`{
		"selector": {
			"docType": "merchant",
			"merchantTypeId": "%s"
		}
	}`, merchantTypeID)

	rows, err := executeQuery(ctx, query)
	if err != nil {
		return nil, err
	}
	var results []*Merchant
	for _, row := range rows {
		var m Merchant
		if err := json.Unmarshal(row, &m); err != nil {
			return nil, err
		}
		results = append(results, &m)
	}
	return results, nil
}

func (s *SmartContract) GetRichMerchantsWithProducts(ctx contractapi.TransactionContextInterface) ([]map[string]interface{}, error) {
	merchants, err := s.GetAllMerchants(ctx)
	if err != nil {
		return nil, err
	}

	var results []map[string]interface{}
	for _, m := range merchants {
		var products []*Product
		for _, pid := range m.ProductIDs {
			p, err := getProduct(ctx, pid)
			if err != nil {
				continue
			}
			products = append(products, p)
		}
		entry := map[string]interface{}{
			"merchant": m,
			"products": products,
		}
		results = append(results, entry)
	}
	return results, nil
}

func (s *SmartContract) SearchUsersBySurname(ctx contractapi.TransactionContextInterface, surname string) ([]*User, error) {
	query := fmt.Sprintf(`{
		"selector": {
			"docType": "user",
			"surname": {"$regex": "(?i)%s"}
		}
	}`, surname)

	rows, err := executeQuery(ctx, query)
	if err != nil {
		return nil, err
	}
	var results []*User
	for _, row := range rows {
		var u User
		if err := json.Unmarshal(row, &u); err != nil {
			return nil, err
		}
		results = append(results, &u)
	}
	return results, nil
}

func (s *SmartContract) GetUsersWithBalanceAbove(ctx contractapi.TransactionContextInterface, threshold float64) ([]*User, error) {
	query := fmt.Sprintf(`{
		"selector": {
			"docType": "user",
			"balance": {"$gt": %f}
		}
	}`, threshold)

	rows, err := executeQuery(ctx, query)
	if err != nil {
		return nil, err
	}
	var results []*User
	for _, row := range rows {
		var u User
		if err := json.Unmarshal(row, &u); err != nil {
			return nil, err
		}
		results = append(results, &u)
	}
	return results, nil
}
