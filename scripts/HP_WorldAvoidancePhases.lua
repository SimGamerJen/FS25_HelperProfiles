-- HP_WorldAvoidancePhases.lua (FS25_HelperProfiles)
-- Alpha 4 visual-execution refinement for local obstacle avoidance.
--
-- The local planner already chooses safe short bypass waypoints. This layer
-- changes only how those waypoints are executed so the worker reads more like
-- a person making deliberate adjustments:
--   stop/hold -> turn in place -> walk -> settle -> reassess.
--
-- It reuses the validated obstacle turn-escape implementation for stationary
-- yaw changes and the validated locomotion controller for all forward motion.

if HP_WorldLocalAvoidance == nil then return end
if HP_WorldObstacleTurnEscape == nil then return end
if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldFollow == nil then return end
if HP_WorldAvoidancePhases ~= nil then return end

HP_WorldAvoidancePhases = {
    version = "2.2.0.0-alpha4-avoidance-phases-1",
    waypointSettleMs = 220,
    installed = false
}

local Phases = HP_WorldAvoidancePhases
local Avoid = HP_WorldLocalAvoidance
local Loco = HP_WorldLocomotionPrototype
local Follow = HP_WorldFollow
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

local function angleDifference(target, current)
    return normalizeAngle((tonumber(target) or 0) - (tonumber(current) or 0))
end

local function getSlot(index)
    if HP_SlotRegistry ~= nil then return HP_SlotRegistry:indexToSlot(index) end
    return tostring(index)
end

local function setPhase(state, active, phase, detail)
    if active == nil or active.hpPhase == phase then return end
    active.hpPhase = phase
    log("AVOID PHASE %s segment=%d -> %s%s",
        tostring(getSlot(state.index)), tonumber(active.segment) or 0,
        tostring(phase), detail ~= nil and (" (" .. tostring(detail) .. ")") or "")
end

function Phases:install()
    if self.installed then return true end

    -- A newly planned bypass must align before it advances. Setting the proven
    -- turn-escape flag gives that module ownership of yaw with speed held at 0.
    -- Once alignment is within its existing tolerance it clears the flag and
    -- the normal curved walker takes over without a second steering system.
    local originalStartBypass = Avoid.startBypass
    function Avoid:startBypass(state, workerX, workerY, workerZ, playerX, playerZ, directYaw, ...)
        local ok = originalStartBypass(self, state, workerX, workerY, workerZ, playerX, playerZ, directYaw, ...)
        if ok ~= true or state == nil or state.hpAvoidance == nil then return ok end

        local motion = Loco.motions[state.id]
        if motion ~= nil then
            local targetX = tonumber(motion.targetX) or tonumber(state.hpAvoidance.x) or tonumber(motion.x) or 0
            local targetZ = tonumber(motion.targetZ) or tonumber(state.hpAvoidance.z) or tonumber(motion.z) or 0
            local dx = targetX - (tonumber(motion.x) or 0)
            local dz = targetZ - (tonumber(motion.z) or 0)
            local targetYaw = yawFromDirection(dx, dz)
            local currentYaw = tonumber(motion.yaw) or targetYaw
            local delta = angleDifference(targetYaw, currentYaw)

            motion.speed = 0
            motion.hpObstacleTurnEscape = true
            motion.hpAvoidanceForcedTurn = true
            setPhase(state, state.hpAvoidance, "TURN",
                string.format("yaw=%.3f targetYaw=%.3f delta=%.3f", currentYaw, targetYaw, delta))
            log("AVOID TURN START %s side=%s segment=%d yaw=%.3f targetYaw=%.3f delta=%.3f",
                tostring(getSlot(state.index)), tostring(state.hpAvoidance.side),
                tonumber(state.hpAvoidance.segment) or 0, currentYaw, targetYaw, delta)
        end
        return ok
    end

    local originalUpdateActive = Avoid.updateActive
    function Avoid:updateActive(state, dt, ...)
        local active = state ~= nil and state.hpAvoidance or nil
        if active == nil then return originalUpdateActive(self, state, dt, ...) end

        dt = math.max(0, tonumber(dt) or 0)
        local motion = Loco.motions[state.id]

        if motion ~= nil then
            if motion.hpAvoidanceForcedTurn == true then
                if motion.hpObstacleTurnEscape == true then
                    setPhase(state, active, "TURN")
                else
                    motion.hpAvoidanceForcedTurn = nil
                    setPhase(state, active, "MOVE")
                    log("AVOID MOVE START %s side=%s segment=%d alignedYaw=%.3f waypoint=(%.2f,%.2f)",
                        tostring(getSlot(state.index)), tostring(active.side), tonumber(active.segment) or 0,
                        tonumber(motion.yaw) or 0, tonumber(active.x) or 0, tonumber(active.z) or 0)
                end
            elseif active.hpPhase ~= "MOVE" then
                setPhase(state, active, "MOVE")
            end
            return originalUpdateActive(self, state, dt, ...)
        end

        -- Safety stops during a bypass remain authoritative. The original
        -- avoidance code clears/replans those immediately into its normal
        -- blocked hold, which already gives us the planning delay before the
        -- next attempt.
        if state.obstacleBlocked == true then
            return originalUpdateActive(self, state, dt, ...)
        end

        -- A cleanly reached waypoint gets a short idle settle before FOLLOW is
        -- allowed to reacquire the player or plan another side-step. This makes
        -- chained segments read as distinct human decisions rather than one
        -- continuous zig-zagging curve.
        if active.hpPhase ~= "SETTLE" then
            active.hpSettleRemainingMs = math.max(0, tonumber(self.waypointSettleMs) or 220)
            setPhase(state, active, "SETTLE",
                string.format("%.0fms", active.hpSettleRemainingMs))
        end

        active.hpSettleRemainingMs = math.max(0,
            (tonumber(active.hpSettleRemainingMs) or 0) - dt)
        if active.hpSettleRemainingMs > 0 then
            if Follow.setMode ~= nil then
                Follow:setMode(state, "avoiding", string.format("settling segment=%d", tonumber(active.segment) or 0))
            end
            return true
        end

        log("AVOID SETTLE COMPLETE %s segment=%d; reassessing route",
            tostring(getSlot(state.index)), tonumber(active.segment) or 0)
        return originalUpdateActive(self, state, dt, ...)
    end

    self.installed = true
    log("Loaded %s (phased stop-turn-move-settle avoidance execution)", tostring(self.version))
    return true
end

Phases:install()
