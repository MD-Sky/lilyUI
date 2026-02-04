--[[
    LilyUI Unit Frames - Aura Display System
    Handles buff/debuff display with enhanced filtering
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local ForEachAura = AuraUtil and AuraUtil.ForEachAura
local UnitClass = UnitClass
local GetTime = GetTime
local CreateFrame = CreateFrame
local UnitAffectingCombat = UnitAffectingCombat
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

-- Aura cache for Blizzard filtering
local blizzardAuraCache = {}

-- ============================================================================
-- SAFE VALUE HELPERS (avoid "secret value" errors from protected aura tables)
-- ============================================================================

local function IsSecretValue(v)
    return type(v) == "userdata"
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
    if UnitFrames.DebugPrint then
        UnitFrames:DebugPrint("Auras: coerced " .. label .. " (" .. type(value) .. ") to " .. tostring(fallback))
    end
end

local function SafeNumberOrNil(v, label)
    local t = type(v)
    if t == "number" then
        local ok, value = pcall(function() return v + 0 end)
        if ok and type(value) == "number" then
            return value
        end
        if label then
            AuraDebugCoerce(label, v, nil)
        end
        return nil
    end
    if t == "userdata" then
        local ok, value = pcall(function() return tonumber(v) end)
        if ok and type(value) == "number" then
            return value
        end
        if label then
            AuraDebugCoerce(label, v, nil)
        end
        return nil
    end
    if t == "string" then
        local n = tonumber(v)
        if n then return n end
        if label then
            AuraDebugCoerce(label, v, nil)
        end
        return nil
    end
    if t ~= "nil" and label then
        AuraDebugCoerce(label, v, nil)
    end
    return nil
end

local function SafeNumber(v, default, label)
    local n = SafeNumberOrNil(v, label)
    if n ~= nil then return n end
    return default
end

local function SafeString(v, default)
    local t = type(v)
    if t == "string" then return v end
    return default
end

local function SafeRevealString(v)
    local ok, result = pcall(function()
        return string.format("%s", v)
    end)
    if not ok or type(result) ~= "string" then
        return nil
    end
    local okEmpty, isEmpty = pcall(function() return result == "" end)
    if not okEmpty or isEmpty then
        return nil
    end
    local okNoValue, isNoValue = pcall(function() return result == "<no value>" end)
    if not okNoValue or isNoValue then
        return nil
    end
    return result
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
    if UnitFrames and UnitFrames.DebugPrint then
        UnitFrames:DebugPrint(msg)
    else
        print("|cff00ccff[LilyUI]|r " .. msg)
    end
end

local function SanitizeAuraData(auraData)
    if type(auraData) ~= "table" then return nil end

    local spellId = SafeNumberOrNil(auraData.spellId, "spellId")
    if not spellId then
        spellId = SafeNumberOrNil(auraData.spellID, "spellID")
    end
    if not spellId and auraData.name and GetSpellInfo then
        local _, _, _, _, _, _, fallbackId = GetSpellInfo(auraData.name)
        spellId = SafeNumberOrNil(fallbackId, "fallbackSpellId")
    end
    if not spellId then
        DumpAuraDataKeys(auraData)
    end

    return {
        auraInstanceID = SafeNumberOrNil(auraData.auraInstanceID, "auraInstanceID"),
        spellId        = spellId,
        name           = SafeString(auraData.name, ""),
        icon           = (type(auraData.icon) == "number" or type(auraData.icon) == "string") and auraData.icon or nil,
        applications   = SafeNumber(auraData.applications or auraData.stacks, 0, "applications"),
        duration       = SafeNumber(auraData.duration or auraData.durationSeconds, 0, "duration"),
        expirationTime = SafeNumber(auraData.expirationTime or auraData.expTime, 0, "expirationTime"),
        sourceUnit     = SafeString(auraData.sourceUnit or auraData.source, ""),
        dispelName     = SafeString(auraData.dispelName, ""),
        isBossAura     = SafeBool(auraData.isBossAura),
        isHelpful      = SafeBool(auraData.isHelpful),
        isHarmful      = SafeBool(auraData.isHarmful),
    }
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

    local expTime = icon._expTime
    local duration = icon._duration
    if expTime and expTime > 0 and duration and duration > 0 then
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
    if not icon or not icon.IsShown or not icon:IsShown() then
        return false
    end

    local expTime = icon._expTime
    local totalDuration = icon._duration
    if not expTime or expTime <= 0 or not totalDuration or totalDuration <= 0 then
        if icon.duration then
            icon.duration:SetText("")
            icon.duration:Hide()
        end
        if icon.expiring then
            icon.expiring:Hide()
        end
        return false
    end

    local remaining = expTime - now
    if remaining <= 0 then
        if icon.duration then
            icon.duration:SetText("")
            icon.duration:Hide()
        end
        if icon.expiring then
            icon.expiring:Hide()
        end
        return false
    end

    if icon.showDuration and icon.duration then
        if remaining >= 3600 then
            icon.duration:SetFormattedText("%dh", floor(remaining / 3600 + 0.5))
        elseif remaining >= 60 then
            icon.duration:SetFormattedText("%dm", floor(remaining / 60 + 0.5))
        elseif remaining >= 10 then
            icon.duration:SetFormattedText("%d", floor(remaining + 0.5))
        else
            icon.duration:SetFormattedText("%.1f", remaining)
        end

        local r, g, b = UnitFrames:GetDurationColorByPercent(remaining, totalDuration)
        if icon.duration.SetTextColor then
            icon.duration:SetTextColor(r, g, b)
        end
        icon.duration:Show()
    elseif icon.duration then
        icon.duration:SetText("")
        icon.duration:Hide()
    end

    local db = icon._db or self:GetDB()
    local expiringThreshold = (db and db.auraExpiringThreshold) or 5
    if db and db.auraExpiringEnabled ~= false and remaining <= expiringThreshold then
        local pulseAlpha = (math.sin(now * 4) + 1) * 0.15
        icon.expiring:SetAlpha(pulseAlpha)
        icon.expiring:Show()
    else
        if icon.expiring then
            icon.expiring:Hide()
        end
    end

    return true
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

function UnitFrames:IsSpellIdInCombatList(list, spellId)
    local safeId = SafeNumberOrNil(spellId)
    if not safeId or type(list) ~= "table" then return false end
    if list[safeId] then return true end
    for _, id in ipairs(list) do
        local listId = SafeNumberOrNil(id)
        if listId and listId == safeId then return true end
    end
    return false
end

function UnitFrames:CombatFilterAllowsAura(auraData, auraType, db)
    local mode = db and (db.combatFilterMode or "NONE") or "NONE"
    if mode == "NONE" then return true end
    local list = (auraType == "BUFF") and db.combatBuffSpellList or db.combatDebuffSpellList
    local spellId = SafeNumberOrNil(auraData.spellId)
    local inList = self:IsSpellIdInCombatList(list, spellId)
    if mode == "WHITELIST" then
        return inList
    elseif mode == "BLACKLIST" then
        return not inList
    end
    return true
end

function UnitFrames:GetCombatFilterDecision(auraData, auraType, db)
    db = db or self:GetDB()
    local enabled = db.combatFilterEnabled
    local mode = db.combatFilterMode or "NONE"
    local appliesTo = db.combatFilterAppliesTo or "BOTH"

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

    local list = (auraType == "BUFF") and db.combatBuffSpellList or db.combatDebuffSpellList
    local spellId = SafeNumberOrNil(auraData.spellId)
    local inList = self:IsSpellIdInCombatList(list, spellId)

    if mode == "WHITELIST" then
        return inList, inList and "filter whitelist hit" or "filter whitelist miss"
    elseif mode == "BLACKLIST" then
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
    local filterId = SafeNumberOrNil(db.combatAuraDebugSpellId)
    if filterId and filterId > 0 and spellId ~= filterId then
        return false
    end
    return true
end

function UnitFrames:LogCombatAura(db, auraType, spellId, duration, expTime, decision, reason, showText, showSwipe)
    if not self:ShouldDebugCombatAura(spellId, db) then return end

    local now = GetTime()
    local key = spellId or 0
    local last = self._combatAuraDebugLast[key] or 0
    local throttle = self._combatAuraDebugThrottle or 0.75
    if (now - last) < throttle then return end
    self._combatAuraDebugLast[key] = now

    local spellName = (spellId and GetSpellInfo and GetSpellInfo(spellId)) or "?"
    local remaining = (expTime and expTime > 0) and (expTime - now) or nil

    local filterEnabled = db and db.combatFilterEnabled
    local filterMode = db and db.combatFilterMode or "NONE"
    local appliesTo = db and db.combatFilterAppliesTo or "BOTH"
    local displayMode = self:GetCombatDisplayMode(db)

    local msg = string.format(
        "combat=%s | type=%s | spell=%s (%s) | filter=%s/%s/%s | display=%s | dur=%s exp=%s rem=%s | decision=%s (%s) | text=%s swipe=%s",
        tostring(self:IsPlayerInCombat()),
        tostring(auraType or "?"),
        tostring(spellName),
        tostring(spellId or "nil"),
        tostring(filterEnabled),
        tostring(filterMode),
        tostring(appliesTo),
        tostring(displayMode),
        tostring(duration or "nil"),
        tostring(expTime or "nil"),
        remaining and string.format("%.1f", remaining) or "nil",
        tostring(decision or "UNKNOWN"),
        tostring(reason or "n/a"),
        tostring(showText),
        tostring(showSwipe)
    )

    self:Print("|cff00ccff[AuraDebug]|r " .. msg)
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
                self:LogCombatAura(db, auraType, SafeNumberOrNil(auraData.spellId), dur, exp, "HIDDEN", "blizzard filter", showText, showSwipe)
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
        self:LogCombatAura(db, auraType, SafeNumberOrNil(auraData.spellId), dur, exp, "HIDDEN", "smart filter", showText, showSwipe)
    end
    return smartShown
end

function UnitFrames:ShouldShowAura(auraData, unit, auraType, db)
    if not auraData then return false end

    db = db or self:GetDB()
    local inCombat = self:IsPlayerInCombat()
    local combatEnabled = db.combatFilterEnabled == true

    -- Base filtering (smart/whitelist/blacklist/blizzard) stays intact.
    local baseShown = self:ShouldShowAura_Base(auraData, unit, auraType, db, inCombat and combatEnabled)
    if not inCombat or not combatEnabled then
        return baseShown
    end

    local mode = db.combatFilterMode or "NONE"
    if mode == "NONE" then
        return baseShown
    end

    local list = (auraType == "BUFF") and db.combatBuffSpellList or db.combatDebuffSpellList
    local spellId = SafeNumberOrNil(auraData.spellId)
    local inList = self:IsSpellIdInCombatList(list, spellId)

    if mode == "WHITELIST" then
        if baseShown and not inList then
            local showText, showSwipe = self:GetAuraDisplayFlags(db)
            local dur = SafeNumber(auraData.duration, 0)
            local exp = SafeNumberOrNil(auraData.expirationTime)
            self:LogCombatAura(db, auraType, spellId, dur, exp, "HIDDEN", "combat whitelist miss", showText, showSwipe)
        end
        return baseShown and inList
    elseif mode == "BLACKLIST" then
        if baseShown and inList then
            local showText, showSwipe = self:GetAuraDisplayFlags(db)
            local dur = SafeNumber(auraData.duration, 0)
            local exp = SafeNumberOrNil(auraData.expirationTime)
            self:LogCombatAura(db, auraType, spellId, dur, exp, "HIDDEN", "combat blacklist hit", showText, showSwipe)
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
    db = db or self:GetDB()
    
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
        
        -- Show debuffs with significant duration
        local dur = SafeNumber(auraData.duration, 0)
        local exp = SafeNumberOrNil(auraData.expirationTime)
        if dur > 0 and exp and exp > 0 then
            local remaining = exp - GetTime()
            if remaining > 5 then
                return true
            end
        end
        
        -- Show debuffs that reduce stats significantly
        -- (This would normally check specific spell IDs)
        
        return false
    else
        -- Buffs
        
        -- Show buffs cast by player
        if db.showPlayerBuffs and SafeString(auraData.sourceUnit, "") == "player" then
            return true
        end
        
        -- Show short duration buffs (likely important cooldowns)
        local dur2 = SafeNumber(auraData.duration, 0)
        if dur2 > 0 and dur2 < 30 then
            return true
        end
        
        -- Show buffs with stacks (tracking buffs)
        local stacks = SafeNumber(auraData.applications, 0)
        if stacks > 0 then
            return true
        end
        
        -- Hide very long duration buffs (food, flasks, etc.)
        local durHide = SafeNumber(auraData.duration, 0)
        if durHide > 3600 then
            return false
        end
        
        return true
    end
end

-- ============================================================================
-- AURA DATA COLLECTION
-- ============================================================================

--[[
    @param unit string - Unit ID
    @param auraType string - "BUFF" or "DEBUFF"
    @return table - Array of aura data
]]
function UnitFrames:CollectAuras(unit, auraType, db)
    db = db or self:GetDB()
    local auras = {}
    local filter = auraType == "BUFF" and "HELPFUL" or "HARMFUL"
    
    if ForEachAura then
        -- Use AuraUtil.ForEachAura for modern API
        ForEachAura(unit, filter, nil, function(auraData)
            local safeAura = SanitizeAuraData(auraData)
            if safeAura and self:ShouldShowAura(safeAura, unit, auraType, db) then
                table.insert(auras, safeAura)
            end
            return false  -- Continue iteration
        end, true)  -- Use the full aura data
    else
        -- Fallback for older API
        local index = 1
        while true do
            local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal,
                spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod, value1, value2, value3,
                auraInstanceID = UnitAura(unit, index, filter)
            if not name then break end

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

            local safeAura = SanitizeAuraData(auraData)
            if safeAura and self:ShouldShowAura(safeAura, unit, auraType, db) then
                table.insert(auras, safeAura)
            end

            index = index + 1
        end
    end
    
    -- Sort auras
    self:SortAuras(auras, auraType, db)
    
    return auras
end

--[[
    Sort auras by priority
    @param auras table - Array of aura data
    @param auraType string - "BUFF" or "DEBUFF"
]]
function UnitFrames:SortAuras(auras, auraType, db)
    db = db or self:GetDB()
    local sortMethod = db[(auraType == "BUFF" and "buff" or "debuff") .. "SortMethod"] or "TIME"

    -- Retail can return some aura fields as "secret values" (userdata). These cannot be
    -- compared (==, ~=, <, >) or used in arithmetic. So we coerce values into plain Lua
    -- booleans/numbers/strings before sorting.
    local function asBool(v)
        local t = type(v)
        if t == "nil" or t == "userdata" then return false end
        if t == "boolean" then return v end
        return true
    end
    local function asNumberOrNil(v)
        return (type(v) == "number") and v or nil
    end
    local function asString(v)
        return (type(v) == "string") and v or ""
    end

    table.sort(auras, function(a, b)
        -- Boss auras first (safe boolean compare)
        local aBoss = SafeBool(a.isBossAura)
        local bBoss = SafeBool(b.isBossAura)
        if aBoss ~= bBoss then
            return aBoss
        end

        -- Then by sort method (only do arithmetic on real numbers)
        if sortMethod == "TIME" then
            local now = GetTime()
            local aExp = SafeNumberOrNil(a.expirationTime)
            local bExp = SafeNumberOrNil(b.expirationTime)
            local aRemaining = (aExp and aExp > 0) and (aExp - now) or 999999
            local bRemaining = (bExp and bExp > 0) and (bExp - now) or 999999
            return aRemaining < bRemaining
        elseif sortMethod == "DURATION" then
            local aDur = SafeNumber(a.duration, 0) or 999999
            local bDur = SafeNumber(b.duration, 0) or 999999
            return aDur < bDur
        elseif sortMethod == "NAME" then
            return asString(a.name) < asString(b.name)
        end

        return false
    end)
end

-- ============================================================================
-- AURA ICON MANAGEMENT
-- ============================================================================

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
    
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(size, size)
    icon.auraType = auraType
    icon.index = index
    
    -- Icon texture
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
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
    
    -- Tooltip
    icon:EnableMouse(true)
    icon:SetScript("OnEnter", function(self)
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellId)
            GameTooltip:Show()
        elseif self.auraInfo then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:Show()
        end
    end)
    
    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
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

    if frameType ~= "party" then
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

    if frameType ~= "party" then
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
    local auras = self:CollectAuras(frame.unit, auraType, db)
    local maxIcons = db[prefix .. "MaxIcons"] or 8
    
    -- Ensure we have enough icons
    self:EnsureAuraIcons(frame, auraType, maxIcons)
    
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons
    
    -- Update each icon
    for i = 1, maxIcons do
        local icon = icons[i]
        local auraData = auras[i]
        
        if icon and auraData then
            self:UpdateSingleAuraIcon(icon, auraData, db)
            icon:Show()
            self:_RegisterAuraDurationIcon(icon)
        elseif icon then
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

function UnitFrames:UpdateSingleAuraIcon(icon, auraData, db)
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
    icon.spellId = SafeNumberOrNil(auraData.spellId) or auraData.spellId

    local showText, showSwipe = self:GetAuraDisplayFlags(db)
    icon.showDuration = showText
    
    if not expStore or expStore <= 0 or not durStore or durStore <= 0 then
        if icon.duration then
            icon.duration:SetText("")
            icon.duration:Hide()
        end
        if icon.expiring then
            icon.expiring:Hide()
        end
    end


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
    local stacks = SafeNumber(auraData.applications, 0)
    if stacks >= (icon.stackMinimum or 2) then
        icon.count:SetText(stacks)
        icon.count:Show()
    else
        icon.count:SetText("")
        icon.count:Hide()
    end
    
    -- Update cooldown
    local dur = durStore
    local exp = expStore
    if showSwipe and dur > 0 and exp and exp > 0 then
        local startTime = exp - dur
        if icon.cooldown.SetDrawSwipe then
            icon.cooldown:SetDrawSwipe(true)
        end
        icon.cooldown:SetCooldown(startTime, dur)
        icon.cooldown:Show()
    else
        if icon.cooldown.SetDrawSwipe then
            icon.cooldown:SetDrawSwipe(false)
        end
        icon.cooldown:Hide()
    end

    if not showText and icon.duration then
        icon.duration:SetText("")
        icon.duration:Hide()
    end

    do
        local reason = "shown"
        if self:IsPlayerInCombat() then
            local _, filterReason = self:GetCombatFilterDecision(auraData, icon.auraType, db)
            reason = filterReason
        end
        if durStore <= 0 or not expStore or expStore <= 0 then
            reason = reason .. "; no duration"
        end
        self:LogCombatAura(db, icon.auraType, icon.spellId, durStore, expStore, "SHOWN", reason, showText, showSwipe)
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
-- COMBAT STATE REFRESH
-- ============================================================================

local function SetupCombatAuraRefresh()
    if UnitFrames._combatEventFrame then return end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        UnitFrames._combatState = (event == "PLAYER_REGEN_DISABLED")
        if UnitFrames.RefreshAuraIcons then
            UnitFrames:RefreshAuraIcons()
        end
    end)

    UnitFrames._combatEventFrame = frame
end

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
