---
date: 2019-08-30
title: Rust Enums as Constructors
slug: rust-enums-as-constructors
categories: [Backend]
tags:
  - rust
---

In my previous post, [Pattern Matching Multiple Variants in Rust](/blog/pattern-matching-multiple-variants-in-rust), I talked about matching against multiple enums variants for a single branch. 

Another handy `enum` feature in Rust is using the variants as a constructor. 

For example,

```rust
#[derive(Debug)]
enum Avatar {
  Uploaded(String),
  NotUploaded,
  Hidden
}

let my_avatar = Avatar::Uploaded("https://avatar.com/123.jpg".to_owned());
let hidden_avatar = Avatar::Hidden;

dbg!(my_avatar);
dbg!(hidden_avatar);
```

Say you have a bunch of uploaded `Avatar`s to process, but first you want them to be wrapped in the `Uploaded` variant. You can map them:

```rust
#[allow(dead_code)]

#[derive(Debug)]
enum Avatar {
    Uploaded(String),
    NotUploaded,
    Hidden,
}

fn main() {
    let avatars_to_process = vec![
        "https://avatar.com/some_avatar1.jpg",
        "https://avatar.com/some_avatar2.jpg",
        "https://avatar.com/some_avatar3.jpg",
    ];

    let uploaded_avatars_to_process = avatars_to_process
        .into_iter()
        .map(Into::into) // &str to String
        .map(Avatar::Uploaded)
        .collect::<Vec<Avatar>>();

    println!("Ready to process:");
    uploaded_avatars_to_process.into_iter().for_each(|a| println!("{:?}", a));
}
```

```bash
$ cargo run
Ready to process:
Uploaded("https://avatar.com/some_avatar1.jpg")
Uploaded("https://avatar.com/some_avatar2.jpg")
Uploaded("https://avatar.com/some_avatar3.jpg")
```

Here's the [full example](https://play.rust-lang.org/?version=stable&mode=debug&edition=2018&gist=270cf326a77f42412ac6fd313d998fab). 
