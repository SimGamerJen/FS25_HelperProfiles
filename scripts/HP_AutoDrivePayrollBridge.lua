-- HP_AutoDrivePayrollBridge.lua (FS25_HelperProfiles)
-- Optional HelperPayroll bridge for AutoDrive continuity sessions.
--
-- HP_AutoDriveContinuityV5 owns the authoritative AutoDrive vehicle/helper
-- reservation. This bridge mirrors only that logical reservation lifecycle into
-- HelperPayroll's generic external-worker-session API. AutoDrive's internal
-- release/reacquire cycles never end the payroll session because the V5
-- reservation deliberately survives those transitions.

HP_AutoDrivePayrollBridge = HP_AutoDrivePayrollBridge or {
    activeByVehicle = setmetatable({}, {__mode = "k"}),
    sessionSequence = 0,
    _lastWaitReason = nil,
    _lastWaitLogMs = -100000
}

local LOG = "[FS25_HelperProfiles/AutoDrivePayroll] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function nowMs()
    return tonumber(g_time) or 0
end

local function vehicleName(vehicle)
    if vehicle ~= nil and type(vehicle.getFullName) == "function" then
        local ok, value = pcall(vehicle.getFullName, vehicle)
        if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    if vehicle ~= nil and type(vehicle.getName) == "function" then
        local ok, value = pcall(vehicle.getName, vehicle)
        if ok and value ~= nil and tostring(value) ~= "" then return tostring(value) end
    end
    return tostring(vehicle or "unknown-vehicle")
end

local function helperName(helper)
    return tostring(helper ~= nil and helper.name or "?")
end

local function helperSlot(helper)
    local index = math.floor(tonumber(helper ~= nil and helper.index or 0) or 0)
    if index < 1 or index > 20 then return nil end
    return string.char(string.byte("A") + index - 1)
end

local function ownerFarmId(vehicle)
    if vehicle ~= nil and type(vehicle.getOwnerFarmId) == "function" then
        local ok, value = pcall(vehicle.getOwnerFarmId, vehicle)
        if ok and tonumber(value) ~= nil then return tonumber(value) end
    end
    if vehicle ~= nil and tonumber(vehicle.ownerFarmId) ~= nil then
        return tonumber(vehicle.ownerFarmId)
    end
    return nil
end

function HP_AutoDrivePayrollBridge:_logWait(reason)
    local now = nowMs()
    reason = tostring(reason or "unknown")
    if self._lastWaitReason ~= reason or now - (tonumber(self._lastWaitLogMs) or 0) >= 10000 then
        self._lastWaitReason = reason
        self._lastWaitLogMs = now
        log("Waiting: %s", reason)
    end
end

function HP_AutoDrivePayrollBridge:_getPayrollAPI()
    local api = nil

    if g_currentMission ~= nil then
        api = g_currentMission.fs25HelperPayrollAPI or g_currentMission.helperPayrollAPI
    end

    if type(api) ~= "table" then
        local ok, value = pcall(function()
            return FS25_HelperPayroll_API or FS25_HelperPayrollAPI
        end)
        if ok then api = value end
    end

    if type(api) ~= "table" then return nil, "HelperPayroll API unavailable" end
    if type(api.beginExternalWorkerSession) ~= "function" then return nil, "HelperPayroll external-session API unavailable" end
    if type(api.endExternalWorkerSession) ~= "function" then return nil, "HelperPayroll external-session finish API unavailable" end
    if type(api.capabilities) == "table" and api.capabilities.externalWorkerSessions == false then
        return nil, "HelperPayroll external sessions disabled"
    end

    return api, nil
end

