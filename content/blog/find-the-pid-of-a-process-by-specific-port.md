---
date: 2017-11-14
title: Find the PID of a process by specific port
slug: find-the-pid-of-a-process-by-specific-port
category: Development
tags:
  - linux
---

You can use the `lsof` utility to find what process is using a port. For example, to see what process is using port 8000:

```bash
lsof -i :8000
```

You'll get something like this:
```bash
COMMAND  PID USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
java    2501  dan   54u  IPv4 0x[some numbers here]      0t0  TCP *:irdmi (LISTEN)
```

See this [stack exchange question](https://unix.stackexchange.com/questions/106561/finding-the-pid-of-the-process-using-a-specific-port) for more info.