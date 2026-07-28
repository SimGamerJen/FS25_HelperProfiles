-- HP_AppearanceBindingsScreen.lua (FS25_HelperProfiles)
-- ModVersion: 2.1.0.0
-- BuildTag: 20260727.2
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


local function getPayrollAPI()
    -- Prefer the globally published companion API. This is independent of
    -- g_currentMission creation order and remains available to GUI code.
    local api = rawget(_G, "FS25_HelperPayroll_API")
        or rawget(_G, "FS25_HelperPayrollAPI")

    if api == nil and g_currentMission ~= nil then
        api = g_currentMission.fs25HelperPayrollAPI or g_currentMission.helperPayrollAPI
    end

    -- Compatibility fallback for 0.4.1.0 builds that only retained the API on
    -- the HelperPayroll owner table. We still consume the public API object,
    -- never its internal role or persistence tables.
    if api == nil then
        local owner = rawget(_G, "HelperPayroll")
        if type(owner) == "table" then
            api = owner.integrationAPI
        end
    end

    if type(api) ~= "table" or tonumber(api.apiVersion) == nil then
        return nil
    end
    return api
end

local function isPayrollCompanionLoaded()
    if getPayrollAPI() ~= nil or type(rawget(_G, "HelperPayroll")) == "table" then
        return true
    end

    local loaded = rawget(_G, "g_modIsLoaded")
    if type(loaded) == "table" then
        return loaded.FS25_HelperPayroll == true
            or loaded.HelperPayroll == true
    end
    return false
end

local function callPayrollAPI(methodName, ...)
    local api = getPayrollAPI()
    if api == nil then
        return false, nil, "api-unavailable"
    end
    local fn = api[methodName]
    if type(fn) ~= "function" then
        return false, nil, "method-unavailable"
    end
    local ok, result, extra = pcall(fn, api, ...)
    if not ok then
        hpPrint("HelperPayroll API call failed: method=" .. tostring(methodName) .. " error=" .. tostring(result))
        return false, nil, tostring(result)
    end
    return true, result, extra
end

local function slotForIndex(index)
    if HP_SlotRegistry ~= nil and HP_SlotRegistry.indexToSlot ~= nil then
        local numeric = math.floor(tonumber(index) or 0)
        if numeric >= 1 and numeric <= HP_SlotRegistry.TARGET_COUNT then
            return HP_SlotRegistry:indexToSlot(numeric)
        end
    end
    return nil
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
            table.insert(rows, { index = idx, slot = slotForIndex(idx), helper = helper, name = name, baseName = baseName, displayName = displayName, label = label })
        end
    end
    return rows
end

function HP_AppearanceBindingsScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or HP_AppearanceBindingsScreen_mt)

    self.helperRows = {}
    self.categoryRows = {}
    self.presetRows = {}
    self.payrollRoles = {}
    self.draftLinks = {}
    self.draftPayrollRoles = {}
    self.originalPayrollRoles = {}
    self.payrollRoleChanges = {}
    self.payrollRoleSources = {}
    self.appearanceChangedSlots = {}

    self.selectedHelperIndex = 1
    self.selectedCategoryIndex = 1
    self.selectedPresetIndex = 1
    self.selectedPayrollRoleIndex = 1
    self.payrollAvailable = false
    self.payrollDetected = false
    self.payrollMode = nil
    self.payrollRetryElapsedMs = 0
    self.payrollRetryAttempts = 0
    self.appearanceDirty = false
    self.payrollDirty = false
    self.dirty = false
    self.actionMessage = nil

    return self
end


function HP_AppearanceBindingsScreen:refreshDirtyState()
    self.dirty = self.appearanceDirty == true or self.payrollDirty == true
end

function HP_AppearanceBindingsScreen:setVisibleSafe(element, visible)
    if element ~= nil and element.setVisible ~= nil then
        element:setVisible(visible == true)
    end
end

function HP_AppearanceBindingsScreen:setDisabledSafe(element, disabled)
    if element ~= nil and element.setDisabled ~= nil then
        element:setDisabled(disabled == true)
    end
end

