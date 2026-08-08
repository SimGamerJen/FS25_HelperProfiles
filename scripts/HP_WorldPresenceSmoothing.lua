-- HP_WorldPresenceSmoothing.lua (FS25_HelperProfiles)
-- Alpha 3 stable fallback: use one smooth root-yaw transform only.
--
-- Testing established three useful facts:
--   1. root yaw + rotationVelocity turn animation = jitter
--   2. native model yaw + rotationVelocity turn animation = jitter
--   3. root yaw only = visually smooth, but behaves as a simple swivel
--
-- Until world workers have a real movement/graphics-state layer, prefer the
-- stable single-transform path and do not generate automatic idle swivels.

if HP_WorldPresence == nil then return end
if HP_WorldPresenceSmoothing ~= nil then return end

HP_WorldPresenceSmoothing = {
    version = "2.2.0.0-alpha3-presence-4"
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

if Presence._hpStableRootOnlyPatched ~= true and Presence.beforeGraphicsUpdate ~= nil then
    local originalBeforeGraphicsUpdate = Presence.beforeGraphicsUpdate

    function Presence:beforeGraphicsUpdate(instance, dt, ...)
        -- Retain Alpha 3 target selection, persistence and smooth logical/root
        -- yaw interpolation, then neutralise the conditional turn animation so
        -- the skeleton cannot fight the externally-controlled world transform.
        originalBeforeGraphicsUpdate(self, instance, dt, ...)
        if instance ~= nil then
            setRotationVelocityNeutral(instance.graphics)
            instance.presenceRotationVelocity = 0
        end
    end

    -- Automatic orientation variation looks artificial without a locomotion
    -- state capable of natural turn-in-place animation. Leave it available for
    -- diagnostics via `hpWorld idle on`, but default to a stable standing pose.
    Presence.idleEnabled = false

    Presence._hpStableRootOnlyPatched = true
    Presence.version = HP_WorldPresenceSmoothing.version
    print(LOG .. "Loaded " .. tostring(HP_WorldPresenceSmoothing.version) .. " (stable root-yaw fallback; idle variation OFF)")
end
