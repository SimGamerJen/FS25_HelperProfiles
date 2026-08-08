-- HP_WorldObstacleAwareness.lua (FS25_HelperProfiles)
-- Alpha 4 environment-awareness experiment.
--
-- Purpose: detect a solid obstacle in the worker's immediate walking corridor
-- and stop before contact. This deliberately does NOT route around obstacles.
-- Follow mode waits while blocked and may resume once the direct corridor is
-- clear again. Other one-shot motions simply stop at the obstruction.
--
-- Diagnostic command:
--   hpWorld sense [slot]

if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldWorkerManager == nil then return end
if HP_WorldObstacleAwareness ~= nil then return end

HP_WorldObstacleAwareness = {
    version = "2.2.0.0-alpha4-obstacle-awareness-1",
    minimumLookAhead = 1.15,
    maximumLookAhead = 2.00,
    speedLookAheadFactor = 0.55,
    nearOffset = 0.20,
    halfWidth = 0.38,
    halfHeight = 0.70,
    centerHeight = 0.92,
    clearHoldMs = 350,
    blockedLogIntervalMs = 2000,
    installed = false,
    warnedUnavailable = false
}

local Awareness = HP_WorldObstacleAwareness
local Loco = HP_WorldLocomotionPrototype
local Manager = HP_WorldWorkerManager
local Follow = HP_WorldFollow
local LOG = "[FS25_HelperProfiles/WorldObstacle] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function normalizeAngle(value)
    local twoPi = math.pi * 2
    value = tonumber(value) or 0
    while value > math.pi do value = value - twoPi end
    while value < -math.pi do value = value + twoPi end
    return value
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

local function yawFromDirection(dx, dz)
    if MathUtil ~= nil and MathUtil.getYRotationFromDirection ~= nil then
        local ok, yaw = pcall(MathUtil.getYRotationFromDirection, dx, dz)
        if ok and tonumber(yaw) ~= nil then return normalizeAngle(tonumber(yaw)) end
    end
    return normalizeAngle(math.atan2(dx, dz))
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

local function isNodeWithin(nodeId, rootId)
    nodeId = tonumber(nodeId) or 0
    rootId = tonumber(rootId) or 0
    if nodeId == 0 or rootId == 0 then return false end
    local current = nodeId
    local guard = 0
    while current ~= nil and current ~= 0 and guard < 64 do
        if current == rootId then return true end
        if getParent == nil then break end
        local ok, parent = pcall(getParent, current)
        if not ok or parent == nil or parent == current then break end
        current = parent
        guard = guard + 1
    end
    return false
end

local function safeNodeName(nodeId)
    if getName ~= nil and tonumber(nodeId) ~= nil and tonumber(nodeId) ~= 0 then
        local ok, name = pcall(getName, nodeId)
        if ok and name ~= nil and tostring(name) ~= "" then return tostring(name) end
    end
    return "node:" .. tostring(nodeId)
end

