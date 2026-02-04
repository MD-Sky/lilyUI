--[[
    LilyUI Unit Frames - Frame Update
    Handles layout application and frame state updates
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local format = string.format
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitClass = UnitClass
local UnitName = UnitName
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitIsAFK = UnitIsAFK
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local strsplit = strsplit

-- Power type colors
local PowerColors = {
    [0] = {0.0, 0.0, 1.0},     -- Mana
    [1] = {1.0, 0.0, 0.0},     -- Rage
    [2] = {1.0, 0.5, 0.25},    -- Focus
    [3] = {1.0, 1.0, 0.0},     -- Energy
    [4] = {0.0, 1.0, 1.0},     -- Combo Points
    [5] = {0.5, 0.5, 0.5},     -- Runes
    [6] = {0.0, 0.82, 1.0},    -- Runic Power
    [7] = {0.35, 0.35, 0.35},  -- Soul Shards
    [8] = {0.0, 0.44, 0.87},   -- Lunar Power
    [9] = {0.95, 0.33, 0.31},  -- Holy Power
    [11] = {0.0, 0.5, 0.5},    -- Maelstrom
    [12] = {0.94, 0.43, 0.02}, -- Chi
    [13] = {0.64, 0.44, 0.98}, -- Insanity
    [17] = {0.88, 0.04, 0.44}, -- Fury
    [18] = {0.6, 0.6, 0.6},    -- Pain
    [19] = {0.0, 0.82, 1.0},   -- Essence
}

-- ============================================================================
-- FRAME LAYOUT APPLICATION
-- ============================================================================

--[[
    Applies all layout settings to a unit frame
    @param frame Frame - The frame to configure
]]
function UnitFrames:ApplyFrameLayout(frame)
    if not frame then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    -- During slider dragging, only do lightweight updates
    if self.sliderDragging then
        self:ApplyLightweightLayout(frame, db)
        return
    end
    
    -- Apply full layout
    self:ApplyFrameSize(frame, db)
    self:ApplyFrameLevels(frame)
    self:ApplyHealthBarLayout(frame, db)
    self:ApplyPowerBarLayout(frame, db)
    self:ApplyAbsorbBarLayout(frame, db)
    self:ApplyBorderLayout(frame, db)
    self:ApplyTextLayout(frame, db)
    self:ApplyIconLayout(frame, db)
    self:ApplyAuraLayout(frame, "BUFF")
    self:ApplyAuraLayout(frame, "DEBUFF")
end

function UnitFrames:ApplyLayoutForFrames(frameType)
    local function apply(frame)
        if frame then
            self:ApplyFrameLayout(frame)
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
    Lightweight layout update during slider dragging
    Only updates size-related elements for performance
]]
function UnitFrames:ApplyLightweightLayout(frame, db)
    if not frame then return end
    
    -- Only update size during drag
    self:ApplyFrameSize(frame, db)
end

-- ============================================================================
-- FRAME SIZE
-- ============================================================================

function UnitFrames:ApplyFrameSize(frame, db)
    local width = db.frameWidth or 120
    local height = db.frameHeight or 50
    frame:SetSize(self:PixelPerfect(width), self:PixelPerfect(height))
end

-- ============================================================================
-- FRAME LAYERING
-- ============================================================================

function UnitFrames:ApplyFrameLevels(frame)
    if not frame then return end
    
    local baseLevel = frame:GetFrameLevel()
    local backgroundLevel = baseLevel + 1
    local healthLevel = baseLevel + 2
    local absorbLevel = baseLevel + 3
    local resourceLevel = baseLevel + 4
    local auraLevel = baseLevel + 5
    local borderLevel = baseLevel + 6
    
    if frame.background then
        frame.background:SetDrawLayer("BACKGROUND", 0)
    end
    
    if frame.healthBar then
        frame.healthBar:SetFrameLevel(healthLevel)
    end
    
    if frame.absorbBar then
        frame.absorbBar:SetFrameLevel(absorbLevel)
    end
    if frame.healAbsorbBar then
        frame.healAbsorbBar:SetFrameLevel(absorbLevel)
    end
    if frame.healPrediction then
        frame.healPrediction:SetFrameLevel(absorbLevel)
    end
    
    if frame.dfPowerBar then
        frame.dfPowerBar:SetFrameLevel(resourceLevel)
    end
    
    if frame.contentOverlay then
        frame.contentOverlay:SetFrameLevel(auraLevel)
    end
    
    if frame.borderTop or frame.borderBottom or frame.borderLeft or frame.borderRight then
        if not frame.borderOverlay then
            local overlay = CreateFrame("Frame", nil, frame)
            overlay:SetAllPoints(frame)
            frame.borderOverlay = overlay
        end
        frame.borderOverlay:SetFrameLevel(borderLevel)
        
        if frame.borderTop then
            frame.borderTop:SetParent(frame.borderOverlay)
            frame.borderTop:SetDrawLayer("OVERLAY", 1)
        end
        if frame.borderBottom then
            frame.borderBottom:SetParent(frame.borderOverlay)
            frame.borderBottom:SetDrawLayer("OVERLAY", 1)
        end
        if frame.borderLeft then
            frame.borderLeft:SetParent(frame.borderOverlay)
            frame.borderLeft:SetDrawLayer("OVERLAY", 1)
        end
        if frame.borderRight then
            frame.borderRight:SetParent(frame.borderOverlay)
            frame.borderRight:SetDrawLayer("OVERLAY", 1)
        end
    end
