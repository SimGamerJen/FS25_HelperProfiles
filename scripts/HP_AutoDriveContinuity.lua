-- HP_AutoDriveContinuity.lua (FS25_HelperProfiles)
-- Event-driven AutoDrive helper continuity bridge.
-- Loaded after HelperProfiles.lua so its hooks wrap the final HelperProfiles picker.

print("[FS25_HelperProfiles/AutoDriveV2] Source loaded (runtime-manager hook build)")

-- The first continuity prototype lives in HP_Compatibility.lua. Disable its polling
-- update path for this test build so only the event-driven bridge owns continuity.
if HP_AutoDriveContinuity ~= nil then
    HP_AutoDriveContinuity.update = function() end
end

HP_AutoDriveContinuityV2 = HP_AutoDriveContinuityV2 or {
    installed = false,
    leaseMs = 3000,
    reservations = setmetatable({}, {__mode = "k"}),
    originalGetRandomHelper = nil,
    originalReleaseHelper = nil,
    originalIsHelperActive = nil,
    runtimeManager = nil,
    _lastWaitReason = nil,
    _lastWaitLogMs = -100000
}

local LOG = "[FS25_HelperProfiles/AutoDriveV2] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function nowMs()
    return tonumber(g_time) or 0
end

local function vehicleName(vehicle)
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
        return false, 0
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

function HP_AutoDriveContinuityV2:_logInstallWait(reason)
    local now = nowMs()
    reason = tostring(reason or "unknown")
    if self._lastWaitReason ~= reason or (now - (tonumber(self._lastWaitLogMs) or 0)) >= 1000 then
        self._lastWaitReason = reason
        self._lastWaitLogMs = now
        log("Waiting to install: %s", reason)
    end
end

function HP_AutoDriveContinuityV2:_pruneExpired()
    local now = nowMs()
    for vehicle, reservation in pairs(self.reservations or {}) do
        if reservation == nil or now > (tonumber(reservation.expiresAt) or 0) then
            if reservation ~= nil then
                log(
                    "Driver reservation expired: vehicle='%s' helper='%s'",
                    vehicleName(vehicle),
                    tostring(reservation.helper and reservation.helper.name or "?")
                )
            end
            self.reservations[vehicle] = nil
        end
    end
end

function HP_AutoDriveContinuityV2:isReserved(helper)
    if helper == nil then return false end
    self:_pruneExpired()
    for _, reservation in pairs(self.reservations or {}) do
        if reservation ~= nil and reservation.helper == helper then
            return true
        end
    end
    return false
end

function HP_AutoDriveContinuityV2:_findOwningVehicle(helper)
    if helper == nil or g_currentMission == nil then return nil end

    local match = nil
    for _, vehicle in pairs(g_currentMission.vehicles or {}) do
        if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.currentHelper == helper then
            if match ~= nil and match ~= vehicle then
                log("Release capture skipped: helper='%s' is referenced by multiple AutoDrive vehicles", tostring(helper.name or "?"))
                return nil
            end
            match = vehicle
        end
    end
    return match
end

function HP_AutoDriveContinuityV2:captureRelease(helper)
    if helper == nil then return false end

    local vehicle = self:_findOwningVehicle(helper)
    if vehicle == nil then return false end

    local active, helperIndex = getAutoDriveState(vehicle)
    local expiresAt = nowMs() + (tonumber(self.leaseMs) or 3000)
    self.reservations[vehicle] = {
        helper = helper,
        helperIndex = tonumber(helper.index) or tonumber(helperIndex) or 0,
        expiresAt = expiresAt
    }

    log(
        "Driver release captured: vehicle='%s' helper='%s' index=%d adActive=%s leaseMs=%d",
        vehicleName(vehicle),
        tostring(helper.name or "?"),
        tonumber(helper.index) or tonumber(helperIndex) or 0,
        tostring(active),
        tonumber(self.leaseMs) or 3000
    )
    return true
end

