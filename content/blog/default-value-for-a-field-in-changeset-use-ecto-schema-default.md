---
date: 2018-08-10
title: Default value for a field in changeset (use ecto schema default)
slug: default-value-for-a-field-in-changeset-use-ecto-schema-default
category: Backend
tags:
  - elixir
---

Set a default value for an ecto schema like so: 

```elixir
defmodule Track.Time.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "logs" do
    # ... other fields
    field(:billable, :boolean, default: true)
  end
end
```
