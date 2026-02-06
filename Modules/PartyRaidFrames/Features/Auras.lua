--[[
    LilyUI Unit Frames - Aura Display System
    Handles buff/debuff display with enhanced filtering
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames
local SpellProvider = ns.SpellProvider or (LilyUI and LilyUI.SpellProvider)
local SecretSafe = ns.SecretSafe or {}

-- Cache commonly used API
local ForEachAura = AuraUtil and AuraUtil.ForEachAura
local UnitClass = UnitClass
local GetTime = GetTime
local CreateFrame = CreateFrame
local UnitAffectingCombat = UnitAffectingCombat
local IsInRaid = IsInRaid
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local unpack = unpack or table.unpack

-- Aura cache for Blizzard filtering
local blizzardAuraCache = {}
local GetAuraDataByInstanceID

-- ============================================================================
-- SAFE VALUE HELPERS (avoid "secret value" errors from protected aura tables)
-- ============================================================================

local function SafeToNumber(v, default)
    if v == nil or type(SecretSafe.NumberOrNil) ~= "function" then
        return default
    end
    local n = SecretSafe.NumberOrNil(v)
    if n == nil then
        return default
    end
    return n
end

local function SafeCompare(a, b)
    local na = SafeToNumber(a, 0) or 0
    local nb = SafeToNumber(b, 0) or 0
    if na < nb then return -1 end
    if na > nb then return 1 end
    return 0
end

local function LilyPlainNumber(v)
    return SafeToNumber(v, nil)
end

local function SafeBool(v)
    local t = type(v)
    if t == "nil" or t == "userdata" then return false end
    if t == "boolean" then
        -- Coerce to a plain Lua boolean (avoid returning a protected "secret value").
        local ok, coerced = pcall(function() return v and true or false end)
        if ok then return coerced end
        return false
    end
    return true
end

local function AuraDebugCoerce(label, value, fallback)
    if not UnitFrames or not UnitFrames.devMode then return end
    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("CombatAuras", "Auras: coerced %s (%s)", label or "?", type(value))
    elseif UnitFrames.DebugPrint then
        UnitFrames:DebugPrint("Auras: coerced " .. (label or "?") .. " (" .. type(value) .. ")")
    end
end

local TrySafeNumber

local function SafeNumberOrNil(v, label)
    local n = TrySafeNumber(v)
    if n ~= nil then return n end
    if label then
        AuraDebugCoerce(label, v, nil)
    end
    return nil
end

local function SafeNumber(v, default, label)
    local n = TrySafeNumber(v)
    if n ~= nil then
        return n
    end
    if label and v ~= nil then
        AuraDebugCoerce(label, v, default)
    end
    return default
end

local function SafeString(v, default)
    local t = type(v)
    if t == "string" then return v end
    return default
end

local function SafeRevealString(v)
    if type(v) ~= "string" or v == "" or v == "<no value>" then
        return nil
    end
    return v
end

TrySafeNumber = function(v)
    return SafeToNumber(v, nil)
end

local function SafePositiveNumber(v)
    local n = TrySafeNumber(v)
    if not n then
        return nil
    end
    local ok, isPositive = pcall(function() return n > 0 end)
    if not ok or not isPositive then
        return nil
    end
    return n
end

local function SafeAuraField(auraData, key)
    if type(auraData) ~= "table" then
        return nil
    end
    local ok, value = pcall(function()
        return auraData[key]
    end)
    if not ok then
        return nil
    end
    return value
end

local function SafeSourceUnitString(v)
    if type(v) == "string" then
        local scrubbed = type(SecretSafe.Scrub1) == "function" and SecretSafe.Scrub1(v) or v
        if type(scrubbed) == "string" then
            return scrubbed
        end
    end
    return ""
end

local function SafeSpellKey(spellId)
    if spellId == nil then
        return nil
    end

    if type(spellId) == "number" then
        local safeId = SafePositiveNumber(spellId)
        if safeId then
            return tostring(floor(safeId))
        end
        return nil
    end

    if type(spellId) ~= "string" then
        return nil
    end

    local trimmed = spellId:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" or trimmed == "<no value>" then
        return nil
    end

    local linkId = trimmed:match("Hspell:(%d+)") or trimmed:match("spell:(%d+)")
    if linkId then
        return linkId
    end

    local digits = trimmed:match("^(%d+)$")
    if digits then
        return digits
    end

    return nil
end

local function ExtractSafeSpellIdAndKey(auraData)
    local rawSpellId = SafeAuraField(auraData, "spellId")
    local spellIdKey = "spellId"
    if rawSpellId == nil then
        rawSpellId = SafeAuraField(auraData, "spellID")
        spellIdKey = "spellID"
    end

    local safeSpellId = LilyPlainNumber(rawSpellId)
    if safeSpellId then
        safeSpellId = floor(safeSpellId)
        if safeSpellId <= 0 then
            safeSpellId = nil
        end
    end

    local safeSpellKey = safeSpellId and tostring(safeSpellId) or nil
    return safeSpellId, safeSpellKey, rawSpellId, spellIdKey
end

local function SafeGetSpellIdRaw(auraData)
    if type(auraData) ~= "table" then
        return nil, "none"
    end

    local okLower, lower = pcall(function()
        return auraData["spellId"]
    end)
    if okLower and lower ~= nil then
        return lower, "spellId"
    end

    local okLegacy, legacy = pcall(function()
        return auraData["spellID"]
    end)
    if okLegacy and legacy ~= nil then
        return legacy, "spellID"
    end

    return nil, "none"
end

local function BuildCombatSpellKeySet(list)
    local set = {}
    if type(list) ~= "table" then
        return set
    end

    local function addId(id)
        local key = SafeSpellKey(id)
        if key then
            set[key] = true
        end
    end

    for _, id in ipairs(list) do
        addId(id)
    end

    for k, v in pairs(list) do
        if v == true then
            addId(k)
        elseif type(v) == "number" or type(v) == "string" then
            addId(v)
        end
    end

    return set
end

local function NormalizeCombatSpellListInPlace(list)
    if type(list) ~= "table" then
        return
    end

    local normalized = BuildCombatSpellKeySet(list)
    for k in pairs(list) do
        list[k] = nil
    end
    for key in pairs(normalized) do
        list[key] = true
    end
end

local function CombatSpellListNeedsNormalization(list)
    if type(list) ~= "table" then
        return false
    end
    for k, v in pairs(list) do
        if v ~= true then
            return true
        end
        if type(k) ~= "string" then
            return true
        end
        local normalizedKey = SafeSpellKey(k)
        if not normalizedKey or normalizedKey ~= k then
            return true
        end
    end
    return false
end

local function SafeCombatListContainsSpellId(spellId, spellKeySet)
    local meta = {
        setLookupErrored = false,
        usedEqualityFallback = false,
        spellKey = nil,
    }

    if spellId == nil then
        return false, meta
    end

    meta.spellKey = SafeSpellKey(spellId)
    if not meta.spellKey then
        return false, meta
    end

    local okSet, setValue = pcall(function()
        return spellKeySet and spellKeySet[meta.spellKey]
    end)
    if okSet then
        return setValue and true or false, meta
    end

    meta.setLookupErrored = true
    return false, meta
end

-- ============================================================================
-- AURA DEBUG HELPERS (toggle via devMode or combatAuraDebugEnabled)
-- ============================================================================

UnitFrames._auraDebugLast = UnitFrames._auraDebugLast or {}
UnitFrames._auraDebugThrottle = UnitFrames._auraDebugThrottle or 0.5
UnitFrames._auraInvalidFieldSeen = UnitFrames._auraInvalidFieldSeen or {}

local function AuraDebugEnabled(db)
    if UnitFrames and UnitFrames.devMode then
        return true
    end
    if db and db.combatAuraDebugEnabled then
        return true
    end
    return false
end

function UnitFrames:LogAuraDebug(db, key, msg, throttle)
    if not AuraDebugEnabled(db) then return end
    local now = GetTime and GetTime() or 0
    local t = throttle or self._auraDebugThrottle or 0.5
    if key then
        local last = self._auraDebugLast[key] or 0
        if (now - last) < t then return end
        self._auraDebugLast[key] = now
    end
    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("CombatAuras", "%s", msg)
    elseif self.DebugPrint then
        self:DebugPrint(msg)
    end
end

function UnitFrames:LogAuraInvalidFieldOnce(db, unit, auraType, auraData, fieldName, rawValue)
    if not self:IsPlayerInCombat() then return end
    if not auraData then return end

    local spellKey = SafeSpellKey(auraData.spellId) or tostring(auraData.spellId or "nil")
    local key = table.concat({
        "invalidfield",
        tostring(spellKey),
        tostring(fieldName or "?"),
    }, ":")
    if self._auraInvalidFieldSeen[key] then
        return
    end
    self._auraInvalidFieldSeen[key] = true

    self:LogAuraDebug(db, key, string.format(
        "[CombatAuras][FieldInvalid] unit=%s type=%s spellID=%s field=%s rawType=%s (no timer)",
        tostring(unit or "?"),
        tostring(auraType or "?"),
        tostring(spellKey),
        tostring(fieldName or "?"),
        tostring(type(rawValue))
    ), 0)
end

local function AuraDebugOutput(msg, ...)
    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("CombatAuras", msg, ...)
        return
    end
    if UnitFrames and UnitFrames.DebugPrint then
        if select("#", ...) > 0 then
            local ok, out = pcall(string.format, msg, ...)
            if ok then
                UnitFrames:DebugPrint(out)
                return
            end
        end
        UnitFrames:DebugPrint(tostring(msg))
    end
end

-- Party aura update debug (logs to /lilydebug only)
UnitFrames._partyAuraUpdateLogLast = UnitFrames._partyAuraUpdateLogLast or {}
UnitFrames._partyAuraUpdateThrottle = UnitFrames._partyAuraUpdateThrottle or 0.75

function UnitFrames:LogPartyAuraUpdate(unit, auraType, icons, shownCount)
    if not (LilyUI and LilyUI.DebugWindowLog) then return end

    local now = GetTime and GetTime() or 0
    local key = tostring(unit or "?") .. ":" .. tostring(auraType or "?")
    local last = self._partyAuraUpdateLogLast[key] or 0
    local throttle = self._partyAuraUpdateThrottle or 0.75
    if (now - last) < throttle then return end
    self._partyAuraUpdateLogLast[key] = now

    LilyUI:DebugWindowLog("CombatAuras", "[PartyAuras] unit=%s auraType=%s shown=%s",
        tostring(unit or "?"),
        tostring(auraType or "?"),
        tostring(shownCount or 0))

    local maxIcons = math.min(2, shownCount or 0)
    for i = 1, maxIcons do
        local icon = icons and icons[i]
        if icon then
            local expTime = icon._expTime
            local cooldownShown = icon.cooldown and icon.cooldown.IsShown and icon.cooldown:IsShown() or false
            local textShown = icon.duration and icon.duration.IsShown and icon.duration:IsShown() or false
            LilyUI:DebugWindowLog("CombatAuras",
                "[PartyAuras] #%d spellID=%s duration=%s expTime=%s remaining=%s cooldownShown=%s textShown=%s",
                i,
                tostring(icon.spellId or "nil"),
                tostring(icon._duration or "nil"),
                tostring(expTime or "nil"),
                "n/a",
                tostring(cooldownShown),
                tostring(textShown))
        end
    end
end

local lastAuraKeyDump = 0
local function DumpAuraDataKeys(auraData)
    if type(auraData) ~= "table" then return end
    local now = GetTime and GetTime() or 0
    if now - lastAuraKeyDump < 2 then return end
    lastAuraKeyDump = now

    local keys = {}
    for k, v in pairs(auraData) do
        keys[#keys + 1] = tostring(k) .. ":" .. type(v)
    end
    table.sort(keys)
    local msg = "AuraData keys (spellId nil): " .. table.concat(keys, ", ")
    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("CombatAuras", "%s", msg)
    elseif UnitFrames and UnitFrames.DebugPrint then
        UnitFrames:DebugPrint(msg)
    else
        print("|cff00ccff[LilyUI]|r " .. msg)
    end
end

local function SanitizeAuraData(auraData)
    if type(auraData) ~= "table" then return nil end

    local safeSpellId, safeSpellKey, rawSpellId, spellIdKey = ExtractSafeSpellIdAndKey(auraData)
    local safeName = SafeString(SafeAuraField(auraData, "name"), "")
    if not safeSpellId and safeName ~= "" and GetSpellInfo then
        local _, _, _, _, _, _, fallbackId = GetSpellInfo(safeName)
        local fallbackNum = TrySafeNumber(fallbackId)
        if fallbackNum and fallbackNum > 0 then
            safeSpellId = floor(fallbackNum)
            safeSpellKey = tostring(safeSpellId)
            rawSpellId = fallbackId
            spellIdKey = "fallbackSpellId"
        end
    end
    if not safeSpellId then
        DumpAuraDataKeys(auraData)
    end

    local rawDuration = SafeAuraField(auraData, "duration")
    if rawDuration == nil then
        rawDuration = SafeAuraField(auraData, "durationSeconds")
    end
    local parsedDuration = TrySafeNumber(rawDuration)
    local safeDuration = parsedDuration or 0
    local durationInvalid = rawDuration ~= nil and parsedDuration == nil

    local rawExpiration = SafeAuraField(auraData, "expirationTime")
    if rawExpiration == nil then
        rawExpiration = SafeAuraField(auraData, "expTime")
    end
    local parsedExpiration = TrySafeNumber(rawExpiration)
    local safeExpiration = parsedExpiration or 0
    local expirationInvalid = rawExpiration ~= nil and parsedExpiration == nil

    local rawApplications = SafeAuraField(auraData, "applications")
    if rawApplications == nil then
        rawApplications = SafeAuraField(auraData, "stacks")
    end
    local safeApplications = TrySafeNumber(rawApplications) or 0

    local safeAuraInstanceID = TrySafeNumber(SafeAuraField(auraData, "auraInstanceID"))
    if safeAuraInstanceID then
        safeAuraInstanceID = floor(safeAuraInstanceID)
    end
    local safeSourceUnit = SafeSourceUnitString(SafeAuraField(auraData, "sourceUnit") or SafeAuraField(auraData, "source"))
    local safeIcon = SafeAuraField(auraData, "icon")

    return {
        auraInstanceID = safeAuraInstanceID,
        spellId        = safeSpellId,
        spellKey       = safeSpellKey,
        spellIdRaw     = rawSpellId,
        name           = safeName,
        icon           = (type(safeIcon) == "number" or type(safeIcon) == "string") and safeIcon or nil,
        applications   = safeApplications,
        duration       = safeDuration,
        expirationTime = safeExpiration,
        sourceUnit     = safeSourceUnit,
        dispelName     = SafeString(SafeAuraField(auraData, "dispelName"), ""),
        isBossAura     = SafeBool(SafeAuraField(auraData, "isBossAura")),
        isHelpful      = SafeBool(SafeAuraField(auraData, "isHelpful")),
        isHarmful      = SafeBool(SafeAuraField(auraData, "isHarmful")),
        _durationInvalid = durationInvalid,
        _expirationInvalid = expirationInvalid,
        _durationRaw = rawDuration,
        _expirationRaw = rawExpiration,
        _spellIdKey    = spellIdKey, -- Debug-only key source marker.
    }
end

local function GetAuraDurationObject(unit, auraInstanceID)
    if not unit or not auraInstanceID or not C_UnitAuras then return nil end
    if C_UnitAuras.GetAuraDuration then
        local ok, obj = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
        if ok and obj then
            return obj
        end
    end
    if C_UnitAuras.GetUnitAuraDuration then
        local ok, obj = pcall(C_UnitAuras.GetUnitAuraDuration, unit, auraInstanceID)
        if ok and obj then
            return obj
        end
    end
    return nil
end

local function ResolveDurationFromObject(durationObj)
    if not durationObj then return nil, nil end
    local okE, elapsed = pcall(durationObj.GetElapsedDuration, durationObj)
    local okR, remaining = pcall(durationObj.GetRemainingDuration, durationObj)
    if not (okE and okR and elapsed and remaining) then
        return nil, nil
    end
    local safeElapsed = TrySafeNumber(elapsed)
    local safeRemaining = SafePositiveNumber(remaining)
    if not safeElapsed or not safeRemaining then
        return nil, nil
    end
    local total = TrySafeNumber(safeElapsed + safeRemaining)
    local safeTotal = SafePositiveNumber(total)
    if safeTotal then
        local now = GetTime and GetTime() or 0
        local expTime = TrySafeNumber(now + safeRemaining)
        local safeExp = SafePositiveNumber(expTime)
        if safeExp then
            return safeTotal, safeExp
        end
    end
    return nil, nil
end

-- ============================================================================
-- SHARED DURATION UPDATER (throttled, combat-safe)
-- ============================================================================

local AURA_DURATION_TICK = 0.1

function UnitFrames:_EnsureAuraDurationUpdater()
    if self._auraDurationUpdater then return end

    self._auraDurationIcons = {}
    self._auraDurationActive = 0
    self._auraDurationElapsed = 0

    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:SetScript("OnUpdate", function(_, elapsed)
        UnitFrames:_OnAuraDurationUpdate(elapsed)
    end)

    self._auraDurationUpdater = f
end

function UnitFrames:_RegisterAuraDurationIcon(icon)
    if not icon then return end
    self:_EnsureAuraDurationUpdater()
    if icon._usesDurationObject then
        self:_UnregisterAuraDurationIcon(icon)
        return
    end

    local expTime = SafePositiveNumber(icon._expTime)
    local duration = SafePositiveNumber(icon._duration)
    if expTime and duration then
        if not self._auraDurationIcons[icon] then
            self._auraDurationIcons[icon] = true
            self._auraDurationActive = self._auraDurationActive + 1
        end
        self._auraDurationUpdater:Show()
    elseif self:IsPlayerInCombat() and icon.auraInstanceID then
        icon._needsTimingRefresh = true
        icon._timingRefreshAttempts = icon._timingRefreshAttempts or 0
        if not self._auraDurationIcons[icon] then
            self._auraDurationIcons[icon] = true
            self._auraDurationActive = self._auraDurationActive + 1
        end
        self._auraDurationUpdater:Show()
    else
        self:_UnregisterAuraDurationIcon(icon)
    end
end

function UnitFrames:_UnregisterAuraDurationIcon(icon)
    local icons = self._auraDurationIcons
    if icons and icons[icon] then
        icons[icon] = nil
        self._auraDurationActive = self._auraDurationActive - 1
        if self._auraDurationActive <= 0 and self._auraDurationUpdater then
            self._auraDurationUpdater:Hide()
        end
    end
end

function UnitFrames:_RefreshAuraTiming(icon)
    if not icon or not icon.auraInstanceID then return false end
    local unit = icon.unit or (icon.unitFrame and icon.unitFrame.unit)
    if not unit then return false end

    local durationObj = GetAuraDurationObject(unit, icon.auraInstanceID)
    if durationObj then
        local total, expTime = ResolveDurationFromObject(durationObj)
        if total and expTime then
            icon._duration = total
            icon._expTime = expTime
            icon.auraDuration = total
            icon.auraExpiration = expTime
            icon.expirationTime = expTime
            icon._needsTimingRefresh = false
            icon._timingRefreshAttempts = 0
            return true
        end
    end

    local data = GetAuraDataByInstanceID(unit, icon.auraInstanceID)
    if not data then
        return false
    end
    local safe = SanitizeAuraData(data)
    if not safe then return false end
    local dur = SafePositiveNumber(safe.duration)
    local exp = SafePositiveNumber(safe.expirationTime)
    if dur and exp then
        icon._duration = dur
        icon._expTime = exp
        icon.auraDuration = dur
        icon.auraExpiration = exp
        icon.expirationTime = exp
        icon._needsTimingRefresh = false
        icon._timingRefreshAttempts = 0
        return true
    end
    return false
end

function UnitFrames:_OnAuraDurationUpdate(elapsed)
    local icons = self._auraDurationIcons
    if not icons then return end

    self._auraDurationElapsed = (self._auraDurationElapsed or 0) + elapsed
    if self._auraDurationElapsed < AURA_DURATION_TICK then return end
    self._auraDurationElapsed = 0

    local now = GetTime()
    for icon in pairs(icons) do
        if not self:_UpdateAuraDurationForIcon(icon, now) then
            icons[icon] = nil
            self._auraDurationActive = self._auraDurationActive - 1
        end
    end

    if self._auraDurationActive <= 0 and self._auraDurationUpdater then
        self._auraDurationUpdater:Hide()
    end
end

function UnitFrames:_UpdateAuraDurationForIcon(icon, now)
    -- Duration updates are driven directly by cooldown widgets via DurationObject.
    -- Keep the legacy updater inert to avoid time arithmetic on aura timing fields.
    return false
end


-- Dispellable debuff types by class
local DispellableByClass = {
    PALADIN = {Magic = true, Disease = true, Poison = true},
    PRIEST = {Magic = true, Disease = true},
    DRUID = {Magic = true, Curse = true, Poison = true},
    SHAMAN = {Magic = true, Curse = true, Poison = true},
    MONK = {Magic = true, Disease = true, Poison = true},
    MAGE = {Curse = true},
    EVOKER = {Magic = true, Poison = true},
}

-- Known boss debuffs (simplified list - normally would be more comprehensive)
local BossDebuffs = {}

-- ============================================================================
-- BLIZZARD AURA HOOK
-- ============================================================================

--[[
    Hook Blizzard's CompactUnitFrame_UpdateAuras to capture filtering decisions
    This allows us to replicate Blizzard's aura filtering logic
]]
local function SetupBlizzardAuraHook()
    if not CompactUnitFrame_UpdateAuras then return end
    
    hooksecurefunc("CompactUnitFrame_UpdateAuras", function(blizzFrame)
        if not blizzFrame or not blizzFrame.unit then return end
        
        local unit = blizzFrame.unit
        local cache = blizzardAuraCache[unit] or {
            buffs = {},
            debuffs = {},
            dispellable = {},
            defensive = nil,
        }
        
        -- Reset cache
        wipe(cache.buffs)
        wipe(cache.debuffs)
        wipe(cache.dispellable)
        cache.defensive = nil
        
        -- Capture displayed buffs
        if blizzFrame.buffFrames then
            for i, buffFrame in ipairs(blizzFrame.buffFrames) do
                if buffFrame:IsShown() and buffFrame.auraInstanceID then
                    cache.buffs[buffFrame.auraInstanceID] = true
                end
            end
        end
        
        -- Capture displayed debuffs
        if blizzFrame.debuffFrames then
            for i, debuffFrame in ipairs(blizzFrame.debuffFrames) do
                if debuffFrame:IsShown() and debuffFrame.auraInstanceID then
                    cache.debuffs[debuffFrame.auraInstanceID] = true
                    
                    -- Check if dispellable
                    if debuffFrame.isBossAura or debuffFrame.isDispellable then
                        cache.dispellable[debuffFrame.auraInstanceID] = true
                    end
                end
            end
        end
        
        -- Store cache
        blizzardAuraCache[unit] = cache
    end)
end

-- Initialize hook
C_Timer.After(0.5, SetupBlizzardAuraHook)

-- ============================================================================
-- AURA FILTERING
-- ============================================================================

local FILTER_MODES = {
    BLIZZARD = "blizzard",
    SMART = "smart",
    WHITELIST = "whitelist",
    BLACKLIST = "blacklist",
    ALL = "all",
}

UnitFrames.FILTER_MODES = FILTER_MODES

-- TEMPORARY DEBUG MODE:
-- Keep all party/raid auras visible while combat filtering is being reworked.
local FORCE_SHOW_ALL_AURAS = true

-- ============================================================================
-- COMBAT FILTERING / DISPLAY
-- ============================================================================

UnitFrames._combatState = UnitFrames._combatState or (UnitAffectingCombat and UnitAffectingCombat("player") or false)

function UnitFrames:IsPlayerInCombat()
    if UnitAffectingCombat then
        return UnitAffectingCombat("player")
    end
    return self._combatState == true
end

function UnitFrames:IsCombatFilterActive(db, auraType)
    if not db or not db.combatFilterEnabled then return false end
    local mode = db.combatFilterMode or "NONE"
    if mode == "NONE" then return false end
    local appliesTo = db.combatFilterAppliesTo or "BOTH"
    if appliesTo == "BUFFS" and auraType ~= "BUFF" then return false end
    if appliesTo == "DEBUFFS" and auraType ~= "DEBUFF" then return false end
    return self:IsPlayerInCombat()
end

function UnitFrames:IsSpellIdInCombatList(list, spellId, spellKeySet)
    local lookupSet = spellKeySet
    if type(lookupSet) ~= "table" then
        lookupSet = BuildCombatSpellKeySet(list)
    end

    local okLookup, inList = pcall(SafeCombatListContainsSpellId, spellId, lookupSet)
    if not okLookup then
        return false
    end
    return inList and true or false
end

local function EnsureCombatLists(db)
    if not db then return end
    if type(db.combatWhitelistSpellList) ~= "table" then
        db.combatWhitelistSpellList = {}
    end
    if type(db.combatBlacklistSpellList) ~= "table" then
        db.combatBlacklistSpellList = {}
    end

    if CombatSpellListNeedsNormalization(db.combatWhitelistSpellList) then
        NormalizeCombatSpellListInPlace(db.combatWhitelistSpellList)
    end
    if CombatSpellListNeedsNormalization(db.combatBlacklistSpellList) then
        NormalizeCombatSpellListInPlace(db.combatBlacklistSpellList)
    end

    if db._combatListMigrated then
        return
    end

    local oldBuff = db.combatBuffSpellList
    local oldDebuff = db.combatDebuffSpellList
    local oldHas = (type(oldBuff) == "table" and next(oldBuff) ~= nil) or (type(oldDebuff) == "table" and next(oldDebuff) ~= nil)
    if oldHas then
        local mode = db.combatFilterMode or "NONE"
        local targetKey = nil
        if mode == "WHITELIST" and (not next(db.combatWhitelistSpellList)) then
            targetKey = "combatWhitelistSpellList"
        elseif mode == "BLACKLIST" and (not next(db.combatBlacklistSpellList)) then
            targetKey = "combatBlacklistSpellList"
        end
        if targetKey then
            local dest = db[targetKey]
            if type(dest) ~= "table" then
                dest = {}
                db[targetKey] = dest
            end
            local function copy(src)
                if type(src) ~= "table" then return end
                for k, v in pairs(src) do
                    local id
                    if type(k) == "number" and v == true then
                        id = k
                    elseif type(v) == "number" then
                        id = v
                    elseif type(v) == "string" then
                        id = SafeToNumber(v, nil)
                    end
                    if id then
                        dest[tostring(floor(id))] = true
                    end
                end
            end
            copy(oldBuff)
            copy(oldDebuff)
            if LilyUI and LilyUI.DebugWindowLog then
                LilyUI:DebugWindowLog("System", "[Migration] Copied combat %s list from legacy buff/debuff lists", mode:lower())
            end
        end
    end

    db._combatListMigrated = true
end

local function BuildCombatFilterLookupContext(self, db, auraType, inCombat)
    local context = {
        inCombat = inCombat == true,
        combatEnabled = db and db.combatFilterEnabled == true or false,
        mode = db and (db.combatFilterMode or "NONE") or "NONE",
        appliesTo = db and (db.combatFilterAppliesTo or "BOTH") or "BOTH",
        listKey = "none",
        list = nil,
        listEmpty = true,
        listSet = {},
    }

    if not context.combatEnabled or not context.inCombat then
        return context
    end
    if context.mode ~= "WHITELIST" and context.mode ~= "BLACKLIST" then
        return context
    end
    if context.appliesTo == "BUFFS" and auraType ~= "BUFF" then
        return context
    end
    if context.appliesTo == "DEBUFFS" and auraType ~= "DEBUFF" then
        return context
    end

    EnsureCombatLists(db)

    context.listKey = context.mode == "WHITELIST" and "combatWhitelistSpellList" or "combatBlacklistSpellList"
    context.list = db and db[context.listKey] or nil
    context.listEmpty = (type(context.list) ~= "table" or next(context.list) == nil)
    context.listSet = BuildCombatSpellKeySet(context.list)
    return context
end

function UnitFrames:EnsureCombatLists(db)
    EnsureCombatLists(db)
end

function UnitFrames:CombatFilterAllowsAura(auraData, auraType, db)
    if FORCE_SHOW_ALL_AURAS then
        return true
    end
    db = db or self:GetDB()
    local inCombat = self:IsPlayerInCombat()
    local context = BuildCombatFilterLookupContext(self, db, auraType, inCombat)
    if not context.combatEnabled or not context.inCombat then
        return true
    end
    local allowed = true
    local ok, result = pcall(self.GetCombatFilterDecision, self, auraData, auraType, db, context)
    if ok then
        allowed = result and true or false
    end
    return allowed
end

function UnitFrames:GetCombatFilterDecision(auraData, auraType, db, combatContext)
    if FORCE_SHOW_ALL_AURAS then
        return true, "forced show all"
    end
    db = db or self:GetDB()
    local inCombat = self:IsPlayerInCombat()
    local context = combatContext
    if type(context) ~= "table" then
        context = BuildCombatFilterLookupContext(self, db, auraType, inCombat)
    end

    local enabled = context.combatEnabled
    local mode = context.mode
    local appliesTo = context.appliesTo

    if not enabled then
        return true, "combat filter disabled"
    end
    if mode == "NONE" then
        return true, "filter mode none"
    end
    if appliesTo == "BUFFS" and auraType ~= "BUFF" then
        return true, "filter applies to buffs only"
    end
    if appliesTo == "DEBUFFS" and auraType ~= "DEBUFF" then
        return true, "filter applies to debuffs only"
    end

    local listEmpty = context.listEmpty == true
    local listSet = context.listSet or {}
    local safeSpellId = LilyPlainNumber(auraData and auraData.spellId)
    if safeSpellId then
        safeSpellId = floor(safeSpellId)
        if safeSpellId <= 0 then
            safeSpellId = nil
        end
    end
    local spellKey = (auraData and auraData.spellKey) or (safeSpellId and tostring(safeSpellId)) or nil

    if mode == "WHITELIST" then
        if listEmpty then
            return true, "whitelist empty (fail-open)"
        end

        if not spellKey then
            if inCombat then
                return false, "spellId missing (combat whitelist block)"
            end
            return true, "spellId missing (fail-open)"
        end

        local lookupOk, lookupHit = pcall(function()
            return listSet[spellKey] == true
        end)
        if not lookupOk then
            return false, "filter whitelist lookup error"
        end
        local inList = lookupHit and true or false
        return inList, inList and "filter whitelist hit" or "filter whitelist miss"
    end

    if not spellKey then
        return true, "spellId missing (fail-open)"
    end

    local lookupOk, lookupHit = pcall(function()
        return listSet[spellKey] == true
    end)
    if not lookupOk then
        return true, "filter blacklist lookup error (fail-open)"
    end
    local inList = lookupHit and true or false

    if mode == "BLACKLIST" then
        return not inList, inList and "filter blacklist hit" or "filter blacklist miss"
    end

    return true, "filter mode none"
end

function UnitFrames:GetCombatDisplayMode(db)
    local mode = (db and db.combatDisplayMode) or "BOTH"
    if mode ~= "TEXT" and mode ~= "SWIPE" and mode ~= "BOTH" then
        mode = "BOTH"
    end
    return mode
end

function UnitFrames:GetAuraDisplayFlags(db)
    if self:IsPlayerInCombat() then
        local mode = self:GetCombatDisplayMode(db)
        if mode == "TEXT" then
            return true, false
        elseif mode == "SWIPE" then
            return false, true
        end
        return true, true
    end
    local showText = db and (db.auraDurationEnabled ~= false) or true
    return showText, true
end

-- ============================================================================
-- COMBAT AURA DEBUG
-- ============================================================================

UnitFrames._combatAuraDebugLast = UnitFrames._combatAuraDebugLast or {}
UnitFrames._combatAuraDebugThrottle = 0.75

function UnitFrames:ShouldDebugCombatAura(spellId, db)
    if not db or not db.combatAuraDebugEnabled then return false end
    if not self:IsPlayerInCombat() then return false end
    local filterKey = SafeSpellKey(db.combatAuraDebugSpellId)
    if filterKey then
        local spellKey = SafeSpellKey(spellId)
        if spellKey ~= filterKey then
            return false
        end
    end
    return true
end

function UnitFrames:LogCombatAura(db, auraType, spellId, duration, expTime, decision, reason, showText, showSwipe)
    if not self:ShouldDebugCombatAura(spellId, db) then return end

    local now = GetTime()
    local spellKey = SafeSpellKey(spellId) or "nil"
    local key = spellKey
    local last = self._combatAuraDebugLast[key] or 0
    local throttle = self._combatAuraDebugThrottle or 0.75
    if (now - last) < throttle then return end
    self._combatAuraDebugLast[key] = now

    local spellName = "?"
    local numericSpellId = SafeToNumber(spellKey, nil)
    if numericSpellId and GetSpellInfo then
        spellName = GetSpellInfo(numericSpellId) or "?"
    end
    local safeExpTime = SafePositiveNumber(expTime)
    local remaining = safeExpTime and (safeExpTime - now) or nil

    local filterEnabled = db and db.combatFilterEnabled
    local filterMode = db and db.combatFilterMode or "NONE"
    local appliesTo = db and db.combatFilterAppliesTo or "BOTH"
    local displayMode = self:GetCombatDisplayMode(db)
    EnsureCombatLists(db)
    local listKey = (filterMode == "WHITELIST") and "combatWhitelistSpellList"
        or (filterMode == "BLACKLIST" and "combatBlacklistSpellList" or "none")
    local list = (listKey ~= "none" and db and db[listKey]) or nil
    local listEmpty = (listKey == "none") and true or (type(list) ~= "table" or next(list) == nil)

    local msg = string.format(
        "combat=%s | type=%s | spell=%s (%s) | filter=%s/%s/%s | list=%s empty=%s | display=%s | dur=%s exp=%s rem=%s | decision=%s (%s) | text=%s swipe=%s",
        tostring(self:IsPlayerInCombat()),
        tostring(auraType or "?"),
        tostring(spellName),
        tostring(spellKey),
        tostring(filterEnabled),
        tostring(filterMode),
        tostring(appliesTo),
        tostring(listKey),
        tostring(listEmpty),
        tostring(displayMode),
        tostring(duration or "nil"),
        tostring(expTime or "nil"),
        remaining and string.format("%.1f", remaining) or "nil",
        tostring(decision or "UNKNOWN"),
        tostring(reason or "n/a"),
        tostring(showText),
        tostring(showSwipe)
    )

    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("CombatAuras", "%s", msg)
    elseif self.DebugPrint then
        self:DebugPrint(msg)
    end
end

function UnitFrames:LogCombatFilterReject(db, unit, auraType, auraData, reason)
    if not AuraDebugEnabled(db) then return end
    if not self:IsPlayerInCombat() then return end

    local safeSpellId = LilyPlainNumber(auraData and auraData.spellId)
    if safeSpellId then
        safeSpellId = floor(safeSpellId)
        if safeSpellId <= 0 then
            safeSpellId = nil
        end
    end

    local safeName = SafeString(auraData and auraData.name, "")
    local safeDuration = TrySafeNumber(auraData and auraData.duration) or 0
    local safeExpiration = TrySafeNumber(auraData and auraData.expirationTime) or 0
    local rejectKey = table.concat({
        "combatreject",
        tostring(unit or "?"),
        tostring(auraType or "?"),
        tostring(safeSpellId or "nil"),
        tostring(reason or "unknown"),
    }, ":")

    self:LogAuraDebug(db, rejectKey, string.format(
        "[CombatAuras][Reject] unit=%s auraType=%s spellID=%s name=%s duration=%s expiration=%s filter=%s",
        tostring(unit or "?"),
        tostring(auraType or "?"),
        tostring(safeSpellId or "nil"),
        safeName ~= "" and safeName or "?",
        tostring(safeDuration),
        tostring(safeExpiration),
        tostring(reason or "unknown")
    ), 2.0)
end

function UnitFrames:LogWhitelistSpellIdNil(db, unit, auraType, mode, auraData, combatState, rawSpellId, lookupMeta)
    local keyName = "none"
    local keyType = "nil"
    local rawType = "nil"
    local reason = "missing-field"
    local spellKey = nil
    local lookupPath = "none"
    local setLookupErrored = false

    if type(auraData) == "table" then
        local legacySpellID = nil
        local _, detectedKey = SafeGetSpellIdRaw(auraData)
        if rawSpellId == nil then
            rawSpellId, detectedKey = SafeGetSpellIdRaw(auraData)
        end
        legacySpellID = rawget(auraData, "spellID")
        if type(auraData._spellIdKey) == "string" and auraData._spellIdKey ~= "" then
            keyName = auraData._spellIdKey
        elseif detectedKey and detectedKey ~= "none" then
            keyName = detectedKey
        elseif auraData.spellId ~= nil then
            keyName = "spellId"
        elseif legacySpellID ~= nil then
            keyName = "spellID"
        end

        if keyName == "spellId" then
            keyType = type(auraData.spellId)
        elseif keyName == "spellID" then
            keyType = type(legacySpellID)
        end
    end

    if rawSpellId ~= nil then
        rawType = type(rawSpellId)
        spellKey = SafeSpellKey(rawSpellId)
        reason = spellKey and "invalid-value" or "spell-key-nil"
    end

    if type(lookupMeta) == "table" then
        setLookupErrored = lookupMeta.setLookupErrored == true
        spellKey = spellKey or lookupMeta.spellKey
        lookupPath = "set-lookup"
    end

    self:LogAuraDebug(db,
        "whitelistnil:" .. tostring(unit or "?") .. ":" .. tostring(auraType or "?"),
        string.format("[CombatAuras][WhitelistSpellIdNil] unit=%s auraType=%s combatState=%s mode=%s key=%s keyType=%s rawType=%s spellKey=%s reason=%s setLookupErrored=%s path=%s",
            tostring(unit or "?"),
            tostring(auraType or "?"),
            tostring(combatState == true),
            tostring(mode or "NONE"),
            tostring(keyName),
            tostring(keyType),
            tostring(rawType),
            tostring(spellKey or "nil"),
            tostring(reason),
            tostring(setLookupErrored),
            tostring(lookupPath)
        ),
        2.0
    )
end

--[[
    Check if player can dispel a debuff type
    @param debuffType string - The type of debuff (Magic, Curse, Disease, Poison)
    @return boolean
]]
function UnitFrames:CanDispelDebuffType(debuffType)
    local dt = SafeRevealString(debuffType)
    if not dt then return false end

    local _, playerClass = UnitClass("player")
    local dispellable = DispellableByClass[playerClass]

    return dispellable and dispellable[dt] == true
end

--[[
    Check if an aura should be shown based on filter settings
    @param unit string - Unit ID
    @param auraType string - "BUFF" or "DEBUFF"
    @return boolean
]]
function UnitFrames:ShouldShowAura_Base(auraData, unit, auraType, db, skipBlizzard)
    if not auraData then return false end
    db = db or self:GetDB()
    if FORCE_SHOW_ALL_AURAS then
        local prefix = auraType == "BUFF" and "buff" or "debuff"
        return db[prefix .. "Enabled"] ~= false
    end

    local prefix = auraType == "BUFF" and "buff" or "debuff"
    local filterMode = db[prefix .. "FilterMode"] or "SMART"
    
    -- All mode - show everything
    if filterMode == "ALL" then
        return true
    end
    
    -- Blizzard mode - use cached decisions (unless we explicitly skip it)
    if filterMode == "BLIZZARD" then
        if skipBlizzard then
            filterMode = "SMART"
        end
    end
    if filterMode == "BLIZZARD" then
        local cache = blizzardAuraCache[unit]
        if cache then
            local cacheTable = auraType == "BUFF" and cache.buffs or cache.debuffs
            local shown = cacheTable[auraData.auraInstanceID] == true
            if not shown then
                local showText, showSwipe = self:GetAuraDisplayFlags(db)
                local dur = SafeNumber(auraData.duration, 0)
                local exp = SafeNumberOrNil(auraData.expirationTime)
                self:LogCombatAura(db, auraType, auraData.spellId, dur, exp, "HIDDEN", "blizzard filter", showText, showSwipe)
            end
            return shown
        end
        -- Fallback to smart if no cache
        filterMode = "SMART"
    end

    -- Fallback to smart filtering for any other mode
    local smartShown = self:SmartFilterAura(auraData, unit, auraType, db)
    if not smartShown then
        local showText, showSwipe = self:GetAuraDisplayFlags(db)
        local dur = SafeNumber(auraData.duration, 0)
        local exp = SafeNumberOrNil(auraData.expirationTime)
        self:LogCombatAura(db, auraType, auraData.spellId, dur, exp, "HIDDEN", "smart filter", showText, showSwipe)
    end
    return smartShown
end

function UnitFrames:ShouldShowAura(auraData, unit, auraType, db, combatContext)
    if not auraData then return false end

    db = db or self:GetDB()
    if FORCE_SHOW_ALL_AURAS then
        local prefix = auraType == "BUFF" and "buff" or "debuff"
        return db[prefix .. "Enabled"] ~= false
    end

    local inCombat = self:IsPlayerInCombat()
    local combatEnabled = db.combatFilterEnabled == true

    -- Base filtering (smart/whitelist/blacklist/blizzard) stays intact.
    local baseShown = self:ShouldShowAura_Base(auraData, unit, auraType, db, inCombat and combatEnabled)
    if not inCombat or not combatEnabled then
        return baseShown
    end

    local context = combatContext
    if type(context) ~= "table" then
        context = BuildCombatFilterLookupContext(self, db, auraType, inCombat)
    end

    local mode = context.mode
    if mode == "NONE" then
        return baseShown
    end

    local appliesTo = context.appliesTo
    if appliesTo == "BUFFS" and auraType ~= "BUFF" then
        return baseShown
    end
    if appliesTo == "DEBUFFS" and auraType ~= "DEBUFF" then
        return baseShown
    end

    local listEmpty = context.listEmpty == true
    local listSet = context.listSet or {}
    local safeSpellId = LilyPlainNumber(auraData.spellId)
    if safeSpellId then
        safeSpellId = floor(safeSpellId)
        if safeSpellId <= 0 then
            safeSpellId = nil
        end
    end
    local spellKey = auraData.spellKey or (safeSpellId and tostring(safeSpellId)) or nil

    if mode == "WHITELIST" then
        if listEmpty then
            local baseNoCombat = baseShown
            if inCombat and combatEnabled then
                baseNoCombat = self:ShouldShowAura_Base(auraData, unit, auraType, db, false)
            end
            if not self._combatWhitelistFailOpenLogged then
                self._combatWhitelistFailOpenLogged = true
                if LilyUI and LilyUI.DebugWindowLog then
                    LilyUI:DebugWindowLog("CombatAuras", "[CombatAuras] WHITELIST empty -> fail-open (base filter)")
                end
            end
            return baseNoCombat
        end
        self._combatWhitelistFailOpenLogged = false

        if not spellKey then
            self:LogCombatFilterReject(db, unit, auraType, auraData, "combat whitelist block (spellId missing)")
            return false
        end

        local lookupOk, lookupHit = pcall(function()
            return listSet[spellKey] == true
        end)
        if not lookupOk then
            self:LogCombatFilterReject(db, unit, auraType, auraData, "combat whitelist lookup error")
            return false
        end
        local inList = lookupHit and true or false

        if not inList then
            self:LogCombatFilterReject(db, unit, auraType, auraData, "combat whitelist miss")
            local showText, showSwipe = self:GetAuraDisplayFlags(db)
            local dur = SafeNumber(auraData.duration, 0)
            local exp = SafeNumberOrNil(auraData.expirationTime)
            self:LogCombatAura(db, auraType, safeSpellId, dur, exp, "HIDDEN", "combat whitelist miss", showText, showSwipe)
        end
        return inList
    else
        if not spellKey then
            return baseShown
        end
        local lookupOk, lookupHit = pcall(function()
            return listSet[spellKey] == true
        end)
        if not lookupOk then
            return baseShown
        end
        local inList = lookupHit and true or false
        if baseShown and inList then
            self:LogCombatFilterReject(db, unit, auraType, auraData, "combat blacklist hit")
            local showText, showSwipe = self:GetAuraDisplayFlags(db)
            local dur = SafeNumber(auraData.duration, 0)
            local exp = SafeNumberOrNil(auraData.expirationTime)
            self:LogCombatAura(db, auraType, safeSpellId, dur, exp, "HIDDEN", "combat blacklist hit", showText, showSwipe)
        end
        return baseShown and not inList
    end

    return baseShown
end
    --[[
    Smart aura filtering logic
    @param unit string - Unit ID
    @param auraType string - "BUFF" or "DEBUFF"
    @return boolean
]]
function UnitFrames:SmartFilterAura(auraData, unit, auraType, db)
    if FORCE_SHOW_ALL_AURAS then
        return true
    end
    db = db or self:GetDB()

    -- Debug: report invalid/secret numeric fields without spamming.
    local function ReadNumericField(fieldName)
        local raw = auraData and auraData[fieldName]
        local value = SafeNumber(raw, nil, fieldName)
        if value == nil and AuraDebugEnabled(db) then
            local spellKey = SafeSpellKey(auraData and auraData.spellId)
            self:LogAuraDebug(db,
                "smartnum:" .. tostring(unit or "?") .. ":" .. tostring(fieldName),
                string.format("[CombatAuras][SmartFilterNumeric] unit=%s spellID=%s field=%s type=%s",
                    tostring(unit or "?"),
                    tostring(spellKey or "nil"),
                    tostring(fieldName),
                    tostring(type(raw))
                ),
                1.0
            )
        end
        return value
    end

    local ok, result = xpcall(function()
        if auraType == "DEBUFF" then
            -- Always show boss auras
            if SafeBool(auraData.isBossAura) then
                return true
            end

            -- Show dispellable debuffs if player can dispel
            if self:CanDispelDebuffType(SafeString(auraData.dispelName, "")) then
                return true
            end

            -- Show debuffs cast by player
            if db.showPlayerDebuffs and SafeString(auraData.sourceUnit, "") == "player" then
                return true
            end

            -- Show debuffs with significant duration (skip if values are invalid).
            local dur = ReadNumericField("duration")
            local exp = ReadNumericField("expirationTime")
            local safeDur = SafePositiveNumber(dur)
            local safeExp = SafePositiveNumber(exp)
            if safeDur and safeExp then
                if safeDur > 5 then
                    return true
                end
            end

            -- Show debuffs that reduce stats significantly
            -- (This would normally check specific spell IDs)
            return false
        end

        -- Buffs
        if db.showPlayerBuffs and SafeString(auraData.sourceUnit, "") == "player" then
            return true
        end

        -- Show short duration buffs (likely important cooldowns); skip if invalid.
        local dur2 = ReadNumericField("duration")
        if dur2 and dur2 > 0 and dur2 < 30 then
            return true
        end

        -- Show buffs with stacks (tracking buffs); skip if invalid.
        local stacks = ReadNumericField("applications")
        if stacks and stacks > 0 then
            return true
        end

        -- Hide very long duration buffs (food, flasks, etc.); skip if invalid.
        local durHide = ReadNumericField("duration")
        if durHide and durHide > 3600 then
            return false
        end

        return true
    end, function(err)
        local spellKey = SafeSpellKey(auraData and auraData.spellId)
        local errText = tostring(err or "unknown error"):gsub("\r", " "):gsub("\n", " | ")
        self:LogAuraDebug(db,
            "smartfiltererr:" .. tostring(unit or "?") .. ":" .. tostring(auraType or "?"),
            string.format("[CombatAuras][SmartFilterError] unit=%s type=%s spellID=%s err=%s",
                tostring(unit or "?"),
                tostring(auraType or "?"),
                tostring(spellKey or "nil"),
                errText
            ),
            1.0
        )
        return err
    end)

    if ok then
        return result and true or false
    end

    -- Never let SmartFilterAura kill aura scanning.
    return false
end

-- ============================================================================
-- AURA DATA COLLECTION
-- ============================================================================

--[[
    @param unit string - Unit ID
    @param auraType string - "BUFF" or "DEBUFF"
    @return table - Array of aura data
]]
GetAuraDataByInstanceID = function(unit, auraInstanceID)
    if not C_UnitAuras or not unit or not auraInstanceID then
        return nil
    end
    if C_UnitAuras.GetAuraDataByAuraInstanceID then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
        if ok and data then
            return data
        end
    end
    if C_UnitAuras.GetAuraDataByInstanceID then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByInstanceID, unit, auraInstanceID)
        if ok and data then
            return data
        end
    end
    return nil
end

local function SafeAuraCallback(inner, ...)
    local args = {...}
    local ok = xpcall(function()
        return inner(unpack(args))
    end, debugstack)
    if not ok then
        SecretSafe.LogOnce("aura_callback_fail", "|cffff0000lilyUI|r Aura callback error (suppressed); scan continues.")
    end
    return ok
end

function UnitFrames:CollectAuras(unit, auraType, db)
    db = db or self:GetDB()
    local auras = {}
    local filter = auraType == "BUFF" and "HELPFUL" or "HARMFUL"
    local combatLookupContext = BuildCombatFilterLookupContext(self, db, auraType, self:IsPlayerInCombat())
    local stats = {
        rawCount = 0,
        passedCount = 0,
        method = "ForEachAura",
    }

    local function AddAuraTimingMeta(safeAura)
        if not safeAura then
            return nil
        end
        local instanceId = SafeNumberOrNil(safeAura.auraInstanceID)
        local timed = false
        local durationObj = nil
        local countText = nil

        if instanceId and C_UnitAuras and type(C_UnitAuras.DoesAuraHaveExpirationTime) == "function" then
            local okTimed, hasTimed = pcall(C_UnitAuras.DoesAuraHaveExpirationTime, unit, instanceId)
            timed = okTimed and hasTimed == true or false
        end

        if timed and instanceId then
            durationObj = GetAuraDurationObject(unit, instanceId)
            if not durationObj then
                local logKey = safeAura.spellId or ("aura:" .. tostring(instanceId or 0))
                SecretSafe.LogOnce(logKey, "|cffffff00lilyUI|r Aura timing secret/unavailable in combat; showing icon without timer.")
            end
        end

        if instanceId and C_UnitAuras and type(C_UnitAuras.GetAuraApplicationDisplayCount) == "function" then
            local okCount, displayCount = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, instanceId)
            if okCount and type(displayCount) == "string" and displayCount ~= "" then
                countText = displayCount
            end
        end

        safeAura.timed = timed
        safeAura.durationObj = durationObj
        safeAura.countText = countText
        safeAura.sortExp = SafeNumberOrNil(safeAura.expirationTime)
        safeAura.sortIsTimed = timed and safeAura.sortExp ~= nil or false
        return safeAura
    end

    local function ResolveAuraData(auraData)
        local safeAura = nil
        SafeAuraCallback(function()
            safeAura = SanitizeAuraData(auraData)
        end)

        if safeAura and safeAura.spellId then
            return AddAuraTimingMeta(safeAura)
        end

        local instanceId = SafeNumberOrNil(SafeAuraField(auraData, "auraInstanceID"))
        if instanceId then
            local refreshed = GetAuraDataByInstanceID(unit, instanceId)
            if refreshed then
                SafeAuraCallback(function()
                    safeAura = SanitizeAuraData(refreshed)
                end)
            end
        end
        return AddAuraTimingMeta(safeAura)
    end

    local function TryCollectAura(rawAura)
        stats.rawCount = stats.rawCount + 1
        local safeAura = ResolveAuraData(rawAura)
        if not safeAura then
            return
        end

        if safeAura._durationInvalid then
            self:LogAuraInvalidFieldOnce(db, unit, auraType, safeAura, "duration", safeAura._durationRaw)
        end
        if safeAura._expirationInvalid then
            self:LogAuraInvalidFieldOnce(db, unit, auraType, safeAura, "expirationTime", safeAura._expirationRaw)
        end

        local shouldShow = false
        SafeAuraCallback(function()
            shouldShow = self:ShouldShowAura(safeAura, unit, auraType, db, combatLookupContext) and true or false
        end)
        if shouldShow then
            table.insert(auras, safeAura)
            stats.passedCount = stats.passedCount + 1
        end
    end

    local scanCompleted = false
    local forEachOk = false
    if ForEachAura then
        local ok = xpcall(function()
            ForEachAura(unit, filter, nil, function(...)
                SafeAuraCallback(function(auraData)
                    TryCollectAura(auraData)
                end, ...)
                return false
            end, true)
            forEachOk = true
            scanCompleted = true
        end, debugstack)
        if not ok then
            forEachOk = false
            stats.rawCount = 0
            stats.passedCount = 0
            stats.method = "UnitAuraFallback"
            SecretSafe.LogOnce("for_each_aura_fail", "|cffff0000lilyUI|r Aura scan failed (suppressed); retrying on next update.")
        end
    else
        stats.method = "UnitAuraFallback"
    end

    if not ForEachAura or not forEachOk then
        local index = 1
        local fallbackOk = true
        while true do
            local ok, name, icon, count, dispelType, duration, expirationTime, source, _, _, spellId, _, isBossDebuff, _, _, _, _, _, _, auraInstanceID = pcall(UnitAura, unit, index, filter)
            if not ok then
                fallbackOk = false
                break
            end
            if not name then
                break
            end

            local auraData = {
                name = name,
                icon = icon,
                applications = count,
                dispelName = dispelType,
                duration = duration,
                expirationTime = expirationTime,
                sourceUnit = source,
                spellId = spellId,
                auraInstanceID = auraInstanceID,
                isBossAura = isBossDebuff,
            }

            SafeAuraCallback(function()
                TryCollectAura(auraData)
            end)
            index = index + 1
        end
        scanCompleted = fallbackOk
    end

    local sortOk = xpcall(function()
        self:SortAuras(auras, auraType, db)
    end, debugstack)
    if not sortOk then
        SecretSafe.LogOnce("aura_sort_fail", "|cffff0000lilyUI|r Aura sort failed (suppressed); using unsorted order.")
    end

    if not scanCompleted then
        return auras, stats, combatLookupContext, false
    end

    self._lastGoodAuras = self._lastGoodAuras or {}
    local byUnit = self._lastGoodAuras[unit]
    if type(byUnit) ~= "table" then
        byUnit = {}
        self._lastGoodAuras[unit] = byUnit
    end
    byUnit[auraType] = {}
    for i = 1, #auras do
        byUnit[auraType][i] = auras[i]
    end

    return auras, stats, combatLookupContext, true
end

--[[
    Sort auras by priority
    @param auras table - Array of aura data
    @param auraType string - "BUFF" or "DEBUFF"
]]
function UnitFrames:SortAuras(auras, auraType, db)
    db = db or self:GetDB()
    local sortMethod = db[(auraType == "BUFF" and "buff" or "debuff") .. "SortMethod"] or "TIME"

    local function AuraSort(a, b)
        local aBoss = SafeBool(a.isBossAura)
        local bBoss = SafeBool(b.isBossAura)
        if aBoss ~= bBoss then
            return aBoss
        end

        if sortMethod == "NAME" then
            local aName = type(a.name) == "string" and a.name or ""
            local bName = type(b.name) == "string" and b.name or ""
            if aName ~= bName then
                return aName < bName
            end
        end

        local aTimed = a.sortIsTimed == true
        local bTimed = b.sortIsTimed == true
        if aTimed ~= bTimed then
            return aTimed
        end

        local aKey = SafeNumberOrNil(a.sortExp) or math.huge
        local bKey = SafeNumberOrNil(b.sortExp) or math.huge
        if aKey ~= bKey then
            return aKey < bKey
        end

        local aID = SafeNumberOrNil(a.auraInstanceID) or 0
        local bID = SafeNumberOrNil(b.auraInstanceID) or 0
        if aID ~= bID then
            return aID < bID
        end

        local aSpell = SafeNumberOrNil(a.spellId) or 0
        local bSpell = SafeNumberOrNil(b.spellId) or 0
        return aSpell < bSpell
    end

    local ok = xpcall(function()
        table.sort(auras, AuraSort)
    end, debugstack)
    if not ok then
        SecretSafe.LogOnce("aura_sort_fail_internal", "|cffff0000lilyUI|r Aura sort failed (suppressed); using unsorted order.")
    end
end

-- ============================================================================
-- AURA ICON MANAGEMENT
-- ============================================================================

-- ============================================================================
-- AURA LAYERING (force icon containers above unit frames)
-- ============================================================================

local AURA_LAYER_STRATA = "TOOLTIP"
local AURA_LAYER_OFFSET = 50

local function GetAuraContainerKey(auraType)
    if auraType == "BUFF" then
        return "buffAuraContainer"
    end
    return "debuffAuraContainer"
end

function UnitFrames:EnsureAuraContainer(frame, auraType)
    if not frame then return nil end
    local key = GetAuraContainerKey(auraType)
    local container = frame[key]

    if not container then
        container = CreateFrame("Frame", nil, frame)
        container:SetAllPoints(frame)
        container:EnableMouse(false)
        frame[key] = container
    end

    container:SetFrameStrata(AURA_LAYER_STRATA)
    container:SetFrameLevel((frame:GetFrameLevel() or 0) + AURA_LAYER_OFFSET)
    return container
end

function UnitFrames:ApplyAuraLayering(frame, auraType)
    if not frame then return end

    local function applyForType(kind)
        local container = self:EnsureAuraContainer(frame, kind)
        if not container then return end

        local icons = kind == "BUFF" and frame.buffIcons or frame.debuffIcons
        if not icons then return end

        for i, icon in ipairs(icons) do
            if icon then
                if icon:GetParent() ~= container then
                    icon:SetParent(container)
                end

                icon:SetFrameStrata(container:GetFrameStrata())
                icon:SetFrameLevel(container:GetFrameLevel() + i)

                if icon.texture and icon.texture.SetDrawLayer then
                    icon.texture:SetDrawLayer("OVERLAY", 1)
                end
                if icon.cooldown then
                    icon.cooldown:SetFrameStrata(icon:GetFrameStrata())
                    icon.cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
                end
                if icon.border then
                    icon.border:SetFrameStrata(icon:GetFrameStrata())
                    icon.border:SetFrameLevel(icon:GetFrameLevel() + 2)
                end
                if icon.count and icon.count.SetDrawLayer then
                    icon.count:SetDrawLayer("OVERLAY", 6)
                end
                if icon.duration and icon.duration.SetDrawLayer then
                    icon.duration:SetDrawLayer("OVERLAY", 7)
                end
                if icon.expiring and icon.expiring.SetDrawLayer then
                    icon.expiring:SetDrawLayer("OVERLAY", 7)
                end
                if icon.masqueBorder and icon.masqueBorder.SetDrawLayer then
                    icon.masqueBorder:SetDrawLayer("OVERLAY", 6)
                end
            end
        end
    end

    if auraType then
        applyForType(auraType)
    else
        applyForType("BUFF")
        applyForType("DEBUFF")
    end
end

function UnitFrames:ReapplyAuraLayering(frameType)
    local function apply(frame)
        if frame then
            self:ApplyAuraLayering(frame, "BUFF")
            self:ApplyAuraLayering(frame, "DEBUFF")
        end
    end

    if frameType ~= "raid" then
        apply(self.playerFrame)
        for i = 1, 4 do
            apply(self.partyFrames and self.partyFrames[i])
        end
    end

    if frameType ~= "party" and IsInRaid and IsInRaid() then
        for i = 1, 40 do
            apply(self.raidFrames and self.raidFrames[i])
        end
    end
end

--[[
    Create an aura icon
    @param parent Frame - Parent frame
    @param index number - Icon index
    @param auraType string - "BUFF" or "DEBUFF"
    @return Frame - The aura icon frame
]]
function UnitFrames:CreateAuraIcon(parent, index, auraType)
    local db = parent.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local size = db[(auraType == "BUFF" and "buff" or "debuff") .. "Size"] or 18

    -- Layering: parent aura icons to a dedicated high-strata container.
    local container = self:EnsureAuraContainer(parent, auraType) or parent
    local icon = CreateFrame("Frame", nil, container)
    icon:SetSize(size, size)
    icon.auraType = auraType
    icon.index = index
    icon.unitFrame = parent
    icon._debugLoggedCreate = false
    icon:SetFrameStrata(container:GetFrameStrata())
    icon:SetFrameLevel(container:GetFrameLevel() + (index or 1))
    
    -- Icon texture
    icon.texture = icon:CreateTexture(nil, "OVERLAY")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Border (square, expands outward with thickness)
    local border = CreateFrame("Frame", nil, icon)
    border:SetAllPoints(icon)
    border:Hide()

    local borderTop = border:CreateTexture(nil, "OVERLAY")
    local borderBottom = border:CreateTexture(nil, "OVERLAY")
    local borderLeft = border:CreateTexture(nil, "OVERLAY")
    local borderRight = border:CreateTexture(nil, "OVERLAY")

    border.sides = {
        top = borderTop,
        bottom = borderBottom,
        left = borderLeft,
        right = borderRight,
    }

    function border:SetThickness(thickness)
        local t = thickness or 1

        borderTop:ClearAllPoints()
        borderTop:SetPoint("TOPLEFT", icon, "TOPLEFT", -t, t)
        borderTop:SetPoint("TOPRIGHT", icon, "TOPRIGHT", t, t)
        borderTop:SetHeight(t)

        borderBottom:ClearAllPoints()
        borderBottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -t, -t)
        borderBottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", t, -t)
        borderBottom:SetHeight(t)

        borderLeft:ClearAllPoints()
        borderLeft:SetPoint("TOPLEFT", icon, "TOPLEFT", -t, t)
        borderLeft:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -t, -t)
        borderLeft:SetWidth(t)

        borderRight:ClearAllPoints()
        borderRight:SetPoint("TOPRIGHT", icon, "TOPRIGHT", t, t)
        borderRight:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", t, -t)
        borderRight:SetWidth(t)
    end

    function border:SetVertexColor(r, g, b, a)
        local alpha = a == nil and 1 or a
        for _, side in pairs(border.sides) do
            side:SetColorTexture(r, g, b, alpha)
        end
    end

    border:SetThickness(self:PixelPerfectThickness(1))
    border:SetVertexColor(0, 0, 0, 0.8)
    icon.border = border

    icon.masqueBorder = icon:CreateTexture(nil, "OVERLAY")
    icon.masqueBorder:SetAllPoints(icon)
    icon.masqueBorder:SetColorTexture(0, 0, 0, 0)
    
    -- Cooldown
    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetDrawSwipe(true)
    icon.cooldown:SetSwipeColor(0, 0, 0, 0.6)
    icon.cooldown:SetFrameStrata(icon:GetFrameStrata())
    icon.cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
    if icon.cooldown.SetHideCountdownNumbers then
        icon.cooldown:SetHideCountdownNumbers(true)
    end
    
    -- Stack count
    icon.count = icon:CreateFontString(nil, "OVERLAY")
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    -- Apply per-type text sizing (Buffs vs Debuffs)
    local prefixText = (auraType == "BUFF") and "buff" or "debuff"
    local textSize = db[prefixText .. "TextSize"] or db.auraStackSize or 10
    local durationSize = db[prefixText .. "DurationSize"] or db.auraDurationSize or 9

    self:SafeSetFont(icon.count, self:GetFontPath(db.auraStackFont), textSize, db.auraStackOutline or "OUTLINE")
    icon.count:SetJustifyH("RIGHT")
    local stackPos = db[prefixText .. "StackPosition"] or "BOTTOMRIGHT"
    icon.count:ClearAllPoints()
    if stackPos == "TOPLEFT" then
        icon.count:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    elseif stackPos == "TOPRIGHT" then
        icon.count:SetPoint("TOPRIGHT", icon, "TOPRIGHT", -1, -1)
    elseif stackPos == "BOTTOMLEFT" then
        icon.count:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 1, 1)
    else
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    end

    -- Duration text (centered within icon)
    icon.duration = icon:CreateFontString(nil, "OVERLAY")
    icon.duration:SetPoint("CENTER", icon, "CENTER", 0, 0)
    local durationFontSize = math.max(6, math.min(durationSize - 1, floor(size * 0.45)))
    self:SafeSetFont(icon.duration, self:GetFontPath(db.auraDurationFont), durationFontSize, db.auraDurationOutline or "OUTLINE")
    local durationBox = max(8, size - 2)
    icon.duration:SetSize(durationBox, durationBox)
    icon.duration:SetJustifyH("CENTER")
    icon.duration:SetJustifyV("MIDDLE")
    if icon.duration.SetWordWrap then
        icon.duration:SetWordWrap(false)
    end
    if icon.duration.SetNonSpaceWrap then
        icon.duration:SetNonSpaceWrap(false)
    end
    if icon.duration.SetMaxLines then
        icon.duration:SetMaxLines(1)
    end
    icon.__durationBox = durationBox
    
    -- Expiring indicator
    icon.expiring = icon:CreateTexture(nil, "OVERLAY", nil, 7)
    icon.expiring:SetAllPoints()
    icon.expiring:SetColorTexture(1, 0, 0, 0)
    icon.expiring:SetBlendMode("ADD")
    icon.expiring:Hide()
    
    -- Store references
    icon.auraDuration = nil
    icon.showDuration = db.auraDurationEnabled ~= false
    icon.stackMinimum = db.auraStackMinimum or 2
    
    -- Temporary: disable aura icon tooltips/mouse interaction to avoid protected data access.
    icon:EnableMouse(false)
    icon:SetScript("OnEnter", nil)
    icon:SetScript("OnLeave", nil)
    
    icon:Hide()
    return icon
