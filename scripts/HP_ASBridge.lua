-- HP_ASBridge.lua (FS25_HelperProfiles)
-- ModVersion: 2.0.20
-- BuildTag: 20260513.4
-- Optional bridge to FS25_AvatarSwitcher presets.
-- v2.0.3: adds direct preset-file fallback because FS25/Luau can isolate mod globals.
-- v2.0.6: makes AS presetId the primary binding key; category is legacy/UI metadata.
-- v2.0.7: stores helper appearance links per savegame and adds unbind/clear support.
-- v2.0.8: exposes snapshot/category helpers for the mouse-driven binding menu.
-- v2.0.9: adds derived per-save helper display names from bound AS presets.

HP_ASBridge = HP_ASBridge or {
    initialized = false,
    debugEnabled = false,
    profilePath = nil,
    modSettingsDir = nil,
    savesDir = nil,
    savegameName = nil,
    savegameDir = nil,
    globalLinksFile = nil,
    linksFile = nil,
    asPresetFile = nil,
    linksByHelperName = {},
    directPresets = {},
    directPresetsById = {},
    directLoaded = false,
    directLoadedAt = -1,
    lastWarningAt = -999999,
}

local LOG = "[FS25_HelperProfiles/ASBridge] "
local function hpPrint(msg) print(LOG .. tostring(msg)) end

local STYLE_PARTS = {
    "facegear",
    "onepiece",
    "bottom",
    "face",
    "top",
    "gloves",
    "headgear",
    "glasses",
    "footwear",
    "hairStyle",
    "beard"
}

local function normalizeName(value)
    local s = tostring(value or "")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s:lower()
end

local function trim(value)
    local s = tostring(value or "")
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function deriveDisplayNameFromPreset(preset, fallback)
    if type(preset) ~= "table" then return fallback end

    local label = trim(preset.description or preset.desc or preset.name or "")
    if label ~= "" then
        -- Common AS naming convention: "Jen - Default Farmwear" / "Marty - Default Outfit".
        local beforeDash = label:match("^(.-)%s+%-%s+.+$")
        if beforeDash ~= nil and trim(beforeDash) ~= "" then
            return trim(beforeDash)
        end

        -- Fallback: strip common outfit suffixes when users name presets without a dash.
        local cleaned = label
        cleaned = cleaned:gsub("%s+[Dd]efault%s+[Oo]utfit$", "")
        cleaned = cleaned:gsub("%s+[Dd]efault%s+[Ff]armwear$", "")
        cleaned = cleaned:gsub("%s+[Ww]orkwear$", "")
        cleaned = trim(cleaned)
        if cleaned ~= "" then return cleaned end
    end

    local cat = trim(preset.characterId or preset.category or "")
    if cat ~= "" and cat:lower() ~= "general" then return cat end
    return fallback
end

local function fileExistsSafe(path)
    return path ~= nil and path ~= "" and fileExists(path)
end

local function normalizePathSlashes(path)
    if path == nil then return nil end
    return tostring(path):gsub("\\", "/")
end

local function getPathBaseName(path)
    path = normalizePathSlashes(path or "") or ""
    path = path:gsub("/+$", "")
    local base = path:match("([^/]+)$")
    if base ~= nil and base ~= "" then return base end
    return nil
end

local function detectSavegameName()
    local mi = g_currentMission ~= nil and g_currentMission.missionInfo or nil
    if mi ~= nil then
        local candidates = {
            mi.savegameDirectory,
            mi.savegameDir,
            mi.savegamePath,
            mi.savegameXMLFilename,
            mi.savegameSavePath,
        }
        for _, value in ipairs(candidates) do
            if value ~= nil and tostring(value) ~= "" then
                local path = normalizePathSlashes(value)
                local match = path and path:match("(savegame%d+)")
                if match ~= nil and match ~= "" then return match end
                local base = getPathBaseName(path)
                if base ~= nil and base ~= "" then return base end
            end
        end

        local index = mi.savegameIndex or mi.savegameNumber or mi.saveGameIndex or mi.saveGameNumber
        if index ~= nil and tonumber(index) ~= nil then
            return "savegame" .. tostring(math.floor(tonumber(index)))
        end
    end

    -- Fallback for very early initialisation. This should be rare once the map
    -- is loaded, but keeps config writes deterministic rather than failing.
    return "unknownSavegame"
