-- HP_AutoDriveContinuity.lua (FS25_HelperProfiles)
-- AutoDrive helper continuity bridge.
--
-- V5 uses HelperProfiles' proven worker-appearance assignment hook as the
-- authoritative vehicle<->helper relationship. HP_WorkerAppearance already sees
-- Enterable.setRandomVehicleCharacter(vehicle, helper) in the live game and stores
-- that exact pair in vehicleAssignments. We retain that assignment across
-- AutoDrive's internal release/reacquire cycle without depending on AutoDrive's
-- private event globals.

print("[FS25_HelperProfiles/AutoDriveV5] Source loaded (worker-assignment continuity build)")

-- Disable the original polling prototype in HP_Compatibility.lua. This module owns
-- AutoDrive continuity on this branch.
if HP_AutoDriveContinuity ~= nil then
    HP_AutoDriveContinuity.update = function() end
end

HP_AutoDriveContinuityV5 = HP_AutoDriveContinuityV5 or {
    installed = false,
    reservations = setmetatable({}, {__mode = "k"}),
    pendingByVehicle = setmetatable({}, {__mode = "k"}),
    originalGetRandomHelper = nil,
    originalReleaseHelper = nil,
    originalIsHelperActive = nil,
    runtimeManager = nil,
    _lastWaitReason = nil,
    _lastWaitLogMs = -100000
}

local LOG = "[FS25_HelperProfiles/AutoDriveV5] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function nowMs()
    return tonumber(g_time) or 0
end

local function vehicleName(vehicle)
    if vehicle ~= nil and type(vehicle.getFullName) == "function" then
        local ok, value = pcall(vehicle.getFullName, vehicle)
        if ok and value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    if vehicle ~= nil and type(vehicle.getName) == "function" then
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

local function isAutoDriveVehicle(vehicle)
    return vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.stateModule ~= nil
end

local function isAutoDriveActive(vehicle)
    if not isAutoDriveVehicle(vehicle) then
        return false
    end

    local stateModule = vehicle.ad.stateModule
    if type(stateModule.isActive) ~= "function" then
        return false
    end

    local ok, value = pcall(stateModule.isActive, stateModule)
    return ok and value == true
end

local function helperIsFree(helper)
    if helper == nil then
        return false
    end

    -- releaseHelper() has already completed before AutoDrive synchronously calls
    -- getRandomHelper() again. Do not require membership in availableHelpers here:
    -- HelperProfiles/roster filtering may proxy that table, while helper.inUse is
    -- the direct ownership state we need for this tiny transition window.
    return helper.inUse ~= true
end

function HP_AutoDriveContinuityV5:_logInstallWait(reason)
    local now = nowMs()
    reason = tostring(reason or "unknown")
    if self._lastWaitReason ~= reason or (now - (tonumber(self._lastWaitLogMs) or 0)) >= 10000 then
        self._lastWaitReason = reason
        self._lastWaitLogMs = now
        log("Waiting to install: %s", reason)
    end
end

function HP_AutoDriveContinuityV5:_reserve(vehicle, helper, reason)
    if vehicle == nil or helper == nil then
        return false
    end

    local previous = self.reservations[vehicle]
    if previous ~= nil and previous.helper == helper then
        previous.helperIndex = tonumber(helper.index) or previous.helperIndex or 0
        return true
    end

    self.reservations[vehicle] = {
        helper = helper,
        helperIndex = tonumber(helper.index) or 0,
        observedAt = nowMs()
    }

    log(
        "Driver session reserved: vehicle='%s' helper='%s' index=%d reason=%s",
        vehicleName(vehicle),
        helperName(helper),
        tonumber(helper.index) or 0,
        tostring(reason or "unknown")
    )
    return true
end

function HP_AutoDriveContinuityV5:_clear(vehicle, reason)
    local reservation = vehicle ~= nil and self.reservations[vehicle] or nil
    if reservation == nil then
        self.pendingByVehicle[vehicle] = nil
        return false
    end

    log(
        "Driver session cleared: vehicle='%s' helper='%s' reason=%s",
        vehicleName(vehicle),
        helperName(reservation.helper),
        tostring(reason or "unknown")
    )

    self.reservations[vehicle] = nil
    self.pendingByVehicle[vehicle] = nil
    return true
