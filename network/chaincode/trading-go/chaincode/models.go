package chaincode

// key "MERCHANTTYPE_<ID>".
type MerchantType struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	DocType     string `json:"docType"` // always "merchantType" — needed for CouchDB selector queries
}

// key "MERCHANT_<ID>".
type Merchant struct {
	ID             string   `json:"id"`
	MerchantTypeID string   `json:"merchantTypeId"`
	PIB            string   `json:"pib"`
	Balance        float64  `json:"balance"`
	ProductIDs     []string `json:"productIds"`
	ReceiptIDs     []string `json:"receiptIds"`
	DocType        string   `json:"docType"` // always "merchant"
}

// key "PRODUCT_<ID>".
type Product struct {
	ID         string  `json:"id"`
	MerchantID string  `json:"merchantId"`
	Name       string  `json:"name"`
	ExpiryDate string  `json:"expiryDate"` // "YYYY-MM-DD" or "" if N/A
	Price      float64 `json:"price"`
	Quantity   int     `json:"quantity"`
	DocType    string  `json:"docType"` // always "product"
}

// key "USER_<ID>".
type User struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Surname    string   `json:"surname"`
	Email      string   `json:"email"`
	Balance    float64  `json:"balance"`
	ReceiptIDs []string `json:"receiptIds"`
	DocType    string   `json:"docType"` // always "user"
}

// key "RECEIPT_<ID>".
type Receipt struct {
	ID         string  `json:"id"`
	MerchantID string  `json:"merchantId"`
	UserID     string  `json:"userId"`
	ProductID  string  `json:"productId"`
	Amount     float64 `json:"amount"` // price at time of purchase
	Date       string  `json:"date"`   // "YYYY-MM-DD"
	DocType    string  `json:"docType"` // always "receipt"
}
