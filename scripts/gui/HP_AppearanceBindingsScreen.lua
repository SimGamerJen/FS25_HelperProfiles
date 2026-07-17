-- HP_AppearanceBindingsScreen.lua (FS25_HelperProfiles)
-- ModVersion: 2.0.25
-- BuildTag: 20260514.4
-- XML dialog for per-save AvatarSwitcher appearance bindings.
-- Reworked to follow the known-working AvatarSwitcher XML dialog pattern:
--   MessageDialog + <GUI> XML + SmoothList + g_gui:showDialog(...)

HP_AppearanceBindingsScreen = {}
local HP_AppearanceBindingsScreen_mt = Class(HP_AppearanceBindingsScreen, MessageDialog)

local LOG = "[FS25_HelperProfiles/AppearanceBindingsXML] "
local function hpPrint(msg) print(LOG .. tostring(msg)) end

local HP_GUI_MOD_DIR = g_currentModDirectory or ""

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if hi == nil or hi < lo then hi = lo end
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function normalizeName(value)
    local s = tostring(value or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end

local function hpI18n(key, fallback)
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, value = pcall(g_i18n.getText, g_i18n, key)
        if ok and value ~= nil and value ~= "" and value ~= key then
            return value
        end
    end
    return fallback or key
end

local function hpFormat(key, fallback, ...)
    local pattern = hpI18n(key, fallback)
    local ok, value = pcall(string.format, pattern, ...)
    if ok then return value end
    return pattern
end

local function isHiddenHelperName(name)
    return name ~= nil and string.find(string.upper(tostring(name)), "SPARE", 1, true) ~= nil
end

local function getPresetDisplayName(preset)
    if type(preset) ~= "table" then return "-" end
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

local function getPresetLabelById(presetId)
    if presetId == nil or tostring(presetId) == "" then return nil end

    if HP_ASBridge ~= nil and HP_ASBridge.getPresetById ~= nil then
        local preset = HP_ASBridge:getPresetById(presetId)
        if preset ~= nil then
            return getPresetDisplayName(preset) .. " [" .. tostring(presetId) .. "]"
        end
    end

    return tostring(presetId)
end

function HP_AppearanceBindingsScreen:getHelperBindingLabel(helperRow)
    if helperRow == nil then return nil end

    local link = self.draftLinks ~= nil and self.draftLinks[normalizeName(helperRow.name)] or nil
    if link == nil then return nil end

    local presetId = link.presetId or link.selectedPresetId
    if presetId == nil or tostring(presetId) == "" then return nil end

    return getPresetLabelById(presetId)
end

function HP_AppearanceBindingsScreen:getHelperListLabel(helperRow)
    if helperRow == nil then return "" end

    local link = self.draftLinks ~= nil and self.draftLinks[normalizeName(helperRow.name)] or nil
    local bindingLabel = self:getHelperBindingLabel(helperRow)

    if link ~= nil and bindingLabel ~= nil and bindingLabel ~= "" then
        local displayName = link.displayName
        if displayName == nil or tostring(displayName) == "" then
            displayName = helperRow.displayName or helperRow.name
        end

        local baseLabel = tostring(displayName or helperRow.name or "")
        if helperRow.name ~= nil and tostring(helperRow.name) ~= "" and tostring(baseLabel) ~= tostring(helperRow.name) then
            baseLabel = baseLabel .. " (" .. hpFormat("hp_slot_label", "slot: %s", tostring(helperRow.name)) .. ")"
        end

        return baseLabel .. "  [" .. hpI18n("hp_state_bound", "BOUND") .. "]  " .. bindingLabel
    end

    -- Important: when a persisted binding is cleared in the draft, the visible
    -- slot label must revert to the real HelperProfiles slot name immediately.
    -- Do not reuse helperRow.displayName here, because that may have been
    -- derived from the previously persisted AvatarSwitcher binding.
    return tostring(helperRow.name or helperRow.baseName or helperRow.label or "") .. "  [" .. hpI18n("hp_state_unbound", "UNBOUND") .. "]"
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

local function getHelpers()
    local rows = {}
    local list = HelperProfiles ~= nil and HelperProfiles.getProfiles ~= nil and HelperProfiles:getProfiles() or {}
    for idx, helper in ipairs(list) do
        local name = tostring(helper.name or ("Helper " .. tostring(idx)))
        if not isHiddenHelperName(name) then
            local displayName, baseName = getHelperDisplayName(helper, idx)
            baseName = tostring(baseName or name)
            local label = tostring(displayName or name)
            if label ~= name then
                label = label .. " (" .. hpFormat("hp_slot_label", "slot: %s", name) .. ")"
            end
            table.insert(rows, { index = idx, helper = helper, name = name, baseName = baseName, displayName = displayName, label = label })
        end
    end
    return rows
end

function HP_AppearanceBindingsScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or HP_AppearanceBindingsScreen_mt)

    self.helperRows = {}
    self.categoryRows = {}
    self.presetRows = {}
    self.draftLinks = {}

    self.selectedHelperIndex = 1
    self.selectedCategoryIndex = 1
    self.selectedPresetIndex = 1
    self.dirty = false
    self.actionMessage = nil

    return self
