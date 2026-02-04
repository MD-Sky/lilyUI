--[[
    LilyUI Unit Frames - Frame Initialization
    Handles container setup and frame creation/layout
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

-- ============================================================================
-- MAIN CONTAINERS
-- ============================================================================

-- Party container
function UnitFrames:CreatePartyContainer()
    if self.container then return self.container end
    
    local container = CreateFrame("Frame", "LilyUIPartyContainer", UIParent, "SecureFrameTemplate")
    container:SetSize(1, 1)
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    
    self.container = container
    return container
end

-- Raid container
function UnitFrames:CreateRaidContainer()
    if self.raidContainer then return self.raidContainer end
    
    local container = CreateFrame("Frame", "LilyUIRaidContainer", UIParent, "SecureFrameTemplate")
    container:SetSize(1, 1)
    container:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    
    self.raidContainer = container
    return container
end

-- ============================================================================
-- FRAME CREATION MANAGEMENT
-- ============================================================================

local frameCreationQueue = {}
local isCreatingFrames = false

function UnitFrames:QueueFrameCreation(createFunc, callback)
    table.insert(frameCreationQueue, {func = createFunc, callback = callback})
    self:ProcessFrameQueue()
end

function UnitFrames:ProcessFrameQueue()
    if isCreatingFrames or #frameCreationQueue == 0 then return end
    
    isCreatingFrames = true
    
    local batchSize = 5
    local processed = 0
    
    while #frameCreationQueue > 0 and processed < batchSize do
        local item = table.remove(frameCreationQueue, 1)
        if item.func then
            item.func()
        end
        if item.callback then
            item.callback()
        end
        processed = processed + 1
    end
    
    if #frameCreationQueue > 0 then
        C_Timer.After(0.01, function()
            isCreatingFrames = false
            self:ProcessFrameQueue()
        end)
    else
        isCreatingFrames = false
    end
end

-- ============================================================================
-- PARTY FRAME INITIALIZATION
-- ============================================================================

function UnitFrames:InitializePartyFrames()
    local container = self:CreatePartyContainer()
    local db = self:GetDB()
    
    -- Create player frame first
    if not self.playerFrame then
        self.playerFrame = self:CreateUnitFrame("player", 0, false)
        self.playerFrame:SetParent(container)
        self:RegisterFrameForClicking(self.playerFrame)
    end
    
    -- Create party member frames
    for i = 1, 4 do
        if not self.partyFrames[i] then
            local unit = "party" .. i
            local frame = self:CreateUnitFrame(unit, i, false)
            frame:SetParent(container)
            self.partyFrames[i] = frame
            self:RegisterFrameForClicking(frame)
        end
    end
    
    -- Apply initial layout
    self:UpdatePartyLayout()
end

-- ============================================================================
-- RAID FRAME INITIALIZATION
-- ============================================================================

function UnitFrames:InitializeRaidFrames()
    local container = self:CreateRaidContainer()
    
    -- Create raid frames in batches to prevent lag
    local BATCH_SIZE = 8
    local totalFrames = 40
    
    local function createBatch(startIndex)
        local endIndex = min(startIndex + BATCH_SIZE - 1, totalFrames)
        
        for i = startIndex, endIndex do
            if not self.raidFrames[i] then
                local unit = "raid" .. i
                local frame = self:CreateUnitFrame(unit, i, true)
                frame:SetParent(container)
                self.raidFrames[i] = frame
                self:RegisterFrameForClicking(frame)
            end
        end
        
        if endIndex < totalFrames then
            C_Timer.After(0.01, function()
                createBatch(endIndex + 1)
            end)
        else
            -- All frames created, update layout
            self:UpdateRaidLayout()
        end
    end
    
    createBatch(1)
end

-- ============================================================================
-- PARTY LAYOUT
-- ============================================================================

function UnitFrames:UpdatePartyLayout()
    if InCombatLockdown() then
        self.pendingPartyLayout = true
        return
    end
    
    local db = self:GetDB()
    local container = self.container
    
    if not container then return end
    
    -- Position container
    local anchorPoint = db.anchorPoint or "CENTER"
    local anchorX = db.anchorX or 0
    local anchorY = db.anchorY or 0
    
    container:ClearAllPoints()
    container:SetPoint(anchorPoint, UIParent, anchorPoint, anchorX, anchorY)
    
    -- Get layout settings
    local growthDirection = db.growthDirection or "DOWN"
    local spacing = db.frameSpacing or 2
    local showPlayer = db.showPlayer ~= false
    local orientation = db.orientation or "VERTICAL"
    
    local frameWidth = db.frameWidth or 120
    local frameHeight = db.frameHeight or 50
    
    -- Calculate position for each frame
    local frames = {}
    
    if showPlayer and self.playerFrame then
        table.insert(frames, self.playerFrame)
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame then
            table.insert(frames, frame)
        end
    end
    
    -- Position frames
    for i, frame in ipairs(frames) do
        frame:ClearAllPoints()
        self:ApplyFrameLayout(frame)
        
        local offsetX, offsetY = 0, 0
        local index = i - 1
        
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
    
    self:UpdateContainerSize()
end

-- ============================================================================
-- RAID LAYOUT - GROUP BASED
-- ============================================================================

function UnitFrames:UpdateRaidLayout()
    if InCombatLockdown() then
        self.pendingRaidLayout = true
        return
    end
    
    local db = self:GetRaidDB()
    local container = self.raidContainer
    
    if not container then return end
    
    if self.raidTestMode then
        self:UpdateRaidTestLayout()
        return
    end
    
    -- Position container
    local anchorPoint = db.anchorPoint or "CENTER"
    local anchorX = db.anchorX or 0
    local anchorY = db.anchorY or 100
    
    container:ClearAllPoints()
    container:SetPoint(anchorPoint, UIParent, anchorPoint, anchorX, anchorY)
    
    local layoutMode = db.layoutMode or "BY_GROUP"
    
    if layoutMode == "FLAT" then
        self:UpdateRaidFlatLayout()
    else
        self:UpdateRaidGroupLayout()
    end
    
    self:UpdateRaidContainerSize()
end

function UnitFrames:UpdateRaidTestLayout()
    local db = self:GetRaidDB()
    local container = self.raidContainer
    
    if not container then return end
    
    -- Position container
    local anchorPoint = db.anchorPoint or "CENTER"
    local anchorX = db.anchorX or 0
    local anchorY = db.anchorY or 100
    
    container:ClearAllPoints()
    container:SetPoint(anchorPoint, UIParent, anchorPoint, anchorX, anchorY)
    
    local frameWidth = db.frameWidth or 80
    local frameHeight = db.frameHeight or 40
    local spacingX = db.frameSpacingX or db.frameSpacing or 2
    local spacingY = db.frameSpacingY or db.frameSpacing or 2
    local columns = db.columns or 5
    local growthDirection = db.growthDirection or "DOWN"
    local orientation = db.orientation or "HORIZONTAL"
    local testFrameCount = db.raidTestFrameCount or 15
    
    local visibleFrames = {}
    for i = 1, testFrameCount do
        local frame = self.raidFrames[i]
        if frame then
            table.insert(visibleFrames, frame)
        end
    end
    
    for i = testFrameCount + 1, 40 do
        local frame = self.raidFrames[i]
        if frame then
            frame:Hide()
        end
    end
    
    for i, frame in ipairs(visibleFrames) do
        frame:ClearAllPoints()
        self:ApplyFrameLayout(frame)
        
        local index = i - 1
        local col = index % columns
        local row = floor(index / columns)
        
        local offsetX, offsetY = 0, 0
        
        if orientation == "HORIZONTAL" then
            offsetX = col * (frameWidth + spacingX)
            if growthDirection == "DOWN" then
                offsetY = -row * (frameHeight + spacingY)
            else
                offsetY = row * (frameHeight + spacingY)
            end
        else
            if growthDirection == "DOWN" then
                offsetY = -col * (frameHeight + spacingY)
            else
                offsetY = col * (frameHeight + spacingY)
            end
            offsetX = row * (frameWidth + spacingX)
        end
        
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX, offsetY)
        frame:Show()
    end
    
    self:UpdateRaidContainerSize()
end

function UnitFrames:UpdateRaidGroupLayout()
    local db = self:GetRaidDB()
    local container = self.raidContainer
    
    local frameWidth = db.frameWidth or 80
    local frameHeight = db.frameHeight or 40
    local spacing = db.frameSpacing or 2
    local groupSpacing = db.groupSpacing or 10
    local growthDirection = db.growthDirection or "DOWN"
    local groupDirection = db.groupDirection or "RIGHT"
    
    -- Get visible groups
    local visibleGroups = db.visibleGroups or {true, true, true, true, true, true, true, true}
    
    -- Organize frames by group
    local groupFrames = {}
    for g = 1, 8 do
        groupFrames[g] = {}
    end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and UnitExists(frame.unit) then
            local _, _, group = GetRaidRosterInfo(i)
            if group and groupFrames[group] and visibleGroups[group] then
                table.insert(groupFrames[group], frame)
            end
        end
    end
    
    -- Position frames by group
    local groupIndex = 0
    
    for g = 1, 8 do
        if visibleGroups[g] and #groupFrames[g] > 0 then
            local groupOffset = groupIndex * (frameWidth + groupSpacing)
            if groupDirection == "LEFT" then
                groupOffset = -groupOffset
            elseif groupDirection == "DOWN" then
                groupOffset = -groupIndex * (frameHeight * 5 + groupSpacing)
            elseif groupDirection == "UP" then
                groupOffset = groupIndex * (frameHeight * 5 + groupSpacing)
            end
            
            for i, frame in ipairs(groupFrames[g]) do
                frame:ClearAllPoints()
                self:ApplyFrameLayout(frame)
                
                local index = i - 1
                local offsetX, offsetY = 0, 0
                
                if growthDirection == "DOWN" then
                    offsetY = -index * (frameHeight + spacing)
                elseif growthDirection == "UP" then
                    offsetY = index * (frameHeight + spacing)
                elseif growthDirection == "RIGHT" then
                    offsetX = index * (frameWidth + spacing)
                else
                    offsetX = -index * (frameWidth + spacing)
                end
                
                -- Apply group offset
                if groupDirection == "RIGHT" or groupDirection == "LEFT" then
                    offsetX = offsetX + groupOffset
                else
                    offsetY = offsetY + groupOffset
                end
                
                frame:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX, offsetY)
                frame:Show()
            end
            
            groupIndex = groupIndex + 1
        end
    end
    
    -- Hide frames not in visible groups
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame then
            local found = false
            for g = 1, 8 do
                for _, f in ipairs(groupFrames[g] or {}) do
                    if f == frame then
                        found = true
                        break
                    end
                end
                if found then break end
            end
            if not found then
                frame:Hide()
            end
        end
    end
    
    -- Update group labels if enabled
    self:UpdateGroupLabels()
