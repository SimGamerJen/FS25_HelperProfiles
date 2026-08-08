-- HP_WorldWorkerScreen.lua (FS25_HelperProfiles)
-- 2.2.0.0-alpha2: fullscreen management UI for static world-worker placement.

if HP_WorldWorkerScreen ~= nil then return end

HP_WorldWorkerScreen = {}
local HP_WorldWorkerScreen_mt = Class(HP_WorldWorkerScreen, MessageDialog)
local LOG = "[FS25_HelperProfiles/WorldWorkerUI] "
local MOD_DIR = g_currentModDirectory or ""

local function hpPrint(message) print(LOG .. tostring(message)) end

local function clamp(value, minimum, maximum)
    value = math.floor(tonumber(value) or minimum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function getDisplayName(helper, stableIndex)
    if HelperProfiles ~= nil and HelperProfiles.getDisplayNameForHelper ~= nil then
        local ok, value = pcall(HelperProfiles.getDisplayNameForHelper, HelperProfiles, helper, stableIndex)
        if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    return tostring(helper ~= nil and helper.name or ("Helper " .. tostring(stableIndex)))
end

local function isActive(helper)
    if helper == nil then return false end
    if HelperProfiles ~= nil and HelperProfiles.isHelperActive ~= nil then
        local ok, value = pcall(HelperProfiles.isHelperActive, HelperProfiles, helper)
        if ok then return value == true end
    end
    return helper.inUse == true
end

local function isRosterEnabled(helper, stableIndex)
    if HP_RosterState == nil then return true end
    return HP_RosterState:isEnabled(helper, stableIndex)
end

local function getPlacement(stableIndex)
    if HP_WorldState == nil then return nil end
    return HP_WorldState:getPlacement(stableIndex)
end

local function isSpawned(stableIndex)
    if HP_WorldWorkerManager == nil or HP_WorldWorkerManager.instancesByCanonicalId == nil then return false end
    local id = HP_SlotRegistry ~= nil and HP_SlotRegistry:canonicalId(stableIndex) or nil
    return id ~= nil and HP_WorldWorkerManager.instancesByCanonicalId[id] ~= nil
end

function HP_WorldWorkerScreen.new(target, customMt)
    local self = MessageDialog.new(target, customMt or HP_WorldWorkerScreen_mt)
    self.rows = {}
    self.selectedIndex = 1
    self.actionMessage = nil
    return self
end

function HP_WorldWorkerScreen:onGuiSetupFinished()
    HP_WorldWorkerScreen:superClass().onGuiSetupFinished(self)
    if self.worldTable ~= nil then
        self.worldTable:setDataSource(self)
        self.worldTable:setDelegate(self)
    end
end

function HP_WorldWorkerScreen:onCreate()
    HP_WorldWorkerScreen:superClass().onCreate(self)
end

function HP_WorldWorkerScreen:onOpen()
    HP_WorldWorkerScreen:superClass().onOpen(self)
    self:reloadData()
    if FocusManager ~= nil and self.worldTable ~= nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.worldTable)
        self:setSoundSuppressed(false)
    end
end

function HP_WorldWorkerScreen:onClose()
    HP_WorldWorkerScreen:superClass().onClose(self)
    if HP_WorldWorkerGui ~= nil then HP_WorldWorkerGui.dialog = nil end
end

