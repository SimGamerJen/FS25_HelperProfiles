-- HP_RosterState.lua (FS25_HelperProfiles)
-- Per-save availability state for the permanent A-T helper identity pool.

if HP_RosterState ~= nil then return end

HP_RosterState = {
    initialized = false,
    savegameName = nil,
    savegameDir = nil,
    stateFile = nil,
    enabledByCanonicalId = {},
    version = "1.0"
}

local LOG = "[FS25_HelperProfiles/RosterState] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function normalizePathSlashes(path)
    if path == nil then return nil end
    return tostring(path):gsub("\\", "/")
end

local function getPathBaseName(path)
    path = normalizePathSlashes(path or "") or ""
    path = path:gsub("/+$", "")
    local base = path:match("([^/]+)$")
    return base ~= nil and base ~= "" and base or nil
end

local function detectSavegameName()
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if missionInfo ~= nil then
        local candidates = {
            missionInfo.savegameDirectory,
            missionInfo.savegameDir,
            missionInfo.savegamePath,
            missionInfo.savegameXMLFilename,
            missionInfo.savegameSavePath
        }
        for _, value in ipairs(candidates) do
            if value ~= nil and tostring(value) ~= "" then
                local path = normalizePathSlashes(value)
                local match = path ~= nil and path:match("(savegame%d+)") or nil
                if match ~= nil and match ~= "" then return match end
                local base = getPathBaseName(path)
                if base ~= nil then return base end
            end
        end

        local index = missionInfo.savegameIndex or missionInfo.savegameNumber
            or missionInfo.saveGameIndex or missionInfo.saveGameNumber
        if tonumber(index) ~= nil then
            return "savegame" .. tostring(math.floor(tonumber(index)))
        end
    end
    return "unknownSavegame"
end

local function ensureFolder(path)
    if path ~= nil and path ~= "" and not fileExists(path) then
        createFolder(path)
    end
end

local function readXmlBool(xmlFile, key, defaultValue)
    if getXMLBool ~= nil then
        local value = getXMLBool(xmlFile, key)
        if value ~= nil then return value == true end
    end
    local text = getXMLString(xmlFile, key)
    if text ~= nil then
        text = string.lower(tostring(text))
        if text == "true" or text == "1" or text == "yes" or text == "on" then return true end
        if text == "false" or text == "0" or text == "no" or text == "off" then return false end
    end
    return defaultValue == true
end

function HP_RosterState:ensureDefaults()
    self.enabledByCanonicalId = self.enabledByCanonicalId or {}
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    for index = 1, target do
        local canonicalId = HP_SlotRegistry ~= nil and HP_SlotRegistry:canonicalId(index)
            or string.format("helper%02d", index)
        if self.enabledByCanonicalId[canonicalId] == nil then
            self.enabledByCanonicalId[canonicalId] = true
        end
    end
end

function HP_RosterState:init()
    if self.initialized then return end
    self.initialized = true

    local profilePath = getUserProfileAppPath()
    local modSettingsDir = profilePath .. "modSettings/FS25_HelperProfiles/"
    local savesDir = modSettingsDir .. "saves/"
    self.savegameName = detectSavegameName()
    self.savegameDir = savesDir .. tostring(self.savegameName) .. "/"
    self.stateFile = self.savegameDir .. "roster.xml"

    ensureFolder(modSettingsDir)
    ensureFolder(savesDir)
    ensureFolder(self.savegameDir)

    self:load()
end

function HP_RosterState:resolveIndex(indexOrSlotOrHelper, fallbackIndex)
    if HP_SlotRegistry == nil then return tonumber(fallbackIndex) end

    if type(indexOrSlotOrHelper) == "table" then
        local slot = HP_SlotRegistry:getSlotForHelper(indexOrSlotOrHelper, fallbackIndex)
        return HP_SlotRegistry:slotToIndex(slot, HP_SlotRegistry.TARGET_COUNT)
    end

    return HP_SlotRegistry:slotToIndex(indexOrSlotOrHelper, HP_SlotRegistry.TARGET_COUNT)
        or HP_SlotRegistry:slotToIndex(fallbackIndex, HP_SlotRegistry.TARGET_COUNT)
end

function HP_RosterState:getCanonicalId(indexOrSlotOrHelper, fallbackIndex)
    local index = self:resolveIndex(indexOrSlotOrHelper, fallbackIndex)
    if index == nil then return nil end
    return HP_SlotRegistry ~= nil and HP_SlotRegistry:canonicalId(index)
        or string.format("helper%02d", index)
end

function HP_RosterState:isEnabled(indexOrSlotOrHelper, fallbackIndex)
    self:ensureDefaults()
    local canonicalId = self:getCanonicalId(indexOrSlotOrHelper, fallbackIndex)
    if canonicalId == nil then return true end
    return self.enabledByCanonicalId[canonicalId] ~= false
end

function HP_RosterState:getSnapshot()
    self:ensureDefaults()
    local snapshot = {}
    for canonicalId, enabled in pairs(self.enabledByCanonicalId) do
        snapshot[canonicalId] = enabled ~= false
    end
    return snapshot
end

function HP_RosterState:getEnabledCount()
    self:ensureDefaults()
    local count = 0
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    for index = 1, target do
        if self:isEnabled(index) then count = count + 1 end
    end
    return count
end

function HP_RosterState:getDisabledCount()
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    return math.max(0, target - self:getEnabledCount())
end

