--[[
    LilyUI Unit Frames - Dispel Overlay System
    Visual indicators for dispellable debuffs
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitDebuff = UnitDebuff
local UnitAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
local ForEachAura = AuraUtil and AuraUtil.ForEachAura
local UnitClass = UnitClass
local CreateFrame = CreateFrame
local GetTime = GetTime
local floor = math.floor

-- Debuff type colors
local DispelColors = {
    Magic   = {r = 0.2, g = 0.6, b = 1.0, a = 0.7},
    Curse   = {r = 0.6, g = 0.0, b = 1.0, a = 0.7},
    Disease = {r = 0.6, g = 0.4, b = 0.0, a = 0.7},
    Poison  = {r = 0.0, g = 0.6, b = 0.0, a = 0.7},
    Bleed   = {r = 0.8, g = 0.0, b = 0.0, a = 0.7},
}

UnitFrames.DispelColors = DispelColors

-- Dispel priority (higher = more important)
local DispelPriority = {
    Magic = 4,
    Curse = 3,
    Disease = 2,
    Poison = 1,
    Bleed = 0,
}

-- Classes that can dispel each type
local ClassDispels = {
    PALADIN = {Magic = true, Disease = true, Poison = true},
    PRIEST = {Magic = true, Disease = true},
    DRUID = {Magic = true, Curse = true, Poison = true},
    SHAMAN = {Magic = true, Curse = true, Poison = true},
    MONK = {Magic = true, Disease = true, Poison = true},
    MAGE = {Curse = true},
    EVOKER = {Magic = true, Poison = true},
}

-- ============================================================================
-- DISPEL OVERLAY CREATION
-- ============================================================================

--[[
    Create dispel overlay elements for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:CreateDispelOverlay(frame)
    if frame.dispelOverlay then return end
    
    -- Main overlay frame
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(frame:GetFrameLevel() + 3)
    
    -- Border overlays (one for each side)
    overlay.borders = {}
    
    -- Create border textures using StatusBar for secret color support
    local borderSize = 2
    
    -- Top border
    overlay.borders.top = CreateFrame("StatusBar", nil, overlay)
    overlay.borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT")
    overlay.borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    overlay.borders.top:SetHeight(borderSize)
    overlay.borders.top:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    overlay.borders.top:SetMinMaxValues(0, 1)
    overlay.borders.top:SetValue(1)
    
    -- Bottom border
    overlay.borders.bottom = CreateFrame("StatusBar", nil, overlay)
    overlay.borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    overlay.borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    overlay.borders.bottom:SetHeight(borderSize)
    overlay.borders.bottom:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    overlay.borders.bottom:SetMinMaxValues(0, 1)
    overlay.borders.bottom:SetValue(1)
    
    -- Left border
    overlay.borders.left = CreateFrame("StatusBar", nil, overlay)
    overlay.borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT")
    overlay.borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    overlay.borders.left:SetWidth(borderSize)
    overlay.borders.left:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    overlay.borders.left:SetMinMaxValues(0, 1)
    overlay.borders.left:SetValue(1)
    
    -- Right border
    overlay.borders.right = CreateFrame("StatusBar", nil, overlay)
    overlay.borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    overlay.borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    overlay.borders.right:SetWidth(borderSize)
    overlay.borders.right:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    overlay.borders.right:SetMinMaxValues(0, 1)
    overlay.borders.right:SetValue(1)
    
    -- Gradient overlay
    overlay.gradient = overlay:CreateTexture(nil, "OVERLAY")
    overlay.gradient:SetPoint("TOPLEFT", frame, "TOPLEFT", borderSize, -borderSize)
    overlay.gradient:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -borderSize, borderSize)
    overlay.gradient:SetTexture("Interface\\Buttons\\WHITE8X8")
    overlay.gradient:SetBlendMode("ADD")
    
    -- Dispel icon (optional, shows type)
    overlay.icon = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    overlay.icon:SetSize(16, 16)
    overlay.icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    overlay.icon:Hide()
    
    -- Initialize hidden
    self:HideDispelOverlay(overlay)
    
    frame.dispelOverlay = overlay
end

-- ============================================================================
-- DISPEL OVERLAY DISPLAY
-- ============================================================================

--[[
    Show dispel overlay with specific type
    @param frame Frame - The unit frame
    @param dispelType string - Type of dispellable debuff
]]
function UnitFrames:ShowDispelOverlay(frame, dispelType)
    if not frame.dispelOverlay then
        self:CreateDispelOverlay(frame)
    end
    
    local overlay = frame.dispelOverlay
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.dispelIndicatorEnabled then
        self:HideDispelOverlay(overlay)
        return
    end
    
    local color = DispelColors[dispelType] or DispelColors.Magic
    
    -- Apply border colors
    for _, border in pairs(overlay.borders) do
        border:SetStatusBarColor(color.r, color.g, color.b, color.a or 0.7)
        border:Show()
    end
    
    -- Apply gradient
    if db.dispelGradientEnabled then
        overlay.gradient:SetVertexColor(color.r, color.g, color.b, 0.15)
        overlay.gradient:Show()
    else
        overlay.gradient:Hide()
    end
    
    -- Show icon if enabled
    if db.dispelIconEnabled then
        local iconTexture = self:GetDispelTypeIcon(dispelType)
        if iconTexture then
            overlay.icon:SetTexture(iconTexture)
            overlay.icon:Show()
        end
    else
        overlay.icon:Hide()
    end
    
    overlay.currentType = dispelType
    overlay:Show()
end

--[[
    Hide dispel overlay
    @param overlay Frame - The dispel overlay
]]
function UnitFrames:HideDispelOverlay(overlay)
    if not overlay then return end
    
    for _, border in pairs(overlay.borders) do
        border:Hide()
    end
    
    overlay.gradient:Hide()
    overlay.icon:Hide()
    overlay:Hide()
    overlay.currentType = nil
end

--[[
    Get icon texture for dispel type
    @param dispelType string - The dispel type
    @return string - Icon texture path
]]
function UnitFrames:GetDispelTypeIcon(dispelType)
    local icons = {
        Magic = "Interface\\RaidFrame\\Raid-Icon-DebuffMagic",
        Curse = "Interface\\RaidFrame\\Raid-Icon-DebuffCurse",
        Disease = "Interface\\RaidFrame\\Raid-Icon-DebuffDisease",
        Poison = "Interface\\RaidFrame\\Raid-Icon-DebuffPoison",
    }
    return icons[dispelType]
end

-- ============================================================================
-- DISPEL DETECTION
-- ============================================================================

--[[
    Check if player can dispel a specific type
    @param dispelType string - The debuff type
    @return boolean
]]
function UnitFrames:CanDispelType(dispelType)
    if not dispelType then return false end
    
    local _, playerClass = UnitClass("player")
    local classDispels = ClassDispels[playerClass]
    
    return classDispels and classDispels[dispelType]
end

--[[
    Find highest priority dispellable debuff on unit
    @param unit string - Unit ID
    @return string|nil - Dispel type or nil if none
]]
function UnitFrames:FindDispellableDebuff(unit)
    local db = self:GetDB()
    local onlyDispellable = db.dispelOnlyPlayerDispellable ~= false
    
    local highestPriority = -1
    local highestType = nil
    
    local function checkAura(auraData)
        local dispelType = auraData.dispelName
        
        if dispelType and DispelPriority[dispelType] then
            -- Check if we should only show what player can dispel
            if onlyDispellable and not self:CanDispelType(dispelType) then
                return false
            end
            
            local priority = DispelPriority[dispelType]
            if priority > highestPriority then
                highestPriority = priority
                highestType = dispelType
            end
        end
        
        return false  -- Continue iteration
    end
    
    -- Use modern API if available
    if ForEachAura then
        ForEachAura(unit, "HARMFUL", nil, checkAura, true)
    else
        -- Fallback for older API
        local index = 1
        while true do
            local name, _, _, dispelType = UnitDebuff(unit, index)
            if not name then break end
            
            if dispelType and DispelPriority[dispelType] then
                if not onlyDispellable or self:CanDispelType(dispelType) then
                    local priority = DispelPriority[dispelType]
                    if priority > highestPriority then
                        highestPriority = priority
                        highestType = dispelType
                    end
                end
            end
            
            index = index + 1
        end
    end
    
    return highestType
end

-- ============================================================================
-- DISPEL UPDATE
-- ============================================================================

--[[
    Update dispel overlay for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:UpdateDispelOverlay(frame)
    if not frame or not frame.unit then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.dispelIndicatorEnabled then
        if frame.dispelOverlay then
            self:HideDispelOverlay(frame.dispelOverlay)
        end
        return
    end
    
    local dispelType = self:FindDispellableDebuff(frame.unit)
    
    if dispelType then
        self:ShowDispelOverlay(frame, dispelType)
    else
        if frame.dispelOverlay then
            self:HideDispelOverlay(frame.dispelOverlay)
        end
    end
end

-- ============================================================================
-- DISPEL LAYOUT
-- ============================================================================

--[[
    Apply layout settings to dispel overlay
    @param frame Frame - The unit frame
]]
function UnitFrames:ApplyDispelOverlayLayout(frame)
    if not frame.dispelOverlay then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local borderSize = self:PixelPerfectThickness(db.dispelBorderSize or 2)
    
    local overlay = frame.dispelOverlay
    
    -- Update border sizes
    overlay.borders.top:SetHeight(borderSize)
    overlay.borders.bottom:SetHeight(borderSize)
    overlay.borders.left:SetWidth(borderSize)
    overlay.borders.right:SetWidth(borderSize)
    
    -- Update gradient inset
    overlay.gradient:SetPoint("TOPLEFT", frame, "TOPLEFT", borderSize, -borderSize)
    overlay.gradient:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -borderSize, borderSize)
    
    -- Update icon position and size
    local iconSize = db.dispelIconSize or 16
    overlay.icon:SetSize(iconSize, iconSize)
end

-- ============================================================================
-- BATCH UPDATE
-- ============================================================================

--[[
    Update dispel overlays for all frames
]]
function UnitFrames:UpdateAllDispelOverlays()
    -- Update player frame
    if self.playerFrame then
        self:UpdateDispelOverlay(self.playerFrame)
    end
    
    -- Update party frames
    for _, frame in pairs(self.partyFrames) do
        self:UpdateDispelOverlay(frame)
    end
    
    -- Update raid frames
    for _, frame in pairs(self.raidFrames) do
        self:UpdateDispelOverlay(frame)
    end
end

-- ============================================================================
-- TICKER FOR FREQUENT UPDATES
-- ============================================================================

local dispelTicker = nil

--[[
    Start dispel update ticker
]]
function UnitFrames:StartDispelTicker()
    if dispelTicker then return end
    
    local db = self:GetDB()
    local updateInterval = db.dispelUpdateInterval or 0.2
    
    dispelTicker = C_Timer.NewTicker(updateInterval, function()
        self:UpdateAllDispelOverlays()
    end)
end

--[[
    Stop dispel update ticker
]]
function UnitFrames:StopDispelTicker()
    if dispelTicker then
        dispelTicker:Cancel()
        dispelTicker = nil
    end
end
