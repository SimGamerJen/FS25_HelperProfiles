-- HP_WorldObstacleTurnEscape.lua (FS25_HelperProfiles)
-- Alpha 4 obstacle-awareness refinement.
--
-- Fixes a blocked-follow edge case: after the direct route to the player
-- becomes clear, a worker can still be facing the old obstruction. The normal
-- obstacle wrapper then sees that stale facing corridor before curved steering
-- has time to rotate the worker and immediately blocks again.
--
-- When the target direction is clear but the current facing corridor is not,
-- rotate in place using the validated bounded-yaw rate. Forward locomotion is
-- allowed to resume only after the worker has turned onto the clear route.

if HP_WorldObstacleAwareness == nil then return end
if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldWorkerManager == nil then return end
if HP_WorldObstacleTurnEscape ~= nil then return end

HP_WorldObstacleTurnEscape = {
    version = "2.2.0.0-alpha4-obstacle-turn-escape-3",
    alignmentToleranceRad = math.rad(5),
    installed = false
}

local Escape = HP_WorldObstacleTurnEscape
local Awareness = HP_WorldObstacleAwareness
local Loco = HP_WorldLocomotionPrototype
local Manager = HP_WorldWorkerManager
local Curve = HP_WorldLocomotionCurved
local LOG = "[FS25_HelperProfiles/WorldObstacle] "
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

local function yawFromDirection(dx, dz)
    if MathUtil ~= nil and MathUtil.getYRotationFromDirection ~= nil then
        local ok, yaw = pcall(MathUtil.getYRotationFromDirection, dx, dz)
        if ok and tonumber(yaw) ~= nil then return normalizeAngle(tonumber(yaw)) end
    end
    return normalizeAngle(math.atan2(dx, dz))
end

local function getSlot(index)
    if HP_SlotRegistry ~= nil then return HP_SlotRegistry:indexToSlot(index) end
    return tostring(index)
end

local function fillIdleState(state)
    if state == nil then return end
    if state.setDefault ~= nil then pcall(state.setDefault, state) end

    state.absSpeed = 0
    state.relativeVelocityX = 0
    state.relativeVelocityY = 0
    state.relativeVelocityZ = 0
    state.rotationVelocity = 0
    state.movementDirX = 0
    state.movementDirZ = 1
    state.distanceToGround = 0
    state.isCloseToGround = true
    state.isGrounded = true
    state.isIdling = true
    state.isWalking = false
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

local function applyIdleTurn(motion, yaw, dt)
    local instance = Manager.instancesByCanonicalId ~= nil and Manager.instancesByCanonicalId[motion.id] or nil
    local graphics = instance ~= nil and instance.graphics or nil
    if graphics == nil then return false, "graphics-unavailable" end

    fillIdleState(motion.state)

    if graphics.applyState ~= nil then
        local ok, err = pcall(graphics.applyState, graphics, motion.state)
        if not ok then return false, "applyState-failed: " .. tostring(err) end
    end

    if graphics.setModelPosition ~= nil then
        pcall(graphics.setModelPosition, graphics, motion.x, motion.y, motion.z)
    elseif graphics.graphicsRootNode ~= nil and setTranslation ~= nil then
        pcall(setTranslation, graphics.graphicsRootNode, motion.x, motion.y, motion.z)
    end

    if graphics.setModelYaw ~= nil then
        pcall(graphics.setModelYaw, graphics, yaw)
    elseif graphics.graphicsRootNode ~= nil and setRotation ~= nil then
        pcall(setRotation, graphics.graphicsRootNode, 0, yaw, 0)
    end

    if graphics.update ~= nil then
        local ok, err = pcall(graphics.update, graphics, dt)
        if not ok then return false, "graphics-update-failed: " .. tostring(err) end
    end
    return true, nil
end

