-- HP_WorldLocomotionCurved.lua (FS25_HelperProfiles)
-- Alpha 4 curved movement experiment layered on the validated straight-walk prototype.
--
-- Test command:
--   hpWorld curve A 5 3
--
-- Arguments are local offsets from the worker's current facing:
--   forward metres, right metres (negative right = left).
-- The worker keeps a forward walking gait while model yaw blends continuously
-- toward the fixed target point. rotationVelocity deliberately remains zero,
-- matching the PlayerGraphicsState telemetry captured from a real FS25 player.

if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldLocomotionCurved ~= nil then return end
if HP_WorldWorkerManager == nil then return end

HP_WorldLocomotionCurved = {
    version = "2.2.0.0-alpha4-curved-movement-1",
    turnRateRadPerSec = 1.0,
    arrivalDistance = 0.06,
    installed = false
}

local Curve = HP_WorldLocomotionCurved
local Loco = HP_WorldLocomotionPrototype
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldLocomotion] "
local TWO_PI = math.pi * 2

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
    value = tonumber(value) or 0
    while value > math.pi do value = value - TWO_PI end
    while value < -math.pi do value = value + TWO_PI end
    return value
end

local function angleDifference(target, current)
    return normalizeAngle((tonumber(target) or 0) - (tonumber(current) or 0))
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

local function terrainY(x, fallbackY, z)
    local terrainNode = rawget(_G, "g_terrainNode")
    if terrainNode ~= nil and terrainNode ~= 0 and getTerrainHeightAtWorldPos ~= nil then
        local ok, value = pcall(getTerrainHeightAtWorldPos, terrainNode, x, 0, z)
        if ok and tonumber(value) ~= nil then return tonumber(value) end
    end
    return tonumber(fallbackY) or 0
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
        if ok and tonumber(dx) ~= nil and tonumber(dz) ~= nil then return tonumber(dx), tonumber(dz) end
    end
    return math.sin(yaw), math.cos(yaw)
end

local function fillForwardWalkState(state, speed)
    if state == nil then return end
    if state.setDefault ~= nil then pcall(state.setDefault, state) end

    speed = math.max(0, tonumber(speed) or 0)
    local walking = speed > 0.02

    state.absSpeed = speed
    state.relativeVelocityX = 0
    state.relativeVelocityY = 0
    state.relativeVelocityZ = 0
    state.rotationVelocity = 0
    state.movementDirX = 0
    state.movementDirZ = 1
    state.distanceToGround = 0
    state.isCloseToGround = true
    state.isGrounded = true
    state.isIdling = not walking
    state.isWalking = walking
    state.isRunning = false
    state.isCrouching = false
    state.isInWater = false
    state.isSwimming = false
    state.isStrafeWalkMode = false
    state.isFirstPerson = false
    state.isCutting = false
    state.isVerticalCut = false
    state.isHoldingChainsaw = false
    state.isNPC = true
end

local function applyCurvedPose(instance, state, x, y, z, yaw, speed, dt)
    local graphics = instance ~= nil and instance.graphics or nil
    if graphics == nil then return false, "graphics-unavailable" end

    fillForwardWalkState(state, speed)

    if graphics.applyState == nil then return false, "applyState-unavailable" end
    local okState, stateErr = pcall(graphics.applyState, graphics, state)
    if not okState then return false, "applyState-failed: " .. tostring(stateErr) end

    local positionApplied = false
    if graphics.setModelPosition ~= nil then
        positionApplied = pcall(graphics.setModelPosition, graphics, x, y, z)
    end
    if not positionApplied and graphics.graphicsRootNode ~= nil and setTranslation ~= nil then
        pcall(setTranslation, graphics.graphicsRootNode, x, y, z)
    end

    local yawApplied = false
    if graphics.setModelYaw ~= nil then
        yawApplied = pcall(graphics.setModelYaw, graphics, yaw)
    end
    if not yawApplied and graphics.graphicsRootNode ~= nil and setRotation ~= nil then
        pcall(setRotation, graphics.graphicsRootNode, 0, yaw, 0)
    end

    if graphics.update ~= nil then
        local okUpdate, updateErr = pcall(graphics.update, graphics, dt)
        if not okUpdate then return false, "graphics-update-failed: " .. tostring(updateErr) end
    end

    return true, nil
end

function Curve:start(indexOrSlot, forwardMetres, rightMetres)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local id = getCanonicalId(index)
    if id == nil then return false, "invalid-helper-id" end
    if Loco.motions[id] ~= nil then return false, "worker-already-walking" end

    forwardMetres = clamp(forwardMetres or 5, -15, 25)
    rightMetres = clamp(rightMetres or 3, -15, 15)
    local directDistance = math.sqrt(forwardMetres * forwardMetres + rightMetres * rightMetres)
    if directDistance < 0.5 then return false, "target-too-close" end

    -- Reuse the validated straight-walk initializer so graphics state, active
    -- ownership and persistence bookkeeping remain exactly the same baseline.
    local ok, err = Loco:startStraightWalk(index, directDistance)
    if not ok then return false, err end

    local motion = Loco.motions[id]
    if motion == nil then return false, "motion-initialization-failed" end

    local startYaw = tonumber(motion.yaw) or 0
    local forwardX, forwardZ = directionFromYaw(startYaw)
    local rightX, rightZ = math.cos(startYaw), -math.sin(startYaw)

    motion.mode = "curve"
    motion.curveForward = forwardMetres
    motion.curveRight = rightMetres
    motion.targetX = motion.x + forwardX * forwardMetres + rightX * rightMetres
    motion.targetZ = motion.z + forwardZ * forwardMetres + rightZ * rightMetres
    motion.targetY = terrainY(motion.targetX, motion.y, motion.targetZ)
    motion.totalDistance = directDistance
    motion.startYaw = startYaw

    log("CURVE START %s forward=%.2f right=%.2f direct=%.2f from=(%.2f,%.2f) to=(%.2f,%.2f) yaw=%.3f turnRate=%.3f",
        tostring(getSlot(index)), forwardMetres, rightMetres, directDistance,
        motion.x, motion.z, motion.targetX, motion.targetZ, startYaw,
        tonumber(self.turnRateRadPerSec) or 1.0)
    return true, nil
