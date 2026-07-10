---
date: 2017-09-14
title: Installing Golang 1.9 on Raspberry PI 3B
slug: installing-golang-1-9-on-raspberry-pi-3b
taxonomies: 
    category: [Backend]
    tags:
      - go
      - raspberry-pi
---

From your home directory:

```bash 
wget https://storage.googleapis.com/golang/go1.9.linux-armv6l.tar.gz
sudo tar -C /usr/local -xzf go1.9.linux-armv6l.tar.gz
```

Next, edit ~/.bashrc and add this to the bottom:

```bash
export PATH=$PATH:/usr/local/go/bin:~/go/bin 
```

Now create your workspace:

```bash
mkdir ~/go
```
