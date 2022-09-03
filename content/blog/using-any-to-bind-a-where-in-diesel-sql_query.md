---
date: 2020-01-24
title: Using ANY to bind a WHERE IN Diesel sql_query
slug: using-any-to-bind-a-where-in-diesel-sql-query
aliases: [/blog/using-any-to-bind-a-where-in-diesel-sql_query]
taxonomies: 
  category: [Backend]
  tags: [rust]
---

Say you have a query that you want to run in diesel that selects records using `WHERE IN`:

```sql
SELECT id, name from user
WHERE user.id IN (1, 2, 3)
```

Also, lets assume the query is more complex and needs to use `sql_query` instead of diesel's dsl. 

How do you bind the ids? By using `ANY`: 

```sql
SELECT id, name from user
WHERE user.id = ANY($1)
```

Then you can use `sql_query` from diesel: 
```rust
#[derive(QueryableByName)]
stuct User {
  #[sql_type="Integer"]
  id: i32,
  #[sql_type="Text"]
  name: String
}

let my_ids = vec![1, 2, 3];

let results = diesel::sql_query(include_str!("./myquery.sql"))
  .bind::<Array<Integer>, _>(my_ids)
  .get_results::<User>()
  .unwrap();
```
