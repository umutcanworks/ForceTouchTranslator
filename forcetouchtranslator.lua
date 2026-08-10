-- ==============================================================================
-- ForceTouchTranslator for macOS
-- Powered by Hammerspoon
-- ==============================================================================

local CONFIG = {
    targetLanguage = "tr",
    ignoredApps    = { "Finder", "Dock" },
    escKeyCode     = 53,
    dragThreshold  = 10,
    fadeStep       = 0.3,
    fadeInterval   = 0.005,
    dictBubbleSize = { w = 340, h = 280 },
    menubarSize    = { w = 350, h = 320 },
}

CONFIG._ignoredSet = {}
for _, name in ipairs(CONFIG.ignoredApps) do CONFIG._ignoredSet[name] = true end

local LANGUAGES = {
    { code = "auto",  name = "Auto Detect", sourceOnly = true },
    { code = "en",    name = "English" },
    { code = "tr",    name = "Turkish" },
    { code = "es",    name = "Spanish" },
    { code = "fr",    name = "French" },
    { code = "de",    name = "German" },
    { code = "it",    name = "Italian" },
    { code = "ru",    name = "Russian" },
    { code = "zh-CN", name = "Chinese" },
    { code = "ja",    name = "Japanese" },
    { code = "ko",    name = "Korean" },
    { code = "ar",    name = "Arabic" },
}

-- ==============================================================================
-- APP STATE MANAGEMENT
-- ==============================================================================

local AppState = {
    requestId          = 0,
    forceClickDetected = false,
    targetPos          = nil,
    
    lastSourceLang     = "auto",
    lastTargetLang     = CONFIG.targetLanguage,
    lastSourceText     = "",

    tap                = nil,
    watchdogTimer      = nil,
    wakeWatcher        = nil,
    ucc                = nil,
    menubar            = nil,
    
    bubbleWebview      = nil,
    bubbleMouseTap     = nil,
    bubbleEscapeTap    = nil,
    fadeTimer          = nil,
    bubbleReadyData    = nil,

    menubarWebview     = nil,
    menubarMouseTap    = nil
}

local function stopAndNil(key)
    if AppState[key] then pcall(function() AppState[key]:stop() end); AppState[key] = nil end
end

local function deleteAndNil(key)
    if AppState[key] then pcall(function() AppState[key]:delete() end); AppState[key] = nil end
end

-- ==============================================================================
-- UTILITIES
-- ==============================================================================

local function urlencode(str)
    if not str then return str end
    return str:gsub("\n", "\r\n")
              :gsub("([^%w %-%_%.%~])", function(c) return ("%%%02X"):format(c:byte()) end)
              :gsub(" ", "%%20")
end

local function escapeHTML(str)
    if not str then return "" end
    return str:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&#39;")
end

local function escapeJSTemplate(str)
    if not str then return "[]" end
    return str:gsub("`","\\`"):gsub("%$","\\$"):gsub("<","\\u003c")
end

local function distance(p1, p2)
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2)
end

local function trim(s) return s and s:match("^%s*(.-)%s*$") end

-- ==============================================================================
-- HTML / CSS / JS TEMPLATES
-- ==============================================================================