end

-- ============================================================================
-- RAID LAYOUT - FLAT GRID
-- ============================================================================

function UnitFrames:UpdateRaidFlatLayout()
    local db = self:GetRaidDB()
    local container = self.raidContainer
    
    local frameWidth = db.frameWidth or 80
    local frameHeight = db.frameHeight or 40
    local spacingX = db.frameSpacingX or db.frameSpacing or 2
    local spacingY = db.frameSpacingY or db.frameSpacing or 2
    local columns = db.columns or 5
    local growthDirection = db.growthDirection or "DOWN"
    local orientation = db.orientation or "HORIZONTAL"
    
    -- Collect visible frames
    local visibleFrames = {}
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and UnitExists(frame.unit) then
            table.insert(visibleFrames, frame)
        end
    end
    
    -- Sort frames if enabled
    if db.sortEnabled and self.SortFrames then
        self:SortFrames(visibleFrames, db.sortMethod)
    end
    
    -- Position frames in grid
    for i, frame in ipairs(visibleFrames) do
        frame:ClearAllPoints()
        self:ApplyFrameLayout(frame)
        
        local index = i - 1
        local col = index % columns
        local row = floor(index / columns)
        
        local offsetX, offsetY = 0, 0
        
        if orientation == "HORIZONTAL" then
            offsetX = col * (frameWidth + spacingX)
            if growthDirection == "DOWN" then
                offsetY = -row * (frameHeight + spacingY)
            else
                offsetY = row * (frameHeight + spacingY)
            end
        else
            if growthDirection == "DOWN" then
                offsetY = -col * (frameHeight + spacingY)
            else
                offsetY = col * (frameHeight + spacingY)
            end
            offsetX = row * (frameWidth + spacingX)
        end
        
        frame:SetPoint("TOPLEFT", container, "TOPLEFT", offsetX, offsetY)
        frame:Show()
    end
    
    -- Hide unused frames
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame and not UnitExists(frame.unit) then
            frame:Hide()
        end
    end
