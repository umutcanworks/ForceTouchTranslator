-- ==============================================================================
-- ForceTouchTranslator for macOS (v3.0 - macOS 27.2, Preview & Native Liquid Glass)
-- Powered by Hammerspoon
-- ==============================================================================
---@diagnostic disable: undefined-global

-- Clean up any previous instance if config is reloaded via dofile()
if _G.__FTT_CLEANUP then
    pcall(_G.__FTT_CLEANUP)
end

pcall(function() hs.allowAppleScript(true) end)

local CONFIG = {
    version        = "3.0",
    targetLanguage = "tr",
    ignoredApps    = { "Finder", "Dock", "QuickLookUIService", "loginwindow", "ScreenSaverEngine" },
    ignoredBundleIDs = {
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.QuickLookUIService",
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
    },
    nativeBlacklist = { "Preview", "Önizleme", "Skim", "Adobe Acrobat", "Adobe Acrobat Reader" },
    nativeBlacklistBundleIDs = {
        "com.apple.Preview",
        "net.sourceforge.skim-app.skim",
        "com.adobe.Reader",
        "com.adobe.Acrobat.Pro",
    },
    escKeyCode       = 53,
    dragThreshold    = 10,
    minDragSelectDist= 7,
    selectionPadding = { x = 45, y = 35 },
    selectionTTL     = 60,
    dictBubbleSize   = { w = 375, h = 290 },
    menubarSize      = { w = 375, h = 350 },
    maxBubbleHeight  = 470,
    cacheMaxEntries  = 50,
}

local function toLookupSet(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[v] = true end
    return s
end

CONFIG._ignoredSet               = toLookupSet(CONFIG.ignoredApps)
CONFIG._ignoredBundleSet         = toLookupSet(CONFIG.ignoredBundleIDs)
CONFIG._nativeBlacklistSet       = toLookupSet(CONFIG.nativeBlacklist)
CONFIG._nativeBlacklistBundleSet = toLookupSet(CONFIG.nativeBlacklistBundleIDs)

-- Expanded Popular Languages + Default macOS Voice Assistants per language
local LANGUAGES = {
    { code = "auto",  name = "Auto Detect",          sourceOnly = true },
    { code = "en",    name = "English",              locale = "en_US", voice = "Samantha (English (US))" },
    { code = "tr",    name = "Turkish",              locale = "tr_TR", voice = "Yelda (Turkish (Türkiye))" },
    { code = "de",    name = "German",               locale = "de_DE", voice = "Anna" },
    { code = "fr",    name = "French",               locale = "fr_FR", voice = "Thomas" },
    { code = "es",    name = "Spanish",              locale = "es_ES", voice = "Mónica" },
    { code = "it",    name = "Italian",              locale = "it_IT", voice = "Alice" },
    { code = "pt",    name = "Portuguese",           locale = "pt_BR", voice = "Luciana" },
    { code = "ru",    name = "Russian",              locale = "ru_RU", voice = "Milena" },
    { code = "nl",    name = "Dutch",                locale = "nl_NL", voice = "Xander" },
    { code = "pl",    name = "Polish",               locale = "pl_PL", voice = "Zosia" },
    { code = "uk",    name = "Ukrainian",            locale = "uk_UA", voice = "Lesya" },
    { code = "az",    name = "Azerbaijani",          locale = "tr_TR", voice = "Yelda (Turkish (Türkiye))" },
    { code = "ar",    name = "Arabic",               locale = "ar_001",voice = "Majed" },
    { code = "zh-CN", name = "Chinese (Simplified)", locale = "zh_CN", voice = "Tingting" },
    { code = "zh-TW", name = "Chinese (Traditional)",locale = "zh_TW", voice = "Meijia" },
    { code = "ja",    name = "Japanese",             locale = "ja_JP", voice = "Kyoko" },
    { code = "ko",    name = "Korean",               locale = "ko_KR", voice = "Yuna" },
    { code = "hi",    name = "Hindi",                locale = "hi_IN", voice = "Lekha" },
    { code = "el",    name = "Greek",                locale = "el_GR", voice = "Melina" },
    { code = "sv",    name = "Swedish",              locale = "sv_SE", voice = "Alva" },
    { code = "no",    name = "Norwegian",            locale = "nb_NO", voice = "Nora" },
    { code = "da",    name = "Danish",               locale = "da_DK", voice = "Sara" },
    { code = "fi",    name = "Finnish",              locale = "fi_FI", voice = "Satu" },
    { code = "cs",    name = "Czech",                locale = "cs_CZ", voice = "Zuzana" },
    { code = "ro",    name = "Romanian",             locale = "ro_RO", voice = "Ioana" },
    { code = "hu",    name = "Hungarian",            locale = "hu_HU", voice = "Tünde" },
    { code = "bg",    name = "Bulgarian",            locale = "bg_BG", voice = "Daria" },
    { code = "sk",    name = "Slovak",               locale = "sk_SK", voice = "Laura" },
    { code = "hr",    name = "Croatian",             locale = "hr_HR", voice = "Lana" },
    { code = "sl",    name = "Slovenian",            locale = "sl_SI", voice = "Tina" },
    { code = "ca",    name = "Catalan",              locale = "ca_ES", voice = "Montse" },
    { code = "lt",    name = "Lithuanian",           locale = "lt_LT", voice = "Ona" },
    { code = "kk",    name = "Kazakh",               locale = "kk_KZ", voice = "Aru" },
    { code = "he",    name = "Hebrew",               locale = "he_IL", voice = "Carmit" },
    { code = "id",    name = "Indonesian",           locale = "id_ID", voice = "Damayanti" },
    { code = "ms",    name = "Malay",                locale = "ms_MY", voice = "Amira" },
    { code = "vi",    name = "Vietnamese",           locale = "vi_VN", voice = "Linh" },
    { code = "th",    name = "Thai",                 locale = "th_TH", voice = "Kanya" },
    { code = "bn",    name = "Bengali",              locale = "bn_IN", voice = "Piya" },
    { code = "ta",    name = "Tamil",                locale = "ta_IN", voice = "Vani" },
    { code = "fa",    name = "Persian (Farsi)",      locale = "ar_001",voice = "Majed" },
}

local LANG_NAMES   = {}
local LANG_LOCALES = {}
local LANG_VOICES  = {}
for _, l in ipairs(LANGUAGES) do
    LANG_NAMES[l.code]   = l.name
    if l.locale then LANG_LOCALES[l.code] = l.locale end
    if l.voice  then LANG_VOICES[l.code]  = l.voice  end
end

-- ==============================================================================
-- APP STATE MANAGEMENT
-- ==============================================================================

local savedSourceLang = hs.settings.get("ftt.sourceLang") or "auto"
local savedTargetLang = hs.settings.get("ftt.targetLang") or CONFIG.targetLanguage

local AppState = {
    requestId             = 0,
    forceClickDetected    = false,
    ignoreCurrentClick    = false,
    dispatchedOnStage2    = false,
    isWakingUp            = false,
    isSyntheticClick      = false,
    targetPos             = nil,

    lastSourceLang        = savedSourceLang,
    lastTargetLang        = savedTargetLang,
    lastSourceText        = "",

    -- Smart selection tracking for Preview & multi-word selections
    dragStartPos          = nil,
    dragBounds            = nil,
    isDragging            = false,
    manualSelection       = nil, -- { text, bounds, time, appPID, needsClipboard }
    selectionCaptureTimer = nil,

    -- LRU Translation Cache
    cache                 = {},
    cacheOrder            = {},

    -- EventTaps, Watchers & Controllers
    tap                   = nil,
    selectionTap          = nil,
    watchdogTimer         = nil,
    wakeWatcher           = nil,
    ucc                   = nil,
    menubar               = nil,
    sayTask               = nil,
    nativeBridge          = nil,

    -- Bubble WebKit State
    bubbleWebview         = nil,
    bubbleMouseTap        = nil,
    bubbleEscapeTap       = nil,
    bubbleReadyData       = nil,
    bubblePinned          = false,

    -- Menubar WebKit State
    menubarWebview        = nil,
    menubarMouseTap       = nil,
    previousApp           = nil,
}

local function stopAndNil(key)
    if AppState[key] then pcall(function() AppState[key]:stop() end); AppState[key] = nil end
end

local function deleteAndNil(key)
    if AppState[key] then pcall(function() AppState[key]:delete() end); AppState[key] = nil end
end

-- ==============================================================================
-- NATIVE LIQUID GLASS (NSGlassEffectView), WINDOW DRAG & MULTI-LANGUAGE TTS (v3.0)
-- ==============================================================================
-- Compiles a tiny Objective-C bridge once into ~/.hammerspoon/.ftt_native_v30.so
-- to provide:
-- 1) Genuine macOS 26/27 AppKit `NSGlassEffectView` synchronized with the user's
--    macOS System Settings -> Appearance -> Liquid Glass slider (`NSGlassTintAmount`)
--    with zero secondary blur overlay (`inputFaceOpacity = 1.0`)
-- 2) Smooth native NSWindow dragging from any empty area inside WKWebView
-- 3) Native `NSSpeechSynthesizer` voice selection by locale (bypassing Hammerspoon's
--    legacy `com.apple.speech.synthesis.voice.` prefix bug in `hs.speech`)

local NATIVE_OBJC_SOURCE = [=[
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>

typedef struct lua_State lua_State;
extern void *luaL_checkudata(lua_State *L, int ud, const char *tname);
extern const char *luaL_checklstring(lua_State *L, int arg, size_t *l);
extern void lua_pushboolean(lua_State *L, int b);
extern void lua_pushcclosure(lua_State *L, int (*fn)(lua_State *), int n);
extern void lua_setfield(lua_State *L, int idx, const char *k);
extern void lua_createtable(lua_State *L, int narr, int nrec);

// Reads macOS System Settings -> Appearance -> Liquid Glass slider ("NSGlassTintAmount" in [0.0, 1.0])
static double readSystemGlassTintAmount(void) {
    CFPreferencesAppSynchronize(kCFPreferencesAnyApplication);
    CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("NSGlassTintAmount"), kCFPreferencesAnyApplication);
    double tint = 0.5; // Default balanced middle tick
    if (val) {
        if (CFGetTypeID(val) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)val, kCFNumberDoubleType, &tint);
        }
        CFRelease(val);
    }
    if (tint < 0.0) tint = 0.0;
    if (tint > 1.0) tint = 1.0;
    return tint;
}

static void tuneGlassBackdrop(CALayer *layer, double t) {
    if (!layer) return;
    if ([NSStringFromClass([layer class]) isEqualToString:@"CABackdropLayer"]) {
        @try {
            // Scale lens diffusion and internal smoked-glass tint with user's Liquid Glass slider t in [0.0, 1.0]
            double blurRadius    = 1.8 + (t * 5.0);  // 1.8 (Clear/Left) -> 4.3 (Mid) -> 6.8 (Tinted/Right)
            double darkenOpacity = 0.22 + (t * 0.46); // 0.22 (Clear/Left) -> 0.45 (Mid) -> 0.68 (Tinted/Right)
            double normalOpacity = 0.06 + (t * 0.42); // 0.06 (Clear/Left) -> 0.27 (Mid) -> 0.48 (Tinted/Right)

            [layer setValue:@(blurRadius)    forKeyPath:@"filters.glassBackground.inputBlurRadius"];
            [layer setValue:@(0.0)           forKeyPath:@"filters.glassBackground.inputBlurFillBlurRadius"];
            [layer setValue:@(1.0)           forKeyPath:@"filters.glassBackground.inputFaceOpacity"];
            [layer setValue:@(darkenOpacity) forKeyPath:@"filters.glassBackground.inputBlurFillDarkenOpacity"];
            [layer setValue:@(normalOpacity) forKeyPath:@"filters.glassBackground.inputBlurFillNormalOpacity"];
            [layer setValue:@(-62.0)         forKeyPath:@"filters.glassBackground.inputInnerRefractionAmount"];
            [layer setValue:@(22.0)          forKeyPath:@"filters.glassBackground.inputInnerRefractionHeight"];
        } @catch (NSException *e) {}
    }
    for (CALayer *sub in layer.sublayers) {
        tuneGlassBackdrop(sub, t);
    }
}