end

-- ============================================================================
-- HEALTH BAR LAYOUT
-- ============================================================================

function UnitFrames:ApplyHealthBarLayout(frame, db)
    if not frame.healthBar then return end
    
    local inset = db.healthBarInset or 1
    inset = self:PixelPerfect(inset)
    
    -- Calculate power bar offset if enabled
    local powerOffset = 0
    if db.powerBarEnabled and db.powerBarPosition == "BOTTOM" then
        powerOffset = (db.powerBarHeight or 6) + 1
    end
    
    frame.healthBar:ClearAllPoints()
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + powerOffset)
    
    -- Apply texture
    local texturePath = self:GetTexturePath(db.healthBarTexture)
    frame.healthBar:SetStatusBarTexture(texturePath)
    
    -- Update missing health background (healthBar.bgTexture)
    if frame.healthBar.bgTexture then
        if db.missingHealthEnabled then
            local missingColor = db.missingHealthColor or {r = 0.15, g = 0.15, b = 0.15, a = 0.9}
            frame.healthBar.bgTexture:SetColorTexture(
                missingColor.r or 0.15,
                missingColor.g or 0.15,
                missingColor.b or 0.15,
                missingColor.a or 0.9
            )
            frame.healthBar.bgTexture:Show()
        else
            frame.healthBar.bgTexture:Hide()
        end
    end
    
    -- Apply orientation
    if db.healthBarOrientation == "VERTICAL" then
        frame.healthBar:SetOrientation("VERTICAL")
    else
        frame.healthBar:SetOrientation("HORIZONTAL")
            end
        end
        
-- ============================================================================
-- POWER BAR LAYOUT
-- ============================================================================

function UnitFrames:ApplyPowerBarLayout(frame, db)
    if not frame.dfPowerBar then return end
    
    if not db.powerBarEnabled then
        frame.dfPowerBar:Hide()
        return
    end
    
    local height = db.powerBarHeight or 6
    local inset = db.powerBarInset or 1
    inset = self:PixelPerfect(inset)
    height = self:PixelPerfect(height)
    
    frame.dfPowerBar:ClearAllPoints()
    
    if db.powerBarPosition == "TOP" then
        frame.dfPowerBar:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        frame.dfPowerBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
    else
        frame.dfPowerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
        frame.dfPowerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    end
    
    frame.dfPowerBar:SetHeight(height)
    
    -- Apply texture
    local texturePath = self:GetTexturePath(db.powerBarTexture)
    frame.dfPowerBar:SetStatusBarTexture(texturePath)
    
    -- Apply background
    if frame.dfPowerBar.bgTexture then
        local bgColor = db.powerBarBackground or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
        frame.dfPowerBar.bgTexture:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.8)
    end
    
    frame.dfPowerBar:Show()
end

-- ============================================================================
-- ABSORB BAR LAYOUT
-- ============================================================================

function UnitFrames:ApplyAbsorbBarLayout(frame, db)
    if not frame.absorbBar then return end
    
    if not db.absorbBarEnabled then
        frame.absorbBar:Hide()
        return
    end
    
    -- Apply color
    local color = db.absorbBarColor or {r = 0.8, g = 0.8, b = 0.2, a = 0.6}
    frame.absorbBar:SetStatusBarColor(color.r, color.g, color.b, color.a or 0.6)
    
    -- Apply texture
    local texturePath = self:GetTexturePath(db.absorbBarTexture)
    frame.absorbBar:SetStatusBarTexture(texturePath)
end

-- ============================================================================
-- BORDER LAYOUT
-- ============================================================================