local function getObstacleMask()
    if CollisionFlag == nil or bit32 == nil or bit32.bor == nil then return nil end
    local flags = {}
    if CollisionFlag.STATIC_OBJECT ~= nil then flags[#flags + 1] = CollisionFlag.STATIC_OBJECT end
    if CollisionFlag.BUILDING ~= nil then flags[#flags + 1] = CollisionFlag.BUILDING end
    if CollisionFlag.VEHICLE ~= nil then flags[#flags + 1] = CollisionFlag.VEHICLE end
    if #flags == 0 then return nil end
    local mask = flags[1]
    for i = 2, #flags do mask = bit32.bor(mask, flags[i]) end
    return mask
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
    if player.rootNode ~= nil and player.rootNode ~= 0 and getWorldTranslation ~= nil then
        local ok, x, _, z = pcall(getWorldTranslation, player.rootNode)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then return tonumber(x), tonumber(z) end
    end
    return nil, nil
end

function Awareness:scan(index, id, x, y, z, yaw, speed)
    if overlapBox == nil then
        if not self.warnedUnavailable then
            self.warnedUnavailable = true
            log("Sensing unavailable: overlapBox is not exposed by this runtime")
        end
        return false, nil
    end

    local mask = getObstacleMask()
    if mask == nil then
        if not self.warnedUnavailable then
            self.warnedUnavailable = true
            log("Sensing unavailable: required collision flags are missing")
        end
        return false, nil
    end

    x, y, z = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
    yaw = tonumber(yaw) or 0
    speed = math.max(0, tonumber(speed) or 0)

    local lookAhead = clamp((tonumber(self.minimumLookAhead) or 1.15) + speed * (tonumber(self.speedLookAheadFactor) or 0.55),
        tonumber(self.minimumLookAhead) or 1.15,
        tonumber(self.maximumLookAhead) or 2.0)
    local nearOffset = clamp(self.nearOffset or 0.20, 0.05, math.max(0.06, lookAhead - 0.05))
    local halfDepth = math.max(0.05, (lookAhead - nearOffset) * 0.5)
    local centerOffset = nearOffset + halfDepth
    local dirX, dirZ = directionFromYaw(yaw)
    local centerX = x + dirX * centerOffset
    local centerZ = z + dirZ * centerOffset
    local centerY = y + (tonumber(self.centerHeight) or 0.92)

    local instance = Manager.instancesByCanonicalId ~= nil and Manager.instancesByCanonicalId[id] or nil
    local graphicsRoot = instance ~= nil and instance.graphics ~= nil and instance.graphics.graphicsRootNode or nil

    local result = {
        blocked = false,
        nodeId = nil,
        nodeName = nil,
        group = nil,
        lookAhead = lookAhead,
        centerX = centerX,
        centerY = centerY,
        centerZ = centerZ
    }

    local callbackTarget = {}
    callbackTarget.overlapCallback = function(_, hitObjectId, ...)
        hitObjectId = tonumber(hitObjectId) or 0
        if hitObjectId == 0 then return true end
        if graphicsRoot ~= nil and isNodeWithin(hitObjectId, graphicsRoot) then return true end
        if g_currentMission ~= nil and g_currentMission.terrainRootNode ~= nil and hitObjectId == g_currentMission.terrainRootNode then return true end

        result.blocked = true
        result.nodeId = hitObjectId
        result.nodeName = safeNodeName(hitObjectId)
        if getCollisionFilterGroup ~= nil then
            local okGroup, group = pcall(getCollisionFilterGroup, hitObjectId)
            if okGroup then result.group = group end
        end
        return false
    end

    local ok, err = pcall(overlapBox,
        centerX, centerY, centerZ,
        0, yaw, 0,
        tonumber(self.halfWidth) or 0.38,
        tonumber(self.halfHeight) or 0.70,
        halfDepth,
        "overlapCallback", callbackTarget, mask,
        true, true, true, true)

    if not ok then
        if not self.warnedUnavailable then
            self.warnedUnavailable = true
            log("Sensing call failed: %s", tostring(err))
        end
        return false, nil
    end

    return result.blocked, result
end

function Awareness:markFollowBlocked(motion, result)
    if Follow == nil or motion == nil then return end
    local state = Follow.followers ~= nil and Follow.followers[motion.id] or nil
    if state == nil then return end

    state.obstacleBlocked = true
    state.obstacleNodeId = result ~= nil and result.nodeId or nil
    state.obstacleNodeName = result ~= nil and result.nodeName or "unknown"
    state.obstacleClearMs = 0
    state.obstacleLogMs = 0
    if Follow.setMode ~= nil then
        Follow:setMode(state, "blocked", "obstacle=" .. tostring(state.obstacleNodeName))
    end
end

function Awareness:handleMotion(motion, dt, originalUpdateMotion, locoSelf, ...)
    if motion == nil then return originalUpdateMotion(locoSelf, motion, dt, ...) end

    local blocked, result = self:scan(motion.index, motion.id, motion.x, motion.y, motion.z, motion.yaw, motion.speed)
    if blocked then
        if motion.navigationKind == "follow" then self:markFollowBlocked(motion, result) end
        log("OBSTACLE STOP %s kind=%s obstacle=%s node=%s group=%s lookAhead=%.2f pos=(%.2f,%.2f)",
            tostring(getSlot(motion.index)), tostring(motion.navigationKind or motion.mode or "walk"),
            tostring(result ~= nil and result.nodeName or "unknown"),
            tostring(result ~= nil and result.nodeId or "?"),
            tostring(result ~= nil and result.group or "?"),
            tonumber(result ~= nil and result.lookAhead or 0) or 0,
            tonumber(motion.x) or 0, tonumber(motion.z) or 0)
        Loco:finishMotion(motion, "obstacle-blocked", true)
        return
    end

    return originalUpdateMotion(locoSelf, motion, dt, ...)
end

function Awareness:updateBlockedFollower(state, dt)
    local placement = getPlacement(state.index)
    if placement == nil then
        state.obstacleBlocked = nil
        return false
    end

    local playerX, playerZ = getPlayerXZ()
    if playerX == nil or playerZ == nil then
        if Follow ~= nil and Follow.setMode ~= nil then Follow:setMode(state, "blocked", "player-unavailable") end
        return true
    end

    local workerX = tonumber(placement.x) or 0
    local workerY = tonumber(placement.y) or 0
    local workerZ = tonumber(placement.z) or 0
    local dx = playerX - workerX
    local dz = playerZ - workerZ
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= 0.001 then return true end

    -- Test the CURRENT direct route to the player, not merely the worker's old
    -- facing. If the player walks around the obstruction the route can clear.
    local desiredYaw = yawFromDirection(dx, dz)
    local blocked, result = self:scan(state.index, state.id, workerX, workerY, workerZ, desiredYaw, 0)

    if blocked then
        state.obstacleClearMs = 0
        state.obstacleNodeId = result ~= nil and result.nodeId or state.obstacleNodeId
        state.obstacleNodeName = result ~= nil and result.nodeName or state.obstacleNodeName
        state.obstacleLogMs = (tonumber(state.obstacleLogMs) or 0) - math.max(0, tonumber(dt) or 0)
        if state.obstacleLogMs <= 0 then
            state.obstacleLogMs = tonumber(self.blockedLogIntervalMs) or 2000
            log("OBSTACLE HOLD %s obstacle=%s distanceToPlayer=%.2f", tostring(getSlot(state.index)), tostring(state.obstacleNodeName or "unknown"), distance)
        end
        if Follow ~= nil and Follow.setMode ~= nil then
            Follow:setMode(state, "blocked", "obstacle=" .. tostring(state.obstacleNodeName or "unknown"))
        end
        return true
    end

    state.obstacleClearMs = (tonumber(state.obstacleClearMs) or 0) + math.max(0, tonumber(dt) or 0)
    if state.obstacleClearMs < (tonumber(self.clearHoldMs) or 350) then
        if Follow ~= nil and Follow.setMode ~= nil then Follow:setMode(state, "blocked", "clear-confirming") end
        return true
    end

    log("OBSTACLE CLEAR %s previous=%s; follow may resume", tostring(getSlot(state.index)), tostring(state.obstacleNodeName or "unknown"))
    state.obstacleBlocked = nil
    state.obstacleNodeId = nil
    state.obstacleNodeName = nil
    state.obstacleClearMs = nil
    state.obstacleLogMs = nil
    return false
end

function Awareness:sense(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end
    local placement = getPlacement(index)
    if placement == nil then return false, "worker-not-placed" end
    local id = getCanonicalId(index)
    local blocked, result = self:scan(index, id,
        placement.x, placement.y, placement.z, placement.yaw, 0)
    if blocked then
        log("SENSE %s -> BLOCKED obstacle=%s node=%s group=%s lookAhead=%.2f",
            tostring(getSlot(index)), tostring(result.nodeName), tostring(result.nodeId), tostring(result.group or "?"), tonumber(result.lookAhead) or 0)
    else
        log("SENSE %s -> CLEAR lookAhead=%.2f", tostring(getSlot(index)), tonumber(result ~= nil and result.lookAhead or self.minimumLookAhead) or 0)
    end
    return true, blocked and "blocked" or "clear"
end

local function normalizeCommandArgs(...)
    local args = {...}
    local clean = {}
    for _, value in ipairs(args) do
        if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "hpWorld" then clean[#clean + 1] = tostring(value) end
    end
    return clean[1], clean[2], clean[3]
end

function Awareness:install()
    if self.installed then return true end

    local originalUpdateMotion = Loco.updateMotion
    function Loco:updateMotion(motion, dt, ...)
        return Awareness:handleMotion(motion, dt, originalUpdateMotion, self, ...)
    end

    if Follow ~= nil and Follow.updateFollower ~= nil then
        local originalUpdateFollower = Follow.updateFollower
        function Follow:updateFollower(state, dt, ...)
            if state ~= nil and state.obstacleBlocked == true then
                if Awareness:updateBlockedFollower(state, dt) then return end
            end
            return originalUpdateFollower(self, state, dt, ...)
        end
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))
        if sub == "sense" or sub == "obstacle" or sub == "obstacles" then
            local ok, result = Awareness:sense(slot)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld sense %s -> %s%s", tostring(label), tostring(ok == true), result ~= nil and (" (" .. tostring(result) .. ")") or ""))
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha4 obstacle awareness: hpWorld sense [slot]")
            print("[HP] Moving workers stop when STATIC_OBJECT / BUILDING / VEHICLE collision blocks the direct corridor.")
            print("[HP] FOLLOW waits while blocked and resumes only after the direct corridor stays clear briefly; no avoidance/pathfinding yet.")
            return
        end
        return originalConsole(self, ...)
    end

    self.installed = true
    local mask = getObstacleMask()
    log("Loaded %s (forward overlap corridor; stop/hold only; collisionMask=%s)", tostring(self.version), tostring(mask or "unavailable"))
    return true
end

Awareness:install()
