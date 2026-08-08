-- HP_WorldMovementProbe.lua (FS25_HelperProfiles)
-- Alpha 4 diagnostic probe: observe the live FS25 player movement/graphics
-- pipeline so world-worker locomotion can reproduce proven runtime behaviour.

if HP_WorldMovementProbe ~= nil then return end

HP_WorldMovementProbe = {
    version = "2.2.0.0-alpha4-movement-probe-2",
    initialized = false,
    commandsRegistered = false,
    watchActive = false,
    watchRemainingMs = 0,
    watchSampleMs = 0,
    watchIntervalMs = 250,
    watchSlot = nil,
    sampleIndex = 0
}

local Probe = HP_WorldMovementProbe
local LOG = "[FS25_HelperProfiles/MovementProbe] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function fmtNumber(value)
    value = tonumber(value)
    if value == nil then return "nil" end
    return string.format("%.4f", value)
end

local function scalarToString(value)
    local valueType = type(value)
    if valueType == "number" then return fmtNumber(value) end
    if valueType == "boolean" then return tostring(value) end
    if valueType == "string" then return value end
    if value == nil then return "nil" end
    return "<" .. valueType .. ">"
end

local function safeCall(object, methodName, ...)
    if object == nil then return nil end
    local method = object[methodName]
    if type(method) ~= "function" then return nil end
    local results = { pcall(method, object, ...) }
    if results[1] ~= true then return nil end
    table.remove(results, 1)
    return results
end

local function findLocalPlayer()
    local mission = g_currentMission
    if mission == nil then return nil, "mission-unavailable" end

    if rawget(_G, "g_localPlayer") ~= nil and g_localPlayer ~= nil then
        return g_localPlayer, "g_localPlayer"
    end
    if mission.player ~= nil then return mission.player, "mission.player" end

    local playerSystem = mission.playerSystem
    if playerSystem == nil then return nil, "player-system-unavailable" end

    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil and (player.isOwner == true or player.isLocallyControlled == true) then
            return player, player.isOwner == true and "playerSystem.owner" or "playerSystem.local"
        end
    end

    if playerSystem.getPlayerByIndex ~= nil then
        local result = safeCall(playerSystem, "getPlayerByIndex", 1)
        if result ~= nil and result[1] ~= nil then return result[1], "playerSystem.index1" end
    end

    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil then return player, "playerSystem.first" end
    end

    return nil, "local-player-not-found"
end

local function resolveIndex(value)
    if value ~= nil and tostring(value) ~= "" then
        if HP_SlotRegistry ~= nil then
            local index = HP_SlotRegistry:slotToIndex(value, HP_SlotRegistry.TARGET_COUNT)
            if index ~= nil then return index end
        end
        local numeric = math.floor(tonumber(value) or 0)
        if numeric >= 1 and numeric <= 20 then return numeric end
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

local function getWorldWorker(indexOrSlot)
    local index = resolveIndex(indexOrSlot)
    if index == nil or HP_WorldWorkerManager == nil then return nil, index end
    local id = getCanonicalId(index)
    local instance = HP_WorldWorkerManager.instancesByCanonicalId ~= nil
        and HP_WorldWorkerManager.instancesByCanonicalId[id] or nil
    return instance, index
end

local function readParameter(graphics, parameter)
    if graphics ~= nil and graphics.animation ~= nil and graphics.animation.getParameter ~= nil and parameter ~= nil then
        local ok, value = pcall(graphics.animation.getParameter, graphics.animation, parameter)
        if ok and (type(value) == "number" or type(value) == "boolean" or type(value) == "string") then
            return value
        end
    end

    if type(parameter) == "table" then
        local methods = { "getValue", "getCurrentValue" }
        for _, methodName in ipairs(methods) do
            local method = parameter[methodName]
            if type(method) == "function" then
                local ok, value = pcall(method, parameter)
                if ok and (type(value) == "number" or type(value) == "boolean" or type(value) == "string") then
                    return value
                end
            end
        end

        local fields = { "value", "currentValue", "lastValue" }
        for _, fieldName in ipairs(fields) do
            local value = parameter[fieldName]
            if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then
                return value
            end
        end
    end

    return nil
end

local function collectAnimationParameters(graphics)
    local result = {}
    if graphics == nil or graphics.animationParameters == nil then return result end
    for name, parameter in pairs(graphics.animationParameters) do
        local value = readParameter(graphics, parameter)
        if value == nil then value = "?" end
        result[tostring(name)] = value
    end
    return result
end

