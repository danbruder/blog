---
date: 2024-03-17
title: Delete files older than 7 days with bash
slug: delete-files-older-than-7-days-with-bash
taxonomies: 
    category: [ Development ]
    tags:
      - linux
---

To delete files older than 7 days with bash, you can use the following command:

```bash
find ! -ctime -7 -type f -delete
```

Passing `!` to `find` will negate the condition, so it will find files that are not created in the last 7 days. The -type f flag will make sure that only files are deleted, and the -delete flag will delete the files found.

Replace 7 with the number of days you want to use as a threshold.

