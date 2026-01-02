-- HP_UI.lua (FS25_HelperProfiles) — FS25-styled overlay (guarded APIs)
-- Now also auto-loads config from modSettings/FS25_HelperProfiles/config.xml (if HP_Config is present)

-- ============================================================================
-- FS25_HelperProfiles
-- ModVersion: 1.1.0.1
-- Script:     HP_UI.lua
-- BuildTag:   20260102-4
-- ============================================================================

do
    local MOD_VERSION   = "1.1.0.1"
    local SCRIPT_NAME   = "HP_UI.lua"
    local BUILD_TAG     = "20260102-4"
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

---@class HP_UI
HP_UI = {
    bindHud     = true,  -- when true, overlay hides if base HUD is hidden (HideHUD etc.)
    visible     = true,
    anchor      = "TR",   -- TL | TR | BL | BR
    x           = 0.985,  -- screen-space (0..1) anchor offset
    y           = 0.900,
    scale       = 1.0,
    opacity     = 0.85,   -- background opacity
    pad         = 0.006,  -- panel padding
    rowGap      = 0.006,  -- vertical gap between rows
    fontSize    = 0.014,  -- base font size
    maxRows     = 10,
    width       = 0.22,   -- panel width in screen units (0..1)
    bgEnabled   = true,
    outline     = false,  -- thin outline around panel
    shadow      = false,  -- soft text shadow
    showMarkers = true,   -- « selected / ← next markers
    flashText   = nil,
    flashTime   = 0
}

-- ===== Safe wrappers (no-ops if engine funcs missing) ========================

local function safeSetTextAlign(a)
    if _G.setTextAlignment ~= nil then
        setTextAlignment(a)
    end
end

local function safeRenderText(x, y, size, txt)
    if _G.renderText ~= nil then
        renderText(x, y, size, txt)
    end
end

local function safeGetTextColor()
    if _G.getTextColor ~= nil then
        return getTextColor()
    end
    return 1, 1, 1, 1
end

local function safeSetTextColor(r, g, b, a)
    if _G.setTextColor ~= nil then
        setTextColor(r, g, b, a)
    end
end

-- rectangles: prefer drawFilledRect; if missing, no-op
local function safeRect(x, y, w, h, r, g, b, a)
    if _G.drawFilledRect ~= nil then
        drawFilledRect(x, y, w, h, r, g, b, a)
    end
end

local function drawOutline(x, y, w, h, a)
    local t = 0.0018
    safeRect(x, y, w, t, 1, 1, 1, a)                 -- bottom
    safeRect(x, y + h - t, w, t, 1, 1, 1, a)         -- top
    safeRect(x, y, t, h, 1, 1, 1, a)                 -- left
    safeRect(x + w - t, y, t, h, 1, 1, 1, a)         -- right
end

local function shadowedText(x, y, size, txt)
    if not HP_UI.shadow then
        safeRenderText(x, y, size, txt)
        return
    end
    local ox, oy = 0.0012, -0.0012
    local r, g, b, a = safeGetTextColor()
    safeSetTextColor(0, 0, 0, math.min(1, a * 0.75))
    safeRenderText(x + ox, y + oy, size, txt)
    safeSetTextColor(r, g, b, a)
    safeRenderText(x, y, size, txt)
end

local function clamp(v, lo, hi)
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

-- ===== Public config setters ==================================================

function HP_UI:setVisible(val) self.visible = val and true or false end
function HP_UI:toggle() self.visible = not self.visible end

function HP_UI:setAnchor(anchor)
    anchor = string.upper(anchor or "")
    if anchor == "TL" or anchor == "TR" or anchor == "BL" or anchor == "BR" then
        self.anchor = anchor
    end
end

function HP_UI:setPos(x, y)
    self.x = clamp(tonumber(x) or self.x, 0.0, 1.0)
    self.y = clamp(tonumber(y) or self.y, 0.0, 1.0)
end

function HP_UI:setScale(s)      self.scale    = clamp(tonumber(s)  or self.scale,    0.5, 2.0) end
function HP_UI:setOpacity(a)    self.opacity  = clamp(tonumber(a)  or self.opacity,  0.0, 1.0) end
function HP_UI:setFontSize(sz)  self.fontSize = clamp(tonumber(sz) or self.fontSize, 0.010, 0.030) end
function HP_UI:setRowGap(gap)   self.rowGap   = clamp(tonumber(gap) or self.rowGap,  0.001, 0.030) end

