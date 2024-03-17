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

`Debouncing` and `throttling` are two different techniques to control the frequency of events. They are often used when building UIs to limit the number of events that are processed.

**Debouncing** is a technique to delay the processing of an event until a certain amount of time has passed since the last event. This is useful when you want to wait for a user to stop typing before performing an action, like searching for a term in a search box.

**Throttling**, on the other hand, is a technique to make sure that events are not processed more frequently than a certain amount of time. This is useful when you want to limit the rate at which a user can perform an action, like scrolling through a list of items.

# Debouncing

The term "debouncing" comes from the analogy of a mechanical switch. When a switch is pressed, it can bounce back and forth between the on and off positions several times before settling into the final state. Debouncing is the process of waiting for the switch to settle into its final state before taking any action.

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

# Throttling

The term "throttling" comes from the analogy of a car engine. When you throttle the engine, you limit the amount of fuel that is delivered to the engine, which in turn limits the speed at which the car can go. Throttling is the process of limiting the rate at which events are processed.

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

In this example, the `throttleTime` operator is used to make sure that the `click` event is not processed more frequently than once every 1000 milliseconds.

# Conclusion

Debouncing and throttling are two different techniques to control the frequency of events. Debouncing is used to delay the processing of events until a certain amount of time has passed since the last event, while throttling is used to make sure that events are not processed more frequently than a certain amount of time.
