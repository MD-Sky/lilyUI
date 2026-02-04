--[[
    LilyUI Unit Frames - Default Configuration
    Contains all default settings for party and raid frame customization
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Ensure PartyFrames module exists
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames


-- Local deep-copy helper.
-- Core/Defaults.lua is loaded early, before the PartyRaidFrames module defines its own DeepCopy.
-- We keep this here so defaults are always buildable.
local function DeepCopy(src, seen)
    if type(src) ~= "table" then return src end
    seen = seen or {}
    if seen[src] then return seen[src] end
    local dst = {}
    seen[src] = dst
    for k, v in pairs(src) do
        dst[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return setmetatable(dst, getmetatable(src))
end

-- Provide a method-style DeepCopy for any early callers.
UnitFrames.DeepCopy = UnitFrames.DeepCopy or function(_, t)
    return DeepCopy(t)
end


-- ============================================================================
-- SHARED DEFAULT VALUES
-- Common settings used by both party and raid frames
-- ============================================================================

local SharedDefaults = {
    -- Module State
    enabled = true,
    locked = true,
    
    -- Frame Dimensions
    frameWidth = 120,
    frameHeight = 50,
    frameSpacing = 2,
    
    -- Position
    anchorPoint = "CENTER",
    anchorX = 0,
    anchorY = 0,
    
    -- Layout Direction
    growDirection = "VERTICAL",
    growthAnchor = "START",
    
    -- Health Bar Configuration
    healthBarOrientation = "HORIZONTAL",
    healthBarTexture = "Solid",
    healthBarInset = 1,
    
    -- Health Colors
    healthColorMode = "CLASS",
    healthCustomColor = {r = 0.2, g = 0.8, b = 0.2},
    healthGradientStart = {r = 1, g = 0, b = 0},
    healthGradientEnd = {r = 0.2, g = 0.8, b = 0.2},
    healthReactionColors = true,
    
    -- Background Settings
    backgroundColor = {r = 0.1, g = 0.1, b = 0.1, a = 0.8},
    backgroundColorMode = "CUSTOM",
    backgroundClassAlpha = 0.3,
    backgroundTexture = "Solid",
    
    -- Missing Health Background
    missingHealthEnabled = false,
    missingHealthColor = {r = 0.15, g = 0.15, b = 0.15, a = 0.9},
    missingHealthColorMode = "CUSTOM",
    
    -- Border Configuration
    borderEnabled = true,
    borderColor = {r = 0, g = 0, b = 0, a = 1},
    borderSize = 1,
    borderTexture = "Solid",
    
    -- Power Bar Settings
    powerBarEnabled = true,
    powerBarHeight = 6,
    powerBarPosition = "BOTTOM",
    powerBarTexture = "Solid",
    powerBarInset = 1,
    powerBarColorMode = "POWER",
    powerBarCustomColor = {r = 0.3, g = 0.3, b = 0.8},
    powerBarBackground = {r = 0.1, g = 0.1, b = 0.1, a = 0.8},
    
    -- Absorb Bar Settings
    absorbBarEnabled = true,
    absorbBarColor = {r = 0.8, g = 0.8, b = 0.2, a = 0.6},
    absorbBarTexture = "Solid",
    absorbBarOverlay = true,
    
    -- Heal Absorb Settings
    healAbsorbEnabled = true,
    healAbsorbColor = {r = 0.8, g = 0.2, b = 0.2, a = 0.6},
    
    -- Heal Prediction Settings
    healPredictionEnabled = true,
    healPredictionColor = {r = 0.3, g = 0.8, b = 0.3, a = 0.5},
    healPredictionMaxOverflow = 1.2,
    
    -- Name Text Configuration
    nameTextEnabled = true,
    nameTextFont = "Fonts\\FRIZQT__.TTF",
    nameTextSize = 11,
    nameTextOutline = "OUTLINE",
    nameTextColor = {r = 1, g = 1, b = 1},
    nameTextColorMode = "WHITE",
    nameTextAnchor = "TOP",
    nameTextOffsetX = 0,
    nameTextOffsetY = -2,
    nameTextMaxLength = 12,
    nameTextTruncate = true,
    
    -- Health Text Configuration
    healthTextEnabled = true,
    healthTextFont = "Fonts\\FRIZQT__.TTF",
    healthTextSize = 10,
    healthTextOutline = "OUTLINE",
    healthTextColor = {r = 1, g = 1, b = 1},
    healthTextFormat = "PERCENT",
    healthTextAnchor = "CENTER",
    healthTextOffsetX = 0,
    healthTextOffsetY = 0,
    healthTextHideAtFull = false,
    
    -- Status Text Configuration
    statusTextEnabled = true,
    statusTextFont = "Fonts\\FRIZQT__.TTF",
    statusTextSize = 10,
    statusTextOutline = "OUTLINE",
    statusTextAnchor = "CENTER",
    statusTextOffsetX = 0,
    statusTextOffsetY = 0,
    
    -- Role Icon Settings
    roleIconEnabled = true,
    roleIconSize = 14,
    roleIconAnchor = "TOPLEFT",
    roleIconOffsetX = 2,
    roleIconOffsetY = -2,
    roleIconAlpha = 1,
    
    -- Leader Icon Settings
    leaderIconEnabled = true,
    leaderIconSize = 14,
    leaderIconAnchor = "TOPRIGHT",
    leaderIconOffsetX = -2,
    leaderIconOffsetY = -2,
    
    -- Raid Target Icon Settings
    raidTargetIconEnabled = true,
    raidTargetIconSize = 20,
    raidTargetIconAnchor = "CENTER",
    raidTargetIconOffsetX = 0,
    raidTargetIconOffsetY = 0,
    
    -- Ready Check Icon Settings
    readyCheckIconEnabled = true,
    readyCheckIconSize = 24,
    readyCheckIconAnchor = "CENTER",
    readyCheckIconOffsetX = 0,
    readyCheckIconOffsetY = 0,
    
    -- Center Status Icon (Resurrection, Summon, etc.)
    centerStatusIconEnabled = true,
    centerStatusIconSize = 24,
    centerStatusIconAnchor = "CENTER",
    centerStatusIconOffsetX = 0,
    centerStatusIconOffsetY = 0,
    
    -- Buff Display Settings
    showBuffs = true,
    buffMax = 4,
    buffSize = 18,
    buffScale = 1.0,
    buffAnchor = "BOTTOMRIGHT",
    buffGrowth = "LEFT_UP",
    buffOffsetX = -2,
    buffOffsetY = 2,
    buffPaddingX = 2,
    buffPaddingY = 2,
    buffWrap = 4,
    buffBorderEnabled = true,
    buffBorderThickness = 1,
    buffFilterMode = "BLIZZARD",
    buffFilterPlayer = false,
    buffFilterRaid = false,
    buffFilterCancelable = false,
    
    -- Debuff Display Settings
    showDebuffs = true,
    debuffMax = 4,
    debuffSize = 18,
    debuffScale = 1.0,
    debuffAnchor = "BOTTOMLEFT",
    debuffGrowth = "RIGHT_UP",
    debuffOffsetX = 2,
    debuffOffsetY = 2,
    debuffPaddingX = 2,
    debuffPaddingY = 2,
    debuffWrap = 4,
    debuffBorderEnabled = true,
    debuffBorderThickness = 1,
    debuffBorderColorByType = true,
    debuffFilterMode = "BLIZZARD",
    debuffShowAll = false,
    
    -- Debuff Border Colors by Type
    debuffBorderColorNone = {r = 0.8, g = 0, b = 0},
    debuffBorderColorMagic = {r = 0.2, g = 0.6, b = 1.0},
    debuffBorderColorCurse = {r = 0.6, g = 0, b = 1.0},
    debuffBorderColorDisease = {r = 0.6, g = 0.4, b = 0},
    debuffBorderColorPoison = {r = 0, g = 0.6, b = 0},
    debuffBorderColorBleed = {r = 1.0, g = 0, b = 0},
    
    -- Aura Duration Text
    auraDurationEnabled = true,
    auraDurationFont = "Fonts\\FRIZQT__.TTF",
    auraDurationSize = 9,
    auraDurationOutline = "OUTLINE",
    auraDurationPosition = "BOTTOM",
    auraDurationOffsetY = -2,
    
    -- Aura Stack Count
    auraStackEnabled = true,
    auraStackFont = "Fonts\\FRIZQT__.TTF",
    auraStackSize = 10,
    auraStackOutline = "OUTLINE",
    auraStackPosition = "BOTTOMRIGHT",
    auraStackMinimum = 2,
    
    -- Aura Expiring Indicator
    auraExpiringEnabled = true,
    auraExpiringThreshold = 5,
    auraExpiringTintColor = {r = 1, g = 0.2, b = 0.2, a = 0.4},
    auraExpiringBorderPulse = true,
    
    -- Duration Color Settings
    durationColorEnabled = false,
    durationColorHigh = {r = 1, g = 1, b = 1},
    durationColorMid = {r = 1, g = 1, b = 0},
    durationColorLow = {r = 1, g = 0, b = 0},
    durationHighThreshold = 0.5,
    durationLowThreshold = 0.25,
    
    -- Dispel Overlay Settings
    dispelOverlayEnabled = true,
    dispelShowGradient = true,
    dispelGradientAlpha = 0.3,
    dispelGradientIntensity = 1.0,
    dispelGradientDarkenEnabled = false,
    dispelGradientDarkenAlpha = 0.5,
    dispelShowIcon = true,
    dispelIconSize = 20,
    dispelIconAlpha = 1.0,
    dispelIconPosition = "CENTER",
    dispelIconOffsetX = 0,
    dispelIconOffsetY = 0,
    dispelBorderSize = 2,
    dispelBorderInset = 0,
    dispelBorderAlpha = 0.8,
    
    -- Dispel Type Colors
    dispelMagicColor = {r = 0.2, g = 0.6, b = 1.0},
    dispelCurseColor = {r = 0.6, g = 0, b = 1.0},
    dispelDiseaseColor = {r = 0.6, g = 0.4, b = 0},
    dispelPoisonColor = {r = 0, g = 0.6, b = 0},
    dispelBleedColor = {r = 1.0, g = 0, b = 0},
    
    -- Selection Highlight
    selectionHighlightEnabled = true,
    selectionHighlightTexture = "Interface\\AddOns\\LilyUI\\Media\\uf_selected.tga",
    selectionHighlightAlpha = 0.5,
    
    -- Mouseover Highlight
    mouseoverHighlightEnabled = true,
    mouseoverHighlightTexture = "Interface\\AddOns\\LilyUI\\Media\\uf_mouseover.tga",
    mouseoverHighlightAlpha = 0.3,
    
    -- Aggro Highlight
    aggroHighlightMode = "SOLID",
    aggroHighlightThickness = 2,
    aggroHighlightInset = 0,
    aggroHighlightAlpha = 0.8,
    aggroOnlyTanking = false,
    
    -- Out of Range Settings
    oorEnabled = false,
    rangeFadeAlpha = 0.55,
    oorHealthBarAlpha = 0.55,
    oorBackgroundAlpha = 0.55,
    oorNameTextAlpha = 0.55,
    oorHealthTextAlpha = 0.55,
    oorAurasAlpha = 0.55,
    oorIconsAlpha = 0.55,
    oorDispelOverlayAlpha = 0.55,
    oorPowerBarAlpha = 0.55,
    oorMissingBuffAlpha = 0.5,
    oorDefensiveIconAlpha = 0.5,
    oorTargetedSpellAlpha = 0.5,
    
    -- Dead/Offline Frame Fading
    fadeDeadFrames = true,
    fadeDeadAlpha = 0.6,
    fadeDeadBackground = 0.4,
    fadeDeadUseCustomColor = true,
    fadeDeadBackgroundColor = {r = 0.3, g = 0, b = 0},
    
    -- Tooltip Settings
    tooltipEnabled = true,
    tooltipInCombat = false,
    tooltipPosition = "CURSOR",
    
    -- Missing Buff Icon
    missingBuffEnabled = false,
    missingBuffSize = 20,
    missingBuffAnchor = "TOPRIGHT",
    missingBuffOffsetX = -2,
    missingBuffOffsetY = -2,
    missingBuffBorderColor = {r = 1, g = 0.5, b = 0, a = 0.8},
    missingBuffHideFromBar = false,
    
    -- Defensive Icon
    defensiveIconEnabled = false,
    defensiveIconSize = 24,
    defensiveIconAnchor = "CENTER",
    defensiveIconOffsetX = 0,
    defensiveIconOffsetY = 0,
    defensiveIconBorderColor = {r = 0, g = 0.8, b = 0, a = 0.8},
    
    -- Private Auras
    privateAurasEnabled = true,
    privateAurasSize = 20,
    privateAurasAnchor = "TOP",
    privateAurasOffsetX = 0,
    privateAurasOffsetY = 2,
    
    -- Sorting Options
    sortEnabled = false,
    sortPrimary = "ROLE",
    sortSecondary = "NAME",
    sortReverseOrder = false,
    sortPlayerFirst = true,
    
    -- Test Mode Settings
    testFrameCount = 5,
    testShowSelection = true,
    testShowAggro = true,
    testShowOutOfRange = true,
    
    -- Blizzard Frame Visibility
    hideBlizzardPartyFrames = true,
    showBlizzardSideMenu = false,
    
    -- Solo Mode
    soloMode = true,
    hidePlayerFrame = false,
    
    -- Pet Frame Settings
    showPetFrames = false,
    petFrameWidth = 80,
    petFrameHeight = 25,
    petFrameAnchor = "BOTTOM",
    petFrameOffsetX = 0,
    petFrameOffsetY = -5,
    
    -- Rested Indicator
    restedIndicatorEnabled = false,
    
    -- Targeted Spells
    targetedSpellsEnabled = false,
    targetedSpellsMax = 3,
    targetedSpellsSize = 20,
    targetedSpellsAnchor = "LEFT",
    targetedSpellsOffsetX = -5,
    targetedSpellsOffsetY = 0,
}

-- ============================================================================
-- PARTY FRAME DEFAULTS
-- Settings specific to party frames
-- ============================================================================

UnitFrames.PartyDefaults = {}
for k, v in pairs(SharedDefaults) do
    if type(v) == "table" then
        UnitFrames.PartyDefaults[k] = DeepCopy(v)
    else
        UnitFrames.PartyDefaults[k] = v
    end
end

-- Party-specific overrides
UnitFrames.PartyDefaults.frameWidth = 120
UnitFrames.PartyDefaults.frameHeight = 50
UnitFrames.PartyDefaults.growDirection = "VERTICAL"
UnitFrames.PartyDefaults.anchorX = -400
UnitFrames.PartyDefaults.anchorY = 0

-- ============================================================================
-- RAID FRAME DEFAULTS
-- Settings specific to raid frames
-- ============================================================================

UnitFrames.RaidDefaults = {}
for k, v in pairs(SharedDefaults) do
    if type(v) == "table" then
        UnitFrames.RaidDefaults[k] = DeepCopy(v)
    else
        UnitFrames.RaidDefaults[k] = v
    end
end

-- Raid-specific overrides
UnitFrames.RaidDefaults.frameWidth = 80
UnitFrames.RaidDefaults.frameHeight = 35
UnitFrames.RaidDefaults.growDirection = "HORIZONTAL"
UnitFrames.RaidDefaults.nameTextSize = 10
UnitFrames.RaidDefaults.healthTextSize = 9
UnitFrames.RaidDefaults.buffMax = 3
UnitFrames.RaidDefaults.debuffMax = 3
UnitFrames.RaidDefaults.buffSize = 16
UnitFrames.RaidDefaults.debuffSize = 16

-- Raid-specific position
UnitFrames.RaidDefaults.raidAnchorX = 0
UnitFrames.RaidDefaults.raidAnchorY = -200
UnitFrames.RaidDefaults.raidLocked = true

-- Raid Layout Settings
UnitFrames.RaidDefaults.raidUseGroups = true
UnitFrames.RaidDefaults.raidGroupSpacing = 10
UnitFrames.RaidDefaults.raidRowColSpacing = 15
UnitFrames.RaidDefaults.raidGroupsPerRow = 2
UnitFrames.RaidDefaults.raidGroupAnchor = "START"
UnitFrames.RaidDefaults.raidPlayerAnchor = "START"
UnitFrames.RaidDefaults.raidReverseGroupOrder = false

-- Raid Flat Grid Layout
UnitFrames.RaidDefaults.raidPlayersPerRow = 5
UnitFrames.RaidDefaults.raidFlatHorizontalSpacing = 2
UnitFrames.RaidDefaults.raidFlatVerticalSpacing = 2
UnitFrames.RaidDefaults.raidFlatPlayerAnchor = "START"
UnitFrames.RaidDefaults.raidFlatReverseFillOrder = false

-- Raid Group Labels
UnitFrames.RaidDefaults.groupLabelEnabled = false
UnitFrames.RaidDefaults.groupLabelFont = "Fonts\\FRIZQT__.TTF"
UnitFrames.RaidDefaults.groupLabelFontSize = 12
UnitFrames.RaidDefaults.groupLabelOutline = "OUTLINE"
UnitFrames.RaidDefaults.groupLabelColor = {r = 1, g = 1, b = 1, a = 1}
UnitFrames.RaidDefaults.groupLabelFormat = "GROUP_NUM"
UnitFrames.RaidDefaults.groupLabelAnchor = "TOP"
UnitFrames.RaidDefaults.groupLabelRelativeAnchor = "TOP"
UnitFrames.RaidDefaults.groupLabelOffsetX = 0
UnitFrames.RaidDefaults.groupLabelOffsetY = 12
UnitFrames.RaidDefaults.groupLabelShadow = false

-- Raid Test Mode
UnitFrames.RaidDefaults.raidTestFrameCount = 15

-- Raid Blizzard Frame Visibility
UnitFrames.RaidDefaults.hideBlizzardRaidFrames = true


-- ============================================================================
-- ACE DB DEFAULTS (Core profile defaults)
-- ============================================================================
-- These are the defaults used to initialize lilyUIDB (AceDB). They MUST exist,
-- because many config setters assign into LilyUI.db.profile.<table> directly.

LilyUI.defaults = LilyUI.defaults or { profile = {} }
local p = LilyUI.defaults.profile

-- General / global styling
p.general = p.general or {
    uiScale = 1,
    eyefinity = false,
    ultrawide = false,
    applyGlobalFontToBlizzard = true,
    globalFont = "Fonts\\FRIZQT__.TTF",
    globalTexture = "Solid",
    uiBackdropStyle = "Default",
    -- Pink-ish default theme (matches your "make it pink" request)
    colorScheme = { 1.0, 0.25, 0.65, 1.0 },
}

-- Minimap
p.minimap = p.minimap or {
    enabled = true,
    size = 160,
    scale = 1,
    lock = false,
    borderSize = 1,
    mouseWheelZoom = true,
    autoZoom = false,
    hideZoomButtons = false,
    hideTrackingButton = false,
    hideMailButton = false,
    hideMissionsButton = false,
    hideCalendarButton = false,
    hideAddonCompartment = false,
    hideDifficultyIcon = false,
    clock = { enabled = true, fontSize = 12, anchorPoint = "TOP", offsetX = 0, offsetY = 0, color = { 1, 1, 1, 1 } },
    fps   = { enabled = false, fontSize = 12, anchorPoint = "TOP", offsetX = 0, offsetY = -12, color = { 1, 1, 1, 1 }, updateFrequency = 1 },
    zoneText = { enabled = true, fontSize = 12, anchorPoint = "BOTTOM", offsetX = 0, offsetY = 0, color = { 1, 1, 1, 1 } },
    mailIcon = { anchorPoint = "TOPRIGHT", offsetX = 0, offsetY = 0 },
    difficultyIcon = { anchorPoint = "TOPLEFT", offsetX = 0, offsetY = 0 },
    missionsButton = { anchorPoint = "BOTTOMRIGHT", offsetX = 0, offsetY = 0 },
}

-- Chat
p.chat = p.chat or {
    enabled = true,
    backgroundColor = { 0, 0, 0, 0.4 },
    hideQuickJoinToastButton = true,
    quickJoinToastButtonOffsetX = 0,
    quickJoinToastButtonOffsetY = 0,
}

-- Action Bars
p.actionBars = p.actionBars or {
    enabled = true,
    font = "Fonts\\FRIZQT__.TTF",
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    backdropColor = { 0, 0, 0, 0.25 },
    mouseover = false,
    procGlow = { enabled = true },
    macroText = { hide = false, fontSize = 10, offsetX = 0, offsetY = 0, fontColor = { 1, 1, 1, 1 } },
    keybindText = { hide = false, fontSize = 10, offsetX = 0, offsetY = 0, fontColor = { 1, 1, 1, 1 } },
    countText = { hide = false, fontSize = 10, offsetX = 0, offsetY = 0, fontColor = { 1, 1, 1, 1 } },
}

-- Cast Bars (player/target/focus/boss)
p.castBar = p.castBar or {
    enabled = true,
    attachTo = "PLAYER",
    anchorPoint = "CENTER",
    offsetX = 0,
    offsetY = -180,
    width = 240,
    height = 18,
    texture = "Solid",
    bgColor = { 0, 0, 0, 0.35 },
    color = { 1, 0.7, 0.2, 1 },
    useClassColor = false,
    showIcon = true,
    showTimeText = true,
    textSize = 11,
    showEmpoweredTicks = true,
    showEmpoweredStageColors = true,
    empoweredStageColors = {
        { 0.2, 0.8, 1.0, 1 },
        { 0.4, 1.0, 0.4, 1 },
        { 1.0, 0.85, 0.2, 1 },
    },
}

p.targetCastBar = p.targetCastBar or {
    enabled = true,
    attachTo = "TARGET",
    anchorPoint = "CENTER",
    offsetX = 0,
    offsetY = -140,
    width = 220,
    height = 16,
    texture = "Solid",
    bgColor = { 0, 0, 0, 0.35 },
    color = { 0.3, 0.8, 1.0, 1 },
    interruptedColor = { 0.8, 0.2, 0.2, 1 },
    interruptibleColor = { 0.3, 0.8, 1.0, 1 },
    nonInterruptibleColor = { 0.8, 0.8, 0.8, 1 },
    showIcon = true,
    showTimeText = true,
    textSize = 10,
}

p.focusCastBar = p.focusCastBar or {
    enabled = true,
    attachTo = "FOCUS",
    anchorPoint = "CENTER",
    offsetX = 0,
    offsetY = -120,
    width = 220,
    height = 16,
    texture = "Solid",
    bgColor = { 0, 0, 0, 0.35 },
    color = { 0.3, 0.8, 1.0, 1 },
    interruptedColor = { 0.8, 0.2, 0.2, 1 },
    interruptibleColor = { 0.3, 0.8, 1.0, 1 },
    nonInterruptibleColor = { 0.8, 0.8, 0.8, 1 },
    showIcon = true,
    showTimeText = true,
    textSize = 10,
}

p.bossCastBar = p.bossCastBar or {
    enabled = true,
    anchorPoint = "CENTER",
    offsetX = 0,
    offsetY = -100,
    width = 220,
    height = 16,
    texture = "Solid",
    bgColor = { 0, 0, 0, 0.35 },
    interruptedColor = { 0.8, 0.2, 0.2, 1 },
    interruptibleColor = { 0.9, 0.7, 0.2, 1 },
    nonInterruptibleColor = { 0.8, 0.8, 0.8, 1 },
    showIcon = true,
    showTimeText = true,
}

-- Resource Bars
p.powerBar = p.powerBar or {
    enabled = true,
    attachTo = "PLAYER",
    anchorPoint = "CENTER",
    offsetX = 0,
    offsetY = -210,
    width = 240,
    height = 8,
    texture = "Solid",
    bgColor = { 0, 0, 0, 0.35 },
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    updateFrequency = 0.05,
    smoothProgress = true,
    showText = true,
    hideBarShowText = false,
    showManaAsPercent = false,
    hideWhenMana = false,
    showTicks = true,
    textSize = 10,
    textX = 0,
    textY = 0,
}

p.secondaryPowerBar = p.secondaryPowerBar or {
    enabled = true,
    attachTo = "PLAYER",
    anchorPoint = "CENTER",
    offsetX = 0,
    offsetY = -225,
    width = 240,
    height = 8,
    texture = "Solid",
    bgColor = { 0, 0, 0, 0.35 },
    borderSize = 1,
    borderColor = { 0, 0, 0, 1 },
    updateFrequency = 0.05,
    smoothProgress = true,
    showText = true,
    hideBarShowText = false,
    showManaAsPercent = false,
    hideWhenMana = false,
    showTicks = true,
    showFragmentedPowerBarText = true,
    runeTimerTextSize = 10,
    runeTimerTextX = 0,
    runeTimerTextY = 0,
    textSize = 10,
    textX = 0,
    textY = 0,
}

-- Buff Bar Viewer
p.buffBarViewer = p.buffBarViewer or {
    enabled = true,
    width = 220,
    height = 18,
    texture = "Solid",
    barSpacing = 2,
    showName = true,
    showDuration = true,
    showApplications = true,
    nameSize = 11,
    durationSize = 10,
    applicationsSize = 10,
    nameAnchor = "LEFT",
    durationAnchor = "RIGHT",
    applicationsAnchor = "RIGHT",
    nameOffsetX = 4, nameOffsetY = 0,
    durationOffsetX = -4, durationOffsetY = 0,
    applicationsOffsetX = -22, applicationsOffsetY = 0,
    hideIcon = false,
    hideIconMask = false,
    iconBorderSize = 1,
    iconZoom = 0.08,
    barColors = { 0.2, 0.8, 0.2, 1 },
    barColorsBySpec = {},
}

-- Buff/Debuff Frames (player auras)
p.buffDebuffFrames = p.buffDebuffFrames or { enabled = true }

-- Icon Viewers (Cooldown Viewer skinning/overrides)
p.viewers = p.viewers or { general = { enabled = true } }

-- Custom Icons / Icon Customization
p.customIcons = p.customIcons or { enabled = true }
p.iconCustomization = p.iconCustomization or { enabled = true }
p.dynamicIcons = p.dynamicIcons or { iconData = {} }
p.keybindCache = p.keybindCache or {}

-- QOL
p.qol = p.qol or {
    hideBagsBar = false,
    tooltipIDs = false,
    characterPanel = true,
}

-- Unit Frames
p.unitFrames = p.unitFrames or {
    enabled = true,
    General = {},
    boss = {},
}

-- Party/Raid frames (big defaults are defined above)
p.partyFrames = p.partyFrames or DeepCopy(UnitFrames.PartyDefaults)
p.raidFrames  = p.raidFrames  or DeepCopy(UnitFrames.RaidDefaults)

-- Power type colors
p.powerTypeColors = p.powerTypeColors or { useClassColor = false, colors = {} }

-- Cooldown Manager keybind defaults
p.cooldownManager_keybindFontName  = p.cooldownManager_keybindFontName  or "Fonts\\FRIZQT__.TTF"
p.cooldownManager_keybindFontFlags = p.cooldownManager_keybindFontFlags or ""
p.cooldownManager_keybindFontColor = p.cooldownManager_keybindFontColor or { 1, 1, 1, 1 }