function HP_AppearanceBindingsScreen:loadPayrollData(isRetry)
    self.payrollAvailable = false
    self.payrollDetected = isPayrollCompanionLoaded()
    self.payrollRoles = {}
    self.draftPayrollRoles = {}
    self.originalPayrollRoles = {}
    self.payrollRoleChanges = {}
    self.payrollRoleSources = {}
    self.payrollMode = nil

    local api = getPayrollAPI()
    if api ~= nil then
        self.payrollDetected = true
    end

    local statusOk, status = callPayrollAPI("getStatus")
    if not statusOk or type(status) ~= "table" or status.available ~= true then
        if isRetry ~= true then
            hpPrint("HelperPayroll detected=" .. tostring(self.payrollDetected) .. " API ready=false; role controls will retry")
        end
        self:updatePayrollControls()
        return
    end

    self.payrollMode = tostring(status.payrollMode or "roleType")

    local rolesOk, roles = callPayrollAPI("getRoles")
    if not rolesOk or type(roles) ~= "table" or #roles == 0 then
        self:updatePayrollControls()
        return
    end

    for _, role in ipairs(roles) do
        if type(role) == "table" and role.id ~= nil and tostring(role.id) ~= "" then
            table.insert(self.payrollRoles, {
                id = tostring(role.id),
                name = tostring(role.name or role.id),
                payBasis = tostring(role.payBasis or "hourly"),
                rate = tonumber(role.rate) or 0,
                profileId = tostring(role.profileId or status.activePayrollProfile or "default")
            })
        end
    end

    self.payrollAvailable = #self.payrollRoles > 0
    if self.payrollAvailable then
        for _, helperRow in ipairs(self.helperRows or {}) do
            if helperRow.slot ~= nil then
                local roleOk, roleData = callPayrollAPI("getRoleForSlot", helperRow.slot)
                local roleId = roleOk and type(roleData) == "table" and tostring(roleData.roleId or "") or ""
                if roleId == "" then roleId = self.payrollRoles[1].id end
                self.draftPayrollRoles[helperRow.slot] = roleId
                self.originalPayrollRoles[helperRow.slot] = roleId
                self.payrollRoleSources[helperRow.slot] = roleOk and type(roleData) == "table" and tostring(roleData.mappingSource or "unknown") or "unknown"
            end
        end
    end

    self:syncPayrollSelectionFromDraft()
    self:updatePayrollControls()
end

function HP_AppearanceBindingsScreen:syncPayrollSelectionFromDraft()
    self.selectedPayrollRoleIndex = 1
    local helperRow = self:getSelectedHelperRow()
    if helperRow == nil or helperRow.slot == nil then return end
    local wanted = self.draftPayrollRoles[helperRow.slot]
    for index, role in ipairs(self.payrollRoles or {}) do
        if tostring(role.id) == tostring(wanted) then
            self.selectedPayrollRoleIndex = index
            return
        end
    end
end

