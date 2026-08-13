# ForceTouchTranslator

A lightweight macOS utility that translates words or selected sentences instantly when you Force Click (Deep Press) on your trackpad. It uses a borderless, native-looking dark mode popover. Powered by Hammerspoon.

### The Backstory
I built this during my summer IT internship. I use a base model M4 MacBook with 256GB storage, so I avoid installing heavy Electron-based dictionary apps just to translate documentation or articles. I wanted the native "Apple Look Up" feel, but routed through Google Translate. 

Writing a simple script to capture text sounded easy, but dealing with macOS accessibility permissions, Electron apps ignoring native APIs, and WindowServer crashes turned it into a serious architecture project. Here is the honest result of that process.

### Features
* **Native Trackpad Integration:** Listens specifically for macOS Force Touch (pressure stage 2) events.
* **Smart Text Detection:** If you select a whole sentence, it translates the block. If you just hover over a single word, it translates only that word.
* **Universal Support (The Hard Way):** Works on native apps (Safari, Notes) and non-native apps (Chrome, VS Code) without breaking your workflow.
* **Clipboard Safe:** It temporarily borrows your clipboard for extraction if needed, but uses raw data APIs to instantly restore your previously copied items (even images and files) without breaking anything.
* **No API Keys Needed:** Uses the free Google Translate web endpoint.

---

### Under the Hood & Architecture

To make this feel as fast as a native macOS feature and prevent system freezes, I had to implement a few specific architectural decisions:

**1. Hybrid Text Extraction Engine**
Grabbing text under the cursor is tricky on macOS. 
* **Native Path:** For apps like Safari or Notes, the script uses `AXUIElement` and `AXRangeForPosition` to extract the word seamlessly without any clicks.
* **Fallback Path:** Apps like Chrome or VS Code ignore Apple's accessibility text APIs. If the script detects this "blind spot", it triggers an asynchronous double-click and `Cmd+C` macro. Instead of just waiting for 50ms and hoping it copied, it actively listens to the OS clipboard change counter. It extracts the text the exact millisecond the copy registers, and restores your old clipboard data so fast you don't even notice it happened. 

**2. Singleton WebKit Engine**
Destroying and recreating a webview (Safari engine) for every translation was causing CPU spikes and visible delays. Instead, the script initializes a single hidden WebKit window on startup. When you Force Click, it simply injects the new HTML and moves the window to your cursor's coordinates. Zero render delay.

**3. Thread-Safe EventTap**
macOS WindowServer hates it when you block mouse events to wait for network or UI tasks. Earlier versions of this script accidentally froze the Mac. Now, the event listener (`hs.eventtap`) instantly releases the mouse and offloads all API calls and text extraction to asynchronous timers (`hs.timer.doAfter`). The system never locks up.

**4. Bypassed Artificial Delays**
Hammerspoon has a hidden 200ms delay between key down and key up events. I overrode this by forcing a 0ms delay on the clipboard keystrokes. I also added `Cache-Control: no-cache` and `Connection: keep-alive` headers to bypass DNS resolution lags on the async HTTP client.

**5. API Resilience**
The Google Translate endpoint sometimes returns bad JSON. If that happens, standard scripts crash. I wrapped the JSON parsing in protected calls (pcall) and added request IDs. Even if the network drops or the API sends garbage, the script just ignores it instead of crashing the whole Hammerspoon environment.

---

### Installation (Under a minute)

**Prerequisites:**
1. Install [Hammerspoon](https://www.hammerspoon.org/) for macOS.
2. Grant Hammerspoon Accessibility Permissions:
   * Open System Settings -> Privacy & Security -> Accessibility
   * Enable Hammerspoon. (If you update the script and it stops working, remove Hammerspoon with the minus (-) button and add it back).

**Setup:**
1. Download `forcetouchtranslator.lua` and place it in your Hammerspoon folder (usually `~/.hammerspoon/`).
2. Open `~/.hammerspoon/init.lua` and add this line:
   ```lua
   dofile(os.getenv("HOME") .. "/.hammerspoon/forcetouchtranslator.lua")
