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

Let's go through the command step by step:

- `find`: The `find` command is used to search for files in a directory hierarchy.
- `! -ctime -7`: This is the condition to find files older than 7 days. The `!` is used to negate the condition, and `-ctime -7` is used to find files that were changed more than 7 days ago.
- `-type f`: This is used to specify that we are looking for files, not directories.
- `-delete`: This option is used to delete the files that match the conditions.
