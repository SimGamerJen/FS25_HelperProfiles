-- HP_UI.lua (FS25_HelperProfiles) — autosizing tabular helper overlay
-- Loads optional UI configuration from modSettings/FS25_HelperProfiles/config.xml.

-- ============================================================================
-- FS25_HelperProfiles
-- ModVersion: 2.0.26
-- Script:     HP_UI.lua
-- BuildTag:   20260721-1
-- ============================================================================

do
    local MOD_VERSION = "2.0.26"
    local SCRIPT_NAME = "HP_UI.lua"
    local BUILD_TAG = "20260721-1"
    local SCRIPT_VER = string.format("%s-%s+%s", MOD_VERSION, SCRIPT_NAME, BUILD_TAG)

    local vi = rawget(_G, "FS25_HelperProfiles_VersionInfo")
    if vi == nil then
        vi = {modVersion = MOD_VERSION, scripts = {}}
        _G.FS25_HelperProfiles_VersionInfo = vi
    end

    vi.modVersion = vi.modVersion or MOD_VERSION
    vi.scripts = vi.scripts or {}
    vi.scripts[SCRIPT_NAME] = SCRIPT_VER
end

---@class HP_UI
HP_UI = {
    bindHud = true,       -- hide with the base HUD
    visible = true,
    anchor = "TR",       -- TL | TR | BL | BR
    x = 0.985,
    y = 0.900,
    scale = 1.0,
    opacity = 0.4,
    pad = 0.006,
    rowGap = 0.006,
    columnGap = 0.010,
    sectionGap = 0.004,
    fontSize = 0.014,     -- retained from the previous overlay
    maxRows = 10,
    width = 0.24,         -- minimum width while autosizing; fixed width otherwise
    maxWidth = 0.94,
    autoSize = true,
    bgEnabled = true,
    outline = false,
    shadow = false,
    showMarkers = true,
    flashText = nil,
    flashTime = 0
}

-- ===== Safe engine wrappers ==================================================

local function safeSetTextAlign(alignment)
    if _G.setTextAlignment ~= nil then
        setTextAlignment(alignment)
    end
end

local function safeRenderText(x, y, size, text)
    if _G.renderText ~= nil then
        renderText(x, y, size, text)
    end
end

local function safeGetTextWidth(size, text)
    text = tostring(text or "")
    if _G.getTextWidth ~= nil then
        local ok, width = pcall(getTextWidth, size, text)
        if ok and type(width) == "number" then
            return width
        end
    end

    -- Conservative fallback for environments where the renderer is unavailable.
    return #text * size * 0.52
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

local function safeRect(x, y, width, height, r, g, b, a)
    if _G.drawFilledRect ~= nil then
        drawFilledRect(x, y, width, height, r, g, b, a)
    end
end

local function drawOutline(x, y, width, height, alpha)
    local thickness = 0.0018
    safeRect(x, y, width, thickness, 1, 1, 1, alpha)
    safeRect(x, y + height - thickness, width, thickness, 1, 1, 1, alpha)
    safeRect(x, y, thickness, height, 1, 1, 1, alpha)
    safeRect(x + width - thickness, y, thickness, height, 1, 1, 1, alpha)
end

local function shadowedText(x, y, size, text)
    if not HP_UI.shadow then
        safeRenderText(x, y, size, text)
        return
    end

    local offsetX, offsetY = 0.0012, -0.0012
    local r, g, b, a = safeGetTextColor()
    safeSetTextColor(0, 0, 0, math.min(1, a * 0.75))
    safeRenderText(x + offsetX, y + offsetY, size, text)
    safeSetTextColor(r, g, b, a)
    safeRenderText(x, y, size, text)
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function setLeftAlignment()
    if _G.RenderText ~= nil and RenderText.ALIGN_LEFT ~= nil then
        safeSetTextAlign(RenderText.ALIGN_LEFT)
    end
end

local function setCenterAlignment()
    if _G.RenderText ~= nil and RenderText.ALIGN_CENTER ~= nil then
        safeSetTextAlign(RenderText.ALIGN_CENTER)
    end
