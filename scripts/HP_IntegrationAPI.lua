-- HP_IntegrationAPI.lua (FS25_HelperProfiles)
-- Optional shared API for compatible mods such as FS25_HelperPayroll.
-- This does not create a hard dependency in either direction.
-- API v4 resolves A-J by stable helper identity rather than runtime list position.

HP_IntegrationAPI = HP_IntegrationAPI or {
    apiVersion = 4,
    modVersion = "2.0.26.0",
    published = false,
    api = nil
}

local LOG = "[FS25_HelperProfiles/API] "

local function hpApiPrint(message)
    print(LOG .. tostring(message))
end

local function normalizeSlot(slot)
    if slot == nil then return nil, nil end

    local number = tonumber(slot)
    if number ~= nil then
        local index = math.floor(number)
        if index >= 1 and index <= 10 then
            return string.char(string.byte("A") + index - 1), index
        end
    end

    local text = string.upper(tostring(slot)):gsub("^%s+", ""):gsub("%s+$", "")
    if #text ~= 1 or text < "A" or text > "J" then
        return nil, nil
    end

    return text, string.byte(text) - string.byte("A") + 1
end

local function getProfiles()
    if HelperProfiles == nil or type(HelperProfiles.getProfiles) ~= "function" then
        return {}
    end

    local ok, profiles = pcall(HelperProfiles.getProfiles, HelperProfiles)
    if ok and type(profiles) == "table" then
        return profiles
    end

    return {}
end

local function slotForHelper(helper)
    if helper == nil then return nil end

    local baseName = tostring(helper.name or "")
    local upper = string.upper(baseName):gsub("^%s+", ""):gsub("%s+$", "")
    local direct = upper:match("^([A-J])$") or upper:match("^HELPER%s+([A-J])$")
    if direct ~= nil then
        return direct
    end

    if HelperProfiles ~= nil and HelperProfiles._defaultPosByRef ~= nil then
        local position = tonumber(HelperProfiles._defaultPosByRef[helper])
        if position ~= nil and position >= 1 and position <= 10 then
            return string.char(string.byte("A") + position - 1)
        end
    end

    return nil
end

local function currentIndexForHelper(profiles, wanted)
    if wanted == nil then return nil end
    for index, helper in ipairs(profiles or {}) do
        if helper == wanted then return index end
    end
    return nil
end

local function getHelperForSlot(normalizedSlot, stableIndex)
    local profiles = getProfiles()

    -- Primary resolution: the helper object's own vanilla base name. This remains
    -- A-J even when GIANTS reorders availableHelpers as workers enter/leave use.
    for currentIndex, helper in ipairs(profiles) do
        if slotForHelper(helper) == normalizedSlot then
            return helper, currentIndex, profiles, "baseName"
        end
    end

    -- Secondary resolution: the reference cached while all helpers were idle.
    -- This keeps the A-J identity stable even if a helper implementation does not
    -- expose its base name in the usual form.
    if HelperProfiles ~= nil and HelperProfiles._defaultOrderRefs ~= nil then
        local helper = HelperProfiles._defaultOrderRefs[stableIndex]
        if helper ~= nil then
            return helper, currentIndexForHelper(profiles, helper) or stableIndex, profiles, "defaultOrderRef"
        end
    end

    return nil, stableIndex, profiles, "missing"
end

local function getSelectedHelperRef()
    if HelperProfiles == nil then return nil end

    if HelperProfiles.selectedHelperRef ~= nil then
        return HelperProfiles.selectedHelperRef
    end

    if type(HelperProfiles.getSelectedHelper) == "function" then
        local ok, helper = pcall(HelperProfiles.getSelectedHelper, HelperProfiles)
        if ok then return helper end
    end

    local profiles = getProfiles()
    local currentIndex = tonumber(HelperProfiles.selectedIdx) or 1
    return profiles[currentIndex]
end

local function getSelectedSlot()
    local selectedRef = getSelectedHelperRef()
    local slot = slotForHelper(selectedRef)
    if slot ~= nil then return slot end

    local currentIndex = HelperProfiles ~= nil and tonumber(HelperProfiles.selectedIdx) or nil
    if currentIndex ~= nil and currentIndex >= 1 and currentIndex <= 10 then
        local profiles = getProfiles()
        return slotForHelper(profiles[currentIndex])
    end

    return nil
end

