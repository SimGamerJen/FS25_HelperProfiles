-- HP_WorldLocomotionPrototype.lua (FS25_HelperProfiles)
-- Alpha 4 locomotion experiment.
--
-- This is intentionally NOT pathfinding. It proves one narrower question:
-- can an existing HelperProfiles HumanGraphicsComponent be translated through
-- the world while a HumanGraphicsComponentState drives the same walk flags and
-- speed values observed from a real FS25 player?
--
-- Test command:
--   hpWorld walk A 5
--   hpWorld walkstop A
--
-- The worker walks straight ahead from its current facing for N metres.

if HP_WorldLocomotionPrototype ~= nil then return end
if HP_WorldWorkerManager == nil then return end

HP_WorldLocomotionPrototype = {
    version = "2.2.0.0-alpha4-locomotion-prototype-1",
    motions = {},
    walkSpeed = 1.35,
    acceleration = 2.8,
    deceleration = 3.2,
    logIntervalMs = 500,
    installed = false
}

local Loco = HP_WorldLocomotionPrototype
local Manager = HP_WorldWorkerManager
local Presence = HP_WorldPresence
local LOG = "[FS25_HelperProfiles/WorldLocomotion] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function getTargetCount()
    return HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
end

local function resolveIndex(value)
    if value ~= nil and tostring(value) ~= "" then
        if HP_SlotRegistry ~= nil then
            local index = HP_SlotRegistry:slotToIndex(value, getTargetCount())
            if index ~= nil then return index end
        end
        local numeric = math.floor(tonumber(value) or 0)
        if numeric >= 1 and numeric <= getTargetCount() then return numeric end
        return nil
    end

    if HelperProfiles ~= nil and HelperProfiles.getSelectedHelper ~= nil then
        local ok, helper = pcall(HelperProfiles.getSelectedHelper, HelperProfiles)
        if ok and helper ~= nil and HelperProfiles.getStableIndexForHelper ~= nil then
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

local function getInstance(index)
    local id = getCanonicalId(index)
    if id == nil or Manager.instancesByCanonicalId == nil then return nil, id end
    return Manager.instancesByCanonicalId[id], id
end

local function getRootPose(instance)
    if instance == nil or instance.graphics == nil then return nil end
    local graphics = instance.graphics
    local x, y, z, yaw

    if graphics.graphicsRootNode ~= nil and graphics.graphicsRootNode ~= 0 then
        if getWorldTranslation ~= nil then
            local ok, px, py, pz = pcall(getWorldTranslation, graphics.graphicsRootNode)
            if ok then x, y, z = tonumber(px), tonumber(py), tonumber(pz) end
        end
        if getRotation ~= nil then
            local ok, _, ry = pcall(getRotation, graphics.graphicsRootNode)
            if ok then yaw = tonumber(ry) end
        end
    end

    local placement = HP_WorldState ~= nil and HP_WorldState:getPlacement(instance.index) or nil
    if x == nil and placement ~= nil then x = tonumber(placement.x) end
    if y == nil and placement ~= nil then y = tonumber(placement.y) end
    if z == nil and placement ~= nil then z = tonumber(placement.z) end
    if instance.presenceCurrentYaw ~= nil then yaw = tonumber(instance.presenceCurrentYaw) end
    if yaw == nil and placement ~= nil then yaw = tonumber(placement.yaw) end

    if x == nil or y == nil or z == nil then return nil end
    return {x = x, y = y, z = z, yaw = yaw or 0}
end

local function terrainY(x, fallbackY, z)
    local terrainNode = rawget(_G, "g_terrainNode")
    if terrainNode ~= nil and terrainNode ~= 0 and getTerrainHeightAtWorldPos ~= nil then
        local ok, value = pcall(getTerrainHeightAtWorldPos, terrainNode, x, 0, z)
        if ok and tonumber(value) ~= nil then return tonumber(value) end
    end
    return tonumber(fallbackY) or 0
end

local function makeState()
    if HumanGraphicsComponentState == nil or HumanGraphicsComponentState.new == nil then return nil end
    local ok, state = pcall(HumanGraphicsComponentState.new)
    if not ok or state == nil then return nil end
    return state
end

local function fillState(state, speed, walking)
    if state == nil then return end
    if state.setDefault ~= nil then pcall(state.setDefault, state) end

    speed = math.max(0, tonumber(speed) or 0)
    walking = walking == true and speed > 0.02

    -- These are the fields the movement probe observed changing in the real
    -- player's PlayerGraphicsState. Keep the prototype deliberately simple:
    -- forward walk only, grounded, no strafe/crouch/tool state.
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

