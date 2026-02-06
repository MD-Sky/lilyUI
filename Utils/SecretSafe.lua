local ADDON_NAME, ns = ...

local SecretSafe = ns.SecretSafe or {}
ns.SecretSafe = SecretSafe

local hasIsSecret = type(issecretvalue) == "function"
local hasScrub = type(scrubsecretvalues) == "function"

function SecretSafe.IsSecret(v)
    return hasIsSecret and issecretvalue(v) or false
end

-- Scrub a single value: secret -> nil, otherwise unchanged.
function SecretSafe.Scrub1(v)
    if hasScrub then
        return scrubsecretvalues(v)
    end
    if SecretSafe.IsSecret(v) then
        return nil
    end
    return v
end

function SecretSafe.IsNumber(v)
    return type(v) == "number"
end

-- Only return a usable number (never tonumber).
function SecretSafe.NumberOrNil(v)
    v = SecretSafe.Scrub1(v)
    if type(v) == "number" then
        return v
    end
    return nil
end

function SecretSafe.NumberOr(v, default)
    local n = SecretSafe.NumberOrNil(v)
    if n == nil then
        return default
    end
    return n
end

-- Safe key helper for one-time logs.
function SecretSafe.KeyOr(v, defaultKey)
    if type(v) == "number" then
        return v
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return defaultKey or "unknown"
end

-- Safe "once" logger: never formats or concatenates secret values.
local logged = {}
function SecretSafe.LogOnce(key, msg)
    key = SecretSafe.KeyOr(key, "unknown")
    if logged[key] then
        return
    end
    logged[key] = true
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

return SecretSafe
