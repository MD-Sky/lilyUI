local ADDON_NAME, ns = ...

local LilyUI = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceConsole-3.0",
    "AceEvent-3.0"
)

ns.Addon = LilyUI

-- Get localization table (should be loaded by Locales/Locale.lua)
local L = ns.L or LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)

local AceSerializer = LibStub("AceSerializer-3.0", true)
local LibDeflate    = LibStub("LibDeflate", true)
local AceDBOptions = LibStub("AceDBOptions-3.0", true)
local LibDualSpec   = LibStub("LibDualSpec-1.0", true)

-- ---------------------------------------------------------------------------
-- WoW API compatibility shims
-- ---------------------------------------------------------------------------
-- Some newer clients no longer expose GetSpellInfo() globally. A few bundled
-- libraries (and older code paths) still expect it. Provide a lightweight
-- fallback that forwards to C_Spell.GetSpellInfo when available.
if not _G.GetSpellInfo and C_Spell and C_Spell.GetSpellInfo then
    function _G.GetSpellInfo(spellIdentifier, ...)
        local info = C_Spell.GetSpellInfo(spellIdentifier)
        if not info then
            return nil
        end
        local name = info.name
        local icon = info.iconID or info.icon
        local castTime = info.castTime or 0
        local minRange = info.minRange or 0
        local maxRange = info.maxRange or 0
        local spellID = info.spellID or tonumber(spellIdentifier)
        -- Match classic return order as closely as possible:
        -- name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon
        return name, nil, icon, castTime, minRange, maxRange, spellID, icon
    end
end

local WHITE8 = "Interface\\Buttons\\WHITE8X8"

local SELECTION_ALPHA = 0.5
local SelectionRegionKeys = {
    "Center",
    "MouseOverHighlight",
    "TopEdge",
    "BottomEdge",
    "LeftEdge",
    "RightEdge",
    "TopLeft",
    "TopRight",
    "BottomLeft",
    "BottomRight",
    "Left",
    "Right",
    "Top",
    "Bottom",
}

local function ApplyAlphaToRegion(region)
    if not region or not region.SetAlpha then
        return
    end

    region:SetAlpha(SELECTION_ALPHA)
    if region.HookScript and not region.__nephuiSelectionAlphaHooked then
        region.__nephuiSelectionAlphaHooked = true
        region:HookScript("OnShow", function(self)
            self:SetAlpha(SELECTION_ALPHA)
        end)
    end
end

local function ForceSelectionAlpha(selection)
    if not selection or not selection.SetAlpha then
        return
    end

    selection.__nephuiSelectionAlphaLock = true
    selection:SetAlpha(SELECTION_ALPHA)
    selection.__nephuiSelectionAlphaLock = nil
end

function LilyUI:ApplySelectionAlpha(selection)
    if not selection then
        return
    end

    ForceSelectionAlpha(selection)

    if selection.HookScript and not selection.__nephuiSelectionOnShowHooked then
        selection.__nephuiSelectionOnShowHooked = true
        selection:HookScript("OnShow", function(self)
            LilyUI:ApplySelectionAlpha(self)
        end)
    end

    if selection.SetAlpha and not selection.__nephuiSelectionAlphaHooked then
        selection.__nephuiSelectionAlphaHooked = true
        hooksecurefunc(selection, "SetAlpha", function(frame)
            if frame.__nephuiSelectionAlphaLock then
                return
            end
            ForceSelectionAlpha(frame)
        end)
    end

    for _, key in ipairs(SelectionRegionKeys) do
        ApplyAlphaToRegion(selection[key])
    end
end

function LilyUI:ApplySelectionAlphaToFrame(frame)
    if not frame then
        return
    end
    if frame.IsForbidden and frame:IsForbidden() then
        return
    end
    if frame.Selection then
        self:ApplySelectionAlpha(frame.Selection)
    end
end

function LilyUI:ApplySelectionAlphaToAllFrames()
    local frame = EnumerateFrames()
    while frame do
        self:ApplySelectionAlphaToFrame(frame)
        frame = EnumerateFrames(frame)
    end
end

