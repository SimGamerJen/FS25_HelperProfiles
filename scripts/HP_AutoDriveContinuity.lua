-- HP_AutoDriveContinuity.lua (FS25_HelperProfiles)
-- AutoDrive helper continuity bridge.
--
-- Ownership is established when an active AutoDrive vehicle first acquires a helper.
-- That vehicle keeps the same helper across GIANTS/AutoDrive release/reacquire cycles
-- until AutoDrive has been genuinely inactive for a short sustained interval.

print("[FS25_HelperProfiles/AutoDriveV3] Source loaded (session-ownership build)")

-- Disable the first polling prototype in HP_Compatibility.lua. This module owns
-- AutoDrive continuity for this test branch.
if HP_AutoDriveContinuity ~= nil then
    HP_AutoDriveContinuity.update = function() end
end

HP_AutoDriveContinuityV3 = HP_AutoDriveContinuityV3 or {
    installed = false,
    reservations = setmetatable({}, {__mode = "k"}),
    originalGetRandomHelper = nil,
    originalReleaseHelper = nil,
    originalIsHelperActive = nil,
    runtimeManager = nil,
    stopGraceMs = 500,
    _lastWaitReason = nil,
    _lastWaitLogMs = -100000
}

local LOG = "[FS25_HelperProfiles/AutoDriveV3] "

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

local function helperName(helper)
    return tostring(helper ~= nil and helper.name or "?")
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
        if ok then
            helperIndex = tonumber(value) or 0
        end
    end

    return active, helperIndex
end

local function isEngineAvailable(helper)
    if helper == nil or helper.inUse == true or g_helperManager == nil then
        return false
    end

    for _, candidate in ipairs(g_helperManager.availableHelpers or {}) do
        if candidate == helper then
            return true
        end
    end
    return false
end

function HP_AutoDriveContinuityV3:_logInstallWait(reason)
    local now = nowMs()
    reason = tostring(reason or "unknown")
    if self._lastWaitReason ~= reason or (now - (tonumber(self._lastWaitLogMs) or 0)) >= 10000 then
        self._lastWaitReason = reason
        self._lastWaitLogMs = now
        log("Waiting to install: %s", reason)
    end
end

function HP_AutoDriveContinuityV3:_findAwaitingVehicle()
    if g_currentMission == nil then
        return nil, 0
    end

    local match = nil
    local matches = 0

    for _, vehicle in pairs(g_currentMission.vehicles or {}) do
        if vehicle ~= nil and vehicle.ad ~= nil then
            local active, helperIndex = getAutoDriveState(vehicle)
            local currentHelper = vehicle.ad.currentHelper

            -- AutoDrive sets itself active before calling getRandomHelper(). During
            -- both initial allocation and an internal restart, currentHelper/index
            -- are empty while the vehicle is awaiting its driver.
            if active and (currentHelper == nil or (tonumber(helperIndex) or 0) <= 0) then
                matches = matches + 1
                match = vehicle
            end
        end
    end

    if matches == 1 then
        return match, matches
    end

    return nil, matches
end

function HP_AutoDriveContinuityV3:_reserve(vehicle, helper, reason)
    if vehicle == nil or helper == nil then
        return false
    end

    local previous = self.reservations[vehicle]
    self.reservations[vehicle] = {
        helper = helper,
        helperIndex = tonumber(helper.index) or 0,
        inactiveSince = nil
    }

    if previous == nil or previous.helper ~= helper then
        log(
            "Driver session reserved: vehicle='%s' helper='%s' index=%d reason=%s",
            vehicleName(vehicle),
            helperName(helper),
            tonumber(helper.index) or 0,
            tostring(reason or "unknown")
        )
    end
    return true
end

function HP_AutoDriveContinuityV3:_clear(vehicle, reason)
    local reservation = vehicle ~= nil and self.reservations[vehicle] or nil
    if reservation == nil then
        return false
    end

    log(
        "Driver session cleared: vehicle='%s' helper='%s' reason=%s",
        vehicleName(vehicle),
        helperName(reservation.helper),
        tostring(reason or "unknown")
    )
    self.reservations[vehicle] = nil
    return true
end

function HP_AutoDriveContinuityV3:isReserved(helper)
    if helper == nil then
        return false
    end

    for _, reservation in pairs(self.reservations or {}) do
        if reservation ~= nil and reservation.helper == helper then
            return true
        end
    end
    return false
end

function HP_AutoDriveContinuityV3:getReservedReacquire()
    local vehicle, awaitingCount = self:_findAwaitingVehicle()
    if vehicle == nil then
        if awaitingCount > 1 then
            log("Continuity skipped: %d AutoDrive vehicles are simultaneously awaiting helpers", awaitingCount)
        end
        return nil, nil
    end

    local reservation = self.reservations[vehicle]
    if reservation == nil or reservation.helper == nil then
        return nil, vehicle
    end

    local helper = reservation.helper
    if not isEngineAvailable(helper) then
        log(
            "Reserved helper not engine-available yet: vehicle='%s' helper='%s'",
            vehicleName(vehicle),
            helperName(helper)
        )
        return nil, vehicle
    end

    reservation.inactiveSince = nil
    log(
        "Driver continuity reacquire: vehicle='%s' helper='%s' index=%d",
        vehicleName(vehicle),
        helperName(helper),
        tonumber(helper.index) or tonumber(reservation.helperIndex) or 0
    )
    return helper, vehicle
