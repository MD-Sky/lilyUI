--[[
    LilyUI Unit Frames - Test Mode
    Provides preview/test mode for configuring frames outside of groups
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache commonly used API
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitClass = UnitClass
local floor = math.floor
local random = math.random

-- Test mode state
UnitFrames.testModeActive = false
UnitFrames.testModeData = {}

-- Power type colors (for test mode)
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
-- TEST DATA
-- ============================================================================

local TestNames = {
    "Grok",
    "ChatGPT",
    "Gemini",
    "Claude",
    "Perplexity",
}

local TestPlayerTemplates = {
    {class = "WARRIOR", role = "TANK", powerType = 1},
    {class = "PRIEST", role = "HEALER", powerType = 0},
    {class = "MAGE", role = "DAMAGER", powerType = 0},
    {class = "ROGUE", role = "DAMAGER", powerType = 3},
    {class = "DRUID", role = "HEALER", powerType = 0},
}

-- Test debuffs
local TestDebuffs = {
    {name = "Poison", icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", type = "Poison", duration = 30, stacks = 3},
    {name = "Curse", icon = "Interface\\Icons\\Spell_Shadow_CurseOfTounAA", type = "Curse", duration = 60, stacks = 0},
    {name = "Disease", icon = "Interface\\Icons\\Spell_Shadow_PlagueCloud", type = "Disease", duration = 45, stacks = 0},
    {name = "Magic", icon = "Interface\\Icons\\Spell_Frost_FrostShock", type = "Magic", duration = 15, stacks = 0},
}

-- Test buffs
local TestBuffs = {
    {name = "Shield", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", duration = 15, stacks = 0},
    {name = "Renew", icon = "Interface\\Icons\\Spell_Holy_Renew", duration = 12, stacks = 0},
    {name = "Fortitude", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", duration = 3600, stacks = 0},
}

local MountDebuff = {name = "Dazed", icon = "Interface\\Icons\\Spell_Frost_Stun", type = "Magic", duration = 8, stacks = 0}
local MountBuff = {name = "Mounted", icon = "Interface\\Icons\\Ability_Mount_RidingHorse", duration = 180, stacks = 0}

local function ShuffleInPlace(list)
    for i = #list, 2, -1 do
        local j = random(i)
        list[i], list[j] = list[j], list[i]
    end
end

local function RandomBetween(minValue, maxValue)
    return minValue + (maxValue - minValue) * random()
end

local function BuildRandomTestPlayers(count)
    local players = {}
    local names = {}
    local templates = {}
    for i, name in ipairs(TestNames) do
        names[i] = name
    end
    for i, template in ipairs(TestPlayerTemplates) do
        templates[i] = template
    end
    ShuffleInPlace(names)
    ShuffleInPlace(templates)

    for i = 1, count do
        local template = templates[((i - 1) % #templates) + 1]
        local name = names[((i - 1) % #names) + 1]
        local isDead = random() < 0.12
        local isAFK = (not isDead) and (random() < 0.18)
        local health = isDead and 0 or RandomBetween(0.15, 1)
        local power = isDead and 0 or RandomBetween(0.05, 1)

        players[i] = {
            name = name,
            class = template.class,
            role = template.role,
            powerType = template.powerType,
            health = health,
            power = power,
            maxHealth = random(90000, 220000),
            isDead = isDead,
            isAFK = isAFK,
            showDebuffs = random() < 0.6,
            showBuffs = random() < 0.6,
            showMountedDebuff = random() < 0.25,
            showMountedBuff = random() < 0.35,
        }
    end

    return players
end

local function ClearAuraIcons(icons)
    if not icons then return end
    for i = 1, #icons do
        local icon = icons[i]
        if icon then
            icon:Hide()
            if icon.count then
                icon.count:Hide()
            end
            if icon.border then
                icon.border:Hide()
            end
        end
    end
end

-- ============================================================================
-- TEST MODE TOGGLE
-- ============================================================================

--[[
    Enable test mode
    @param mode string - "party" or "raid" (defaults to "party")
]]
function UnitFrames:EnableTestMode(mode)
    local wantsRaid = mode == "raid"
    local alreadyActive = (wantsRaid and self.raidTestMode) or (not wantsRaid and self.testMode)
    if alreadyActive then return end
    
    -- Store original update functions if this is the first test mode being enabled
    if not self.testModeActive then
        self.originalGetSafeHealthPercent = self.GetSafeHealthPercent
        self.originalUpdateUnitFrame = self.UpdateUnitFrame
        
        -- Override functions for test mode
        self.GetSafeHealthPercent = function(unit)
            return self:GetTestHealthPercent(unit)
        end
    end
    
    self.testModeActive = true
    
    -- Enable the specific mode without affecting the other
    if wantsRaid then
        self.raidTestMode = true
    else
        self.testMode = true
    end
    
    -- Show test frames for the requested mode
    if wantsRaid then
        self:ShowTestRaidFrames()
    else
        self:ShowTestPartyFrames()
    end
    
    local modeText = wantsRaid and "raid" or "party"
    self:Print("Test mode (" .. modeText .. ") enabled. Use /nephui testmode to disable.")
end

--[[
    Disable test mode
    @param mode string - Optional: "party" or "raid" to disable only that mode, or nil to disable both
]]
function UnitFrames:DisableTestMode(mode)
    if not self.testModeActive then return end
    
    local disableParty = mode == nil or mode == "party"
    local disableRaid = mode == nil or mode == "raid"
    
    -- Only disable if the requested mode is actually active
    if mode == "party" and not self.testMode then return end
    if mode == "raid" and not self.raidTestMode then return end
    
    -- Disable the specific mode(s)
    if disableParty then
        self.testMode = false
        self:HideTestPartyFrames()
    end
    
    if disableRaid then
        self.raidTestMode = false
        self:HideTestRaidFrames()
    end
    
    -- Only fully disable test mode if both modes are now off
    if not self.testMode and not self.raidTestMode then
        self.testModeActive = false
        
        -- Restore original functions
        if self.originalGetSafeHealthPercent then
            self.GetSafeHealthPercent = self.originalGetSafeHealthPercent
        end
        
        if self.originalUpdateUnitFrame then
            self.UpdateUnitFrame = self.originalUpdateUnitFrame
        end
    end
    
    -- Update frame visibility
    self:UpdateFrameVisibility()
    self:UpdateAllFrames()
    
    local modeText = mode and ("(" .. mode .. ") ") or ""
    self:Print("Test mode " .. modeText .. "disabled.")
end

--[[
    Toggle test mode for a specific mode
    @param mode string - "party" or "raid" (defaults to "party")
]]
function UnitFrames:ToggleTestMode(mode)
    mode = mode or "party"
    local wantsRaid = mode == "raid"
    local activeForMode = (wantsRaid and self.raidTestMode) or (not wantsRaid and self.testMode)
    
    if activeForMode then
        self:DisableTestMode(mode)
        return
    end
    
    self:EnableTestMode(mode)
end

-- ============================================================================
-- TEST FRAME DISPLAY
-- ============================================================================

--[[
    Show test party frames
]]
function UnitFrames:ShowTestPartyFrames()
    local container = self.container
    if not container then return end
    
    self.testModeActive = true
    self.testMode = true
    -- Don't touch raidTestMode - allow both to be active
    
    container:Show()
    
    -- Don't hide raid frames - allow both test modes to be active simultaneously
    
    self:UpdateTestFramesWithLayout()
    self:UpdatePartyLayout()
end

--[[
    Show test raid frames
]]
function UnitFrames:ShowTestRaidFrames()
    if not self.raidContainer then
        self:CreateRaidContainer()
    end
    if not self.raidFrames or not self.raidFrames[1] then
        self:InitializeRaidFrames()
    end
    
    local container = self.raidContainer
    if not container then return end
    
    self.testModeActive = true
    -- Don't touch testMode - allow both to be active
    self.raidTestMode = true
    
    container:Show()
    
    -- Don't hide party frames - allow both test modes to be active simultaneously
    
    self.testModeData = self.testModeData or {}
    self.testModeData.raidPlayers = nil
    
    self:UpdateTestFramesWithLayout()
    -- Update layout (test layout ignores UnitExists)
    self:UpdateRaidLayout()
end

--[[
    Update all test frames (party and raid)
    @param applyLayout boolean - Whether to reapply layout before updating data
]]
function UnitFrames:UpdateTestFrames(applyLayout)
    if not self.testModeActive then return end
    
    local partyDb = self:GetDB()
    local raidDb = self:GetRaidDB()
    
    -- Party test frames
    if self.testMode then
        local testFrameCount = partyDb.testFrameCount or 5
        local showPlayer = partyDb.showPlayer ~= false
        local partyPlayers = BuildRandomTestPlayers(testFrameCount)
        
        if self.playerFrame then
            if showPlayer and testFrameCount >= 1 then
                if applyLayout then
                    self:ApplyFrameLayout(self.playerFrame)
                end
                self:ConfigureTestFrame(self.playerFrame, partyPlayers[1], 0)
                self.playerFrame:Show()
            else
                self.playerFrame:Hide()
            end
        end
        
        for i = 1, 4 do
            local frame = self.partyFrames[i]
            if frame then
                local frameIndex = (showPlayer and (i + 1) or i)
                local testData = partyPlayers[frameIndex]
                if testData and frameIndex <= testFrameCount then
                    if applyLayout then
                        self:ApplyFrameLayout(frame)
                    end
                    self:ConfigureTestFrame(frame, testData, i)
                    frame:Show()
                else
                    frame:Hide()
                end
            end
        end
    end
    
    -- Raid test frames
    if self.raidTestMode and self.raidFrames then
        local testFrameCount = raidDb.raidTestFrameCount or 15
        local raidPlayers = BuildRandomTestPlayers(testFrameCount)
        
        for i = 1, 40 do
            local frame = self.raidFrames[i]
            if frame then
                if i <= testFrameCount then
                    local testData
                    testData = raidPlayers[i]
                    
                    if testData then
                        if applyLayout then
                            self:ApplyFrameLayout(frame)
                        end
                        self:ConfigureTestFrame(frame, testData, i)
                        frame:Show()
                    end
                else
                    frame:Hide()
                end
            end
        end
    end
end

--[[
    Update all test frames and reapply layouts
]]
function UnitFrames:UpdateTestFramesWithLayout()
    self:UpdateTestFrames(true)
end

--[[
    Configure a frame with test data
    @param frame Frame - The frame to configure
    @param testData table - Test player data
    @param index number - Frame index
]]
function UnitFrames:ConfigureTestFrame(frame, testData, index)
    if not frame or not testData then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local healthPct = testData.health or 1
    local maxHealth = testData.maxHealth or 100000
    local currentHealth = math.floor(healthPct * maxHealth)
    local classColor = RAID_CLASS_COLORS[testData.class]
    
    local function GetClassColor()
        if classColor then
            return classColor.r, classColor.g, classColor.b
        end
        return 0.5, 0.5, 0.5
    end
    
    -- Store test data on frame
    frame.testData = testData
    frame.testIndex = index
    
    -- Update health bar
    if frame.healthBar then
        frame.healthBar:SetMinMaxValues(0, maxHealth)
        frame.healthBar:SetValue(currentHealth)
        
        -- Apply health bar color based on settings
        local colorMode = db.healthBarColorMode or "CLASS"
        local r, g, b
        if colorMode == "CLASS" then
            r, g, b = GetClassColor()
        elseif colorMode == "GRADIENT" then
            local gradientPreset = db.gradientPreset or "default"
            if db.useCustomGradient and db.customGradient then
                r, g, b = self:GetGradientColor(healthPct, db.customGradient)
            else
                r, g, b = self:GetGradientColor(healthPct, gradientPreset)
            end
        elseif colorMode == "CUSTOM" then
            local customColor = db.healthBarCustomColor or {r = 0.2, g = 0.8, b = 0.2}
            r, g, b = customColor.r, customColor.g, customColor.b
        elseif colorMode == "GRADIENT_CLASS" then
            local classR, classG, classB = GetClassColor()
            local gradR, gradG, gradB = self:GetGradientColor(healthPct, "default")
            local blendFactor = db.gradientClassBlend or 0.5
            r = classR * blendFactor + gradR * (1 - blendFactor)
            g = classG * blendFactor + gradG * (1 - blendFactor)
            b = classB * blendFactor + gradB * (1 - blendFactor)
        else
            r, g, b = GetClassColor()
        end
        
        if r and g and b then
            frame.healthBar:SetStatusBarColor(r, g, b)
            frame.currentHealthColor = {r = r, g = g, b = b}
        end
    end
    
    -- Update background
    if frame.background then
        local colorMode = db.backgroundColorMode or "CUSTOM"
        local r, g, b, a
        if colorMode == "CLASS" then
            local cr, cg, cb = GetClassColor()
            local alpha = db.backgroundClassAlpha or 0.3
            r, g, b, a = cr, cg, cb, alpha
        elseif colorMode == "HEALTH" and frame.currentHealthColor then
            r = frame.currentHealthColor.r * 0.3
            g = frame.currentHealthColor.g * 0.3
            b = frame.currentHealthColor.b * 0.3
            a = db.backgroundAlpha or 0.8
        else
            local customColor = db.backgroundColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
            r, g, b, a = customColor.r, customColor.g, customColor.b, customColor.a or 0.8
        end
        frame.background:SetColorTexture(r, g, b, a)
    end
    
    -- Update missing health bar
    if frame.healthBarBG and db.missingHealthEnabled then
        local missingColor = db.missingHealthColor or {r = 0.2, g = 0, b = 0}
        frame.healthBarBG:SetStatusBarColor(missingColor.r, missingColor.g, missingColor.b, missingColor.a or 1)
    end
    
    -- Update name
    if frame.nameText then
        frame.nameText:SetText(testData.name)
        
        -- Apply class color to name if configured
        if db.nameTextColorMode == "CLASS" then
            local r, g, b = GetClassColor()
            frame.nameText:SetTextColor(r, g, b)
        else
            local color = db.nameTextColor or {r = 1, g = 1, b = 1}
            frame.nameText:SetTextColor(color.r, color.g, color.b)
        end
    end
    
    -- Update health text
    if frame.healthText and db.healthTextEnabled then
        local format = db.healthTextFormat or "PERCENT"
        local text = ""
        if format == "PERCENT" then
            text = string.format("%.0f%%", healthPct * 100)
        elseif format == "CURRENT" then
            text = self:FormatNumber(currentHealth)
        elseif format == "CURRENT_MAX" then
            text = self:FormatNumber(currentHealth) .. "/" .. self:FormatNumber(maxHealth)
        elseif format == "DEFICIT" then
            local deficit = maxHealth - currentHealth
            if deficit > 0 then
                text = "-" .. self:FormatNumber(deficit)
            end
        end
        frame.healthText:SetText(text)
    end
    
    -- Update power bar
    if frame.dfPowerBar and db.powerBarEnabled then
        local powerPct = testData.power or 0.8
        frame.dfPowerBar:SetMinMaxValues(0, 100)
        frame.dfPowerBar:SetValue(powerPct * 100)
        
        local colorMode = db.powerBarColorMode or "POWER"
        if colorMode == "POWER" then
            local powerType = testData.powerType or 0
            local color = PowerColors[powerType] or {0.5, 0.5, 0.5}
            frame.dfPowerBar:SetStatusBarColor(color[1], color[2], color[3])
        elseif colorMode == "CLASS" then
            local r, g, b = GetClassColor()
            frame.dfPowerBar:SetStatusBarColor(r, g, b)
        else
            local color = db.powerBarCustomColor or {r = 0.3, g = 0.3, b = 0.8}
            frame.dfPowerBar:SetStatusBarColor(color.r, color.g, color.b)
        end
        frame.dfPowerBar:Show()
    end
    
    -- Update role icon
    if frame.roleIcon and db.roleIconEnabled then
        self:SetTestRoleIcon(frame.roleIcon, testData.role)
    end
    
    -- Update status text (dead/afk)
    if frame.statusText then
        if db.statusTextEnabled == false then
            frame.statusText:Hide()
        elseif testData.isDead or healthPct <= 0.02 then
            frame.statusText:SetText("Dead")
            frame.statusText:Show()
        elseif testData.isAFK then
            frame.statusText:SetText("AFK")
            frame.statusText:Show()
        else
            frame.statusText:Hide()
        end
    end
    
    -- Show test debuffs on some frames
    if frame.debuffIcons then
        if testData.showDebuffs or testData.showMountedDebuff then
            self:ShowTestDebuffs(frame, testData)
        else
            ClearAuraIcons(frame.debuffIcons)
        end
    end
    
    -- Show test buffs on some frames
    if frame.buffIcons then
        if testData.showBuffs or testData.showMountedBuff then
            self:ShowTestBuffs(frame, testData)
        else
            ClearAuraIcons(frame.buffIcons)
        end
    end
    
    -- Show dispel overlay on frames with dispellable debuffs
    if index % 3 == 1 then
        self:ShowDispelOverlay(frame, "Magic")
    end
end

--[[
    Set test role icon
    @param icon Texture - The role icon texture
    @param role string - Role name (TANK, HEALER, DAMAGER)
]]
function UnitFrames:SetTestRoleIcon(icon, role)
    if role == "TANK" then
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        icon:SetTexCoord(0, 19/64, 22/64, 41/64)
        icon:Show()
    elseif role == "HEALER" then
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        icon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
        icon:Show()
    elseif role == "DAMAGER" then
        icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        icon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
        icon:Show()
    else
        icon:Hide()
    end
end

--[[
    Show test debuffs on a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:ShowTestDebuffs(frame, testData)
    if not frame.debuffIcons then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local maxDebuffs = db.debuffMaxIcons or 3
    local debuffPool = {}
    for i = 1, #TestDebuffs do
        debuffPool[#debuffPool + 1] = TestDebuffs[i]
    end
    if testData and testData.showMountedDebuff then
        debuffPool[#debuffPool + 1] = MountDebuff
    end
    
    self:EnsureAuraIcons(frame, "DEBUFF", maxDebuffs)

    ShuffleInPlace(debuffPool)
    for i = 1, maxDebuffs do
        local icon = frame.debuffIcons[i]
        local debuff = debuffPool[i]

        if icon and debuff then
            icon.texture:SetTexture(debuff.icon)
            icon.expirationTime = GetTime() + random(5, debuff.duration)
            icon.auraDuration = debuff.duration
            icon.showDuration = db.auraDurationEnabled ~= false

            if debuff.stacks > 0 then
                icon.count:SetText(debuff.stacks)
                icon.count:Show()
            else
                icon.count:Hide()
            end

            -- Set border color based on debuff type
            local color = self.DebuffTypeColors[debuff.type]
            if color and icon.border then
                icon.border:SetVertexColor(color.r, color.g, color.b)
                icon.border:Show()
            end

            icon:Show()
        elseif icon then
            icon:Hide()
            if icon.count then
                icon.count:Hide()
            end
            if icon.border then
                icon.border:Hide()
            end
        end
    end
end

--[[
    Show test buffs on a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:ShowTestBuffs(frame, testData)
    if not frame.buffIcons then return end
    
    local db = frame.isRaidFrame and self:GetRaidDB() or self:GetDB()
    local maxBuffs = db.buffMaxIcons or 3
    local buffPool = {}
    for i = 1, #TestBuffs do
        buffPool[#buffPool + 1] = TestBuffs[i]
    end
    if testData and testData.showMountedBuff then
        buffPool[#buffPool + 1] = MountBuff
    end
    
    self:EnsureAuraIcons(frame, "BUFF", maxBuffs)

    ShuffleInPlace(buffPool)
    for i = 1, maxBuffs do
        local icon = frame.buffIcons[i]
        local buff = buffPool[i]

        if icon and buff then
            icon.texture:SetTexture(buff.icon)
            icon.expirationTime = GetTime() + random(5, buff.duration)
            icon.auraDuration = buff.duration
            icon.showDuration = db.auraDurationEnabled ~= false

            icon.count:Hide()
            if icon.border then
                icon.border:Hide()
            end

            icon:Show()
        elseif icon then
            icon:Hide()
            if icon.count then
                icon.count:Hide()
            end
            if icon.border then
                icon.border:Hide()
            end
        end
    end
end

-- ============================================================================
-- TEST DATA HELPERS
-- ============================================================================

--[[
    Get test health percent for a unit
    @param unit string - Unit ID
    @return number - Health percentage
]]
function UnitFrames:GetTestHealthPercent(unit)
    -- Find frame for unit
    local frame = self:GetFrameForUnit(unit)
    
    if frame and frame.testData then
        return frame.testData.health * 100
    end
    
    return 100
end

--[[
    Hide test party frames
]]
function UnitFrames:HideTestPartyFrames()
    -- Clear test data from party frames
    if self.playerFrame then
        self.playerFrame.testData = nil
    end
    
    for _, frame in pairs(self.partyFrames) do
        if frame then
            frame.testData = nil
        end
    end
end

--[[
    Hide test raid frames
]]
function UnitFrames:HideTestRaidFrames()
    -- Clear test data from raid frames
    for _, frame in pairs(self.raidFrames) do
        if frame then
            frame.testData = nil
            frame:Hide()
        end
    end
end

--[[
    Hide all test frames (both party and raid)
]]
function UnitFrames:HideTestFrames()
    self:HideTestPartyFrames()
    self:HideTestRaidFrames()
end

-- ============================================================================
-- ANIMATED TEST MODE
-- ============================================================================

local animationTicker = nil

--[[
    Start animated test mode (health changes over time)
    @param mode string - Optional: "party" or "raid" (defaults to "party")
]]
function UnitFrames:StartAnimatedTestMode(mode)
    if animationTicker then return end
    
    mode = mode or "party"
    self:EnableTestMode(mode)
    
    animationTicker = C_Timer.NewTicker(0.5, function()
        self:AnimateTestFrames()
    end)
end

--[[
    Stop animated test mode
]]
function UnitFrames:StopAnimatedTestMode()
    if animationTicker then
        animationTicker:Cancel()
        animationTicker = nil
    end
    
    self:DisableTestMode()
end

--[[
    Animate test frames (random health changes)
]]
function UnitFrames:AnimateTestFrames()
    if not self.testModeActive then return end
    
    -- Animate party frames if party test mode is active
    if self.testMode then
        if self.playerFrame and self.playerFrame.testData then
            local change = (random() - 0.5) * 0.1
            self.playerFrame.testData.health = math.max(0, math.min(1, self.playerFrame.testData.health + change))
            self:ConfigureTestFrame(self.playerFrame, self.playerFrame.testData, 0)
        end
        
        for _, frame in pairs(self.partyFrames) do
            if frame and frame.testData then
                local change = (random() - 0.5) * 0.1
                frame.testData.health = math.max(0, math.min(1, frame.testData.health + change))
                self:ConfigureTestFrame(frame, frame.testData, frame.testIndex or 0)
            end
        end
    end
    
    -- Animate raid frames if raid test mode is active
    if self.raidTestMode then
        for _, frame in pairs(self.raidFrames) do
            if frame and frame.testData then
                local change = (random() - 0.5) * 0.1
                frame.testData.health = math.max(0, math.min(1, frame.testData.health + change))
                self:ConfigureTestFrame(frame, frame.testData, frame.testIndex or 0)
            end
        end
    end
end

-- ============================================================================
-- SLASH COMMAND
-- ============================================================================

-- Register slash command for test mode
SLASH_NEPHUITEST1 = "/nephuitest"
SlashCmdList["NEPHUITEST"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "party" then
        UnitFrames:ToggleTestMode("party")
    elseif msg == "raid" then
        UnitFrames:ToggleTestMode("raid")
    elseif msg == "both" then
        -- Enable both test modes
        UnitFrames:EnableTestMode("party")
        UnitFrames:EnableTestMode("raid")
    elseif msg == "animate" then
        UnitFrames:StartAnimatedTestMode()
    elseif msg == "stop" then
        UnitFrames:StopAnimatedTestMode()
    elseif msg == "" or msg == "toggle" then
        -- Toggle party by default for backwards compatibility
        UnitFrames:ToggleTestMode("party")
    elseif msg == "off" or msg == "disable" then
        -- Disable all test modes
        UnitFrames:DisableTestMode()
    else
        print("LilyUI Test Mode Commands:")
        print("  /nephuitest - Toggle party test mode")
        print("  /nephuitest party - Toggle party test frames")
        print("  /nephuitest raid - Toggle raid test frames")
        print("  /nephuitest both - Enable both party and raid test modes")
        print("  /nephuitest animate - Start animated test")
        print("  /nephuitest stop - Stop animated test")
        print("  /nephuitest off - Disable all test modes")
    end
end
