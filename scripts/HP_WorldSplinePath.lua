-- HP_WorldSplinePath.lua (FS25_HelperProfiles)
-- Alpha 6 experimental spline-guided path execution.
--
-- This does NOT replace normal COME/FOLLOW. It creates a temporary GIANTS
-- cubic spline and continuously feeds the validated curved locomotion layer a
-- short look-ahead target on that spline. The experiment isolates whether a
-- spline/tangent-led path produces the smoother flow observed in pedestrians.
--
-- Commands:
--   hpWorld smoothcome [slot] [standOffMetres]
--   hpWorld smoothgoto [slot] <x> <z>
--   hpWorld smoothstop [slot]

if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldLocomotionCurved == nil then return end
if HP_WorldTargetNavigation == nil then return end
if HP_WorldWorkerManager == nil then return end
if HP_WorldSplinePath ~= nil then return end

HP_WorldSplinePath = {
    version = "2.2.0.0-alpha6-spline-path-1",
    paths = {},
    lookAheadDistance = 1.05,
    finishDirectDistance = 0.90,
    minimumPathDistance = 1.0,
    maximumPathDistance = 100.0,
    startTangentMin = 0.8,
    startTangentMax = 3.2,
    logIntervalMs = 1000,
    installed = false
}

local Path = HP_WorldSplinePath
local Loco = HP_WorldLocomotionPrototype
local Nav = HP_WorldTargetNavigation
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldSplinePath] "

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

local function normalizeAngle(value)
    value = tonumber(value) or 0
    local twoPi = math.pi * 2
    while value > math.pi do value = value - twoPi end
    while value < -math.pi do value = value + twoPi end
    return value
end

local function directionFromYaw(yaw)
    if MathUtil ~= nil and MathUtil.getDirectionFromYRotation ~= nil then
        local ok, dx, dz = pcall(MathUtil.getDirectionFromYRotation, yaw)
        if ok and tonumber(dx) ~= nil and tonumber(dz) ~= nil then return tonumber(dx), tonumber(dz) end
    end
    return math.sin(yaw), math.cos(yaw)
end

local function terrainY(x, fallbackY, z)
    local terrainNode = rawget(_G, "g_terrainNode")
    if terrainNode ~= nil and terrainNode ~= 0 and getTerrainHeightAtWorldPos ~= nil then
        local ok, value = pcall(getTerrainHeightAtWorldPos, terrainNode, x, 0, z)
        if ok and tonumber(value) ~= nil then return tonumber(value) end
    end
    return tonumber(fallbackY) or 0
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

local function getWorkerPose(index)
    local id = getCanonicalId(index)
    local instance = id ~= nil and Manager.instancesByCanonicalId ~= nil and Manager.instancesByCanonicalId[id] or nil
    if instance == nil or instance.loading == true or instance.graphics == nil then
        return nil, "worker-not-visible"
    end

    local placement = HP_WorldState ~= nil and HP_WorldState:getPlacement(index) or nil
    if placement == nil then return nil, "worker-not-placed" end

    local x = tonumber(placement.x)
    local y = tonumber(placement.y)
    local z = tonumber(placement.z)
    local yaw = tonumber(instance.presenceCurrentYaw) or tonumber(placement.yaw) or 0

    local root = instance.graphics.graphicsRootNode
    if root ~= nil and root ~= 0 and getWorldTranslation ~= nil then
        local ok, px, py, pz = pcall(getWorldTranslation, root)
        if ok and tonumber(px) ~= nil and tonumber(pz) ~= nil then
            x, z = tonumber(px), tonumber(pz)
            if tonumber(py) ~= nil then y = tonumber(py) end
        end
    end

    if x == nil or z == nil then return nil, "worker-pose-unavailable" end
    y = terrainY(x, y or 0, z)
    return {x=x, y=y, z=z, yaw=normalizeAngle(yaw), id=id, instance=instance}, nil
