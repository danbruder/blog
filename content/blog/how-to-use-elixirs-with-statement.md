---
date: 2018-07-25
title: "How to use Elixir's \"with\" statement"
slug: how-to-use-elixirs-with-statement
categories: [Backend]
tags:
  - elixir
---

One of my favorite language constructs of elixir is the pipe operator (|>). It makes really readable code: 

```elixir
defmodule User do
  def set_avatar(args) do
    args
    |> upload_to_s3
    |> create_responsive_sizes
    |> save_to_db
  end
end
```

It's easy to tell by reading the function `set_avatar` what is going on here without needing to see the other functions. 

How do you handle errors in this scenario? There are a few options available: 
1. Store the error in the data structure that is piped and handle it at the end
2. Use an [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html) transaction
3. Use the `with` statement

## With statement
Let's look at the third option: `with`. Consider this example:

```elixir
defmodule User do
  def set_avatar(args) do
    with {:ok, url} <- upload_to_s3(args),
         {:ok, sizes} <- create_responsive_sizes(url),
         {:ok, result} <- save_to_db(sizes) do
      # Return the result
      {:ok, result}
    else
      # Handle specific errors here
      {:error, :network_timeout} ->
        set_avatar(args, retries: 1)

      error ->
        Logger.error("Could not set sizes: #{IO.inspect(error)}")
        {:error, :could_not_set_avatar}
    end
  end
end
```

The `with` statement matches the return of each function. If they all match, the first `do` block is executed: 

```elixir,hl_lines=6-7
defmodule User do
  def set_avatar(args) do
    with {:ok, url} <- upload_to_s3(args),
         {:ok, sizes} <- create_responsive_sizes(url),
         {:ok, result} <- save_to_db(sizes) do
      # Return the result
      {:ok, result}
    else
      # Handle specific errors here
      {:error, :network_timeout} ->
        set_avatar(args, retries: 1)

      error ->
        Logger.error("Could not set sizes: #{IO.inspect(error)}")
        {:error, :could_not_set_avatar}
    end
  end
end
```

If any of the returns do _not_ match, the else block gets executed:

```elixir,hl_lines=9-15
defmodule User do
  def set_avatar(args) do
    with {:ok, url} <- upload_to_s3(args),
         {:ok, sizes} <- create_responsive_sizes(url),
         {:ok, result} <- save_to_db(sizes) do
      # Return the result
      {:ok, result}
    else
      # Handle specific errors here
      {:error, :network_timeout} ->
        set_avatar(args, retries: 1)

      error ->
        Logger.error("Could not set sizes: #{IO.inspect(error)}")
        {:error, :could_not_set_avatar}
    end
  end
end
```

In the else block you can handle specific errors by matching on function returns. Here we handle a `:network_timeout` specifically and any other error generically.

```elixir,hl_lines=9-11
defmodule User do
  def set_avatar(args) do
    with {:ok, url} <- upload_to_s3(args),
         {:ok, sizes} <- create_responsive_sizes(url),
         {:ok, result} <- save_to_db(sizes) do
      # Return the result
      {:ok, result}
    else
      # Handle specific errors here
      {:error, :network_timeout} ->
        set_avatar(args, retries: 1)

      error ->
        Logger.error("Could not set sizes: #{IO.inspect(error)}")
        {:error, :could_not_set_avatar}
    end
  end
end
```

## Using intermediate results
Another helpful feature of the `with` statement is the ability to use results returned by each function in the next. For example, if our `save_to_db` function needed the `url` and `sizes` we could do that with:

```elixir,hl_lines=3-5
defmodule User do
  def set_avatar(args) do
    with {:ok, url} <- upload_to_s3(args),
         {:ok, sizes} <- create_responsive_sizes(url),
         {:ok, result} <- save_to_db(sizes, url) do
      # Return the result
      {:ok, result}
    else
      # Handle specific errors here
      {:error, :network_timeout} ->
        set_avatar(args, retries: 1)

      error ->
        Logger.error("Could not set sizes: #{IO.inspect(error)}")
        {:error, :could_not_set_avatar}
    end
  end
end
```

I have found the `with` statement quite useful as I develop applications with elixir. I hope this example helps!
