-- HelperProfiles.lua

HelperProfiles = {}
HelperProfiles.profiles = {}
HelperProfiles.currentHelperIdx = 1
HelperProfiles.overlayText = ""
HelperProfiles.overlayTime = 0
HelperProfiles.xmlFile = nil
HelperProfiles.actionEventId = nil

function HelperProfiles:loadProfiles()
    local settingsDir = getUserProfileAppPath()
    local path = Utils.getFilename("modSettings/HelperProfiles/maps_helpers.xml", settingsDir)
    self.xmlFile = loadXMLFile("CustomHelpers", path)
    self.profiles = {}
    if not self.xmlFile then
        print("[FS25_HelperProfiles] ERROR: Could not load custom helpers file at: " .. tostring(path))
        return
    end

    local i = 0
    while true do
        local base = string.format("map.helpers.helper(%d)", i)
        local name = getXMLString(self.xmlFile, base.."#name")
        if not name or name == "" then break end

        -- Get helper color as a string
        local colorStr = getXMLString(self.xmlFile, base.."#color")

        -- Parse <playerStyle>
        local stylePath = base..".playerStyle"
        local playerStyle = { filename = getXMLString(self.xmlFile, stylePath.."#filename") or "" }

        -- For each possible child element of <playerStyle>
        local styleFields = {"bottom", "face", "top", "footwear", "hairStyle", "beard", "onepiece", "headgear"}
        for _, field in ipairs(styleFields) do
            local fieldPath = stylePath.."."..field.."(0)"
            local valName = getXMLString(self.xmlFile, fieldPath.."#name")
            local valColor = getXMLInt(self.xmlFile, fieldPath.."#color")
            if valName and valName ~= "" then
                playerStyle[field] = { name = valName }
                if valColor then playerStyle[field].color = valColor end
            end
        end

        table.insert(self.profiles, {
            name = name,
            color = colorStr,
            playerStyle = playerStyle
        })

        i = i + 1
    end
    self.currentHelperIdx = 1
    print("[FS25_HelperProfiles] Loaded custom helpers: " .. table.concat(
        (function() local t={} for _,v in ipairs(self.profiles) do t[#t+1]=v.name end return t end)(), ", "))
end

function HelperProfiles:rebuildHelperList()
    if not self.profiles or not g_helperManager then
        print("[FS25_HelperProfiles] No profiles or helper manager found!")
        return
    end

    g_helperManager.helpers = {}
    g_helperManager.nameToIndex = {}
    g_helperManager.indexToHelper = {}
    g_helperManager.availableHelpers = {}
    g_helperManager.numHelpers = 0

    for i, profile in ipairs(self.profiles) do
        local name = profile.name
        g_helperManager.numHelpers = g_helperManager.numHelpers + 1
        local entry = {
            name = name,
            title = name,
            index = g_helperManager.numHelpers,
            color = {1,1,1},
            playerStyle = profile.playerStyle or {}
        }
        g_helperManager.helpers[name] = entry
        g_helperManager.nameToIndex[name] = g_helperManager.numHelpers
        g_helperManager.indexToHelper[g_helperManager.numHelpers] = entry
        table.insert(g_helperManager.availableHelpers, entry)
    end

    -- Make sure the game knows the max number of helpers
    if g_currentMission then
        g_currentMission.maxNumHirables = g_helperManager.numHelpers
    end

    print(string.format("[FS25_HelperProfiles] Total helpers loaded: %d", g_helperManager.numHelpers))
end

function HelperProfiles:onCycleHelper(actionName, inputValue, callbackState, eventUsed)
    if #self.profiles == 0 then return end
    self.currentHelperIdx = self.currentHelperIdx + 1
    if self.currentHelperIdx > #self.profiles then self.currentHelperIdx = 1 end
    local p = self.profiles[self.currentHelperIdx]
    print("[FS25_HelperProfiles] Selected helper: " .. p.name)
    self.overlayText = "Active Helper: " .. p.name
    self.overlayTime = 2.5
end

function HelperProfiles:draw()
    if self.overlayTime and self.overlayTime > 0 then
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        renderText(0.45, 0.92, 0.03, self.overlayText)
        setTextBold(false)
        self.overlayTime = self.overlayTime - (g_currentDt or 16) / 1000
    end
end

function HelperProfiles:loadMap(mapName)
    self:loadProfiles()
    self:rebuildHelperList()
end

function HelperProfiles:update(dt)
    if g_currentMission and g_helperManager and g_currentMission.maxNumHirables ~= g_helperManager.numHelpers then
        g_currentMission.maxNumHirables = g_helperManager.numHelpers
    end
end

addModEventListener(HelperProfiles)