function HP_WorldWorkerScreen:reloadData()
    self.rows = {}
    if HP_WorldState ~= nil and not HP_WorldState.initialized then HP_WorldState:init() end

    local allProfiles = HelperProfiles ~= nil and HelperProfiles.getAllProfiles ~= nil
        and HelperProfiles:getAllProfiles() or {}
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or #allProfiles

    for stableIndex = 1, target do
        local helper = allProfiles[stableIndex]
        local slot = HP_SlotRegistry ~= nil and HP_SlotRegistry:indexToSlot(stableIndex) or tostring(stableIndex)
        local canonicalId = HP_SlotRegistry ~= nil and HP_SlotRegistry:canonicalId(stableIndex) or tostring(stableIndex)
        self.rows[#self.rows + 1] = {
            stableIndex = stableIndex,
            slot = slot,
            canonicalId = canonicalId,
            helper = helper,
            displayName = getDisplayName(helper, stableIndex)
        }
    end

    self.selectedIndex = clamp(self.selectedIndex, 1, math.max(1, #self.rows))
    self.actionMessage = nil
    if self.worldTable ~= nil then self.worldTable:reloadData() end
    self:updateDetailText()
end

function HP_WorldWorkerScreen:getSelectedRow()
    return self.rows[clamp(self.selectedIndex, 1, math.max(1, #self.rows))]
end

function HP_WorldWorkerScreen:getNumberOfSections() return 1 end
function HP_WorldWorkerScreen:getNumberOfItemsInSection() return #(self.rows or {}) end

function HP_WorldWorkerScreen:populateCellForItemInSection(list, section, index, cell)
    local row = self.rows[index]
    if row == nil or cell == nil then return end

    local placement = getPlacement(row.stableIndex)
    local active = isActive(row.helper)
    local spawned = isSpawned(row.stableIndex)
    local rostered = isRosterEnabled(row.helper, row.stableIndex)

    local worldState = "NOT PLACED"
    if placement ~= nil then
        if active then worldState = "PLACED / WORKING"
        elseif spawned then worldState = "PLACED"
        else worldState = "PLACED / HIDDEN" end
    end

    local position = "-"
    if placement ~= nil then
        position = string.format("%.1f, %.1f", tonumber(placement.x) or 0, tonumber(placement.z) or 0)
    end

    cell:getAttribute("Slot"):setText(tostring(row.slot or "?"))
    cell:getAttribute("Worker"):setText(tostring(row.displayName or "-"))
    cell:getAttribute("RosterState"):setText(rostered and "ON ROSTER" or "OFF ROSTER")
    cell:getAttribute("WorkState"):setText(active and "ACTIVE" or "AVAILABLE")
    cell:getAttribute("WorldState"):setText(worldState)
    cell:getAttribute("Position"):setText(position)
end

function HP_WorldWorkerScreen:onListSelectionChanged(list, section, index)
    self.selectedIndex = clamp(index or 1, 1, math.max(1, #self.rows))
    self:updateDetailText()
end

function HP_WorldWorkerScreen:setStatus(message)
    self.actionMessage = tostring(message or "")
    self:updateDetailText()
end

function HP_WorldWorkerScreen:updateDetailText()
    local row = self:getSelectedRow()
    local placedCount, spawnedCount = 0, 0
    for _, candidate in ipairs(self.rows or {}) do
        if getPlacement(candidate.stableIndex) ~= nil then placedCount = placedCount + 1 end
        if isSpawned(candidate.stableIndex) then spawnedCount = spawnedCount + 1 end
    end

    local detail = "Select a worker to place, move or remove their independent world presence."
    if row ~= nil then
        local placement = getPlacement(row.stableIndex)
        local active = isActive(row.helper)
        local rostered = isRosterEnabled(row.helper, row.stableIndex)
        detail = string.format("%s (%s / %s) | %s | %s | %s",
            tostring(row.displayName), tostring(row.slot), tostring(row.canonicalId),
            rostered and "ON ROSTER" or "OFF ROSTER",
            active and "ACTIVE" or "AVAILABLE",
            placement ~= nil and "WORLD PLACEMENT SAVED" or "NOT PLACED")
    end
    if self.detailText ~= nil then self.detailText:setText(detail) end

    local status = self.actionMessage or string.format("World placements: %d | Currently visible: %d", placedCount, spawnedCount)
    if self.statusText ~= nil then self.statusText:setText(status) end
end

function HP_WorldWorkerScreen:runWorldAction(actionName)
    local row = self:getSelectedRow()
    if row == nil then return end
    if HP_WorldWorkerManager == nil then
        self:setStatus("World worker manager unavailable.")
        return
    end

    local ok, err
    if actionName == "place" or actionName == "move" then
        ok, err = HP_WorldWorkerManager:placeAtPlayer(row.stableIndex)
    elseif actionName == "remove" then
        ok, err = HP_WorldWorkerManager:removePlacement(row.stableIndex)
    else
        return
    end

    if ok then
        if actionName == "place" then
            self.actionMessage = string.format("Placed %s at your current location.", tostring(row.displayName))
        elseif actionName == "move" then
            self.actionMessage = string.format("Moved %s to your current location.", tostring(row.displayName))
        else
            self.actionMessage = string.format("Removed %s from the world.", tostring(row.displayName))
        end
    else
        self.actionMessage = string.format("%s failed for %s: %s", string.upper(actionName), tostring(row.displayName), tostring(err or "unknown"))
    end

    if self.worldTable ~= nil then self.worldTable:reloadData() end
    self:updateDetailText()
end

function HP_WorldWorkerScreen:onClickPlaceHere(sender)
    local row = self:getSelectedRow()
    if row ~= nil and getPlacement(row.stableIndex) ~= nil then
        return self:runWorldAction("move")
    end
    return self:runWorldAction("place")
end

function HP_WorldWorkerScreen:onClickMoveHere(sender)
    return self:runWorldAction("move")
end

function HP_WorldWorkerScreen:onClickRemove(sender)
    return self:runWorldAction("remove")
end

function HP_WorldWorkerScreen:onClickBack(sender)
    self:close()
end

HP_WorldWorkerGui = HP_WorldWorkerGui or {
    dialog = nil,
    loaded = false,
    failed = false,
    modDirectory = MOD_DIR
}

function HP_WorldWorkerGui:loadMap()
    self.modDirectory = MOD_DIR ~= "" and MOD_DIR or (g_currentModDirectory or self.modDirectory or "")
end

function HP_WorldWorkerGui:deleteMap()
    self.dialog = nil
    self.loaded = false
    self.failed = false
end

function HP_WorldWorkerGui:loadDialog()
    if self.loaded or self.failed then return self.loaded end
    if g_gui == nil then return false end

    local modDir = self.modDirectory or MOD_DIR or g_currentModDirectory or ""
    local ok, err = pcall(function()
        if g_gui.loadProfiles ~= nil then g_gui:loadProfiles(modDir .. "gui/guiProfiles.xml") end
        local frame = HP_WorldWorkerScreen.new(g_i18n)
        g_gui:loadGui(modDir .. "gui/HP_WorldWorkerScreen.xml", "HP_WorldWorkerDialog", frame)
        self.loaded = true
    end)

    if not ok then
        self.failed = true
        hpPrint("Failed to load world worker manager: " .. tostring(err))
    end
    return self.loaded
end

function HP_WorldWorkerGui:open()
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then return false end
    if not self.loaded then self:loadDialog() end
    if self.loaded and g_gui ~= nil then
        self.dialog = g_gui:showDialog("HP_WorldWorkerDialog")
        return self.dialog ~= nil
    end
    return false
end

if addConsoleCommand ~= nil then
    addConsoleCommand("hpWorldManage", "Open the HelperProfiles world worker manager", "open", HP_WorldWorkerGui)
end

addModEventListener(HP_WorldWorkerGui)
