-- HP_WorldPresenceSmoothing.lua (FS25_HelperProfiles)
-- Alpha 3 turn refinement: drive graphical facing through the same model-yaw
-- path used by FS25's on-foot player, while keeping rotationVelocity available
-- to the native HumanGraphicsComponent turn animation.
--
-- The first Alpha 3 build rotated graphicsRootNode while also driving the turn
-- animation, which jittered. The second build neutralised rotationVelocity,
-- which was smooth but looked like a mannequin swivel. This third pass keeps
-- the presence layer's target/timing interpolation but routes the resulting yaw
-- through HumanGraphicsComponent:setModelYaw() where available.

if HP_WorldPresence == nil then return end
if HP_WorldPresenceSmoothing ~= nil then return end

HP_WorldPresenceSmoothing = {
    version = "2.2.0.0-alpha3-presence-3"
}

local Presence = HP_WorldPresence
local LOG = "[FS25_HelperProfiles/WorldPresence] "

local function getRootYaw(graphics)
    if graphics == nil or graphics.graphicsRootNode == nil or getRotation == nil then return nil end
    local ok, _, yaw = pcall(getRotation, graphics.graphicsRootNode)
    if ok and tonumber(yaw) ~= nil then return tonumber(yaw) end
    return nil
end

local function restoreRootYaw(graphics, yaw)
    if graphics == nil or graphics.graphicsRootNode == nil or yaw == nil or setRotation == nil then return end
    pcall(setRotation, graphics.graphicsRootNode, 0, yaw, 0)
end

local function setRotationVelocityNeutral(graphics)
    if graphics == nil or graphics.animationParameters == nil then return end
    local parameter = graphics.animationParameters.rotationVelocity
    if parameter == nil then return end

    if type(parameter) == "table" and parameter.setValue ~= nil then
        pcall(parameter.setValue, parameter, 0)
    elseif graphics.animation ~= nil and graphics.animation.setParameter ~= nil then
        pcall(graphics.animation.setParameter, graphics.animation, parameter, 0)
    end
end

if Presence._hpNativeModelYawPatched ~= true and Presence.beforeGraphicsUpdate ~= nil then
    local originalBeforeGraphicsUpdate = Presence.beforeGraphicsUpdate

    function Presence:beforeGraphicsUpdate(instance, dt, ...)
        local graphics = instance ~= nil and instance.graphics or nil
        local preYaw = getRootYaw(graphics)

        -- Let Alpha 3 calculate idle/face targets, smooth the logical yaw and
        -- populate rotationVelocity. Its direct root rotation is immediately
        -- undone below before the native HumanGraphicsComponent update runs.
        originalBeforeGraphicsUpdate(self, instance, dt, ...)

        if instance == nil or graphics == nil then return end
        local currentYaw = tonumber(instance.presenceCurrentYaw)

        if graphics.setModelYaw ~= nil and currentYaw ~= nil then
            -- Remove the presence layer's direct root change, then use the same
            -- graphical-yaw API that PlayerOnFootStateMachine uses. Leave the
            -- calculated rotationVelocity intact so the conditional animation
            -- can select a natural turn-in-place motion.
            if preYaw ~= nil then restoreRootYaw(graphics, preYaw) end
            local ok = pcall(graphics.setModelYaw, graphics, currentYaw)
            if ok then
                instance._hpNativeModelYawActive = true
                return
            end
        end

        -- Defensive fallback for an unexpected runtime without setModelYaw:
        -- retain the already-smoothed root turn but neutralise the animation,
        -- matching the known-good presence-2 behaviour rather than jittering.
        setRotationVelocityNeutral(graphics)
        instance.presenceRotationVelocity = 0
        instance._hpNativeModelYawActive = false
    end

    Presence._hpNativeModelYawPatched = true
    Presence.version = HP_WorldPresenceSmoothing.version
    print(LOG .. "Loaded " .. tostring(HP_WorldPresenceSmoothing.version) .. " (native model-yaw turn path)")
end
