local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
local THEME = {

    -- These are updated dynamically from the saved color scheme (see ApplyColorSchemeToTheme).
    primary = {0.78, 0.25, 0.55},
    primaryHover = {0.90, 0.28, 0.62},
    primaryActive = {1.00, 0.32, 0.70},
    bgDark = {0.085, 0.095, 0.120},
    bgMedium = {0.115, 0.130, 0.155},
    bgLight = {0.165, 0.180, 0.220},
    input = {0.02, 0.02, 0.02, 0.95},
    border = {0.080, 0.080, 0.090, 0.95},
    borderLight = {0.280, 0.280, 0.320, 0.9},
    text = {0.96, 0.96, 0.98},
    textDim = {0.72, 0.72, 0.78},
    gold = {0.96, 0.96, 0.98},
    accent = {1.00, 0.25, 0.65},
}

local function Clamp01(v)
    if v == nil then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ScaleColor(r, g, b, s)
    return Clamp01(r * s), Clamp01(g * s), Clamp01(b * s)
end

local function ApplyColorSchemeToTheme(r, g, b)
    r, g, b = Clamp01(r), Clamp01(g), Clamp01(b)

    THEME.accent[1], THEME.accent[2], THEME.accent[3] = r, g, b

    -- Derive button shades from the accent so the whole GUI feels cohesive.
    -- (Slightly darker for normal, brighter for hover/active.)
    local pr, pg, pb = ScaleColor(r, g, b, 0.78)
    local hr, hg, hb = ScaleColor(r, g, b, 0.90)
    local ar, ag, ab = ScaleColor(r, g, b, 1.00)
    THEME.primary[1], THEME.primary[2], THEME.primary[3] = pr, pg, pb
    THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3] = hr, hg, hb
    THEME.primaryActive[1], THEME.primaryActive[2], THEME.primaryActive[3] = ar, ag, ab
end

-- Exposed helper: the saved UI color scheme (defaults to pink)
function LilyUI:GetColorScheme()
    local scheme = self.db and self.db.profile and self.db.profile.general and self.db.profile.general.colorScheme
    if type(scheme) == "table" then
        return scheme[1] or 1.0, scheme[2] or 0.25, scheme[3] or 0.65, scheme[4] or 1.0
    end
    return 1.0, 0.25, 0.65, 1.0
end

-- Apply the saved scheme to the GUI theme (safe to call any time)
function LilyUI:ApplyColorScheme()
    local r, g, b = self:GetColorScheme()
    ApplyColorSchemeToTheme(r, g, b)
end


-- Helper: config window backdrop style
function LilyUI:GetUIBackdropStyle()
    return (self.db and self.db.profile and self.db.profile.general and self.db.profile.general.uiBackdropStyle) or "Default"
end

-- Helper: gradient compatibility across client versions
local function SetTextureGradientAlpha(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if not tex then return end
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    elseif tex.SetGradient and CreateColor then
        tex:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    elseif tex.SetColorTexture then
        tex:SetColorTexture(r1, g1, b1, (a1 + a2) * 0.5)
    end
end

local function StyleFontString(fontString)
    if not fontString then return end
    
    -- Always use LilyUI's global font for GUI elements
    local globalFontPath = LilyUI:GetGlobalFont()
    local currentFont, size, flags = fontString:GetFont()
    
    -- Preserve size, default to 12 if not found
    size = size or 12
    
    -- Use OUTLINE flag if no flags or if flags don't contain OUTLINE
    if not flags or (flags ~= "OUTLINE" and flags ~= "THICKOUTLINE" and not flags:find("OUTLINE")) then
        flags = "OUTLINE"
    end
    
    -- Apply global font if available, otherwise use existing font with outline
    if globalFontPath then
        fontString:SetFont(globalFontPath, size, flags)
    elseif currentFont and size and flags then
        -- Fallback: preserve existing font but ensure outline
        fontString:SetFont(currentFont, size, flags)
    end
    
    fontString:SetShadowOffset(0, 0)
    fontString:SetShadowColor(0, 0, 0, 1)
end

local function StyleEditBox(editBox, fontObjectName)
    if not editBox then return end
    
    -- Always use LilyUI's global font for GUI elements
    local globalFontPath = LilyUI:GetGlobalFont()
    
    -- Get size from font object if provided, otherwise from edit box
    local size = 12
    if fontObjectName and _G[fontObjectName] then
        local fontObject = _G[fontObjectName]
        local _, fontObjectSize = fontObject:GetFont()
        if fontObjectSize then
            size = fontObjectSize
        end
    else
        local _, editBoxSize = editBox:GetFont()
        if editBoxSize then
            size = editBoxSize
        end
    end
    
    -- Apply global font with OUTLINE flag
    if globalFontPath then
        editBox:SetFont(globalFontPath, size, "OUTLINE")
    end
    
    editBox:SetShadowOffset(0, 0)
    editBox:SetShadowColor(0, 0, 0, 1)
end

local function GUIDebug(fmt, ...)
    if not (LilyUI and type(LilyUI.DebugWindowLog) == "function") then
        return
    end
    local ok = pcall(LilyUI.DebugWindowLog, LilyUI, "System", fmt, ...)
    if not ok then
        -- Swallow any logging errors to avoid breaking the UI.
    end
end

local function BuildLandingPageUI(parent, configFrame)
    GUIDebug("[GUI] Landing page opened")
    if not parent then return end

    -- Header
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    StyleFontString(title)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, -16)
    title:SetText("LilyUI Settings")
    title:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)

    local sub = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    StyleFontString(sub)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetJustifyH("LEFT")
    sub:SetText("Choose a section to configure. These are quick shortcuts — the full list is still in the left sidebar.")
    sub:SetTextColor(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\Buttons\\WHITE8x8")
    divider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.6)

    local tileContainer = CreateFrame("Frame", nil, parent)
    tileContainer:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -16)
    tileContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, 0)

    local function NavigateTo(tabKey)
        if not configFrame or not configFrame.tabs then return end
        local btn = configFrame.tabs[tabKey]
        if btn and btn.Click then
            btn:Click()
        end
    end

    local tiles = {
        { key = "general",      title = "General",         desc = "Textures, fonts, colors, scale, QoL", icon = "Interface\\Icons\\INV_Gizmo_02" },
        { key = "minimap",      title = "Minimap",         desc = "Minimap styling & buttons",          icon = "Interface\\Icons\\INV_Misc_Map_01" },
        { key = "chat",         title = "Chat",            desc = "Chat frames, fonts, fading",         icon = "Interface\\Icons\\INV_Misc_Note_01" },
        { key = "viewers",      title = "Cooldowns",       desc = "Cooldown manager & proc glows",      icon = "Interface\\Icons\\Spell_Holy_BorrowedTime" },
        { key = "actionBars",   title = "Action Bars",     desc = "Bars, buttons, layouts",            icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
        { key = "buffDebuffFrames", title = "Auras & Icons", desc = "Buffs, debuffs, aura visuals",      icon = "Interface\\Icons\\Spell_Holy_SealOfValor" },
        { key = "unitFrames",   title = "Frames",          desc = "Unit / Party / Raid frames",         icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear" },
        { key = "clickCast",    title = "Click Casting",   desc = "Clique-style click binds",           icon = "Interface\\Icons\\Ability_Priest_BindingPrayers" },
    }

    local tileButtons = {}

    local function CreateTile(def)
        local b = CreateFrame("Button", nil, tileContainer, "BackdropTemplate")
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        b:SetBackdropColor(THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], 0.85)
        b:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.65)

        local accent = b:CreateTexture(nil, "ARTWORK")
        accent:SetTexture("Interface\\Buttons\\WHITE8x8")
        accent:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
        accent:SetWidth(3)
        accent:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.9)
        accent:Hide()

        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(34, 34)
        icon:SetPoint("TOPLEFT", b, "TOPLEFT", 12, -12)
        icon:SetTexture(def.icon)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        StyleFontString(t)
        t:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
        t:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10, -12)
        t:SetJustifyH("LEFT")
        t:SetText(def.title)
        t:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)

        local d = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        StyleFontString(d)
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
        d:SetPoint("RIGHT", b, "RIGHT", -10, 0)
        d:SetJustifyH("LEFT")
        d:SetText(def.desc)
        d:SetTextColor(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)

        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.9)
            self:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.9)
            accent:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], 0.85)
            self:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.65)
            accent:Hide()
        end)
        b:SetScript("OnClick", function()
            NavigateTo(def.key)
        end)

        return b
    end

    for _, def in ipairs(tiles) do
        table.insert(tileButtons, CreateTile(def))
    end

    -- Quick links row (smaller buttons)
    local quickHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(quickHeader)
    quickHeader:SetPoint("TOPLEFT", tileContainer, "BOTTOMLEFT", 0, -20)
    quickHeader:SetText("Quick Links")
    quickHeader:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)

    local quickContainer = CreateFrame("Frame", nil, parent)
    quickContainer:SetPoint("TOPLEFT", quickHeader, "BOTTOMLEFT", 0, -10)
    quickContainer:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, 0)

    local quick = {
        { key = "qol",          label = "QoL" },
        { key = "resourceBars", label = "Resource Bars" },
        { key = "castBars",    label = "Cast Bars" },
        { key = "customIcons", label = "Dynamic Icons" },
        { key = "partyFrames", label = "Party Frames" },
        { key = "raidFrames",  label = "Raid Frames" },
        { key = "profiles",    label = "Profiles" },
        { key = "importExport", label = "Import / Export" },
    }

    local quickButtons = {}
    local function CreateQuickButton(def)
        local b = CreateFrame("Button", nil, quickContainer, "BackdropTemplate")
        b:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        b:SetBackdropColor(THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85)
        b:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.55)
        b:SetHeight(26)

        local l = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        StyleFontString(l)
        l:SetPoint("CENTER")
        l:SetText(def.label)
        l:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)

        b:SetScript("OnEnter", function(self)
            self:SetBackdropColor(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.9)
            self:SetBackdropBorderColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.8)
        end)
        b:SetScript("OnLeave", function(self)
            self:SetBackdropColor(THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85)
            self:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.55)
        end)
        b:SetScript("OnClick", function()
            NavigateTo(def.key)
        end)

        b.label = l
        return b
    end

    for _, def in ipairs(quick) do
        table.insert(quickButtons, CreateQuickButton(def))
    end

    local function Layout()
        local w = tileContainer:GetWidth()
        if not w or w <= 0 then w = parent:GetWidth() - 36 end
        if not w or w <= 0 then w = 700 end

        local cols = 4
        local gap = 12
        local tileW = math.floor((w - gap * (cols - 1)) / cols)
        local tileH = 110

        for i, b in ipairs(tileButtons) do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            b:ClearAllPoints()
            b:SetSize(tileW, tileH)
            b:SetPoint("TOPLEFT", tileContainer, "TOPLEFT", col * (tileW + gap), -row * (tileH + gap))
        end

        local rows = math.ceil(#tileButtons / cols)
        tileContainer:SetHeight(rows * tileH + (rows - 1) * gap)

        -- Quick buttons layout
        local qw = quickContainer:GetWidth()
        if not qw or qw <= 0 then qw = w end
        local qcols = 4
        local qgap = 10
        local qbtnW = math.floor((qw - qgap * (qcols - 1)) / qcols)
        for i, b in ipairs(quickButtons) do
            local row = math.floor((i - 1) / qcols)
            local col = (i - 1) % qcols
            b:ClearAllPoints()
            b:SetWidth(qbtnW)
            b:SetPoint("TOPLEFT", quickContainer, "TOPLEFT", col * (qbtnW + qgap), -row * (26 + qgap))
        end
        local qrows = math.ceil(#quickButtons / qcols)
        quickContainer:SetHeight(qrows * 26 + (qrows - 1) * qgap)

        -- Expand parent height hint (scroll uses content height anyway)
        local total = 16 + 20 + 16 + tileContainer:GetHeight() + 20 + 26 + 10 + quickContainer:GetHeight() + 30
        if parent.SetHeight then
            parent:SetHeight(math.max(total, 650))
        end
    end

    parent:SetScript("OnShow", function()
        C_Timer.After(0, Layout)
    end)
    parent:SetScript("OnSizeChanged", function()
        C_Timer.After(0, Layout)
    end)
    C_Timer.After(0, Layout)
end

local function CreateBackdrop(parent, bgColor, borderColor)
    if not parent.SetBackdrop then
        if Mixin and BackdropTemplateMixin then
            Mixin(parent, BackdropTemplateMixin)
        else
            return
        end
    end
    
    local backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    }
    
    parent:SetBackdrop(backdrop)
    if bgColor then
        parent:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end
    if borderColor then
        parent:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end
end

-- Main Config Frame
local ConfigFrame = nil

-- Auto-close the config when leaving the world (e.g. swapping characters)
local _ConfigAutoCloseFrame = CreateFrame("Frame")
_ConfigAutoCloseFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
_ConfigAutoCloseFrame:SetScript("OnEvent", function()
    if ConfigFrame and ConfigFrame.Hide then
        ConfigFrame:Hide()
    end
    if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.ClickCast and LilyUI.PartyFrames.ClickCast.HideCaptureOverlay then
        LilyUI.PartyFrames.ClickCast:HideCaptureOverlay()
    end
end)


-- Tab system - vertical list style
local function CreateTabButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(20)
    btn:SetWidth(parent:GetWidth() - 4)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    btn:SetBackdropColor(0, 0, 0, 0)
    btn:SetBackdropBorderColor(0, 0, 0, 0)

    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0)

    local highlight = btn:CreateTexture(nil, "BORDER")
    highlight:SetPoint("TOPLEFT")
    highlight:SetPoint("BOTTOMRIGHT")
    highlight:SetColorTexture(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.35)
    highlight:Hide()

    local accentBar = btn:CreateTexture(nil, "ARTWORK")
    accentBar:SetWidth(2)
    accentBar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    accentBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    accentBar:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    accentBar:Hide()

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("LEFT", btn, "LEFT", 10, 0)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.85)

    btn:SetScript("OnEnter", function(self)
        if not self.active then
            self.background:SetColorTexture(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.25)
            self.highlight:Show()
            self.label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if not self.active then
            self.background:SetColorTexture(0, 0, 0, 0)
            self.highlight:Hide()
            self.label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.85)
        end
    end)

    btn:SetScript("OnClick", function(self)
        onClick(self)
    end)

    btn.label = label
    btn.active = false
    btn.background = background
    btn.highlight = highlight
    btn.accentBar = accentBar

    btn.SetActive = function(self, active)
        self.active = active
        if active then
            self.background:SetColorTexture(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.55)
            self.highlight:Show()
            self.accentBar:Show()
            self.label:SetTextColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
        else
            self.background:SetColorTexture(0, 0, 0, 0)
            self.highlight:Hide()
            self.accentBar:Hide()
            self.label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.85)
        end
    end

    return btn