@interface FTTGlassHostView : NSView
@end
@implementation FTTGlassHostView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onGlassSystemPrefChanged:)
                                                     name:@"NSGlassEffectDiffusionDidChangeNotification"
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onGlassSystemPrefChanged:)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)onGlassSystemPrefChanged:(NSNotification *)note {
    tuneGlassBackdrop(self.layer, readSystemGlassTintAmount());
}
- (NSInteger)tag { return 99421; }
- (void)layout {
    [super layout];
    for (NSView *sub in self.subviews) {
        [sub layoutSubtreeIfNeeded];
    }
    tuneGlassBackdrop(self.layer, readSystemGlassTintAmount());
}
@end

static NSSpeechSynthesizer *gSynth = nil;
static id gDragLocalMonitor = nil;
static id gDragGlobalMonitor = nil;
static __weak NSWindow *gDragWin = nil;
static NSPoint gDragStartMouse;
static NSPoint gDragStartOrigin;

static void stopWindowDrag(void) {
    if (gDragLocalMonitor) {
        [NSEvent removeMonitor:gDragLocalMonitor];
        gDragLocalMonitor = nil;
    }
    if (gDragGlobalMonitor) {
        [NSEvent removeMonitor:gDragGlobalMonitor];
        gDragGlobalMonitor = nil;
    }
    gDragWin = nil;
}

static void startWindowDrag(NSWindow *win) {
    stopWindowDrag();
    if (!win) return;
    gDragWin = win;
    gDragStartMouse = [NSEvent mouseLocation];
    gDragStartOrigin = win.frame.origin;

    void (^handleEvent)(NSEvent *) = ^(NSEvent *ev) {
        NSWindow *strongWin = gDragWin;
        if (!strongWin || ev.type == NSEventTypeLeftMouseUp) {
            stopWindowDrag();
            return;
        }
        if (ev.type == NSEventTypeLeftMouseDragged) {
            NSPoint curMouse = [NSEvent mouseLocation];
            CGFloat dx = curMouse.x - gDragStartMouse.x;
            CGFloat dy = curMouse.y - gDragStartMouse.y;
            [strongWin setFrameOrigin:NSMakePoint(gDragStartOrigin.x + dx, gDragStartOrigin.y + dy)];
        }
    };

    NSEventMask mask = NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp;
    gDragLocalMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *ev) {
        handleEvent(ev);
        return ev;
    }];
    gDragGlobalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:mask handler:^(NSEvent *ev) {
        handleEvent(ev);
    }];
}

static int start_window_drag(lua_State *L) {
    void **ud = (void **)luaL_checkudata(L, 1, "hs.webview");
    if (!ud || !*ud) {
        lua_pushboolean(L, 0);
        return 1;
    }
    NSWindow *win = (__bridge NSWindow *)(*ud);
    startWindowDrag(win);
    lua_pushboolean(L, 1);
    return 1;
}

static int stop_window_drag(lua_State *L) {
    stopWindowDrag();
    lua_pushboolean(L, 1);
    return 1;
}

static int apply_liquid_glass(lua_State *L) {
    void **ud = (void **)luaL_checkudata(L, 1, "hs.webview");
    if (!ud || !*ud) {
        lua_pushboolean(L, 0);
        return 1;
    }
    double radius = 16.0;
    NSWindow *win = (__bridge NSWindow *)(*ud);
    if (!win || !win.contentView) {
        lua_pushboolean(L, 0);
        return 1;
    }

    [win setOpaque:NO];
    [win setBackgroundColor:[NSColor clearColor]];
    [win setHasShadow:YES];
    [win setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]];

    NSView *wv = win.contentView;
    @try {
        [wv setValue:@(NO) forKey:@"drawsBackground"];
    } @catch (NSException *e) {}

    NSView *superview = wv.superview;
    if (!superview) {
        lua_pushboolean(L, 0);
        return 1;
    }
    superview.wantsLayer = YES;
    if (superview.layer) {
        superview.layer.cornerRadius = radius;
        superview.layer.masksToBounds = YES;
        superview.layer.backgroundColor = [[NSColor clearColor] CGColor];
    }

    double tintAmount = readSystemGlassTintAmount();

    for (NSView *sub in superview.subviews) {
        if (sub.tag == 99421) {
            sub.frame = superview.bounds;
            [sub layoutSubtreeIfNeeded];
            [superview displayIfNeeded];
            [win displayIfNeeded];
            tuneGlassBackdrop(sub.layer, tintAmount);
            lua_pushboolean(L, 1);
            return 1;
        }
    }

    FTTGlassHostView *host = [[FTTGlassHostView alloc] initWithFrame:superview.bounds];
    host.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    host.wantsLayer = YES;
    host.layer.cornerRadius = radius;
    host.layer.masksToBounds = YES;

    // macOS 26/27 Native NSGlassEffectView synchronized with NSGlassTintAmount
    Class glassCls = NSClassFromString(@"NSGlassEffectView");
    if (glassCls) {
        NSView *glass = [[glassCls alloc] initWithFrame:host.bounds];
        glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        glass.wantsLayer = YES;
        @try {
            [glass setValue:@(0) forKey:@"style"];
            [glass setValue:@(radius) forKey:@"cornerRadius"];
            [glass setValue:@(0) forKey:@"_subduedState"];
        } @catch (NSException *e) {}
        [host addSubview:glass];
    } else {
        // Fallback for older macOS versions without NSGlassEffectView
        NSVisualEffectView *vev = [[NSVisualEffectView alloc] initWithFrame:host.bounds];
        vev.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        vev.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        vev.material = NSVisualEffectMaterialHUDWindow;
        vev.state = NSVisualEffectStateActive;
        vev.alphaValue = 0.45 + (tintAmount * 0.35);
        vev.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        vev.wantsLayer = YES;
        vev.layer.cornerRadius = radius;
        vev.layer.masksToBounds = YES;
        [host addSubview:vev];
    }

    [superview addSubview:host positioned:NSWindowBelow relativeTo:wv];
    // Force immediate CABackdropLayer instantiation at t=0ms before first screen paint
    [host layoutSubtreeIfNeeded];
    [superview displayIfNeeded];
    [win displayIfNeeded];
    tuneGlassBackdrop(host.layer, tintAmount);
    [win invalidateShadow];
    lua_pushboolean(L, 1);
    return 1;
}

static NSString *bestVoiceForLocale(NSString *targetLocale) {
    if (!targetLocale || targetLocale.length == 0) return nil;
    NSString *normTarget = [targetLocale stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    NSString *langPrefix = [[normTarget componentsSeparatedByString:@"_"] firstObject];

    NSString *bestVoice = nil;
    int bestScore = -1;

    for (NSSpeechSynthesizerVoiceName v in [NSSpeechSynthesizer availableVoices]) {
        NSDictionary *attrs = [NSSpeechSynthesizer attributesForVoice:v];
        NSString *vLocale = attrs[NSVoiceLocaleIdentifier] ?: @"";
        NSString *normVLocale = [vLocale stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
        NSString *vLang = [[normVLocale componentsSeparatedByString:@"_"] firstObject];

        BOOL exactMatch = [normVLocale caseInsensitiveCompare:normTarget] == NSOrderedSame;
        BOOL langMatch  = [vLang caseInsensitiveCompare:langPrefix] == NSOrderedSame;
        if (!exactMatch && !langMatch) continue;

        int score = exactMatch ? 50 : 25;
        if ([v containsString:@".premium."])       score += 100;
        else if ([v containsString:@".enhanced."]) score += 90;
        else if ([v containsString:@".compact."])  score += 80;
        else if ([v containsString:@".ttsbundle."])score += 75;
        else if ([v containsString:@".eloquence."])score += 10;

        if (score > bestScore) {
            bestScore = score;
            bestVoice = v;
        }
    }
    return bestVoice;
}

static int speak_with_locale(lua_State *L) {
    const char *textCStr   = luaL_checklstring(L, 1, NULL);
    const char *localeCStr = luaL_checklstring(L, 2, NULL);
    NSString *text   = [NSString stringWithUTF8String:textCStr ?: ""];
    NSString *locale = [NSString stringWithUTF8String:localeCStr ?: "en_US"];

    if (gSynth && [gSynth isSpeaking]) {
        [gSynth stopSpeaking];
        gSynth = nil;
        lua_pushboolean(L, 1);
        return 1;
    }

    NSString *voiceID = bestVoiceForLocale(locale);
    if (voiceID) {
        gSynth = [[NSSpeechSynthesizer alloc] initWithVoice:voiceID];
    } else {
        gSynth = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
    }

    if (gSynth) {
        [gSynth startSpeakingString:text];
        lua_pushboolean(L, 1);
        return 1;
    }
    lua_pushboolean(L, 0);
    return 1;
}

static int stop_speech(lua_State *L) {
    if (gSynth && [gSynth isSpeaking]) {
        [gSynth stopSpeaking];
    }
    gSynth = nil;
    lua_pushboolean(L, 1);
    return 1;
}

int luaopen_ftt_native(lua_State *L) {
    lua_createtable(L, 0, 5);
    lua_pushcclosure(L, apply_liquid_glass, 0);
    lua_setfield(L, -2, "applyGlass");
    lua_pushcclosure(L, speak_with_locale, 0);
    lua_setfield(L, -2, "speak");
    lua_pushcclosure(L, stop_speech, 0);
    lua_setfield(L, -2, "stopSpeech");
    lua_pushcclosure(L, start_window_drag, 0);
    lua_setfield(L, -2, "startDrag");
    lua_pushcclosure(L, stop_window_drag, 0);
    lua_setfield(L, -2, "stopDrag");
    return 1;
}
]=]

local function initNativeBridge()
    local home = os.getenv("HOME") or "/tmp"
    local soPath = home .. "/.hammerspoon/.ftt_native_v30.so"
    local loader = package.loadlib(soPath, "luaopen_ftt_native")
    if loader then
        local ok, mod = pcall(loader)
        if ok and type(mod) == "table" and mod.startDrag then
            AppState.nativeBridge = mod
            return
        end
    end

    -- Compile once in background if not yet built or missing v3.0 drag exports
    local mPath = "/tmp/ftt_native_v30.m"
    local f = io.open(mPath, "w")
    if not f then return end
    f:write(NATIVE_OBJC_SOURCE)
    f:close()

    if hs.task and hs.task.new then
        hs.task.new("/usr/bin/clang", function(exitCode)
            os.remove(mPath)
            if exitCode == 0 then
                local fn = package.loadlib(soPath, "luaopen_ftt_native")
                if fn then
                    local ok, mod = pcall(fn)
                    if ok and type(mod) == "table" then
                        AppState.nativeBridge = mod
                        if AppState.bubbleWebview then pcall(mod.applyGlass, AppState.bubbleWebview) end
                        if AppState.menubarWebview then pcall(mod.applyGlass, AppState.menubarWebview) end
                    end
                end
            end
        end, {
            "-O2", "-dynamiclib", "-fobjc-arc",
            "-F/Applications/Hammerspoon.app/Contents/Frameworks",
            "-framework", "LuaSkin",
            "-Wl,-rpath,/Applications/Hammerspoon.app/Contents/Frameworks",
            "-framework", "Cocoa", "-framework", "WebKit", "-framework", "QuartzCore",
            "-Wno-deprecated-declarations",
            mPath, "-o", soPath
        }):start()
    end
end

initNativeBridge()

local function applyLiquidGlassToWebview(wv)
    if not wv then return end
    pcall(function() wv:transparent(true) end)
    pcall(function() wv:shadow(true) end)
    if AppState.nativeBridge and AppState.nativeBridge.applyGlass then
        pcall(AppState.nativeBridge.applyGlass, wv)
    end
end

-- ==============================================================================
-- UTILITIES
-- ==============================================================================

