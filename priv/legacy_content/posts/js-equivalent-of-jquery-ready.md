---
date: 2024-03-23
title: Vanilla JavaScript equivalent of jQuery's $.ready()
slug: js-equivalent-of-jquery-ready
taxonomies: 
    category: [JavaScript]
    tags: []
---

jQuery's `$.ready()` function is used to execute a function when the DOM is fully loaded. The equivalent in vanilla JavaScript is to use the `DOMContentLoaded` event.

```js
document.addEventListener('DOMContentLoaded', function(){ 
    // your code goes here
}, false);
```
