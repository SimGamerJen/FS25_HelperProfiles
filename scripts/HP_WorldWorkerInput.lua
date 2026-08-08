-- HP_WorldWorkerInput.lua (FS25_HelperProfiles)
-- 2.2.0.0-alpha2: register the custom A-key menu action while the World dialog is open.

if HP_WorldWorkerInput ~= nil then return end
HP_WorldWorkerInput = { installed = false }

local LOG = "[FS25_HelperProfiles/WorldWorkerInput] "

local function isPress(inputValue, callbackState)
    if type(inputValue) == "number" then
        return inputValue > 0
    elseif type(inputValue) == "boolean" then
        return inputValue == true
    end
    local value = tonumber(callbackState)
    return value ~= nil and value > 0
end

local function removeMoveAction(screen)
    local id = screen ~= nil and screen._hpWorldMoveActionEventId or nil
    if id ~= nil and g_inputBinding ~= nil and g_inputBinding.removeActionEvent ~= nil then
        pcall(function() g_inputBinding:removeActionEvent(id) end)
    end
    if screen ~= nil then screen._hpWorldMoveActionEventId = nil end
end

local function onMoveAction(screen, actionName, inputValue, callbackState, isAnalog)
    if screen == nil or not isPress(inputValue, callbackState) then return end
    if screen.onClickMoveHere ~= nil then screen:onClickMoveHere(nil) end
end

local function registerMoveAction(screen)
    removeMoveAction(screen)

    local inputAction = InputAction ~= nil and InputAction.HP_CLEAR_ALL_BINDINGS or nil
    if screen == nil or g_inputBinding == nil or g_inputBinding.registerActionEvent == nil or inputAction == nil then
        print(LOG .. "Failed to register MOVE HERE action: input action unavailable")
        return
    end

    local callOk, registered, id = pcall(function()
        return g_inputBinding:registerActionEvent(
            inputAction,
            screen,
            onMoveAction,
            false,
            true,
            false,
            true
        )
    end)

    if callOk and registered == true and id ~= nil then
        screen._hpWorldMoveActionEventId = id
        if g_inputBinding.setActionEventTextPriority ~= nil then
            g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_LOW)
        end
        if g_inputBinding.setActionEventTextVisibility ~= nil then
            g_inputBinding:setActionEventTextVisibility(id, false)
        end
        if g_inputBinding.setActionEventActive ~= nil then
            g_inputBinding:setActionEventActive(id, true)
        end
        print(LOG .. "Registered A -> MOVE HERE (World dialog)")
    else
        print(LOG .. "Failed to register A -> MOVE HERE (World dialog)")
    end
end

if HP_WorldWorkerScreen ~= nil and HP_WorldWorkerScreen._hpWorldMoveInputPatched ~= true then
    local originalOpen = HP_WorldWorkerScreen.onOpen
    local originalClose = HP_WorldWorkerScreen.onClose

    function HP_WorldWorkerScreen:onOpen(...)
        originalOpen(self, ...)
        registerMoveAction(self)
    end

    function HP_WorldWorkerScreen:onClose(...)
        removeMoveAction(self)
        return originalClose(self, ...)
    end

    HP_WorldWorkerScreen._hpWorldMoveInputPatched = true
    HP_WorldWorkerInput.installed = true
    print(LOG .. "World MOVE HERE input wrapper installed")
end