end

local Widgets = {}

if not Widgets._dropdownScaleHooked then
    Widgets._dropdownScaleHooked = true
    hooksecurefunc("ToggleDropDownMenu", function(level, value, dropDownFrame, anchorName, xOffset, yOffset, menuList, button, autoHideDelay)
        if dropDownFrame and dropDownFrame._lilyUIDropdownScale then
            C_Timer.After(0.01, function()
                for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
                    local listFrame = _G["DropDownList" .. i]
                    if listFrame and listFrame:IsShown() and listFrame.dropdown == dropDownFrame then
                        listFrame:SetScale(dropDownFrame._lilyUIDropdownScale)
                        break
                    end
                end
            end)
        end
    end)
end

local function ResolveGetSet(method, optionsTable, option, ...)
    if not method then
        return nil
    end
    local info = {
        handler = optionsTable and optionsTable.handler,
        option = option,
        arg = option and option.arg,
    }
    
    if type(method) == "function" then
        return method(info, ...)
    elseif type(method) == "string" then
        local handler = optionsTable and optionsTable.handler
        if handler and handler[method] then
            return handler[method](handler, info, ...)
        end
    end
    return nil
end

local function ResolveDisabled(disabled, optionsTable, option)
    if not disabled then
        return false
    end
    if type(disabled) == "function" then
        local info = {
            handler = optionsTable and optionsTable.handler,
            option = option,
            arg = option and option.arg,
        }
        return disabled(info) == true
    elseif type(disabled) == "string" then
        local handler = optionsTable and optionsTable.handler
        if handler and handler[disabled] then
            local info = {
                handler = handler,
                option = option,
                arg = option and option.arg,
            }
            return handler[disabled](handler, info) == true
        end
    elseif disabled == true then
        return true
    end
    return false
end

function Widgets.CreateToggle(parent, option, yOffset, optionsTable)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(35)  -- Increased from 30 to 35 for better spacing
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    local name = option.name or ""
    if type(name) == "function" then
        name = name()
    end
    label:SetText(name)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)

    local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    checkbox:SetSize(24, 24)
    checkbox:SetPoint("RIGHT", frame, "RIGHT", 0, 0)

    local checkTexture = checkbox:GetCheckedTexture()
    if checkTexture then
        checkTexture:SetVertexColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
        checkTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end

    if option.get then
        local value = ResolveGetSet(option.get, optionsTable, option)
        checkbox:SetChecked(value or false)
    end
    
    checkbox:SetScript("OnClick", function(self)
        if option.set then
            ResolveGetSet(option.set, optionsTable, option, self:GetChecked())
        end
    end)
    
    -- Handle disabled state
    if option.disabled then
        local function UpdateDisabled()
            local disabled = ResolveDisabled(option.disabled, optionsTable, option)
            checkbox:SetEnabled(not disabled)
            if disabled then
                label:SetTextColor(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
            else
                label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)
            end
        end
        UpdateDisabled()
        frame.UpdateDisabled = UpdateDisabled
    end
    
    frame.Refresh = function(self)
        if option.get then
            local value = ResolveGetSet(option.get, optionsTable, option)
            checkbox:SetChecked(value or false)
        end
        if self.UpdateDisabled then
            self.UpdateDisabled()
        end
    end
    
    frame.checkbox = checkbox
    frame.label = label
    
    return frame
end

