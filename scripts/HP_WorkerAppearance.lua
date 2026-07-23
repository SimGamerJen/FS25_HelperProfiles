-- HP_WorkerAppearance.lua (FS25_HelperProfiles)
-- ModVersion: 2.0.26
-- BuildTag: 20260513.4
-- PlayerWorkers-inspired runtime vehicle-character appearance bridge.
-- v2.0.5: reverts to the working 2.0.3 injection path; adds minimal success logging only.

HP_WorkerAppearance = HP_WorkerAppearance or {
    hooksInstalled = false,
    wrappedFunctions = {},
    vehicleAssignments = {},
    scanTimer = 0,
    debugEnabled = false,
    lastWarnAt = -999999,
}

local LOG = "[FS25_HelperProfiles/WorkerAppearance] "
local function hpwaPrint(msg) print(LOG .. tostring(msg)) end

function HP_WorkerAppearance:debug(msg)
    if self.debugEnabled then hpwaPrint(msg) end
end

function HP_WorkerAppearance:logAppliedOnce(vehicle, helper, preset, reason)
    if vehicle == nil then return end
    local presetId = tostring(preset and preset.id or "preset")
    local helperName = tostring(helper and helper.name or "?")
    local key = presetId .. "|" .. tostring(reason or "?")
    if vehicle.hpLastApplyLogKey ~= key then
        vehicle.hpLastApplyLogKey = key
        hpwaPrint("Applied worker appearance | helper=" .. helperName .. " | preset=" .. presetId .. " | vehicle=" .. self:getVehicleName(vehicle) .. " | reason=" .. tostring(reason or "?"))
    end
end

function HP_WorkerAppearance:getVehicleName(vehicle)
    if vehicle == nil then return "vehicle" end
    if type(vehicle.getFullName) == "function" then
        local ok, name = pcall(vehicle.getFullName, vehicle)
        if ok and name ~= nil and name ~= "" then return tostring(name) end
    end
    if type(vehicle.getName) == "function" then
        local ok, name = pcall(vehicle.getName, vehicle)
        if ok and name ~= nil and name ~= "" then return tostring(name) end
    end
    return tostring(vehicle.configFileName or vehicle)
end

function HP_WorkerAppearance:getHelperIndexForVehicle(vehicle)
    if vehicle ~= nil and type(vehicle.getAIHelperIndex) == "function" then
        local ok, idx = pcall(vehicle.getAIHelperIndex, vehicle)
        if ok and idx ~= nil then return idx end
    end
    if vehicle ~= nil and vehicle.spec_aiVehicle ~= nil then
        return vehicle.spec_aiVehicle.helperIndex or vehicle.spec_aiVehicle.aiHelperIndex
    end
    return nil
end

function HP_WorkerAppearance:getHelperForVehicle(vehicle)
    local assignment = self.vehicleAssignments[vehicle]
    if assignment ~= nil and assignment.helper ~= nil then
        return assignment.helper, assignment.helperIndex
    end

    local idx = self:getHelperIndexForVehicle(vehicle)
    if idx ~= nil and g_helperManager ~= nil and g_helperManager.indexToHelper ~= nil then
        local helper = g_helperManager.indexToHelper[idx]
        if helper ~= nil then return helper, idx end
    end

    return nil, idx
end

function HP_WorkerAppearance:onHelperHired(vehicle, helper, helperIndex)
    if vehicle == nil or helper == nil then return end
    self.vehicleAssignments[vehicle] = {
        helper = helper,
        helperIndex = helperIndex,
        assignedAt = g_time or 0,
    }
    vehicle.hpAssignedHelper = helper
    vehicle.hpAssignedHelperIndex = helperIndex
    self:debug("Assigned " .. tostring(helper.name) .. " to " .. self:getVehicleName(vehicle))
    self:applyAppearanceToVehicle(vehicle, "hireHelper", true, helper, helperIndex)
end

function HP_WorkerAppearance:shouldReplaceVehicleCharacter(vehicle, incomingStyle)
    if vehicle == nil or vehicle.spec_enterable == nil then
        return false, "no enterable spec"
    end
    if vehicle.spec_enterable.isEntered == true then
        return false, "vehicle entered by player"
    end
    if type(incomingStyle) == "table" and incomingStyle.hpIsHelperProfilesStyle == true then
        return false, "already helper-profiles style"
    end
    return true, nil
end

function HP_WorkerAppearance:buildStyleForVehicle(vehicle, helperArg)
    local helper, idx = helperArg, nil
    if helper == nil then
        helper, idx = self:getHelperForVehicle(vehicle)
    end
    if helper == nil then
        return nil, "no-helper-resolved", nil
    end

    if HP_ASBridge == nil or HP_ASBridge.createPlayerStyleForHelper == nil then
        return nil, "as-bridge-unavailable", helper
    end

    local style, err, preset = HP_ASBridge:createPlayerStyleForHelper(helper, idx)
    if style == nil then
        return nil, err or "style-build-failed", helper, preset
    end

    return style, nil, helper, preset
end

