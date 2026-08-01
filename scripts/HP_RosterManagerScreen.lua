-- HP_RosterManagerScreen.lua (FS25_HelperProfiles)
-- Fullscreen administrative UI for per-save ON/OFF roster availability.

if HP_RosterManagerScreen ~= nil then return end

HP_RosterManagerScreen = {}
local HP_RosterManagerScreen_mt = Class(HP_RosterManagerScreen, MessageDialog)
local LOG = "[FS25_HelperProfiles/RosterManager] "
local MOD_DIR = g_currentModDirectory or ""

local function hpPrint(message) print(LOG .. tostring(message)) end

local function hpI18n(key, fallback)
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, value = pcall(g_i18n.getText, g_i18n, key)
        if ok and value ~= nil and value ~= "" and value ~= key then return tostring(value) end
    end
    return fallback or key
end

local function clamp(value, minimum, maximum)
    value = math.floor(tonumber(value) or minimum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function getPayrollAPI()
    local api = rawget(_G, "FS25_HelperPayroll_API") or rawget(_G, "FS25_HelperPayrollAPI")
    if type(api) == "table" then return api end
    if g_currentMission ~= nil then
        api = g_currentMission.fs25HelperPayrollAPI or g_currentMission.helperPayrollAPI
        if type(api) == "table" then return api end
    end
    return nil
end

local function getRoleLabel(slot)
    local api = getPayrollAPI()
    if api == nil or type(api.getRoleForSlot) ~= "function" then return "-" end
    local ok, roleData = pcall(api.getRoleForSlot, api, slot)
    if ok and type(roleData) == "table" then
        return tostring(roleData.roleName or roleData.roleId or "-")
    end
    return "-"
end

local function getDisplayName(helper, stableIndex)
    if HelperProfiles ~= nil and HelperProfiles.getDisplayNameForHelper ~= nil then
        local ok, displayName = pcall(HelperProfiles.getDisplayNameForHelper, HelperProfiles, helper, stableIndex)
        if ok and displayName ~= nil and tostring(displayName) ~= "" then return tostring(displayName) end
    end
    return tostring(helper ~= nil and helper.name or ("Helper " .. tostring(stableIndex)))
end

local function getAppearanceLabel(helper, stableIndex)
    if HelperProfiles ~= nil and HelperProfiles.getAppearanceLabelForHelper ~= nil then
        local ok, label = pcall(HelperProfiles.getAppearanceLabelForHelper, HelperProfiles, helper, stableIndex)
        if ok and label ~= nil and tostring(label) ~= "" then
            local text = tostring(label)
            local lower = string.lower(text)
            if string.find(lower, "no as preset", 1, true) == 1
                or string.find(lower, "as presets unavailable", 1, true) == 1 then
                return "-"
            end
            return text
        end
    end
    return "-"
end

local function isActive(helper)
    if helper == nil then return false end
    if HelperProfiles ~= nil and HelperProfiles.isHelperActive ~= nil then
        local ok, value = pcall(HelperProfiles.isHelperActive, HelperProfiles, helper)
        if ok then return value == true end
    end
    return helper.inUse == true
end

local function mapsEqual(a, b)
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    for index = 1, target do
        local canonicalId = HP_SlotRegistry:canonicalId(index)
        if (a[canonicalId] ~= false) ~= (b[canonicalId] ~= false) then return false end
    end
    return true
end

function HP_RosterManagerScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or HP_RosterManagerScreen_mt)
    self.rows = {}
    self.originalEnabled = {}
    self.draftEnabled = {}
    self.selectedIndex = 1
    self.actionMessage = nil
    self.dirty = false
    return self
end

function HP_RosterManagerScreen:onGuiSetupFinished()
    HP_RosterManagerScreen:superClass().onGuiSetupFinished(self)
    if self.rosterTable ~= nil then
        self.rosterTable:setDataSource(self)
        self.rosterTable:setDelegate(self)
    end