local function buildLangOptions(kind, selected)
    local t = {}
    for _, l in ipairs(LANGUAGES) do
        if not (kind == "target" and l.sourceOnly) then
            local sel = l.code == selected and " selected" or ""
            t[#t + 1] = '<option value="' .. l.code .. '"' .. sel .. '>' .. l.name .. '</option>'
        end
    end
    return table.concat(t, "\n                        ")
end

local SHARED_CSS = [=[
    html, body { background: transparent; margin: 0; padding: 0; height: 100%; overflow: hidden; }
    .container {
        background-color: rgba(28, 28, 30, 0.98); color: #F5F5F7;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
        font-size: 14px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.15);
        height: 100%; box-sizing: border-box; padding: 12px 16px; overflow-y: auto;
        scroll-behavior: smooth; -webkit-user-select: text; cursor: default;
        display: flex; flex-direction: column; gap: 12px;
    }
    .controls {
        display: flex; align-items: center; justify-content: space-between;
        background: rgba(40, 40, 42, 0.85); padding: 8px 12px; border-radius: 10px; flex-shrink: 0;
        position: sticky; top: 0; z-index: 10;
        backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.25);
    }
    select {
        background: transparent; color: #0A84FF; border: none;
        font-size: 13px; font-weight: 600; outline: none;
        cursor: pointer; -webkit-appearance: none; padding-right: 4px;
    }
    select option { background: #1c1c1e; color: #F5F5F7; }
    .text-box { display: flex; flex-direction: column; gap: 4px; }
    .header { font-weight: 600; font-size: 11px; color: #8E8E93; text-transform: uppercase; letter-spacing: 0.5px; }
    .content { line-height: 1.4; font-weight: 400; white-space: pre-wrap; word-wrap: break-word; }
    .translation-header { color: #0A84FF; }
    .dictionary-container { margin-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.1); padding-top: 10px; display: none; }
    .dict-header { font-weight: 600; font-size: 11px; color: #8E8E93; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
    .dict-pos { font-style: italic; color: #A2A2A6; font-size: 12px; margin-bottom: 4px; margin-top: 8px; }
    .dict-entry { display: flex; align-items: baseline; margin-bottom: 6px; }
    .dict-word { font-weight: 500; font-size: 13px; color: #F5F5F7; width: 40%; flex-shrink: 0; padding-right: 8px; box-sizing: border-box; }
    .dict-reverse { font-size: 12px; color: #A2A2A6; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    ::-webkit-scrollbar { width: 5px; }
    ::-webkit-scrollbar-track { background: transparent; margin: 16px 0; }
    ::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.2); border-radius: 3px; }
    ::-webkit-scrollbar-thumb:hover { background: rgba(255, 255, 255, 0.4); }
]=]

local SHARED_JS = [=[
    let textHistory = [];
    function getSourceText() {
        const el = document.getElementById("sourceText");
        return el.tagName === "TEXTAREA" ? el.value : el.innerText;
    }
    function setSourceText(text) {
        const el = document.getElementById("sourceText");
        if (el.tagName === "TEXTAREA") el.value = text; else el.innerText = text;
    }
    function copyTranslation() {
        const textEl = document.getElementById("translatedText");
        if (textEl && textEl.innerText && window.webkit && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({ action: "copy", text: textEl.innerText });
        }
    }
    function renderDictionary(data) {
        const dictContainer = document.getElementById("dictContainer");
        const dictContent = document.getElementById("dictContent");
        dictContent.innerHTML = "";

        if (data && data.length > 1 && Array.isArray(data[1])) {
            dictContainer.style.display = "block";
            data[1].forEach(posGroup => {
                if (!Array.isArray(posGroup)) return;
                if (posGroup[0]) {
                    const el = document.createElement("div"); el.className = "dict-pos"; el.innerText = posGroup[0];
                    dictContent.appendChild(el);
                }
                if (Array.isArray(posGroup[2])) {
                    posGroup[2].forEach(entry => {
                        const row = document.createElement("div"); row.className = "dict-entry";
                        const wordEl = document.createElement("div"); wordEl.className = "dict-word"; wordEl.innerText = entry[0];
                        const revEl = document.createElement("div"); revEl.className = "dict-reverse";
                        if (Array.isArray(entry[1])) revEl.innerText = entry[1].join(", ");
                        row.appendChild(wordEl); row.appendChild(revEl); dictContent.appendChild(row);
                    });
                } else if (Array.isArray(posGroup[1])) {
                    const row = document.createElement("div"); row.className = "dict-entry"; row.innerText = posGroup[1].join(", ");
                    dictContent.appendChild(row);
                }
            });
        } else {
            dictContainer.style.display = "none";
        }
    }

    function emitRenderComplete() {
        if (window.webkit && window.webkit.messageHandlers.ftt) {
            const cont = document.querySelector('.container');
            const oldHeight = cont.style.height;
            cont.style.height = 'auto';
            const actualHeight = cont.offsetHeight;
            cont.style.height = oldHeight;
            window.webkit.messageHandlers.ftt.postMessage({ action: "render_complete", h: actualHeight });
        }
    }

    async function doTranslate(text, sl, tl) {
        const url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=" + sl + "&tl=" + tl + "&dt=t&dt=bd";
        const resp = await fetch(url, {
            method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
            body: "q=" + encodeURIComponent(text)
        });
        return await resp.json();
    }
    function extractTranslation(data) {
        let t = ""; if (data && data[0]) data[0].forEach(b => { if (b[0]) t += b[0]; }); return t;
    }
    function swapLanguages() {
        const ss = document.getElementById("sourceLang");
        const ts = document.getElementById("targetLang");
        let newSrc = ts.value, newTgt = ss.value === "auto" ? "en" : ss.value;
        ss.value = newSrc; ts.value = newTgt;

        const currentSrc = getSourceText();
        const currentTgt = document.getElementById("translatedText").innerText;

        if (textHistory.length > 0) {
            const last = textHistory.pop();
            setSourceText(last.src);
            document.getElementById("translatedText").innerText = last.tgt;
        } else {
            textHistory.push({ src: currentSrc, tgt: currentTgt });
            if (currentTgt && currentTgt !== "Translating..." && !currentTgt.startsWith("Error:")) {
                setSourceText(currentTgt);
            }
        }
        translateText();
    }
    async function translateText() {
        const sourceText = getSourceText().trim();
        const sl = document.getElementById("sourceLang").value;
        const tl = document.getElementById("targetLang").value;
        if (typeof saveState === "function") saveState();
        if (!sourceText) {
            document.getElementById("translatedText").innerText = "";
            document.getElementById("dictContainer").style.display = "none";
            return;
        }
        document.getElementById("translatedText").innerText = "Translating...";
        document.getElementById("dictContainer").style.display = "none";
        try {
            const data = await doTranslate(sourceText, sl, tl);
            document.getElementById("translatedText").innerText = extractTranslation(data);
            renderDictionary(data);
            emitRenderComplete();
        } catch (err) {
            document.getElementById("translatedText").innerText = "Error: " + err.message;
            emitRenderComplete();
        }
    }
]=]

local DICT_SECTION = [=[
                <div class="dictionary-container" id="dictContainer">
                    <div class="dict-header">More translations</div>
                    <div id="dictContent"></div>
                </div>
]=]
local SWAP_SVG   = [=[<svg onclick="swapLanguages()" style="cursor:pointer; width:14px; height:14px; fill:#0A84FF; transition: transform 0.2s;" title="Swap languages" viewBox="0 0 512 512"><path d="M0 168v-16c0-13.3 10.7-24 24-24h360V80c0-21.4 25.9-32.1 41-17l71 71c9.4 9.4 9.4 24.6 0 33.9l-71 71c-15.1 15.1-41 4.4-41-17v-48H24c-13.3 0-24-10.7-24-24zm512 192v16c0 13.3-10.7 24-24 24H128v48c0 21.4-25.9 32.1-41 17l-71-71c-9.4-9.4-9.4-24.6 0-33.9l71-71c15.1-15.1 41-4.4 41 17v48h360c13.3 0 24 10.7 24 24z"/></svg>]=]
local CLEAR_SVG  = [=[<svg onclick="clearText()" style="cursor:pointer; width:12px; height:12px; fill:#8E8E93; opacity: 0.8;" title="Clear Text" viewBox="0 0 384 512"><path d="M342.6 150.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L192 210.7 86.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L146.7 256 41.4 361.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L192 301.3 297.4 406.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L237.3 256 342.6 150.6z"/></svg>]=]
local COPY_SVG   = [=[<svg onclick="copyTranslation()" style="cursor:pointer; width:13px; height:13px; fill:#0A84FF; opacity: 0.8; transition: opacity 0.2s;" onmouseover="this.style.opacity='1'" onmouseout="this.style.opacity='0.8'" title="Copy Translation" viewBox="0 0 448 512"><path d="M208 0H332.1c12.7 0 24.9 5.1 33.9 14.1l67.9 67.9c9 9 14.1 21.2 14.1 33.9V336c0 26.5-21.5 48-48 48H208c-26.5 0-48-21.5-48-48V48c0-26.5 21.5-48 48-48zM48 128h80v64H64V448H256V416h64v40c0 30.9-25.1 56-56 56H48c-30.9 0-56-25.1-56-56V184c0-30.9 25.1-56 56-56z"/></svg>]=]

local function buildBubbleHTML(originalText, translatedText, rawJsonBody)
    return [=[<!DOCTYPE html><html><head><meta charset="utf-8">
        <style>]=] .. SHARED_CSS .. [=[</style>
        </head><body>
            <div class="container">
                <div class="controls">
                    <select id="sourceLang" onchange="textHistory=[]; translateText()">
                        ]=] .. buildLangOptions("source", "auto") .. [=[
                    </select>
                    ]=] .. SWAP_SVG .. [=[
                    <select id="targetLang" onchange="textHistory=[]; translateText()">
                        ]=] .. buildLangOptions("target", CONFIG.targetLanguage) .. [=[
                    </select>
                </div>
                <div class="text-box">
                    <div class="header">Original</div>
                    <div class="content" id="sourceText">]=] .. escapeHTML(originalText) .. [=[</div>
                </div>
                <div class="text-box">
                    <div class="header translation-header" style="display: flex; justify-content: space-between; align-items: center;">
                        <span>Translation</span>
                        ]=] .. COPY_SVG .. [=[
                    </div>
                    <div class="content" id="translatedText">]=] .. escapeHTML(translatedText) .. [=[</div>
                </div>
]=] .. DICT_SECTION .. [=[
            </div>
            <script>
                ]=] .. SHARED_JS .. [=[
                const initialJson = `]=] .. escapeJSTemplate(rawJsonBody) .. [=[`;
                try { renderDictionary(JSON.parse(initialJson)); } catch(e) {}
                emitRenderComplete();
            </script>
        </body></html>]=]
end

local MENUBAR_EXTRA_CSS = [=[
    textarea {
        width: 100%; background: transparent; color: #F5F5F7; border: none;
        font-family: inherit; font-size: 14px; resize: none; outline: none;
        min-height: 70px; padding: 0; line-height: 1.4;
    }
    textarea::placeholder { color: rgba(255, 255, 255, 0.3); }
]=]

local function buildMenubarHTML()
    return [=[<!DOCTYPE html><html><head><meta charset="utf-8">
        <style>]=] .. SHARED_CSS .. MENUBAR_EXTRA_CSS .. [=[</style>
        </head><body>
            <div class="container">
                <div class="controls">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <svg onclick="window.webkit.messageHandlers.ftt.postMessage({action: 'quit'})" style="cursor:pointer; width:16px; height:16px; flex-shrink:0;" title="Quit ForceTouchTranslator" viewBox="0 0 24 24" fill="none" stroke="#FF3B30" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="2" x2="12" y2="12"/><path d="M18.36 6.64A9 9 0 1 1 5.64 6.64"/></svg>
                        <select id="sourceLang" onchange="textHistory=[]; translateText()">
                            ]=] .. buildLangOptions("source", AppState.lastSourceLang) .. [=[
                        </select>
                    </div>
                    ]=] .. SWAP_SVG .. [=[
                    <select id="targetLang" onchange="textHistory=[]; translateText()">
                        ]=] .. buildLangOptions("target", AppState.lastTargetLang) .. [=[
                    </select>
                </div>
                <div class="text-box">
                    <div class="header" style="display: flex; justify-content: space-between; align-items: center;">
                        <span>Original</span>
                        ]=] .. CLEAR_SVG .. [=[
                    </div>
                    <textarea id="sourceText" placeholder="Type text to translate..." oninput="debounceTranslate()">]=] .. escapeHTML(AppState.lastSourceText) .. [=[</textarea>
                </div>
                <div class="text-box">
                    <div class="header translation-header" style="display: flex; justify-content: space-between; align-items: center;">
                        <span>Translation</span>
                        ]=] .. COPY_SVG .. [=[
                    </div>
                    <div class="content" id="translatedText"></div>
                </div>
]=] .. DICT_SECTION .. [=[
            </div>
            <script>
                ]=] .. SHARED_JS .. [=[
                let _debounceTimer = null;
                function debounceTranslate() {
                    textHistory = [];
                    clearTimeout(_debounceTimer);
                    _debounceTimer = setTimeout(translateText, 400);
                }
                function saveState() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ftt) {
                        window.webkit.messageHandlers.ftt.postMessage({
                            action: "save",
                            sl: document.getElementById("sourceLang").value,
                            tl: document.getElementById("targetLang").value,
                            text: document.getElementById("sourceText").value
                        });
                    }
                }
                function clearText() {
                    document.getElementById("sourceText").value = "";
                    saveState(); translateText(); document.getElementById("sourceText").focus();
                }
                setTimeout(() => {
                    document.getElementById("sourceText").focus();
                    if (document.getElementById("sourceText").value.trim() !== "") translateText();
                }, 100);
            </script>
        </body></html>]=]
end

-- ==============================================================================
-- UI TEARDOWN & LIFECYCLE
-- ==============================================================================

local function destroyBubble()
    stopAndNil("fadeTimer")
    stopAndNil("bubbleMouseTap")
    stopAndNil("bubbleEscapeTap")
    if AppState.bubbleWebview then
        AppState.bubbleWebview:alpha(0)
        AppState.bubbleWebview:hide() 
    end
    AppState.bubbleReadyData = nil
end

local function destroyMenubar()
    stopAndNil("menubarMouseTap")
    if AppState.menubarWebview then
        AppState.menubarWebview:alpha(0)
        deleteAndNil("menubarWebview")
    end
end

-- ==============================================================================
-- WEBVIEW MESSAGE HANDLER
-- ==============================================================================

if AppState.ucc then pcall(function() AppState.ucc:removeAllCallbacks() end) end
AppState.ucc = hs.webview.usercontent.new("ftt")
AppState.ucc:setCallback(function(msg)
    if not msg.body then return end
    if msg.body.action == "quit" then
        hs.alert.show("Exiting ForceTouchTranslator...")
        stopAndNil("tap")
        stopAndNil("watchdogTimer")
        stopAndNil("wakeWatcher")
        destroyBubble()
        destroyMenubar()
        deleteAndNil("menubar")
    elseif msg.body.action == "save" then
        if msg.body.sl then AppState.lastSourceLang = msg.body.sl end
        if msg.body.tl then AppState.lastTargetLang = msg.body.tl end
        if msg.body.text ~= nil then AppState.lastSourceText = msg.body.text end
    elseif msg.body.action == "render_complete" then
        if AppState.bubbleWebview and AppState.bubbleReadyData and msg.body.h then
            local f = AppState.bubbleWebview:frame()
            f.h = math.min(msg.body.h, 420)
            
            if AppState.bubbleReadyData.screen then
                local s = AppState.bubbleReadyData.screen
                if f.y + f.h > s.y + s.h then f.y = s.y + s.h - f.h - 15 end
            end
            
            AppState.bubbleWebview:frame(f)
            AppState.bubbleWebview:alpha(1.0)
        elseif AppState.menubarWebview and msg.body.h then
            local f = AppState.menubarWebview:frame()
            f.h = math.min(msg.body.h, 420)
            AppState.menubarWebview:frame(f)
        end
    elseif msg.body.action == "copy" then
        if msg.body.text then
            hs.pasteboard.setContents(msg.body.text)
            hs.alert.show("Translation copied!")
        end
    end
end)

-- ==============================================================================
-- BUBBLE POPUP GENERATION
-- ==============================================================================

local function calcInitialBubbleWidth(originalText, translatedText, hasDictionary)
    if hasDictionary then return CONFIG.dictBubbleSize.w end
    local totalLen = #originalText + #translatedText
    return math.floor(math.min(420, math.max(320, 320 + (totalLen - 60) * 0.4)))
end

local function showTranslationBubble(originalText, translatedText, rawJsonBody, targetPos, reqId)
    if reqId and reqId ~= AppState.requestId then return end
    destroyBubble()

    local hasDictionary = false
    if rawJsonBody then
        local ok, data = pcall(hs.json.decode, rawJsonBody)
        if ok and data and data[2] then hasDictionary = true end
    end
    
    local w = calcInitialBubbleWidth(originalText, translatedText, hasDictionary)
    local h = 420

    local screen = (hs.screen.find(targetPos) or hs.mouse.getCurrentScreen()):frame()
    local x = targetPos.x + 15
    local y = targetPos.y + 15
    if x + w > screen.x + screen.w then x = targetPos.x - w - 15 end
    if y + h > screen.y + screen.h then y = targetPos.y - h - 15 end

    local rect = hs.geometry.rect(x, y, w, h)
    if not AppState.bubbleWebview then
        AppState.bubbleWebview = hs.webview.new(rect, {developerExtrasEnabled = true}, AppState.ucc)
        AppState.bubbleWebview:windowStyle({"borderless", "nonactivating", "utility"})
        AppState.bubbleWebview:transparent(true)
        AppState.bubbleWebview:level(hs.drawing.windowLevels.popUpMenu)
    else
        AppState.bubbleWebview:frame(rect)
    end
    AppState.bubbleWebview:alpha(0.0)
    
    AppState.bubbleReadyData = { screen = screen }
    
    AppState.bubbleWebview:html(buildBubbleHTML(originalText, translatedText, rawJsonBody))
    AppState.bubbleWebview:show()

    AppState.bubbleMouseTap = hs.eventtap.new(
        { hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown },
        function()
            if AppState.bubbleWebview then
                local p = hs.mouse.absolutePosition()
                local f = AppState.bubbleWebview:frame()
                if p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h then return false end
            end
            destroyBubble()
            return false
        end
    )
    AppState.bubbleMouseTap:start()

    AppState.bubbleEscapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
        if e:getKeyCode() == CONFIG.escKeyCode then destroyBubble() end
        return false
    end)
    AppState.bubbleEscapeTap:start()
