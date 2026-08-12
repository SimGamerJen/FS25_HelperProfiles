-- HP_AutoDriveContinuity.lua (FS25_HelperProfiles)
-- AutoDrive helper continuity bridge.
--
-- V4 uses AutoDrive's own start/stop event functions as the authoritative vehicle
-- context. This avoids scanning g_currentMission.vehicles and guessing which AD
-- vehicle is currently asking HelperManager for a worker.

print("[FS25_HelperProfiles/AutoDriveV4] Source loaded (AutoDrive-event-context build)")

-- Disable the first polling prototype in HP_Compatibility.lua. This module owns
-- AutoDrive continuity for this test branch.
if HP_AutoDriveContinuity ~= nil then
    HP_AutoDriveContinuity.update = function() end
end

HP_AutoDriveContinuityV4 = HP_AutoDriveContinuityV4 or {
    installed = false,
    reservations = setmetatable({}, {__mode = "k"}),
    pendingRestartVehicle = nil,
    originalGetRandomHelper = nil,
    originalIsHelperActive = nil,
    originalSendStartEvent = nil,
    originalSendStopEvent = nil,
    runtimeManager = nil,
    _lastWaitReason = nil,
    _lastWaitLogMs = -100000
}

local LOG = "[FS25_HelperProfiles/AutoDriveV4] "

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

local function isAutoDriveActive(vehicle)
    if vehicle == nil or vehicle.ad == nil or vehicle.ad.stateModule == nil then
        return false
    end
    local stateModule = vehicle.ad.stateModule
    if type(stateModule.isActive) ~= "function" then
        return false
    end
    local ok, value = pcall(stateModule.isActive, stateModule)
    return ok and value == true
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

function HP_AutoDriveContinuityV4:_logInstallWait(reason)
    local now = nowMs()
    reason = tostring(reason or "unknown")
    if self._lastWaitReason ~= reason or (now - (tonumber(self._lastWaitLogMs) or 0)) >= 10000 then
        self._lastWaitReason = reason
        self._lastWaitLogMs = now
        log("Waiting to install: %s", reason)
    end
end

