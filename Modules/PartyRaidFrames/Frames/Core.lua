--[[
    LilyUI Unit Frames - Core Frame Module
    Contains frame storage, external API, and core frame utilities
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local pairs, ipairs, type = pairs, ipairs, type
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local format = string.format
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitClass = UnitClass
local UnitName = UnitName
local GetTime = GetTime

-- Curve constants for WoW 12.0+ API
-- NOTE: CurveConstants is a GLOBAL table in WoW, not under Enum
local ScaleTo100 = CurveConstants and CurveConstants.ScaleTo100

-- ============================================================================
-- FRAME STORAGE INITIALIZATION
-- Ensure frame containers exist
-- ============================================================================

UnitFrames.partyFrames = UnitFrames.partyFrames or {}
UnitFrames.playerFrame = UnitFrames.playerFrame or nil
UnitFrames.container = UnitFrames.container or nil
UnitFrames.raidFrames = UnitFrames.raidFrames or {}
UnitFrames.raidContainer = UnitFrames.raidContainer or nil
UnitFrames.raidGroupContainers = UnitFrames.raidGroupContainers or {}
UnitFrames.raidRowColContainers = UnitFrames.raidRowColContainers or {}
UnitFrames.raidGroupsContainer = UnitFrames.raidGroupsContainer or nil
UnitFrames.petFrames = UnitFrames.petFrames or {}
UnitFrames.partyPetFrames = UnitFrames.partyPetFrames or {}
UnitFrames.raidPetFrames = UnitFrames.raidPetFrames or {}
UnitFrames.moverFrame = UnitFrames.moverFrame or nil
UnitFrames.raidMoverFrame = UnitFrames.raidMoverFrame or nil
UnitFrames.partyGroupContainer = UnitFrames.partyGroupContainer or nil
UnitFrames.raidGroupLabels = UnitFrames.raidGroupLabels or {}

-- ============================================================================
-- HEALTH PERCENTAGE API
-- Safe methods for WoW 12.0+ secret value handling
-- ============================================================================

local function GetSafeHealthPercent(unitToken)
    -- Use ScaleTo100 curve - returns 0-100 directly (matches old LilyUI)
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        return UnitHealthPercent(unitToken, true, CurveConstants.ScaleTo100)
    end
    
    -- Fallback for older clients without CurveConstants
    local maxHP = UnitHealthMax(unitToken, true)
    local currentHP = UnitHealth(unitToken, true)
    if maxHP == nil or currentHP == nil or maxHP <= 0 then return 0 end
    return (currentHP / maxHP) * 100
end

-- Export for use by other modules
UnitFrames.GetSafeHealthPercent = GetSafeHealthPercent

--[[
    Sets a health bar's value using the curve-based API
    Handles secret values automatically
    
    @param statusBar StatusBar - The bar to update
    @param unitToken string - Unit identifier
]]
function UnitFrames:SetHealthBarValue(statusBar, unitToken)
    if not statusBar then return end
    
    if statusBar.SetValueFromHealthPercentCurve then
        statusBar:SetValueFromHealthPercentCurve(unitToken)
        return
    end

    -- Use absolute values to avoid scale mismatches and secret math
    local maxHealth = UnitHealthMax(unitToken, true)
    local currentHealth = UnitHealth(unitToken, true)
    if maxHealth and currentHealth then
        statusBar:SetMinMaxValues(0, maxHealth)
        statusBar:SetValue(currentHealth)
        return
    end

    -- Fallback to percent if needed
    local pct = GetSafeHealthPercent(unitToken)
    if pct ~= nil then
        statusBar:SetMinMaxValues(0, 100)
        statusBar:SetValue(pct)
    end
end

-- ============================================================================
-- PIXEL-PERFECT UTILITIES
-- Methods for precise UI scaling
-- ============================================================================

function UnitFrames:PixelPerfect(value)
    if LilyUI and LilyUI.Scale then
        return LilyUI:Scale(value)
    end
    
    local scale = UIParent:GetEffectiveScale()
    return floor(value * scale + 0.5) / scale
end

function UnitFrames:PixelPerfectThickness(thickness)
    local scale = UIParent:GetEffectiveScale()
    local minSize = 1 / scale
    return max(self:PixelPerfect(thickness), minSize)
end

function UnitFrames:PixelPerfectCeil(value)
    local scale = UIParent:GetEffectiveScale()
    return ceil(value * scale) / scale
end

function UnitFrames:PixelPerfectSizeAndScaleForBorder(size, scale, borderWidth)
    size = self:PixelPerfect(size)
    borderWidth = self:PixelPerfectThickness(borderWidth)
    return size, scale, borderWidth
end

function UnitFrames:SetPixelPerfectSize(frame, width, height)
    if not frame then return end
    frame:SetSize(self:PixelPerfect(width), self:PixelPerfect(height))
end

function UnitFrames:SetPixelPerfectWidth(frame, width)
    if not frame then return end
    frame:SetWidth(self:PixelPerfect(width))
end

function UnitFrames:SetPixelPerfectHeight(frame, height)
    if not frame then return end
    frame:SetHeight(self:PixelPerfect(height))
end

-- ============================================================================
-- NUMBER FORMATTING UTILITIES
-- ============================================================================

function UnitFrames:FormatNumber(value)
    if value >= 1000000 then
        return format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return format("%.1fK", value / 1000)
    end
    return tostring(floor(value))
end

function UnitFrames:AbbreviateNumber(value)
    return self:FormatNumber(value)
end

-- ============================================================================
-- DURATION COLOR CALCULATION
-- ============================================================================

function UnitFrames:GetDurationColorByPercent(remaining, total, db)
    if not db then
        return 1, 1, 1
    end
    
    local percent = 1
    if total and total > 0 then
        percent = remaining / total
    end
    
    local highColor = db.durationColorHigh or {r = 1, g = 1, b = 1}
    local midColor = db.durationColorMid or {r = 1, g = 1, b = 0}
    local lowColor = db.durationColorLow or {r = 1, g = 0, b = 0}
    local highThreshold = db.durationHighThreshold or 0.5
    local lowThreshold = db.durationLowThreshold or 0.25
    
    if percent > highThreshold then
        return highColor.r, highColor.g, highColor.b
    elseif percent > lowThreshold then
        local t = (percent - lowThreshold) / (highThreshold - lowThreshold)
        return midColor.r + (highColor.r - midColor.r) * t,
               midColor.g + (highColor.g - midColor.g) * t,
               midColor.b + (highColor.b - midColor.b) * t
    else
        local t = percent / lowThreshold
        return lowColor.r + (midColor.r - lowColor.r) * t,
               lowColor.g + (midColor.g - lowColor.g) * t,
               lowColor.b + (midColor.b - lowColor.b) * t
    end
end

-- ============================================================================
-- FRAME VALIDATION
-- ============================================================================

function UnitFrames:IsValidFrame(frame)
    return frame and type(frame) == "table" and frame.GetObjectType
end

-- ============================================================================
-- EXTERNAL API FUNCTIONS
-- Methods exposed for other addons to use
-- ============================================================================

--[[
    Gets display name for a unit
    @param unitToken string - Unit identifier
    @return string - Unit name
]]
function UnitFrames:GetUnitName(unitToken)
    if not unitToken then return "" end
    local name = UnitName(unitToken)
    return name or ""
end

--[[
    Iterates over all visible unit frames
    @param callback function - Called with (frame, unit) for each frame
]]
function UnitFrames:IterateCompactFrames(callback)
    if not callback then return end
    
    -- Player frame
    if self.playerFrame and self.playerFrame:IsShown() then
        callback(self.playerFrame, self.playerFrame.unit)
    end
    
    -- Party frames
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame:IsShown() then
            callback(frame, frame.unit)
        end
    end
    
    -- Raid frames
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame:IsShown() then
            callback(frame, frame.unit)
        end
    end
end

--[[
    Gets the frame for a specific unit
    @param unitToken string - Unit to find
    @return Frame|nil - Frame or nil if not found
]]
function UnitFrames:GetFrameForUnit(unitToken)
    if not unitToken then return nil end
    
    -- Check player frame
    if self.playerFrame and self.playerFrame.unit then
        if UnitIsUnit(self.playerFrame.unit, unitToken) then
            return self.playerFrame
        end
    end
    
    -- Check party frames
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unitToken) then
            return frame
        end
    end
    
    -- Check raid frames
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unitToken) then
            return frame
        end
    end
    
    return nil
