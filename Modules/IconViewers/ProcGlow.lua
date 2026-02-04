local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

LilyUI.ProcGlow = LilyUI.ProcGlow or {}
local ProcGlow = LilyUI.ProcGlow

-- Get LibCustomGlow for glow effects
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- Track which icons currently have active glows
local activeGlowingIcons = {}  -- [icon] = true

-- Glow key for LibCustomGlow
local GLOW_KEY = "_LilyUICustomGlow"

-- LibCustomGlow glow types
ProcGlow.LibCustomGlowTypes = {
    "Pixel Glow",
    "Autocast Shine",
    "Action Button Glow",
    "Proc Glow",
}

-- Check if a button belongs to one of our cooldown viewer frames
local function IsCooldownViewerIcon(button)
    if not button then return false end
    local currentParent = button
    for _ = 1, 6 do
        currentParent = currentParent:GetParent()
        if not currentParent then return false end
        local parentName = currentParent:GetName()
        if parentName then
            local viewers = LilyUI.viewers or {
                "EssentialCooldownViewer",
                "UtilityCooldownViewer",
                "BuffIconCooldownViewer",
            }
            for _, viewerName in ipairs(viewers) do
                if parentName == viewerName then
                    return true
                end
            end
        end
    end
    return false
end

-- Get settings for proc glow (viewers only)
local function GetProcGlowSettings()
    local settings = LilyUI.db.profile.viewers.general.procGlow
    if not settings or not settings.enabled then return nil end
    return settings
end

-- Hide Blizzard's glow effects (like BetterCooldownManager)
local function HideBlizzardGlow(iconFrame)
    if iconFrame.SpellActivationAlert then
        iconFrame.SpellActivationAlert:Hide()
        if iconFrame.SpellActivationAlert.ProcLoopFlipbook then
            iconFrame.SpellActivationAlert.ProcLoopFlipbook:Hide()
        end
        if iconFrame.SpellActivationAlert.ProcStartFlipbook then
            iconFrame.SpellActivationAlert.ProcStartFlipbook:Hide()
        end
    end

    if iconFrame.overlay then iconFrame.overlay:Hide() end
    if iconFrame.Overlay then iconFrame.Overlay:Hide() end
    if iconFrame.Glow then iconFrame.Glow:Hide() end
end

-- Start glow on an icon (like BetterCooldownManager's StartGlow)
local function StartGlow(iconFrame)
    if iconFrame._LilyUICustomGlowActive then return end

    local glowSettings = GetProcGlowSettings()
    if not glowSettings then return end

    local glowType = glowSettings.glowType or "Pixel Glow"
    local color = glowSettings.loopColor or {0.95, 0.95, 0.32, 1}
    if not color[4] then color[4] = 1 end

    -- Stop any existing glows first
    if LCG then
        LCG.PixelGlow_Stop(iconFrame, GLOW_KEY)
        LCG.AutoCastGlow_Stop(iconFrame, GLOW_KEY)
        LCG.ProcGlow_Stop(iconFrame, GLOW_KEY)
        LCG.ButtonGlow_Stop(iconFrame)
    end

    if glowType == "Pixel Glow" then
        local lines = glowSettings.lcgLines or 14
        local frequency = glowSettings.lcgFrequency or 0.25
        local thickness = glowSettings.lcgThickness or 2
        local xOffset = glowSettings.xOffset or 0
        local yOffset = glowSettings.yOffset or 0
        
        if LCG then
            LCG.PixelGlow_Start(
                iconFrame,
                color,
                lines,
                frequency,
                nil,
                thickness,
                xOffset,
                yOffset,
                true,
                GLOW_KEY
            )
        end
    elseif glowType == "Autocast Shine" then
        local particles = glowSettings.lcgLines or 14
        local frequency = glowSettings.lcgFrequency or 0.25
        local scale = glowSettings.lcgScale or 1
        local xOffset = glowSettings.xOffset or 0
        local yOffset = glowSettings.yOffset or 0
        
        if LCG then
            LCG.AutoCastGlow_Start(
                iconFrame,
                color,
                particles,
                frequency,
                scale,
                xOffset,
                yOffset,
                GLOW_KEY
            )
        end
    elseif glowType == "Action Button Glow" then
        local frequency = glowSettings.lcgFrequency or 0.25
        
        if LCG then
            LCG.ButtonGlow_Start(iconFrame, color, frequency)
        end
    elseif glowType == "Proc Glow" then
        if LCG then
            LCG.ProcGlow_Start(iconFrame, {
                color = color,
                startAnim = false,
                xOffset = glowSettings.xOffset or 0,
                yOffset = glowSettings.yOffset or 0,
                key = GLOW_KEY
            })
        end
    end

    iconFrame._LilyUICustomGlowActive = true
    activeGlowingIcons[iconFrame] = true
end

-- Stop glow on an icon (like BetterCooldownManager's StopGlow)
local function StopGlow(iconFrame)
    if not iconFrame._LilyUICustomGlowActive then return end
    
    if LCG then
        LCG.PixelGlow_Stop(iconFrame, GLOW_KEY)
        LCG.AutoCastGlow_Stop(iconFrame, GLOW_KEY)
        LCG.ProcGlow_Stop(iconFrame, GLOW_KEY)
        LCG.ButtonGlow_Stop(iconFrame)
    end
    
    iconFrame._LilyUICustomGlowActive = nil
    activeGlowingIcons[iconFrame] = nil
end

-- Setup glow hooks (like BetterCooldownManager's SetupGlowHooks)
local function SetupGlowHooks()
    if ActionButtonSpellAlertManager then
        if ActionButtonSpellAlertManager.ShowAlert then
            hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
                if not IsCooldownViewerIcon(button) then return end
                HideBlizzardGlow(button)
                StartGlow(button)
            end)
        end

        if ActionButtonSpellAlertManager.HideAlert then
            hooksecurefunc(ActionButtonSpellAlertManager, "HideAlert", function(_, button)
                if not IsCooldownViewerIcon(button) then return end
                StopGlow(button)
            end)
        end
    end
end

-- Initialize the module
function ProcGlow:Initialize()
    local settings = GetProcGlowSettings()
    if not settings or not settings.enabled then return end
    
    -- Set up hooks (only ActionButtonSpellAlertManager like BetterCooldownManager)
    C_Timer.After(0.5, function()
        SetupGlowHooks()
    end)
end

-- Refresh all proc glows (viewers only)
function ProcGlow:RefreshAll()
    local settings = GetProcGlowSettings()
    if not settings or not settings.enabled then return end
    
    -- Store which icons had glows before refresh
    local iconsWithGlows = {}
    for icon, _ in pairs(activeGlowingIcons) do
        if icon then
            iconsWithGlows[icon] = true
        end
    end
    
    -- Stop all existing custom glows
    for icon, _ in pairs(activeGlowingIcons) do
        if icon then
            StopGlow(icon)
        end
    end
    wipe(activeGlowingIcons)
    
    -- Re-apply glows to icons that had them before (if settings allow)
    for icon, _ in pairs(iconsWithGlows) do
        if icon and icon:IsShown() then
            StartGlow(icon)
        end
    end
end

-- Public API for starting/stopping glows (for compatibility)
function ProcGlow:StartGlow(icon)
    if not icon or not IsCooldownViewerIcon(icon) then return end
    StartGlow(icon)
end

function ProcGlow:StopGlow(icon)
    if not icon or not IsCooldownViewerIcon(icon) then return end
    StopGlow(icon)
end
