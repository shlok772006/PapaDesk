# Smart Business Manager — Database Schema

## 1. Overview
The application uses Firebase Firestore as its database. Firestore is a NoSQL document database, optimized for fast syncing and offline capabilities. The schema is designed around independent collections with atomic increments to manage aggregates (like stock and balances) without requiring live server transactions.

## 2. Collections

### 2.1 `customers`
Stores customer details and their aggregate financial state.
```json
{
  "name": "string",
  "phone": "string",
  "address": "string",
  "totalPurchases": "number", // updated via FieldValue.increment()
  "pendingAmount": "number",  // updated via FieldValue.increment()
  "createdAt": "timestamp"
}
```
*Note: `pendingAmount` and `totalPurchases` are never written directly by the client. They are only updated via atomic increments when a sale or payment is recorded.*

### 2.2 `products`
Stores inventory items and pricing.
```json
{
  "name": "string",
  "category": "string",
  "supplierId": "string",
  "purchasePrice": "number",
  "sellingPrice": "number",
  "currentStock": "number",   // updated via FieldValue.increment()
  "minStock": "number"
}
```

### 2.3 `suppliers`
Stores details of vendors where stock is purchased.
```json
{
  "name": "string",
  "phone": "string"
}
```

### 2.4 `sales`
Records an outbound transaction to a customer.
```json
{
  "customerId": "string",
  "saleDate": "timestamp",
  "items": [
    {
      "productId": "string",
      "productName": "string",
      "quantity": "number",
      "unitPrice": "number",
      "subtotal": "number"
    }
  ],
  "totalAmount": "number",
  "discount": "number",
  "paidAmount": "number",
  "createdBy": "string" // UID of the operator
}
```
*When a `sales` document is created, a batched write simultaneously decrements `products.currentStock` and increments `customers.pendingAmount` and `customers.totalPurchases`.*

### 2.5 `payments`
Records money received from a customer.
```json
{
  "customerId": "string",
  "saleId": "string | null", // optional reference
  "amount": "number",
  "paymentDate": "timestamp",
  "method": "string",
  "createdBy": "string" // UID of the operator
}
```
*When a `payments` document is created, a batched write simultaneously decrements `customers.pendingAmount`.*

### 2.6 `purchases`
Records incoming stock from a supplier.
```json
{
  "supplierId": "string",
  "purchaseDate": "timestamp",
  "items": [
    {
      "productId": "string",
      "quantity": "number",
      "unitCost": "number"
    }
  ],
  "totalCost": "number",
  "createdBy": "string" // UID of the operator
}
```
*When a `purchases` document is created, a batched write simultaneously increments `products.currentStock`.*

## 3. Security Rules Outline
Only the Operator can write data. Admins have read-only access.
```javascript
match /databases/{database}/documents {
  function isOperator() {
    return request.auth.uid == resource.data.createdBy;
  }
  function isAdmin() {
    return request.auth.token.role == 'admin';
  }

  match /{collection}/{docId} {
    allow read: if isOperator() || isAdmin();
    allow write: if isOperator();
  }
}
```