end

-- ===== Public configuration setters =========================================

function HP_UI:setVisible(value) self.visible = value and true or false end
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

function HP_UI:setScale(scale) self.scale = clamp(tonumber(scale) or self.scale, 0.5, 2.0) end
function HP_UI:setOpacity(alpha) self.opacity = clamp(tonumber(alpha) or self.opacity, 0.0, 1.0) end
function HP_UI:setFontSize(size) self.fontSize = clamp(tonumber(size) or self.fontSize, 0.010, 0.030) end
function HP_UI:setRowGap(gap) self.rowGap = clamp(tonumber(gap) or self.rowGap, 0.001, 0.030) end
function HP_UI:setColumnGap(gap) self.columnGap = clamp(tonumber(gap) or self.columnGap, 0.002, 0.040) end

function HP_UI:setMaxRows(count)
    local value = math.floor(tonumber(count) or self.maxRows)
    self.maxRows = clamp(value, 3, 30)
end

function HP_UI:setWidth(width)
    width = tonumber(width)
    if width == nil then return end
    self.width = clamp(width, 0.15, 0.90)
end

function HP_UI:setAutoSize(enabled) self.autoSize = enabled and true or false end
function HP_UI:setBackground(enabled) self.bgEnabled = enabled and true or false end
function HP_UI:setPadding(padding) self.pad = clamp(tonumber(padding) or self.pad, 0.0, 0.05) end
function HP_UI:setOutline(enabled) self.outline = enabled and true or false end
function HP_UI:flash(text, seconds) self.flashText = text or ""; self.flashTime = tonumber(seconds) or 2.0 end

-- ===== Data collection =======================================================

local function hpI18n(key, fallback)
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, value = pcall(g_i18n.getText, g_i18n, key)
        if ok and value ~= nil and value ~= "" and value ~= key then
            return tostring(value)
        end
    end
    return fallback or key
end

local function isGuiHiddenProfile(name)
    if name == nil then return false end
    return string.find(string.upper(tostring(name)), "SPARE", 1, true) ~= nil
end

local function getDisplayName(helper, index)
    if HelperProfiles ~= nil and HelperProfiles.getDisplayNameForHelper ~= nil then
        local ok, displayName = pcall(HelperProfiles.getDisplayNameForHelper, HelperProfiles, helper, index)
        if ok and displayName ~= nil and tostring(displayName) ~= "" then
            return tostring(displayName)
        end
    end
    return tostring((helper ~= nil and helper.name) or ("Helper " .. tostring(index or "?")))
end

local function getAppearanceLabel(helper, index)
    if HelperProfiles ~= nil and HelperProfiles.getAppearanceLabelForHelper ~= nil then
        local ok, label = pcall(HelperProfiles.getAppearanceLabelForHelper, HelperProfiles, helper, index)
        if ok and label ~= nil and tostring(label) ~= "" then
            local text = tostring(label)
            if text == "no AS preset" or text == "AS presets unavailable" then
                return "-"
            end
            return text
        end
    end
    return "-"
end

local function getModeLabel(mode)
    if mode == "firstFree" then
        return hpI18n("hp_overlay_mode_first_free", "First available")
    end
    if mode == "preferSelected" then
        return hpI18n("hp_overlay_mode_prefer_selected", "Prefer selected")
    end
    return tostring(mode or "-")
end