function HP_AutoDrivePayrollBridge:_begin(vehicle, reservation)
    if vehicle == nil or reservation == nil or reservation.helper == nil then return false end

    local api, reason = self:_getPayrollAPI()
    if api == nil then
        self:_logWait(reason)
        return false
    end

    local helper = reservation.helper
    local slot = helperSlot(helper)
    if slot == nil then
        self:_logWait("reserved helper has no A-T slot")
        return false
    end

    self.sessionSequence = (tonumber(self.sessionSequence) or 0) + 1
    local sessionId = string.format("helperprofiles-autodrive-%d", self.sessionSequence)
    local request = {
        sessionId = sessionId,
        source = "FS25_HelperProfiles",
        controller = "AutoDrive",
        jobType = "AutoDrive",
        label = "AutoDrive worker",
        helperSlot = slot,
        helperIndex = tonumber(helper.index),
        helperName = helperName(helper),
        helperSlotSource = "HelperProfiles-AutoDrive-reservation",
        vehicleName = vehicleName(vehicle),
        farmId = ownerFarmId(vehicle)
    }

    local ok, accepted, result = pcall(api.beginExternalWorkerSession, api, request)
    if not ok then
        self:_logWait("HelperPayroll beginExternalWorkerSession raised an error: " .. tostring(accepted))
        return false
    end
    if accepted ~= true then
        local status = type(result) == "table" and result.status or "rejected"
        self:_logWait("HelperPayroll rejected external session: " .. tostring(status))
        return false
    end

    self.activeByVehicle[vehicle] = {
        helper = helper,
        helperIndex = tonumber(helper.index) or 0,
        sessionId = sessionId,
        api = api,
        startedAt = nowMs()
    }
    self._lastWaitReason = nil

    log(
        "Payroll session started: id=%s vehicle='%s' helper='%s' slot=%s",
        tostring(sessionId),
        vehicleName(vehicle),
        helperName(helper),
        tostring(slot)
    )
    return true
end

function HP_AutoDrivePayrollBridge:_finish(vehicle, active, reason)
    if active == nil then return false end

    local api = active.api
    if type(api) ~= "table" or type(api.endExternalWorkerSession) ~= "function" then
        api = select(1, self:_getPayrollAPI())
    end

    local finished = false
    local status = "api-unavailable"
    if type(api) == "table" and type(api.endExternalWorkerSession) == "function" then
        local ok, accepted, result = pcall(api.endExternalWorkerSession, api, active.sessionId, reason)
        if ok then
            finished = accepted == true
            status = type(result) == "table" and tostring(result.status or (finished and "finished" or "rejected")) or tostring(accepted)
        else
            status = "error:" .. tostring(accepted)
        end
    end

    log(
        "Payroll session ended: id=%s vehicle='%s' helper='%s' reason=%s accepted=%s status=%s",
        tostring(active.sessionId),
        vehicleName(vehicle),
        helperName(active.helper),
        tostring(reason or "reservation-ended"),
        tostring(finished),
        tostring(status)
    )

    self.activeByVehicle[vehicle] = nil
    return finished
end

function HP_AutoDrivePayrollBridge:_sync()
    if HP_AutoDriveContinuityV5 == nil or type(HP_AutoDriveContinuityV5.reservations) ~= "table" then
        self:_logWait("AutoDrive V5 reservation table unavailable")
        return
    end

    local reservations = HP_AutoDriveContinuityV5.reservations

    -- End sessions whose logical V5 reservation has genuinely disappeared or
    -- changed owner. Internal AutoDrive release/reacquire transitions retain the
    -- reservation, so they do not pass through this branch.
    for vehicle, active in pairs(self.activeByVehicle or {}) do
        local reservation = reservations[vehicle]
        if reservation == nil then
            self:_finish(vehicle, active, "autodrive-reservation-ended")
        elseif reservation.helper ~= active.helper then
            self:_finish(vehicle, active, "autodrive-reservation-owner-changed")
        end
    end

    -- Start payroll for any live V5 reservation that does not yet have a mirrored
    -- external session. If HelperPayroll loads later, this naturally retries on a
    -- subsequent update without disturbing AutoDrive continuity.
    for vehicle, reservation in pairs(reservations) do
        if reservation ~= nil and reservation.helper ~= nil and self.activeByVehicle[vehicle] == nil then
            self:_begin(vehicle, reservation)
        end
    end
end

function HP_AutoDrivePayrollBridge:loadMap()
    self.activeByVehicle = setmetatable({}, {__mode = "k"})
    self.sessionSequence = 0
    self._lastWaitReason = nil
    self._lastWaitLogMs = -100000
end

function HP_AutoDrivePayrollBridge:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then return end
    self:_sync()
end

function HP_AutoDrivePayrollBridge:deleteMap()
    self.activeByVehicle = setmetatable({}, {__mode = "k"})
end

addModEventListener(HP_AutoDrivePayrollBridge)
