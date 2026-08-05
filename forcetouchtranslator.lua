-- ==============================================================================
-- ForceTouchTranslator for macOS
-- https://github.com/user/ForceTouchTranslator
-- Powered by Hammerspoon
-- ==============================================================================

-- USER CONFIGURATION
local TARGET_LANGUAGE = "tr" -- Target language code (e.g. "tr", "en", "es", "fr", "de")

local IGNORED_APPS = {
    "Finder",
    "Dock"
}

-- ==============================================================================
-- CORE LOGIC
-- ==============================================================================

_G.ForceTouchTranslator = _G.ForceTouchTranslator or {}
local FTT = _G.ForceTouchTranslator

FTT.requestId = 0
FTT.activeBubble = nil
FTT.closeMouseTap = nil
FTT.closeEscapeTap = nil
FTT.fadeTimer = nil
FTT.forceClickDetected = false
FTT.targetPos = nil

local function urlencode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "%%20")
    end
    return str
end

local function escapeHTML(str)
    if not str then return "" end
    str = string.gsub(str, "&", "&amp;")
    str = string.gsub(str, "<", "&lt;")
    str = string.gsub(str, ">", "&gt;")
    str = string.gsub(str, '"', "&quot;")
    str = string.gsub(str, "'", "&#39;")
    return str
end

local function distance(p1, p2)
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2)
end

-- Convert UTF-16 index to UTF-8 byte index and locate word boundaries
local function getWordAroundIndex(text, utf16_index)
    if not text or type(text) ~= "string" then return nil end
    
    local isAscii = not text:match("[%z\128-\255]")
    local byteIdx
    
    if isAscii then
        byteIdx = utf16_index + 1
    else
        local utf8_idx = 1
        local current_utf16_idx = 0
        while current_utf16_idx < utf16_index and utf8_idx <= #text do
            local b = text:byte(utf8_idx)
            if not b then break end
            if b < 0x80 then
                utf8_idx = utf8_idx + 1
                current_utf16_idx = current_utf16_idx + 1
            elseif b >= 0xC0 and b < 0xE0 then
                utf8_idx = utf8_idx + 2
                current_utf16_idx = current_utf16_idx + 1
            elseif b >= 0xE0 and b < 0xF0 then
                utf8_idx = utf8_idx + 3
                current_utf16_idx = current_utf16_idx + 1
            elseif b >= 0xF0 and b < 0xF8 then
                utf8_idx = utf8_idx + 4
                current_utf16_idx = current_utf16_idx + 2
            else
                utf8_idx = utf8_idx + 1
                current_utf16_idx = current_utf16_idx + 1
            end
        end
        byteIdx = utf8_idx
    end
    
    if byteIdx < 1 or byteIdx > #text then return nil end
    
    local startIdx = byteIdx
    while startIdx > 1 do
        local b = text:byte(startIdx - 1)
        if b < 128 then
            local c = string.char(b)
            if c:match("[%s%p]") then break end
        end
        startIdx = startIdx - 1
    end
    
    local endIdx = byteIdx
    while endIdx < #text do
        local b = text:byte(endIdx + 1)
        if b < 128 then
            local c = string.char(b)
            if c:match("[%s%p]") then break end
        end
        endIdx = endIdx + 1
    end
    
    return text:sub(startIdx, endIdx)
end

local function getElementWithRangeSupport(elem)
    while elem do
        local attrs = elem:parameterizedAttributeNames()
        if attrs then
            for _, attr in ipairs(attrs) do
                if attr == "AXRangeForPosition" then return elem end
            end
        end
        elem = elem:attributeValue("AXParent")
    end
    return nil
end

