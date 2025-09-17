-- RegisterPlayerActionEvents.lua
-- Ensure semicolon action is registered BOTH on foot and in vehicles.

local function registerActionSafe(target, actionName, callback, storeField)
    if HelperProfiles[storeField] ~= nil then
        -- already registered in this context
        return
    end
    local success, actionEventId = g_inputBinding:registerActionEvent(
        InputAction[actionName],  -- use enum from modDesc <actions>
        target,                   -- we pass the HelperProfiles table as context
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
        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
        g_inputBinding:setActionEventTextVisibility(actionEventId, true)
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

-- ON-FOOT (player) context
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(self, controlling)
        registerActionSafe(HelperProfiles, "OPEN_HELPER_MENU", HelperProfiles.onCycleAction, "_playerActionEventId")
    end
)

PlayerInputComponent.removeGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.removeGlobalPlayerActionEvents,
    function(self)
        unregisterActionSafe("_playerActionEventId")
    end
)

-- IN-VEHICLE context
if Vehicle and Vehicle.registerActionEvents then
    Vehicle.registerActionEvents = Utils.appendedFunction(
        Vehicle.registerActionEvents,
        function(self, isActiveForInput, isActiveForGUI)
            if isActiveForInput then
                registerActionSafe(HelperProfiles, "OPEN_HELPER_MENU", HelperProfiles.onCycleAction, "_vehicleActionEventId")
            end
        end
    )
end

if Vehicle and Vehicle.removeActionEvents then
    Vehicle.removeActionEvents = Utils.appendedFunction(
        Vehicle.removeActionEvents,
        function(self)
            -- unregister when leaving vehicle or when a new context is created
            unregisterActionSafe("_vehicleActionEventId")
        end
    )
end