function HP_AutoDriveContinuityV4:_reserve(vehicle, helper, reason)
    if vehicle == nil or helper == nil then
        return false
    end

    local previous = self.reservations[vehicle]
    self.reservations[vehicle] = {
        helper = helper,
        helperIndex = tonumber(helper.index) or 0
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

function HP_AutoDriveContinuityV4:_clear(vehicle, reason)
    local reservation = vehicle ~= nil and self.reservations[vehicle] or nil
    if reservation == nil then
        if self.pendingRestartVehicle == vehicle then
            self.pendingRestartVehicle = nil
        end
        return false
    end

    log(
        "Driver session cleared: vehicle='%s' helper='%s' reason=%s",
        vehicleName(vehicle),
        helperName(reservation.helper),
        tostring(reason or "unknown")
    )
    self.reservations[vehicle] = nil
    if self.pendingRestartVehicle == vehicle then
        self.pendingRestartVehicle = nil
    end
    return true
end

function HP_AutoDriveContinuityV4:isReserved(helper)
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

function HP_AutoDriveContinuityV4:_onAutoDriveStartEvent(vehicle)
    if vehicle == nil or vehicle.ad == nil then
        return
    end

    local helper = vehicle.ad.currentHelper
    if helper ~= nil then
        self:_reserve(vehicle, helper, "autodrive-start-event")
    else
        log("Start event without current helper: vehicle='%s'", vehicleName(vehicle))
    end

    if self.pendingRestartVehicle == vehicle then
        self.pendingRestartVehicle = nil
    end
end

function HP_AutoDriveContinuityV4:_onAutoDriveStopEvent(vehicle)
    if vehicle == nil or vehicle.ad == nil then
        return
    end

    -- The stop event is sent before AutoDrive:onStopAutoDrive releases and clears
    -- currentHelper. Capture/confirm ownership while the exact vehicle context is
    -- still available.
    local helper = vehicle.ad.currentHelper
    if self.reservations[vehicle] == nil and helper ~= nil then
        self:_reserve(vehicle, helper, "autodrive-stop-fallback")
    end

    local reservation = self.reservations[vehicle]
    if reservation ~= nil and reservation.helper ~= nil then
        self.pendingRestartVehicle = vehicle
        log(
            "Stop transition captured: vehicle='%s' helper='%s'; retaining ownership until next update frame",
            vehicleName(vehicle),
            helperName(reservation.helper)
        )
    end
end

function HP_AutoDriveContinuityV4:_getSynchronousRestartHelper()
    local vehicle = self.pendingRestartVehicle
    if vehicle == nil then
        return nil, nil
    end

    local reservation = self.reservations[vehicle]
    if reservation == nil or reservation.helper == nil then
        self.pendingRestartVehicle = nil
        return nil, nil
    end

    -- RestartADTask stops AD and immediately starts the mode again in the same call.
    -- startAutoDrive() sets AD active before it asks HelperManager for a helper, so
    -- an active pending vehicle here is the exact synchronous-restart case.
    if not isAutoDriveActive(vehicle) then
        return nil, vehicle
    end

    local helper = reservation.helper
    if not isEngineAvailable(helper) then
        log(
            "Synchronous restart found but reserved helper is not engine-available: vehicle='%s' helper='%s' inUse=%s",
            vehicleName(vehicle),
            helperName(helper),
            tostring(helper.inUse)
        )
        return nil, vehicle
    end

    self.pendingRestartVehicle = nil
    log(
        "Driver continuity reacquire: vehicle='%s' helper='%s' index=%d reason=synchronous-restart",
        vehicleName(vehicle),
        helperName(helper),
        tonumber(helper.index) or tonumber(reservation.helperIndex) or 0
    )
    return helper, vehicle
end

function HP_AutoDriveContinuityV4:_expireUnrestartedStop()
    local vehicle = self.pendingRestartVehicle
    if vehicle == nil then
        return
    end

    -- If RestartADTask was going to restart this AD session, it would already have
    -- done so synchronously before this update frame. Reaching update while still
    -- pending therefore means this was a genuine stop.
    if not isAutoDriveActive(vehicle) then
        self:_clear(vehicle, "autodrive-stopped-no-synchronous-restart")
    else
        -- Defensive fallback: an active vehicle should have consumed the token from
        -- getRandomHelper/sendStartEvent. Keep ownership but drop the stale token.
        log("Pending restart token expired while vehicle is active: vehicle='%s'", vehicleName(vehicle))
        self.pendingRestartVehicle = nil
    end
end

function HP_AutoDriveContinuityV4:install()
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
    if type(runtimeManager.getRandomHelper) ~= "function" then
        self:_logInstallWait("g_helperManager.getRandomHelper unavailable (type=" .. tostring(type(runtimeManager.getRandomHelper)) .. ")")
        return false
    end

    if AutoDriveStartStopEvent == nil then
        self:_logInstallWait("AutoDriveStartStopEvent unavailable")
        return false
    end
    if type(AutoDriveStartStopEvent.sendStartEvent) ~= "function" then
        self:_logInstallWait("AutoDriveStartStopEvent.sendStartEvent unavailable")
        return false
    end
    if type(AutoDriveStartStopEvent.sendStopEvent) ~= "function" then
        self:_logInstallWait("AutoDriveStartStopEvent.sendStopEvent unavailable")
        return false
    end

    self.runtimeManager = runtimeManager

    self.originalGetRandomHelper = runtimeManager.getRandomHelper
    runtimeManager.getRandomHelper = function(manager, ...)
        local helper = HP_AutoDriveContinuityV4:_getSynchronousRestartHelper()
        if helper ~= nil then
            print(("[FS25_HelperProfiles] getRandomHelper -> '%s' (autodrive-event-continuity)"):format(helperName(helper)))
            return helper
        end
        return HP_AutoDriveContinuityV4.originalGetRandomHelper(manager, ...)
    end

    if HelperProfiles.isHelperActive ~= nil then
        self.originalIsHelperActive = HelperProfiles.isHelperActive
        HelperProfiles.isHelperActive = function(helperProfilesSelf, helper)
            if HP_AutoDriveContinuityV4:isReserved(helper) then
                return true
            end
            return HP_AutoDriveContinuityV4.originalIsHelperActive(helperProfilesSelf, helper)
        end
    end

    self.originalSendStartEvent = AutoDriveStartStopEvent.sendStartEvent
    AutoDriveStartStopEvent.sendStartEvent = function(eventSelf, vehicle, ...)
        HP_AutoDriveContinuityV4:_onAutoDriveStartEvent(vehicle)
        return HP_AutoDriveContinuityV4.originalSendStartEvent(eventSelf, vehicle, ...)
    end

    self.originalSendStopEvent = AutoDriveStartStopEvent.sendStopEvent
    AutoDriveStartStopEvent.sendStopEvent = function(eventSelf, vehicle, ...)
        HP_AutoDriveContinuityV4:_onAutoDriveStopEvent(vehicle)
        return HP_AutoDriveContinuityV4.originalSendStopEvent(eventSelf, vehicle, ...)
    end

    self.installed = true
    self._lastWaitReason = nil
    log("Installed AutoDrive event-context continuity hooks")
    return true
end

function HP_AutoDriveContinuityV4:loadMap()
    self.reservations = setmetatable({}, {__mode = "k"})
    self.pendingRestartVehicle = nil
    self._lastWaitReason = nil
    self._lastWaitLogMs = -100000
end

function HP_AutoDriveContinuityV4:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then
        return
    end

    if not self.installed then
        self:install()
    else
        self:_expireUnrestartedStop()
    end
end

function HP_AutoDriveContinuityV4:deleteMap()
    self.reservations = setmetatable({}, {__mode = "k"})
    self.pendingRestartVehicle = nil
end

addModEventListener(HP_AutoDriveContinuityV4)