end

--[[
    Ensure we have enough aura icons for a frame
    @param frame Frame - The unit frame
    @param auraType string - "BUFF" or "DEBUFF"
    @param count number - Number of icons needed
]]
function UnitFrames:EnsureAuraIcons(frame, auraType, count)
    self:EnsureAuraContainer(frame, auraType)
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons
    
    if not icons then
        icons = {}
        if auraType == "BUFF" then
            frame.buffIcons = icons
        else
            frame.debuffIcons = icons
        end
    end
    
    while #icons < count do
        local icon = self:CreateAuraIcon(frame, #icons + 1, auraType)
        table.insert(icons, icon)
    end

    self:ApplyAuraLayering(frame, auraType)
end

-- ============================================================================
-- AURA DISPLAY UPDATE
-- ============================================================================

--[[
    Update aura icons for a frame
    @param frame Frame - The unit frame
    @param auraType string - "BUFF" or "DEBUFF" (optional, updates both if nil)
]]

--[[
    Update auras for a unit frame (called by UNIT_AURA events)
]]
function UnitFrames:UpdateAuras(frame)
    if not frame or not frame.unit then return end
    if self.UpdateAuraIcons then
        self:UpdateAuraIcons(frame)
    end
end

function UnitFrames:UpdateAuraIcons(frame, auraType)
    if not frame or not frame.unit then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if auraType then
        self:UpdateAuraIconsForType(frame, auraType, db)
    else
        self:UpdateAuraIconsForType(frame, "BUFF", db)
        self:UpdateAuraIconsForType(frame, "DEBUFF", db)
    end
end

function UnitFrames:ApplyAuraSettings(frameType)
    local function apply(frame)
        if not frame then return end
        if self.ApplyAuraLayout then
            self:ApplyAuraLayout(frame, "BUFF")
            self:ApplyAuraLayout(frame, "DEBUFF")
        end
        if self.ApplyAuraLayering then
            self:ApplyAuraLayering(frame, "BUFF")
            self:ApplyAuraLayering(frame, "DEBUFF")
        end
        if self.UpdateAuraIcons then
            self:UpdateAuraIcons(frame)
        end
    end

    if frameType ~= "raid" then
        apply(self.playerFrame)
        for i = 1, 4 do
            apply(self.partyFrames[i])
        end
    end

    if frameType ~= "party" and IsInRaid and IsInRaid() then
        for i = 1, 40 do
            apply(self.raidFrames[i])
        end
    end

    if self.ApplyAllPrivateAuraLayouts then
        self:ApplyAllPrivateAuraLayouts()
    end
end

function UnitFrames:RefreshAuraIcons(frameType)
    local function apply(frame)
        if not frame then return end
        if self.UpdateAuraIcons then
            self:UpdateAuraIcons(frame)
        end
    end

    if frameType ~= "raid" then
        apply(self.playerFrame)
        for i = 1, 4 do
            apply(self.partyFrames[i])
        end
    end

    if frameType ~= "party" and IsInRaid and IsInRaid() then
        for i = 1, 40 do
            apply(self.raidFrames[i])
        end
    end
end

--[[
    Update aura icons for a specific type
    @param frame Frame - The unit frame
    @param auraType string - "BUFF" or "DEBUFF"
    @param db table - Database settings
]]
function UnitFrames:UpdateAuraIconsForType(frame, auraType, db)
    local prefix = auraType == "BUFF" and "buff" or "debuff"
    
    if not db[prefix .. "Enabled"] then
        self:HideAllAuraIcons(frame, auraType)
        return
    end
    
    -- Collect auras
    local auras, collectStats, combatLookupContext, hasValidAuraList = self:CollectAuras(frame.unit, auraType, db)
    local maxIcons = db[prefix .. "MaxIcons"] or 8

    if hasValidAuraList == false then
        self:LogAuraDebug(db,
            "skipupdate:" .. tostring(frame.unit or "?") .. ":" .. tostring(auraType or "?"),
            string.format("[CombatAuras][ScanRetry] skip icon wipe/update unit=%s type=%s (scan incomplete; retry next event)",
                tostring(frame.unit or "?"),
                tostring(auraType or "?")
            ),
            0.2
        )
        return
    end
    
    -- Ensure we have enough icons
    self:EnsureAuraIcons(frame, auraType, maxIcons)
    self:ApplyAuraLayering(frame, auraType)
    
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons

    -- Stabilize updates: hide/reset all first, then populate visible entries.
    for i = 1, maxIcons do
        local icon = icons[i]
        if icon then
            self:_UnregisterAuraDurationIcon(icon)
            if icon.duration then
                icon.duration:SetText("")
                icon.duration:Hide()
            end
            if icon.expiring then
                icon.expiring:Hide()
            end
            if icon.cooldown then
                if icon.cooldown.SetDrawSwipe then
                    icon.cooldown:SetDrawSwipe(false)
                end
                icon.cooldown:Hide()
            end
            icon:Hide()
        end
    end
    
    -- Update each icon
    for i = 1, maxIcons do
        local icon = icons[i]
        local auraData = auras[i]
        
        if icon and auraData then
            local iconOk = xpcall(function()
                self:UpdateSingleAuraIcon(icon, auraData, db, combatLookupContext)
            end, debugstack)
            if iconOk then
                icon:Show()
            else
                SecretSafe.LogOnce("aura_icon_apply_fail", "|cffff0000lilyUI|r Aura icon update error (suppressed); continuing.")
                icon:Hide()
                self:_UnregisterAuraDurationIcon(icon)
                if icon.cooldown then
                    icon.cooldown:Hide()
                end
                if icon.duration then
                    icon.duration:Hide()
                end
            end
        end
    end

    local shownCount = 0
    for i = 1, maxIcons do
        if auras[i] then
            shownCount = shownCount + 1
        end
    end

    if AuraDebugEnabled(db) then
        local rawCount = (collectStats and collectStats.rawCount) or 0
        self:LogAuraDebug(db, "counts:" .. tostring(frame.unit or "?") .. ":" .. tostring(auraType),
            string.format("[CombatAuras][Update] unit=%s type=%s raw=%d shown=%d",
                tostring(frame.unit or "?"),
                tostring(auraType),
                rawCount,
                shownCount
            ), 0.1)
    end
end

--[[
    Update a single aura icon with aura data
    @param icon Frame - The aura icon
    @param auraData table - Aura data
    @param db table - Database settings
]]
local function UpdateAuraIconTexture(iconTexture, aura)
    if not iconTexture or not iconTexture.SetTexture then return end

    if aura and aura.icon then
        iconTexture:SetTexture(aura.icon)
        iconTexture:Show()
    else
        iconTexture:Hide()
    end
end

function UnitFrames:UpdateSingleAuraIcon(icon, auraData, db, combatLookupContext)
    -- Set texture
    UpdateAuraIconTexture(icon.texture, auraData)
    -- Store aura info (sanitized to avoid protected "secret" values)
    local durStore = SafeNumber(auraData.duration, 0)
    local expStore = SafeNumberOrNil(auraData.expirationTime)

    icon.auraInfo = auraData
    icon.auraDuration = durStore
    icon.auraExpiration = expStore
    icon.expirationTime = expStore
    icon._duration = durStore
    icon._expTime = expStore
    icon._db = db
    icon.spellId = auraData.spellId
    icon.auraInstanceID = SafeNumberOrNil(auraData.auraInstanceID)
    icon.unit = (icon.unitFrame and icon.unitFrame.unit) or icon.unit

    local showText, showSwipe = self:GetAuraDisplayFlags(db)
    icon.showDuration = showText
    icon.showSwipe = showSwipe
    
    -- Apply per-type text sizing (Buffs vs Debuffs)
    local prefixText = (icon.auraType == "BUFF") and "buff" or "debuff"
    local textSize = db[prefixText .. "TextSize"] or db.auraStackSize or 10
    local durationSize = db[prefixText .. "DurationSize"] or db.auraDurationSize or 9

    self:SafeSetFont(icon.count, self:GetFontPath(db.auraStackFont), textSize, db.auraStackOutline)
    if icon.duration then
        local iconSize = (icon.GetWidth and icon:GetWidth()) or (db[prefixText .. "Size"] or 18)
        local durationFontSize = math.max(6, math.min(durationSize - 1, floor(iconSize * 0.45)))
        self:SafeSetFont(icon.duration, self:GetFontPath(db.auraDurationFont), durationFontSize, db.auraDurationOutline)
        local durationBox = max(8, iconSize - 2)
        if icon.__durationBox ~= durationBox then
            icon.duration:SetSize(durationBox, durationBox)
            icon.__durationBox = durationBox
        end
    end

    -- Update stack count
    if type(auraData.countText) == "string" and auraData.countText ~= "" then
        icon.count:SetText(auraData.countText)
        icon.count:Show()
    else
        local stacks = SafeNumber(auraData.applications, 0)
        if stacks >= (icon.stackMinimum or 2) then
            icon.count:SetText(stacks)
            icon.count:Show()
        else
            icon.count:SetText("")
            icon.count:Hide()
        end
    end

    local durationObj = auraData.durationObj or GetAuraDurationObject(icon.unit, icon.auraInstanceID)
    icon._usesDurationObject = false
    if durationObj then
        local total, expTime = ResolveDurationFromObject(durationObj)
        if total and expTime then
            icon._duration = total
            icon._expTime = expTime
            icon.auraDuration = total
            icon.auraExpiration = expTime
            icon.expirationTime = expTime
        end
    end

    -- Update cooldown with DurationObject-first logic.
    if showSwipe and icon.cooldown then
        local cooldownApplied = false
        local cooldown = icon.cooldown

        if durationObj and cooldown.SetCooldownFromDurationObject then
            local okObj = pcall(cooldown.SetCooldownFromDurationObject, cooldown, durationObj, true)
            if okObj then
                cooldownApplied = true
                icon._usesDurationObject = true
            end
        end

        if cooldownApplied then
            if cooldown.SetDrawSwipe then
                cooldown:SetDrawSwipe(true)
            end
            cooldown:Show()
        else
            if cooldown.SetDrawSwipe then
                cooldown:SetDrawSwipe(false)
            end
            cooldown:Hide()
        end
    elseif icon.cooldown then
        if icon.cooldown.SetDrawSwipe then
            icon.cooldown:SetDrawSwipe(false)
        end
        icon.cooldown:Hide()
    end

    if icon.duration then
        icon.duration:SetText("")
        icon.duration:Hide()
    end
    if icon.expiring then
        icon.expiring:Hide()
    end

    if not showText and icon.duration then
        icon.duration:SetText("")
        icon.duration:Hide()
    end

    -- Update border for debuffs
    if icon.auraType == "DEBUFF" then
        local dispelName = SafeString(auraData.dispelName, "")
        local color = UnitFrames.DebuffTypeColors[""]
        if dispelName ~= "" then
            local ok, result = pcall(function()
                return UnitFrames.DebuffTypeColors[dispelName]
            end)
            if ok and result then
                color = result
            end
        end
        if color then
            icon.border:SetVertexColor(color.r, color.g, color.b)
            icon.border:Show()
        else
            icon.border:Hide()
        end
    end
end
--[[
    Hide all aura icons of a type
    @param frame Frame - The unit frame
    @param auraType string - "BUFF" or "DEBUFF"
]]

--test
function UnitFrames:HideAllAuraIcons(frame, auraType)
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons
    
    if icons then
        for _, icon in ipairs(icons) do
            self:_UnregisterAuraDurationIcon(icon)
            if icon.duration then
                icon.duration:SetText("")
                icon.duration:Hide()
            end
            if icon.expiring then
                icon.expiring:Hide()
            end
            icon:Hide()
        end
    end
end

-- ============================================================================
-- AURA VISIBILITY DEBUG DUMP (debug flag required)
-- ============================================================================

local function SafeFrameCall(frame, methodName, default)
    if not frame or type(frame[methodName]) ~= "function" then
        return default
    end
    local ok, value = pcall(frame[methodName], frame)
    if not ok then
        return default
    end
    return value
end

local function FormatAlpha(value)
    if type(value) ~= "number" then
        return "nil"
    end
    return string.format("%.2f", value)
end

local function DumpAuraVisibilityForType(frame, unitToken, auraType)
    if not frame then
        AuraDebugOutput("[CombatAuras][VisibilityDump] unit=%s type=%s frame=nil", tostring(unitToken), tostring(auraType))
        return
    end

    local container = frame[GetAuraContainerKey(auraType)]
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons
    local icon = icons and icons[1]

    AuraDebugOutput(
        "[CombatAuras][VisibilityDump] unit=%s type=%s containerShown=%s containerVisible=%s containerAlpha=%s containerEffAlpha=%s containerStrata=%s containerLevel=%s iconShown=%s iconVisible=%s iconAlpha=%s iconStrata=%s iconLevel=%s",
        tostring(unitToken),
        tostring(auraType),
        tostring(SafeFrameCall(container, "IsShown", false)),
        tostring(SafeFrameCall(container, "IsVisible", false)),
        FormatAlpha(SafeFrameCall(container, "GetAlpha", nil)),
        FormatAlpha(SafeFrameCall(container, "GetEffectiveAlpha", nil)),
        tostring(SafeFrameCall(container, "GetFrameStrata", "nil")),
        tostring(SafeFrameCall(container, "GetFrameLevel", "nil")),
        tostring(SafeFrameCall(icon, "IsShown", false)),
        tostring(SafeFrameCall(icon, "IsVisible", false)),
        FormatAlpha(SafeFrameCall(icon, "GetAlpha", nil)),
        tostring(SafeFrameCall(icon, "GetFrameStrata", "nil")),
        tostring(SafeFrameCall(icon, "GetFrameLevel", "nil"))
    )
end

function UnitFrames:DumpAuraVisibilityState()
    local db = (self and self.GetDB) and self:GetDB() or nil
    if not AuraDebugEnabled(db) then
        AuraDebugOutput("[CombatAuras][VisibilityDump] debug disabled (enable with /lilydebug aura on)")
        return
    end

    DumpAuraVisibilityForType(self.playerFrame, "player", "BUFF")
    DumpAuraVisibilityForType(self.playerFrame, "player", "DEBUFF")
    DumpAuraVisibilityForType(self.partyFrames and self.partyFrames[1], "party1", "BUFF")
    DumpAuraVisibilityForType(self.partyFrames and self.partyFrames[1], "party1", "DEBUFF")
end

SLASH_LILYUIAURADEBUG1 = "/lilyuiauradebug"
SlashCmdList.LILYUIAURADEBUG = function()
    local UF = LilyUI and LilyUI.PartyFrames
    if UF and UF.DumpAuraVisibilityState then
        UF:DumpAuraVisibilityState()
    end
end

-- ============================================================================
-- COMBAT STATE REFRESH
-- ============================================================================

local function SetupAuraLayoutLayeringHook()
    if UnitFrames._auraLayoutLayeringHooked then return end
    if type(UnitFrames.ApplyAuraLayout) ~= "function" then return end

    -- Layering safety: re-assert strata/levels after any aura layout rebuild.
    hooksecurefunc(UnitFrames, "ApplyAuraLayout", function(self, frame, auraType)
        if self and self.ApplyAuraLayering then
            self:ApplyAuraLayering(frame, auraType)
        end
    end)
    UnitFrames._auraLayoutLayeringHooked = true
end

local function SetupCombatAuraRefresh()
    if UnitFrames._combatEventFrame then return end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        UnitFrames._combatState = (event == "PLAYER_REGEN_DISABLED")
        UnitFrames:LogAuraDebug(UnitFrames:GetDB(), "combatState",
            "[AURA] combatState=" .. tostring(UnitFrames._combatState), 0)
        if UnitFrames.ReapplyAuraLayering then
            -- Layering safety: re-assert on combat state transitions.
            UnitFrames:ReapplyAuraLayering()
        end
        if UnitFrames.RefreshAuraIcons then
            UnitFrames:RefreshAuraIcons()
        end
    end)

    UnitFrames._combatEventFrame = frame
