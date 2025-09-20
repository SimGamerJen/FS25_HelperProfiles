-- HelperProfiles.lua (FS25_HelperProfiles) – debounced cycle + UI bridge
-- Semicolon/H binding cycles helpers; PN-style overlay handled by HP_UI.

HelperProfiles = {}

-- Selection & runtime
HelperProfiles.selectedIdx       = 1
HelperProfiles._hooksDone        = false
HelperProfiles._lastCycleTs      = 0
HelperProfiles._cycleDebounceMs  = 180   -- tweak via: hpOverlay debounce <ms>

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

function HelperProfiles:getSelectionIndex()
    return self.selectedIdx or 1
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

function HelperProfiles:_flash(text, secs)
    -- UI bridge (HP_UI owns all rendering)
    if HP_UI and HP_UI.flash then
        HP_UI:flash(text, secs)
    end
end

function HelperProfiles:setSelection(idx)
    local profiles = self:getProfiles()
    if #profiles == 0 then return end
    idx = math.floor(math.max(1, math.min(idx or 1, #profiles)))
    self.selectedIdx = idx

    local sel = profiles[self.selectedIdx]
    local label = sel and sel.name or ("Helper "..self.selectedIdx)
    self:_flash(("Helper: %s (%d/%d)"):format(label, self.selectedIdx, #profiles), 1.2)
    print(("[FS25_HelperProfiles] Selected helper: %s"):format(label))
end

function HelperProfiles:cycleSelection(delta)
    delta = delta or 1
    local profiles = self:getProfiles()
    if #profiles == 0 then return end
    self:ensureValidSelection()
    local newIdx = ((self.selectedIdx - 1 + delta) % #profiles) + 1
    self:setSelection(newIdx)
end

local function _nowMs()
    -- FS provides g_time (ms since game start)
    return (g_time or 0)
end

function HelperProfiles:cycleSelectionDebounced(delta)
    local now = _nowMs()
    local last = self._lastCycleTs or 0
    if (now - last) < (self._cycleDebounceMs or 150) then
        return
    end
    self._lastCycleTs = now
    self:cycleSelection(delta or 1)
end

----------------------------------------------------------------------
-- Action handler (semicolon/H), called from RegisterPlayerActionEvents.lua
----------------------------------------------------------------------
-- Expecting FS25 style callback with key status (1 on press).
function HelperProfiles:onCycleAction(actionName, keyStatus)
    if keyStatus ~= 1 then return end  -- press only
    self:cycleSelectionDebounced(1)
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
function HelperProfiles:update(dt)
    if not HelperProfiles._hooksDone then
        hookOnce()
    end
end

addModEventListener(HelperProfiles)
