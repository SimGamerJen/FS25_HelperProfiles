-- HP_WorldPresence.lua (FS25_HelperProfiles)
-- 2.2.0.0-alpha3: subtle idle-facing variation and explicit FACE ME control.
--
-- This layer deliberately does not move workers through the world. It only
-- varies their standing orientation while leaving HumanGraphicsComponent in
-- its native NPC idle state. Walking/navigation belongs to a later alpha.

if HP_WorldPresence ~= nil then return end

HP_WorldPresence = {
    version = "2.2.0.0-alpha3-presence-1",
    idleEnabled = true,
    idleMinMs = 5500,
    idleMaxMs = 10500,
    idleMaxOffsetRad = math.rad(10),
    turnSpeedRadPerSec = math.rad(32),
    faceHoldMs = 6500,
    installed = false
}

local Presence = HP_WorldPresence
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldPresence] "
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

local function angleDifference(target, current)
    return normalizeAngle((tonumber(target) or 0) - (tonumber(current) or 0))
end

local function setAnimationParameter(graphics, name, value)
    if graphics == nil or graphics.animationParameters == nil then return end
    local parameter = graphics.animationParameters[name]
    if parameter == nil then return end

    if type(parameter) == "table" and parameter.setValue ~= nil then
        pcall(parameter.setValue, parameter, value)
    elseif graphics.animation ~= nil and graphics.animation.setParameter ~= nil then
        pcall(graphics.animation.setParameter, graphics.animation, parameter, value)
    end
end

local function getTargetCount()
    return HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
end

local function resolveIndex(value)
    if value ~= nil and tostring(value) ~= "" then
        if HP_SlotRegistry ~= nil then
            local index = HP_SlotRegistry:slotToIndex(value, HP_SlotRegistry.TARGET_COUNT)
            if index ~= nil then return index end
        end
        local numeric = math.floor(tonumber(value) or 0)
        if numeric >= 1 and numeric <= getTargetCount() then return numeric end
        return nil
    end

    if HelperProfiles ~= nil and HelperProfiles.getSelectedHelper ~= nil then
        local ok, helper = pcall(HelperProfiles.getSelectedHelper, HelperProfiles)
        if ok and helper ~= nil then
            if HelperProfiles.getStableIndexForHelper ~= nil then
                local okIndex, index = pcall(HelperProfiles.getStableIndexForHelper, HelperProfiles, helper)
                if okIndex and tonumber(index) ~= nil then return math.floor(tonumber(index)) end
            end
            for index = 1, getTargetCount() do
                local candidate = g_helperManager ~= nil and g_helperManager.indexToHelper ~= nil
                    and g_helperManager.indexToHelper[index] or nil
                if candidate == helper then return index end
            end
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
    local mission = g_currentMission
    if mission == nil then return nil end
    if rawget(_G, "g_localPlayer") ~= nil and g_localPlayer ~= nil then return g_localPlayer end
    if mission.player ~= nil then return mission.player end

    local playerSystem = mission.playerSystem
    if playerSystem == nil then return nil end
    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil and (player.isOwner == true or player.isLocallyControlled == true) then
            return player
        end
    end
    if playerSystem.getPlayerByIndex ~= nil then
        local ok, player = pcall(playerSystem.getPlayerByIndex, playerSystem, 1)
        if ok and player ~= nil then return player end
    end
    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil then return player end
    end
    return nil
end

local function getPlayerXZ()
    local player = findLocalPlayer()
    if player == nil then return nil, nil, "local-player-unavailable" end

    if player.getPosition ~= nil then
        local ok, x, _, z = pcall(player.getPosition, player)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then
            return tonumber(x), tonumber(z), nil
        end
    end

    if player.getMapPositionAndLookYaw ~= nil then
        local ok, x, z = pcall(player.getMapPositionAndLookYaw, player)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then
            return tonumber(x), tonumber(z), nil
        end
    end

    if player.rootNode ~= nil and player.rootNode ~= 0 and getWorldTranslation ~= nil then
        local ok, x, _, z = pcall(getWorldTranslation, player.rootNode)
        if ok and tonumber(x) ~= nil and tonumber(z) ~= nil then
            return tonumber(x), tonumber(z), nil
        end
    end

    return nil, nil, "player-position-unavailable"
end

local function chooseIdleDelay()
    local minimum = math.max(1000, math.floor(tonumber(Presence.idleMinMs) or 5500))
    local maximum = math.max(minimum, math.floor(tonumber(Presence.idleMaxMs) or 10500))
    if maximum <= minimum then return minimum end
    return math.random(minimum, maximum)
end

