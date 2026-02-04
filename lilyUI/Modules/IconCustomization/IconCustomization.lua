local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

LilyUI.IconCustomization = LilyUI.IconCustomization or {}
local IconCustomization = LilyUI.IconCustomization

local Widgets = LilyUI.GUI and LilyUI.GUI.Widgets
local THEME = LilyUI.GUI and LilyUI.GUI.THEME

-- Get LibCustomGlow
local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)

-- Helper to refresh the LilyUI custom GUI (soft refresh to avoid flash)
local function RefreshGUI()
    local configFrame = _G["LilyUI_ConfigFrame"]
    if configFrame and configFrame.SoftRefresh then
        configFrame:SoftRefresh()
    elseif configFrame and configFrame.FullRefresh then
        configFrame:FullRefresh()
    end
end

-- Style font string helper
local function StyleFontString(fontString)
    if not fontString then return end
    local globalFontPath = LilyUI:GetGlobalFont()
    local currentFont, size, flags = fontString:GetFont()
    size = size or 12
    if not flags or (flags ~= "OUTLINE" and flags ~= "THICKOUTLINE" and not flags:find("OUTLINE")) then
        flags = "OUTLINE"
    end
    if globalFontPath then
        fontString:SetFont(globalFontPath, size, flags)
    elseif currentFont and size and flags then
        fontString:SetFont(currentFont, size, flags)
    end
    fontString:SetShadowOffset(0, 0)
    fontString:SetShadowColor(0, 0, 0, 1)
end

-- Create backdrop helper
local function CreateBackdrop(frame, bgColor, borderColor)
    if not frame.SetBackdrop then
        if Mixin and BackdropTemplateMixin then
            Mixin(frame, BackdropTemplateMixin)
        else
            return
        end
    end
    local backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    }
    frame:SetBackdrop(backdrop)
    if bgColor then
        frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)
    end
    if borderColor then
        frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    end
end