local function applyPoseAndState(instance, state, x, y, z, yaw, speed, walking, dt)
    local graphics = instance ~= nil and instance.graphics or nil
    if graphics == nil then return false, "graphics-unavailable" end

    fillState(state, speed, walking)

    if graphics.applyState ~= nil then
        local ok, err = pcall(graphics.applyState, graphics, state)
        if not ok then return false, "applyState-failed: " .. tostring(err) end
    else
        return false, "applyState-unavailable"
    end

    local positionApplied = false
    if graphics.setModelPosition ~= nil then
        local ok = pcall(graphics.setModelPosition, graphics, x, y, z)
        positionApplied = ok
    end
    if not positionApplied and graphics.graphicsRootNode ~= nil and setTranslation ~= nil then
        pcall(setTranslation, graphics.graphicsRootNode, x, y, z)
    end

    local yawApplied = false
    if graphics.setModelYaw ~= nil then
        local ok = pcall(graphics.setModelYaw, graphics, yaw)
        yawApplied = ok
    end
    if not yawApplied and graphics.graphicsRootNode ~= nil and setRotation ~= nil then
        pcall(setRotation, graphics.graphicsRootNode, 0, yaw, 0)
    end

    if graphics.update ~= nil then
        local ok, err = pcall(graphics.update, graphics, dt)
        if not ok then return false, "graphics-update-failed: " .. tostring(err) end
    end

    return true, nil
end

function Loco:startStraightWalk(indexOrSlot, distance)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local instance, id = getInstance(index)
    if instance == nil then return false, "worker-not-visible" end
    if instance.loading == true then return false, "worker-still-loading" end
    if instance.graphics == nil then return false, "worker-graphics-unavailable" end

    local pose = getRootPose(instance)
    if pose == nil then return false, "worker-pose-unavailable" end

    local state = makeState()
    if state == nil then return false, "HumanGraphicsComponentState-unavailable" end

    distance = clamp(distance or 5, 0.5, 25)
    local dirX, dirZ
    if MathUtil ~= nil and MathUtil.getDirectionFromYRotation ~= nil then
        dirX, dirZ = MathUtil.getDirectionFromYRotation(pose.yaw)
    else
        dirX, dirZ = math.sin(pose.yaw), math.cos(pose.yaw)
    end
    dirX, dirZ = tonumber(dirX) or 0, tonumber(dirZ) or 1

    local targetX = pose.x + dirX * distance
    local targetZ = pose.z + dirZ * distance
    local targetY = terrainY(targetX, pose.y, targetZ)

    self.motions[id] = {
        id = id,
        index = index,
        instance = instance,
        state = state,
        x = pose.x,
        y = pose.y,
        z = pose.z,
        yaw = pose.yaw,
        dirX = dirX,
        dirZ = dirZ,
        targetX = targetX,
        targetY = targetY,
        targetZ = targetZ,
        speed = 0,
        elapsedMs = 0,
        logMs = 0,
        totalDistance = distance
    }
    instance.hpLocomotionActive = true

    log("WALK START %s distance=%.2f speed=%.2f from=(%.2f,%.2f) to=(%.2f,%.2f) yaw=%.3f",
        tostring(getSlot(index)), distance, tonumber(self.walkSpeed) or 1.35,
        pose.x, pose.z, targetX, targetZ, pose.yaw)
    return true, nil
end

function Loco:finishMotion(motion, reason, persist)
    if motion == nil then return end
    local id = motion.id
    local instance = motion.instance

    if persist ~= false and HP_WorldState ~= nil then
        local ok, err = HP_WorldState:setPlacement(motion.index, motion.x, motion.y, motion.z, motion.yaw)
        if not ok then log("WALK persistence failed %s: %s", tostring(getSlot(motion.index)), tostring(err)) end
    end

    if instance ~= nil then
        instance.hpLocomotionActive = nil
        if instance.presenceBaseYaw ~= nil then
            instance.presenceBaseYaw = motion.yaw
            instance.presencePersistedYaw = motion.yaw
            instance.presenceCurrentYaw = motion.yaw
            instance.presenceTargetYaw = motion.yaw
        end
        applyPoseAndState(instance, motion.state, motion.x, motion.y, motion.z, motion.yaw, 0, false, 0)
    end

    self.motions[id] = nil
    log("WALK STOP %s reason=%s pos=(%.2f,%.2f,%.2f) elapsed=%.2fs",
        tostring(getSlot(motion.index)), tostring(reason or "complete"),
        tonumber(motion.x) or 0, tonumber(motion.y) or 0, tonumber(motion.z) or 0,
        (tonumber(motion.elapsedMs) or 0) * 0.001)
end