function Escape:handleMotion(motion, dt, originalUpdateMotion, locoSelf, ...)
    if motion == nil or motion.navigationKind ~= "follow" then
        return originalUpdateMotion(locoSelf, motion, dt, ...)
    end

    local targetX = tonumber(motion.targetX)
    local targetZ = tonumber(motion.targetZ)
    local x = tonumber(motion.x)
    local y = tonumber(motion.y)
    local z = tonumber(motion.z)
    if targetX == nil or targetZ == nil or x == nil or y == nil or z == nil then
        return originalUpdateMotion(locoSelf, motion, dt, ...)
    end

    local dx = targetX - x
    local dz = targetZ - z
    local targetDistance = math.sqrt(dx * dx + dz * dz)
    if targetDistance <= 0.001 then
        return originalUpdateMotion(locoSelf, motion, dt, ...)
    end

    local currentYaw = tonumber(motion.yaw) or yawFromDirection(dx, dz)
    local desiredYaw = yawFromDirection(dx, dz)
    local yawDiff = angleDifference(desiredYaw, currentYaw)

    -- Make both decisions with the corridor FOLLOW will actually need when it
    -- starts walking. A short stationary target probe can report CLEAR even
    -- though the full walking look-ahead still intersects the obstruction,
    -- causing TURN COMPLETE -> immediate OBSTACLE STOP loops.
    local prospectiveWalkSpeed = math.max(
        tonumber(motion.speed) or 0,
        tonumber(Loco.walkSpeed) or 1.35)
    local currentBlocked, currentResult = Awareness:scan(
        motion.index, motion.id, x, y, z, currentYaw, prospectiveWalkSpeed)
    local targetBlocked = Awareness:scan(
        motion.index, motion.id, x, y, z, desiredYaw, prospectiveWalkSpeed)

    local wasTurning = motion.hpObstacleTurnEscape == true
    local tolerance = math.max(math.rad(1), tonumber(self.alignmentToleranceRad) or math.rad(5))

    if targetBlocked ~= true and (currentBlocked == true or wasTurning) and math.abs(yawDiff) > tolerance then
        if not wasTurning then
            motion.hpObstacleTurnEscape = true
            motion.speed = 0
            log("OBSTACLE TURN START %s obstacle=%s yaw=%.3f targetYaw=%.3f delta=%.3f probeSpeed=%.2f",
                tostring(getSlot(motion.index)),
                tostring(currentResult ~= nil and currentResult.nodeName or "old-facing obstruction"),
                currentYaw, desiredYaw, yawDiff, prospectiveWalkSpeed)
        end

        local dtMs = math.max(0, tonumber(dt) or 0)
        local dtSeconds = dtMs * 0.001
        local turnRate = math.max(0.1,
            Curve ~= nil and tonumber(Curve.turnRateRadPerSec) or 1.0)
        local maxStep = turnRate * dtSeconds
        local newYaw = normalizeAngle(currentYaw + clamp(yawDiff, -maxStep, maxStep))

        motion.yaw = newYaw
        motion.speed = 0
        motion.elapsedMs = (tonumber(motion.elapsedMs) or 0) + dtMs

        local ok, err = applyIdleTurn(motion, newYaw, dt)
        if not ok then
            log("OBSTACLE TURN ERROR %s: %s", tostring(getSlot(motion.index)), tostring(err))
            motion.hpObstacleTurnEscape = nil
            return originalUpdateMotion(locoSelf, motion, dt, ...)
        end
        return
    end

    if wasTurning and targetBlocked ~= true and math.abs(yawDiff) <= tolerance then
        motion.hpObstacleTurnEscape = nil
        motion.speed = 0
        log("OBSTACLE TURN COMPLETE %s yaw=%.3f targetYaw=%.3f probeSpeed=%.2f; walking corridor clear",
            tostring(getSlot(motion.index)), currentYaw, desiredYaw, prospectiveWalkSpeed)
        -- Continue into the normal obstacle + curved-locomotion pipeline on
        -- this frame. Both current and target walking corridors are now clear.
    elseif wasTurning and targetBlocked == true then
        -- The player may have moved again while we were rotating. Give control
        -- back to the normal obstacle wrapper so FOLLOW returns to blocked/hold.
        motion.hpObstacleTurnEscape = nil
        log("OBSTACLE TURN ABORT %s target walking corridor blocked again", tostring(getSlot(motion.index)))
    end

    return originalUpdateMotion(locoSelf, motion, dt, ...)
end

function Escape:install()
    if self.installed then return true end

    -- Load after HP_WorldObstacleAwareness. This wrapper deliberately sits
    -- outside the stop/hold wrapper so it gets first refusal on the one safe
    -- special case: current facing blocked, requested follow direction clear.
    local originalUpdateMotion = Loco.updateMotion
    function Loco:updateMotion(motion, dt, ...)
        return Escape:handleMotion(motion, dt, originalUpdateMotion, self, ...)
    end

    self.installed = true
    log("Loaded %s (matched walking-corridor turn-before-walk escape)", tostring(self.version))
    return true
end

Escape:install()
