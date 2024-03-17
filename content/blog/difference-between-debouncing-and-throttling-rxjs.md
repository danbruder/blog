---
date: 2024-03-17
title: What's the difference between debouncing and throttling in RxJS?
slug: difference-between-debouncing-and-throttling-rxjs
taxonomies: 
    category: 
      - Development
    tags:
      - rxjs
---

Debouncing and throttling are two different techniques to control the frequency of events. They are often used in user interface programming to limit the number of events that are processed.

Debouncing is a technique to delay the processing of an event until a certain amount of time has passed since the last event. This is useful when you want to wait for a user to stop typing before performing an action, such as searching for a term in a search box.

Throttling, on the other hand, is a technique to ensure that events are not processed more frequently than a certain amount of time. This is useful when you want to limit the rate at which a user can perform an action, such as scrolling through a list of items.

## Examples

Here's an example of debouncing in RxJS:

```typescript
import { fromEvent } from 'rxjs';

const input = document.getElementById('search-box');

fromEvent(input, 'input')
  .pipe(
    debounceTime(300)
  )
  .subscribe(() => {
    // Perform search
  });
```

In this example, the `debounceTime` operator is used to delay the processing of the `input` event until 300 milliseconds have passed since the last event.


Here's an example of throttling in RxJS:

```typescript

import { fromEvent } from 'rxjs';

const button = document.getElementById('scroll-button');

fromEvent(button, 'click')
  .pipe(
    throttleTime(1000)
  )
  .subscribe(() => {
    // Scroll to next page
  });
```

In this example, the `throttleTime` operator is used to ensure that the `click` event is not processed more frequently than once every 1000 milliseconds.
```

## Conclusion

Debouncing and throttling are two different techniques to control the frequency of events. Debouncing is used to delay the processing of events until a certain amount of time has passed since the last event, while throttling is used to ensure that events are not processed more frequently than a certain amount of time.