function UnitFrames:ApplyBorderLayout(frame, db)
    local enabled = db.borderEnabled ~= false
    local borderSize = self:PixelPerfectThickness(db.borderSize or 1)
    local color = db.borderColor or {r = 0, g = 0, b = 0, a = 1}
    
    if not enabled then
        if frame.borderTop then frame.borderTop:Hide() end
        if frame.borderBottom then frame.borderBottom:Hide() end
        if frame.borderLeft then frame.borderLeft:Hide() end
        if frame.borderRight then frame.borderRight:Hide() end
        return
    end
    
    -- Top border
    if frame.borderTop then
        frame.borderTop:ClearAllPoints()
        frame.borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT")
        frame.borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        frame.borderTop:SetHeight(borderSize)
        frame.borderTop:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        frame.borderTop:Show()
    end
    
    -- Bottom border
    if frame.borderBottom then
        frame.borderBottom:ClearAllPoints()
        frame.borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        frame.borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
        frame.borderBottom:SetHeight(borderSize)
        frame.borderBottom:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        frame.borderBottom:Show()
    end
    
    -- Left border
    if frame.borderLeft then
        frame.borderLeft:ClearAllPoints()
        frame.borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT")
        frame.borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
        frame.borderLeft:SetWidth(borderSize)
        frame.borderLeft:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        frame.borderLeft:Show()
    end
    
    -- Right border
    if frame.borderRight then
        frame.borderRight:ClearAllPoints()
        frame.borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
        frame.borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
        frame.borderRight:SetWidth(borderSize)
        frame.borderRight:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        frame.borderRight:Show()
        end
    end
    
-- ============================================================================
-- TEXT LAYOUT
-- ============================================================================

function UnitFrames:ApplyTextLayout(frame, db)
    -- Name text
    if frame.nameText then
        if db.nameTextEnabled then
            local fontPath = self:GetFontPath(db.nameTextFont)
            self:SafeSetFont(frame.nameText, fontPath, db.nameTextSize or 11, db.nameTextOutline or "OUTLINE")
            
        frame.nameText:ClearAllPoints()
            frame.nameText:SetPoint(db.nameTextAnchor or "TOP", frame, db.nameTextAnchor or "TOP", 
                                    db.nameTextOffsetX or 0, db.nameTextOffsetY or -2)
            frame.nameText:Show()
        else
            frame.nameText:Hide()
        end
    end
    
    -- Health text
    if frame.healthText then
        if db.healthTextEnabled then
            local fontPath = self:GetFontPath(db.healthTextFont)
            self:SafeSetFont(frame.healthText, fontPath, db.healthTextSize or 10, db.healthTextOutline or "OUTLINE")
            
        frame.healthText:ClearAllPoints()
            frame.healthText:SetPoint(db.healthTextAnchor or "CENTER", frame, db.healthTextAnchor or "CENTER",
                                      db.healthTextOffsetX or 0, db.healthTextOffsetY or 0)
            frame.healthText:Show()
        else
            frame.healthText:Hide()
        end
    end
    
    -- Status text
    if frame.statusText then
        local fontPath = self:GetFontPath(db.statusTextFont)
        self:SafeSetFont(frame.statusText, fontPath, db.statusTextSize or 10, db.statusTextOutline or "OUTLINE")
        
        frame.statusText:ClearAllPoints()
        frame.statusText:SetPoint(db.statusTextAnchor or "CENTER", frame, db.statusTextAnchor or "CENTER",
                                  db.statusTextOffsetX or 0, db.statusTextOffsetY or 0)
    end
end

-- ============================================================================
-- ICON LAYOUT
-- ============================================================================

function UnitFrames:ApplyIconLayout(frame, db)
    -- Role icon
    if frame.roleIcon then
        if db.roleIconEnabled then
            frame.roleIcon:SetSize(db.roleIconSize or 14, db.roleIconSize or 14)
        frame.roleIcon:ClearAllPoints()
            frame.roleIcon:SetPoint(db.roleIconAnchor or "TOPLEFT", frame, db.roleIconAnchor or "TOPLEFT",
                                    db.roleIconOffsetX or 2, db.roleIconOffsetY or -2)
            frame.roleIcon:SetAlpha(db.roleIconAlpha or 1)
        else
            frame.roleIcon:Hide()
        end
    end
    
    -- Leader icon
    if frame.leaderIcon then
        if db.leaderIconEnabled then
            frame.leaderIcon:SetSize(db.leaderIconSize or 14, db.leaderIconSize or 14)
        frame.leaderIcon:ClearAllPoints()
            frame.leaderIcon:SetPoint(db.leaderIconAnchor or "TOPRIGHT", frame, db.leaderIconAnchor or "TOPRIGHT",
                                      db.leaderIconOffsetX or -2, db.leaderIconOffsetY or -2)
        else
            frame.leaderIcon:Hide()
        end
    end
    
    -- Raid target icon
    if frame.raidTargetIcon then
        if db.raidTargetIconEnabled then
            frame.raidTargetIcon:SetSize(db.raidTargetIconSize or 20, db.raidTargetIconSize or 20)
            frame.raidTargetIcon:ClearAllPoints()
            frame.raidTargetIcon:SetPoint(db.raidTargetIconAnchor or "CENTER", frame, db.raidTargetIconAnchor or "CENTER",
                                          db.raidTargetIconOffsetX or 0, db.raidTargetIconOffsetY or 0)
        else
            frame.raidTargetIcon:Hide()
        end
    end
    
    -- Ready check icon
    if frame.readyCheckIcon then
        if db.readyCheckIconEnabled then
            frame.readyCheckIcon:SetSize(db.readyCheckIconSize or 24, db.readyCheckIconSize or 24)
            frame.readyCheckIcon:ClearAllPoints()
            frame.readyCheckIcon:SetPoint(db.readyCheckIconAnchor or "CENTER", frame, db.readyCheckIconAnchor or "CENTER",
                                          db.readyCheckIconOffsetX or 0, db.readyCheckIconOffsetY or 0)
        else
            frame.readyCheckIcon:Hide()
        end
    end
    
    -- Center status icon
    if frame.centerStatusIcon then
        if db.centerStatusIconEnabled then
            frame.centerStatusIcon:SetSize(db.centerStatusIconSize or 24, db.centerStatusIconSize or 24)
            frame.centerStatusIcon:ClearAllPoints()
            frame.centerStatusIcon:SetPoint(db.centerStatusIconAnchor or "CENTER", frame, db.centerStatusIconAnchor or "CENTER",
                                            db.centerStatusIconOffsetX or 0, db.centerStatusIconOffsetY or 0)
        else
            frame.centerStatusIcon:Hide()
        end
    end
