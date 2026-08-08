-- HP_WorldWorkerPlayerAccess.lua (FS25_HelperProfiles)
-- Alpha 1 hotfix: resolve the local FS25 Player through PlayerSystem and use
-- the supported Player map-position/camera-yaw API for world-worker placement.

if HP_WorldWorkerManager == nil then return end

HP_WorldWorkerPlayerAccess = HP_WorldWorkerPlayerAccess or {
    version = "2.2.0.0-alpha1-player-access-2"
}

local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/WorldWorkers] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function findLocalPlayer()
    local mission = g_currentMission
    if mission == nil then return nil, "mission-unavailable" end

    -- Retain compatibility with environments/mods that expose either shortcut.
    if rawget(_G, "g_localPlayer") ~= nil and g_localPlayer ~= nil then
        return g_localPlayer, "g_localPlayer"
    end
    if mission.player ~= nil then
        return mission.player, "mission.player"
    end

    local playerSystem = mission.playerSystem
    if playerSystem == nil then return nil, "player-system-unavailable" end

    -- FS25 PlayerSystem marks the locally-owned Player with isOwner when it is
    -- added. Prefer that explicit identity over assuming player index 1.
    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil and (player.isOwner == true or player.isLocallyControlled == true) then
            return player, player.isOwner == true and "playerSystem.owner" or "playerSystem.local"
        end
    end

    -- Single-player fallback. This is intentionally last because index order is
    -- less semantically strong than the owner/local flags above.
    if playerSystem.getPlayerByIndex ~= nil then
        local ok, player = pcall(playerSystem.getPlayerByIndex, playerSystem, 1)
        if ok and player ~= nil then return player, "playerSystem.index1" end
    end

    -- Final single-player fallback: use the first concrete Player object in the
    -- PlayerSystem table even if owner/local flags are unavailable at runtime.
    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil then return player, "playerSystem.first" end
    end

    return nil, "local-player-not-found"
end

local function getPlayerPositionAndYaw(player)
    local x, y, z, yaw = nil, nil, nil, nil

    -- Supported FS25 Player API: current map X/Z plus current camera look yaw.
    if player.getMapPositionAndLookYaw ~= nil then
        local ok, px, pz, cameraYaw = pcall(player.getMapPositionAndLookYaw, player)
        if ok and tonumber(px) ~= nil and tonumber(pz) ~= nil then
            x, z = tonumber(px), tonumber(pz)
            yaw = tonumber(cameraYaw)
        end
    end

    -- Recover full XYZ from the Player/Object position API when available.
    if player.getPosition ~= nil then
        local ok, px, py, pz = pcall(player.getPosition, player)
        if ok then
            if x == nil and tonumber(px) ~= nil then x = tonumber(px) end
            if tonumber(py) ~= nil then y = tonumber(py) end
            if z == nil and tonumber(pz) ~= nil then z = tonumber(pz) end
        end
    end

    -- Defensive fallbacks for live Player implementations/mod interactions.
    if (x == nil or y == nil or z == nil) and player.capsuleController ~= nil
        and player.capsuleController.getPosition ~= nil then
        local ok, px, py, pz = pcall(player.capsuleController.getPosition, player.capsuleController)
        if ok then
            if x == nil and tonumber(px) ~= nil then x = tonumber(px) end
            if y == nil and tonumber(py) ~= nil then y = tonumber(py) end
            if z == nil and tonumber(pz) ~= nil then z = tonumber(pz) end
        end
    end

    if (x == nil or y == nil or z == nil) and player.rootNode ~= nil and player.rootNode ~= 0
        and getWorldTranslation ~= nil then
        local ok, px, py, pz = pcall(getWorldTranslation, player.rootNode)
        if ok then
            if x == nil and tonumber(px) ~= nil then x = tonumber(px) end
            if y == nil and tonumber(py) ~= nil then y = tonumber(py) end
            if z == nil and tonumber(pz) ~= nil then z = tonumber(pz) end
        end
    end

    if yaw == nil and player.getMovementYaw ~= nil then
        local ok, value = pcall(player.getMovementYaw, player)
        if ok and tonumber(value) ~= nil then yaw = tonumber(value) end
    end

    if x == nil or z == nil then return nil, "player-position-unavailable" end
    y = tonumber(y) or 0
    yaw = tonumber(yaw) or 0
    return {x=x, y=y, z=z, yaw=yaw}, nil
end

function Manager:getPlacementInFrontOfPlayer()
    local player, playerSource = findLocalPlayer()
    if player == nil then
        log("Player access failed: %s", tostring(playerSource))
        return nil, "local-player-unavailable:" .. tostring(playerSource)
    end

    local current, positionErr = getPlayerPositionAndYaw(player)
    if current == nil then
        log("Player position failed via %s: %s", tostring(playerSource), tostring(positionErr))
        return nil, positionErr or "player-position-unavailable"
    end

    local dirX, dirZ
    if MathUtil ~= nil and MathUtil.getDirectionFromYRotation ~= nil then
        dirX, dirZ = MathUtil.getDirectionFromYRotation(current.yaw)
    else
        dirX, dirZ = math.sin(current.yaw), math.cos(current.yaw)
    end

    local distance = tonumber(self.placeDistance) or 2.0
    local x = current.x + (tonumber(dirX) or 0) * distance
    local z = current.z + (tonumber(dirZ) or 1) * distance
    local y = current.y

    local terrainNode = rawget(_G, "g_terrainNode")
    if terrainNode ~= nil and terrainNode ~= 0 and getTerrainHeightAtWorldPos ~= nil then
        local okTerrain, terrainY = pcall(getTerrainHeightAtWorldPos, terrainNode, x, 0, z)
        if okTerrain and tonumber(terrainY) ~= nil then y = tonumber(terrainY) end
    end

    log("Placement source=%s player=(%.2f, %.2f, %.2f) target=(%.2f, %.2f, %.2f) yaw=%.3f",
        tostring(playerSource), current.x, current.y, current.z, x, y, z, current.yaw)

    -- Place the worker in front of the camera direction and face them back
    -- toward the player.
    return {x=x, y=y, z=z, yaw=current.yaw + math.pi}, nil
end

log("PlayerSystem access override installed (%s)", tostring(HP_WorldWorkerPlayerAccess.version))
