-- HP_WorldMovementProbeDelta.lua (FS25_HelperProfiles)
-- Alpha 4 probe refinement: discover which animation/graphics-state values
-- actually change while the local player moves, instead of relying only on
-- preselected parameter names.

if HP_WorldMovementProbe == nil then return end
if HP_WorldMovementProbeDelta ~= nil then return end

HP_WorldMovementProbeDelta = {
    version = "2.2.0.0-alpha4-movement-probe-delta-1",
    lastAnim = {},
    lastGraphicsState = {}
}

local Delta = HP_WorldMovementProbeDelta
local Probe = HP_WorldMovementProbe
local LOG = "[FS25_HelperProfiles/MovementProbe] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function findLocalPlayer()
    local mission = g_currentMission
    if mission == nil then return nil end
    if rawget(_G, "g_localPlayer") ~= nil and g_localPlayer ~= nil then return g_localPlayer end
    if mission.player ~= nil then return mission.player end
    local playerSystem = mission.playerSystem
    if playerSystem == nil then return nil end
    for _, player in pairs(playerSystem.players or {}) do
        if player ~= nil and (player.isOwner == true or player.isLocallyControlled == true) then return player end
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

local function readAnimParameter(graphics, parameter)
    if graphics == nil or parameter == nil then return nil end
    if graphics.animation ~= nil and graphics.animation.getParameter ~= nil then
        local ok, value = pcall(graphics.animation.getParameter, graphics.animation, parameter)
        if ok and (type(value) == "number" or type(value) == "boolean" or type(value) == "string") then return value end
    end
    if type(parameter) == "table" then
        for _, methodName in ipairs({"getValue", "getCurrentValue"}) do
            local method = parameter[methodName]
            if type(method) == "function" then
                local ok, value = pcall(method, parameter)
                if ok and (type(value) == "number" or type(value) == "boolean" or type(value) == "string") then return value end
            end
        end
        for _, fieldName in ipairs({"value", "currentValue", "lastValue"}) do
            local value = parameter[fieldName]
            if type(value) == "number" or type(value) == "boolean" or type(value) == "string" then return value end
        end
    end
    return nil
end

local function collectAnim(graphics)
    local values = {}
    if graphics == nil or type(graphics.animationParameters) ~= "table" then return values end
    for name, parameter in pairs(graphics.animationParameters) do
        local value = readAnimParameter(graphics, parameter)
        if value ~= nil then values[tostring(name)] = value end
    end
    return values
end

local function collectGraphicsState(state)
    local values = {}
    if type(state) ~= "table" then return values end
    for key, value in pairs(state) do
        local t = type(value)
        if t == "number" or t == "boolean" or t == "string" then values[tostring(key)] = value end
    end
    return values
end

local function changed(a, b)
    if a == nil then return true end
    if type(a) == "number" and type(b) == "number" then return math.abs(a - b) > 0.0005 end
    return a ~= b
end

local function fmt(value)
    if type(value) == "number" then return string.format("%.3f", value) end
    return tostring(value)
end

local function emitChanges(label, previous, current)
    local keys = {}
    for key, value in pairs(current) do
        if changed(previous[key], value) then keys[#keys + 1] = key end
    end
    table.sort(keys)
    if #keys == 0 then return end

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = key .. "=" .. fmt(current[key])
    end
    log("WATCH DELTA %s[%s]", tostring(label), table.concat(parts, " "))
end

local originalStartWatch = Probe.startWatch
function Probe:startWatch(seconds, slot, ...)
    Delta.lastAnim = {}
    Delta.lastGraphicsState = {}
    return originalStartWatch(self, seconds, slot, ...)
end

local originalPrintWatchSample = Probe.printWatchSample
function Probe:printWatchSample(...)
    originalPrintWatchSample(self, ...)

    local player = findLocalPlayer()
    if player == nil then return end

    local anim = collectAnim(player.graphicsComponent)
    local graphicsState = collectGraphicsState(player.graphicsState)

    emitChanges("playerAnim", Delta.lastAnim, anim)
    emitChanges("graphicsState", Delta.lastGraphicsState, graphicsState)

    Delta.lastAnim = anim
    Delta.lastGraphicsState = graphicsState
end

log("Loaded %s (dynamic animation/graphics-state delta logging)", tostring(Delta.version))