function HP_RosterState:load()
    self.enabledByCanonicalId = {}
    self:ensureDefaults()

    if self.stateFile == nil or not fileExists(self.stateFile) then
        log("No per-save roster file found; all %d slots default to ON", self:getEnabledCount())
        return true
    end

    local xmlFile = loadXMLFile("hpRosterStateRead", self.stateFile)
    if xmlFile == nil or xmlFile == 0 then
        log("Could not read roster state; all slots remain ON: %s", tostring(self.stateFile))
        return false, "unreadable"
    end

    local index = 0
    while true do
        local key = string.format("helperProfilesRoster.slots.slot(%d)", index)
        if not hasXMLProperty(xmlFile, key) then break end

        local canonicalId = getXMLString(xmlFile, key .. "#id")
        local slot = getXMLString(xmlFile, key .. "#slot")
        local normalizedIndex = self:resolveIndex(canonicalId or slot)
        if normalizedIndex ~= nil then
            local resolvedCanonicalId = HP_SlotRegistry:canonicalId(normalizedIndex)
            self.enabledByCanonicalId[resolvedCanonicalId] = readXmlBool(xmlFile, key .. "#enabled", true)
        end
        index = index + 1
    end
    delete(xmlFile)

    self:ensureDefaults()
    if self:getEnabledCount() < 1 then
        self.enabledByCanonicalId = {}
        self:ensureDefaults()
        log("Roster file disabled every slot; recovered by enabling all slots")
    end

    log("Loaded per-save roster: savegame=%s enabled=%d disabled=%d file=%s",
        tostring(self.savegameName), self:getEnabledCount(), self:getDisabledCount(), tostring(self.stateFile))
    return true
end

function HP_RosterState:write()
    if not self.initialized then self:init() end
    self:ensureDefaults()
    ensureFolder(self.savegameDir)

    local xmlFile = createXMLFile("hpRosterStateWrite", self.stateFile, "helperProfilesRoster")
    if xmlFile == nil or xmlFile == 0 then
        return false, "create-failed"
    end

    setXMLString(xmlFile, "helperProfilesRoster#version", tostring(self.version))
    setXMLString(xmlFile, "helperProfilesRoster#savegame", tostring(self.savegameName or "unknownSavegame"))
    setXMLString(xmlFile, "helperProfilesRoster#note", "Permanent A-T identities remain stored. enabled controls whether a worker appears in operational HelperProfiles selection and overlays.")

    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    for index = 1, target do
        local key = string.format("helperProfilesRoster.slots.slot(%d)", index - 1)
        local slot = HP_SlotRegistry:indexToSlot(index)
        local canonicalId = HP_SlotRegistry:canonicalId(index)
        setXMLString(xmlFile, key .. "#id", canonicalId)
        setXMLString(xmlFile, key .. "#slot", slot)
        if setXMLBool ~= nil then
            setXMLBool(xmlFile, key .. "#enabled", self.enabledByCanonicalId[canonicalId] ~= false)
        else
            setXMLString(xmlFile, key .. "#enabled", tostring(self.enabledByCanonicalId[canonicalId] ~= false))
        end
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
    return true
end

local function snapshotValue(snapshot, index)
    local slot = HP_SlotRegistry:indexToSlot(index)
    local canonicalId = HP_SlotRegistry:canonicalId(index)
    local value = nil
    if snapshot ~= nil then value = snapshot[canonicalId] end
    if value == nil and snapshot ~= nil then value = snapshot[slot] end
    if value == nil and snapshot ~= nil then value = snapshot[index] end
    return value ~= false
end

function HP_RosterState:validateSnapshot(snapshot)
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    local enabledCount = 0
    for index = 1, target do
        if snapshotValue(snapshot, index) then enabledCount = enabledCount + 1 end
    end
    if enabledCount < 1 then return false, "at-least-one-required" end

    local allProfiles = HelperProfiles ~= nil and HelperProfiles.getAllProfiles ~= nil
        and HelperProfiles:getAllProfiles() or {}
    for stableIndex, helper in ipairs(allProfiles) do
        if self:isEnabled(stableIndex) and not snapshotValue(snapshot, stableIndex) then
            local active = HelperProfiles ~= nil and HelperProfiles.isHelperActive ~= nil
                and HelperProfiles:isHelperActive(helper) or helper.inUse == true
            if active then
                return false, "active-slot", HP_SlotRegistry:indexToSlot(stableIndex)
            end
        end
    end

    return true, nil, enabledCount
end

function HP_RosterState:replaceSnapshot(snapshot)
    local ok, err, detail = self:validateSnapshot(snapshot)
    if not ok then return false, err, detail end

    local replacement = {}
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    for index = 1, target do
        replacement[HP_SlotRegistry:canonicalId(index)] = snapshotValue(snapshot, index)
    end

    local previous = self.enabledByCanonicalId
    self.enabledByCanonicalId = replacement
    local wrote, writeErr = self:write()
    if not wrote then
        self.enabledByCanonicalId = previous
        return false, writeErr or "write-failed"
    end

    if HelperProfiles ~= nil and HelperProfiles.onRosterAvailabilityChanged ~= nil then
        pcall(HelperProfiles.onRosterAvailabilityChanged, HelperProfiles)
    end

    log("Saved per-save roster: enabled=%d disabled=%d", self:getEnabledCount(), self:getDisabledCount())
    return true
end

function HP_RosterState:enableAll()
    local snapshot = {}
    local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
    for index = 1, target do snapshot[HP_SlotRegistry:canonicalId(index)] = true end
    return self:replaceSnapshot(snapshot)
end

function HP_RosterState:loadMap()
    self.initialized = false
    self:init()
end

function HP_RosterState:deleteMap()
    self.initialized = false
    self.savegameName = nil
    self.savegameDir = nil
    self.stateFile = nil
    self.enabledByCanonicalId = {}
end

addModEventListener(HP_RosterState)