-- Helper function to get spell ID from an icon frame
local function GetSpellIDFromIcon(iconFrame)
    if not iconFrame then return nil end
    
    local spellID = nil
    pcall(function()
        -- Try cooldownInfo first (Blizzard's cooldown manager format)
        if iconFrame.cooldownInfo then
            spellID = iconFrame.cooldownInfo.overrideSpellID or iconFrame.cooldownInfo.spellID
        end
        -- Fallback to other common properties
        if not spellID then
            spellID = iconFrame.spellID or iconFrame.SpellID
        end
        if not spellID and iconFrame.GetSpellID then
            spellID = iconFrame:GetSpellID()
        end
        if not spellID and iconFrame.GetSpellId then
            spellID = iconFrame:GetSpellId()
        end
    end)
    return spellID
end

-- Scan viewers for icons and collect spell data
local function ScanViewerIcons(viewerName)
    local viewer = _G[viewerName]
    if not viewer then return {} end
    
    local container = viewer.viewerFrame or viewer
    local icons = {}
    local spellMap = {} -- Track unique spells by ID
    
    for _, child in ipairs({ container:GetChildren() }) do
        if child and (child.icon or child.Icon) and child.Cooldown then
            local spellID = GetSpellIDFromIcon(child)
            if spellID and not spellMap[spellID] then
                spellMap[spellID] = true
                
                local spellInfo = C_Spell.GetSpellInfo(spellID)
                if spellInfo then
                    table.insert(icons, {
                        spellID = spellID,
                        spellName = spellInfo.name or "Unknown",
                        iconTexture = spellInfo.iconID or C_Spell.GetSpellTexture(spellID),
                        viewerName = viewerName,
                    })
                end
            end
        end
    end
    
    return icons
end

-- Get all icons from all viewers
local function ScanAllViewerIcons()
    local viewers = LilyUI.viewers or {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BuffIconCooldownViewer",
    }
    
    local categorizedIcons = {
        Essential = {},
        Utility = {},
        Buff = {},
    }
    
    for _, viewerName in ipairs(viewers) do
        local icons = ScanViewerIcons(viewerName)
        if viewerName == "EssentialCooldownViewer" then
            categorizedIcons.Essential = icons
        elseif viewerName == "UtilityCooldownViewer" then
            categorizedIcons.Utility = icons
        elseif viewerName == "BuffIconCooldownViewer" then
            categorizedIcons.Buff = icons
        end
    end
    
    return categorizedIcons
end

-- Get customization settings for a spell
local function GetSpellCustomization(spellID)
    local db = LilyUI.db.profile.iconCustomization or {}
    db.spells = db.spells or {}
    return db.spells[tostring(spellID)] or {}
end

-- Check if a spell is customized
local function IsSpellCustomized(spellID)
    local custom = GetSpellCustomization(spellID)
    return custom.readyGlow ~= nil
end

-- UI state
local uiState = {
    selectedSpellID = nil,
    scannedIcons = {},
}

-- Track hooked frames for event-driven updates
local hookedFrames = {} -- [iconFrame] = true


-- READY STATE GLOW FUNCTIONS

-- Stop all glow effects on a frame
local function StopAllGlows(frame, key)
    if not frame or not LCG then return end
    local glowKey = key or "LilyUI_ReadyGlow"
    pcall(LCG.PixelGlow_Stop, frame, glowKey)
    pcall(LCG.AutoCastGlow_Stop, frame, glowKey)
    pcall(LCG.ButtonGlow_Stop, frame)
    pcall(LCG.ProcGlow_Stop, frame, glowKey)
end

-- Check if glow should be shown for a spell
local function ShouldShowReadyGlow(spellID)
    if not spellID then return false end
    
    local custom = GetSpellCustomization(spellID)
    -- STRICT CHECK: readyGlow must be explicitly boolean true
    if not custom or custom.readyGlow ~= true then
        return false
    end
    
    return true
end

-- Show ready glow with settings
local function ShowReadyGlow(frame, spellID)
    if not frame or not LCG then return end
    
    -- Stop any existing glow first
    StopAllGlows(frame, "LilyUI_ReadyGlow")
    
    if not spellID then
        frame._nephuiReadyGlowActive = false
        return
    end
    
    -- Get customization settings
    local custom = GetSpellCustomization(spellID)
    if not custom or custom.readyGlow ~= true then
        frame._nephuiReadyGlowActive = false
        return
    end
    
    -- Get glow settings with defaults
    local glowType = custom.glowType or "button"
    local glowColor = custom.glowColor or {r = 1, g = 0.85, b = 0.1}
    local glowSpeed = custom.glowSpeed or 0.25
    local glowLines = custom.glowLines or 8
    local glowThickness = custom.glowThickness or 2
    
    -- Convert color to table format
    local color = {glowColor.r or 1, glowColor.g or 0.85, glowColor.b or 0.1, 1}
    
    -- Start appropriate glow type
    if glowType == "pixel" then
        pcall(LCG.PixelGlow_Start, frame, color, glowLines, glowSpeed, nil, glowThickness, 0, 0, true, "LilyUI_ReadyGlow")
    elseif glowType == "autocast" then
        pcall(LCG.AutoCastGlow_Start, frame, color, 4, glowSpeed, 1.0, 0, 0, "LilyUI_ReadyGlow")
    elseif glowType == "proc" then
        pcall(LCG.ProcGlow_Start, frame, {
            color = color,
            startAnim = false,
            xOffset = 0,
            yOffset = 0,
            key = "LilyUI_ReadyGlow"
        })
    else -- button (default)
        pcall(LCG.ButtonGlow_Start, frame, color, glowSpeed)
    end
    
    frame._nephuiReadyGlowActive = true
end

-- Hide ready glow
local function HideReadyGlow(frame)
    if not frame then return end
    
    -- Stop all glow types
    StopAllGlows(frame, "LilyUI_ReadyGlow")
    
    -- Explicitly hide ButtonGlow frame
    if frame._ButtonGlow then
        frame._ButtonGlow:SetAlpha(0)
        frame._ButtonGlow:Hide()
    end
    
    frame._nephuiReadyGlowActive = false
end

-- Check if spell is on cooldown (ignores GCD) - SECRET-SAFE for combat
local function IsSpellOnCooldown(iconFrame)
    if not iconFrame then return false end
    
    local spellID = GetSpellIDFromIcon(iconFrame)
    if not spellID then return false end
    
    -- SECRET-SAFE: Use IsVisible() instead of GetCooldownTimes() arithmetic
    -- Check if cooldown frame is visible (indicates active cooldown)
    local cooldownVisible = false
    if iconFrame.Cooldown then
        local ok, visible = pcall(iconFrame.Cooldown.IsVisible, iconFrame.Cooldown)
        if ok and visible == true then
            cooldownVisible = true
        end
    end
    
    -- Get cooldown info to check isOnGCD (NeverSecret!)
    local cooldownInfo
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and info then
        cooldownInfo = info
    end
    
    -- Logic: If cooldown is visible AND it's NOT just GCD, then it's on cooldown
    -- If isOnGCD is true, treat as ready (not on cooldown)
    if cooldownVisible and cooldownInfo and not cooldownInfo.isOnGCD then
        return true
    end
    
    -- If cooldown is NOT visible, or if it's just GCD, treat as ready (not on cooldown)
    return false
end

-- Update glow state for an icon frame
local function UpdateReadyGlow(iconFrame)
    if not iconFrame then return end
    
    -- Use cached spellID if available
    local spellID = iconFrame._nephuiCachedSpellID
    if not spellID then
        spellID = GetSpellIDFromIcon(iconFrame)
        if spellID then
            iconFrame._nephuiCachedSpellID = spellID
        end
    end
    
    if not spellID then
        if iconFrame._nephuiReadyGlowActive then
            HideReadyGlow(iconFrame)
        end
        return
    end
    
    if not ShouldShowReadyGlow(spellID) then
        if iconFrame._nephuiReadyGlowActive then
            HideReadyGlow(iconFrame)
        end
        return
    end
    
    -- Check if spell is on cooldown (ignores GCD)
    local onCooldown = IsSpellOnCooldown(iconFrame)
    
    -- Only update if state actually changed (prevent flashing)
    if onCooldown then
        if iconFrame._nephuiReadyGlowActive then
            HideReadyGlow(iconFrame)
        end
    else
        if not iconFrame._nephuiReadyGlowActive then
            ShowReadyGlow(iconFrame, spellID)
        end
    end
end

-- Hook cooldown frame
local function HookCooldownFrame(iconFrame)
    if not iconFrame or not iconFrame.Cooldown then return end
    if iconFrame.__nephuiReadyGlowHooked then return end
    
    iconFrame.__nephuiReadyGlowHooked = true
    
    -- Cache spellID on frame for event-driven updates
    if not InCombatLockdown() then
        local cooldownInfo = iconFrame.cooldownInfo
        if cooldownInfo then
            local spellID = cooldownInfo.overrideSpellID or cooldownInfo.spellID
            if spellID then
                iconFrame._nephuiCachedSpellID = spellID
            end
        end
    end
    
    -- If we couldn't cache from cooldownInfo, try GetSpellIDFromIcon
    if not iconFrame._nephuiCachedSpellID then
        local spellID = GetSpellIDFromIcon(iconFrame)
        if spellID then
            iconFrame._nephuiCachedSpellID = spellID
        end
    end
    
    -- Track frame for event-driven updates
    hookedFrames[iconFrame] = true
    
    -- Initial update
    UpdateReadyGlow(iconFrame)
end

-- Refresh all icons with ready glow customizations
local function RefreshAllReadyGlows()
    -- Loop through tracked frames
    for frame, _ in pairs(hookedFrames) do
        if frame and not frame:IsForbidden() then
            -- Use cached spellID
            local spellID = frame._nephuiCachedSpellID
            if not spellID then
                -- Fallback if cache missing
                spellID = GetSpellIDFromIcon(frame)
                if spellID then
                    frame._nephuiCachedSpellID = spellID
                end
            end
            
            -- Only update frames that have ready glow enabled
            if spellID and ShouldShowReadyGlow(spellID) then
                UpdateReadyGlow(frame)
            end
        end
    end
end

-- Build the Icon Customization UI
function IconCustomization:BuildIconCustomizationUI(parentFrame)
    if not parentFrame then return end
    
    -- Clear existing widgets
    if parentFrame.widgets then
        for _, widget in ipairs(parentFrame.widgets) do
            if widget and widget.ClearAllPoints then
                widget:Hide()
                widget:ClearAllPoints()
                widget:SetParent(nil)
            end
        end
    end
    parentFrame.widgets = {}
    
    local yOffset = 10
    
    -- Scan Icons button
    local scanButtonFrame = CreateFrame("Frame", nil, parentFrame)
    scanButtonFrame:SetHeight(32)
    scanButtonFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -yOffset)
    scanButtonFrame:SetPoint("RIGHT", parentFrame, "RIGHT", -10, 0)
    
    local scanButton = CreateFrame("Button", nil, scanButtonFrame, "BackdropTemplate")
    scanButton:SetHeight(28)
    scanButton:SetWidth(150)
    scanButton:SetPoint("LEFT", scanButtonFrame, "LEFT", 0, 0)
    
    scanButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    scanButton:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 1)
    scanButton:SetBackdropBorderColor(THEME.border[1], THEME.border[2], THEME.border[3], THEME.border[4] or 1)
    
    local scanLabel = scanButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(scanLabel)
    scanLabel:SetPoint("CENTER")
    scanLabel:SetText("Scan Icons")
    scanLabel:SetTextColor(1, 1, 1, 1)
    
    scanButton:SetScript("OnClick", function(self)
        uiState.scannedIcons = ScanAllViewerIcons()
        RefreshGUI()
    end)
    
    table.insert(parentFrame.widgets, scanButtonFrame)
    yOffset = yOffset + 42
    
    -- Help text
    local helpText = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    StyleFontString(helpText)
    helpText:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -yOffset)
    helpText:SetPoint("RIGHT", parentFrame, "RIGHT", -10, 0)
    helpText:SetJustifyH("LEFT")
    helpText:SetText("Click to select • Blue border = Customized")
    helpText:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], 0.85)
    table.insert(parentFrame.widgets, helpText)
    yOffset = yOffset + 25
    
    -- Display icons by category
    local categories = {
        { name = "Essential Cooldowns", key = "Essential", color = {1, 0.5, 0.2} },
        { name = "Utility Cooldowns", key = "Utility", color = {0.2, 0.6, 1} },
        { name = "Buff Icons", key = "Buff", color = {0.2, 1, 0.2} },
    }
    
    for _, category in ipairs(categories) do
        local icons = uiState.scannedIcons[category.key] or {}
        if #icons > 0 then
            -- Category header
            local headerFrame = CreateFrame("Frame", nil, parentFrame)
            headerFrame:SetHeight(24)
            headerFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -yOffset)
            headerFrame:SetPoint("RIGHT", parentFrame, "RIGHT", -10, 0)
            
            local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            StyleFontString(headerText)
            local globalFontPath = LilyUI:GetGlobalFont()
            if globalFontPath then
                headerText:SetFont(globalFontPath, 16, "OUTLINE")
            end
            headerText:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
            headerText:SetText(string.format("%s (%d)", category.name, #icons))
            headerText:SetTextColor(category.color[1], category.color[2], category.color[3], 1)
            
            table.insert(parentFrame.widgets, headerFrame)
            yOffset = yOffset + 30
            
            -- Icon grid
            local gridFrame = CreateFrame("Frame", nil, parentFrame)
            gridFrame:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -yOffset)
            gridFrame:SetPoint("RIGHT", parentFrame, "RIGHT", -10, 0)
            
            local iconSize = 44
            local spacing = 5
            local parentWidth = parentFrame:GetWidth() or 900
            local iconsPerRow = math.floor((parentWidth - 20) / (iconSize + spacing))
            if iconsPerRow < 1 then iconsPerRow = 1 end
            
            local currentRow = 0
            local currentCol = 0
            
            for i, iconData in ipairs(icons) do
                local iconButton = CreateFrame("Button", nil, gridFrame, "BackdropTemplate")
                iconButton:SetSize(iconSize, iconSize)
                iconButton:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 
                    currentCol * (iconSize + spacing), -currentRow * (iconSize + spacing))
                
                -- Icon texture
                local iconTexture = iconButton:CreateTexture(nil, "ARTWORK")
                iconTexture:SetAllPoints(iconButton)
                iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if iconData.iconTexture then
                    iconTexture:SetTexture(iconData.iconTexture)
                else
                    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                end
                
                iconButton.iconTexture = iconTexture
                
                -- Border for customization indicator
                local border = CreateFrame("Frame", nil, iconButton, "BackdropTemplate")
                border:SetAllPoints(iconButton)
                border:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 2,
                })
                border:SetBackdropBorderColor(0, 0, 0, 0) -- Hidden by default
                border:Hide()
                iconButton.customBorder = border
                
                -- Show blue border if customized
                if IsSpellCustomized(iconData.spellID) then
                    border:SetBackdropBorderColor(0.2, 0.6, 1, 1) -- Blue
                    border:Show()
                end
                
                -- Highlight border for selected
                if uiState.selectedSpellID == iconData.spellID then
                    border:SetBackdropBorderColor(1, 1, 0, 1) -- Yellow for selected
                    border:Show()
                end
                
                -- Click handler
                iconButton:SetScript("OnClick", function(self)
                    uiState.selectedSpellID = iconData.spellID
                    RefreshGUI()
                end)
                
                -- Tooltip
                iconButton:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetSpellByID(iconData.spellID)
                    GameTooltip:Show()
                end)
                iconButton:SetScript("OnLeave", function(self)
                    GameTooltip:Hide()
                end)
                
                iconButton.spellData = iconData
                
                currentCol = currentCol + 1
                if currentCol >= iconsPerRow then
                    currentCol = 0
                    currentRow = currentRow + 1
                end
            end
            
            local gridHeight = (math.ceil(#icons / iconsPerRow)) * (iconSize + spacing)
            gridFrame:SetHeight(gridHeight)
            
            table.insert(parentFrame.widgets, gridFrame)
            yOffset = yOffset + gridHeight + 20
        end
    end
    
    -- Configuration panel for selected spell
    if uiState.selectedSpellID then
        local selectedSpellData = nil
        for _, category in ipairs(categories) do
            for _, iconData in ipairs(uiState.scannedIcons[category.key] or {}) do
                if iconData.spellID == uiState.selectedSpellID then
                    selectedSpellData = iconData
                    break
                end
            end
            if selectedSpellData then break end
        end
        
        if selectedSpellData then
            yOffset = yOffset + 20
            
            -- Preview icon
            local previewIcon = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
            previewIcon:SetSize(48, 48)
            previewIcon:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -yOffset)
            CreateBackdrop(previewIcon, THEME.bgDark, THEME.border)
            
            local previewTexture = previewIcon:CreateTexture(nil, "ARTWORK")
            previewTexture:SetAllPoints(previewIcon)
            previewTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            if selectedSpellData.iconTexture then
                previewTexture:SetTexture(selectedSpellData.iconTexture)
            end
            table.insert(parentFrame.widgets, previewIcon)
            
            -- Editing header
            local editingHeader = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            StyleFontString(editingHeader)
            local globalFontPath = LilyUI:GetGlobalFont()
            if globalFontPath then
                editingHeader:SetFont(globalFontPath, 14, "OUTLINE")
            end
            editingHeader:SetPoint("LEFT", previewIcon, "RIGHT", 10, 0)
            editingHeader:SetPoint("TOP", previewIcon, "TOP", 0, 0)
            editingHeader:SetText(string.format("Editing: %s", selectedSpellData.spellName))
            editingHeader:SetTextColor(1, 1, 0.2, 1)
            table.insert(parentFrame.widgets, editingHeader)
            
            yOffset = yOffset + 60
            
            -- Get current customization settings
            local custom = GetSpellCustomization(uiState.selectedSpellID)
            local db = LilyUI.db.profile.iconCustomization
            db.spells = db.spells or {}
            local spellKey = tostring(uiState.selectedSpellID)
            
            -- Deselect button
            local deselectButton = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
            deselectButton:SetHeight(28)
            deselectButton:SetWidth(120)
            deselectButton:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 10, -yOffset)
            CreateBackdrop(deselectButton, THEME.primary, THEME.border)
            
            local deselectLabel = deselectButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            StyleFontString(deselectLabel)
            deselectLabel:SetPoint("CENTER")
            deselectLabel:SetText("Deselect")
            deselectLabel:SetTextColor(1, 1, 1, 1)
            
            deselectButton:SetScript("OnClick", function(self)
                uiState.selectedSpellID = nil
                RefreshGUI()
            end)
            table.insert(parentFrame.widgets, deselectButton)
            
            -- Reset Icon button
            local resetButton = CreateFrame("Button", nil, parentFrame, "BackdropTemplate")
            resetButton:SetHeight(28)
            resetButton:SetWidth(120)
            resetButton:SetPoint("LEFT", deselectButton, "RIGHT", 10, 0)
            CreateBackdrop(resetButton, THEME.primary, THEME.border)
            
            local resetLabel = resetButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            StyleFontString(resetLabel)
            resetLabel:SetPoint("CENTER")
            resetLabel:SetText("Reset Icon")
            resetLabel:SetTextColor(1, 1, 1, 1)
            
            resetButton:SetScript("OnClick", function(self)
                db.spells[spellKey] = nil
                uiState.selectedSpellID = nil
                -- Refresh all icons with this spell to remove glow
                RefreshAllReadyGlows()
                RefreshGUI()
            end)
            table.insert(parentFrame.widgets, resetButton)
            
            yOffset = yOffset + 40
            
            -- Ready State Glow toggle
            if Widgets and Widgets.CreateToggle then
                local glowToggle = Widgets.CreateToggle(parentFrame, {
                    name = "Ready State Glow",
                    get = function() return custom.readyGlow == true end,
                    set = function(_, val)
                        db.spells[spellKey] = db.spells[spellKey] or {}
                        db.spells[spellKey].readyGlow = val or nil
                        if not val then
                            -- Clean up if false
                            db.spells[spellKey] = nil
                        end
                        -- Refresh all icons with this spell
                        RefreshAllReadyGlows()
                    end,
                }, yOffset, {})
                table.insert(parentFrame.widgets, glowToggle)
                yOffset = yOffset + 35
            end
            
            -- Glow Type select (always visible)
            if Widgets and Widgets.CreateSelect then
                local glowTypeSelect = Widgets.CreateSelect(parentFrame, {
                    name = "Glow Type",
                    values = {
                        ["button"] = "Action Button Glow",
                        ["pixel"] = "Pixel Glow",
                        ["autocast"] = "Autocast Shine",
                        ["proc"] = "Proc Effect",
                    },
                    get = function() return custom.glowType or "button" end,
                    set = function(_, val)
                        db.spells[spellKey] = db.spells[spellKey] or {}
                        db.spells[spellKey].glowType = val
                        RefreshAllReadyGlows()
                        RefreshGUI()
                    end,
                }, yOffset, nil, nil, nil)
                table.insert(parentFrame.widgets, glowTypeSelect)
                yOffset = yOffset + 40
            end
            
            -- Glow Color (always visible)
            if Widgets and Widgets.CreateColor then
                local glowColor = Widgets.CreateColor(parentFrame, {
                    name = "Glow Color",
                    get = function()
                        local color = custom.glowColor or {r = 1, g = 0.85, b = 0.1}
                        return color.r or 1, color.g or 0.85, color.b or 0.1
                    end,
                    set = function(_, r, g, b)
                        db.spells[spellKey] = db.spells[spellKey] or {}
                        db.spells[spellKey].glowColor = {r = r, g = g, b = b}
                        RefreshAllReadyGlows()
                    end,
                }, yOffset, {})
                table.insert(parentFrame.widgets, glowColor)
                yOffset = yOffset + 35
            end
            
            -- Glow Frequency/Speed (always visible - proc glow just won't use it)
            if Widgets and Widgets.CreateRange then
                local glowSpeedRange = Widgets.CreateRange(parentFrame, {
                    name = "Glow Frequency",
                    get = function() return custom.glowSpeed or 0.25 end,
                    set = function(_, val)
                        db.spells[spellKey] = db.spells[spellKey] or {}
                        db.spells[spellKey].glowSpeed = val
                        RefreshAllReadyGlows()
                    end,
                    min = 0.05,
                    max = 1.0,
                    step = 0.05,
                }, yOffset, {})
                table.insert(parentFrame.widgets, glowSpeedRange)
                yOffset = yOffset + 35
            end
            
            -- Glow Lines (always visible - pixel glow only, but show for all)
            if Widgets and Widgets.CreateRange then
                local glowLinesRange = Widgets.CreateRange(parentFrame, {
                    name = "Line Amount",
                    get = function() return custom.glowLines or 8 end,
                    set = function(_, val)
                        db.spells[spellKey] = db.spells[spellKey] or {}
                        db.spells[spellKey].glowLines = val
                        RefreshAllReadyGlows()
                    end,
                    min = 1,
                    max = 16,
                    step = 1,
                }, yOffset, {})
                table.insert(parentFrame.widgets, glowLinesRange)
                yOffset = yOffset + 35
            end
            
            -- Glow Thickness (always visible - pixel glow only, but show for all)
            if Widgets and Widgets.CreateRange then
                local glowThicknessRange = Widgets.CreateRange(parentFrame, {
                    name = "Line Thickness",
                    get = function() return custom.glowThickness or 2 end,
                    set = function(_, val)
                        db.spells[spellKey] = db.spells[spellKey] or {}
                        db.spells[spellKey].glowThickness = val
                        RefreshAllReadyGlows()
                    end,
                    min = 1,
                    max = 10,
                    step = 1,
                }, yOffset, {})
                table.insert(parentFrame.widgets, glowThicknessRange)
                yOffset = yOffset + 35
            end
        end
    end
    
    parentFrame:SetHeight(math.max(yOffset, 400))
end

-- Apply customizations to viewer icons
function IconCustomization:ApplySpellCustomization(iconFrame, spellID)
    if not iconFrame or not spellID then return end
    
    local custom = GetSpellCustomization(spellID)
    if not custom or not IsSpellCustomized(spellID) then return end
    
    -- Hook cooldown frame for ready glow
    if custom.readyGlow == true then
        HookCooldownFrame(iconFrame)
    end
end

-- Hook an icon frame for ready glow
function IconCustomization:HookIconFrame(iconFrame)
    if not iconFrame then return end
    local spellID = GetSpellIDFromIcon(iconFrame)
    if not spellID then return end
    
    local custom = GetSpellCustomization(spellID)
    if custom.readyGlow == true then
        HookCooldownFrame(iconFrame)
    end
end

-- Initialize hooks - hook into SkinIcon to hook new icons
function IconCustomization:Initialize()
    if self.__initialized then return end
    self.__initialized = true
    
    -- Hook into IconViewers.SkinIcon to hook new icons as they're created
    if LilyUI.IconViewers and LilyUI.IconViewers.SkinIcon then
        local originalSkinIcon = LilyUI.IconViewers.SkinIcon
        function LilyUI.IconViewers:SkinIcon(icon, settings)
            local result = originalSkinIcon(self, icon, settings)
            
            -- Hook the icon for ready glow if it has customization
            if icon and (icon.icon or icon.Icon) and icon.Cooldown then
                IconCustomization:HookIconFrame(icon)
            end
            
            return result
        end
    end
    
    -- Hook existing icons in viewers
    C_Timer.After(1.0, function()
        local viewers = LilyUI.viewers or {
            "EssentialCooldownViewer",
            "UtilityCooldownViewer",
            "BuffIconCooldownViewer",
        }
        
        for _, viewerName in ipairs(viewers) do
            local viewer = _G[viewerName]
            if viewer then
                local container = viewer.viewerFrame or viewer
                for _, child in ipairs({ container:GetChildren() }) do
                    if child and (child.icon or child.Icon) and child.Cooldown then
                        IconCustomization:HookIconFrame(child)
                    end
                end
            end
        end
    end)
    
    -- Register events to refresh glow when cooldowns update
    if not self.__eventFrame then
        self.__eventFrame = CreateFrame("Frame")
        self.__eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self.__eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
        self.__eventFrame:SetScript("OnEvent", function(self, event)
            -- No throttling
            RefreshAllReadyGlows()
        end)
    end
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        IconCustomization:Initialize()
        initFrame:UnregisterAllEvents()
    end
end)