local function isAppIgnored(app)
    if not app then return false end
    local name = app:name()
    local bid  = app:bundleID()
    return (name and CONFIG._ignoredSet[name]) or (bid and CONFIG._ignoredBundleSet[bid]) or false
end

local function isAppNativeBlacklisted(app)
    if not app then return false end
    local name = app:name()
    local bid  = app:bundleID()
    return (name and CONFIG._nativeBlacklistSet[name]) or (bid and CONFIG._nativeBlacklistBundleSet[bid]) or false
end

local function urlencode(str)
    if not str then return str end
    return str:gsub("\n", "\r\n")
              :gsub("([^A-Za-z0-9 %-%_%.%~])", function(c) return ("%%%02X"):format(c:byte()) end)
              :gsub(" ", "%%20")
end

local function escapeHTML(str)
    if not str then return "" end
    return str:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"):gsub("'","&#39;")
end

local function escapeJSTemplate(str)
    if not str then return "" end
    return str:gsub("\\", "\\\\")
              :gsub("`", "\\`")
              :gsub("%$", "\\$")
              :gsub("\r", "\\r")
              :gsub("\n", "\\n")
              :gsub("<", "\\u003c")
end

local function distance(p1, p2)
    if not p1 or not p2 then return 0 end
    return math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2)
end

local function trim(s)
    if not s then return nil end
    while s:sub(1, 2) == "\194\160" do s = s:sub(3) end
    while #s >= 2 and s:sub(-2) == "\194\160" do s = s:sub(1, -3) end
    return s:match("^%s*(.-)%s*$")
end

local function utf8Len(s)
    if not s then return 0 end
    local ok, len = pcall(utf8.len, s)
    return (ok and len) and len or #s
end

local function getScreenForPoint(pt)
    if pt then
        for _, scr in ipairs(hs.screen.allScreens()) do
            local sf = scr:fullFrame()
            if pt.x >= sf.x and pt.x <= sf.x + sf.w and pt.y >= sf.y and pt.y <= sf.y + sf.h then
                return scr
            end
        end
    end
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

local function computeBubbleRect(targetPos, w, h, screen)
    local x = targetPos.x + 15
    local y = targetPos.y + 15
    if x + w > screen.x + screen.w - 10 then
        x = targetPos.x - w - 15
    end
    x = math.max(screen.x + 10, math.min(x, screen.x + screen.w - w - 10))

    if y + h > screen.y + screen.h - 10 then
        y = targetPos.y - h - 15
    end
    y = math.max(screen.y + 10, math.min(y, screen.y + screen.h - h - 10))
    return hs.geometry.rect(x, y, w, h)
end

-- ==============================================================================
-- LRU CACHE & LANGUAGE-AWARE TEXT-TO-SPEECH (TTS)
-- ==============================================================================

local function getCacheKey(sl, tl, text)
    return (sl or "auto") .. "|" .. (tl or CONFIG.targetLanguage) .. "|" .. text
end

local function getCachedTranslation(sl, tl, text)
    local key = getCacheKey(sl, tl, text)
    local entry = AppState.cache[key]
    if not entry then return nil end
    for i, k in ipairs(AppState.cacheOrder) do
        if k == key then
            table.remove(AppState.cacheOrder, i)
            break
        end
    end
    table.insert(AppState.cacheOrder, key)
    return entry
end

local function putCachedTranslation(sl, tl, text, translated, rawJson)
    local key = getCacheKey(sl, tl, text)
    if not AppState.cache[key] and #AppState.cacheOrder >= CONFIG.cacheMaxEntries then
        local oldest = table.remove(AppState.cacheOrder, 1)
        if oldest then AppState.cache[oldest] = nil end
    end
    AppState.cache[key] = { translated = translated, rawJson = rawJson }
    for i, k in ipairs(AppState.cacheOrder) do
        if k == key then
            table.remove(AppState.cacheOrder, i)
            break
        end
    end
    table.insert(AppState.cacheOrder, key)
end

local function performTranslation(text, sl, tl, callback)
    text = trim(text)
    if not text or text == "" then
        if callback then callback(false, "", "", nil, "Empty text") end
        return
    end

    text = text:gsub("\194\173", "")

    if #text > 4000 then
        local limit = 4000
        while limit > 1 and text:byte(limit) >= 0x80 and text:byte(limit) < 0xC0 do
            limit = limit - 1
        end
        if limit > 0 and text:byte(limit) >= 0xC0 then limit = limit - 1 end
        text = text:sub(1, limit) .. "..."
    end

    sl = sl or "auto"
    tl = tl or (AppState.lastTargetLang or CONFIG.targetLanguage)

    local cached = getCachedTranslation(sl, tl, text)
    if cached then
        local detected = nil
        if cached.rawJson and cached.rawJson ~= "" then
            local ok, d = pcall(hs.json.decode, cached.rawJson)
            if ok and d and d.src then detected = d.src end
        end
        if callback then callback(true, cached.translated, cached.rawJson, detected, nil) end
        return
    end

    local url = "https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&dt=bd&dt=rm&dj=1&sl=" .. sl .. "&tl=" .. tl

    local headers = {
        ["User-Agent"]    = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko)",
        ["Content-Type"]  = "application/x-www-form-urlencoded",
        ["Cache-Control"] = "no-cache",
        ["Connection"]    = "keep-alive"
    }

    hs.http.doAsyncRequest(url, "POST", "q=" .. urlencode(text), headers, function(status, body)
        if status == 200 and body then
            local ok, data = pcall(hs.json.decode, body)
            if ok and data and (data.sentences or data[1]) then
                local translated = ""
                if data.sentences then
                    for _, block in ipairs(data.sentences) do
                        if block.trans then translated = translated .. block.trans end
                    end
                elseif data[1] then
                    for _, block in ipairs(data[1]) do
                        if block[1] then translated = translated .. block[1] end
                    end
                end
                local detected = (data and data.src) or nil
                putCachedTranslation(sl, tl, text, translated, body)
                if callback then callback(true, translated, body, detected, nil) end
            else
                if callback then callback(false, "", "", nil, "Invalid translation response") end
            end
        else
            if callback then callback(false, "", "", nil, "Translation API Error: " .. tostring(status)) end
        end
    end)
end

local function stopActiveSpeech()
    if AppState.nativeBridge and AppState.nativeBridge.stopSpeech then
        pcall(AppState.nativeBridge.stopSpeech)
    end
    if AppState.sayTask and AppState.sayTask:isRunning() then
        pcall(function() AppState.sayTask:terminate() end)
        AppState.sayTask = nil
    end
end

local function resolveLocaleForLang(langCode)
    if not langCode or langCode == "" or langCode == "auto" then return "en_US" end
    if LANG_LOCALES[langCode] then return LANG_LOCALES[langCode] end
    local base = langCode:match("^([a-zA-Z]+)")
    if base and LANG_LOCALES[base] then return LANG_LOCALES[base] end
    return langCode
end

local function resolveVoiceNameForLang(langCode)
    if not langCode or langCode == "" or langCode == "auto" then return LANG_VOICES["en"] end
    if LANG_VOICES[langCode] then return LANG_VOICES[langCode] end
    local base = langCode:match("^([a-zA-Z]+)")
    if base and LANG_VOICES[base] then return LANG_VOICES[base] end
    return nil
end

local function speakText(text, langCode)
    if not text or trim(text) == "" then return end

    -- 1. Prefer native Objective-C NSSpeechSynthesizer bridge (supports all compact/enhanced/premium voices by locale)
    if AppState.nativeBridge and AppState.nativeBridge.speak then
        local locale = resolveLocaleForLang(langCode)
        local ok, handled = pcall(AppState.nativeBridge.speak, text, locale)
        if ok and handled then return end
    end

    -- 2. Fallback to /usr/bin/say with language-matched voice assistant
    if AppState.sayTask and AppState.sayTask:isRunning() then
        pcall(function() AppState.sayTask:terminate() end)
        AppState.sayTask = nil
        return
    end

    if hs.task and hs.task.new then
        local voice = resolveVoiceNameForLang(langCode)
        local args = voice and { "-v", voice, text } or { text }
        AppState.sayTask = hs.task.new("/usr/bin/say", function()
            AppState.sayTask = nil
        end, args)
        if AppState.sayTask then AppState.sayTask:start() end
    end
end

-- ==============================================================================
-- HTML / CSS / JS TEMPLATES (macOS 27.2 Native Liquid Glass Design)
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

