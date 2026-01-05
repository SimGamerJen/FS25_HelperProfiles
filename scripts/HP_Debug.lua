-- HP_Debug.lua (FS25_HelperProfiles) — robust console parsing + debounce + external config cmds

-- ============================================================================
-- FS25_HelperProfiles
-- ModVersion: 1.1.0.2
-- Script:     HP_Debug.lua
-- BuildTag:   20260105-1
-- ============================================================================

do
    local MOD_VERSION   = "1.1.0.1"
    local SCRIPT_NAME   = "HP_Debug.lua"
    local BUILD_TAG     = "20260102-5"
    local SCRIPT_VER    = string.format("%s-%s+%s", MOD_VERSION, SCRIPT_NAME, BUILD_TAG)

    local vi = rawget(_G, "FS25_HelperProfiles_VersionInfo")
    if vi == nil then
        vi = { modVersion = MOD_VERSION, scripts = {} }
        _G.FS25_HelperProfiles_VersionInfo = vi
    end

    vi.modVersion = vi.modVersion or MOD_VERSION
    vi.scripts = vi.scripts or {}
    vi.scripts[SCRIPT_NAME] = SCRIPT_VER
end

HP_Debug = {}
local Debug = HP_Debug

local function _printf(fmt, ...)
    print(("[HP] " .. fmt):format(...))
end

local function _boolArg(s)
    if s == nil then return nil end
    s = string.lower(tostring(s))
    if s == "1" or s == "true" or s == "on" or s == "yes" then return true end
    if s == "0" or s == "false" or s == "off" or s == "no" then return false end
    return nil
end

local function normalizeArgs(...)
    local args = {...}
    local sub, p1, p2, p3, p4
    for i = 1, #args do
        local v = args[i]
        if v ~= nil and v ~= "" then
            if v == "hpOverlay" or v == "hpSelect" or v == "hpCycle" or v == "hpNext" or v == "hpDump" or v == "hpResetOrder" or v == "hpMode" then
                -- skip command name echoes
            elseif not sub then
                sub = v
            elseif not p1 then
                p1 = v
            elseif not p2 then
                p2 = v
            elseif not p3 then
                p3 = v
            else
                p4 = v
            end
        end
    end
    return sub, p1, p2, p3, p4
end

-- ===== Overlay commands (as METHODS) =========================================

