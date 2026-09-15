-- HP_HelperAcquisitionRouter.lua (FS25_HelperProfiles)
-- Reconciles HelperProfiles API v7 scoped preferred hires with AutoDrive V5
-- helper continuity.
--
-- Acquisition precedence:
--   1. Active API v7 scoped preferred hire (RemoteDispatcher / compatible mods)
--   2. Existing AutoDrive V5 continuity wrapper
--   3. Normal HelperProfiles / GIANTS helper selection
--
-- The router wraps the runtime g_helperManager instance after the underlying
-- HelperProfiles, AutoDrive and API hooks have had a chance to install. This
-- avoids class-vs-instance shadowing without changing the accepted API v7
-- contract or AutoDrive's proven continuity logic.

HP_HelperAcquisitionRouter = HP_HelperAcquisitionRouter or {
    installed = false,
    runtimeManager = nil,
    previousMethods = {},
    _lastWaitReason = nil,
    _lastWaitMs = -100000
}

local LOG = "[FS25_HelperProfiles/HelperRouter] "

local function log(message, ...)
    print(LOG .. string.format(tostring(message), ...))
end

local function nowMs()
    return tonumber(g_time) or 0
end

function HP_HelperAcquisitionRouter:_logWait(reason)
    local now = nowMs()
    reason = tostring(reason or "unknown")
    if self._lastWaitReason ~= reason or now - (tonumber(self._lastWaitMs) or 0) >= 10000 then
        self._lastWaitReason = reason
        self._lastWaitMs = now
        log("Waiting to install: %s", reason)
    end
end

function HP_HelperAcquisitionRouter:_resolveScopedHire(methodName)
    if HP_IntegrationAPI == nil or type(HP_IntegrationAPI.resolveScopedPreferredHelper) ~= "function" then
        return nil, nil, false
    end

    local ok, helper, reason, scoped = pcall(
        HP_IntegrationAPI.resolveScopedPreferredHelper,
        HP_IntegrationAPI
    )

    if not ok then
        log("Scoped hire resolution error in %s: %s", tostring(methodName), tostring(helper))
        return nil, "scoped-resolution-error", true
    end

    if scoped == true then
        if helper ~= nil then
            log(
                "%s -> '%s' (%s; precedence=scoped-hire)",
                tostring(methodName),
                tostring(helper.name or "?"),
                tostring(reason or "scoped")
            )
            return helper, reason, true
        end

        log("%s blocked (%s; precedence=scoped-hire)", tostring(methodName), tostring(reason or "scoped-unavailable"))
        return nil, reason, true
    end

    return nil, reason, false
end

function HP_HelperAcquisitionRouter:install()
    if self.installed then return true end

    if HelperProfiles == nil or HelperProfiles._hooksDone ~= true then
        self:_logWait("HelperProfiles helper hooks not ready")
        return false
    end

    if HP_IntegrationAPI == nil or type(HP_IntegrationAPI.resolveScopedPreferredHelper) ~= "function" then
        self:_logWait("HelperProfiles API v7 scoped-hire resolver unavailable")
        return false
    end

    if HP_AutoDriveContinuityV5 == nil or HP_AutoDriveContinuityV5.installed ~= true then
        self:_logWait("AutoDrive V5 continuity wrapper not ready")
        return false
    end

    local manager = g_helperManager
    if manager == nil then
        self:_logWait("g_helperManager unavailable")
        return false
    end

    local wrapped = 0
    self.runtimeManager = manager
    self.previousMethods = self.previousMethods or {}

    local function wrap(methodName)
        local previous = manager[methodName]
        if type(previous) ~= "function" then return false end

        self.previousMethods[methodName] = previous
        manager[methodName] = function(runtimeManager, ...)
            local helper, _, scoped = HP_HelperAcquisitionRouter:_resolveScopedHire(methodName)
            if scoped then
                return helper
            end
            return previous(runtimeManager, ...)
        end
        return true
    end

    if wrap("getNextHelper") then wrapped = wrapped + 1 end
    if wrap("getFreeHelper") then wrapped = wrapped + 1 end
    if wrap("getRandomHelper") then wrapped = wrapped + 1 end

    if wrapped <= 0 then
        self:_logWait("no helper acquisition methods available")
        return false
    end

    self.installed = true
    self._lastWaitReason = nil
    log(
        "Installed helper acquisition router (%d methods): scoped hire > AutoDrive continuity > normal HelperProfiles",
        wrapped
    )
    return true
end

function HP_HelperAcquisitionRouter:loadMap()
    self.installed = false
    self.runtimeManager = nil
    self.previousMethods = {}
    self._lastWaitReason = nil
    self._lastWaitMs = -100000
end

function HP_HelperAcquisitionRouter:update(dt)
    if HP_Compatibility ~= nil and HP_Compatibility:isBlocked() then return end
    if not self.installed then self:install() end
end

function HP_HelperAcquisitionRouter:deleteMap()
    self.installed = false
    self.runtimeManager = nil
    self.previousMethods = {}
end

addModEventListener(HP_HelperAcquisitionRouter)