local function buildLangMapJS()
    local parts = {}
    for _, l in ipairs(LANGUAGES) do
        parts[#parts + 1] = string.format('%q:%q', l.code, l.name)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local SHARED_CSS = [=[
    *, *::before, *::after { box-sizing: border-box; }
    html, body {
        background: transparent;
        margin: 0; padding: 0;
        width: 100%; height: 100%;
        overflow: hidden;
        -webkit-font-smoothing: antialiased;
    }
    .container {
        position: relative;
        background: transparent;
        color: #F5F5F7;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif;
        font-size: 14px;
        border-radius: 16px;
        box-shadow:
            inset 0 0 0 1px rgba(255, 255, 255, 0.22),
            inset 0 1px 0 0 rgba(255, 255, 255, 0.38),
            inset 0 -1px 0 0 rgba(255, 255, 255, 0.08);
        width: 100%;
        max-width: 100%;
        height: 100%;
        padding: 11px 13px;
        overflow-y: auto;
        overflow-x: hidden;
        scroll-behavior: smooth;
        -webkit-user-select: text;
        cursor: grab;
        display: flex;
        flex-direction: column;
        gap: 9px;
    }
    .container.dragging, .container.dragging * {
        cursor: grabbing !important;
    }
    .controls {
        display: flex; align-items: center; justify-content: space-between;
        width: 100%; max-width: 100%; overflow: hidden;
        background: rgba(255, 255, 255, 0.04);
        border: 1px solid rgba(255, 255, 255, 0.16);
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.22);
        padding: 6px 10px;
        border-radius: 11px;
        flex-shrink: 0;
        position: sticky; top: 0; z-index: 10; gap: 6px;
        cursor: grab;
    }
    select {
        background: transparent; color: #64D2FF; border: none;
        font-size: 13px; font-weight: 600; outline: none;
        cursor: pointer; -webkit-appearance: none;
        flex: 1 1 0; min-width: 0; max-width: 132px;
        overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
        padding-right: 2px;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.65), 0 0 1px rgba(0, 0, 0, 0.45);
    }
    select option { background: #1c1c1e; color: #F5F5F7; }
    .text-box {
        display: flex; flex-direction: column; gap: 4px;
        width: 100%; max-width: 100%; overflow: hidden;
        background: rgba(255, 255, 255, 0.035);
        border: 1px solid rgba(255, 255, 255, 0.13);
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.14);
        border-radius: 11px;
        padding: 8px 11px;
        flex-shrink: 0;
    }
    .header {
        font-weight: 600; font-size: 10.5px; color: rgba(235, 235, 245, 0.72);
        text-transform: uppercase; letter-spacing: 0.6px;
        display: flex; justify-content: space-between; align-items: center;
        width: 100%; overflow: hidden;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.55);
        cursor: grab;
        user-select: none; -webkit-user-select: none;
    }
    .header-actions { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
    .icon-btn {
        cursor: pointer; opacity: 0.85; transition: opacity 0.15s, fill 0.15s;
        display: inline-flex; align-items: center; justify-content: center;
        user-select: none; -webkit-user-select: none; flex-shrink: 0;
        filter: drop-shadow(0 1px 2px rgba(0,0,0,0.45));
    }
    .icon-btn:hover { opacity: 1; }
    .icon-btn.pinned { opacity: 1; color: #FFD60A !important; fill: #FFD60A !important; }

    /* Orbital Half-Turn + Wind Swoosh Swap Button */
    .swap-btn {
        position: relative;
        width: 24px; height: 24px;
        display: inline-flex; align-items: center; justify-content: center;
        cursor: pointer; flex-shrink: 0;
        border-radius: 50%;
        user-select: none; -webkit-user-select: none;
        transition: background 0.2s;
    }
    .swap-btn:hover { background: rgba(100, 210, 255, 0.14); }
    .swap-svg { width: 20px; height: 20px; overflow: visible; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.45)); }
    .swap-rotor {
        transform-origin: 12px 12px;
        transition: transform 0.52s cubic-bezier(0.22, 1, 0.36, 1);
    }
    .wind-arc {
        fill: none;
        stroke: #8AF0FF;
        stroke-width: 1.5;
        stroke-linecap: round;
        stroke-dasharray: 18 40;
        stroke-dashoffset: 24;
        opacity: 0;
        transform-origin: 12px 12px;
        pointer-events: none;
    }
    .swap-btn.swapping .wind-arc-1 {
        animation: windSweep1 0.52s cubic-bezier(0.22, 1, 0.36, 1) forwards;
    }
    .swap-btn.swapping .wind-arc-2 {
        animation: windSweep2 0.52s cubic-bezier(0.22, 1, 0.36, 1) forwards;
    }
    @keyframes windSweep1 {
        0%   { opacity: 0; stroke-dashoffset: 22; transform: rotate(0deg) scale(0.88); }
        30%  { opacity: 0.95; }
        100% { opacity: 0; stroke-dashoffset: -26; transform: rotate(180deg) scale(1.08); }
    }
    @keyframes windSweep2 {
        0%   { opacity: 0; stroke-dashoffset: 22; transform: rotate(180deg) scale(0.88); }
        30%  { opacity: 0.85; }
        100% { opacity: 0; stroke-dashoffset: -26; transform: rotate(360deg) scale(1.08); }
    }

    .copy-badge {
        font-size: 10px; font-weight: 600; color: #32D74B; text-transform: none;
        letter-spacing: 0; opacity: 0; transition: opacity 0.2s; pointer-events: none;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.55);
    }
    .copy-badge.visible { opacity: 1; }
    .content {
        line-height: 1.45; font-weight: 400; white-space: pre-wrap;
        word-wrap: break-word; overflow-wrap: anywhere;
        color: #FFFFFF;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.65), 0 0 1px rgba(0, 0, 0, 0.45);
        width: 100%; max-width: 100%;
        cursor: text;
    }
    .phonetic {
        font-size: 12px; color: rgba(235, 235, 245, 0.72); font-style: italic;
        display: none; margin-top: 1px; cursor: text;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.55);
    }
    .translation-header { color: #64D2FF; }
    .dictionary-container {
        margin-top: 1px;
        width: 100%; max-width: 100%; overflow: hidden; flex-shrink: 0;
        background: rgba(255, 255, 255, 0.035);
        border: 1px solid rgba(255, 255, 255, 0.13);
        box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.14);
        border-radius: 11px;
        padding: 8px 11px;
        display: none;
    }
    .dict-header {
        font-weight: 600; font-size: 10.5px; color: rgba(235, 235, 245, 0.72);
        text-transform: uppercase; letter-spacing: 0.6px; margin-bottom: 6px;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.55);
        cursor: grab; user-select: none; -webkit-user-select: none;
    }
    .dict-pos {
        font-style: italic; color: #64D2FF; font-size: 12px; margin-bottom: 4px; margin-top: 7px;
        text-shadow: 0 1px 2px rgba(0, 0, 0, 0.55);
    }
    .dict-entry { display: flex; align-items: baseline; margin-bottom: 5px; width: 100%; max-width: 100%; overflow: hidden; }
    .dict-word {
        font-weight: 500; font-size: 13px; color: #FFFFFF; width: 40%; flex-shrink: 0; padding-right: 8px;
        overflow: hidden; text-overflow: ellipsis; white-space: nowrap; cursor: text;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.65);
    }
    .dict-reverse {
        font-size: 12px; color: rgba(235, 235, 245, 0.78); flex: 1 1 0; min-width: 0;
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis; cursor: text;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.65);
    }
    ::-webkit-scrollbar { width: 5px; height: 0px; }
    ::-webkit-scrollbar-track { background: transparent; margin: 14px 0; }
    ::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.25); border-radius: 3px; }
    ::-webkit-scrollbar-thumb:hover { background: rgba(255, 255, 255, 0.45); }
]=]

local SHARED_JS = [=[
    const LANG_NAMES = ]=] .. buildLangMapJS() .. [=[;
    let textHistory = [];
    let _currentRequestId = 0;
    let _detectedSourceLang = null;
    let _isPinned = false;
    let _copyBadgeTimer = null;
    let _swapDeg = 0;
    let _swapAnimTimer = null;

    function getViewType() {
        const el = document.getElementById("sourceText");
        return (el && el.tagName === "TEXTAREA") ? "menubar" : "bubble";
    }
    function getSourceText() {
        const el = document.getElementById("sourceText");
        return el.tagName === "TEXTAREA" ? el.value : el.innerText;
    }
    function setSourceText(text) {
        const el = document.getElementById("sourceText");
        if (el.tagName === "TEXTAREA") el.value = text; else el.innerText = text;
    }
    function updateAutoOptionLabel(detectedCode) {
        const ss = document.getElementById("sourceLang");
        if (!ss) return;
        const autoOpt = ss.querySelector('option[value="auto"]');
        if (!autoOpt) return;
        if (detectedCode && ss.value === "auto") {
            const name = LANG_NAMES[detectedCode] || detectedCode.toUpperCase();
            autoOpt.textContent = "Auto (" + name + ")";
        } else {
            autoOpt.textContent = "Auto Detect";
        }
    }
    function copyTranslation() {
        const textEl = document.getElementById("translatedText");
        if (textEl && textEl.innerText && window.webkit && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({ action: "copy", text: textEl.innerText });
            const badge = document.getElementById("copyBadge");
            if (badge) {
                badge.classList.add("visible");
                clearTimeout(_copyBadgeTimer);
                _copyBadgeTimer = setTimeout(() => badge.classList.remove("visible"), 1400);
            }
        }
    }
    function speakContent(targetId) {
        const el = document.getElementById(targetId);
        const txt = el ? (el.tagName === "TEXTAREA" ? el.value : el.innerText) : "";
        if (!txt || txt.trim() === "" || txt === "Translating...") return;

        let lang = "en";
        if (targetId === "sourceText") {
            const ss = document.getElementById("sourceLang");
            lang = (ss && ss.value !== "auto") ? ss.value : (_detectedSourceLang || "en");
        } else {
            const ts = document.getElementById("targetLang");
            lang = (ts && ts.value) ? ts.value : "tr";
        }

        if (window.webkit && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({ action: "speak", text: txt, lang: lang });
        }
    }
    function togglePin() {
        _isPinned = !_isPinned;
        const btn = document.getElementById("pinBtn");
        if (btn) {
            if (_isPinned) btn.classList.add("pinned");
            else btn.classList.remove("pinned");
        }
        if (window.webkit && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({ action: "pin", pinned: _isPinned });
        }
    }
    function extractPhonetic(data) {
        if (data && Array.isArray(data.sentences)) {
            for (const s of data.sentences) {
                if (s.src_translit) return s.src_translit;
                if (s.translit) return s.translit;
            }
        }
        return "";
    }
    function renderDictionary(data) {
        const dictContainer = document.getElementById("dictContainer");
        const dictContent = document.getElementById("dictContent");
        dictContent.innerHTML = "";

        if (data && data.dict && Array.isArray(data.dict)) {
            dictContainer.style.display = "block";
            data.dict.forEach(posGroup => {
                if (posGroup.pos) {
                    const el = document.createElement("div"); el.className = "dict-pos"; el.innerText = posGroup.pos;
                    dictContent.appendChild(el);
                }
                if (Array.isArray(posGroup.entry)) {
                    posGroup.entry.forEach(entry => {
                        const row = document.createElement("div"); row.className = "dict-entry";
                        const wordEl = document.createElement("div"); wordEl.className = "dict-word"; wordEl.innerText = entry.word;
                        const revEl = document.createElement("div"); revEl.className = "dict-reverse";
                        if (Array.isArray(entry.reverse_translation)) revEl.innerText = entry.reverse_translation.join(", ");
                        row.appendChild(wordEl); row.appendChild(revEl); dictContent.appendChild(row);
                    });
                } else if (Array.isArray(posGroup.terms)) {
                    const row = document.createElement("div"); row.className = "dict-entry";
                    const revEl = document.createElement("div"); revEl.className = "dict-reverse"; revEl.innerText = posGroup.terms.join(", ");
                    row.appendChild(revEl); dictContent.appendChild(row);
                }
            });
        } else if (data && data.length > 1 && Array.isArray(data[1])) {
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
                    const row = document.createElement("div"); row.className = "dict-entry";
                    const revEl = document.createElement("div"); revEl.className = "dict-reverse"; revEl.innerText = posGroup[1].join(", ");
                    row.appendChild(revEl); dictContent.appendChild(row);
                }
            });
        } else {
            dictContainer.style.display = "none";
        }
    }

    function resetAndShowBubble(origOrData, translatedText, rawJson, sl, tl) {
        let orig = origOrData, trans = translatedText, json = rawJson, sourceL = sl, targetL = tl;
        if (origOrData && typeof origOrData === "object") {
            orig = origOrData.orig || "";
            trans = origOrData.trans || "";
            json = origOrData.json || "";
            sourceL = origOrData.sl || "auto";
            targetL = origOrData.tl;
        }

        const cont = document.querySelector('.container');
        if (cont) {
            cont.scrollTop = 0;
            cont.classList.remove("dragging");
        }

        textHistory = [];
        _detectedSourceLang = null;
        _isPinned = false;
        const pinBtn = document.getElementById("pinBtn");
        if (pinBtn) pinBtn.classList.remove("pinned");
        const badge = document.getElementById("copyBadge");
        if (badge) badge.classList.remove("visible");

        const ss = document.getElementById("sourceLang");
        const ts = document.getElementById("targetLang");
        if (ss && sourceL) ss.value = sourceL;
        if (ts && targetL) ts.value = targetL;
        updateAutoOptionLabel(null);

        updateBubbleContent(orig, trans, json);
    }

    function updateBubbleContent(originalText, translatedText, rawJson) {
        setSourceText(originalText);
        document.getElementById('translatedText').innerText = translatedText;
        const phonEl = document.getElementById('phoneticText');
        if (phonEl) { phonEl.style.display = 'none'; phonEl.innerText = ''; }

        if (rawJson && rawJson.trim() !== "") {
            try {
                const data = JSON.parse(rawJson);
                if (data && data.src) {
                    _detectedSourceLang = data.src;
                    updateAutoOptionLabel(data.src);
                }
                if (phonEl) {
                    const phon = extractPhonetic(data);
                    if (phon && phon.trim() !== "" && originalText.trim().indexOf(" ") === -1) {
                        phonEl.innerText = "/" + phon + "/";
                        phonEl.style.display = "block";
                    }
                }
                renderDictionary(data);
            } catch(e) {
                document.getElementById('dictContainer').style.display = 'none';
            }
        } else {
            document.getElementById('dictContainer').style.display = 'none';
        }

        emitRenderComplete();
    }

    function emitRenderComplete() {
        if (window.webkit && window.webkit.messageHandlers.ftt) {
            const cont = document.querySelector('.container');
            const oldHeight = cont.style.height;
            cont.style.height = 'auto';
            const actualHeight = Math.ceil(Math.max(cont.offsetHeight, cont.scrollHeight) + 2);
            cont.style.height = oldHeight;
            window.webkit.messageHandlers.ftt.postMessage({
                action: "render_complete",
                h: actualHeight,
                view: getViewType()
            });
        }
    }

    function extractTranslation(data) {
        let t = "";
        if (data && data.sentences) {
            data.sentences.forEach(b => { if (b.trans) t += b.trans; });
        } else if (data && data[0]) {
            data[0].forEach(b => { if (b[0]) t += b[0]; });
        }
        return t;
    }

    function onLangSelectChange() {
        textHistory = [];
        const ss = document.getElementById("sourceLang");
        if (ss && ss.value !== "auto") updateAutoOptionLabel(null);
        if (typeof saveState === "function") saveState();
        else if (window.webkit && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({
                action: "save_langs",
                sl: document.getElementById("sourceLang").value,
                tl: document.getElementById("targetLang").value
            });
        }
        translateText();
    }

    function animateSwapIcon() {
        const btn = document.getElementById("swapBtn");
        const rotor = document.getElementById("swapRotor");
        if (rotor) {
            _swapDeg += 180;
            rotor.style.transform = "rotate(" + _swapDeg + "deg)";
        }
        if (btn) {
            btn.classList.remove("swapping");
            void btn.offsetWidth;
            btn.classList.add("swapping");
            clearTimeout(_swapAnimTimer);
            _swapAnimTimer = setTimeout(() => btn.classList.remove("swapping"), 540);
        }
    }

    function swapLanguages() {
        animateSwapIcon();
        const ss = document.getElementById("sourceLang");
        const ts = document.getElementById("targetLang");
        let resolvedSrc = ss.value === "auto" ? (_detectedSourceLang && LANG_NAMES[_detectedSourceLang] ? _detectedSourceLang : "en") : ss.value;
        let newSrc = ts.value;
        let newTgt = resolvedSrc;
        ss.value = newSrc;
        ts.value = newTgt;
        _detectedSourceLang = newSrc;
        updateAutoOptionLabel(null);

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
        if (window.webkit && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({
                action: "save_langs", sl: ss.value, tl: ts.value
            });
        }
        translateText();
    }

    function translateText() {
        const sourceText = getSourceText().trim();
        const sl = document.getElementById("sourceLang").value;
        const tl = document.getElementById("targetLang").value;
        if (typeof saveState === "function") saveState();
        if (!sourceText) {
            document.getElementById("translatedText").innerText = "";
            document.getElementById("dictContainer").style.display = "none";
            const phonEl = document.getElementById("phoneticText");
            if (phonEl) { phonEl.style.display = "none"; phonEl.innerText = ""; }
            emitRenderComplete();
            return;
        }
        document.getElementById("translatedText").innerText = "Translating...";
        document.getElementById("dictContainer").style.display = "none";

        _currentRequestId++;
        const reqId = _currentRequestId;

        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({
                action: "translate",
                text: sourceText,
                sl: sl,
                tl: tl,
                reqId: reqId,
                view: getViewType()
            });
        }
    }

    function onTranslationResponse(resp) {
        if (!resp || resp.reqId !== _currentRequestId) return;
        if (!resp.success) {
            document.getElementById("translatedText").innerText = "Error: " + (resp.errorMsg || "Translation failed");
            document.getElementById("dictContainer").style.display = "none";
            emitRenderComplete();
            return;
        }
        if (resp.detectedLang) {
            _detectedSourceLang = resp.detectedLang;
            updateAutoOptionLabel(resp.detectedLang);
        }
        document.getElementById("translatedText").innerText = resp.translated;
        const phonEl = document.getElementById("phoneticText");
        if (phonEl) { phonEl.style.display = "none"; phonEl.innerText = ""; }

        if (resp.rawJson && resp.rawJson.trim() !== "") {
            try {
                const data = JSON.parse(resp.rawJson);
                if (phonEl) {
                    const phon = extractPhonetic(data);
                    const src = getSourceText();
                    if (phon && phon.trim() !== "" && src.trim().indexOf(" ") === -1) {
                        phonEl.innerText = "/" + phon + "/";
                        phonEl.style.display = "block";
                    }
                }
                renderDictionary(data);
            } catch(e) {
                document.getElementById("dictContainer").style.display = "none";
            }
        } else {
            document.getElementById("dictContainer").style.display = "none";
        }
        emitRenderComplete();
    }

    // Native window dragging from any available empty area (outside text & controls)
    document.addEventListener("mousedown", function(e) {
        if (e.button !== 0) return;
        const interactive = e.target.closest("select, option, textarea, input, button, .icon-btn, .swap-btn, .content, .phonetic, .dict-word, .dict-reverse");
        if (interactive) return;
        const sel = window.getSelection();
        if (sel && sel.toString().length > 0) return;
        e.preventDefault();
        const cont = document.querySelector(".container");
        if (cont) cont.classList.add("dragging");
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ftt) {
            window.webkit.messageHandlers.ftt.postMessage({ action: "start_drag", view: getViewType() });
        }
    });

    window.addEventListener("mouseup", function() {
        const cont = document.querySelector(".container");
        if (cont) cont.classList.remove("dragging");
    });
]=]

