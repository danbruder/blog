---
date: 2018-09-27
title: What is the alpine equivalent to build-essential?
slug: what-is-the-alpine-equivalent-to-build-essential
taxonomies: 
    category: [ Development ]
    tags:
      - linux
      - docker
---

Answer: 

```bash
build-base
```

To include in a Docker image that is alpine based, you can use: 

```docker
RUN apk update \
    && apk --no-cache --update add build-base 
```