local function getTextAtPosition(pos)
    local system = hs.axuielement.systemWideElement()
    if not system then return nil end
    
    local elem = system:elementAtPosition(pos)
    if not elem then return nil end
    
    local rangeElem = getElementWithRangeSupport(elem) or elem
    local charRange = rangeElem:parameterizedAttributeValue("AXRangeForPosition", pos)
    if type(charRange) == "table" then
        local loc = charRange.loc or charRange.location
        local len = charRange.len or charRange.length
        -- WebKit and Chromium return dummy {location = 0, length = 1} for unsupported AXRangeForPosition queries.
        -- Only accept loc > 0 and len > 0 for native text components.
        if loc and len and loc > 0 and len > 0 then
            -- A. PDF / Native Accessibility
            local startLoc = math.max(0, loc - 50)
            local chunkRange = {loc = startLoc, len = 100, location = startLoc, length = 100}
            local chunk = rangeElem:parameterizedAttributeValue("AXStringForRange", chunkRange)
            
            if type(chunk) == "string" then
                local offset = loc - startLoc
                local word = getWordAroundIndex(chunk, offset)
                if word and word:match("%S") then
                    return word
                end
            end
            
            -- B. Chrome / Electron Accessibility
            local fullText = rangeElem:attributeValue("AXValue") or rangeElem:attributeValue("AXTitle")
            if type(fullText) == "string" then
                local word = getWordAroundIndex(fullText, loc)
                if word and word:match("%S") then
                    return word
                end
            end
        end
    end
    
    return nil
end

-- ==============================================================================
-- APPLE UI POPUP BUBBLE SYSTEM
-- ==============================================================================

local function closeBubble()
    if FTT.fadeTimer then
        FTT.fadeTimer:stop()
        FTT.fadeTimer = nil
    end
    if FTT.activeBubble then
        FTT.activeBubble:delete()
        FTT.activeBubble = nil
    end
    if FTT.closeMouseTap then
        FTT.closeMouseTap:stop()
        FTT.closeMouseTap = nil
    end
    if FTT.closeEscapeTap then
        FTT.closeEscapeTap:stop()
        FTT.closeEscapeTap = nil
    end
end

local function showTranslationBubble(translatedText, targetPos, reqId)
    if reqId and reqId ~= FTT.requestId then return end

    closeBubble() 
    
    local textLen = string.len(translatedText)
    local w, h = 260, 75
    if textLen > 30 then h = 100 end
    if textLen > 80 then h = 130; w = 300 end
    if textLen > 150 then h = 170; w = 340 end
    if textLen > 300 then h = 220; w = 380 end
    
    local screenInfo = hs.screen.find(targetPos)
    local screen = screenInfo and screenInfo:frame() or hs.mouse.getCurrentScreen():frame()
    local x = targetPos.x + 15
    local y = targetPos.y + 15
    
    if x + w > screen.x + screen.w then x = targetPos.x - w - 15 end
    if y + h > screen.y + screen.h then y = targetPos.y - h - 15 end
    
    local rect = hs.geometry.rect(x, y, w, h)
    
    FTT.activeBubble = hs.webview.new(rect)
    FTT.activeBubble:windowStyle({"borderless", "nonactivating", "utility"})
    FTT.activeBubble:transparent(true) 
    FTT.activeBubble:level(hs.drawing.windowLevels.popUpMenu)
    
    local html = [[
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                html, body {
                    background: transparent;
                    margin: 0;
                    padding: 0;
                    height: 100%;
                    overflow: hidden;
                }
                .container {
                    background-color: rgba(28, 28, 30, 0.98);
                    color: #F5F5F7;
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
                    font-size: 14px;
                    border-radius: 10px;
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    height: 100%;
                    box-sizing: border-box;
                    padding: 12px 16px;
                    overflow-y: auto;
                    -webkit-user-select: text;
                    cursor: default;
                }
                .header {
                    font-weight: 600;
                    font-size: 11px;
                    color: #0A84FF;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                    margin-bottom: 6px;
                }
                .content {
                    line-height: 1.4;
                    font-weight: 400;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                }
                ::-webkit-scrollbar { width: 4px; }
                ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 2px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">Translation</div>
                <div class="content">]] .. escapeHTML(translatedText) .. [[</div>
            </div>
        </body>
        </html>
    ]]
    
    FTT.activeBubble:html(html)
    FTT.activeBubble:alpha(0.0)
    FTT.activeBubble:show()
    
    local currentAlpha = 0.0
    FTT.fadeTimer = hs.timer.doEvery(0.015, function()
        currentAlpha = currentAlpha + 0.1
        if FTT.activeBubble then
            if currentAlpha >= 1.0 then
                FTT.activeBubble:alpha(1.0)
                if FTT.fadeTimer then FTT.fadeTimer:stop() end
            else
                FTT.activeBubble:alpha(currentAlpha)
            end
        else
            if FTT.fadeTimer then FTT.fadeTimer:stop() end
        end
    end)
    
    FTT.closeMouseTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown}, function(e)
        local clickPos = hs.mouse.absolutePosition()
        if clickPos.x >= x and clickPos.x <= x + w and clickPos.y >= y and clickPos.y <= y + h then
            return false
        end
        closeBubble()
        return false 
    end)
    FTT.closeMouseTap:start()
    
    FTT.closeEscapeTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(e)
        if e:getKeyCode() == 53 then 
            closeBubble()
            return false 
        end
        return false
    end)
    FTT.closeEscapeTap:start()
