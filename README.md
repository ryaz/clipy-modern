# Clipy

A modern clipboard manager for macOS, built with SwiftUI, SwiftData, and async/await. Features AI-powered tagging and smart search via Claude.

## Install

### Option 1: Homebrew (recommended)

```bash
brew tap ryaz/clipy
brew install --cask clipy-modern
```

### Option 2: Download DMG

1. Download the latest `Clipy-x.x.x.dmg` from [Releases](https://github.com/ryaz/clipy-modern/releases)
2. Open the DMG and drag **Clipy** to **Applications**

### After installing

1. On first launch: right-click the app > **Open** > **Open** (required for unsigned apps). If that doesn't work, run `xattr -cr /Applications/Clipy.app`
2. Grant **Accessibility** access in **System Settings > Privacy & Security > Accessibility** (required for paste to work)

## Usage

| Shortcut | Action |
|---|---|
| **Cmd+Shift+V** | Open clipboard history |
| **Cmd+Shift+B** | Open snippets menu |
| **1-9** | Quick-paste item from history menu |

- Select any item from the history menu to paste it into the active app
- Items are numbered 1-30; press a number key to instantly paste that item
- The menu appears at your cursor position

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
