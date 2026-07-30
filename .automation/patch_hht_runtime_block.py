from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one match, found {count}: {old[:80]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


# Hide the HUD immediately once the late compatibility guard detects HHT.
replace_once(
    "scripts/HP_UI.lua",
    "function HP_UI:render(dtMillis)\n    if self.flashTime ~= nil and self.flashTime > 0 then",
    "function HP_UI:render(dtMillis)\n    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then\n        self.visible = false\n        self.flashText = nil\n        self.flashTime = 0\n        return\n    end\n\n    if self.flashTime ~= nil and self.flashTime > 0 then",
)
replace_once(
    "scripts/HP_UI.lua",
    "function HP_UI:loadMap()\n    if HP_Config ~= nil",
    "function HP_UI:loadMap()\n    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then\n        self.visible = false\n        return\n    end\n\n    if HP_Config ~= nil",
)

# Ensure every player/vehicle input path observes the compatibility block.
replace_once(
    "scripts/RegisterPlayerActionEvents.lua",
    "local function _onCycle(_, actionName, inputValue, callbackState, isAnalog)\n    if not _isPress(inputValue, callbackState) then return end",
    "local function _isCompatibilityBlocked()\n    return HP_Compatibility ~= nil and HP_Compatibility:isBlocked()\nend\n\nlocal function _onCycle(_, actionName, inputValue, callbackState, isAnalog)\n    if not _isPress(inputValue, callbackState) then return end\n    if _isCompatibilityBlocked() then return end",
)
replace_once(
    "scripts/RegisterPlayerActionEvents.lua",
    "local function _onToggle(_, actionName, inputValue, callbackState, isAnalog)\n    if HP_UI and HP_UI.onToggleAction then",
    "local function _onToggle(_, actionName, inputValue, callbackState, isAnalog)\n    if _isCompatibilityBlocked() then return end\n    if HP_UI and HP_UI.onToggleAction then",
)
replace_once(
    "scripts/RegisterPlayerActionEvents.lua",
    "local function _onMode(_, actionName, inputValue, callbackState, isAnalog)\n    if not _isPress(inputValue, callbackState) then return end",
    "local function _onMode(_, actionName, inputValue, callbackState, isAnalog)\n    if not _isPress(inputValue, callbackState) then return end\n    if _isCompatibilityBlocked() then return end",
)
replace_once(
    "scripts/RegisterPlayerActionEvents.lua",
    "local function _onAppearanceMenu(_, actionName, inputValue, callbackState, isAnalog)\n    if not _isPress(inputValue, callbackState) then return end",
    "local function _onAppearanceMenu(_, actionName, inputValue, callbackState, isAnalog)\n    if not _isPress(inputValue, callbackState) then return end\n    if _isCompatibilityBlocked() then return end",
)
replace_once(
    "scripts/RegisterPlayerActionEvents.lua",
    "local function _registerPlayerActions()\n    _registerPlayerAction",
    "local function _registerPlayerActions()\n    if _isCompatibilityBlocked() then return end\n    _registerPlayerAction",
)
replace_once(
    "scripts/RegisterPlayerActionEvents.lua",
    "local function _registerVehicleActions(vehicle, isActiveForInput)\n    if not isActiveForInput",
    "local function _registerVehicleActions(vehicle, isActiveForInput)\n    if _isCompatibilityBlocked() then return end\n    if not isActiveForInput",
)

# Withdraw the shared HelperProfiles API when the roster is owned by HHT.
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "local function hpApiPrint(message)\n    print(LOG .. tostring(message))\nend\n\nlocal function normalizeSlot",
    "local function hpApiPrint(message)\n    print(LOG .. tostring(message))\nend\n\nlocal function isCompatibilityBlocked()\n    return HP_Compatibility ~= nil and HP_Compatibility:isBlocked()\nend\n\nlocal function normalizeSlot",
)
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "local function getProfiles()\n    if HelperProfiles == nil",
    "local function getProfiles()\n    if isCompatibilityBlocked() then return {} end\n    if HelperProfiles == nil",
)
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "        return {\n            available = true,",
    "        return {\n            available = not isCompatibilityBlocked(),\n            disabledReason = isCompatibilityBlocked() and HP_Compatibility:getReason() or nil,",
)
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "    function api:getSlots()\n        local profiles = getProfiles()",
    "    function api:getSlots()\n        if isCompatibilityBlocked() then return {} end\n        local profiles = getProfiles()",
)
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "function HP_IntegrationAPI:publish(reason)\n    if g_currentMission == nil then return false end",
    "function HP_IntegrationAPI:unpublish()\n    if g_currentMission ~= nil then\n        if g_currentMission.helperProfilesAPI == self.api then g_currentMission.helperProfilesAPI = nil end\n        if g_currentMission.fs25HelperProfilesAPI == self.api then g_currentMission.fs25HelperProfilesAPI = nil end\n    end\n    if rawget(_G, \"FS25_HelperProfiles_API\") == self.api then _G.FS25_HelperProfiles_API = nil end\n    if rawget(_G, \"FS25_HelperProfilesAPI\") == self.api then _G.FS25_HelperProfilesAPI = nil end\n    self.published = false\nend\n\nfunction HP_IntegrationAPI:publish(reason)\n    if isCompatibilityBlocked() then\n        self:unpublish()\n        return false\n    end\n    if g_currentMission == nil then return false end",
)
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "function HP_IntegrationAPI:update()\n    if not self.published",
    "function HP_IntegrationAPI:update()\n    if isCompatibilityBlocked() then\n        self:unpublish()\n        return\n    end\n    if not self.published",
)
replace_once(
    "scripts/HP_IntegrationAPI.lua",
    "function HP_IntegrationAPI:deleteMap()\n    if g_currentMission ~= nil then\n        if g_currentMission.helperProfilesAPI == self.api then g_currentMission.helperProfilesAPI = nil end\n        if g_currentMission.fs25HelperProfilesAPI == self.api then g_currentMission.fs25HelperProfilesAPI = nil end\n    end\n    if rawget(_G, \"FS25_HelperProfiles_API\") == self.api then _G.FS25_HelperProfiles_API = nil end\n    if rawget(_G, \"FS25_HelperProfilesAPI\") == self.api then _G.FS25_HelperProfilesAPI = nil end\n    self.published = false\nend",
    "function HP_IntegrationAPI:deleteMap()\n    self:unpublish()\nend",
)

# Static assertions for the corrected architecture.
checks = {
    "scripts/HP_UI.lua": ["HP_Compatibility:isBlocked()", "self.visible = false"],
    "scripts/RegisterPlayerActionEvents.lua": ["_isCompatibilityBlocked", "if _isCompatibilityBlocked() then return end"],
    "scripts/HP_IntegrationAPI.lua": ["function HP_IntegrationAPI:unpublish()", "disabledReason", "if isCompatibilityBlocked() then return {} end"],
    "scripts/HP_Compatibility.lua": ["helperCount > target", "function HP_Compatibility:update(dt)", "scanLoadedModTable"],
}
for path, needles in checks.items():
    text = Path(path).read_text(encoding="utf-8")
    for needle in needles:
        if needle not in text:
            raise RuntimeError(f"{path}: missing verification token {needle!r}")

print("HHT runtime block patch verified")