function Debug:hpOverlay(...)
    if HP_UI == nil then _printf("UI not loaded"); return end

    local a, b, c, d = normalizeArgs(...)
    a = (a or ""):lower()

    if a == "help" or a == "" then
        _printf("hpOverlay commands:")
        _printf("  on|off|toggle")
        _printf("  pos <x 0..1> <y 0..1> | anchor TL|TR|BL|BR")
        _printf("  scale <0.5..2.0> | width <0.15..0.90> | opacity <0..1> | font <0.010..0.030>")
        _printf("  rowgap <0.001..0.03> | maxrows <3..30> | pad <0..0.05>")
        _printf("  bg on|off | outline on|off | markers on|off | bindhud on|off")
        _printf("  debounce <ms>")
        _printf("  save [filename]   (to modSettings/FS25_HelperProfiles)")
        _printf("  load [filename]   (reads from modSettings/FS25_HelperProfiles)")
        _printf("  reset             (reverts to defaults and saves)")
        return
    elseif a == "on" or a == "off" or a == "toggle" then
        if a == "on" then HP_UI:setVisible(true)
        elseif a == "off" then HP_UI:setVisible(false)
        else HP_UI:toggle() end
        _printf("Overlay visible=%s", tostring(HP_UI.visible)); return

    elseif a == "pos" then
        HP_UI:setPos(b, c)
        _printf("Overlay pos set to x=%.3f y=%.3f (anchor %s)", HP_UI.x, HP_UI.y, HP_UI.anchor); return

    elseif a == "anchor" then
        HP_UI:setAnchor(b or "TR"); _printf("Overlay anchor=%s", HP_UI.anchor); return

    elseif a == "scale" then
        HP_UI:setScale(b); _printf("Overlay scale=%.2f", HP_UI.scale); return

    elseif a == "width" then
        if HP_UI.setWidth then HP_UI:setWidth(b) end
        _printf("Overlay width=%.3f (screen units)", HP_UI.width); return

    elseif a == "opacity" then
        HP_UI:setOpacity(b); _printf("Overlay opacity=%.2f", HP_UI.opacity); return

    elseif a == "font" then
        HP_UI:setFontSize(b); _printf("Overlay fontSize=%.3f", HP_UI.fontSize); return

    elseif a == "rowgap" then
        HP_UI:setRowGap(b); _printf("Overlay rowGap=%.3f", HP_UI.rowGap); return

    elseif a == "maxrows" then
        HP_UI:setMaxRows(b); _printf("Overlay maxRows=%d", HP_UI.maxRows); return

    elseif a == "bg" then
        local bol = _boolArg(b); if bol == nil then _printf("Usage: hpOverlay bg on|off"); return end
        HP_UI:setBackground(bol); _printf("Overlay background=%s", tostring(HP_UI.bgEnabled)); return

    elseif a == "pad" then
        HP_UI:setPadding(b); _printf("Overlay pad=%.3f", HP_UI.pad); return

    elseif a == "outline" then
        local bol = _boolArg(b); if bol == nil then _printf("Usage: hpOverlay outline on|off"); return end
        HP_UI:setOutline(bol); _printf("Overlay outline=%s", tostring(HP_UI.outline)); return

    elseif a == "markers" then
        local bol = _boolArg(b); if bol == nil then _printf("Usage: hpOverlay markers on|off"); return end
        HP_UI.showMarkers = bol; _printf("Overlay markers=%s", tostring(HP_UI.showMarkers)); return

    elseif a == "bindhud" then
        local bol = _boolArg(b); if bol == nil then _printf("Usage: hpOverlay bindhud on|off"); return end
        HP_UI.bindHud = bol; _printf("Overlay bindHud=%s", tostring(HP_UI.bindHud)); return

    elseif a == "debounce" then
        local ms = tonumber(b); if not ms then _printf("Usage: hpOverlay debounce <ms>"); return end
        HelperProfiles._cycleDebounceMs = math.max(0, math.floor(ms))
        _printf("Cycle debounce set to %d ms", HelperProfiles._cycleDebounceMs); return

    elseif a == "save" then
        if not HP_Config or not HP_Config.write then _printf("Config system unavailable"); return end
        HP_Config:init()
        local out
        if b and b ~= "" then out = HP_Config.dir .. b else out = HP_Config.path end
        if not string.find(string.lower(out), "%.xml$") then out = out .. ".xml" end
        local ok, err = HP_Config:write(out)
        if ok then _printf("Saved overlay config -> %s", out) else _printf("Save failed: %s", tostring(err)) end
        return

    elseif a == "load" then
        if not HP_Config or not HP_Config.read or not HP_Config.applyToUI then _printf("Config system unavailable"); return end
        HP_Config:init()
        local src
        if b and b ~= "" then src = HP_Config.dir .. b else src = HP_Config.path end
        if not string.find(string.lower(src or ""), "%.xml$") then src = src .. ".xml" end
        local cfg, err = HP_Config:read(src)
        if cfg then
            HP_Config:applyToUI(cfg); _printf("Loaded overlay config <- %s", src)
        else
            _printf("Load failed: %s", tostring(err or "unknown"))
        end
        return

    elseif a == "reset" then
        if not HP_Config or not HP_Config.getDefaults or not HP_Config.applyToUI or not HP_Config.write then _printf("Config system unavailable"); return end
        local def = HP_Config:getDefaults()
        HP_Config:applyToUI(def)
        local ok = HP_Config:write()
        _printf("Overlay reset to defaults%s", ok and " (saved)" or "")
        return

    else
        _printf("Unknown hpOverlay subcommand '%s' (try: hpOverlay help)", tostring(a))
    end
end

function Debug:hpSelect(...)
    local a = normalizeArgs(...)
    local idx = tonumber(a)
    if not idx then _printf("Usage: hpSelect <index>"); return end
    if HelperProfiles and HelperProfiles.setSelection then
        HelperProfiles:setSelection(idx)
    else
        _printf("Core does not expose setSelection()")
    end
