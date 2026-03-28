# Mbanimator

A minimal macOS menu bar app that plays GIF animations directly in your menu bar.

## Features

- Play any GIF file in the macOS menu bar
- Built-in spinner animation (no GIF required)
- GIF library — add multiple GIFs and switch between them with one click
- Remembers the last played animation across restarts
- Launch at login toggle
- Lightweight native app — no Electron, no dependencies

## Requirements

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```bash
make
```

The app bundle `Mbanimator.app` will be created in the project directory.

```bash
make run     # build and launch
make clean   # remove build artifacts
```

## Install

Move the built app to your Applications folder:

```bash
cp -r Mbanimator.app /Applications/
```

## Usage

1. Launch **Mbanimator** — a small icon appears in your menu bar
2. Click the icon → **Einstellungen** to open the library window
3. Click **GIF hinzufügen** to add one or more GIFs
4. Click any GIF in the list to play it in the menu bar
5. Use **Spinner** for a built-in terminal-style loading animation
6. Toggle **Autostart** to launch Mbanimator at login

## Project Structure

```
Mbanimator/
├── Sources/Mbanimator/
│   ├── main.swift              # Entry point
│   ├── AppDelegate.swift       # App lifecycle
│   ├── MenuBarController.swift # Menu bar icon & animation
│   ├── GIFLibrary.swift        # Persistence model
│   └── SettingsView.swift      # SwiftUI settings window
├── scripts/
│   └── create_icon.swift       # Generates the app icon
├── Info.plist
├── Package.swift
└── Makefile
```

## License

MIT