local DICT_SECTION = [=[
                <div class="dictionary-container" id="dictContainer">
                    <div class="dict-header">More translations</div>
                    <div id="dictContent"></div>
                </div>
]=]

local SWAP_SVG  = [=[<div id="swapBtn" class="swap-btn" onclick="swapLanguages()" title="Swap languages"><svg class="swap-svg" viewBox="0 0 24 24"><path class="wind-arc wind-arc-1" d="M 3.5 9.5 A 9.2 9.2 0 0 1 18.5 5.5"/><path class="wind-arc wind-arc-2" d="M 20.5 14.5 A 9.2 9.2 0 0 1 5.5 18.5"/><g id="swapRotor" class="swap-rotor"><path d="M 5.2 10.2 C 6.4 6.2 10.8 4.4 15.2 6.0 L 13.7 7.5 L 18.4 7.3 L 16.5 3.0 L 15.6 4.6 C 10.4 2.6 5.0 4.8 3.6 9.6 Z" fill="#64D2FF"/><path d="M 18.8 13.8 C 17.6 17.8 13.2 19.6 8.8 18.0 L 10.3 16.5 L 5.6 16.7 L 7.5 21.0 L 8.4 19.4 C 13.6 21.4 19.0 19.2 20.4 14.4 Z" fill="#64D2FF"/></g></svg></div>]=]
local CLEAR_SVG = [=[<svg class="icon-btn" onclick="clearText()" style="width:12px; height:12px; fill:rgba(235,235,245,0.65);" title="Clear Text" viewBox="0 0 384 512"><path d="M342.6 150.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L192 210.7 86.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L146.7 256 41.4 361.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L192 301.3 297.4 406.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L237.3 256 342.6 150.6z"/></svg>]=]
local COPY_SVG  = [=[<svg class="icon-btn" onclick="copyTranslation()" style="width:13px; height:13px; fill:#64D2FF;" title="Copy Translation" viewBox="0 0 448 512"><path d="M208 0H332.1c12.7 0 24.9 5.1 33.9 14.1l67.9 67.9c9 9 14.1 21.2 14.1 33.9V336c0 26.5-21.5 48-48 48H208c-26.5 0-48-21.5-48-48V48c0-26.5 21.5-48 48-48zM48 128h80v64H64V448H256V416h64v40c0 30.9-25.1 56-56 56H48c-30.9 0-56-25.1-56-56V184c0-30.9 25.1-56 56-56z"/></svg>]=]
local SPEAK_ORIG_SVG = [=[<svg class="icon-btn" onclick="speakContent('sourceText')" style="width:13px; height:13px; fill:rgba(235,235,245,0.75);" title="Listen in Source Language" viewBox="0 0 640 512"><path d="M533.6 32.5C598.5 85.2 640 165.8 640 256s-41.5 170.7-106.4 223.5c-10.3 8.4-25.4 6.8-33.8-3.5s-6.8-25.4 3.5-33.8C557.5 398.2 592 331.2 592 256s-34.5-142.2-88.7-186.3c-10.3-8.4-11.8-23.5-3.5-33.8s23.5-11.8 33.8-3.5zM473.1 107c43.2 35.2 70.9 88.9 70.9 149s-27.7 113.8-70.9 149c-10.3 8.4-25.4 6.8-33.8-3.5s-6.8-25.4 3.5-33.8C475.3 341.3 496 301.1 496 256s-20.7-85.3-53.2-111.8c-10.3-8.4-11.8-23.5-3.5-33.8s23.5-11.8 33.8-3.5zm-60.5 74.5C434.1 199.1 448 225.9 448 256s-13.9 56.9-35.4 74.5c-10.3 8.4-25.4 6.8-33.8-3.5s-6.8-25.4 3.5-33.8C393.1 284.4 400 271 400 256s-6.9-28.4-17.7-37.3c-10.3-8.4-11.8-23.5-3.5-33.8s23.5-11.8 33.8-3.5zM301.1 34.8C312.6 40 320 51.4 320 64V448c0 12.6-7.4 24-18.9 29.2s-25 3.1-34.4-5.3L131.8 352H64c-35.3 0-64-28.7-64-64V224c0-35.3 28.7-64 64-64h67.8L266.7 40.1c9.4-8.4 22.9-10.4 34.4-5.3z"/></svg>]=]
local SPEAK_TRANS_SVG = [=[<svg class="icon-btn" onclick="speakContent('translatedText')" style="width:13px; height:13px; fill:#64D2FF;" title="Listen in Target Language" viewBox="0 0 640 512"><path d="M533.6 32.5C598.5 85.2 640 165.8 640 256s-41.5 170.7-106.4 223.5c-10.3 8.4-25.4 6.8-33.8-3.5s-6.8-25.4 3.5-33.8C557.5 398.2 592 331.2 592 256s-34.5-142.2-88.7-186.3c-10.3-8.4-11.8-23.5-3.5-33.8s23.5-11.8 33.8-3.5zM473.1 107c43.2 35.2 70.9 88.9 70.9 149s-27.7 113.8-70.9 149c-10.3 8.4-25.4 6.8-33.8-3.5s-6.8-25.4 3.5-33.8C475.3 341.3 496 301.1 496 256s-20.7-85.3-53.2-111.8c-10.3-8.4-11.8-23.5-3.5-33.8s23.5-11.8 33.8-3.5zm-60.5 74.5C434.1 199.1 448 225.9 448 256s-13.9 56.9-35.4 74.5c-10.3 8.4-25.4 6.8-33.8-3.5s-6.8-25.4 3.5-33.8C393.1 284.4 400 271 400 256s-6.9-28.4-17.7-37.3c-10.3-8.4-11.8-23.5-3.5-33.8s23.5-11.8 33.8-3.5zM301.1 34.8C312.6 40 320 51.4 320 64V448c0 12.6-7.4 24-18.9 29.2s-25 3.1-34.4-5.3L131.8 352H64c-35.3 0-64-28.7-64-64V224c0-35.3 28.7-64 64-64h67.8L266.7 40.1c9.4-8.4 22.9-10.4 34.4-5.3z"/></svg>]=]
local PIN_SVG   = [=[<svg id="pinBtn" class="icon-btn" onclick="togglePin()" style="width:12px; height:12px; fill:rgba(235,235,245,0.65); flex-shrink:0;" title="Pin Bubble (Keep Open)" viewBox="0 0 384 512"><path d="M32 32C32 14.3 46.3 0 64 0H320c17.7 0 32 14.3 32 32s-14.3 32-32 32H290.5l11.4 148.2c36.7 19.9 65.7 53.2 79.5 94.7l1 3c3.3 9.8 1.6 20.5-4.4 28.8s-15.7 13.3-26 13.3H32c-10.3 0-19.9-4.9-26-13.3s-7.7-19.1-4.4-28.8l1-3c13.8-41.5 42.8-74.8 79.5-94.7L93.5 64H64C46.3 64 32 49.7 32 32zM160 384h64v96c0 17.7-14.3 32-32 32s-32-14.3-32-32V384z"/></svg>]=]