function Widgets.CreateRange(parent, option, yOffset, optionsTable)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(35)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    label:SetWidth(150)
    label:SetJustifyH("LEFT")
    local name = option.name or ""
    if type(name) == "function" then
        name = name()
    end
    label:SetText(name)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)

    local valueEditBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    valueEditBox:SetHeight(20)
    valueEditBox:SetWidth(60)
    valueEditBox:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    StyleEditBox(valueEditBox, "GameFontHighlight")
    valueEditBox:SetTextColor(1, 1, 1, 1)
    valueEditBox:SetAutoFocus(false)
    valueEditBox:SetJustifyH("CENTER")
    CreateBackdrop(valueEditBox, THEME.input, THEME.border)

    valueEditBox:EnableKeyboard(false)

    local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("LEFT", label, "RIGHT", 10, 0)
    slider:SetPoint("RIGHT", valueEditBox, "LEFT", -10, 0)
    slider:EnableMouse(true)
    
    local min = option.min or 0
    local max = option.max or 100
    local step = option.step or 1
    
    if option.get then
        local value = ResolveGetSet(option.get, optionsTable, option) or min
        value = math.max(min, math.min(max, value))
        value = math.floor((value + 0.5 * step) / step) * step
        
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(step)
        slider:SetValue(value)
        valueEditBox:SetText(string.format("%.2f", value))
    end
    
    local function UpdateValueFromEditBox()
        local text = valueEditBox:GetText()
        local numValue = tonumber(text)
        if numValue then
            numValue = math.max(min, math.min(max, numValue))
            numValue = math.floor((numValue + 0.5 * step) / step) * step
            slider:SetValue(numValue)
            valueEditBox:SetText(string.format("%.2f", numValue))
            if option.set then
                ResolveGetSet(option.set, optionsTable, option, numValue)
            end
        else
            local currentValue = slider:GetValue()
            valueEditBox:SetText(string.format("%.2f", currentValue))
        end
    end
    
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor((value + 0.5 * step) / step) * step
        value = math.max(min, math.min(max, value))
        valueEditBox:SetText(string.format("%.2f", value))
        if option.set then
            ResolveGetSet(option.set, optionsTable, option, value)
        end
    end)
    
    valueEditBox:SetScript("OnEditFocusGained", function(self)
        self:EnableKeyboard(true)
        self:HighlightText()
    end)
    
    valueEditBox:SetScript("OnEditFocusLost", function(self)
        self:EnableKeyboard(false)
        self:ClearFocus()
        UpdateValueFromEditBox()
    end)
    
    valueEditBox:SetScript("OnEnterPressed", function(self)
        self:EnableKeyboard(false)
        self:ClearFocus()
        UpdateValueFromEditBox()
    end)
    
    valueEditBox:SetScript("OnEscapePressed", function(self)
        local currentValue = slider:GetValue()
        self:SetText(tostring(currentValue))
        self:EnableKeyboard(false)
        self:ClearFocus()
    end)
    
    if option.disabled then
        local function UpdateDisabled()
            local disabled = ResolveDisabled(option.disabled, optionsTable, option)
            slider:SetEnabled(not disabled)
            valueEditBox:SetEnabled(not disabled)
            if disabled then
                label:SetTextColor(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
                valueEditBox:SetTextColor(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
            else
                label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)
                valueEditBox:SetTextColor(1, 1, 1, 1)
            end
        end
        UpdateDisabled()
        frame.UpdateDisabled = UpdateDisabled
    end
    
    frame.Refresh = function(self)
        if option.get then
            local min = option.min or 0
            local max = option.max or 100
            local step = option.step or 1
            local value = ResolveGetSet(option.get, optionsTable, option) or min
            value = math.max(min, math.min(max, value))
            value = math.floor((value + 0.5 * step) / step) * step
            slider:SetMinMaxValues(min, max)
            slider:SetValueStep(step)
            slider:SetValue(value)
            valueEditBox:SetText(string.format("%.2f", value))
        end
        if self.UpdateDisabled then
            self.UpdateDisabled()
        end
    end
    
    frame.slider = slider
    frame.label = label
    frame.valueEditBox = valueEditBox
    
    return frame
end

function Widgets.CreateSelect(parent, option, yOffset, optionsTable, optionKey, path)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(40)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    label:SetJustifyH("LEFT")
    -- Build info structure with path - needs to be accessible to name resolution
    local function BuildInfo()
        local info = {
            handler = optionsTable and optionsTable.handler,
            option = option,
            arg = option.arg,
            options = optionsTable,
        }
        if path then
            for i = 1, #path do
                info[i] = path[i]
            end
        end
        if optionKey then
            info[#info + 1] = optionKey
        end
        return info
    end
    
    local name = option.name or ""
    if type(name) == "function" then
        -- Create info structure for the name function (similar to AceConfig)
        local info = BuildInfo()
        -- Try calling with info structure
        local success, result = pcall(function()
            return name(info)
        end)
        if success and result then
            name = result
        else
            -- Fallback: try without info, or use a default
            success, result = pcall(function()
                return name()
            end)
            if success and result then
                name = result
            else
                name = optionKey or option.name or ""
            end
        end
    end
    label:SetText(name)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)

    local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    dropdown:SetWidth(150)
    
    local function ResolveMethod(method, useInfo)
        if not method then
            return nil
        end
        -- Use provided info or build new one
        local info = useInfo or BuildInfo()
        if type(method) == "function" then
            return method(info)
        elseif type(method) == "string" then
            local handler = optionsTable and optionsTable.handler
            if handler and handler[method] then
                return handler[method](handler, info)
            end
        end
        return nil
    end
    
    local function CallSetMethod(value)
        if not option.set then return end
        local info = BuildInfo()
        if type(option.set) == "function" then
            option.set(info, value)
        elseif type(option.set) == "string" then
            local handler = optionsTable and optionsTable.handler
            if handler and handler[option.set] then
                handler[option.set](handler, info, value)
            end
        end
    end
    
    
    local values = {}
    if option.values then
        local info = BuildInfo()
        if type(option.values) == "function" then
            values = option.values(info) or {}
        elseif type(option.values) == "string" then
            local handler = optionsTable and optionsTable.handler
            if handler and handler[option.values] then
                values = handler[option.values](handler, info) or {}
            end
        else
            values = option.values or {}
        end
    end
    
    local info = BuildInfo()
    local currentValue = ResolveMethod(option.get, info)

    local defaultText = "Select..."
    if currentValue and values[currentValue] then
        defaultText = values[currentValue]
    end
    dropdown:SetDefaultText(defaultText)

    dropdown:SetupMenu(function(dropdown, rootDescription)
        for key, value in pairs(values) do
            rootDescription:CreateButton(value, function()
                CallSetMethod(key)
                dropdown:SetDefaultText(value)
            end)
        end
    end)
    
    frame.dropdown = dropdown
    frame.label = label
    
    return frame
end

function Widgets.CreateColor(parent, option, yOffset, optionsTable)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(35)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("LEFT", frame, "LEFT", 0, 0)
    label:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)  -- Vertically center
    local name = option.name or ""
    if type(name) == "function" then
        name = name()
    end
    label:SetText(name)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)

    local colorButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    colorButton:SetSize(60, 22)
    colorButton:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    colorButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    CreateBackdrop(colorButton, THEME.bgDark, THEME.border)
    
    local colorSwatch = colorButton:CreateTexture(nil, "ARTWORK")
    colorSwatch:SetPoint("TOPLEFT", colorButton, "TOPLEFT", 2, -2)
    colorSwatch:SetPoint("BOTTOMRIGHT", colorButton, "BOTTOMRIGHT", -2, 2)
    
    local r, g, b, a = 1, 1, 1, 1
    if option.get then
        local info = {
            handler = optionsTable and optionsTable.handler,
            option = option,
            arg = option.arg,
        }
        local success
        if type(option.get) == "function" then
            success, r, g, b, a = pcall(option.get, info)
            if not success then r, g, b, a = 1, 1, 1, 1 end
        elseif type(option.get) == "string" then
            local handler = optionsTable and optionsTable.handler
            if handler and handler[option.get] then
                success, r, g, b, a = pcall(handler[option.get], handler, info)
                if not success then r, g, b, a = 1, 1, 1, 1 end
            end
        end
        r, g, b, a = r or 1, g or 1, b or 1, a or 1
    end
    colorSwatch:SetColorTexture(r, g, b, a or 1)
    
    colorButton:SetScript("OnClick", function(self)
        ColorPickerFrame:Hide()
        local previousValues = {r, g, b, a}
        
        if ColorPickerFrame.SetupColorPickerAndShow then
            local r2, g2, b2, a2 = r, g, b, (a or 1)
            local INVERTED_ALPHA = (WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE)
            if INVERTED_ALPHA then
                a2 = 1 - a2
            end
            
            local info = {
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    if INVERTED_ALPHA then
                        a = 1 - a
                    end
                    colorSwatch:SetColorTexture(r, g, b, a or 1)
                    if option.set then
                        ResolveGetSet(option.set, optionsTable, option, r, g, b, a)
                    end
                end,
                hasOpacity = option.hasAlpha or false,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    if INVERTED_ALPHA then
                        a = 1 - a
                    end
                    colorSwatch:SetColorTexture(r, g, b, a or 1)
                    if option.set then
                        ResolveGetSet(option.set, optionsTable, option, r, g, b, a)
                    end
                end,
                opacity = a2,
                cancelFunc = function()
                    r, g, b, a = unpack(previousValues)
                    colorSwatch:SetColorTexture(r, g, b, a or 1)
                end,
                r = r2,
                g = g2,
                b = b2,
            }
            
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            local colorPicker = ColorPickerFrame
            colorPicker.previousValues = previousValues
            
            colorPicker.func = function()
                if ColorPickerFrame.GetColorRGB then
                    r, g, b = ColorPickerFrame:GetColorRGB()
                else
                    r = ColorPickerFrame.r or r
                    g = ColorPickerFrame.g or g
                    b = ColorPickerFrame.b or b
                end
                if option.hasAlpha then
                    if OpacitySliderFrame and OpacitySliderFrame.GetValue then
                        a = OpacitySliderFrame:GetValue()
                    else
                        a = ColorPickerFrame.opacity or a
                    end
                end
                colorSwatch:SetColorTexture(r, g, b, a or 1)
                if option.set then
                    ResolveGetSet(option.set, optionsTable, option, r, g, b, a)
                end
            end
            
            colorPicker.hasOpacity = option.hasAlpha or false
            if option.hasAlpha then
                colorPicker.opacityFunc = function()
                    if ColorPickerFrame.GetColorRGB then
                        r, g, b = ColorPickerFrame:GetColorRGB()
                    else
                        r = ColorPickerFrame.r or r
                        g = ColorPickerFrame.g or g
                        b = ColorPickerFrame.b or b
                    end
                    if OpacitySliderFrame and OpacitySliderFrame.GetValue then
                        a = OpacitySliderFrame:GetValue()
                    else
                        a = ColorPickerFrame.opacity or a
                    end
                    colorSwatch:SetColorTexture(r, g, b, a or 1)
                    if option.set then
                        ResolveGetSet(option.set, optionsTable, option, r, g, b, a)
                    end
                end
                colorPicker.opacity = 1 - (a or 1)
            end
            
            if colorPicker.SetColorRGB then
                colorPicker:SetColorRGB(r, g, b)
            else
                colorPicker.r = r
                colorPicker.g = g
                colorPicker.b = b
            end
            
            colorPicker.cancelFunc = function()
                r, g, b, a = unpack(previousValues)
                colorSwatch:SetColorTexture(r, g, b, a or 1)
            end
            
            ColorPickerFrame:Show()
        end
    end)
    
    frame.colorButton = colorButton
    frame.colorSwatch = colorSwatch
    frame.label = label
    
    return frame
end

