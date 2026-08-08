-- HP_WorldFollow.lua (FS25_HelperProfiles)
-- Alpha 4 continuous-follow experiment layered on validated direct navigation.
--
-- Commands:
--   hpWorld follow A [standOffMetres]
--   hpWorld unfollow A
--
-- Follow is session-only behaviour. Worker world placement still persists as
-- movement completes/stops, but the follow mode itself is not saved/reloaded.

if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldLocomotionCurved == nil then return end
if HP_WorldTargetNavigation == nil then return end
if HP_WorldWorkerManager == nil then return end
if HP_WorldFollow ~= nil then return end

HP_WorldFollow = {
    version = "2.2.0.0-alpha4-continuous-follow-1",
    followers = {},
    defaultStandOff = 1.8,
    minimumStandOff = 0.75,
    maximumStandOff = 5.0,
    resumeMargin = 0.75,
    maximumFollowDistance = 100.0,
    statusLogIntervalMs = 2000,
    installed = false
}

local Follow = HP_WorldFollow
local Loco = HP_WorldLocomotionPrototype
local Nav = HP_WorldTargetNavigation
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldFollow] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function resolveIndex(value)
    if value ~= nil and tostring(value) ~= "" then
        if HP_SlotRegistry ~= nil then
            local index = HP_SlotRegistry:slotToIndex(value, HP_SlotRegistry.TARGET_COUNT or 20)
            if index ~= nil then return index end
        end
        local numeric = math.floor(tonumber(value) or 0)
        if numeric >= 1 and numeric <= (HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20) then return numeric end
        return nil
    end

    if HelperProfiles ~= nil and HelperProfiles.getSelectedHelper ~= nil and HelperProfiles.getStableIndexForHelper ~= nil then
        local okHelper, helper = pcall(HelperProfiles.getSelectedHelper, HelperProfiles)
        if okHelper and helper ~= nil then
            local okIndex, index = pcall(HelperProfiles.getStableIndexForHelper, HelperProfiles, helper)
            if okIndex and tonumber(index) ~= nil then return math.floor(tonumber(index)) end
        end
    end
    return nil
end

local function getCanonicalId(index)
    if HP_SlotRegistry ~= nil then return HP_SlotRegistry:canonicalId(index) end
    return string.format("helper%02d", math.floor(tonumber(index) or 0))
end

local function getSlot(index)
    if HP_SlotRegistry ~= nil then return HP_SlotRegistry:indexToSlot(index) end
    return tostring(index)
end

local function findLocalPlayer()
    if rawget(_G, "g_localPlayer") ~= nil and g_localPlayer ~= nil then return g_localPlayer end
    local mission = g_currentMission
    if mission == nil then return nil end
    if mission.player ~= nil then return mission.player end
    if mission.controlledPlayer ~= nil then return mission.controlledPlayer end

    local playerSystem = mission.playerSystem
    if playerSystem ~= nil then
        for _, player in pairs(playerSystem.players or {}) do
            if player ~= nil and (player.isOwner == true or player.isLocallyControlled == true) then return player end
        end
        for _, player in pairs(playerSystem.players or {}) do
            if player ~= nil then return player end
        end
    end
    return nil
end

local function getPlayerXZ()
    local player = findLocalPlayer()
    if player == nil then return nil, nil, "local-player-unavailable" end

    if player.getPosition ~= nil then
        local ok, x, _, z = pcall(player.getPosition, player)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z), nil end
    end
    if player.getMapPositionAndLookYaw ~= nil then
        local ok, x, z = pcall(player.getMapPositionAndLookYaw, player)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z), nil end
    end
    if player.rootNode ~= nil and player.rootNode ~= 0 and getWorldTranslation ~= nil then
        local ok, x, _, z = pcall(getWorldTranslation, player.rootNode)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z), nil end
    end
    return nil, nil, "player-position-unavailable"
end