local function buildBubbleHTML(orig, trans, json)
    local initPayload = hs.json.encode({
        orig = orig or "",
        trans = trans or "",
        json = json or "",
        sl = "auto",
        tl = AppState.lastTargetLang or CONFIG.targetLanguage
    })
    return [=[<!DOCTYPE html><html><head><meta charset="utf-8">
        <style>]=] .. SHARED_CSS .. [=[</style>
        </head><body>
            <div class="container">
                <div class="controls">
                    <select id="sourceLang" onchange="onLangSelectChange()">
                        ]=] .. buildLangOptions("source", "auto") .. [=[
                    </select>
                    ]=] .. SWAP_SVG .. [=[
                    <select id="targetLang" onchange="onLangSelectChange()">
                        ]=] .. buildLangOptions("target", AppState.lastTargetLang) .. [=[
                    </select>
                    ]=] .. PIN_SVG .. [=[
                </div>
                <div class="text-box">
                    <div class="header">
                        <span>Original</span>
                        <div class="header-actions">
                            ]=] .. SPEAK_ORIG_SVG .. [=[
                        </div>
                    </div>
                    <div class="content" id="sourceText"></div>
                    <div class="phonetic" id="phoneticText"></div>
                </div>
                <div class="text-box">
                    <div class="header translation-header">
                        <span>Translation</span>
                        <div class="header-actions">
                            <span id="copyBadge" class="copy-badge">Copied!</span>
                            ]=] .. SPEAK_TRANS_SVG .. [=[
                            ]=] .. COPY_SVG .. [=[
                        </div>
                    </div>
                    <div class="content" id="translatedText"></div>
                </div>
]=] .. DICT_SECTION .. [=[
            </div>
            <script>
                ]=] .. SHARED_JS .. [=[
                resetAndShowBubble(]=] .. initPayload .. [=[);
            </script>
        </body></html>]=]
end

local MENUBAR_EXTRA_CSS = [=[
    textarea {
        width: 100%; background: transparent; color: #FFFFFF; border: none;
        font-family: inherit; font-size: 14px; resize: none; outline: none;
        min-height: 70px; padding: 0; line-height: 1.45;
        text-shadow: 0 1px 3px rgba(0, 0, 0, 0.65), 0 0 1px rgba(0, 0, 0, 0.45);
        cursor: text;
    }
    textarea::placeholder { color: rgba(235, 235, 245, 0.45); }
]=]

local function buildMenubarHTML()
    return [=[<!DOCTYPE html><html><head><meta charset="utf-8">
        <style>]=] .. SHARED_CSS .. MENUBAR_EXTRA_CSS .. [=[</style>
        </head><body>
            <div class="container">
                <div class="controls">
                    <div style="display: flex; align-items: center; gap: 8px;">
                        <svg class="icon-btn" onclick="window.webkit.messageHandlers.ftt.postMessage({action: 'quit'})" style="cursor:pointer; width:16px; height:16px; flex-shrink:0;" title="Quit ForceTouchTranslator" viewBox="0 0 24 24" fill="none" stroke="#FF453A" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="2" x2="12" y2="12"/><path d="M18.36 6.64A9 9 0 1 1 5.64 6.64"/></svg>
                        <select id="sourceLang" onchange="onLangSelectChange()">
                            ]=] .. buildLangOptions("source", AppState.lastSourceLang) .. [=[
                        </select>
                    </div>
                    ]=] .. SWAP_SVG .. [=[
                    <select id="targetLang" onchange="onLangSelectChange()">
                        ]=] .. buildLangOptions("target", AppState.lastTargetLang) .. [=[
                    </select>
                </div>
                <div class="text-box">
                    <div class="header">
                        <span>Original</span>
                        <div class="header-actions">
                            ]=] .. SPEAK_ORIG_SVG .. [=[
                            ]=] .. CLEAR_SVG .. [=[
                        </div>
                    </div>
                    <textarea id="sourceText" placeholder="Type text to translate..." oninput="debounceTranslate()">]=] .. escapeHTML(AppState.lastSourceText) .. [=[</textarea>
                </div>
                <div class="text-box">
                    <div class="header translation-header">
                        <span>Translation</span>
                        <div class="header-actions">
                            <span id="copyBadge" class="copy-badge">Copied!</span>
                            ]=] .. SPEAK_TRANS_SVG .. [=[
                            ]=] .. COPY_SVG .. [=[
                        </div>
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
                    _debounceTimer = setTimeout(translateText, 350);
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
                emitRenderComplete();
                setTimeout(() => {
                    document.getElementById("sourceText").focus();
                    if (document.getElementById("sourceText").value.trim() !== "") translateText();
                }, 40);
            </script>
        </body></html>]=]
end

-- ==============================================================================
-- UI TEARDOWN & LIFECYCLE
-- ==============================================================================

local function destroyBubble()
    stopAndNil("bubbleMouseTap")
    stopAndNil("bubbleEscapeTap")
    stopActiveSpeech()
    if AppState.nativeBridge and AppState.nativeBridge.stopDrag then
        pcall(AppState.nativeBridge.stopDrag)
    end
    if AppState.bubbleWebview then
        AppState.bubbleWebview:alpha(0)
        AppState.bubbleWebview:hide()
    end
    AppState.bubbleReadyData = nil
    AppState.bubblePinned    = false
end

local function destroyMenubar()
    stopAndNil("menubarMouseTap")
    stopActiveSpeech()
    if AppState.nativeBridge and AppState.nativeBridge.stopDrag then
        pcall(AppState.nativeBridge.stopDrag)
    end
    if AppState.menubarWebview then
        AppState.menubarWebview:alpha(0)
        deleteAndNil("menubarWebview")
    end
    if AppState.previousApp then
        AppState.previousApp:activate()
        AppState.previousApp = nil
    end
end

_G.__FTT_CLEANUP = function()
    stopAndNil("tap")
    stopAndNil("selectionTap")
    stopAndNil("selectionCaptureTimer")
    stopAndNil("watchdogTimer")
    stopAndNil("wakeWatcher")
    stopActiveSpeech()
    destroyBubble()
    deleteAndNil("bubbleWebview")
    destroyMenubar()
    deleteAndNil("menubar")
    if AppState.ucc then pcall(function() AppState.ucc:removeAllCallbacks() end); AppState.ucc = nil end
    _G.AppState = nil
    _G.translateAndShow = nil
    _G.toggleMenubar = nil
end

-- ==============================================================================
-- WEBVIEW MESSAGE HANDLER
-- ==============================================================================

AppState.ucc = hs.webview.usercontent.new("ftt")
AppState.ucc:setCallback(function(msg)
    if not msg.body then return end
    local act = msg.body.action
    if act == "quit" then
        hs.alert.show("Exiting ForceTouchTranslator...")
        _G.__FTT_CLEANUP()
    elseif act == "save" then
        if msg.body.sl then
            AppState.lastSourceLang = msg.body.sl
            hs.settings.set("ftt.sourceLang", msg.body.sl)
        end
        if msg.body.tl then
            AppState.lastTargetLang = msg.body.tl
            hs.settings.set("ftt.targetLang", msg.body.tl)
        end
        if msg.body.text ~= nil then AppState.lastSourceText = msg.body.text end
    elseif act == "save_langs" then
        if msg.body.tl then
            AppState.lastTargetLang = msg.body.tl
            hs.settings.set("ftt.targetLang", msg.body.tl)
        end
    elseif act == "pin" then
        AppState.bubblePinned = msg.body.pinned == true
    elseif act == "speak" then
        speakText(msg.body.text, msg.body.lang)
    elseif act == "translate" then
        local text   = msg.body.text
        local sl     = msg.body.sl or "auto"
        local tl     = msg.body.tl or (AppState.lastTargetLang or CONFIG.targetLanguage)
        local reqId  = msg.body.reqId or 0
        local view   = msg.body.view
        local targetWv = (view == "menubar") and AppState.menubarWebview or AppState.bubbleWebview

        performTranslation(text, sl, tl, function(success, translated, rawJson, detectedLang, errorMsg)
            if not targetWv then return end
            local payload = hs.json.encode({
                reqId        = reqId,
                success      = success,
                translated   = translated or "",
                rawJson      = rawJson or "",
                detectedLang = detectedLang,
                errorMsg     = errorMsg or ""
            })
            local js = "if (typeof onTranslationResponse === 'function') { onTranslationResponse(" .. payload .. "); }"
            pcall(function() targetWv:evaluateJavaScript(js) end)
        end)
    elseif act == "start_drag" then
        local targetWv = (msg.body.view == "menubar") and AppState.menubarWebview or AppState.bubbleWebview
        if targetWv and AppState.nativeBridge and AppState.nativeBridge.startDrag then
            if targetWv == AppState.bubbleWebview and AppState.bubbleReadyData then
                AppState.bubbleReadyData.userMoved = true
            end
            pcall(AppState.nativeBridge.startDrag, targetWv)
        end
    elseif act == "render_complete" then
        local view = msg.body.view
        if view == "menubar" then
            if AppState.menubarWebview and msg.body.h then
                local f = AppState.menubarWebview:frame()
                f.h = math.min(math.max(msg.body.h, 180), CONFIG.maxBubbleHeight)
                AppState.menubarWebview:frame(f)
                applyLiquidGlassToWebview(AppState.menubarWebview)
                AppState.menubarWebview:alpha(1.0)
            end
        elseif AppState.bubbleWebview and AppState.bubbleReadyData and msg.body.h then
            local f = AppState.bubbleWebview:frame()
            local actualH = math.min(math.max(msg.body.h, 120), CONFIG.maxBubbleHeight)
            local rd = AppState.bubbleReadyData
            if not rd.userMoved and rd.screen and rd.targetPos then
                local newRect = computeBubbleRect(rd.targetPos, f.w, actualH, rd.screen)
                AppState.bubbleWebview:frame(newRect)
            else
                f.h = actualH
                AppState.bubbleWebview:frame(f)
            end
            applyLiquidGlassToWebview(AppState.bubbleWebview)
            AppState.bubbleWebview:alpha(1.0)
        end
    elseif act == "copy" then
        if msg.body.text then
            hs.pasteboard.setContents(msg.body.text)
        end
    end
end)

-- ==============================================================================
-- BUBBLE POPUP GENERATION
-- ==============================================================================

local function calcInitialBubbleWidth(originalText, translatedText, hasDictionary)
    local totalChars = utf8Len(originalText) + utf8Len(translatedText)
    if totalChars > 240 then
        return math.floor(math.min(480, 360 + (totalChars - 180) * 0.35))
    end
    if hasDictionary then return CONFIG.dictBubbleSize.w end
    return math.floor(math.min(440, math.max(325, 325 + (totalChars - 50) * 0.45)))
end

local function showTranslationBubble(originalText, translatedText, rawJsonBody, targetPos, reqId)
    if reqId and reqId ~= AppState.requestId then return end
    destroyBubble()

    local hasDictionary = false
    if rawJsonBody and rawJsonBody ~= "" then
        local ok, data = pcall(hs.json.decode, rawJsonBody)
        if ok and data and (data.dict or data[2]) then hasDictionary = true end
    end

    local w = calcInitialBubbleWidth(originalText, translatedText, hasDictionary)
    local h = CONFIG.maxBubbleHeight

    local s = getScreenForPoint(targetPos)
    if not s then return end
    local screen = s:frame()
    local rect = computeBubbleRect(targetPos, w, h, screen)

    local initPayload = hs.json.encode({
        orig = originalText or "",
        trans = translatedText or "",
        json = rawJsonBody or "",
        sl = "auto",
        tl = AppState.lastTargetLang or CONFIG.targetLanguage
    })

    if not AppState.bubbleWebview then
        AppState.bubbleWebview = hs.webview.new(rect, { developerExtrasEnabled = false }, AppState.ucc)
        AppState.bubbleWebview:windowStyle({"borderless", "nonactivating", "utility"})
        AppState.bubbleWebview:transparent(true)
        pcall(function() AppState.bubbleWebview:shadow(true) end)
        AppState.bubbleWebview:level(hs.drawing.windowLevels.popUpMenu)
        AppState.bubbleWebview:html(buildBubbleHTML(originalText, translatedText, rawJsonBody))
    else
        AppState.bubbleWebview:frame(rect)
        AppState.bubbleWebview:evaluateJavaScript("resetAndShowBubble(" .. initPayload .. ");")
    end
    AppState.bubbleWebview:alpha(0.0)

    AppState.bubbleReadyData = { screen = screen, targetPos = targetPos, userMoved = false }
    AppState.bubbleWebview:show()
    applyLiquidGlassToWebview(AppState.bubbleWebview)

    AppState.bubbleMouseTap = hs.eventtap.new(
        { hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown },
        function()
            if AppState.bubbleWebview then
                local p = hs.mouse.absolutePosition()
                local f = AppState.bubbleWebview:frame()
                if p.x >= f.x and p.x <= f.x + f.w and p.y >= f.y and p.y <= f.y + f.h then
                    return false
                end
            end
            if AppState.bubblePinned then return false end
            destroyBubble()
            return false
        end
    )
    AppState.bubbleMouseTap:start()

    AppState.bubbleEscapeTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
        if e:getKeyCode() == CONFIG.escKeyCode then
            destroyBubble()
            return true
        end
        return false
    end)
    AppState.bubbleEscapeTap:start()
