--[[
    LilyUI Localization System
    Core loader that initializes AceLocale-3.0 and provides access to locale strings
--]]

local ADDON_NAME, ns = ...

local AceLocale = LibStub("AceLocale-3.0")

-- Pull the locale table registered by the concrete locale files (e.g. enUS.lua).
-- Use a safe fallback table so config pages never explode if locale registration fails.
local L = AceLocale:GetLocale(ADDON_NAME, true)
if not L then
    L = setmetatable({}, {
        __index = function(_, key)
            return tostring(key)
        end,
    })
end

-- Store the locale table in the namespace for access from other files
ns.L = L

-- Return the locale table for backwards compatibility
return L
