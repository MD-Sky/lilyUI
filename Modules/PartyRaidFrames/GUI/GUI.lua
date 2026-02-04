--[[
    LilyUI Unit Frames - Configuration GUI System
    Builds AceConfig options tables for party and raid frames
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- ============================================================================
-- GUI BUILDER
-- ============================================================================

--[[
    Build LilyUI options for a frame type
    @param frameType string - "party" or "raid"
    @param displayName string - Display name for the options
    @param order number - Order in the options panel
    @return table - AceConfig options table
]]
function UnitFrames:BuildLilyUIOptions(frameType, displayName, order)
    local isRaid = frameType == "raid"
    
    local options = {
        type = "group",
        name = displayName,
        order = order,
        childGroups = "tab",
        args = {
            generalTab = self:BuildGeneralOptions(frameType, isRaid),
            layoutTab = self:BuildLayoutOptions(frameType, isRaid),
            healthTab = self:BuildHealthOptions(frameType, isRaid),
            powerTab = self:BuildPowerOptions(frameType, isRaid),
            textTab = self:BuildTextOptions(frameType, isRaid),
            auraTab = self:BuildAuraOptions(frameType, isRaid),
            iconTab = self:BuildIconOptions(frameType, isRaid),
            highlightTab = self:BuildHighlightOptions(frameType, isRaid),
            profileTab = self:BuildProfileOptions(frameType, isRaid),
        },
    }
    
    return options
end

-- ============================================================================
-- GENERAL OPTIONS
-- ============================================================================

function UnitFrames:BuildGeneralOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    return {
        type = "group",
        name = "General",
        order = 1,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable",
                desc = "Enable " .. (isRaid and "raid" or "party") .. " frames",
                order = 1,
                width = "full",
                get = function() return GetDB().enabled ~= false end,
                set = function(_, val)
                    GetDB().enabled = val
                    self:UpdateFrameVisibility()
                end,
            },
            testMode = {
                type = "execute",
                name = "Toggle Test Mode",
                desc = "Show test frames for configuration",
                order = 2,
                func = function()
                    self:ToggleTestMode(frameType)
                end,
            },
            toggleMovers = {
                type = "execute",
                name = "Toggle Movers",
                desc = "Show/hide frame movers for positioning",
                order = 3,
                func = function()
                    self:ToggleMovers()
                end,
            },
            hideBlizzard = {
                type = "toggle",
                name = "Hide Blizzard Frames",
                desc = "Hide the default Blizzard " .. (isRaid and "raid" or "party") .. " frames",
                order = 10,
                width = "full",
                get = function() return GetDB()[isRaid and "hideBlizzardRaid" or "hideBlizzardParty"] end,
                set = function(_, val)
                    GetDB()[isRaid and "hideBlizzardRaid" or "hideBlizzardParty"] = val
                    self:HideBlizzardFrames()
                end,
            },
        },
    }
end

-- ============================================================================
-- LAYOUT OPTIONS
-- ============================================================================

