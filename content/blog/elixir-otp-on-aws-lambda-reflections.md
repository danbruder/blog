---
date: 2018-12-13
title: Elixir/OTP on AWS Lambda - Reflections
slug: elixir-otp-on-aws-lambda-reflections
categories: [Serverless]
tags:
  - elixir
  - architecture
  - aws
  - devops
---

You can't talk about Elixir without talking about OTP. It is integral to the language and ecosystem and a compelling reason to use Elixir. But what about using Elixir in an environment that side-steps the benefits of OTP?

I believe this is what you get for running Elixir on AWS lambda (though I'm not totally sure yet). 

The primary features of OTP that make it so compelling are a robust concurrency model, fault-tolerance through isolation and supervision, and built in distribution. 

With Lambda, you (kind of) get those features but they are built into the platform that your code is running on. In Lambda's model, each event (http request, for example), gets a new execution of your application code - isolated to that event and AWS allows as many of these to run in parallel as you want (with some caveats). That gets us concurrency and isolation. You can also send events to other lambdas or AWS services. This kind of mirrors OTP distribution.

With Elixir/OTP deployed traditionally to a server, you send the whole system up to the cloud. With Labmda, you write your application code and it plugs into the "whole system". 

So why use Elixir on Lambda? Why consider Lambda at all?

The main driver for lambda in my opinion is outsourcing infrastructure (to the highest degree). You deploy lambda and are _done_ (again, with caveats probably). Another reason is to re-coup the costs of infrastructure when your traffic is low. Only get traffic during the U.S.'s day -  then why pay for servers at night? And the other side of that coin - front page of HN? No problem. 

Is it better than deploying the regular way to some boxes in the cloud? I'm not totally convinced (but am curious). The upsides of Lambda come with limits: 
1. You are limited to 1000 concurrent functions (unless AWS lifts it)
2. Functions that haven't been active are subject to a "cold start" delay
3. You can't run real-time long running processes. You can't do websockets without hoop jumping. 

And of course you throw out the OTP state niceties - ets, mneasia and agents.

I think the Elixir-Lambda fit has its place in an API where latency isn't first priority, you don't need long-running processes, traffic is variable, and you want the set-it-and-forget-it nature of deploying a function. Elixir as a language is delightful enough for me to use it even outside of OTP. 

One thing I need to investigate is the process of multiple concurrent functions running - do they use their own OTP instance or do they share one somehow? I'd also like to know more about the freezing/thawing of an OTP instance when the lambda is spun down. 