end

-- ============================================================================
-- AURA LAYOUT
-- ============================================================================

function UnitFrames:ApplyAuraLayout(frame, auraType)
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local prefix = auraType == "BUFF" and "buff" or "debuff"
    local icons = auraType == "BUFF" and frame.buffIcons or frame.debuffIcons
    
    if not icons then return end
    
    local size = db[prefix .. "Size"] or 18
    local scale = db[prefix .. "Scale"] or 1.0
    local defaultAnchor = (auraType == "BUFF") and "BOTTOMRIGHT" or "BOTTOMLEFT"
    local anchor = db[prefix .. "Anchor"] or defaultAnchor
    if db.auraAnchor == "TOP" then
        anchor = (auraType == "BUFF") and "TOPRIGHT" or "TOPLEFT"
    elseif db.auraAnchor == "BOTTOM" then
        anchor = (auraType == "BUFF") and "BOTTOMRIGHT" or "BOTTOMLEFT"
    elseif db.auraAnchor == "LEFT" then
        anchor = (auraType == "BUFF") and "TOPLEFT" or "BOTTOMLEFT"
    elseif db.auraAnchor == "RIGHT" then
        anchor = (auraType == "BUFF") and "TOPRIGHT" or "BOTTOMRIGHT"
    end

    local growth = db[prefix .. "Growth"] or (auraType == "BUFF" and "LEFT_UP" or "RIGHT_UP")
    local simpleGrowth = db[prefix .. "GrowthDirection"]
    if simpleGrowth then
        local secondary = (simpleGrowth == "UP" or simpleGrowth == "DOWN") and "RIGHT" or "UP"
        growth = simpleGrowth .. "_" .. secondary
    end

    local offsetX = db[prefix .. "OffsetX"] or (auraType == "BUFF" and -2 or 2)
    local offsetY = db[prefix .. "OffsetY"] or 2

    local iconSpacing = db[prefix .. "IconSpacing"]
    local paddingX = iconSpacing ~= nil and iconSpacing or (db[prefix .. "PaddingX"] or 2)
    local paddingY = iconSpacing ~= nil and iconSpacing or (db[prefix .. "PaddingY"] or 2)

    local wrap = db[prefix .. "IconsPerRow"] or db[prefix .. "Wrap"] or 4
    wrap = max(1, wrap)

    local framePadding = db.auraFramePadding or 0
    if framePadding ~= 0 then
        if anchor:find("LEFT") then
            offsetX = offsetX + framePadding
        elseif anchor:find("RIGHT") then
            offsetX = offsetX - framePadding
        end
        if anchor:find("TOP") then
            offsetY = offsetY - framePadding
        elseif anchor:find("BOTTOM") then
            offsetY = offsetY + framePadding
        end
    end
    local borderThickness = db[prefix .. "BorderThickness"] or 1
    
    -- Apply pixel-perfect adjustments
    size, scale, borderThickness = self:PixelPerfectSizeAndScaleForBorder(size, scale, borderThickness)
    
    -- Parse growth direction
    local primary, secondary = strsplit("_", growth)
    secondary = secondary or "UP"
    
    local scaledSize = size * scale
    
    -- Calculate growth vectors
    local primaryX, primaryY = 0, 0
    local secondaryX, secondaryY = 0, 0
    
    if primary == "LEFT" then
        primaryX = -(scaledSize + paddingX)
    elseif primary == "RIGHT" then
        primaryX = scaledSize + paddingX
    elseif primary == "UP" then
        primaryY = scaledSize + paddingY
    elseif primary == "DOWN" then
        primaryY = -(scaledSize + paddingY)
    elseif primary == "CENTER" then
        primaryX = scaledSize + paddingX  -- Default to right for center
    end
    
    if secondary == "UP" then
        secondaryY = scaledSize + paddingY
    elseif secondary == "DOWN" then
        secondaryY = -(scaledSize + paddingY)
    elseif secondary == "LEFT" then
        secondaryX = -(scaledSize + paddingX)
    elseif secondary == "RIGHT" then
        secondaryX = scaledSize + paddingX
    end
    
    -- Position icons
    local stackPos = db[prefix .. "StackPosition"] or "BOTTOMRIGHT"
    local durationSize = db[prefix .. "DurationSize"] or db.auraDurationSize or 9

    for i, icon in ipairs(icons) do
        icon:SetFrameLevel(frame:GetFrameLevel() + 5)
        local idx = i - 1
        local row = floor(idx / wrap)
        local col = idx % wrap
        
        local x = offsetX + (col * primaryX) + (row * secondaryX)
        local y = offsetY + (col * primaryY) + (row * secondaryY)
        
        icon:ClearAllPoints()
        icon:SetPoint(anchor, frame, anchor, x, y)
        icon:SetSize(scaledSize, scaledSize)
        
        -- Apply border
        if icon.border then
            if icon.border.SetThickness then
                icon.border:SetThickness(borderThickness)
            end
            local borderEnabled = db[prefix .. "BorderEnabled"] ~= false
            if borderEnabled then
                icon.border:Show()
            else
                icon.border:Hide()
            end
        end
        
        -- Apply duration text settings
        if icon.duration then
            local fontPath = self:GetFontPath(db.auraDurationFont)
            local durationFontSize = math.max(6, math.min(durationSize - 1, floor(scaledSize * 0.45)))
            self:SafeSetFont(icon.duration, fontPath, durationFontSize, db.auraDurationOutline or "OUTLINE")
            icon.duration:ClearAllPoints()
            icon.duration:SetPoint("CENTER", icon, "CENTER", 0, 0)
            local durationBox = max(8, scaledSize - 2)
            icon.duration:SetSize(durationBox, durationBox)
            icon.showDuration = db.auraDurationEnabled ~= false
        end
        
        -- Apply stack count settings
        if icon.count then
            local fontPath = self:GetFontPath(db.auraStackFont)
            self:SafeSetFont(icon.count, fontPath, db.auraStackSize or 10, db.auraStackOutline or "OUTLINE")
            icon.stackMinimum = db.auraStackMinimum or 2
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
        end
    end