function UnitFrames:BuildLayoutOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateLayout()
        if isRaid then
            self:UpdateRaidLayout()
        else
            self:UpdatePartyLayout()
        end
    end
    
    local args = {
        sizeHeader = {
            type = "header",
            name = "Frame Size",
            order = 1,
        },
        frameWidth = {
            type = "range",
            name = "Frame Width",
            order = 2,
            min = 40, max = 300, step = 1,
            get = function() return GetDB().frameWidth or (isRaid and 80 or 120) end,
            set = function(_, val)
                GetDB().frameWidth = val
                self:OnSliderDragStart(UpdateLayout, "frameWidth", true)
            end,
        },
        frameHeight = {
            type = "range",
            name = "Frame Height",
            order = 3,
            min = 20, max = 150, step = 1,
            get = function() return GetDB().frameHeight or (isRaid and 40 or 50) end,
            set = function(_, val)
                GetDB().frameHeight = val
                self:OnSliderDragStart(UpdateLayout, "frameHeight", true)
            end,
        },
        spacingHeader = {
            type = "header",
            name = "Spacing",
            order = 10,
        },
        frameSpacing = {
            type = "range",
            name = "Frame Spacing",
            order = 11,
            min = 0, max = 20, step = 1,
            get = function() return GetDB().frameSpacing or 2 end,
            set = function(_, val)
                GetDB().frameSpacing = val
                UpdateLayout()
            end,
        },
        growthHeader = {
            type = "header",
            name = "Growth Direction",
            order = 20,
        },
        growthDirection = {
            type = "select",
            name = "Growth Direction",
            order = 21,
            values = {
                DOWN = "Down",
                UP = "Up",
                LEFT = "Left",
                RIGHT = "Right",
            },
            get = function() return GetDB().growthDirection or "DOWN" end,
            set = function(_, val)
                GetDB().growthDirection = val
                UpdateLayout()
            end,
        },
        orientation = {
            type = "select",
            name = "Orientation",
            order = 22,
            values = {
                VERTICAL = "Vertical",
                HORIZONTAL = "Horizontal",
            },
            get = function() return GetDB().orientation or "VERTICAL" end,
            set = function(_, val)
                GetDB().orientation = val
                UpdateLayout()
            end,
        },
    }
    
    -- Add raid-specific options
    if isRaid then
        args.columns = {
            type = "range",
            name = "Columns",
            order = 12,
            min = 1, max = 10, step = 1,
            get = function() return GetDB().columns or 5 end,
            set = function(_, val)
                GetDB().columns = val
                UpdateLayout()
            end,
        }
        
        args.layoutMode = {
            type = "select",
            name = "Layout Mode",
            order = 23,
            values = {
                BY_GROUP = "By Group",
                FLAT = "Flat Grid",
            },
            get = function() return GetDB().layoutMode or "BY_GROUP" end,
            set = function(_, val)
                GetDB().layoutMode = val
                UpdateLayout()
            end,
        }
    else
        args.showPlayer = {
            type = "toggle",
            name = "Show Player Frame",
            order = 5,
            get = function() return GetDB().showPlayer ~= false end,
            set = function(_, val)
                GetDB().showPlayer = val
                UpdateLayout()
            end,
        }
    end
    
    return {
        type = "group",
        name = "Layout",
        order = 2,
        args = args,
    }
end

-- ============================================================================
-- HEALTH OPTIONS
-- ============================================================================

function UnitFrames:BuildHealthOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:UpdateAllFrames()
    end
    
    return {
        type = "group",
        name = "Health Bar",
        order = 3,
        args = {
            colorHeader = {
                type = "header",
                name = "Health Bar Color",
                order = 1,
            },
            healthBarColorMode = {
                type = "select",
                name = "Color Mode",
                order = 2,
                values = {
                    CLASS = "Class Color",
                    GRADIENT = "Health Gradient",
                    REACTION = "Reaction",
                    CUSTOM = "Custom Color",
                },
                get = function() return GetDB().healthBarColorMode or "CLASS" end,
                set = function(_, val)
                    GetDB().healthBarColorMode = val
                    UpdateFrames()
                end,
            },
            healthBarCustomColor = {
                type = "color",
                name = "Custom Color",
                order = 3,
                hasAlpha = false,
                hidden = function() return GetDB().healthBarColorMode ~= "CUSTOM" end,
                get = function()
                    local c = GetDB().healthBarCustomColor or {r = 0.2, g = 0.8, b = 0.2}
                    return c.r, c.g, c.b
                end,
                set = function(_, r, g, b)
                    GetDB().healthBarCustomColor = {r = r, g = g, b = b}
                    UpdateFrames()
                end,
            },
            textureHeader = {
                type = "header",
                name = "Texture",
                order = 10,
            },
            healthBarTexture = {
                type = "select",
                name = "Health Bar Texture",
                order = 11,
                dialogControl = "LSM30_Statusbar",
                values = function() return self:GetTextureList() end,
                get = function() return GetDB().healthBarTexture or "Blizzard Raid Bar" end,
                set = function(_, val)
                    GetDB().healthBarTexture = val
                    UpdateFrames()
                end,
            },
            backgroundHeader = {
                type = "header",
                name = "Background",
                order = 20,
            },
            backgroundColor = {
                type = "color",
                name = "Background Color",
                order = 21,
                hasAlpha = true,
                get = function()
                    local c = GetDB().backgroundColor or {r = 0.1, g = 0.1, b = 0.1, a = 0.8}
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    GetDB().backgroundColor = {r = r, g = g, b = b, a = a}
                    UpdateFrames()
                end,
            },
        },
    }