function LilyUI:InitializeSelectionAlphaController()
    if self.__selectionAlphaInitialized then
        return
    end
    self.__selectionAlphaInitialized = true

    local function TryHookSelectionMixin()
        if self.__selectionMixinHooked then
            return true
        end
        if EditModeSelectionFrameBaseMixin then
            self.__selectionMixinHooked = true
            hooksecurefunc(EditModeSelectionFrameBaseMixin, "OnLoad", function(selectionFrame)
                LilyUI:ApplySelectionAlpha(selectionFrame)
            end)
            hooksecurefunc(EditModeSelectionFrameBaseMixin, "OnShow", function(selectionFrame)
                LilyUI:ApplySelectionAlpha(selectionFrame)
            end)
            return true
        end
        return false
    end

    if not TryHookSelectionMixin() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("ADDON_LOADED")
        waiter:SetScript("OnEvent", function(self, _, addonName)
            if addonName == "Blizzard_EditMode" or addonName == ADDON_NAME then
                if TryHookSelectionMixin() then
                    self:UnregisterEvent("ADDON_LOADED")
                    self:SetScript("OnEvent", nil)
                end
            end
        end)
    end

    self:ApplySelectionAlphaToAllFrames()
    C_Timer.After(0.5, function()
        LilyUI:ApplySelectionAlphaToAllFrames()
    end)

    self.SelectionAlphaTicker = C_Timer.NewTicker(1.0, function()
        if EditModeManagerFrame and EditModeManagerFrame.editModeActive then
            LilyUI:ApplySelectionAlphaToAllFrames()
        end
    end)
end

function LilyUI:ExportProfileToString()
    if not self.db or not self.db.profile then
        return L["No profile loaded."] or "No profile loaded."
    end
    if not AceSerializer or not LibDeflate then
        return L["Export requires AceSerializer-3.0 and LibDeflate."] or "Export requires AceSerializer-3.0 and LibDeflate."
    end

    local serialized = AceSerializer:Serialize(self.db.profile)
    if not serialized or type(serialized) ~= "string" then
        return L["Failed to serialize profile."] or "Failed to serialize profile."
    end

    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return L["Failed to compress profile."] or "Failed to compress profile."
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return L["Failed to encode profile."] or "Failed to encode profile."
    end

    return "NUI1:" .. encoded
end

function LilyUI:ImportProfileFromString(str, profileName)
    if not self.db then
        return false, L["No profile loaded."] or "No profile loaded."
    end
    if not AceSerializer or not LibDeflate then
        return false, L["Import requires AceSerializer-3.0 and LibDeflate."] or "Import requires AceSerializer-3.0 and LibDeflate."
    end
    if not str or str == "" then
        return false, L["No data provided."] or "No data provided."
    end

    str = str:gsub("%s+", "")
    str = str:gsub("^CDM1:", "")
    str = str:gsub("^NUI1:", "")

    local compressed = LibDeflate:DecodeForPrint(str)
    if not compressed then
        return false, L["Could not decode string (maybe corrupted)."] or "Could not decode string (maybe corrupted)."
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return false, L["Could not decompress data."] or "Could not decompress data."
    end

    local ok, t = AceSerializer:Deserialize(serialized)
    if not ok or type(t) ~= "table" then
        return false, L["Could not deserialize profile."] or "Could not deserialize profile."
    end

    -- If profileName is provided, create a new profile
    if profileName and profileName ~= "" then
        -- Ensure unique name by checking if profile already exists
        local baseName = profileName
        local counter = 1
        while self.db.profiles and self.db.profiles[profileName] do
            counter = counter + 1
            profileName = baseName .. " " .. counter
        end

        -- Create the new profile
        if not self.db.profiles then
            return false, L["Profile system not available."] or "Profile system not available."
        end

        self.db.profiles[profileName] = t
        self.db:SetProfile(profileName)
    else
        -- Old behavior: overwrite current profile (for backwards compatibility)
        if not self.db.profile then
            return false, L["No profile loaded."] or "No profile loaded."
        end
        local profile = self.db.profile
        for k in pairs(profile) do
            profile[k] = nil
        end
        for k, v in pairs(t) do
            profile[k] = v
        end
    end

    if self.RefreshAll then
        self:RefreshAll()
    end

    return true
end