end

function HP_RosterManagerScreen:onCreate()
    HP_RosterManagerScreen:superClass().onCreate(self)
end

function HP_RosterManagerScreen:onOpen()
    HP_RosterManagerScreen:superClass().onOpen(self)
    self:reloadData()
    if FocusManager ~= nil and self.rosterTable ~= nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.rosterTable)
        self:setSoundSuppressed(false)
    end
end

function HP_RosterManagerScreen:onClose()
    HP_RosterManagerScreen:superClass().onClose(self)
    if HP_RosterManagerGui ~= nil then HP_RosterManagerGui.dialog = nil end
end

function HP_RosterManagerScreen:reloadData()
    if HP_RosterState ~= nil and not HP_RosterState.initialized then HP_RosterState:init() end
    self.rows = {}

    local allProfiles = HelperProfiles ~= nil and HelperProfiles.getAllProfiles ~= nil
        and HelperProfiles:getAllProfiles() or {}
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or #allProfiles

    self.originalEnabled = HP_RosterState ~= nil and HP_RosterState:getSnapshot() or {}
    self.draftEnabled = {}
    for canonicalId, enabled in pairs(self.originalEnabled) do self.draftEnabled[canonicalId] = enabled ~= false end

    for stableIndex = 1, target do
        local helper = allProfiles[stableIndex]
        local slot = HP_SlotRegistry:indexToSlot(stableIndex)
        local canonicalId = HP_SlotRegistry:canonicalId(stableIndex)
        self.rows[#self.rows + 1] = {
            stableIndex = stableIndex,
            slot = slot,
            canonicalId = canonicalId,
            helper = helper,
            displayName = getDisplayName(helper, stableIndex),
            appearance = getAppearanceLabel(helper, stableIndex),
            role = getRoleLabel(slot),
            active = isActive(helper)
        }
    end

    self.selectedIndex = clamp(self.selectedIndex, 1, math.max(1, #self.rows))
    self.actionMessage = nil
    self:refreshDirtyState()
    if self.rosterTable ~= nil then self.rosterTable:reloadData() end
    self:updateDetailText()
end

function HP_RosterManagerScreen:refreshDirtyState()
    self.dirty = not mapsEqual(self.draftEnabled or {}, self.originalEnabled or {})
end

function HP_RosterManagerScreen:getEnabledCount()
    local count = 0
    for _, row in ipairs(self.rows or {}) do
        if self.draftEnabled[row.canonicalId] ~= false then count = count + 1 end
    end
    return count
end

function HP_RosterManagerScreen:getSelectedRow()
    return self.rows[clamp(self.selectedIndex, 1, math.max(1, #self.rows))]
end

function HP_RosterManagerScreen:getNumberOfSections() return 1 end
function HP_RosterManagerScreen:getNumberOfItemsInSection() return #(self.rows or {}) end

function HP_RosterManagerScreen:populateCellForItemInSection(list, section, index, cell)
    local row = self.rows[index]
    if row == nil or cell == nil then return end

    local enabled = self.draftEnabled[row.canonicalId] ~= false
    cell:getAttribute("Slot"):setText(tostring(row.slot or "?"))
    cell:getAttribute("Worker"):setText(tostring(row.displayName or "-"))
    cell:getAttribute("Appearance"):setText(tostring(row.appearance or "-"))
    cell:getAttribute("Role"):setText(tostring(row.role or "-"))
    cell:getAttribute("WorkState"):setText(row.active and hpI18n("hp_state_active", "ACTIVE") or hpI18n("hp_state_available", "AVAILABLE"))
    cell:getAttribute("RosterState"):setText(enabled and hpI18n("hp_roster_on", "ON ROSTER") or hpI18n("hp_roster_off", "OFF ROSTER"))
end

function HP_RosterManagerScreen:onListSelectionChanged(list, section, index)
    self.selectedIndex = clamp(index or 1, 1, math.max(1, #self.rows))
    self:updateDetailText()
end

function HP_RosterManagerScreen:updateDetailText()
    local row = self:getSelectedRow()
    local enabledCount = self:getEnabledCount()
    local total = #(self.rows or {})
    local detail = hpI18n("hp_roster_detail", "Choose which permanent helper identities are available to the farm.")

    if row ~= nil then
        local enabled = self.draftEnabled[row.canonicalId] ~= false
        detail = string.format("%s (%s / %s) | %s | %s",
            tostring(row.displayName), tostring(row.slot), tostring(row.canonicalId),
            row.active and hpI18n("hp_state_active", "ACTIVE") or hpI18n("hp_state_available", "AVAILABLE"),
            enabled and hpI18n("hp_roster_on", "ON ROSTER") or hpI18n("hp_roster_off", "OFF ROSTER"))
    end
    if self.detailText ~= nil then self.detailText:setText(detail) end

    local status = self.actionMessage or string.format(
        hpI18n("hp_roster_status_summary", "Rostered workers: %d of %d | Off roster: %d"),
        enabledCount, total, total - enabledCount
    )
    if self.dirty then status = status .. " | " .. hpI18n("hp_status_unsaved_changes", "Unsaved changes") end
    if self.statusText ~= nil then self.statusText:setText(status) end
end

function HP_RosterManagerScreen:setStatus(message)
    self.actionMessage = tostring(message or "")
    self:updateDetailText()
end

function HP_RosterManagerScreen:onClickToggleRoster(sender)
    local row = self:getSelectedRow()
    if row == nil then return end

    local currentlyEnabled = self.draftEnabled[row.canonicalId] ~= false
    if currentlyEnabled then
        if row.active then
            self:setStatus(string.format(
                hpI18n("hp_roster_error_active", "Slot %s is active. Release the worker before removing them from the roster."),
                tostring(row.slot)
            ))
            return
        end
        if self:getEnabledCount() <= 1 then
            self:setStatus(hpI18n("hp_roster_error_minimum", "At least one worker must remain ON roster."))
            return
        end
    end

    self.draftEnabled[row.canonicalId] = not currentlyEnabled
    self.actionMessage = string.format(
        hpI18n("hp_roster_status_draft", "%s set %s. Press Save to persist."),
        tostring(row.displayName),
        self.draftEnabled[row.canonicalId] and hpI18n("hp_roster_on", "ON ROSTER") or hpI18n("hp_roster_off", "OFF ROSTER")
    )
    self:refreshDirtyState()
    if self.rosterTable ~= nil then self.rosterTable:reloadData() end
    self:updateDetailText()
end

function HP_RosterManagerScreen:onClickEnableAll(sender)
    for _, row in ipairs(self.rows or {}) do self.draftEnabled[row.canonicalId] = true end
    self.actionMessage = hpI18n("hp_roster_status_enable_all", "All workers set ON roster. Press Save to persist.")
    self:refreshDirtyState()
    if self.rosterTable ~= nil then self.rosterTable:reloadData() end
    self:updateDetailText()
end

function HP_RosterManagerScreen:onClickSave(sender)
    self:refreshDirtyState()
    if not self.dirty then
        self:setStatus(hpI18n("hp_status_ready", "Ready"))
        return
    end
    if HP_RosterState == nil then
        self:setStatus(hpI18n("hp_roster_error_service", "Roster state service unavailable."))
        return
    end

    local ok, err, detail = HP_RosterState:replaceSnapshot(self.draftEnabled)
    if not ok then
        if err == "active-slot" then
            self:setStatus(string.format(
                hpI18n("hp_roster_error_became_active", "Slot %s became active. Release the worker before removing them from the roster."),
                tostring(detail or "?")
            ))
        elseif err == "at-least-one-required" then
            self:setStatus(hpI18n("hp_roster_error_minimum", "At least one worker must remain ON roster."))
        else
            self:setStatus(string.format(
                hpI18n("hp_roster_error_save", "Roster save failed: %s"),
                tostring(err or "unknown")
            ))
        end
        return
    end

    self.originalEnabled = HP_RosterState:getSnapshot()
    self.draftEnabled = HP_RosterState:getSnapshot()
    self:refreshDirtyState()
    self.actionMessage = string.format(
        hpI18n("hp_roster_status_saved", "Roster saved. %d worker(s) are ON roster."),
        HP_RosterState:getEnabledCount()
    )
    if self.rosterTable ~= nil then self.rosterTable:reloadData() end
    self:updateDetailText()
end

function HP_RosterManagerScreen:onClickAppearances(sender)
    self:close()
    if HP_AppearanceBindingsGui ~= nil and HP_AppearanceBindingsGui.open ~= nil then
        HP_AppearanceBindingsGui:open()
    end
end

function HP_RosterManagerScreen:onClickBack(sender)
    self:close()
end

HP_RosterManagerGui = HP_RosterManagerGui or {
    dialog = nil,
    loaded = false,
    failed = false,
    modDirectory = MOD_DIR
}

function HP_RosterManagerGui:loadMap()
    self.modDirectory = MOD_DIR ~= "" and MOD_DIR or (g_currentModDirectory or self.modDirectory or "")
end

function HP_RosterManagerGui:deleteMap()
    self.dialog = nil
    self.loaded = false
    self.failed = false
end

function HP_RosterManagerGui:loadDialog()
    if self.loaded or self.failed then return self.loaded end
    if g_gui == nil then return false end

    local modDir = self.modDirectory or MOD_DIR or g_currentModDirectory or ""
    local ok, err = pcall(function()
        if g_gui.loadProfiles ~= nil then g_gui:loadProfiles(modDir .. "gui/guiProfiles.xml") end
        local frame = HP_RosterManagerScreen.new(g_i18n)
        g_gui:loadGui(modDir .. "gui/HP_RosterManagerScreen.xml", "HP_RosterManagerDialog", frame)
        self.loaded = true
    end)

    if not ok then
        self.failed = true
        hpPrint("Failed to load roster manager: " .. tostring(err))
    end
    return self.loaded
end

function HP_RosterManagerGui:open()
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then return false end
    if not self.loaded then self:loadDialog() end
    if self.loaded and g_gui ~= nil then
        self.dialog = g_gui:showDialog("HP_RosterManagerDialog")
        return self.dialog ~= nil
    end
    return false
end

if HP_AppearanceBindingsScreen ~= nil then
    -- The operational roster is compacted after OFF-roster workers are filtered.
    -- Re-resolve every appearance row to its permanent A-T slot so messages and
    -- active-slot protection never confuse the visible list index with identity.
    if HP_AppearanceBindingsScreen._hpRosterReloadWrapped ~= true then
        local originalReloadData = HP_AppearanceBindingsScreen.reloadData
        function HP_AppearanceBindingsScreen:reloadData(...)
            originalReloadData(self, ...)
            for _, helperRow in ipairs(self.helperRows or {}) do
                if helperRow.helper ~= nil and HP_SlotRegistry ~= nil then
                    helperRow.slot = HP_SlotRegistry:getSlotForHelper(helperRow.helper, helperRow.index)
                        or helperRow.name
                end
            end
            if self.helperTable ~= nil then self.helperTable:reloadData() end
            self:updateDetailText()
        end
        HP_AppearanceBindingsScreen._hpRosterReloadWrapped = true
    end

    function HP_AppearanceBindingsScreen:onClickOpenRosterManager(sender)
        self:close()
        HP_RosterManagerGui:open()
    end
end

if addConsoleCommand ~= nil then
    addConsoleCommand("hpRosterManage", "Open the HelperProfiles roster manager", "open", HP_RosterManagerGui)
end

addModEventListener(HP_RosterManagerGui)