function HP_WorkerAppearance:getStyleSignature(style, preset)
    local presetId = style and style.hpPresetId or (preset and preset.id) or "unknown"
    return tostring(presetId)
end

function HP_WorkerAppearance:applyAppearanceToVehicle(vehicle, reason, force, helperArg, helperIndex)
    if vehicle == nil or type(vehicle.setVehicleCharacter) ~= "function" then return false end
    if vehicle.spec_enterable == nil or vehicle.spec_enterable.vehicleCharacter == nil then return false end

    local style, err, helper, preset = self:buildStyleForVehicle(vehicle, helperArg)
    if style == nil then
        local now = g_time or 0
        if err ~= "no-presets-in-category" and err ~= "avatar-switcher-unavailable" and now - (self.lastWarnAt or -999999) > 3000 then
            self.lastWarnAt = now
            hpwaPrint("Could not build worker style; using vanilla helper appearance. reason=" .. tostring(err))
        end
        return false
    end

    local signature = self:getStyleSignature(style, preset)
    if force ~= true and vehicle.hpLastAppliedAppearanceSignature == signature then
        return true
    end

    local ok, applyErr = pcall(vehicle.setVehicleCharacter, vehicle, style)
    if not ok then
        local now = g_time or 0
        if now - (self.lastWarnAt or -999999) > 3000 then
            self.lastWarnAt = now
            hpwaPrint("Failed to apply worker style; using vanilla helper appearance. error=" .. tostring(applyErr))
        end
        return false
    end

    vehicle.hpLastAppliedAppearanceSignature = signature
    self:debug("Applied " .. tostring(preset and preset.id or "preset") .. " to " .. self:getVehicleName(vehicle) .. " | helper=" .. tostring(helper and helper.name or "?") .. " | reason=" .. tostring(reason))
    self:logAppliedOnce(vehicle, helper, preset, reason)
    return true
end

function HP_WorkerAppearance:wrapSetVehicleCharacterFunction(originalFunc, label)
    if type(originalFunc) ~= "function" then return originalFunc end
    if self.wrappedFunctions[originalFunc] ~= nil then return self.wrappedFunctions[originalFunc] end

    local wrapped = function(vehicle, playerStyle, ...)
        local replace, reason = HP_WorkerAppearance:shouldReplaceVehicleCharacter(vehicle, playerStyle)
        if replace then
            local style, err, helper, preset = HP_WorkerAppearance:buildStyleForVehicle(vehicle, nil)
            if style ~= nil then
                HP_WorkerAppearance:debug("Substituting AS preset " .. tostring(preset and preset.id or "?") .. " in " .. tostring(label) .. " for " .. HP_WorkerAppearance:getVehicleName(vehicle))
                playerStyle = style
                HP_WorkerAppearance:logAppliedOnce(vehicle, helper, preset, tostring(label))
            else
                HP_WorkerAppearance:debug("Keeping original style in " .. tostring(label) .. " | reason=" .. tostring(err or reason))
            end
        end
        return originalFunc(vehicle, playerStyle, ...)
    end

    self.wrappedFunctions[originalFunc] = wrapped
    self.wrappedFunctions[wrapped] = wrapped
    return wrapped
end

function HP_WorkerAppearance:wrapSetRandomVehicleCharacterFunction(originalFunc, label)
    if type(originalFunc) ~= "function" then return originalFunc end
    if self.wrappedFunctions[originalFunc] ~= nil then return self.wrappedFunctions[originalFunc] end

    local wrapped = function(vehicle, helper, ...)
        HP_WorkerAppearance:debug("setRandomVehicleCharacter via " .. tostring(label) .. " for " .. HP_WorkerAppearance:getVehicleName(vehicle))
        if helper ~= nil then
            HP_WorkerAppearance.vehicleAssignments[vehicle] = { helper = helper, assignedAt = g_time or 0 }
        end
        if HP_WorkerAppearance:applyAppearanceToVehicle(vehicle, tostring(label), true, helper, nil) then
            return
        end
        return originalFunc(vehicle, helper, ...)
    end

    self.wrappedFunctions[originalFunc] = wrapped
    self.wrappedFunctions[wrapped] = wrapped
    return wrapped
end

function HP_WorkerAppearance:patchVehicleType(vehicleType, typeName)
    if type(vehicleType) ~= "table" or type(vehicleType.functions) ~= "table" then return 0 end
    local patched = 0
    if type(vehicleType.functions.setVehicleCharacter) == "function" then
        local wrapped = self:wrapSetVehicleCharacterFunction(vehicleType.functions.setVehicleCharacter, tostring(typeName) .. ".functions.setVehicleCharacter")
        if wrapped ~= vehicleType.functions.setVehicleCharacter then
            vehicleType.functions.setVehicleCharacter = wrapped
            patched = patched + 1
        end
    end
    if type(vehicleType.functions.setRandomVehicleCharacter) == "function" then
        local wrapped = self:wrapSetRandomVehicleCharacterFunction(vehicleType.functions.setRandomVehicleCharacter, tostring(typeName) .. ".functions.setRandomVehicleCharacter")
        if wrapped ~= vehicleType.functions.setRandomVehicleCharacter then
            vehicleType.functions.setRandomVehicleCharacter = wrapped
            patched = patched + 1
        end
    end
    return patched