end

--[[
    Gets all frames for a specific unit (handles duplicate unit IDs)
    @param unitToken string - Unit to find
    @return table - List of frames
]]
function UnitFrames:GetFramesForUnit(unitToken)
    local frames = {}
    if not unitToken then return frames end
    
    -- Check player frame
    if self.playerFrame and self.playerFrame.unit then
        if UnitIsUnit(self.playerFrame.unit, unitToken) then
            table.insert(frames, self.playerFrame)
        end
    end
    
    -- Check party frames
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unitToken) then
            table.insert(frames, frame)
        end
    end
    
    -- Check raid frames
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unitToken) then
            table.insert(frames, frame)
        end
    end
    
    return frames
end

--[[
    Updates a specific unit's frame(s) across all containers
    @param unitToken string - Unit to update
]]
function UnitFrames:UpdateUnitByToken(unitToken)
    local frames = self:GetFramesForUnit(unitToken)
    for _, frame in ipairs(frames) do
        if self.UpdateUnitFrame then
            self:UpdateUnitFrame(frame)
        end
    end
end

-- ============================================================================
-- CLICK CAST REGISTRATION
-- ============================================================================

--[[
    Registers party frames with click-cast addons (Clique, etc.)
]]
function UnitFrames:RegisterClickCastFrames()
    if not ClickCastFrames then return end
    
    if self.playerFrame then
        ClickCastFrames[self.playerFrame] = true
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame then
            ClickCastFrames[frame] = true
        end
    end
