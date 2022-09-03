---
date: 2018-06-30
title: AWS AppSync First Impressions
slug: aws-appsync-first-impressions
category: Serverless
tags:
  - aws
  - graphql
---

AppSync is a service from AWS that lets you configure a GraphQL API over your AWS data sources including DynamoDB, Lambda, and Elasticsearch. It seems to be aimed at getting a backend up and running quickly and with minimal fuss.

## The up-and-running experience is nice
Their UI is easy to navigate. I was able to create a schema, connect it to Dynamo and query items pretty quickly.

They offer features that help you build your schema. For example, you can “import” from a DynamoDB table and in the process, the appropriate Graphql types are generated for you.

You can also create a resource from a type and they will spin up a DynamoDB table behind the scenes.

Specifying Lambdas a resolvers gives you access to whatever datasource you want, whether in AWS or otherwise.

## Prior GraphQL knowlege helps
Having experience building schemas by hand, helped me get going, I think it may be a bit much for someone new to GraphQL.

## Other stuff
- Mapping queries to resolution values is done with a templating language called Velocity.
- They provide starter kits for iOS, Android, RN, and Web
- Integration with AWS auth services is nice: You can add access logic to your queries based on roles/users in Cognito

_Go fourth and build!_