local function collectRows()
    local summary = {
        mode = "-",
        availableCount = 0,
        activeCount = 0,
        selectedName = "-",
        nextName = "-"
    }

    if HelperProfiles == nil or HelperProfiles.getProfiles == nil then
        return summary, {}
    end

    local profiles = HelperProfiles:getProfiles() or {}

    local selectedIdx = HelperProfiles.getSelectionIndex ~= nil
        and HelperProfiles:getSelectionIndex() or HelperProfiles.selectedIdx
    if type(selectedIdx) ~= "number" then selectedIdx = 1 end
    if selectedIdx < 1 or selectedIdx > #profiles then selectedIdx = 1 end

    local nextHelper = nil
    if HelperProfiles.pickPreferredFreeHelper ~= nil then
        nextHelper = HelperProfiles:pickPreferredFreeHelper()
    end

    local selectedRef = HelperProfiles.selectedHelperRef
    summary.selectedName = selectedRef ~= nil and getDisplayName(selectedRef, selectedIdx) or "-"

    local nextIdx = nil
    if nextHelper ~= nil then
        for index, candidate in ipairs(profiles) do
            if candidate == nextHelper then
                nextIdx = index
                break
            end
        end
        summary.nextName = getDisplayName(nextHelper, nextIdx or "?")
    end

    if HelperProfiles.getPickMode ~= nil then
        local ok, mode = pcall(HelperProfiles.getPickMode, HelperProfiles)
        if ok then summary.mode = getModeLabel(mode) end
    elseif HelperProfiles._pickMode ~= nil then
        summary.mode = getModeLabel(HelperProfiles._pickMode)
    end

    local rows = {}
    for index, helper in ipairs(profiles) do
        local helperName = tostring(helper.name or ("Helper " .. tostring(index)))
        if not isGuiHiddenProfile(helperName) then
            local isActive = HelperProfiles.isHelperActive ~= nil
                and HelperProfiles:isHelperActive(helper) or helper.inUse == true

            if isActive then
                summary.activeCount = summary.activeCount + 1
            else
                summary.availableCount = summary.availableCount + 1
            end

            local slotLabel = helperName
            if not slotLabel:match("^[A-J]$") then
                slotLabel = string.format("%02d", index)
            end

            table.insert(rows, {
                slot = slotLabel,
                worker = getDisplayName(helper, index),
                status = isActive
                    and hpI18n("hp_state_active", "ACTIVE")
                    or hpI18n("hp_state_available", "AVAILABLE"),
                appearance = getAppearanceLabel(helper, index),
                selected = (HP_UI.showMarkers and index == selectedIdx and not isActive) and "»" or "",
                next = (HP_UI.showMarkers and nextHelper == helper and not isActive) and "←" or "",
                inUse = isActive,
                isSelected = index == selectedIdx and not isActive,
                isNext = nextHelper == helper and not isActive
            })
        end
    end

    return summary, rows
end

-- ===== Layout ================================================================

local function getColumnKeys(rows, rowCount)
    local keys = {"slot", "worker", "status"}
    local showAppearance = false
    for index = 1, rowCount do
        if rows[index].appearance ~= nil and rows[index].appearance ~= "" and rows[index].appearance ~= "-" then
            showAppearance = true
            break
        end
    end
    if showAppearance then table.insert(keys, "appearance") end
    if HP_UI.showMarkers then
        table.insert(keys, "selected")
        table.insert(keys, "next")
    end
    return keys
end

local function getColumnHeaders()
    return {
        slot = hpI18n("hp_overlay_header_slot", "SLOT"),
        worker = hpI18n("hp_overlay_header_worker", "WORKER"),
        status = hpI18n("hp_overlay_header_status", "STATUS"),
        appearance = hpI18n("hp_overlay_header_appearance", "APPEARANCE"),
        selected = hpI18n("hp_overlay_header_selected", "SEL"),
        next = hpI18n("hp_overlay_header_next", "NEXT")
    }
end

local function buildSummaryLine(summary)
    return string.format(
        "%s: %s   |   %s: %d   |   %s: %d",
        hpI18n("hp_overlay_label_mode", "Mode"), summary.mode,
        hpI18n("hp_overlay_label_available", "Available"), summary.availableCount,
        hpI18n("hp_overlay_label_active", "Active"), summary.activeCount
    )
end

