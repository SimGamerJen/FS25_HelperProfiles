-- HP_WorldLocalAvoidance.lua (FS25_HelperProfiles)
-- Alpha 4 local obstacle-avoidance experiment.
--
-- Builds on the validated obstacle-awareness/turn-escape stack. When FOLLOW is
-- persistently blocked, probe short candidate corridors to either side of the
-- direct player line, choose a safe local bypass waypoint, walk to it, then
-- reacquire the player. This is deliberately local steering, not navmesh or
-- global pathfinding.

if HP_WorldObstacleAwareness == nil then return end
if HP_WorldFollow == nil then return end
if HP_WorldTargetNavigation == nil then return end
if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldWorkerManager == nil then return end
if HP_WorldLocalAvoidance ~= nil then return end

HP_WorldLocalAvoidance = {
    version = "2.2.0.0-alpha4-local-avoidance-1",
    planDelayMs = 450,
    retryDelayMs = 300,
    clearResetMs = 2000,
    waypointDistance = 1.65,
    maximumChainSegments = 10,
    statusLogIntervalMs = 1200,
    candidateOffsetsDeg = {45, -45, 70, -70, 95, -95},
    installed = false
}

local Avoid = HP_WorldLocalAvoidance
local Awareness = HP_WorldObstacleAwareness
local Follow = HP_WorldFollow
local Nav = HP_WorldTargetNavigation
local Loco = HP_WorldLocomotionPrototype
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldAvoidance] "
local TWO_PI = math.pi * 2

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function normalizeAngle(value)
    value = tonumber(value) or 0
    while value > math.pi do value = value - TWO_PI end
    while value < -math.pi do value = value + TWO_PI end
    return value
end

local function yawFromDirection(dx, dz)
    if MathUtil ~= nil and MathUtil.getYRotationFromDirection ~= nil then
        local ok, yaw = pcall(MathUtil.getYRotationFromDirection, dx, dz)
        if ok and tonumber(yaw) ~= nil then return normalizeAngle(tonumber(yaw)) end
    end
    return normalizeAngle(math.atan2(dx, dz))
end

local function directionFromYaw(yaw)
    if MathUtil ~= nil and MathUtil.getDirectionFromYRotation ~= nil then
        local ok, dx, dz = pcall(MathUtil.getDirectionFromYRotation, yaw)
        if ok and tonumber(dx) ~= nil and tonumber(dz) ~= nil then
            return tonumber(dx), tonumber(dz)
        end
    end
    return math.sin(tonumber(yaw) or 0), math.cos(tonumber(yaw) or 0)
end

local function getSlot(index)
    if HP_SlotRegistry ~= nil then return HP_SlotRegistry:indexToSlot(index) end
    return tostring(index)
end

local function getPlacement(index)
    if HP_WorldState == nil then return nil end
    return HP_WorldState:getPlacement(index)
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
    if player == nil then return nil, nil end
    if player.getPosition ~= nil then
        local ok, x, _, z = pcall(player.getPosition, player)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z) end
    end
    if player.getMapPositionAndLookYaw ~= nil then
        local ok, x, z = pcall(player.getMapPositionAndLookYaw, player)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z) end
    end
    if player.rootNode ~= nil and player.rootNode ~= 0 and getWorldTranslation ~= nil then
        local ok, x, _, z = pcall(getWorldTranslation, player.rootNode)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z) end
    end
    return nil, nil
end

local function terrainHeight(x, fallbackY, z)
    if g_currentMission ~= nil and g_currentMission.terrainRootNode ~= nil and getTerrainHeightAtWorldPos ~= nil then
        local ok, y = pcall(getTerrainHeightAtWorldPos, g_currentMission.terrainRootNode, x, 0, z)
        if ok and tonumber(y) ~= nil then return tonumber(y) end
    end
    return tonumber(fallbackY) or 0
end

local function walkingSpeed()
    return math.max(0.1, tonumber(Loco.walkSpeed) or 1.35)
end

local function clearObstacleState(state)
    state.obstacleBlocked = nil
    state.obstacleNodeId = nil
    state.obstacleNodeName = nil
    state.obstacleClearMs = nil
    state.obstacleLogMs = nil
