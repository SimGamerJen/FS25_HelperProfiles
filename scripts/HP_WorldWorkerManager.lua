-- HP_WorldWorkerManager.lua (FS25_HelperProfiles)
-- Alpha 1: standalone static world workers, independent of AI worker jobs.

if HP_WorldWorkerManager ~= nil then return end

HP_WorldWorkerManager = {
    instancesByCanonicalId = {},
    startupDelayMs = 1800,
    retryMs = 1800,
    initialized = false,
    commandsRegistered = false,
    placeDistance = 2.0,
    version = "2.2.0.0-alpha1"
}

local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldWorkers] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function getTargetCount()
    return HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
end

local function getHelperByIndex(index)
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > getTargetCount() or g_helperManager == nil then return nil end
    if g_helperManager.getHelperByIndex ~= nil then
        local ok, helper = pcall(g_helperManager.getHelperByIndex, g_helperManager, index)
        if ok and helper ~= nil then return helper end
    end
    return g_helperManager.indexToHelper ~= nil and g_helperManager.indexToHelper[index] or nil
end

local function getStableIndexForHelper(wanted)
    if wanted == nil then return nil end
    if HelperProfiles ~= nil and HelperProfiles.getStableIndexForHelper ~= nil then
        local ok, index = pcall(HelperProfiles.getStableIndexForHelper, HelperProfiles, wanted)
        if ok and tonumber(index) ~= nil then return math.floor(tonumber(index)) end
    end
    for index = 1, getTargetCount() do
        if getHelperByIndex(index) == wanted then return index end
    end
    return nil
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
        if ok and helper ~= nil then return getStableIndexForHelper(helper) end
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

local function getDisplayName(helper, index)
    if HelperProfiles ~= nil and HelperProfiles.getDisplayNameForHelper ~= nil then
        local ok, displayName = pcall(HelperProfiles.getDisplayNameForHelper, HelperProfiles, helper, index)
        if ok and displayName ~= nil and tostring(displayName) ~= "" then return tostring(displayName) end
    end
    return tostring(helper ~= nil and helper.name or ("Helper " .. tostring(getSlot(index))))
end

local function isHelperActive(helper)
    if helper == nil then return false end
    if HelperProfiles ~= nil and HelperProfiles.isHelperActive ~= nil then
        local ok, active = pcall(HelperProfiles.isHelperActive, HelperProfiles, helper)
        if ok then return active == true end
    end
    return helper.inUse == true
end

local function clonePlayerStyle(sourceStyle)
    if sourceStyle == nil then return nil, "missing-helper-style" end
    if PlayerStyle == nil or PlayerStyle.new == nil then return nil, "playerstyle-class-unavailable" end

    if sourceStyle.loadConfigurationIfRequired ~= nil then
        pcall(sourceStyle.loadConfigurationIfRequired, sourceStyle)
    end

    local style = PlayerStyle.new()
    if style.copyFrom ~= nil then
        local ok, err = pcall(style.copyFrom, style, sourceStyle)
        if ok then return style, nil end
        return nil, "copy-style-failed: " .. tostring(err)
    end
    if style.copySelectionFrom ~= nil then
        local ok, err = pcall(style.copySelectionFrom, style, sourceStyle)
        if ok then return style, nil end
        return nil, "copy-selection-failed: " .. tostring(err)
    end
    return nil, "style-copy-unavailable"
end

local function createStyleForHelper(helper, index)
    if HP_ASBridge ~= nil and HP_ASBridge.createPlayerStyleForHelper ~= nil then
        local ok, style, err, preset = pcall(HP_ASBridge.createPlayerStyleForHelper, HP_ASBridge, helper, index)
        if ok and style ~= nil then
            return style, "avatarSwitcher", preset
        end
        if not ok then
            log("AvatarSwitcher style build failed for slot %s: %s", tostring(getSlot(index)), tostring(style))
        elseif err ~= nil and err ~= "no-preset" and err ~= "no-presets-in-category" and err ~= "avatar-switcher-unavailable" then
            log("AvatarSwitcher style unavailable for slot %s: %s", tostring(getSlot(index)), tostring(err))
        end
    end

    local style, err = clonePlayerStyle(helper ~= nil and helper.playerStyle or nil)
    return style, "helperStyle", err
end

