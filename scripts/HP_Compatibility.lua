-- HP_Compatibility.lua (FS25_HelperProfiles)
-- Central runtime guard for helper-roster mods that cannot safely coexist.

HP_Compatibility = HP_Compatibility or {
    checked = false,
    blocked = false,
    conflictMod = nil,
    conflictSource = nil,
    warningLogged = false,
    checkAccumulatorMs = 0,
    checkIntervalMs = 250
}

local LOG = "[FS25_HelperProfiles/Compatibility] "
local CONFLICT_NAMES = {"FS25_HiredHelperTool", "HiredHelperTool", "HireHelperTool"}
local CONFLICT_TOKENS = {"hiredhelpertool", "hirehelpertool"}
local CONFLICT_GLOBALS = {"HiredHelperTool", "HiredHelperToolGUI", "g_hiredHelperTool"}

local function normaliseToken(value)
    return string.lower(tostring(value or "")):gsub("[^%w]", "")
end

local function looksLikeConflict(value)
    local token = normaliseToken(value)
    if token == "" then return false end
    for _, wanted in ipairs(CONFLICT_TOKENS) do
        if string.find(token, wanted, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function isTruthy(value)
    return value ~= nil and value ~= false
end

local function getModLabel(mod, fallback)
    if type(mod) ~= "table" then return tostring(fallback or "unknown") end
    return tostring(mod.modName or mod.name or mod.title or mod.filename or mod.fileName or fallback or "unknown")
end

local function modLooksActive(mod)
    if type(mod) ~= "table" then return false end

    local sawState = false
    for _, field in ipairs({"isLoaded", "isActive", "isSelected", "loaded", "active", "selected"}) do
        if mod[field] ~= nil then
            sawState = true
            if mod[field] == true then return true end
        end
    end

    -- A mod-manager record with no explicit state is only metadata for an installed
    -- mod and must not block HelperProfiles by itself.
    return not sawState and false
end

local function scanLoadedModTable()
    local loaded = rawget(_G, "g_modIsLoaded")
    if type(loaded) ~= "table" then return nil end

    -- Prefer exact known names. GIANTS treats any truthy entry as loaded; the value
    -- is not guaranteed to be the literal boolean true.
    for _, name in ipairs(CONFLICT_NAMES) do
        if isTruthy(loaded[name]) then
            return name
        end
    end

    for key, value in pairs(loaded) do
        if isTruthy(value) and looksLikeConflict(key) then
            return tostring(key)
        end
    end
    return nil
end

local function scanRuntimeGlobals()
    for _, name in ipairs(CONFLICT_GLOBALS) do
        if rawget(_G, name) ~= nil then return name end
    end
    return nil
end

local function scanModCollection(collection)
    if type(collection) ~= "table" then return nil end
    for key, mod in pairs(collection) do
        local label = getModLabel(mod, key)
        if (looksLikeConflict(key) or looksLikeConflict(label)) and modLooksActive(mod) then
            return label
        end
    end
    return nil
end

local function scanModManager()
    if g_modManager == nil then return nil end

    if type(g_modManager.getModByName) == "function" then
        for _, name in ipairs(CONFLICT_NAMES) do
            local ok, mod = pcall(g_modManager.getModByName, g_modManager, name)
            if ok and type(mod) == "table" and modLooksActive(mod) then
                return getModLabel(mod, name)
            end
        end
    end

    for _, field in ipairs({"loadedMods", "activeMods", "modsByName", "nameToMod", "mods"}) do
        local found = scanModCollection(g_modManager[field])
        if found ~= nil then return found end
    end
    return nil
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

local function getManagerHelperCount()
    local manager = rawget(_G, "g_helperManager")
    if manager == nil then return 0 end

    local count = 0
    if type(manager.getNumOfHelpers) == "function" then
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

local function removeRegisteredPlayerActions()
    if HelperProfiles == nil or g_inputBinding == nil or g_inputBinding.removeActionEvent == nil then return end
    for _, field in ipairs({
        "_playerCycleId",
        "_playerToggleId",
        "_playerModeId",
        "_playerAppearanceMenuId"
    }) do
        local id = HelperProfiles[field]
        if id ~= nil then
            pcall(g_inputBinding.removeActionEvent, g_inputBinding, id)
            HelperProfiles[field] = nil
        end
    end
end

function HP_Compatibility:getLiveHelperCount()
    return getManagerHelperCount()
end

function HP_Compatibility:setBlocked(conflict, source)
    if self.blocked == true then return true end

    self.checked = true
    self.blocked = true
    self.conflictMod = tostring(conflict or "unknown")
    self.conflictSource = tostring(source or "unknown")

    if HP_UI ~= nil then
        HP_UI.visible = false
        HP_UI.flashText = nil
        HP_UI.flashTime = 0
    end
    if HelperProfiles ~= nil then
        HelperProfiles.selectedHelperRef = nil
        HelperProfiles.selectedIdx = 1
    end

    removeRegisteredPlayerActions()

    if HP_IntegrationAPI ~= nil and HP_IntegrationAPI.unpublish ~= nil then
        pcall(HP_IntegrationAPI.unpublish, HP_IntegrationAPI)
    end

    if not self.warningLogged then
        self.warningLogged = true
        print(LOG .. "HelperProfiles disabled for this session: incompatible helper-roster owner detected (" .. self.conflictMod .. ", source=" .. self.conflictSource .. "). Disable either HelperProfiles or Hired Helper Tool and reload the save.")
    end
    return true
end

function HP_Compatibility:detect()
    if self.blocked == true then return true end
    self.checked = true

    local conflict = scanLoadedModTable() or scanRuntimeGlobals() or scanModManager()
    if conflict ~= nil then
        return self:setBlocked(conflict, "loaded-mod")
    end

    local target = HP_SlotRegistry ~= nil and tonumber(HP_SlotRegistry.TARGET_COUNT) or 20
    local helperCount = getManagerHelperCount()
    if helperCount > target then
        return self:setBlocked("external-helper-roster-" .. tostring(helperCount), "helper-count")
    end

    return false
end

function HP_Compatibility:isBlocked()
    if self.blocked ~= true then
        self:detect()
    end
    return self.blocked == true
end

function HP_Compatibility:getReason()
    if not self:isBlocked() then return nil end
    return "incompatible-helper-roster-mod:" .. tostring(self.conflictMod or "unknown")
end

function HP_Compatibility:loadMap()
    self.checked = false
    self.blocked = false
    self.conflictMod = nil
    self.conflictSource = nil
    self.warningLogged = false
    self.checkAccumulatorMs = 0

    local blocked = self:detect()
    if not blocked then
        print(LOG .. "Guard initialized: Hired Helper Tool not active at HelperProfiles loadMap; continuing startup checks.")
    end
end

function HP_Compatibility:update(dt)
    if self.blocked == true then return end
    self.checkAccumulatorMs = (tonumber(self.checkAccumulatorMs) or 0) + (tonumber(dt) or 0)
    if self.checkAccumulatorMs >= (tonumber(self.checkIntervalMs) or 250) then
        self.checkAccumulatorMs = 0
        self:detect()
    end
end

function HP_Compatibility:deleteMap()
    self.checked = false
    self.blocked = false
    self.conflictMod = nil
    self.conflictSource = nil
    self.warningLogged = false
    self.checkAccumulatorMs = 0
end

addModEventListener(HP_Compatibility)