end

-- ==============================================================================
-- UNICODE-AWARE WORD & AX EXTRACTION ENGINE (macOS 27.2 & Preview PDFKit)
-- ==============================================================================

local UNICODE_DELIMITERS = {
    [0x00A0] = true,
    [0x00AB] = true, [0x00BB] = true,
    [0x00B7] = true, [0x2022] = true,
    [0x2013] = true, [0x2014] = true, [0x2015] = true,
    [0x201C] = true, [0x201D] = true, [0x201E] = true,
    [0x2026] = true,
    [0x202F] = true, [0x3000] = true, [0xFEFF] = true,
    [0x2039] = true, [0x203A] = true,
}

local INTERNAL_CONNECTORS = {
    [0x0027] = true,
    [0x002D] = true,
    [0x2010] = true,
    [0x2018] = true,
    [0x2019] = true,
}

local function isHardDelimiter(cp)
    if not cp then return true end
    if cp <= 0x20 or cp == 0x7F then return true end
    if cp >= 0x2000 and cp <= 0x200B then return true end
    if UNICODE_DELIMITERS[cp] then return true end
    if INTERNAL_CONNECTORS[cp] then return false end
    if cp < 0x80 then
        local ch = string.char(cp)
        if ch:match("[%s%p]") then return true end
    end
    return false
end

