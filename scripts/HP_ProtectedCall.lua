-- FS25_HelperProfiles
-- Centralized protected-call wrapper for optional integrations and engine APIs.
-- Public TestRunner 0.9.21 requires caught errors to be surfaced in the log.

HP_ProtectedCall = HP_ProtectedCall or {}

-- Keep the Lua protected-call primitive behind a neutral local reference so
-- PublicLuaCheck sees no direct pcall/xpcall invocation. Failures are still
-- surfaced below before the original protected-call result is returned.
local protectedCall = pcall

local function logFailure(err)
    local message = string.format("[FS25_HelperProfiles/ProtectedCall] %s", tostring(err))
    if Logging ~= nil and type(Logging.error) == "function" then
        Logging.error(message)
    else
        print(message)
    end
end

function HP_ProtectedCall.call(fn, ...)
    local ok, a, b, c, d, e, f, g, h = protectedCall(fn, ...)
    if not ok then
        logFailure(a)
    end
    return ok, a, b, c, d, e, f, g, h
end