function Widgets.CreateExecute(parent, option, yOffset, optionsTable)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(32)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)

    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetHeight(28)
    button:SetWidth(200)
    button:SetPoint("LEFT", frame, "LEFT", 0, 0)

    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    button:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 1)
    button:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4] or 1)

    local glowLeft = button:CreateTexture(nil, "ARTWORK")
    glowLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    glowLeft:SetGradient("HORIZONTAL",
        CreateColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 1),
        CreateColor(THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3], 1))
    glowLeft:SetPoint("LEFT", button, "LEFT", 8, 0)
    glowLeft:SetPoint("RIGHT", button, "CENTER", 0, 0)
    glowLeft:SetPoint("TOP", button, "TOP", 0, -4)
    glowLeft:SetPoint("BOTTOM", button, "BOTTOM", 0, 4)
    glowLeft:Hide()

    local glowRight = button:CreateTexture(nil, "ARTWORK")
    glowRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    glowRight:SetGradient("HORIZONTAL",
        CreateColor(THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3], 1),
        CreateColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 1))
    glowRight:SetPoint("LEFT", button, "CENTER", 0, 0)
    glowRight:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    glowRight:SetPoint("TOP", button, "TOP", 0, -4)
    glowRight:SetPoint("BOTTOM", button, "BOTTOM", 0, 4)
    glowRight:Hide()

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("CENTER")
    local name = option.name or ""
    if type(name) == "function" then
        name = name()
    end
    label:SetText(name)
    label:SetTextColor(1, 1, 1, 1)

    button:SetScript("OnEnter", function(self)
        glowLeft:Show()
        glowRight:Show()
    end)

    button:SetScript("OnLeave", function(self)
        glowLeft:Hide()
        glowRight:Hide()
    end)
    
    button:SetScript("OnClick", function(self)
        if option.func then
            local info = {
                handler = optionsTable and optionsTable.handler,
                option = option,
                arg = option.arg,
            }
            if type(option.func) == "function" then
                option.func(info)
            elseif type(option.func) == "string" then
                local handler = optionsTable and optionsTable.handler
                if handler and handler[option.func] then
                    handler[option.func](handler, info)
                end
            end
        end
    end)
    
    frame.button = button
    frame.label = label
    
    return frame
end

function Widgets.CreateInput(parent, option, yOffset, optionsTable)
    local isMultiline = option.multiline or false
    local frame = CreateFrame("Frame", nil, parent)
    
    if isMultiline then
        frame:SetHeight(150)
    else
        frame:SetHeight(30)
    end
    
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    local name = option.name or ""
    if type(name) == "function" then
        name = name()
    end
    label:SetText(name)
    label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.95)

        if isMultiline then
        -- Create container frame with backdrop (the black box background)
        local scrollContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        scrollContainer:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        scrollContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 0)
        scrollContainer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        scrollContainer:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
        scrollContainer:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 4, -4)
        scrollFrame:SetPoint("BOTTOMRIGHT", -22, 4)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        editBox:SetWidth(scrollFrame:GetWidth() - 20)
        editBox:SetHeight(120)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        scrollFrame:SetScrollChild(editBox)
        
        -- Make the container and scroll frame clickable to focus and highlight the EditBox
        local function FocusAndHighlight()
            editBox:SetFocus()
            editBox:HighlightText()
        end
        
        scrollContainer:EnableMouse(true)
        scrollContainer:SetScript("OnMouseDown", FocusAndHighlight)
        scrollFrame:EnableMouse(true)
        scrollFrame:SetScript("OnMouseDown", FocusAndHighlight)
        
        -- Also highlight when EditBox gains focus (for direct clicks on the EditBox)
        editBox:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
        end)

        if option.get then
            local text = ResolveGetSet(option.get, optionsTable, option) or ""
            editBox:SetText(text)
            editBox:SetCursorPosition(0)
            editBox:ClearFocus()
        end
        
        editBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput and option.set then
                ResolveGetSet(option.set, optionsTable, option, self:GetText())
            end
            local text = self:GetText()
            local lines = select(2, text:gsub("\n", "\n"))
            local height = math.max(120, (lines + 1) * 14)
            self:SetHeight(height)
        end)
        
        editBox:ClearFocus()
        
        frame.editBox = editBox
        frame.scrollFrame = scrollFrame
        frame.scrollContainer = scrollContainer
    else
        local editBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
        editBox:SetHeight(24)
        editBox:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        editBox:SetWidth(200)
        StyleEditBox(editBox, "GameFontNormal")
        editBox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        CreateBackdrop(editBox, THEME.input, THEME.border)
        
        editBox:EnableKeyboard(false)
        
        if option.get then
            local text = ResolveGetSet(option.get, optionsTable, option) or ""
            editBox:SetText(text)
            editBox:ClearFocus()
        end
        
        editBox:SetScript("OnEditFocusGained", function(self)
            self:EnableKeyboard(true)
            self:SetCursorPosition(string.len(self:GetText()))
            -- Add visual feedback for focus
            CreateBackdrop(self, THEME.input, THEME.accent)
        end)

        editBox:SetScript("OnEditFocusLost", function(self)
            self:EnableKeyboard(false)
            self:ClearFocus()
            -- Remove visual feedback for focus
            CreateBackdrop(self, THEME.input, THEME.border)
        end)

        editBox:SetScript("OnEnter", function(self)
        end)

        editBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput and option.set then
                ResolveGetSet(option.set, optionsTable, option, self:GetText())
            end
        end)
        
        editBox:SetScript("OnEnterPressed", function(self)
            self:EnableKeyboard(false)
            self:ClearFocus()
        end)
        
        editBox:ClearFocus()
        
        frame.editBox = editBox
    end
    
    frame.label = label
    
    if option.desc then
        local desc = option.desc
        if type(desc) == "function" then
            desc = desc()
        end
        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(desc, nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
    end
    
    return frame
end

function Widgets.CreateHeader(parent, option, yOffset)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    StyleFontString(label)
    -- Ensure we use global font with custom size for headers
    local globalFontPath = LilyUI:GetGlobalFont()
    local currentFont, _, flags = label:GetFont()
    flags = flags or "OUTLINE"
    if globalFontPath then
        label:SetFont(globalFontPath, 20, flags)
    elseif currentFont then
        label:SetFont(currentFont, 20, flags)
    end
    label:SetPoint("LEFT", frame, "LEFT", 0, 2)
    label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(true)
    local name = option.name or ""
    if type(name) == "function" then
        name = name()
    end
    label:SetText(name)
    label:SetTextColor(1.0, 1.0, 1.0, 1)

    local labelHeight = label:GetStringHeight() or 20
    frame:SetHeight(math.max(32, labelHeight + 8))

    local borderLeft = frame:CreateTexture(nil, "ARTWORK")
    borderLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    borderLeft:SetGradient("HORIZONTAL",
        CreateColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0),
        CreateColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.9))
    borderLeft:SetHeight(1)
    borderLeft:SetWidth(60)
    borderLeft:SetPoint("LEFT", frame, "BOTTOMLEFT", 0, 0)

    local borderCenter = frame:CreateTexture(nil, "ARTWORK")
    borderCenter:SetColorTexture(THEME.accent[1], THEME.accent[2], THEME.accent[3], 1)
    borderCenter:SetHeight(1)
    borderCenter:SetPoint("LEFT", borderLeft, "RIGHT", 0, 0)
    borderCenter:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -60, 0)

    local borderRight = frame:CreateTexture(nil, "ARTWORK")
    borderRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    borderRight:SetGradient("HORIZONTAL",
        CreateColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0.9),
        CreateColor(THEME.accent[1], THEME.accent[2], THEME.accent[3], 0))
    borderRight:SetHeight(1)
    borderRight:SetWidth(60)
    borderRight:SetPoint("RIGHT", frame, "BOTTOMRIGHT", 0, 0)

    frame.label = label

    return frame
end

