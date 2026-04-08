# Clipy

A modern clipboard manager for macOS, built with SwiftUI, SwiftData, and async/await. Features AI-powered tagging and smart search via Claude.

## Install

### Option 1: Download DMG

1. Download the latest `Clipy-x.x.x.dmg` from [Releases](https://github.com/ryaz/clipy-modern/releases)
2. Open the DMG and drag **Clipy** to **Applications**
3. Launch Clipy from Applications
4. On first launch: right-click the app > **Open** > **Open** (required for unsigned apps)
5. Grant **Accessibility** access in System Settings > Privacy & Security > Accessibility

### Option 2: Homebrew

```bash
brew tap ryaz/clipy
brew install --cask clipy-modern
```

Then grant Accessibility access in System Settings.

## Usage

- **Cmd+Shift+V** — Open clipboard history
- **Cmd+Shift+B** — Open snippets menu
- Click any item to paste it
- Right-click to pin or delete items

### AI Features (optional)

Set your Anthropic API key to enable automatic tagging, summaries, and smart search. The key is stored securely in your macOS Keychain.

## Build from source

```bash
git clone https://github.com/ryaz/clipy-modern.git
cd clipy-modern
make app
open build/Clipy.app
```

Requires macOS 14+ and Xcode Command Line Tools.

## Requirements

- macOS 14 (Sonoma) or later
- Accessibility permission (for paste injection)