end

-- ==============================================================================
-- TEXT EXTRACTION
-- ==============================================================================

local function getWordAroundIndex(text, utf16_index)
    if not text or type(text) ~= "string" then return nil end

    local byteIdx
    if not text:match("[%z\128-\255]") then
        byteIdx = utf16_index + 1
    else
        local u8, u16 = 1, 0
        while u16 < utf16_index and u8 <= #text do
            local b = text:byte(u8)
            if not b then break end
            local n = (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
            u8  = u8 + n
            u16 = u16 + (n == 4 and 2 or 1)
        end
        byteIdx = u8
    end

    if byteIdx < 1 or byteIdx > #text then return nil end

    local s = byteIdx
    while s > 1 do
        local b = text:byte(s - 1)
        if b < 128 and string.char(b):match("[%s%p]") then break end
        s = s - 1
    end

    local e = byteIdx
    while e < #text do
        local b = text:byte(e + 1)
        if b < 128 and string.char(b):match("[%s%p]") then break end
        e = e + 1
    end

    return text:sub(s, e)
end

local function getElementWithRangeSupport(elem)
    while elem do
        local attrs = elem:parameterizedAttributeNames()
        if attrs then
            for _, a in ipairs(attrs) do
                if a == "AXRangeForPosition" then return elem end
            end
        end
        elem = elem:attributeValue("AXParent")
    end
    return nil
end

local function tryNativeAXExtraction(pos)
    local sys = hs.axuielement.systemWideElement()
    if not sys then return nil end
    
    local focused = sys:attributeValue("AXFocusedUIElement")
    if focused then
        local sel = focused:attributeValue("AXSelectedText")
        if type(sel) == "string" and sel:match("%S") then return sel end
    end
    
    local elem = sys:elementAtPosition(pos)
    if not elem then return nil end

    local rangeElem = getElementWithRangeSupport(elem)
    if rangeElem then
        local cr = rangeElem:parameterizedAttributeValue("AXRangeForPosition", pos)
        if type(cr) == "table" and cr.location and cr.length then
            local loc = cr.loc or cr.location
            local startLoc = math.max(0, loc - 50)
            local chunkRange = { loc = startLoc, len = 100, location = startLoc, length = 100 }
            local chunk = rangeElem:parameterizedAttributeValue("AXStringForRange", chunkRange)
            if type(chunk) == "string" then
                local w = getWordAroundIndex(chunk, loc - startLoc)
                if w and w:match("%S") then return w end
            end
        end
    end

    return nil 
end

local function translateAndShow(text, targetPos)
    text = trim(text)
    if not text or text == "" then return end

    AppState.requestId = AppState.requestId + 1
    local reqId = AppState.requestId
    local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" .. CONFIG.targetLanguage .. "&dt=t&dt=bd"
    
    local headers = {
        ["User-Agent"]    = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
        ["Content-Type"]  = "application/x-www-form-urlencoded",
        ["Cache-Control"] = "no-cache",
        ["Connection"]    = "keep-alive"
    }

    hs.http.doAsyncRequest(url, "POST", "q=" .. urlencode(text), headers, function(status, body)
        if status == 200 then
            local data = hs.json.decode(body)
            if data and data[1] then
                local translated = ""
                for _, block in ipairs(data[1]) do
                    if block[1] then translated = translated .. block[1] end
                end
                showTranslationBubble(text, translated, body, targetPos, reqId)
            else
                hs.alert.show("Translation could not be retrieved.")
            end
        else
            hs.alert.show("Translation API Error: " .. tostring(status))
        end
    end)
end

-- ==============================================================================
-- DOUBLE-CLICK SIMULATOR
-- ==============================================================================

local function doDoubleClick(pos)
    local e1D = hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, pos)
    e1D:setProperty(hs.eventtap.event.properties.mouseEventClickState, 1)
    local e1U = hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, pos)
    e1U:setProperty(hs.eventtap.event.properties.mouseEventClickState, 1)
    
    local e2D = hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseDown, pos)
    e2D:setProperty(hs.eventtap.event.properties.mouseEventClickState, 2)
    local e2U = hs.eventtap.event.newMouseEvent(hs.eventtap.event.types.leftMouseUp, pos)
    e2U:setProperty(hs.eventtap.event.properties.mouseEventClickState, 2)
    
    e1D:post(); e1U:post()
    e2D:post(); e2U:post()
