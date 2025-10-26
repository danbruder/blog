---
date: 2018-01-03
title: How to delete a git tag
slug: how-to-delete-a-git-tag
categories: [Development]
tags:
  - git
---

To delete a local tag:

```bash
git tag -d v0.1.1
```

To delete a remote tag:

```bash
git push origin :refs/tags/v0.1.1
```
