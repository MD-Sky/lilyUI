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
    if t == "boolean" then return v end
    return true
end

local function SafeNumberOrNil(v)
    local t = type(v)
    if t == "number" then return v end
    if t == "string" then
        local n = tonumber(v)
        if n then return n end
    end
    return nil
end

local function SafeNumber(v, default)
    local n = SafeNumberOrNil(v)
    if n ~= nil then return n end
    return default
end

local function SafeString(v, default)
    local t = type(v)
    if t == "string" then return v end
    return default
end


local function SanitizeAuraData(auraData)
    if type(auraData) ~= "table" then return nil end

    -- Strip any protected/secret userdata values by copying only safe primitives.
    return {
        auraInstanceID = SafeNumberOrNil(auraData.auraInstanceID),
        name = SafeString(auraData.name, ""),
        icon = (type(auraData.icon) == "number" or type(auraData.icon) == "string") and auraData.icon or nil,
        spellId = SafeNumberOrNil(auraData.spellId),
        applications = SafeNumber(auraData.applications, 0),
        duration = SafeNumber(auraData.duration, 0),
        expirationTime = SafeNumber(auraData.expirationTime, 0),
        sourceUnit = SafeString(auraData.sourceUnit, ""),
        dispelName = SafeString(auraData.dispelName, ""),
        isBossAura = SafeBool(auraData.isBossAura),
        isStealable = SafeBool(auraData.isStealable),
        isHarmful = SafeBool(auraData.isHarmful),
        isHelpful = SafeBool(auraData.isHelpful),
    }
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

--[[
    Check if player can dispel a debuff type
    @param debuffType string - The type of debuff (Magic, Curse, Disease, Poison)
    @return boolean
]]
function UnitFrames:CanDispelDebuffType(debuffType)
    if not debuffType then return false end
    
    local _, playerClass = UnitClass("player")
    local dispellable = DispellableByClass[playerClass]
    
    return dispellable and dispellable[debuffType]
end

--[[
    Check if an aura should be shown based on filter settings
    @param unit string - Unit ID
    @param auraType string - "BUFF" or "DEBUFF"
    @return boolean
]]
function UnitFrames:ShouldShowAura(auraData, unit, auraType)
    if not auraData then return false end
    
    local db = self:GetDB()
    local prefix = auraType == "BUFF" and "buff" or "debuff"
    local filterMode = db[prefix .. "FilterMode"] or "SMART"
    
    -- All mode - show everything
    if filterMode == "ALL" then
        return true
    end
    
    -- Blizzard mode - use cached decisions
    if filterMode == "BLIZZARD" then
        local cache = blizzardAuraCache[unit]
        if cache then
            local cacheTable = auraType == "BUFF" and cache.buffs or cache.debuffs
            return cacheTable[auraData.auraInstanceID] == true
        end
        -- Fallback to smart if no cache
        filterMode = "SMART"
    end
    
    -- Whitelist mode
    if filterMode == "WHITELIST" then
        local whitelist = db[prefix .. "Whitelist"] or {}


            if auraData and type(auraData.spellId) == "number" and auraData.spellId == 8936 then
                icon:SetTexture(auraData.icon)
            end
                icon:SetTexture(auraData.icon)
                icon:Show()
            end
            end
    
    -- Blacklist mode
    if filterMode == "BLACKLIST" then
        local blacklist = db[prefix .. "Blacklist"] or {}


            if auraData and type(auraData.spellId) == "number" and auraData.spellId == 8936 then
                icon:SetTexture(auraData.icon)
            end
                icon:SetTexture(auraData.icon)
                icon:Show()
            end
                    return false
        end
        -- If not blacklisted, use smart filtering
    end
    
    -- Smart mode - intelligent filtering
    return self:SmartFilterAura(auraData, unit, auraType)
end

--[[
    Smart aura filtering logic
    @param unit string - Unit ID
    @param auraType string - "BUFF" or "DEBUFF"
    @return boolean
]]
function UnitFrames:SmartFilterAura(auraData, unit, auraType)
    local db = self:GetDB()
    
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
        if dur > 0 and exp > 0 then
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
function UnitFrames:CollectAuras(unit, auraType)
    local auras = {}
    local filter = auraType == "BUFF" and "HELPFUL" or "HARMFUL"
    
    if ForEachAura then
        -- Use AuraUtil.ForEachAura for modern API
        ForEachAura(unit, filter, nil, function(auraData)
            local safeAura = SanitizeAuraData(auraData)
            if safeAura and self:ShouldShowAura(safeAura, unit, auraType) then
                table.insert(auras, safeAura)
            end
            return false  -- Continue iteration
        end, true)  -- Use the full aura data
    else
        -- Fallback for older API
        local index = 1
        while true do
            if not name then break end
            
            local auraData = {
                name = name,
                icon = icon,
                applications = count,
                dispelName = dispelType,
                duration = duration,
                sourceUnit = source,
                spellId = spellId,
            }
            
            if self:ShouldShowAura(auraData, unit, auraType) then
                table.insert(auras, auraData)
            end
            
            index = index + 1
        end
    end
    
    -- Sort auras
    self:SortAuras(auras, auraType)
    
    return auras
end