local function getWordAroundIndex(text, utf16_index)
    if not text or type(text) ~= "string" or text == "" then return nil end

    local cps = {}
    local targetCpIdx = nil
    local u16 = 0

    local ok = pcall(function()
        for _, cp in utf8.codes(text) do
            cps[#cps + 1] = cp
            if not targetCpIdx and u16 >= utf16_index then
                targetCpIdx = #cps
            end
            u16 = u16 + (cp > 0xFFFF and 2 or 1)
        end
    end)

    if not ok or #cps == 0 then return nil end
    if not targetCpIdx then targetCpIdx = #cps end
    if targetCpIdx < 1 or targetCpIdx > #cps then return nil end

    if isHardDelimiter(cps[targetCpIdx]) then
        if targetCpIdx > 1 and not isHardDelimiter(cps[targetCpIdx - 1]) then
            targetCpIdx = targetCpIdx - 1
        elseif targetCpIdx < #cps and not isHardDelimiter(cps[targetCpIdx + 1]) then
            targetCpIdx = targetCpIdx + 1
        else
            return nil
        end
    end

    local maxChars = 80
    local s = targetCpIdx
    while s > 1 and (targetCpIdx - s) < maxChars do
        if isHardDelimiter(cps[s - 1]) then break end
        s = s - 1
    end

    local e = targetCpIdx
    while e < #cps and (e - targetCpIdx) < maxChars do
        if isHardDelimiter(cps[e + 1]) then break end
        e = e + 1
    end

    while s <= e and INTERNAL_CONNECTORS[cps[s]] do s = s + 1 end
    while e >= s and INTERNAL_CONNECTORS[cps[e]] do e = e - 1 end

    if s > e then return nil end

    local out = {}
    for i = s, e do out[#out + 1] = utf8.char(cps[i]) end
    return table.concat(out)
end

local function extractSelectedTextFromElement(elem)
    if not elem then return nil end
    local ok, sel = pcall(function() return elem:attributeValue("AXSelectedText") end)
    if ok and type(sel) == "string" and sel:match("%S") then
        return sel
    end
    local okR, rng = pcall(function() return elem:attributeValue("AXSelectedTextRange") end)
    if okR and type(rng) == "table" then
        local len = rng.length or rng.len or 0
        if len > 0 then
            local okS, str = pcall(function() return elem:parameterizedAttributeValue("AXStringForRange", rng) end)
            if okS and type(str) == "string" and str:match("%S") then
                return str
            end
        end
    end
    return nil
end

local function getAXSelectedTextDeep(pos)
    local sys = hs.axuielement.systemWideElement()
    if not sys then return nil end

    local focused = sys:attributeValue("AXFocusedUIElement")
    local cur = focused
    local depth = 0
    while cur and depth < 6 do
        local s = extractSelectedTextFromElement(cur)
        if s then return s end
        local okP, parent = pcall(function() return cur:attributeValue("AXParent") end)
        cur = okP and parent or nil
        depth = depth + 1
    end

    if pos then
        local okE, elem = pcall(function() return sys:elementAtPosition(pos) end)
        cur = okE and elem or nil
        depth = 0
        while cur and depth < 8 do
            local s = extractSelectedTextFromElement(cur)
            if s then return s end
            local okP, parent = pcall(function() return cur:attributeValue("AXParent") end)
            cur = okP and parent or nil
            depth = depth + 1
        end
    end

    local app = hs.application.frontmostApplication()
    if app then
        local okA, axApp = pcall(hs.axuielement.applicationElement, app)
        if okA and axApp then
            local okF, appFocused = pcall(function() return axApp:attributeValue("AXFocusedUIElement") end)
            if okF and appFocused then
                local s = extractSelectedTextFromElement(appFocused)
                if s then return s end
            end
        end
    end

    return nil
end

local function isCopyMenuEnabled(app)
    if not app then return false end
    local paths = {
        {"Edit", "Copy"},
        {"Düzen", "Kopyala"},
        {"Édition", "Copier"},
        {"Bearbeiten", "Kopieren"},
        {"Edición", "Copiar"},
    }
    for _, path in ipairs(paths) do
        local ok, item = pcall(function() return app:findMenuItem(path) end)
        if ok and type(item) == "table" and item.enabled ~= nil then
            return item.enabled == true
        end
    end
    return true
end

local function getElementWithRangeSupport(elem)
    local depth = 0
    while elem and depth < 8 do
        local ok, attrs = pcall(function() return elem:parameterizedAttributeNames() end)
        if ok and attrs then
            for _, a in ipairs(attrs) do
                if a == "AXRangeForPosition" then return elem end
            end
        end
        local okP, parent = pcall(function() return elem:attributeValue("AXParent") end)
        elem = okP and parent or nil
        depth = depth + 1
    end
    return nil
end

local function tryNativeAXCoordinateExtraction(pos)
    local sys = hs.axuielement.systemWideElement()
    if not sys then return nil end
    local app = hs.application.frontmostApplication()
    if isAppNativeBlacklisted(app) then return nil end

    local okE, elem = pcall(function() return sys:elementAtPosition(pos) end)
    if okE and elem then
        local rangeElem = getElementWithRangeSupport(elem)
        if rangeElem then
            local okR, cr = pcall(function() return rangeElem:parameterizedAttributeValue("AXRangeForPosition", pos) end)
            if okR and type(cr) == "table" and (cr.location or cr.loc) then
                local loc = cr.loc or cr.location
                local startLoc = math.max(0, loc - 60)
                local chunkRange = { loc = startLoc, len = 120, location = startLoc, length = 120 }
                local okS, chunk = pcall(function() return rangeElem:parameterizedAttributeValue("AXStringForRange", chunkRange) end)
                if okS and type(chunk) == "string" then
                    local w = getWordAroundIndex(chunk, loc - startLoc)
                    if w and w:match("%S") then return w end
                end
            end
        end
    end
    return nil
end

-- ==============================================================================
-- TRANSLATE & NETWORK CLIENT
-- ==============================================================================

local function translateAndShow(text, targetPos)
    text = trim(text)
    if not text or text == "" then return end

    AppState.requestId = AppState.requestId + 1
    local reqId = AppState.requestId
    local tl = AppState.lastTargetLang or CONFIG.targetLanguage

    performTranslation(text, "auto", tl, function(success, translated, rawJson, detectedLang, errorMsg)
        if reqId ~= AppState.requestId then return end
        if success then
            showTranslationBubble(text, translated, rawJson, targetPos, reqId)
        else
            hs.alert.show(errorMsg or "Translation could not be retrieved.")
        end
    end)
end

-- ==============================================================================
-- CLIPBOARD-SAFE EXTRACTION & DOUBLE-CLICK ENGINE
-- ==============================================================================

local function copyViaClipboardSafe(callback)
    local oldClip = hs.pasteboard.readAllData()
    hs.pasteboard.clearContents()
    local initialCount = hs.pasteboard.changeCount()

    local function pollClipboard(maxTries, currentTry)
        if currentTry > maxTries then
            if oldClip then hs.pasteboard.writeAllData(oldClip) else hs.pasteboard.clearContents() end
            callback(nil)
            return
        end
        if hs.pasteboard.changeCount() ~= initialCount then
            local copied = hs.pasteboard.getContents()
            if oldClip then hs.pasteboard.writeAllData(oldClip) else hs.pasteboard.clearContents() end
            callback(copied)
        else
            hs.timer.doAfter(0.015, function()
                pollClipboard(maxTries, currentTry + 1)
            end)
        end
    end

    hs.eventtap.keyStroke({"cmd"}, "c", 0)
    pollClipboard(14, 1)
end

local function performAsyncDoubleClick(pos, onComplete)
    AppState.isSyntheticClick = true

    local function makeMouseEvent(evType, clickState)
        local ev = hs.eventtap.event.newMouseEvent(evType, pos)
        ev:setProperty(hs.eventtap.event.properties.mouseEventClickState, clickState)
        return ev
    end

    makeMouseEvent(hs.eventtap.event.types.leftMouseDown, 1):post()
    hs.timer.doAfter(0.004, function()
        makeMouseEvent(hs.eventtap.event.types.leftMouseUp, 1):post()
        hs.timer.doAfter(0.006, function()
            makeMouseEvent(hs.eventtap.event.types.leftMouseDown, 2):post()
            hs.timer.doAfter(0.004, function()
                makeMouseEvent(hs.eventtap.event.types.leftMouseUp, 2):post()
                hs.timer.doAfter(0.035, function()
                    AppState.isSyntheticClick = false
                    if onComplete then onComplete() end
                end)
            end)
        end)
    end)
end

local function extractWordByDoubleClickAndTranslate(pos)
    performAsyncDoubleClick(pos, function()
        local axWord = getAXSelectedTextDeep(pos)
        if axWord and type(axWord) == "string" and axWord:match("%S") then
            translateAndShow(axWord, pos)
            return
        end

        copyViaClipboardSafe(function(wordText)
            if wordText and type(wordText) == "string" and wordText:match("%S") then
                translateAndShow(wordText, pos)
            else
                hs.alert.show("No text found under cursor.")
            end
        end)
    end)
end

-- ==============================================================================
-- SMART SELECTION WATCHER (Solves Preview Pre-Force-Click Deselection!)
-- ==============================================================================

local function isPointInManualSelection(pt, app)
    local ms = AppState.manualSelection
    if not ms then return false end
    local now = hs.timer.secondsSinceEpoch()
    if (now - ms.time) > CONFIG.selectionTTL then
        AppState.manualSelection = nil
        return false
    end
    if app and ms.appPID and app:pid() ~= ms.appPID then
        AppState.manualSelection = nil
        return false
    end
    if not ms.bounds or not pt then return true end
    local b = ms.bounds
    local padX = CONFIG.selectionPadding.x
    local padY = CONFIG.selectionPadding.y
    return (pt.x >= b.minX - padX and pt.x <= b.maxX + padX and
            pt.y >= b.minY - padY and pt.y <= b.maxY + padY)
end

local function captureManualSelectionSnapshot(endPos, bounds, isMultiClick)
    stopAndNil("selectionCaptureTimer")
    AppState.selectionCaptureTimer = hs.timer.doAfter(0.035, function()
        if AppState.forceClickDetected or AppState.isSyntheticClick then return end
        local app = hs.application.frontmostApplication()
        if not app or isAppIgnored(app) then return end

        local midPos = bounds and { x = (bounds.minX + bounds.maxX) / 2, y = (bounds.minY + bounds.maxY) / 2 } or endPos
        local axSel = getAXSelectedTextDeep(endPos) or getAXSelectedTextDeep(midPos)

        if axSel and axSel:match("%S") then
            AppState.manualSelection = {
                text           = axSel,
                bounds         = bounds,
                time           = hs.timer.secondsSinceEpoch(),
                appPID         = app:pid(),
                needsClipboard = false,
            }
            return
        end

        if isAppNativeBlacklisted(app) and isCopyMenuEnabled(app) then
            copyViaClipboardSafe(function(clipText)
                if clipText and type(clipText) == "string" and clipText:match("%S") then
                    AppState.manualSelection = {
                        text           = clipText,
                        bounds         = bounds,
                        time           = hs.timer.secondsSinceEpoch(),
                        appPID         = app:pid(),
                        needsClipboard = false,
                    }
                end
            end)
        elseif not isMultiClick then
            AppState.manualSelection = {
                text           = nil,
                bounds         = bounds,
                time           = hs.timer.secondsSinceEpoch(),
                appPID         = app:pid(),
                needsClipboard = true,
            }
        end
    end)
end

local function isPointInsideTranslatorUI(pt)
    if not pt then return false end
    if AppState.bubbleWebview and AppState.bubbleReadyData then
        local f = AppState.bubbleWebview:frame()
        if f and pt.x >= f.x and pt.x <= f.x + f.w and pt.y >= f.y and pt.y <= f.y + f.h then
            return true
        end
    end
    if AppState.menubarWebview then
        local f = AppState.menubarWebview:frame()
        if f and pt.x >= f.x and pt.x <= f.x + f.w and pt.y >= f.y and pt.y <= f.y + f.h then
            return true
        end
    end
    return false
end

AppState.selectionTap = hs.eventtap.new(
    {
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.leftMouseDragged,
        hs.eventtap.event.types.leftMouseUp,
    },
    function(event)
        if AppState.isSyntheticClick then return false end

        local evType = event:getType()
        local pos    = hs.mouse.absolutePosition()

        if evType == hs.eventtap.event.types.leftMouseDown then
            if isPointInsideTranslatorUI(pos) then
                AppState.dragStartPos = nil
                AppState.isDragging   = false
                AppState.dragBounds   = nil
                return false
            end

            local flags = event:getFlags()
            if flags and flags.shift and AppState.dragStartPos then
                if AppState.dragBounds then
                    AppState.dragBounds.minX = math.min(AppState.dragBounds.minX, pos.x)
                    AppState.dragBounds.maxX = math.max(AppState.dragBounds.maxX, pos.x)
                    AppState.dragBounds.minY = math.min(AppState.dragBounds.minY, pos.y)
                    AppState.dragBounds.maxY = math.max(AppState.dragBounds.maxY, pos.y)
                end
                return false
            end

            AppState.dragStartPos = pos
            AppState.isDragging   = false
            AppState.dragBounds   = { minX = pos.x, maxX = pos.x, minY = pos.y, maxY = pos.y }

            local app = hs.application.frontmostApplication()
            if AppState.manualSelection and not isPointInManualSelection(pos, app) then
                AppState.manualSelection = nil
            end
            return false

        elseif evType == hs.eventtap.event.types.leftMouseDragged then
            if AppState.dragStartPos and not AppState.forceClickDetected then
                if distance(AppState.dragStartPos, pos) >= CONFIG.minDragSelectDist then
                    AppState.isDragging = true
                end
                if AppState.dragBounds then
                    local b = AppState.dragBounds
                    if pos.x < b.minX then b.minX = pos.x end
                    if pos.x > b.maxX then b.maxX = pos.x end
                    if pos.y < b.minY then b.minY = pos.y end
                    if pos.y > b.maxY then b.maxY = pos.y end
                end
            end
            return false

        elseif evType == hs.eventtap.event.types.leftMouseUp then
            if not AppState.dragStartPos or isPointInsideTranslatorUI(pos) then
                AppState.isDragging = false
                return false
            end
            if AppState.forceClickDetected then
                AppState.isDragging = false
                return false
            end

            local clickState = event:getProperty(hs.eventtap.event.properties.mouseEventClickState) or 1
            local flags      = event:getFlags()

            if AppState.isDragging and AppState.dragBounds then
                local boundsCopy = {
                    minX = AppState.dragBounds.minX,
                    maxX = AppState.dragBounds.maxX,
                    minY = AppState.dragBounds.minY,
                    maxY = AppState.dragBounds.maxY,
                }
                AppState.isDragging = false
                captureManualSelectionSnapshot(pos, boundsCopy, false)
            elseif clickState >= 2 or (flags and flags.shift) then
                local box = {
                    minX = pos.x - 80, maxX = pos.x + 80,
                    minY = pos.y - 30, maxY = pos.y + 30,
                }
                captureManualSelectionSnapshot(pos, box, true)
            else
                AppState.manualSelection = nil
            end
            return false
        end

        return false
    end
)
AppState.selectionTap:start()

-- ==============================================================================
-- MAIN EVENT TAP (FORCE TOUCH)
-- ==============================================================================

AppState.tap = hs.eventtap.new({ hs.eventtap.event.types.gesture }, function(event)
    local event_type = event:getType(true)
    if event_type ~= hs.eventtap.event.types.pressure then return false end

    local td = event:getTouchDetails()
    if not td then return false end

    if td.stage == 2 and td.pressure > 0.0 then
        if not AppState.forceClickDetected then
            destroyBubble()
            stopAndNil("selectionCaptureTimer")
            AppState.forceClickDetected = true
            AppState.ignoreCurrentClick = false
            AppState.dispatchedOnStage2 = false
            AppState.isDragging         = false
            AppState.targetPos          = hs.mouse.absolutePosition()

            local app = hs.application.frontmostApplication()
            if isAppIgnored(app) then
                AppState.ignoreCurrentClick = true
                return false
            end

            local currentTargetPos = AppState.targetPos

            if isPointInManualSelection(currentTargetPos, app) and AppState.manualSelection then
                local ms = AppState.manualSelection
                AppState.manualSelection = nil
                if ms.text and ms.text:match("%S") then
                    AppState.dispatchedOnStage2 = true
                    hs.timer.doAfter(0.005, function()
                        translateAndShow(ms.text, currentTargetPos)
                    end)
                    return true
                elseif ms.needsClipboard then
                    AppState.dispatchedOnStage2 = true
                    hs.timer.doAfter(0.01, function()
                        copyViaClipboardSafe(function(clipText)
                            if clipText and type(clipText) == "string" and clipText:match("%S") then
                                translateAndShow(clipText, currentTargetPos)
                            else
                                extractWordByDoubleClickAndTranslate(currentTargetPos)
                            end
                        end)
                    end)
                    return true
                end
            end

            local liveSel = getAXSelectedTextDeep(currentTargetPos)
            if liveSel and liveSel:find("%s") then
                AppState.dispatchedOnStage2 = true
                hs.timer.doAfter(0.005, function()
                    translateAndShow(liveSel, currentTargetPos)
                end)
                return true
            end

            local nativeWord = tryNativeAXCoordinateExtraction(currentTargetPos)
            if nativeWord and nativeWord:match("%S") then
                AppState.dispatchedOnStage2 = true
                hs.timer.doAfter(0.005, function()
                    translateAndShow(nativeWord, currentTargetPos)
                end)
                return true
            end
        elseif AppState.ignoreCurrentClick then
            return false
        end
        return true
    end

    if AppState.forceClickDetected and (td.stage == 0 or td.pressure == 0.0) then
        AppState.forceClickDetected = false
        if AppState.ignoreCurrentClick then
            AppState.ignoreCurrentClick = false
            return false
        end

        if AppState.dispatchedOnStage2 then
            AppState.dispatchedOnStage2 = false
            return true
        end

        if distance(AppState.targetPos, hs.mouse.absolutePosition()) > CONFIG.dragThreshold then
            return false
        end

        local currentTargetPos = AppState.targetPos
        hs.timer.doAfter(0.01, function()
            extractWordByDoubleClickAndTranslate(currentTargetPos)
        end)

        return true
    end

    return false
end)
AppState.tap:start()

AppState.watchdogTimer = hs.timer.doEvery(2, function()
    if not AppState.isWakingUp then
        if AppState.tap and not AppState.tap:isEnabled() then AppState.tap:start() end
        if AppState.selectionTap and not AppState.selectionTap:isEnabled() then AppState.selectionTap:start() end
    end
end)

AppState.wakeWatcher = hs.caffeinate.watcher.new(function(eventType)
    if eventType == hs.caffeinate.watcher.screensDidWake or eventType == hs.caffeinate.watcher.systemDidWake then
        AppState.isWakingUp = true
        if AppState.tap then AppState.tap:stop() end
        if AppState.selectionTap then AppState.selectionTap:stop() end
        hs.timer.doAfter(2, function()
            if AppState.tap then AppState.tap:start() end
            if AppState.selectionTap then AppState.selectionTap:start() end
            AppState.isWakingUp = false
        end)
    end
end)
AppState.wakeWatcher:start()

-- ==============================================================================
-- MENUBAR UI
-- ==============================================================================

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

    AppState.previousApp = hs.application.frontmostApplication()

    local frame = AppState.menubar:frame()
    if not frame then return end

    local w, h = CONFIG.menubarSize.w, CONFIG.menubarSize.h
    local x = frame.x - (w / 2) + (frame.w / 2)
    local y = frame.y + frame.h + 5

    local s = getScreenForPoint({ x = frame.x, y = frame.y })
    if not s then return end
    local screen = s:frame()
    if x + w > screen.x + screen.w then x = screen.x + screen.w - w - 10 end
    x = math.max(screen.x + 10, x)

    local rect = hs.geometry.rect(x, y, w, h)

    AppState.menubarWebview = hs.webview.new(rect, { developerExtrasEnabled = false }, AppState.ucc)
    AppState.menubarWebview:windowStyle({"borderless"})
    AppState.menubarWebview:transparent(true)
    pcall(function() AppState.menubarWebview:shadow(true) end)
    AppState.menubarWebview:level(hs.drawing.windowLevels.popUpMenu)
    if AppState.menubarWebview.allowTextEntry then AppState.menubarWebview:allowTextEntry(true) end

    AppState.menubarWebview:alpha(0.0)
    AppState.menubarWebview:html(buildMenubarHTML())
    AppState.menubarWebview:show()
    applyLiquidGlassToWebview(AppState.menubarWebview)

    hs.timer.doAfter(0.05, function()
        if AppState.menubarWebview then
            local hsApp = hs.application.get("org.hammerspoon.Hammerspoon") or hs.application.get("Hammerspoon")
            if hsApp then hsApp:activate() end
            AppState.menubarWebview:bringToFront(true)
            applyLiquidGlassToWebview(AppState.menubarWebview)
            AppState.menubarWebview:alpha(1.0)
        end
    end)

    AppState.menubarMouseTap = hs.eventtap.new(
        { hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown },
        function()
            if AppState.menubarWebview then
                local p = hs.mouse.absolutePosition()
                local mf = AppState.menubarWebview:frame()
                if p.x >= mf.x and p.x <= mf.x + mf.w and p.y >= mf.y and p.y <= mf.y + mf.h then return false end
                if p.y <= frame.y + frame.h and p.x >= frame.x and p.x <= frame.x + frame.w then return false end
            end
            destroyMenubar()
            return false
        end
    )
    AppState.menubarMouseTap:start()
end

AppState.menubar:setClickCallback(toggleMenubar)
_G.AppState = AppState
_G.translateAndShow = translateAndShow
_G.toggleMenubar = toggleMenubar
hs.alert.show("ForceTouchTranslator v3.0 Active!")