end

-- ============================================================================
-- CONTAINER SIZE CALCULATION
-- ============================================================================

function UnitFrames:UpdateContainerSize()
    local db = self:GetDB()
    local container = self.container
    
    if not container then return end
    
    local frameWidth = db.frameWidth or 120
    local frameHeight = db.frameHeight or 50
    local spacing = db.frameSpacing or 2
    local showPlayer = db.showPlayer ~= false
    local orientation = db.orientation or "VERTICAL"
    
    local numFrames = showPlayer and 5 or 4
    
    local width, height
    
    if orientation == "HORIZONTAL" then
        width = numFrames * frameWidth + (numFrames - 1) * spacing
        height = frameHeight
    else
        width = frameWidth
        height = numFrames * frameHeight + (numFrames - 1) * spacing
    end
    
    container:SetSize(max(width, 1), max(height, 1))
end

function UnitFrames:UpdateRaidContainerSize()
    local db = self:GetRaidDB()
    local container = self.raidContainer
    
    if not container then return end
    
    local frameWidth = db.frameWidth or 80
    local frameHeight = db.frameHeight or 40
    local spacing = db.frameSpacing or 2
    local columns = db.columns or 5
    local layoutMode = db.layoutMode or "BY_GROUP"
    
    -- Count visible frames
    local numFrames = 0
    if self.raidTestMode then
        numFrames = db.raidTestFrameCount or 15
    else
        for i = 1, 40 do
            if self.raidFrames[i] and UnitExists("raid" .. i) then
                numFrames = numFrames + 1
            end
        end
    end
    
    if numFrames == 0 then
        numFrames = 1
    end
    
    local rows = ceil(numFrames / columns)
    
    local width = columns * frameWidth + (columns - 1) * spacing
    local height = rows * frameHeight + (rows - 1) * spacing
    
    container:SetSize(max(width, 1), max(height, 1))