end

function UnitFrames:RefreshDurationColorSettings(frame)
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    -- Update buffs
    if frame.buffIcons then
        for _, icon in ipairs(frame.buffIcons) do
            if icon.duration and db.durationColorEnabled and icon.expirationTime and icon.auraDuration then
                local remaining = icon.expirationTime - GetTime()
                if remaining > 0 then
                    local r, g, b = self:GetDurationColorByPercent(remaining, icon.auraDuration, db)
                    icon.duration:SetTextColor(r, g, b)
                end
            end
        end
    end
    
    -- Update debuffs
    if frame.debuffIcons then
        for _, icon in ipairs(frame.debuffIcons) do
            if icon.duration and db.durationColorEnabled and icon.expirationTime and icon.auraDuration then
                local remaining = icon.expirationTime - GetTime()
                if remaining > 0 then
                    local r, g, b = self:GetDurationColorByPercent(remaining, icon.auraDuration, db)
                    icon.duration:SetTextColor(r, g, b)
                end
            end
        end
    end
end

-- ============================================================================
-- FRAME STYLE APPLICATION
-- ============================================================================

function UnitFrames:ApplyFrameStyle(frame)
    if not frame then return end
    self:ApplyFrameLayout(frame)
end

-- ============================================================================
-- UNIT FRAME UPDATE
-- ============================================================================

