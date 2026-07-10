---
date: 2019-07-08
title: "Elm Compiler \"Map.!: given key is not an element in the map\""
slug: elm-compiler-map-given-key-is-not-an-element-in-the-map
taxonomies: 
    category: [Tips]
    tags: []
---

There's an issue with the Elm compiler documented [here](https://github.com/elm/compiler/issues/1851) that results in the error message: 

```bash
Map.!: given key is not an element in the map
```

Though it is not resolved, there are a few things you can do to get around it for now:

1. Don't use `Array` in a custom type (use `List` instead)
2. Try removing `elm-stuff` and recompile
3. Compile without the `--debug` flag

Using `Array` in a custom type was what led me to the error, and substituting for `List` made it go away. 

Looking forward to updating this post when the issue is resolved!