local function measureColumns(columnKeys, headers, rows, rowCount, fontSize, gap)
    local widths = {}
    local totalWidth = 0

    for _, key in ipairs(columnKeys) do
        widths[key] = safeGetTextWidth(fontSize, headers[key])
    end

    if widths.status ~= nil then
        widths.status = math.max(
            widths.status,
            safeGetTextWidth(fontSize, hpI18n("hp_state_active", "ACTIVE")),
            safeGetTextWidth(fontSize, hpI18n("hp_state_available", "AVAILABLE"))
        )
    end

    for index = 1, rowCount do
        local row = rows[index]
        for _, key in ipairs(columnKeys) do
            widths[key] = math.max(widths[key], safeGetTextWidth(fontSize, row[key] or ""))
        end
    end

    for index, key in ipairs(columnKeys) do
        totalWidth = totalWidth + widths[key]
        if index < #columnKeys then totalWidth = totalWidth + gap end
    end

    return widths, totalWidth
end

local function place(width, height)
    local x, y
    if HP_UI.anchor == "TR" then
        x, y = HP_UI.x - width, HP_UI.y - height
    elseif HP_UI.anchor == "TL" then
        x, y = HP_UI.x, HP_UI.y - height
    elseif HP_UI.anchor == "BR" then
        x, y = HP_UI.x - width, HP_UI.y
    else
        x, y = HP_UI.x, HP_UI.y
    end

    -- Keep the complete panel inside the screen even with long localised text.
    x = clamp(x, 0.005, math.max(0.005, 0.995 - width))
    y = clamp(y, 0.005, math.max(0.005, 0.995 - height))
    return x, y
end

local function buildColumnPositions(columnKeys, startX, widths, gap)
    local positions = {}
    local x = startX
    for index, key in ipairs(columnKeys) do
        positions[key] = x
        x = x + widths[key]
        if index < #columnKeys then x = x + gap end
    end
    return positions
end

-- ===== Input and HUD state ===================================================

function HP_UI:onToggleAction(actionName, inputValue, callbackState, isAnalog)
    local value = 0
    if type(inputValue) == "number" then
        value = inputValue
    elseif type(inputValue) == "boolean" then
        value = inputValue and 1 or 0
    else
        value = tonumber(callbackState) or 0
    end

    if value <= 0 then return end
    self:toggle()
    if self.visible then
        self:flash(hpI18n("hp_flash_overlay_on", "HelperProfiles overlay: ON"), 1.25)
    else
        print("[FS25_HelperProfiles] Overlay: OFF")
    end
end

local function isBaseHudShown()
    if g_currentMission ~= nil then
        local hud = g_currentMission.hud
        if hud ~= nil then
            if hud.getIsVisible ~= nil then
                local ok, result = pcall(hud.getIsVisible, hud)
                if ok then return result end
            end
            if hud.getVisible ~= nil then
                local ok, result = pcall(hud.getVisible, hud)
                if ok then return result end
            end
            if hud.isVisible ~= nil then
                return hud.isVisible and true or false
            end
        end
    end

    if g_gameSettings ~= nil and g_gameSettings.getValue ~= nil then
        local ok, result = pcall(g_gameSettings.getValue, g_gameSettings, "showHud")
        if ok and result ~= nil then return result == true end
    end

    return true
end

-- ===== Render ================================================================

