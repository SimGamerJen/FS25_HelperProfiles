-- HP_WorldPedestrianProbe.lua (FS25_HelperProfiles)
-- Alpha 6 research probe for GIANTS' native PedestrianSystem / spline runtime.
--
-- This module is intentionally diagnostic-only. It does not alter world-worker
-- locomotion, graphics, obstacle handling, persistence or UI behaviour.
--
-- Commands:
--   hpWorld pedprobe
--   hpWorld pedprobe system
--   hpWorld pedprobe globals
--   hpWorld pedprobe mission
--   hpWorld pedprobe spline
--   hpWorld pedprobe scene
--   hpWorld pedprobe all

if HP_WorldWorkerManager == nil then return end
if HP_WorldPedestrianProbe ~= nil then return end

HP_WorldPedestrianProbe = {
    version = "2.2.0.0-alpha6-pedestrian-probe-1",
    installed = false,
    maxTableEntries = 180,
    maxSceneNodes = 12000,
    maxSceneDepth = 12
}

local Probe = HP_WorldPedestrianProbe
local Manager = HP_WorldWorkerManager
local LOG = "[FS25_HelperProfiles/PedestrianProbe] "

local function log(message, ...)
    local ok, text = pcall(string.format, tostring(message), ...)
    print(LOG .. (ok and text or tostring(message)))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function containsPedestrian(value)
    local text = lower(value)
    return string.find(text, "pedestrian", 1, true) ~= nil
        or string.find(text, "ped", 1, true) == 1
end

local function sortedKeys(tbl, predicate)
    local keys = {}
    if type(tbl) ~= "table" then return keys end
    for key, value in pairs(tbl) do
        if predicate == nil or predicate(key, value) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function functionInfo(fn)
    if type(fn) ~= "function" then return "" end
    if debug == nil or debug.getinfo == nil then return "function" end
    local ok, info = pcall(debug.getinfo, fn, "Sln")
    if not ok or info == nil then return "function" end

    local source = tostring(info.short_src or info.source or "?")
    local line = tonumber(info.linedefined) or -1
    local name = tostring(info.name or "")
    if name ~= "" then
        return string.format("function name=%s source=%s:%d", name, source, line)
    end
    return string.format("function source=%s:%d", source, line)
end

local function valueSummary(value)
    local t = type(value)
    if t == "function" then return functionInfo(value) end
    if t == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return string.format("table entries=%d tostring=%s", count, tostring(value))
    end
    if t == "userdata" then return "userdata " .. tostring(value) end
    if t == "string" then
        local text = value
        if #text > 160 then text = string.sub(text, 1, 157) .. "..." end
        return string.format("string %q", text)
    end
    return t .. " " .. tostring(value)
end