end

local function splineApiAvailable()
    return createSplineFromEditPoints ~= nil
        and getSplineLength ~= nil
        and getClosestSplinePosition ~= nil
        and getSplinePositionWithDistance ~= nil
        and getSplinePosition ~= nil
end

local function deleteSpline(state)
    if state == nil or state.spline == nil or state.spline == 0 then return end
    if delete ~= nil then pcall(delete, state.spline) end
    state.spline = nil
end

local function buildSpline(startPose, targetX, targetZ)
    if not splineApiAvailable() then return nil, "required-spline-api-unavailable" end
    if getRootNode == nil then return nil, "scene-root-unavailable" end

    local dx = targetX - startPose.x
    local dz = targetZ - startPose.z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < Path.minimumPathDistance then return nil, "target-too-close" end
    if distance > Path.maximumPathDistance then return nil, "target-too-far" end

    local directX, directZ = dx / distance, dz / distance
    local faceX, faceZ = directionFromYaw(startPose.yaw)
    local tangent = clamp(distance * 0.30, Path.startTangentMin, Path.startTangentMax)

    -- Four edit points give the cubic spline a meaningful start tangent while
    -- still converging onto the destination direction. The first intermediate
    -- point follows the worker's current facing; the second approaches the end
    -- along the overall route. This is path shaping, not obstacle avoidance.
    local p0x, p0z = startPose.x, startPose.z
    local p1x, p1z = p0x + faceX * tangent, p0z + faceZ * tangent
    local p3x, p3z = targetX, targetZ
    local p2x, p2z = p3x - directX * tangent, p3z - directZ * tangent

    local p0y = terrainY(p0x, startPose.y, p0z)
    local p1y = terrainY(p1x, p0y, p1z)
    local p2y = terrainY(p2x, p1y, p2z)
    local p3y = terrainY(p3x, p2y, p3z)

    local editPoints = {
        p0x, p0y, p0z,
        p1x, p1y, p1z,
        p2x, p2y, p2z,
        p3x, p3y, p3z
    }

    local okRoot, root = pcall(getRootNode)
    if not okRoot or root == nil or root == 0 then return nil, "scene-root-unavailable" end

    local okSpline, spline = pcall(createSplineFromEditPoints, root, editPoints, false, false)
    if not okSpline or spline == nil or spline == 0 then
        return nil, "createSplineFromEditPoints-failed: " .. tostring(spline)
    end

    if setVisibility ~= nil then pcall(setVisibility, spline, false) end

    local okLength, length = pcall(getSplineLength, spline)
    if not okLength or tonumber(length) == nil then
        if delete ~= nil then pcall(delete, spline) end
        return nil, "getSplineLength-failed"
    end

    return {
        spline = spline,
        pathLength = tonumber(length),
        finalX = p3x,
        finalY = p3y,
        finalZ = p3z,
        startX = p0x,
        startY = p0y,
        startZ = p0z,
        tangent = tangent,
        editPoints = editPoints,
        splineTime = 0,
        logMs = 0,
        finishing = false
    }, nil
end