end

local function ensureFolderSafe(path)
    if path ~= nil and path ~= "" and not fileExists(path) then
        createFolder(path)
    end
end

local function getASAPI()
    -- Keep this for future compatibility, but do not rely on it. In current
    -- testing, the AvatarSwitcher mod global is not visible to HelperProfiles.
    if _G ~= nil then
        return _G.AvatarSwitcherAPI or _G.FS25_AvatarSwitcherAPI or AvatarSwitcherAPI
    end
    return AvatarSwitcherAPI
end

local function hp_getXMLIntOrString(xmlFile, key)
    local value = getXMLString(xmlFile, key)
    if value == nil then
        local intValue = getXMLInt(xmlFile, key)
        if intValue ~= nil then
            value = tostring(intValue)
        end
    end
    return value
end

local function hp_readStyleFromXML(xmlFile, baseKey)
    if xmlFile == nil or baseKey == nil then return nil end
    if not hasXMLProperty(xmlFile, baseKey) then return nil end

    local style = {
        filename = getXMLString(xmlFile, baseKey .. "#filename"),
        parts = {}
    }

    for _, partName in ipairs(STYLE_PARTS) do
        local partKey = baseKey .. "." .. partName
        if hasXMLProperty(xmlFile, partKey) then
            style.parts[partName] = {
                name = getXMLString(xmlFile, partKey .. "#name"),
                color = hp_getXMLIntOrString(xmlFile, partKey .. "#color")
            }
        end
    end

    return style
end

local function hp_setConfigSelection(playerStyle, configName, part)
    if playerStyle == nil or playerStyle.configs == nil or part == nil then
        return true
    end

    local config = playerStyle.configs[configName]
    if config == nil then
        hpPrint("[DirectRuntimeStyle] No PlayerStyle config found for: " .. tostring(configName))
        return false
    end

    local ok = true

    if part.name ~= nil and tostring(part.name) ~= "" then
        local name = tostring(part.name)
        if config.setSelectedItemName ~= nil then
            local callOk, err = pcall(config.setSelectedItemName, config, name)
            if not callOk then
                hpPrint("[DirectRuntimeStyle] setSelectedItemName failed for " .. tostring(configName) .. "=" .. name .. " | " .. tostring(err))
                ok = false
            end
        elseif config.getItemNameIndex ~= nil then
            local index = config:getItemNameIndex(name)
            if index ~= nil then
                config.selectedItemIndex = index
            else
                hpPrint("[DirectRuntimeStyle] Could not resolve item name for " .. tostring(configName) .. ": " .. name)
                ok = false
            end
        else
            hpPrint("[DirectRuntimeStyle] Config has no item-name setter for " .. tostring(configName))
            ok = false
        end
    end

    if part.color ~= nil then
        local colorIndex = tonumber(part.color)
        if colorIndex ~= nil then
            if config.setSelectedColorIndex ~= nil then
                local callOk, err = pcall(config.setSelectedColorIndex, config, colorIndex)
                if not callOk then
                    hpPrint("[DirectRuntimeStyle] setSelectedColorIndex failed for " .. tostring(configName) .. "=" .. tostring(colorIndex) .. " | " .. tostring(err))
                    ok = false
                end
            else
                config.selectedColorIndex = colorIndex
            end
        end
    end

    return ok
end

local function hp_isPlayerStyle(value)
    if type(value) ~= "table" then return false end
    if type(value.configs) == "table" then
        return type(value.copyFrom) == "function"
            or type(value.copySelectionFrom) == "function"
            or type(value.writeStream) == "function"
    end
    return type(value.faceConfig) == "table"
        and type(value.topConfig) == "table"
        and type(value.bottomConfig) == "table"
        and type(value.footwearConfig) == "table"
