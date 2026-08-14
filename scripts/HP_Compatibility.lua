-- HP_Compatibility.lua (FS25_HelperProfiles)
-- Central runtime guard for helper-roster mods that cannot safely coexist.

HP_Compatibility = HP_Compatibility or {
    checked = false,
    blocked = false,
    conflictMod = nil,
    conflictSource = nil,
    warningLogged = false,
    checkAccumulatorMs = 0,
    checkIntervalMs = 250,
    startupCheckWindowMs = 5000,
    startupCheckRemainingMs = 0
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
    self.startupCheckRemainingMs = 0

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
    -- This accessor is used by render, input and helper-selection hot paths.
    -- It must remain a cached state lookup: performing a full mod-manager scan
    -- here caused the 2.1.0.0 alpha to scan every loaded mod on every frame.
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
    self.startupCheckRemainingMs = tonumber(self.startupCheckWindowMs) or 5000

    local blocked = self:detect()
    if not blocked then
        print(LOG .. "Guard initialized: Hired Helper Tool not active at HelperProfiles loadMap; checking late startup for " .. tostring(self.startupCheckRemainingMs) .. " ms.")
    end
end

function HP_Compatibility:update(dt)
    if self.blocked == true then return end

    local remaining = tonumber(self.startupCheckRemainingMs) or 0
    if remaining <= 0 then return end

    local elapsed = tonumber(dt) or 0
    remaining = math.max(0, remaining - elapsed)
    self.startupCheckRemainingMs = remaining
    self.checkAccumulatorMs = (tonumber(self.checkAccumulatorMs) or 0) + elapsed

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
    self.startupCheckRemainingMs = 0
end

addModEventListener(HP_Compatibility)

----------------------------------------------------------------------
-- AutoDrive helper continuity compatibility
----------------------------------------------------------------------
-- AutoDrive can synchronously stop/restart a running mode. Its stop path releases
-- and clears the GIANTS helper, then startAutoDrive() asks getRandomHelper() for a
-- helper again. Preserve the vehicle's existing helper identity across that
-- restart window without changing normal HelperProfiles selection behaviour.

HP_AutoDriveContinuity = HP_AutoDriveContinuity or {
    _helperHookInstalled = false,
    _activityHookInstalled = false,
    _baseGetRandomHelper = nil,
    _baseIsHelperActive = nil,
    _reservations = setmetatable({}, {__mode = "k"})
}

local AD_LOG = "[FS25_HelperProfiles/AutoDrive] "

local function adLog(message, ...)
    print(AD_LOG .. string.format(tostring(message), ...))
end

local function getVehicleLabel(vehicle)
    if vehicle ~= nil and vehicle.getName ~= nil then
        local ok, value = pcall(vehicle.getName, vehicle)
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    return tostring(vehicle or "unknown-vehicle")
end

local function getAutoDriveState(vehicle)
    if vehicle == nil or vehicle.ad == nil or vehicle.ad.stateModule == nil then
        return false, nil
    end

    local stateModule = vehicle.ad.stateModule
    local active = false
    if stateModule.isActive ~= nil then
        local ok, value = pcall(stateModule.isActive, stateModule)
        active = ok and value == true
    end

    local helperIndex = 0
    if stateModule.getCurrentHelperIndex ~= nil then
        local ok, value = pcall(stateModule.getCurrentHelperIndex, stateModule)
        if ok then helperIndex = tonumber(value) or 0 end
    end

    return active, helperIndex
end

local function isEngineAvailable(helper)
    if helper == nil or helper.inUse == true or g_helperManager == nil then return false end
    for _, candidate in ipairs(g_helperManager.availableHelpers or {}) do
        if candidate == helper then return true end
    end
    return false
end

function HP_AutoDriveContinuity:isEnabled()
    return rawget(_G, "AutoDrive") ~= nil
end

function HP_AutoDriveContinuity:isReserved(helper)
    if helper == nil then return false end
    for _, reservation in pairs(self._reservations or {}) do
        if reservation ~= nil and reservation.helper == helper then
            return true
        end
    end
    return false
end

function HP_AutoDriveContinuity:_remember(vehicle, helper, helperIndex)
    if vehicle == nil or helper == nil then return end

    local existing = self._reservations[vehicle]
    if existing ~= nil and existing.helper == helper then
        existing.helperIndex = tonumber(helperIndex) or tonumber(helper.index) or existing.helperIndex or 0
        return
    end

    self._reservations[vehicle] = {
        helper = helper,
        helperIndex = tonumber(helperIndex) or tonumber(helper.index) or 0
    }

    adLog(
        "Driver reserved: vehicle='%s' helper='%s' index=%d",
        getVehicleLabel(vehicle),
        tostring(helper.name or "?"),
        tonumber(helperIndex) or tonumber(helper.index) or 0
    )
end

function HP_AutoDriveContinuity:_release(vehicle, reason)
    local reservation = self._reservations[vehicle]
    if reservation == nil then return end

    adLog(
        "Driver reservation cleared: vehicle='%s' helper='%s' reason=%s",
        getVehicleLabel(vehicle),
        tostring(reservation.helper and reservation.helper.name or "?"),
        tostring(reason or "unknown")
    )
    self._reservations[vehicle] = nil
end

function HP_AutoDriveContinuity:_findReacquireCandidate()
    if not self:isEnabled() or g_currentMission == nil then return nil, nil end

    local matchedVehicle = nil
    local matchedHelper = nil
    local matches = 0

    for _, vehicle in pairs(g_currentMission.vehicles or {}) do
        local reservation = self._reservations[vehicle]
        if reservation ~= nil and reservation.helper ~= nil then
            local active, helperIndex = getAutoDriveState(vehicle)
            local adHelper = vehicle.ad ~= nil and vehicle.ad.currentHelper or nil

            -- AutoDrive:startAutoDrive sets active=true before calling
            -- g_helperManager:getRandomHelper(). During a restart this creates a
            -- distinctive active + no-current-helper window for the calling vehicle.
            if active and (adHelper == nil or (tonumber(helperIndex) or 0) <= 0) and isEngineAvailable(reservation.helper) then
                matches = matches + 1
                matchedVehicle = vehicle
                matchedHelper = reservation.helper
            end
        end
    end

    -- getRandomHelper has no vehicle argument, so only override when exactly one
    -- AutoDrive vehicle has an unambiguous reserved-helper reacquisition window.
    if matches == 1 then
        return matchedHelper, matchedVehicle
    end

    if matches > 1 then
        adLog("Continuity skipped: %d AutoDrive vehicles are simultaneously awaiting reserved helpers", matches)
    end
    return nil, nil
end

function HP_AutoDriveContinuity:_installActivityHook()
    if self._activityHookInstalled then return true end
    if HelperProfiles == nil or HelperProfiles.isHelperActive == nil then return false end

    self._baseIsHelperActive = HelperProfiles.isHelperActive
    HelperProfiles.isHelperActive = function(helperProfilesSelf, helper)
        if HP_AutoDriveContinuity ~= nil and HP_AutoDriveContinuity:isReserved(helper) then
            return true
        end
        return HP_AutoDriveContinuity._baseIsHelperActive(helperProfilesSelf, helper)
    end

    self._activityHookInstalled = true
    adLog("Installed reserved-helper activity bridge")
    return true
end

function HP_AutoDriveContinuity:_installHelperHook()
    if self._helperHookInstalled then return true end
    if not self:isEnabled() then return false end
    if HelperProfiles == nil or HelperProfiles._hooksDone ~= true then return false end
    if HelperManager == nil or HelperManager.getRandomHelper == nil then return false end

    self._baseGetRandomHelper = HelperManager.getRandomHelper
    HelperManager.getRandomHelper = function(manager, ...)
        local helper, vehicle = HP_AutoDriveContinuity:_findReacquireCandidate()
        if helper ~= nil then
            adLog(
                "Driver continuity reacquire: vehicle='%s' helper='%s' index=%d",
                getVehicleLabel(vehicle),
                tostring(helper.name or "?"),
                tonumber(helper.index) or 0
            )
            return helper
        end
        return HP_AutoDriveContinuity._baseGetRandomHelper(manager, ...)
    end

    self._helperHookInstalled = true
    adLog("Installed AutoDrive getRandomHelper continuity hook")
    return true
end

function HP_AutoDriveContinuity:loadMap()
    self._reservations = setmetatable({}, {__mode = "k"})
end

function HP_AutoDriveContinuity:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then return end

    self:_installActivityHook()
    self:_installHelperHook()

    if not self:isEnabled() or g_currentMission == nil then return end

    for _, vehicle in pairs(g_currentMission.vehicles or {}) do
        if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil then
            local active, helperIndex = getAutoDriveState(vehicle)
            local currentHelper = vehicle.ad.currentHelper

            if active and currentHelper ~= nil then
                self:_remember(vehicle, currentHelper, helperIndex)
            elseif not active and self._reservations[vehicle] ~= nil then
                -- AutoDrive's RestartADTask performs stopAutoDrive() and mode:start()
                -- synchronously, so an internal restart does not reach this update in
                -- the inactive state. A vehicle observed inactive here is a genuine stop.
                self:_release(vehicle, "autodrive-stopped")
            end
        end
    end
end

function HP_AutoDriveContinuity:deleteMap()
    self._reservations = setmetatable({}, {__mode = "k"})
end

addModEventListener(HP_AutoDriveContinuity)
