---
date: 2018-07-21
title: "[SOLVED]: ERROR 22001 (string_data_right_truncation): value too long for type character varying(255)"
slug: error-22001-string_data_right_truncation-value-too-long-for-type-character
categories: [ Backend ]
tags:
  - elixir
  - ecto
---

```elixir
ERROR 22001 (string_data_right_truncation): value too long for type character varying(255)
```

This is an ecto error that occurs when trying to put more than 255 characters into a field that has an ecto type of `:string`. 

To solve this be sure that your migration for the field is of type `:text`:

```elixir
  def change do
    create table(:photos) do
      add :url, :text
      add :caption, :text

      timestamps()
    end
  end
```
