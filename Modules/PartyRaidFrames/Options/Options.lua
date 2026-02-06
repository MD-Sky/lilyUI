--[[
    LilyUI Unit Frames - Options Integration
    Provides options panel integration for the addon's configuration system
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- ============================================================================
-- OPTIONS CREATION FUNCTIONS
-- ============================================================================

--[[
    Create party frame options table for LilyUI config
    @return table - AceConfig options table
]]
function ns.CreatePartyFrameOptions()
    -- Check if UnitFrames is initialized
    if UnitFrames and UnitFrames.BuildLilyUIOptions then
        return UnitFrames:BuildLilyUIOptions("party", "Party Frames", 45)
    end
    
    -- Fallback if module not ready
    return {
        type = "group",
        name = "Party Frames",
        order = 45,
        args = {
            fallback = {
                type = "description",
                name = "Party frame options are loading. Please reload your UI if this persists.",
                order = 1,
            },
        },
    }
end

--[[
    Create raid frame options table for LilyUI config
    @return table - AceConfig options table
]]
function ns.CreateRaidFrameOptions()
    -- Check if UnitFrames is initialized
    if UnitFrames and UnitFrames.BuildLilyUIOptions then
        return UnitFrames:BuildLilyUIOptions("raid", "Raid Frames", 46)
    end
    
    -- Fallback if module not ready
    return {
        type = "group",
        name = "Raid Frames",
        order = 46,
        args = {
            fallback = {
                type = "description",
                name = "Raid frame options are loading. Please reload your UI if this persists.",
                order = 1,
            },
        },
    }
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

-- Create slash commands for quick access
SLASH_NEPHFRAMES1 = "/nephframes"
SLASH_NEPHFRAMES2 = "/nf"
SlashCmdList["NEPHFRAMES"] = function(msg)
    msg = msg:lower():trim()
    
    if msg == "party" then
        -- Open party frame options
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("LilyUI|Party Frames")
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory("LilyUI")
        end
    elseif msg == "raid" then
        -- Open raid frame options
        if Settings and Settings.OpenToCategory then
            Settings.OpenToCategory("LilyUI|Raid Frames")
        elseif InterfaceOptionsFrame_OpenToCategory then
            InterfaceOptionsFrame_OpenToCategory("LilyUI")
        end
    elseif msg == "test" then
        UnitFrames:ToggleTestMode("party")
    elseif msg == "test raid" or msg == "testraid" then
        UnitFrames:ToggleTestMode("raid")
    elseif msg == "move" or msg == "movers" then
        UnitFrames:ToggleMovers()
    elseif msg == "reset party" then
        UnitFrames:ResetProfile("party")
        print("|cFF00FF00LilyUI:|r Party frame settings reset to defaults.")
    elseif msg == "reset raid" then
        UnitFrames:ResetProfile("raid")
        print("|cFF00FF00LilyUI:|r Raid frame settings reset to defaults.")
    elseif msg == "help" or msg == "" then
        print("|cFF00FF00LilyUI Party/Raid Frames Commands:|r")
        print("  /nephframes party - Open party frame options")
        print("  /nephframes raid - Open raid frame options")
        print("  /nephframes test - Toggle test mode")
        print("  /nephframes move - Toggle movers")
        print("  /nephframes reset party - Reset party settings")
        print("  /nephframes reset raid - Reset raid settings")
    else
        print("|cFF00FF00LilyUI:|r Unknown command. Use '/nephframes help' for available commands.")
            end
        end
        
-- ============================================================================
-- OPTION REGISTRATION
-- ============================================================================

--[[
    Register options with LilyUI's config system
    Called during addon initialization
]]
function UnitFrames:RegisterOptions()
    -- This would integrate with LilyUI's main config system
    -- The exact implementation depends on how LilyUI handles option registration
    
    -- For now, we expose the creation functions for the main addon to call
    if ns.RegisterOptionsCallback then
        ns.RegisterOptionsCallback("PartyFrames", ns.CreatePartyFrameOptions)
        ns.RegisterOptionsCallback("RaidFrames", ns.CreateRaidFrameOptions)
            end
        end

-- ============================================================================
-- PROFILE CALLBACKS
-- ============================================================================

--[[
    Called when profile changes
    @param newProfile string - New profile name
]]
function UnitFrames:OnProfileChanged(newProfile)
    -- Reinitialize with new profile settings
    self:SyncProfile()
    
    -- Update all frames
    self:UpdateAllFrames()
    
    -- Update layouts
    self:UpdatePartyLayout()
    self:UpdateRaidLayout()
end

--[[
    Called when profile is copied
    @param sourceProfile string - Source profile name
]]
function UnitFrames:OnProfileCopied(sourceProfile)
    self:OnProfileChanged(sourceProfile)
end

--[[
    Called when profile is reset
]]
function UnitFrames:OnProfileReset()
    -- Reset to defaults
    self:SyncProfile()
    self:UpdateAllFrames()
    self:UpdatePartyLayout()
    self:UpdateRaidLayout()
end

-- ============================================================================
-- MINIMAP BUTTON
-- ============================================================================

local minimapButton = nil

--[[
    Create minimap button for quick access
]]
function UnitFrames:CreateMinimapButton()
    if minimapButton then return end
    
    -- Check for LibDBIcon
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    
    if not LDB or not LDBIcon then return end
    
    local dataObject = LDB:NewDataObject("LilyUIFrames", {
        type = "launcher",
        icon = "Interface\\AddOns\\lilyUI\\Media\\lilyui",
        OnClick = function(self, button)
            if button == "LeftButton" then
                UnitFrames:ToggleMovers()
            elseif button == "RightButton" then
                -- Open options
                if Settings and Settings.OpenToCategory then
                    Settings.OpenToCategory("LilyUI")
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("LilyUI Frames")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cFFFFFFFFLeft-click:|r Toggle movers")
            tooltip:AddLine("|cFFFFFFFFRight-click:|r Open options")
        end,
    })
    
    -- Register with LibDBIcon
    local minimapDB = {
        hide = false,
        minimapPos = 220,
        lock = false,
    }
    
    LDBIcon:Register("LilyUIFrames", dataObject, minimapDB)
    minimapButton = true
end
