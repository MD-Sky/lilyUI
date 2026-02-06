--[[
    LilyUI Unit Frames - Configuration GUI System
    Builds AceConfig options tables for party and raid frames
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames
local SpellProvider = ns.SpellProvider or (LilyUI and LilyUI.SpellProvider)

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
    local function Request(flags)
        self:RequestRefresh(frameType, flags)
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
                    Request({visibility = true, layout = true})
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
        self:RequestRefresh(frameType, {layout = true})
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
                UpdateLayout()
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
                UpdateLayout()
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
        auraLayoutHeader = {
            type = "header",
            name = "Aura Attachment",
            order = 30,
        },
        auraFramePadding = {
            type = "range",
            name = "Aura Padding",
            order = 31,
            min = 0, max = 20, step = 1,
            get = function() return GetDB().auraFramePadding or 0 end,
            set = function(_, val)
                GetDB().auraFramePadding = val
                self:RequestRefresh(frameType, {auras = true})
            end,
        },
        auraAnchor = {
            type = "select",
            name = "Aura Anchor",
            order = 32,
            values = {
                TOP = "Top",
                BOTTOM = "Bottom",
                LEFT = "Left",
                RIGHT = "Right",
            },
            get = function() return GetDB().auraAnchor or "BOTTOM" end,
            set = function(_, val)
                GetDB().auraAnchor = val
                self:RequestRefresh(frameType, {auras = true})
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
                self:RequestRefresh(frameType, {layout = true, visibility = true})
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
        self:RequestRefresh(frameType, {frames = true, style = true})
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
        self:RequestRefresh(frameType, {frames = true, style = true})
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
        self:RequestRefresh(frameType, {frames = true, style = true})
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
    local unitFrames = self
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end

    if self.EnsureCombatLists then
        self:EnsureCombatLists(GetDB())
    end
    
    local function UpdateFrames()
        self:RequestRefresh(frameType, {auras = true})
    end

    local function RefreshAuras()
        local count = 0
        if frameType == "party" then
            if self.partyFrames then
                for _ in pairs(self.partyFrames) do count = count + 1 end
            end
        else
            if self.raidFrames then
                for _ in pairs(self.raidFrames) do count = count + 1 end
            end
        end
        if self.RefreshAuraIcons then
            self:RefreshAuraIcons(frameType)
        else
            self:RequestRefresh(frameType, {auras = true})
        end
        if self.devMode and self.DebugPrint then
            self:DebugPrint("[PartyFrames] Auras refreshed (frames=" .. tostring(count) .. ")")
        end
        if SpellProvider and SpellProvider.Log then
            SpellProvider:Log("[PartyFrames] Auras refreshed (frames=" .. tostring(count) .. ")")
        end
    end

    local function EnsureCombatAuraTooltipHook()
        if self._combatAuraTooltipHooked then return end

        local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        local tooltip = (AceConfigDialog and AceConfigDialog.tooltip) or GameTooltip
        if not tooltip or not tooltip.HookScript then return end
        local hasScript = tooltip.HasScript
        if not hasScript or tooltip:HasScript("OnTooltipSetSpell") then
            tooltip:HookScript("OnTooltipSetSpell", function(tt)
                local spellId = self._combatTooltipSpellId
                if not spellId then return end
                tt:AddLine("SpellID: " .. spellId, 0.8, 0.8, 0.8, true)
                tt:Show()
            end)
        elseif not hasScript or tooltip:HasScript("OnShow") then
            tooltip:HookScript("OnShow", function(tt)
                local spellId = self._combatTooltipSpellId
                if not spellId then return end
                tt:AddLine("SpellID: " .. spellId, 0.8, 0.8, 0.8, true)
                tt:Show()
            end)
        end

        if not hasScript or tooltip:HasScript("OnHide") then
            tooltip:HookScript("OnHide", function()
                self._combatTooltipSpellId = nil
            end)
        end

        self._combatAuraTooltipHooked = true
    end

    local function NotifyOptionsChanged()
        local AceConfigRegistry = LibStub and LibStub("AceConfigRegistry-3.0", true)
        if AceConfigRegistry then
            AceConfigRegistry:NotifyChange(ADDON_NAME)
        end
    end

    local function RefreshOptionsUI()
        local configFrame = _G["LilyUI_ConfigFrame"]
        if configFrame and configFrame:IsShown() then
            if configFrame.SoftRefresh then
                configFrame:SoftRefresh()
            elseif configFrame.Refresh then
                configFrame:Refresh()
            elseif configFrame.FullRefresh then
                configFrame:FullRefresh()
            end
        end
    end

    local function GetSimpleGrowth(value)
        if type(value) ~= "string" then return nil end
        if value:find("LEFT") then return "LEFT" end
        if value:find("RIGHT") then return "RIGHT" end
        if value:find("UP") then return "UP" end
        if value:find("DOWN") then return "DOWN" end
        return nil
    end

    local function EnsureSpellList(listKey)
        local db = GetDB()
        if type(db[listKey]) ~= "table" then
            db[listKey] = {}
        end
        return db[listKey]
    end

    local function InputKey(listKey)
        return frameType .. "_" .. listKey
    end

    local function GetInputValue(listKey)
        local cache = self._combatSpellInputs
        if not cache then return "" end
        return cache[InputKey(listKey)] or ""
    end

    local function SetInputValue(listKey, value)
        self._combatSpellInputs = self._combatSpellInputs or {}
        self._combatSpellInputs[InputKey(listKey)] = value or ""
    end

    local function GetFinderState()
        self._combatSpellFinderState = self._combatSpellFinderState or {}
        local state = self._combatSpellFinderState[frameType]
        if not state then
            state = { target = "WHITELIST", mode = "NAME" }
            self._combatSpellFinderState[frameType] = state
        end
        return state
    end

    local function GetFinderTarget()
        return GetFinderState().target or "WHITELIST"
    end

    local function SetFinderTarget(val)
        GetFinderState().target = val or "WHITELIST"
    end

    local function GetFinderMode()
        return GetFinderState().mode or "NAME"
    end

    local function SetFinderMode(val)
        GetFinderState().mode = val or "NAME"
    end

    local function SpellFinderDebug(msg)
        if not msg then return end
        local text = "[SF] " .. tostring(msg)
        if LilyUI and LilyUI.DebugWindowLog then
            LilyUI:DebugWindowLog("SpellFinder", "%s", text)
        elseif self and self.devMode and self.DebugPrint then
            self:DebugPrint(text)
        end
    end

    local function SafeTrim(value)
        if type(value) == "string" then
            return value:match("^%s*(.-)%s*$") or value
        end
        if value == nil then return "" end
        local ok, str = pcall(tostring, value)
        if ok and type(str) == "string" then
            return str:match("^%s*(.-)%s*$") or str
        end
        return ""
    end

    local function ParseSpellId(value)
        if type(value) == "number" then
            return math.floor(value)
        end
        if type(value) ~= "string" then
            return nil
        end

        local linkId = value:match("Hspell:(%d+)") or value:match("spell:(%d+)")
        if linkId then
            return tonumber(linkId)
        end

        local num = tonumber(value:match("^%s*(%d+)%s*$")) or tonumber(value:match("%d+"))
        if num then
            return math.floor(num)
        end

        local trimmed = value:match("^%s*(.-)%s*$") or ""
        if trimmed ~= "" and GetSpellInfo then
            local _, _, _, _, _, _, spellId = GetSpellInfo(trimmed)
            if spellId then
                return spellId
            end
        end
        return nil
    end

    local function AddSpellIdValue(listKey, spellId, closePicker)
        if not spellId or spellId <= 0 then return end
        local list = EnsureSpellList(listKey)
        list[spellId] = true
        RefreshAuras()
        if unitFrames and unitFrames.RefreshAuraListsUI then
            unitFrames:RefreshAuraListsUI(frameType)
        end
        if closePicker and self._spellPickerFrame and self._spellPickerFrame.Hide then
            self._spellPickerFrame:Hide()
        end
        NotifyOptionsChanged()
        SpellFinderDebug("Add spellID=" .. tostring(spellId) .. " list=" .. tostring(listKey))
        if LilyUI and LilyUI.DebugWindowLog then
            local modeLabel = (type(listKey) == "string" and listKey:find("^combat")) and "combat" or "out"
            local filterMode = modeLabel == "combat" and (GetDB().combatFilterMode or "NONE") or (GetDB().buffFilterMode or "NONE")
            local targetLabel = "list"
            if filterMode == "WHITELIST" then
                targetLabel = "whitelist"
            elseif filterMode == "BLACKLIST" then
                targetLabel = "blacklist"
            end
            LilyUI:DebugWindowLog("Lists", "[Lists] Added spellID=%s list=%s mode=%s", tostring(spellId), tostring(listKey), tostring(modeLabel))
        end
    end

    local function AddSpellId(listKey)
        local spellId = ParseSpellId(GetInputValue(listKey))
        if not spellId or spellId <= 0 then return end
        AddSpellIdValue(listKey, spellId, false)
        SetInputValue(listKey, "")
    end

    local function RemoveSpellId(listKey, spellId)
        if not spellId then return end
        local list = EnsureSpellList(listKey)
        list[spellId] = nil
        if #list > 0 then
            for i = #list, 1, -1 do
                if list[i] == spellId then
                    table.remove(list, i)
                end
            end
        end
        RefreshAuras()
        if unitFrames and unitFrames.RefreshAuraListsUI then
            unitFrames:RefreshAuraListsUI(frameType)
        end
        if LilyUI and LilyUI.DebugWindowLog then
            local modeLabel = (type(listKey) == "string" and listKey:find("^combat")) and "combat" or "out"
            LilyUI:DebugWindowLog("Lists", "[Lists] Removed spellID=%s list=%s mode=%s", tostring(spellId), tostring(listKey), tostring(modeLabel))
        end
        NotifyOptionsChanged()
    end

    local function EnsureSpellPickerEvents()
        if self._spellPickerEventFrame then return end
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("SPELLS_CHANGED")
        eventFrame:RegisterEvent("PLAYER_LOGIN")
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        eventFrame:SetScript("OnEvent", function()
            if SpellProvider and SpellProvider.EnsureBuilt then
                SpellProvider:EnsureBuilt(true)
            end
            if self._spellPickerFrame and self._spellPickerFrame.IsShown and self._spellPickerFrame:IsShown() then
                if self._spellPickerFrame.RefreshList then
                    self._spellPickerFrame:RefreshList()
                end
            end
        end)
        self._spellPickerEventFrame = eventFrame
    end

    local function GetSpellPickerCache()
        if SpellProvider and SpellProvider.EnsureBuilt then
            SpellProvider:EnsureBuilt()
            return SpellProvider:GetAllSpells()
        end
        return {}
    end

    local function EnsureSpellPickerFrame()
        if self._spellPickerFrame then return self._spellPickerFrame end

        EnsureSpellPickerEvents()

        local frame = CreateFrame("Frame", "LilyUI_SpellPicker", UIParent, "BackdropTemplate")
        frame:SetSize(440, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        frame:SetBackdropColor(0.08, 0.08, 0.1, 0.95)
        frame:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
        title:SetText("Pick Spell")

        local targetText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        targetText:SetPoint("LEFT", title, "RIGHT", 8, 0)
        targetText:SetTextColor(0.7, 0.7, 0.7, 1)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

        local searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
        searchBox:SetSize(220, 20)
        searchBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        searchBox:SetAutoFocus(false)
        searchBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        local idBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        idBox:SetSize(220, 20)
        idBox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        idBox:SetAutoFocus(false)
        idBox:Hide()
        idBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 14)

        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetPoint("TOPLEFT")
        content:SetPoint("RIGHT")
        scrollFrame:SetScrollChild(content)

        frame.title = title
        frame.targetText = targetText
        frame.searchBox = searchBox
        frame.idBox = idBox
        frame.scrollFrame = scrollFrame
        frame.content = content
        frame.rows = {}

        local statusText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        statusText:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
        statusText:SetJustifyH("LEFT")
        statusText:Hide()

        local refreshButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        refreshButton:SetSize(90, 20)
        refreshButton:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
        refreshButton:SetText("Refresh")
        refreshButton:Hide()

        local rowHeight = 24

        local function UpdateRows(spells)
            local filterText = SafeTrim((searchBox and searchBox.GetText and searchBox:GetText()) or "")
            spells = spells or GetSpellPickerCache()
            local filtered = (SpellProvider and SpellProvider.Filter and SpellProvider:Filter(spells, filterText)) or spells or {}
            local modeLabel = (frame.mode == "ID") and "ID" or "NAME"

            local function BuildFirst3(entries)
                local parts = {}
                for i = 1, math.min(3, #entries) do
                    local e = entries[i]
                    if e then
                        local id = e.spellID or "?"
                        local name = e.name or "?"
                        parts[#parts + 1] = tostring(id) .. ":" .. tostring(name)
                    end
                end
                return table.concat(parts, ", ")
            end

            SpellFinderDebug("RefreshList start. mode=" .. modeLabel .. " query=\"" .. tostring(filterText or "") .. "\"")
            SpellFinderDebug("Filter results=" .. tostring(#filtered) .. " (first3: " .. BuildFirst3(filtered) .. ")")

            for i, spell in ipairs(filtered) do
                local row = frame.rows[i]
                if not row then
                    row = CreateFrame("Button", nil, content)
                    row:SetHeight(rowHeight)
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowHeight))
                    row:SetPoint("RIGHT", content, "RIGHT", -4, 0)

                    row.icon = row:CreateTexture(nil, "ARTWORK")
                    row.icon:SetSize(18, 18)
                    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)

                    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
                    row.name:SetPoint("RIGHT", row, "RIGHT", -60, 0)
                    row.name:SetJustifyH("LEFT")

                    row.id = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    row.id:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                    row.id:SetJustifyH("RIGHT")
                    row.id:SetTextColor(0.7, 0.7, 0.7, 1)

                    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                    local hl = row:GetHighlightTexture()
                    if hl then
                        hl:SetBlendMode("ADD")
                    end

                    row:SetScript("OnEnter", function(selfRow)
                        if not selfRow.spellID then return end
                        GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
                        GameTooltip:SetSpellByID(selfRow.spellID)
                        GameTooltip:AddLine("SpellID: " .. selfRow.spellID, 0.7, 0.7, 0.7)
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    row:SetScript("OnClick", function(selfRow)
                        if not selfRow.spellID then return end
                        AddSpellIdValue(frame.targetListKey, selfRow.spellID, true)
                    end)

                    frame.rows[i] = row
                else
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * rowHeight))
                end

                row.spellID = spell.spellID
                row.icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                local nameText = spell.name or ("Spell " .. tostring(spell.spellID))
                if spell.isExternal then
                    nameText = nameText .. " (not in spellbook)"
                end
                row.name:SetText(nameText)
                row.id:SetText(spell.spellID)
                row:Show()
            end

            for i = #filtered + 1, #frame.rows do
                frame.rows[i]:Hide()
            end

            local totalSpells = spells and #spells or 0
            local results = #filtered

            if totalSpells == 0 then
                statusText:SetText(frame._spellFinderLoading and "Loading spells..." or "No spells found yet. Try again in a moment.")
                statusText:Show()
                refreshButton:Show()
                SpellFinderDebug("Empty: provider=0 filter=" .. tostring(results) .. " reason=provider empty")
            elseif results == 0 then
                statusText:SetText("No results")
                statusText:Show()
                refreshButton:Hide()
                SpellFinderDebug("Empty: provider=" .. tostring(totalSpells) .. " filter=0 reason=filter empty")
            else
                statusText:Hide()
                refreshButton:Hide()
            end

            content:SetHeight(math.max(1, (math.max(results, statusText:IsShown() and 1 or 0) * rowHeight) + 4))

            SpellFinderDebug("Rows created=" .. tostring(results) .. " rowsShown=" .. tostring(results) .. " scrollChildHeight=" .. tostring(content:GetHeight() or 0))
        end

        local idStatus = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        idStatus:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 4, -10)
        idStatus:SetText("Enter a spell ID or spell link.")
        idStatus:SetTextColor(0.7, 0.7, 0.7, 1)
        idStatus:Hide()

        local idRow = CreateFrame("Frame", nil, frame)
        idRow:SetHeight(28)
        idRow:SetPoint("TOPLEFT", idBox, "BOTTOMLEFT", 0, -6)
        idRow:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
        idRow:Hide()

        idRow.icon = idRow:CreateTexture(nil, "ARTWORK")
        idRow.icon:SetSize(20, 20)
        idRow.icon:SetPoint("LEFT", idRow, "LEFT", 4, 0)

        idRow.name = idRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        idRow.name:SetPoint("LEFT", idRow.icon, "RIGHT", 6, 0)
        idRow.name:SetPoint("RIGHT", idRow, "RIGHT", -80, 0)
        idRow.name:SetJustifyH("LEFT")

        idRow.id = idRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        idRow.id:SetPoint("RIGHT", idRow, "RIGHT", -55, 0)
        idRow.id:SetJustifyH("RIGHT")
        idRow.id:SetTextColor(0.7, 0.7, 0.7, 1)

        idRow.add = CreateFrame("Button", nil, idRow, "UIPanelButtonTemplate")
        idRow.add:SetSize(48, 20)
        idRow.add:SetPoint("RIGHT", idRow, "RIGHT", -4, 0)
        idRow.add:SetText("Add")

        local function UpdateIdPreview()
            local input = idBox:GetText() or ""
            local spellId = ParseSpellId(input)
            local info = nil
            if spellId and C_Spell and C_Spell.GetSpellInfo then
                local ok, t = pcall(C_Spell.GetSpellInfo, spellId)
                if ok then info = t end
            end
            local name = spellId and ((info and info.name) or (GetSpellInfo and GetSpellInfo(spellId))) or nil
            if spellId and name and name ~= "" then
                local icon = (info and (info.iconID or info.icon)) or (GetSpellTexture and GetSpellTexture(spellId)) or nil
                if not icon and C_Spell and C_Spell.GetSpellTexture then
                    local ok, t = pcall(C_Spell.GetSpellTexture, spellId)
                    if ok then icon = t end
                end
                icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
                idRow.spellID = spellId
                idRow.icon:SetTexture(icon)
                idRow.name:SetText(tostring(name))
                idRow.id:SetText(spellId)
                idRow:Show()
                idStatus:Hide()
            else
                idRow.spellID = nil
                idRow:Hide()
                idStatus:Show()
            end
        end

        idRow:SetScript("OnEnter", function(selfRow)
            if not selfRow.spellID then return end
            GameTooltip:SetOwner(selfRow, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(selfRow.spellID)
            GameTooltip:AddLine("SpellID: " .. selfRow.spellID, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        idRow:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        idRow.add:SetScript("OnClick", function()
            if not idRow.spellID then return end
            AddSpellIdValue(frame.targetListKey, idRow.spellID, true)
        end)

        function frame:RefreshList()
            local modeLabel = (self.mode == "ID") and "ID" or "NAME"
            local queryText = SafeTrim((searchBox and searchBox.GetText and searchBox:GetText()) or "")
            SpellFinderDebug("RefreshList start. mode=" .. modeLabel .. " query=\"" .. tostring(queryText or "") .. "\"")
            local spells = GetSpellPickerCache()
            SpellFinderDebug("Provider built. totalSpells=" .. tostring(spells and #spells or 0))
            if spells and #spells == 0 then
                self._spellFinderEmptyAttempts = (self._spellFinderEmptyAttempts or 0) + 1
                SpellFinderDebug("empty spell list")
            else
                self._spellFinderEmptyAttempts = 0
            end
            self._spellFinderLoading = (self._spellFinderEmptyAttempts == 1)
            UpdateRows(spells)
            if spells and #spells == 0 and SpellProvider and SpellProvider.RefreshSoon and not self._spellFinderRetry then
                self._spellFinderRetry = true
                SpellFinderDebug("scheduling refresh")
                SpellProvider:RefreshSoon(function()
                    self._spellFinderRetry = nil
                    if frame and frame.IsShown and frame:IsShown() then
                        frame:RefreshList()
                    end
                end)
            end
        end

        function frame:RefreshIdPreview()
            UpdateIdPreview()
        end

        function frame:SetMode(mode)
            self.mode = mode or "NAME"
            local isId = self.mode == "ID"
            searchBox:SetShown(not isId)
            scrollFrame:SetShown(not isId)
            if not isId then
                idBox:Hide()
                idRow:Hide()
                idStatus:Hide()
            else
                idBox:Show()
                UpdateIdPreview()
            end
        end

        searchBox:SetScript("OnTextChanged", function()
            if frame.mode ~= "ID" then
                frame:RefreshList()
            end
        end)

        idBox:SetScript("OnTextChanged", function()
            if frame.mode == "ID" then
                frame:RefreshIdPreview()
            end
        end)

        refreshButton:SetScript("OnClick", function()
            if SpellProvider and SpellProvider.EnsureBuilt then
                SpellProvider:EnsureBuilt(true)
            end
            frame:RefreshList()
        end)

        frame:SetScript("OnShow", function()
            SpellFinderDebug("OnShow")
            frame._spellFinderEmptyAttempts = 0
            if frame.mode == "ID" then
                frame:RefreshIdPreview()
            else
                frame:RefreshList()
            end
        end)

        self._spellPickerFrame = frame
        return frame
    end

    local function OpenSpellFinder()
        local target = GetFinderTarget()
        local mode = GetFinderMode()
        local modeKey = (mode == "ID") and "ID" or "NAME"
        local listKey = target == "BLACKLIST" and "combatBlacklistSpellList" or "combatWhitelistSpellList"
        local label = target == "BLACKLIST" and "Blacklist Spell IDs" or "Whitelist Spell IDs"
        local frame = EnsureSpellPickerFrame()
        frame.targetListKey = listKey
        local modeLabel = mode == "ID" and "ID Search" or "Icon/Name Search"
        frame.targetText:SetText(label and ("|cffcfcfcf->|r " .. label .. " | " .. modeLabel) or "")
        frame.searchBox:SetText("")
        frame.searchBox:ClearFocus()
        frame.idBox:SetText("")
        frame.idBox:ClearFocus()
        frame:SetMode(mode)
        if SpellProvider and SpellProvider.EnsureBuilt then
            SpellProvider:EnsureBuilt()
        end
        local spells = GetSpellPickerCache()
        local results = (SpellProvider and SpellProvider.Filter and SpellProvider:Filter(spells, "")) or spells or {}
        SpellFinderDebug("Opened. mode=" .. modeKey .. " query=\"\"")
        SpellFinderDebug("Open: spells=" .. tostring(spells and #spells or 0) .. " query=\"\" results=" .. tostring(results and #results or 0))
        local wasShown = frame:IsShown()
        frame:Show()
        frame:Raise()
        if mode == "ID" then
            frame:RefreshIdPreview()
        end
        frame:RefreshList()
        if (not wasShown) and spells and #spells == 0 and SpellProvider and SpellProvider.RefreshSoon then
            SpellProvider:RefreshSoon(function()
                if frame and frame.IsShown and frame:IsShown() then
                    frame:RefreshList()
                end
            end)
        end
    end

    local function BuildSpellLabel(spellId)
        local name = GetSpellInfo and GetSpellInfo(spellId) or nil
        local texture = GetSpellTexture and GetSpellTexture(spellId) or nil
        local label = name and (name .. " (" .. spellId .. ")") or tostring(spellId)
        if texture then
            label = ("|T%s:14:14:0:0:64:64:4:60:4:60|t %s"):format(texture, label)
        end
        return label
    end

    local function CollectSpellIds(listKey)
        local list = EnsureSpellList(listKey)
        local ids = {}
        local seen = {}
        for k, v in pairs(list) do
            local id
            if type(k) == "number" and v == true then
                id = k
            elseif type(v) == "number" then
                id = v
            elseif type(v) == "string" then
                id = tonumber(v)
            end
            if id and not seen[id] then
                seen[id] = true
                table.insert(ids, id)
            end
        end
        table.sort(ids)
        return ids
    end

    local function BuildSpellListArgs(listKey, orderStart)
        local args = {}
        local ids = CollectSpellIds(listKey)
        local order = orderStart or 1
        if #ids == 0 then
            args.empty = {
                type = "description",
                name = "(none)",
                order = order,
            }
            return args
        end
        for _, id in ipairs(ids) do
            local spellId = id
            args["remove_" .. spellId] = {
                type = "execute",
                name = "Remove " .. BuildSpellLabel(spellId),
                order = order,
                tooltipHyperlink = function()
                    if GetSpellInfo and GetSpellInfo(spellId) then
                        self._combatTooltipSpellId = spellId
                        return "spell:" .. spellId
                    end
                    return nil
                end,
                desc = function()
                    if GetSpellInfo and GetSpellInfo(spellId) then
                        return "SpellID: " .. spellId
                    end
                    return "Unknown spell ID: " .. spellId
                end,
                func = function() RemoveSpellId(listKey, spellId) end,
            }
            order = order + 1
        end
        return args
    end

    local displayArgs = {
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
        buffIconSpacing = {
            type = "range",
            name = "Icon Spacing",
            order = 5,
            min = 0, max = 20, step = 1,
            get = function() return GetDB().buffIconSpacing or GetDB().buffPaddingX or 2 end,
            set = function(_, val)
                GetDB().buffIconSpacing = val
                UpdateFrames()
            end,
        },
        buffIconsPerRow = {
            type = "range",
            name = "Icons Per Row",
            order = 6,
            min = 1, max = 16, step = 1,
            get = function() return GetDB().buffIconsPerRow or GetDB().buffWrap or 4 end,
            set = function(_, val)
                GetDB().buffIconsPerRow = val
                UpdateFrames()
            end,
        },
        buffGrowthDirection = {
            type = "select",
            name = "Growth Direction",
            order = 7,
            values = {
                RIGHT = "Right",
                LEFT = "Left",
                UP = "Up",
                DOWN = "Down",
            },
            get = function()
                return GetDB().buffGrowthDirection or GetSimpleGrowth(GetDB().buffGrowth) or "LEFT"
            end,
            set = function(_, val)
                GetDB().buffGrowthDirection = val
                UpdateFrames()
            end,
        },
        buffDurationSize = {
            type = "range",
            name = "Duration Font Size",
            order = 8,
            min = 6, max = 24, step = 1,
            get = function() return GetDB().buffDurationSize or GetDB().auraDurationSize or 9 end,
            set = function(_, val)
                GetDB().buffDurationSize = val
                UpdateFrames()
            end,
        },
        buffStackPosition = {
            type = "select",
            name = "Stacks Position",
            order = 9,
            values = {
                TOPRIGHT = "Top Right",
                TOPLEFT = "Top Left",
                BOTTOMRIGHT = "Bottom Right",
                BOTTOMLEFT = "Bottom Left",
            },
            get = function() return GetDB().buffStackPosition or "BOTTOMRIGHT" end,
            set = function(_, val)
                GetDB().buffStackPosition = val
                UpdateFrames()
            end,
        },

        -- TEST: you should see this block directly under Buff Size
        buffTextNotice = {
            type = "description",
            name = "|cff00ff00Text Size Controls (TEST - should appear)|r",
            order = 15,
        },
        buffTextSize = {
            type = "range",
            name = "Buff Text Size (TEST)",
            order = 16,
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
        debuffIconSpacing = {
            type = "range",
            name = "Icon Spacing",
            order = 14,
            min = 0, max = 20, step = 1,
            get = function() return GetDB().debuffIconSpacing or GetDB().debuffPaddingX or 2 end,
            set = function(_, val)
                GetDB().debuffIconSpacing = val
                UpdateFrames()
            end,
        },
        debuffIconsPerRow = {
            type = "range",
            name = "Icons Per Row",
            order = 15,
            min = 1, max = 16, step = 1,
            get = function() return GetDB().debuffIconsPerRow or GetDB().debuffWrap or 4 end,
            set = function(_, val)
                GetDB().debuffIconsPerRow = val
                UpdateFrames()
            end,
        },
        debuffGrowthDirection = {
            type = "select",
            name = "Growth Direction",
            order = 16,
            values = {
                RIGHT = "Right",
                LEFT = "Left",
                UP = "Up",
                DOWN = "Down",
            },
            get = function()
                return GetDB().debuffGrowthDirection or GetSimpleGrowth(GetDB().debuffGrowth) or "RIGHT"
            end,
            set = function(_, val)
                GetDB().debuffGrowthDirection = val
                UpdateFrames()
            end,
        },
        debuffDurationSize = {
            type = "range",
            name = "Duration Font Size",
            order = 17,
            min = 6, max = 24, step = 1,
            get = function() return GetDB().debuffDurationSize or GetDB().auraDurationSize or 9 end,
            set = function(_, val)
                GetDB().debuffDurationSize = val
                UpdateFrames()
            end,
        },
        debuffStackPosition = {
            type = "select",
            name = "Stacks Position",
            order = 18,
            values = {
                TOPRIGHT = "Top Right",
                TOPLEFT = "Top Left",
                BOTTOMRIGHT = "Bottom Right",
                BOTTOMLEFT = "Bottom Left",
            },
            get = function() return GetDB().debuffStackPosition or "BOTTOMRIGHT" end,
            set = function(_, val)
                GetDB().debuffStackPosition = val
                UpdateFrames()
            end,
        },

        -- TEST: you should see this block directly under Debuff Size
        debuffTextNotice = {
            type = "description",
            name = "|cff00ff00Text Size Controls (TEST - should appear)|r",
            order = 24,
        },
        debuffTextSize = {
            type = "range",
            name = "Debuff Text Size (TEST)",
            order = 25,
            min = 6, max = 22, step = 1,
            get = function() return GetDB().debuffTextSize or GetDB().auraStackSize or 10 end,
            set = function(_, val)
                GetDB().debuffTextSize = val
                UpdateFrames()
            end,
        },
    }

    local buffListArgs = {
        buffSpellId = {
            type = "input",
            name = "Spell ID",
            order = 1,
            width = "half",
            get = function() return GetInputValue("combatWhitelistSpellList") end,
            set = function(_, val) SetInputValue("combatWhitelistSpellList", val) end,
        },
        buffSpellAdd = {
            type = "execute",
            name = "Add",
            order = 2,
            width = "half",
            disabled = function() return not ParseSpellId(GetInputValue("combatWhitelistSpellList")) end,
            func = function() AddSpellId("combatWhitelistSpellList") end,
        },
        buffSpellListHeader = {
            type = "description",
            name = "Current entries:",
            order = 3,
        },
    }
    local buffRemoveArgs = BuildSpellListArgs("combatWhitelistSpellList", 10)
    for key, value in pairs(buffRemoveArgs) do
        buffListArgs[key] = value
    end

    local debuffListArgs = {
        debuffSpellId = {
            type = "input",
            name = "Spell ID",
            order = 1,
            width = "half",
            get = function() return GetInputValue("combatBlacklistSpellList") end,
            set = function(_, val) SetInputValue("combatBlacklistSpellList", val) end,
        },
        debuffSpellAdd = {
            type = "execute",
            name = "Add",
            order = 2,
            width = "half",
            disabled = function() return not ParseSpellId(GetInputValue("combatBlacklistSpellList")) end,
            func = function() AddSpellId("combatBlacklistSpellList") end,
        },
        debuffSpellListHeader = {
            type = "description",
            name = "Current entries:",
            order = 3,
        },
    }
    local debuffRemoveArgs = BuildSpellListArgs("combatBlacklistSpellList", 10)
    for key, value in pairs(debuffRemoveArgs) do
        debuffListArgs[key] = value
    end

    local combatArgs = {
        combatForm = {
            type = "group",
            name = "Combat Controls",
            order = 1,
            inline = true,
            width = "full",
            args = {
                combatDisplayMode = {
                    type = "select",
                    name = "Duration Display",
                    order = 1,
                    width = "full",
                    values = {
                        TEXT = "Text only",
                        SWIPE = "Swipe only",
                        BOTH = "Text + Swipe",
                    },
                    get = function() return GetDB().combatDisplayMode or "BOTH" end,
                    set = function(_, val)
                        GetDB().combatDisplayMode = val
                        RefreshAuras()
                    end,
                },
                combatAuraDebugEnabled = {
                    type = "toggle",
                    name = "Enable Combat Aura Debug",
                    order = 2,
                    width = "full",
                    get = function() return GetDB().combatAuraDebugEnabled end,
                    set = function(_, val)
                        GetDB().combatAuraDebugEnabled = val
                        if SpellProvider then
                            SpellProvider.debugEnabled = val
                        end
                        if val and LilyUI and LilyUI.DebugWindowLog then
                            LilyUI:DebugWindowLog("CombatAuras", "Combat aura debug enabled")
                        end
                    end,
                },
                combatAuraDebugSpellId = {
                    type = "input",
                    name = "Debug Spell ID (optional)",
                    order = 3,
                    width = "full",
                    get = function()
                        local value = GetDB().combatAuraDebugSpellId
                        return value and value ~= 0 and tostring(value) or ""
                    end,
                    set = function(_, val)
                        local spellId = ParseSpellId(val)
                        GetDB().combatAuraDebugSpellId = spellId or 0
                    end,
                },
                combatFilterEnabled = {
                    type = "toggle",
                    name = "Enable Combat Filtering",
                    order = 4,
                    width = "full",
                    get = function() return GetDB().combatFilterEnabled end,
                    set = function(_, val)
                        GetDB().combatFilterEnabled = val
                        if LilyUI and LilyUI.DebugWindowLog then
                            LilyUI:DebugWindowLog("CombatAuras", "Combat filter enabled=%s", tostring(val))
                        end
                        RefreshAuras()
                    end,
                },
                combatFilterMode = {
                    type = "select",
                    name = "Filter Mode",
                    order = 5,
                    width = "full",
                    values = {
                        NONE = "None",
                        WHITELIST = "Whitelist",
                        BLACKLIST = "Blacklist",
                    },
                    get = function() return GetDB().combatFilterMode or "NONE" end,
                    set = function(_, val)
                        GetDB().combatFilterMode = val
                        if LilyUI and LilyUI.DebugWindowLog then
                            LilyUI:DebugWindowLog("CombatAuras", "Combat filter mode=%s", tostring(val))
                        end
                        RefreshAuras()
                    end,
                },
                finderMode = {
                    type = "select",
                    name = "Search Mode",
                    order = 6,
                    width = "full",
                    values = {
                        NAME = "Icon/Name Search",
                        ID = "ID Search",
                    },
                    get = function() return GetFinderMode() end,
                    set = function(_, val) SetFinderMode(val) end,
                },
                combatFilterAppliesTo = {
                    type = "select",
                    name = "Applies To",
                    order = 7,
                    width = "full",
                    values = {
                        BOTH = "Buffs + Debuffs",
                        BUFFS = "Buffs Only",
                        DEBUFFS = "Debuffs Only",
                    },
                    get = function() return GetDB().combatFilterAppliesTo or "BOTH" end,
                    set = function(_, val)
                        GetDB().combatFilterAppliesTo = val
                        if LilyUI and LilyUI.DebugWindowLog then
                            LilyUI:DebugWindowLog("CombatAuras", "Combat filter appliesTo=%s", tostring(val))
                        end
                        RefreshAuras()
                    end,
                },
                finderTarget = {
                    type = "select",
                    name = "Add To",
                    order = 8,
                    width = "full",
                    values = {
                        WHITELIST = "Whitelist",
                        BLACKLIST = "Blacklist",
                    },
                    get = function() return GetFinderTarget() end,
                    set = function(_, val) SetFinderTarget(val) end,
                },
                finderOpen = {
                    type = "execute",
                    name = "Open Spell Finder",
                    order = 9,
                    width = "full",
                    func = function() OpenSpellFinder() end,
                },
            },
        },
        combatBuffList = {
            type = "group",
            name = "Whitelist Spell IDs",
            order = 20,
            inline = true,
            width = "full",
            args = buffListArgs,
        },
        combatDebuffList = {
            type = "group",
            name = "Blacklist Spell IDs",
            order = 30,
            inline = true,
            width = "full",
            args = debuffListArgs,
        },
    }

    EnsureCombatAuraTooltipHook()
    if self.RegisterAuraListsWidget then
        self:RegisterAuraListsWidget()
    end

    return {
        type = "group",
        name = "Auras",
        order = 6,
        childGroups = "tab",
        args = {
            displayTab = {
                type = "group",
                name = "Buffs/Debuffs",
                order = 1,
                args = displayArgs,
            },
            combatTab = {
                type = "group",
                name = "Combat",
                order = 2,
                args = combatArgs,
            },
            listsTab = {
                type = "group",
                name = "Whitelist / Blacklist",
                order = 3,
                args = {
                    listsPage = {
                        type = "description",
                        name = "",
                        order = 1,
                        width = "full",
                        dialogControl = "LilyUIAuraListsPage",
                        frameType = frameType,
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- AURA LISTS UI (Whitelist / Blacklist)
-- ============================================================================

function UnitFrames:RegisterAuraListsWidget()
    if self._auraListsWidgetRegistered then return end
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then return end

    local Type, Version = "LilyUIAuraListsPage", 1
    if (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
        self._auraListsWidgetRegistered = true
        return
    end

    local function NormalizeFrameType(value)
        if not value then return nil end
        local v = tostring(value):lower()
        if v:find("raid") then
            return "raid"
        end
        if v:find("party") then
            return "party"
        end
        return nil
    end

    local function ResolveFrameType(widget)
        if not widget then return nil end
        if widget._fixedFrameType then
            return NormalizeFrameType(widget._fixedFrameType)
        end

        local option = widget.GetUserData and widget:GetUserData("option") or nil
        local user = widget.GetUserDataTable and widget:GetUserDataTable() or nil
        if not option and user then
            option = user.option
        end

        local frameType = option and (option.frameType or option.mode)
        frameType = NormalizeFrameType(frameType)
        if frameType then
            return frameType
        end

        local path = user and user.path
        local pathStr = ""
        if type(path) == "table" then
            pathStr = table.concat(path, "/")
        elseif path ~= nil then
            pathStr = tostring(path)
        end
        frameType = NormalizeFrameType(pathStr)
        if frameType then
            return frameType
        end

        if UnitFrames and UnitFrames._auraListsFrameTypeFallbackLogged ~= true then
            UnitFrames._auraListsFrameTypeFallbackLogged = true
            if LilyUI and LilyUI.DebugWindowLog then
                LilyUI:DebugWindowLog("Lists", "[AuraListsUI] frameType missing; defaulting to party")
            end
        end
        return "party"
    end

    local function TryBuild(widget)
        if not widget or widget._listsBuilt then return end
        local frameType = ResolveFrameType(widget) or "party"
        if UnitFrames and UnitFrames.CreateAuraListsUI then
            local host = widget.content or widget.frame
            local ok, err = pcall(UnitFrames.CreateAuraListsUI, UnitFrames, host, frameType)
            if not ok and host and host.CreateFontString then
                local label = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                label:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -12)
                label:SetText("|cffff6060Unable to build aura lists: " .. tostring(err) .. "|r")
            end
            widget._listsBuilt = true
        end
    end

    local methods = {
        OnAcquire = function(self)
            self:SetWidth(300)
            self:SetHeight(420)
            if self.frame and self.frame.SetHeight then
                self.frame:SetHeight(420)
            end
            if self.content and self.content.SetHeight then
                self.content:SetHeight(420)
            end
            self._listsBuilt = false
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() TryBuild(self) end)
            else
                TryBuild(self)
            end
        end,
        OnRelease = function(self)
            self._listsBuilt = false
        end,
        OnWidthSet = function(self, width)
            local content = self.content or self.frame
            if content then
                content:SetWidth(width)
                content.width = width
            end
        end,
        OnHeightSet = function(self, height)
            local targetHeight = height
            if not targetHeight or targetHeight < 200 then
                targetHeight = 420
            end
            if self.frame and self.frame.SetHeight then
                self.frame:SetHeight(targetHeight)
            end
            local content = self.content or self.frame
            if content then
                content:SetHeight(targetHeight)
                content.height = targetHeight
            end
        end,
        SetText = function(self, text)
            self._labelText = text
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function() TryBuild(self) end)
            else
                TryBuild(self)
            end
        end,
        SetDisabled = function() end,
    }

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()

        local content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT")
        content:SetPoint("BOTTOMRIGHT")

        local widget = {
            frame = frame,
            content = content,
            type = Type,
        }
        for method, func in pairs(methods) do
            widget[method] = func
        end

        frame.obj = widget
        frame:SetScript("OnShow", function(selfFrame)
            local obj = selfFrame.obj
            if obj then
                if not obj._wlblLoggedThisShow and LilyUI and LilyUI.DebugWindowLog then
                    obj._wlblLoggedThisShow = true
                    local parent = (obj and obj.content) or selfFrame
                    local parentExists = parent ~= nil
                    local w = (parent and parent.GetWidth and parent:GetWidth()) or 0
                    local h = (parent and parent.GetHeight and parent:GetHeight()) or 0
                    LilyUI:DebugWindowLog("System", "[GUI] [WL/BL] Subtab selected (parent=%s size=%sx%s)", tostring(parentExists), tostring(w), tostring(h))
                end
                TryBuild(obj)
            end
        end)
        frame:SetScript("OnHide", function(selfFrame)
            local obj = selfFrame.obj
            if obj then
                obj._wlblLoggedThisShow = nil
            end
        end)

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
    self._auraListsWidgetRegistered = true
end

function UnitFrames:RefreshAuraListsUI(frameType)
    if not self._auraListsFrames then return end
    local frame = self._auraListsFrames[frameType]
    if frame and frame._refreshLists then
        frame:_refreshLists()
    end
end

function UnitFrames:CreateAuraListsUI(parent, frameType)
    local function WLBLDebug(fmt, ...)
        if LilyUI and type(LilyUI.DebugWindowLog) == "function" then
            if select("#", ...) > 0 then
                local ok, out = pcall(string.format, fmt, ...)
                if ok then
                    LilyUI:DebugWindowLog("System", "%s", out)
                else
                    LilyUI:DebugWindowLog("System", "%s", fmt)
                end
            else
                LilyUI:DebugWindowLog("System", "%s", fmt)
            end
        end
    end

    if not parent then
        WLBLDebug("[GUI] [WL/BL] ERROR: parent/container is nil - aborting")
        return
    end

    -- Temporary: detach all WL/BL logic and show a single placeholder panel for visibility.
    local function BuildPlaceholder(force)
        local parentW = (parent.GetWidth and parent:GetWidth()) or 0
        local parentH = (parent.GetHeight and parent:GetHeight()) or 0
        WLBLDebug("[GUI] [WL/BL] Open/build start parentSize=%sx%s", tostring(parentW), tostring(parentH))

        if (parentW <= 1 or parentH <= 1) and not force then
            if not parent._wlblDeferred then
                parent._wlblDeferred = true
                WLBLDebug("[GUI] [WL/BL] Parent size 0, deferring once")
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if parent and parent.GetWidth then
                            BuildPlaceholder(true)
                        end
                    end)
                    return
                end
            end
        end

        local THEME = (LilyUI and LilyUI.GUI and LilyUI.GUI.THEME) or {
            bgMedium = {0.115, 0.130, 0.155, 0.95},
            borderLight = {0.280, 0.280, 0.320, 0.9},
            text = {0.96, 0.96, 0.98},
            textDim = {0.72, 0.72, 0.78},
        }

        local function SetBackdrop(frame, bg, border)
            if not frame or not frame.SetBackdrop then
                if frame and Mixin and BackdropTemplateMixin then
                    Mixin(frame, BackdropTemplateMixin)
                else
                    return
                end
            end

            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false,
                edgeSize = 1,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            if bg then
                frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
            end
            if border then
                frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
            end
        end

        local function ApplyFont(fs, size, r, g, b, a)
            if not fs then return end
            local fontPath = LilyUI and LilyUI.GetGlobalFont and LilyUI:GetGlobalFont()
            local _, oldSize = fs:GetFont()
            size = size or oldSize or 12
            if fontPath then
                fs:SetFont(fontPath, size, "OUTLINE")
            end
            fs:SetShadowOffset(0, 0)
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetTextColor(r or THEME.text[1], g or THEME.text[2], b or THEME.text[3], a or 1)
        end

        local function CreatePanel(parentFrame)
            local f = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
            SetBackdrop(f, THEME.bgMedium, THEME.borderLight)
            return f
        end

        local panel = parent._wlblPlaceholder
        if not panel then
            panel = CreatePanel(parent)
            parent._wlblPlaceholder = panel

            local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ApplyFont(label, 12, THEME.textDim[1], THEME.textDim[2], THEME.textDim[3], 1)
            label:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
            label:SetJustifyH("LEFT")
            label:SetWidth(520)
            label:SetText("This page is queued for a later update.\n\nWhitelist/Blacklist tools are being rebuilt.")
            panel._placeholderLabel = label
        else
            panel:Show()
        end

        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -34)
        panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -6, 6)
        panel:Show()

        if panel._placeholderLabel then
            panel._placeholderLabel:SetText("This page is queued for a later update.\n\nWhitelist/Blacklist tools are being rebuilt.")
        end

        local children = { parent:GetChildren() }
        for i = 1, #children do
            local child = children[i]
            if child and child ~= panel and child.Hide then
                child:Hide()
            end
        end

        local lw = (panel.GetWidth and panel:GetWidth()) or 0
        local lh = (panel.GetHeight and panel:GetHeight()) or 0
        WLBLDebug("[GUI] [WL/BL] Placeholder panel created shown=%s size=%sx%s", tostring(panel:IsShown()), tostring(lw), tostring(lh))
    end

    BuildPlaceholder(false)
    return

end

-- ============================================================================
-- ICON OPTIONS
-- ============================================================================

function UnitFrames:BuildIconOptions(frameType, isRaid)
    local function GetDB()
        return isRaid and self:GetRaidDB() or self:GetDB()
    end
    
    local function UpdateFrames()
        self:RequestRefresh(frameType, {frames = true, style = true})
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
    
    local function UpdateHighlights()
        self:RequestRefresh(frameType, {highlights = true})
    end

    local function UpdateRange()
        self:RequestRefresh(frameType, {range = true})
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
                    UpdateHighlights()
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
                    UpdateHighlights()
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
                    UpdateHighlights()
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
                    UpdateRange()
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
                    UpdateRange()
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
                    self:RequestRefresh(frameType, {
                        visibility = true,
                        layout = true,
                        style = true,
                        frames = true,
                        auras = true,
                        highlights = true,
                        range = true,
                    })
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
                    self:RequestRefresh(frameType, {
                        visibility = true,
                        layout = true,
                        style = true,
                        frames = true,
                        auras = true,
                        highlights = true,
                        range = true,
                    })
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
                    print("Export string generated. Use /lilyui export to view.")
                end,
            },
        },
    }
end