local function getWorkerXZ(index, id)
    local motion = id ~= nil and Loco.motions[id] or nil
    if motion ~= nil and tonumber(motion.x) ~= nil and tonumber(motion.z) ~= nil then
        return tonumber(motion.x), tonumber(motion.z), motion
    end

    if HP_WorldState ~= nil then
        local placement = HP_WorldState:getPlacement(index)
        if placement ~= nil and tonumber(placement.x) ~= nil and tonumber(placement.z) ~= nil then
            return tonumber(placement.x), tonumber(placement.z), nil
        end
    end
    return nil, nil, nil
end

local function targetBeforePlayer(workerX, workerZ, playerX, playerZ, standOff)
    local dx = playerX - workerX
    local dz = playerZ - workerZ
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= 0.0001 then return playerX, playerZ, distance end
    local inv = 1 / distance
    return playerX - dx * inv * standOff,
           playerZ - dz * inv * standOff,
           distance
end

function Follow:setMode(state, mode, detail)
    mode = tostring(mode or "unknown")
    if state.mode == mode then return end
    state.mode = mode
    log("FOLLOW STATE %s -> %s%s",
        tostring(getSlot(state.index)), mode,
        detail ~= nil and (" (" .. tostring(detail) .. ")") or "")
end

function Follow:updateFollower(state, dt)
    if state == nil then return end

    local index = state.index
    local id = state.id
    local playerX, playerZ, playerErr = getPlayerXZ()
    if playerX == nil or playerZ == nil then
        self:setMode(state, "paused", playerErr or "player-unavailable")
        return
    end

    local workerX, workerZ, motion = getWorkerXZ(index, id)
    if workerX == nil or workerZ == nil then
        self.followers[id] = nil
        log("FOLLOW STOP %s reason=worker-not-placed", tostring(getSlot(index)))
        return
    end

    local targetX, targetZ, distance = targetBeforePlayer(workerX, workerZ, playerX, playerZ, state.standOff)
    state.lastDistance = distance
    state.lastPlayerX = playerX
    state.lastPlayerZ = playerZ

    local maxDistance = math.max(5, tonumber(self.maximumFollowDistance) or 100)
    if distance > maxDistance then
        if motion ~= nil and motion.navigationKind == "follow" then
            Loco:finishMotion(motion, "follow-out-of-range", true)
            motion = nil
        end
        self:setMode(state, "out-of-range", string.format("distance=%.2f", distance))
        return
    end

    -- If the player comes inside the desired stand-off while the worker is
    -- moving, stop immediately. Otherwise the direct steering controller may
    -- walk through the player before the moving target has time to settle.
    if distance <= state.standOff then
        if motion ~= nil and motion.navigationKind == "follow" then
            Loco:finishMotion(motion, "follow-stand-off", true)
            motion = nil
        end
        self:setMode(state, "waiting", string.format("distance=%.2f", distance))
        return
    end

    if motion ~= nil then
        if motion.navigationKind ~= "follow" then
            self:setMode(state, "paused", "other-motion-active")
            return
        end

        -- Continuous retarget: the validated curved controller remains sole
        -- owner of speed/yaw/animation. We only move its destination point.
        motion.targetX = targetX
        motion.targetZ = targetZ
        motion.navigationKind = "follow"
        self:setMode(state, "moving")

        state.logMs = (tonumber(state.logMs) or 0) - math.max(0, tonumber(dt) or 0)
        if state.logMs <= 0 then
            state.logMs = tonumber(self.statusLogIntervalMs) or 2000
            log("FOLLOW %s distance=%.2f standOff=%.2f worker=(%.2f,%.2f) player=(%.2f,%.2f) target=(%.2f,%.2f)",
                tostring(getSlot(index)), distance, state.standOff,
                workerX, workerZ, playerX, playerZ, targetX, targetZ)
        end
        return
    end

    local resumeDistance = state.standOff + math.max(0.25, tonumber(self.resumeMargin) or 0.75)
    if distance <= resumeDistance then
        self:setMode(state, "waiting", string.format("distance=%.2f resumeAt=%.2f", distance, resumeDistance))
        return
    end

    local ok, err = Nav:startPoint(index, targetX, targetZ, "follow")
    if ok then
        local started = Loco.motions[id]
        if started ~= nil then started.navigationKind = "follow" end
        state.logMs = 0
        self:setMode(state, "moving", string.format("distance=%.2f", distance))
        log("FOLLOW RESUME %s distance=%.2f standOff=%.2f target=(%.2f,%.2f)",
            tostring(getSlot(index)), distance, state.standOff, targetX, targetZ)
    else
        if err == "target-too-close" or err == "already-near-player" then
            self:setMode(state, "waiting", tostring(err))
        else
            if state.lastError ~= tostring(err) then
                state.lastError = tostring(err)
                log("FOLLOW WAIT %s unable-to-move: %s", tostring(getSlot(index)), tostring(err))
            end
            self:setMode(state, "paused", tostring(err))
        end
    end