end

-- ============================================================================
-- GROUP LABELS
-- ============================================================================

function UnitFrames:UpdateGroupLabels()
    local db = self:GetRaidDB()
    
    if not db.groupLabelsEnabled then
        self:HideGroupLabels()
        return
    end
    
    if not self.groupLabels then
        self.groupLabels = {}
    end
    
    -- Create labels as needed
    for g = 1, 8 do
        if not self.groupLabels[g] then
            local label = self.raidContainer:CreateFontString(nil, "OVERLAY")
            self:SafeSetFont(label, self:GetFontPath(db.groupLabelFont), db.groupLabelSize or 10, "OUTLINE")
            label:SetText("Group " .. g)
            self.groupLabels[g] = label
        end
        
        -- Position label
        local label = self.groupLabels[g]
        local visibleGroups = db.visibleGroups or {}
        
        if visibleGroups[g] then
            label:SetText("Group " .. g)
            -- Positioning would be based on first frame in group
            -- This is simplified; full implementation would track group positions
            label:Show()
        else
            label:Hide()
        end
    end
end

function UnitFrames:HideGroupLabels()
    if self.groupLabels then
        for _, label in pairs(self.groupLabels) do
            label:Hide()
        end
    end
end

-- ============================================================================
-- FRAME REGISTRATION
-- ============================================================================

function UnitFrames:RegisterFrameForClicking(frame)
    if not frame then return end
    
    -- Register with Clique if available
    if ClickCastFrames then
        ClickCastFrames[frame] = true
    end
    
    -- Register custom click casting
    if self.RegisterClickCast then
        self:RegisterClickCast(frame)
    end
end

function UnitFrames:UnregisterFrameForClicking(frame)
    if not frame then return end
    
    if ClickCastFrames then
        ClickCastFrames[frame] = nil
    end
    
    if self.UnregisterClickCast then
        self:UnregisterClickCast(frame)
    end
end

-- ============================================================================
-- VISIBILITY MANAGEMENT
-- ============================================================================

function UnitFrames:UpdateFrameVisibility()
    if InCombatLockdown() then
        self.pendingVisibilityUpdate = true
        return
    end
    
    local inRaid = IsInRaid()
    local inGroup = IsInGroup()
    local db = self:GetDB()
    local raidDb = self:GetRaidDB()
    
    -- Party frames visibility
    local partyEnabled = db.enabled ~= false
    local showParty = partyEnabled and not inRaid and inGroup
    if db.showInRaid then
        showParty = partyEnabled and (showParty or inRaid)
    end
    
    if showParty then
        if self.container then
            self.container:Show()
        end
        if self.playerFrame and db.showPlayer ~= false then
            self.playerFrame:Show()
        elseif self.playerFrame then
            self.playerFrame:Hide()
        end
        
        for i = 1, 4 do
            local frame = self.partyFrames[i]
            if frame then
                if UnitExists("party" .. i) then
                    frame:Show()
                else
                    frame:Hide()
                end
            end
        end
    else
        if self.container then
            self.container:Hide()
        end
    end
    
    -- Raid frames visibility
    if inRaid and raidDb.enabled ~= false then
        if self.raidContainer then
            self.raidContainer:Show()
        end
        
        for i = 1, 40 do
            local frame = self.raidFrames[i]
            if frame then
                if UnitExists("raid" .. i) then
                    frame:Show()
                else
                    frame:Hide()
                end
            end
        end
    else
        if self.raidContainer then
            self.raidContainer:Hide()
        end
    end
