---
date: 2025-05-03
title: "TBD"
slug: insta-360
draft: true
categories: []
tags:
---

# Braindump of everything I remember 

It was late 2019. I had just finished up a beta of SmartTrack and shifted gears to help the team round out the VideoWalk feature we launched but was struggling with gaps and scaling issues. 

Insta360 had a new camera called the OneX that was a lower cost option by like 10x. We were working on getting VideoWalk adoption rolling and customers kept asking if we could support the OneX. - maybe I need Philip interview here. 

Stiching the two fisheye lense files into a single mp4 was not supported outside of the Insta360 Desktop application. We needed an automated way to stitch these two together without clicking around in the desktop UI.

Insta360 did not have stitching in their SDK yet. So we used what we had. 

We stood up a Windows Desktop computer in the cloud through AWS Workspaces, installed the Insta360 desktop application, then used AutoHotKey to click around the GUI to stitch files together. 

I wrote a script in Rust that was a single lane queue for the stitching pipeline. It downloaded the files from the right bucket stitched them and then reuploaded them. I needed to make sure I didn't send a video to the wrong destination. And needed to reliably determine when the stitcher was done doing its work. 




