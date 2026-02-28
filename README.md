# FrameworkScanner

A macOS app that scans installed applications and identifies the development frameworks they use — Electron, SwiftUI, Flutter, Qt, Unity, and more.

![macOS 13.0+](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

![Screenshot](image/c49ed43a-27c7-4909-ab99-e0c1230af6fe.png)

## Features

- Scans `/Applications` and `~/Applications` with up to 8 concurrent tasks
- Detects 13 framework types: Electron, CEF, Flutter, Qt, Unity, Unreal Engine, .NET/MAUI, Java/JVM, Tauri, Catalyst, SwiftUI, AppKit, and Unknown
- Electron apps show Electron / Chromium / Node.js version details
- Expandable rows reveal embedded frameworks with name, version, path, and size
- Search, multi-filter, and sort by name / size / date / framework
- Stats bar showing framework distribution and total Electron disk usage
- Export results as CSV or JSON
- Light / Dark / System appearance, 8 languages supported

## Requirements

- macOS 13.0 (Ventura) or later

## Installation

### Homebrew (Recommended)

```bash
brew tap Geoion/tap
brew install --cask frameworkscanner
```

After installation, if macOS Gatekeeper blocks the app on first launch, run:

```bash
xattr -cr /Applications/FrameworkScanner.app
```

> **Why is this needed?**
> macOS automatically adds a `com.apple.quarantine` extended attribute to files downloaded from the internet. This causes Gatekeeper to block unsigned or ad-hoc signed apps. The command above removes that attribute so the app can launch normally.

Then open the app as usual.

### Build from Source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/Geoion/FrameworkScanner.git
cd FrameworkScanner
xcodegen generate
open FrameworkScanner.xcodeproj
```

## Usage

1. Launch **FrameworkScanner**
2. Click **Grant Access** and select your `/Applications` folder when prompted
3. The app scans all `.app` bundles and displays results in a sortable list
4. Click any row to expand and view embedded frameworks
5. Use the search bar and filter menu to narrow results
6. Use the **Export** button to save results as CSV or JSON

## License

MIT