function Widgets.CreateDescription(parent, option, yOffset, optionsTable)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -yOffset)
    frame:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
    
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(label)
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    
    local name = option.name or ""
    if type(name) == "function" then
        local info = {
            handler = optionsTable and optionsTable.handler,
            option = option,
            arg = option.arg,
        }
            local success, result = pcall(name, info)
            if success then
                name = result or ""
            else
                success, result = pcall(name)
                if success then
                    name = result or ""
                else
                    name = ""
                end
            end
        end
    label:SetText(name)
    label:SetTextColor(THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
    
    frame:SetHeight(label:GetStringHeight() + 10)
    frame.label = label
    
    return frame
end

local function RenderOptions(contentFrame, options, path, parentFrame)
    path = path or {}
    parentFrame = parentFrame or contentFrame:GetParent():GetParent()

    -- Make sure the ClickCast UI doesn't linger when navigating between
    -- option categories/tabs.
    if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.ClickCast and LilyUI.PartyFrames.ClickCast.CloseClickCastUI then
        LilyUI.PartyFrames.ClickCast:CloseClickCastUI()
    end
    
    if contentFrame.subScrollChild then
        if contentFrame.subScrollChild.widgets then
            for i = #contentFrame.subScrollChild.widgets, 1, -1 do
                local widget = contentFrame.subScrollChild.widgets[i]
                if widget then
                    widget:Hide()
                    widget:SetParent(nil)
                end
            end
            contentFrame.subScrollChild.widgets = {}
        end
        contentFrame.subScrollChild = nil
    end
    if contentFrame.subTabContainer then
        contentFrame.subTabContainer:Hide()
        contentFrame.subTabContainer:SetParent(nil)
        contentFrame.subTabContainer = nil
    end
    if contentFrame.subContentArea then
        contentFrame.subContentArea:Hide()
        contentFrame.subContentArea:SetParent(nil)
        contentFrame.subContentArea = nil
    end
    if contentFrame.subTabButtons then
        for _, btn in ipairs(contentFrame.subTabButtons) do
            if btn then
                btn:Hide()
                btn:SetParent(nil)
            end
        end
        contentFrame.subTabButtons = nil
    end
    
    if contentFrame.widgets then
        for i = #contentFrame.widgets, 1, -1 do
            local widget = contentFrame.widgets[i]
            if widget then
                widget:Hide()
                widget:SetParent(nil)
            end
        end
    end
    contentFrame.widgets = {}
    
    if options.childGroups == "tab" then
        -- Get the parent frame's content area and scroll frame to make tabs sticky
        local parentContentArea = parentFrame and parentFrame.contentArea
        local parentScrollFrame = parentFrame and parentFrame.scrollFrame
        
        -- Check if we're in a nested tab situation (sub-sub tabs)
        -- Look for parent sub tab containers to calculate offset
        local cumulativeTabHeight = 0
        local parentSubTabContainer = nil
        
        -- When nested, contentFrame is a subScrollChild, whose parent is subContentArea,
        -- whose parent is the parent contentFrame that has the subTabContainer
        local parentFrame = contentFrame:GetParent()
        if parentFrame then
            local grandParentFrame = parentFrame:GetParent()
            if grandParentFrame and grandParentFrame.subTabContainer then
                -- Found parent sub tab container
                parentSubTabContainer = grandParentFrame.subTabContainer
                cumulativeTabHeight = cumulativeTabHeight + (grandParentFrame._subTabContainerHeight or 35)
            elseif parentFrame.subTabContainer then
                -- Parent frame itself has sub tab container
                parentSubTabContainer = parentFrame.subTabContainer
                cumulativeTabHeight = cumulativeTabHeight + (parentFrame._subTabContainerHeight or 35)
            end
        end

        -- Create sub tab container as child of contentArea (not scrollChild) so it stays fixed
        local subTabContainer = CreateFrame("Frame", nil, parentContentArea or contentFrame, "BackdropTemplate")
        subTabContainer:SetHeight(35)
        subTabContainer:SetFrameStrata("HIGH")
        subTabContainer:SetFrameLevel((parentScrollFrame and parentScrollFrame:GetFrameLevel() or 1) + 10)
        
        -- Add background to make it look good when sticky
        local bgMediumTransparent = {THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], 0.95}
        CreateBackdrop(subTabContainer, bgMediumTransparent, THEME.border)
        
        if parentContentArea and parentScrollFrame then
            if parentSubTabContainer then
                -- Nested tabs: position below parent sub tab container
                subTabContainer:SetPoint("TOPLEFT", parentSubTabContainer, "BOTTOMLEFT", 0, 0)
                subTabContainer:SetPoint("TOPRIGHT", parentSubTabContainer, "BOTTOMRIGHT", 0, 0)
            else
                -- Top-level sub tabs: position relative to scroll frame's viewport (sticky at top)
                subTabContainer:SetPoint("TOPLEFT", parentScrollFrame, "TOPLEFT", 0, 0)
                subTabContainer:SetPoint("TOPRIGHT", parentScrollFrame, "TOPRIGHT", 0, 0)
            end
        else
            -- Fallback to original positioning if parent info not available
            if parentSubTabContainer then
                subTabContainer:SetPoint("TOPLEFT", parentSubTabContainer, "BOTTOMLEFT", 0, 0)
                subTabContainer:SetPoint("TOPRIGHT", parentSubTabContainer, "BOTTOMRIGHT", 0, 0)
            else
                subTabContainer:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
                subTabContainer:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, 0)
            end
        end

        local subContentArea = CreateFrame("Frame", nil, contentFrame)
        -- Position normally - content starts at top, tab container overlays it
        local tabContainerHeight = 35
        subContentArea:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -1)
        subContentArea:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
        
        -- Store tab container height for height calculations
        contentFrame._subTabContainerHeight = tabContainerHeight
        -- Store cumulative height for nested tabs
        contentFrame._cumulativeTabHeight = cumulativeTabHeight + tabContainerHeight
        
        local subScrollChild = CreateFrame("Frame", nil, subContentArea)
        -- Position normally - content will start below tab container via yOffset
        subScrollChild:SetPoint("TOPLEFT", subContentArea, "TOPLEFT", 10, -10)
        subScrollChild:SetPoint("RIGHT", subContentArea, "RIGHT", -10, 0)
        subScrollChild.widgets = {}
        -- Store tab container height so RenderOptions can account for it
        subScrollChild._tabContainerHeight = contentFrame._cumulativeTabHeight or (contentFrame._subTabContainerHeight or 35)
        
        local sortedTabs = {}
        for key, option in pairs(options.args or {}) do
            if option.type == "group" or (option.type ~= "group" and option.type ~= "header" and option.type ~= "description") then
                table.insert(sortedTabs, {key = key, option = option, order = option.order or 999})
            end
        end
        table.sort(sortedTabs, function(a, b) return a.order < b.order end)
        
        local subTabButtons = {}
        local tabX = 5
        
        for i, item in ipairs(sortedTabs) do
            local displayName = item.option.name or item.key
            if type(displayName) == "function" then
                displayName = displayName()
            end
            
            local subTabBtn = CreateTabButton(subTabContainer, displayName, function(btn)
                for _, t in ipairs(subTabButtons) do
                    t:SetActive(false)
                end
                btn:SetActive(true)

                GUIDebug("[GUI] Subtab selected: %s", tostring(displayName))
                RenderOptions(subScrollChild, item.option, path, parentFrame)
                
                -- Update content frame height after rendering sub-tab content
                if contentFrame._updateSubTabHeight then
                    C_Timer.After(0.01, contentFrame._updateSubTabHeight)
                end
            end)
            subTabBtn:SetPoint("LEFT", subTabContainer, "LEFT", tabX, 0)

            local textWidth = subTabBtn.label:GetStringWidth()
            local buttonWidth = textWidth + 20
            subTabBtn:SetWidth(buttonWidth)
            tabX = tabX + buttonWidth + 5
            
            table.insert(subTabButtons, subTabBtn)
        end
        
        if #subTabButtons > 0 then
            subTabButtons[1]:SetActive(true)
            GUIDebug("[GUI] Subtab selected: %s", tostring(sortedTabs[1].option and sortedTabs[1].option.name or sortedTabs[1].key))
            RenderOptions(subScrollChild, sortedTabs[1].option, path, parentFrame)
            
            -- Update content frame height after initial render
            if contentFrame._updateSubTabHeight then
                C_Timer.After(0.01, contentFrame._updateSubTabHeight)
            end
        end
        
        contentFrame.subTabContainer = subTabContainer
        contentFrame.subContentArea = subContentArea
        contentFrame.subTabButtons = subTabButtons
        contentFrame.subScrollChild = subScrollChild
        
        -- Update scroll child height to account for tab container
        -- This will be called after sub-tab content is rendered
        contentFrame._updateSubTabHeight = function()
            if subScrollChild then
                local subContentHeight = subScrollChild:GetHeight() or 100
                local tabContainerHeight = contentFrame._subTabContainerHeight or 35
                -- Content frame needs to be tall enough for tab container + content + padding
                local minHeight = subContentHeight + tabContainerHeight + 20
                if contentFrame.scrollFrame then
                    contentFrame:SetHeight(math.max(minHeight, contentFrame.scrollFrame:GetHeight() + 20))
                elseif contentFrame:GetParent() and contentFrame:GetParent():GetObjectType() == "ScrollFrame" then
                    contentFrame:SetHeight(math.max(minHeight, 100))
                end
            end
        end
        
        return
    end
    
    local sortedOptions = {}
    for key, option in pairs(options.args or {}) do
        table.insert(sortedOptions, {key = key, option = option, order = option.order or 999})
    end
    table.sort(sortedOptions, function(a, b) return a.order < b.order end)
    
    -- Start yOffset accounting for sticky tab container if present
    local yOffset = 15
    if contentFrame._tabContainerHeight then
        yOffset = yOffset + contentFrame._tabContainerHeight
    end
    local widgetHeight = 0

    for _, item in ipairs(sortedOptions) do
        local key = item.key
        local option = item.option

        local isDisabled = ResolveDisabled(option.disabled, options, option)
        if not isDisabled then
            local widget = nil

            if option.type == "toggle" then
                widget = Widgets.CreateToggle(contentFrame, option, yOffset, options)
                widgetHeight = 35
            elseif option.type == "range" then
                widget = Widgets.CreateRange(contentFrame, option, yOffset, options)
                widgetHeight = 35
            elseif option.type == "select" then
                -- Build path for info structure
                local currentPath = {}
                if path then
                    for i = 1, #path do
                        currentPath[i] = path[i]
                    end
                end
                currentPath[#currentPath + 1] = key
                widget = Widgets.CreateSelect(contentFrame, option, yOffset, options, key, currentPath)
                widgetHeight = 40
            elseif option.type == "color" then
                widget = Widgets.CreateColor(contentFrame, option, yOffset, options)
                widgetHeight = 35
            elseif option.type == "execute" then
                widget = Widgets.CreateExecute(contentFrame, option, yOffset)
                widgetHeight = 32

elseif option.type == "landingPage" then
    local embed = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
    embed:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
    embed:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
    embed:SetWidth(contentFrame:GetWidth() or 600)
    embed:SetHeight(650)

    BuildLandingPageUI(embed, parentFrame)

    widget = embed
    widgetHeight = embed:GetHeight() or 650
            elseif option.type == "dynamicIcons" then
                if LilyUI and LilyUI.CustomIcons and LilyUI.CustomIcons.BuildDynamicIconsUI then
                    local dynFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
                    dynFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                    dynFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
                    LilyUI.CustomIcons:BuildDynamicIconsUI(dynFrame)
                    widget = dynFrame
                    widgetHeight = dynFrame:GetHeight() or 400
                end
            elseif option.type == "iconCustomization" then
                if LilyUI and LilyUI.IconCustomization and LilyUI.IconCustomization.BuildIconCustomizationUI then
                    local iconFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
                    iconFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                    iconFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", 0, 0)
                    LilyUI.IconCustomization:BuildIconCustomizationUI(iconFrame)
                    widget = iconFrame
                    widgetHeight = iconFrame:GetHeight() or 400
                end
            elseif option.type == "partyRaidFramesPage" then
                local embed = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
                embed:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                embed:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                embed:SetWidth(contentFrame:GetWidth() or 600)
                embed:SetHeight(contentFrame:GetHeight() or 600)

                local mode = option.mode or "party"
                if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.RenderOptionsPage then
                    LilyUI.PartyFrames:RenderOptionsPage(embed, mode, option.builder)
                end

                widget = embed
                widgetHeight = embed:GetHeight() or 600
            elseif option.type == "clickCastingPage" then
                local embed = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
                embed:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                embed:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                embed:SetWidth(contentFrame:GetWidth() or 600)
                embed:SetHeight(600)

                if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.ClickCast and LilyUI.PartyFrames.ClickCast.CreateClickCastUI then
                    local defaultTab = option.defaultTab or "spells"
                    LilyUI.PartyFrames.ClickCast:CreateClickCastUI(embed, defaultTab)
                end

                widget = embed
                widgetHeight = embed:GetHeight() or 600
            elseif option.type == "auraListsPage" then
                local embed = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
                embed:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
                embed:SetPoint("RIGHT", contentFrame, "RIGHT", 0, 0)
                embed:SetWidth(contentFrame:GetWidth() or 600)
                embed:SetHeight(600)

                if LilyUI and LilyUI.PartyFrames and LilyUI.PartyFrames.CreateAuraListsUI then
                    if LilyUI and LilyUI.DebugWindowLog then
                        LilyUI:DebugWindowLog("System", "[GUI] [WL/BL] Subtab selected")
                    end
                    local mode = option.mode or "party"
                    LilyUI.PartyFrames:CreateAuraListsUI(embed, mode)
                end

                widget = embed
                widgetHeight = embed:GetHeight() or 600
            elseif option.type == "input" then
                widget = Widgets.CreateInput(contentFrame, option, yOffset, options)
                widgetHeight = option.multiline and 150 or 35
            elseif option.type == "header" then
                widget = Widgets.CreateHeader(contentFrame, option, yOffset)
                widgetHeight = widget:GetHeight() or 32
            elseif option.type == "description" then
                widget = Widgets.CreateDescription(contentFrame, option, yOffset, options)
                widgetHeight = widget:GetHeight()
            elseif option.type == "group" and option.inline then
                local groupName = option.name or ""
                if type(groupName) == "function" then
                    groupName = groupName()
                end
                
                local groupFrame = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
                groupFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -yOffset)
                groupFrame:SetPoint("RIGHT", contentFrame, "RIGHT", -10, 0)
                CreateBackdrop(groupFrame, THEME.bgMedium, THEME.border)
                
                local groupTitle = groupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                StyleFontString(groupTitle)
                groupTitle:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", 10, -8)
                groupTitle:SetText(groupName)
                groupTitle:SetTextColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 1)
                
                local inlineYOffset = 35
                local inlineSorted = {}
                for k, v in pairs(option.args or {}) do
                    table.insert(inlineSorted, {key = k, option = v, order = v.order or 999})
                end
                table.sort(inlineSorted, function(a, b) return a.order < b.order end)
                
                for _, inlineItem in ipairs(inlineSorted) do
                    -- Skip if disabled
                    local inlineDisabled = ResolveDisabled(inlineItem.option.disabled, options, inlineItem.option)
                    if not inlineDisabled then
                        local inlineWidget = nil
                        local inlineHeight = 0
                        
                        if inlineItem.option.type == "toggle" then
                            inlineWidget = Widgets.CreateToggle(groupFrame, inlineItem.option, inlineYOffset, options)
                            inlineHeight = 35
                        elseif inlineItem.option.type == "range" then
                            inlineWidget = Widgets.CreateRange(groupFrame, inlineItem.option, inlineYOffset, options)
                            inlineHeight = 35
                        elseif inlineItem.option.type == "select" then
                            -- Build path for info structure (for inline groups, path is just the key)
                            local inlinePath = {inlineItem.key}
                            inlineWidget = Widgets.CreateSelect(groupFrame, inlineItem.option, inlineYOffset, options, inlineItem.key, inlinePath)
                            inlineHeight = 40
                        elseif inlineItem.option.type == "color" then
                            inlineWidget = Widgets.CreateColor(groupFrame, inlineItem.option, inlineYOffset, options)
                            inlineHeight = 35
                        elseif inlineItem.option.type == "execute" then
                            inlineWidget = Widgets.CreateExecute(groupFrame, inlineItem.option, inlineYOffset)
                            inlineHeight = 32
                        elseif inlineItem.option.type == "input" then
                            inlineWidget = Widgets.CreateInput(groupFrame, inlineItem.option, inlineYOffset, options)
                            inlineHeight = inlineItem.option.multiline and 150 or 35
                        elseif inlineItem.option.type == "header" then
                            inlineWidget = Widgets.CreateHeader(groupFrame, inlineItem.option, inlineYOffset)
                            inlineHeight = inlineWidget:GetHeight() or 32
                        elseif inlineItem.option.type == "description" then
                            inlineWidget = Widgets.CreateDescription(groupFrame, inlineItem.option, inlineYOffset, options)
                            inlineHeight = inlineWidget:GetHeight() + 5  -- Add extra spacing
                        elseif inlineItem.option.type == "group" and inlineItem.option.inline then
                            -- Nested inline group - render recursively
                            local nestedGroupName = inlineItem.option.name or ""
                            if type(nestedGroupName) == "function" then
                                nestedGroupName = nestedGroupName()
                            end
                            
                            -- Create nested container frame
                            local nestedGroupFrame = CreateFrame("Frame", nil, groupFrame, "BackdropTemplate")
                            nestedGroupFrame:SetPoint("TOPLEFT", groupFrame, "TOPLEFT", 10, -inlineYOffset)
                            nestedGroupFrame:SetPoint("RIGHT", groupFrame, "RIGHT", -10, 0)
                            CreateBackdrop(nestedGroupFrame, THEME.bgDark, THEME.border)
                            
                            -- Nested group title
                            local nestedGroupTitle = nestedGroupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                            StyleFontString(nestedGroupTitle)
                            nestedGroupTitle:SetPoint("TOPLEFT", nestedGroupFrame, "TOPLEFT", 10, -8)
                            nestedGroupTitle:SetText(nestedGroupName)
                            nestedGroupTitle:SetTextColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 1)
                            
                            -- Render nested inline group options
                            local nestedYOffset = 35
                            local nestedSorted = {}
                            for k, v in pairs(inlineItem.option.args or {}) do
                                table.insert(nestedSorted, {key = k, option = v, order = v.order or 999})
                            end
                            table.sort(nestedSorted, function(a, b) return a.order < b.order end)
                            
                            for _, nestedItem in ipairs(nestedSorted) do
                                local nestedDisabled = ResolveDisabled(nestedItem.option.disabled, options, nestedItem.option)
                                if not nestedDisabled then
                                    local nestedWidget = nil
                                    local nestedHeight = 0
                                    
                                    if nestedItem.option.type == "toggle" then
                                        nestedWidget = Widgets.CreateToggle(nestedGroupFrame, nestedItem.option, nestedYOffset, options)
                                        nestedHeight = 35
                                    elseif nestedItem.option.type == "range" then
                                        nestedWidget = Widgets.CreateRange(nestedGroupFrame, nestedItem.option, nestedYOffset, options)
                                        nestedHeight = 35
                                    elseif nestedItem.option.type == "select" then
                                        -- Build path for info structure (for nested groups, path is just the key)
                                        local nestedPath = {nestedItem.key}
                                        nestedWidget = Widgets.CreateSelect(nestedGroupFrame, nestedItem.option, nestedYOffset, options, nestedItem.key, nestedPath)
                                        nestedHeight = 40
                                    elseif nestedItem.option.type == "color" then
                                        nestedWidget = Widgets.CreateColor(nestedGroupFrame, nestedItem.option, nestedYOffset, options)
                                        nestedHeight = 35
                                    elseif nestedItem.option.type == "execute" then
                                        nestedWidget = Widgets.CreateExecute(nestedGroupFrame, nestedItem.option, nestedYOffset)
                                        nestedHeight = 32
                                    elseif nestedItem.option.type == "input" then
                                        nestedWidget = Widgets.CreateInput(nestedGroupFrame, nestedItem.option, nestedYOffset, options)
                                        nestedHeight = nestedItem.option.multiline and 150 or 35
                                    elseif nestedItem.option.type == "header" then
                                        nestedWidget = Widgets.CreateHeader(nestedGroupFrame, nestedItem.option, nestedYOffset)
                                        nestedHeight = nestedWidget:GetHeight() or 32
                                    elseif nestedItem.option.type == "description" then
                                        nestedWidget = Widgets.CreateDescription(nestedGroupFrame, nestedItem.option, nestedYOffset, options)
                                        nestedHeight = nestedWidget:GetHeight() + 5
                                    end
                                    
                                    if nestedWidget then
                                        nestedWidget:SetParent(nestedGroupFrame)
                                        nestedWidget:Show()
                                        table.insert(contentFrame.widgets, nestedWidget)
                                        nestedYOffset = nestedYOffset + nestedHeight + 15
                                    end
                                end
                            end
                            
                            nestedGroupFrame:SetHeight(nestedYOffset + 10)
                            nestedGroupFrame:Show()
                            table.insert(contentFrame.widgets, nestedGroupFrame)
                            inlineWidget = nestedGroupFrame
                            inlineHeight = nestedYOffset + 10
                        end
                        
                        if inlineWidget then
                            inlineWidget:SetParent(groupFrame)
                            inlineWidget:Show()
                            table.insert(contentFrame.widgets, inlineWidget)
                            inlineYOffset = inlineYOffset + inlineHeight + 18  -- Increased spacing from 12 to 18 for better separation
                        end
                    end
                end
                
                groupFrame:SetHeight(inlineYOffset + 10)
                groupFrame:Show()
                table.insert(contentFrame.widgets, groupFrame)
                widgetHeight = inlineYOffset + 10
            end
            
            if widget then
                widget:SetParent(contentFrame)
                widget:Show()
                table.insert(contentFrame.widgets, widget)
                yOffset = yOffset + widgetHeight + 15  -- Increased spacing from 10 to 15
            end
        end
    end


    -- Update scroll frame
    if contentFrame.scrollFrame then
        contentFrame.scrollFrame:SetScrollChild(contentFrame)
        contentFrame:SetHeight(math.max(yOffset, contentFrame.scrollFrame:GetHeight() + 20))
    elseif contentFrame:GetParent() and contentFrame:GetParent():GetObjectType() == "ScrollFrame" then
        -- If parent is a scroll frame, update height
        contentFrame:SetHeight(math.max(yOffset, 100))
    elseif yOffset > 0 then
        -- Fallback: always set height if we have content (for subScrollChild, etc.)
        contentFrame:SetHeight(math.max(yOffset, 100))
    end
