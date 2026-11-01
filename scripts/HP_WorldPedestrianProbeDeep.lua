-- HP_WorldPedestrianProbeDeep.lua (FS25_HelperProfiles)
-- Alpha 6 follow-up probe after the first live PedestrianSystem inspection.
--
-- The first probe deliberately used rawget(_G, ...) and therefore hid engine
-- functions exposed through the GIANTS Lua environment/metatable. This layer
-- compares raw and normal global resolution, walks metatable/__index chains,
-- and samples the live pedestrian records owned by g_currentMission.
--
-- Commands added to the existing hpWorld pedprobe command:
--   hpWorld pedprobe deep
--   hpWorld pedprobe splineenv
--   hpWorld pedprobe pedestrians

if HP_WorldPedestrianProbe == nil then return end
if HP_WorldPedestrianProbeDeep ~= nil then return end

HP_WorldPedestrianProbeDeep = {
    version = "2.2.0.0-alpha6-pedestrian-deep-probe-1",
    maxEntries = 120,
    samplePedestrians = 4,
    installed = false
}

local Deep = HP_WorldPedestrianProbeDeep
local Probe = HP_WorldPedestrianProbe
local LOG = "[FS25_HelperProfiles/PedestrianProbe] "

local function log(message, ...)
    local ok, text = pcall(string.format, tostring(message), ...)
    print(LOG .. (ok and text or tostring(message)))
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function functionInfo(fn)
    if type(fn) ~= "function" then return "" end
    if debug == nil or debug.getinfo == nil then return "function" end
    local ok, info = pcall(debug.getinfo, fn, "Sln")
    if not ok or info == nil then return "function" end
    return string.format("function source=%s:%d", tostring(info.short_src or info.source or "?"), tonumber(info.linedefined) or -1)
end

local function valueSummary(value)
    local kind = type(value)
    if kind == "function" then return functionInfo(value) end
    if kind == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return string.format("table entries=%d tostring=%s", count, tostring(value))
    end
    if kind == "userdata" then return "userdata " .. tostring(value) end
    if kind == "string" then
        local text = value
        if #text > 180 then text = string.sub(text, 1, 177) .. "..." end
        return string.format("string %q", text)
    end
    return kind .. " " .. tostring(value)
end

local function sortedKeys(tbl)
    local keys = {}
    if type(tbl) ~= "table" then return keys end
    for key in pairs(tbl) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function dumpTable(label, tbl, maxEntries)
    log("TABLE %s -> %s", tostring(label), valueSummary(tbl))
    if type(tbl) ~= "table" then return end
    local limit = math.max(1, tonumber(maxEntries) or Deep.maxEntries)
    local keys = sortedKeys(tbl)
    for i, key in ipairs(keys) do
        if i > limit then
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

local function dumpMetatable(label, value)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        log("META %s -> unavailable for type=%s", tostring(label), type(value))
        return
    end

    local seen = {}
    local current = value
    for depth = 1, 5 do
        local ok, mt = pcall(getmetatable, current)
        if not ok or mt == nil then
            log("META %s depth=%d -> nil", tostring(label), depth)
            return
        end
        if seen[mt] then
            log("META %s depth=%d -> cycle %s", tostring(label), depth, tostring(mt))
            return
        end
        seen[mt] = true
        dumpTable(string.format("%s.__meta%d", tostring(label), depth), mt, Deep.maxEntries)

        local indexValue = rawget(mt, "__index")
        log("META %s depth=%d __index -> %s", tostring(label), depth, valueSummary(indexValue))
        if type(indexValue) == "table" then
            dumpTable(string.format("%s.__index%d", tostring(label), depth), indexValue, Deep.maxEntries)
            current = indexValue
        else
            return
        end
    end
end

local function resolveGlobal(name)
    local rawValue = rawget(_G, name)
    local normalValue = nil
    local ok, value = pcall(function() return _G[name] end)
    if ok then normalValue = value end
    return rawValue, normalValue
end

local function probeSplineEnvironment()
    log("=== Engine global resolution (rawget vs normal lookup) ===")
    local names = {
        "PedestrianSystem",
        "g_pedestrianSystem",
        "getSplineLength",
        "getSplinePosition",
        "getSplinePositionWithDistance",
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
        local rawValue, normalValue = resolveGlobal(name)
        log("ENV %s raw=%s | resolved=%s", tostring(name), valueSummary(rawValue), valueSummary(normalValue))
        if type(normalValue) == "table" and normalValue ~= rawValue then
            dumpTable("ENV." .. tostring(name), normalValue, 80)
        end
    end

    local ok, mt = pcall(getmetatable, _G)
    if ok and mt ~= nil then
        dumpTable("_G.__meta", mt, 80)
        local indexValue = rawget(mt, "__index")
        log("_G.__meta.__index -> %s", valueSummary(indexValue))
    else
        log("_G metatable unavailable")
    end
end

local function sampleCollection(label, collection)
    if type(collection) ~= "table" then
        log("%s unavailable: %s", tostring(label), valueSummary(collection))
        return
    end

    log("=== Sampling %s ===", tostring(label))
    local count = 0
    for key, value in pairs(collection) do
        count = count + 1
        if count > (tonumber(Deep.samplePedestrians) or 4) then break end
        local entryLabel = string.format("%s[%s]", tostring(label), tostring(key))
        log("SAMPLE %s -> %s", entryLabel, valueSummary(value))
        if type(value) == "table" then dumpTable(entryLabel, value, 100) end
        dumpMetatable(entryLabel, value)
    end
end

local function probePedestrianObjects()
    log("=== Live pedestrian object/class inspection ===")
    local mission = g_currentMission
    local system = mission ~= nil and mission.pedestrianSystem or nil
    log("SYSTEM -> %s", valueSummary(system))
    if type(system) ~= "table" then return end

    dumpTable("pedestrianSystem", system, Deep.maxEntries)
    dumpMetatable("pedestrianSystem", system)

    sampleCollection("pedestrianSystem.pedestrians", system.pedestrians)
    sampleCollection("pedestrianSystem.pedestrianNodes", system.pedestrianNodes)

    if type(system.groupNameToGroup) == "table" then
        dumpTable("pedestrianSystem.groupNameToGroup", system.groupNameToGroup, 40)
        sampleCollection("pedestrianSystem.groupNameToGroup", system.groupNameToGroup)
    end
end

local originalRun = Probe.run
function Probe:run(mode)
    local normalized = lower(mode)
    if normalized == "deep" then
        log("RUN %s mode=deep", tostring(Deep.version))
        probeSplineEnvironment()
        probePedestrianObjects()
        log("DONE mode=deep")
        return true
    elseif normalized == "splineenv" or normalized == "engine" then
        log("RUN %s mode=splineenv", tostring(Deep.version))
        probeSplineEnvironment()
        log("DONE mode=splineenv")
        return true
    elseif normalized == "pedestrians" or normalized == "objects" then
        log("RUN %s mode=pedestrians", tostring(Deep.version))
        probePedestrianObjects()
        log("DONE mode=pedestrians")
        return true
    end
    return originalRun(self, mode)
end

Deep.installed = true
log("Loaded %s (metatable/class + live pedestrian record inspection; raw/resolved engine globals)", tostring(Deep.version))