-- Wago UI Pack Installer Integration Functions
function LilyUI:ExportLilyUI(profileKey)
    local profile = self.db.profiles[profileKey]
    if not profile then return nil end

    local profileData = { profile = profile, }

    local SerializedInfo = AceSerializer:Serialize(profileData)
    local CompressedInfo = LibDeflate:CompressDeflate(SerializedInfo)
    local EncodedInfo = LibDeflate:EncodeForPrint(CompressedInfo)
    EncodedInfo = "!lilyUI_" .. EncodedInfo
    return EncodedInfo
end

function LilyUI:ImportLilyUI(importString, profileKey)
    local payload = importString
    if payload:sub(1,8) == "!LilyUI_" or payload:sub(1,8) == "!lilyUI_" then
        payload = payload:sub(9)
    end
    local DecodedInfo = LibDeflate:DecodeForPrint(payload)
    local DecompressedInfo = LibDeflate:DecompressDeflate(DecodedInfo)
    local success, profileData = AceSerializer:Deserialize(DecompressedInfo)

    if not success or type(profileData) ~= "table" then 
        print("|cFF8080FF" .. (L["lilyUI: Invalid Import String."] or "lilyUI: Invalid Import String.") .. "|r") 
        return 
    end

    if type(profileData.profile) == "table" then
        self.db.profiles[profileKey] = profileData.profile
        self.db:SetProfile(profileKey)
    end
end

function LilyUI:OnInitialize()
    local defaults = LilyUI.defaults
    if not defaults then
        error("lilyUI: Defaults not loaded! Make sure Core/Defaults.lua is loaded before Core/Main.lua")
    end
    
    -- Use a unique database namespace to avoid conflicts with other addons
    -- The name must match the SavedVariables in lilyUI.toc
    self.db = LibStub("AceDB-3.0"):New("lilyUIDB", defaults, true)
    
    -- Verify the database was created with the correct namespace
    if not self.db or not self.db.sv then
        error("lilyUI: Failed to initialize database! Check SavedVariables in lilyUI.toc")
    end
    
    ns.db = self.db

    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied",  "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset",   "OnProfileChanged")
    
    -- Create ShadowUIParent for hiding UI elements
    self.ShadowUIParent = CreateFrame("Frame", nil, UIParent)
    self.ShadowUIParent:Hide()

    if LibDualSpec then
        LibDualSpec:EnhanceDatabase(self.db, ADDON_NAME)
        -- Debug: verify LibDualSpec is working
        if self.db.IsDualSpecEnabled then
            -- LibDualSpec is properly initialized
        end
    else
        -- LibDualSpec not available (may be disabled in Classic Era for non-Season realms)
    end

    self:InitializePixelPerfect()

    -- Apply saved UI color scheme early so the custom config GUI picks it up.
    if self.ApplyColorScheme then
        self:ApplyColorScheme()
    end

    self:SetupOptions()
    
    self:RegisterChatCommand("lilyui", "OpenConfig")
    self:RegisterChatCommand("nephui", "OpenConfig")
    self:RegisterChatCommand("nui", "OpenConfig")
    self:RegisterChatCommand("lilyframes", "OpenPartyRaidFramesConfig")
    self:RegisterChatCommand("nephframes", "OpenPartyRaidFramesConfig")
    self:RegisterChatCommand("nframes", "OpenPartyRaidFramesConfig")
    self:RegisterChatCommand("lilyuirefresh", "ForceRefreshBuffIcons")
    self:RegisterChatCommand("nephuirefresh", "ForceRefreshBuffIcons")
    self:RegisterChatCommand("lilyuicheckdualspec", "CheckDualSpec")
    self:RegisterChatCommand("nephuicheckdualspec", "CheckDualSpec")
    
    self:CreateMinimapButton()
end

function LilyUI:OnProfileChanged(event, db, profileKey)
    if self.RefreshAll then
        -- Defer RefreshAll if in combat to avoid taint/secret value errors
        if InCombatLockdown() then
            if not self.__pendingRefreshAll then
                self.__pendingRefreshAll = true
                local eventFrame = CreateFrame("Frame")
                eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
                eventFrame:SetScript("OnEvent", function(self)
                    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    if LilyUI.RefreshAll and not InCombatLockdown() then
                        LilyUI:RefreshAll()
                    end
                    LilyUI.__pendingRefreshAll = nil
                end)
            end
        else
            self:RefreshAll()
        end
    end
