---
date: 2017-06-29
title: "TypeError: require is not a function (webpack + faunadb)"
slug: typeerror-require-is-not-a-function-webpack-faunadb
categories: [ Serverless ]
tags:
  - faunadb
  - nosql
  - nodejs
---

This error comes up when using faunadb’s driver for nodejs with webpack.

Adding the following to webpack.config.js fixed the issue:

```js
plugins: [
  new webpack.DefinePlugin({ "global.GENTLY": false })
],
node: {
  __dirname: true,
},
alias: {
  'inherits': 'inherits/inherits_browser.js',
  'superagent': 'superagent/lib/client',
  'emitter': 'component-emitter',
},
```
Here’s the issue and fix: [https://github.com/felixge/node-formidable/issues/337#issuecomment-264337905](https://github.com/felixge/node-formidable/issues/337#issuecomment-264337905).
