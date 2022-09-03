---
date: 2019-02-17
title: Store JSON blob in Postgres with Diesel
slug: store-json-blob-in-postgres-with-diesel
taxonomies:
    category: [Backend]
    tags:
      - rust
---

Use the `jsonb` type in your migration:  

```sql
ALTER TABLE orders
ADD COLUMN meta_data jsonb;
```


The generated schema uses `Jsonb`: 

```rust

// Diesel schema definition
table! {
    orders (id) {
        id -> Int4,
        // ... other fields
        // uses Jsonb type
        meta_data -> Nullable<Jsonb>,
    }
}
```

Then you can store anything that `serde` can serialize as a JSON blob: 

```rust
#[derive(Serialize, Identifiable, Clone, Queryable, Debug)]
#[table_name = "orders"]
pub struct Order {
    pub id: i32,
    // ... other fields
    pub meta_data: Option<serde_json::Value>,
}

#[derive(Insertable)]
#[table_name = "orders"]
pub struct NewOrder {
  // ... other fields
  pub meta_data: Option<serde_json::Value>
}

#[derive(Serialize)]
pub struct MetaData { 
  pub avatar: String, 
  pub coupon_code: String
}

let meta_data = MetaData { 
  avatar: "https://someplace.com/12345/avatar.png".to_string(),
  coupon_code: "123COUPON".to_string()
}

let order = &NewOrder{
  meta_data: Some(serde_json::to_value(meta_data)?)
}

// Insert order with serialized Json
diesel::insert_into(orders::table)
  .values(order)
  .get_result::<Order>(&conn)?;
```
