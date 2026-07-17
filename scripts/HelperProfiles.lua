-- HelperProfiles.lua (FS25_HelperProfiles) – debounced cycle + UI bridge
-- Semicolon/H binding cycles helpers; PN-style overlay handled by HP_UI.

-- ============================================================================
-- FS25_HelperProfiles
-- ModVersion: 2.0.25
-- Script:     HelperProfiles.lua
-- BuildTag:   20260105-1
-- ============================================================================

do
    local MOD_VERSION   = "2.0.25"
    local SCRIPT_NAME   = "HelperProfiles.lua"
    local BUILD_TAG     = "20260513-2"
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

-- Default-order caching / reset-on-idle behaviour
HelperProfiles._defaultOrderRefs = nil   -- array of helper refs in default order
HelperProfiles._defaultPosByRef  = nil   -- map: helperRef -> position
HelperProfiles._hadInUse         = nil   -- tracks transition to "all idle"
HelperProfiles._resetOrderWhenIdle = true -- feature flag
HelperProfiles._pickMode = HelperProfiles._pickMode or "preferSelected"  -- preferSelected | firstFree

local function hpI18n(key, fallback)
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, value = pcall(g_i18n.getText, g_i18n, key)
        if ok and value ~= nil and value ~= "" and value ~= key then
            return value
        end
    end
    return fallback or key
end

local function hpFormat(key, fallback, ...)
    local pattern = hpI18n(key, fallback)
    local ok, value = pcall(string.format, pattern, ...)
    if ok then return value end
    return pattern
end

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

local function _containsHelper(list, wanted)
    if wanted == nil then return false end
    for _, helper in ipairs(list or {}) do
        if helper == wanted then return true end
    end
    return false
end

-- Public roster accessor used by UI + selection logic.
-- Once the idle A-J order has been cached, keep returning that complete roster
-- even while GIANTS removes active workers from availableHelpers.
function HelperProfiles:getProfiles()
    local available = _getHelpersRaw()

    -- Only establish the stable A-J roster while every helper is idle.
    self:_cacheDefaultOrderIfReady(available)

    if self._defaultOrderRefs ~= nil and #self._defaultOrderRefs > 0 then
        local roster = {}
        for index, helper in ipairs(self._defaultOrderRefs) do
            roster[index] = helper
        end
        return roster
    end

    if self._resetOrderWhenIdle and not _anyInUse(available) and self._defaultPosByRef ~= nil then
        self:_sortToDefault(available)
    end

    return available
end

function HelperProfiles:isHelperActive(helper)
    if helper == nil then return false end
    if helper.inUse == true then return true end

    -- In FS25 an active helper may be removed from availableHelpers. The cached
    -- roster reference remains valid, so absence from the live available list is
    -- also treated as active/unavailable for selection purposes.
    if self._defaultPosByRef ~= nil then
        return not _containsHelper(_getHelpersRaw(), helper)
    end

    return false
end

function HelperProfiles:isHelperSelectable(helper)
    return helper ~= nil and not self:isHelperActive(helper)
end

