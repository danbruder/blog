---
date: 2019-08-16
title: Pattern Matching Multiple Variants in Rust
slug: pattern-matching-multiple-variants-in-rust
categories: [Backend]
tags:
  - rust
---

One of my favorite features of Rust is the `enum` data type and the pattern matching capabilities of `match`. It allows me to be sure that I have covered every case and if not, the compiler will let me know. 

For example,

```rust
use TrafficLightColor::*;

enum TrafficLightColor {
    Red,
    Yellow,
    Green
}

fn main() {
  println!("Can I go?");
  
  let current_light_color = Red;
  match current_light_color {
      Red => println!("No!"),
      Green => println!("Yes!"),
      Yellow => println!("Yes!"),
  };
}
```

```bash
$ cargo run
Can I go? 
No!
```

But what if I need to do the same thing for two variants? Rust allows you to match on multiple variants with the `|` operator. 

```rust
use TrafficLightColor::*;

enum TrafficLightColor {
    Red,
    Yellow,
    Green
}

fn main() {
  println!("Can I go?");
  
  let current_light_color = TrafficLightColor::Yellow;
  match current_light_color {
      Red => println!("No!"),
      Green | Yellow => println!("Yes!"),
  };
}
```

```bash
$ cargo run
Can I go?
Yes!
```

Here's a [REPL](https://repl.it/@danbruder/Enums) demonstrating this.