end

-- ============================================================================
-- MOVER FRAMES
-- ============================================================================

function UnitFrames:CreateMoverFrame(parent, name, onDragStop)
    local mover = CreateFrame("Frame", name, parent)
    mover:SetAllPoints(parent)
    mover:SetMovable(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetFrameLevel(parent:GetFrameLevel() + 10)
    mover:Hide()
    
    -- No background or border overlays - just text label like unit frame anchors
    -- Set anchor to be 8 pixels larger than parent (for clickable area)
    local parentWidth = parent:GetWidth() or 200
    local parentHeight = parent:GetHeight() or 40
    mover:SetSize(math.max(1, parentWidth + 8), math.max(1, parentHeight + 8))
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", parent, "CENTER", 0, 0)
    
    -- Label only - blue text like unit frame anchors
    mover.text = mover:CreateFontString(nil, "OVERLAY")
    local fontPath = LilyUI and LilyUI:GetGlobalFont()
    if fontPath then
        mover.text:SetFont(fontPath, 12, "OUTLINE")
    else
        self:SafeSetFont(mover.text, "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    end
    mover.text:SetTextColor(0.2, 0.5, 1, 1) -- Blue color matching unit frame anchors
    mover.text:SetText(name or "Mover")
    mover.text:SetPoint("TOP", mover, "TOP", 0, -2)
    mover.text:SetJustifyH("CENTER")
    
    -- Drag handlers
    mover:SetScript("OnDragStart", function(self)
        parent:StartMoving()
    end)
    
    mover:SetScript("OnDragStop", function(self)
        parent:StopMovingOrSizing()
        if onDragStop then
            onDragStop(parent)
        end
    end)
    
    return mover
end

function UnitFrames:ShowMovers()
    if InCombatLockdown() then
        self:Print("Cannot move frames in combat!")
        return
    end
    
    self.moversShown = true
    
    -- Create/show party mover
    if self.container then
        if not self.partyMover then
            self.partyMover = self:CreateMoverFrame(self.container, "Party Frames", function(parent)
                self:SaveContainerPosition("party")
            end)
        end
        self.partyMover:Show()
    end
    
    -- Create/show raid mover
    if self.raidContainer then
        if not self.raidMover then
            self.raidMover = self:CreateMoverFrame(self.raidContainer, "Raid Frames", function(parent)
                self:SaveContainerPosition("raid")
            end)
        end
        self.raidMover:Show()
    end
end

function UnitFrames:HideMovers()
    self.moversShown = false
    
    if self.partyMover then
        self.partyMover:Hide()
    end
    
    if self.raidMover then
        self.raidMover:Hide()
    end
end

function UnitFrames:ToggleMovers()
    if self.moversShown then
        self:HideMovers()
    else
        self:ShowMovers()
    end
end

-- ============================================================================
-- LOCK/UNLOCK FRAMES (for anchor system)
-- ============================================================================

function UnitFrames:UnlockFrames()
    -- Show movers for party frames (no overlay grid)
    self:ShowMovers()
end

function UnitFrames:LockFrames()
    -- Hide movers for party frames
    self:HideMovers()
end

function UnitFrames:UnlockRaidFrames()
    -- Show movers for raid frames (no overlay grid)
    self:ShowMovers()
end

function UnitFrames:LockRaidFrames()
    -- Hide movers for raid frames
    self:HideMovers()
end

function UnitFrames:SaveContainerPosition(containerType)
    local container = containerType == "raid" and self.raidContainer or self.container
    local db = containerType == "raid" and self:GetRaidDB() or self:GetDB()
    
    if not container then return end
    
    local point, _, relativePoint, x, y = container:GetPoint()
    
    db.anchorPoint = point
    db.anchorX = x
    db.anchorY = y
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function UnitFrames:Initialize()
    -- Initialize saved variables and defaults
    if self.InitializeDB then
        self:InitializeDB()
    end

    -- Load click casting bindings/settings (if module is present)
    if self.LoadClickCastBindings then
        self:LoadClickCastBindings()
    end
    
    -- Create containers
    self:CreatePartyContainer()
    self:CreateRaidContainer()
    
    -- Initialize party frames
    self:InitializePartyFrames()

    -- Apply click casting bindings now that frames exist
    if self.UpdateAllClickCastFrames then
        self:UpdateAllClickCastFrames()
    end
    
    -- Defer raid frame creation
    C_Timer.After(0.5, function()
        self:InitializeRaidFrames()
    end)
    
    -- Register events
    self:RegisterGroupEvents()
    
    -- Initial visibility update
    self:UpdateFrameVisibility()
    
    -- Force an initial update once unit data is ready
    C_Timer.After(0.1, function()
        self:UpdateAllFrames()
        self:UpdateAllLeaderIcons()
        if self.UpdateAllRoleIcons then
            self:UpdateAllRoleIcons()
        end
    end)
end

function UnitFrames:RegisterGroupEvents()
    local eventFrame = CreateFrame("Frame")
    self.eventFrame = eventFrame
    
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PARTY_LEADER_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "GROUP_ROSTER_UPDATE" then
            UnitFrames:OnGroupRosterUpdate()
        elseif event == "PARTY_LEADER_CHANGED" then
            UnitFrames:UpdateAllLeaderIcons()
        elseif event == "PLAYER_ROLES_ASSIGNED" then
            if UnitFrames.UpdateAllRoleIcons then
                UnitFrames:UpdateAllRoleIcons()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            UnitFrames:UpdateFrameVisibility()
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Process pending updates
            if UnitFrames.pendingPartyLayout then
                UnitFrames.pendingPartyLayout = nil
                UnitFrames:UpdatePartyLayout()
            end
            if UnitFrames.pendingRaidLayout then
                UnitFrames.pendingRaidLayout = nil
                UnitFrames:UpdateRaidLayout()
            end
            if UnitFrames.pendingVisibilityUpdate then
                UnitFrames.pendingVisibilityUpdate = nil
                UnitFrames:UpdateFrameVisibility()
            end
            if UnitFrames.UpdateAllRoleIcons then
                UnitFrames:UpdateAllRoleIcons()
            end
        end
    end)
end

function UnitFrames:OnGroupRosterUpdate()
    self:UpdateFrameVisibility()
    
    if IsInRaid() then
        self:UpdateRaidLayout()
    else
        self:UpdatePartyLayout()
    end
    
    self:UpdateAllFrames()
    if self.UpdateAllRoleIcons then
        self:UpdateAllRoleIcons()
    end
    self:UpdateAllLeaderIcons()
end

function UnitFrames:UpdateAllLeaderIcons()
    if self.playerFrame then
        self:UpdateLeaderIcon(self.playerFrame)
    end
    
    for i = 1, 4 do
        local frame = self.partyFrames[i]
        if frame then
            self:UpdateLeaderIcon(frame)
        end
    end
    
    for i = 1, 40 do
        local frame = self.raidFrames[i]
        if frame then
            self:UpdateLeaderIcon(frame)
        end
    end
end

-- ============================================================================
-- BLIZZARD FRAME HIDING
-- ============================================================================

function UnitFrames:HideBlizzardFrames()
    local db = self:GetDB()
    
    if db.hideBlizzardParty then
        self:HideBlizzardPartyFrames()
    end
    
    local raidDb = self:GetRaidDB()
    if raidDb.hideBlizzardRaid then
        self:HideBlizzardRaidFrames()
    end
end

function UnitFrames:HideBlizzardPartyFrames()
    -- Hide party frames
    local function HidePartyFrame(frame)
        if frame then
            frame:SetAlpha(0)
            frame:EnableMouse(false)
        end
    end
    
    -- Try to hide compact party frames
    if CompactPartyFrame then
        HidePartyFrame(CompactPartyFrame)
    end
    
    -- Hide individual party member frames
    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        if frame then
            HidePartyFrame(frame)
        end
    end
end

function UnitFrames:HideBlizzardRaidFrames()
    -- Hide compact raid frames
    if CompactRaidFrameManager then
        CompactRaidFrameManager:SetAlpha(0)
        CompactRaidFrameManager:EnableMouse(false)
    end
    
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:SetAlpha(0)
        CompactRaidFrameContainer:EnableMouse(false)
    end
end
