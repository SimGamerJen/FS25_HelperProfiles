-- RegisterPlayerActionEvents.lua
-- Clean, duplicate-safe input setup for both Player and Vehicle contexts.
-- v2.0.8-alpha adds HP_OPEN_APPEARANCE_MENU for the mouse-driven binding UI.

HelperProfiles = HelperProfiles or {}

local LOG = "[FS25_HelperProfiles] "

local _loggedVehicleCycle = false
local _loggedVehicleToggle = false
local _loggedVehicleMode = false
local _loggedVehicleAppearanceMenu = false

local function _isPress(inputValue, callbackState)
    if type(inputValue) == "number" then
        return inputValue > 0
    elseif type(inputValue) == "boolean" then
        return inputValue == true
    end
    local v = tonumber(callbackState)
    return v ~= nil and v > 0
end

local function _onCycle(_, actionName, inputValue, callbackState, isAnalog)
    if not _isPress(inputValue, callbackState) then return end
    if HelperProfiles and HelperProfiles.cycleSelectionDebounced then
        HelperProfiles:cycleSelectionDebounced(1)
    elseif HelperProfiles and HelperProfiles.cycleSelection then
        HelperProfiles:cycleSelection(1)
    end
end

local function _onToggle(_, actionName, inputValue, callbackState, isAnalog)
    if HP_UI and HP_UI.onToggleAction then
        HP_UI:onToggleAction(actionName, inputValue, callbackState, isAnalog)
    end
end

local function _onMode(_, actionName, inputValue, callbackState, isAnalog)
    if not _isPress(inputValue, callbackState) then return end
    if HelperProfiles and HelperProfiles.togglePickMode then
        HelperProfiles:togglePickMode()
    end
end

local function _onAppearanceMenu(_, actionName, inputValue, callbackState, isAnalog)
    if not _isPress(inputValue, callbackState) then return end
    if HP_AppearanceMenu ~= nil and HP_AppearanceMenu.toggle ~= nil then
        HP_AppearanceMenu:toggle()
    end
end

local function _setActionEventLowPriority(id, visible)
    if id == nil or g_inputBinding == nil then return end
    if g_inputBinding.setActionEventTextPriority then
        g_inputBinding:setActionEventTextPriority(id, GS_PRIO_VERY_LOW)
    end
    if g_inputBinding.setActionEventTextVisibility then
        g_inputBinding:setActionEventTextVisibility(id, visible ~= false)
    end
end

local function _registerPlayerAction(field, inputAction, target, callback, label)
    if HelperProfiles[field] ~= nil then return end
    if g_inputBinding == nil or inputAction == nil then
        print(LOG .. "❌ Failed to register " .. tostring(label) .. " (player): input action unavailable")
        return
    end
    local ok, id = g_inputBinding:registerActionEvent(inputAction, target, callback, false, true, false, true)
    if ok and id then
        HelperProfiles[field] = id
        _setActionEventLowPriority(id, true)
        print(LOG .. "✅ Registered " .. tostring(label) .. " (player)")
    else
        print(LOG .. "❌ Failed to register " .. tostring(label) .. " (player)")
    end
end

local function _unregisterPlayerAction(field, label)
    local id = HelperProfiles[field]
    if id ~= nil and g_inputBinding ~= nil then
        g_inputBinding:removeActionEvent(id)
        HelperProfiles[field] = nil
        print(LOG .. "Unregistered " .. tostring(label) .. " (player)")
    end
end

local function _registerPlayerActions()
    _registerPlayerAction("_playerCycleId", InputAction.OPEN_HELPER_MENU, HelperProfiles, _onCycle, "OPEN_HELPER_MENU")
    _registerPlayerAction("_playerToggleId", InputAction.HP_TOGGLE_OVERLAY, HP_UI, _onToggle, "HP_TOGGLE_OVERLAY")
    _registerPlayerAction("_playerModeId", InputAction.HP_TOGGLE_MODE, HelperProfiles, _onMode, "HP_TOGGLE_MODE")
    _registerPlayerAction("_playerAppearanceMenuId", InputAction.HP_OPEN_APPEARANCE_MENU, HP_AppearanceMenu or HelperProfiles, _onAppearanceMenu, "HP_OPEN_APPEARANCE_MENU")
end

local function _unregisterPlayerActions()
    _unregisterPlayerAction("_playerCycleId", "OPEN_HELPER_MENU")
    _unregisterPlayerAction("_playerToggleId", "HP_TOGGLE_OVERLAY")
    _unregisterPlayerAction("_playerModeId", "HP_TOGGLE_MODE")
    _unregisterPlayerAction("_playerAppearanceMenuId", "HP_OPEN_APPEARANCE_MENU")
