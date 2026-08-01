-- HP_RosterExpansion.lua (FS25_HelperProfiles)
-- Adds helper slots K-T when the game has the untouched vanilla A-J roster.

HP_RosterExpansion = HP_RosterExpansion or {
    completed = false,
    result = "pending",
    addedCount = 0,
    attempts = 0,
    retryMs = 0,
    startupDelayMs = 1000
}

local LOG = "[FS25_HelperProfiles/Roster] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function copyColor(color)
    if type(color) ~= "table" then return {1, 1, 1} end
    local result = {}
    for index, value in ipairs(color) do result[index] = value end
    if #result == 0 then return {1, 1, 1} end
    return result
end

local function cloneStyle(sourceStyle)
    if sourceStyle == nil then return nil, "missing-source-style" end
    if PlayerStyle == nil or PlayerStyle.new == nil then return sourceStyle, "shared-style" end

    if sourceStyle.loadConfigurationIfRequired ~= nil then
        pcall(sourceStyle.loadConfigurationIfRequired, sourceStyle)
    end

    local style = PlayerStyle.new()
    if style ~= nil and style.copyFrom ~= nil then
        local ok = pcall(style.copyFrom, style, sourceStyle)
        if ok then return style, "copied-style" end
    end

    return sourceStyle, "shared-style"
end