end

function HP_AppearanceBindingsScreen:onGuiSetupFinished()
    HP_AppearanceBindingsScreen:superClass().onGuiSetupFinished(self)

    if self.helperTable ~= nil then
        self.helperTable:setDataSource(self)
        self.helperTable:setDelegate(self)
    end
    if self.categoryTable ~= nil then
        self.categoryTable:setDataSource(self)
        self.categoryTable:setDelegate(self)
    end
    if self.presetTable ~= nil then
        self.presetTable:setDataSource(self)
        self.presetTable:setDelegate(self)
    end
end

function HP_AppearanceBindingsScreen:onCreate()
    HP_AppearanceBindingsScreen:superClass().onCreate(self)
end

function HP_AppearanceBindingsScreen:onOpen()
    HP_AppearanceBindingsScreen:superClass().onOpen(self)
    self:reloadData(true)

    if FocusManager ~= nil and self.helperTable ~= nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.helperTable)
        self:setSoundSuppressed(false)
    end
end

function HP_AppearanceBindingsScreen:onClose()
    HP_AppearanceBindingsScreen:superClass().onClose(self)
    if HP_AppearanceBindingsGui ~= nil then
        HP_AppearanceBindingsGui.dialog = nil
    end
end

function HP_AppearanceBindingsScreen:reloadData(reloadBridge)
    if HP_ASBridge ~= nil then
        if HP_ASBridge.init ~= nil then HP_ASBridge:init() end
        if reloadBridge == true and HP_ASBridge.reload ~= nil then HP_ASBridge:reload() end
    end

    self.helperRows = getHelpers()
    if #self.helperRows == 0 then
        table.insert(self.helperRows, { index = 1, helper = nil, name = hpI18n("hp_helper_fallback", "Helper 1"), displayName = hpI18n("hp_no_helpers_available", "No helpers available"), label = hpI18n("hp_no_helpers_available", "No helpers available") })
    end

    self.categoryRows = {}
    if HP_ASBridge ~= nil and HP_ASBridge.getCategories ~= nil then
        local cats = HP_ASBridge:getCategories() or {}
        for _, category in ipairs(cats) do
            if category ~= nil and tostring(category) ~= "" then
                table.insert(self.categoryRows, { id = tostring(category), label = tostring(category) })
            end
        end
    end
    if #self.categoryRows == 0 then
        table.insert(self.categoryRows, { id = "", label = hpI18n("hp_no_categories", "No AvatarSwitcher categories found") })
    end

    self.draftLinks = {}
    if HP_ASBridge ~= nil and HP_ASBridge.getLinksSnapshot ~= nil then
        local snap = HP_ASBridge:getLinksSnapshot() or {}
        for k, link in pairs(snap) do
            self.draftLinks[k] = {
                name = link.name,
                displayName = link.displayName,
                presetId = link.presetId or link.selectedPresetId,
                selectedPresetId = link.selectedPresetId or link.presetId,
                category = link.category,
                characterId = link.characterId,
            }
        end
    end

    self.selectedHelperIndex = clamp(self.selectedHelperIndex or 1, 1, #self.helperRows)
    self:syncSelectionFromDraft()
    self:rebuildPresetRows()
    self:reloadLists()
    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:syncSelectionFromDraft()
    local row = self:getSelectedHelperRow()
    if row == nil then return end

    local link = self.draftLinks[normalizeName(row.name)]
    local wantedCategory = nil
    local wantedPresetId = nil

    if link ~= nil then
        wantedCategory = link.category
        wantedPresetId = link.presetId or link.selectedPresetId
    end

    if wantedCategory ~= nil and tostring(wantedCategory) ~= "" then
        for i, cat in ipairs(self.categoryRows) do
            if tostring(cat.id) == tostring(wantedCategory) then
                self.selectedCategoryIndex = i
                break
            end
        end
    else
        self.selectedCategoryIndex = clamp(self.selectedCategoryIndex or 1, 1, #self.categoryRows)
    end

    self._wantedPresetId = wantedPresetId
end

function HP_AppearanceBindingsScreen:rebuildPresetRows()
    self.presetRows = {}
    local category = self:getSelectedCategoryId()

    if category ~= nil and category ~= "" and HP_ASBridge ~= nil and HP_ASBridge.getPresetsByCategoryForMenu ~= nil then
        local presets = HP_ASBridge:getPresetsByCategoryForMenu(category) or {}
        for _, preset in ipairs(presets) do
            if preset ~= nil and preset.id ~= nil and tostring(preset.id) ~= "" then
                table.insert(self.presetRows, {
                    id = tostring(preset.id),
                    category = tostring(preset.category or category),
                    label = getPresetDisplayName(preset),
                    preset = preset,
                })
            end
        end
    end

    if #self.presetRows == 0 then
        table.insert(self.presetRows, { id = "", category = category or "", label = "No appearances found", preset = nil })
    end

    self.selectedPresetIndex = clamp(self.selectedPresetIndex or 1, 1, #self.presetRows)

    if self._wantedPresetId ~= nil and tostring(self._wantedPresetId) ~= "" then
        for i, row in ipairs(self.presetRows) do
            if tostring(row.id) == tostring(self._wantedPresetId) then
                self.selectedPresetIndex = i
                break
            end
        end
    end
    self._wantedPresetId = nil
end

function HP_AppearanceBindingsScreen:reloadLists()
    if self.helperTable ~= nil then self.helperTable:reloadData() end
    if self.categoryTable ~= nil then self.categoryTable:reloadData() end
    if self.presetTable ~= nil then self.presetTable:reloadData() end
end

function HP_AppearanceBindingsScreen:getNumberOfSections(list)
    return 1
end

function HP_AppearanceBindingsScreen:getNumberOfItemsInSection(list, section)
    if list == self.helperTable then
        return #(self.helperRows or {})
    elseif list == self.categoryTable then
        return #(self.categoryRows or {})
    elseif list == self.presetTable then
        return #(self.presetRows or {})
    end
    return 0
end

function HP_AppearanceBindingsScreen:populateCellForItemInSection(list, section, index, cell)
    if list == self.helperTable then
        local row = self.helperRows[index]
        if row ~= nil and cell ~= nil then
            cell:getAttribute("HelperName"):setText(self:getHelperListLabel(row))
        end
    elseif list == self.categoryTable then
        local row = self.categoryRows[index]
        if row ~= nil and cell ~= nil then
            cell:getAttribute("CategoryName"):setText(tostring(row.label or row.id or ""))
        end
    elseif list == self.presetTable then
        local row = self.presetRows[index]
        if row ~= nil and cell ~= nil then
            cell:getAttribute("PresetName"):setText(tostring(row.label or row.id or ""))
            cell:getAttribute("PresetId"):setText(tostring(row.id or ""))
        end
    end
end

function HP_AppearanceBindingsScreen:onListSelectionChanged(list, section, index)
    if list == self.helperTable then
        self.selectedHelperIndex = clamp(index or 1, 1, #self.helperRows)
        self:syncSelectionFromDraft()
        self:rebuildPresetRows()
        if self.categoryTable ~= nil then self.categoryTable:reloadData() end
        if self.presetTable ~= nil then self.presetTable:reloadData() end
    elseif list == self.categoryTable then
        self.selectedCategoryIndex = clamp(index or 1, 1, #self.categoryRows)
        self.selectedPresetIndex = 1
        self:rebuildPresetRows()
        if self.presetTable ~= nil then self.presetTable:reloadData() end
    elseif list == self.presetTable then
        self.selectedPresetIndex = clamp(index or 1, 1, #self.presetRows)
    end

    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:getSelectedHelperRow()
    return self.helperRows[clamp(self.selectedHelperIndex or 1, 1, #self.helperRows)]
end

function HP_AppearanceBindingsScreen:getSelectedCategoryId()
    local row = self.categoryRows[clamp(self.selectedCategoryIndex or 1, 1, #self.categoryRows)]
    return row ~= nil and row.id or nil
end

function HP_AppearanceBindingsScreen:getSelectedPresetRow()
    return self.presetRows[clamp(self.selectedPresetIndex or 1, 1, #self.presetRows)]
end

function HP_AppearanceBindingsScreen:updateDetailText()
    local helperRow = self:getSelectedHelperRow()
    local category = self:getSelectedCategoryId()
    local presetRow = self:getSelectedPresetRow()

    local detail = hpI18n("hp_detail_select", "Select a helper slot, category, and appearance.")
    if helperRow ~= nil and presetRow ~= nil and presetRow.id ~= nil and presetRow.id ~= "" then
        detail = hpFormat("hp_detail_selected", "Selected: %s  |  %s  |  %s [%s]", tostring(helperRow.displayName or helperRow.name), tostring(category or "-"), tostring(presetRow.label or presetRow.id), tostring(presetRow.id))
    end

    if self.detailText ~= nil then self.detailText:setText(detail) end

    local status = self.actionMessage
    if status == nil or status == "" then
        status = self.dirty and hpI18n("hp_status_unsaved_changes", "Unsaved changes") or hpI18n("hp_status_ready", "Ready")
    elseif self.dirty then
        status = status .. "  |  " .. hpI18n("hp_status_unsaved_changes", "Unsaved changes")
    end

    if helperRow ~= nil then
        local bindingLabel = self:getHelperBindingLabel(helperRow)
        if bindingLabel ~= nil and bindingLabel ~= "" then
            status = status .. "  |  " .. hpFormat("hp_status_current_binding", "Current binding: %s → %s", tostring(helperRow.displayName or helperRow.name), bindingLabel)
        else
            status = status .. "  |  " .. hpFormat("hp_status_current_binding", "Current binding: %s → %s", tostring(helperRow.displayName or helperRow.name), hpI18n("hp_state_unbound_title", "Unbound"))
        end
    end

    if self.statusText ~= nil then self.statusText:setText(status) end
end

function HP_AppearanceBindingsScreen:onClickBindAppearance(sender)
    local helperRow = self:getSelectedHelperRow()
    local presetRow = self:getSelectedPresetRow()
    if helperRow == nil or helperRow.helper == nil then
        self:setStatus(hpI18n("hp_error_no_helper_selected", "Cannot bind: no helper selected"))
        return
    end
    if presetRow == nil or presetRow.id == nil or presetRow.id == "" then
        self:setStatus(hpI18n("hp_error_no_appearance_selected", "Cannot bind: no appearance selected"))
        return
    end

    self.draftLinks[normalizeName(helperRow.name)] = {
        name = helperRow.name,
        displayName = getDerivedDisplayNameForPreset(presetRow.preset, helperRow.name),
        presetId = presetRow.id,
        selectedPresetId = presetRow.id,
        category = presetRow.category or self:getSelectedCategoryId(),
        characterId = presetRow.preset ~= nil and presetRow.preset.characterId or nil,
    }
    self.dirty = true

    local helperName = tostring(helperRow.displayName or helperRow.name)
    local presetLabel = tostring(presetRow.label or presetRow.id)
    self.actionMessage = hpFormat("hp_status_draft_bind", "Draft bind: %s → %s [%s]. Press Save to persist.", helperName, presetLabel, tostring(presetRow.id))

    if self.helperTable ~= nil then self.helperTable:reloadData() end
    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:onClickApplyBinding(sender)
    -- Backwards-compatible callback name for older XML builds.
    return self:onClickBindAppearance(sender)
end

function HP_AppearanceBindingsScreen:onClickClearBinding(sender)
    local helperRow = self:getSelectedHelperRow()
    if helperRow == nil then return end
    self.draftLinks[normalizeName(helperRow.name)] = nil
    self.dirty = true
    self.actionMessage = hpFormat("hp_status_draft_clear", "Draft binding cleared for %s. Press Save to persist.", tostring(helperRow.displayName or helperRow.name))
    if self.helperTable ~= nil then self.helperTable:reloadData() end
    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:onClickClearAllBindings(sender)
    self.draftLinks = {}
    self.dirty = true
    self.actionMessage = hpI18n("hp_status_draft_clear_all", "All draft bindings cleared. Press Save to persist.")
    if self.helperTable ~= nil then self.helperTable:reloadData() end
    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:onClickSave(sender)
    self:saveBindings(false)
end

function HP_AppearanceBindingsScreen:onClickOk(sender)
    self:saveBindings(true)
end

function HP_AppearanceBindingsScreen:onClickBack(sender)
    self:close()
end

function HP_AppearanceBindingsScreen:saveBindings(closeAfterSave)
    if HP_ASBridge == nil or HP_ASBridge.replaceLinksSnapshot == nil then
        self:setStatus(hpI18n("hp_error_as_bridge_unavailable", "Save failed: AS bridge unavailable"))
        return false
    end

    local ok, err = HP_ASBridge:replaceLinksSnapshot(self.draftLinks or {})
    if ok then
        self.dirty = false
        if HP_WorkerAppearance ~= nil and HP_WorkerAppearance.refreshActiveWorkers ~= nil then
            HP_WorkerAppearance:refreshActiveWorkers()
        end
        self.actionMessage = hpI18n("hp_status_bindings_saved", "Bindings saved. Active workers refreshed.")
        -- Rebuild rows from the saved bridge state so an unbound slot drops any
        -- stale display name that came from the previous persisted binding.
        self:reloadData(true)
        if closeAfterSave == true then self:close() end
        return true
    end

    self:setStatus(hpFormat("hp_error_save_failed", "Save failed: %s", tostring(err)))
    return false
end

function HP_AppearanceBindingsScreen:setStatus(text)
    self.actionMessage = tostring(text or "")
    if self.statusText ~= nil then self.statusText:setText(self.actionMessage) end
end

-- ----------------------------------------------------------------------------
-- XML GUI manager. Existing console/keybind code calls HP_AppearanceBindingsGui.
-- ----------------------------------------------------------------------------

HP_AppearanceBindingsGui = HP_AppearanceBindingsGui or {
    dialog = nil,
    loaded = false,
    failed = false,
    modDirectory = HP_GUI_MOD_DIR,
}

function HP_AppearanceBindingsGui:loadMap(name)
    self.modDirectory = HP_GUI_MOD_DIR ~= "" and HP_GUI_MOD_DIR or (g_currentModDirectory or self.modDirectory or "")
end

function HP_AppearanceBindingsGui:deleteMap()
    self.dialog = nil
    self.loaded = false
    self.failed = false
end

function HP_AppearanceBindingsGui:loadDialog()
    if self.loaded or self.failed then return self.loaded end
    if g_gui == nil then
        hpPrint("g_gui unavailable; XML dialog not loaded yet")
        return false
    end

    local modDir = self.modDirectory or HP_GUI_MOD_DIR or g_currentModDirectory or ""
    local profilePath = modDir .. "gui/guiProfiles.xml"
    local dialogPath = modDir .. "gui/HP_AppearanceBindingsScreen.xml"

    local ok, err = pcall(function()
        if g_gui.loadProfiles ~= nil then
            g_gui:loadProfiles(profilePath)
        end
        local frame = HP_AppearanceBindingsScreen.new(g_i18n)
        g_gui:loadGui(dialogPath, "HP_AppearanceBindingsDialog", frame)
        self.loaded = true
    end)

    if ok then
        hpPrint("Loaded XML appearance binding dialog")
        return true
    end

    self.failed = true
    hpPrint("Failed to load XML appearance binding dialog: " .. tostring(err))
    return false
end

function HP_AppearanceBindingsGui:open()
    if not self.loaded then self:loadDialog() end
    if self.loaded and g_gui ~= nil then
        self.dialog = g_gui:showDialog("HP_AppearanceBindingsDialog")
        if self.dialog ~= nil then
            return true
        end
        hpPrint("g_gui:showDialog returned nil for HP_AppearanceBindingsDialog")
    end

    if HP_AppearanceMenu ~= nil and HP_AppearanceMenu.open ~= nil then
        HP_AppearanceMenu:open()
        hpPrint("XML dialog unavailable; opened legacy appearance menu fallback")
        return true
    end

    hpPrint("Appearance binding GUI unavailable")
    return false
end

function HP_AppearanceBindingsGui:toggle()
    return self:open()
end

if addModEventListener ~= nil then
    addModEventListener(HP_AppearanceBindingsGui)
end