end

function Curve:updateMotion(motion, dt)
    local live = Manager.instancesByCanonicalId ~= nil and Manager.instancesByCanonicalId[motion.id] or nil
    if live == nil or live ~= motion.instance or live.graphics == nil then
        Loco.motions[motion.id] = nil
        return
    end

    local dtMs = math.max(0, tonumber(dt) or 0)
    local dtSeconds = dtMs * 0.001
    if dtSeconds <= 0 then return end

    motion.elapsedMs = (tonumber(motion.elapsedMs) or 0) + dtMs
    motion.logMs = (tonumber(motion.logMs) or 0) - dtMs

    local dx = motion.targetX - motion.x
    local dz = motion.targetZ - motion.z
    local remaining = math.sqrt(dx * dx + dz * dz)
    local arrival = math.max(0.025, tonumber(self.arrivalDistance) or 0.06)
    if remaining <= arrival then
        motion.x, motion.z = motion.targetX, motion.targetZ
        motion.y = terrainY(motion.x, motion.targetY, motion.z)
        local finishedIndex = motion.index
        local elapsed = motion.elapsedMs
        Loco:finishMotion(motion, "curve-target-reached", true)
        log("CURVE STOP %s reason=target-reached elapsed=%.2fs", tostring(getSlot(finishedIndex)), (tonumber(elapsed) or 0) * 0.001)
        return
    end

    local maxSpeed = math.max(0.25, tonumber(Loco.walkSpeed) or 1.35)
    local accel = math.max(0.1, tonumber(Loco.acceleration) or 2.8)
    local decel = math.max(0.1, tonumber(Loco.deceleration) or 3.2)
    local desiredSpeed = math.min(maxSpeed, math.sqrt(math.max(0, 2 * decel * remaining)))
    local speed = math.max(0, tonumber(motion.speed) or 0)
    if speed < desiredSpeed then
        speed = math.min(desiredSpeed, speed + accel * dtSeconds)
    else
        speed = math.max(desiredSpeed, speed - decel * dtSeconds)
    end

    local desiredYaw = yawFromDirection(dx, dz)
    local currentYaw = tonumber(motion.yaw) or desiredYaw
    local yawDiff = angleDifference(desiredYaw, currentYaw)
    local maxYawStep = math.max(0.1, tonumber(self.turnRateRadPerSec) or 1.0) * dtSeconds
    local yawStep = clamp(yawDiff, -maxYawStep, maxYawStep)
    local newYaw = normalizeAngle(currentYaw + yawStep)
    motion.yaw = newYaw

    local moveX, moveZ = directionFromYaw(newYaw)
    local step = speed * dtSeconds

    -- Once very close, snap rather than orbiting around the target because the
    -- bounded yaw rate can otherwise make a tiny circle at low speed.
    if remaining <= math.max(arrival * 3, step * 1.5) then
        motion.x, motion.z = motion.targetX, motion.targetZ
    else
        motion.x = motion.x + moveX * step
        motion.z = motion.z + moveZ * step
    end
    motion.y = terrainY(motion.x, motion.y, motion.z)
    motion.speed = speed

    local okApply, applyErr = applyCurvedPose(live, motion.state, motion.x, motion.y, motion.z, newYaw, speed, dt)
    if not okApply then
        log("CURVE ERROR %s: %s", tostring(getSlot(motion.index)), tostring(applyErr))
        Loco:finishMotion(motion, "curve-graphics-error", true)
        return
    end

    if motion.logMs <= 0 then
        motion.logMs = tonumber(Loco.logIntervalMs) or 500
        log("CURVE %s speed=%.3f remaining=%.3f yaw=%.3f desired=%.3f delta=%.3f pos=(%.2f,%.2f,%.2f)",
            tostring(getSlot(motion.index)), speed, remaining, newYaw, desiredYaw, yawDiff,
            motion.x, motion.y, motion.z)
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

function Curve:install()
    if self.installed then return true end

    local originalUpdateMotion = Loco.updateMotion
    function Loco:updateMotion(motion, dt, ...)
        if motion ~= nil and motion.mode == "curve" then
            return Curve:updateMotion(motion, dt)
        end
        return originalUpdateMotion(self, motion, dt, ...)
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot, forwardValue, rightValue = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))

        if sub == "curve" or sub == "walkcurve" then
            local ok, err = Curve:start(slot, forwardValue, rightValue)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld curve %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha4 curved movement: hpWorld curve [slot] [forwardMetres] [rightMetres]")
            print("[HP] Example: hpWorld curve A 5 3   (negative rightMetres turns left)")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (bounded-yaw curved walk test; rotationVelocity=0)", tostring(self.version))
    return true
end

Curve:install()