local function chooseIdleOffset()
    local maxOffset = math.abs(tonumber(Presence.idleMaxOffsetRad) or math.rad(10))
    -- Weighted toward the saved/base facing so workers do not continually sway.
    local choices = {-1.0, -0.55, 0, 0, 0.55, 1.0}
    return maxOffset * choices[math.random(1, #choices)]
end

function Presence:initializeInstance(instance)
    if instance == nil or instance.graphics == nil or instance.graphics.graphicsRootNode == nil then return false end
    if instance._hpPresenceInitialized == true then return true end

    local placement = HP_WorldState ~= nil and HP_WorldState:getPlacement(instance.index) or nil
    local baseYaw = placement ~= nil and tonumber(placement.yaw) or 0

    instance.presenceBaseYaw = baseYaw
    instance.presencePersistedYaw = baseYaw
    instance.presenceCurrentYaw = baseYaw
    instance.presenceTargetYaw = baseYaw
    instance.presenceIdleTimerMs = chooseIdleDelay()
    instance.presenceRotationVelocity = 0
    instance._hpPresenceInitialized = true

    local graphics = instance.graphics
    if graphics._hpPresenceUpdateWrapped ~= true and graphics.update ~= nil then
        local originalGraphicsUpdate = graphics.update
        graphics.update = function(component, dt, ...)
            Presence:beforeGraphicsUpdate(instance, dt)
            return originalGraphicsUpdate(component, dt, ...)
        end
        graphics._hpPresenceUpdateWrapped = true
    end

    return true
end

function Presence:syncBaseYaw(instance)
    if instance == nil then return end
    local placement = HP_WorldState ~= nil and HP_WorldState:getPlacement(instance.index) or nil
    if placement == nil then return end

    local persistedYaw = tonumber(placement.yaw) or 0
    if instance.presencePersistedYaw == nil then
        instance.presencePersistedYaw = persistedYaw
        instance.presenceBaseYaw = persistedYaw
        return
    end

    if math.abs(angleDifference(persistedYaw, instance.presencePersistedYaw)) > 0.0001 then
        instance.presencePersistedYaw = persistedYaw
        instance.presenceBaseYaw = persistedYaw
        instance.presenceTargetYaw = persistedYaw
        instance.presenceIdleTimerMs = tonumber(self.faceHoldMs) or 6500
    end
end

function Presence:beforeGraphicsUpdate(instance, dt)
    if instance == nil or instance.graphics == nil or instance.loading == true then return end
    if not self:initializeInstance(instance) then return end
    self:syncBaseYaw(instance)

    local dtSeconds = math.max(0, tonumber(dt) or 0) * 0.001
    local current = tonumber(instance.presenceCurrentYaw) or tonumber(instance.presenceBaseYaw) or 0
    local target = tonumber(instance.presenceTargetYaw) or tonumber(instance.presenceBaseYaw) or current

    instance.presenceIdleTimerMs = (tonumber(instance.presenceIdleTimerMs) or chooseIdleDelay()) - (tonumber(dt) or 0)
    if self.idleEnabled and instance.presenceIdleTimerMs <= 0 then
        target = normalizeAngle((tonumber(instance.presenceBaseYaw) or 0) + chooseIdleOffset())
        instance.presenceTargetYaw = target
        instance.presenceIdleTimerMs = chooseIdleDelay()
    elseif not self.idleEnabled then
        target = tonumber(instance.presenceBaseYaw) or target
        instance.presenceTargetYaw = target
    end

    local diff = angleDifference(target, current)
    local maxStep = math.abs(tonumber(self.turnSpeedRadPerSec) or math.rad(32)) * dtSeconds
    local applied = 0
    if maxStep > 0 and math.abs(diff) > 0.0005 then
        applied = math.max(-maxStep, math.min(maxStep, diff))
        current = normalizeAngle(current + applied)
        instance.presenceCurrentYaw = current
        if instance.graphics.graphicsRootNode ~= nil and setRotation ~= nil then
            setRotation(instance.graphics.graphicsRootNode, 0, current, 0)
        end
    else
        instance.presenceCurrentYaw = current
    end

    local rotationVelocity = dtSeconds > 0 and applied / dtSeconds or 0
    instance.presenceRotationVelocity = rotationVelocity
    -- HumanGraphicsComponent registers rotationVelocity as a special animation
    -- parameter. Set it immediately before the native graphics update so the
    -- standing turn can use the game's own conditional-animation transitions.
    setAnimationParameter(instance.graphics, "rotationVelocity", rotationVelocity)
    setAnimationParameter(instance.graphics, "isNPC", true)
    setAnimationParameter(instance.graphics, "isIdling", true)
end

function Presence:updateAllInstances()
    if Manager == nil then return end
    for _, instance in pairs(Manager.instancesByCanonicalId or {}) do
        if instance ~= nil and instance.loading ~= true then
            self:initializeInstance(instance)
        end
    end
end

function Presence:facePlayer(indexOrSlot)
    if Manager == nil or HP_WorldState == nil then return false, "world-manager-unavailable" end
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end

    local placement = HP_WorldState:getPlacement(index)
    if placement == nil then return false, "not-placed" end

    local canonicalId = getCanonicalId(index)
    local instance = Manager.instancesByCanonicalId ~= nil and Manager.instancesByCanonicalId[canonicalId] or nil
    if instance == nil or instance.graphics == nil or instance.loading == true then
        return false, "worker-not-visible"
    end

    local playerX, playerZ, playerErr = getPlayerXZ()
    if playerX == nil or playerZ == nil then return false, playerErr or "local-player-unavailable" end

    local dx = playerX - (tonumber(placement.x) or 0)
    local dz = playerZ - (tonumber(placement.z) or 0)
    if (dx * dx + dz * dz) < 0.0001 then return false, "player-too-close" end

    local yaw
    if MathUtil ~= nil and MathUtil.getYRotationFromDirection ~= nil then
        yaw = MathUtil.getYRotationFromDirection(dx, dz)
    else
        yaw = math.atan2(dx, dz)
    end
    yaw = normalizeAngle(yaw)

    local wrote, writeErr = HP_WorldState:setPlacement(index, placement.x, placement.y, placement.z, yaw)
    if not wrote then return false, writeErr or "state-write-failed" end

    self:initializeInstance(instance)
    instance.presenceBaseYaw = yaw
    instance.presencePersistedYaw = yaw
    instance.presenceTargetYaw = yaw
    instance.presenceIdleTimerMs = tonumber(self.faceHoldMs) or 6500

    log("FACE ME %s -> yaw=%.3f toward player=(%.2f, %.2f)", tostring(getSlot(index)), yaw, playerX, playerZ)
    return true, nil
end

function Presence:setIdleEnabled(enabled)
    self.idleEnabled = enabled == true
    for _, instance in pairs(Manager ~= nil and Manager.instancesByCanonicalId or {}) do
        if instance ~= nil then
            self:initializeInstance(instance)
            instance.presenceTargetYaw = tonumber(instance.presenceBaseYaw) or 0
            instance.presenceIdleTimerMs = chooseIdleDelay()
        end
    end
    log("Idle facing variation %s", self.idleEnabled and "enabled" or "disabled")
end

local function normalizeCommandArgs(...)
    local args = {...}
    local clean = {}
    for _, value in ipairs(args) do
        if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "hpWorld" then
            clean[#clean + 1] = tostring(value)
        end
    end
    return clean[1], clean[2]
end

function Presence:installManagerPatch()
    if self.installed or Manager == nil then return false end

    local originalUpdate = Manager.update
    function Manager:update(dt, ...)
        Presence:updateAllInstances()
        return originalUpdate(self, dt, ...)
    end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, slot = normalizeCommandArgs(...)
        sub = string.lower(tostring(sub or "status"))

        if sub == "face" or sub == "faceme" then
            local ok, err = Presence:facePlayer(slot)
            local index = resolveIndex(slot)
            local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
            print(string.format("[HP] hpWorld face %s -> %s%s", tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
            return
        elseif sub == "idle" then
            local value = string.lower(tostring(slot or "status"))
            if value == "on" or value == "1" or value == "true" then Presence:setIdleEnabled(true)
            elseif value == "off" or value == "0" or value == "false" then Presence:setIdleEnabled(false)
            else print(string.format("[HP] World idle variation: %s", Presence.idleEnabled and "ON" or "OFF")) end
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha3: hpWorld face [slot] | idle [on|off]")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s", tostring(self.version))
    return true
end

function Presence:installScreenPatch()
    if HP_WorldWorkerScreen == nil or HP_WorldWorkerScreen._hpPresenceUIPatched == true then return false end

    local originalUpdateDetailText = HP_WorldWorkerScreen.updateDetailText
    function HP_WorldWorkerScreen:updateDetailText(...)
        originalUpdateDetailText(self, ...)
        local row = self.getSelectedRow ~= nil and self:getSelectedRow() or nil
        local placed = row ~= nil and HP_WorldState ~= nil and HP_WorldState:getPlacement(row.stableIndex) ~= nil
        if self.placeMoveButton ~= nil then
            self.placeMoveButton:setText(placed and "MOVE HERE" or "PLACE HERE")
        end
    end

    function HP_WorldWorkerScreen:onClickFaceMe(sender)
        local row = self.getSelectedRow ~= nil and self:getSelectedRow() or nil
        if row == nil then return end
        local ok, err = Presence:facePlayer(row.stableIndex)
        if ok then
            self.actionMessage = string.format("%s is turning to face you.", tostring(row.displayName or row.slot or "Worker"))
        else
            self.actionMessage = string.format("FACE ME failed for %s: %s", tostring(row.displayName or row.slot or "Worker"), tostring(err or "unknown"))
        end
        if self.worldTable ~= nil then self.worldTable:reloadData() end
        self:updateDetailText()
    end

    HP_WorldWorkerScreen._hpPresenceUIPatched = true
    return true
end

Presence:installManagerPatch()
Presence:installScreenPatch()