local function updateLookAhead(state, motion)
    if state == nil or motion == nil or state.spline == nil then return false, "path-state-invalid" end

    local dxEnd = state.finalX - motion.x
    local dzEnd = state.finalZ - motion.z
    local directEndDistance = math.sqrt(dxEnd * dxEnd + dzEnd * dzEnd)

    if directEndDistance <= Path.finishDirectDistance then
        state.finishing = true
        motion.targetX = state.finalX
        motion.targetY = state.finalY
        motion.targetZ = state.finalZ
        return true, nil
    end

    local okClosest, _, _, _, closestT = pcall(
        getClosestSplinePosition,
        state.spline,
        motion.x, motion.y, motion.z,
        0.02
    )
    if not okClosest or tonumber(closestT) == nil then
        return false, "getClosestSplinePosition-failed"
    end

    state.splineTime = clamp(closestT, 0, 1)
    local lookAhead = math.max(0.35, tonumber(Path.lookAheadDistance) or 1.05)
    local okAhead, tx, ty, tz, aheadT = pcall(
        getSplinePositionWithDistance,
        state.spline,
        state.splineTime,
        lookAhead,
        true,
        0.01
    )

    if okAhead and tonumber(tx) ~= nil and tonumber(tz) ~= nil and tonumber(aheadT) ~= nil then
        motion.targetX = tonumber(tx)
        motion.targetY = terrainY(tonumber(tx), tonumber(ty) or motion.y, tonumber(tz))
        motion.targetZ = tonumber(tz)
        state.lookAheadT = tonumber(aheadT)
    else
        -- At/near the end the distance query may not be able to find a point
        -- a full look-ahead metre ahead. Fall back to the spline endpoint.
        state.finishing = true
        motion.targetX = state.finalX
        motion.targetY = state.finalY
        motion.targetZ = state.finalZ
    end

    return true, nil
end

function Path:startPoint(indexOrSlot, targetX, targetZ, kind)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    targetX = tonumber(targetX)
    targetZ = tonumber(targetZ)
    if targetX == nil or targetZ == nil then return false, "invalid-target-coordinates" end

    local pose, poseErr = getWorkerPose(index)
    if pose == nil then return false, poseErr end
    if Loco.motions[pose.id] ~= nil then return false, "worker-already-walking" end

    local state, splineErr = buildSpline(pose, targetX, targetZ)
    if state == nil then return false, splineErr end

    local okStart, startErr = Nav:startPoint(index, targetX, targetZ, "spline-path")
    if not okStart then
        deleteSpline(state)
        return false, startErr
    end

    local motion = Loco.motions[pose.id]
    if motion == nil then
        deleteSpline(state)
        return false, "motion-initialization-failed"
    end

    state.id = pose.id
    state.index = index
    state.kind = tostring(kind or "smoothgoto")
    self.paths[pose.id] = state
    motion.navigationKind = "spline-path"

    local okAhead, aheadErr = updateLookAhead(state, motion)
    if not okAhead then
        self.paths[pose.id] = nil
        deleteSpline(state)
        Loco:finishMotion(motion, "spline-lookahead-init-failed", true)
        return false, aheadErr
    end

    log("PATH START %s kind=%s length=%.2f tangent=%.2f from=(%.2f,%.2f) final=(%.2f,%.2f) firstTarget=(%.2f,%.2f)",
        tostring(getSlot(index)), state.kind, state.pathLength, state.tangent,
        state.startX, state.startZ, state.finalX, state.finalZ,
        tonumber(motion.targetX) or 0, tonumber(motion.targetZ) or 0)
    return true, nil
end

function Path:startCome(indexOrSlot, standOff)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local pose, poseErr = getWorkerPose(index)
    if pose == nil then return false, poseErr end

    local playerX, playerZ, playerErr = getPlayerXZ()
    if playerX == nil or playerZ == nil then return false, playerErr end

    standOff = clamp(standOff or (Nav.defaultStandOff or 1.8), Nav.minimumStandOff or 0.75, Nav.maximumStandOff or 5.0)
    local dx = playerX - pose.x
    local dz = playerZ - pose.z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= standOff + 0.20 then return false, "already-near-player" end

    local targetX = playerX - (dx / distance) * standOff
    local targetZ = playerZ - (dz / distance) * standOff
    local ok, err = self:startPoint(index, targetX, targetZ, "smoothcome")
    if ok then
        log("SMOOTH COME %s player=(%.2f,%.2f) standOff=%.2f final=(%.2f,%.2f)",
            tostring(getSlot(index)), playerX, playerZ, standOff, targetX, targetZ)
    end
    return ok, err
end

