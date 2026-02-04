local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Get UnitFrames module
local UF = LilyUI.UnitFrames
if not UF then
    error("lilyUI: UnitFrames module not initialized! Load UnitFrames.lua first.")
end

-- Clique Integration for Unit Frames
-- This module registers LilyUI unit frames with Clique for click-casting support

local isLilyUI = C_AddOns.IsAddOnLoaded("nUI") or C_AddOns.IsAddOnLoaded("LilyUI")

if not isLilyUI then
    return -- Exit if LilyUI isn't active
end

local function TryRegister()
    -- Check if Clique is active
    if not ClickCastFrames then 
        return false -- Clique not loaded yet, keep trying
    end
    
    local playerFrame = _G["LilyUI_Player"]
    if playerFrame then
        local frames = {
            playerFrame, 
            _G["LilyUI_Target"], 
            _G["LilyUI_Focus"], 
            _G["LilyUI_Pet"]
        }
        
        for _, frame in ipairs(frames) do
            if frame then
                -- Add to Clique if not already there
                ClickCastFrames[frame] = true
                
                -- Modern WoW attribute for click-cast pass-through
                if not InCombatLockdown() then
                    frame:SetAttribute("clickcast_onenter", [=[
                        local header = self:GetParent()
                        if header and header:GetAttribute("clickcast_button") then
                            header:RunAttribute("clickcast_onenter")
                        end
                    ]=])
                    
                    frame:EnableMouse(true)
                    frame:RegisterForClicks("AnyUp")
                end
            end
        end
        print("|cFF00FF00Bridge:|r LilyUI & Clique linked successfully.")
        return true -- Found and fixed the frames!
    end
    return false -- Frames not spawned yet, try again.
end

-- Runs every 2 seconds, up to 10 times. Stops once TryRegister returns true.
-- This handles cases where Clique loads after LilyUI or frames are created later
C_Timer.NewTicker(2, function(self)
    if TryRegister() then
        self:Cancel()
    end
end, 10)