end

function Debug:hpCycle(...)
    local a = normalizeArgs(...)
    local delta = tonumber(a) or 1
    if HelperProfiles and HelperProfiles.cycleSelectionDebounced then
        HelperProfiles:cycleSelectionDebounced(delta)
    elseif HelperProfiles and HelperProfiles.cycleSelection then
        HelperProfiles:cycleSelection(delta)
    else
        _printf("Core does not expose cycleSelection()")
    end
end

function Debug:hpNext(...)
    if HelperProfiles and HelperProfiles.pickPreferredFreeHelper then
        local h, why = HelperProfiles:pickPreferredFreeHelper()
        if h then _printf("Next to hire: %s (reason=%s)", h.name or "?", tostring(why))
        else _printf("No free helper (reason=%s)", tostring(why)) end
    else
        _printf("Core does not expose pickPreferredFreeHelper()")
    end
end

function Debug:hpDump(...)
    if HelperProfiles and HelperProfiles.getProfiles then
        local list = HelperProfiles:getProfiles()
        _printf("Active helpers: %d", #list)
        for i, h in ipairs(list) do
            _printf("  %02d  name=%s  inUse=%s", i, h.name or ("Helper "..i), tostring(h.inUse==true))
        end
    else
        _printf("HelperProfiles.getProfiles() not available")
    end
end

function Debug:hpResetOrder(...)
    if HelperProfiles and HelperProfiles.resetOrderToDefault then
        local ok, err = HelperProfiles:resetOrderToDefault()
        if ok then _printf("Helper order reset to default")
        else _printf("Reset failed: %s", tostring(err or "unknown")) end
    else
        _printf("Core does not expose resetOrderToDefault()")
    end
end

-- ===== Registration for both console APIs ====================================

local function registerCommandDual(name, desc, methodName)
    local ok = false
    if g_console and g_console.addCommand then
        g_console:addCommand(name, desc, methodName, Debug); ok = true
    end
    if not ok and addConsoleCommand ~= nil then
        addConsoleCommand(name, desc, methodName, Debug); ok = true
    end
    _G[name] = function(...)
        local fn = Debug[methodName]
        if fn then return fn(Debug, ...) end
    end
end


function Debug:hpMode(...)
    local sub = normalizeArgs(...)
    if sub == nil or sub == "" or sub == "help" then
        print("[HP] hpMode status | firstFree | preferSelected")
        return
    end
    if sub == "status" then
        if HelperProfiles and HelperProfiles.getPickMode then
            print(("[HP] Mode=%s"):format(tostring(HelperProfiles:getPickMode())))
        elseif HelperProfiles and HelperProfiles._pickMode then
            print(("[HP] Mode=%s"):format(tostring(HelperProfiles._pickMode)))
        else
            print("[HP] HelperProfiles does not expose mode controls")
        end
        return
    end

    if not HelperProfiles or not HelperProfiles.setPickMode then
        print("[HP] HelperProfiles does not expose mode controls (setPickMode/getPickMode missing)")
        return
    end

    local ok, why = HelperProfiles:setPickMode(sub, false)
    if ok then
        print(("[HP] Mode set to %s"):format(tostring(sub)))
    else
        print(("[HP] Invalid mode '%s' (%s)"):format(tostring(sub), tostring(why)))
    end
end

function Debug:loadMap()
    registerCommandDual("hpOverlay",    "Configure HelperProfiles overlay", "hpOverlay")
    registerCommandDual("hpSelect",     "Select helper index",             "hpSelect")
    registerCommandDual("hpCycle",      "Cycle selection by delta",        "hpCycle")
    registerCommandDual("hpNext",       "Print next helper to be hired",   "hpNext")
    registerCommandDual("hpDump",       "Dump active helpers to the log",  "hpDump")
    registerCommandDual("hpMode",       "Set helper selection mode (firstFree/preferSelected)", "hpMode")
    registerCommandDual("hpResetOrder", "Reset helper list to default order (when idle)", "hpResetOrder")
end

addModEventListener(HP_Debug)