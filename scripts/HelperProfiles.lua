-- HelperProfiles.lua (FS25_HelperProfiles) – safe hook version
-- Semicolon cycles helpers (registered via RegisterPlayerActionEvents.lua).
-- When you press H, we prefer your selected free helper. No table/appearance edits.

HelperProfiles = {}
HelperProfiles.selectedIdx   = 1
HelperProfiles.overlayText   = ""
HelperProfiles.overlayTime   = 0
HelperProfiles._hooksDone    = false

-- originals (filled when we hook)
HelperProfiles._orig_getNext   = nil
HelperProfiles._orig_getFree   = nil
HelperProfiles._orig_getRandom = nil
HelperProfiles._orig_hire      = nil

----------------------------------------------------------------------
-- Helper list (read-only from engine; keeps avatars intact)
----------------------------------------------------------------------
function HelperProfiles:getProfiles()
    local list = {}
    if g_helperManager and g_helperManager.availableHelpers then
        for _, h in ipairs(g_helperManager.availableHelpers) do
            table.insert(list, h)
        end
    end
    return list
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function HelperProfiles:ensureValidSelection()
    local profiles = self:getProfiles()
    if #profiles == 0 then self.selectedIdx = 1; return end
    self.selectedIdx = clamp(self.selectedIdx or 1, 1, #profiles)
end

local function isFree(h)
    return h ~= nil and h.inUse ~= true
end

-- pick our preferred helper (selected if free; else next free; else nil)
function HelperProfiles:pickPreferredFreeHelper()
    local profiles = self:getProfiles()
    if #profiles == 0 then return nil, "none-available" end

    self:ensureValidSelection()

    local sel = profiles[self.selectedIdx]
    if isFree(sel) then
        return sel, "selected"
    end
    for i = 1, #profiles - 1 do
        local idx = ((self.selectedIdx - 1 + i) % #profiles) + 1
        local h = profiles[idx]
        if isFree(h) then
            return h, "fallback"
        end
    end
    return nil, "none-free"
end

----------------------------------------------------------------------
-- HUD overlay
----------------------------------------------------------------------
function HelperProfiles:_flash(text, secs)
    self.overlayText = text or ""
    self.overlayTime = secs or 2.0
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

----------------------------------------------------------------------
-- Action handler (semicolon), called from RegisterPlayerActionEvents.lua
----------------------------------------------------------------------
function HelperProfiles:onCycleAction(actionName, keyStatus)
    if keyStatus ~= 1 then return end

    local profiles = self:getProfiles()
    if #profiles == 0 then
        self:_flash("No helpers available", 1.2)
        return
    end

    self:ensureValidSelection()
    self.selectedIdx = (self.selectedIdx % #profiles) + 1
    local sel = profiles[self.selectedIdx]
    local label = sel and sel.name or "?"
    self:_flash(("Helper: %s (%d/%d)"):format(label, self.selectedIdx, #profiles), 1.2)
    print(("[FS25_HelperProfiles] Selected helper: %s"):format(label))
end

----------------------------------------------------------------------
-- Safe hooking (no Utils.overwrittenFunction)
----------------------------------------------------------------------
local function hookOnce()
    if HelperProfiles._hooksDone then return end
    if not g_helperManager or not HelperManager then return end

    -- getNextHelper
    if HelperManager.getNextHelper and not HelperProfiles._orig_getNext then
        HelperProfiles._orig_getNext = HelperManager.getNextHelper
        HelperManager.getNextHelper = function(self, ...)
            local h, why = HelperProfiles:pickPreferredFreeHelper()
            if h then
                print(("[FS25_HelperProfiles] getNextHelper -> '%s' (%s)"):format(tostring(h.name), why))
                return h
            end
            return HelperProfiles._orig_getNext(self, ...)
        end
        print("[FS25_HelperProfiles] Hooked HelperManager.getNextHelper")
    end

    -- getFreeHelper
    if HelperManager.getFreeHelper and not HelperProfiles._orig_getFree then
        HelperProfiles._orig_getFree = HelperManager.getFreeHelper
        HelperManager.getFreeHelper = function(self, ...)
            local h, why = HelperProfiles:pickPreferredFreeHelper()
            if h then
                print(("[FS25_HelperProfiles] getFreeHelper -> '%s' (%s)"):format(tostring(h.name), why))
                return h
            end
            return HelperProfiles._orig_getFree(self, ...)
        end
        print("[FS25_HelperProfiles] Hooked HelperManager.getFreeHelper")
    end

    -- getRandomHelper
    if HelperManager.getRandomHelper and not HelperProfiles._orig_getRandom then
        HelperProfiles._orig_getRandom = HelperManager.getRandomHelper
        HelperManager.getRandomHelper = function(self, ...)
            local h, why = HelperProfiles:pickPreferredFreeHelper()
            if h then
                print(("[FS25_HelperProfiles] getRandomHelper -> '%s' (%s)"):format(tostring(h.name), why))
                return h
            end
            return HelperProfiles._orig_getRandom(self, ...)
        end
        print("[FS25_HelperProfiles] Hooked HelperManager.getRandomHelper")
    end

    -- hireHelper (for logging/visibility)
    if HelperManager.hireHelper and not HelperProfiles._orig_hire then
        HelperProfiles._orig_hire = HelperManager.hireHelper
        HelperManager.hireHelper = function(self, vehicle, ...)
            local res = HelperProfiles._orig_hire(self, vehicle, ...)
            local idx = nil
            if vehicle and vehicle.getAIHelperIndex then
                idx = vehicle:getAIHelperIndex()
            end
            if idx and g_helperManager and g_helperManager.indexToHelper then
                local h = g_helperManager.indexToHelper[idx]
                if h then
                    print(("[FS25_HelperProfiles] hireHelper -> vehicle got '%s' (idx %d)"):format(tostring(h.name), idx))
                end
            end
            return res
        end
        print("[FS25_HelperProfiles] Hooked HelperManager.hireHelper")
    end

    HelperProfiles._hooksDone = (HelperProfiles._orig_getNext or HelperProfiles._orig_getFree or HelperProfiles._orig_getRandom) ~= nil
end

----------------------------------------------------------------------
-- FS lifecycle
----------------------------------------------------------------------
function HelperProfiles:loadMap()
    self.selectedIdx = 1
    self:_flash("Press ; to cycle helper", 3.0)
    -- Attempt to hook now; if too early, update() will retry
    hookOnce()
end

function HelperProfiles:update(dt)
    if not HelperProfiles._hooksDone then
        hookOnce()
    end
end

addModEventListener(HelperProfiles)  -- includes draw()
