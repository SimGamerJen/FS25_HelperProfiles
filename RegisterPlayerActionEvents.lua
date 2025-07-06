-- RegisterPlayerActionEvents.lua

PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.registerGlobalPlayerActionEvents,
    function(self, controlling)
        print("[FS25_HelperProfiles] Registering keybind action event...")

        local success, actionEventId = pcall(function()
            return g_inputBinding:registerActionEvent(
                InputAction.OPEN_HELPER_MENU,   -- Must match modDesc.xml!
                HelperProfiles,                 -- The mod table
                HelperProfiles.onCycleHelper,   -- Handler function
                false, true, false, true, nil, true
            )
        end)

        if success and actionEventId then
            HelperProfiles.actionEventId = actionEventId
            print("[FS25_HelperProfiles] ✅ Keybind (;) registered and visible in Controls!")
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_VERY_LOW)
            g_inputBinding:setActionEventTextVisibility(actionEventId, true)
        else
            print("[FS25_HelperProfiles] ❌ Failed to register keybind action event")
            print("[FS25_HelperProfiles] Error details: " .. tostring(actionEventId))
        end
    end
)

PlayerInputComponent.removeGlobalPlayerActionEvents = Utils.appendedFunction(
    PlayerInputComponent.removeGlobalPlayerActionEvents,
    function(self)
        if HelperProfiles and HelperProfiles.actionEventId then
            print("[FS25_HelperProfiles] Unregistering keybind action event...")
            g_inputBinding:removeActionEvent(HelperProfiles.actionEventId)
            HelperProfiles.actionEventId = nil
            print("[FS25_HelperProfiles] Keybind unregistered")
        end
    end
)