local function getSlotData(slot)
    local normalizedSlot, stableIndex = normalizeSlot(slot)
    if normalizedSlot == nil then return nil end

    local helper, currentIndex, _, resolutionSource = getHelperForSlot(normalizedSlot, stableIndex)
    local selectedRef = getSelectedHelperRef()

    if helper == nil then
        return {
            slot = normalizedSlot,
            index = stableIndex,
            currentIndex = nil,
            identityId = "slot:" .. normalizedSlot,
            identitySource = "slotFallback",
            baseName = normalizedSlot,
            displayName = "Helper " .. normalizedSlot,
            inUse = false,
            selected = getSelectedSlot() == normalizedSlot,
            resolutionSource = resolutionSource,
            source = "HelperProfilesAPI"
        }
    end

    local displayName = tostring(helper.name or normalizedSlot)
    local baseName = tostring(helper.name or normalizedSlot)
    if HelperProfiles ~= nil and type(HelperProfiles.getDisplayNameForHelper) == "function" then
        local ok, resolvedDisplayName, resolvedBaseName = pcall(
            HelperProfiles.getDisplayNameForHelper,
            HelperProfiles,
            helper,
            stableIndex
        )
        if ok then
            if resolvedDisplayName ~= nil and tostring(resolvedDisplayName) ~= "" then
                displayName = tostring(resolvedDisplayName)
            end
            if resolvedBaseName ~= nil and tostring(resolvedBaseName) ~= "" then
                baseName = tostring(resolvedBaseName)
            end
        end
    end

    local appearanceLabel, presetId, category = nil, nil, nil
    if HelperProfiles ~= nil and type(HelperProfiles.getAppearanceLabelForHelper) == "function" then
        local ok, label, resolvedPresetId, resolvedCategory = pcall(
            HelperProfiles.getAppearanceLabelForHelper,
            HelperProfiles,
            helper,
            stableIndex
        )
        if ok then
            appearanceLabel = label
            presetId = resolvedPresetId
            category = resolvedCategory
        end
    end

    local identityId
    local identitySource
    if presetId ~= nil and tostring(presetId) ~= "" then
        identityId = "preset:" .. tostring(presetId)
        identitySource = "presetId"
    else
        identityId = "slot:" .. tostring(normalizedSlot)
        identitySource = "slotFallback"
    end

    return {
        slot = normalizedSlot,
        index = stableIndex,
        currentIndex = currentIndex,
        identityId = identityId,
        identitySource = identitySource,
        baseName = baseName,
        displayName = displayName,
        inUse = HelperProfiles ~= nil and HelperProfiles.isHelperActive ~= nil
            and HelperProfiles:isHelperActive(helper) or helper.inUse == true,
        selected = selectedRef ~= nil and helper == selectedRef or getSelectedSlot() == normalizedSlot,
        appearanceLabel = appearanceLabel,
        presetId = presetId,
        category = category,
        resolutionSource = resolutionSource,
        source = "HelperProfilesAPI"
    }
end

local function buildApi()
    local api = {
        apiVersion = HP_IntegrationAPI.apiVersion,
        modName = "FS25_HelperProfiles",
        modVersion = HP_IntegrationAPI.modVersion,
        readOnly = true
    }

    function api:getStatus()
        local profiles = getProfiles()
        local selectedSlot = getSelectedSlot()
        local selected = selectedSlot ~= nil and getSlotData(selectedSlot) or nil
        local selectedIndex = selected ~= nil and selected.index or nil

        return {
            available = true,
            apiVersion = self.apiVersion,
            modName = self.modName,
            modVersion = self.modVersion,
            profileCount = #profiles,
            selectedIndex = selectedIndex,
            selectedSlot = selectedSlot,
            selectedName = selected ~= nil and selected.displayName or nil,
            pickMode = HelperProfiles ~= nil and type(HelperProfiles.getPickMode) == "function" and HelperProfiles:getPickMode() or nil
        }
    end

    function api:getSelectedIndex()
        local slot = getSelectedSlot()
        local _, index = normalizeSlot(slot)
        return index
    end

    function api:getSelectedSlot()
        return getSelectedSlot()
    end

    function api:getSelectedDisplayName()
        local slot = getSelectedSlot()
        local data = slot ~= nil and getSlotData(slot) or nil
        return data ~= nil and data.displayName or nil
    end

    function api:getSlotData(slot)
        return getSlotData(slot)
    end

    function api:getDisplayNameForSlot(slot)
        local data = getSlotData(slot)
        return data ~= nil and data.displayName or nil
    end

    function api:getIdentityIdForSlot(slot)
        local data = getSlotData(slot)
        return data ~= nil and data.identityId or nil
    end

    function api:getIdentityData(identityId)
        if identityId == nil or tostring(identityId) == "" then
            return nil
        end
        local wanted = tostring(identityId)
        for index = 1, 10 do
            local slot = string.char(string.byte("A") + index - 1)
            local data = getSlotData(slot)
            if data ~= nil and tostring(data.identityId or "") == wanted then
                return data
            end
        end
        return nil
    end

    function api:getSlots()
        local slots = {}
        for index = 1, 10 do
            local slot = string.char(string.byte("A") + index - 1)
            slots[index] = getSlotData(slot)
        end
        return slots
    end

    return api
end

function HP_IntegrationAPI:publish(reason)
    if g_currentMission == nil then
        return false
    end

    self.api = self.api or buildApi()

    local changed = g_currentMission.helperProfilesAPI ~= self.api
        or g_currentMission.fs25HelperProfilesAPI ~= self.api

    g_currentMission.helperProfilesAPI = self.api
    g_currentMission.fs25HelperProfilesAPI = self.api
    self.published = true

    if changed then
        hpApiPrint(string.format(
            "Published optional shared API: reason=%s apiVersion=%s modVersion=%s",
            tostring(reason or "runtime"),
            tostring(self.api.apiVersion),
            tostring(self.api.modVersion)
        ))
    end

    return true
end

function HP_IntegrationAPI:loadMap()
    self:publish("loadMap")
end

function HP_IntegrationAPI:update()
    if not self.published
        or g_currentMission == nil
        or g_currentMission.helperProfilesAPI ~= self.api
        or g_currentMission.fs25HelperProfilesAPI ~= self.api then
        self:publish("update")
    end
end

function HP_IntegrationAPI:deleteMap()
    if g_currentMission ~= nil then
        if g_currentMission.helperProfilesAPI == self.api then
            g_currentMission.helperProfilesAPI = nil
        end
        if g_currentMission.fs25HelperProfilesAPI == self.api then
            g_currentMission.fs25HelperProfilesAPI = nil
        end
    end
    self.published = false
end

addModEventListener(HP_IntegrationAPI)