end

SetupAuraLayoutLayeringHook()
SetupCombatAuraRefresh()

-- ============================================================================
-- DURATION COLOR
-- ============================================================================

--[[
    Get color for duration text based on remaining time
    @param remaining number - Remaining time in seconds
    @param totalDuration number - Total duration
    @return number, number, number - r, g, b
]]
function UnitFrames:GetDurationColorByPercent(remaining, totalDuration)
    local db = self:GetDB()
    
    if not db.durationColorEnabled then
        return 1, 1, 1
    end
    
    -- Color thresholds
    local lowThreshold = db.durationColorLowThreshold or 5
    local midThreshold = db.durationColorMidThreshold or 30
    
    if remaining <= lowThreshold then
        -- Red - critical
        return 1, 0.2, 0.2
    elseif remaining <= midThreshold then
        -- Yellow - warning
        return 1, 1, 0.4
    else
        -- White - normal
        return 1, 1, 1
    end
end

-- ============================================================================
-- BLIZZARD FRAME HIDING
-- ============================================================================

--[[
    Hide Blizzard's default party/raid frames
]]
function UnitFrames:HideBlizzardFrames()
    local db = self:GetDB()
    
    if db.hideBlizzardParty then
        -- Hide compact party frame
        if CompactPartyFrame then
            CompactPartyFrame:SetAlpha(0)
            CompactPartyFrame:SetScale(0.001)
        end
        
        -- Hide individual party frames
        for i = 1, 4 do
            local frame = _G["PartyMemberFrame" .. i]
            if frame then
                frame:SetAlpha(0)
            end
        end
    end
    
    local raidDb = self:GetRaidDB()
    
    if raidDb.hideBlizzardRaid then
        -- Hide compact raid manager
        if CompactRaidFrameManager then
            CompactRaidFrameManager:SetAlpha(0)
            CompactRaidFrameManager:SetScale(0.001)
        end
        
        -- Hide compact raid container
        if CompactRaidFrameContainer then
            CompactRaidFrameContainer:SetAlpha(0)
            CompactRaidFrameContainer:SetScale(0.001)
        end
    end
end