end

function HP_ASBridge:debug(msg)
    if self.debugEnabled then hpPrint(msg) end
end

function HP_ASBridge:init()
    if self.initialized then return end
    self.initialized = true
    self.profilePath = getUserProfileAppPath()
    self.modSettingsDir = self.profilePath .. "modSettings/FS25_HelperProfiles/"
    self.savesDir = self.modSettingsDir .. "saves/"
    self.savegameName = detectSavegameName()
    self.savegameDir = self.savesDir .. tostring(self.savegameName or "unknownSavegame") .. "/"
    self.globalLinksFile = self.modSettingsDir .. "appearanceLinks.xml"
    self.linksFile = self.savegameDir .. "appearanceLinks.xml"
    self.asPresetFile = self.profilePath .. "modSettings/FS25_AvatarSwitcher/avatarPresets.xml"

    ensureFolderSafe(self.modSettingsDir)
    ensureFolderSafe(self.savesDir)
    ensureFolderSafe(self.savegameDir)

    if fileExistsSafe(self.linksFile) then
        self:readLinks(self.linksFile)
    elseif fileExistsSafe(self.globalLinksFile) then
        -- One-time compatibility migration from the old global 2.0.x file into
        -- the current savegame. Future writes are per-save only.
        self:readLinks(self.globalLinksFile)
        self:writeLinks()
        hpPrint("Migrated global appearance links to per-save file: " .. tostring(self.linksFile))
    else
        self.linksByHelperName = {}
        self:writeLinks()
    end

    self:loadDirectPresets(false)
end

function HP_ASBridge:readLinks(path)
    self.linksByHelperName = {}
    local src = path or self.linksFile
    if not fileExistsSafe(src) then return false end

    local xmlFile = loadXMLFile("hpAppearanceLinksRead", src)
    if xmlFile == nil or xmlFile == 0 then
        hpPrint("Could not read appearance links: " .. tostring(src))
        return false
    end

    local i = 0
    while true do
        local key = string.format("helperProfilesAppearance.links.helper(%d)", i)
        if not hasXMLProperty(xmlFile, key) then break end

        local helperName = getXMLString(xmlFile, key .. "#name")
        local category = getXMLString(xmlFile, key .. "#category")
        local presetId = getXMLString(xmlFile, key .. "#presetId")
        local selectedPresetId = getXMLString(xmlFile, key .. "#selectedPresetId")
        local characterId = getXMLString(xmlFile, key .. "#characterId")
        local displayName = getXMLString(xmlFile, key .. "#displayName")

        if helperName ~= nil and helperName ~= "" then
            local effectivePresetId = presetId or selectedPresetId
            local preset = effectivePresetId ~= nil and self:getDirectPresetById(effectivePresetId) or nil
            self.linksByHelperName[normalizeName(helperName)] = {
                name = helperName,
                displayName = displayName or deriveDisplayNameFromPreset(preset, helperName),
                category = category or helperName,
                presetId = effectivePresetId,
                selectedPresetId = selectedPresetId or presetId, -- legacy alias
                characterId = characterId,
            }
        end
        i = i + 1
    end

    delete(xmlFile)
    self:debug("Loaded appearance links: " .. tostring(i) .. " from " .. tostring(src))
    return true
end