end

-- Create main config frame
function LilyUI:CreateConfigFrame()
    -- Always destroy and recreate the frame to ensure we have latest version
    -- This prevents issues with cached frames from previous reloads
    if ConfigFrame then
        ConfigFrame:Hide()
        ConfigFrame:ClearAllPoints()
        -- Release all children
        local children = {ConfigFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:SetParent(nil)
            child:Hide()
        end
        ConfigFrame:SetParent(nil)
        ConfigFrame = nil
    end
    
    -- Also clear global reference
    local globalFrame = _G["LilyUI_ConfigFrame"]
    if globalFrame and globalFrame ~= ConfigFrame then
        globalFrame:Hide()
        globalFrame:ClearAllPoints()
        local children = {globalFrame:GetChildren()}
        for _, child in ipairs(children) do
            child:SetParent(nil)
            child:Hide()
        end
        globalFrame:SetParent(nil)
        _G["LilyUI_ConfigFrame"] = nil
    end
    
    -- Main frame
    local frame = CreateFrame("Frame", "LilyUI_ConfigFrame", UIParent, "BackdropTemplate")
    frame:SetSize(950, 750)  -- Slightly wider to accommodate sidebar
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

-- Config window backdrop style (flat vs art)
local backdropStyle = (self.GetUIBackdropStyle and self:GetUIBackdropStyle()) or "Default"
local bgColorSolid = {THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.30}

if backdropStyle == "VoidPurple" then
    -- Border only; background handled by a full-frame texture
    CreateBackdrop(frame, {0, 0, 0, 0}, THEME.border)

    local bgTex = frame:CreateTexture(nil, "BACKGROUND")
    bgTex:SetDrawLayer("BACKGROUND", -8)
    bgTex:SetAllPoints()
    bgTex:SetTexture("Interface\\AddOns\\lilyUI\\Media\\Backdrops\\VoidPurple.tga")
    bgTex:SetAlpha(0.85)
    frame._uiBackdropTex = bgTex

    -- Subtle dark vignette to keep content readable
    local vignette = frame:CreateTexture(nil, "BORDER")
    vignette:SetDrawLayer("BORDER", -7)
    vignette:SetAllPoints()
    vignette:SetTexture("Interface\\Buttons\\WHITE8x8")
    SetTextureGradientAlpha(vignette, "VERTICAL", 0, 0, 0, 0.35, 0, 0, 0, 0.05)
    frame._uiBackdropVignette = vignette
else
    CreateBackdrop(frame, bgColorSolid, THEME.border)
end

    
    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetHeight(35)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local titleBarColor = {THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], (backdropStyle == "VoidPurple" and 0.30 or 0.45)}
    CreateBackdrop(titleBar, titleBarColor, THEME.border)
    
    -- Get version from .toc file
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"
    
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    StyleFontString(title)
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetText("LilyUI - v" .. version)
    title:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
    
    -- Store title reference on frame for debugging
    frame.titleText = title
    
    -- Close button (modern Dragonflight style)
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -5, 0)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    
    -- Helper function to create title bar buttons
    local function CreateTitleButton(text, onClick, tooltip)
        local btn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
        btn:SetHeight(25)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        btn:SetBackdropColor(THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], 0.85)
        btn:SetBackdropBorderColor(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], THEME.borderLight[4] or 1)
        
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        StyleFontString(label)
        label:SetPoint("CENTER")
        label:SetText(text)
        label:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 1)
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3], 0.9)
            if tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                GameTooltip:Show()
            end
        end)
        
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], 0.85)
            GameTooltip:Hide()
        end)
        
        btn:SetScript("OnClick", onClick)
        
        btn.label = label
        return btn
    end
    
    -- Create vertical center line for anchor mode
    local centerLine = CreateFrame("Frame", "LilyUI_CenterLine", UIParent, "BackdropTemplate")
    centerLine:SetWidth(2)
    centerLine:SetPoint("TOP", UIParent, "TOP", 0, 0)
    centerLine:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
    centerLine:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    centerLine:SetFrameStrata("HIGH")
    centerLine:SetFrameLevel(1000)
    centerLine:Hide()
    
    -- Set backdrop for the line
    centerLine:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
    })
    centerLine:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.6)
    
    -- Function to update center line visibility and position
    -- Made globally accessible so other modules can call it
    function LilyUI.UpdateCenterLine()
        local centerLine = _G["LilyUI_CenterLine"]
        if not centerLine then return end
        
        local unitFramesAnchorsEnabled = LilyUI.db.profile.unitFrames and 
                                         LilyUI.db.profile.unitFrames.General and 
                                         LilyUI.db.profile.unitFrames.General.ShowEditModeAnchors
        
        if unitFramesAnchorsEnabled then
            centerLine:Show()
            -- Update position in case UIParent size changed
            centerLine:ClearAllPoints()
            centerLine:SetPoint("TOP", UIParent, "TOP", 0, 0)
            centerLine:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
            centerLine:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        else
            centerLine:Hide()
        end
    end
    
    -- Disable Anchors button (rightmost, positioned before close button)
    -- Controls unit frame, party frame, and raid frame anchors
    local disableAnchorsBtn = CreateTitleButton("Disable Anchors", function()
        -- Disable unit frame anchors
        local db = LilyUI.db.profile.unitFrames
        if not db then
            db = {}
            LilyUI.db.profile.unitFrames = db
        end
        if not db.General then db.General = {} end
        db.General.ShowEditModeAnchors = false
        if LilyUI.UnitFrames then
            LilyUI.UnitFrames:UpdateEditModeAnchors()
            LilyUI.UnitFrames:HideBossFramesPreview()
        end

        -- Disable party and raid frame anchors
        local NUF = LilyUI.PartyFrames
        if NUF then
            if NUF.LockFrames then NUF:LockFrames() end
            if NUF.LockRaidFrames then NUF:LockRaidFrames() end
        end

        -- Disable test mode
        if NUF and NUF.DisableTestMode then
            NUF:DisableTestMode()
        end

        -- Hide center line
        LilyUI.UpdateCenterLine()

        print("|cff00ff00[LilyUI] Anchors disabled (unit, party, raid frames)|r")
    end, "Hide draggable anchors for unit, party, and raid frames")
    disableAnchorsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    disableAnchorsBtn:SetWidth(110)
    
    -- Enable Anchors button
    -- Controls unit frame, party frame, and raid frame anchors
    local enableAnchorsBtn = CreateTitleButton("Enable Anchors", function()
        -- Enable unit frame anchors
        local db = LilyUI.db.profile.unitFrames
        if not db then
            db = {}
            LilyUI.db.profile.unitFrames = db
        end
        if not db.General then db.General = {} end
        db.General.ShowEditModeAnchors = true
        if LilyUI.UnitFrames then
            LilyUI.UnitFrames:UpdateEditModeAnchors()
            LilyUI.UnitFrames:ShowBossFramesPreview()
        end

        -- Enable party and raid frame anchors (show movers for drag-to-reposition)
        local NUF = LilyUI.PartyFrames
        if NUF then
            if NUF.UnlockFrames then NUF:UnlockFrames() end
            if NUF.UnlockRaidFrames then NUF:UnlockRaidFrames() end
        end

        -- Enable test mode
        if NUF and NUF.EnableTestMode then
            NUF:EnableTestMode("party")
        end

        -- Show center line
        LilyUI.UpdateCenterLine()

        print("|cff00ff00[LilyUI] Anchors enabled (unit, party, raid frames)|r")
    end, "Show draggable anchors for unit, party, raid frames, and action bars (works independently of Edit Mode)")
    enableAnchorsBtn:SetPoint("RIGHT", disableAnchorsBtn, "LEFT", -5, 0)
    enableAnchorsBtn:SetWidth(110)
    
    -- Open CooldownViewerSettings button
    local cooldownViewerBtn = CreateTitleButton("Cooldowns", function()
        -- Try to find and open the CooldownViewerSettings frame
        local frame = _G["CooldownViewerSettings"]
        if frame then
            frame:Show()
            frame:Raise()
        else
            -- Fallback: Open the custom GUI and navigate to the Cooldown Manager tab
            if LilyUI and LilyUI.OpenConfigGUI then
                LilyUI:OpenConfigGUI(nil, "viewers")
            end
        end
    end, "Open Advanced Cooldown Manager Panel")
    cooldownViewerBtn:SetPoint("RIGHT", enableAnchorsBtn, "LEFT", -5, 0)
    cooldownViewerBtn:SetWidth(90)
    
    -- Open Edit Mode button (leftmost of the button group)
    local editModeBtn = CreateTitleButton("Edit Mode", function()
        DEFAULT_CHAT_FRAME.editBox:SetText("/editmode")
        ChatEdit_SendText(DEFAULT_CHAT_FRAME.editBox, 0)
    end, "Open WoW's Edit Mode to reposition UI elements")
    editModeBtn:SetPoint("RIGHT", cooldownViewerBtn, "LEFT", -5, 0)
    editModeBtn:SetWidth(80)
    
    -- Mark frame as having title buttons so we know it's been updated
    frame._hasTitleButtons = true
    
    -- Left sidebar for tabs (vertical list)
    local tabContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabContainer:SetWidth(180)  -- Fixed width for sidebar
    tabContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1)
    tabContainer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 1)
    local bgMediumTransparent = {THEME.bgMedium[1], THEME.bgMedium[2], THEME.bgMedium[3], 0.85}
    CreateBackdrop(tabContainer, bgMediumTransparent, THEME.border)

    -- Direct child frame for tabs (no scrolling)
    local tabScrollChild = CreateFrame("Frame", nil, tabContainer)
    tabScrollChild:SetPoint("TOPLEFT", tabContainer, "TOPLEFT", 2, -2)
    tabScrollChild:SetPoint("BOTTOMRIGHT", tabContainer, "BOTTOMRIGHT", -2, 2)
    tabScrollChild:SetWidth(tabContainer:GetWidth() - 4)

    -- Content area (right side of tabs)
    local contentArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 181, -1)  -- Start after tab container
    contentArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    local bgDarkTransparent = {THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85}
    CreateBackdrop(contentArea, bgDarkTransparent, THEME.border)
    
    -- Modern Dragonflight scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, contentArea)
    scrollFrame:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 1, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -20, 1)

    -- Modern scroll bar
    local scrollBar = CreateFrame("EventFrame", nil, contentArea, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 2, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 2, 0)
    scrollFrame.ScrollBar = scrollBar

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() - 1)
    scrollChild.widgets = {}
    scrollChild.scrollFrame = scrollFrame
    scrollFrame:SetScrollChild(scrollChild)

    -- Connect scroll bar to scroll frame
    ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollBar)
    
    -- Store references
    frame.titleBar = titleBar
    frame.tabContainer = tabContainer
    frame.tabScrollChild = tabScrollChild
    frame.contentArea = contentArea
    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild
    frame.tabs = {}
    frame.currentTab = nil
    frame.currentPath = {}
    
    -- Methods
    frame.SetContent = function(self, options, path)
        -- Clear scroll position
        self.scrollFrame:SetVerticalScroll(0)
        RenderOptions(self.scrollChild, options, path, self)
    end
    
    -- Refresh method to update all widgets
    frame.Refresh = function(self)
        if self.scrollChild and self.scrollChild.widgets then
            for _, widget in ipairs(self.scrollChild.widgets) do
                if widget.Refresh then
                    widget:Refresh()
                end
            end
        end
    end
    
    -- Soft refresh - reload content without flash (preserves scroll position)
    frame.SoftRefresh = function(self)
        if self.currentTab and self.configOptions then
            -- Store current scroll position
            local scrollPos = self.scrollFrame:GetVerticalScroll()
            
            -- Store which sub-tab is active
            local activeSubTabKey = nil
            if self.scrollChild and self.scrollChild.subTabButtons then
                local tabOption = self.configOptions.args[self.currentTab]
                if tabOption and tabOption.args then
                    local sortedTabs = {}
                    for key, option in pairs(tabOption.args) do
                        if option.type == "group" or (option.type ~= "group" and option.type ~= "header" and option.type ~= "description") then
                            table.insert(sortedTabs, {key = key, option = option, order = option.order or 999})
                        end
                    end
                    table.sort(sortedTabs, function(a, b) return a.order < b.order end)
                    
                    for i, btn in ipairs(self.scrollChild.subTabButtons) do
                        if btn.active and sortedTabs[i] then
                            activeSubTabKey = sortedTabs[i].key
                            break
                        end
                    end
                end
            end
            
            local tabOption = self.configOptions.args[self.currentTab]
            if tabOption then
                -- Re-render content
                RenderOptions(self.scrollChild, tabOption, {self.currentTab}, self)
                
                -- Restore the active sub-tab
                if activeSubTabKey and self.scrollChild.subTabButtons then
                    local newTabOption = self.configOptions.args[self.currentTab]
                    if newTabOption and newTabOption.args then
                        local sortedTabs = {}
                        for key, option in pairs(newTabOption.args) do
                            if option.type == "group" or (option.type ~= "group" and option.type ~= "header" and option.type ~= "description") then
                                table.insert(sortedTabs, {key = key, option = option, order = option.order or 999})
                            end
                        end
                        table.sort(sortedTabs, function(a, b) return a.order < b.order end)
                        
                        for i, item in ipairs(sortedTabs) do
                            if item.key == activeSubTabKey and self.scrollChild.subTabButtons[i] then
                                self.scrollChild.subTabButtons[i]:Click()
                                break
                            end
                        end
                    end
                end
                
                -- Restore scroll position
                C_Timer.After(0.01, function()
                    if self.scrollFrame then
                        self.scrollFrame:SetVerticalScroll(scrollPos)
                    end
                end)
            end
        end
    end
    
    -- Full refresh - reload content
    frame.FullRefresh = function(self)
        if self.currentTab and self.configOptions then
            -- Store which sub-tab is active before refresh (if we're on a tabbed group)
            local activeSubTabKey = nil
            local activeSubTabOption = nil
            if self.scrollChild and self.scrollChild.subTabButtons then
                -- Get the tab option to find which sub-tab key corresponds to the active button
                local tabOption = self.configOptions.args[self.currentTab]
                if tabOption and tabOption.args then
                    local sortedTabs = {}
                    for key, option in pairs(tabOption.args) do
                        if option.type == "group" or (option.type ~= "group" and option.type ~= "header" and option.type ~= "description") then
                            table.insert(sortedTabs, {key = key, option = option, order = option.order or 999})
                        end
                    end
                    table.sort(sortedTabs, function(a, b) return a.order < b.order end)
                    
                    for i, btn in ipairs(self.scrollChild.subTabButtons) do
                        if btn.active and sortedTabs[i] then
                            activeSubTabKey = sortedTabs[i].key
                            activeSubTabOption = sortedTabs[i].option
                            break
                        end
                    end
                end
            end
            
            local tabOption = self.configOptions.args[self.currentTab]
            if tabOption then
                self:SetContent(tabOption, {self.currentTab})
                
                -- Restore the active sub-tab if we were on one
                if activeSubTabKey and activeSubTabOption and self.scrollChild and self.scrollChild.subTabButtons then
                    -- Use a small delay to ensure SetContent has finished creating sub-tabs
                    C_Timer.After(0.01, function()
                        if self.scrollChild and self.scrollChild.subTabButtons and self.scrollChild.subScrollChild then
                            -- Find the button for this sub-tab
                            local tabOption = self.configOptions.args[self.currentTab]
                            if tabOption and tabOption.args then
                                local sortedTabs = {}
                                for key, option in pairs(tabOption.args) do
                                    if option.type == "group" or (option.type ~= "group" and option.type ~= "header" and option.type ~= "description") then
                                        table.insert(sortedTabs, {key = key, option = option, order = option.order or 999})
                                    end
                                end
                                table.sort(sortedTabs, function(a, b) return a.order < b.order end)
                                
                                for i, item in ipairs(sortedTabs) do
                                    if item.key == activeSubTabKey then
                                        -- Deactivate all buttons
                                        for _, btn in ipairs(self.scrollChild.subTabButtons) do
                                            btn:SetActive(false)
                                        end
                                        -- Activate the correct one
                                        if self.scrollChild.subTabButtons[i] then
                                            self.scrollChild.subTabButtons[i]:SetActive(true)
                                        end
                                        
                                        -- Clear and re-render the sub-tab content directly
                                        local subScrollChild = self.scrollChild.subScrollChild
                                        if subScrollChild then
                                            if subScrollChild.widgets then
                                                for j = #subScrollChild.widgets, 1, -1 do
                                                    local widget = subScrollChild.widgets[j]
                                                    if widget then
                                                        widget:Hide()
                                                        widget:SetParent(nil)
                                                    end
                                                end
                                            end
                                            subScrollChild.widgets = {}
                                            
                                            -- Re-render the sub-tab content
                                            RenderOptions(subScrollChild, item.option, {self.currentTab, item.key}, self)
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end
    
    ConfigFrame = frame
    return frame
end

-- Open config with options
function LilyUI:OpenConfigGUI(options, tabKey)
    -- Ensure the GUI picks up the latest saved color scheme before building widgets.
    if self.ApplyColorScheme then
        self:ApplyColorScheme()
    end
    local frame = self:CreateConfigFrame()
    
    -- Always ensure title is up to date
    if frame then
        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"
        if frame.titleText then
            frame.titleText:SetText("LilyUI - v" .. version)
        else
            -- If titleText doesn't exist, find and update it
            local titleBar = frame.titleBar
            if titleBar then
                local regions = {titleBar:GetRegions()}
                for _, region in ipairs(regions) do
                    if region:IsObjectType("FontString") and region:GetText() then
                        local text = region:GetText()
                        if text == "LilyUI" or text == "LilyUI Configuration" or text:match("^LilyUI") then
                            region:SetText("LilyUI - v" .. version)
                            frame.titleText = region
                            break
                        end
                    end
                end
            end
        end
    end
    
    if not options then
        -- Try to get from stored configOptions first
        if self.configOptions then
            options = self.configOptions
        else
            -- Get options from AceConfig if available (using custom GUI format)
            local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
            if AceConfigRegistry then
                local app = AceConfigRegistry:GetOptionsTable(ADDON_NAME)
                if app then
                    -- Get options table without AceConfigDialog format
                    options = app()
                end
            end
        end
    end
    
    if options then
        -- Create main tabs
        local tabButtons = {}
        local sortedTabs = {}
        
        for key, option in pairs(options.args or {}) do
            if option.type == "group" then
                table.insert(sortedTabs, {key = key, option = option, order = option.order or 999})
            end
        end
        table.sort(sortedTabs, function(a, b) return a.order < b.order end)
        
        local tabY = -5
        for i, item in ipairs(sortedTabs) do
            local tabName = item.option.name or item.key
            if type(tabName) == "function" then
                tabName = tabName()
            end
            local tabBtn = CreateTabButton(frame.tabScrollChild, tabName, function(btn)
                -- Deactivate all tabs
                for _, t in ipairs(tabButtons) do
                    t:SetActive(false)
                end
                btn:SetActive(true)

                -- Set content
                GUIDebug("[GUI] Main tab selected: %s", tostring(tabName))
                frame:SetContent(item.option, {item.key})
                frame.currentTab = item.key
                frame.currentPath = {item.key}
                frame.configOptions = options
            end)
            tabBtn:SetPoint("TOPLEFT", frame.tabScrollChild, "TOPLEFT", 2, tabY)
            tabBtn:SetPoint("RIGHT", frame.tabScrollChild, "RIGHT", -2, 0)
            tabY = tabY - 20  -- Height (18) + spacing (2)
            
            table.insert(tabButtons, tabBtn)
            frame.tabs[item.key] = tabBtn
        end
        
        -- No need to set height since tabs are in a non-scrolling container
        
        -- Activate specified tab or first tab
        if #tabButtons > 0 then
            local targetTabIndex = 1
            local targetTab = sortedTabs[1]
            
            -- If tabKey is provided, find and activate that tab
            if tabKey then
                for i, item in ipairs(sortedTabs) do
                    if item.key == tabKey then
                        targetTabIndex = i
                        targetTab = item
                        break
                    end
                end
            end
            
            if targetTab and tabButtons[targetTabIndex] then
                tabButtons[targetTabIndex]:SetActive(true)
                local tabName = targetTab.option and targetTab.option.name or targetTab.key
                if type(tabName) == "function" then
                    tabName = tabName()
                end
                GUIDebug("[GUI] Main tab selected: %s", tostring(tabName))
                frame:SetContent(targetTab.option, {targetTab.key})
                frame.currentTab = targetTab.key
                frame.currentPath = {targetTab.key}
                frame.configOptions = options
            end
        end
    end
    
    -- One final check: ensure title is correct before showing
    if frame and frame.titleText then
        local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"
        frame.titleText:SetText("LilyUI - v" .. version)
    end
    
    frame:Show()
    frame:Raise()
end

-- Rebuild the config GUI so theme changes apply immediately
function LilyUI:RebuildConfigGUI(tabKey)
    local targetTab = tabKey
    if (not targetTab) and ConfigFrame and ConfigFrame.currentTab then
        targetTab = ConfigFrame.currentTab
    end

    if ConfigFrame then
        ConfigFrame:Hide()
        ConfigFrame:SetParent(nil)
        ConfigFrame = nil
    end

    self:OpenConfigGUI(nil, targetTab)
end

-- Export
LilyUI.GUI = {
    CreateConfigFrame = LilyUI.CreateConfigFrame,
    OpenConfigGUI = LilyUI.OpenConfigGUI,
    RebuildConfigGUI = LilyUI.RebuildConfigGUI,
    Widgets = Widgets,
    THEME = THEME,
}