function HP_AutoDriveContinuityV2:getReacquireHelper()
    self:_pruneExpired()

    local matchedVehicle = nil
    local matchedHelper = nil
    local matches = 0

    for vehicle, reservation in pairs(self.reservations or {}) do
        if reservation ~= nil and reservation.helper ~= nil then
            local active, helperIndex = getAutoDriveState(vehicle)
            local currentHelper = vehicle.ad ~= nil and vehicle.ad.currentHelper or nil

            -- AutoDrive start/restart sets itself active before asking HelperManager
            -- for another helper. Only reclaim a reservation for that exact vehicle.
            if active
                and (currentHelper == nil or (tonumber(helperIndex) or 0) <= 0)
                and isEngineAvailable(reservation.helper) then
                matches = matches + 1
                matchedVehicle = vehicle
                matchedHelper = reservation.helper
            end
        end
    end

    if matches ~= 1 then
        if matches > 1 then
            log("Continuity skipped: %d AutoDrive vehicles are simultaneously awaiting reserved helpers", matches)
        end
        return nil, nil
    end

    self.reservations[matchedVehicle] = nil
    log(
        "Driver continuity reacquire: vehicle='%s' helper='%s' index=%d",
        vehicleName(matchedVehicle),
        tostring(matchedHelper.name or "?"),
        tonumber(matchedHelper.index) or 0
    )
    return matchedHelper, matchedVehicle
end

function HP_AutoDriveContinuityV2:install()
    if self.installed then return true end

    if HelperProfiles == nil then
        self:_logInstallWait("HelperProfiles global unavailable")
        return false
    end
    if HelperProfiles._hooksDone ~= true then
        self:_logInstallWait("HelperProfiles getRandomHelper hook not ready")
        return false
    end

    local runtimeManager = rawget(_G, "g_helperManager")
    if runtimeManager == nil then
        self:_logInstallWait("g_helperManager unavailable")
        return false
    end

    local runtimeGetRandomHelper = runtimeManager.getRandomHelper
    local runtimeReleaseHelper = runtimeManager.releaseHelper

    if type(runtimeGetRandomHelper) ~= "function" then
        self:_logInstallWait("g_helperManager.getRandomHelper unavailable (type=" .. tostring(type(runtimeGetRandomHelper)) .. ")")
        return false
    end
    if type(runtimeReleaseHelper) ~= "function" then
        self:_logInstallWait("g_helperManager.releaseHelper unavailable (type=" .. tostring(type(runtimeReleaseHelper)) .. ")")
        return false
    end

    -- Hook the live manager instance rather than assuming both methods are exposed
    -- directly on the HelperManager class. AutoDrive invokes g_helperManager with
    -- colon syntax, so these instance wrappers intercept the exact runtime calls.
    self.runtimeManager = runtimeManager
    self.originalGetRandomHelper = runtimeGetRandomHelper
    runtimeManager.getRandomHelper = function(manager, ...)
        local helper = HP_AutoDriveContinuityV2:getReacquireHelper()
        if helper ~= nil then
            print(("[FS25_HelperProfiles] getRandomHelper -> '%s' (autodrive-continuity)"):format(tostring(helper.name)))
            return helper
        end
        return HP_AutoDriveContinuityV2.originalGetRandomHelper(manager, ...)
    end

    self.originalReleaseHelper = runtimeReleaseHelper
    runtimeManager.releaseHelper = function(manager, helper, ...)
        HP_AutoDriveContinuityV2:captureRelease(helper)
        return HP_AutoDriveContinuityV2.originalReleaseHelper(manager, helper, ...)
    end

    if HelperProfiles.isHelperActive ~= nil then
        self.originalIsHelperActive = HelperProfiles.isHelperActive
        HelperProfiles.isHelperActive = function(helperProfilesSelf, helper)
            if HP_AutoDriveContinuityV2:isReserved(helper) then
                return true
            end
            return HP_AutoDriveContinuityV2.originalIsHelperActive(helperProfilesSelf, helper)
        end
    end

    self.installed = true
    self._lastWaitReason = nil
    log(
        "Installed event-driven runtime-manager continuity hooks (getRandomHelper=%s releaseHelper=%s)",
        tostring(type(runtimeGetRandomHelper)),
        tostring(type(runtimeReleaseHelper))
    )
    return true
end

function HP_AutoDriveContinuityV2:loadMap()
    self.reservations = setmetatable({}, {__mode = "k"})
    self._lastWaitReason = nil
    self._lastWaitLogMs = -100000
end

function HP_AutoDriveContinuityV2:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then return end
    if not self.installed then
        self:install()
    else
        self:_pruneExpired()
    end
end

function HP_AutoDriveContinuityV2:deleteMap()
    self.reservations = setmetatable({}, {__mode = "k"})
end

addModEventListener(HP_AutoDriveContinuityV2)
