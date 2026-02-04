--[[
    LilyUI Unit Frames - Range Detection System
    Out of range alpha fading
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitInRange = UnitInRange
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsUnit = UnitIsUnit
local IsSpellInRange = C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
local CreateFrame = CreateFrame
local floor = math.floor

-- Range check spell IDs by class (friendly spells)
local RangeCheckSpells = {
    PRIEST = 2061,      -- Flash Heal
    PALADIN = 19750,    -- Flash of Light
    DRUID = 8936,       -- Regrowth
    SHAMAN = 8004,      -- Healing Surge
    MONK = 116694,      -- Surging Mist
    EVOKER = 361469,    -- Living Flame
    MAGE = 1459,        -- Arcane Intellect
    WARLOCK = 20707,    -- Soulstone
    WARRIOR = 198304,   -- Intercept
    HUNTER = 982,       -- Mend Pet (for self/pet)
    ROGUE = 57934,      -- Tricks of the Trade
    DEMONHUNTER = 203720, -- Consume Magic (any range)
    DEATHKNIGHT = 61999, -- Raise Ally
}

-- ============================================================================
-- RANGE CHECK FUNCTIONS
-- ============================================================================

--[[
    Check if a unit is in range
    @param unit string - Unit ID
    @return boolean, boolean - inRange, checkedRange
]]
function UnitFrames:IsUnitInRange(unit)
    if not unit then return false, false end
    
    -- Always consider player in range
    if UnitIsUnit(unit, "player") then
        return true, true
    end
    
    -- Check if connected
    if not UnitIsConnected(unit) then
        return false, true
    end
    
    -- Use UnitInRange as primary check
    local inRange, checkedRange = UnitInRange(unit)
    
    if checkedRange then
        return inRange, true
    end
    
    -- Fallback to spell range check
    local _, playerClass = UnitClass("player")
    local spellID = RangeCheckSpells[playerClass]
    
    if spellID then
        local spellInRange = IsSpellInRange(spellID, unit)
        if spellInRange ~= nil then
            return spellInRange == 1 or spellInRange == true, true
        end
    end
    
    -- Default to in range if we can't check
    return true, false
end

-- ============================================================================
-- RANGE ALPHA APPLICATION
-- ============================================================================

--[[
    Apply range-based alpha to a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:ApplyRangeAlpha(frame)
    if not frame or not frame.unit then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.rangeCheckEnabled then
        -- Reset alpha if range check disabled
        if frame.dfOutOfRange then
            frame:SetAlpha(1)
            frame.dfOutOfRange = false
        end
        return
    end
    
    local inRange, checkedRange = self:IsUnitInRange(frame.unit)
    local outOfRangeAlpha = db.outOfRangeAlpha or 0.4
    
    -- Check dead/offline status
    local isDeadOrOffline = not UnitIsConnected(frame.unit) or UnitIsDeadOrGhost(frame.unit)
    
    if not inRange and checkedRange then
        -- Unit is out of range
        self:SetFrameOutOfRange(frame, outOfRangeAlpha, db)
    else
        -- Unit is in range
        self:SetFrameInRange(frame, db)
    end
end

--[[
    Set frame to out-of-range state
    @param frame Frame - The unit frame
    @param alpha number - Alpha to apply
    @param db table - Database settings
]]
function UnitFrames:SetFrameOutOfRange(frame, alpha, db)
    frame.dfOutOfRange = true
    
    if db.rangeAlphaMode == "FRAME" then
        -- Fade entire frame
        frame:SetAlpha(alpha)
    else
        -- Fade individual elements
        self:FadeFrameElements(frame, alpha, db)
    end
end

--[[
    Set frame to in-range state
    @param frame Frame - The unit frame
    @param db table - Database settings
]]
function UnitFrames:SetFrameInRange(frame, db)
    if not frame.dfOutOfRange then return end
    
    frame.dfOutOfRange = false
    
    if db.rangeAlphaMode == "FRAME" then
        -- Reset frame alpha (unless dead-faded)
        if not frame.dfDeadFadeApplied then
            frame:SetAlpha(1)
        end
    else
        -- Reset individual elements
        self:ResetFrameElements(frame, db)
    end
end

-- ============================================================================
-- ELEMENT FADING
-- ============================================================================

--[[
    Fade individual frame elements
    @param frame Frame - The unit frame
    @param alpha number - Target alpha
    @param db table - Database settings
]]
function UnitFrames:FadeFrameElements(frame, alpha, db)
    -- Elements to fade
    local elements = {
        frame.healthBar,
        frame.background,
        frame.nameText,
        frame.healthText,
        frame.statusText,
        frame.dfPowerBar,
        frame.absorbBar,
        frame.roleIcon,
        frame.leaderIcon,
        frame.raidTargetIcon,
        frame.dispelOverlay,
    }
    
    for _, element in pairs(elements) do
        if element then
            element:SetAlpha(alpha)
        end
    end
    
    -- Fade aura icons
    if frame.buffIcons then
        for _, icon in ipairs(frame.buffIcons) do
            icon:SetAlpha(alpha)
        end
    end
    
    if frame.debuffIcons then
        for _, icon in ipairs(frame.debuffIcons) do
            icon:SetAlpha(alpha)
        end
    end
end

--[[
    Reset frame elements to full alpha
    @param frame Frame - The unit frame
    @param db table - Database settings
]]
function UnitFrames:ResetFrameElements(frame, db)
    local elements = {
        frame.healthBar,
        frame.background,
        frame.nameText,
        frame.healthText,
        frame.statusText,
        frame.dfPowerBar,
        frame.absorbBar,
        frame.roleIcon,
        frame.leaderIcon,
        frame.raidTargetIcon,
        frame.dispelOverlay,
    }
    
    for _, element in pairs(elements) do
        if element then
            element:SetAlpha(1)
        end
    end
    
    -- Reset aura icons
    if frame.buffIcons then
        for _, icon in ipairs(frame.buffIcons) do
            icon:SetAlpha(1)
        end
    end
    
    if frame.debuffIcons then
        for _, icon in ipairs(frame.debuffIcons) do
            icon:SetAlpha(1)
        end
    end
end

-- ============================================================================
-- RANGE UPDATE TICKER
-- ============================================================================

local rangeTicker = nil

--[[
    Start the range check ticker
]]
function UnitFrames:StartRangeTicker()
    if rangeTicker then return end
    
    local db = self:GetDB()
    local updateInterval = db.rangeUpdateInterval or 0.2
    
    rangeTicker = C_Timer.NewTicker(updateInterval, function()
        self:UpdateAllRangeAlpha()
    end)
end

--[[
    Stop the range check ticker
]]
function UnitFrames:StopRangeTicker()
    if rangeTicker then
        rangeTicker:Cancel()
        rangeTicker = nil
    end
end

-- ============================================================================
-- BATCH UPDATES
-- ============================================================================

--[[
    Update range alpha for all frames
]]
function UnitFrames:UpdateAllRangeAlpha()
    -- Update player frame (always in range)
    if self.playerFrame then
        self:SetFrameInRange(self.playerFrame, self:GetDB())
    end
    
    -- Update party frames
    for _, frame in pairs(self.partyFrames) do
        self:ApplyRangeAlpha(frame)
    end
    
    -- Update raid frames
    for _, frame in pairs(self.raidFrames) do
        self:ApplyRangeAlpha(frame)
    end
    
    -- Update pet frames
    for _, frame in pairs(self.petFrames) do
        self:UpdatePetRangeAlpha(frame)
    end
    
    for _, frame in pairs(self.partyPetFrames) do
        self:UpdatePetRangeAlpha(frame)
    end
end

--[[
    Update pet frame range based on owner
    @param petFrame Frame - The pet frame
]]
function UnitFrames:UpdatePetRangeAlpha(petFrame)
    if not petFrame or not petFrame.ownerUnit then return end
    
    local db = petFrame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    
    if not db.petInheritRange then
        return
    end
    
    -- Check owner's range status
    local ownerInRange = self:IsUnitInRange(petFrame.ownerUnit)
    
    if ownerInRange then
        petFrame:SetAlpha(1)
        petFrame.dfOutOfRange = false
    else
        local outOfRangeAlpha = db.outOfRangeAlpha or 0.4
        petFrame:SetAlpha(outOfRangeAlpha)
        petFrame.dfOutOfRange = true
    end
end

-- ============================================================================
-- RANGE CHECK SPELL DETECTION
-- ============================================================================

--[[
    Auto-detect a range check spell for the current class
    @return number|nil - Spell ID or nil if none found
]]
function UnitFrames:DetectRangeCheckSpell()
    local _, playerClass = UnitClass("player")
    return RangeCheckSpells[playerClass]
end

--[[
    Set a custom range check spell
    @param spellID number - The spell ID to use for range checking
]]
function UnitFrames:SetRangeCheckSpell(spellID)
    local _, playerClass = UnitClass("player")
    RangeCheckSpells[playerClass] = spellID
end