end

-- ============================================================================
-- POWER OPTIONS
-- ============================================================================

function UnitFrames:BuildPowerOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:UpdateAllFrames()
    end
    
    return {
        type = "group",
        name = "Power Bar",
        order = 4,
        args = {
            powerBarEnabled = {
                type = "toggle",
                name = "Enable Power Bar",
                order = 1,
                width = "full",
                get = function() return GetDB().powerBarEnabled end,
                set = function(_, val)
                    GetDB().powerBarEnabled = val
                    UpdateFrames()
                end,
            },
            powerBarHeight = {
                type = "range",
                name = "Height",
                order = 2,
                min = 2, max = 20, step = 1,
                get = function() return GetDB().powerBarHeight or 6 end,
                set = function(_, val)
                    GetDB().powerBarHeight = val
                    UpdateFrames()
                end,
            },
            powerBarPosition = {
                type = "select",
                name = "Position",
                order = 3,
                values = {
                    BOTTOM = "Bottom",
                    TOP = "Top",
                },
                get = function() return GetDB().powerBarPosition or "BOTTOM" end,
                set = function(_, val)
                    GetDB().powerBarPosition = val
                    UpdateFrames()
                end,
            },
        },
    }
end

-- ============================================================================
-- TEXT OPTIONS
-- ============================================================================

function UnitFrames:BuildTextOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:UpdateAllFrames()
    end
    
    return {
        type = "group",
        name = "Text",
        order = 5,
        args = {
            nameHeader = {
                type = "header",
                name = "Name Text",
                order = 1,
            },
            nameTextEnabled = {
                type = "toggle",
                name = "Show Name",
                order = 2,
                get = function() return GetDB().nameTextEnabled ~= false end,
                set = function(_, val)
                    GetDB().nameTextEnabled = val
                    UpdateFrames()
                end,
            },
            nameTextSize = {
                type = "range",
                name = "Font Size",
                order = 3,
                min = 6, max = 24, step = 1,
                get = function() return GetDB().nameTextSize or 11 end,
                set = function(_, val)
                    GetDB().nameTextSize = val
                    UpdateFrames()
                end,
            },
            healthHeader = {
                type = "header",
                name = "Health Text",
                order = 10,
            },
            healthTextEnabled = {
                type = "toggle",
                name = "Show Health",
                order = 11,
                get = function() return GetDB().healthTextEnabled end,
                set = function(_, val)
                    GetDB().healthTextEnabled = val
                    UpdateFrames()
                end,
            },
            healthTextFormat = {
                type = "select",
                name = "Format",
                order = 12,
                values = {
                    PERCENT = "Percentage",
                    CURRENT = "Current",
                    CURRENT_MAX = "Current / Max",
                    DEFICIT = "Deficit",
                },
                get = function() return GetDB().healthTextFormat or "PERCENT" end,
                set = function(_, val)
                    GetDB().healthTextFormat = val
                    UpdateFrames()
                end,
            },
            healthTextSize = {
                type = "range",
                name = "Font Size",
                order = 13,
                min = 6, max = 24, step = 1,
                get = function() return GetDB().healthTextSize or 10 end,
                set = function(_, val)
                    GetDB().healthTextSize = val
                    UpdateFrames()
                end,
            },
        },
    }
end

-- ============================================================================
-- AURA OPTIONS
-- ============================================================================