end

function LilyUI:InitializePixelPerfect()
    self.physicalWidth, self.physicalHeight = GetPhysicalScreenSize()
    self.resolution = string.format('%dx%d', self.physicalWidth, self.physicalHeight)
    self.perfect = 768 / self.physicalHeight
    
    self:UIMult()
    
    self:RegisterEvent('UI_SCALE_CHANGED')
end

function LilyUI:UI_SCALE_CHANGED()
    self:PixelScaleChanged('UI_SCALE_CHANGED')
end

local function StyleMicroButtonRegion(button, region)
    if not (button and region) then
        return
    end
    if region.__nephuiStyled then
        return
    end

    region.__nephuiStyled = true
    region:SetTexture(WHITE8)
    region:SetVertexColor(0, 0, 0, 1)
    region:SetAlpha(0.8)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", button, 2.5, -2.5)
    region:SetPoint("BOTTOMRIGHT", button, -2.5, 2.5)
end

local function StyleMicroButton(button)
    if not button then
        return
    end
    StyleMicroButtonRegion(button, button.Background)
    StyleMicroButtonRegion(button, button.PushedBackground)
end

function LilyUI:StyleMicroButtons()
    if type(MICRO_BUTTONS) == "table" then
        for _, name in ipairs(MICRO_BUTTONS) do
            StyleMicroButton(_G[name])
        end
    end
    -- Fallback if MICRO_BUTTONS is missing
    StyleMicroButton(_G.CharacterMicroButton)
end

function LilyUI:PLAYER_LOGIN()
    if self.ApplyGlobalFont then
        self:ApplyGlobalFont()
    end
    self:UnregisterEvent("PLAYER_LOGIN")
end

