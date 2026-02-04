--[[
    LilyUI Unit Frames - Pet Frame Support
    Handles pet frames for party and raid units
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitExists = UnitExists
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitClass = UnitClass
local UnitName = UnitName
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

-- Pet frame storage
UnitFrames.petFrames = UnitFrames.petFrames or {}
UnitFrames.partyPetFrames = UnitFrames.partyPetFrames or {}

-- ============================================================================
-- PET FRAME CREATION
-- ============================================================================

--[[
    Create a pet frame for a unit
    @param ownerUnit string - The owner's unit ID (e.g., "player", "party1", "raid1")
    @param isRaid boolean - Whether this is for raid frames
    @return Frame - The created pet frame
]]
function UnitFrames:CreatePetFrame(ownerUnit, isRaid)
    local petUnit
    
    if ownerUnit == "player" then
        petUnit = "pet"
    elseif ownerUnit:match("^party(%d)$") then
        local index = ownerUnit:match("^party(%d)$")
        petUnit = "partypet" .. index
    elseif ownerUnit:match("^raid(%d+)$") then
        local index = ownerUnit:match("^raid(%d+)$")
        petUnit = "raidpet" .. index
    else
        return nil
    end
    
    local db = isRaid and self:GetRaidDB() or self:GetDB()
    
    local frame = CreateFrame("Button", "LilyUIPetFrame_" .. petUnit, UIParent, "SecureUnitButtonTemplate")
    frame:SetAttribute("unit", petUnit)
    frame:SetAttribute("type1", "target")
    frame:SetAttribute("type2", "togglemenu")
    
    frame.unit = petUnit
    frame.ownerUnit = ownerUnit
    frame.isPetFrame = true
    frame.isRaidFrame = isRaid
    
    -- Apply pet-specific sizing
    local width = db.petFrameWidth or (db.frameWidth * 0.8) or 96
    local height = db.petFrameHeight or (db.frameHeight * 0.6) or 30
    
    frame:SetSize(self:PixelPerfect(width), self:PixelPerfect(height))
    
    -- Create background
    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    frame.background:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Create health bar
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.healthBar:SetStatusBarTexture(self:GetTexturePath(db.healthBarTexture))
    frame.healthBar:SetMinMaxValues(0, 100)
    frame.healthBar:SetValue(100)
    
    -- Create name text
    frame.nameText = frame:CreateFontString(nil, "OVERLAY")
    self:SafeSetFont(frame.nameText, self:GetFontPath(db.nameTextFont), (db.petNameSize or 9), db.nameTextOutline or "OUTLINE")
    frame.nameText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.nameText:SetJustifyH("CENTER")
    
    -- Create borders
    frame.borderTop = frame:CreateTexture(nil, "OVERLAY")
    frame.borderBottom = frame:CreateTexture(nil, "OVERLAY")
    frame.borderLeft = frame:CreateTexture(nil, "OVERLAY")
    frame.borderRight = frame:CreateTexture(nil, "OVERLAY")
    
    local borderColor = db.petBorderColor or db.borderColor or {r = 0, g = 0, b = 0, a = 1}
    local borderSize = self:PixelPerfectThickness(db.petBorderSize or 1)
    
    frame.borderTop:SetHeight(borderSize)
    frame.borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    frame.borderTop:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
    
    frame.borderBottom:SetHeight(borderSize)
    frame.borderBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    frame.borderBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    frame.borderBottom:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
    
    frame.borderLeft:SetWidth(borderSize)
    frame.borderLeft:SetPoint("TOPLEFT", frame, "TOPLEFT")
    frame.borderLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    frame.borderLeft:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
    
    frame.borderRight:SetWidth(borderSize)
    frame.borderRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    frame.borderRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    frame.borderRight:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a or 1)
    
    -- Event handling
    frame:RegisterEvent("UNIT_HEALTH")
    frame:RegisterEvent("UNIT_MAXHEALTH")
    frame:RegisterEvent("UNIT_PET")
    frame:RegisterEvent("UNIT_NAME_UPDATE")
    
    frame:SetScript("OnEvent", function(self, event, eventUnit)
        if eventUnit == self.unit or eventUnit == self.ownerUnit then
            UnitFrames:UpdatePetFrame(self)
        end
    end)
    
    -- Register unit watch
    RegisterUnitWatch(frame)
    
    -- Tooltip
    frame:SetScript("OnEnter", function(self)
        if db.tooltipEnabled ~= false then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    
    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return frame
end

-- ============================================================================
-- PET FRAME UPDATES
-- ============================================================================

--[[
    Update a pet frame's display
    @param frame Frame - The pet frame to update
]]
function UnitFrames:UpdatePetFrame(frame)
    if not frame or not frame.unit then return end
    
    local unit = frame.unit
    
    if not UnitExists(unit) then
        return
    end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    -- Update health
    local health = UnitHealth(unit)
    local healthMax = UnitHealthMax(unit)
    
    if healthMax > 0 then
        local pct = (health / healthMax) * 100
        frame.healthBar:SetValue(pct)
    else
        frame.healthBar:SetValue(0)
    end
    
    -- Update health color
    local colorMode = db.petHealthColorMode or "OWNER_CLASS"
    
    if colorMode == "OWNER_CLASS" then
        -- Color by owner's class
        local _, ownerClass = UnitClass(frame.ownerUnit)
        if ownerClass and RAID_CLASS_COLORS[ownerClass] then
            local color = RAID_CLASS_COLORS[ownerClass]
            frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
        else
            frame.healthBar:SetStatusBarColor(0.5, 0.5, 0.5)
        end
    elseif colorMode == "GRADIENT" then
        local healthPct = healthMax > 0 and (health / healthMax) or 1
        local r, g, b = self:GetGradientColor(healthPct, "default")
        frame.healthBar:SetStatusBarColor(r, g, b)
    else
        local customColor = db.petHealthColor or {r = 0.2, g = 0.8, b = 0.2}
        frame.healthBar:SetStatusBarColor(customColor.r, customColor.g, customColor.b)
    end
    
    -- Update name
    local name = UnitName(unit) or ""
    if db.petNameTruncate and #name > (db.petNameMaxLength or 8) then
        name = name:sub(1, db.petNameMaxLength or 8) .. "..."
    end
    frame.nameText:SetText(name)
    
    -- Apply dead fade
    if UnitIsDeadOrGhost(unit) then
        frame:SetAlpha(db.petDeadAlpha or 0.4)
    else
        frame:SetAlpha(1)
    end
end

--[[
    Apply layout to pet frame
    @param frame Frame - The pet frame
    @param ownerFrame Frame - The owner's frame
]]
function UnitFrames:ApplyPetFrameLayout(frame, ownerFrame)
    if not frame or not ownerFrame then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.petFrameEnabled then
        frame:Hide()
        return
    end
    
    -- Size
    local width = db.petFrameWidth or (db.frameWidth * 0.8)
    local height = db.petFrameHeight or (db.frameHeight * 0.6)
    frame:SetSize(self:PixelPerfect(width), self:PixelPerfect(height))
    
    -- Position relative to owner
    local anchor = db.petFrameAnchor or "BOTTOM"
    local offsetX = db.petFrameOffsetX or 0
    local offsetY = db.petFrameOffsetY or -2
    
    frame:ClearAllPoints()
    
    if anchor == "BOTTOM" then
        frame:SetPoint("TOP", ownerFrame, "BOTTOM", offsetX, offsetY)
    elseif anchor == "TOP" then
        frame:SetPoint("BOTTOM", ownerFrame, "TOP", offsetX, -offsetY)
    elseif anchor == "LEFT" then
        frame:SetPoint("RIGHT", ownerFrame, "LEFT", -offsetX, offsetY)
    elseif anchor == "RIGHT" then
        frame:SetPoint("LEFT", ownerFrame, "RIGHT", offsetX, offsetY)
    end
    
    -- Health bar texture
    frame.healthBar:SetStatusBarTexture(self:GetTexturePath(db.healthBarTexture))
    
    -- Name text
    self:SafeSetFont(frame.nameText, self:GetFontPath(db.nameTextFont), db.petNameSize or 9, db.nameTextOutline or "OUTLINE")
    
    frame:Show()
end

-- ============================================================================
-- PET FRAME INITIALIZATION
-- ============================================================================

--[[
    Initialize pet frames for party
]]
function UnitFrames:InitializePartyPetFrames()
    local db = self:GetDB()
    
    if not db.petFrameEnabled then return end
    
    -- Player pet
    if not self.petFrames["player"] then
        self.petFrames["player"] = self:CreatePetFrame("player", false)
    end
    
    -- Party pet frames
    for i = 1, 4 do
        local ownerUnit = "party" .. i
        if not self.partyPetFrames[i] then
            self.partyPetFrames[i] = self:CreatePetFrame(ownerUnit, false)
        end
    end
end

--[[
    Initialize pet frames for raid
]]
function UnitFrames:InitializeRaidPetFrames()
    local db = self:GetRaidDB()
    
    if not db.petFrameEnabled then return end
    
    -- Raid pet frames (create on demand or in batches)
    -- For performance, only create for first 10 raid members by default
    local maxPets = db.maxRaidPets or 10
    
    for i = 1, maxPets do
        local ownerUnit = "raid" .. i
        if not self.petFrames["raid" .. i] then
            self.petFrames["raid" .. i] = self:CreatePetFrame(ownerUnit, true)
        end
    end
end

-- ============================================================================
-- PET FRAME LAYOUT UPDATE
-- ============================================================================

--[[
    Update layout for all party pet frames
]]
function UnitFrames:UpdatePartyPetLayout()
    if InCombatLockdown() then
        self.pendingPartyPetLayout = true
        return
    end
    
    local db = self:GetDB()
    
    if not db.petFrameEnabled then
        self:HideAllPartyPets()
        return
    end
    
    -- Player pet
    if self.petFrames["player"] and self.playerFrame then
        self:ApplyPetFrameLayout(self.petFrames["player"], self.playerFrame)
        self:UpdatePetFrame(self.petFrames["player"])
    end
    
    -- Party pets
    for i = 1, 4 do
        local petFrame = self.partyPetFrames[i]
        local ownerFrame = self.partyFrames[i]
        
        if petFrame and ownerFrame then
            self:ApplyPetFrameLayout(petFrame, ownerFrame)
            self:UpdatePetFrame(petFrame)
        end
    end
end

--[[
    Update layout for all raid pet frames
]]
function UnitFrames:UpdateRaidPetLayout()
    if InCombatLockdown() then
        self.pendingRaidPetLayout = true
        return
    end
    
    local db = self:GetRaidDB()
    
    if not db.petFrameEnabled then
        self:HideAllRaidPets()
        return
    end
    
    local maxPets = db.maxRaidPets or 10
    
    for i = 1, maxPets do
        local petFrame = self.petFrames["raid" .. i]
        local ownerFrame = self.raidFrames[i]
        
        if petFrame and ownerFrame then
            self:ApplyPetFrameLayout(petFrame, ownerFrame)
            self:UpdatePetFrame(petFrame)
        end
    end
end

-- ============================================================================
-- PET FRAME VISIBILITY
-- ============================================================================

--[[
    Hide all party pet frames
]]
function UnitFrames:HideAllPartyPets()
    if self.petFrames["player"] then
        self.petFrames["player"]:Hide()
    end
    
    for i = 1, 4 do
        if self.partyPetFrames[i] then
            self.partyPetFrames[i]:Hide()
        end
    end
end

--[[
    Hide all raid pet frames
]]
function UnitFrames:HideAllRaidPets()
    for key, frame in pairs(self.petFrames) do
        if key:match("^raid") then
            frame:Hide()
        end
    end
end

-- ============================================================================
-- PET FRAME RANGE HANDLING
-- ============================================================================

--[[
    Update pet frame alpha based on owner's range
    @param petFrame Frame - The pet frame
    @param ownerInRange boolean - Whether the owner is in range
]]
function UnitFrames:UpdatePetRangeAlpha(petFrame, ownerInRange)
    if not petFrame then return end
    
    local db = petFrame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.petInheritRange then return end
    
    local outOfRangeAlpha = db.outOfRangeAlpha or 0.4
    
    if ownerInRange then
        if not UnitIsDeadOrGhost(petFrame.unit) then
            petFrame:SetAlpha(1)
        end
    else
        petFrame:SetAlpha(outOfRangeAlpha)
    end
end

-- ============================================================================
-- UPDATE ALL PETS
-- ============================================================================

--[[
    Update all pet frames
]]
function UnitFrames:UpdateAllPetFrames()
    for _, frame in pairs(self.petFrames) do
        self:UpdatePetFrame(frame)
    end
    
    for _, frame in pairs(self.partyPetFrames) do
        self:UpdatePetFrame(frame)
    end
end