end

function HP_AutoDriveContinuityV3:captureInitialAllocation(helper, awaitingVehicle)
    if helper == nil then
        return false
    end

    local vehicle = awaitingVehicle
    local matches = 1
    if vehicle == nil then
        vehicle, matches = self:_findAwaitingVehicle()
    end

    if vehicle == nil then
        if matches > 1 then
            log("Initial reservation skipped: %d AutoDrive vehicles are simultaneously awaiting helpers", matches)
        end
        return false
    end

    -- If a reservation already exists, do not replace it with the currently
    -- highlighted helper. The existing reservation owns this AutoDrive session.
    local existing = self.reservations[vehicle]
    if existing ~= nil and existing.helper ~= nil then
        return true
    end

    return self:_reserve(vehicle, helper, "initial-allocation")
end

function HP_AutoDriveContinuityV3:observeRelease(helper)
    if helper == nil then
        return false
    end

    for vehicle, reservation in pairs(self.reservations or {}) do
        if reservation ~= nil and reservation.helper == helper then
            local active, helperIndex = getAutoDriveState(vehicle)
            log(
                "Reserved driver released by engine: vehicle='%s' helper='%s' adActive=%s helperIndex=%d; session ownership retained",
                vehicleName(vehicle),
                helperName(helper),
                tostring(active),
                tonumber(helperIndex) or 0
            )
            return true
        end
    end

    -- Fallback for unusual call ordering: if AutoDrive still references the helper
    -- at release time, establish the session reservation here.
    if g_currentMission ~= nil then
        local match = nil
        local matches = 0
        for _, vehicle in pairs(g_currentMission.vehicles or {}) do
            if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.currentHelper == helper then
                matches = matches + 1
                match = vehicle
            end
        end
        if matches == 1 then
            return self:_reserve(match, helper, "release-fallback")
        end
    end

    return false
end

function HP_AutoDriveContinuityV3:_updateReservations()
    local now = nowMs()
    local grace = tonumber(self.stopGraceMs) or 500

    for vehicle, reservation in pairs(self.reservations or {}) do
        if reservation ~= nil then
            local active = false
            if vehicle ~= nil and vehicle.ad ~= nil then
                active = select(1, getAutoDriveState(vehicle))
            end

            if active then
                reservation.inactiveSince = nil
            else
                if reservation.inactiveSince == nil then
                    reservation.inactiveSince = now
                elseif (now - (tonumber(reservation.inactiveSince) or now)) >= grace then
                    self:_clear(vehicle, "autodrive-inactive")
                end
            end
        end
    end
end

function HP_AutoDriveContinuityV3:install()
    if self.installed then
        return true
    end

    if HelperProfiles == nil then
        self:_logInstallWait("HelperProfiles global unavailable")
        return false
    end
    if HelperProfiles._hooksDone ~= true then
        self:_logInstallWait("HelperProfiles getRandomHelper hook not ready")
        return false
    end

    local runtimeManager = g_helperManager
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

    self.runtimeManager = runtimeManager
    self.originalGetRandomHelper = runtimeGetRandomHelper
    runtimeManager.getRandomHelper = function(manager, ...)
        local reservedHelper, awaitingVehicle = HP_AutoDriveContinuityV3:getReservedReacquire()
        if reservedHelper ~= nil then
            print(("[FS25_HelperProfiles] getRandomHelper -> '%s' (autodrive-session-continuity)"):format(helperName(reservedHelper)))
            return reservedHelper
        end

        local helper = HP_AutoDriveContinuityV3.originalGetRandomHelper(manager, ...)
        if helper ~= nil then
            HP_AutoDriveContinuityV3:captureInitialAllocation(helper, awaitingVehicle)
        end
        return helper
    end

    self.originalReleaseHelper = runtimeReleaseHelper
    runtimeManager.releaseHelper = function(manager, helper, ...)
        HP_AutoDriveContinuityV3:observeRelease(helper)
        return HP_AutoDriveContinuityV3.originalReleaseHelper(manager, helper, ...)
    end

    if HelperProfiles.isHelperActive ~= nil then
        self.originalIsHelperActive = HelperProfiles.isHelperActive
        HelperProfiles.isHelperActive = function(helperProfilesSelf, helper)
            if HP_AutoDriveContinuityV3:isReserved(helper) then
                return true
            end
            return HP_AutoDriveContinuityV3.originalIsHelperActive(helperProfilesSelf, helper)
        end
    end

    self.installed = true
    self._lastWaitReason = nil
    log(
        "Installed session-ownership continuity hooks (getRandomHelper=%s releaseHelper=%s stopGraceMs=%d)",
        tostring(type(runtimeGetRandomHelper)),
        tostring(type(runtimeReleaseHelper)),
        tonumber(self.stopGraceMs) or 500
    )
    return true
end

function HP_AutoDriveContinuityV3:loadMap()
    self.reservations = setmetatable({}, {__mode = "k"})
    self._lastWaitReason = nil
    self._lastWaitLogMs = -100000
end

function HP_AutoDriveContinuityV3:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then
        return
    end

    if not self.installed then
        self:install()
    else
        self:_updateReservations()
    end
end

function HP_AutoDriveContinuityV3:deleteMap()
    self.reservations = setmetatable({}, {__mode = "k"})
end

addModEventListener(HP_AutoDriveContinuityV3)
