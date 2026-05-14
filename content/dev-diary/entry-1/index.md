---
title: "Dev Diary - Entry #1"
date: 2026-05-13T20:19:48+02:00
featureImage: https://media.lemon.industries/screenshot-20260513194937.png
draft: false
description: "An article where I am talking about this website and another related new tool I worked on today."
summary: "I am talking about this website and another related new tool I worked on today."
categories: ["Lemon Industries Website", "File Valet"]
tags: ["hugo", "blowfish", "rust", "egui", "avif", "webp"]
---

# New ventures

Today I started two new projects, one is the website you're currently reading this on, and the other is a kinda-related new tool.

## Lemon Industries Website

![](https://media.lemon.industries/screenshot-20260513194937.png)

### Why?

Why lemons? I dont know, I just really love the faint essence of it, like when theyre in a cocktail or something, but even then limes are slightly tastier... yellow just looks better than green. I just love lemons for some reason.

Why website? I am coding actively as a hobby for a couple of years now and I am always sharing my progress and all the cool things with my friends. All the images, screenshots and progress reports become scattered around everywhere and drown in other unrelated messages... I really wanted to have one central place where I could share all the things I am working on and keep track of my progress. I think it could also be fun to look back on this post in like 2-3 years time and see how things have changed (if I look back at the stuff I did 2-3 years back from now a part of me dies).

### I hate frontend

In my humble opinion, frontend development is a pain and not something I wanna do for fun in my freetime. I am already forced to do it at work and I would rather avoid it whenever I can. That is also what lead the creation of this website into a certain direction. In an ideal world I would just write the text I wanna write, have some basic features like image embedding, have it all sorted, organized neatly, pleasant to look at, with view and like counts, and ... I would lose myself and never finish it if I were to do this fully myself and while also trying to avoid any frontend shenanigans (which would be impossible), thats why I took a look out for alternatives.

### Technology
In university we talked about Content Management Systems (CMS). There are a couple of different categories, there are the fully-fledged-out ones like Wordpess, Typo3, Ghost, etc.. There are headless ones where I forgot the names. And then there are so called "static site generators". I did not wanna use a UI to configure stuff, while it has it's charme, it can also be pretty annoying (like in Wordpress, honestly theres just too much to configure, and the plugin stuff is a pain too). And for Ghost, a really nice-looking and sleek app... it was on my list. UNTIL I found **[Hugo](https://gohugo.io)**, a static site generator that generates your website from markdown and some config files.

I always liked markdown for editing any kinds of things where I wanna put some effort in writing, Obsidian comes to mind. I used it for studying more complex computer science topics in university and it was kind of fun to create my own little Wiki through markdown, it grew on me. I hate dabbling with all the format options in Word or Pages when the text I write is fundamentally just text split in sections, sub-sections and sub-sub-sections. So creating my own website just through markdown sounded like a dream.

Then I saw Hugo supporting custom themes and dove deeper into the rabbit hole, eventually finding **[Blowfish](https://blowfish.page)**. What really surprised me is that its more than just a theme. It severely extends the featureset of Hugo and even provides a CLI tool through (`npx blowfish-tools`) for creating and editing sites, so in most cases you dont even have to touch any configuration files. Setting up and configuring the website was a matter of an hour or two, which included setting up firebase for live view and like counts and a docker container for eventually deploying my website. It was really simple, and now I can write markdown and it turns into a website, I dont have to do any frontend code, thats all I need. If you want to do the same you literally just have to follow the guide on https://blowfish.page.

If you are interested in how this page looks like for me during editing: https://github.com/Zitronenjoghurt/lemon-personal

### Plans
Realistically, I will probably not write an entry every day. And most future entries might also not be this long or detailed (or maybe even more detailed it will really depend). Even more so once I start working full-time in the near future... I will just go with the flow and plaster on this page whatever goes through my mind and keyboard at whatever convenient time.

## File Valet

Yet another remote file copying tool... but is that really it?\
https://github.com/Zitronenjoghurt/file-valet

### My usecase
If I continue on with this website long into the future, I will not be able to keep any kind of media in its git repository (it will be way too much)... Thats why I set up a centralized media server to serve any kinds of files online from a directory on my server. I even set up an NFS to connect my PC and the server to more easily drop images into the remote media directory right from my desktop or wherever else locally. Only problem: Its still too cumbersome. Screenshots created on MacOs have a weird, non-URL friendly name out of the box. And I would also prefer it having a name like a timestamp: `screenshot-20260513194937.png` instead of `Screenshot 2026-05-13 at 7.49.37 PM.png`. For optimizing storage capacity I would also like to convert the images to WEBP or AVIF (most browsers should properly support these by know? I only know about the memes of how badly supported there are in other software, but even that might not be the case anymore nowadays). In short: I want to upload files to a directory on a remote server WHILE pre-processing them in a very specific way.

### Technology
As I am used to Rust + egui for making desktop applications, I will stick to those. I will also need some ssh crate to connect to my server via SFTP, probably [ssh2](https://crates.io/crates/ssh2). And something to encode the images with, probably [ravif](https://crates.io/crates/ravif). I read AVIF compressed better than WEBP with a better overall image quality, so thats a clear winner then. The images are only for being embedded on my webpage anyway and almost all browsers support avif (even Safari).

### Plans
I already laid the rough foundation today and will continue tomorrow.
