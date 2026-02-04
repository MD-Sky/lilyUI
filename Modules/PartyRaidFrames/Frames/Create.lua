--[[
    LilyUI Unit Frames - Frame Creation
    Handles construction of unit frames and their visual components
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitClass = UnitClass
local UnitName = UnitName
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch
local GetTime = GetTime

-- Masque integration
UnitFrames.Masque = LibStub and LibStub("Masque", true)
UnitFrames.MasqueGroup_Buffs = nil
UnitFrames.MasqueGroup_Debuffs = nil

-- ============================================================================
-- UNIT FRAME CREATION
-- Main entry point for creating unit frames
-- ============================================================================

--[[
    Creates a new unit frame with all visual components
    @param unitToken string - Unit identifier (e.g., "player", "party1", "raid1")
    @param frameIndex number - Numeric index for the frame
    @param isRaidFrame boolean - True if this is a raid frame
    @return Frame - The created unit frame
]]
function UnitFrames:CreateUnitFrame(unitToken, frameIndex, isRaidFrame)
    local db = isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    -- Generate unique frame name
    local frameName = isRaidFrame 
        and ("LilyUIRaidFrame" .. frameIndex)
        or ("LilyUIPartyFrame" .. (frameIndex == 0 and "Player" or frameIndex))
    
    -- Create main secure button frame
    local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate")
    frame.unit = unitToken
    frame.index = frameIndex
    frame.isRaidFrame = isRaidFrame
    
    -- Set initial size
    local width = db.frameWidth or 120
    local height = db.frameHeight or 50
    frame:SetSize(self:PixelPerfect(width), self:PixelPerfect(height))
    
    -- Configure secure attributes
    frame:SetAttribute("unit", unitToken)
    frame:SetAttribute("type1", "target")
    frame:SetAttribute("type2", "togglemenu")
    
    -- Enable mouse interaction
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyDown")
    
    -- Create visual components
    self:CreateBackground(frame, db)
    self:CreateHealthBar(frame, db)
    self:CreateMissingHealthOverlay(frame, db)
    self:CreateContentOverlay(frame, db)
    self:CreateNameText(frame, db)
    self:CreateHealthText(frame, db)
    self:CreateStatusText(frame, db)
    self:CreateFrameBorder(frame, db)
    self:CreateRoleIcon(frame, db)
    self:CreateLeaderIcon(frame, db)
    self:CreateRaidTargetIcon(frame, db)
    self:CreateReadyCheckIcon(frame, db)
    self:CreateCenterStatusIcon(frame, db)
    self:CreatePowerBar(frame, db)
    self:CreateAbsorbBar(frame, db)
    self:CreateHealAbsorbBar(frame, db)
    self:CreateHealPrediction(frame, db)
    self:CreateAuraContainers(frame, db)
    self:CreateMissingBuffIcon(frame, db)
    self:CreateDefensiveIcon(frame, db)
    self:CreateRestedIndicator(frame, db)
    
    -- Setup event handlers
    self:SetupFrameEvents(frame, isRaidFrame)
    self:SetupTooltipHandlers(frame, db)
    self:SetupMouseoverHandlers(frame)
    
    -- Register with ping system (WoW 10.1+)
    if PingableType_UnitFrameMixin then
        Mixin(frame, PingableType_UnitFrameMixin)
        frame:SetAttribute("ping-receiver", true)
    end
    
    return frame
end

-- ============================================================================
-- BACKGROUND CREATION
-- ============================================================================

function UnitFrames:CreateBackground(frame, db)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    frame.background = bg
end

-- ============================================================================
-- HEALTH BAR CREATION
-- ============================================================================

function UnitFrames:CreateHealthBar(frame, db)
    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    healthBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healthBar:SetStatusBarColor(0.2, 0.8, 0.2)
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(100)
    healthBar:SetFrameLevel(frame:GetFrameLevel() + 1)
    
    -- Background for missing health
    local bgTexture = healthBar:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints(healthBar)
    bgTexture:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    healthBar.bgTexture = bgTexture
    
    frame.healthBar = healthBar
end

-- ============================================================================
-- MISSING HEALTH OVERLAY
-- ============================================================================

function UnitFrames:CreateMissingHealthOverlay(frame, db)
    local overlay = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    overlay:SetPoint("TOPRIGHT", frame.healthBar, "TOPRIGHT")
    overlay:SetPoint("BOTTOMRIGHT", frame.healthBar, "BOTTOMRIGHT")
    overlay:SetColorTexture(0.15, 0.15, 0.15, 0.9)
    overlay:SetWidth(0)
    overlay:Hide()
    frame.missingHealthOverlay = overlay
end

-- ============================================================================
-- CONTENT OVERLAY
-- High-level container for text and icons
-- ============================================================================

function UnitFrames:CreateContentOverlay(frame, db)
    local overlay = CreateFrame("Frame", nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(frame:GetFrameLevel() + 25)
    frame.contentOverlay = overlay
end

-- ============================================================================
-- NAME TEXT
-- ============================================================================

function UnitFrames:CreateNameText(frame, db)
    local nameText = frame.contentOverlay:CreateFontString(nil, "OVERLAY")
    nameText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    nameText:SetTextColor(1, 1, 1)
    nameText:SetPoint("TOP", frame, "TOP", 0, -2)
    nameText:SetJustifyH("CENTER")
    nameText:SetText("")
    frame.nameText = nameText
end

-- ============================================================================
-- HEALTH TEXT
-- ============================================================================

function UnitFrames:CreateHealthText(frame, db)
    local healthText = frame.contentOverlay:CreateFontString(nil, "OVERLAY")
    healthText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    healthText:SetTextColor(1, 1, 1)
    healthText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    healthText:SetJustifyH("CENTER")
    healthText:SetText("")
    frame.healthText = healthText
end

-- ============================================================================
-- STATUS TEXT (Dead, Offline, etc.)
-- ============================================================================

function UnitFrames:CreateStatusText(frame, db)
    local statusText = frame.contentOverlay:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    statusText:SetTextColor(0.8, 0.8, 0.8)
    statusText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    statusText:SetJustifyH("CENTER")
    statusText:SetText("")
    statusText:Hide()
    frame.statusText = statusText
end

-- ============================================================================
-- FRAME BORDER
-- ============================================================================

function UnitFrames:CreateFrameBorder(frame, db)
    local borderSize = self:PixelPerfectThickness(1)
    
    local borderTop = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT")
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    borderTop:SetHeight(borderSize)
    borderTop:SetColorTexture(0, 0, 0, 1)
    frame.borderTop = borderTop
    
    local borderBottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    borderBottom:SetHeight(borderSize)
    borderBottom:SetColorTexture(0, 0, 0, 1)
    frame.borderBottom = borderBottom
    
    local borderLeft = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    borderLeft:SetWidth(borderSize)
    borderLeft:SetColorTexture(0, 0, 0, 1)
    frame.borderLeft = borderLeft
    
    local borderRight = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    borderRight:SetWidth(borderSize)
    borderRight:SetColorTexture(0, 0, 0, 1)
    frame.borderRight = borderRight
end

-- ============================================================================
-- ROLE ICON
-- ============================================================================

function UnitFrames:CreateRoleIcon(frame, db)
    local icon = frame.contentOverlay:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:Hide()
    frame.roleIcon = icon
end

-- ============================================================================
-- LEADER ICON
-- ============================================================================

function UnitFrames:CreateLeaderIcon(frame, db)
    local icon = frame.contentOverlay:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    icon:Hide()
    frame.leaderIcon = icon
end

-- ============================================================================
-- RAID TARGET ICON
-- ============================================================================

function UnitFrames:CreateRaidTargetIcon(frame, db)
    local icon = frame.contentOverlay:CreateTexture(nil, "OVERLAY")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:Hide()
    frame.raidTargetIcon = icon
end

-- ============================================================================
-- READY CHECK ICON
-- ============================================================================

function UnitFrames:CreateReadyCheckIcon(frame, db)
    local icon = frame.contentOverlay:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:Hide()
    frame.readyCheckIcon = icon
end

-- ============================================================================
-- CENTER STATUS ICON (Resurrection, Summon, etc.)
-- ============================================================================

function UnitFrames:CreateCenterStatusIcon(frame, db)
    local icon = frame.contentOverlay:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:Hide()
    frame.centerStatusIcon = icon
end

-- ============================================================================
-- POWER BAR
-- ============================================================================

function UnitFrames:CreatePowerBar(frame, db)
    local powerBar = CreateFrame("StatusBar", nil, frame)
    powerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    powerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    powerBar:SetHeight(6)
    powerBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    powerBar:SetStatusBarColor(0.3, 0.3, 0.8)
    powerBar:SetMinMaxValues(0, 100)
    powerBar:SetValue(100)
    powerBar:SetFrameLevel(frame:GetFrameLevel() + 2)
    
    -- Power bar background
    local bgTexture = powerBar:CreateTexture(nil, "BACKGROUND")
    bgTexture:SetAllPoints(powerBar)
    bgTexture:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    powerBar.bgTexture = bgTexture
    
    powerBar:Hide()
    frame.dfPowerBar = powerBar
end

-- ============================================================================
-- ABSORB BAR
-- ============================================================================

function UnitFrames:CreateAbsorbBar(frame, db)
    local absorbBar = CreateFrame("StatusBar", nil, frame.healthBar)
    absorbBar:SetPoint("TOPLEFT", frame.healthBar:GetStatusBarTexture(), "TOPRIGHT")
    absorbBar:SetPoint("BOTTOMLEFT", frame.healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    absorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    absorbBar:SetStatusBarColor(0.8, 0.8, 0.2, 0.6)
    absorbBar:SetMinMaxValues(0, 100)
    absorbBar:SetValue(0)
    absorbBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)
    absorbBar:Hide()
    frame.absorbBar = absorbBar
end

-- ============================================================================
-- HEAL ABSORB BAR
-- ============================================================================

function UnitFrames:CreateHealAbsorbBar(frame, db)
    local healAbsorbBar = CreateFrame("StatusBar", nil, frame.healthBar)
    healAbsorbBar:SetPoint("TOPRIGHT", frame.healthBar:GetStatusBarTexture(), "TOPRIGHT")
    healAbsorbBar:SetPoint("BOTTOMRIGHT", frame.healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    healAbsorbBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healAbsorbBar:SetStatusBarColor(0.8, 0.2, 0.2, 0.6)
    healAbsorbBar:SetMinMaxValues(0, 100)
    healAbsorbBar:SetValue(0)
    healAbsorbBar:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)
    healAbsorbBar:SetReverseFill(true)
    healAbsorbBar:Hide()
    frame.healAbsorbBar = healAbsorbBar
end

-- ============================================================================
-- HEAL PREDICTION
-- ============================================================================

function UnitFrames:CreateHealPrediction(frame, db)
    local healPrediction = CreateFrame("StatusBar", nil, frame.healthBar)
    healPrediction:SetPoint("TOPLEFT", frame.healthBar:GetStatusBarTexture(), "TOPRIGHT")
    healPrediction:SetPoint("BOTTOMLEFT", frame.healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    healPrediction:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    healPrediction:SetStatusBarColor(0.3, 0.8, 0.3, 0.5)
    healPrediction:SetMinMaxValues(0, 100)
    healPrediction:SetValue(0)
    healPrediction:SetFrameLevel(frame.healthBar:GetFrameLevel() + 1)
    healPrediction:Hide()
    frame.healPrediction = healPrediction
end

-- ============================================================================
-- AURA CONTAINERS
-- ============================================================================

function UnitFrames:CreateAuraContainers(frame, db)
    frame.buffIcons = {}
    frame.debuffIcons = {}
    
    -- Create buff icons
    local buffMax = db.buffMaxIcons or db.buffMax or 4
    for i = 1, buffMax do
        frame.buffIcons[i] = self:CreateAuraIcon(frame, i, "BUFF")
    end
    
    -- Create debuff icons
    local debuffMax = db.debuffMaxIcons or db.debuffMax or 8
    for i = 1, debuffMax do
        frame.debuffIcons[i] = self:CreateAuraIcon(frame, i, "DEBUFF")
    end
end

-- ============================================================================
-- AURA ICON CREATION
-- ============================================================================

function UnitFrames:CreateAuraIcon(frame, index, auraType)
    local icon = CreateFrame("Frame", nil, frame)
    icon:SetSize(18, 18)
    icon:SetFrameLevel(frame:GetFrameLevel() + 50)
    icon.unitFrame = frame
    icon.auraType = auraType
    icon.index = index
    
    -- Icon texture
    local texture = icon:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon.texture = texture
    
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
    local cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon.texture)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    icon.cooldown = cooldown
    
    -- Stack count
    local count = icon:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    count:SetJustifyH("RIGHT")
    count:SetText("")
    icon.count = count
    icon.stackMinimum = 2
    
    -- Duration text
    local duration = icon:CreateFontString(nil, "OVERLAY")
    duration:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    duration:SetPoint("BOTTOM", icon, "BOTTOM", 0, -2)
    duration:SetJustifyH("CENTER")
    duration:SetText("")
    duration:Hide()
    icon.duration = duration
    icon.showDuration = true
    
    -- Expiring tint overlay
    local expiringTint = icon:CreateTexture(nil, "OVERLAY", nil, 2)
    expiringTint:SetAllPoints(icon.texture)
    expiringTint:SetColorTexture(1, 0.2, 0.2, 0.4)
    expiringTint:Hide()
    icon.expiringTint = expiringTint
    
    -- Expiring border container
    local expiringBorderContainer = CreateFrame("Frame", nil, icon)
    expiringBorderContainer:SetAllPoints(icon)
    expiringBorderContainer:SetFrameLevel(icon:GetFrameLevel() + 1)
    expiringBorderContainer:Hide()
    icon.expiringBorderAlphaContainer = expiringBorderContainer
    
    -- Expiring border texture
    local expiringBorder = expiringBorderContainer:CreateTexture(nil, "OVERLAY", nil, 3)
    expiringBorder:SetAllPoints(expiringBorderContainer)
    expiringBorder:SetColorTexture(1, 0, 0, 0.8)
    icon.expiringBorder = expiringBorder
    
    -- Setup tooltip handlers
    self:SetupAuraTooltip(icon)
    
    -- Setup OnUpdate for duration tracking
    self:SetupAuraOnUpdate(icon)
    
    -- Register with Masque if available
    self:RegisterAuraWithMasque(icon, auraType)
    
    icon:Hide()
    return icon
end

-- ============================================================================
-- AURA TOOLTIP SETUP
-- ============================================================================

function UnitFrames:SetupAuraTooltip(icon)
    icon:SetScript("OnEnter", function(self)
        if not self.auraData then return end
        
        local db = self.unitFrame.isRaidFrame and UnitFrames:GetRaidDB() or UnitFrames:GetDB()
        if not db.tooltipEnabled then return end
        if not db.tooltipInCombat and InCombatLockdown() then return end
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        
        if self.auraData.auraInstanceID then
            GameTooltip:SetUnitAura(self.unitFrame.unit, self.auraData.auraInstanceID)
        elseif self.auraData.index then
            local filter = self.auraType == "BUFF" and "HELPFUL" or "HARMFUL"
            GameTooltip:SetUnitAura(self.unitFrame.unit, self.auraData.index, filter)
        end
        
        GameTooltip:Show()
    end)
    
    icon:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

-- ============================================================================
-- AURA ONUPDATE SETUP
-- ============================================================================

function UnitFrames:SetupAuraOnUpdate(icon)
    icon.elapsed = 0
    icon:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.1 then return end
        self.elapsed = 0
        
        if not self.hasExpiration or not self.expirationTime then
            if self.duration then self.duration:SetText("") end
            return
        end
        
        local remaining = self.expirationTime - GetTime()
        if remaining <= 0 then
            if self.duration then self.duration:SetText("") end
            return
        end
        
        -- Update duration text
        if self.showDuration and self.duration then
            local text
            if remaining >= 3600 then
                text = string.format("%dh", remaining / 3600)
            elseif remaining >= 60 then
                text = string.format("%dm", remaining / 60)
            elseif remaining >= 10 then
                text = string.format("%d", remaining)
            else
                text = string.format("%.1f", remaining)
            end
            self.duration:SetText(text)
            
            -- Apply duration color if enabled
            local db = self.unitFrame and (self.unitFrame.isRaidFrame and UnitFrames:GetRaidDB() or UnitFrames:GetDB())
            if db and db.durationColorEnabled and self.auraDuration then
                local r, g, b = UnitFrames:GetDurationColorByPercent(remaining, self.auraDuration, db)
                self.duration:SetTextColor(r, g, b)
            end
        end
        
        -- Handle expiring indicators
        local db = self.unitFrame and (self.unitFrame.isRaidFrame and UnitFrames:GetRaidDB() or UnitFrames:GetDB())
        local threshold = db and db.auraExpiringThreshold or 5
        
        if remaining <= threshold then
            if db and db.auraExpiringEnabled then
                if self.expiringTint then
                    self.expiringTint:Show()
                end
                if db.auraExpiringBorderPulse and self.expiringBorderAlphaContainer then
                    self.expiringBorderAlphaContainer:Show()
                end
            end
        else
            if self.expiringTint then self.expiringTint:Hide() end
            if self.expiringBorderAlphaContainer then self.expiringBorderAlphaContainer:Hide() end
        end
    end)
end

-- ============================================================================
-- MASQUE INTEGRATION
-- ============================================================================

function UnitFrames:RegisterAuraWithMasque(icon, auraType)
    if not self.Masque then return end
    
    local groupName = auraType == "BUFF" and "LilyUI Buffs" or "LilyUI Debuffs"
    
    if auraType == "BUFF" then
        if not self.MasqueGroup_Buffs then
            self.MasqueGroup_Buffs = self.Masque:Group("LilyUI", "Buffs")
        end
        self.MasqueGroup_Buffs:AddButton(icon, {
            Icon = icon.texture,
            Cooldown = icon.cooldown,
            Normal = icon.masqueBorder,
        })
    else
        if not self.MasqueGroup_Debuffs then
            self.MasqueGroup_Debuffs = self.Masque:Group("LilyUI", "Debuffs")
        end
        self.MasqueGroup_Debuffs:AddButton(icon, {
            Icon = icon.texture,
            Cooldown = icon.cooldown,
            Normal = icon.masqueBorder,
        })
    end
end

-- ============================================================================
-- MISSING BUFF ICON
-- ============================================================================

function UnitFrames:CreateMissingBuffIcon(frame, db)
    local container = CreateFrame("Frame", nil, frame.contentOverlay)
    container:SetSize(20, 20)
    container:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    container:Hide()
    frame.missingBuffFrame = container
    
    local icon = container:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    frame.missingBuffIcon = icon
    
    -- Create borders
    local borderSize = self:PixelPerfectThickness(1)
    
    local borderLeft = container:CreateTexture(nil, "OVERLAY")
    borderLeft:SetPoint("TOPLEFT", container, "TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT")
    borderLeft:SetWidth(borderSize)
    borderLeft:SetColorTexture(1, 0.5, 0, 0.8)
    frame.missingBuffBorderLeft = borderLeft
    
    local borderRight = container:CreateTexture(nil, "OVERLAY")
    borderRight:SetPoint("TOPRIGHT", container, "TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
    borderRight:SetWidth(borderSize)
    borderRight:SetColorTexture(1, 0.5, 0, 0.8)
    frame.missingBuffBorderRight = borderRight
    
    local borderTop = container:CreateTexture(nil, "OVERLAY")
    borderTop:SetPoint("TOPLEFT", container, "TOPLEFT")
    borderTop:SetPoint("TOPRIGHT", container, "TOPRIGHT")
    borderTop:SetHeight(borderSize)
    borderTop:SetColorTexture(1, 0.5, 0, 0.8)
    frame.missingBuffBorderTop = borderTop
    
    local borderBottom = container:CreateTexture(nil, "OVERLAY")
    borderBottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
    borderBottom:SetHeight(borderSize)
    borderBottom:SetColorTexture(1, 0.5, 0, 0.8)
    frame.missingBuffBorderBottom = borderBottom
end

-- ============================================================================
-- DEFENSIVE ICON
-- ============================================================================

function UnitFrames:CreateDefensiveIcon(frame, db)
    local container = CreateFrame("Frame", nil, frame.contentOverlay)
    container:SetSize(24, 24)
    container:SetPoint("CENTER", frame, "CENTER", 0, 0)
    container:Hide()
    frame.defensiveIcon = container
    
    local texture = container:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    texture:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    container.texture = texture
    
    -- Cooldown
    local cooldown = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
    cooldown:SetAllPoints(texture)
    cooldown:SetDrawSwipe(true)
    cooldown:SetHideCountdownNumbers(true)
    container.cooldown = cooldown
    
    -- Stack count
    local count = container:CreateFontString(nil, "OVERLAY")
    count:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    count:SetText("")
    container.count = count
    
    -- Create borders
    local borderSize = self:PixelPerfectThickness(1)
    
    local borderLeft = container:CreateTexture(nil, "OVERLAY")
    borderLeft:SetPoint("TOPLEFT", container, "TOPLEFT")
    borderLeft:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT")
    borderLeft:SetWidth(borderSize)
    borderLeft:SetColorTexture(0, 0.8, 0, 0.8)
    container.borderLeft = borderLeft
    
    local borderRight = container:CreateTexture(nil, "OVERLAY")
    borderRight:SetPoint("TOPRIGHT", container, "TOPRIGHT")
    borderRight:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
    borderRight:SetWidth(borderSize)
    borderRight:SetColorTexture(0, 0.8, 0, 0.8)
    container.borderRight = borderRight
    
    local borderTop = container:CreateTexture(nil, "OVERLAY")
    borderTop:SetPoint("TOPLEFT", container, "TOPLEFT")
    borderTop:SetPoint("TOPRIGHT", container, "TOPRIGHT")
    borderTop:SetHeight(borderSize)
    borderTop:SetColorTexture(0, 0.8, 0, 0.8)
    container.borderTop = borderTop
    
    local borderBottom = container:CreateTexture(nil, "OVERLAY")
    borderBottom:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT")
    borderBottom:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT")
    borderBottom:SetHeight(borderSize)
    borderBottom:SetColorTexture(0, 0.8, 0, 0.8)
    container.borderBottom = borderBottom
    
    -- Tooltip
    container:EnableMouse(true)
    container:SetScript("OnEnter", function(self)
        if not self.auraData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.auraData.auraInstanceID then
            GameTooltip:SetUnitAura(frame.unit, self.auraData.auraInstanceID)
        end
        GameTooltip:Show()
    end)
    container:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- ============================================================================
-- RESTED INDICATOR
-- ============================================================================

function UnitFrames:CreateRestedIndicator(frame, db)
    local indicator = frame:CreateTexture(nil, "OVERLAY")
    indicator:SetSize(16, 16)
    indicator:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    indicator:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    indicator:SetTexCoord(0, 0.5, 0, 0.421875)
    indicator:Hide()
    frame.restedIndicator = indicator
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

function UnitFrames:SetupFrameEvents(frame, isRaidFrame)
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_MAXHEALTH")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    frame:RegisterEvent("UNIT_CONNECTION")
    frame:RegisterEvent("READY_CHECK")
    frame:RegisterEvent("READY_CHECK_CONFIRM")
    frame:RegisterEvent("READY_CHECK_FINISHED")
    frame:RegisterEvent("RAID_TARGET_UPDATE")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    -- Conditionally register power events
    local unit = frame.unit
    if unit == "player" or unit:match("^party") then
        frame:RegisterEvent("UNIT_POWER_UPDATE")
        frame:RegisterEvent("UNIT_MAXPOWER")
    end
    
    frame:SetScript("OnEvent", function(self, event, eventUnit, ...)
        -- Avoid secure UnitIsUnit() checks in combat; unit tokens match directly here.
        if eventUnit ~= nil and self.unit ~= nil and eventUnit ~= self.unit then return end
        
        if UnitFrames.UpdateUnitFrame then
            UnitFrames:UpdateUnitFrame(self)
        end
        
        -- Specific event handlers
        if event == "UNIT_AURA" and UnitFrames.UpdateAuras then
            UnitFrames:UpdateAuras(self)
        elseif event == "RAID_TARGET_UPDATE" and UnitFrames.UpdateRaidTargetIcon then
            UnitFrames:UpdateRaidTargetIcon(self)
        elseif event == "PLAYER_TARGET_CHANGED" and UnitFrames.UpdateHighlights then
            UnitFrames:UpdateHighlights(self)
        end
    end)
end

    -- Initial aura scan so icons populate immediately
    if UnitFrames.UpdateAuras then
        UnitFrames:UpdateAuras(frame)
    end


-- ============================================================================
-- TOOLTIP HANDLERS
-- ============================================================================

function UnitFrames:SetupTooltipHandlers(frame, db)
    frame:SetScript("OnEnter", function(self)
        local db = self.isRaidFrame and UnitFrames:GetRaidDB() or UnitFrames:GetDB()
        
        -- Mouseover highlight
        if UnitFrames.SetMouseoverHighlightState then
            UnitFrames:SetMouseoverHighlightState(self, true)
        end
        
        -- Tooltip
        if db.tooltipEnabled then
            if db.tooltipInCombat or not InCombatLockdown() then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetUnit(self.unit)
                GameTooltip:Show()
            end
        end
    end)
    
    frame:SetScript("OnLeave", function(self)
        -- Mouseover highlight
        if UnitFrames.SetMouseoverHighlightState then
            UnitFrames:SetMouseoverHighlightState(self, false)
        end
        
        GameTooltip:Hide()
    end)
end

-- ============================================================================
-- MOUSEOVER HANDLERS
-- ============================================================================

function UnitFrames:SetupMouseoverHandlers(frame)
    -- Mouseover state is managed through OnEnter/OnLeave above
end

-- ============================================================================
-- PARTY/RAID SPECIFIC FRAME CREATORS
-- ============================================================================

function UnitFrames:CreatePartyFrame(unitToken, frameIndex)
    local frame = self:CreateUnitFrame(unitToken, frameIndex, false)
    self:ApplyFrameLayout(frame)
    return frame
end

function UnitFrames:CreateRaidFrame(unitToken, frameIndex)
    local frame = self:CreateUnitFrame(unitToken, frameIndex, true)
    self:ApplyFrameLayout(frame)
    return frame
end
