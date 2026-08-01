-- HP_RosterFilter.lua (FS25_HelperProfiles)
-- Installs the operational ON/OFF roster filter without changing permanent A-T identities.

if HP_RosterFilter ~= nil then return end
HP_RosterFilter = { fallbackPatched = false }

local LOG = "[FS25_HelperProfiles/RosterFilter] "
local rawGetProfiles = HelperProfiles ~= nil and HelperProfiles.getProfiles or nil

if HelperProfiles == nil or type(rawGetProfiles) ~= "function" then
    print(LOG .. "Core unavailable; roster filter not installed")
    return
end

function HelperProfiles:getAllProfiles()
    return rawGetProfiles(self)
end

function HelperProfiles:getStableIndexForHelper(wanted)
    if wanted == nil then return nil end
    for index, helper in ipairs(self:getAllProfiles() or {}) do
        if helper == wanted then return index end
    end
    return nil
end

function HelperProfiles:isHelperRosterEnabled(helper, fallbackIndex)
    if HP_RosterState == nil then return true end
    local stableIndex = self:getStableIndexForHelper(helper) or fallbackIndex
    return HP_RosterState:isEnabled(helper, stableIndex)
end

function HelperProfiles:getProfiles()
    local enabled = {}
    for stableIndex, helper in ipairs(self:getAllProfiles() or {}) do
        if HP_RosterState == nil or HP_RosterState:isEnabled(helper, stableIndex) then
            enabled[#enabled + 1] = helper
        end
    end
    return enabled
end

local originalIsHelperSelectable = HelperProfiles.isHelperSelectable
function HelperProfiles:isHelperSelectable(helper)
    if helper == nil or not self:isHelperRosterEnabled(helper) then return false end
    return originalIsHelperSelectable(self, helper)
end

function HelperProfiles:onRosterAvailabilityChanged()
    self:ensureValidSelection()
    if HP_UI ~= nil and HP_UI.flash ~= nil and HP_RosterState ~= nil then
        HP_UI:flash(string.format("Roster updated: %d worker(s) ON", HP_RosterState:getEnabledCount()), 1.75)
    end
end

local function installFallbackGuard(field)
    local original = HelperProfiles[field]
    if type(original) ~= "function" then return end

    HelperProfiles[field] = function(manager, ...)
        local enabledCount = HP_RosterState ~= nil and HP_RosterState:getEnabledCount() or 20
        local target = HP_SlotRegistry ~= nil and HP_SlotRegistry.TARGET_COUNT or 20
        if enabledCount < target then
            -- All ON-roster helpers are busy/unavailable. Do not allow the engine
            -- fallback to allocate a worker deliberately marked OFF roster.
            return nil
        end
        return original(manager, ...)
    end
end

function HP_RosterFilter:update()
    if self.fallbackPatched then return end
    if HelperProfiles._hooksDone ~= true then return end

    installFallbackGuard("_orig_getNext")
    installFallbackGuard("_orig_getFree")
    installFallbackGuard("_orig_getRandom")
    self.fallbackPatched = true
    print(LOG .. "Operational roster filtering installed; engine fallback cannot allocate OFF-roster workers")
end

function HP_RosterFilter:deleteMap()
    self.fallbackPatched = false
end

addModEventListener(HP_RosterFilter)
