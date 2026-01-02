-- RegisterPlayerActionEvents.lua
-- Clean, duplicate-safe input setup for both Player and Vehicle contexts.
-- Fixes: "❌ Failed to register ... in context _vehicleActionEventId" spam
-- by registering vehicle actions via vehicle:addActionEvent on a per-vehicle table.

-- ============================================================================
-- FS25_HelperProfiles
-- ModVersion: 1.1.0.2
-- Script:     RegisterPlayerActionEvents.lua
-- BuildTag:     20260102-4
-- ============================================================================

do
    local MOD_VERSION   = "1.1.0.2"
    local SCRIPT_NAME   = "RegisterPlayerActionEvents.lua"
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

local LOG = "[FS25_HelperProfiles] "

-- --- Utility: treat callback args as "press only" -----------------------------
local function _isPress(inputValue, callbackState)
    -- GIANTS can pass either analog value (>0 on press) or a keyStatus/state
    if type(inputValue) == "number" then
        return inputValue > 0
    elseif type(inputValue) == "boolean" then
        return inputValue == true
    end
    local v = tonumber(callbackState)
    return v ~= nil and v > 0
end

-- Cycle handler that works for both contexts/signatures
local function _onCycle(_, actionName, inputValue, callbackState, isAnalog)
    if not _isPress(inputValue, callbackState) then return end
    if HelperProfiles and HelperProfiles.cycleSelectionDebounced then
        HelperProfiles:cycleSelectionDebounced(1)
    elseif HelperProfiles and HelperProfiles.cycleSelection then
        HelperProfiles:cycleSelection(1)
    end
end

-- Toggle handler lives on HP_UI (robust version already there)
local function _onToggle(_, actionName, inputValue, callbackState, isAnalog)
    if HP_UI and HP_UI.onToggleAction then
        HP_UI:onToggleAction(actionName, inputValue, callbackState, isAnalog)
    end
end

-- --- Player (on-foot) context -------------------------------------------------
-- We keep ids on HelperProfiles and unregister properly to avoid duplicates.

local function _registerPlayerCycle()
    if HelperProfiles._playerCycleId ~= nil then return end
    local ok, id = g_inputBinding:registerActionEvent(
        InputAction.OPEN_HELPER_MENU,  -- you mapped semicolon/H to this
        HelperProfiles,                -- target table
        _onCycle,                      -- press-only wrapper
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true    -- startActive
    )
    if ok and id then
        HelperProfiles._playerCycleId = id
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(id, true)
        end
        print(("%s✅ Registered OPEN_HELPER_MENU (player)").format and ("%s✅ Registered OPEN_HELPER_MENU (player)"):format(LOG) or (LOG.."✅ Registered OPEN_HELPER_MENU (player)"))
    else
        print(LOG.."❌ Failed to register OPEN_HELPER_MENU (player)")
    end
end

local function _unregisterPlayerCycle()
    local id = HelperProfiles._playerCycleId
    if id ~= nil then
        g_inputBinding:removeActionEvent(id)
        HelperProfiles._playerCycleId = nil
        print(LOG.."Unregistered OPEN_HELPER_MENU (player)")
    end
end

local function _registerPlayerToggle()
    if HelperProfiles._playerToggleId ~= nil then return end
    local ok, id = g_inputBinding:registerActionEvent(
        InputAction.HP_TOGGLE_OVERLAY,
        HP_UI,
        _onToggle,
        false, true, false, true
    )
    if ok and id then
        HelperProfiles._playerToggleId = id
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(id, true)
        end
        print(LOG.."✅ Registered HP_TOGGLE_OVERLAY (player)")
    else
        print(LOG.."❌ Failed to register HP_TOGGLE_OVERLAY (player)")
    end
end

local function _unregisterPlayerToggle()
    local id = HelperProfiles._playerToggleId
    if id ~= nil then
        g_inputBinding:removeActionEvent(id)
        HelperProfiles._playerToggleId = nil
        print(LOG.."Unregistered HP_TOGGLE_OVERLAY (player)")
    end
end

-- Hook into PlayerInputComponent “global” events (covers on-foot)
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(self, controlling)
        _registerPlayerCycle()
        _registerPlayerToggle()
    end
)

PlayerInputComponent.removeGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.removeGlobalPlayerActionEvents,
    function(self)
        _unregisterPlayerCycle()
        _unregisterPlayerToggle()
    end
)

-- --- Vehicle context ----------------------------------------------------------
-- IMPORTANT: use per-vehicle table and vehicle:addActionEvent to avoid nil ids.

local function _ensureVehicleSpec(vehicle)
    vehicle.spec_hp = vehicle.spec_hp or {}
    local spec = vehicle.spec_hp
    spec.actionEvents = spec.actionEvents or {}
    return spec
end

local function _registerVehicleActions(vehicle, isActiveForInput)
    if not isActiveForInput then return end
    local spec = _ensureVehicleSpec(vehicle)

    -- Clear our action events each (re)arm to avoid duplicates
    if vehicle.clearActionEventsTable then
        vehicle:clearActionEventsTable(spec.actionEvents)
    end

    -- Cycle (OPEN_HELPER_MENU)
    local _, id1 = vehicle:addActionEvent(
        spec.actionEvents,
        InputAction.OPEN_HELPER_MENU,
        HelperProfiles,  -- target (we don’t rely on its legacy signature)
        _onCycle,
        false,  -- triggerDown?
        true,   -- triggerUp
        false,  -- triggerAlways
        true    -- startActive
    )
    if id1 ~= nil then
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(id1, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(id1, true)
        end
        if not spec._loggedCycle then
            print(LOG.."✅ Registered OPEN_HELPER_MENU (vehicle)")
            spec._loggedCycle = true
        end
    else
        print(LOG.."❌ Failed to register OPEN_HELPER_MENU (vehicle)")
    end

    -- Toggle (HP_TOGGLE_OVERLAY)
    local _, id2 = vehicle:addActionEvent(
        spec.actionEvents,
        InputAction.HP_TOGGLE_OVERLAY,
        HP_UI,
        _onToggle,
        false, true, false, true
    )
    if id2 ~= nil then
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(id2, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(id2, true)
        end
        if not spec._loggedToggle then
            print(LOG.."✅ Registered HP_TOGGLE_OVERLAY (vehicle)")
            spec._loggedToggle = true
        end
    else
        print(LOG.."❌ Failed to register HP_TOGGLE_OVERLAY (vehicle)")
    end
end

local function _unregisterVehicleActions(vehicle)
    if not vehicle or not vehicle.spec_hp or not vehicle.spec_hp.actionEvents then return end
    if vehicle.clearActionEventsTable then
        vehicle:clearActionEventsTable(vehicle.spec_hp.actionEvents)
        -- keep spec for future re-arm; no spam logs on next register
    end
end

if Vehicle and Vehicle.registerActionEvents then
    Vehicle.registerActionEvents = Utils.appendedFunction(
        Vehicle.registerActionEvents,
        function(self, isActiveForInput, isActiveForGUI)
            _registerVehicleActions(self, isActiveForInput)
        end
    )
end

if Vehicle and Vehicle.removeActionEvents then
    Vehicle.removeActionEvents = Utils.appendedFunction(
        Vehicle.removeActionEvents,
        function(self)
            _unregisterVehicleActions(self)
        end
    )
end