function HelperProfiles:getActiveHelperCount()
    local count = 0
    for _, helper in ipairs(self:getProfiles()) do
        if self:isHelperActive(helper) then count = count + 1 end
    end
    return count
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

    local startIndex = clamp(self.selectedIdx or 1, 1, #profiles)

    -- Prefer keeping the same helper selected by stable reference, but never
    -- retain an active worker as the selectable overlay entry.
    if self.selectedHelperRef ~= nil then
        for i, helper in ipairs(profiles) do
            if helper == self.selectedHelperRef then
                startIndex = i
                if self:isHelperSelectable(helper) then
                    self.selectedIdx = i
                    return
                end
                break
            end
        end
    end

    -- The selected worker became active (or disappeared). Move to the next free
    -- stable roster entry, wrapping A-J. If all are active, keep no selection.
    for offset = 0, #profiles - 1 do
        local index = ((startIndex - 1 + offset) % #profiles) + 1
        local helper = profiles[index]
        if self:isHelperSelectable(helper) then
            self.selectedIdx = index
            self.selectedHelperRef = helper
            return
        end
    end

    self.selectedIdx = startIndex
    self.selectedHelperRef = nil
end

function HelperProfiles:getSelectionIndex()
    return self.selectedIdx or 1
end

function HelperProfiles:getSelectedHelper()
    self:ensureValidSelection()
    return self.selectedHelperRef, self.selectedIdx
end

function HelperProfiles:getDisplayNameForHelper(helper, idx)
    if HP_ASBridge ~= nil and HP_ASBridge.getDisplayNameForHelper ~= nil then
        local ok, displayName, baseName = pcall(HP_ASBridge.getDisplayNameForHelper, HP_ASBridge, helper, idx)
        if ok and displayName ~= nil and tostring(displayName) ~= "" then
            return tostring(displayName), tostring(baseName or (helper and helper.name) or idx or "?")
        end
    end
    local baseName = helper ~= nil and helper.name or ("Helper " .. tostring(idx or "?"))
    return tostring(baseName), tostring(baseName)
end

function HelperProfiles:getAppearanceLabelForHelper(helper, idx)
    if HP_ASBridge ~= nil and HP_ASBridge.getAppearanceLabelForHelper ~= nil then
        local ok, label, presetId, category = pcall(HP_ASBridge.getAppearanceLabelForHelper, HP_ASBridge, helper, idx)
        if ok then
            return label, presetId, category
        end
    end
    return nil, nil, nil
end

function HelperProfiles:cycleSelectedAppearance(delta)
    local helper, idx = self:getSelectedHelper()
    if helper == nil then
        self:_flash(hpI18n("hp_flash_no_helper_selected", "No helper selected"), 1.2)
        return false, "no-helper"
    end
    if HP_ASBridge == nil or HP_ASBridge.cycleAppearance == nil then
        self:_flash(hpI18n("hp_flash_as_bridge_unavailable", "AvatarSwitcher bridge unavailable"), 1.5)
        return false, "bridge-unavailable"
    end

    local ok, result = HP_ASBridge:cycleAppearance(helper, idx, delta or 1)
    if ok then
        local label = tostring(result.name or result.id or "appearance")
        local displayName = self.getDisplayNameForHelper ~= nil and self:getDisplayNameForHelper(helper, idx) or tostring(helper.name or "Helper")
        self:_flash(hpFormat("hp_flash_appearance_changed", "%s appearance: %s", tostring(displayName or helper.name or hpI18n("hp_helper_generic", "Helper")), label), 1.5)
        if HP_WorkerAppearance ~= nil and HP_WorkerAppearance.refreshActiveWorkers ~= nil then
            HP_WorkerAppearance:refreshActiveWorkers()
        end
        return true, result
    end

    self:_flash(hpFormat("hp_flash_appearance_cycle_failed", "Appearance cycle failed: %s", tostring(result)), 1.5)
    return false, result
end

local function isFree(h)
    return HelperProfiles ~= nil and HelperProfiles:isHelperSelectable(h)
end

-- pick our preferred helper (selected if free; else next free; else nil)

-- ----------------------------------------------------------------------------
-- Helper selection mode (runtime switchable)
--   preferSelected: current behaviour (selected helper if free, else fallback)
--   firstFree:      always use the first available helper in list order
-- ----------------------------------------------------------------------------
function HelperProfiles:getPickMode()
    return self._pickMode or "preferSelected"
end

function HelperProfiles:setPickMode(mode, silent)
    if mode ~= "preferSelected" and mode ~= "firstFree" then
        return false, "invalid-mode"
    end
    self._pickMode = mode
    if not silent then
        self:_flash(hpFormat("hp_flash_mode", "Mode: %s", mode), 1.25)
    end
    return true
end

function HelperProfiles:togglePickMode(silent)
    local cur = self:getPickMode()
    local nxt = (cur == "firstFree") and "preferSelected" or "firstFree"
    return self:setPickMode(nxt, silent)
end

function HelperProfiles:pickPreferredFreeHelper()
    local profiles = self:getProfiles()
    if #profiles == 0 then return nil, "none-available" end

    local mode = self:getPickMode()

    -- Mode: firstFree (always first free helper in list order)
    if mode == "firstFree" then
        for i = 1, #profiles do
            local h = profiles[i]
            if isFree(h) then
                -- keep UI selection aligned with actual pick
                self.selectedIdx = i
                self.selectedHelperRef = h
                return h, "firstFree"
            end
        end
        return nil, "none-free"
    end

    -- Mode: preferSelected (legacy behaviour)
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
    if #profiles == 0 then return false, "no-helpers" end

    idx = math.floor(math.max(1, math.min(idx or 1, #profiles)))
    local target = profiles[idx]
    if not self:isHelperSelectable(target) then
        local displayName = self:getDisplayNameForHelper(target, idx)
        self:_flash(hpFormat("hp_flash_helper_active", "%s is active and cannot be selected", tostring(displayName)), 1.25)
        return false, "helper-active"
    end

    self.selectedIdx = idx
    self.selectedHelperRef = target

    local label = target and target.name or (hpI18n("hp_helper_generic", "Helper") .. " " .. tostring(self.selectedIdx))
    self:_flash(hpFormat("hp_flash_helper_selected", "Helper: %s (%d/%d)", label, self.selectedIdx, #profiles), 1.2)
    print(("[FS25_HelperProfiles] Selected helper: %s"):format(label))
    return true, nil
end

function HelperProfiles:cycleSelection(delta)
    delta = delta or 1
    local profiles = self:getProfiles()
    if #profiles == 0 then return false end
    self:ensureValidSelection()

    local startIndex = clamp(self.selectedIdx or 1, 1, #profiles)
    local direction = delta >= 0 and 1 or -1
    for step = 1, #profiles do
        local index = ((startIndex - 1 + (step * direction)) % #profiles) + 1
        if self:isHelperSelectable(profiles[index]) then
            return self:setSelection(index)
        end
    end

    self:_flash(hpI18n("hp_no_helpers_available", "No helpers available"), 1.25)
    return false
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
    local list = self:getProfiles()
    if self:getActiveHelperCount() > 0 then
        self:_flash(hpI18n("hp_flash_reset_order_active", "Cannot reset helper order: helpers active"), 1.5)
        return false, "helpers-active"
    end
    self:_cacheDefaultOrderIfReady(list)
    if self._defaultPosByRef == nil then
        self:_flash(hpI18n("hp_flash_reset_order_no_default", "Cannot reset helper order: no default cached yet"), 1.5)
        return false, "no-default"
    end
    -- No engine mutation required: when idle, getProfiles() will render default order.
    self:ensureValidSelection()
    self:_flash(hpI18n("hp_flash_order_reset", "Helper order reset to default"), 1.2)
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
                    if HP_WorkerAppearance ~= nil and HP_WorkerAppearance.onHelperHired ~= nil then
                        HP_WorkerAppearance:onHelperHired(vehicle, h, idx)
                    end
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

    -- Track "helpers active -> all idle" transition using the stable roster.
    local available = _getHelpersRaw()
    if available ~= nil and #available > 0 then
        self:_cacheDefaultOrderIfReady(available)
    end

    local roster = self:getProfiles()
    if roster ~= nil and #roster > 0 then
        local any = self:getActiveHelperCount() > 0

        -- If the selected helper has just become active, move selection to the
        -- next available worker without removing the active row from the overlay.
        self:ensureValidSelection()

        if self._hadInUse == nil then
            self._hadInUse = any
        else
            if self._hadInUse and not any and self._resetOrderWhenIdle and self._defaultPosByRef ~= nil then
                self:ensureValidSelection()
                self:_flash(hpI18n("hp_flash_helpers_idle_reset", "Helpers idle: list reset to default order"), 1.25)
            end
            self._hadInUse = any
        end
    end
end

addModEventListener(HelperProfiles)