function Loco:stopWalk(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end
    local id = getCanonicalId(index)
    local motion = id ~= nil and self.motions[id] or nil
    if motion == nil then return false, "worker-not-walking" end
    self:finishMotion(motion, "requested", true)
    return true, nil
end

function Loco:updateMotion(motion, dt)
    if motion == nil then return end
    local live = Manager.instancesByCanonicalId ~= nil and Manager.instancesByCanonicalId[motion.id] or nil
    if live == nil or live ~= motion.instance or live.graphics == nil then
        self.motions[motion.id] = nil
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
    if remaining <= 0.025 then
        motion.x, motion.z = motion.targetX, motion.targetZ
        motion.y = terrainY(motion.x, motion.targetY, motion.z)
        self:finishMotion(motion, "target-reached", true)
        return
    end

    local maxSpeed = math.max(0.25, tonumber(self.walkSpeed) or 1.35)
    local accel = math.max(0.1, tonumber(self.acceleration) or 2.8)
    local decel = math.max(0.1, tonumber(self.deceleration) or 3.2)

    -- Desired speed follows a braking-distance envelope, giving us a smooth
    -- departure and stop instead of snapping the animation between idle/walk.
    local desiredSpeed = math.min(maxSpeed, math.sqrt(math.max(0, 2 * decel * remaining)))
    local speed = math.max(0, tonumber(motion.speed) or 0)
    if speed < desiredSpeed then
        speed = math.min(desiredSpeed, speed + accel * dtSeconds)
    else
        speed = math.max(desiredSpeed, speed - decel * dtSeconds)
    end

    local step = math.min(remaining, speed * dtSeconds)
    if remaining > 0 then
        motion.x = motion.x + (dx / remaining) * step
        motion.z = motion.z + (dz / remaining) * step
    end
    motion.y = terrainY(motion.x, motion.y, motion.z)
    motion.speed = speed

    local ok, err = applyPoseAndState(live, motion.state, motion.x, motion.y, motion.z, motion.yaw, speed, true, dt)
    if not ok then
        log("WALK ERROR %s: %s", tostring(getSlot(motion.index)), tostring(err))
        self:finishMotion(motion, "graphics-error", true)
        return
    end

    if motion.logMs <= 0 then
        motion.logMs = tonumber(self.logIntervalMs) or 500
        log("WALK %s speed=%.3f remaining=%.3f pos=(%.2f,%.2f,%.2f)",
            tostring(getSlot(motion.index)), speed, remaining, motion.x, motion.y, motion.z)
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
    return clean[1], clean[2], clean[3]
end

function Loco:install()
    if self.installed then return true end

    -- Presence currently owns the stable root-only FACE ME fallback. While a
    -- locomotion test is active, suppress that layer so the walking state is
    -- the sole owner of pose + HumanGraphicsComponent updates.
    if Presence ~= nil and Presence.beforeGraphicsUpdate ~= nil and Presence._hpLocomotionSuppressionPatched ~= true then
        local originalBeforeGraphicsUpdate = Presence.beforeGraphicsUpdate
        function Presence:beforeGraphicsUpdate(instance, dt, ...)
            if instance ~= nil and instance.hpLocomotionActive == true then return end
            return originalBeforeGraphicsUpdate(self, instance, dt, ...)
        end
        Presence._hpLocomotionSuppressionPatched = true
    end

    -- The base manager forces its static NPC-idle values every frame. For a
    -- moving instance we temporarily mark it as loading so the base graphics
    -- loop skips it, then this prototype becomes the only updater for that
    -- instance during the test. Persistent/AI duplicate sync still runs.
    local originalManagerUpdate = Manager.update
    function Manager:update(dt, ...)
        local hidden = {}
        for id, motion in pairs(Loco.motions) do
            local instance = motion ~= nil and motion.instance or nil
            if instance ~= nil and instance.loading ~= true then
                hidden[id] = instance
                instance.loading = true
            end
        end

        local results = { originalManagerUpdate(self, dt, ...) }

        for id, instance in pairs(hidden) do
            local live = self.instancesByCanonicalId ~= nil and self.instancesByCanonicalId[id] or nil
            if live == instance then instance.loading = false end
        end

        local active = {}
        for _, motion in pairs(Loco.motions) do active[#active + 1] = motion end
        for _, motion in ipairs(active) do Loco:updateMotion(motion, dt) end

        return unpack(results)
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot, value = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))

        if sub == "walk" or sub == "walktest" then
            local ok, err = Loco:startStraightWalk(slot, value)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld walk %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "walkstop" or sub == "stopwalk" then
            local ok, err = Loco:stopWalk(slot)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld walkstop %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha4 prototype: hpWorld walk [slot] [metres] | walkstop [slot]")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (graphics-state straight-walk test)", tostring(self.version))
    return true
end

Loco:install()
