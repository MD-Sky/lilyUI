
--[[ 
    TestModule for PartyFrames - Test Target Bar
    This module replicates the target bar logic for testing purposes
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.TestModule = LilyUI.TestModule or {}
local TestModule = LilyUI.TestModule

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitClass = UnitClass
local UnitName = UnitName

-- Function to create the test target bar
function TestModule:CreateTestBar(unitToken, frameIndex)
    local frame = CreateFrame("Frame", "TestTargetBar", UIParent)
    frame:SetSize(250, 40) -- Size of the test target bar

    -- Create a simple health bar for the test
    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetSize(200, 20)
    healthBar:SetPoint("CENTER", frame, "CENTER", 0, 0)
    healthBar:SetStatusBarTexture("Interface\TargetingFrame\UI-StatusBar")
    healthBar:SetMinMaxValues(0, 100)
    healthBar:SetValue(50) -- Test with 50% health for now

    -- Create a name label for the test
    local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOP", frame, "BOTTOM", 0, -5)
    nameLabel:SetText("Test Target")

    -- Optional: Create a simple icon to represent the target
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", frame, "RIGHT", 5, 0)
    icon:SetTexture("Interface\Icons\spell_nature_healingtouch") -- Example: Healing Touch Icon

    -- Show the frame
    frame:Show()

    return frame
end
