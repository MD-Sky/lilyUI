--[[
    LilyUI Unit Frames Module
    Core entry point for party and raid unit frame functionality
    
    This module provides customizable unit frames for party and raid groups,
    including health bars, power bars, auras, status icons, and various
    visual indicators for gameplay information.
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Module namespace initialization
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Module metadata
UnitFrames.IDENTIFIER = "LilyUIUnitFrames"
UnitFrames.BUILD = (C_AddOns and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.0.0"
UnitFrames.LOADED = false

-- Development flags
UnitFrames.devMode = false
UnitFrames.verboseLogging = false

-- State tracking
UnitFrames.initialized = false
UnitFrames.testMode = false
UnitFrames.raidTestMode = false
UnitFrames.sliderDragging = false
UnitFrames.configOpen = false
UnitFrames.deferredUpdates = {}

-- Frame storage containers
UnitFrames.partyFrames = {}
UnitFrames.playerFrame = nil
UnitFrames.container = nil
UnitFrames.raidFrames = {}
UnitFrames.raidContainer = nil
UnitFrames.petFrames = {}
UnitFrames.raidPetFrames = {}
UnitFrames.partyPetFrames = {}

-- Cache commonly used API
local pairs, ipairs, type, select = pairs, ipairs, type, select
local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local format, strsplit, strmatch = string.format, strsplit, strmatch
local tinsert, tremove, wipe = table.insert, table.remove, table.wipe
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitClass = UnitClass
local UnitName = UnitName
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetTime = GetTime
local C_Timer = C_Timer
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch

-- ============================================================================
-- DATABASE INITIALIZATION
-- ============================================================================

function UnitFrames:InitializeDB()
    -- Prefer LilyUI's profile DB if available
    if LilyUI and LilyUI.db and LilyUI.db.profile then
        local profile = LilyUI.db.profile
        profile.partyFrames = profile.partyFrames or self:DeepCopy(self.PartyDefaults or {})
        profile.raidFrames = profile.raidFrames or self:DeepCopy(self.RaidDefaults or {})
        
        self.db = self.db or {}
        self.db.party = profile.partyFrames
        self.db.raid = profile.raidFrames
        
        self:SyncProfile()
        return
    end
    
    -- Fallback: use in-memory defaults (no persistence)
    if not self.db then
        self.db = {
            party = self:DeepCopy(self.PartyDefaults or {}),
            raid = self:DeepCopy(self.RaidDefaults or {}),
        }
    end
end

-- Curve constants for WoW 12.0+ health percentage API
-- NOTE: CurveConstants is a GLOBAL table in WoW, not under Enum
local ScaleTo100 = CurveConstants and CurveConstants.ScaleTo100

-- ============================================================================
-- DATABASE ACCESS
-- ============================================================================

function UnitFrames:GetDB()
    if self.db and self.db.party then
        return self.db.party
    end
    return {}
end

function UnitFrames:GetRaidDB()
    if self.db and self.db.raid then
        return self.db.raid
    end
    return {}
end

function UnitFrames:SyncProfile()
    if not self.db then return end
    
    local function MergeDefaults(target, defaults)
        if not target or not defaults then return end
        for key, value in pairs(defaults) do
            if target[key] == nil then
                if type(value) == "table" then
                    target[key] = self:DeepCopy(value)
                else
                    target[key] = value
                end
            elseif type(value) == "table" and type(target[key]) == "table" then
                MergeDefaults(target[key], value)
            end
        end
    end
    
    if self.PartyDefaults then
        MergeDefaults(self.db.party, self.PartyDefaults)
    end
    if self.RaidDefaults then
        MergeDefaults(self.db.raid, self.RaidDefaults)
    end
end

-- ============================================================================
-- TABLE UTILITIES
-- ============================================================================

function UnitFrames:DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    
    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = self:DeepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

function UnitFrames:TablesMatch(tableA, tableB)
    if type(tableA) ~= "table" or type(tableB) ~= "table" then
        return tableA == tableB
    end
    
    for key, value in pairs(tableA) do
        if not self:TablesMatch(value, tableB[key]) then
            return false
        end
    end
    
    for key in pairs(tableB) do
        if tableA[key] == nil then
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- FONT UTILITIES
-- ============================================================================

function UnitFrames:SafeSetFont(fontString, fontPath, fontSize, outlineStyle)
    if not fontString then return end
    
    fontSize = fontSize or 12
    outlineStyle = outlineStyle or "OUTLINE"
    if outlineStyle == "NONE" then outlineStyle = "" end
    
    local resolvedPath = fontPath
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and fontPath then
        local mediaPath = LSM:Fetch("font", fontPath)
        if mediaPath then
            resolvedPath = mediaPath
        end
    end
    
    if not resolvedPath or resolvedPath == "" then
        resolvedPath = "Fonts\\FRIZQT__.TTF"
    end
    
    local applied = fontString:SetFont(resolvedPath, fontSize, outlineStyle)
    if not applied then
        fontString:SetFont("Fonts\\FRIZQT__.TTF", fontSize, outlineStyle)
    end
end

-- ============================================================================
-- PIXEL-PERFECT SCALING
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
    return max(thickness, minSize)
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
-- HEALTH PERCENTAGE UTILITIES
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

UnitFrames.GetSafeHealthPercent = GetSafeHealthPercent

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
-- NUMBER FORMATTING
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
-- COLOR UTILITIES
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
-- SLIDER DRAG OPTIMIZATION SYSTEM
-- ============================================================================

UnitFrames.lightweightFunctions = {}
UnitFrames.throttleRate = 0.05
UnitFrames.lastThrottleTime = 0

function UnitFrames:OnSliderDragStart(lightweightFunc, funcName, usePreviewMode)
    self.sliderDragging = true
    self.currentSliderFunc = lightweightFunc
    self.currentSliderFuncName = funcName
    self.previewModeEnabled = usePreviewMode
    self.lastThrottleTime = GetTime()
end

function UnitFrames:ThrottledUpdateAll()
    local currentTime = GetTime()
    if currentTime - self.lastThrottleTime < self.throttleRate then
        return
    end
    
    self.lastThrottleTime = currentTime
    
    if self.currentSliderFunc then
        self.currentSliderFunc()
    end
end

function UnitFrames:OnSliderDragEnd()
    self.sliderDragging = false
    self.currentSliderFunc = nil
    self.currentSliderFuncName = nil
    self.previewModeEnabled = false
    
    C_Timer.After(0.05, function()
        self:UpdateAllFrames()
    end)
end

function UnitFrames:UpdateAllFrames()
    if InCombatLockdown() then
        self.needsUpdate = true
        return
    end
    
    if self.testModeActive and self.UpdateTestFrames then
        local applyLayout = not self.sliderDragging
        self:UpdateTestFrames(applyLayout)
        return
    end
    
    if self.playerFrame and self.playerFrame:IsShown() then
        self:UpdateUnitFrame(self.playerFrame)
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame:IsShown() then
            self:UpdateUnitFrame(frame)
        end
    end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame:IsShown() then
            self:UpdateUnitFrame(frame)
        end
    end
end

-- ============================================================================
-- COMBAT LOCKDOWN HANDLING
-- ============================================================================

function UnitFrames:QueueForPostCombat(operationKey, callback)
    if not InCombatLockdown() then
        callback()
        return
    end
    
    self.deferredUpdates[operationKey] = callback
end

function UnitFrames:RunDeferredUpdates()
    for key, callback in pairs(self.deferredUpdates) do
        if type(callback) == "function" then
            callback()
        elseif callback == true and key == "fullUpdate" then
            self:UpdateAllFrames()
        end
        self.deferredUpdates[key] = nil
    end
end

-- ============================================================================
-- UNIT WATCH WRAPPER
-- ============================================================================

function UnitFrames:SafeRegisterUnitWatch(frame)
    if not frame then return end
    
    if InCombatLockdown() then
        self:QueueForPostCombat("watch_" .. (frame:GetName() or tostring(frame)), function()
            RegisterUnitWatch(frame)
        end)
        return
    end
    
    RegisterUnitWatch(frame)
end

function UnitFrames:SafeUnregisterUnitWatch(frame)
    if not frame then return end
    
    if InCombatLockdown() then
        self:QueueForPostCombat("unwatch_" .. (frame:GetName() or tostring(frame)), function()
            UnregisterUnitWatch(frame)
        end)
        return
    end
    
    UnregisterUnitWatch(frame)
end

-- ============================================================================
-- FRAME VALIDATION
-- ============================================================================

function UnitFrames:IsValidFrame(frame)
    return frame and type(frame) == "table" and frame.GetObjectType
end

-- ============================================================================
-- DEVELOPMENT UTILITIES
-- ============================================================================

function UnitFrames:Print(...)
    if LilyUI and LilyUI.Print then
        LilyUI:Print(...)
        return
    end
    print("|cff00ccff[LilyUI UF]|r", ...)
end

function UnitFrames:DebugPrint(...)
    if self.devMode then
        print("|cff00ccff[LilyUI UF Debug]|r", ...)
    end
end

function UnitFrames:VerbosePrint(...)
    if self.verboseLogging then
        print("|cff888888[LilyUI UF]|r", ...)
    end
end

-- ============================================================================
-- EXTERNAL API
-- ============================================================================

function UnitFrames:GetUnitName(unitToken)
    if not unitToken then return "" end
    local name = UnitName(unitToken)
    return name or ""
end

function UnitFrames:IterateCompactFrames(callback)
    if not callback then return end
    
    if self.playerFrame and self.playerFrame:IsShown() then
        callback(self.playerFrame, self.playerFrame.unit)
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame:IsShown() then
            callback(frame, frame.unit)
        end
    end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame:IsShown() then
            callback(frame, frame.unit)
        end
    end
end

function UnitFrames:GetFrameForUnit(unitToken)
    if not unitToken then return nil end
    
    if self.playerFrame and self.playerFrame.unit and UnitIsUnit(self.playerFrame.unit, unitToken) then
        return self.playerFrame
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unitToken) then
            return frame
        end
    end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and frame.unit and UnitIsUnit(frame.unit, unitToken) then
            return frame
        end
    end
    
    return nil
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function UnitFrames:OnModuleLoad()
    if self.LOADED then return end
    self.LOADED = true
    
    self:DebugPrint("Module loaded, version:", self.BUILD)
end

UnitFrames:OnModuleLoad()