function UnitFrames:BuildAuraOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:UpdateAllFrames()
    end
    
    return {
        type = "group",
        name = "Auras",
        order = 6,
        args = {
            buffHeader = {
                type = "header",
                name = "Buffs",
                order = 1,
            },
            buffEnabled = {
                type = "toggle",
                name = "Show Buffs",
                order = 2,
                get = function() return GetDB().buffEnabled end,
                set = function(_, val)
                    GetDB().buffEnabled = val
                    UpdateFrames()
                end,
            },
            buffMaxIcons = {
                type = "range",
                name = "Max Buffs",
                order = 3,
                min = 1, max = 16, step = 1,
                get = function() return GetDB().buffMaxIcons or 4 end,
                set = function(_, val)
                    GetDB().buffMaxIcons = val
                    UpdateFrames()
                end,
            },
            buffSize = {
                type = "range",
                name = "Buff Size",
                order = 4,
                min = 8, max = 40, step = 1,
                get = function() return GetDB().buffSize or 18 end,
                set = function(_, val)
                    GetDB().buffSize = val
                    UpdateFrames()
                end,
            },

            -- TEST: you should see this block directly under Buff Size
            buffTextNotice = {
                type = "description",
                name = "|cff00ff00Text Size Controls (TEST - should appear)|r",
                order = 5,
            },
            buffTextSize = {
                type = "range",
                name = "Buff Text Size (TEST)",
                order = 6,
                min = 6, max = 22, step = 1,
                get = function() return GetDB().buffTextSize or GetDB().auraStackSize or 10 end,
                set = function(_, val)
                    GetDB().buffTextSize = val
                    UpdateFrames()
                end,
            },

            debuffHeader = {
                type = "header",
                name = "Debuffs",
                order = 10,
            },
            debuffEnabled = {
                type = "toggle",
                name = "Show Debuffs",
                order = 11,
                get = function() return GetDB().debuffEnabled ~= false end,
                set = function(_, val)
                    GetDB().debuffEnabled = val
                    UpdateFrames()
                end,
            },
            debuffMaxIcons = {
                type = "range",
                name = "Max Debuffs",
                order = 12,
                min = 1, max = 16, step = 1,
                get = function() return GetDB().debuffMaxIcons or 8 end,
                set = function(_, val)
                    GetDB().debuffMaxIcons = val
                    UpdateFrames()
                end,
            },
            debuffSize = {
                type = "range",
                name = "Debuff Size",
                order = 13,
                min = 8, max = 40, step = 1,
                get = function() return GetDB().debuffSize or 18 end,
                set = function(_, val)
                    GetDB().debuffSize = val
                    UpdateFrames()
                end,
            },

            -- TEST: you should see this block directly under Debuff Size
            debuffTextNotice = {
                type = "description",
                name = "|cff00ff00Text Size Controls (TEST - should appear)|r",
                order = 14,
            },
            debuffTextSize = {
                type = "range",
                name = "Debuff Text Size (TEST)",
                order = 15,
                min = 6, max = 22, step = 1,
                get = function() return GetDB().debuffTextSize or GetDB().auraStackSize or 10 end,
                set = function(_, val)
                    GetDB().debuffTextSize = val
                    UpdateFrames()
                end,
            },

        },
    }
end

-- ============================================================================
-- ICON OPTIONS
-- ============================================================================

function UnitFrames:BuildIconOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:UpdateAllFrames()
    end
    
    return {
        type = "group",
        name = "Icons",
        order = 7,
        args = {
            roleHeader = {
                type = "header",
                name = "Role Icon",
                order = 1,
            },
            roleIconEnabled = {
                type = "toggle",
                name = "Show Role Icon",
                order = 2,
                get = function() return GetDB().roleIconEnabled ~= false end,
                set = function(_, val)
                    GetDB().roleIconEnabled = val
                    UpdateFrames()
                end,
            },
            roleIconSize = {
                type = "range",
                name = "Size",
                order = 3,
                min = 8, max = 32, step = 1,
                get = function() return GetDB().roleIconSize or 14 end,
                set = function(_, val)
                    GetDB().roleIconSize = val
                    UpdateFrames()
                end,
            },
            leaderHeader = {
                type = "header",
                name = "Leader Icon",
                order = 10,
            },
            leaderIconEnabled = {
                type = "toggle",
                name = "Show Leader Icon",
                order = 11,
                get = function() return GetDB().leaderIconEnabled ~= false end,
                set = function(_, val)
                    GetDB().leaderIconEnabled = val
                    UpdateFrames()
                end,
            },
            raidTargetHeader = {
                type = "header",
                name = "Raid Target Icon",
                order = 20,
            },
            raidTargetIconEnabled = {
                type = "toggle",
                name = "Show Raid Target",
                order = 21,
                get = function() return GetDB().raidTargetIconEnabled ~= false end,
                set = function(_, val)
                    GetDB().raidTargetIconEnabled = val
                    UpdateFrames()
                end,
            },
        },
    }
