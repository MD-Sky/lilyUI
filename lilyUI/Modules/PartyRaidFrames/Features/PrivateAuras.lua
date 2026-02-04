--[[
    LilyUI Unit Frames - Private Aura System
    Handles private aura anchors for units
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local C_UnitAuras = C_UnitAuras
local floor = math.floor

-- ============================================================================
-- PRIVATE AURA ANCHOR CREATION
-- ============================================================================

--[[
    Create private aura anchor for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:CreatePrivateAuraAnchor(frame)
    if frame.privateAuraAnchor then return end
    
    local anchor = CreateFrame("Frame", nil, frame, "SecureFrameTemplate")
    anchor:SetSize(1, 1)
    anchor:SetPoint("CENTER", frame, "CENTER", 0, 0)
    anchor:Hide()
    
    frame.privateAuraAnchor = anchor
    frame.privateAuraIcons = {}
end

--[[
    Update private aura anchor for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:UpdatePrivateAuraAnchor(frame)
    if not frame or not frame.unit then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.privateAurasEnabled then
        if frame.privateAuraAnchor then
            frame.privateAuraAnchor:Hide()
        end
        return
    end
    
    -- Create anchor if needed
    if not frame.privateAuraAnchor then
        self:CreatePrivateAuraAnchor(frame)
    end
    
    local anchor = frame.privateAuraAnchor
    
    -- Position anchor
    local anchorPoint = db.privateAuraAnchor or "TOP"
    local offsetX = db.privateAuraOffsetX or 0
    local offsetY = db.privateAuraOffsetY or 5
    
    anchor:ClearAllPoints()
    anchor:SetPoint(anchorPoint, frame, anchorPoint, offsetX, offsetY)
    
    -- Show anchor
    anchor:Show()
    
    -- Setup private aura display
    self:SetupPrivateAuraDisplay(frame, db)
end

-- ============================================================================
-- PRIVATE AURA DISPLAY
-- ============================================================================

--[[
    Setup private aura display for unit
    @param frame Frame - The unit frame
    @param db table - Database settings
]]
function UnitFrames:SetupPrivateAuraDisplay(frame, db)
    if not frame.privateAuraAnchor or not frame.unit then return end
    
    local anchor = frame.privateAuraAnchor
    local maxIcons = db.privateAuraMaxIcons or 4
    local iconSize = db.privateAuraSize or 16
    local spacing = db.privateAuraSpacing or 2
    local growth = db.privateAuraGrowth or "RIGHT"
    
    -- Ensure we have enough icon frames
    while #frame.privateAuraIcons < maxIcons do
        local icon = self:CreatePrivateAuraIcon(anchor, #frame.privateAuraIcons + 1)
        table.insert(frame.privateAuraIcons, icon)
    end
    
    -- Position icons
    for i, icon in ipairs(frame.privateAuraIcons) do
        icon:ClearAllPoints()
        icon:SetSize(iconSize, iconSize)
        
        local offset = (i - 1) * (iconSize + spacing)
        
        if growth == "RIGHT" then
            icon:SetPoint("LEFT", anchor, "LEFT", offset, 0)
        elseif growth == "LEFT" then
            icon:SetPoint("RIGHT", anchor, "RIGHT", -offset, 0)
        elseif growth == "DOWN" then
            icon:SetPoint("TOP", anchor, "TOP", 0, -offset)
        else -- UP
            icon:SetPoint("BOTTOM", anchor, "BOTTOM", 0, offset)
        end
        
        if i <= maxIcons then
            icon:Show()
        else
            icon:Hide()
        end
    end
    
    -- Update anchor size
    if growth == "RIGHT" or growth == "LEFT" then
        anchor:SetSize(maxIcons * (iconSize + spacing), iconSize)
    else
        anchor:SetSize(iconSize, maxIcons * (iconSize + spacing))
    end
end

--[[
    Create a private aura icon
    @param parent Frame - Parent anchor frame
    @param index number - Icon index
    @return Frame - The icon frame
]]
function UnitFrames:CreatePrivateAuraIcon(parent, index)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(16, 16)
    icon.index = index
    
    -- Background
    icon.bg = icon:CreateTexture(nil, "BACKGROUND")
    icon.bg:SetAllPoints()
    icon.bg:SetColorTexture(0, 0, 0, 0.5)
    
    -- Icon texture (placeholder - actual private aura textures handled by game)
    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Border
    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    icon.border:SetColorTexture(0, 0, 0, 1)
    
    icon:Hide()
    return icon
end

-- ============================================================================
-- PRIVATE AURA ANCHOR REGISTRATION
-- ============================================================================

--[[
    Register private aura anchor with game
    @param frame Frame - The unit frame
]]
function UnitFrames:RegisterPrivateAuraAnchor(frame)
    if not frame or not frame.unit or not frame.privateAuraAnchor then return end
    
    -- Only works in War Within and later
    if not C_UnitAuras or not C_UnitAuras.AddPrivateAuraAnchor then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.privateAurasEnabled then return end
    
    -- Unregister existing if any
    self:UnregisterPrivateAuraAnchor(frame)
    
    -- Create anchor point for private auras
    local anchorData = {
        unitToken = frame.unit,
        auraIndex = 1,
        parent = frame.privateAuraAnchor,
        showCountdownFrame = true,
        showCountdownNumbers = true,
        iconInfo = {
            iconWidth = db.privateAuraSize or 16,
            iconHeight = db.privateAuraSize or 16,
            iconAnchor = {
                point = "CENTER",
                relativeTo = frame.privateAuraAnchor,
                relativePoint = "CENTER",
                offsetX = 0,
                offsetY = 0,
            },
        },
    }
    
    -- Register with game
    local success = pcall(function()
        frame.privateAuraAnchorInfo = C_UnitAuras.AddPrivateAuraAnchor(anchorData)
    end)
    
    if not success then
        frame.privateAuraAnchorInfo = nil
    end
end

--[[
    Unregister private aura anchor
    @param frame Frame - The unit frame
]]
function UnitFrames:UnregisterPrivateAuraAnchor(frame)
    if not frame or not frame.privateAuraAnchorInfo then return end
    
    -- Only works in War Within and later
    if not C_UnitAuras or not C_UnitAuras.RemovePrivateAuraAnchor then return end
    
    pcall(function()
        C_UnitAuras.RemovePrivateAuraAnchor(frame.privateAuraAnchorInfo)
    end)
    
    frame.privateAuraAnchorInfo = nil
end

-- ============================================================================
-- BATCH OPERATIONS
-- ============================================================================

--[[
    Update private aura anchors for all frames
]]
function UnitFrames:UpdateAllPrivateAuraAnchors()
    -- Update player frame
    if self.playerFrame then
        self:UpdatePrivateAuraAnchor(self.playerFrame)
        self:RegisterPrivateAuraAnchor(self.playerFrame)
    end
    
    -- Update party frames
    for _, frame in pairs(self.partyFrames) do
        self:UpdatePrivateAuraAnchor(frame)
        self:RegisterPrivateAuraAnchor(frame)
    end
    
    -- Update raid frames
    for _, frame in pairs(self.raidFrames) do
        self:UpdatePrivateAuraAnchor(frame)
        self:RegisterPrivateAuraAnchor(frame)
    end
end

--[[
    Apply layout to all private aura anchors
]]
function UnitFrames:ApplyAllPrivateAuraLayouts()
    local db = self:GetDB()
    local raidDb = self:GetRaidDB()
    
    -- Update player frame
    if self.playerFrame then
        self:SetupPrivateAuraDisplay(self.playerFrame, db)
    end
    
    -- Update party frames
    for _, frame in pairs(self.partyFrames) do
        self:SetupPrivateAuraDisplay(frame, db)
    end
    
    -- Update raid frames
    for _, frame in pairs(self.raidFrames) do
        self:SetupPrivateAuraDisplay(frame, raidDb)
    end
end
