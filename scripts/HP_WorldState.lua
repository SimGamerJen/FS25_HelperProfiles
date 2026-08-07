-- HP_WorldState.lua (FS25_HelperProfiles)
-- Per-save placement state for standalone HelperProfiles world workers.

if HP_WorldState ~= nil then return end

HP_WorldState = {
    initialized = false,
    savegameName = nil,
    savegameDir = nil,
    stateFile = nil,
    placementsByCanonicalId = {},
    version = "1.0"
}

local LOG = "[FS25_HelperProfiles/WorldState] "

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

local function readXmlNumber(xmlFile, key, defaultValue)
    if getXMLFloat ~= nil then
        local value = getXMLFloat(xmlFile, key)
        if value ~= nil then return tonumber(value) or defaultValue end
    end
    local text = getXMLString(xmlFile, key)
    return tonumber(text) or defaultValue
end

local function writeXmlNumber(xmlFile, key, value)
    if setXMLFloat ~= nil then
        setXMLFloat(xmlFile, key, tonumber(value) or 0)
    else
        setXMLString(xmlFile, key, tostring(tonumber(value) or 0))
    end
end

function HP_WorldState:init()
    if self.initialized then return end
    self.initialized = true

    local profilePath = getUserProfileAppPath()
    local modSettingsDir = profilePath .. "modSettings/FS25_HelperProfiles/"
    local savesDir = modSettingsDir .. "saves/"
    self.savegameName = detectSavegameName()
    self.savegameDir = savesDir .. tostring(self.savegameName) .. "/"
    self.stateFile = self.savegameDir .. "worldWorkers.xml"

    ensureFolder(modSettingsDir)
    ensureFolder(savesDir)
    ensureFolder(self.savegameDir)
    self:load()
end

function HP_WorldState:getCanonicalId(indexOrSlot)
    if HP_SlotRegistry ~= nil then
        local index = HP_SlotRegistry:slotToIndex(indexOrSlot, HP_SlotRegistry.TARGET_COUNT)
        if index ~= nil then return HP_SlotRegistry:canonicalId(index), index end
    end

    local numeric = math.floor(tonumber(indexOrSlot) or 0)
    if numeric >= 1 and numeric <= 20 then
        return string.format("helper%02d", numeric), numeric
    end
    return nil, nil
end

function HP_WorldState:getPlacement(indexOrSlot)
    if not self.initialized then self:init() end
    local canonicalId = self:getCanonicalId(indexOrSlot)
    if canonicalId == nil then return nil end
    local placement = self.placementsByCanonicalId[canonicalId]
    if placement == nil then return nil end
    return {
        id = canonicalId,
        x = placement.x,
        y = placement.y,
        z = placement.z,
        yaw = placement.yaw or 0
    }
end

function HP_WorldState:getAllPlacements()
    if not self.initialized then self:init() end
    local result = {}
    for canonicalId, placement in pairs(self.placementsByCanonicalId or {}) do
        result[canonicalId] = {
            id = canonicalId,
            x = placement.x,
            y = placement.y,
            z = placement.z,
            yaw = placement.yaw or 0
        }
    end
    return result
end

function HP_WorldState:setPlacement(indexOrSlot, x, y, z, yaw)
    if not self.initialized then self:init() end
    local canonicalId, index = self:getCanonicalId(indexOrSlot)
    if canonicalId == nil then return false, "invalid-helper" end

    x, y, z, yaw = tonumber(x), tonumber(y), tonumber(z), tonumber(yaw) or 0
    if x == nil or y == nil or z == nil then return false, "invalid-position" end

    self.placementsByCanonicalId[canonicalId] = {
        id = canonicalId,
        index = index,
        x = x,
        y = y,
        z = z,
        yaw = yaw
    }
    return self:write()
end

function HP_WorldState:clearPlacement(indexOrSlot)
    if not self.initialized then self:init() end
    local canonicalId = self:getCanonicalId(indexOrSlot)
    if canonicalId == nil then return false, "invalid-helper" end
    self.placementsByCanonicalId[canonicalId] = nil
    return self:write()