end

function HP_AutoDriveContinuityV5:isReserved(helper)
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

function HP_AutoDriveContinuityV5:_syncWorkerAssignments()
    if HP_WorkerAppearance == nil or type(HP_WorkerAppearance.vehicleAssignments) ~= "table" then
        return
    end

    for vehicle, assignment in pairs(HP_WorkerAppearance.vehicleAssignments) do
        local helper = assignment ~= nil and assignment.helper or nil
        if vehicle ~= nil and helper ~= nil and isAutoDriveVehicle(vehicle) and isAutoDriveActive(vehicle) then
            local existing = self.reservations[vehicle]
            local pending = self.pendingByVehicle[vehicle]

            -- During a continuity transition, never let a later appearance update
            -- replace the reserved owner before getRandomHelper has had a chance to
            -- return that owner. In the normal path this branch is never needed,
            -- because getRandomHelper is intercepted first.
            if existing ~= nil and pending ~= nil and existing.helper ~= helper then
                log(
                    "Ignoring replacement assignment while continuity is pending: vehicle='%s' reserved='%s' observed='%s'",
                    vehicleName(vehicle),
                    helperName(existing.helper),
                    helperName(helper)
                )
            else
                self:_reserve(vehicle, helper, "worker-appearance-assignment")
            end
        end
    end
end

function HP_AutoDriveContinuityV5:_findReservedVehicleForHelper(helper)
    if helper == nil then
        return nil
    end

    local match = nil
    local matches = 0
    for vehicle, reservation in pairs(self.reservations or {}) do
        if reservation ~= nil and reservation.helper == helper then
            match = vehicle
            matches = matches + 1
        end
    end

    if matches == 1 then
        return match
    end
    if matches > 1 then
        log("Release mapping ambiguous: helper='%s' has %d reserved AutoDrive vehicles", helperName(helper), matches)
    end
    return nil
end

function HP_AutoDriveContinuityV5:_observeRelease(helper)
    local vehicle = self:_findReservedVehicleForHelper(helper)
    if vehicle == nil then
        return false
    end

    self.pendingByVehicle[vehicle] = {
        helper = helper,
        releasedAt = nowMs()
    }

    log(
        "Driver release captured: vehicle='%s' helper='%s' adActive=%s; retaining reservation for synchronous restart",
        vehicleName(vehicle),
        helperName(helper),
        tostring(isAutoDriveActive(vehicle))
    )
    return true
end

function HP_AutoDriveContinuityV5:_getPendingReacquire()
    local matchedVehicle = nil
    local matchedHelper = nil
    local matches = 0

    for vehicle, pending in pairs(self.pendingByVehicle or {}) do
        local reservation = self.reservations[vehicle]
        local helper = pending ~= nil and pending.helper or nil

        if reservation ~= nil and helper ~= nil and reservation.helper == helper and isAutoDriveActive(vehicle) then
            if helperIsFree(helper) then
                matchedVehicle = vehicle
                matchedHelper = helper
                matches = matches + 1
            else
                log(
                    "Pending restart found but helper still in use: vehicle='%s' helper='%s'",
                    vehicleName(vehicle),
                    helperName(helper)
                )
            end
        end
    end

    if matches == 1 then
        self.pendingByVehicle[matchedVehicle] = nil
        log(
            "Driver continuity reacquire: vehicle='%s' helper='%s' index=%d reason=release-restart",
            vehicleName(matchedVehicle),
            helperName(matchedHelper),
            tonumber(matchedHelper.index) or 0
        )
        return matchedHelper, matchedVehicle
    end

    if matches > 1 then
        log("Continuity skipped: %d released AutoDrive vehicles are simultaneously requesting helpers", matches)
    end
    return nil, nil
end

