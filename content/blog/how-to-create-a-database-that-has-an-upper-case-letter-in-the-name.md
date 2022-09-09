---
date: 2022-09-09
title: How to create a Database that has an upper-case letter in the name
slug: how-to-create-a-database-that-has-an-upper-case-letter-in-the-name
taxonomies:
  category: []
  tags: []
---

Answer: **Surround the name with quotes!**

Like so:

```psql
psql (14.5, server 12.9)
Type "help" for help.

postgres=# CREATE DATABASE "MyAwesomeDatabase";
CREATE DATABASE
postgres=# \l
                                        List of databases
           Name           |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
--------------------------+----------+----------+------------+------------+-----------------------
 MyAwesomeDatabase        | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres                 | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
(2 rows)
```

If you don't include quotes, you'll create a database with all lowercase letters:

```psql
psql (14.5, server 12.9)
Type "help" for help.

postgres=# CREATE DATABASE MyAwesomeDatabase;
CREATE DATABASE
postgres=# \l
                                        List of databases
           Name           |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
--------------------------+----------+----------+------------+------------+-----------------------
 myawesomedatabase        | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres                 | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
(2 rows)
```