end

function Follow:start(indexOrSlot, standOff)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local id = getCanonicalId(index)
    if id == nil then return false, "invalid-helper-id" end

    if HP_WorldState == nil or HP_WorldState:getPlacement(index) == nil then
        return false, "worker-not-placed"
    end

    local existingMotion = Loco.motions[id]
    if existingMotion ~= nil and existingMotion.navigationKind ~= "follow" then
        return false, "worker-already-walking"
    end

    local playerX, playerZ, playerErr = getPlayerXZ()
    if playerX == nil or playerZ == nil then return false, playerErr or "player-position-unavailable" end

    standOff = clamp(standOff or self.defaultStandOff, self.minimumStandOff, self.maximumStandOff)

    local state = self.followers[id]
    if state == nil then
        state = {
            id = id,
            index = index,
            standOff = standOff,
            mode = nil,
            logMs = 0,
            lastError = nil
        }
        self.followers[id] = state
        log("FOLLOW START %s standOff=%.2f resumeAt=%.2f",
            tostring(getSlot(index)), standOff, standOff + (tonumber(self.resumeMargin) or 0.75))
    else
        state.standOff = standOff
        state.lastError = nil
        log("FOLLOW UPDATE %s standOff=%.2f resumeAt=%.2f",
            tostring(getSlot(index)), standOff, standOff + (tonumber(self.resumeMargin) or 0.75))
    end

    self:updateFollower(state, 0)
    return true, nil
end

function Follow:stop(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local id = getCanonicalId(index)
    local state = id ~= nil and self.followers[id] or nil
    if state == nil then return false, "worker-not-following" end

    local motion = Loco.motions[id]
    if motion ~= nil and motion.navigationKind == "follow" then
        Loco:finishMotion(motion, "follow-cancelled", true)
    end

    self.followers[id] = nil
    log("FOLLOW STOP %s reason=requested", tostring(getSlot(index)))
    return true, nil
end

local function normalizeCommandArgs(...)
    local args = {...}
    local clean = {}
    for _, value in ipairs(args) do
        if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "hpWorld" then
            clean[#clean + 1] = tostring(value)
        end
    end
    return clean[1], clean[2], clean[3], clean[4]
end

function Follow:install()
    if self.installed then return true end

    -- Install outside the locomotion manager wrapper. Follow retargeting runs
    -- BEFORE the validated locomotion update each frame, so the curved mover
    -- sees the newest player-relative target on that same frame.
    local originalManagerUpdate = Manager.update
    function Manager:update(dt, ...)
        local snapshot = {}
        for _, state in pairs(Follow.followers) do snapshot[#snapshot + 1] = state end
        for _, state in ipairs(snapshot) do Follow:updateFollower(state, dt) end
        return originalManagerUpdate(self, dt, ...)
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot, value1 = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))

        if sub == "follow" or sub == "followme" or sub == "trail" then
            local ok, err = Follow:start(slot, value1)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld follow %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "unfollow" or sub == "followstop" or sub == "stopfollow" then
            local ok, err = Follow:stop(slot)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld unfollow %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha4 continuous follow: hpWorld follow [slot] [standOffMetres]")
            print("[HP] Alpha4 continuous follow: hpWorld unfollow [slot]")
            print("[HP] Follow is session-only and uses direct steering; no obstacle avoidance/pathfinding yet.")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (live player retargeting; stop/resume hysteresis; direct steering only)", tostring(self.version))
    return true
end

Follow:install()