end

--[[
    Registers raid frames with click-cast addons
]]
function UnitFrames:RegisterRaidClickCastFrames()
    if not ClickCastFrames then return end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame then
            ClickCastFrames[frame] = true
        end
    end
end

-- ============================================================================
-- SNAP PREVIEW UTILITIES
-- Used for frame positioning
-- ============================================================================

function UnitFrames:HideSnapPreview()
    if self.snapPreviewLines then
        for _, line in ipairs(self.snapPreviewLines) do
            line:Hide()
        end
    end
end

-- ============================================================================
-- FRAME COUNT HELPERS
-- ============================================================================

--[[
    Gets count of visible party members
    @return number - Number of visible party members
]]
function UnitFrames:GetVisiblePartyCount()
    local count = 0
    
    if self.playerFrame and self.playerFrame:IsShown() then
        count = count + 1
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame:IsShown() then
            count = count + 1
        end
    end
    
    return count
end

--[[
    Gets count of visible raid members
    @return number - Number of visible raid members
]]
function UnitFrames:GetVisibleRaidCount()
    local count = 0
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame:IsShown() then
            count = count + 1
        end
    end
    
    return count
end

-- ============================================================================
-- FRAME STATE TRACKING
-- ============================================================================

--[[
    Checks if any test mode is currently active
    @return boolean
]]
function UnitFrames:IsTestModeActive()
    return self.testMode or self.raidTestMode
end

--[[
    Checks if frames are currently locked
    @param frameType string - "party" or "raid"
    @return boolean
]]
function UnitFrames:IsLocked(frameType)
    if frameType == "raid" then
        local db = self:GetRaidDB()
        return db.raidLocked ~= false
    else
        local db = self:GetDB()
        return db.locked ~= false
    end
end