function UnitFrames:UpdateUnitFrame(frame)
    if not frame or not frame.unit then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local unit = frame.unit
    
    -- Check if unit exists
    if not UnitExists(unit) then
        return
    end
    
    -- Check offline/dead status
    local isOffline = not UnitIsConnected(unit)
    local isDead = UnitIsDeadOrGhost(unit)
    local isAFK = UnitIsAFK(unit)
    
    -- Update status text
    if frame.statusText then
        if isOffline then
            frame.statusText:SetText("Offline")
            frame.statusText:Show()
        elseif isDead then
            frame.statusText:SetText("Dead")
            frame.statusText:Show()
        elseif isAFK then
            frame.statusText:SetText("AFK")
            frame.statusText:Show()
        else
            frame.statusText:Hide()
            end
        end
        
    -- Update health bar
    self:UpdateHealthBar(frame, db, unit, isDead, isOffline)
    
    -- Update background
    self:UpdateBackground(frame, db, unit, isDead, isOffline)
    
    -- Update name text
    self:UpdateNameText(frame, db, unit)
    
    -- Update health text
    self:UpdateHealthText(frame, db, unit, isDead, isOffline)
    
    -- Update power bar
    self:UpdatePowerBar(frame, db, unit)
    
    -- Update absorb/heal absorb/heal prediction
    self:UpdateAbsorbBars(frame, db, unit)
    
    -- Update icons
    self:UpdateRoleIcon(frame)
    self:UpdateLeaderIcon(frame)
    self:UpdateRaidTargetIcon(frame)
    
    -- Apply dead/offline fading
    if db.fadeDeadFrames and (isDead or isOffline) then
        local fadeAlpha = db.fadeDeadAlpha or 0.6
        frame:SetAlpha(fadeAlpha)
        frame.dfDeadFadeApplied = true
    else
        if frame.dfDeadFadeApplied then
            frame:SetAlpha(1)
            frame.dfDeadFadeApplied = false
            end
        end
    end
    
-- Alias for compatibility
UnitFrames.UpdateFrame = UnitFrames.UpdateUnitFrame

-- ============================================================================
-- HEALTH BAR UPDATE
-- ============================================================================

function UnitFrames:UpdateHealthBar(frame, db, unit, isDead, isOffline)
    if not frame.healthBar then return end
    
    -- Set health value
    self:SetHealthBarValue(frame.healthBar, unit)
    
    -- Apply health colors
    if self.ApplyHealthColors then
        self:ApplyHealthColors(frame)
    else
        -- Default class coloring
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS[class] then
            local color = RAID_CLASS_COLORS[class]
            frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        end
    end
    
-- ============================================================================
-- BACKGROUND UPDATE
-- ============================================================================

function UnitFrames:UpdateBackground(frame, db, unit, isDead, isOffline)
    if not frame.background then return end
    
    local bgColor = db.backgroundColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
    local colorMode = db.backgroundColorMode or "CUSTOM"
    
    if colorMode == "CLASS" then
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS[class] then
            local classColor = RAID_CLASS_COLORS[class]
            local alpha = db.backgroundClassAlpha or 0.3
            frame.background:SetColorTexture(classColor.r, classColor.g, classColor.b, alpha)
            return
        end
    end
    
    -- Check for dead/offline custom color
    if db.fadeDeadUseCustomColor and (isDead or isOffline) then
        local deadColor = db.fadeDeadBackgroundColor or {r = 0.3, g = 0, b = 0}
        local deadAlpha = db.fadeDeadBackground or 0.4
        frame.background:SetColorTexture(deadColor.r, deadColor.g, deadColor.b, deadAlpha)
        return
    end
    
    -- Default custom color
    frame.background:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a or 0.8)
end

-- ============================================================================
-- NAME TEXT UPDATE
-- ============================================================================

function UnitFrames:UpdateNameText(frame, db, unit)
    if not frame.nameText or not db.nameTextEnabled then return end
    
    local name = UnitName(unit) or ""
    
    -- Truncate if enabled
    if db.nameTextTruncate and db.nameTextMaxLength then
        local maxLen = db.nameTextMaxLength
        if #name > maxLen then
            name = name:sub(1, maxLen) .. "..."
    end
end

    frame.nameText:SetText(name)
    
    -- Apply color
    local colorMode = db.nameTextColorMode or "WHITE"
    if colorMode == "CLASS" then
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS[class] then
            local color = RAID_CLASS_COLORS[class]
            frame.nameText:SetTextColor(color.r, color.g, color.b)
        return
        end
    end
    
    -- Default white
    local color = db.nameTextColor or {r = 1, g = 1, b = 1}
    frame.nameText:SetTextColor(color.r, color.g, color.b)
end

-- ============================================================================
-- HEALTH TEXT UPDATE
-- ============================================================================