end

local function translateAndShow(text, targetPos)
    text = text:match("^%s*(.-)%s*$")
    if text and text ~= "" then
        
        FTT.requestId = FTT.requestId + 1
        local reqId = FTT.requestId
        
        local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" .. TARGET_LANGUAGE .. "&dt=t"
        local headers = { 
            ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
            ["Content-Type"] = "application/x-www-form-urlencoded"
        }
        local bodyContent = "q=" .. urlencode(text)
        
        hs.http.doAsyncRequest(url, "POST", bodyContent, headers, function(status, body, headers)
            if status == 200 then
                local data = hs.json.decode(body)
                if data and data[1] then
                    local translatedText = ""
                    for _, block in ipairs(data[1]) do
                        if block[1] then translatedText = translatedText .. block[1] end
                    end
                    showTranslationBubble(translatedText, targetPos, reqId)
                else
                    hs.alert.show("Translation could not be retrieved.")
                end
            else
                hs.alert.show("Translation API Error: " .. tostring(status))
            end
        end)
    else
        hs.alert.show("Error: No valid text to translate.")
    end
end

-- ==============================================================================
-- SMART TEXT EXTRACTION (SENTENCE & HOVER WORD SUPPORT)
-- ==============================================================================

local function fetchTextAndTranslate(targetPos)
    -- Step 1: Check native Accessibility API selected text (Safari, TextEdit, Pages, Notes, Xcode, etc.)
    local system = hs.axuielement.systemWideElement()
    if system then
        local focused = system:attributeValue("AXFocusedUIElement")
        if focused then
            local selectedText = focused:attributeValue("AXSelectedText")
            if type(selectedText) == "string" and selectedText:match("%S") then
                local trimmed = selectedText:match("^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    translateAndShow(trimmed, targetPos)
                    return
                end
            end
        end
    end

    local oldClipboardData = hs.pasteboard.readAllData()
    local SENTINEL = "__FTT_EMPTY_MARKER_" .. tostring(os.time()) .. "__"
    
    -- Step 2: Check active text selection via Cmd+C (for apps/browsers where AXSelectedText is not exposed)
    hs.pasteboard.setContents(SENTINEL)
    hs.eventtap.keyStroke({"cmd"}, "c", 0)
    
    hs.timer.doAfter(0.06, function()
        local copiedText = hs.pasteboard.getContents()
        
        -- If copied text is not SENTINEL, the user had an active text selection
        if copiedText and copiedText ~= SENTINEL and type(copiedText) == "string" and copiedText:match("%S") then
            local trimmed = copiedText:match("^%s*(.-)%s*$")
            if oldClipboardData then hs.pasteboard.writeAllData(oldClipboardData) end
            translateAndShow(trimmed, targetPos)
            return
        end

        -- Step 3: If NO text was selected, try native AX API (clickless single word for native apps)
        local axWord = getTextAtPosition(targetPos)
        if axWord and type(axWord) == "string" and axWord:match("%S") then
            if oldClipboardData then hs.pasteboard.writeAllData(oldClipboardData) end
            translateAndShow(axWord:match("^%s*(.-)%s*$"), targetPos)
            return
        end

        -- Step 4: Fallback for Web Browsers (Safari, Chrome, Firefox) & Electron apps:
        -- Simulate a precise double-click at targetPos to highlight the single word under cursor
        hs.pasteboard.setContents(SENTINEL)
        local evt = hs.eventtap.event
        local e1 = evt.newMouseEvent(evt.types.leftMouseDown, targetPos)
        e1:setProperty(evt.properties.mouseEventClickState, 1)
        e1:post()
        
        hs.timer.doAfter(0.015, function()
            local e2 = evt.newMouseEvent(evt.types.leftMouseUp, targetPos)
            e2:setProperty(evt.properties.mouseEventClickState, 1)
            e2:post()
            
            hs.timer.doAfter(0.015, function()
                local e3 = evt.newMouseEvent(evt.types.leftMouseDown, targetPos)
                e3:setProperty(evt.properties.mouseEventClickState, 2)
                e3:post()
                
                hs.timer.doAfter(0.015, function()
                    local e4 = evt.newMouseEvent(evt.types.leftMouseUp, targetPos)
                    e4:setProperty(evt.properties.mouseEventClickState, 2)
                    e4:post()
                    
                    hs.timer.doAfter(0.04, function()
                        hs.eventtap.keyStroke({"cmd"}, "c", 0)
                        
                        hs.timer.doAfter(0.08, function()
                            local wordText = hs.pasteboard.getContents()
                            
                            -- Restore user clipboard
                            if oldClipboardData then hs.pasteboard.writeAllData(oldClipboardData) end
                            
                            if wordText and wordText ~= SENTINEL and type(wordText) == "string" and wordText:match("%S") then
                                translateAndShow(wordText:match("^%s*(.-)%s*$"), targetPos)
                            else
                                hs.alert.show("No text found to translate.")
                            end
                        end)
                    end)
                end)
            end)
        end)
    end)
end

-- ==============================================================================
-- MAIN EVENT TAP
-- ==============================================================================

if FTT.tap then FTT.tap:stop() end
if FTT.watchdogTimer then FTT.watchdogTimer:stop() end
if FTT.wakeWatcher then FTT.wakeWatcher:stop() end

FTT.tap = hs.eventtap.new({hs.eventtap.event.types.gesture}, function(event)
    local event_type = event:getType(true)
    
    if event_type == hs.eventtap.event.types.pressure then
        local td = event:getTouchDetails()
        if not td then return false end
        
        if td.stage == 2 and td.pressure > 0.0 then
            if not FTT.forceClickDetected then
                closeBubble()
                
                FTT.forceClickDetected = true
                FTT.targetPos = hs.mouse.absolutePosition()
                
                local app = hs.application.frontmostApplication()
                if app then
                    local appName = app:name()
                    for _, ignoredApp in ipairs(IGNORED_APPS) do
                        if appName == ignoredApp then 
                            FTT.forceClickDetected = false
                            return false 
                        end
                    end
                end
            end
            return true -- Block default macOS dictionary lookup popup
        end
        
        if FTT.forceClickDetected and (td.stage < 2 or td.pressure == 0.0) then
            FTT.forceClickDetected = false
            
            local currentPos = hs.mouse.absolutePosition()
            if distance(FTT.targetPos, currentPos) > 10 then
                return false
            end
            
            fetchTextAndTranslate(FTT.targetPos)
            return true
        end
    end
    
    return false
end)

FTT.tap:start()

FTT.watchdogTimer = hs.timer.doEvery(2, function()
    if FTT.tap and not FTT.tap:isEnabled() then
        FTT.tap:start()
    end
end)

FTT.wakeWatcher = hs.caffeinate.watcher.new(function(eventType)
    if eventType == hs.caffeinate.watcher.screensDidWake or eventType == hs.caffeinate.watcher.systemDidWake then
        if FTT.tap then
            FTT.tap:stop()
            hs.timer.doAfter(2, function()
                FTT.tap:start()
            end)
        end
    end
end)
FTT.wakeWatcher:start()

hs.alert.show("ForceTouchTranslator Active!")
