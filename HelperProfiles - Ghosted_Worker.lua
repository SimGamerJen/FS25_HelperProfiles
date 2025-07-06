HelperProfiles = {}
HelperProfiles.xmlFile = nil

-- Central addHelper function (safe, like HiredHelperTool)
function HelperProfiles:addHelper(name, playerStyle)
    if not name or not playerStyle then
        print("[FS25_HelperProfiles] Skipping helper with missing name or style.")
        return
    end
    name = name:upper()
    if g_helperManager.nameToIndex[name] then
        print("[FS25_HelperProfiles] Helper '"..name.."' already exists, skipping.")
        return
    end
    g_helperManager.numHelpers = g_helperManager.numHelpers + 1
    local helper = {
        name = name,
        title = name,
        index = g_helperManager.numHelpers,
        color = {1,1,1}, -- You could parse your color string here if needed
        playerStyle = playerStyle
    }
    g_helperManager.helpers[name] = helper
    g_helperManager.nameToIndex[name] = g_helperManager.numHelpers
    g_helperManager.indexToHelper[g_helperManager.numHelpers] = helper
    table.insert(g_helperManager.availableHelpers, helper)
end

function HelperProfiles:loadProfiles()
    local settingsDir = getUserProfileAppPath()
    local path = Utils.getFilename("modSettings/HelperProfiles/maps_helpers.xml", settingsDir)
    if fileExists(path) then
        self.xmlFile = loadXMLFile("ProfilesHelpers", path)
        print("[FS25_HelperProfiles] Loaded custom profiles from: " .. path)
        return true
    else
        print("[FS25_HelperProfiles] profiles_helpers.xml NOT found at: " .. path)
        self.xmlFile = nil
        return false
    end
end

function HelperProfiles:rebuildHelperList()
    if self.xmlFile == nil or g_helperManager == nil then return end

    -- Reset tables
    g_helperManager.helpers = {}
    g_helperManager.nameToIndex = {}
    g_helperManager.indexToHelper = {}
    g_helperManager.availableHelpers = {}
    g_helperManager.numHelpers = 0

    local i = 0
    while true do
        local name = getXMLString(self.xmlFile, string.format("map.helpers.helper(%d)#name", i))
        if not name then break end
        local playerStyle = getXMLString(self.xmlFile, string.format("map.helpers.helper(%d).playerStyle#filename", i))
        if not playerStyle or playerStyle == "" then
            playerStyle = "dataS/character/playerM/playerM.xml"
        end
        self:addHelper(name, playerStyle)
        i = i + 1
    end
    g_currentMission.maxNumHirables = g_helperManager.numHelpers
end

function HelperProfiles:loadMap(mapName)
    if self:loadProfiles() then
        self:rebuildHelperList()
        print("[FS25_HelperProfiles] Custom helper list loaded and applied!")
    else
        print("[FS25_HelperProfiles] Custom profile load failed. Using default helpers.")
    end
end

function HelperProfiles:update(dt)
    if g_currentMission and g_helperManager and g_currentMission.maxNumHirables ~= g_helperManager.numHelpers then
        g_currentMission.maxNumHirables = g_helperManager.numHelpers
    end
end

addModEventListener(HelperProfiles)