function HP_ASBridge:writeLinks()
    if not fileExists(self.modSettingsDir) then createFolder(self.modSettingsDir) end

    local xmlFile = createXMLFile("hpAppearanceLinksWrite", self.linksFile, "helperProfilesAppearance")
    if xmlFile == nil or xmlFile == 0 then
        hpPrint("Could not write appearance links: " .. tostring(self.linksFile))
        return false
    end

    setXMLString(xmlFile, "helperProfilesAppearance#version", "2.0.20")
    setXMLString(xmlFile, "helperProfilesAppearance#savegame", tostring(self.savegameName or "unknownSavegame"))
    setXMLString(xmlFile, "helperProfilesAppearance#note", "Per-save helper appearance links. Bind helper names to AvatarSwitcher preset IDs. Use the HP appearance menu or hpAppearance bind <helperIndex> <presetId>. Category is stored as metadata/legacy fallback. displayName is derived from the bound AvatarSwitcher preset and used by the HP overlay/menu.")

    local rows = {}
    for _, link in pairs(self.linksByHelperName or {}) do table.insert(rows, link) end
    table.sort(rows, function(a,b) return tostring(a.name or "") < tostring(b.name or "") end)

    for i, link in ipairs(rows) do
        local key = string.format("helperProfilesAppearance.links.helper(%d)", i - 1)
        setXMLString(xmlFile, key .. "#name", tostring(link.name or ""))
        if link.displayName ~= nil and link.displayName ~= "" then
            setXMLString(xmlFile, key .. "#displayName", tostring(link.displayName))
        end
        if link.presetId ~= nil and link.presetId ~= "" then
            setXMLString(xmlFile, key .. "#presetId", tostring(link.presetId))
        end
        if link.category ~= nil and link.category ~= "" then
            setXMLString(xmlFile, key .. "#category", tostring(link.category))
        end
        if link.characterId ~= nil and link.characterId ~= "" then
            setXMLString(xmlFile, key .. "#characterId", tostring(link.characterId))
        end
        -- Backward compatibility for older 2.0.x builds.
        if link.selectedPresetId ~= nil and link.selectedPresetId ~= "" then
            setXMLString(xmlFile, key .. "#selectedPresetId", tostring(link.selectedPresetId))
        elseif link.presetId ~= nil and link.presetId ~= "" then
            setXMLString(xmlFile, key .. "#selectedPresetId", tostring(link.presetId))
        end
    end

    saveXMLFile(xmlFile)
    delete(xmlFile)
    return true
end