function HP_AutoDriveContinuityV5:_expireStoppedPending()
    for vehicle, pending in pairs(self.pendingByVehicle or {}) do
        if pending ~= nil and not isAutoDriveActive(vehicle) then
            -- AutoDrive's internal RestartADTask restarts synchronously. If we have
            -- reached a later update frame and the vehicle is still inactive, this
            -- was a genuine stop rather than the temporary release/reacquire cycle.
            self:_clear(vehicle, "autodrive-stopped-no-synchronous-restart")
        end
    end
end

function HP_AutoDriveContinuityV5:install()
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
    if HP_WorkerAppearance == nil or type(HP_WorkerAppearance.vehicleAssignments) ~= "table" then
        self:_logInstallWait("HP_WorkerAppearance.vehicleAssignments unavailable")
        return false
    end

    local runtimeManager = g_helperManager
    if runtimeManager == nil then
        self:_logInstallWait("g_helperManager unavailable")
        return false
    end
    if type(runtimeManager.getRandomHelper) ~= "function" then
        self:_logInstallWait("g_helperManager.getRandomHelper unavailable (type=" .. tostring(type(runtimeManager.getRandomHelper)) .. ")")
        return false
    end
    if type(runtimeManager.releaseHelper) ~= "function" then
        self:_logInstallWait("g_helperManager.releaseHelper unavailable (type=" .. tostring(type(runtimeManager.releaseHelper)) .. ")")
        return false
    end

    self.runtimeManager = runtimeManager

    self.originalGetRandomHelper = runtimeManager.getRandomHelper
    runtimeManager.getRandomHelper = function(manager, ...)
        local helper = HP_AutoDriveContinuityV5:_getPendingReacquire()
        if helper ~= nil then
            print(("[FS25_HelperProfiles] getRandomHelper -> '%s' (autodrive-worker-continuity)"):format(helperName(helper)))
            return helper
        end
        return HP_AutoDriveContinuityV5.originalGetRandomHelper(manager, ...)
    end

    self.originalReleaseHelper = runtimeManager.releaseHelper
    runtimeManager.releaseHelper = function(manager, helper, ...)
        HP_AutoDriveContinuityV5:_observeRelease(helper)
        return HP_AutoDriveContinuityV5.originalReleaseHelper(manager, helper, ...)
    end

    if type(HelperProfiles.isHelperActive) == "function" then
        self.originalIsHelperActive = HelperProfiles.isHelperActive
        HelperProfiles.isHelperActive = function(helperProfilesSelf, helper)
            if HP_AutoDriveContinuityV5:isReserved(helper) then
                return true
            end
            return HP_AutoDriveContinuityV5.originalIsHelperActive(helperProfilesSelf, helper)
        end
    end

    self.installed = true
    self._lastWaitReason = nil
    log("Installed worker-assignment continuity hooks (getRandomHelper + releaseHelper + activity bridge)")
    return true
end

function HP_AutoDriveContinuityV5:loadMap()
    self.reservations = setmetatable({}, {__mode = "k"})
    self.pendingByVehicle = setmetatable({}, {__mode = "k"})
    self._lastWaitReason = nil
    self._lastWaitLogMs = -100000
end

function HP_AutoDriveContinuityV5:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then
        return
    end

    if not self.installed then
        if not self:install() then
            return
        end
    end

    self:_expireStoppedPending()
    self:_syncWorkerAssignments()
end

function HP_AutoDriveContinuityV5:deleteMap()
    self.reservations = setmetatable({}, {__mode = "k"})
    self.pendingByVehicle = setmetatable({}, {__mode = "k"})
end

-- Keep payroll accounting optional and outside the continuity algorithm. The
-- bridge is sourced here so older modDesc files on this feature branch do not
-- need a new load-order dependency; failure to load it must never disable V5.
if source ~= nil and g_currentModDirectory ~= nil then
    local ok, err = pcall(source, g_currentModDirectory .. "scripts/HP_AutoDrivePayrollBridge.lua")
    if not ok then
        log("Optional HelperPayroll bridge failed to load: %s", tostring(err))
    end
end

addModEventListener(HP_AutoDriveContinuityV5)
