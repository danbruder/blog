---
date: 2018-07-19
title: Using Tachyons is a huge productivity boost
slug: using-tachyons-is-a-huge-productivity-boost
category: Frontend
tags:
  - css
---

I come from the dark days of CSS when browser support was so-so and you had to have fallbacks for your fallbacks for good ol' IE9. 

_\*cringe\*_

## SASS is nice
When I discovered SASS, it was a breath of fresh air. There were abstractions in place so that you could use fancy features without breaking cross-browser styles _and_ without adding every vendor-prefix under the sun. It also handled nesting and variables. _Awesome_.

For the most part SASS has been great - _but_ - I still found my typical application development cycles taking longer than I wanted. They went something like this:

1. Add some html
2. Come up with good class names
3. Jump to my style sheet file
4. Add styles

This was a reasonable workflow but I kept running into a couple of problems:

1. A lot of one-off classes that didn't fit into the 'reusable' category
2. Inconsistent values for all the number-bound things: widths, heights, padding, margin, line-height, etc.

I know there are systems out there that are meant to help these issues - and I've used some of them - but I never quite shook these issues off. 

## CSS-in-JS is nice
There are certainly benefits to [styled-components](https://www.styled-components.com/) and other CSS-in-JS libs. The biggest one seems to be modularity and re-use scoped to a component. I've used styled components for a couple of projects with an overall positive response, but it still felt slower than it could be.

## Then... Tachyons
Somehow I stumbled on Tachyons and by extension, "functional CSS". 

Functional CSS focuses on style classes that have a single responsibility that can be composed. 

For example:

```css
.w1{
  width: 10px; /* Not actual Tachyons values */
}
.w2{
  width: 30px;
}
```

This helps in a number of ways:

1. Nimble-ness: no more classes with a ton of properties that are difficult to override
2. No context switching: once you get the gist of the short names, you can write them on the fly without leaving your application code. 
3. Easy-peasy refactoring: the single-responsibility classes are easy to mix and match and rearrange. 

### Sizing and Rhythm
Tachyons does a great job of providing a small number of good options for sizing. 

For example, you get 5 choices for width: `w1, w2, w3, w4, w5`. This frees up mental space that was otherwise occupied by pixel count or SASS variables. I know if I'm specifying width, it's going to be between w1 and w5 and that w5 is bigger. 

Does this produce pixel perfect replicas of the design? Maybe not, but for most spacing cases, it is close enough. When an element needs to be perfect, you can always add additional styles to get it just right.

### Responsive design
Tachyons ships with some modifiers for each class: 
1. `-ns`: Not small
2. `-m`: Medium
3. `-l`: Large

By adding these modifiers to your classes, you can limit the class application to the screens you care about.

An example I use a lot:

```html
<div className="pa3 pa5-ns">
  Some Stuff
</div>
```

The div has level 3 padding on small screens and level 5 on non-small screens. With a couple of keystrokes I have added responsive behavior to this element. Very nice!

## Happy Styling Again
I have built a number of applications with Tachyons ([this site included!](https://github.com/danbruder/blog)). I have found I'm able to move much faster. Not only that I have been happier with the result - both the look and maintainability.

And since **shipping is all that matters™**, I've found a new style-y partner for the foreseeable future.

P.S. Go check out Tachyons for yourself [here](http://tachyons.io/).