--[[
    Sort auras by priority
    @param auras table - Array of aura data
    @param auraType string - "BUFF" or "DEBUFF"
]]
function UnitFrames:SortAuras(auras, auraType)
    local db = self:GetDB()
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
            local aRemaining = aExp and (aExp - now) or 999999
            local bRemaining = bExp and (bExp - now) or 999999
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
    
    -- Stack count
    icon.count = icon:CreateFontString(nil, "OVERLAY")
    icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    -- Apply per-type text sizing (Buffs vs Debuffs)
    local prefixText = (auraType == "BUFF") and "buff" or "debuff"
    local textSize = db[prefixText .. "TextSize"] or db.auraStackSize or 10
    local durationSize = db[prefixText .. "TextSize"] or db.auraDurationSize or 9

    self:SafeSetFont(icon.count, self:GetFontPath(db.auraStackFont), textSize, db.auraStackOutline or "OUTLINE")
    icon.count:SetJustifyH("RIGHT")

    -- Duration text
    icon.duration = icon:CreateFontString(nil, "OVERLAY")
    icon.duration:SetPoint("TOP", icon, "BOTTOM", 0, -1)
    self:SafeSetFont(icon.duration, self:GetFontPath(db.auraDurationFont), math.max(6, durationSize - 1), db.auraDurationOutline or "OUTLINE")
    icon.duration:SetJustifyH("CENTER")
    
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
    
    -- OnUpdate for duration
    
icon:SetScript("OnUpdate", function(self, elapsed)
    local exp = self.expirationTime or 0
    local dur = self.auraDuration or 0

    if exp <= 0 or dur <= 0 then
        if self.showDuration then
            self.duration:SetText("")
        end
        self.expiring:Hide()
        return
    end

    local remaining = exp - GetTime()
    if remaining <= 0 then
        if self.showDuration then
            self.duration:SetText("")
        end
        self.expiring:Hide()
        return
    end

    -- Update duration text
    if self.showDuration then
        if remaining >= 3600 then
            self.duration:SetFormattedText("%dh", math.floor(remaining / 3600 + 0.5))
        elseif remaining >= 60 then
            self.duration:SetFormattedText("%dm", math.floor(remaining / 60 + 0.5))
        elseif remaining >= 10 then
            self.duration:SetFormattedText("%d", math.floor(remaining + 0.5))
        else
            self.duration:SetFormattedText("%.1f", remaining)
        end

        local r, g, b = UnitFrames:GetDurationColorByPercent(remaining, dur)
        if self.duration.SetTextColor then
            self.duration:SetTextColor(r, g, b)
        end
    else
        self.duration:SetText("")
    end

    -- Expiring indicator pulse
    local expiringThreshold = db.auraExpiringThreshold or 5
    if remaining <= expiringThreshold then
        local pulseAlpha = (math.sin(GetTime() * 4) + 1) * 0.15
        self.expiring:SetAlpha(pulseAlpha)
        self.expiring:Show()
    else
        self.expiring:Hide()
    end
end)

    
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
    local auras = self:CollectAuras(frame.unit, auraType)
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
        elseif icon then
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

function UnitFrames:UpdateSingleAuraIcon(icon, auraData, db)
    if not icon or type(auraData) ~= "table" then return end

    -- Texture
    if icon.texture and auraData.icon then
        icon.texture:SetTexture(auraData.icon)
    end

    -- Safe storage for tooltips and OnUpdate
    icon.auraInfo = SanitizeAuraData(auraData)
    icon.spellId = SafeNumberOrNil(auraData.spellId)
    icon.auraDuration = SafeNumber(auraData.duration, 0)
    icon.expirationTime = SafeNumber(auraData.expirationTime, 0)

    -- Apply per-type text sizing (Buffs vs Debuffs)
    local prefixText = (icon.auraType == "BUFF") and "buff" or "debuff"
    local textSize = db[prefixText .. "TextSize"] or db.auraStackSize or 10
    local durationSize = db[prefixText .. "TextSize"] or db.auraDurationSize or 9

    self:SafeSetFont(icon.count, self:GetFontPath(db.auraStackFont), textSize, db.auraStackOutline)
    self:SafeSetFont(icon.duration, self:GetFontPath(db.auraDurationFont), math.max(6, durationSize - 1), db.auraDurationOutline)

    -- Stack count
    local stacks = SafeNumber(auraData.applications, 0)
    if stacks >= (icon.stackMinimum or 2) then
        icon.count:SetText(stacks)
        icon.count:Show()
    else
        icon.count:SetText("")
        icon.count:Hide()
    end

    -- Cooldown swipe
    local dur = icon.auraDuration or 0
    local exp = icon.expirationTime or 0
    if dur > 0 and exp > 0 and icon.cooldown and icon.cooldown.SetCooldown then
        local startTime = exp - dur
        icon.cooldown:SetCooldown(startTime, dur)
        icon.cooldown:Show()
    elseif icon.cooldown then
        icon.cooldown:Hide()
    end

    -- Debuff border
    if icon.border then
        if icon.auraType == "DEBUFF" then
            local color = UnitFrames.DebuffTypeColors and (UnitFrames.DebuffTypeColors[auraData.dispelName] or UnitFrames.DebuffTypeColors[""])
            if color then
                icon.border:SetVertexColor(color.r, color.g, color.b, 1)
                icon.border:Show()
            else
                icon.border:Hide()
            end
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
function UnitFrames:HideAllAuraIcons(frame, auraType)
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons
    
    if icons then
        for _, icon in ipairs(icons) do
            icon:Hide()
        end
    end
end

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
