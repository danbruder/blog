---
date: 2020-11-28
title: How to return a warp filter from a function in rust
slug: how-to-return-a-warp-filter-from-a-function-in-rust
taxonomies: 
    category: 
      - Backend
    tags:
      - rust
---

To test a warp app, you provide your `Filter` to a mock server which you can then make requests against and assert responses. 

I wanted to build up my app's `Filter` and bootstrap a test server for it but all the examples show creating a filter and immediately passing it to the real server. 

When I broke filter creation out into its own function I had to do some digging to figure out the return type. The concrete type for the filter you create is based on the routes of your api. It would be cumbersome to write out the actual type.

We can use `-> impl Trait` to specify that the return type needs to implement the Filter trait without naming the type exactly! 

To return a filter from a function, you can use this as the return type: 

```rust
impl Filter<Extract = impl Reply> + Clone
```

Here is warp's README example with the filter broken into its own function:

```rust
use warp::{Filter, Reply};

#[tokio::main]
async fn main() {
    // GET /hello/warp => 200 OK with body "Hello, warp!"
    let hello = get_filter();
    warp::serve(hello).run(([127, 0, 0, 1], 3030)).await;
}

fn get_filter() -> impl Filter<Extract = impl Reply> + Clone {
    warp::path!("hello" / String).map(|name| format!("Hello, {}!", name))
}
```
