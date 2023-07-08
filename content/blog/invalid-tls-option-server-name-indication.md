---
date: 2023-07-08
title: "ssl connect: Invalid TLS option: {server_name_indication:..."
slug: invalid-tls-option-server-name-indication
taxonomies:
  category: [Backend]
  tags:
    - elixir
    - ecto
---

Following this guide from [neon.tech](https://neon.tech/docs/guides/elixir-ecto) on setting up Ecto with Neon I ran into this error:

```bash
09:11:48.565 [error] Postgrex.Protocol (#PID<0.435.0>) failed to connect: ** (DBConnection.ConnectionError) ssl connect: Invalid TLS option: {server_name_indication,
                        <<"[my neon db host].us-east-2.aws.neon.tech">>} - {:options, {:server_name_indication, "[my neon db host].us-east-2.aws.neon.tech"}}
```

This was after using their recommended Ecto configuration:

```elixir
config :friends, Friends.Repo,
  database: "friends",
  username: "<user>",
  password: "<password>",
  hostname: "ep-billowing-sun-767748.us-west-2.aws.neon.tech",
  ssl: true,
  ssl_opts: [
    server_name_indication: 'ep-billowing-sun-767748.us-west-2.aws.neon.tech',
    verify: :verify_none
  ]
```

## Solution

`server_name_indication` is a char list, not a string! The single quotes are important! I had been passing in a string from an environment variable like this:

```elixir
    config :danos, Danos.Repo,
      ssl: true,
      ssl_opts: [
        server_name_indication: System.get_env("DATABASE_HOST"),
        verify: :verify_none
      ],
```

To make it a char list:

```elixir
    config :danos, Danos.Repo,
      ssl: true,
      ssl_opts: [
        server_name_indication: to_char_list(System.get_env("DATABASE_HOST")),
        verify: :verify_none
      ],
```

And voila, it works!