function UnitFrames:UpdateHealthText(frame, db, unit, isDead, isOffline)
    if not frame.healthText then return end
    
    if not db.healthTextEnabled then
            frame.healthText:Hide()
        return
    end
    
    -- Hide if dead/offline (status text shows that)
    if isDead or isOffline then
        frame.healthText:SetText("")
        return
    end
    
    local format = db.healthTextFormat or "PERCENT"

    -- Avoid boolean checks on secret values; format directly like DandersFrames.
    local success = pcall(function()
        if format == "PERCENT" or format == "PERCENTAGE" then
            -- Match old LilyUI: use the safe percent helper and avoid secret checks.
            -- NOTE: Use dot notation (not colon) since GetSafeHealthPercent only takes unit as parameter
            if self.GetSafeHealthPercent then
                local pct = self.GetSafeHealthPercent(unit)
                frame.healthText:SetFormattedText("%.0f%%", pct)
            else
                -- Fallback: use global CurveConstants (not Enum.CurveConstants)
                local pct = UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 and UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
                if pct ~= nil then
                    frame.healthText:SetFormattedText("%.0f%%", pct)
                else
                    local current = UnitHealth(unit, true)
                    local maxValue = UnitHealthMax(unit, true)
                    frame.healthText:SetFormattedText("%.0f%%", (current / maxValue) * 100)
                end
            end
        elseif format == "DEFICIT" then
            if UnitHealthMissing then
                local missing = UnitHealthMissing(unit, true)
                if C_StringUtil and C_StringUtil.TruncateWhenZero and C_StringUtil.WrapString then
                    local truncated = C_StringUtil.TruncateWhenZero(missing)
                    frame.healthText:SetText(C_StringUtil.WrapString(truncated, "-"))
                elseif db.healthTextAbbreviate and AbbreviateNumbers then
                    frame.healthText:SetFormattedText("-%s", AbbreviateNumbers(missing))
                elseif db.healthTextAbbreviate then
                    frame.healthText:SetFormattedText("-%s", self:FormatNumber(missing))
                else
                    frame.healthText:SetFormattedText("-%s", missing)
                end
            else
                frame.healthText:SetText("")
            end
        elseif format == "CURRENT" then
            local current = UnitHealth(unit, true)
            if db.healthTextAbbreviate and AbbreviateNumbers then
                frame.healthText:SetText(AbbreviateNumbers(current))
            elseif db.healthTextAbbreviate then
                frame.healthText:SetText(self:FormatNumber(current))
            else
                frame.healthText:SetFormattedText("%s", current)
            end
        elseif format == "CURRENT_MAX" or format == "CURRENTMAX" then
            local current = UnitHealth(unit, true)
            local maxValue = UnitHealthMax(unit, true)
            if db.healthTextAbbreviate and AbbreviateNumbers then
                frame.healthText:SetFormattedText("%s/%s", AbbreviateNumbers(current), AbbreviateNumbers(maxValue))
            elseif db.healthTextAbbreviate then
                frame.healthText:SetFormattedText("%s/%s", self:FormatNumber(current), self:FormatNumber(maxValue))
            else
                frame.healthText:SetFormattedText("%s/%s", current, maxValue)
            end
        else
            frame.healthText:SetText("")
        end
    end)

    if not success then
        frame.healthText:SetText("")
        return
    end

    frame.healthText:Show()
end

-- ============================================================================
-- POWER BAR UPDATE
-- ============================================================================

function UnitFrames:UpdatePowerBar(frame, db, unit)
    if not frame.dfPowerBar then return end
    
    if not db.powerBarEnabled then
        frame.dfPowerBar:Hide()
        return
    end
    
    local power = UnitPower(unit)
    local powerMax = UnitPowerMax(unit)
    
    if powerMax <= 0 then
        frame.dfPowerBar:Hide()
        return
    end
    
    frame.dfPowerBar:SetMinMaxValues(0, powerMax)
    frame.dfPowerBar:SetValue(power)
    
    -- Apply color
    local colorMode = db.powerBarColorMode or "POWER"
    
    if colorMode == "POWER" then
        local powerType = UnitPowerType(unit)
        local color = PowerColors[powerType] or {0.5, 0.5, 0.5}
        frame.dfPowerBar:SetStatusBarColor(color[1], color[2], color[3])
    elseif colorMode == "CLASS" then
        local _, class = UnitClass(unit)
        if class and RAID_CLASS_COLORS[class] then
            local color = RAID_CLASS_COLORS[class]
            frame.dfPowerBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    else
        local color = db.powerBarCustomColor or {r = 0.3, g = 0.3, b = 0.8}
        frame.dfPowerBar:SetStatusBarColor(color.r, color.g, color.b)
    end
    
    frame.dfPowerBar:Show()
end

-- ============================================================================
-- ABSORB BARS UPDATE
-- ============================================================================