function Path:stop(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end
    local id = getCanonicalId(index)
    local state = id ~= nil and self.paths[id] or nil
    local motion = id ~= nil and Loco.motions[id] or nil
    if state == nil and (motion == nil or motion.navigationKind ~= "spline-path") then
        return false, "worker-not-on-spline-path"
    end

    if motion ~= nil then
        Loco:finishMotion(motion, "spline-path-cancelled", true)
    else
        self.paths[id] = nil
        deleteSpline(state)
    end
    return true, nil
end

function Path:updateState(state, dt)
    if state == nil or state.id == nil then return end
    local motion = Loco.motions[state.id]
    if motion == nil or motion.navigationKind ~= "spline-path" then
        self.paths[state.id] = nil
        deleteSpline(state)
        return
    end

    if not state.finishing then
        local ok, err = updateLookAhead(state, motion)
        if not ok then
            log("PATH ERROR %s: %s", tostring(getSlot(state.index)), tostring(err))
            Loco:finishMotion(motion, "spline-path-update-failed", true)
            return
        end
    end

    state.logMs = (tonumber(state.logMs) or 0) - math.max(0, tonumber(dt) or 0)
    if state.logMs <= 0 then
        state.logMs = tonumber(self.logIntervalMs) or 1000
        local dx = state.finalX - motion.x
        local dz = state.finalZ - motion.z
        log("PATH %s t=%.4f aheadT=%s finishing=%s speed=%.3f finalDistance=%.2f target=(%.2f,%.2f)",
            tostring(getSlot(state.index)), tonumber(state.splineTime) or 0,
            state.lookAheadT ~= nil and string.format("%.4f", state.lookAheadT) or "-",
            tostring(state.finishing == true), tonumber(motion.speed) or 0,
            math.sqrt(dx * dx + dz * dz),
            tonumber(motion.targetX) or 0, tonumber(motion.targetZ) or 0)
    end
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

function Path:install()
    if self.installed then return true end

    -- Retarget spline-guided motions before the validated movement stack runs.
    -- The curved locomotion controller remains the sole owner of worker pose,
    -- speed, yaw and HumanGraphicsComponent state.
    local originalManagerUpdate = Manager.update
    function Manager:update(dt, ...)
        local snapshot = {}
        for _, state in pairs(Path.paths) do snapshot[#snapshot + 1] = state end
        for _, state in ipairs(snapshot) do Path:updateState(state, dt) end
        return originalManagerUpdate(self, dt, ...)
    end

    -- Ensure temporary engine spline entities are removed on every normal,
    -- blocked, cancelled or error completion path.
    local originalFinishMotion = Loco.finishMotion
    function Loco:finishMotion(motion, reason, persist, ...)
        local state = motion ~= nil and Path.paths[motion.id] or nil
        if state ~= nil then
            Path.paths[motion.id] = nil
            deleteSpline(state)
            log("PATH STOP %s reason=%s", tostring(getSlot(state.index)), tostring(reason or "complete"))
        end
        return originalFinishMotion(self, motion, reason, persist, ...)
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot, value1, value2 = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))

        if sub == "smoothcome" or sub == "splinecome" then
            local ok, err = Path:startCome(slot, value1)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld smoothcome %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "smoothgoto" or sub == "splinegoto" then
            local ok, err = Path:startPoint(slot, value1, value2, "smoothgoto")
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld smoothgoto %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "smoothstop" or sub == "splinestop" then
            local ok, err = Path:stop(slot)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld smoothstop %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha6 spline prototype: hpWorld smoothcome [slot] [standOffMetres]")
            print("[HP] Alpha6 spline prototype: hpWorld smoothgoto [slot] <x> <z> | smoothstop [slot]")
            print("[HP] Experimental only: normal COME/FOLLOW remain unchanged.")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (runtime cubic spline + moving look-ahead target; normal COME/FOLLOW unchanged)", tostring(self.version))
    return true
end

Path:install()
