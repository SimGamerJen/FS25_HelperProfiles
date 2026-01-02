-- HelperProfiles.lua (FS25_HelperProfiles) – debounced cycle + UI bridge
-- Semicolon/H binding cycles helpers; PN-style overlay handled by HP_UI.

-- ============================================================================
-- FS25_HelperProfiles
-- ModVersion: 1.1.0.2
-- Script:     HelperProfiles.lua
-- BuildTag:     20260102-4
-- ============================================================================

do
    local MOD_VERSION   = "1.1.0.2"
    local SCRIPT_NAME   = "HelperProfiles.lua"
    local BUILD_TAG     = "20260102-4"
    local SCRIPT_VER    = string.format("%s-%s+%s", MOD_VERSION, SCRIPT_NAME, BUILD_TAG)

    local vi = rawget(_G, "FS25_HelperProfiles_VersionInfo")
    if vi == nil then
        vi = { modVersion = MOD_VERSION, scripts = {} }
        _G.FS25_HelperProfiles_VersionInfo = vi
    end

    vi.modVersion = vi.modVersion or MOD_VERSION
    vi.scripts = vi.scripts or {}
    vi.scripts[SCRIPT_NAME] = SCRIPT_VER
end

HelperProfiles = HelperProfiles or {}
-- Selection & runtime
HelperProfiles.selectedIdx       = 1
HelperProfiles.selectedHelperRef = nil   -- keeps selection stable across reorder
HelperProfiles._hooksDone        = false
HelperProfiles._lastCycleTs      = 0
HelperProfiles._cycleDebounceMs  = 180   -- tweak via: hpOverlay debounce <ms>

-- Helper selection mode
HelperProfiles._pickMode = "preferSelected" -- "preferSelected" | "firstFree"

function HelperProfiles:getPickMode()
    return self._pickMode or "preferSelected"
end

function HelperProfiles:setPickMode(mode, silent)
    local m = tostring(mode or ""):lower()
    if m == "firstfree" or m == "first_free" or m == "first" then
        m = "firstFree"
    elseif m == "preferselected" or m == "prefer_selected" or m == "selected" or m == "prefer" then
        m = "preferSelected"
    else
        return false, "invalid-mode"
    end

    self._pickMode = m
    if not silent then
        if self._flash then
            self:_flash(("Mode: %s"):format(m), 1.2)
        end
        print(("[FS25_HelperProfiles] Helper mode set to: %s"):format(m))
    end
    return true, nil
end

-- Default-order caching / reset-on-idle behaviour
HelperProfiles._defaultOrderRefs = nil   -- array of helper refs in default order
HelperProfiles._defaultPosByRef  = nil   -- map: helperRef -> position
HelperProfiles._hadInUse         = nil   -- tracks transition to "all idle"
HelperProfiles._resetOrderWhenIdle = true -- feature flag

-- originals (filled when we hook)
HelperProfiles._orig_getNext   = nil
HelperProfiles._orig_getFree   = nil
HelperProfiles._orig_getRandom = nil
HelperProfiles._orig_hire      = nil

----------------------------------------------------------------------
-- Helper list (read-only from engine; keeps avatars intact)
----------------------------------------------------------------------

local function _getHelpersRaw()
    local list = {}
    if g_helperManager and g_helperManager.availableHelpers then
        for _, h in ipairs(g_helperManager.availableHelpers) do
            table.insert(list, h)
        end
    end
    return list
end

local function _anyInUse(list)
    for _, h in ipairs(list) do
        if h ~= nil and h.inUse == true then
            return true
        end
    end
    return false
end

function HelperProfiles:_cacheDefaultOrderIfReady(list)
    if self._defaultPosByRef ~= nil then return end
    if list == nil or #list == 0 then return end
    if _anyInUse(list) then return end

    self._defaultOrderRefs = {}
    self._defaultPosByRef  = {}
    for i, h in ipairs(list) do
        self._defaultOrderRefs[i] = h
        self._defaultPosByRef[h]  = i
    end

    print(("[FS25_HelperProfiles] Cached default helper order (%d helpers)"):format(#list))
end

function HelperProfiles:_sortToDefault(list)
    if self._defaultPosByRef == nil then return end
    table.sort(list, function(a, b)
        local pa = self._defaultPosByRef[a] or 1000000
        local pb = self._defaultPosByRef[b] or 1000000
        if pa == pb then
            return tostring(a) < tostring(b)
        end
        return pa < pb
    end)
end

-- Public list accessor used by UI + selection logic
function HelperProfiles:getProfiles()
    local list = _getHelpersRaw()

    -- only establish "default" order when everything is idle
    self:_cacheDefaultOrderIfReady(list)

    if self._resetOrderWhenIdle and not _anyInUse(list) and self._defaultPosByRef ~= nil then
        self:_sortToDefault(list)
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
    if #profiles == 0 then
        self.selectedIdx = 1
        self.selectedHelperRef = nil
        return
    end

    -- Prefer keeping the same helper selected (by reference), even if list order changes
    if self.selectedHelperRef ~= nil then
        for i, h in ipairs(profiles) do
            if h == self.selectedHelperRef then
                self.selectedIdx = i
                return
            end
        end
    end

    self.selectedIdx = clamp(self.selectedIdx or 1, 1, #profiles)
    self.selectedHelperRef = profiles[self.selectedIdx]
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

    local mode = (self.getPickMode and self:getPickMode()) or (self._pickMode or "preferSelected")

    -- Mode: firstFree -> always pick first free helper in list order
    if mode == "firstFree" then
        for i, h in ipairs(profiles) do
            if isFree(h) then
                -- align selection without flashing
                self.selectedIdx = i
                self.selectedHelperRef = h
                return h, "firstFree"
            end
        end
        return nil, "none-free"
    end

    -- Mode: preferSelected (legacy)
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
    self.selectedHelperRef = profiles[idx]

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

-- Optional manual reset (support/testing)
function HelperProfiles:resetOrderToDefault()
    local list = _getHelpersRaw()
    if _anyInUse(list) then
        self:_flash("Cannot reset helper order: helpers active", 1.5)
        return false, "helpers-active"
    end
    self:_cacheDefaultOrderIfReady(list)
    if self._defaultPosByRef == nil then
        self:_flash("Cannot reset helper order: no default cached yet", 1.5)
        return false, "no-default"
    end
    -- No engine mutation required: when idle, getProfiles() will render default order.
    self:ensureValidSelection()
    self:_flash("Helper order reset to default", 1.2)
    return true, nil
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

    -- Track "helpers active -> all idle" transition and inform the user once.
    local list = _getHelpersRaw()
    if list ~= nil and #list > 0 then
        self:_cacheDefaultOrderIfReady(list)

        local any = _anyInUse(list)
        if self._hadInUse == nil then
            self._hadInUse = any
        else
            if self._hadInUse and not any and self._resetOrderWhenIdle and self._defaultPosByRef ~= nil then
                -- When all idle again, the overlay list returns to default order automatically.
                self:ensureValidSelection()
                self:_flash("Helpers idle: list reset to default order", 1.25)
            end
            self._hadInUse = any
        end
    end
end

addModEventListener(HelperProfiles)
