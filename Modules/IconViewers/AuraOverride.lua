local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
local SecretSafe = ns.SecretSafe or {}

LilyUI.AuraOverride = LilyUI.AuraOverride or {}
local AuraOverride = LilyUI.AuraOverride

-- Get settings for a viewer
local function GetViewerSettings(viewerName)
    if not viewerName then return nil end
    local settings = LilyUI.db.profile.viewers[viewerName]
    if not settings then return nil end
    return settings.ignoreAuraOverride or false
end

-- Check if an icon frame has an active aura
local function HasActiveAura(iconFrame)
    if not iconFrame then return false end
    local auraID = iconFrame.auraInstanceID
    return auraID and type(auraID) == "number" and auraID > 0
end

-- Get spell ID from icon frame
local function GetSpellID(iconFrame)
    if not iconFrame then return nil end
    if iconFrame.cooldownInfo then
        return iconFrame.cooldownInfo.overrideSpellID or iconFrame.cooldownInfo.spellID
    end
    return nil
end

local function GetCooldownDurationObject(spellID)
    if type(C_Spell) == "table" and type(C_Spell.GetSpellCooldownDuration) == "function" then
        local ok, obj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
        if ok and obj then
            return obj
        end
    end
    return nil
end

local function GetChargeDurationObject(spellID)
    if type(C_Spell) == "table" and type(C_Spell.GetSpellChargeDuration) == "function" then
        local ok, obj = pcall(C_Spell.GetSpellChargeDuration, spellID)
        if ok and obj then
            return obj
        end
    end
    return nil
end

local function GetNumericCooldownFallback(spellID)
    if type(C_Spell) == "table" and type(C_Spell.GetSpellCooldown) == "function" then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if not ok or not info then
            return nil, nil, false
        end
        local startTime = type(SecretSafe.NumberOrNil) == "function" and SecretSafe.NumberOrNil(info.startTime) or nil
        local duration = type(SecretSafe.NumberOrNil) == "function" and SecretSafe.NumberOrNil(info.duration) or nil
        local isOnGCD = info.isOnGCD == true
        return startTime, duration, isOnGCD
    end
    return nil, nil, false
end

local function ApplySpellCooldownToFrame(cooldownFrame, spellID)
    if not cooldownFrame or not spellID then
        return false, nil, false
    end

    local durObj = GetCooldownDurationObject(spellID)
    if durObj and cooldownFrame.SetCooldownFromDurationObject then
        local ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, durObj, true)
        if ok then
            return true, "cooldown_object", false
        end
    end

    local chargeObj = GetChargeDurationObject(spellID)
    if chargeObj and cooldownFrame.SetCooldownFromDurationObject then
        local ok = pcall(cooldownFrame.SetCooldownFromDurationObject, cooldownFrame, chargeObj, true)
        if ok then
            return true, "charge_object", false
        end
    end

    local startTime, duration, isOnGCD = GetNumericCooldownFallback(spellID)
    if type(startTime) == "number" and type(duration) == "number" and duration > 0 and cooldownFrame.SetCooldown then
        local ok = pcall(cooldownFrame.SetCooldown, cooldownFrame, startTime, duration)
        if ok then
            return true, "numeric_fallback", isOnGCD
        end
    end

    return false, nil, isOnGCD
end

-- Apply desaturation when aura is active but we're showing spell cooldown
-- Uses a force value flag that hooks will enforce to prevent flashing
local function ApplyDesaturationForAuraActive(iconFrame, desaturate)
    if not iconFrame then return end
    
    local iconTexture = iconFrame.icon or iconFrame.Icon
    if not iconTexture then return end
    
    -- Set the force value flag - hooks will enforce this
    if desaturate then
        iconFrame.__lilyuiForceDesatValue = 1
    else
        iconFrame.__lilyuiForceDesatValue = nil
    end
    
    -- Apply immediately
    if desaturate then
        if iconTexture.SetDesaturation then
            iconTexture:SetDesaturation(1)
        elseif iconTexture.SetDesaturated then
            iconTexture:SetDesaturated(true)
        end
    else
        if iconTexture.SetDesaturation then
            iconTexture:SetDesaturation(0)
        elseif iconTexture.SetDesaturated then
            iconTexture:SetDesaturated(false)
        end
    end
end

