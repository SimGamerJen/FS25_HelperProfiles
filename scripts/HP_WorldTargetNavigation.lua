-- HP_WorldTargetNavigation.lua (FS25_HelperProfiles)
-- Alpha 4 target-navigation experiment layered on the validated curved-walk controller.
--
-- Commands:
--   hpWorld goto A <x> <z>
--   hpWorld come A [standOffMetres]
--
-- This is still direct steering, not pathfinding. The destination is fixed when
-- the command is issued. "come" snapshots the local player's current position
-- and stops short by the requested stand-off distance.

if HP_WorldLocomotionPrototype == nil then return end
if HP_WorldLocomotionCurved == nil then return end
if HP_WorldWorkerManager == nil then return end
if HP_WorldTargetNavigation ~= nil then return end

HP_WorldTargetNavigation = {
    version = "2.2.0.0-alpha4-target-navigation-1",
    defaultStandOff = 1.8,
    minimumStandOff = 0.75,
    maximumStandOff = 5.0,
    maximumDirectDistance = 100.0,
    installed = false
}

local Nav = HP_WorldTargetNavigation
local Loco = HP_WorldLocomotionPrototype
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldNavigation] "

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

local function getWorkerPlacement(index)
    if HP_WorldState == nil then return nil, "world-state-unavailable" end
    local placement = HP_WorldState:getPlacement(index)
    if placement == nil then return nil, "worker-not-placed" end
    return placement, nil
end

function Nav:startPoint(indexOrSlot, targetX, targetZ, reason)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    targetX = tonumber(targetX)
    targetZ = tonumber(targetZ)
    if targetX == nil or targetZ == nil then return false, "invalid-target-coordinates" end

    local id = getCanonicalId(index)
    if id == nil then return false, "invalid-helper-id" end
    if Loco.motions[id] ~= nil then return false, "worker-already-walking" end

    local placement, placementErr = getWorkerPlacement(index)
    if placement == nil then return false, placementErr end

    local dx = targetX - (tonumber(placement.x) or 0)
    local dz = targetZ - (tonumber(placement.z) or 0)
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance < 0.35 then return false, "target-too-close" end
    if distance > (tonumber(self.maximumDirectDistance) or 100) then return false, "target-too-far-for-direct-navigation" end

    -- Reuse the straight-walk initializer purely to create the proven graphics
    -- state and motion ownership. The temporary straight target is replaced
    -- immediately, before the next update tick.
    local ok, err = Loco:startStraightWalk(index, math.min(distance, 25))
    if not ok then return false, err end

    local motion = Loco.motions[id]
    if motion == nil then return false, "motion-initialization-failed" end

    -- The validated curved controller already performs bounded-yaw steering,
    -- acceleration/braking, terrain following, graphics-state application and
    -- persistence. Mark this as curve mode and feed it an absolute target.
    motion.mode = "curve"
    motion.navigationKind = tostring(reason or "goto")
    motion.targetX = targetX
    motion.targetZ = targetZ
    motion.totalDistance = distance

    log("TARGET START %s kind=%s distance=%.2f from=(%.2f,%.2f) to=(%.2f,%.2f) yaw=%.3f",
        tostring(getSlot(index)), tostring(motion.navigationKind), distance,
        tonumber(motion.x) or 0, tonumber(motion.z) or 0,
        targetX, targetZ, tonumber(motion.yaw) or 0)
    return true, nil
end

function Nav:startCome(indexOrSlot, standOff)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local playerX, playerZ, playerErr = getPlayerXZ()
    if playerX == nil or playerZ == nil then return false, playerErr or "player-position-unavailable" end

    local placement, placementErr = getWorkerPlacement(index)
    if placement == nil then return false, placementErr end

    standOff = clamp(standOff or self.defaultStandOff, self.minimumStandOff, self.maximumStandOff)

    local workerX = tonumber(placement.x) or 0
    local workerZ = tonumber(placement.z) or 0
    local dx = playerX - workerX
    local dz = playerZ - workerZ
    local distance = math.sqrt(dx * dx + dz * dz)
    if distance <= standOff + 0.20 then return false, "already-near-player" end

    local inv = 1 / distance
    local targetX = playerX - dx * inv * standOff
    local targetZ = playerZ - dz * inv * standOff

    local ok, err = self:startPoint(index, targetX, targetZ, "come")
    if ok then
        log("COME %s player=(%.2f,%.2f) standOff=%.2f target=(%.2f,%.2f)",
            tostring(getSlot(index)), playerX, playerZ, standOff, targetX, targetZ)
    end
    return ok, err
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

function Nav:install()
    if self.installed then return true end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot, value1, value2 = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))

        if sub == "goto" or sub == "walkto" then
            local ok, err = Nav:startPoint(slot, value1, value2, "goto")
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld goto %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "come" or sub == "cometo" or sub == "walktome" then
            local ok, err = Nav:startCome(slot, value1)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld come %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha4 target navigation: hpWorld goto [slot] <x> <z>")
            print("[HP] Alpha4 target navigation: hpWorld come [slot] [standOffMetres]")
            print("[HP] 'come' snapshots your current position; it does not continuously follow you yet.")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (absolute target + come-here snapshot; direct steering only)", tostring(self.version))
    return true
end

Nav:install()
