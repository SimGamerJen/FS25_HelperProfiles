-- HP_WorldAnticipatorySteering.lua (FS25_HelperProfiles)
-- Alpha 4 smooth local-avoidance refinement.
--
-- Normal obstacle avoidance should read as continuous walking rather than a
-- stop/turn/waypoint sequence. This layer therefore adds a longer-range sensor
-- ahead of FOLLOW motion and smoothly biases the existing curved controller's
-- target heading around an obstruction before the short-range safety detector
-- needs to stop the worker.
--
-- The validated obstacle stop/hold + local waypoint planner remain available
-- as fallback only when no safe anticipatory steering corridor can be found.

if HP_WorldObstacleAwareness == nil then return end
if HP_WorldFollow == nil then return end
if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldLocalAvoidance == nil then return end
if HP_WorldAnticipatorySteering ~= nil then return end

HP_WorldAnticipatorySteering = {
    version = "2.2.0.0-alpha4-anticipatory-steering-1",
    lookAhead = 3.80,
    virtualTargetDistance = 4.50,
    engageRateRadPerSec = 0.72,
    recoverRateRadPerSec = 0.52,
    directClearHoldMs = 300,
    logIntervalMs = 700,
    candidateOffsetsDeg = {30, -30, 45, -45, 60, -60, 72, -72},
    installed = false
}

local Steer = HP_WorldAnticipatorySteering
local Awareness = HP_WorldObstacleAwareness
local Follow = HP_WorldFollow
local Loco = HP_WorldLocomotionPrototype
local LOG = "[FS25_HelperProfiles/WorldAvoidance] "
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

local function moveTowards(value, target, maximumDelta)
    value = tonumber(value) or 0
    target = tonumber(target) or 0
    maximumDelta = math.max(0, tonumber(maximumDelta) or 0)
    local delta = target - value
    if math.abs(delta) <= maximumDelta then return target end
    return value + (delta > 0 and maximumDelta or -maximumDelta)
end

local function walkingSpeed()
    return math.max(0.1, tonumber(Loco.walkSpeed) or 1.35)
end

-- HP_WorldObstacleAwareness intentionally keeps a short, validated emergency
-- stopping corridor. For anticipation we need a longer *read-only* query but
-- must not change the emergency detector's global dimensions. scan() is fully
-- synchronous, so temporarily widening its range for this single call is safe
-- and is restored immediately even if the call fails.
local function scanLong(index, id, x, y, z, yaw, lookAhead)
    lookAhead = math.max(2.1, tonumber(lookAhead) or 3.8)
    local oldMinimum = Awareness.minimumLookAhead
    local oldMaximum = Awareness.maximumLookAhead
    local oldFactor = Awareness.speedLookAheadFactor

    Awareness.minimumLookAhead = lookAhead
    Awareness.maximumLookAhead = lookAhead
    Awareness.speedLookAheadFactor = 0

    local ok, blocked, result = pcall(
        Awareness.scan, Awareness,
        index, id, x, y, z, yaw, walkingSpeed())

    Awareness.minimumLookAhead = oldMinimum
    Awareness.maximumLookAhead = oldMaximum
    Awareness.speedLookAheadFactor = oldFactor

    if not ok then return false, nil end
    return blocked == true, result
end

local function clearState(state, silent)
    if state == nil then return end
    local hadSteering = state.hpAnticipatorySteering == true
    state.hpAnticipatorySteering = nil
    state.hpSteerSide = nil
    state.hpSteerOffsetRad = nil
    state.hpSteerTargetOffsetRad = nil
    state.hpSteerClearMs = nil
    state.hpSteerLogMs = nil
    state.hpSteerObstacleName = nil
    if hadSteering and not silent then
        log("STEER END %s direct follow restored", tostring(getSlot(state.index)))
    end
end