end

function Avoid:isDirectRouteBlocked(state, workerX, workerY, workerZ, playerX, playerZ)
    local dx = playerX - workerX
    local dz = playerZ - workerZ
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= 0.001 then return false, nil, nil end
    local yaw = yawFromDirection(dx, dz)
    local blocked, result = Awareness:scan(state.index, state.id,
        workerX, workerY, workerZ, yaw, walkingSpeed())
    return blocked == true, result, yaw
end

function Avoid:chooseCandidate(state, workerX, workerY, workerZ, playerX, playerZ, directYaw)
    local stepDistance = math.max(0.75, tonumber(self.waypointDistance) or 1.65)
    local best = nil
    local probeSummary = {}

    for _, offsetDeg in ipairs(self.candidateOffsetsDeg or {}) do
        local offsetRad = math.rad(tonumber(offsetDeg) or 0)
        local candidateYaw = normalizeAngle(directYaw + offsetRad)
        local blocked, result = Awareness:scan(state.index, state.id,
            workerX, workerY, workerZ, candidateYaw, walkingSpeed())
        local side = offsetDeg >= 0 and "RIGHT" or "LEFT"

        if blocked == true then
            probeSummary[#probeSummary + 1] = string.format("%s%d=BLOCKED:%s",
                side:sub(1, 1), math.abs(offsetDeg),
                tostring(result ~= nil and result.nodeName or "?"))
        else
            local dirX, dirZ = directionFromYaw(candidateYaw)
            local targetX = workerX + dirX * stepDistance
            local targetZ = workerZ + dirZ * stepDistance
            local targetY = terrainHeight(targetX, workerY, targetZ)

            local nextDx = playerX - targetX
            local nextDz = playerZ - targetZ
            local nextDistance = math.sqrt(nextDx * nextDx + nextDz * nextDz)
            local futureBlocked = false
            local futureResult = nil
            if nextDistance > 0.001 then
                local futureYaw = yawFromDirection(nextDx, nextDz)
                futureBlocked, futureResult = Awareness:scan(state.index, state.id,
                    targetX, targetY, targetZ, futureYaw, walkingSpeed())
                futureBlocked = futureBlocked == true
            end

            -- Prefer a candidate whose next leg toward the player is already
            -- clear. If every candidate still sees the obstacle from its end
            -- point, prefer stronger lateral progress and remain on the same
            -- side as prior bypass segments to avoid left/right oscillation.
            local absOffset = math.abs(tonumber(offsetDeg) or 0)
            local score
            if futureBlocked then
                score = 1000 - absOffset * 2
            else
                score = absOffset + nextDistance * 0.01
            end
            if state.hpAvoidanceSide == side then score = score - 12 end

            probeSummary[#probeSummary + 1] = string.format("%s%d=CLEAR%s",
                side:sub(1, 1), absOffset, futureBlocked and "" or "+EXIT")

            if best == nil or score < best.score then
                best = {
                    score = score,
                    side = side,
                    offsetDeg = offsetDeg,
                    yaw = candidateYaw,
                    x = targetX,
                    y = targetY,
                    z = targetZ,
                    futureBlocked = futureBlocked,
                    futureObstacle = futureResult ~= nil and futureResult.nodeName or nil
                }
            end
        end
    end

    log("AVOID PROBE %s %s", tostring(getSlot(state.index)), table.concat(probeSummary, " "))
    return best
end

