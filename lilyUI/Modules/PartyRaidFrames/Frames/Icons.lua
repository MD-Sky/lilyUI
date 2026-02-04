--[[
    LilyUI Unit Frames - Status Icons
    Handles role, leader, raid target, ready check, and other icons
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitIsGroupLeader = UnitIsGroupLeader
local UnitIsGroupAssistant = UnitIsGroupAssistant
local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local GetReadyCheckStatus = GetReadyCheckStatus
local UnitHasIncomingResurrection = UnitHasIncomingResurrection
local UnitPvpClassification = UnitPvpClassification
local UnitIsPVP = UnitIsPVP

-- ============================================================================
-- ICON TEXTURES
-- ============================================================================

local RoleTextures = {
    TANK = {
        atlas = "roleicon-tank",
        fallback = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
        coords = {0, 19/64, 22/64, 41/64},
    },
    HEALER = {
        atlas = "roleicon-healer",
        fallback = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
        coords = {20/64, 39/64, 1/64, 20/64},
    },
    DAMAGER = {
        atlas = "roleicon-dps",
        fallback = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES",
        coords = {20/64, 39/64, 22/64, 41/64},
    },
}

-- ============================================================================
-- ROLE ICON
-- ============================================================================

--[[
    Create role icon for a frame
    @param frame table - Parent frame
    @return table - Role icon texture
]]
function UnitFrames:CreateRoleIcon(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    icon:Hide()
    
    frame.roleIcon = icon
    return icon
end

--[[
    Update role icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdateRoleIcon(frame)
    if not frame.roleIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.roleIconEnabled then
        frame.roleIcon:Hide()
        return
    end
    
    local role = UnitGroupRolesAssigned(frame.unit)
    local roleData = RoleTextures[role]
    
    if roleData then
        -- Try atlas first, fall back to texture
        if roleData.atlas then
            local success = pcall(function()
                frame.roleIcon:SetAtlas(roleData.atlas)
            end)
            if not success then
                frame.roleIcon:SetTexture(roleData.fallback)
                frame.roleIcon:SetTexCoord(unpack(roleData.coords))
            end
        else
            frame.roleIcon:SetTexture(roleData.fallback)
            frame.roleIcon:SetTexCoord(unpack(roleData.coords))
        end
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end
end

-- ============================================================================
-- LEADER ICON
-- ============================================================================

--[[
    Create leader/assistant icon for a frame
    @param frame table - Parent frame
    @return table - Leader icon texture
]]
function UnitFrames:CreateLeaderIcon(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    icon:Hide()
    
    frame.leaderIcon = icon
    return icon
end

--[[
    Update leader/assistant icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdateLeaderIcon(frame)
    if not frame.leaderIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.leaderIconEnabled then
        frame.leaderIcon:Hide()
        return
    end
    
    local unit = frame.unit
    local isLeader = UnitIsGroupLeader(unit)
    local isAssistant = UnitIsGroupAssistant(unit)
    
    if isLeader then
        frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        frame.leaderIcon:SetTexCoord(0, 1, 0, 1)
        frame.leaderIcon:Show()
    elseif isAssistant then
        frame.leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        frame.leaderIcon:SetTexCoord(0, 1, 0, 1)
        frame.leaderIcon:Show()
    else
        frame.leaderIcon:Hide()
    end
end

-- ============================================================================
-- RAID TARGET ICON
-- ============================================================================

--[[
    Create raid target (skull, cross, etc.) icon
    @param frame table - Parent frame
    @return table - Raid target icon texture
]]
function UnitFrames:CreateRaidTargetIcon(frame)
    local parent = frame.contentOverlay or frame
    local iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:SetSize(20, 20)
    iconFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    iconFrame:SetFrameLevel(parent:GetFrameLevel() + 1)
    iconFrame:Hide()

    local iconTexture = iconFrame:CreateTexture(nil, "OVERLAY")
    iconTexture:SetAllPoints()
    iconTexture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    iconTexture:SetDrawLayer("OVERLAY", 6)

    frame.raidTargetIcon = iconFrame
    frame.raidTargetIcon.texture = iconTexture
    return iconFrame
end

--[[
    Update raid target icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdateRaidTargetIcon(frame)
    if not frame.raidTargetIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.raidTargetIconEnabled then
        frame.raidTargetIcon:Hide()
        return
    end
    
    local index = GetRaidTargetIndex(frame.unit)
    
    if index then
        local texture = frame.raidTargetIcon.texture or frame.raidTargetIcon
        texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        SetRaidTargetIconTexture(texture, index)
        frame.raidTargetIcon:Show()
    else
        frame.raidTargetIcon:Hide()
        return
    end

    local size = db.raidTargetIconSize or 20
    frame.raidTargetIcon:SetSize(size, size)
    frame.raidTargetIcon:ClearAllPoints()
    frame.raidTargetIcon:SetPoint(db.raidTargetIconAnchor or "CENTER", frame, db.raidTargetIconAnchor or "CENTER",
        db.raidTargetIconOffsetX or 0, db.raidTargetIconOffsetY or 0)
    if frame.contentOverlay then
        frame.raidTargetIcon:SetFrameLevel(frame.contentOverlay:GetFrameLevel() + 1)
    end
end

-- ============================================================================
-- READY CHECK ICON
-- ============================================================================

--[[
    Create ready check icon
    @param frame table - Parent frame
    @return table - Ready check icon texture
]]
function UnitFrames:CreateReadyCheckIcon(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:Hide()
    
    frame.readyCheckIcon = icon
    return icon
end

--[[
    Update ready check icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdateReadyCheckIcon(frame)
    if not frame.readyCheckIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.readyCheckIconEnabled then
        frame.readyCheckIcon:Hide()
        return
    end
    
    local status = GetReadyCheckStatus(frame.unit)
    
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

-- ============================================================================
-- CENTER STATUS ICON
-- ============================================================================

--[[
    Create center status icon (resurrection, summon, etc.)
    @param frame table - Parent frame
    @return table - Center status icon texture
]]
function UnitFrames:CreateCenterStatusIcon(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:Hide()
    
    frame.centerStatusIcon = icon
    return icon
end

--[[
    Update center status icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdateCenterStatusIcon(frame)
    if not frame.centerStatusIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.centerStatusIconEnabled then
        frame.centerStatusIcon:Hide()
        return
    end
    
    local unit = frame.unit
    
    -- Check resurrection pending
    if UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit) then
        frame.centerStatusIcon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
        frame.centerStatusIcon:Show()
        return
    end
    
    -- Check summon pending
    if C_IncomingSummon and C_IncomingSummon.IncomingSummonStatus then
        local summonStatus = C_IncomingSummon.IncomingSummonStatus(unit)
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
    end
    
    frame.centerStatusIcon:Hide()
end

-- ============================================================================
-- PVP ICON
-- ============================================================================

--[[
    Create PvP status icon
    @param frame table - Parent frame
    @return table - PvP icon texture
]]
function UnitFrames:CreatePvPIcon(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    icon:Hide()
    
    frame.pvpIcon = icon
    return icon
end

--[[
    Update PvP icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdatePvPIcon(frame)
    if not frame.pvpIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.pvpIconEnabled then
        frame.pvpIcon:Hide()
        return
    end
    
    local unit = frame.unit
    
    if UnitIsPVP(unit) then
        local factionGroup = UnitFactionGroup(unit)
        if factionGroup == "Horde" then
            frame.pvpIcon:SetTexture("Interface\\PVPFrame\\PVP-Currency-Horde")
        elseif factionGroup == "Alliance" then
            frame.pvpIcon:SetTexture("Interface\\PVPFrame\\PVP-Currency-Alliance")
        else
            frame.pvpIcon:Hide()
            return
        end
        frame.pvpIcon:SetTexCoord(0, 1, 0, 1)
        frame.pvpIcon:Show()
    else
        frame.pvpIcon:Hide()
    end
end

-- ============================================================================
-- PHASE ICON
-- ============================================================================

--[[
    Create phase indicator icon
    @param frame table - Parent frame
    @return table - Phase icon texture
]]
function UnitFrames:CreatePhaseIcon(frame)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    icon:Hide()
    
    frame.phaseIcon = icon
    return icon
end

--[[
    Update phase icon display
    @param frame table - The unit frame
]]
function UnitFrames:UpdatePhaseIcon(frame)
    if not frame.phaseIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.phaseIconEnabled then
        frame.phaseIcon:Hide()
        return
    end
    
    local unit = frame.unit
    
    -- Check if unit is in a different phase/instance
    local isPhased = UnitPhaseReason and UnitPhaseReason(unit)
    
    if isPhased then
        frame.phaseIcon:SetTexture("Interface\\TargetingFrame\\UI-PhasingIcon")
        frame.phaseIcon:SetTexCoord(0, 1, 0, 1)
        frame.phaseIcon:Show()
    else
        frame.phaseIcon:Hide()
    end
end

-- ============================================================================
-- RESTED INDICATOR
-- ============================================================================

--[[
    Create rested indicator (for player frame)
    @param frame table - Parent frame
    @return table - Rested indicator container
]]
function UnitFrames:CreateRestedIndicator(frame)
    local container = CreateFrame("Frame", nil, frame)
    container:SetSize(20, 20)
    container:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    container:Hide()
    
    local texture = container:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    texture:SetTexCoord(0.0625, 0.4375, 0.0625, 0.4375)  -- Rested icon
    
    container.texture = texture
    frame.restedIndicator = container
    
    return container
end

--[[
    Update rested indicator display
    @param frame table - The unit frame (only relevant for player)
]]
function UnitFrames:UpdateRestedIndicator(frame)
    if not frame.restedIndicator then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.restedIndicatorEnabled then
        frame.restedIndicator:Hide()
        return
    end
    
    -- Only show for player
    if frame.unit ~= "player" then
        frame.restedIndicator:Hide()
        return
    end
    
    local isResting = IsResting()
    
    if isResting then
        frame.restedIndicator:Show()
    else
        frame.restedIndicator:Hide()
    end
end

-- ============================================================================
-- DEFENSIVE ICON (Special abilities like immunities)
-- ============================================================================

--[[
    Create defensive ability icon
    @param frame table - Parent frame
    @return table - Defensive icon frame
]]
function UnitFrames:CreateDefensiveIcon(frame)
    local container = CreateFrame("Frame", nil, frame)
    container:SetSize(24, 24)
    container:SetPoint("LEFT", frame, "LEFT", 4, 0)
    container:Hide()
    
    container.texture = container:CreateTexture(nil, "OVERLAY")
    container.texture:SetAllPoints()
    
    container.cooldown = CreateFrame("Cooldown", nil, container, "CooldownFrameTemplate")
    container.cooldown:SetAllPoints()
    container.cooldown:SetDrawEdge(false)
    container.cooldown:SetDrawSwipe(true)
    
    -- Tooltip handling
    container:EnableMouse(true)
    container:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:Show()
        end
    end)
    container:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    frame.defensiveIcon = container
    return container
end

--[[
    Update defensive icon display
    @param frame table - The unit frame
    @param spellID number - Spell ID to display
    @param expirationTime number - When the buff expires
    @param duration number - Total duration of the buff
]]
function UnitFrames:UpdateDefensiveIcon(frame, spellID, expirationTime, duration)
    if not frame.defensiveIcon then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    if not db.defensiveIconEnabled then
        frame.defensiveIcon:Hide()
        return
    end
    
    if spellID and expirationTime then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo then
            frame.defensiveIcon.texture:SetTexture(spellInfo.iconID)
            frame.defensiveIcon.spellID = spellID
            
            if duration and duration > 0 then
                local startTime = expirationTime - duration
                frame.defensiveIcon.cooldown:SetCooldown(startTime, duration)
            else
                frame.defensiveIcon.cooldown:Clear()
            end
            
            frame.defensiveIcon:Show()
        else
            frame.defensiveIcon:Hide()
        end
    else
        frame.defensiveIcon:Hide()
    end
end

-- ============================================================================
-- BATCH ICON UPDATES
-- ============================================================================

--[[
    Update all icons for a frame
    @param frame table - The unit frame
]]
function UnitFrames:UpdateAllIcons(frame)
    if not frame then return end
    
    self:UpdateRoleIcon(frame)
    self:UpdateLeaderIcon(frame)
    self:UpdateRaidTargetIcon(frame)
    self:UpdateReadyCheckIcon(frame)
    self:UpdateCenterStatusIcon(frame)
    self:UpdatePvPIcon(frame)
    self:UpdatePhaseIcon(frame)
    self:UpdateRestedIndicator(frame)
end

--[[
    Update all role icons for all frames
]]
function UnitFrames:UpdateAllRoleIcons()
    if self.playerFrame then
        self:UpdateRoleIcon(self.playerFrame)
    end
    
    for _, frame in pairs(self.partyFrames) do
        self:UpdateRoleIcon(frame)
    end
    
    for _, frame in pairs(self.raidFrames) do
        self:UpdateRoleIcon(frame)
    end
end

--[[
    Update all leader icons for all frames
]]
function UnitFrames:UpdateAllLeaderIcons()
    if self.playerFrame then
        self:UpdateLeaderIcon(self.playerFrame)
    end
    
    for _, frame in pairs(self.partyFrames) do
        self:UpdateLeaderIcon(frame)
    end
    
    for _, frame in pairs(self.raidFrames) do
        self:UpdateLeaderIcon(frame)
    end
end
