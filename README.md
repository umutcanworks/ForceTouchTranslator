# ForceTouchTranslator (v3.0)

A lightweight macOS utility that translates words, selected sentences, or full paragraphs instantly when you Force Click (Deep Press) on your trackpad. It uses a borderless, native Liquid Glass popover. Powered by Hammerspoon and fully compatible with **macOS 27.2** and **Preview (`PDFKit`)**.

### The Backstory
I built this during my summer IT internship. I use a base model M4 MacBook with 256GB storage, so I avoid installing heavy Electron-based dictionary apps just to translate documentation or articles. I wanted the native "Apple Look Up" feel, but routed through Google Translate. 

Writing a simple script to capture text sounded easy, but dealing with macOS accessibility permissions, Electron apps ignoring native APIs, PDFKit deselection quirks in Preview, and WindowServer crashes turned it into a serious architecture project. Here is the honest result of that process.

### Features
* **Native Trackpad Integration:** Listens specifically for macOS Force Touch (pressure stage 2) events.
* **Smart Text Detection (Single Word & Multi-Paragraph):** If you select a sentence or paragraph and Force Click on top of it, it translates the entire selection. If you just hover over a single word and Force Click, it translates only that word.
* **Full macOS 27.2 & Preview.app Compatibility:** Solves PDFKit's stage-1 click deselection bug and supports both native PDFs and Live Text layers in Apple Preview (`Önizleme`), Skim, and Acrobat.
* **Native macOS 27.2 Liquid Glass UI (`NSGlassEffectView` + `NSGlassTintAmount` Sync):** Auto-compiles a lightweight Objective-C bridge (`~/.hammerspoon/.ftt_native_v30.so`) that attaches AppKit's native `NSGlassEffectView` behind the transparent `WKWebView` with zero secondary blur overlay (`inputFaceOpacity = 1.0`), dynamically reading and live-syncing with the user's **macOS System Settings -> Appearance -> Liquid Glass** slider (`NSGlassTintAmount`).
* **Smoothly Draggable Popover UI:** Grab and move the Force Click translation popover (or Menubar popover) from any available empty space (top control bar, card headers, or margins) without interfering with text selection or controls.
* **38 Languages & Language-Specific Voice Assistants (TTS):** Supports 38 popular world languages and automatically selects each language's native macOS voice assistant (e.g., *Yelda* for Turkish, *Samantha* for English, *Anna* for German, *Thomas* for French, *Mónica* for Spanish, *Milena* for Russian, *Kyoko* for Japanese, *Yuna* for Korean, *Majed* for Arabic, *Tingting* for Chinese) for both original and translated text.
* **Orbital Wind-Swoosh Language Swap, Pin Mode & Detected Language:** Includes a half-turn (`+180°`) orbital wind-arc swap button, Pin mode to keep the translation popover open while taking notes, and auto-detected source language labels with phonetics.
* **Zero-Latency LRU Cache:** Frequently translated words and sentences are served instantly (0ms) from an in-memory LRU cache.
* **Clipboard Safe:** Temporarily borrows your clipboard for fallback extraction only when needed, using raw pasteboard data APIs to instantly restore previously copied items (even images and files).
* **No API Keys Needed:** Uses the free Google Translate web endpoint.

---

### Under the Hood & Architecture

To make this feel as fast as a native macOS feature and prevent system freezes, the engine relies on several specific architectural decisions:

**1. Pre-Click Selection Watcher & Hybrid Text Extraction Engine**
Grabbing text under the cursor on macOS—especially inside **Preview (`com.apple.Preview`)**—is tricky because a physical Force Click starts with a Stage 1 `leftMouseDown` event that causes PDFKit to clear any highlighted paragraph before Stage 2 pressure is reached.
* **Selection Snapshot Path:** A lightweight mouse/drag watcher tracks manual selections (including Three-Finger Drag) and snapshots the text via deep `AXParent` hierarchy traversal (`AXSelectedText` / `AXSelectedTextRange`) or clipboard-safe fallback the moment you finish selecting. When you Force Click on top of your selection, the full paragraph is translated even if Stage 1 cleared the highlight.
* **Native Coordinate Path:** For apps like Safari or Notes, the script uses `AXUIElement`, `AXRangeForPosition`, and a Unicode-aware word boundary parser (supporting Turkish characters, curly quotes, em-dashes, and internal apostrophes) to extract the word at Stage 2 entry with zero synthetic clicks.
* **Fallback Double-Click Path:** For apps that ignore coordinate APIs (Preview single-word hover, Chrome, VS Code), it waits until Stage 0 release (preventing hardware button-state collisions), fires an asynchronous double-click macro, checks `AXSelectedText` first, and falls back to clipboard change-counter polling (`changeCount()`) with full clipboard restoration.

**2. Singleton WebKit Engine & Multi-Monitor Edge Alignment**
Destroying and recreating a webview (Safari engine) for every translation causes CPU spikes and visible delays. Instead, the script initializes a single hidden WebKit window on startup. When you Force Click, it resets state, injects the updated content, and dynamically recalculates screen edge bounds upon `render_complete` so popovers near the bottom of the screen or on secondary monitors align directly with the cursor.

**3. Thread-Safe EventTap & Sleep/Wake Watchdog**
macOS WindowServer hates it when you block mouse events to wait for network or UI tasks. The event listener (`hs.eventtap`) instantly releases the mouse and offloads all API calls, double-click sequencing, and text extraction to non-blocking asynchronous timers (`hs.timer.doAfter`). A watchdog timer and `hs.caffeinate.watcher` ensure the event taps stay alive across macOS sleep/wake cycles.

**4. API Resilience & Persistent Preferences**
JSON parsing is wrapped in protected calls (`pcall`) with monotonically increasing request IDs (`requestId`) to prevent race conditions. Source and target language preferences are persisted across restarts via `hs.settings`.

**5. Native Lua Network Bridge & WKWebView Sandboxing Bypass**
WebKit security isolates local HTML documents from cross-origin remote HTTP requests, preventing fragile in-browser `fetch` calls from failing with CORS errors. Instead, translation requests communicate via native message handlers (`window.webkit.messageHandlers.ftt`), leveraging macOS native asynchronous networking (`hs.http`) and an in-memory 50-entry LRU cache for 0ms re-translations and zero CORS restrictions.

---

### Installation (Under a minute)

**Prerequisites:**
1. Install [Hammerspoon](https://www.hammerspoon.org/) for macOS.
2. Grant Hammerspoon Accessibility Permissions:
   * Open **System Settings -> Privacy & Security -> Accessibility**
   * Enable **Hammerspoon**. (If you update macOS or Hammerspoon and it stops working, remove Hammerspoon with the minus (`-`) button and add it back).

**Setup:**
1. Download `forcetouchtranslator.lua` and place it in your Hammerspoon folder (usually `~/.hammerspoon/`).
2. Open `~/.hammerspoon/init.lua` and add this line:
   ```lua
   dofile(os.getenv("HOME") .. "/.hammerspoon/forcetouchtranslator.lua")
   ```
3. Click the Hammerspoon menu bar icon and select **Reload Config**.

---

### License
This project is licensed under the [MIT License](LICENSE).