function Avoid:startBypass(state, workerX, workerY, workerZ, playerX, playerZ, directYaw)
    local segments = math.max(0, tonumber(state.hpAvoidanceSegments) or 0)
    if segments >= math.max(1, tonumber(self.maximumChainSegments) or 10) then
        if state.hpAvoidanceExhausted ~= true then
            state.hpAvoidanceExhausted = true
            log("AVOID HOLD %s maximum local segments reached (%d); waiting for direct route",
                tostring(getSlot(state.index)), segments)
        end
        return false
    end

    local candidate = self:chooseCandidate(state, workerX, workerY, workerZ, playerX, playerZ, directYaw)
    if candidate == nil then
        state.hpAvoidanceRetryMs = tonumber(self.retryDelayMs) or 300
        log("AVOID HOLD %s no clear local candidate; retaining blocked state", tostring(getSlot(state.index)))
        return false
    end

    local obstacleName = state.obstacleNodeName or "unknown"
    local ok, err = Nav:startPoint(state.index, candidate.x, candidate.z, "follow")
    if not ok then
        state.hpAvoidanceRetryMs = tonumber(self.retryDelayMs) or 300
        log("AVOID WAIT %s unable to start %s bypass: %s",
            tostring(getSlot(state.index)), candidate.side, tostring(err))
        return false
    end

    local motion = Loco.motions[state.id]
    if motion == nil then
        state.hpAvoidanceRetryMs = tonumber(self.retryDelayMs) or 300
        log("AVOID WAIT %s bypass motion missing after navigation start", tostring(getSlot(state.index)))
        return false
    end

    segments = segments + 1
    state.hpAvoidanceSegments = segments
    state.hpAvoidanceSide = candidate.side
    state.hpAvoidanceWaitMs = 0
    state.hpAvoidanceRetryMs = 0
    state.hpAvoidanceExhausted = nil
    state.hpAvoidance = {
        x = candidate.x,
        z = candidate.z,
        side = candidate.side,
        offsetDeg = candidate.offsetDeg,
        segment = segments,
        obstacleName = obstacleName,
        futureBlocked = candidate.futureBlocked,
        logMs = 0
    }

    motion.navigationKind = "follow"
    motion.hpAvoidanceWaypoint = true
    motion.hpAvoidanceSide = candidate.side
    motion.targetX = candidate.x
    motion.targetZ = candidate.z

    clearObstacleState(state)
    if Follow.setMode ~= nil then
        Follow:setMode(state, "avoiding", string.format("%s %ddeg segment=%d",
            candidate.side, math.abs(candidate.offsetDeg), segments))
    end
    log("AVOID START %s side=%s offset=%d segment=%d obstacle=%s from=(%.2f,%.2f) waypoint=(%.2f,%.2f) nextLeg=%s",
        tostring(getSlot(state.index)), candidate.side, candidate.offsetDeg, segments,
        tostring(obstacleName), workerX, workerZ, candidate.x, candidate.z,
        candidate.futureBlocked and "blocked" or "clear")
    return true
end

function Avoid:updateActive(state, dt)
    local active = state.hpAvoidance
    if active == nil then return false end

    local motion = Loco.motions[state.id]
    if motion ~= nil then
        -- FOLLOW must not retarget this short waypoint to the moving player.
        -- The validated locomotion/obstacle/turn stack remains sole owner of
        -- movement and may still stop this segment if its corridor becomes blocked.
        motion.navigationKind = "follow"
        motion.hpAvoidanceWaypoint = true
        motion.targetX = active.x
        motion.targetZ = active.z
        if Follow.setMode ~= nil then Follow:setMode(state, "avoiding") end

        active.logMs = (tonumber(active.logMs) or 0) - math.max(0, tonumber(dt) or 0)
        if active.logMs <= 0 then
            active.logMs = tonumber(self.statusLogIntervalMs) or 1200
            log("AVOID MOVE %s side=%s segment=%d pos=(%.2f,%.2f) waypoint=(%.2f,%.2f)",
                tostring(getSlot(state.index)), tostring(active.side), tonumber(active.segment) or 0,
                tonumber(motion.x) or 0, tonumber(motion.z) or 0, active.x, active.z)
        end
        return true
    end

    state.hpAvoidance = nil
    if state.obstacleBlocked == true then
        state.hpAvoidanceRetryMs = tonumber(self.retryDelayMs) or 300
        log("AVOID SEGMENT BLOCKED %s side=%s segment=%d obstacle=%s; replanning",
            tostring(getSlot(state.index)), tostring(active.side), tonumber(active.segment) or 0,
            tostring(state.obstacleNodeName or "unknown"))
        return false
    end

    log("AVOID WAYPOINT REACHED %s side=%s segment=%d waypoint=(%.2f,%.2f); reacquiring player",
        tostring(getSlot(state.index)), tostring(active.side), tonumber(active.segment) or 0,
        active.x, active.z)
    state.hpAvoidanceWaitMs = 0
    state.hpAvoidanceRetryMs = 0
    return false