local function countSequence(values)
    if type(values) ~= "table" then return 0 end
    local count = math.floor(tonumber(#values) or 0)
    local sequential = 0
    for _, value in ipairs(values) do
        if value ~= nil then sequential = sequential + 1 end
    end
    count = math.max(count, sequential)
    local keyed = 0
    for _, value in pairs(values) do
        if value ~= nil then keyed = keyed + 1 end
    end
    return math.max(count, keyed)
end

local function getCount(manager)
    if manager == nil then return 0 end
    local count = 0
    if manager.getNumOfHelpers ~= nil then
        local ok, value = pcall(manager.getNumOfHelpers, manager)
        if ok and tonumber(value) ~= nil then
            count = math.max(count, math.floor(tonumber(value)))
        end
    end
    count = math.max(count, math.floor(tonumber(manager.numHelpers) or 0))
    count = math.max(count, countSequence(manager.availableHelpers))
    count = math.max(count, countSequence(manager.indexToHelper))
    return count
end

local function getByName(manager, name)
    if manager == nil then return nil end
    if manager.getHelperByName ~= nil then
        local ok, helper = pcall(manager.getHelperByName, manager, name)
        if ok then return helper end
    end
    return manager.helpers ~= nil and manager.helpers[string.upper(tostring(name))] or nil
end

local function getByIndex(manager, index)
    if manager == nil then return nil end
    if manager.getHelperByIndex ~= nil then
        local ok, helper = pcall(manager.getHelperByIndex, manager, index)
        if ok then return helper end
    end
    return manager.indexToHelper ~= nil and manager.indexToHelper[index] or nil
end

local function invalidateRosterCache()
    if HelperProfiles ~= nil then
        HelperProfiles._defaultOrderRefs = nil
        HelperProfiles._defaultPosByRef = nil
        HelperProfiles._hadInUse = nil
        HelperProfiles.selectedHelperRef = nil
        HelperProfiles.selectedIdx = math.max(1, tonumber(HelperProfiles.selectedIdx) or 1)
    end
end

function HP_RosterExpansion:isVanillaRoster(manager)
    if getCount(manager) ~= HP_SlotRegistry.BASE_COUNT then return false end
    for index = 1, HP_SlotRegistry.BASE_COUNT do
        local slot = HP_SlotRegistry:indexToSlot(index)
        if getByName(manager, slot) == nil then return false end
    end
    return true
end

function HP_RosterExpansion:tryExpand(reason)
    if self.completed then return true end
    if g_helperManager == nil or HP_SlotRegistry == nil then return false end

    self.attempts = self.attempts + 1
    local manager = g_helperManager
    local before = getCount(manager)

    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then
        self.completed = true
        self.result = "blocked-incompatible-mod"
        invalidateRosterCache()
        log("HelperProfiles roster disabled because Hired Helper Tool is active: reason=%s helpers=%d", tostring(reason), before)
        return true
    end

    if before > HP_SlotRegistry.TARGET_COUNT then
        if HP_Compatibility ~= nil and HP_Compatibility.setBlocked ~= nil then
            HP_Compatibility:setBlocked("external-helper-roster-" .. tostring(before), "roster-expansion")
        end
        self.completed = true
        self.result = "blocked-external-roster"
        invalidateRosterCache()
        log("HelperProfiles roster disabled because an external roster exceeds the managed target: reason=%s helpers=%d target=%d", tostring(reason), before, HP_SlotRegistry.TARGET_COUNT)
        return true
    end

    if before == HP_SlotRegistry.TARGET_COUNT then
        self.completed = true
        self.result = "adopted-existing-roster"
        invalidateRosterCache()
        log("Existing helper roster adopted: reason=%s helpers=%d target=%d", tostring(reason), before, HP_SlotRegistry.TARGET_COUNT)
        return true
    end

    -- Do not stack a second roster expansion on top of a map or another mod.
    if before ~= HP_SlotRegistry.BASE_COUNT or not self:isVanillaRoster(manager) then
        if before >= HP_SlotRegistry.BASE_COUNT then
            self.completed = true
            self.result = before > HP_SlotRegistry.BASE_COUNT and "external-expanded-roster" or "custom-ten-helper-roster"
            invalidateRosterCache()
            log("External/custom helper roster detected; no helpers injected: reason=%s helpers=%d", tostring(reason), before)
            return true
        end
        return false
    end

    local added = 0
    for index = HP_SlotRegistry.BASE_COUNT + 1, HP_SlotRegistry.TARGET_COUNT do
        local slot = HP_SlotRegistry:indexToSlot(index)
        if getByName(manager, slot) == nil then
            local sourceIndex = ((index - 1) % HP_SlotRegistry.BASE_COUNT) + 1
            local source = getByIndex(manager, sourceIndex)
            if source == nil or source.playerStyle == nil then
                log("Expansion deferred: source helper unavailable for slot %s", tostring(slot))
                return false
            end

            local style, styleSource = cloneStyle(source.playerStyle)
            local helper = manager:addHelper(
                slot,
                "Helper " .. slot,
                copyColor(source.color),
                style,
                g_currentModDirectory or "",
                false
            )
            if helper == nil then
                log("Failed to add helper slot %s", tostring(slot))
                return false
            end

            helper.hpExpandedByHelperProfiles = true
            helper.hpSlotLabel = slot
            helper.hpCanonicalId = HP_SlotRegistry:canonicalId(index)
            helper.hpSourceSlot = HP_SlotRegistry:indexToSlot(sourceIndex)
            helper.hpStyleSource = styleSource
            added = added + 1
        end
    end

    self.addedCount = added
    self.completed = getCount(manager) >= HP_SlotRegistry.TARGET_COUNT
    self.result = self.completed and "expanded-to-20" or "partial"
    invalidateRosterCache()

    log(
        "Roster expansion complete: reason=%s before=%d added=%d after=%d slots=%s-%s",
        tostring(reason), before, added, getCount(manager), HP_SlotRegistry.FIRST_SLOT, HP_SlotRegistry.LAST_SLOT
    )
    return self.completed
end

function HP_RosterExpansion:getStatus()
    return {
        completed = self.completed == true,
        result = tostring(self.result or "pending"),
        addedCount = tonumber(self.addedCount) or 0,
        attempts = tonumber(self.attempts) or 0,
        managerCount = HP_SlotRegistry ~= nil and HP_SlotRegistry:getManagerCount() or 0,
        targetCount = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    }
end

function HP_RosterExpansion:consoleCommandStatus()
    local status = self:getStatus()
    log(
        "status completed=%s result=%s helpers=%d target=%d added=%d attempts=%d",
        tostring(status.completed), status.result, status.managerCount, status.targetCount, status.addedCount, status.attempts
    )
end

function HP_RosterExpansion:loadMap()
    self.completed = false
    self.result = "waiting-startup"
    self.addedCount = 0
    self.attempts = 0
    self.retryMs = tonumber(self.startupDelayMs) or 1000

    -- Do not mutate HelperManager during loadMap. Other roster mods can run later
    -- in the same loadMap pass, so expansion is deferred until every mod has had
    -- time to initialise and the incompatibility guard can observe the final owner.
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then
        self.completed = true
        self.result = "blocked-incompatible-mod"
        invalidateRosterCache()
        log("Roster expansion cancelled during startup because an incompatible roster owner is active.")
    else
        log("Roster expansion deferred for %d ms while compatibility checks complete.", self.retryMs)
    end
end

function HP_RosterExpansion:update(dt)
    if self.completed then return end

    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then
        self.completed = true
        self.result = "blocked-incompatible-mod"
        invalidateRosterCache()
        log("Roster expansion cancelled because an incompatible roster owner became active.")
        return
    end

    self.retryMs = (tonumber(self.retryMs) or 0) - (tonumber(dt) or 0)
    if self.retryMs <= 0 then
        self.retryMs = 500
        self:tryExpand("deferred-update")
    end
end

function HP_RosterExpansion:deleteMap()
    self.completed = false
    self.result = "pending"
end

addModEventListener(HP_RosterExpansion)
