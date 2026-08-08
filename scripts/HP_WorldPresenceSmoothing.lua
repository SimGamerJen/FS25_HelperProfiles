-- HP_WorldPresenceSmoothing.lua (FS25_HelperProfiles)
-- Alpha 3 hotfix: keep world-facing interpolation on the graphics root while
-- leaving the HumanGraphicsComponent turn-animation input neutral.
--
-- HumanGraphicsComponent:update() advances the conditional animation but does
-- not own/interpolate graphicsRootNode yaw. The Alpha 3 presence layer already
-- moves that root every frame, so also driving rotationVelocity can make the
-- turn-in-place animation visually fight the root transform and appear jittery.

if HP_WorldPresence == nil then return end
if HP_WorldPresenceSmoothing ~= nil then return end

HP_WorldPresenceSmoothing = {
    version = "2.2.0.0-alpha3-presence-2"
}

local Presence = HP_WorldPresence
local LOG = "[FS25_HelperProfiles/WorldPresence] "

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

if Presence._hpRootOnlySmoothingPatched ~= true and Presence.beforeGraphicsUpdate ~= nil then
    local originalBeforeGraphicsUpdate = Presence.beforeGraphicsUpdate

    function Presence:beforeGraphicsUpdate(instance, dt, ...)
        -- Retain Alpha 3 target selection, persistence and per-frame yaw
        -- interpolation, then neutralize the conditional turn-in-place input
        -- immediately before HumanGraphicsComponent:update() runs.
        originalBeforeGraphicsUpdate(self, instance, dt, ...)
        if instance ~= nil then
            setRotationVelocityNeutral(instance.graphics)
            instance.presenceRotationVelocity = 0
        end
    end

    Presence._hpRootOnlySmoothingPatched = true
    Presence.version = HP_WorldPresenceSmoothing.version
    print(LOG .. "Loaded " .. tostring(HP_WorldPresenceSmoothing.version) .. " (root-yaw smoothing; turn animation neutral)")
end