function Steer:chooseOffset(state, x, y, z, directYaw)
    local currentSide = state.hpSteerSide
    local best = nil
    local summary = {}

    for _, offsetDeg in ipairs(self.candidateOffsetsDeg or {}) do
        local side = offsetDeg >= 0 and "RIGHT" or "LEFT"
        local candidateYaw = normalizeAngle(directYaw + math.rad(offsetDeg))
        local blocked, result = scanLong(
            state.index, state.id, x, y, z, candidateYaw, self.lookAhead)

        if blocked then
            summary[#summary + 1] = string.format("%s%d=X:%s",
                side:sub(1, 1), math.abs(offsetDeg),
                tostring(result ~= nil and result.nodeName or "?"))
        else
            -- Smoothness is the main objective: prefer the smallest heading
            -- correction that exposes a full long-range walking corridor. Once
            -- a side has been chosen, keep a modest preference for that side so
            -- the steering field does not flick left/right between frames.
            local score = math.abs(offsetDeg)
            if currentSide ~= nil and side == currentSide then score = score - 18 end
            if best == nil or score < best.score then
                best = {
                    score = score,
                    side = side,
                    offsetDeg = offsetDeg,
                    yaw = candidateYaw
                }
            end
            summary[#summary + 1] = string.format("%s%d=O", side:sub(1, 1), math.abs(offsetDeg))
        end
    end

    return best, table.concat(summary, " ")
end

function Steer:apply(state, motion, dt)
    if state == nil or motion == nil then return end

    -- Do not compete with the proven hard-stop/local-planner fallback. This
    -- steering layer is only for uninterrupted normal FOLLOW motion.
    if state.obstacleBlocked == true
        or state.hpAvoidance ~= nil
        or motion.hpAvoidanceWaypoint == true
        or motion.navigationKind ~= "follow" then
        clearState(state, true)
        return
    end

    local x = tonumber(motion.x)
    local y = tonumber(motion.y)
    local z = tonumber(motion.z)
    local directTargetX = tonumber(motion.targetX)
    local directTargetZ = tonumber(motion.targetZ)
    if x == nil or y == nil or z == nil or directTargetX == nil or directTargetZ == nil then
        clearState(state, true)
        return
    end

    local dx = directTargetX - x
    local dz = directTargetZ - z
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= 0.35 then
        clearState(state, false)
        return
    end

    local dtMs = math.max(0, tonumber(dt) or 0)
    local dtSeconds = dtMs * 0.001
    local directYaw = yawFromDirection(dx, dz)
    local directBlocked, directResult = scanLong(
        state.index, state.id, x, y, z, directYaw, self.lookAhead)

    local currentOffset = tonumber(state.hpSteerOffsetRad) or 0
    local targetOffset = 0

    if directBlocked then
        state.hpSteerClearMs = 0
        local candidate, summary = self:chooseOffset(state, x, y, z, directYaw)
        if candidate == nil then
            -- No long-range alternative is safe. Leave the original FOLLOW
            -- target untouched; the short-range detector will stop safely if
            -- necessary and the existing waypoint planner can take over.
            if state.hpAnticipatorySteering == true then
                log("STEER FALLBACK %s no clear anticipatory corridor (%s)",
                    tostring(getSlot(state.index)), tostring(summary))
            end
            clearState(state, true)
            return
        end

        targetOffset = math.rad(candidate.offsetDeg)
        state.hpSteerTargetOffsetRad = targetOffset
        state.hpSteerSide = candidate.side
        state.hpSteerObstacleName = directResult ~= nil and directResult.nodeName or "unknown"

        if state.hpAnticipatorySteering ~= true then
            state.hpAnticipatorySteering = true
            state.hpSteerLogMs = 0
            log("STEER START %s obstacle=%s side=%s offset=%d lookAhead=%.2f probes=[%s]",
                tostring(getSlot(state.index)), tostring(state.hpSteerObstacleName),
                tostring(candidate.side), candidate.offsetDeg,
                tonumber(self.lookAhead) or 3.8, tostring(summary))
        end
    elseif state.hpAnticipatorySteering == true then
        state.hpSteerClearMs = (tonumber(state.hpSteerClearMs) or 0) + dtMs
        if state.hpSteerClearMs < (tonumber(self.directClearHoldMs) or 300) then
            targetOffset = tonumber(state.hpSteerTargetOffsetRad) or currentOffset
        else
            targetOffset = 0
        end
    else
        return
    end

    local rate
    if math.abs(targetOffset) > math.abs(currentOffset) then
        rate = math.max(0.1, tonumber(self.engageRateRadPerSec) or 0.72)
    else
        rate = math.max(0.1, tonumber(self.recoverRateRadPerSec) or 0.52)
    end
    currentOffset = moveTowards(currentOffset, targetOffset, rate * dtSeconds)
    state.hpSteerOffsetRad = currentOffset

    -- The target itself is virtual and moves every frame. The existing curved
    -- locomotion controller therefore sees a continuously changing desired
    -- heading while retaining sole ownership of model yaw, speed and animation.
    local steerYaw = normalizeAngle(directYaw + currentOffset)
    local steerX, steerZ = directionFromYaw(steerYaw)
    local virtualDistance = math.max(2.5, tonumber(self.virtualTargetDistance) or 4.5)
    motion.targetX = x + steerX * virtualDistance
    motion.targetZ = z + steerZ * virtualDistance
    motion.hpAnticipatorySteer = true

    state.hpSteerLogMs = (tonumber(state.hpSteerLogMs) or 0) - dtMs
    if state.hpSteerLogMs <= 0 then
        state.hpSteerLogMs = tonumber(self.logIntervalMs) or 700
        log("STEER %s side=%s offset=%.1fdeg target=%.1fdeg direct=%s obstacle=%s yaw=%.3f",
            tostring(getSlot(state.index)), tostring(state.hpSteerSide or "-"),
            math.deg(currentOffset), math.deg(targetOffset),
            directBlocked and "BLOCKED" or "CLEAR",
            tostring(state.hpSteerObstacleName or "-"), steerYaw)
    end

    if not directBlocked
        and (tonumber(state.hpSteerClearMs) or 0) >= (tonumber(self.directClearHoldMs) or 300)
        and math.abs(currentOffset) <= math.rad(1.0) then
        clearState(state, false)
        motion.hpAnticipatorySteer = nil
    end
end

function Steer:install()
    if self.installed then return true end

    -- Follow.updateFollower executes before locomotion each frame. Call the
    -- existing stack first so it establishes the current live player-relative
    -- target, then bend that target only for this frame when anticipation sees
    -- an obstruction farther ahead.
    local originalUpdateFollower = Follow.updateFollower
    function Follow:updateFollower(state, dt, ...)
        local result = originalUpdateFollower(self, state, dt, ...)
        if state ~= nil then
            local motion = Loco.motions[state.id]
            if motion ~= nil then
                Steer:apply(state, motion, dt)
            elseif state.hpAnticipatorySteering == true then
                clearState(state, true)
            end
        end
        return result
    end

    self.installed = true
    log("Loaded %s (%.1fm anticipatory sensor; continuous steering bias; hard stop fallback retained)",
        tostring(self.version), tonumber(self.lookAhead) or 3.8)
    return true
end

Steer:install()
