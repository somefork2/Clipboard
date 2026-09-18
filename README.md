# CopyWell

Clipboard manager for macOS 14+. Keyboard-first, on-device, no account required.

## Features

- **History** — everything you copy, searchable across text, links, OCR'd images, tags and source app.
- **Clipboard palette** — ⌥⌘V opens a floating panel at the cursor without stealing focus, so the paste lands where you were typing.
- **Menu bar** — the last dozen clips with search, one click to paste, no window needed.
- **Paste Stack** — queue clips and paste them in order.
- **Pinboards** — group clips you keep reusing.
- **On-device analysis** — Natural Language for type, language, entities and tags; Vision for text in screenshots. Nothing leaves the Mac.
- **Privacy first** — items marked secret by password managers are never recorded; items you mark sensitive are encrypted with a key in your login keychain; windows can be hidden from screen recordings.
- **Export** — JSON, CSV, Markdown, HTML.
- **iCloud sync** — optional, through your own private CloudKit database. A custom record zone with server change tokens, so edits and deletions both propagate. Syncs on launch, when you switch back to CopyWell, on a timer and shortly after you copy. Images and clips marked sensitive never leave the Mac.
- **Themes** — System, Light, Dark, plus Paper, Graphite, Slate and Ink.
- **Accessible** — five text sizes that scale every label and grow the rows with them.
- **Retention you choose** — keep the last N clips, or only the last N days, or everything. Favourites and pinboards are never dropped.

## Keyboard shortcuts

All global shortcuts are remappable in Settings ▸ Shortcuts.

| Shortcut | Action |
|---|---|
| ⌥⌘V | Open the clipboard palette |
| ⇧⌘V | Put the previous item back on the clipboard |
| ⌃⌥⌘V | Copy the latest clip without formatting |
| ⌥⌘P | Pin the last copied item |
| ⌃⌥P | Pause / resume recording |
| ⌥⌘S | Copy the next item from the Paste Stack |

In the main window, pinboards included: click a clip's icon or thumbnail to preview it, ⌘Y or Space for the selected row, ⏎ to paste, ⌥⏎ as plain text, ⌘D to favourite, ⌘⌫ to delete.

Inside the palette:

| Key | Action |
|---|---|
| ↑ ↓ | Move |
| ⌘1–9 | Jump to an item |
| ⏎ | Copy and return to your app |
| ⌥⏎ | Copy without formatting |
| ⌘Y | Quick Look |
| ⌘F | Focus search |
| ⌘⌫ | Delete |
| ⎋ | Close |

CopyWell adds a **CopyWell** item to the top level of Finder's right-click menu
through a Finder extension: save the selected files, copy their paths, or copy
their text contents. Enable it in System Settings ▸ General ▸ Login Items &
Extensions ▸ Finder Extensions.

CopyWell also installs Services entries (Save to CopyWell, Pin to CopyWell, Add to Paste Stack, Paste from CopyWell) that appear in the right-click ▸ Services menu of any app. Enable them in System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Services.

## Permissions

**CopyWell asks for none.**

It never synthesises keystrokes, so it does not need Accessibility access —
choosing a clip puts it on the clipboard and hands focus back to the app you
came from, one ⌘V away. To insert a clip without pressing anything, use
Services ▸ Paste from CopyWell, which is the mechanism macOS provides for one
app to hand text to another and requires no permission.

iCloud is used only if you turn sync on, and only in your own private database.

## Building

The App Store build comes from the Xcode project, which carries the sandbox, entitlements, signing and privacy manifest:

```bash
xcodegen generate
open CopyWell.xcodeproj
```

Set `DEVELOPMENT_TEAM` in `project.yml` (or pick your team in Xcode) before archiving. `Products.storekit` is attached to the Run scheme so purchases can be exercised without App Store Connect.

The Swift package builds the same sources for quick type-checking, but cannot produce a signed, sandboxed bundle:

```bash
swift build
```

## Release checklist

See [docs/APP_STORE.md](docs/APP_STORE.md).

## Architecture

```
Sources/
├── App/        # Entry point, AppDelegate, coordinator that owns shortcuts and capture
├── Core/       # Store, settings, hashing, image storage, encryption, shortcut model
├── Models/     # SwiftData models
├── Services/   # Capture, paste, categorisation, OCR, StoreKit, CloudKit, export
├── Views/      # SwiftUI views, palette panel, menu bar, settings
└── Resources/  # Info.plist, entitlements, privacy manifest, app icon
```

## License

MIT