local function applyIdleNpcAnimation(graphics)
    if graphics == nil or graphics.animation == nil or graphics.animationParameters == nil then return end
    if graphics.animation.setParameter == nil then return end

    local parameters = graphics.animationParameters
    local values = {
        absSpeed = 0,
        relativeVelocityX = 0,
        relativeVelocityY = 0,
        relativeVelocityZ = 0,
        rotationVelocity = 0,
        movementDirX = 0,
        movementDirZ = 0,
        distanceToGround = 0,
        isCloseToGround = true,
        isIdling = true,
        isWalking = false,
        isRunning = false,
        isCrouching = false,
        isGrounded = true,
        isInWater = false,
        isSwimming = false,
        isStrafeWalkMode = false,
        isFirstPerson = false,
        isCutting = false,
        isVerticalCut = false,
        isHoldingChainsaw = false,
        isNPC = true
    }

    for name, value in pairs(values) do
        local parameterId = parameters[name]
        if parameterId ~= nil then
            pcall(graphics.animation.setParameter, graphics.animation, parameterId, value)
        end
    end
end

local function getLocalPlayer()
    if rawget(_G, "g_localPlayer") ~= nil then return g_localPlayer end
    if g_currentMission ~= nil then
        return g_currentMission.player or g_currentMission.controlledPlayer
    end
    return nil
end

function Manager:getPlacementInFrontOfPlayer()
    local player = getLocalPlayer()
    if player == nil or player.getPosition == nil then return nil, "local-player-unavailable" end

    local okPos, x, y, z = pcall(player.getPosition, player)
    if not okPos or x == nil or z == nil then return nil, "player-position-unavailable" end

    local yaw = 0
    if player.getMapPositionAndLookYaw ~= nil then
        local okLook, _, _, lookYaw = pcall(player.getMapPositionAndLookYaw, player)
        if okLook and tonumber(lookYaw) ~= nil then yaw = tonumber(lookYaw) end
    elseif player.getMovementYaw ~= nil then
        local okYaw, value = pcall(player.getMovementYaw, player)
        if okYaw and tonumber(value) ~= nil then yaw = tonumber(value) end
    end

    local dirX, dirZ
    if MathUtil ~= nil and MathUtil.getDirectionFromYRotation ~= nil then
        dirX, dirZ = MathUtil.getDirectionFromYRotation(yaw)
    else
        dirX, dirZ = math.sin(yaw), math.cos(yaw)
    end

    local distance = tonumber(self.placeDistance) or 2.0
    x = x + (tonumber(dirX) or 0) * distance
    z = z + (tonumber(dirZ) or 1) * distance

    local terrainNode = rawget(_G, "g_terrainNode")
    if terrainNode ~= nil and terrainNode ~= 0 and getTerrainHeightAtWorldPos ~= nil then
        local okTerrain, terrainY = pcall(getTerrainHeightAtWorldPos, terrainNode, x, 0, z)
        if okTerrain and tonumber(terrainY) ~= nil then y = tonumber(terrainY) end
    end

    -- The worker is placed in front of the player and faces back towards them.
    return { x = x, y = y, z = z, yaw = yaw + math.pi }, nil
end

function Manager:destroyInstance(indexOrId, reason)
    local canonicalId = indexOrId
    if type(indexOrId) ~= "string" or not tostring(indexOrId):match("^helper%d+$") then
        local index = resolveIndex(indexOrId)
        canonicalId = index ~= nil and getCanonicalId(index) or nil
    end
    if canonicalId == nil then return false end

    local instance = self.instancesByCanonicalId[canonicalId]
    if instance == nil then return false end
    self.instancesByCanonicalId[canonicalId] = nil

    if instance.graphics ~= nil and instance.graphics.delete ~= nil then
        pcall(instance.graphics.delete, instance.graphics)
    end
    log("Despawned world worker %s (%s)", tostring(instance.displayName or canonicalId), tostring(reason or "requested"))
    return true
end