function UnitFrames:UpdateAbsorbBars(frame, db, unit)
    if not frame.healthBar then return end
    
    local healthMax = UnitHealthMax(unit)
    if not healthMax then return end
    
    -- Get absorb values
    local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
    local healAbsorb = UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit) or 0
    local allHeals = UnitGetIncomingHeals and UnitGetIncomingHeals(unit) or 0
    
    -- Update absorb bar
    if frame.absorbBar and db.absorbBarEnabled then
        frame.absorbBar:SetMinMaxValues(0, healthMax)
        frame.absorbBar:SetValue(absorb)
        frame.absorbBar:Show()
    elseif frame.absorbBar then
        frame.absorbBar:Hide()
    end
    
    -- Update heal absorb bar
    if frame.healAbsorbBar and db.healAbsorbEnabled then
        frame.healAbsorbBar:SetMinMaxValues(0, healthMax)
        frame.healAbsorbBar:SetValue(healAbsorb)
        frame.healAbsorbBar:Show()
    elseif frame.healAbsorbBar then
        frame.healAbsorbBar:Hide()
    end
    
    -- Update heal prediction
    if frame.healPrediction and db.healPredictionEnabled then
        frame.healPrediction:SetMinMaxValues(0, healthMax)
        frame.healPrediction:SetValue(allHeals)
        frame.healPrediction:Show()
    elseif frame.healPrediction then
        frame.healPrediction:Hide()
    end
end

-- ============================================================================
-- ICON UPDATES
-- ============================================================================

function UnitFrames:UpdateRoleIcon(frame)
    if not frame.roleIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.roleIconEnabled then
        frame.roleIcon:Hide()
        return
    end
    
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(frame.unit) or "NONE"
    
    if role == "TANK" then
        frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        frame.roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
        frame.roleIcon:Show()
    elseif role == "HEALER" then
        frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        frame.roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
        frame.roleIcon:Show()
    elseif role == "DAMAGER" then
        frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        frame.roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end
end

function UnitFrames:UpdateLeaderIcon(frame)
    if not frame.leaderIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.leaderIconEnabled then
        frame.leaderIcon:Hide()
        return
    end
    
    local isLeader = UnitIsGroupLeader and UnitIsGroupLeader(frame.unit)
    local isAssistant = UnitIsGroupAssistant and UnitIsGroupAssistant(frame.unit)
    
    if isLeader then
        frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        frame.leaderIcon:Show()
    elseif isAssistant then
        frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        frame.leaderIcon:Show()
    else
        frame.leaderIcon:Hide()
    end
end

function UnitFrames:UpdateRaidTargetIcon(frame)
    if not frame.raidTargetIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.raidTargetIconEnabled then
        frame.raidTargetIcon:Hide()
        return
    end
    
    local index = GetRaidTargetIndex and GetRaidTargetIndex(frame.unit)
    
    if index then
        local texture = frame.raidTargetIcon.texture or frame.raidTargetIcon
        texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(texture, index)
        frame.raidTargetIcon:Show()
    else
        frame.raidTargetIcon:Hide()
                end
            end
            
function UnitFrames:UpdateReadyCheckIcon(frame)
    if not frame.readyCheckIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.readyCheckIconEnabled then
        frame.readyCheckIcon:Hide()
        return
    end
    
    local status = GetReadyCheckStatus and GetReadyCheckStatus(frame.unit)
    
    if status == "ready" then
        frame.readyCheckIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        frame.readyCheckIcon:Show()
    elseif status == "notready" then
        frame.readyCheckIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        frame.readyCheckIcon:Show()
    elseif status == "waiting" then
        frame.readyCheckIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
        frame.readyCheckIcon:Show()
    else
        frame.readyCheckIcon:Hide()
    end
end

function UnitFrames:UpdateCenterStatusIcon(frame)
    if not frame.centerStatusIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.centerStatusIconEnabled then
        frame.centerStatusIcon:Hide()
        return
    end
    
    -- Check for resurrection pending
    local hasRes = UnitHasIncomingResurrection and UnitHasIncomingResurrection(frame.unit)
    if hasRes then
        frame.centerStatusIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
        frame.centerStatusIcon:Show()
        return
    end
    
    -- Check for summon pending
    local summonStatus = C_IncomingSummon and C_IncomingSummon.IncomingSummonStatus(frame.unit)
    if summonStatus and summonStatus ~= Enum.SummonStatus.None then
        if summonStatus == Enum.SummonStatus.Pending then
            frame.centerStatusIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-SummonPending")
        elseif summonStatus == Enum.SummonStatus.Accepted then
            frame.centerStatusIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-SummonAccepted")
        elseif summonStatus == Enum.SummonStatus.Declined then
            frame.centerStatusIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-SummonDeclined")
        end
        frame.centerStatusIcon:Show()
        return
    end
    
    frame.centerStatusIcon:Hide()
end

function UnitFrames:UpdateAllRoleIcons()
    if self.playerFrame then
        self:UpdateRoleIcon(self.playerFrame)
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame then
            self:UpdateRoleIcon(frame)
        end
    end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame then
            self:UpdateRoleIcon(frame)
        end
    end
end
