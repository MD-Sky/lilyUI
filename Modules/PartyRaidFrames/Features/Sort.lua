--[[
    LilyUI Unit Frames - Frame Sorting
    Sort frames by role, class, name, or group
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitClass = UnitClass
local UnitName = UnitName
local UnitIsUnit = UnitIsUnit
local GetRaidRosterInfo = GetRaidRosterInfo
local floor = math.floor
local sort = table.sort

-- ============================================================================
-- SORT METHODS
-- ============================================================================

local SORT_METHODS = {
    ROLE = "role",
    CLASS = "class",
    NAME = "name",
    GROUP = "group",
    ROLE_CLASS = "role_class",
    ROLE_NAME = "role_name",
}

UnitFrames.SORT_METHODS = SORT_METHODS

-- Role priority (lower = higher priority)
local RolePriority = {
    TANK = 1,
    HEALER = 2,
    DAMAGER = 3,
    NONE = 4,
}

-- Class sort order (alphabetical by default, can be customized)
local ClassOrder = {
    DEATHKNIGHT = 1,
    DEMONHUNTER = 2,
    DRUID = 3,
    EVOKER = 4,
    HUNTER = 5,
    MAGE = 6,
    MONK = 7,
    PALADIN = 8,
    PRIEST = 9,
    ROGUE = 10,
    SHAMAN = 11,
    WARLOCK = 12,
    WARRIOR = 13,
}

-- ============================================================================
-- SORT FUNCTIONS
-- ============================================================================

--[[
    Get sort value for a frame
    @param frame Frame - The unit frame
    @param method string - Sort method
    @return multiple - Sort values based on method
]]
function UnitFrames:GetSortValue(frame, method)
    if not frame or not frame.unit then
        return 999, 999, "ZZZZ"
    end
    
    local unit = frame.unit
    local role = UnitGroupRolesAssigned(unit) or "NONE"
    local _, class = UnitClass(unit)
    local name = UnitName(unit) or ""
    
    local rolePriority = RolePriority[role] or 4
    local classPriority = class and ClassOrder[class] or 99
    
    return rolePriority, classPriority, name
end

--[[
    Compare two frames for sorting
    @param a Frame - First frame
    @param b Frame - Second frame
    @param method string - Sort method
    @return boolean - True if a should come before b
]]
function UnitFrames:CompareFrames(a, b, method)
    local aRole, aClass, aName = self:GetSortValue(a, method)
    local bRole, bClass, bName = self:GetSortValue(b, method)
    
    if method == "ROLE" then
        if aRole ~= bRole then
            return aRole < bRole
        end
        return aName < bName
        
    elseif method == "CLASS" then
        if aClass ~= bClass then
            return aClass < bClass
        end
        return aName < bName
        
    elseif method == "NAME" then
        return aName < bName
        
    elseif method == "ROLE_CLASS" then
        if aRole ~= bRole then
            return aRole < bRole
        end
        if aClass ~= bClass then
            return aClass < bClass
        end
        return aName < bName
        
    elseif method == "ROLE_NAME" then
        if aRole ~= bRole then
            return aRole < bRole
        end
        return aName < bName
        
    elseif method == "GROUP" then
        -- Sort by raid group
        local aGroup = self:GetUnitGroup(a.unit)
        local bGroup = self:GetUnitGroup(b.unit)
        
        if aGroup ~= bGroup then
            return aGroup < bGroup
        end
        return aName < bName
    end
    
    return aName < bName
end

--[[
    Get the raid group number for a unit
    @param unit string - Unit ID
    @return number - Group number (1-8) or 9 for party/unknown
]]
function UnitFrames:GetUnitGroup(unit)
    if unit == "player" then
        local _, _, group = GetRaidRosterInfo(UnitInRaid("player") or 0)
        return group or 1
    end
    
    local raidIndex = unit:match("^raid(%d+)$")
    if raidIndex then
        local _, _, group = GetRaidRosterInfo(tonumber(raidIndex))
        return group or 9
    end
    
    return 9  -- Party members or unknown
end

-- ============================================================================
-- FRAME SORTING
-- ============================================================================

--[[
    Sort an array of frames
    @param frames table - Array of frames to sort
    @param method string - Sort method
    @return table - Sorted array (same reference)
]]
function UnitFrames:SortFrames(frames, method)
    if not frames or #frames < 2 then
        return frames
    end
    
    method = method or "ROLE"
    
    sort(frames, function(a, b)
        return self:CompareFrames(a, b, method)
    end)
    
    return frames
end

--[[
    Get sorted party frames
    @return table - Sorted array of party frames
]]
function UnitFrames:GetSortedPartyFrames()
    local db = self:GetDB()
    local frames = {}
    
    -- Add player frame if configured
    if db.showPlayer and self.playerFrame then
        table.insert(frames, self.playerFrame)
    end
    
    -- Add party frames
    for i = 1, 4 do
        if self.partyFrames[i] and UnitExists("party" .. i) then
            table.insert(frames, self.partyFrames[i])
        end
    end
    
    -- Sort if enabled
    if db.sortEnabled then
        self:SortFrames(frames, db.sortMethod)
    end
    
    return frames
end

--[[
    Get sorted raid frames
    @return table - Sorted array of raid frames
]]
function UnitFrames:GetSortedRaidFrames()
    local db = self:GetRaidDB()
    local frames = {}
    
    -- Add raid frames
    for i = 1, 40 do
        if self.raidFrames[i] and UnitExists("raid" .. i) then
            table.insert(frames, self.raidFrames[i])
        end
    end
    
    -- Sort if enabled
    if db.sortEnabled then
        self:SortFrames(frames, db.sortMethod)
    end
    
    return frames
end

-- ============================================================================
-- SORT ORDER APPLICATION
-- ============================================================================

--[[
    Apply sort order to party frames layout
]]
function UnitFrames:ApplySortedPartyLayout()
    local db = self:GetDB()
    
    if not db.sortEnabled then
        return
    end
    
    local sortedFrames = self:GetSortedPartyFrames()
    local container = self.container
    
    if not container or #sortedFrames == 0 then return end
    
    local frameWidth = db.frameWidth or 120
    local frameHeight = db.frameHeight or 50
    local spacing = db.frameSpacing or 2
    local growthDirection = db.growthDirection or "DOWN"
    local orientation = db.orientation or "VERTICAL"
    
    for i, frame in ipairs(sortedFrames) do
        frame:ClearAllPoints()
        
        local index = i - 1
        local offsetX, offsetY = 0, 0
        
        if orientation == "HORIZONTAL" then
            if growthDirection == "LEFT" then
                offsetX = -index * (frameWidth + spacing)
            else
                offsetX = index * (frameWidth + spacing)
            end
        else
            if growthDirection == "UP" then
                offsetY = index * (frameHeight + spacing)
            else
                offsetY = -index * (frameHeight + spacing)
            end
        end
        
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX, offsetY)
    end
end

--[[
    Apply sort order to raid frames layout
]]
function UnitFrames:ApplySortedRaidLayout()
    local db = self:GetRaidDB()
    
    if not db.sortEnabled then
        return
    end
    
    local sortedFrames = self:GetSortedRaidFrames()
    local container = self.raidContainer
    
    if not container or #sortedFrames == 0 then return end
    
    local frameWidth = db.frameWidth or 80
    local frameHeight = db.frameHeight or 40
    local spacingX = db.frameSpacingX or db.frameSpacing or 2
    local spacingY = db.frameSpacingY or db.frameSpacing or 2
    local columns = db.columns or 5
    local growthDirection = db.growthDirection or "DOWN"
    
    for i, frame in ipairs(sortedFrames) do
        frame:ClearAllPoints()
        
        local index = i - 1
        local col = index % columns
        local row = floor(index / columns)
        
        local offsetX = col * (frameWidth + spacingX)
        local offsetY
        
        if growthDirection == "DOWN" then
            offsetY = -row * (frameHeight + spacingY)
        else
            offsetY = row * (frameHeight + spacingY)
        end
        
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX, offsetY)
    end