local function ApplyOverrideCooldown(cooldownFrame, iconFrame, spellID)
    if not cooldownFrame or not iconFrame or not spellID then
        return false, nil
    end

    local shown, source, isOnGCD = ApplySpellCooldownToFrame(cooldownFrame, spellID)
    if shown then
        if cooldownFrame.SetSwipeColor then
            cooldownFrame:SetSwipeColor(0, 0, 0, 0.8)
        end
        cooldownFrame:Show()
        if source == "charge_object" then
            iconFrame.__lilyuiForceDesatValue = nil
            ApplyDesaturationForAuraActive(iconFrame, false)
        else
            if not isOnGCD then
                iconFrame.__lilyuiForceDesatValue = 1
                ApplyDesaturationForAuraActive(iconFrame, true)
            else
                iconFrame.__lilyuiForceDesatValue = nil
                ApplyDesaturationForAuraActive(iconFrame, false)
            end
        end
        return true, source
    end

    iconFrame.__lilyuiForceDesatValue = nil
    ApplyDesaturationForAuraActive(iconFrame, false)
    if cooldownFrame.Clear then
        pcall(cooldownFrame.Clear, cooldownFrame)
    end
    cooldownFrame:Hide()
    return false, nil
end

-- Hook SetCooldown to enforce spell cooldown when ignoreAuraOverride is enabled
local function HookCooldownFrame(iconFrame, viewerName)
    if not iconFrame or not iconFrame.Cooldown then return end
    if iconFrame.__lilyuiAuraOverrideHooked then return end
    
    iconFrame.__lilyuiAuraOverrideHooked = true
    iconFrame.__lilyuiViewerName = viewerName
    
    local cooldown = iconFrame.Cooldown
    local iconTexture = iconFrame.icon or iconFrame.Icon
    
    -- Hook SetDesaturated and SetDesaturation to enforce our force value
    -- This prevents CDM from constantly changing desaturation and causing flashing
    if iconTexture and not iconTexture.__lilyuiDesatHooked then
        iconTexture.__lilyuiDesatHooked = true
        iconTexture.__lilyuiParentFrame = iconFrame
        
        -- Hook SetDesaturated (boolean version)
        if iconTexture.SetDesaturated then
            hooksecurefunc(iconTexture, "SetDesaturated", function(self, desaturated)
                local pf = self.__lilyuiParentFrame
                if not pf then return end
                if pf.__lilyuiBypassDesatHook then return end
                
                -- If we have a forced desaturation value (for ignoreAuraOverride), enforce it
                local forceValue = pf.__lilyuiForceDesatValue
                if forceValue ~= nil and self.SetDesaturation then
                    pf.__lilyuiBypassDesatHook = true
                    self:SetDesaturation(forceValue)
                    pf.__lilyuiBypassDesatHook = false
                end
            end)
        end
        
        -- Hook SetDesaturation (numeric version)
        if iconTexture.SetDesaturation then
            hooksecurefunc(iconTexture, "SetDesaturation", function(self, value)
                local pf = self.__lilyuiParentFrame
                if not pf then return end
                if pf.__lilyuiBypassDesatHook then return end
                
                -- If we have a forced desaturation value (for ignoreAuraOverride), enforce it
                local forceValue = pf.__lilyuiForceDesatValue
                if forceValue ~= nil then
                    pf.__lilyuiBypassDesatHook = true
                    self:SetDesaturation(forceValue)
                    pf.__lilyuiBypassDesatHook = false
                end
            end)
        end
    end
    
    -- Hook SetCooldown using hooksecurefunc
    hooksecurefunc(cooldown, "SetCooldown", function(self, startTime, duration)
        local parentFrame = self:GetParent()
        if not parentFrame or not parentFrame.__lilyuiViewerName then return end
        if parentFrame.__lilyuiBypassCooldownHook then return end
        
        local viewerName = parentFrame.__lilyuiViewerName
        local ignoreAuraOverride = GetViewerSettings(viewerName)
        
        if ignoreAuraOverride and HasActiveAura(parentFrame) then
            local spellID = GetSpellID(parentFrame)
            if spellID then
                parentFrame.__lilyuiBypassCooldownHook = true
                ApplyOverrideCooldown(self, parentFrame, spellID)
                parentFrame.__lilyuiBypassCooldownHook = false
            end
        elseif ignoreAuraOverride then
            -- Clear force desaturation when aura is not active
            parentFrame.__lilyuiForceDesatValue = nil
            -- Update desaturation when aura is not active
            ApplyDesaturationForAuraActive(parentFrame, false)
        end
    end)
    
    -- Hook SetCooldownFromDurationObject
    if cooldown.SetCooldownFromDurationObject then
        hooksecurefunc(cooldown, "SetCooldownFromDurationObject", function(self, durationObj, clearIfZero)
            local parentFrame = self:GetParent()
            if not parentFrame or not parentFrame.__lilyuiViewerName then return end
            if parentFrame.__lilyuiBypassCooldownHook then return end
            
            local viewerName = parentFrame.__lilyuiViewerName
            local ignoreAuraOverride = GetViewerSettings(viewerName)
            
            if ignoreAuraOverride and HasActiveAura(parentFrame) then
                local spellID = GetSpellID(parentFrame)
                if spellID then
                    parentFrame.__lilyuiBypassCooldownHook = true
                    ApplyOverrideCooldown(self, parentFrame, spellID)
                    parentFrame.__lilyuiBypassCooldownHook = false
                end
            elseif ignoreAuraOverride then
                -- Clear force desaturation when aura is not active
                parentFrame.__lilyuiForceDesatValue = nil
                -- Update desaturation when aura is not active
                ApplyDesaturationForAuraActive(parentFrame, false)
            end
        end)
    end