end

-- ============================================================================
-- HIGHLIGHT OPTIONS
-- ============================================================================

function UnitFrames:BuildHighlightOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:UpdateAllFrames()
    end
    
    return {
        type = "group",
        name = "Highlights",
        order = 8,
        args = {
            selectionHeader = {
                type = "header",
                name = "Selection Highlight",
                order = 1,
            },
            selectionHighlightEnabled = {
                type = "toggle",
                name = "Enable Selection Highlight",
                order = 2,
                get = function() return GetDB().selectionHighlightEnabled ~= false end,
                set = function(_, val)
                    GetDB().selectionHighlightEnabled = val
                end,
            },
            mouseoverHeader = {
                type = "header",
                name = "Mouseover Highlight",
                order = 10,
            },
            mouseoverHighlightEnabled = {
                type = "toggle",
                name = "Enable Mouseover Highlight",
                order = 11,
                get = function() return GetDB().mouseoverHighlightEnabled ~= false end,
                set = function(_, val)
                    GetDB().mouseoverHighlightEnabled = val
                end,
            },
            aggroHeader = {
                type = "header",
                name = "Aggro Highlight",
                order = 20,
            },
            aggroHighlightEnabled = {
                type = "toggle",
                name = "Enable Aggro Highlight",
                order = 21,
                get = function() return GetDB().aggroHighlightEnabled end,
                set = function(_, val)
                    GetDB().aggroHighlightEnabled = val
                end,
            },
            rangeHeader = {
                type = "header",
                name = "Range Check",
                order = 30,
            },
            rangeCheckEnabled = {
                type = "toggle",
                name = "Enable Range Check",
                order = 31,
                get = function() return GetDB().rangeCheckEnabled ~= false end,
                set = function(_, val)
                    GetDB().rangeCheckEnabled = val
                end,
            },
            outOfRangeAlpha = {
                type = "range",
                name = "Out of Range Alpha",
                order = 32,
                min = 0.1, max = 1, step = 0.05,
                get = function() return GetDB().outOfRangeAlpha or 0.4 end,
                set = function(_, val)
                    GetDB().outOfRangeAlpha = val
                end,
            },
        },
    }
end

-- ============================================================================
-- PROFILE OPTIONS
-- ============================================================================

function UnitFrames:BuildProfileOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    return {
        type = "group",
        name = "Profiles",
        order = 9,
        args = {
            profileHeader = {
                type = "header",
                name = "Profile Management",
                order = 1,
            },
            resetProfile = {
                type = "execute",
                name = "Reset to Defaults",
                desc = "Reset all settings to default values",
                order = 2,
                confirm = true,
                confirmText = "Are you sure you want to reset all " .. (isRaid and "raid" or "party") .. " frame settings?",
                func = function()
                    self:ResetProfile(frameType)
                    self:UpdateAllFrames()
                end,
            },
            copyHeader = {
                type = "header",
                name = "Copy Settings",
                order = 10,
            },
            copyToOther = {
                type = "execute",
                name = "Copy to " .. (isRaid and "Party" or "Raid"),
                desc = "Copy these settings to " .. (isRaid and "party" or "raid") .. " frames",
                order = 11,
                confirm = true,
                confirmText = "This will overwrite " .. (isRaid and "party" or "raid") .. " frame settings. Continue?",
                func = function()
                    self:CopyProfile(frameType, isRaid and "party" or "raid")
                    self:UpdateAllFrames()
                end,
            },
            exportHeader = {
                type = "header",
                name = "Import/Export",
                order = 20,
            },
            exportProfile = {
                type = "execute",
                name = "Export Profile",
                desc = "Export settings to a string for sharing",
                order = 21,
                func = function()
                    local exportString = self:ExportProfile(nil, {frameType}, frameType .. "_export")
                    -- Would open a dialog with the export string
                    print("Export string generated. Use /nephui export to view.")
                end,
            },
        },
    }
end