function HP_ASBridge:loadDirectPresets(force)
    self.directPresets = self.directPresets or {}
    self.directPresetsById = self.directPresetsById or {}

    if force ~= true and self.directLoaded == true then
        return true
    end

    self.directPresets = {}
    self.directPresetsById = {}
    self.directLoaded = false

    if not fileExistsSafe(self.asPresetFile) then
        return false, "avatar-presets-file-missing"
    end

    local xmlFile = loadXMLFile("hpDirectAvatarSwitcherPresets", self.asPresetFile)
    if xmlFile == nil or xmlFile == 0 then
        hpPrint("Could not read AvatarSwitcher presets directly: " .. tostring(self.asPresetFile))
        return false, "avatar-presets-file-unreadable"
    end

    local i = 0
    while true do
        local presetKey = string.format("avatarSwitcher.presets.preset(%d)", i)
        if not hasXMLProperty(xmlFile, presetKey) then break end

        local id = getXMLString(xmlFile, presetKey .. "#id")
        local name = getXMLString(xmlFile, presetKey .. "#name") or id
        local description = getXMLString(xmlFile, presetKey .. "#description") or getXMLString(xmlFile, presetKey .. "#desc")
        local category = getXMLString(xmlFile, presetKey .. "#category") or "general"
        local sortOrder = getXMLInt(xmlFile, presetKey .. "#sortOrder") or (i + 1)
        local style = hp_readStyleFromXML(xmlFile, presetKey .. ".lastPlayerStyle")

        if id ~= nil and id ~= "" and style ~= nil then
            local preset = { id = id, name = name, description = description, category = category, sortOrder = sortOrder, style = style, source = "direct" }
            table.insert(self.directPresets, preset)
            self.directPresetsById[id] = preset
        else
            hpPrint("Skipped invalid direct AvatarSwitcher preset at index " .. tostring(i))
        end

        i = i + 1
    end

    delete(xmlFile)

    table.sort(self.directPresets, function(a, b)
        local ac, bc = tostring(a.category or ""), tostring(b.category or "")
        if ac ~= bc then return ac < bc end
        local ao, bo = tonumber(a.sortOrder or 0) or 0, tonumber(b.sortOrder or 0) or 0
        if ao ~= bo then return ao < bo end
        return tostring(a.name or a.id or "") < tostring(b.name or b.id or "")
    end)

    self.directLoaded = true
    self.directLoadedAt = g_time or 0
    self:debug("Loaded direct AvatarSwitcher preset(s): " .. tostring(#self.directPresets))
    return true
end

function HP_ASBridge:getDirectPresetsByCategory(category)
    self:init()
    self:loadDirectPresets(false)
    local results = {}
    local wanted = tostring(category or ""):lower()
    if wanted == "" then return results end

    for _, preset in ipairs(self.directPresets or {}) do
        if tostring(preset.category or ""):lower() == wanted then
            table.insert(results, preset)
        end
    end

    table.sort(results, function(a, b)
        local ao, bo = tonumber(a.sortOrder or 0) or 0, tonumber(b.sortOrder or 0) or 0
        if ao ~= bo then return ao < bo end
        return tostring(a.name or a.id or "") < tostring(b.name or b.id or "")
    end)
    return results
end

function HP_ASBridge:getDirectPresetById(presetId)
    self:init()
    self:loadDirectPresets(false)
    if presetId == nil or presetId == "" then return nil end
    return self.directPresetsById[tostring(presetId)]
end

function HP_ASBridge:getAllPresets()
    self:init()
    self:loadDirectPresets(false)
    local rows = {}
    for _, preset in ipairs(self.directPresets or {}) do table.insert(rows, preset) end
    table.sort(rows, function(a, b)
        local ac, bc = tostring(a.category or ""):lower(), tostring(b.category or ""):lower()
        if ac ~= bc then return ac < bc end
        local ao, bo = tonumber(a.sortOrder or 0) or 0, tonumber(b.sortOrder or 0) or 0
        if ao ~= bo then return ao < bo end
        return tostring(a.description or a.name or a.id or "") < tostring(b.description or b.name or b.id or "")
    end)
    return rows
end

function HP_ASBridge:getCategories()
    self:init()
    self:loadDirectPresets(false)
    local seen, rows = {}, {}
    for _, preset in ipairs(self.directPresets or {}) do
        local cat = tostring(preset.category or "general")
        local key = cat:lower()
        if seen[key] ~= true then
            seen[key] = true
            table.insert(rows, cat)
        end
    end
    table.sort(rows, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return rows
end

function HP_ASBridge:getPresetsByCategoryForMenu(category)
    self:init()
    self:loadDirectPresets(false)
    local rows = self:getDirectPresetsByCategory(category)
    table.sort(rows, function(a, b)
        local ao, bo = tonumber(a.sortOrder or 0) or 0, tonumber(b.sortOrder or 0) or 0
        if ao ~= bo then return ao < bo end
        return tostring(a.description or a.name or a.id or "") < tostring(b.description or b.name or b.id or "")
    end)
    return rows
end

function HP_ASBridge:getLinksSnapshot()
    self:init()
    local out = {}
    for key, link in pairs(self.linksByHelperName or {}) do
        out[key] = {
            name = link.name,
            displayName = link.displayName,
            category = link.category,
            presetId = link.presetId or link.selectedPresetId,
            selectedPresetId = link.selectedPresetId or link.presetId,
            characterId = link.characterId,
        }
    end
    return out
end

function HP_ASBridge:replaceLinksSnapshot(snapshot)
    self:init()
    self.linksByHelperName = {}
    for key, link in pairs(snapshot or {}) do
        if link ~= nil and link.name ~= nil and tostring(link.name) ~= "" and link.presetId ~= nil and tostring(link.presetId) ~= "" then
            local preset = self:getDirectPresetById(link.presetId) or self:getPresetById(link.presetId)
            self.linksByHelperName[normalizeName(link.name)] = {
                name = tostring(link.name),
                displayName = link.displayName or deriveDisplayNameFromPreset(preset, tostring(link.name)),
                presetId = tostring(link.presetId),
                selectedPresetId = tostring(link.selectedPresetId or link.presetId),
                category = (preset ~= nil and preset.category) or link.category,
                characterId = (preset ~= nil and preset.characterId) or link.characterId,
            }
        end
    end
    return self:writeLinks()
end

function HP_ASBridge:getPresetById(presetId)
    self:init()
    if presetId == nil or presetId == "" then return nil, "no-preset-id" end

    local api = getASAPI()
    if api ~= nil and type(api.getPreset) == "function" then
        local ok, preset = pcall(api.getPreset, presetId)
        if ok and type(preset) == "table" then
            return preset, nil
        end
    end

    if not self:isDirectAvailable() then
        return nil, "avatar-switcher-unavailable"
    end

    local preset = self:getDirectPresetById(presetId)
    if preset ~= nil then return preset, nil end
    return nil, "preset-id-not-found"
end

function HP_ASBridge:isApiAvailable()
    local api = getASAPI()
    if api == nil then return false end
    return type(api.getPresetsByCategory) == "function" and type(api.createPlayerStyleFromPresetId) == "function"
end

function HP_ASBridge:isDirectAvailable()
    self:init()
    if not fileExistsSafe(self.asPresetFile) then return false end
    self:loadDirectPresets(false)
    return #(self.directPresets or {}) > 0
end

function HP_ASBridge:isAvailable()
    return self:isApiAvailable() or self:isDirectAvailable()
end

function HP_ASBridge:getHelperName(helper, fallbackIndex)
    if helper ~= nil and helper.name ~= nil and helper.name ~= "" then return tostring(helper.name) end
    return "Helper " .. tostring(fallbackIndex or "?")
end

function HP_ASBridge:getLinkForHelper(helper, fallbackIndex)
    self:init()
    local helperName = self:getHelperName(helper, fallbackIndex)
    local key = normalizeName(helperName)
    local link = self.linksByHelperName[key]
    if link ~= nil then return link end
    return { name = helperName, displayName = nil, category = helperName, presetId = nil, selectedPresetId = nil, implicit = true }
end

function HP_ASBridge:setLink(helper, fallbackIndex, category, selectedPresetId)
    -- Legacy API: category first, optional selectedPresetId. Kept for old console/config compatibility.
    self:init()
    local helperName = self:getHelperName(helper, fallbackIndex)
    if category == nil or category == "" then category = helperName end
    local preset = selectedPresetId ~= nil and self:getDirectPresetById(selectedPresetId) or nil
    self.linksByHelperName[normalizeName(helperName)] = {
        name = helperName,
        displayName = deriveDisplayNameFromPreset(preset, helperName),
        category = tostring(category),
        presetId = selectedPresetId,
        selectedPresetId = selectedPresetId,
    }
    self:writeLinks()
    return true
end

function HP_ASBridge:setLinkByPresetId(helper, fallbackIndex, presetId)
    self:init()
    local helperName = self:getHelperName(helper, fallbackIndex)
    if presetId == nil or tostring(presetId) == "" then return false, "no-preset-id" end

    local preset, err = self:getPresetById(tostring(presetId))
    if preset == nil then return false, err or "preset-id-not-found" end

    self.linksByHelperName[normalizeName(helperName)] = {
        name = helperName,
        displayName = deriveDisplayNameFromPreset(preset, helperName),
        presetId = tostring(preset.id or presetId),
        selectedPresetId = tostring(preset.id or presetId), -- legacy alias
        category = preset.category,
        characterId = preset.characterId,
    }
    self:writeLinks()
    return true, preset
end

function HP_ASBridge:unbindLink(helper, fallbackIndex)
    self:init()
    local helperName = self:getHelperName(helper, fallbackIndex)
    self.linksByHelperName[normalizeName(helperName)] = nil
    self:writeLinks()
    return true, helperName
end

function HP_ASBridge:clearLinks()
    self:init()
    self.linksByHelperName = {}
    self:writeLinks()
    return true
end

function HP_ASBridge:getLinksFile()
    self:init()
    return self.linksFile
end

function HP_ASBridge:getSavegameName()
    self:init()
    return self.savegameName
end

function HP_ASBridge:getPresetsForHelper(helper, fallbackIndex)
    self:init()
    local link = self:getLinkForHelper(helper, fallbackIndex)
    local category = link and link.category or nil
    if category == nil or category == "" then return {}, "no-category", link end

    local api = getASAPI()
    if self:isApiAvailable() then
        local ok, presets = pcall(api.getPresetsByCategory, category)
        if ok and type(presets) == "table" then
            return presets, nil, link
        end
        hpPrint("AvatarSwitcherAPI preset query failed; falling back to direct XML. error=" .. tostring(presets))
    end

    if not self:isDirectAvailable() then
        return {}, "avatar-switcher-unavailable", link
    end

    return self:getDirectPresetsByCategory(category), nil, link
end

function HP_ASBridge:getSelectedPresetForHelper(helper, fallbackIndex)
    self:init()
    local link = self:getLinkForHelper(helper, fallbackIndex)

    -- Primary model: exact AS preset ID. Category is metadata/fallback only.
    local exactId = link and (link.presetId or link.selectedPresetId) or nil
    if exactId ~= nil and tostring(exactId) ~= "" then
        local preset, err = self:getPresetById(tostring(exactId))
        if preset ~= nil then return preset, nil, link end
        -- Fall through to legacy category handling if an old/stale ID cannot resolve.
        self:debug("Preset ID did not resolve; trying legacy category fallback. id=" .. tostring(exactId) .. " err=" .. tostring(err))
    end

    local presets, err = self:getPresetsForHelper(helper, fallbackIndex)
    if err ~= nil then return nil, err, link end
    if #presets == 0 then return nil, "no-presets-in-category", link end

    if exactId ~= nil and tostring(exactId) ~= "" then
        for _, preset in ipairs(presets) do
            if tostring(preset.id) == tostring(exactId) then return preset, nil, link end
        end
    end

    return presets[1], nil, link
end

function HP_ASBridge:cycleAppearance(helper, fallbackIndex, delta)
    self:init()
    delta = tonumber(delta) or 1
    local presets, err, link = self:getPresetsForHelper(helper, fallbackIndex)
    if err ~= nil then return false, err end
    if #presets == 0 then return false, "no-presets-in-category" end

    local currentId = link and link.selectedPresetId or nil
    local currentIndex = 1
    if currentId ~= nil and currentId ~= "" then
        for i, preset in ipairs(presets) do
            if tostring(preset.id) == tostring(currentId) then currentIndex = i; break end
        end
    end

    local newIndex = ((currentIndex - 1 + delta) % #presets) + 1
    local selected = presets[newIndex]
    self:setLinkByPresetId(helper, fallbackIndex, selected.id)
    return true, selected
end

function HP_ASBridge:getDisplayNameForHelper(helper, fallbackIndex)
    self:init()
    local helperName = self:getHelperName(helper, fallbackIndex)
    local link = self.linksByHelperName[normalizeName(helperName)]
    if link ~= nil then
        if link.displayName ~= nil and tostring(link.displayName) ~= "" then
            return tostring(link.displayName), helperName
        end
        local preset = nil
        local presetId = link.presetId or link.selectedPresetId
        if presetId ~= nil and tostring(presetId) ~= "" then
            preset = self:getDirectPresetById(presetId) or self:getPresetById(presetId)
        end
        local derived = deriveDisplayNameFromPreset(preset, helperName)
        if derived ~= nil and tostring(derived) ~= "" then return tostring(derived), helperName end
    end
    return helperName, helperName
end

function HP_ASBridge:deriveDisplayNameFromPreset(preset, fallback)
    return deriveDisplayNameFromPreset(preset, fallback)
end

function HP_ASBridge:getAppearanceLabelForHelper(helper, fallbackIndex)
    local preset, err, link = self:getSelectedPresetForHelper(helper, fallbackIndex)
    if preset ~= nil then
        local mode = preset.source == "direct" and "direct" or "api"
        return tostring(preset.name or preset.id) .. " [" .. mode .. "]", tostring(preset.id), tostring(preset.category or (link and link.category) or "")
    end
    if err == "avatar-switcher-unavailable" then return "AS presets unavailable", nil, nil end
    if link ~= nil and link.presetId ~= nil then return "no AS preset id: " .. tostring(link.presetId), tostring(link.presetId), link.category end
    if link ~= nil and link.category ~= nil then return "no AS preset: " .. tostring(link.category), nil, link.category end
    return "no AS preset", nil, nil
end

function HP_ASBridge:createPlayerStyleFromPresetStyle(style)
    if style == nil then return nil, "no-style" end
    if PlayerStyle == nil or PlayerStyle.new == nil then return nil, "playerstyle-class-unavailable" end

    local playerStyle = PlayerStyle.new()

    if style.filename ~= nil and playerStyle.loadConfigurationXML ~= nil then
        local ok, err = pcall(playerStyle.loadConfigurationXML, playerStyle, style.filename)
        if not ok then return nil, "loadConfigurationXML-failed: " .. tostring(err) end
    elseif style.filename ~= nil then
        playerStyle.xmlFilename = style.filename
    end

    local allOk = true
    if style.parts ~= nil then
        for _, partName in ipairs(STYLE_PARTS) do
            local part = style.parts[partName]
            if part ~= nil then
                local ok = hp_setConfigSelection(playerStyle, partName, part)
                allOk = allOk and ok
            end
        end
    end

    if playerStyle.updateDisabledOptions ~= nil then pcall(playerStyle.updateDisabledOptions, playerStyle) end
    if not allOk then hpPrint("[DirectRuntimeStyle] Built PlayerStyle, but one or more selections could not be resolved") end
    if not hp_isPlayerStyle(playerStyle) then return nil, "not-playerstyle" end
    return playerStyle, nil
end

function HP_ASBridge:createPlayerStyleForHelper(helper, fallbackIndex)
    local preset, err = self:getSelectedPresetForHelper(helper, fallbackIndex)
    if preset == nil then return nil, err or "no-preset" end

    local style, buildErr = nil, nil
    local api = getASAPI()
    if preset.source ~= "direct" and self:isApiAvailable() then
        local ok, apiStyle, apiErr = pcall(api.createPlayerStyleFromPresetId, preset.id)
        if ok then style, buildErr = apiStyle, apiErr else buildErr = tostring(apiStyle) end
    end

    if style == nil then
        style, buildErr = self:createPlayerStyleFromPresetStyle(preset.style)
    end

    if style == nil then return nil, buildErr or "style-build-failed", preset end

    style.hpIsHelperProfilesStyle = true
    style.hpPresetId = tostring(preset.id)
    return style, nil, preset
end

function HP_ASBridge:reload()
    self.initialized = false
    self.directLoaded = false
    self:init()
    local api = getASAPI()
    if self:isApiAvailable() and api ~= nil and api.reload ~= nil then pcall(api.reload) end
    self:loadDirectPresets(true)
end

addModEventListener(HP_ASBridge)

function HP_ASBridge:loadMap()
    self:init()
    local api = getASAPI()
    local directOk = self:isDirectAvailable()
    hpPrint("Loaded. Appearance provider available=" .. tostring(self:isAvailable()) .. " | api=" .. tostring(self:isApiAvailable()) .. " | global=" .. tostring(_G ~= nil and _G.AvatarSwitcherAPI ~= nil) .. " | direct=" .. tostring(directOk) .. " | directPresetCount=" .. tostring(#(self.directPresets or {})) .. " | savegame=" .. tostring(self.savegameName) .. " | linksFile=" .. tostring(self.linksFile))
end