local function dumpTable(label, tbl, maxEntries)
    log("TABLE %s type=%s value=%s", tostring(label), type(tbl), tostring(tbl))
    if type(tbl) ~= "table" then return end

    local keys = sortedKeys(tbl)
    local limit = math.max(1, tonumber(maxEntries) or Probe.maxTableEntries)
    local shown = 0
    for _, key in ipairs(keys) do
        shown = shown + 1
        if shown > limit then
            log("TABLE %s truncated after %d/%d entries", tostring(label), limit, #keys)
            break
        end
        local ok, value = pcall(function() return tbl[key] end)
        if ok then
            log("  %s[%s] -> %s", tostring(label), tostring(key), valueSummary(value))
        else
            log("  %s[%s] -> <read error: %s>", tostring(label), tostring(key), tostring(value))
        end
    end
end

local function probeLikelySystemObjects()
    log("=== Pedestrian system candidates ===")

    local candidates = {
        {"_G.PedestrianSystem", rawget(_G, "PedestrianSystem")},
        {"_G.g_pedestrianSystem", rawget(_G, "g_pedestrianSystem")},
        {"g_currentMission.pedestrianSystem", g_currentMission ~= nil and g_currentMission.pedestrianSystem or nil},
        {"g_currentMission.pedestrianSystemManager", g_currentMission ~= nil and g_currentMission.pedestrianSystemManager or nil},
        {"g_currentMission.pedestrianManager", g_currentMission ~= nil and g_currentMission.pedestrianManager or nil}
    }

    for _, candidate in ipairs(candidates) do
        local label, value = candidate[1], candidate[2]
        log("CANDIDATE %s -> %s", label, valueSummary(value))
        if type(value) == "table" then dumpTable(label, value, Probe.maxTableEntries) end
    end
end

local function probeGlobals()
    log("=== Global keys containing pedestrian/ped* ===")
    local keys = sortedKeys(_G, function(key, _)
        return containsPedestrian(key)
    end)
    if #keys == 0 then
        log("No matching global keys found")
        return
    end

    for _, key in ipairs(keys) do
        local value = rawget(_G, key)
        log("GLOBAL %s -> %s", tostring(key), valueSummary(value))
    end
end

local function probeMission()
    log("=== Mission keys containing pedestrian/ped* ===")
    if type(g_currentMission) ~= "table" then
        log("g_currentMission unavailable or not a Lua table")
        return
    end

    local keys = sortedKeys(g_currentMission, function(key, _)
        return containsPedestrian(key)
    end)
    if #keys == 0 then
        log("No matching g_currentMission keys found")
        return
    end

    for _, key in ipairs(keys) do
        local value = g_currentMission[key]
        log("MISSION %s -> %s", tostring(key), valueSummary(value))
        if type(value) == "table" then dumpTable("mission." .. tostring(key), value, 100) end
    end
end

local function probeSplineRuntime()
    log("=== Spline runtime availability ===")

    local names = {
        "getSplineLength",
        "getSplinePosition",
        "getSplineDirection",
        "getSplineTime",
        "getSplineEP",
        "getNumOfSplineEPs",
        "getClosestSplinePosition",
        "getClosestSplinePositionVector",
        "createSplineFromEditPoints",
        "setSplineEP",
        "addSplineEP",
        "SplineUtil"
    }

    for _, name in ipairs(names) do
        local value = rawget(_G, name)
        log("SPLINE GLOBAL %s -> %s", name, valueSummary(value))
        if name == "SplineUtil" and type(value) == "table" then
            dumpTable("SplineUtil", value, 100)
        end
    end
end

local function safeNodeName(node)
    if node == nil or node == 0 or getName == nil then return "" end
    local ok, name = pcall(getName, node)
    return ok and tostring(name or "") or ""
end

local function safeChildCount(node)
    if node == nil or node == 0 or getNumOfChildren == nil then return 0 end
    local ok, count = pcall(getNumOfChildren, node)
    return ok and math.max(0, math.floor(tonumber(count) or 0)) or 0
end

local function safeChildAt(node, index)
    if getChildAt == nil then return nil end
    local ok, child = pcall(getChildAt, node, index)
    return ok and child or nil
end

local function nodePath(node, parentPath)
    local name = safeNodeName(node)
    if name == "" then name = "<unnamed:" .. tostring(node) .. ">" end
    if parentPath == nil or parentPath == "" then return name end
    return parentPath .. "/" .. name
end

local function probeScene()
    log("=== Scenegraph pedestrian node search ===")
    if getRootNode == nil then
        log("getRootNode unavailable")
        return
    end

    local okRoot, root = pcall(getRootNode)
    if not okRoot or root == nil or root == 0 then
        log("Unable to resolve scene root")
        return
    end

    local maxNodes = math.max(100, tonumber(Probe.maxSceneNodes) or 12000)
    local maxDepth = math.max(1, tonumber(Probe.maxSceneDepth) or 12)
    local stack = {{node = root, depth = 0, path = safeNodeName(root)}}
    local visited, matched = 0, 0

    while #stack > 0 and visited < maxNodes do
        local item = table.remove(stack)
        local node = item.node
        local depth = item.depth
        local path = item.path
        visited = visited + 1

        local name = safeNodeName(node)
        if containsPedestrian(name) or containsPedestrian(path) then
            matched = matched + 1
            log("SCENE MATCH node=%s depth=%d children=%d path=%s",
                tostring(node), depth, safeChildCount(node), tostring(path))
        end

        if depth < maxDepth then
            local count = safeChildCount(node)
            -- reverse push keeps child order readable when popped
            for i = count - 1, 0, -1 do
                local child = safeChildAt(node, i)
                if child ~= nil and child ~= 0 then
                    stack[#stack + 1] = {
                        node = child,
                        depth = depth + 1,
                        path = nodePath(child, path)
                    }
                end
            end
        end
    end

    log("SCENE SEARCH complete visited=%d matched=%d%s",
        visited, matched, visited >= maxNodes and " (node limit reached)" or "")
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

function Probe:run(mode)
    mode = lower(mode)
    if mode == "" then mode = "summary" end

    log("RUN %s mode=%s", tostring(self.version), mode)

    if mode == "summary" then
        probeLikelySystemObjects()
        probeMission()
        probeSplineRuntime()
    elseif mode == "system" then
        probeLikelySystemObjects()
    elseif mode == "globals" then
        probeGlobals()
    elseif mode == "mission" then
        probeMission()
    elseif mode == "spline" then
        probeSplineRuntime()
    elseif mode == "scene" then
        probeScene()
    elseif mode == "all" then
        probeLikelySystemObjects()
        probeGlobals()
        probeMission()
        probeSplineRuntime()
        probeScene()
    else
        log("Unknown mode '%s'. Use summary|system|globals|mission|spline|scene|all", mode)
        return false
    end

    log("DONE mode=%s", mode)
    return true
end

function Probe:install()
    if self.installed then return true end
    if Manager == nil or type(Manager.consoleCommandWorld) ~= "function" then return false end

    local originalConsole = Manager.consoleCommandWorld
    function Manager:consoleCommandWorld(...)
        local sub, mode = normalizeCommandArgs(...)
        sub = lower(sub or "status")

        if sub == "pedprobe" or sub == "pedestrianprobe" then
            Probe:run(mode)
            return
        elseif sub == "help" then
            originalConsole(self, ...)
            print("[HP] Alpha6 pedestrian research: hpWorld pedprobe [summary|system|globals|mission|spline|scene|all]")
            print("[HP] Probe is diagnostic-only; it does not alter world-worker movement.")
            return
        end

        return originalConsole(self, ...)
    end

    self.installed = true
    log("Loaded %s (diagnostic-only native PedestrianSystem + spline runtime inspection)", tostring(self.version))
    return true
end

Probe:install()
