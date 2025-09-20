-- RegisterPlayerActionEvents.lua
-- Register once per context; debounce inside core prevents double-fire.
-- Cycle action uses OPEN_HELPER_MENU (as in your setup).
-- Toggle action uses HP_TOGGLE_OVERLAY (bind in Controls → MISC).

-- ==== Helpers for the cycle action (semicolon/H) ==============================

local function registerActionSafe(target, actionName, callback, storeField)
    if HelperProfiles[storeField] ~= nil then
        return
    end
    local success, actionEventId = g_inputBinding:registerActionEvent(
        InputAction[actionName],  -- enum from modDesc <actions>
        target,                   -- HelperProfiles as context
        callback,                 -- HelperProfiles.onCycleAction
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- triggerAlways
        true,   -- startActive
        nil,    -- callbackState
        true    -- disableConflictWarning
    )
    if success and actionEventId then
        HelperProfiles[storeField] = actionEventId
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)
        end
        print(("[FS25_HelperProfiles] ✅ Registered %s in context %s"):format(actionName, storeField))
    else
        print(("[FS25_HelperProfiles] ❌ Failed to register %s in context %s"):format(actionName, storeField))
    end
end

local function unregisterActionSafe(storeField)
    local id = HelperProfiles[storeField]
    if id ~= nil then
        g_inputBinding:removeActionEvent(id)
        HelperProfiles[storeField] = nil
        print(("[FS25_HelperProfiles] Unregistered action from context %s"):format(storeField))
    end
end

-- ==== Toggle action (HP_TOGGLE_OVERLAY) per-context registration ==============

local function registerToggleSafe_player()
    if HelperProfiles._playerToggleActionEventId ~= nil then return end
    local ok, id = g_inputBinding:registerActionEvent(
        InputAction.HP_TOGGLE_OVERLAY,
        HP_UI,                -- target table
        HP_UI.onToggleAction, -- robust handler reading analog/digital press
        false,  -- triggerUp
        true,   -- triggerDown
        false,  -- repeat
        true    -- startActive
    )
    if ok and id then
        HelperProfiles._playerToggleActionEventId = id
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(id, true)
        end
        print("[FS25_HelperProfiles] ✅ Registered HP_TOGGLE_OVERLAY (player)")
    else
        print("[FS25_HelperProfiles] ❌ Failed to register HP_TOGGLE_OVERLAY (player)")
    end
end

local function registerToggleSafe_vehicle()
    if HelperProfiles._vehicleToggleActionEventId ~= nil then return end
    local ok, id = g_inputBinding:registerActionEvent(
        InputAction.HP_TOGGLE_OVERLAY,
        HP_UI,
        HP_UI.onToggleAction,
        false, true, false, true
    )
    if ok and id then
        HelperProfiles._vehicleToggleActionEventId = id
        if g_inputBinding.setActionEventTextPriority then
            g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility then
            g_inputBinding:setActionEventTextVisibility(id, true)
        end
        print("[FS25_HelperProfiles] ✅ Registered HP_TOGGLE_OVERLAY (vehicle)")
    else
        print("[FS25_HelperProfiles] ❌ Failed to register HP_TOGGLE_OVERLAY (vehicle)")
    end
end

local function unregisterToggleSafe_player()
    local id = HelperProfiles._playerToggleActionEventId
    if id ~= nil then
        g_inputBinding:removeActionEvent(id)
        HelperProfiles._playerToggleActionEventId = nil
        print("[FS25_HelperProfiles] Unregistered HP_TOGGLE_OVERLAY (player)")
    end
end

local function unregisterToggleSafe_vehicle()
    local id = HelperProfiles._vehicleToggleActionEventId
    if id ~= nil then
        g_inputBinding:removeActionEvent(id)
        HelperProfiles._vehicleToggleActionEventId = nil
        print("[FS25_HelperProfiles] Unregistered HP_TOGGLE_OVERLAY (vehicle)")
    end
end

-- ==== PLAYER (on-foot) context ===============================================

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(self, controlling)
        -- Cycle selection (uses OPEN_HELPER_MENU per your existing mapping)
        registerActionSafe(HelperProfiles, "OPEN_HELPER_MENU", HelperProfiles.onCycleAction, "_playerActionEventId")
        -- Toggle overlay
        registerToggleSafe_player()
    end
)

PlayerInputComponent.removeGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.removeGlobalPlayerActionEvents,
    function(self)
        unregisterActionSafe("_playerActionEventId")
        unregisterToggleSafe_player()
    end
)

-- ==== VEHICLE context =========================================================

if Vehicle and Vehicle.registerActionEvents then
    Vehicle.registerActionEvents = Utils.appendedFunction(
        Vehicle.registerActionEvents,
        function(self, isActiveForInput, isActiveForGUI)
            if isActiveForInput then
                -- Cycle selection
                registerActionSafe(HelperProfiles, "OPEN_HELPER_MENU", HelperProfiles.onCycleAction, "_vehicleActionEventId")
                -- Toggle overlay
                registerToggleSafe_vehicle()
            end
        end
    )
end

if Vehicle and Vehicle.removeActionEvents then
    Vehicle.removeActionEvents = Utils.appendedFunction(
        Vehicle.removeActionEvents,
        function(self)
            unregisterActionSafe("_vehicleActionEventId")
            unregisterToggleSafe_vehicle()
        end
    )
end
