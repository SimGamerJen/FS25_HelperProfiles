-- HP_AppearanceMenu.lua (FS25_HelperProfiles)
-- ModVersion: 2.0.25
-- BuildTag: 20260513.3
-- Mouse-driven per-save helper appearance binding interface.
-- Uses HP_ASBridge direct AvatarSwitcher preset data and stores preset IDs behind the scenes.
-- v2.0.9: shows derived helper display names in the slot list and saves them with bindings.
-- v2.0.16: unbound draft rows use the real helper slot name, not stale derived names.
-- v2.0.10: dropdowns are opaque modal layers and own mouse hit-testing while open.

HP_AppearanceMenu = HP_AppearanceMenu or {
    visible = false,
    initialized = false,
    selectedHelperIndex = 1,
    selectedCategory = nil,
    selectedPresetId = nil,
    dropdown = nil, -- nil | category | preset
    rects = {},
    draftLinks = {},
    dirty = false,
    message = nil,
    messageTime = 0,
    width = 0.76,
    height = 0.68,
}

local LOG = "[FS25_HelperProfiles/AppearanceMenu] "
local function hpPrint(msg) print(LOG .. tostring(msg)) end

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function normalizeName(value)
    local s = tostring(value or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end

local function isHiddenHelperName(name)
    return name ~= nil and string.find(string.upper(tostring(name)), "SPARE", 1, true) ~= nil
end

local function drawRect(x, y, w, h, r, g, b, a)
    if drawFilledRect ~= nil then drawFilledRect(x, y, w, h, r, g, b, a) end
end

local function setTextColorSafe(r, g, b, a)
    if setTextColor ~= nil then setTextColor(r, g, b, a) end
end

local function setTextAlignSafe(align)
    if setTextAlignment ~= nil then setTextAlignment(align) end
end

local function drawText(x, y, size, text, r, g, b, a)
    setTextColorSafe(r or 1, g or 1, b or 1, a or 1)
    setTextAlignSafe(RenderText ~= nil and RenderText.ALIGN_LEFT or 0)
    if renderText ~= nil then renderText(x, y, size, tostring(text or "")) end
end

local function pointInRect(px, py, r)
    return r ~= nil and px >= r.x and px <= r.x + r.w and py >= r.y and py <= r.y + r.h
end

local function ellipsize(text, maxLen)
    text = tostring(text or "")
    maxLen = tonumber(maxLen) or 40
    if string.len(text) <= maxLen then return text end
    return string.sub(text, 1, math.max(1, maxLen - 1)) .. "…"
end

local function getHelpers()
    local rows = {}
    local list = HelperProfiles ~= nil and HelperProfiles.getProfiles ~= nil and HelperProfiles:getProfiles() or {}
    for idx, helper in ipairs(list) do
        local name = tostring(helper.name or ("Helper " .. tostring(idx)))
        if not isHiddenHelperName(name) then
            table.insert(rows, { index = idx, helper = helper, name = name })
        end
    end
    return rows
end

local function getPresetDisplayName(preset)
    if preset == nil then return "-" end
    local desc = preset.description or preset.desc
    if desc ~= nil and tostring(desc) ~= "" then return tostring(desc) end
    if preset.name ~= nil and tostring(preset.name) ~= "" then return tostring(preset.name) end
    return tostring(preset.id or "?")
end

local function getDerivedDisplayNameForPreset(preset, fallback)
    if HP_ASBridge ~= nil and HP_ASBridge.deriveDisplayNameFromPreset ~= nil then
        local ok, value = pcall(HP_ASBridge.deriveDisplayNameFromPreset, HP_ASBridge, preset, fallback)
        if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    return tostring(fallback or "")
end

local function getHelperDisplayName(helper, idx)
    local fallback = tostring((helper ~= nil and helper.name) or ("Helper " .. tostring(idx or "?")))
    if HelperProfiles ~= nil and HelperProfiles.getDisplayNameForHelper ~= nil then
        local ok, displayName, baseName = pcall(HelperProfiles.getDisplayNameForHelper, HelperProfiles, helper, idx)
        if ok and displayName ~= nil and tostring(displayName) ~= "" then
            return tostring(displayName), tostring(baseName or fallback)
        end
    end
    return fallback, fallback
end

local function getCategoryForPreset(presetId)
    if HP_ASBridge == nil or HP_ASBridge.getPresetById == nil then return nil end
    local preset = HP_ASBridge:getPresetById(presetId)
    if type(preset) == "table" then return preset.category end
    return nil
end

function HP_AppearanceMenu:setMouseCursor(visible)
    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        pcall(g_inputBinding.setShowMouseCursor, g_inputBinding, visible == true, visible == true)
    end
end

function HP_AppearanceMenu:flash(msg, secs)
    self.message = tostring(msg or "")
    self.messageTime = tonumber(secs) or 2.0
end

function HP_AppearanceMenu:init()
    if self.initialized then return end
    self.initialized = true
    if HP_ASBridge ~= nil and HP_ASBridge.init ~= nil then HP_ASBridge:init() end
end

function HP_AppearanceMenu:buildDraftFromBridge()
    self.draftLinks = {}
    if HP_ASBridge ~= nil and HP_ASBridge.getLinksSnapshot ~= nil then
        local snap = HP_ASBridge:getLinksSnapshot()
        for k, link in pairs(snap or {}) do
            self.draftLinks[k] = {
                name = link.name,
                displayName = link.displayName,
                presetId = link.presetId or link.selectedPresetId,
                selectedPresetId = link.selectedPresetId or link.presetId,
                category = link.category,
                characterId = link.characterId,
            }
        end
    else
        -- Fallback: build links for visible helpers from current bridge lookup.
        for _, row in ipairs(getHelpers()) do
            if HP_ASBridge ~= nil and HP_ASBridge.getLinkForHelper ~= nil then
                local link = HP_ASBridge:getLinkForHelper(row.helper, row.index)
                if link ~= nil and link.presetId ~= nil and tostring(link.presetId) ~= "" then
                    self.draftLinks[normalizeName(row.name)] = {
                        name = row.name,
                        displayName = link.displayName,
                        presetId = link.presetId,
                        selectedPresetId = link.selectedPresetId or link.presetId,
                        category = link.category,
                        characterId = link.characterId,
                    }
                end
            end
        end
    end
    self.dirty = false
end

function HP_AppearanceMenu:getDraftLinkForHelperName(helperName)
    return self.draftLinks[normalizeName(helperName)]
end

function HP_AppearanceMenu:setDraftLinkForHelperName(helperName, preset)
    if helperName == nil or helperName == "" then return end
    if preset == nil then
        self.draftLinks[normalizeName(helperName)] = nil
    else
        self.draftLinks[normalizeName(helperName)] = {
            name = helperName,
            displayName = getDerivedDisplayNameForPreset(preset, helperName),
            presetId = tostring(preset.id or ""),
            selectedPresetId = tostring(preset.id or ""),
            category = preset.category,
            characterId = preset.characterId,
        }
    end
    self.dirty = true
end

function HP_AppearanceMenu:getSelectedHelperRow()
    local helpers = getHelpers()
    if #helpers == 0 then return nil end
    self.selectedHelperIndex = clamp(self.selectedHelperIndex or 1, 1, #helpers)
    return helpers[self.selectedHelperIndex], helpers
end

function HP_AppearanceMenu:syncSelectionFromDraft()
    local row = self:getSelectedHelperRow()
    if row == nil then
        self.selectedCategory = nil
        self.selectedPresetId = nil
        return
    end
    local link = self:getDraftLinkForHelperName(row.name)
    if link ~= nil and link.presetId ~= nil and tostring(link.presetId) ~= "" then
        self.selectedPresetId = tostring(link.presetId)
        self.selectedCategory = link.category or getCategoryForPreset(self.selectedPresetId)
    else
        self.selectedPresetId = nil
        if self.selectedCategory == nil and HP_ASBridge ~= nil and HP_ASBridge.getCategories ~= nil then
            local cats = HP_ASBridge:getCategories()
            self.selectedCategory = cats[1]
        end
    end
end

function HP_AppearanceMenu:open()
    self:init()
    if HP_ASBridge ~= nil and HP_ASBridge.reload ~= nil then HP_ASBridge:reload() end
    self:buildDraftFromBridge()
    self:syncSelectionFromDraft()
    self.visible = true
    self.dropdown = nil
    self:setMouseCursor(true)
    self:flash("Helper appearance bindings", 1.5)
    hpPrint("Opened")
end

function HP_AppearanceMenu:close(discard)
    self.visible = false
    self.dropdown = nil
    self:setMouseCursor(false)
    if discard == true then
        self:buildDraftFromBridge()
    end
end

function HP_AppearanceMenu:toggle()
    if self.visible then self:close(false) else self:open() end
end

function HP_AppearanceMenu:save()
    if HP_ASBridge == nil or HP_ASBridge.replaceLinksSnapshot == nil then
        self:flash("Save failed: AS bridge cannot replace links", 2.5)
        hpPrint("Save failed: replaceLinksSnapshot unavailable")
        return false
    end
    local ok, err = HP_ASBridge:replaceLinksSnapshot(self.draftLinks or {})
    if ok then
        self.dirty = false
        self:flash("Bindings saved", 2.0)
        hpPrint("Saved appearance bindings")
        if HP_ASBridge ~= nil and HP_ASBridge.reload ~= nil then
            HP_ASBridge:reload()
        end
        if HP_WorkerAppearance ~= nil and HP_WorkerAppearance.refreshActiveWorkers ~= nil then
            HP_WorkerAppearance:refreshActiveWorkers()
        end
        self:buildDraftFromBridge()
        self:syncSelectionFromDraft()
        return true
    end
    self:flash("Save failed: " .. tostring(err), 3.0)
    hpPrint("Save failed: " .. tostring(err))
    return false
end

function HP_AppearanceMenu:clearSelectedBinding()
    local row = self:getSelectedHelperRow()
    if row == nil then return end
    self:setDraftLinkForHelperName(row.name, nil)
    self.selectedPresetId = nil
    self:flash("Cleared binding for " .. tostring(row.name), 1.8)
end

function HP_AppearanceMenu:clearAllBindings()
    self.draftLinks = {}
    self.selectedPresetId = nil
    self.dirty = true
    self:flash("Cleared all bindings in this save", 2.0)
end

function HP_AppearanceMenu:selectHelperByVisibleIndex(visibleIndex)
    local helpers = getHelpers()
    if helpers[visibleIndex] == nil then return end
    self.selectedHelperIndex = visibleIndex
    self.dropdown = nil
    self:syncSelectionFromDraft()
end

function HP_AppearanceMenu:selectCategory(category)
    self.selectedCategory = category
    self.selectedPresetId = nil
    self.dropdown = nil
end

function HP_AppearanceMenu:selectPreset(presetId)
    if HP_ASBridge == nil or HP_ASBridge.getPresetById == nil then return end
    local preset = HP_ASBridge:getPresetById(presetId)
    if preset == nil then
        self:flash("Preset not found: " .. tostring(presetId), 2.5)
        return
    end
    local row = self:getSelectedHelperRow()
    if row == nil then return end
    self.selectedPresetId = tostring(preset.id)
    self.selectedCategory = preset.category or self.selectedCategory
    self:setDraftLinkForHelperName(row.name, preset)
    self.dropdown = nil
    self:flash("Selected " .. getPresetDisplayName(preset), 1.6)
end

function HP_AppearanceMenu:addRect(id, x, y, w, h, data)
    self.rects = self.rects or {}
    table.insert(self.rects, { id = id, x = x, y = y, w = w, h = h, data = data })
end

function HP_AppearanceMenu:drawButton(id, label, x, y, w, h, enabled)
    enabled = enabled ~= false
    local bg = enabled and 0.18 or 0.08
    drawRect(x, y, w, h, bg, bg, bg, 0.92)
    drawRect(x, y, w, 0.002, 0.65, 0.65, 0.65, enabled and 0.55 or 0.25)
    drawText(x + 0.008, y + h * 0.33, 0.0135, label, enabled and 1 or 0.55, enabled and 1 or 0.55, enabled and 1 or 0.55, 1)
    if enabled then self:addRect(id, x, y, w, h) end
end

function HP_AppearanceMenu:drawDropdownButton(id, label, value, x, y, w, h)
    drawRect(x, y, w, h, 0.10, 0.10, 0.10, 0.96)
    drawRect(x, y, w, 0.002, 0.75, 0.75, 0.75, 0.38)
    drawText(x + 0.006, y + h + 0.003, 0.0115, label, 0.72, 0.82, 0.95, 1)
    drawText(x + 0.008, y + h * 0.30, 0.014, ellipsize(value or "-", 52), 1, 1, 1, 1)
    drawText(x + w - 0.022, y + h * 0.30, 0.014, "▼", 0.9, 0.9, 0.9, 1)
    self:addRect(id, x, y, w, h)
end

function HP_AppearanceMenu:drawDropdownList(kind, options, x, yTop, w, rowH)
    local maxRows = math.min(#options, 9)
    local h = rowH * maxRows
    local y = yTop - h

    -- Draw as a deliberately opaque, modal popover.  Earlier alpha builds used
    -- a translucent panel and ordinary rect ordering, which made the list hard
    -- to read and allowed clicks to leak through to controls underneath.
    drawRect(x - 0.004, y - 0.004, w + 0.008, h + 0.008, 0, 0, 0, 0.88)
    drawRect(x, y, w, h, 0.025, 0.025, 0.028, 1.0)
    drawRect(x, y + h - 0.002, w, 0.002, 0.72, 0.82, 0.95, 0.82)
    drawRect(x, y, w, 0.002, 0.72, 0.82, 0.95, 0.36)
    drawRect(x, y, 0.002, h, 0.72, 0.82, 0.95, 0.36)
    drawRect(x + w - 0.002, y, 0.002, h, 0.72, 0.82, 0.95, 0.36)

    -- Add a panel rect so empty space inside the dropdown still swallows the
    -- click instead of activating widgets behind it.
    self:addRect("dropdownPanel", x, y, w, h, { kind = kind })

    for i = 1, maxRows do
        local opt = options[i]
        local rowY = yTop - rowH * i
        local selected = false
        if kind == "category" then selected = tostring(opt.value) == tostring(self.selectedCategory) end
        if kind == "preset" then selected = tostring(opt.value) == tostring(self.selectedPresetId) end
        drawRect(x, rowY, w, rowH, selected and 0.22 or 0.06, selected and 0.27 or 0.06, selected and 0.34 or 0.065, 1.0)
        drawText(x + 0.006, rowY + rowH * 0.30, 0.0125, ellipsize(opt.label, 64), 1, 1, 1, 1)
        self:addRect("dropdownOption", x, rowY, w, rowH, { kind = kind, value = opt.value })
    end
end

function HP_AppearanceMenu:draw()
    if self.visible ~= true then return end
    self:init()
    self.rects = {}

    local panelW, panelH = self.width, self.height
    local x = (1 - panelW) / 2
    local y = (1 - panelH) / 2
    local pad = 0.016
    local titleH = 0.044
    local fs = 0.014

    drawRect(0, 0, 1, 1, 0, 0, 0, 0.36)
    drawRect(x, y, panelW, panelH, 0.025, 0.025, 0.028, 0.97)
    drawRect(x, y + panelH - titleH, panelW, titleH, 0.08, 0.10, 0.13, 0.98)
    drawText(x + pad, y + panelH - titleH + 0.014, 0.0175, "HelperProfiles — Appearance Bindings", 1, 1, 1, 1)

    local saveName = HP_ASBridge ~= nil and HP_ASBridge.getSavegameName ~= nil and HP_ASBridge:getSavegameName() or "?"
    drawText(x + panelW - 0.23, y + panelH - titleH + 0.016, 0.012, "Save: " .. tostring(saveName), 0.78, 0.86, 0.96, 1)

    local leftX = x + pad
    local leftY = y + panelH - titleH - pad
    local leftW = 0.24
    local rowH = 0.032
    drawText(leftX, leftY - 0.002, 0.0125, "Binding slot", 0.72, 0.82, 0.95, 1)

    local helpers = getHelpers()
    local listTop = leftY - 0.018
    local maxRows = math.min(#helpers, 12)
    for i = 1, maxRows do
        local row = helpers[i]
        local rowY = listTop - rowH * i
        local selected = i == self.selectedHelperIndex
        local link = row ~= nil and self:getDraftLinkForHelperName(row.name) or nil
        drawRect(leftX, rowY, leftW, rowH - 0.003, selected and 0.21 or 0.08, selected and 0.26 or 0.08, selected and 0.34 or 0.08, 0.96)
        local displayName = nil
        if link ~= nil and link.displayName ~= nil and tostring(link.displayName) ~= "" then
            displayName = tostring(link.displayName)
        elseif link ~= nil and link.presetId ~= nil and tostring(link.presetId) ~= "" then
            displayName = getHelperDisplayName(row.helper, row.index)
        else
            displayName = tostring(row.name or ("Helper " .. tostring(row.index or "?")))
        end
        local baseHint = (displayName ~= row.name and link ~= nil and link.presetId ~= nil) and (" (" .. tostring(row.name) .. ")") or ""
        local label = string.format("%02d  %s%s", row.index, displayName, baseHint)
        drawText(leftX + 0.006, rowY + 0.010, 0.0125, ellipsize(label, 31), 1, 1, 1, 1)
        local bindText = link ~= nil and link.presetId ~= nil and "bound" or "vanilla"
        drawText(leftX + leftW - 0.058, rowY + 0.010, 0.011, bindText, link and 0.65 or 0.78, link and 0.95 or 0.78, link and 0.70 or 0.78, 1)
        self:addRect("helper", leftX, rowY, leftW, rowH - 0.003, { visibleIndex = i })
    end

    local row, _ = self:getSelectedHelperRow()
    local rightX = leftX + leftW + 0.026
    local rightY = leftY - 0.018
    local rightW = panelW - leftW - pad * 2 - 0.026

    local selectedName = row ~= nil and getHelperDisplayName(row.helper, row.index) or "-"
    local selectedBase = row ~= nil and row.name or "-"
    local slotText = "Selected helper: " .. tostring(selectedName)
    if selectedBase ~= selectedName then slotText = slotText .. "  (slot " .. tostring(selectedBase) .. ")" end
    drawText(rightX, rightY + 0.005, 0.0145, slotText, 1, 1, 1, 1)

    local categories = HP_ASBridge ~= nil and HP_ASBridge.getCategories ~= nil and HP_ASBridge:getCategories() or {}
    if self.selectedCategory == nil and #categories > 0 then self.selectedCategory = categories[1] end

    local categoryY = rightY - 0.055
    self:drawDropdownButton("categoryDropdown", "Category", self.selectedCategory or "-", rightX, categoryY, rightW, 0.036)

    local presetOptions = {}
    local selectedPresetLabel = "-"
    if self.selectedCategory ~= nil and HP_ASBridge ~= nil and HP_ASBridge.getPresetsByCategoryForMenu ~= nil then
        local presets = HP_ASBridge:getPresetsByCategoryForMenu(self.selectedCategory)
        for _, preset in ipairs(presets or {}) do
            local label = getPresetDisplayName(preset) .. "  [" .. tostring(preset.id or "?") .. "]"
            table.insert(presetOptions, { value = preset.id, label = label, preset = preset })
            if tostring(preset.id) == tostring(self.selectedPresetId) then selectedPresetLabel = label end
        end
    end

    local presetY = categoryY - 0.072
    self:drawDropdownButton("presetDropdown", "Appearance", selectedPresetLabel, rightX, presetY, rightW, 0.036)

    local detailsY = presetY - 0.075
    local link = row ~= nil and self:getDraftLinkForHelperName(row.name) or nil
    local currentText = "Current binding: vanilla/basegame helper appearance"
    if link ~= nil and link.presetId ~= nil then
        local who = (link.displayName ~= nil and tostring(link.displayName) ~= "") and (" / helper: " .. tostring(link.displayName)) or ""
        currentText = "Current binding: " .. tostring(link.presetId) .. "  / category: " .. tostring(link.category or "?") .. who
    end
    drawRect(rightX, detailsY, rightW, 0.07, 0.06, 0.06, 0.065, 0.95)
    drawText(rightX + 0.008, detailsY + 0.045, 0.0125, currentText, 0.92, 0.92, 0.92, 1)
    drawText(rightX + 0.008, detailsY + 0.021, 0.0115, "Preset ID is stored behind the scenes. Category only filters the list.", 0.72, 0.78, 0.84, 1)

    local buttonY = y + pad
    local bw = 0.105
    self:drawButton("clearBinding", "Clear binding", rightX, buttonY, bw, 0.038, row ~= nil)
    self:drawButton("clearAll", "Clear all", rightX + bw + 0.010, buttonY, bw, 0.038, true)
    self:drawButton("save", "Save", x + panelW - pad - 0.245, buttonY, 0.075, 0.038, self.dirty == true)
    self:drawButton("ok", "OK", x + panelW - pad - 0.160, buttonY, 0.065, 0.038, true)
    self:drawButton("cancel", "Cancel", x + panelW - pad - 0.085, buttonY, 0.075, 0.038, true)

    local msg = self.message
    if msg ~= nil and msg ~= "" and (self.messageTime or 0) > 0 then
        drawText(rightX, buttonY + 0.055, 0.012, msg, 0.95, 0.88, 0.62, 1)
    elseif self.dirty == true then
        drawText(rightX, buttonY + 0.055, 0.012, "Unsaved changes", 0.95, 0.78, 0.45, 1)
    end

    -- Dropdowns are drawn last so they sit above the form.
    if self.dropdown == "category" then
        local opts = {}
        for _, cat in ipairs(categories) do table.insert(opts, { value = cat, label = cat }) end
        self:drawDropdownList("category", opts, rightX, categoryY, rightW, 0.030)
    elseif self.dropdown == "preset" then
        self:drawDropdownList("preset", presetOptions, rightX, presetY, rightW, 0.030)
    end

    setTextColorSafe(1, 1, 1, 1)
end

function HP_AppearanceMenu:update(dt)
    if self.messageTime ~= nil and self.messageTime > 0 then
        self.messageTime = math.max(0, self.messageTime - ((tonumber(dt) or 0) / 1000))
    end
end

function HP_AppearanceMenu:handleRectClick(r)
    if r == nil then return false end
    local id = r.id
    if id == "helper" then
        self:selectHelperByVisibleIndex(r.data.visibleIndex)
    elseif id == "categoryDropdown" then
        self.dropdown = self.dropdown == "category" and nil or "category"
    elseif id == "presetDropdown" then
        self.dropdown = self.dropdown == "preset" and nil or "preset"
    elseif id == "dropdownOption" then
        if r.data.kind == "category" then self:selectCategory(r.data.value)
        elseif r.data.kind == "preset" then self:selectPreset(r.data.value) end
    elseif id == "dropdownPanel" then
        -- Swallow blank-space clicks inside the open popover.
    elseif id == "clearBinding" then
        self:clearSelectedBinding()
    elseif id == "clearAll" then
        self:clearAllBindings()
    elseif id == "save" then
        self:save()
    elseif id == "ok" then
        if self.dirty then self:save() end
        self:close(false)
    elseif id == "cancel" then
        self:close(true)
    else
        return false
    end
    return true
end

function HP_AppearanceMenu:mouseEvent(posX, posY, isDown, isUp, button)
    if self.visible ~= true then return false end
    local leftButton = Input ~= nil and Input.MOUSE_BUTTON_LEFT or 1
    if button ~= nil and button ~= leftButton and button ~= 1 then return true end
    if isUp ~= true then return true end

    local x = tonumber(posX) or 0
    local y = tonumber(posY) or 0
    local rects = self.rects or {}

    -- If a dropdown is open, it behaves like a modal popover: only the list,
    -- the list's owning button, or blank dropdown space may consume the click.
    -- Any click elsewhere closes the dropdown and is swallowed, so it cannot
    -- accidentally activate a covered appearance/category control behind it.
    if self.dropdown ~= nil then
        for i = #rects, 1, -1 do
            local r = rects[i]
            if pointInRect(x, y, r) then
                if r.id == "dropdownOption" or r.id == "dropdownPanel" or r.id == "categoryDropdown" or r.id == "presetDropdown" then
                    self:handleRectClick(r)
                    return true
                end
            end
        end
        self.dropdown = nil
        return true
    end

    -- Normal state: reverse iteration matches draw order, so the last drawn
    -- controls are hit-tested first.
    for i = #rects, 1, -1 do
        local r = rects[i]
        if pointInRect(x, y, r) then
            self:handleRectClick(r)
            return true
        end
    end

    return true
end

addModEventListener(HP_AppearanceMenu)