end

-- ============================================================================
-- CUSTOM SORT ORDER
-- ============================================================================

--[[
    Set custom class sort order
    @param classOrder table - Map of class to priority number
]]
function UnitFrames:SetClassSortOrder(classOrder)
    if type(classOrder) == "table" then
        for class, priority in pairs(classOrder) do
            ClassOrder[class] = priority
        end
    end
end

--[[
    Set custom role priority
    @param rolePriority table - Map of role to priority number
]]
function UnitFrames:SetRolePriority(rolePriority)
    if type(rolePriority) == "table" then
        for role, priority in pairs(rolePriority) do
            RolePriority[role] = priority
        end
    end
end

-- ============================================================================
-- SORT ORDER PRESETS
-- ============================================================================

local SortPresets = {
    -- Tanks first, healers second, DPS last
    standard = {
        roleOrder = {TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4},
    },
    -- Healers first, tanks second, DPS last
    healer_first = {
        roleOrder = {HEALER = 1, TANK = 2, DAMAGER = 3, NONE = 4},
    },
    -- DPS first (for DPS checking their peers)
    dps_first = {
        roleOrder = {DAMAGER = 1, TANK = 2, HEALER = 3, NONE = 4},
    },
}

--[[
    Apply a sort preset
    @param presetName string - Name of the preset
]]
function UnitFrames:ApplySortPreset(presetName)
    local preset = SortPresets[presetName]
    
    if preset then
        if preset.roleOrder then
            self:SetRolePriority(preset.roleOrder)
        end
        if preset.classOrder then
            self:SetClassSortOrder(preset.classOrder)
        end
    end
end