function LilyUI:OnEnable()
    SetCVar("cooldownViewerEnabled", 1)
    
    if self.UIMult then
        self:UIMult()
    end
    
    if self.ApplyGlobalFont then
        C_Timer.After(0.5, function()
            self:ApplyGlobalFont()
        end)
    end
    
    self:RegisterEvent("PLAYER_LOGIN")
    
    C_Timer.After(0.1, function()
        LilyUI:StyleMicroButtons()
    end)
    
    if self.IconViewers and self.IconViewers.HookViewers then
        self.IconViewers:HookViewers()
    end

    if self.IconViewers and self.IconViewers.BuffBarCooldownViewer and self.IconViewers.BuffBarCooldownViewer.Initialize then
        self.IconViewers.BuffBarCooldownViewer:Initialize()
    end

    if self.ProcGlow and self.ProcGlow.Initialize then
        C_Timer.After(1.0, function()
            self.ProcGlow:Initialize()
        end)
    end

    if self.Keybinds and self.Keybinds.Initialize then
        C_Timer.After(1.0, function()
            self.Keybinds:Initialize()
        end)
    end

    if self.CastBars and self.CastBars.Initialize then
        self.CastBars:Initialize()
    end
    
    if self.ResourceBars and self.ResourceBars.Initialize then
        self.ResourceBars:Initialize()
    end

    if self.PartyFrames and self.PartyFrames.Initialize then
        self.PartyFrames:Initialize()
    end

   -- if self.RaidFrames and self.RaidFrames.Initialize then
   --     self.RaidFrames:Initialize()
   -- end
    
    if self.AutoUIScale and self.AutoUIScale.Initialize then
        self.AutoUIScale:Initialize()
    end
    
    if self.Chat and self.Chat.Initialize then
        self.Chat:Initialize()
    end
    
    if self.Minimap and self.Minimap.Initialize then
        self.Minimap:Initialize()
    end
    
    if self.ActionBars and self.ActionBars.Initialize then
        self.ActionBars:Initialize()
    end
    
    if self.ActionBarGlow and self.ActionBarGlow.Initialize then
        C_Timer.After(1.0, function()
            self.ActionBarGlow:Initialize()
        end)
    end
    
    if self.BuffDebuffFrames and self.BuffDebuffFrames.Initialize then
        self.BuffDebuffFrames:Initialize()
    end
    
    if self.QOL and self.QOL.Initialize then
        self.QOL:Initialize()
    end

    if self.CharacterPanel and self.CharacterPanel.Initialize then
        self.CharacterPanel:Initialize()
    end
    
    C_Timer.After(0.1, function()
        if self.CastBars and self.CastBars.HookTargetAndFocusCastBars then
            self.CastBars:HookTargetAndFocusCastBars()
        end
        if self.CastBars and self.CastBars.HookFocusCastBar then
            self.CastBars:HookFocusCastBar()
        end
        if self.CastBars and self.CastBars.HookBossCastBars then
            self.CastBars:HookBossCastBars()
        end
    end)
    
    if self.UnitFrames and self.db.profile.unitFrames and self.db.profile.unitFrames.enabled then
        C_Timer.After(0.5, function()
            if self.UnitFrames.Initialize then
                self.UnitFrames:Initialize()
            end
            
            if self.AbsorbBars and self.AbsorbBars.Initialize then
                self.AbsorbBars:Initialize()
            end
            
            local UF = self.UnitFrames
            if UF and UF.RepositionAllUnitFrames then
                local originalReposition = UF.RepositionAllUnitFrames
                UF.RepositionAllUnitFrames = function(self, ...)
                    originalReposition(self, ...)
                    C_Timer.After(0.1, function()
                        if LilyUI.CustomIcons and LilyUI.CustomIcons.ApplyCustomIconsLayout then
                            LilyUI.CustomIcons:ApplyCustomIconsLayout()
                        end
                        if LilyUI.CustomIcons and LilyUI.CustomIcons.ApplyTrinketsLayout then
                            LilyUI.CustomIcons:ApplyTrinketsLayout()
                        end
                    end)
                end
            end
        end)
    end
    
    if self.IconViewers and self.IconViewers.AutoLoadBuffIcons then
        C_Timer.After(0.5, function()
            self.IconViewers:AutoLoadBuffIcons()
        end)
    end

    -- Ensure all viewers are skinned on load
    if self.IconViewers and self.IconViewers.RefreshAll then
        C_Timer.After(1.0, function()
            self.IconViewers:RefreshAll()
        end)
    end
    
    if self.CustomIcons then
        C_Timer.After(1.5, function()
            if self.CustomIcons.CreateCustomIconsTrackerFrame then
                self.CustomIcons:CreateCustomIconsTrackerFrame()
            end
            if self.CustomIcons.CreateTrinketsTrackerFrame then
                self.CustomIcons:CreateTrinketsTrackerFrame()
            end
            if self.CustomIcons.CreateDefensivesTrackerFrame then
                self.CustomIcons:CreateDefensivesTrackerFrame()
            end
        end)

        C_Timer.After(2.5, function()
            if self.CustomIcons.ApplyCustomIconsLayout then
                self.CustomIcons:ApplyCustomIconsLayout()
            end
            if self.CustomIcons.ApplyTrinketsLayout then
                self.CustomIcons:ApplyTrinketsLayout()
            end
            if self.CustomIcons.ApplyDefensivesLayout then
                self.CustomIcons:ApplyDefensivesLayout()
            end
        end)
    end

    self:InitializeSelectionAlphaController()
end

function LilyUI:OpenConfig()
    if self.OpenConfigGUI then
        self:OpenConfigGUI()
    else
        print("|cffff0000[LilyUI] Warning: Custom GUI not loaded, using AceConfigDialog|r")
        LibStub("AceConfigDialog-3.0"):Open(ADDON_NAME)
    end
end

function LilyUI:OpenPartyRaidFramesConfig()
    if self.PartyFrames and self.PartyFrames.ToggleGUI then
        self.PartyFrames:ToggleGUI()
    else
        print("|cffff0000[LilyUI] Party/Raid frames GUI not loaded.|r")
    end
end