end

local function fallbackExtractionAndTranslate(pos)
    local oldClip = hs.pasteboard.getContents()
    hs.pasteboard.clearContents()

    hs.timer.doAfter(0.02, function()
        doDoubleClick(pos)

        hs.timer.doAfter(0.05, function()
            hs.eventtap.keyStroke({"cmd"}, "c", 0)
            
            hs.timer.doAfter(0.05, function()
                local text = hs.pasteboard.getContents()
                
                if oldClip then hs.pasteboard.setContents(oldClip) else hs.pasteboard.clearContents() end
                
                if text and type(text) == "string" and text:match("%S") then
                    translateAndShow(text, pos)
                else
                    hs.alert.show("No text found under cursor.")
                end
            end)
        end)
    end)
end

-- ==============================================================================
-- MAIN EVENT TAP (FORCE TOUCH)
-- ==============================================================================

if AppState.tap then AppState.tap:stop() end
if AppState.watchdogTimer then AppState.watchdogTimer:stop() end
if AppState.wakeWatcher then AppState.wakeWatcher:stop() end

AppState.tap = hs.eventtap.new({ hs.eventtap.event.types.gesture }, function(event)
    local event_type = event:getType(true)
    if event_type ~= hs.eventtap.event.types.pressure then return false end

    local td = event:getTouchDetails()
    if not td then return false end

    if td.stage == 2 and td.pressure > 0.0 then
        if not AppState.forceClickDetected then
            destroyBubble()
            AppState.forceClickDetected = true
            AppState.targetPos = hs.mouse.absolutePosition()

            local app = hs.application.frontmostApplication()
            if app and CONFIG._ignoredSet[app:name()] then
                AppState.forceClickDetected = false
                return false
            end
        end
        return true 
    end

    if AppState.forceClickDetected and (td.stage < 2 or td.pressure == 0.0) then
        AppState.forceClickDetected = false
        if distance(AppState.targetPos, hs.mouse.absolutePosition()) > CONFIG.dragThreshold then return false end
        
        local currentTargetPos = AppState.targetPos 
        
        hs.timer.doAfter(0.01, function()
            local nativeText = tryNativeAXExtraction(currentTargetPos)
            
            if nativeText and type(nativeText) == "string" and nativeText:match("%S") then
                translateAndShow(nativeText, currentTargetPos)
            else
                fallbackExtractionAndTranslate(currentTargetPos)
            end
        end)
        
        return true 
    end

    return false
end)
AppState.tap:start()

