---
date: 2018-04-04
title: Syntax Checking in Vim for Rust
slug: syntax-checking-in-vim-for-rust
category: Development
tags:
  - vim
  - rust
---

There is a Vim plugin for Rust that supports syntax checking through Syntastic and auto formatting through RustFmt.

There are some issues yet to be resolved. Most notably one that resulted in this vim error:

```
use of unstable library feature 'rustc_private': this crate is being loaded from the sysroot ...
```

but adding the following to `~/.vimrc` got me up and running:

```vim
" Taken from https://github.com/rust-lang/rust.vim/issues/130
let g:syntastic_rust_rustc_exe = 'cargo check'
let g:syntastic_rust_rustc_fname = ''
let g:syntastic_rust_rustc_args = '--'
let g:syntastic_rust_checkers = ['rustc']
```

Support for cargo check seems to be coming soon.

Happy Vimming (and Rusting!)