end

if PlayerInputComponent ~= nil and PlayerInputComponent.registerGlobalPlayerActionEvents ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(
        PlayerInputComponent.registerGlobalPlayerActionEvents,
        function(self, controlling)
            _registerPlayerActions()
        end
    )
end

if PlayerInputComponent ~= nil and PlayerInputComponent.removeGlobalPlayerActionEvents ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    PlayerInputComponent.removeGlobalPlayerActionEvents = Utils.appendedFunction(
        PlayerInputComponent.removeGlobalPlayerActionEvents,
        function(self)
            _unregisterPlayerActions()
        end
    )
end

local function _ensureVehicleSpec(vehicle)
    vehicle.spec_hp = vehicle.spec_hp or {}
    local spec = vehicle.spec_hp
    spec.actionEvents = spec.actionEvents or {}
    return spec
end

local function _addVehicleAction(vehicle, spec, inputAction, target, callback, label, loggedFlagName)
    if inputAction == nil then
        print(LOG .. "❌ Failed to register " .. tostring(label) .. " (vehicle): input action unavailable")
        return nil
    end
    local _, id = vehicle:addActionEvent(spec.actionEvents, inputAction, target, callback, false, true, false, true)
    if id ~= nil then
        _setActionEventLowPriority(id, true)
        if loggedFlagName == "cycle" and not _loggedVehicleCycle then
            print(LOG .. "✅ Registered " .. tostring(label) .. " (vehicle)")
            _loggedVehicleCycle = true
        elseif loggedFlagName == "toggle" and not _loggedVehicleToggle then
            print(LOG .. "✅ Registered " .. tostring(label) .. " (vehicle)")
            _loggedVehicleToggle = true
        elseif loggedFlagName == "mode" and not _loggedVehicleMode then
            print(LOG .. "✅ Registered " .. tostring(label) .. " (vehicle)")
            _loggedVehicleMode = true
        elseif loggedFlagName == "appearance" and not _loggedVehicleAppearanceMenu then
            print(LOG .. "✅ Registered " .. tostring(label) .. " (vehicle)")
            _loggedVehicleAppearanceMenu = true
        end
    else
        print(LOG .. "❌ Failed to register " .. tostring(label) .. " (vehicle)")
    end
    return id
end

local function _registerVehicleActions(vehicle, isActiveForInput)
    if not isActiveForInput or vehicle == nil or vehicle.addActionEvent == nil then return end
    local spec = _ensureVehicleSpec(vehicle)

    if vehicle.clearActionEventsTable then
        vehicle:clearActionEventsTable(spec.actionEvents)
    end

    _addVehicleAction(vehicle, spec, InputAction.OPEN_HELPER_MENU, HelperProfiles, _onCycle, "OPEN_HELPER_MENU", "cycle")
    _addVehicleAction(vehicle, spec, InputAction.HP_TOGGLE_OVERLAY, HP_UI, _onToggle, "HP_TOGGLE_OVERLAY", "toggle")
    _addVehicleAction(vehicle, spec, InputAction.HP_TOGGLE_MODE, HelperProfiles, _onMode, "HP_TOGGLE_MODE", "mode")
    _addVehicleAction(vehicle, spec, InputAction.HP_OPEN_APPEARANCE_MENU, HP_AppearanceMenu or HelperProfiles, _onAppearanceMenu, "HP_OPEN_APPEARANCE_MENU", "appearance")
end

local function _unregisterVehicleActions(vehicle)
    if not vehicle or not vehicle.spec_hp or not vehicle.spec_hp.actionEvents then return end
    if vehicle.clearActionEventsTable then
        vehicle:clearActionEventsTable(vehicle.spec_hp.actionEvents)
    end
end

if Vehicle ~= nil and Vehicle.registerActionEvents ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    Vehicle.registerActionEvents = Utils.appendedFunction(
        Vehicle.registerActionEvents,
        function(self, isActiveForInput, isActiveForGUI)
            _registerVehicleActions(self, isActiveForInput)
        end
    )
end

if Vehicle ~= nil and Vehicle.removeActionEvents ~= nil and Utils ~= nil and Utils.appendedFunction ~= nil then
    Vehicle.removeActionEvents = Utils.appendedFunction(
        Vehicle.removeActionEvents,
        function(self)
            _unregisterVehicleActions(self)
        end
    )
end
