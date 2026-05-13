---
title: "Citrine - A Game Boy Emulator for Web and Native"
date: 2026-05-13T14:44:33+02:00
draft: false
description: "Description and demo link for my Game Boy emulator which is playable in the browser."
summary: "A Game Boy emulator for your browser (or native), written in Rust."
categories: ["Citrine Game Boy Emulator"]
tags: ["Rust", "Demo", "Game Boy", "Emulation", "Nintendo"]
---
Some time ago I have started working on a Game Boy emulator in rust. My goal was to have nice debugging features and good performance while providing a good UX.

**You can try it out in the browser:** https://gb.lemon.industries\
**Its not made for mobile!**
![](featured.png)

### Features
- Full Game Boy video and audio
- Support for Windows, MacOS and Web
- Controller support
- Plays Game Boy games with MBC1, MBC2 and MBC3 cartridges (no RTC support yet)
- (M-)Cycle-accurate instruction and memory timing
- Save states for games that included a battery
- Includes bundled open source homebrew games
- Basic debugging tools
