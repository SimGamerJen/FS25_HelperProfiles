-- HP_SlotRegistry.lua (FS25_HelperProfiles)
-- Shared helper-slot identity model for the twenty-worker A-T roster.

HP_SlotRegistry = HP_SlotRegistry or {
    BASE_COUNT = 10,
    TARGET_COUNT = 20,
    FIRST_SLOT = "A",
    LAST_SLOT = "T"
}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function HP_SlotRegistry:indexToSlot(index)
    index = math.floor(tonumber(index) or 0)
    if index < 1 then return nil end

    local label = ""
    while index > 0 do
        local remainder = (index - 1) % 26
        label = string.char(string.byte("A") + remainder) .. label
        index = math.floor((index - 1) / 26)
    end
    return label
end

function HP_SlotRegistry:slotToIndex(slot, maximum)
    if slot == nil then return nil end

    local numeric = tonumber(slot)
    if numeric ~= nil then
        local index = math.floor(numeric)
        local limit = math.floor(tonumber(maximum) or self.TARGET_COUNT)
        if index >= 1 and index <= limit then return index end
        return nil
    end

    local text = string.upper(trim(slot))
    text = text:gsub("^SLOT:%s*", "")
    text = text:gsub("^HELPER:%s*", "")

    local canonical = text:match("^HELPER0*(%d+)$")
    if canonical ~= nil then
        local index = tonumber(canonical)
        local limit = math.floor(tonumber(maximum) or self.TARGET_COUNT)
        if index ~= nil and index >= 1 and index <= limit then return index end
        return nil
    end

    local helperLabel = text:match("^HELPER%s+([A-Z]+)$")
    if helperLabel ~= nil then text = helperLabel end

    if text == "" or text:match("^[A-Z]+$") == nil then return nil end

    local index = 0
    for i = 1, #text do
        index = index * 26 + (string.byte(text, i) - string.byte("A") + 1)
    end

    local limit = math.floor(tonumber(maximum) or self.TARGET_COUNT)
    if index < 1 or index > limit then return nil end
    return index
end

function HP_SlotRegistry:normalise(slot, maximum)
    local index = self:slotToIndex(slot, maximum)
    if index == nil then return nil, nil, nil end
    return self:indexToSlot(index), index, self:canonicalId(index)
end

function HP_SlotRegistry:canonicalId(indexOrSlot)
    local index = tonumber(indexOrSlot)
    if index == nil then index = self:slotToIndex(indexOrSlot, self.TARGET_COUNT) end
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > self.TARGET_COUNT then return nil end
    return string.format("helper%02d", index)
end

function HP_SlotRegistry:legacyIdentityId(indexOrSlot)
    local slot = self:normalise(indexOrSlot, self.TARGET_COUNT)
    if slot == nil then return nil end
    return "slot:" .. slot
end

function HP_SlotRegistry:getIdentityAliases(indexOrSlot)
    local slot, index, canonicalId = self:normalise(indexOrSlot, self.TARGET_COUNT)
    if slot == nil then return {} end
    return {
        "slot:" .. slot,
        canonicalId,
        "helper:" .. canonicalId,
        tostring(index)
    }
end

function HP_SlotRegistry:getSlotForHelper(helper, fallbackIndex)
    if helper ~= nil then
        local explicit = helper.hpSlotLabel or helper.hpSlot or helper.name
        local slot = self:normalise(explicit, self.TARGET_COUNT)
        if slot ~= nil then return slot end

        local helperIndex = tonumber(helper.index)
        if helperIndex ~= nil then
            slot = self:normalise(helperIndex, self.TARGET_COUNT)
            if slot ~= nil then return slot end
        end
    end

    return self:normalise(fallbackIndex, self.TARGET_COUNT)
end

function HP_SlotRegistry:getManagerCount()
    if g_helperManager == nil then return 0 end
    if g_helperManager.getNumOfHelpers ~= nil then
        local ok, count = pcall(g_helperManager.getNumOfHelpers, g_helperManager)
        if ok and tonumber(count) ~= nil then return math.floor(tonumber(count)) end
    end
    return math.floor(tonumber(g_helperManager.numHelpers) or 0)
end

function HP_SlotRegistry:getManagedCount(profileCount)
    local profileTotal = math.floor(tonumber(profileCount) or 0)
    local managerTotal = self:getManagerCount()

    -- profileCount may represent the filtered ON-roster list. Never let that
    -- shrink the permanent A-T identity range used by integrations such as
    -- HelperPayroll; use the larger permanent manager/profile count instead.
    local count = math.max(profileTotal, managerTotal)
    return math.max(0, math.min(count, self.TARGET_COUNT))
end

function HP_SlotRegistry:getSlots(count)
    count = math.max(0, math.min(math.floor(tonumber(count) or self.TARGET_COUNT), self.TARGET_COUNT))
    local slots = {}
    for index = 1, count do slots[index] = self:indexToSlot(index) end
    return slots
end

-- Load the per-save roster-state service before any operational UI or helper
-- selection code asks whether a permanent A-T identity is ON or OFF roster.
if HP_RosterState == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_RosterState.lua")
end

-- Install the shared management controller early. It waits until the three
-- GUI screen classes are available before applying its lightweight wrappers.
if HP_TabbedManagement == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_TabbedManagement.lua")
end

-- World-worker services are sourced from the stable slot registry so the
-- permanent A-T identity model is available before they load.
if HP_WorldState == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_WorldState.lua")
end
if HP_WorldWorkerManager == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_WorldWorkerManager.lua")
end
if HP_WorldWorkerPlayerAccess == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_WorldWorkerPlayerAccess.lua")
end
if HP_WorldWorkerScreen == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_WorldWorkerScreen.lua")
end
if HP_WorldPresence == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_WorldPresence.lua")
end
if HP_WorldWorkerInput == nil and source ~= nil then
    source((g_currentModDirectory or "") .. "scripts/HP_WorldWorkerInput.lua")
end
