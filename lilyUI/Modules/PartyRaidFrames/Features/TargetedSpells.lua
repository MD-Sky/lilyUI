--[[
    LilyUI Unit Frames - Targeted Spell Tracking
    Shows when enemies are casting at party/raid members
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitGUID = UnitGUID
local CreateFrame = CreateFrame
local GetTime = GetTime
local floor = math.floor

-- Storage for targeted spell indicators
UnitFrames.targetedSpellContainers = UnitFrames.targetedSpellContainers or {}

-- ============================================================================
-- TARGETED SPELL CONTAINER CREATION
-- ============================================================================

--[[
    Create targeted spell container for a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:CreateTargetedSpellContainer(frame)
    if frame.targetedSpellContainer then return end
    
    local container = CreateFrame("Frame", nil, frame)
    container:SetSize(20, 20)
    container:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
    container:SetFrameLevel(frame:GetFrameLevel() + 5)
    
    -- Background
    container.bg = container:CreateTexture(nil, "BACKGROUND")
    container.bg:SetAllPoints()
    container.bg:SetColorTexture(0, 0, 0, 0.7)
    
    -- Icon
    container.icon = container:CreateTexture(nil, "ARTWORK")
    container.icon:SetPoint("TOPLEFT", container, "TOPLEFT", 1, -1)
    container.icon:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    container.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    -- Border
    container.border = container:CreateTexture(nil, "OVERLAY")
    container.border:SetAllPoints()
    container.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    container.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    container.border:SetVertexColor(1, 0.3, 0.3)
    
    -- Cast bar (small)
    container.castBar = CreateFrame("StatusBar", nil, container)
    container.castBar:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 1, 1)
    container.castBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -1, 1)
    container.castBar:SetHeight(3)
    container.castBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    container.castBar:SetStatusBarColor(1, 0.5, 0)
    container.castBar:SetMinMaxValues(0, 1)
    container.castBar:SetValue(0)
    
    -- Spell info storage
    container.spellID = nil
    container.spellName = nil
    container.casterGUID = nil
    container.endTime = nil
    
    -- Update script
    container:SetScript("OnUpdate", function(self, elapsed)
        if not self.endTime then
            self:Hide()
            return
        end
        
        local remaining = self.endTime - GetTime()
        if remaining <= 0 then
            self:Hide()
            self.endTime = nil
            return
        end
        
        -- Update cast bar
        if self.duration and self.duration > 0 then
            self.castBar:SetValue(remaining / self.duration)
    end
end)

    -- Tooltip
    container:EnableMouse(true)
    container:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Cast by: " .. (self.casterName or "Unknown"), 1, 0.5, 0)
            GameTooltip:Show()
        end
    end)
    
    container:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    container:Hide()
        frame.targetedSpellContainer = container
    end
    
-- ============================================================================
-- TARGETED SPELL DETECTION
-- ============================================================================

--[[
    Check if an enemy is targeting a unit with a cast
    @param enemyUnit string - The enemy unit casting
    @param targetUnit string - The potential target
    @return boolean, table|nil - Whether casting at target, and cast info
]]
function UnitFrames:IsEnemyCastingAt(enemyUnit, targetUnit)
    if not UnitExists(enemyUnit) or not UnitExists(targetUnit) then
        return false, nil
    end
    
    -- Check casting
    local name, text, texture, startTime, endTime, _, _, _, spellID = UnitCastingInfo(enemyUnit)
    
    if not name then
        -- Check channeling
        name, text, texture, startTime, endTime, _, _, _, spellID = UnitChannelInfo(enemyUnit)
    end
    
    if not name then
        return false, nil
    end
    
    -- Check if the target of the cast is our unit
    local enemyTarget = enemyUnit .. "target"
    
    if UnitExists(enemyTarget) and UnitIsUnit(enemyTarget, targetUnit) then
        return true, {
            name = name,
            text = text,
            texture = texture,
            startTime = startTime / 1000,
            endTime = endTime / 1000,
            spellID = spellID,
            casterUnit = enemyUnit,
            casterGUID = UnitGUID(enemyUnit),
            casterName = UnitName(enemyUnit),
        }
    end
    
    return false, nil
end

-- ============================================================================
-- TARGETED SPELL UPDATE
-- ============================================================================

--[[
    Update targeted spell indicator for a frame
    @param frame Frame - The unit frame
    @param castInfo table|nil - Cast information or nil to hide
]]
function UnitFrames:UpdateTargetedSpell(frame, castInfo)
    if not frame then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.targetedSpellEnabled then
        if frame.targetedSpellContainer then
            frame.targetedSpellContainer:Hide()
        end
        return
    end
    
    -- Create container if needed
    if not frame.targetedSpellContainer then
        self:CreateTargetedSpellContainer(frame)
    end
    
    local container = frame.targetedSpellContainer
    
    if castInfo then
        -- Show indicator
        container.icon:SetTexture(castInfo.texture)
        container.spellID = castInfo.spellID
        container.spellName = castInfo.name
        container.casterGUID = castInfo.casterGUID
        container.casterName = castInfo.casterName
        container.endTime = castInfo.endTime
        container.duration = castInfo.endTime - castInfo.startTime
        
        container.castBar:SetValue(1)
        container:Show()
    else
        container:Hide()
        container.spellID = nil
        container.endTime = nil
        end
    end
    
-- ============================================================================
-- SCAN FOR TARGETED SPELLS
-- ============================================================================

local scanQueue = {}
local lastScanTime = 0
local SCAN_INTERVAL = 0.1

--[[
    Scan for enemies casting at party/raid members
]]
function UnitFrames:ScanForTargetedSpells()
    local currentTime = GetTime()
    if currentTime - lastScanTime < SCAN_INTERVAL then
            return
        end
    lastScanTime = currentTime
    
    local db = self:GetDB()
    
    if not db.targetedSpellEnabled then
        return
    end
    
    -- Units to check
    local enemiesToCheck = {"target", "focus", "targettarget", "focustarget"}
    
    -- Add boss units
    for i = 1, 5 do
        table.insert(enemiesToCheck, "boss" .. i)
    end
    
    -- Add nameplate units (if supported)
    for i = 1, 40 do
        table.insert(enemiesToCheck, "nameplate" .. i)
    end
    
    -- Check player frame
    if self.playerFrame then
        self:CheckTargetedSpellForFrame(self.playerFrame, enemiesToCheck)
    end
    
    -- Check party frames
    for _, frame in pairs(self.partyFrames) do
        if frame and UnitExists(frame.unit) then
            self:CheckTargetedSpellForFrame(frame, enemiesToCheck)
        end
    end
    
    -- Check raid frames
    for _, frame in pairs(self.raidFrames) do
        if frame and UnitExists(frame.unit) then
            self:CheckTargetedSpellForFrame(frame, enemiesToCheck)
        end
        end
    end
    
--[[
    Check for targeted spells on a specific frame
    @param frame Frame - The unit frame to check
    @param enemies table - List of enemy unit IDs to check
]]
function UnitFrames:CheckTargetedSpellForFrame(frame, enemies)
    if not frame or not frame.unit then return end
    
    for _, enemyUnit in ipairs(enemies) do
        if UnitExists(enemyUnit) then
            local isCasting, castInfo = self:IsEnemyCastingAt(enemyUnit, frame.unit)
            
            if isCasting then
                self:UpdateTargetedSpell(frame, castInfo)
                return
            end
        end
    end
    
    -- No enemy casting at this unit
    self:UpdateTargetedSpell(frame, nil)
end

-- ============================================================================
-- TARGETED SPELL LAYOUT
-- ============================================================================

--[[
    Apply layout settings to targeted spell container
    @param frame Frame - The unit frame
]]
function UnitFrames:ApplyTargetedSpellLayout(frame)
    if not frame.targetedSpellContainer then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local container = frame.targetedSpellContainer
    
    -- Size
    local size = db.targetedSpellSize or 20
    container:SetSize(size, size)
    
    -- Position
    local anchor = db.targetedSpellAnchor or "RIGHT"
    local offsetX = db.targetedSpellOffsetX or -2
    local offsetY = db.targetedSpellOffsetY or 0
    
    container:ClearAllPoints()
    container:SetPoint(anchor, frame, anchor, offsetX, offsetY)
end

-- ============================================================================
-- TARGETED SPELL TICKER
-- ============================================================================

local targetedSpellTicker = nil

--[[
    Start the targeted spell scanning ticker
]]
function UnitFrames:StartTargetedSpellTicker()
    if targetedSpellTicker then return end
    
    targetedSpellTicker = C_Timer.NewTicker(0.1, function()
        self:ScanForTargetedSpells()
    end)
end

--[[
    Stop the targeted spell scanning ticker
]]
function UnitFrames:StopTargetedSpellTicker()
    if targetedSpellTicker then
        targetedSpellTicker:Cancel()
        targetedSpellTicker = nil
        end
    end
    
-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--[[
    Register targeted spell events
]]
function UnitFrames:RegisterTargetedSpellEvents()
    local eventFrame = CreateFrame("Frame")
    
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    
    eventFrame:SetScript("OnEvent", function(self, event, unit, ...)
        -- Quick scan when cast events occur
        UnitFrames:ScanForTargetedSpells()
    end)
end