function HP_UI:render(dtMillis)
    if self.flashTime ~= nil and self.flashTime > 0 then
        local dt = tonumber(dtMillis) or 16
        self.flashTime = math.max(0, self.flashTime - dt * 0.001)
        if self.flashTime > 0 and self.flashText ~= nil and self.flashText ~= "" then
            setCenterAlignment()
            safeSetTextColor(1, 1, 1, 1)
            shadowedText(0.5, 0.94, 0.021 * self.scale, self.flashText)
            setLeftAlignment()
        end
    end

    if self.bindHud and not isBaseHudShown() then return end
    if not self.visible then return end

    local summary, rows = collectRows()
    local rowCount = math.min(#rows, self.maxRows)
    local headers = getColumnHeaders()
    local columnKeys = getColumnKeys(rows, rowCount)
    local summaryLine = buildSummaryLine(summary)

    local fontSize = self.fontSize * self.scale
    local lineHeight = fontSize + self.rowGap * self.scale
    local padding = self.pad * self.scale
    local columnGap = self.columnGap * self.scale
    local sectionGap = self.sectionGap * self.scale

    local columnWidths, tableWidth = measureColumns(columnKeys, headers, rows, rowCount, fontSize, columnGap)
    local summaryWidth = safeGetTextWidth(fontSize, summaryLine)
    local contentWidth = math.max(tableWidth, summaryWidth)

    local minimumWidth = (self.width or 0.24) * self.scale
    local measuredWidth = contentWidth + padding * 2
    local panelWidth = self.autoSize and math.max(minimumWidth, measuredWidth) or minimumWidth
    panelWidth = math.min(panelWidth, (self.maxWidth or 0.94))

    local panelHeight = padding * 2 + fontSize + lineHeight * (rowCount + 1) + sectionGap
    local panelX, panelY = place(panelWidth, panelHeight)

    if self.bgEnabled then
        safeRect(panelX, panelY, panelWidth, panelHeight, 0, 0, 0, self.opacity)
        if self.outline then
            drawOutline(panelX, panelY, panelWidth, panelHeight, math.min(1, self.opacity + 0.15))
        end
    end

    local contentX = panelX + padding
    local y = panelY + panelHeight - padding - fontSize

    setLeftAlignment()
    safeSetTextColor(1, 1, 1, 1)
    shadowedText(contentX, y, fontSize, summaryLine)
    y = y - lineHeight - sectionGap

    local positions = buildColumnPositions(columnKeys, contentX, columnWidths, columnGap)

    safeSetTextColor(0.78, 0.86, 0.72, 1)
    for _, key in ipairs(columnKeys) do
        if key == "selected" or key == "next" then
            setCenterAlignment()
            shadowedText(positions[key] + columnWidths[key] * 0.5, y, fontSize, headers[key])
        else
            setLeftAlignment()
            shadowedText(positions[key], y, fontSize, headers[key])
        end
    end
    setLeftAlignment()

    local separatorY = y - self.rowGap * self.scale * 0.40
    safeRect(contentX, separatorY, math.min(contentWidth, panelWidth - padding * 2), 0.0012, 1, 1, 1, 0.24)
    y = y - lineHeight

    for index = 1, rowCount do
        local row = rows[index]

        if row.isSelected then
            safeRect(
                contentX - padding * 0.35,
                y - self.rowGap * self.scale * 0.35,
                panelWidth - padding * 1.3,
                lineHeight * 0.92,
                0.45, 0.62, 0.12, 0.16
            )
        end

        if row.inUse then
            safeSetTextColor(0.55, 0.55, 0.55, 1)
        elseif row.isSelected then
            safeSetTextColor(1.00, 0.95, 0.65, 1)
        else
            safeSetTextColor(0.85, 0.95, 0.85, 1)
        end

        for _, key in ipairs(columnKeys) do
            if key == "selected" or key == "next" then
                setCenterAlignment()
                shadowedText(positions[key] + columnWidths[key] * 0.5, y, fontSize, row[key])
            else
                setLeftAlignment()
                shadowedText(positions[key], y, fontSize, row[key])
            end
        end

        y = y - lineHeight
    end

    setLeftAlignment()
    safeSetTextColor(1, 1, 1, 1)
end

-- ===== Engine hooks ==========================================================

function HP_UI:loadMap()
    if HP_Config ~= nil and HP_Config.read ~= nil and HP_Config.applyToUI ~= nil and HP_Config.init ~= nil then
        HP_Config:init()
        local config = HP_Config:read()
        if config ~= nil then
            HP_Config:applyToUI(config)
            self:flash(hpI18n("hp_flash_config_loaded", "HP overlay: config loaded"), 2.0)
        elseif HP_Config.write ~= nil then
            local ok = HP_Config:write()
            if ok then
                self:flash(hpI18n("hp_flash_config_saved", "HP overlay: default config saved"), 2.0)
            end
        end
    else
        self:flash("HelperProfiles overlay: hpOverlay help", 4.0)
    end
end

function HP_UI:update(dt) end
function HP_UI:draw() self:render(16) end

addModEventListener(HP_UI)
