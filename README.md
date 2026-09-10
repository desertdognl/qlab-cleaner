# QLab Cleaner

Mac app that compares a QLab 5 workspace with media on disk: what the show uses, what can go, and what is missing.

## Install

Download the latest **QLab Cleaner-x.y.z.dmg** from [Releases](https://github.com/desertdognl/qlab-cleaner/releases). Open the disk image and drag **QLab Cleaner** onto **Applications**.

The first open may need **Right-click → Open** because the build is ad-hoc signed, not notarized.

## Build on this Mac

```sh
./build.sh
```

That compiles the app, checks the local examples, writes a DMG in `dist/`, replaces `/Applications/QLab Cleaner.app`, and relaunches it.

Requires macOS 13+, Apple Silicon, and the Command Line Tools (`xcode-select --install`). Xcode is not required.

## Relink and extra cue types

Missing files are relinked in QLab, not in this app. Titles, fonts and lighting are only listed when QLab actually stores a file target (`F53Alias`). Those types are not invented.
