---
date: 2024-03-10
title: What is a CTE in Postgres? 
slug: what-is-cte-in-postgres
taxonomies: 
    category: [Development]
    tags:
      - postgres
---

A common table expression (`CTE`) is a temporary result set that you can reference within a `SELECT`, `INSERT`, `UPDATE`, or `DELETE` statement.

CTEs are defined using the WITH keyword, and they are useful for creating recursive queries, or for breaking down complex queries into simpler, more manageable parts.

## Example

```sql
WITH cte AS (
  SELECT * FROM users WHERE age > 18
)
SELECT * FROM cte;
```

In this example, we define a CTE called `cte` that contains all the users with an age greater than 18. We then reference the `cte` in the `SELECT` statement to retrieve the results.

CTEs can also be used to create recursive queries, which can be useful for working with hierarchical data, such as organizational charts or bill of materials.

```sql
WITH RECURSIVE cte AS (
  SELECT id, name, manager_id FROM employees WHERE id = 1
  UNION ALL
  SELECT e.id, e.name, e.manager_id FROM employees e
  JOIN cte ON e.manager_id = cte.id
)

SELECT * FROM cte;
```

In this example, we use a CTE to retrieve all the employees in an organization that report to a given manager, including indirect reports. We define a recursive CTE called `cte` that starts with the employee with id 1, and then recursively retrieves all the employees that report to that employee, and so on.

CTEs are a powerful feature of Postgres that can help you write more readable and maintainable queries, especially for complex or recursive queries.