AppState.watchdogTimer = hs.timer.doEvery(2, function()
    if AppState.tap and not AppState.tap:isEnabled() then AppState.tap:start() end
end)

AppState.wakeWatcher = hs.caffeinate.watcher.new(function(eventType)
    if eventType == hs.caffeinate.watcher.screensDidWake or eventType == hs.caffeinate.watcher.systemDidWake then
        if AppState.tap then
            AppState.tap:stop()
            hs.timer.doAfter(2, function() AppState.tap:start() end)
        end
    end
end)
AppState.wakeWatcher:start()

-- ==============================================================================
-- MENUBAR UI
-- ==============================================================================

if AppState.menubar then AppState.menubar:delete() end
AppState.menubar = hs.menubar.new()

local MENUBAR_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAQAAABLCVATAAABm0lEQVRIx+WUvUoDQRRGj2hQsTaFVbAPqFgEURQhiIVGEBv1HeIbbC/+IFgI9lpGUfANUogQOwuLgI2oaBL/iqD5LHZcNtnd7MZUwTvV3jtzZu/MYeAfhhDqdJBlFkUdVueAwqKXJ8Q93e0e+xpCbLeL6eIKUSPZ2rILhFhxZZYR4qzV/VPUEHcMmO9+bhE1xltv5QghNs3XFkIc/+VMhighvlkA0nwhnom76lmEeCQWjlpFiBLzvCDEel21YGzKRPmrQ5d++3WVESefiwKKkTfT8w0t7DqgKoNR7q5sppdJ1W3wiKiaC8mGYSaouFqrMOFUMghxwihCFJpjpnhDiCIzFBHilUlTyyHEEnCNECPBmGneDSYBJAzqjWFgkKpz8RsIsRuEmeXDhcFBlehzDNoDIO6CeiLtwfyiDlwGjZn8aZBNc3z6YGxU0jHoHcuMc3+bergJwHgNcg8fmxIUm2Bsg/yGj02JQMyvQZdOYxaWeRkKrb0JtkGLDdlQmxrDNujBc9khNnnDNmjHk29qk18UAlvIRX+bOjZ+AKiBMJJvYTH2AAAAAElFTkSuQmCC"
local iconImg = hs.image.imageFromURL("data:image/png;base64," .. MENUBAR_ICON_B64)
if iconImg then
    iconImg:size({w=18, h=18})
    iconImg:template(true)
    AppState.menubar:setIcon(iconImg)