function LilyUI:CheckDualSpec()
    local LibDualSpec = LibStub("LibDualSpec-1.0", true)
    if not LibDualSpec then
        print("|cffff0000[LilyUI] LibDualSpec-1.0 is NOT loaded.|r")
        print("|cffffff00This is normal on Classic Era realms (except Season of Discovery/Anniversary).|r")
        return
    end
    
    print("|cff00ff00[LilyUI] LibDualSpec-1.0 is loaded.|r")
    
    if not self.db then
        print("|cffff0000[LilyUI] Database not initialized yet.|r")
        return
    end
    
    if self.db.IsDualSpecEnabled then
        local isEnabled = self.db:IsDualSpecEnabled()
        print(string.format("|cff00ff00[LilyUI] Dual Spec support: %s|r", isEnabled and "ENABLED" or "DISABLED"))
        
        if isEnabled then
            local currentSpec = GetSpecialization() or GetActiveTalentGroup() or 0
            print(string.format("|cff00ff00[LilyUI] Current spec: %d|r", currentSpec))
            
            local currentProfile = self.db:GetCurrentProfile()
            print(string.format("|cff00ff00[LilyUI] Current profile: %s|r", currentProfile))
            
            -- Check spec profiles
            for i = 1, 2 do
                local specProfile = self.db:GetDualSpecProfile(i)
                print(string.format("|cff00ff00[LilyUI] Spec %d profile: %s|r", i, specProfile))
            end
        end
    else
        print("|cffff0000[LilyUI] LibDualSpec methods not found on database (database not enhanced).|r")
    end
end

function LilyUI:CreateMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1", true)
    local LibDBIcon = LibStub("LibDBIcon-1.0", true)
    
    if not LDB or not LibDBIcon then
        return
    end
    
    if not self.db.profile.minimap then
        self.db.profile.minimap = {
            hide = false,
        }
    end
    
    local dataObj = LDB:NewDataObject(ADDON_NAME, {
        type = "launcher",
        icon = "Interface\\AddOns\\lilyUI\\Media\\lilyui.tga",
        label = L["LilyUI"] or "LilyUI",
        OnClick = function(clickedframe, button)
            if button == "LeftButton" then
                self:OpenConfig()
            elseif button == "RightButton" then
                self:OpenConfig()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:SetText(L["LilyUI"] or "LilyUI")
            tooltip:AddLine(L["Left-click to open configuration"] or "Left-click to open configuration", 1, 1, 1)
            tooltip:AddLine(L["Right-click to open configuration"] or "Right-click to open configuration", 1, 1, 1)
        end,
    })
    
    LibDBIcon:Register(ADDON_NAME, dataObj, self.db.profile.minimap)
end

function LilyUI:RefreshViewers()
    if self.IconViewers and self.IconViewers.RefreshAll then
        self.IconViewers:RefreshAll()
    end

    if self.ProcGlow and self.ProcGlow.RefreshAll then
        self.ProcGlow:RefreshAll()
    end
end

function LilyUI:RefreshCustomIcons()
    if not (self.CustomIcons and self.db and self.db.profile and self.db.profile.customIcons) then
        return
    end
    if self.db.profile.customIcons.enabled == false then
        return
    end

    local module = self.CustomIcons
    if module.CreateCustomIconsTrackerFrame then
        module:CreateCustomIconsTrackerFrame()
    end
end

function LilyUI:RefreshAll()
    self:RefreshViewers()
    
    if self.ResourceBars and self.ResourceBars.RefreshAll then
        self.ResourceBars:RefreshAll()
    end
    
    if self.CastBars and self.CastBars.RefreshAll then
        self.CastBars:RefreshAll()
    end
    
    if self.Chat and self.Chat.RefreshAll then
        self.Chat:RefreshAll()
    end
    
    if self.ActionBars and self.ActionBars.RefreshAll then
        self.ActionBars:RefreshAll()
    end
    
    if self.BuffDebuffFrames and self.BuffDebuffFrames.RefreshAll then
        self.BuffDebuffFrames:RefreshAll()
    end

    if self.QOL and self.QOL.Refresh then
        self.QOL:Refresh()
    end

    if self.CharacterPanel and self.CharacterPanel.Refresh then
        self.CharacterPanel:Refresh()
    end
    
    if self.UnitFrames and self.UnitFrames.RefreshFrames then
        self.UnitFrames:RefreshFrames()
    end

    if self.PartyFrames and self.PartyFrames.Refresh then
        self.PartyFrames:Refresh()
    end

    if self.RaidFrames and self.RaidFrames.Refresh then
        self.RaidFrames:Refresh()
    end
    
    if self.Minimap and self.Minimap.Refresh then
        self.Minimap:Refresh()
    end
    
    if self.CustomIcons and self.db.profile.customIcons and self.db.profile.customIcons.enabled ~= false then
        self:RefreshCustomIcons()
    end
end