end

function Avoid:handleFollower(state, dt, originalUpdateFollower, followSelf, ...)
    if state == nil then return originalUpdateFollower(followSelf, state, dt, ...) end
    dt = math.max(0, tonumber(dt) or 0)

    if state.hpAvoidance ~= nil then
        if self:updateActive(state, dt) then return end
        -- If a waypoint completed cleanly, fall through and let normal FOLLOW
        -- immediately reacquire the live player. If the segment was blocked,
        -- the obstacle-aware wrapper below will keep the worker safely held.
    end

    if state.obstacleBlocked == true then
        state.hpAvoidanceClearMs = 0
        state.hpAvoidanceRetryMs = math.max(0, (tonumber(state.hpAvoidanceRetryMs) or 0) - dt)

        local placement = getPlacement(state.index)
        local playerX, playerZ = getPlayerXZ()
        if placement ~= nil and playerX ~= nil and playerZ ~= nil then
            local workerX = tonumber(placement.x) or 0
            local workerY = tonumber(placement.y) or 0
            local workerZ = tonumber(placement.z) or 0
            local directBlocked, _, directYaw = self:isDirectRouteBlocked(
                state, workerX, workerY, workerZ, playerX, playerZ)

            if directBlocked then
                state.hpAvoidanceWaitMs = (tonumber(state.hpAvoidanceWaitMs) or 0) + dt
                if state.hpAvoidanceWaitMs >= (tonumber(self.planDelayMs) or 450)
                    and state.hpAvoidanceRetryMs <= 0 then
                    if self:startBypass(state, workerX, workerY, workerZ, playerX, playerZ, directYaw) then
                        return
                    end
                end
            else
                -- Preserve the already validated direct-clear behaviour. The
                -- obstacle-awareness layer confirms its clear-hold interval and
                -- turn-escape rotates the stationary worker before walking.
                state.hpAvoidanceWaitMs = 0
                state.hpAvoidanceRetryMs = 0
            end
        end

        return originalUpdateFollower(followSelf, state, dt, ...)
    end

    state.hpAvoidanceWaitMs = 0
    state.hpAvoidanceRetryMs = 0

    -- A sustained period of normal direct following closes the current local
    -- avoidance chain. Short re-blocks retain the previous side preference so
    -- a worker skirting a long obstacle does not oscillate left/right.
    local motion = Loco.motions[state.id]
    if motion ~= nil and motion.navigationKind == "follow" and motion.hpAvoidanceWaypoint ~= true then
        state.hpAvoidanceClearMs = (tonumber(state.hpAvoidanceClearMs) or 0) + dt
        if state.hpAvoidanceClearMs >= (tonumber(self.clearResetMs) or 2000) then
            state.hpAvoidanceSegments = 0
            state.hpAvoidanceSide = nil
            state.hpAvoidanceExhausted = nil
        end
    else
        state.hpAvoidanceClearMs = 0
    end

    return originalUpdateFollower(followSelf, state, dt, ...)
end

function Avoid:install()
    if self.installed then return true end

    -- Load after obstacle awareness and turn-escape. This wrapper sits outside
    -- the obstacle-aware FOLLOW wrapper: it gets first chance to create a safe
    -- local bypass, otherwise delegates unchanged to the proven blocked/clear
    -- state machine.
    local originalUpdateFollower = Follow.updateFollower
    function Follow:updateFollower(state, dt, ...)
        return Avoid:handleFollower(state, dt, originalUpdateFollower, self, ...)
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local args = {...}
        local clean = {}
        for _, value in ipairs(args) do
            if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "hpWorld" then clean[#clean + 1] = tostring(value) end
        end
        local sub = string.lower(tostring(clean[1] or "status"))
        if sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha4 local avoidance: FOLLOW automatically samples short left/right bypass corridors when the direct walking route stays blocked.")
            print("[HP] Local avoidance is experimental only: no navmesh/global pathfinding and maximum 10 chained bypass segments.")
            return
        end
        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (local left/right bypass waypoints; no navmesh/global pathfinding)", tostring(self.version))
    return true
end

Avoid:install()