function HP_UI:setMaxRows(n)
    local val = tonumber(n) or self.maxRows
    val = math.floor(val)
    self.maxRows = clamp(val, 3, 30)
end

function HP_UI:setWidth(w)
    w = tonumber(w)
    if not w then return end
    -- sensible bounds for 16:9; tweak if you like
    if w < 0.15 then w = 0.15 end
    if w > 0.90 then w = 0.90 end
    self.width = w
end

function HP_UI:setBackground(b) self.bgEnabled = b and true or false end
function HP_UI:setPadding(pad)  self.pad      = clamp(tonumber(pad) or self.pad, 0.0, 0.05) end
function HP_UI:setOutline(b)    self.outline  = b and true or false end
function HP_UI:flash(text, secs) self.flashText = text or ""; self.flashTime = tonumber(secs) or 2.0 end

-- ===== Data collection ========================================================

local function collectRows()
    if HelperProfiles == nil or HelperProfiles.getProfiles == nil then
        return "Helpers active: 0 | Selected: - | Next: -", {}
    end

    local profiles = HelperProfiles:getProfiles() or {}

    local selectedIdx
    if HelperProfiles.getSelectionIndex ~= nil then
        selectedIdx = HelperProfiles:getSelectionIndex()
    else
        selectedIdx = HelperProfiles.selectedIdx
    end
    if type(selectedIdx) ~= "number" then selectedIdx = 1 end
    if selectedIdx < 1 or selectedIdx > #profiles then selectedIdx = 1 end

    local nextHelper, reason = nil, "n/a"
    if HelperProfiles.pickPreferredFreeHelper ~= nil then
        nextHelper, reason = HelperProfiles:pickPreferredFreeHelper()
    end

    local selName = (#profiles > 0 and profiles[selectedIdx] and (profiles[selectedIdx].name or ("Helper " .. tostring(selectedIdx)))) or "-"
    local nextName = nextHelper and (nextHelper.name or ("Helper " .. tostring(nextHelper.index or "?"))) or ("(" .. tostring(reason) .. ")")

    local rows = {}
    for idx, h in ipairs(profiles) do
        local state = (h.inUse and "IN USE") or "FREE"
        local marks = {}
        if HP_UI.showMarkers then
            if idx == selectedIdx then table.insert(marks, "» sel") end
            if nextHelper == h   then table.insert(marks, "← next") end
        end
        local suffix = (#marks > 0) and ("  " .. table.concat(marks, "  ")) or ""
        local line = string.format("%02d  %s  [%s]%s", idx, h.name or ("Helper " .. idx), state, suffix)

        table.insert(rows, {
            text = line,
            inUse = (h.inUse == true),
            isSelected = (idx == selectedIdx),
            isNext = (nextHelper == h)
        })
    end

    local mode = "-"
    if HelperProfiles ~= nil then
        if HelperProfiles.getPickMode ~= nil then
            local ok, res = pcall(function() return HelperProfiles:getPickMode() end)
            if ok and res ~= nil and res ~= "" then mode = tostring(res) end
        elseif HelperProfiles._pickMode ~= nil then
            mode = tostring(HelperProfiles._pickMode)
        end
    end

    local header = string.format("Mode: %s | Helpers active: %d | Selected: %s | Next: %s", mode, #profiles, selName, nextName)
    return header, rows
end

-- ===== Layout helpers =========================================================

local function place(w, h)
    local x = HP_UI.x
    local y = HP_UI.y
    if HP_UI.anchor == "TR" then
        return x - w, y - h
    elseif HP_UI.anchor == "TL" then
        return x, y - h
    elseif HP_UI.anchor == "BR" then
        return x - w, y
    end
    return x, y -- BL
end

-- Replace the whole function with this version
function HP_UI:onToggleAction(actionName, inputValue, callbackState, isAnalog)
    -- GIANTS sends either (name, value, state, isAnalog) OR (name, keyStatus)
    local v = 0
    if type(inputValue) == "number" then
        v = inputValue                      -- typical path: >0 on press, 0 on release
    elseif type(inputValue) == "boolean" then
        v = inputValue and 1 or 0
    else
        -- Some builds pass keyStatus as 2nd arg when using legacy style
        -- e.g. function(self, actionName, keyStatus)
        v = tonumber(callbackState) or 0
    end

    if v <= 0 then return end  -- only act on press
    self:toggle()
    if self.visible then
        self:flash("HelperProfiles overlay: ON", 1.25)
    else
        print("[FS25_HelperProfiles] Overlay: OFF")
    end
end

local function _isBaseHudShown()
    -- Prefer mission HUD visibility if available
    if g_currentMission ~= nil then
        local hud = g_currentMission.hud
        if hud ~= nil then
            if hud.getIsVisible ~= nil then
                local ok, res = pcall(function() return hud:getIsVisible() end)
                if ok then return res end
            end
            if hud.getVisible ~= nil then
                local ok, res = pcall(function() return hud:getVisible() end)
                if ok then return res end
            end
            if hud.isVisible ~= nil then
                return hud.isVisible and true or false
            end
        end
    end
    -- Fallback to game setting, many mods flip this when hiding the HUD
    if g_gameSettings ~= nil and g_gameSettings.getValue ~= nil then
        local ok, res = pcall(function() return g_gameSettings:getValue("showHud") end)
        if ok and res ~= nil then return (res == true) end
    end
    -- Default: assume shown
    return true
end

-- ===== Render =================================================================

function HP_UI:render(dtMillis)
    -- flash banner (top-center)
    if self.flashTime ~= nil and self.flashTime > 0 then
        local dt = tonumber(dtMillis) or 16
        self.flashTime = math.max(0, self.flashTime - dt * 0.001)
        if self.flashTime > 0 and self.flashText ~= nil and self.flashText ~= "" then
            if _G.RenderText ~= nil and RenderText.ALIGN_CENTER ~= nil then
                safeSetTextAlign(RenderText.ALIGN_CENTER)
            end
            safeSetTextColor(1, 1, 1, 1)
            shadowedText(0.5, 0.94, 0.021 * self.scale, self.flashText)
            if _G.RenderText ~= nil and RenderText.ALIGN_LEFT ~= nil then
                safeSetTextAlign(RenderText.ALIGN_LEFT)
            end
        end
    end

    -- Follow base HUD visibility when requested
    if self.bindHud and (not _isBaseHudShown()) then
        return
    end

    if not self.visible then return end

    local header, rows = collectRows()
    local numRows = math.min(#rows, self.maxRows)

    local fs   = self.fontSize * self.scale
    local line = fs + self.rowGap * self.scale
    local pad  = self.pad * self.scale

    local width  = (self.width or 0.36) * self.scale
    local height = (pad * 2) + (line * (numRows + 1)) -- header + rows

    local px, py = place(width, height)

    if self.bgEnabled then
        safeRect(px, py, width, height, 0, 0, 0, self.opacity)
        if self.outline then
            drawOutline(px, py, width, height, math.min(1, self.opacity + 0.15))
        end
    end

    local x = px + pad
    local y = py + height - pad - fs

    safeSetTextColor(1, 1, 1, 1)
    shadowedText(x, y, fs, header)
    y = y - line

    for i = 1, numRows do
        local r = rows[i]
        if r.isSelected then
            safeSetTextColor(1.00, 0.95, 0.65, 1)  -- selected: warmer
        elseif r.inUse then
            safeSetTextColor(0.95, 0.85, 0.35, 1)  -- in use
        else
            safeSetTextColor(0.85, 0.95, 0.85, 1)  -- free
        end
        shadowedText(x, y, fs, r.text)
        y = y - line
    end

    safeSetTextColor(1, 1, 1, 1)
end

-- ===== Engine hooks ===========================================================

function HP_UI:loadMap()
    -- Load external config if available
    if HP_Config and HP_Config.read and HP_Config.applyToUI and HP_Config.init then
        HP_Config:init()
        local cfg, err = HP_Config:read()
        if cfg then
            HP_Config:applyToUI(cfg)
            self:flash("HP overlay: config loaded", 2.0)
        else
            -- first run: write defaults so users have a file to tweak
            if HP_Config.write then
                local ok = HP_Config:write()
                if ok then self:flash("HP overlay: default config saved", 2.0) end
            end
        end
    else
        -- Keep previous behavior if config system isn't present
        self:flash("HelperProfiles overlay: hpOverlay help", 4.0)
    end
end

function HP_UI:update(dt) end
function HP_UI:draw() self:render(16) end

addModEventListener(HP_UI)