local function collectMatchingScalars(object, patterns)
    local result = {}
    if type(object) ~= "table" then return result end

    for key, value in pairs(object) do
        local valueType = type(value)
        if valueType == "number" or valueType == "boolean" or valueType == "string" then
            local lowerKey = string.lower(tostring(key))
            local matched = false
            for _, pattern in ipairs(patterns) do
                if string.find(lowerKey, pattern, 1, true) ~= nil then
                    matched = true
                    break
                end
            end
            if matched then result[tostring(key)] = value end
        end
    end
    return result
end

local MOVEMENT_PATTERNS = {
    "speed", "velocity", "force", "yaw", "ground", "move", "walk", "run",
    "idle", "crouch", "strafe", "swim", "water", "fall", "rotation", "positiondelta"
}

local function printSortedScalars(label, values)
    local keys = {}
    for key in pairs(values or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 0 then
        log("%s: <no readable scalar fields>", tostring(label))
        return
    end
    for _, key in ipairs(keys) do
        log("%s.%s=%s", tostring(label), tostring(key), scalarToString(values[key]))
    end
end

local function printCapabilities(label, object, methods)
    if object == nil then
        log("%s: MISSING", tostring(label))
        return
    end
    log("%s: present type=%s", tostring(label), type(object))
    for _, methodName in ipairs(methods) do
        log("%s.%s=%s", tostring(label), tostring(methodName), tostring(type(object[methodName]) == "function"))
    end
end

local function getPosition(player)
    if player == nil then return nil, nil, nil end
    local result = safeCall(player, "getPosition")
    if result ~= nil and tonumber(result[1]) ~= nil and tonumber(result[3]) ~= nil then
        return tonumber(result[1]), tonumber(result[2]) or 0, tonumber(result[3])
    end
    if player.rootNode ~= nil and player.rootNode ~= 0 and getWorldTranslation ~= nil then
        local ok, x, y, z = pcall(getWorldTranslation, player.rootNode)
        if ok then return tonumber(x), tonumber(y), tonumber(z) end
    end
    return nil, nil, nil
end

local function getGraphicalYaw(player)
    local result = safeCall(player, "getGraphicalYaw")
    return result ~= nil and tonumber(result[1]) or nil
end

local function getMovementYaw(mover)
    local result = safeCall(mover, "getMovementYaw")
    if result ~= nil and tonumber(result[1]) ~= nil then return tonumber(result[1]) end
    return mover ~= nil and tonumber(mover.movementDirectionYaw) or nil
end

local function getMoverSpeed(mover)
    local result = safeCall(mover, "getSpeed")
    if result ~= nil and tonumber(result[1]) ~= nil then return tonumber(result[1]) end
    return mover ~= nil and tonumber(mover.currentSpeed) or nil
end

function Probe:printOverview(indexOrSlot)
    local player, playerSource = findLocalPlayer()
    if player == nil then
        log("Overview failed: %s", tostring(playerSource))
        return
    end

    log("=== Movement Probe Overview %s ===", tostring(self.version))
    log("Local player source=%s", tostring(playerSource))
    log("Classes: PlayerMover=%s PlayerGraphicsState=%s HumanGraphicsComponentState=%s PlayerCCT=%s",
        tostring(PlayerMover ~= nil), tostring(PlayerGraphicsState ~= nil),
        tostring(HumanGraphicsComponentState ~= nil), tostring(PlayerCCT ~= nil))

    printCapabilities("player", player, {
        "getPosition", "getGraphicalPosition", "getGraphicalYaw", "getMapPositionAndLookYaw"
    })
    printCapabilities("player.mover", player.mover, {
        "getMovementYaw", "getSpeed", "calculateSmoothSpeed", "moveHorizontally",
        "setPosition", "teleportTo", "update"
    })
    printCapabilities("player.graphicsState", player.graphicsState, {
        "setDefault", "updateLocal", "updateRemote"
    })
    printCapabilities("player.graphicsComponent", player.graphicsComponent, {
        "applyState", "setModelYaw", "setModelPosition", "update"
    })
    printCapabilities("player.capsuleController", player.capsuleController, {
        "update", "getPosition", "setPosition"
    })

    printSortedScalars("mover", collectMatchingScalars(player.mover, MOVEMENT_PATTERNS))
    printSortedScalars("graphicsState", collectMatchingScalars(player.graphicsState, MOVEMENT_PATTERNS))
    printSortedScalars("playerAnim", collectAnimationParameters(player.graphicsComponent))

    local worker, index = getWorldWorker(indexOrSlot)
    if worker ~= nil then
        log("World worker slot=%s id=%s visible=true", tostring(getSlot(index)), tostring(worker.id))
        printCapabilities("worker.graphics", worker.graphics, {
            "applyState", "setModelYaw", "setModelPosition", "update"
        })
        printSortedScalars("workerAnim", collectAnimationParameters(worker.graphics))
    else
        log("World worker: none selected/visible (optional; pass a placed slot, e.g. hpWorldProbe overview A)")
    end

    log("=== End Overview ===")
end

local function getAnimValue(anim, key)
    if anim == nil then return nil end
    local value = anim[key]
    if value == "?" then return nil end
    return value
end

function Probe:samplePlayer()
    local player = findLocalPlayer()
    if player == nil then return nil end

    local x, y, z = getPosition(player)
    local mover = player.mover
    local graphics = player.graphicsComponent
    local anim = collectAnimationParameters(graphics)

    return {
        x = x, y = y, z = z,
        graphicalYaw = getGraphicalYaw(player),
        movementYaw = getMovementYaw(mover),
        speed = getMoverSpeed(mover),
        moverRotationVelocity = mover ~= nil and tonumber(mover.currentRotationVelocity) or nil,
        forceX = mover ~= nil and tonumber(mover.currentForceX) or nil,
        forceZ = mover ~= nil and tonumber(mover.currentForceZ) or nil,
        velocityX = mover ~= nil and tonumber(mover.currentVelocityX) or nil,
        velocityY = mover ~= nil and tonumber(mover.currentVelocityY) or nil,
        velocityZ = mover ~= nil and tonumber(mover.currentVelocityZ) or nil,
        deltaX = mover ~= nil and tonumber(mover.positionDeltaX) or nil,
        deltaZ = mover ~= nil and tonumber(mover.positionDeltaZ) or nil,
        grounded = mover ~= nil and mover.isGrounded or nil,
        closeToGround = mover ~= nil and mover.isCloseToGround or nil,
        groundDistance = mover ~= nil and tonumber(mover.currentGroundDistance) or nil,
        absSpeed = getAnimValue(anim, "absSpeed"),
        rotationVelocity = getAnimValue(anim, "rotationVelocity"),
        relativeVelocityX = getAnimValue(anim, "relativeVelocityX"),
        relativeVelocityZ = getAnimValue(anim, "relativeVelocityZ"),
        movementDirX = getAnimValue(anim, "movementDirX"),
        movementDirZ = getAnimValue(anim, "movementDirZ"),
        isIdling = getAnimValue(anim, "isIdling"),
        isWalking = getAnimValue(anim, "isWalking"),
        isRunning = getAnimValue(anim, "isRunning"),
        isGrounded = getAnimValue(anim, "isGrounded")
    }
end

function Probe:sampleWorker(indexOrSlot)
    local instance, index = getWorldWorker(indexOrSlot)
    if instance == nil or instance.graphics == nil then return nil end
    local graphics = instance.graphics
    local anim = collectAnimationParameters(graphics)
    local x, y, z = nil, nil, nil
    local yaw = nil
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
    return {
        slot = getSlot(index), x = x, y = y, z = z, yaw = yaw,
        absSpeed = getAnimValue(anim, "absSpeed"),
        rotationVelocity = getAnimValue(anim, "rotationVelocity"),
        relativeVelocityX = getAnimValue(anim, "relativeVelocityX"),
        relativeVelocityZ = getAnimValue(anim, "relativeVelocityZ"),
        movementDirX = getAnimValue(anim, "movementDirX"),
        movementDirZ = getAnimValue(anim, "movementDirZ"),
        isIdling = getAnimValue(anim, "isIdling"),
        isWalking = getAnimValue(anim, "isWalking"),
        isRunning = getAnimValue(anim, "isRunning")
    }
end

local function compact(value)
    if value == nil then return "?" end
    if type(value) == "number" then return string.format("%.3f", value) end
    return tostring(value)
end

function Probe:printWatchSample()
    local p = self:samplePlayer()
    if p == nil then
        log("WATCH player unavailable")
        return
    end

    self.sampleIndex = self.sampleIndex + 1
    local elapsed = self.sampleIndex * (tonumber(self.watchIntervalMs) or 250) * 0.001
    log("WATCH t=%.2f pos=(%s,%s,%s) yaw[g=%s m=%s] speed=%s moverRot=%s force=(%s,%s) vel=(%s,%s,%s) delta=(%s,%s) ground=%s close=%s dist=%s anim[abs=%s rot=%s rel=(%s,%s) dir=(%s,%s) idle=%s walk=%s run=%s]",
        elapsed,
        compact(p.x), compact(p.y), compact(p.z),
        compact(p.graphicalYaw), compact(p.movementYaw), compact(p.speed), compact(p.moverRotationVelocity),
        compact(p.forceX), compact(p.forceZ),
        compact(p.velocityX), compact(p.velocityY), compact(p.velocityZ),
        compact(p.deltaX), compact(p.deltaZ),
        compact(p.grounded), compact(p.closeToGround), compact(p.groundDistance),
        compact(p.absSpeed), compact(p.rotationVelocity), compact(p.relativeVelocityX), compact(p.relativeVelocityZ),
        compact(p.movementDirX), compact(p.movementDirZ),
        compact(p.isIdling), compact(p.isWalking), compact(p.isRunning))

    if self.watchSlot ~= nil then
        local w = self:sampleWorker(self.watchSlot)
        if w ~= nil then
            log("WATCH worker=%s pos=(%s,%s,%s) yaw=%s anim[abs=%s rot=%s rel=(%s,%s) dir=(%s,%s) idle=%s walk=%s run=%s]",
                tostring(w.slot), compact(w.x), compact(w.y), compact(w.z), compact(w.yaw),
                compact(w.absSpeed), compact(w.rotationVelocity), compact(w.relativeVelocityX), compact(w.relativeVelocityZ),
                compact(w.movementDirX), compact(w.movementDirZ), compact(w.isIdling), compact(w.isWalking), compact(w.isRunning))
        end
    end
end

function Probe:startWatch(seconds, slot)
    seconds = tonumber(seconds) or 12
    seconds = math.max(2, math.min(60, seconds))
    self.watchActive = true
    self.watchRemainingMs = seconds * 1000
    self.watchSampleMs = 0
    self.sampleIndex = 0
    self.watchSlot = resolveIndex(slot)
    log("WATCH START duration=%.1fs interval=%dms worker=%s. Now walk, turn, curve, stop, and run if desired.",
        seconds, self.watchIntervalMs, self.watchSlot ~= nil and tostring(getSlot(self.watchSlot)) or "none")
end

function Probe:stopWatch(reason)
    if self.watchActive then
        log("WATCH STOP samples=%d reason=%s", self.sampleIndex or 0, tostring(reason or "requested"))
    end
    self.watchActive = false
    self.watchRemainingMs = 0
    self.watchSampleMs = 0
    self.watchSlot = nil
end

local function normalizeCommandArgs(...)
    local args = {...}
    local clean = {}
    for _, value in ipairs(args) do
        if value ~= nil and tostring(value) ~= "" and tostring(value) ~= "hpWorldProbe" then
            clean[#clean + 1] = tostring(value)
        end
    end
    return clean[1], clean[2], clean[3]
end

function Probe:consoleCommandProbe(...)
    local sub, arg1, arg2 = normalizeCommandArgs(...)
    sub = string.lower(tostring(sub or "help"))

    if sub == "help" then
        print("[HP] hpWorldProbe overview [slot]")
        print("[HP] hpWorldProbe watch [seconds] [slot]   -- default 12s, samples local player at 4 Hz")
        print("[HP] hpWorldProbe stop")
        print("[HP] Example: hpWorldProbe watch 15 A")
        return
    elseif sub == "overview" or sub == "status" then
        self:printOverview(arg1)
        return
    elseif sub == "watch" or sub == "start" then
        self:startWatch(arg1, arg2)
        return
    elseif sub == "stop" then
        self:stopWatch("console")
        return
    end

    print("[HP] Unknown hpWorldProbe command '" .. tostring(sub) .. "' (try: hpWorldProbe help)")
end

function Probe:registerConsoleCommand()
    if self.commandsRegistered then return end
    local registered = false
    if g_console ~= nil and g_console.addCommand ~= nil then
        g_console:addCommand("hpWorldProbe", "Inspect FS25 player movement/animation telemetry", "consoleCommandProbe", self)
        registered = true
    elseif addConsoleCommand ~= nil then
        addConsoleCommand("hpWorldProbe", "Inspect FS25 player movement/animation telemetry", "consoleCommandProbe", self)
        registered = true
    end
    _G.hpWorldProbe = function(...) return Probe:consoleCommandProbe(...) end
    self.commandsRegistered = registered
    log("Loaded %s commandRegistered=%s", tostring(self.version), tostring(registered))
end

function Probe:loadMap()
    self.initialized = true
    self:registerConsoleCommand()
end

function Probe:update(dt)
    if not self.initialized or not self.watchActive then return end

    local delta = tonumber(dt) or 0
    self.watchRemainingMs = self.watchRemainingMs - delta
    self.watchSampleMs = self.watchSampleMs - delta

    if self.watchSampleMs <= 0 then
        self.watchSampleMs = tonumber(self.watchIntervalMs) or 250
        self:printWatchSample()
    end

    if self.watchRemainingMs <= 0 then self:stopWatch("duration-complete") end
end

function Probe:deleteMap()
    self:stopWatch("map-delete")
    self.initialized = false
    self.commandsRegistered = false
    _G.hpWorldProbe = nil
end

addModEventListener(HP_WorldMovementProbe)
