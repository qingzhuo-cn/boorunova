<div align="center">

<p align="center"><img width="1000px" alt="BooruNova banner" src="docs/assets/banner.svg"></p>

# BooruNova [![Awesome](https://awesome.re/badge-flat.svg)](https://awesome.re)

**One app, every booru.** An open-source Android client for booru image boards.

English / [简体中文](README_cn.md)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%208.0%2B-green.svg)](https://github.com/qingzhuo-cn/boorunova/releases)
[![Language](https://img.shields.io/badge/language-Dart%20%2F%20Flutter-0175C2.svg)](https://flutter.dev)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Release](https://img.shields.io/github/v/release/qingzhuo-cn/boorunova)](https://github.com/qingzhuo-cn/boorunova/releases)

</div>

## Table of Contents

- [Why BooruNova](#why-boorunova)
- [Features](#features)
- [Supported Sites](#supported-sites)
- [Download](#download)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [How It Works](#how-it-works)
- [Development](#development)
- [Related Projects](#related-projects)
- [License](#license)

## Why BooruNova

Browsing multiple booru sites usually means juggling several apps or clunky mobile websites, each with different search syntax, tag layouts, and quirks. BooruNova was built to be a single, fast, native client that speaks every major booru engine — one search bar, one timeline, one place for favorites and downloads.

## Features

### Browsing
- 🖼️ **Multi-server support** — browse every configured site from one app
- 🌊 **Masonry timeline** — adjustable grid columns (2–6), seamless infinite scroll
- 🔍 **Full-screen viewer** — pinch-zoom, swipe navigation, slideshow mode
- 🏷️ **Categorized tags** — artist / character / copyright / general / meta

### Search
- ✨ **Tag autocomplete** — debounced, per-server cached suggestions
- 🔥 **Trending tags** — pulled live from the current site
- 🕘 **Search history** — last 20 queries, one-tap re-run
- 🎚️ **Sort & rating filters** — relevance / score / date / rating, built into the query

### Favorites & Downloads
- ⭐ **Favorites** — tracked per-server, cross-app
- 💾 **Download to gallery** — sample or original quality
- 📦 **Batch operations** — favorite, download, and share multiple posts

### Personalization
- 🚫 **Tag blacklist** — hide what you don't want to see
- 🎨 **Themes** — light / dark / midnight with custom accent colors
- 👆 **Configurable gestures** — swipe / tap / long-press actions
- 🌐 **Custom Hosts mapping** — reach sites from restricted networks

### Data Management
- 🗄️ **Full backup & restore** — servers, favorites, history, blacklist, settings
- 🧹 **Cache management** — reclaim storage in one tap

## Supported Sites

Any site running one of these engines can be added by URL — the app auto-detects the engine:

| Engine | Example sites |
|--------|---------------|
| Danbooru | danbooru.donmai.us |
| Gelbooru (v0.2 API) | gelbooru.com |
| Moebooru | yande.re, konachan.com |
| Safebooru | safebooru.org |
| e621 | e621.net |
| Sankaku | chan.sankakucomplex.com |
| Zerochan | zerochan.net |
| Rule34 | rule34.xxx |

## Download

Grab the latest APK from [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases).

| ABI | Package |
|-----|---------|
| arm64-v8a / x86_64 (universal) | `app-release.apk` |

## Quick Start

### Prerequisites

| Requirement | Version |
|-------------|---------|
| Flutter SDK | >= 3.10.4 |
| Dart | >= 3.0.3 |
| Android SDK | API 26+ |

### Run from source

```bash
git clone https://github.com/qingzhuo-cn/boorunova.git
cd boorunova
flutter pub get
flutter run
```

### Build a release APK

```bash
flutter build apk --release
```

Output lands at `build/app/outputs/flutter-apk/app-release.apk`.

## Usage

### Adding a server

| Step | Action |
|------|--------|
| 1 | Open the **Servers** page, tap **+** |
| 2 | Enter the site URL (e.g. `https://safebooru.org`) |
| 3 | Tap **探测 / Detect** — the engine is auto-matched |
| 4 | Confirm the engine, name it, save |

### Reordering servers

Tap the sort button (top-right of the Servers page) to enter drag-reorder mode, then drag to taste.

### Searching

Type a tag and pick from live suggestions, or combine with sort/rating filters from the toolbar (`order:score`, `rating:s`, …) — they're merged into the query for you.

## How It Works

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   UI (Riverpod) │──▶│  BooruRegistry    │──▶│  Engine (8 impl) │
│  screens/widgets │   │  createRepository │   │  per-site repo   │
└─────────────┘    └──────────────────┘    └────────┬────────┘
                                                    │
                          ┌─────────────────────────┘
                          ▼
                   ┌──────────────┐    ┌──────────────┐
                   │  BaseBooru    │──▶│   Parser      │──▶ BooruPost
                   │  Repository   │   │ (per engine)  │
                   │  (dio+server) │    └──────────────┘
                   └──────┬───────┘
                         │
                   ┌─────▼──────┐
                   │ DioFactory │──▶ hosts interceptor, timeouts, UA
                   └────────────┘
```

Every engine is a thin `BaseBooruRepository` subclass — it only declares its endpoints and parser. Networking (timeouts, hosts remapping, auth headers) is centralized in `DioFactory`, so one fix applies everywhere.

## Development

| Task | Command |
|------|---------|
| Analyze | `flutter analyze` |
| Run tests | `flutter test` |
| Add an engine | subclass `BaseBooruRepository`, register in `BooruRegistry` |

The parser layer is covered by fixture-driven unit tests (`test/boorus/`) — each engine's parser is exercised against real-shaped responses plus malformed-input cases.

## Related Projects

- [Boorusphere](https://github.com/nullxception/boorusphere) — UI/UX inspiration
- [Boorusama](https://github.com/khoadng/Boorusama) — feature & settings inspiration
- [awesome-booru](https://awesome.re) — the booru ecosystem

## License

[MIT](LICENSE) © BooruNova contributors
