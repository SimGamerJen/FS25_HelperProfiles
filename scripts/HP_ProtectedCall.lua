-- FS25_HelperProfiles
-- Centralized protected-call wrapper for optional integrations and engine APIs.
-- Public TestRunner 0.9.21 requires caught errors to be surfaced in the log.

HP_ProtectedCall = HP_ProtectedCall or {}

local function logFailure(err)
    local message = string.format("[FS25_HelperProfiles/ProtectedCall] %s", tostring(err))
    if Logging ~= nil and type(Logging.error) == "function" then
        Logging.error(message)
    else
        print(message)
    end
end

function HP_ProtectedCall.call(fn, ...)
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if not ok then
        logFailure(a)
    end
    return ok, a, b, c, d, e, f, g, h
end
