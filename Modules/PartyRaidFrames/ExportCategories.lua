--[[
    LilyUI Unit Frames - Export Categories
    Defines setting categories for selective import/export functionality
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Ensure PartyFrames module exists
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- ============================================================================
-- CATEGORY DEFINITIONS
-- Maps category names to the settings they contain
-- ============================================================================

UnitFrames.ExportCategories = {
    -- Position and anchor settings
    position = {
        "anchorPoint",
        "anchorX",
        "anchorY",
        "raidAnchorX",
        "raidAnchorY",
    },
    
    -- Frame size and layout settings
    layout = {
        "frameWidth",
        "frameHeight",
        "frameSpacing",
        "growDirection",
        "growthAnchor",
        "raidUseGroups",
        "raidGroupSpacing",
        "raidRowColSpacing",
        "raidGroupsPerRow",
        "raidGroupAnchor",
        "raidPlayerAnchor",
        "raidReverseGroupOrder",
        "raidPlayersPerRow",
        "raidFlatHorizontalSpacing",
        "raidFlatVerticalSpacing",
        "raidFlatPlayerAnchor",
        "raidFlatReverseFillOrder",
    },
    
    -- Health, power, and absorb bar settings
    bars = {
        "healthBarOrientation",
        "healthBarTexture",
        "healthBarInset",
        "healthColorMode",
        "healthCustomColor",
        "healthGradientStart",
        "healthGradientEnd",
        "healthReactionColors",
        "missingHealthEnabled",
        "missingHealthColor",
        "missingHealthColorMode",
        "powerBarEnabled",
        "powerBarHeight",
        "powerBarPosition",
        "powerBarTexture",
        "powerBarInset",
        "powerBarColorMode",
        "powerBarCustomColor",
        "powerBarBackground",
        "absorbBarEnabled",
        "absorbBarColor",
        "absorbBarTexture",
        "absorbBarOverlay",
        "healAbsorbEnabled",
        "healAbsorbColor",
        "healPredictionEnabled",
        "healPredictionColor",
        "healPredictionMaxOverflow",
    },
    
    -- Background and border settings
    background = {
        "backgroundColor",
        "backgroundColorMode",
        "backgroundClassAlpha",
        "backgroundTexture",
        "borderEnabled",
        "borderColor",
        "borderSize",
        "borderTexture",
    },
    
    -- Buff and debuff display settings
    auras = {
        "showBuffs",
        "buffMax",
        "buffSize",
        "buffScale",
        "buffAnchor",
        "buffGrowth",
        "buffOffsetX",
        "buffOffsetY",
        "buffPaddingX",
        "buffPaddingY",
        "buffWrap",
        "buffBorderEnabled",
        "buffBorderThickness",
        "buffFilterMode",
        "buffFilterPlayer",
        "buffFilterRaid",
        "buffFilterCancelable",
        "showDebuffs",
        "debuffMax",
        "debuffSize",
        "debuffScale",
        "debuffAnchor",
        "debuffGrowth",
        "debuffOffsetX",
        "debuffOffsetY",
        "debuffPaddingX",
        "debuffPaddingY",
        "debuffWrap",
        "debuffBorderEnabled",
        "debuffBorderThickness",
        "debuffBorderColorByType",
        "debuffFilterMode",
        "debuffShowAll",
        "debuffBorderColorNone",
        "debuffBorderColorMagic",
        "debuffBorderColorCurse",
        "debuffBorderColorDisease",
        "debuffBorderColorPoison",
        "debuffBorderColorBleed",
        "auraDurationEnabled",
        "auraDurationFont",
        "auraDurationSize",
        "auraDurationOutline",
        "auraDurationPosition",
        "auraDurationOffsetY",
        "auraStackEnabled",
        "auraStackFont",
        "auraStackSize",
        "auraStackOutline",
        "auraStackPosition",
        "auraStackMinimum",
        "auraExpiringEnabled",
        "auraExpiringThreshold",
        "auraExpiringTintColor",
        "auraExpiringBorderPulse",
        "durationColorEnabled",
        "durationColorHigh",
        "durationColorMid",
        "durationColorLow",
        "durationHighThreshold",
        "durationLowThreshold",
        "combatFilterEnabled",
        "combatFilterMode",
        "combatFilterAppliesTo",
        "combatBuffSpellList",
        "combatDebuffSpellList",
        "combatDisplayMode",
        "combatAuraDebugEnabled",
        "combatAuraDebugSpellId",
    },
    
    -- Text display settings
    text = {
        "nameTextEnabled",
        "nameTextFont",
        "nameTextSize",
        "nameTextOutline",
        "nameTextColor",
        "nameTextColorMode",
        "nameTextAnchor",
        "nameTextOffsetX",
        "nameTextOffsetY",
        "nameTextMaxLength",
        "nameTextTruncate",
        "healthTextEnabled",
        "healthTextFont",
        "healthTextSize",
        "healthTextOutline",
        "healthTextColor",
        "healthTextFormat",
        "healthTextAnchor",
        "healthTextOffsetX",
        "healthTextOffsetY",
        "healthTextHideAtFull",
        "statusTextEnabled",
        "statusTextFont",
        "statusTextSize",
        "statusTextOutline",
        "statusTextAnchor",
        "statusTextOffsetX",
        "statusTextOffsetY",
    },
    
    -- Icon display settings
    icons = {
        "roleIconEnabled",
        "roleIconSize",
        "roleIconAnchor",
        "roleIconOffsetX",
        "roleIconOffsetY",
        "roleIconAlpha",
        "leaderIconEnabled",
        "leaderIconSize",
        "leaderIconAnchor",
        "leaderIconOffsetX",
        "leaderIconOffsetY",
        "raidTargetIconEnabled",
        "raidTargetIconSize",
        "raidTargetIconAnchor",
        "raidTargetIconOffsetX",
        "raidTargetIconOffsetY",
        "readyCheckIconEnabled",
        "readyCheckIconSize",
        "readyCheckIconAnchor",
        "readyCheckIconOffsetX",
        "readyCheckIconOffsetY",
        "centerStatusIconEnabled",
        "centerStatusIconSize",
        "centerStatusIconAnchor",
        "centerStatusIconOffsetX",
        "centerStatusIconOffsetY",
        "missingBuffEnabled",
        "missingBuffSize",
        "missingBuffAnchor",
        "missingBuffOffsetX",
        "missingBuffOffsetY",
        "missingBuffBorderColor",
        "missingBuffHideFromBar",
        "defensiveIconEnabled",
        "defensiveIconSize",
        "defensiveIconAnchor",
        "defensiveIconOffsetX",
        "defensiveIconOffsetY",
        "defensiveIconBorderColor",
    },
    
    -- Highlight and overlay settings
    highlights = {
        "selectionHighlightEnabled",
        "selectionHighlightTexture",
        "selectionHighlightAlpha",
        "mouseoverHighlightEnabled",
        "mouseoverHighlightTexture",
        "mouseoverHighlightAlpha",
        "aggroHighlightMode",
        "aggroHighlightThickness",
        "aggroHighlightInset",
        "aggroHighlightAlpha",
        "aggroOnlyTanking",
    },
    
    -- Dispel overlay settings
    dispel = {
        "dispelOverlayEnabled",
        "dispelShowGradient",
        "dispelGradientAlpha",
        "dispelGradientIntensity",
        "dispelGradientDarkenEnabled",
        "dispelGradientDarkenAlpha",
        "dispelShowIcon",
        "dispelIconSize",
        "dispelIconAlpha",
        "dispelIconPosition",
        "dispelIconOffsetX",
        "dispelIconOffsetY",
        "dispelBorderSize",
        "dispelBorderInset",
        "dispelBorderAlpha",
        "dispelMagicColor",
        "dispelCurseColor",
        "dispelDiseaseColor",
        "dispelPoisonColor",
        "dispelBleedColor",
    },
    
    -- Range and fading settings
    range = {
        "oorEnabled",
        "rangeFadeAlpha",
        "oorHealthBarAlpha",
        "oorBackgroundAlpha",
        "oorNameTextAlpha",
        "oorHealthTextAlpha",
        "oorAurasAlpha",
        "oorIconsAlpha",
        "oorDispelOverlayAlpha",
        "oorPowerBarAlpha",
        "oorMissingBuffAlpha",
        "oorDefensiveIconAlpha",
        "oorTargetedSpellAlpha",
        "fadeDeadFrames",
        "fadeDeadAlpha",
        "fadeDeadBackground",
        "fadeDeadUseCustomColor",
        "fadeDeadBackgroundColor",
    },
    
    -- Other miscellaneous settings
    other = {
        "enabled",
        "tooltipEnabled",
        "tooltipInCombat",
        "tooltipPosition",
        "privateAurasEnabled",
        "privateAurasSize",
        "privateAurasAnchor",
        "privateAurasOffsetX",
        "privateAurasOffsetY",
        "sortEnabled",
        "sortPrimary",
        "sortSecondary",
        "sortReverseOrder",
        "sortPlayerFirst",
        "soloMode",
        "hidePlayerFrame",
        "showPetFrames",
        "petFrameWidth",
        "petFrameHeight",
        "petFrameAnchor",
        "petFrameOffsetX",
        "petFrameOffsetY",
        "restedIndicatorEnabled",
        "targetedSpellsEnabled",
        "targetedSpellsMax",
        "targetedSpellsSize",
        "targetedSpellsAnchor",
        "targetedSpellsOffsetX",
        "targetedSpellsOffsetY",
        "hideBlizzardPartyFrames",
        "hideBlizzardRaidFrames",
        "showBlizzardSideMenu",
        "groupLabelEnabled",
        "groupLabelFont",
        "groupLabelFontSize",
        "groupLabelOutline",
        "groupLabelColor",
        "groupLabelFormat",
        "groupLabelAnchor",
        "groupLabelRelativeAnchor",
        "groupLabelOffsetX",
        "groupLabelOffsetY",
        "groupLabelShadow",
    },
}

-- ============================================================================
-- REVERSE LOOKUP TABLE
-- Maps setting keys back to their categories
-- ============================================================================

local reverseLookup = nil

local function BuildReverseLookup()
    if reverseLookup then return reverseLookup end
    
    reverseLookup = {}
    for category, settings in pairs(UnitFrames.ExportCategories) do
        for _, settingKey in ipairs(settings) do
            reverseLookup[settingKey] = category
        end
    end
    
    return reverseLookup
end

--[[
    Gets the category a setting belongs to
    @param settingKey string - The setting key
    @return string|nil - Category name or nil if not found
]]
function UnitFrames:GetSettingCategory(settingKey)
    local lookup = BuildReverseLookup()
    return lookup[settingKey]
end

-- ============================================================================
-- CATEGORY EXTRACTION AND MERGING
-- ============================================================================

--[[
    Extracts settings for specified categories from a profile
    @param profile table - Source profile data
    @param categories table - List of category names to extract
    @param frameType string - "party" or "raid"
    @return table - Extracted settings
]]
function UnitFrames:ExtractCategorySettings(profile, categories, frameType)
    if not profile or not categories then return {} end
    
    local extracted = {}
    
    for _, category in ipairs(categories) do
        local settingKeys = self.ExportCategories[category]
        if settingKeys then
            for _, key in ipairs(settingKeys) do
                if profile[key] ~= nil then
                    if type(profile[key]) == "table" then
                        extracted[key] = self:DeepCopy(profile[key])
                    else
                        extracted[key] = profile[key]
                    end
                end
            end
        end
    end
    
    return extracted
end

--[[
    Merges imported settings into a profile based on categories
    @param target table - Target profile to merge into
    @param source table - Source settings to merge from
    @param categories table - Categories that were exported (optional)
]]
function UnitFrames:MergeCategorySettings(target, source, categories)
    if not target or not source then return end
    
    -- If categories are specified, only merge those
    if categories then
        for _, category in ipairs(categories) do
            local settingKeys = self.ExportCategories[category]
            if settingKeys then
                for _, key in ipairs(settingKeys) do
                    if source[key] ~= nil then
                        if type(source[key]) == "table" then
                            target[key] = self:DeepCopy(source[key])
                        else
                            target[key] = source[key]
                        end
                    end
                end
            end
        end
    else
        -- No categories specified, merge everything
        for key, value in pairs(source) do
            if type(value) == "table" then
                target[key] = self:DeepCopy(value)
            else
                target[key] = value
            end
        end
    end
end

-- ============================================================================
-- CATEGORY DISPLAY NAMES
-- User-friendly names for UI display
-- ============================================================================

UnitFrames.CategoryDisplayNames = {
    position = "Position",
    layout = "Layout & Size",
    bars = "Health & Power Bars",
    background = "Background & Border",
    auras = "Buffs & Debuffs",
    text = "Text Display",
    icons = "Status Icons",
    highlights = "Highlights",
    dispel = "Dispel Overlay",
    range = "Range & Fading",
    other = "Other Settings",
}

--[[
    Gets display name for a category
    @param category string - Category key
    @return string - Display name
]]
function UnitFrames:GetCategoryDisplayName(category)
    return self.CategoryDisplayNames[category] or category
end

--[[
    Gets list of all category keys
    @return table - List of category keys
]]
function UnitFrames:GetCategoryList()
    local list = {}
    for category in pairs(self.ExportCategories) do
        table.insert(list, category)
    end
    table.sort(list)
    return list
end
