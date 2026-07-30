-- HP_IntegrationAPI.lua (FS25_HelperProfiles)
-- Optional shared API for compatible mods such as FS25_HelperPayroll.
-- API v5 exposes the managed A-T roster and stable helper01-helper20 identities.

HP_IntegrationAPI = HP_IntegrationAPI or {
    apiVersion = 5,
    modVersion = "2.1.0.0",
    published = false,
    api = nil
}

local LOG = "[FS25_HelperProfiles/API] "

local function hpApiPrint(message)
    print(LOG .. tostring(message))
end

local function isCompatibilityBlocked()
    return HP_Compatibility ~= nil and HP_Compatibility:isBlocked()
end

local function normalizeSlot(slot)
    if HP_SlotRegistry ~= nil and HP_SlotRegistry.normalise ~= nil then
        return HP_SlotRegistry:normalise(slot, HP_SlotRegistry.TARGET_COUNT)
    end
    return nil, nil, nil
end

local function getProfiles()
    if isCompatibilityBlocked() then return {} end
    if HelperProfiles == nil or type(HelperProfiles.getProfiles) ~= "function" then return {} end
    local ok, profiles = pcall(HelperProfiles.getProfiles, HelperProfiles)
    return ok and type(profiles) == "table" and profiles or {}
end

local function slotForHelper(helper, fallbackIndex)
    if HP_SlotRegistry ~= nil and HP_SlotRegistry.getSlotForHelper ~= nil then
        return HP_SlotRegistry:getSlotForHelper(helper, fallbackIndex)
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

