# ForceTouchTranslator 🚀

**ForceTouchTranslator** is a lightweight, instant translation tool for macOS. It allows you to **Force Click (Deep Press)** on your trackpad over any selected sentence or hovered word to display a native Apple-style dark mode translation popover instantly.

Powered by [Hammerspoon](https://www.hammerspoon.org/).

---

## ✨ Features

- **Gesture & Trackpad Native Integration**: Uses macOS Force Touch (pressure stage 2) events.
- **Smart Text Detection**:
  - **Selected Sentence Mode**: Select any sentence or multi-word paragraph and force-click to translate it as a whole without losing your active text selection.
  - **Hover Single-Word Mode**: Hover your cursor over a single word and force-click to translate just that word.
- **Universal Application Support**: Works seamlessly across Safari, Google Chrome, VS Code, Slack, Obsidian, Preview, PDF Readers, Notes, Pages, and native macOS apps.
- **Clipboard Preserved**: Automatically restores your original clipboard contents after fetching text.
- **Apple UI Aesthetics**: Sleek, borderless dark-mode popover with smooth fade-in animations. Dismisses instantly on `Escape` or clicking anywhere outside the window.
- **Zero API Key Required**: Powered by Google Translate free web endpoint.

---

## 📦 Installation (30 Seconds)

### Prerequisites
1. Install **[Hammerspoon](https://www.hammerspoon.org/)** for macOS.
2. Grant Hammerspoon **Accessibility Permissions**:
   - Open **System Settings** -> **Privacy & Security** -> **Accessibility**
   - Enable **Hammerspoon**.

### Setup
1. Download `forcetouchtranslator.lua` and place it in your Hammerspoon folder (`~/.hammerspoon/`).
2. Open `~/.hammerspoon/init.lua` and add this line:
   ```lua
   dofile(os.getenv("HOME") .. "/.hammerspoon/forcetouchtranslator.lua")
   ```
3. Reload Hammerspoon config (Click the Hammerspoon menu bar icon -> **Reload Config**).

---

## ⚙️ Configuration

You can customize the target language and ignored apps at the top of `forcetouchtranslator.lua`:

```lua
-- Target language for translation (e.g., "tr" for Turkish, "es" for Spanish, "fr" for French, "de" for German)
local TARGET_LANGUAGE = "tr"

-- Applications where Force Touch translation should be ignored
local IGNORED_APPS = {
    "Finder",
    "Dock"
}
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
