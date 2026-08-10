ForceTouchTranslator
A lightweight macOS utility that translates words or selected sentences instantly when you Force Click (Deep Press) on your trackpad. It uses a borderless, native-looking dark mode popover. Powered by Hammerspoon.

The Backstory
I built this during my summer IT internship. I use a base model M4 MacBook with 256GB storage, so I avoid installing heavy Electron-based dictionary apps just to translate documentation or articles. I wanted the native "Apple Look Up" feel, but routed through Google Translate.

Writing a simple script to capture text sounded easy, but dealing with macOS accessibility permissions, Electron apps ignoring native APIs, and WindowServer crashes turned it into a serious architecture project. Here is the honest result of that process.

Features
Native Trackpad Integration: Listens specifically for macOS Force Touch (pressure stage 2) events.

Smart Text Detection: If you select a whole sentence, it translates the block. If you just hover over a single word, it translates only that word.

Universal Support (The Hard Way): Works on native apps (Safari, Notes) and non-native apps (Chrome, VS Code) without breaking your workflow.

Clipboard Safe: It temporarily borrows your clipboard for extraction if needed, but restores your previous copied item instantly.

No API Keys Needed: Uses the free Google Translate web endpoint.

Under the Hood & Architecture
To make this feel as fast as a native macOS feature and prevent system freezes, I had to implement a few specific architectural decisions:

1. Hybrid Text Extraction Engine
Grabbing text under the cursor is tricky on macOS.

Native Path: For apps like Safari or Notes, the script uses AXUIElement and AXRangeForPosition to extract the word seamlessly without any clicks.

Fallback Path: Apps like Chrome or VS Code ignore Apple's accessibility text APIs. If the script detects this "blind spot", it triggers a highly optimized, asynchronous double-click and Cmd+C macro. It takes less than 30 milliseconds, reads the text, and restores your old clipboard data so fast that you don't even notice it happened.

2. Singleton WebKit Engine
Destroying and recreating a webview (Safari engine) for every translation was causing CPU spikes and visible delays. Instead, the script initializes a single hidden WebKit window on startup. When you Force Click, it simply injects the new HTML and moves the window to your cursor's coordinates. Zero render delay.

3. Thread-Safe EventTap
macOS WindowServer hates it when you block mouse events to wait for network or UI tasks. Earlier versions of this script accidentally froze the Mac. Now, the event listener (hs.eventtap) instantly releases the mouse and offloads all API calls and text extraction to asynchronous timers (hs.timer.doAfter). The system never locks up.

4. Bypassed Artificial Delays
Hammerspoon has a hidden 200ms delay between key down and key up events. I overrode this by forcing a 0ms delay on the clipboard keystrokes. I also added Cache-Control: no-cache and Connection: keep-alive headers to bypass DNS resolution lags on the async HTTP client.

Installation (Under a minute)
Prerequisites:

Install Hammerspoon for macOS.

Grant Hammerspoon Accessibility Permissions:

Go to System Settings -> Privacy & Security -> Accessibility

Enable Hammerspoon. (If you update the script and it stops working, remove Hammerspoon with the minus (-) button and add it back).

Setup:

Download forcetouchtranslator.lua and place it in your Hammerspoon folder (usually ~/.hammerspoon/).

Open ~/.hammerspoon/init.lua and add this line:

Lua
dofile(os.getenv("HOME") .. "/.hammerspoon/forcetouchtranslator.lua")
Click the Hammerspoon menu bar icon and select Reload Config.

Configuration
You can easily change the target language and ignored apps by editing the CONFIG table at the very top of the forcetouchtranslator.lua file:

Lua
local CONFIG = {
    targetLanguage = "tr", -- Change to "en", "es", "fr", etc.
    ignoredApps    = { "Finder", "Dock" }, -- Apps where the script won't run
    escKeyCode     = 53,
    dragThreshold  = 10,
    fadeStep       = 0.3,
    fadeInterval   = 0.005,
    dictBubbleSize = { w = 340, h = 280 },
    menubarSize    = { w = 350, h = 320 },
}
Known Limitations
On some high-resolution multi-monitor setups, the translation bubble might spawn slightly offset from the cursor.

Heavy Electron apps under full load might occasionally fail to register the 10ms double-click fallback.

License
This project is licensed under the MIT License. Feel free to fork it, break it, and make it better.
