# ClipStack

Modern clipboard manager for macOS with AI-powered categorization.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.10-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Smart Clipboard History** — automatically captures and organizes everything you copy
- **AI Categorization** — NaturalLanguage framework analyzes content type, entities, and sentiment
- **OCR for Images** — extracts text from screenshots and images via Vision framework
- **Global Shortcuts** — ⌥⌘V for quick paste, ⌃⌥P to toggle pause
- **CloudKit Sync** — sync across devices (graceful fallback when unavailable)
- **Export** — save history as JSON, CSV, Markdown, or HTML
- **Themes** — System, Light, Dark, Midnight, Neon with accent colors
- **Paste Stack** — queue multiple items for sequential pasting
- **Subscription** — Free tier (100 items) with Pro upgrade

## Requirements

- macOS 14.0+
- Swift 5.10+

## Installation

```bash
git clone https://github.com/somefork2/Clipboard.git
cd Clipboard
swift build
swift run
```

Or create an app bundle:

```bash
mkdir -p build/ClipStack.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/ClipStack build/ClipStack.app/Contents/MacOS/
open build/ClipStack.app
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌥⌘V | Quick Paste popup |
| ⌃⌥V | Toggle pause monitoring |

## Architecture

```
Sources/
├── App/            # App entry point, AppDelegate
├── Models/         # SwiftData models (ClipboardItem, Pinboard, ContentType)
├── Services/       # Core logic (ClipboardMonitor, SmartCategorizer, OCR, etc.)
├── ViewModels/     # MVVM view models
└── Views/          # SwiftUI views
```

## Tech Stack

- **SwiftUI** — declarative UI
- **SwiftData** — local persistence
- **NaturalLanguage** — text analysis, NER, sentiment
- **Vision** — OCR for images
- **CloudKit** — optional sync
- **AppKit** — system integration

## License

MIT