function Manager:spawnFromPlacement(index, placement, reason)
    index = resolveIndex(index)
    if index == nil or placement == nil then return false, "invalid-placement" end

    local helper = getHelperByIndex(index)
    if helper == nil then return false, "helper-not-ready" end
    if isHelperActive(helper) then return false, "helper-active" end
    if HumanGraphicsComponent == nil or HumanGraphicsComponent.new == nil then
        return false, "human-graphics-unavailable"
    end

    local canonicalId = getCanonicalId(index)
    self:destroyInstance(canonicalId, "replace")

    local style, styleSource, styleDetail = createStyleForHelper(helper, index)
    if style == nil then return false, styleDetail or "style-unavailable" end

    local graphics = HumanGraphicsComponent.new()
    if graphics == nil then return false, "graphics-create-failed" end

    local okInit, initErr = pcall(graphics.initialize, graphics)
    if not okInit or graphics.graphicsRootNode == nil then
        pcall(graphics.delete, graphics)
        return false, "graphics-initialize-failed: " .. tostring(initErr)
    end

    setTranslation(graphics.graphicsRootNode, tonumber(placement.x) or 0, tonumber(placement.y) or 0, tonumber(placement.z) or 0)
    setRotation(graphics.graphicsRootNode, 0, tonumber(placement.yaw) or 0, 0)
    graphics.soundsEnabled = false

    local instance = {
        id = canonicalId,
        index = index,
        helper = helper,
        displayName = getDisplayName(helper, index),
        graphics = graphics,
        styleSource = styleSource,
        loading = true
    }
    self.instancesByCanonicalId[canonicalId] = instance

    local function onStyleLoaded(manager, loadingState, loadedNewPlayerModel, callbackArgs)
        local live = manager.instancesByCanonicalId[callbackArgs.id]
        if live == nil or live.graphics ~= callbackArgs.graphics then return end
        live.loading = false
        live.loadingState = loadingState
        applyIdleNpcAnimation(live.graphics)
        if live.graphics.show ~= nil then pcall(live.graphics.show, live.graphics) end
        log("Spawned world worker %s [slot=%s id=%s style=%s loadState=%s reason=%s]",
            tostring(live.displayName), tostring(getSlot(live.index)), tostring(live.id),
            tostring(live.styleSource), tostring(loadingState), tostring(callbackArgs.reason))
    end

    local okStyle, styleErr = pcall(
        graphics.setStyleAsync,
        graphics,
        style,
        onStyleLoaded,
        self,
        { id = canonicalId, graphics = graphics, reason = reason or "state" },
        false,
        nil,
        false
    )
    if not okStyle then
        self.instancesByCanonicalId[canonicalId] = nil
        pcall(graphics.delete, graphics)
        return false, "set-style-failed: " .. tostring(styleErr)
    end

    applyIdleNpcAnimation(graphics)
    return true, nil
end