end

-- Hook an icon frame
function AuraOverride:HookIconFrame(iconFrame, viewerName)
    if not iconFrame or not viewerName then return end
    if not GetViewerSettings(viewerName) then return end
    
    HookCooldownFrame(iconFrame, viewerName)
end

-- Refresh all icons in a viewer
function AuraOverride:RefreshViewer(viewer)
    if not viewer or not viewer.GetName then return end
    
    local viewerName = viewer:GetName()
    local ignoreAuraOverride = GetViewerSettings(viewerName)
    
    if not ignoreAuraOverride then return end
    
    local container = viewer.viewerFrame or viewer
    local children = { container:GetChildren() }
    
    for _, icon in ipairs(children) do
        if icon and (icon.icon or icon.Icon) and icon.Cooldown then
            self:HookIconFrame(icon, viewerName)
            
            -- Force update if aura is active
            if HasActiveAura(icon) then
                local spellID = GetSpellID(icon)
                if spellID and icon.Cooldown then
                    ApplyOverrideCooldown(icon.Cooldown, icon, spellID)
                end
            end
        end
    end
end

-- Event handler for aura changes
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" and unit == "player" then
        -- Refresh viewers when player auras change
        C_Timer.After(0.1, function()
            for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer"}) do
                local viewer = _G[viewerName]
                if viewer and viewer:IsShown() and GetViewerSettings(viewerName) then
                    AuraOverride:RefreshViewer(viewer)
                end
            end
        end)
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        -- Refresh viewers when spell cooldowns update
        C_Timer.After(0.1, function()
            for _, viewerName in ipairs({"EssentialCooldownViewer", "UtilityCooldownViewer"}) do
                local viewer = _G[viewerName]
                if viewer and viewer:IsShown() and GetViewerSettings(viewerName) then
                    AuraOverride:RefreshViewer(viewer)
                end
            end
        end)
    end
end)

-- Initialize hooks for existing viewers
function AuraOverride:Initialize()
    local viewers = {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
    }
    
    for _, viewerName in ipairs(viewers) do
        local viewer = _G[viewerName]
        if viewer then
            -- Hook the viewer's OnShow to refresh icons
            if not viewer.__lilyuiAuraOverrideHooked then
                viewer.__lilyuiAuraOverrideHooked = true
                viewer:HookScript("OnShow", function()
                    C_Timer.After(0.1, function()
                        AuraOverride:RefreshViewer(viewer)
                    end)
                end)
            end
            
            -- Initial refresh
            C_Timer.After(1.0, function()
                self:RefreshViewer(viewer)
            end)
        end
    end
    
    -- Hook into IconViewers to hook new icons as they're skinned
    if LilyUI.IconViewers and LilyUI.IconViewers.SkinIcon then
        local originalSkinIcon = LilyUI.IconViewers.SkinIcon
        function LilyUI.IconViewers:SkinIcon(icon, settings)
            local result = originalSkinIcon(self, icon, settings)
            
            -- Determine viewer name from settings
            local viewerName = nil
            for name, viewerSettings in pairs(LilyUI.db.profile.viewers) do
                if viewerSettings == settings then
                    viewerName = name
                    break
                end
            end
            
            if viewerName and (viewerName == "EssentialCooldownViewer" or viewerName == "UtilityCooldownViewer") then
                AuraOverride:HookIconFrame(icon, viewerName)
            end
            
            return result
        end
    end
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(2.0, function()
            AuraOverride:Initialize()
        end)
    end
end)