end

local function toggleMenubar()
    if AppState.menubarWebview then destroyMenubar(); return end

    local frame = AppState.menubar:frame()
    if not frame then return end

    local w, h = CONFIG.menubarSize.w, CONFIG.menubarSize.h
    local x = frame.x - (w / 2) + (frame.w / 2)
    local y = frame.y + frame.h + 5

    local screen = hs.mouse.getCurrentScreen():frame()
    if x + w > screen.x + screen.w then x = screen.x + screen.w - w - 10 end

    local rect = hs.geometry.rect(x, y, w, h)

    AppState.menubarWebview = hs.webview.new(rect, { developerExtrasEnabled = true }, AppState.ucc)
    AppState.menubarWebview:windowStyle({"borderless"})
    AppState.menubarWebview:transparent(true)
    AppState.menubarWebview:level(hs.drawing.windowLevels.popUpMenu)
    if AppState.menubarWebview.allowTextEntry then AppState.menubarWebview:allowTextEntry(true) end

    AppState.menubarWebview:html(buildMenubarHTML())
    AppState.menubarWebview:show()

    hs.timer.doAfter(0.05, function()
        if AppState.menubarWebview then
            hs.application.get("Hammerspoon"):activate()
            AppState.menubarWebview:bringToFront(true)
        end
    end)

    AppState.menubarMouseTap = hs.eventtap.new(
        { hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown },
        function()
            local p = hs.mouse.absolutePosition()
            if p.x >= x and p.x <= x + w and p.y >= y and p.y <= y + h then return false end
            if p.y <= frame.y + frame.h and p.x >= frame.x and p.x <= frame.x + frame.w then return false end
            destroyMenubar()
            return false
        end
    )
    AppState.menubarMouseTap:start()
end

AppState.menubar:setClickCallback(toggleMenubar)
hs.alert.show("ForceTouchTranslator Active!")