function HP_AppearanceBindingsScreen:getSelectedPayrollRole()
    if not self.payrollAvailable or #self.payrollRoles == 0 then return nil end
    return self.payrollRoles[clamp(self.selectedPayrollRoleIndex or 1, 1, #self.payrollRoles)]
end

function HP_AppearanceBindingsScreen:updatePayrollControls()
    local visible = self.payrollAvailable == true or self.payrollDetected == true
    self:setVisibleSafe(self.payrollRoleControls, visible)
    self:setDisabledSafe(self.payrollRolePrevButton, self.payrollAvailable ~= true or #self.payrollRoles < 2)
    self:setDisabledSafe(self.payrollRoleNextButton, self.payrollAvailable ~= true or #self.payrollRoles < 2)

    if not visible then return end

    if self.payrollAvailable ~= true then
        if self.payrollRoleValue ~= nil then
            self.payrollRoleValue:setText(hpI18n("hp_payroll_waiting", "Waiting for HelperPayroll..."))
        end
        if self.payrollRoleSource ~= nil then
            self.payrollRoleSource:setText(hpI18n("hp_payroll_retry_context", "API unavailable | Retrying"))
        end
        return
    end

    local helperRow = self:getSelectedHelperRow()
    local role = self:getSelectedPayrollRole()
    local roleText = role ~= nil and tostring(role.name or role.id) or hpI18n("hp_payroll_no_roles", "No payroll roles available")
    if self.payrollRoleValue ~= nil then self.payrollRoleValue:setText(roleText) end

    local source = helperRow ~= nil and helperRow.slot ~= nil and self.payrollRoleSources[helperRow.slot] or "unknown"
    if self.payrollRoleSource ~= nil then
        self.payrollRoleSource:setText(hpFormat(
            "hp_payroll_context",
            "Source: %s | Mode: %s",
            tostring(source),
            tostring(self.payrollMode or "roleType")
        ))
    end
end

function HP_AppearanceBindingsScreen:cyclePayrollRole(delta)
    if not self.payrollAvailable or #self.payrollRoles == 0 then return end
    local helperRow = self:getSelectedHelperRow()
    if helperRow == nil or helperRow.slot == nil or helperRow.helper == nil then
        self:setStatus(hpI18n("hp_error_no_helper_selected", "Cannot change role: no helper selected"))
        return
    end

    local count = #self.payrollRoles
    self.selectedPayrollRoleIndex = ((self.selectedPayrollRoleIndex - 1 + (delta or 1)) % count) + 1
    local role = self:getSelectedPayrollRole()
    self.draftPayrollRoles[helperRow.slot] = role.id
    self.payrollRoleSources[helperRow.slot] = "draft"
    if tostring(self.originalPayrollRoles[helperRow.slot] or "") == tostring(role.id) then
        self.payrollRoleChanges[helperRow.slot] = nil
    else
        self.payrollRoleChanges[helperRow.slot] = role.id
    end
    self.payrollDirty = next(self.payrollRoleChanges) ~= nil
    self:refreshDirtyState()
    self.actionMessage = hpFormat(
        "hp_status_draft_payroll_role",
        "Draft payroll role: %s → %s. Press Save to persist.",
        tostring(helperRow.displayName or helperRow.name),
        tostring(role.name or role.id)
    )
    self:updatePayrollControls()
    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:onClickPayrollRolePrevious(sender)
    self:cyclePayrollRole(-1)
end

function HP_AppearanceBindingsScreen:onClickPayrollRoleNext(sender)
    self:cyclePayrollRole(1)
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
    self:updatePayrollControls()
end

function HP_AppearanceBindingsScreen:onCreate()
    HP_AppearanceBindingsScreen:superClass().onCreate(self)
end

function HP_AppearanceBindingsScreen:onOpen()
    HP_AppearanceBindingsScreen:superClass().onOpen(self)
    self.payrollRetryElapsedMs = 0
    self.payrollRetryAttempts = 0
    self:reloadData(true)

    if FocusManager ~= nil and self.helperTable ~= nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.helperTable)
        self:setSoundSuppressed(false)
    end
end


function HP_AppearanceBindingsScreen:update(dt)
    local superClass = HP_AppearanceBindingsScreen:superClass()
    if superClass ~= nil and superClass.update ~= nil then
        superClass.update(self, dt)
    end

    if self.payrollAvailable == true then return end
    if not isPayrollCompanionLoaded() and getPayrollAPI() == nil then return end

    self.payrollDetected = true
    self.payrollRetryElapsedMs = (self.payrollRetryElapsedMs or 0) + (tonumber(dt) or 0)
    if self.payrollRetryElapsedMs < 500 then
        self:updatePayrollControls()
        return
    end

    self.payrollRetryElapsedMs = 0
    self.payrollRetryAttempts = (self.payrollRetryAttempts or 0) + 1
    self:loadPayrollData(true)
    if self.payrollAvailable == true then
        hpPrint("HelperPayroll API became ready after " .. tostring(self.payrollRetryAttempts) .. " UI retry attempt(s)")
        self:updateDetailText()
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
        table.insert(self.helperRows, { index = 1, slot = "A", helper = nil, name = hpI18n("hp_helper_fallback", "Helper 1"), displayName = hpI18n("hp_no_helpers_available", "No helpers available"), label = hpI18n("hp_no_helpers_available", "No helpers available") })
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
    self.appearanceDirty = false
    self.payrollDirty = false
    self.appearanceChangedSlots = {}
    self:refreshDirtyState()
    self:syncSelectionFromDraft()
    self:rebuildPresetRows()
    self:loadPayrollData()
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
        self:syncPayrollSelectionFromDraft()
        self:rebuildPresetRows()
        self:updatePayrollControls()
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

    local detail = hpI18n("hp_detail_select", "Select a helper slot, appearance, and payroll role.")
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
    self.appearanceDirty = true
    if helperRow.slot ~= nil then self.appearanceChangedSlots[helperRow.slot] = true end
    self:refreshDirtyState()

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
    self.appearanceDirty = true
    if helperRow.slot ~= nil then self.appearanceChangedSlots[helperRow.slot] = true end
    self:refreshDirtyState()
    self.actionMessage = hpFormat("hp_status_draft_clear", "Draft binding cleared for %s. Press Save to persist.", tostring(helperRow.displayName or helperRow.name))
    if self.helperTable ~= nil then self.helperTable:reloadData() end
    self:updateDetailText()
end

function HP_AppearanceBindingsScreen:onClickClearAllBindings(sender)
    self.draftLinks = {}
    self.appearanceDirty = true
    for _, helperRow in ipairs(self.helperRows or {}) do
        if helperRow.slot ~= nil then self.appearanceChangedSlots[helperRow.slot] = true end
    end
    self:refreshDirtyState()
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
    if self.dirty ~= true then
        self:setStatus(hpI18n("hp_status_ready", "Ready"))
        if closeAfterSave == true then self:close() end
        return true
    end

    local appearanceSaved = false
    if self.appearanceDirty == true then
        if HP_ASBridge == nil or HP_ASBridge.replaceLinksSnapshot == nil then
            self:setStatus(hpI18n("hp_error_as_bridge_unavailable", "Save failed: AS bridge unavailable"))
            return false
        end

        local ok, err = HP_ASBridge:replaceLinksSnapshot(self.draftLinks or {})
        if not ok then
            self:setStatus(hpFormat("hp_error_save_failed", "Save failed: %s", tostring(err)))
            return false
        end

        self.appearanceDirty = false
        appearanceSaved = true
        if HP_WorkerAppearance ~= nil and HP_WorkerAppearance.refreshActiveWorkers ~= nil then
            HP_WorkerAppearance:refreshActiveWorkers()
        end
    end

    local payrollSaved = false
    local roleMappingsToApply = {}
    for slot, roleId in pairs(self.payrollRoleChanges or {}) do
        roleMappingsToApply[slot] = roleId
    end
    -- Avatar bindings are part of a helper's stable identity. When an appearance
    -- changes, re-save that helper's current role against the new identity even
    -- when the visible role itself was not changed in this edit session.
    if appearanceSaved and self.payrollAvailable == true then
        for slot, changed in pairs(self.appearanceChangedSlots or {}) do
            if changed == true and self.draftPayrollRoles[slot] ~= nil then
                roleMappingsToApply[slot] = self.draftPayrollRoles[slot]
            end
        end
    end

    if next(roleMappingsToApply) ~= nil then
        local api = getPayrollAPI()
        if api == nil then
            self:refreshDirtyState()
            self:setStatus(hpI18n("hp_error_payroll_api_unavailable", "Payroll role save failed: HelperPayroll API unavailable"))
            return false
        end

        local callOk, saved, result = callPayrollAPI("applyRoleMappings", roleMappingsToApply, "helperprofiles-profile-ui")
        if not callOk or saved ~= true then
            self:refreshDirtyState()
            self:setStatus(hpFormat("hp_error_payroll_save_failed", "Payroll role save failed: %s", tostring(result or saved or "unknown")))
            return false
        end
        self.payrollRoleChanges = {}
        self.payrollDirty = false
        payrollSaved = true
    end

    self:refreshDirtyState()
    if appearanceSaved and payrollSaved then
        self.actionMessage = hpI18n("hp_status_profile_changes_saved", "Appearance bindings and payroll roles saved.")
    elseif payrollSaved then
        self.actionMessage = hpI18n("hp_status_payroll_roles_saved", "Payroll roles saved.")
    else
        self.actionMessage = hpI18n("hp_status_bindings_saved", "Bindings saved. Active workers refreshed.")
    end

    self:reloadData(true)
    if closeAfterSave == true then self:close() end
    return true
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
