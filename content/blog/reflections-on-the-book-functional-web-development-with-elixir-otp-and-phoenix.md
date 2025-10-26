---
date: 2018-07-23
title: "Reflections on the book Functional Web Development with Elixir, OTP, and Phoenix"
slug: reflections-on-the-book-functional-web-development-with-elixir-otp-and-phoenix
categories: [Books]
tags:
  - elixir
  - functional
  - architecture
---

> _TLDR: Its a great book and you should buy it. **Seriously**. Stop reading this and go [buy it right now](https://pragprog.com/book/lhelph/functional-web-development-with-elixir-otp-and-phoenix)._

Having just finished [Functional Web Development with Elixir, OTP, and Phoenix](https://pragprog.com/book/lhelph/functional-web-development-with-elixir-otp-and-phoenix) it seemed appropriate to write up some takeaways that I encountered in the book. 

**The primary point of the book was to challenge assumptions about web development architecture.**

The author leads you through the process of building an application and challenges architecture assumptions along the way. 

## Thinking of your application first
Instead of thinking about the application in terms of the user interface that it will be accessed through - the author challenges readers to think of (and build) the application first. 

One way of thinking about architecture this way is to ask the question - _what if I were building a CLI **and** a web interface?_ It forces you to think about the application API boundary that will be accessed by both user interfaces.

### Example
For example, if I had a hot dog stand that allowed orders to be taken online, I would need a form that allows them to select quantity, toppings, and submit payment. 

#### Outside in
I could start at the __outer-most layer__ and build the HTML that the user will see in order to do this. Then to make the HTML do something, I'd need to add a `route` and `controller`. In the controller I'd need to call some functions that store data to a database or call a payment API, so I'd build those too. Eventually I'd have a working form. 

This way of building increases the risk that that the application will be tightly coupled to the user interface. What if I want to add a hot dog button that people can push to order? 

#### Inside out
The "inside out" approach would be starting with the core functionality of the application. In this case it would be writing a `HotDogOrder` module with functions to add hot dogs, toppings, submit payment, etc. 

With the core application in place, I'd then add a web interface on top of it, calling the application functions from the web controllers.

## Towards maintainability
The difference between these two approaches is subtle but important. By thinking of your application first and the user interface second, it sets you up for building something that is more maintainable. 

The author also covers these ideas in his talk [Phoenix is not your application](https://www.youtube.com/watch?v=lDKCSheBc-8). I highly recommend watching it. 