end

function HP_WorldState:load()
    self.placementsByCanonicalId = {}
    if self.stateFile == nil or not fileExists(self.stateFile) then
        log("No per-save world-worker file found; no workers are placed")
        return true
    end

    local xmlFile = loadXMLFile("hpWorldStateRead", self.stateFile)
    if xmlFile == nil or xmlFile == 0 then
        log("Could not read world-worker state: %s", tostring(self.stateFile))
        return false, "unreadable"
    end

    local row = 0
    while true do
        local key = string.format("helperProfilesWorld.workers.worker(%d)", row)
        if not hasXMLProperty(xmlFile, key) then break end

        local canonicalId = getXMLString(xmlFile, key .. "#id")
        local slot = getXMLString(xmlFile, key .. "#slot")
        local resolvedId, index = self:getCanonicalId(canonicalId or slot)
        if resolvedId ~= nil then
            self.placementsByCanonicalId[resolvedId] = {
                id = resolvedId,
                index = index,
                x = readXmlNumber(xmlFile, key .. "#x", 0),
                y = readXmlNumber(xmlFile, key .. "#y", 0),
                z = readXmlNumber(xmlFile, key .. "#z", 0),
                yaw = readXmlNumber(xmlFile, key .. "#yaw", 0)
            }
        end
        row = row + 1
    end
    delete(xmlFile)

    local count = 0
    for _ in pairs(self.placementsByCanonicalId) do count = count + 1 end
    log("Loaded per-save world-worker state: savegame=%s placed=%d file=%s",
        tostring(self.savegameName), count, tostring(self.stateFile))
    return true
end

function HP_WorldState:write()
    if not self.initialized then self:init() end
    ensureFolder(self.savegameDir)

    local xmlFile = createXMLFile("hpWorldStateWrite", self.stateFile, "helperProfilesWorld")
    if xmlFile == nil or xmlFile == 0 then return false, "create-failed" end

    setXMLString(xmlFile, "helperProfilesWorld#version", tostring(self.version))
    setXMLString(xmlFile, "helperProfilesWorld#savegame", tostring(self.savegameName or "unknownSavegame"))
    setXMLString(xmlFile, "helperProfilesWorld#note", "Static HelperProfiles world placements. Runtime world presence is independent of AI helper jobs.")

    local rows = {}
    for canonicalId, placement in pairs(self.placementsByCanonicalId or {}) do
        rows[#rows + 1] = { id = canonicalId, placement = placement }
    end
    table.sort(rows, function(a, b) return tostring(a.id) < tostring(b.id) end)

    for rowIndex, row in ipairs(rows) do
        local key = string.format("helperProfilesWorld.workers.worker(%d)", rowIndex - 1)
        local index = HP_SlotRegistry ~= nil and HP_SlotRegistry:slotToIndex(row.id, HP_SlotRegistry.TARGET_COUNT)
            or row.placement.index
        local slot = HP_SlotRegistry ~= nil and HP_SlotRegistry:indexToSlot(index) or tostring(index or "")
        setXMLString(xmlFile, key .. "#id", tostring(row.id))
        setXMLString(xmlFile, key .. "#slot", tostring(slot or ""))
        writeXmlNumber(xmlFile, key .. "#x", row.placement.x)
        writeXmlNumber(xmlFile, key .. "#y", row.placement.y)
        writeXmlNumber(xmlFile, key .. "#z", row.placement.z)
        writeXmlNumber(xmlFile, key .. "#yaw", row.placement.yaw or 0)
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
    return true
end

function HP_WorldState:loadMap()
    self.initialized = false
    self:init()
end

function HP_WorldState:deleteMap()
    self.initialized = false
    self.savegameName = nil
    self.savegameDir = nil
    self.stateFile = nil
    self.placementsByCanonicalId = {}
end

addModEventListener(HP_WorldState)