local function getManagedSlotCount(profiles)
    profiles = profiles or getProfiles()
    if HP_SlotRegistry ~= nil and HP_SlotRegistry.getManagedCount ~= nil then
        return HP_SlotRegistry:getManagedCount(#profiles)
    end
    return #profiles
end

local function getHelperForSlot(normalizedSlot, stableIndex)
    local profiles = getProfiles()

    for currentIndex, helper in ipairs(profiles) do
        if slotForHelper(helper, currentIndex) == normalizedSlot then
            return helper, currentIndex, profiles, "helperSlot"
        end
    end

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
    if HelperProfiles.selectedHelperRef ~= nil then return HelperProfiles.selectedHelperRef end

    if type(HelperProfiles.getSelectedHelper) == "function" then
        local ok, helper = pcall(HelperProfiles.getSelectedHelper, HelperProfiles)
        if ok then return helper end
    end

    local profiles = getProfiles()
    return profiles[tonumber(HelperProfiles.selectedIdx) or 1]
end

local function getSelectedSlot()
    local profiles = getProfiles()
    local selectedRef = getSelectedHelperRef()
    local currentIndex = currentIndexForHelper(profiles, selectedRef)
    local slot = slotForHelper(selectedRef, currentIndex)
    if slot ~= nil then return slot end

    currentIndex = HelperProfiles ~= nil and tonumber(HelperProfiles.selectedIdx) or nil
    if currentIndex ~= nil and currentIndex >= 1 and currentIndex <= getManagedSlotCount(profiles) then
        return slotForHelper(profiles[currentIndex], currentIndex)
    end
    return nil
end

local function getSlotData(slot)
    local normalizedSlot, stableIndex, canonicalId = normalizeSlot(slot)
    if normalizedSlot == nil then return nil end

    local helper, currentIndex, _, resolutionSource = getHelperForSlot(normalizedSlot, stableIndex)
    local selectedRef = getSelectedHelperRef()
    local aliases = HP_SlotRegistry ~= nil and HP_SlotRegistry:getIdentityAliases(stableIndex) or {"slot:" .. normalizedSlot}

    if helper == nil then
        return {
            slot = normalizedSlot,
            index = stableIndex,
            currentIndex = nil,
            canonicalId = canonicalId,
            identityId = "slot:" .. normalizedSlot,
            identityAliases = aliases,
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
            HelperProfiles.getDisplayNameForHelper, HelperProfiles, helper, stableIndex
        )
        if ok then
            if resolvedDisplayName ~= nil and tostring(resolvedDisplayName) ~= "" then displayName = tostring(resolvedDisplayName) end
            if resolvedBaseName ~= nil and tostring(resolvedBaseName) ~= "" then baseName = tostring(resolvedBaseName) end
        end
    end

    local appearanceLabel, presetId, category = nil, nil, nil
    if HelperProfiles ~= nil and type(HelperProfiles.getAppearanceLabelForHelper) == "function" then
        local ok, label, resolvedPresetId, resolvedCategory = pcall(
            HelperProfiles.getAppearanceLabelForHelper, HelperProfiles, helper, stableIndex
        )
        if ok then
            appearanceLabel = label
            presetId = resolvedPresetId
            category = resolvedCategory
        end
    end

    local identityId = "slot:" .. normalizedSlot
    local identitySource = "slotFallback"
    if presetId ~= nil and tostring(presetId) ~= "" then
        identityId = "preset:" .. tostring(presetId)
        identitySource = "presetId"
        table.insert(aliases, 1, identityId)
    end

    return {
        slot = normalizedSlot,
        index = stableIndex,
        currentIndex = currentIndex,
        canonicalId = canonicalId,
        identityId = identityId,
        identityAliases = aliases,
        identitySource = identitySource,
        baseName = baseName,
        displayName = displayName,
        inUse = HelperProfiles ~= nil and HelperProfiles.isHelperActive ~= nil
            and HelperProfiles:isHelperActive(helper) or helper.inUse == true,
        selected = selectedRef ~= nil and helper == selectedRef or getSelectedSlot() == normalizedSlot,
        appearanceLabel = appearanceLabel,
        presetId = presetId,
        category = category,
        expandedByHelperProfiles = helper.hpExpandedByHelperProfiles == true,
        sourceSlot = helper.hpSourceSlot,
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
        local expansion = HP_RosterExpansion ~= nil and HP_RosterExpansion.getStatus ~= nil
            and HP_RosterExpansion:getStatus() or nil

        return {
            available = not isCompatibilityBlocked(),
            disabledReason = isCompatibilityBlocked() and HP_Compatibility:getReason() or nil,
            apiVersion = self.apiVersion,
            modName = self.modName,
            modVersion = self.modVersion,
            profileCount = #profiles,
            managedSlotCount = getManagedSlotCount(profiles),
            targetSlotCount = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20,
            selectedIndex = selected ~= nil and selected.index or nil,
            selectedSlot = selectedSlot,
            selectedName = selected ~= nil and selected.displayName or nil,
            pickMode = HelperProfiles ~= nil and type(HelperProfiles.getPickMode) == "function" and HelperProfiles:getPickMode() or nil,
            rosterSource = expansion ~= nil and expansion.result or "unknown",
            expandedByHelperProfiles = expansion ~= nil and expansion.addedCount > 0 or false
        }
    end

    function api:getSelectedIndex()
        local _, index = normalizeSlot(getSelectedSlot())
        return index
    end

    function api:getSelectedSlot() return getSelectedSlot() end

    function api:getSelectedDisplayName()
        local slot = getSelectedSlot()
        local data = slot ~= nil and getSlotData(slot) or nil
        return data ~= nil and data.displayName or nil
    end

    function api:normaliseSlot(slot)
        local label, index, canonicalId = normalizeSlot(slot)
        if label == nil then return nil end
        return {slot = label, index = index, canonicalId = canonicalId}
    end

    function api:getSlotData(slot) return getSlotData(slot) end

    function api:getDisplayNameForSlot(slot)
        local data = getSlotData(slot)
        return data ~= nil and data.displayName or nil
    end

    function api:getIdentityIdForSlot(slot)
        local data = getSlotData(slot)
        return data ~= nil and data.identityId or nil
    end

    function api:getIdentityData(identityId)
        if identityId == nil or tostring(identityId) == "" then return nil end
        local wanted = tostring(identityId)
        for _, data in ipairs(self:getSlots()) do
            if data ~= nil then
                if tostring(data.identityId or "") == wanted then return data end
                for _, alias in ipairs(data.identityAliases or {}) do
                    if tostring(alias) == wanted then return data end
                end
            end
        end
        return nil
    end

    function api:getSlots()
        if isCompatibilityBlocked() then return {} end
        local profiles = getProfiles()
        local slots = {}
        for index = 1, getManagedSlotCount(profiles) do
            slots[index] = getSlotData(HP_SlotRegistry:indexToSlot(index))
        end
        return slots
    end

    return api
end

function HP_IntegrationAPI:unpublish()
    if g_currentMission ~= nil then
        if g_currentMission.helperProfilesAPI == self.api then g_currentMission.helperProfilesAPI = nil end
        if g_currentMission.fs25HelperProfilesAPI == self.api then g_currentMission.fs25HelperProfilesAPI = nil end
    end
    if rawget(_G, "FS25_HelperProfiles_API") == self.api then _G.FS25_HelperProfiles_API = nil end
    if rawget(_G, "FS25_HelperProfilesAPI") == self.api then _G.FS25_HelperProfilesAPI = nil end
    self.published = false
end

function HP_IntegrationAPI:publish(reason)
    if isCompatibilityBlocked() then
        self:unpublish()
        return false
    end
    if g_currentMission == nil then return false end
    self.api = self.api or buildApi()
    self.api.modVersion = self.modVersion

    local changed = g_currentMission.helperProfilesAPI ~= self.api
        or g_currentMission.fs25HelperProfilesAPI ~= self.api

    g_currentMission.helperProfilesAPI = self.api
    g_currentMission.fs25HelperProfilesAPI = self.api
    _G.FS25_HelperProfiles_API = self.api
    _G.FS25_HelperProfilesAPI = self.api
    self.published = true

    if changed then
        hpApiPrint(string.format(
            "Published optional shared API: reason=%s apiVersion=%s modVersion=%s slots=%d",
            tostring(reason or "runtime"), tostring(self.api.apiVersion), tostring(self.api.modVersion),
            HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
        ))
    end
    return true
end

function HP_IntegrationAPI:loadMap() self:publish("loadMap") end

function HP_IntegrationAPI:update()
    if isCompatibilityBlocked() then
        self:unpublish()
        return
    end
    if not self.published or g_currentMission == nil
        or g_currentMission.helperProfilesAPI ~= self.api
        or g_currentMission.fs25HelperProfilesAPI ~= self.api then
        self:publish("update")
    end
end

function HP_IntegrationAPI:deleteMap()
    self:unpublish()
end

addModEventListener(HP_IntegrationAPI)
