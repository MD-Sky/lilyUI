--[[
    LilyUI Unit Frames - Color System
    Handles health bar colors, gradients, and color modes
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitClass = UnitClass
local UnitReaction = UnitReaction

-- ============================================================================
-- COLOR MODES
-- ============================================================================

local COLOR_MODES = {
    CLASS = "class",
    GRADIENT = "gradient",
    REACTION = "reaction",
    CUSTOM = "custom",
}

UnitFrames.COLOR_MODES = COLOR_MODES

-- ============================================================================
-- DEFAULT COLORS
-- ============================================================================

-- Reaction colors (for NPCs)
local ReactionColors = {
    [1] = {r = 0.90, g = 0.0, b = 0.0},   -- Exceptionally hostile
    [2] = {r = 0.90, g = 0.0, b = 0.0},   -- Hostile
    [3] = {r = 0.90, g = 0.45, b = 0.0},  -- Unfriendly
    [4] = {r = 0.90, g = 0.90, b = 0.0},  -- Neutral
    [5] = {r = 0.0, g = 0.90, b = 0.0},   -- Friendly
    [6] = {r = 0.0, g = 0.90, b = 0.0},   -- Honored
    [7] = {r = 0.0, g = 0.90, b = 0.0},   -- Revered
    [8] = {r = 0.0, g = 0.90, b = 0.0},   -- Exalted
}

-- Gradient presets
local GradientPresets = {
    -- Red to Green (classic health)
    default = {
        low = {r = 0.90, g = 0.0, b = 0.0},
        mid = {r = 0.90, g = 0.90, b = 0.0},
        high = {r = 0.0, g = 0.90, b = 0.0},
    },
    -- Blue to Cyan (mana style)
    cool = {
        low = {r = 0.0, g = 0.0, b = 0.90},
        mid = {r = 0.0, g = 0.45, b = 0.90},
        high = {r = 0.0, g = 0.90, b = 0.90},
    },
    -- Purple to Pink
    mystic = {
        low = {r = 0.50, g = 0.0, b = 0.50},
        mid = {r = 0.75, g = 0.0, b = 0.75},
        high = {r = 1.0, g = 0.4, b = 0.8},
    },
    -- Orange to Yellow
    warm = {
        low = {r = 0.80, g = 0.20, b = 0.0},
        mid = {r = 0.90, g = 0.60, b = 0.0},
        high = {r = 1.0, g = 0.90, b = 0.0},
    },
}

UnitFrames.ReactionColors = ReactionColors
UnitFrames.GradientPresets = GradientPresets

-- ============================================================================
-- COLOR INTERPOLATION
-- ============================================================================

--[[
    Linearly interpolate between two colors
    @param c1 table - First color {r, g, b}
    @param c2 table - Second color {r, g, b}
    @param t number - Interpolation factor (0-1)
    @return number, number, number - Interpolated r, g, b
]]
function UnitFrames:LerpColor(c1, c2, t)
    t = math.max(0, math.min(1, t))
    return
        c1.r + (c2.r - c1.r) * t,
        c1.g + (c2.g - c1.g) * t,
        c1.b + (c2.b - c1.b) * t
end

--[[
    Get gradient color based on health percentage
    @param healthPct number - Health percentage (0-1)
    @param preset string|table - Gradient preset name or custom gradient table
    @return number, number, number - r, g, b
]]
function UnitFrames:GetGradientColor(healthPct, preset)
    local gradient
    
    if type(preset) == "string" then
        gradient = GradientPresets[preset] or GradientPresets.default
    elseif type(preset) == "table" then
        gradient = preset
    else
        gradient = GradientPresets.default
    end
    
    healthPct = math.max(0, math.min(1, healthPct))
    
    if healthPct <= 0.5 then
        -- Interpolate from low to mid
        local t = healthPct * 2
        return self:LerpColor(gradient.low, gradient.mid, t)
    else
        -- Interpolate from mid to high
        local t = (healthPct - 0.5) * 2
        return self:LerpColor(gradient.mid, gradient.high, t)
        end
    end
    
-- ============================================================================
-- CLASS COLOR HANDLING
-- ============================================================================

--[[
    Get class color for a unit
    @param unit string - Unit ID
    @return number, number, number - r, g, b
]]
function UnitFrames:GetClassColor(unit)
    local _, class = UnitClass(unit)
    
    if class and RAID_CLASS_COLORS[class] then
        local color = RAID_CLASS_COLORS[class]
        return color.r, color.g, color.b
    end
    
    -- Fallback gray
    return 0.5, 0.5, 0.5
end

--[[
    Get reaction color for a unit
    @param unit string - Unit ID
    @return number, number, number - r, g, b
]]
function UnitFrames:GetReactionColor(unit)
    local reaction = UnitReaction(unit, "player")
    
    if reaction and ReactionColors[reaction] then
        local color = ReactionColors[reaction]
        return color.r, color.g, color.b
    end
    
    -- Fallback gray for unknown
    return 0.5, 0.5, 0.5
end

-- ============================================================================
-- HEALTH BAR COLOR APPLICATION
-- ============================================================================

--[[
    Apply appropriate color to a health bar based on settings
    @param frame table - The unit frame containing the health bar
]]
function UnitFrames:ApplyHealthColors(frame)
    if not frame or not frame.healthBar or not frame.unit then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local colorMode = db.healthBarColorMode or "CLASS"
    local unit = frame.unit
    
    local r, g, b = 0.5, 0.5, 0.5
    
    if colorMode == "CLASS" then
        r, g, b = self:GetClassColor(unit)
        
    elseif colorMode == "GRADIENT" then
        -- Use dot notation since GetSafeHealthPercent only takes unit as parameter
        local healthPct = self.GetSafeHealthPercent and self.GetSafeHealthPercent(unit)
        if type(healthPct) == "number" then
            healthPct = healthPct / 100
        else
            healthPct = 1
        end
        
        local gradientPreset = db.gradientPreset or "default"
        
        -- Check for custom gradient
        if db.useCustomGradient and db.customGradient then
            r, g, b = self:GetGradientColor(healthPct, db.customGradient)
        else
            r, g, b = self:GetGradientColor(healthPct, gradientPreset)
        end
        
    elseif colorMode == "REACTION" then
        r, g, b = self:GetReactionColor(unit)
        
    elseif colorMode == "CUSTOM" then
        local customColor = db.healthBarCustomColor or {r = 0.2, g = 0.8, b = 0.2}
        r, g, b = customColor.r, customColor.g, customColor.b
        
    elseif colorMode == "GRADIENT_CLASS" then
        -- Gradient tinted by class color
        -- Use dot notation since GetSafeHealthPercent only takes unit as parameter
        local healthPct = self.GetSafeHealthPercent and self.GetSafeHealthPercent(unit)
        if type(healthPct) == "number" then
            healthPct = healthPct / 100
        else
            healthPct = 1
        end
        
        local classR, classG, classB = self:GetClassColor(unit)
        local gradR, gradG, gradB = self:GetGradientColor(healthPct, "default")
        
        -- Blend class color with gradient
        local blendFactor = db.gradientClassBlend or 0.5
        r = classR * blendFactor + gradR * (1 - blendFactor)
        g = classG * blendFactor + gradG * (1 - blendFactor)
        b = classB * blendFactor + gradB * (1 - blendFactor)
    end
    
    -- Apply color
    frame.healthBar:SetStatusBarColor(r, g, b)
    
    -- Update missing health bar if present
    if frame.healthBarBG and db.missingHealthEnabled then
        local missingColor = db.missingHealthColor or {r = 0.2, g = 0, b = 0}
        frame.healthBarBG:SetStatusBarColor(missingColor.r, missingColor.g, missingColor.b)
    end
    
    -- Store current color for other uses
    frame.currentHealthColor = {r = r, g = g, b = b}
end

-- ============================================================================
-- BACKGROUND COLOR
-- ============================================================================

--[[
    Apply background color to a frame
    @param frame table - The unit frame
]]
function UnitFrames:ApplyBackgroundColor(frame)
    if not frame or not frame.background then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local colorMode = db.backgroundColorMode or "CUSTOM"
    
    local r, g, b, a = 0.1, 0.1, 0.1, 0.8
    
    if colorMode == "CLASS" then
        local classR, classG, classB = self:GetClassColor(frame.unit)
        local alpha = db.backgroundClassAlpha or 0.3
        r, g, b, a = classR, classG, classB, alpha
        
    elseif colorMode == "HEALTH" then
        -- Darken the health color for background
        if frame.currentHealthColor then
            r = frame.currentHealthColor.r * 0.3
            g = frame.currentHealthColor.g * 0.3
            b = frame.currentHealthColor.b * 0.3
            a = db.backgroundAlpha or 0.8
        end
        
    else
        local customColor = db.backgroundColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
        r, g, b = customColor.r, customColor.g, customColor.b
        a = customColor.a or 0.8
    end
    
    frame.background:SetColorTexture(r, g, b, a)
end

-- ============================================================================
-- DEBUFF TYPE COLORS
-- ============================================================================

local DebuffTypeColors = {
    Magic = {r = 0.2, g = 0.6, b = 1.0},
    Curse = {r = 0.6, g = 0.0, b = 1.0},
    Disease = {r = 0.6, g = 0.4, b = 0.0},
    Poison = {r = 0.0, g = 0.6, b = 0.0},
    [""] = {r = 0.8, g = 0.0, b = 0.0},  -- Physical/None
}

UnitFrames.DebuffTypeColors = DebuffTypeColors

--[[
    Get color for a debuff type
    @param debuffType string - Type of debuff (Magic, Curse, Disease, Poison, or empty)
    @return number, number, number - r, g, b
]]
function UnitFrames:GetDebuffTypeColor(debuffType)
    local color = DebuffTypeColors[debuffType or ""]
    if color then
        return color.r, color.g, color.b
    end
    return 0.8, 0.0, 0.0
end

-- ============================================================================
-- POWER TYPE COLORS
-- ============================================================================

local PowerTypeColors = {
    [Enum.PowerType.Mana] = {r = 0.0, g = 0.0, b = 1.0},
    [Enum.PowerType.Rage] = {r = 1.0, g = 0.0, b = 0.0},
    [Enum.PowerType.Focus] = {r = 1.0, g = 0.5, b = 0.25},
    [Enum.PowerType.Energy] = {r = 1.0, g = 1.0, b = 0.0},
    [Enum.PowerType.ComboPoints] = {r = 1.0, g = 0.96, b = 0.41},
    [Enum.PowerType.Runes] = {r = 0.5, g = 0.5, b = 0.5},
    [Enum.PowerType.RunicPower] = {r = 0.0, g = 0.82, b = 1.0},
    [Enum.PowerType.SoulShards] = {r = 0.5, g = 0.32, b = 0.55},
    [Enum.PowerType.LunarPower] = {r = 0.3, g = 0.52, b = 0.9},
    [Enum.PowerType.HolyPower] = {r = 0.95, g = 0.9, b = 0.6},
    [Enum.PowerType.Maelstrom] = {r = 0.0, g = 0.5, b = 1.0},
    [Enum.PowerType.Chi] = {r = 0.71, g = 1.0, b = 0.92},
    [Enum.PowerType.Insanity] = {r = 0.4, g = 0.0, b = 0.8},
    [Enum.PowerType.ArcaneCharges] = {r = 0.1, g = 0.1, b = 0.98},
    [Enum.PowerType.Fury] = {r = 0.788, g = 0.259, b = 0.992},
    [Enum.PowerType.Pain] = {r = 1.0, g = 0.612, b = 0.0},
    [Enum.PowerType.Essence] = {r = 0.513, g = 0.937, b = 0.435},
}

UnitFrames.PowerTypeColors = PowerTypeColors

--[[
    Get color for a power type
    @param powerType number - Power type enum value
    @return number, number, number - r, g, b
]]
function UnitFrames:GetPowerTypeColor(powerType)
    local color = PowerTypeColors[powerType]
    if color then
        return color.r, color.g, color.b
    end
    return 0.5, 0.5, 0.5
end

-- ============================================================================
-- COLOR UTILITY FUNCTIONS
-- ============================================================================

--[[
    Convert RGB to HSV
    @param r number - Red (0-1)
    @param g number - Green (0-1)
    @param b number - Blue (0-1)
    @return number, number, number - Hue (0-360), Saturation (0-1), Value (0-1)
]]
function UnitFrames:RGBtoHSV(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min
    
    local h, s, v
    v = max
    
    if max == 0 then
        s = 0
    else
        s = delta / max
    end
    
    if delta == 0 then
        h = 0
    elseif max == r then
        h = 60 * ((g - b) / delta % 6)
    elseif max == g then
        h = 60 * ((b - r) / delta + 2)
    else
        h = 60 * ((r - g) / delta + 4)
    end
    
    return h, s, v
end

--[[
    Convert HSV to RGB
    @param h number - Hue (0-360)
    @param s number - Saturation (0-1)
    @param v number - Value (0-1)
    @return number, number, number - Red, Green, Blue (0-1)
]]
function UnitFrames:HSVtoRGB(h, s, v)
    if s == 0 then
        return v, v, v
    end
    
    h = h / 60
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q
    end
end

--[[
    Darken a color by a factor
    @param r number - Red (0-1)
    @param g number - Green (0-1)
    @param b number - Blue (0-1)
    @param factor number - Darkening factor (0-1, where 1 is black)
    @return number, number, number - Darkened r, g, b
]]
function UnitFrames:DarkenColor(r, g, b, factor)
    factor = 1 - (factor or 0.3)
    return r * factor, g * factor, b * factor
end

--[[
    Lighten a color by a factor
    @param r number - Red (0-1)
    @param g number - Green (0-1)
    @param b number - Blue (0-1)
    @param factor number - Lightening factor (0-1, where 1 is white)
    @return number, number, number - Lightened r, g, b
]]
function UnitFrames:LightenColor(r, g, b, factor)
    factor = factor or 0.3
    return
        r + (1 - r) * factor,
        g + (1 - g) * factor,
        b + (1 - b) * factor
end

--[[
    Desaturate a color
    @param r number - Red (0-1)
    @param g number - Green (0-1)
    @param b number - Blue (0-1)
    @param factor number - Desaturation factor (0-1, where 1 is grayscale)
    @return number, number, number - Desaturated r, g, b
]]
function UnitFrames:DesaturateColor(r, g, b, factor)
    factor = factor or 0.5
    local gray = 0.3 * r + 0.59 * g + 0.11 * b
    return
        r + (gray - r) * factor,
        g + (gray - g) * factor,
        b + (gray - b) * factor
end
