---
date: 2018-07-27
title: Running specific tests in Elixir
slug: running-specific-tests-in-elixir
category: Development
tags:
  - elixir
  - tdd
  - testing
---

To run the whole test suite, you can stick to 

```bash
mix test
```

For tests in a single file: 

```bash
mix test test/specific_test.exs
```

For a specific test, append the line number: 

```bash
mix test test/specific_test.exs:22
```