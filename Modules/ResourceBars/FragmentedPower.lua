local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Get ResourceBars module
local ResourceBars = LilyUI.ResourceBars
if not ResourceBars then
    error("lilyUI: ResourceBars module not initialized! Load ResourceDetection.lua first.")
end

-- Get tables from ResourceDetection
local fragmentedPowerTypes = ResourceBars.fragmentedPowerTypes
local GetResourceColor = ResourceBars.GetResourceColor
local GetSecondaryResource = ResourceBars.GetSecondaryResource

-- RUNE UPDATE TICKER

local runeUpdateTicker = nil

local function StartRuneUpdateTicker()
    if runeUpdateTicker then return end
    
    runeUpdateTicker = C_Timer.NewTicker(0.1, function()
        local resource = GetSecondaryResource()
        if resource == Enum.PowerType.Runes then
            local bar = LilyUI.secondaryPowerBar
            if bar and bar:IsShown() and fragmentedPowerTypes[resource] then
                ResourceBars:UpdateFragmentedPowerDisplay(bar, resource)
            end
        else
            -- Stop ticker if not on a DK anymore
            if runeUpdateTicker then
                runeUpdateTicker:Cancel()
                runeUpdateTicker = nil
            end
        end
    end)
end

local function StopRuneUpdateTicker()
    if runeUpdateTicker then
        runeUpdateTicker:Cancel()
        runeUpdateTicker = nil
    end
end

-- SOUL FRAGMENTS UPDATE TICKER

local soulUpdateTicker = nil

local function StartSoulUpdateTicker()
    if soulUpdateTicker then return end
    
    soulUpdateTicker = C_Timer.NewTicker(0.1, function()
        local resource = GetSecondaryResource()
        if resource == "SOUL" then
            local bar = LilyUI.secondaryPowerBar
            if bar and bar:IsShown() then
                ResourceBars:UpdateSecondaryPowerBar()
            end
        else
            -- Stop ticker if not on a DH with soul resource anymore
            if soulUpdateTicker then
                soulUpdateTicker:Cancel()
                soulUpdateTicker = nil
            end
        end
    end)
end

local function StopSoulUpdateTicker()
    if soulUpdateTicker then
        soulUpdateTicker:Cancel()
        soulUpdateTicker = nil
    end
end

-- Export ticker functions
ResourceBars.StartRuneUpdateTicker = StartRuneUpdateTicker
ResourceBars.StopRuneUpdateTicker = StopRuneUpdateTicker
ResourceBars.StartSoulUpdateTicker = StartSoulUpdateTicker
ResourceBars.StopSoulUpdateTicker = StopSoulUpdateTicker