end

function HP_WorkerAppearance:patchRegisteredVehicleTypes()
    local patched = 0
    local manager = g_vehicleTypeManager
    if manager ~= nil then
        for _, typeTable in ipairs({ manager.types, manager.vehicleTypes, manager.nameToType }) do
            if type(typeTable) == "table" then
                for typeName, vehicleType in pairs(typeTable) do
                    patched = patched + self:patchVehicleType(vehicleType, typeName)
                end
            end
        end
    end
    return patched
end

function HP_WorkerAppearance:patchVehicleInstance(vehicle)
    if type(vehicle) ~= "table" or vehicle.spec_enterable == nil then return 0 end
    local patched = 0
    if type(vehicle.setVehicleCharacter) == "function" and vehicle.hpSetVehicleCharacterWrapped ~= true then
        vehicle.setVehicleCharacter = self:wrapSetVehicleCharacterFunction(vehicle.setVehicleCharacter, "vehicle.setVehicleCharacter")
        vehicle.hpSetVehicleCharacterWrapped = true
        patched = patched + 1
    end
    if type(vehicle.setRandomVehicleCharacter) == "function" and vehicle.hpSetRandomVehicleCharacterWrapped ~= true then
        vehicle.setRandomVehicleCharacter = self:wrapSetRandomVehicleCharacterFunction(vehicle.setRandomVehicleCharacter, "vehicle.setRandomVehicleCharacter")
        vehicle.hpSetRandomVehicleCharacterWrapped = true
        patched = patched + 1
    end
    return patched
end

function HP_WorkerAppearance:patchLoadedVehicles()
    local patched = 0
    if g_currentMission ~= nil and type(g_currentMission.vehicles) == "table" then
        for _, vehicle in pairs(g_currentMission.vehicles) do
            patched = patched + self:patchVehicleInstance(vehicle)
        end
    end
    return patched
end

function HP_WorkerAppearance:getVehicleIsAIActive(vehicle)
    if vehicle == nil then return false end
    if type(vehicle.getIsAIActive) == "function" then
        local ok, active = pcall(vehicle.getIsAIActive, vehicle)
        if ok then return active == true end
    end
    if vehicle.spec_aiVehicle ~= nil then
        if vehicle.spec_aiVehicle.isActive ~= nil then return vehicle.spec_aiVehicle.isActive == true end
        if vehicle.spec_aiVehicle.aiActive ~= nil then return vehicle.spec_aiVehicle.aiActive == true end
    end
    if vehicle.spec_enterable ~= nil then
        local spec = vehicle.spec_enterable
        if spec.isControlled == true and spec.isEntered ~= true then return true end
        if spec.controllerFarmId ~= nil and spec.controllerFarmId ~= 0 and spec.isEntered ~= true and spec.isControlled == true then return true end
    end
    return false
end

function HP_WorkerAppearance:scanAndFixWorkers(force)
    local count = 0
    if g_currentMission ~= nil and type(g_currentMission.vehicles) == "table" then
        for _, vehicle in pairs(g_currentMission.vehicles) do
            if self:getVehicleIsAIActive(vehicle) then
                if self:applyAppearanceToVehicle(vehicle, force and "manualRefresh" or "periodicScan", force == true) then
                    count = count + 1
                end
            end
        end
    end
    return count
end

function HP_WorkerAppearance:refreshActiveWorkers()
    self:patchLoadedVehicles()
    local count = self:scanAndFixWorkers(true)
    hpwaPrint("Refreshed " .. tostring(count) .. " active AI worker vehicle(s).")
    return count
end

function HP_WorkerAppearance:installHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true
    local hooks = 0
    if Enterable ~= nil then
        if type(Enterable.setVehicleCharacter) == "function" then
            Enterable.setVehicleCharacter = self:wrapSetVehicleCharacterFunction(Enterable.setVehicleCharacter, "Enterable.setVehicleCharacter")
            hooks = hooks + 1
        end
        if type(Enterable.setRandomVehicleCharacter) == "function" then
            Enterable.setRandomVehicleCharacter = self:wrapSetRandomVehicleCharacterFunction(Enterable.setRandomVehicleCharacter, "Enterable.setRandomVehicleCharacter")
            hooks = hooks + 1
        end
    end
    hooks = hooks + self:patchRegisteredVehicleTypes()
    hpwaPrint("Installed vehicle-character hooks: " .. tostring(hooks))
end

function HP_WorkerAppearance:update(dt)
    self.scanTimer = (self.scanTimer or 0) + (dt or 0)
    if self.scanTimer >= 1000 then
        self.scanTimer = 0
        self:patchLoadedVehicles()
        self:scanAndFixWorkers(false)
    end
end

function HP_WorkerAppearance:loadMap()
    self:installHooks()
    self:patchLoadedVehicles()
end

function HP_WorkerAppearance:deleteMap()
    self.vehicleAssignments = {}
    self.lastWarnAt = -999999
end

addModEventListener(HP_WorkerAppearance)
