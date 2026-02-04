--[[
    LilyUI Unit Frames - Highlight System
    Selection, mouseover, and aggro highlights
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitIsUnit = UnitIsUnit
local UnitThreatSituation = UnitThreatSituation
local CreateFrame = CreateFrame
local GetTime = GetTime
local floor = math.floor
local sin = math.sin
local pi = math.pi

-- ============================================================================
-- HIGHLIGHT FRAME CREATION
-- ============================================================================

--[[
    Create highlight elements for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:CreateHighlights(frame)
    if frame.highlights then return end
    
    frame.highlights = {}
    
    -- Selection highlight (when unit is targeted)
    self:CreateSelectionHighlight(frame)
    
    -- Mouseover highlight
    self:CreateMouseoverHighlight(frame)
    
    -- Aggro highlight
    self:CreateAggroHighlight(frame)
end

-- ============================================================================
-- SELECTION HIGHLIGHT
-- ============================================================================

--[[
    Create selection highlight (animated border for targeted unit)
    @param frame Frame - The unit frame
]]
function UnitFrames:CreateSelectionHighlight(frame)
    local highlight = CreateFrame("Frame", nil, frame)
    highlight:SetAllPoints()
    highlight:SetFrameLevel(frame:GetFrameLevel() + 5)
    
    -- Create border textures
    highlight.borders = {}
    
    local borderWidth = 2
    
    -- Top
    highlight.borders.top = highlight:CreateTexture(nil, "OVERLAY", nil, 6)
    highlight.borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT")
    highlight.borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    highlight.borders.top:SetHeight(borderWidth)
    highlight.borders.top:SetColorTexture(1, 1, 1, 1)
    
    -- Bottom
    highlight.borders.bottom = highlight:CreateTexture(nil, "OVERLAY", nil, 6)
    highlight.borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    highlight.borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    highlight.borders.bottom:SetHeight(borderWidth)
    highlight.borders.bottom:SetColorTexture(1, 1, 1, 1)
    
    -- Left
    highlight.borders.left = highlight:CreateTexture(nil, "OVERLAY", nil, 6)
    highlight.borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT")
    highlight.borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    highlight.borders.left:SetWidth(borderWidth)
    highlight.borders.left:SetColorTexture(1, 1, 1, 1)
    
    -- Right
    highlight.borders.right = highlight:CreateTexture(nil, "OVERLAY", nil, 6)
    highlight.borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    highlight.borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    highlight.borders.right:SetWidth(borderWidth)
    highlight.borders.right:SetColorTexture(1, 1, 1, 1)
    
    -- Animation state
    highlight.animated = false
    highlight.animTime = 0
    
    highlight:Hide()
    frame.highlights.selection = highlight
end

--[[
    Show selection highlight
    @param frame Frame - The unit frame
]]
function UnitFrames:ShowSelectionHighlight(frame)
    if not frame.highlights or not frame.highlights.selection then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local highlight = frame.highlights.selection
    
    if not db.selectionHighlightEnabled then
        highlight:Hide()
        return
    end
    
    local color = db.selectionHighlightColor or {r = 1, g = 1, b = 1, a = 1}
    
    for _, border in pairs(highlight.borders) do
        border:SetColorTexture(color.r, color.g, color.b, color.a or 1)
    end
    
    -- Start animation if enabled
    if db.selectionAnimated then
        highlight.animated = true
        highlight:SetScript("OnUpdate", function(self, elapsed)
            self.animTime = self.animTime + elapsed
            
            -- Pulse effect
            local alpha = 0.5 + 0.5 * sin(self.animTime * 4)
            for _, border in pairs(self.borders) do
                border:SetAlpha(alpha)
            end
        end)
    else
        highlight.animated = false
        highlight:SetScript("OnUpdate", nil)
        for _, border in pairs(highlight.borders) do
            border:SetAlpha(1)
        end
    end
    
    highlight:Show()
end

--[[
    Hide selection highlight
    @param frame Frame - The unit frame
]]
function UnitFrames:HideSelectionHighlight(frame)
    if not frame.highlights or not frame.highlights.selection then return end
    
    frame.highlights.selection:Hide()
    frame.highlights.selection:SetScript("OnUpdate", nil)
end

-- ============================================================================
-- MOUSEOVER HIGHLIGHT
-- ============================================================================

--[[
    Create mouseover highlight
    @param frame Frame - The unit frame
]]
function UnitFrames:CreateMouseoverHighlight(frame)
    local highlight = frame:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)
    highlight:SetBlendMode("ADD")
    highlight:Hide()
    
    frame.highlights.mouseover = highlight
    
    -- Hook mouse events
    frame:HookScript("OnEnter", function(self)
        UnitFrames:OnFrameEnter(self)
    end)
    
    frame:HookScript("OnLeave", function(self)
        UnitFrames:OnFrameLeave(self)
    end)
end

--[[
    Handle frame mouse enter
    @param frame Frame - The unit frame
]]
function UnitFrames:OnFrameEnter(frame)
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if db.mouseoverHighlightEnabled and frame.highlights and frame.highlights.mouseover then
        local color = db.mouseoverHighlightColor or {r = 1, g = 1, b = 1, a = 0.15}
        frame.highlights.mouseover:SetColorTexture(color.r, color.g, color.b, color.a or 0.15)
        frame.highlights.mouseover:Show()
    end
    
    frame.isMouseOver = true
end

--[[
    Handle frame mouse leave
    @param frame Frame - The unit frame
]]
function UnitFrames:OnFrameLeave(frame)
    if frame.highlights and frame.highlights.mouseover then
        frame.highlights.mouseover:Hide()
    end
    
    frame.isMouseOver = false
end

-- ============================================================================
-- AGGRO HIGHLIGHT
-- ============================================================================

--[[
    Create aggro highlight
    @param frame Frame - The unit frame
]]
function UnitFrames:CreateAggroHighlight(frame)
    local highlight = CreateFrame("Frame", nil, frame)
    highlight:SetAllPoints()
    highlight:SetFrameLevel(frame:GetFrameLevel() + 4)
    
    -- Create border textures
    highlight.borders = {}
    
    local borderWidth = 2
    
    -- Top
    highlight.borders.top = highlight:CreateTexture(nil, "OVERLAY", nil, 5)
    highlight.borders.top:SetPoint("TOPLEFT", frame, "TOPLEFT")
    highlight.borders.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    highlight.borders.top:SetHeight(borderWidth)
    
    -- Bottom
    highlight.borders.bottom = highlight:CreateTexture(nil, "OVERLAY", nil, 5)
    highlight.borders.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    highlight.borders.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    highlight.borders.bottom:SetHeight(borderWidth)
    
    -- Left
    highlight.borders.left = highlight:CreateTexture(nil, "OVERLAY", nil, 5)
    highlight.borders.left:SetPoint("TOPLEFT", frame, "TOPLEFT")
    highlight.borders.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
    highlight.borders.left:SetWidth(borderWidth)
    
    -- Right
    highlight.borders.right = highlight:CreateTexture(nil, "OVERLAY", nil, 5)
    highlight.borders.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT")
    highlight.borders.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT")
    highlight.borders.right:SetWidth(borderWidth)
    
    highlight:Hide()
    frame.highlights.aggro = highlight
end

-- Aggro colors by threat level
local AggroColors = {
    [0] = {r = 0.0, g = 0.0, b = 0.0, a = 0.0},  -- No threat
    [1] = {r = 1.0, g = 1.0, b = 0.0, a = 1.0},  -- High threat (yellow)
    [2] = {r = 1.0, g = 0.6, b = 0.0, a = 1.0},  -- Tanking, not highest (orange)
    [3] = {r = 1.0, g = 0.0, b = 0.0, a = 1.0},  -- Has aggro (red)
}

--[[
    Update aggro highlight for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:UpdateAggroHighlight(frame)
    if not frame.highlights or not frame.highlights.aggro then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local highlight = frame.highlights.aggro
    
    if not db.aggroHighlightEnabled then
        highlight:Hide()
        return
    end
    
    local threatStatus = UnitThreatSituation(frame.unit) or 0
    
    -- Determine if we should show aggro
    local showAggro = threatStatus >= (db.aggroMinThreat or 1)
    
    if showAggro then
        local color = AggroColors[threatStatus] or AggroColors[3]
        
        -- Use custom colors if defined
        if db.aggroCustomColors and db.aggroCustomColors[threatStatus] then
            color = db.aggroCustomColors[threatStatus]
        end
        
        for _, border in pairs(highlight.borders) do
            border:SetColorTexture(color.r, color.g, color.b, color.a or 1)
        end
        
        highlight:Show()
        
        -- Also update health bar color if using aggro color mode
        if db.aggroHealthBarOverride and frame.healthBar then
            frame.healthBar:SetStatusBarColor(color.r, color.g, color.b)
        end
    else
        highlight:Hide()
    end
end

-- ============================================================================
-- HIGHLIGHT LAYOUT
-- ============================================================================

--[[
    Apply layout settings to all highlights
    @param frame Frame - The unit frame
]]
function UnitFrames:ApplyHighlightLayout(frame)
    if not frame.highlights then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local borderWidth = self:PixelPerfectThickness(db.highlightBorderSize or 2)
    
    -- Update selection highlight borders
    if frame.highlights.selection then
        for key, border in pairs(frame.highlights.selection.borders) do
            if key == "top" or key == "bottom" then
                border:SetHeight(borderWidth)
            else
                border:SetWidth(borderWidth)
            end
        end
    end
    
    -- Update aggro highlight borders
    if frame.highlights.aggro then
        for key, border in pairs(frame.highlights.aggro.borders) do
            if key == "top" or key == "bottom" then
                border:SetHeight(borderWidth)
            else
                border:SetWidth(borderWidth)
            end
        end
    end
end

-- ============================================================================
-- SELECTION UPDATE
-- ============================================================================

--[[
    Update selection highlight based on current target
    @param frame Frame - The unit frame
]]
function UnitFrames:UpdateSelectionHighlight(frame)
    if not frame or not frame.unit then return end
    
    local isTarget = UnitIsUnit(frame.unit, "target")
    
    if isTarget then
        self:ShowSelectionHighlight(frame)
    else
        self:HideSelectionHighlight(frame)
    end
end

-- ============================================================================
-- BATCH UPDATES
-- ============================================================================

--[[
    Update all highlights for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:UpdateAllHighlights(frame)
    if not frame then return end
    
    self:UpdateSelectionHighlight(frame)
    self:UpdateAggroHighlight(frame)
end

--[[
    Update highlights for all frames
]]
function UnitFrames:UpdateAllFrameHighlights()
    -- Update player frame
    if self.playerFrame then
        self:UpdateAllHighlights(self.playerFrame)
    end
    
    -- Update party frames
    for _, frame in pairs(self.partyFrames) do
        self:UpdateAllHighlights(frame)
    end
    
    -- Update raid frames
    for _, frame in pairs(self.raidFrames) do
        self:UpdateAllHighlights(frame)
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--[[
    Register highlight-related events
]]
function UnitFrames:RegisterHighlightEvents()
    local eventFrame = CreateFrame("Frame")
    
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    eventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_TARGET_CHANGED" then
            UnitFrames:OnTargetChanged()
        elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
            local unit = ...
            UnitFrames:OnThreatUpdate(unit)
        end
    end)
end

--[[
    Handle target change event
]]
function UnitFrames:OnTargetChanged()
    -- Update all selection highlights
    if self.playerFrame then
        self:UpdateSelectionHighlight(self.playerFrame)
    end
    
    for _, frame in pairs(self.partyFrames) do
        self:UpdateSelectionHighlight(frame)
    end
    
    for _, frame in pairs(self.raidFrames) do
        self:UpdateSelectionHighlight(frame)
    end
end

--[[
    Handle threat update event
    @param unit string - The unit that had threat change
]]
function UnitFrames:OnThreatUpdate(unit)
    -- Find the frame for this unit and update it
    if self.playerFrame and self.playerFrame.unit == unit then
        self:UpdateAggroHighlight(self.playerFrame)
        return
    end
    
    for _, frame in pairs(self.partyFrames) do
        if frame.unit == unit then
            self:UpdateAggroHighlight(frame)
            return
        end
    end
    
    for _, frame in pairs(self.raidFrames) do
        if frame.unit == unit then
            self:UpdateAggroHighlight(frame)
            return
        end
    end
end