function Manager:placeAtPlayer(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end
    local helper = getHelperByIndex(index)
    if helper == nil then return false, "helper-not-ready" end
    if isHelperActive(helper) then return false, "helper-active" end

    local placement, err = self:getPlacementInFrontOfPlayer()
    if placement == nil then return false, err end

    local wrote, writeErr = HP_WorldState:setPlacement(index, placement.x, placement.y, placement.z, placement.yaw)
    if not wrote then return false, writeErr or "state-write-failed" end
    return self:spawnFromPlacement(index, placement, "place-at-player")
end

function Manager:removePlacement(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end
    self:destroyInstance(index, "placement-removed")
    return HP_WorldState:clearPlacement(index)
end

function Manager:refreshPlacement(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil then return false, "invalid-or-no-selected-helper" end
    local placement = HP_WorldState:getPlacement(index)
    if placement == nil then return false, "not-placed" end
    return self:spawnFromPlacement(index, placement, "refresh")
end

function Manager:syncPersistentPlacements()
    if HP_WorldState == nil then return end
    local placements = HP_WorldState:getAllPlacements()
    for canonicalId, placement in pairs(placements) do
        local index = resolveIndex(canonicalId)
        if index ~= nil then
            local helper = getHelperByIndex(index)
            local instance = self.instancesByCanonicalId[canonicalId]
            if helper ~= nil and isHelperActive(helper) then
                if instance ~= nil then self:destroyInstance(canonicalId, "AI-helper-active") end
            elseif helper ~= nil and instance == nil then
                local ok, err = self:spawnFromPlacement(index, placement, "persistent-state")
                if not ok and err ~= "helper-not-ready" and err ~= "helper-active" then
                    log("Could not restore slot %s: %s", tostring(getSlot(index)), tostring(err))
                end
            end
        end
    end

    -- Remove runtime instances whose persisted placement was deleted.
    local stale = {}
    for canonicalId in pairs(self.instancesByCanonicalId) do
        if placements[canonicalId] == nil then stale[#stale + 1] = canonicalId end
    end
    for _, canonicalId in ipairs(stale) do self:destroyInstance(canonicalId, "state-cleared") end
end

function Manager:getStatusRows()
    local rows = {}
    local placements = HP_WorldState ~= nil and HP_WorldState:getAllPlacements() or {}
    for index = 1, getTargetCount() do
        local id = getCanonicalId(index)
        local placement = placements[id]
        if placement ~= nil then
            local helper = getHelperByIndex(index)
            local instance = self.instancesByCanonicalId[id]
            rows[#rows + 1] = {
                index = index,
                slot = getSlot(index),
                id = id,
                name = getDisplayName(helper, index),
                placed = true,
                spawned = instance ~= nil,
                active = helper ~= nil and isHelperActive(helper) or false,
                x = placement.x,
                y = placement.y,
                z = placement.z,
                yaw = placement.yaw
            }
        end
    end
    return rows
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

function Manager:consoleCommandWorld(...)
    local sub, slot = normalizeCommandArgs(...)
    sub = string.lower(tostring(sub or "status"))

    if sub == "help" then
        print("[HP] hpWorld status | place [slot] | move [slot] | remove [slot] | refresh [slot]")
        print("[HP] With no slot, place/move/remove/refresh use the currently selected HelperProfiles worker.")
        return
    end

    if sub == "status" or sub == "list" then
        local rows = self:getStatusRows()
        print(string.format("[HP] World workers: placed=%d", #rows))
        for _, row in ipairs(rows) do
            print(string.format("[HP]   %s %-18s id=%s spawned=%s aiActive=%s pos=(%.2f, %.2f, %.2f) yaw=%.3f",
                tostring(row.slot), tostring(row.name), tostring(row.id), tostring(row.spawned), tostring(row.active),
                tonumber(row.x) or 0, tonumber(row.y) or 0, tonumber(row.z) or 0, tonumber(row.yaw) or 0))
        end
        return
    end

    local ok, err
    if sub == "place" or sub == "move" then
        ok, err = self:placeAtPlayer(slot)
    elseif sub == "remove" or sub == "clear" then
        ok, err = self:removePlacement(slot)
    elseif sub == "refresh" then
        ok, err = self:refreshPlacement(slot)
    else
        print("[HP] Unknown hpWorld subcommand '" .. tostring(sub) .. "' (try: hpWorld help)")
        return
    end

    local index = resolveIndex(slot)
    local label = index ~= nil and getSlot(index) or tostring(slot or "selected")
    print(string.format("[HP] hpWorld %s %s -> %s%s", tostring(sub), tostring(label), tostring(ok == true), err ~= nil and (" (" .. tostring(err) .. ")") or ""))
end

function Manager:registerConsoleCommand()
    if self.commandsRegistered then return end
    local ok = false
    if g_console ~= nil and g_console.addCommand ~= nil then
        g_console:addCommand("hpWorld", "Manage standalone HelperProfiles world workers", "consoleCommandWorld", self)
        ok = true
    elseif addConsoleCommand ~= nil then
        addConsoleCommand("hpWorld", "Manage standalone HelperProfiles world workers", "consoleCommandWorld", self)
        ok = true
    end
    _G.hpWorld = function(...) return Manager:consoleCommandWorld(...) end
    self.commandsRegistered = ok
end

function Manager:loadMap()
    self.instancesByCanonicalId = {}
    self.initialized = true
    self.retryMs = tonumber(self.startupDelayMs) or 1800
    self:registerConsoleCommand()
    log("Alpha 1 world-worker manager loaded; waiting for helper roster before restoring placements")
end

function Manager:update(dt)
    if not self.initialized or HP_WorldState == nil then return end

    self.retryMs = (tonumber(self.retryMs) or 0) - (tonumber(dt) or 0)
    if self.retryMs <= 0 then
        self.retryMs = 500
        self:syncPersistentPlacements()
    end

    for _, instance in pairs(self.instancesByCanonicalId) do
        if instance.graphics ~= nil then
            applyIdleNpcAnimation(instance.graphics)
            if instance.graphics.update ~= nil then pcall(instance.graphics.update, instance.graphics, dt) end
        end
    end
end

function Manager:deleteMap()
    local ids = {}
    for canonicalId in pairs(self.instancesByCanonicalId) do ids[#ids + 1] = canonicalId end
    for _, canonicalId in ipairs(ids) do self:destroyInstance(canonicalId, "map-delete") end
    self.instancesByCanonicalId = {}
    self.initialized = false
    self.commandsRegistered = false
    _G.hpWorld = nil
end

addModEventListener(HP_WorldWorkerManager)
