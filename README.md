# BooruNova

A Flutter-based booru client for Android, inspired by Boorusphere and Boorusama.

## Features

- **Multi-server Support** — Danbooru, Gelbooru, Safebooru, Moebooru, e621, Sankaku, Zerochan, Rule34, etc.
- **Server Management** — Add/edit/delete servers, auto-detect engine type, preset templates
- **Post Timeline** — Masonry grid layout with adjustable columns (2-6), staggered entry animations
- **Post Viewer** — Full-screen image viewer with pinch-to-zoom, slideshow, swipe navigation
- **Post Details** — Categorized tags, multi-select, SpeedDial FAB (search/append/block/copy)
- **Search** — Bottom search bar with autocomplete suggestions, search history
- **Favorites & Downloads** — Save posts to favorites, download images to gallery
- **Tags Blocker** — Block unwanted tags from timeline
- **Hosts Feature** — Custom domain-to-IP mapping for network-restricted environments
- **Gesture Controls** — Configurable swipe/tap/double-tap/long-press actions
- **Themes** — Light/dark/midnight modes with accent color picker
- **Navigation** — Left drawer (favorites/downloads/servers/settings), right panel (explore/forum/artists)
- **Chinese UI** — Full Chinese language interface

## Screenshots

(Screenshots coming soon)

## Getting Started

### Prerequisites

- Flutter SDK >=3.0.3
- Android SDK

### Installation

```bash
git clone https://github.com/qingzhuo-cn/boorunova.git
cd boorunova
flutter pub get
flutter run
```

### Build Release APK

```bash
flutter build apk --release --target-platform android-arm64
```

Or download the latest APK from [GitHub Releases](https://github.com/qingzhuo-cn/boorunova/releases).

## Configuration

### Adding a Server

1. Tap the **+** FAB on the Servers page
2. Enter the site URL (e.g., `https://safebooru.org`)
3. Tap **检测引擎** (Detect Engine) to auto-detect the booru type
4. Fill in a name and save

### Hosts (DNS Mapping)

For users in network-restricted environments, the Hosts feature allows mapping booru domains to custom IPs. Add rules in **设置 → Hosts** or import a hosts file.

## License

MIT License

## Credits

- Inspired by [Boorusphere](https://github.com/null-dev/Boorusphere) and [Boorusama](https://github.com/gsurika/Boorusama)
- Built with [Flutter](https://flutter.dev)
