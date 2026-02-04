local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Click casting config UI.
-- Mirrors Clique's workflow (bindings list + spell picker) but styled to match LilyUI.

if not LilyUI then return end

LilyUI.PartyFrames = LilyUI.PartyFrames or {}
LilyUI.PartyFrames.ClickCast = LilyUI.PartyFrames.ClickCast or {}
local ClickCast = LilyUI.PartyFrames.ClickCast

-- ============================================================================
-- ENGINE BRIDGE
-- ============================================================================
-- The click-cast engine lives on LilyUI.PartyFrames (UnitFrames), while this UI
-- lives on LilyUI.PartyFrames.ClickCast. Provide thin wrappers so the UI can
-- read/write bindings reliably.

local UF = LilyUI and LilyUI.PartyFrames

local function ToEngineMod(mod)
    if not mod or mod == "" or mod == "nomod" then
        return ""
    end
    return tostring(mod):lower()
end

local function ToUiMod(mod)
    if not mod or mod == "" then
        return "nomod"
    end
    return tostring(mod):lower()
end

local function EnsureBindingsLoaded()
    UF = UF or (LilyUI and LilyUI.PartyFrames)
    if UF and UF.LoadClickCastBindings then
        UF:LoadClickCastBindings()
    end
end

local function GetBindingEntry(button, uiMod)
    EnsureBindingsLoaded()
    if not (UF and UF.ClickCastBindings) then
        return nil
    end
    local engMod = ToEngineMod(uiMod)
    local key
    if UF.BuildBindingKey then
        key = UF:BuildBindingKey(button, engMod)
    else
        key = (engMod ~= "" and (engMod .. "-" .. button) or button)
    end
    return UF.ClickCastBindings[key]
end

local function GetBindingString(button, uiMod)
    local b = GetBindingEntry(button, uiMod)
    if not b or not b.spell or b.spell == "" then
        return nil
    end
    if b.isMacro then
        return "macro:" .. tostring(b.spell)
    end
    return tostring(b.spell)
end

function ClickCast:GetClickCastBinding(button, modifier)
    return GetBindingString(button, modifier)
end

function ClickCast:SetClickCastBinding(button, modifier, spellOrMacro, isMacro)
    if UF and UF.SetClickCastBinding then
        local payload = spellOrMacro
        if type(payload) == "string" and payload:match("^macro:") then
            payload = payload:gsub("^macro:", "")
        end
        UF:SetClickCastBinding(button, ToEngineMod(modifier), payload, isMacro and true or false)
    end
end

function ClickCast:RemoveClickCastBinding(button, modifier)
    if UF and UF.RemoveClickCastBinding then
        UF:RemoveClickCastBinding(button, ToEngineMod(modifier))
    end
end

function ClickCast:UpdateClickCasting()
    if UF and UF.UpdateAllClickCastFrames and not InCombatLockdown() then
        UF:UpdateAllClickCastFrames()
    end
end


local THEME = (LilyUI.GUI and LilyUI.GUI.THEME) or {
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
    accent = {1.00, 0.25, 0.65},
}

local _G = _G
local CreateFrame = CreateFrame
local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber
local strlower, strmatch, strtrim = string.lower, string.match, string.trim
local tinsert, sort, wipe = table.insert, table.sort, wipe

-- WoW API compatibility:
-- Newer clients may not expose GetSpellInfo() globally.
-- Prefer C_Spell.GetSpellInfo(), fallback to _G.GetSpellInfo().
local function CompatGetSpellInfo(spellIdentifier)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellIdentifier)
        if ok and info then
            return info.name, nil, (info.iconID or info.icon)
        end
    end
    if _G and _G.GetSpellInfo then
        return _G.GetSpellInfo(spellIdentifier)
    end
    return (type(spellIdentifier) == "string" and spellIdentifier or tostring(spellIdentifier)), nil, nil
end

local function CompatGetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and name then
            return name
        end
    end
    local name = select(1, CompatGetSpellInfo(spellID))
    return name
end

local function ApplyFont(fs, size, r, g, b, a)
    if not fs then return end
    local fontPath = LilyUI.GetGlobalFont and LilyUI:GetGlobalFont()
    local _, oldSize = fs:GetFont()
    size = size or oldSize or 12
    if fontPath then
        fs:SetFont(fontPath, size, "OUTLINE")
    end
    fs:SetShadowOffset(0, 0)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(r or THEME.text[1], g or THEME.text[2], b or THEME.text[3], a or 1)
end

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

local function CreatePanel(parent)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    SetBackdrop(f, THEME.bgMedium, THEME.borderLight)
    return f
end

local function CreateLabel(parent, text, size, dim)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(fs, size or 12, dim and THEME.textDim[1] or THEME.text[1], dim and THEME.textDim[2] or THEME.text[2], dim and THEME.textDim[3] or THEME.text[3], 1)
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    return fs
end

local function CreateButton(parent, text, width, height, isSmall)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 80, height or 18)
    SetBackdrop(btn, THEME.bgLight, THEME.borderLight)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(label, isSmall and 11 or 12)
    label:SetPoint("CENTER")
    label:SetText(text or "Button")
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3], 0.85)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.85)
    end)
    btn:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(THEME.primaryActive[1], THEME.primaryActive[2], THEME.primaryActive[3], 0.9)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3], 0.85)
    end)

    return btn
end

local function CreateIcon(parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size or 18, size or 18)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return t
end

local BUTTON_NAMES = {
    LeftButton = "Left",
    RightButton = "Right",
    MiddleButton = "Middle",
    Button4 = "Button4",
    Button5 = "Button5",
}

local MOD_NAMES = {
    nomod = "None",
    shift = "Shift",
    ctrl = "Ctrl",
    alt = "Alt",
}

local function FormatBind(mod, button)
    local m = MOD_NAMES[mod or "nomod"] or tostring(mod or "None")
    local b = BUTTON_NAMES[button] or tostring(button or "?")
    if mod and mod ~= "nomod" then
        return m .. " + " .. b
    end
    return b
end

local function GetSpellIconAndName(spellOrName)
    if not spellOrName or spellOrName == "" then
        return nil, nil
    end

    -- Try ID
    local spellID = tonumber(spellOrName)
    local name, icon

    if spellID then
        name = CompatGetSpellName(spellID)
        local _, _, tex = CompatGetSpellInfo(spellID)
        icon = tex
        if (not icon) and C_Spell and C_Spell.GetSpellTexture then
            local ok, t = pcall(C_Spell.GetSpellTexture, spellID)
            if ok then icon = t end
        end
        return icon, name
    end

    -- Name string (may not resolve to an icon on modern APIs; keep name at least)
    name = tostring(spellOrName)
    local _, _, tex = CompatGetSpellInfo(name)
    icon = tex
    return icon, name
end

-- Build a spell list from the player's spellbook.
-- Uses C_SpellBook (modern) with fallbacks.
function ClickCast:BuildSpellCache()
    self._spellCache = self._spellCache or { all = {}, general = {}, class = {}, spec = {} }
    wipe(self._spellCache.all)
    wipe(self._spellCache.general)
    wipe(self._spellCache.class)
    wipe(self._spellCache.spec)

    if LilyUI and LilyUI.DebugLog then
        LilyUI:DebugLog("ClickCastUI: BuildSpellCache() start")
    end

    local specName
    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex then
            local _, name = GetSpecializationInfo(specIndex)
            specName = name
        end
    end

    local seen = {}

    local function AddSpell(spellID, skillLineName, skillLineIndex)
        if not spellID or spellID == 0 or seen[spellID] then
            return
        end
        local spellName = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or select(1, CompatGetSpellInfo(spellID))
        if not spellName or spellName == "" then
            return
        end

        local _, _, icon = CompatGetSpellInfo(spellID)
        if (not icon) and C_Spell and C_Spell.GetSpellTexture then
            local ok, t = pcall(C_Spell.GetSpellTexture, spellID)
            if ok then icon = t end
        end

        seen[spellID] = true
        local entry = {
            spellID = spellID,
            name = spellName,
            icon = icon,
            lineName = skillLineName,
            lineIndex = skillLineIndex,
        }
        tinsert(self._spellCache.all, entry)

        -- Categorize
        local lineLower = skillLineName and strlower(skillLineName)
        local isGeneral = (skillLineIndex == 1) or (lineLower == "general")
        local isSpec = false
        if specName and skillLineName and strlower(specName) == strlower(skillLineName) then
            isSpec = true
        end

        if isGeneral then
            tinsert(self._spellCache.general, entry)
        elseif isSpec then
            tinsert(self._spellCache.spec, entry)
        else
            tinsert(self._spellCache.class, entry)
        end
    end

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local typeSpell = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        local typeFuture = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell

        local numLines = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for i = 1, numLines do
            local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
            local offset = lineInfo and lineInfo.itemIndexOffset or 0
            local numSlots = lineInfo and lineInfo.numSpellBookItems or 0
            local lineName = lineInfo and (lineInfo.name or lineInfo.skillLineName)

            for slot = offset + 1, offset + numSlots do
                local itemInfo = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if itemInfo then
                    local itemType = itemInfo.itemType
                    local id = itemInfo.actionID
                    if (typeSpell and itemType == typeSpell) or (typeFuture and itemType == typeFuture) or (not typeSpell and id) then
                        AddSpell(id, lineName, i)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        -- Legacy fallback
        local tabs = GetNumSpellTabs() or 0
        for i = 1, tabs do
            local name, _, offset, numSlots = GetSpellTabInfo(i)
            for j = offset + 1, offset + numSlots do
                local skillType, spellID = GetSpellBookItemInfo(j, BOOKTYPE_SPELL)
                if skillType == "SPELL" or skillType == "FUTURESPELL" then
                    AddSpell(spellID, name, i)
                end
            end
        end
    end

    sort(self._spellCache.all, function(a, b) return a.name < b.name end)
    sort(self._spellCache.general, function(a, b) return a.name < b.name end)
    sort(self._spellCache.class, function(a, b) return a.name < b.name end)
    sort(self._spellCache.spec, function(a, b) return a.name < b.name end)

    self._spellCacheBuilt = true

    if LilyUI and LilyUI.DebugLog then
        LilyUI:DebugLog(
            "ClickCastUI: Spell cache built - all=" .. tostring(#self._spellCache.all)
                .. " general=" .. tostring(#self._spellCache.general)
                .. " class=" .. tostring(#self._spellCache.class)
                .. " spec=" .. tostring(#self._spellCache.spec)
        )
    end
end

local function FlattenBindings()
    local out = {}

    -- NOTE: Don't reload bindings on every UI refresh.
    -- Reloading here can wipe newly-added runtime bindings if the DB table
    -- hasn't been fully initialized yet. We load once on page open.
    UF = UF or (LilyUI and LilyUI.PartyFrames)

    if not (UF and UF.ClickCastBindings) then
        return out
    end

    for _, binding in pairs(UF.ClickCastBindings) do
        if binding and binding.button and binding.spell and binding.spell ~= "" then
            local uiMod = ToUiMod(binding.modifier)
            local icon, name = GetSpellIconAndName(binding.spell)
            table.insert(out, {
                modifier = uiMod,
                button = binding.button,
                binding = (binding.isMacro and ("macro:" .. tostring(binding.spell))) or tostring(binding.spell),
                isMacro = binding.isMacro and true or false,
                displayName = name or tostring(binding.spell),
                displayIcon = icon,
            })
        end
    end

    table.sort(out, function(a, b)
        if a.modifier == b.modifier then
            return tostring(a.button) < tostring(b.button)
        end
        -- Put "nomod" first for readability
        if a.modifier == "nomod" then return true end
        if b.modifier == "nomod" then return false end
        return tostring(a.modifier) < tostring(b.modifier)
    end)

    return out
end

local function ClearChildren(frame)
    if not frame then return end
    local children = { frame:GetChildren() }
    for i = 1, #children do
        local c = children[i]
        c:Hide()
        c:SetParent(nil)
    end
end

-- A single shared capture overlay so we don't leak frames.
local CaptureOverlay
local function GetCaptureOverlay()
    if CaptureOverlay then
        return CaptureOverlay
    end

    local f = CreateFrame("Frame", "LilyUI_ClickCastCaptureOverlay", UIParent, "BackdropTemplate")
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)

    local card = CreatePanel(f)
    card:SetSize(460, 120)
    card:SetPoint("CENTER")

    local title = CreateLabel(card, "Bind Click", 14, false)
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -12)

    local hint = CreateLabel(card, "Press a mouse button (with optional Shift/Ctrl/Alt).", 12, true)
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)

    local cancel = CreateButton(card, "Cancel", 90, 20, true)
    cancel:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 12)
    cancel:SetScript("OnClick", function()
        f:Hide()
        if f.onCancel then
            f.onCancel()
        end
    end)

    f.title = title
    f.hint = hint
    f.card = card

    CaptureOverlay = f
    return f
end


function ClickCast:HideCaptureOverlay()
    if CaptureOverlay then
        CaptureOverlay:Hide()
    end
end

-- Hard-close any currently rendered ClickCast UI.
-- This is used by the config system when the user navigates away, because
-- some parts of the config UI can reuse content frames.
function ClickCast:CloseClickCastUI()
    -- Hide capture overlay if it's up
    if self.HideCaptureOverlay then
        self:HideCaptureOverlay()
    end

    -- Hide the last embed we rendered into
    if self._activeUI and self._activeUI.embed then
        local e = self._activeUI.embed
        if e and e.Hide then
            e:Hide()
        end
        -- Defensive: clear children so nothing lingers if it was reparented.
        if e then
            ClearChildren(e)
        end
    end
    self._activeUI = nil
end

-- Keep the ClickCast UI sane across spec/spellbook changes and character swaps.
-- (Prevents the capture overlay/config page lingering into the character screen.)
if not ClickCast._uiEventFrame then
    local ef = CreateFrame('Frame')
    ef:RegisterEvent('PLAYER_LEAVING_WORLD')
    ef:RegisterEvent('SPELLS_CHANGED')
    ef:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
    ef:RegisterEvent('PLAYER_TALENT_UPDATE')

    ef:SetScript('OnEvent', function(_, event)
        if event == 'PLAYER_LEAVING_WORLD' then
            if CaptureOverlay then
                CaptureOverlay:Hide()
            end
            ClickCast._activeUI = nil
            return
        end

        -- Spellbook/spec changes: rebuild cache and refresh any open UI.
        ClickCast._spellCacheBuilt = false
        if ClickCast.BuildSpellCache then
            ClickCast:BuildSpellCache()
        end
        if ClickCast._activeUI and ClickCast._activeUI.refresh then
            ClickCast._activeUI.refresh()
        end
    end)

    ClickCast._uiEventFrame = ef
end

local function GetActiveModifier()
    local ctrl = IsControlKeyDown and IsControlKeyDown() or false
    local alt = IsAltKeyDown and IsAltKeyDown() or false
    local shift = IsShiftKeyDown and IsShiftKeyDown() or false

    -- ClickCast engine currently supports a single modifier bucket.
    if ctrl then return "ctrl" end
    if alt then return "alt" end
    if shift then return "shift" end
    return "nomod"
end

-- Main entry point called by the config GUI (custom widget type: clickCastingPage).
function ClickCast:CreateClickCastUI(embed, defaultTab)
    if not embed then return end

    -- If another ClickCast tab's embed is still around, hide it.
    -- (Some config navigation paths don't reliably fire OnHide on the old widget.)
    if self._activeUI and self._activeUI.embed and self._activeUI.embed ~= embed then
        local old = self._activeUI.embed
        if old and old.Hide then old:Hide() end
        if old then ClearChildren(old) end
        self._activeUI = nil
    end

    ClearChildren(embed)

    -- Load bindings once when opening the page so the list can render immediately.
    EnsureBindingsLoaded()

    -- Ensure the bind-capture overlay never lingers when switching config sections/tabs.
    if self.HideCaptureOverlay then
        self:HideCaptureOverlay()
    end

    local tab = defaultTab or "spells"

    if LilyUI and LilyUI.DebugLog then
        LilyUI:DebugLog("ClickCastUI: CreateClickCastUI(tab=" .. tostring(tab) .. ")")
    end

    -- Basic title/header area
    local header = CreateLabel(embed, "Click Cast", 14)
    header:SetPoint("TOPLEFT", embed, "TOPLEFT", 6, -6)

    local sub = CreateLabel(embed, tab:gsub("^%l", string.upper), 12, true)
    sub:SetPoint("LEFT", header, "RIGHT", 10, 0)

    -- Enable toggle (applies to party/raid frames click casting engine)
    local enableBtn = CreateFrame("CheckButton", nil, embed, "UICheckButtonTemplate")
    enableBtn:SetPoint("TOPRIGHT", embed, "TOPRIGHT", -8, -6)
    enableBtn:SetSize(24, 24)
    enableBtn.text = enableBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ApplyFont(enableBtn.text, 12, THEME.text[1], THEME.text[2], THEME.text[3], 1)
    enableBtn.text:SetPoint("RIGHT", enableBtn, "LEFT", -6, 0)
    enableBtn.text:SetText("Enable")

    local function RefreshEnable()
        UF = UF or (LilyUI and LilyUI.PartyFrames)
        local enabled = true
        if UF and UF.GetClickCastDB then
            local db = UF:GetClickCastDB()

            -- Toggle logic for enabling/disabling Click Casting
            if db and db.clickCastEnabled then
                enabled = db.clickCastEnabled
            else
                enabled = false  -- Default to false if not set
            end
                end
        enableBtn:SetChecked(enabled)
    end

    enableBtn:SetScript("OnClick", function(self)
        UF = UF or (LilyUI and LilyUI.PartyFrames)
        local val = self:GetChecked() and true or false

        if UF and UF.GetClickCastDB then
            local db = UF:GetClickCastDB()
            if db then
                db.clickCastEnabled = val
            end
        end

        if not InCombatLockdown() then
            if val then
                if ClickCast.UpdateClickCasting then
                    ClickCast:UpdateClickCasting()
                elseif UF and UF.UpdateAllClickCastFrames then
                    UF:UpdateAllClickCastFrames()
                end
            else
                if UF and UF.ClickCastFrames and UF.ClearClickCastFromFrame then
                    for frame in pairs(UF.ClickCastFrames) do
                        UF:ClearClickCastFromFrame(frame)
                    end
                end
            end
        end

        RefreshEnable()
    end)

    RefreshEnable()

    -- Placeholder pages for later tabs
    if tab ~= "spells" then
        local panel = CreatePanel(embed)
        panel:SetPoint("TOPLEFT", embed, "TOPLEFT", 6, -34)
        panel:SetPoint("BOTTOMRIGHT", embed, "BOTTOMRIGHT", -6, 6)
        local txt = CreateLabel(panel, "This page is queued for a later update.\n\nRight now we’re building the Spells workflow first (bindings list + spell picker).", 12, true)
        txt:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12)
        txt:SetJustifyH("LEFT")
        txt:SetWidth(520)
        return
    end

    -- Ensure we have a spell cache (spellbook can load/refresh after login/spec changes)
    if (not self._spellCacheBuilt) or (not self._spellCache) or (not self._spellCache.all) or (#self._spellCache.all == 0) then
        self:BuildSpellCache()
    end

    local state = {
        selected = nil,   -- { modifier, button }
        draft = nil,      -- { modifier, button } when adding new binding before spell chosen
        draftSpell = nil, -- { spellID, name, icon }
        filter = "class", -- general/class/spec
    }

    -- Layout columns
    local left = CreatePanel(embed)
    left:SetPoint("TOPLEFT", embed, "TOPLEFT", 6, -34)
    left:SetPoint("BOTTOMLEFT", embed, "BOTTOMLEFT", 6, 6)
    left:SetPoint("RIGHT", embed, "CENTER", -4, 0)

    local right = CreatePanel(embed)
    -- Match the left panel's top edge and fill the full height.
    -- (Old anchor used embed CENTER which made this panel only half height.)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", embed, "BOTTOMRIGHT", -6, 6)

    -- Left header row (responsive so it doesn't spill into the right panel)
    local hSpell = CreateLabel(left, "Spell", 12)
    hSpell:SetPoint("TOPLEFT", left, "TOPLEFT", 10, -10)

    local hRem = CreateLabel(left, "Remove", 12, true)
    -- Rows live inside the scroll area with right inset (-28) and button inset (-10)
    hRem:SetPoint("TOPRIGHT", left, "TOPRIGHT", -38, -10)
	-- FontStrings anchored to RIGHT but left-justified will extend *into* the right panel.
	-- Force right-justify (and give a sane width) so the header never overlaps "Available Spells".
	hRem:SetJustifyH("RIGHT")
	hRem:SetWidth(70)

    local hEdit = CreateLabel(left, "Edit", 12, true)
    hEdit:SetPoint("RIGHT", hRem, "LEFT", -28, 0)
	hEdit:SetJustifyH("RIGHT")
	hEdit:SetWidth(50)

    local hSet = CreateLabel(left, "Bind", 12, true)
    hSet:SetPoint("RIGHT", hEdit, "LEFT", -56, 0)
	hSet:SetJustifyH("RIGHT")
	hSet:SetWidth(60)

    local hBind = CreateLabel(left, "Modifier", 12, true)
    hBind:SetPoint("RIGHT", hSet, "LEFT", -70, 0)
	hBind:SetJustifyH("RIGHT")
	hBind:SetWidth(80)

    local divider = left:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.6)
    divider:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -28)
    divider:SetPoint("TOPRIGHT", left, "TOPRIGHT", -8, -28)
    divider:SetHeight(1)

    -- Scroll container
    local scroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", left, "TOPLEFT", 8, -34)
    scroll:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", -28, 44)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(1, 1)
    scroll:SetScrollChild(scrollChild)

    -- Keep the scroll child width in sync so rows can stretch full width
    scroll:HookScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 1 then
            scrollChild:SetWidth(w)
        end
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if scroll and scrollChild then
                local w = scroll:GetWidth()
                if w and w > 1 then
                    scrollChild:SetWidth(w)
                end
            end
        end)
    end

    -- Remove default scrollframe textures to better match theme
    local sb = scroll.ScrollBar
    if not sb and scroll.GetName then
        local n = scroll:GetName()
        if n then sb = _G[n .. "ScrollBar"] end
    end
    if sb then
        if sb.Track then
            sb.Track:Hide()
        end
        if sb.GetThumbTexture then
            local thumb = sb:GetThumbTexture()
            if thumb then
                thumb:SetColorTexture(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.85)
                thumb:SetSize(8, 20)
            end
        end
    end

    local rows = {}

    local function SetStatus(text)
        if right.status then
            right.status:SetText(text or "")
        end
    end

    local function SelectBinding(mod, btn)
        state.selected = mod and btn and { modifier = mod, button = btn } or nil
        state.draft = nil
        state.draftSpell = nil
    end

    local function BeginBindCapture(mode, payload)
        local overlay = GetCaptureOverlay()
        overlay.mode = mode
        overlay.payload = payload
        overlay.onCancel = function()
            SetStatus("Bind canceled.")
        end

        overlay:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" or button == "RightButton" or button == "MiddleButton" or button == "Button4" or button == "Button5" then
                local mod = GetActiveModifier()
                self:Hide()
                if self.onBind then
                    self.onBind(mod, button)
                end
            end
        end)

        overlay.onBind = function(mod, button)
            if overlay.mode == "rebind" then
                local old = overlay.payload
                if not old or not old.modifier or not old.button then
                    return
                end
                local oldMod, oldBtn = old.modifier, old.button

                -- Move binding to new slot
                local binding = ClickCast:GetClickCastBinding(oldBtn, oldMod)
                if binding then
                    ClickCast:RemoveClickCastBinding(oldBtn, oldMod)
                    -- Overwrite if needed
                    ClickCast:RemoveClickCastBinding(button, mod)
                    ClickCast:SetClickCastBinding(button, mod, binding, binding:match("^macro:") ~= nil)
                    SelectBinding(mod, button)
                    SetStatus("Bound: " .. FormatBind(mod, button))
                end
            elseif overlay.mode == "add" then
                -- New binding slot chosen; wait for spell selection (or commit if already selected)
                state.draft = { modifier = mod, button = button }
                if state.draftSpell and state.draftSpell.name then
					-- IMPORTANT: SelectBinding() clears draftSpell, so capture the name before calling it.
					local spellName = state.draftSpell.name
                    ClickCast:RemoveClickCastBinding(button, mod)
					ClickCast:SetClickCastBinding(button, mod, spellName, false)
                    state.draft = nil
                    SelectBinding(mod, button)
					SetStatus("Added: " .. spellName .. " (" .. FormatBind(mod, button) .. ")")
                else
                    SetStatus("Now pick a spell for " .. FormatBind(mod, button) .. ".")
                end
            end

            if ClickCast.UpdateClickCasting and not InCombatLockdown() then
                ClickCast:UpdateClickCasting()
            end

            if left.RefreshList then
                left:RefreshList()
            end
            if right.RefreshPicker then
                right:RefreshPicker()
            end
        end

        overlay:Show()
        overlay:SetFrameStrata("DIALOG")
        overlay:Raise()
    end

    local function RemoveBinding(mod, btn)
        ClickCast:RemoveClickCastBinding(btn, mod)
        if state.selected and state.selected.modifier == mod and state.selected.button == btn then
            state.selected = nil
        end
        if ClickCast.UpdateClickCasting and not InCombatLockdown() then
            ClickCast:UpdateClickCasting()
        end
        SetStatus("Removed binding.")
        if left.RefreshList then
            left:RefreshList()
        end
        if right.RefreshPicker then
            right:RefreshPicker()
        end
    end

    local function SetSpellForSelected(spellEntry)
        if not spellEntry or not spellEntry.name then
            return
        end

        -- If a draft binding exists, commit it.
        if state.draft and state.draft.modifier and state.draft.button then
            local mod, btn = state.draft.modifier, state.draft.button
            ClickCast:RemoveClickCastBinding(btn, mod)
            ClickCast:SetClickCastBinding(btn, mod, spellEntry.name, false)
            state.draft = nil
            SelectBinding(mod, btn)
            SetStatus("Added: " .. spellEntry.name .. " (" .. FormatBind(mod, btn) .. ")")
            if ClickCast.UpdateClickCasting and not InCombatLockdown() then
                ClickCast:UpdateClickCasting()
            end
            if left.RefreshList then left:RefreshList() end
            if right.RefreshPicker then right:RefreshPicker() end
            return
        end

        -- If no binding selected yet, do a spell-first flow: pick spell, then capture the click.
        if not state.selected or not state.selected.modifier or not state.selected.button then
            state.draftSpell = spellEntry
            SetStatus("Spell selected: " .. spellEntry.name .. ". Now choose the click bind.")
            if right.RefreshPicker then right:RefreshPicker() end
            if left.RefreshList then left:RefreshList() end
            BeginBindCapture("add")
            return
        end

        local mod, btn = state.selected.modifier, state.selected.button
        ClickCast:SetClickCastBinding(btn, mod, spellEntry.name, false)
        SetStatus("Updated: " .. spellEntry.name)

        if ClickCast.UpdateClickCasting and not InCombatLockdown() then
            ClickCast:UpdateClickCasting()
        end
        if left.RefreshList then left:RefreshList() end
        if right.RefreshPicker then right:RefreshPicker() end
    end

    function left:RefreshList()
        -- Clear old rows
        for i = 1, #rows do
            rows[i]:Hide()
            rows[i]:SetParent(nil)
        end
        wipe(rows)

        local data = FlattenBindings()

        -- If the user picked a spell first, show a pending draft row until they pick the click bind.
        if (not state.selected) and (not state.draft) and state.draftSpell and state.draftSpell.name then
            tinsert(data, 1, {
                modifier = nil,
                button = nil,
                binding = "",
                isSpellDraft = true,
                displayName = state.draftSpell.name,
                displayIcon = state.draftSpell.icon,
            })
        end

        -- Inject draft row if user started "Add" flow and already picked a bind
        if state.draft and state.draft.modifier and state.draft.button then
            tinsert(data, 1, {
                modifier = state.draft.modifier,
                button = state.draft.button,
                binding = "",
                isDraft = true,
                displayName = state.draftSpell and state.draftSpell.name or "<Pick a spell>" ,
                displayIcon = state.draftSpell and state.draftSpell.icon or nil,
            })
        end

        local y = -2
        local rowH = 26
        local totalH = 0

        for i = 1, #data do
            local entry = data[i]
            local row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, y)
            row:SetHeight(rowH)
            SetBackdrop(row, THEME.bgDark, THEME.border)

            row.icon = CreateIcon(row, 18)
            row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
            if entry.displayIcon then
                row.icon:SetTexture(entry.displayIcon)
            else
                row.icon:SetTexture(nil)
            end

            -- Right-side controls (anchor from the right so the list never spills into the right panel)
            row.remBtn = CreateButton(row, "X", 26, 18, true)
            row.remBtn:SetPoint("RIGHT", row, "RIGHT", -10, 0)

            row.editBtn = CreateButton(row, "Edit", 46, 18, true)
            row.editBtn:SetPoint("RIGHT", row.remBtn, "LEFT", -6, 0)

            row.bindBtn = CreateButton(row, "Bind", 52, 18, true)
            row.bindBtn:SetPoint("RIGHT", row.editBtn, "LEFT", -10, 0)
            row.bindBtn:SetScript("OnClick", function()
                BeginBindCapture("rebind", { modifier = entry.modifier, button = entry.button })
            end)

            row.bindText = CreateLabel(row, FormatBind(entry.modifier, entry.button), 12, true)
            row.bindText:SetPoint("RIGHT", row.bindBtn, "LEFT", -10, 0)
            row.bindText:SetWidth(110)
            row.bindText:SetJustifyH("RIGHT")

            row.name = CreateLabel(row, entry.displayName or "", 12)
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.name:SetPoint("RIGHT", row.bindText, "LEFT", -10, 0)
            row.name:SetJustifyH("LEFT")

            if entry.isSpellDraft then
                row.bindText:SetText("Pick bind...")
                row.bindBtn:SetScript("OnClick", function()
                    BeginBindCapture("add")
                end)
            end

            row.editBtn:SetScript("OnClick", function()
                SelectBinding(entry.modifier, entry.button)
                SetStatus("Editing: " .. (entry.displayName or "") .. " (" .. FormatBind(entry.modifier, entry.button) .. ")")
                if right.RefreshPicker then right:RefreshPicker() end
                if left.RefreshList then left:RefreshList() end
            end)

            if entry.isSpellDraft then
                if row.editBtn.Disable then row.editBtn:Disable() end
                if row.editBtn.SetAlpha then row.editBtn:SetAlpha(0.4) end
            end

            row.remBtn:SetScript("OnClick", function()
                if entry.isSpellDraft then
                    state.draftSpell = nil
                    if ClickCast.HideCaptureOverlay then
                        ClickCast:HideCaptureOverlay()
                    end
                    SetStatus("Draft cleared.")
                    left:RefreshList()
                    if right.RefreshPicker then right:RefreshPicker() end
                    return
                end
                if entry.isDraft then
                    state.draft = nil
                    SetStatus("Draft cleared.")
                    left:RefreshList()
                    if right.RefreshPicker then right:RefreshPicker() end
                    return
                end
                RemoveBinding(entry.modifier, entry.button)
            end)

            row:SetScript("OnClick", function()
                SelectBinding(entry.modifier, entry.button)
                SetStatus("Selected: " .. (entry.displayName or "") .. " (" .. FormatBind(entry.modifier, entry.button) .. ")")
                if right.RefreshPicker then right:RefreshPicker() end
                left:RefreshList()
            end)

            if entry.isSpellDraft then
                row:SetScript("OnClick", function()
                    SetStatus("Pick your click bind for: " .. (entry.displayName or ""))
                    BeginBindCapture("add")
                end)
            end

            row:SetScript("OnEnter", function(self)
                if not (state.selected and state.selected.modifier == entry.modifier and state.selected.button == entry.button) then
                    self:SetBackdropColor(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.35)
                end
            end)
            row:SetScript("OnLeave", function(self)
                if not (state.selected and state.selected.modifier == entry.modifier and state.selected.button == entry.button) then
                    self:SetBackdropColor(THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85)
                end
            end)

            -- Selection highlight
            if state.selected and state.selected.modifier == entry.modifier and state.selected.button == entry.button and not entry.isDraft then
                row:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.35)
            elseif entry.isDraft then
                row:SetBackdropColor(THEME.primaryHover[1], THEME.primaryHover[2], THEME.primaryHover[3], 0.25)
            else
                row:SetBackdropColor(THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85)
            end

            rows[i] = row
            y = y - rowH - 2
            totalH = totalH + rowH + 2
        end

        scrollChild:SetHeight(totalH + 2)
    end

    local addBtn = CreateButton(left, "+ Add Spell Binding", 160, 20, true)
    addBtn:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 10, 12)
    addBtn:SetScript("OnClick", function()
        state.selected = nil
        state.draft = nil
        state.draftSpell = nil
        SetStatus("Choose a spell, then pick your click bind.")
        if right.RefreshPicker then right:RefreshPicker() end
    end)

    local bindNewBtn = CreateButton(left, "Bind Click", 110, 20, true)
    bindNewBtn:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
    bindNewBtn:SetScript("OnClick", function()
        BeginBindCapture("add")
    end)

    -- Right panel: filters + spell list
    local pickerTitle = CreateLabel(right, "Available Spells", 12)
    pickerTitle:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -10)

    local filterBar = CreateFrame("Frame", nil, right)
    filterBar:SetPoint("TOPLEFT", right, "TOPLEFT", 10, -30)
    filterBar:SetPoint("TOPRIGHT", right, "TOPRIGHT", -10, -30)
    filterBar:SetHeight(22)

    local btnGeneral = CreateButton(filterBar, "General", 84, 20, true)
    btnGeneral:SetPoint("LEFT", filterBar, "LEFT", 0, 0)

    local btnClass = CreateButton(filterBar, "Class", 74, 20, true)
    btnClass:SetPoint("LEFT", btnGeneral, "RIGHT", 6, 0)

    local btnSpec = CreateButton(filterBar, "Spec", 70, 20, true)
    btnSpec:SetPoint("LEFT", btnClass, "RIGHT", 6, 0)

    local function SetFilter(f)
        state.filter = f
        if right.RefreshPicker then right:RefreshPicker() end
    end

    btnGeneral:SetScript("OnClick", function() SetFilter("general") end)
    btnClass:SetScript("OnClick", function() SetFilter("class") end)
    btnSpec:SetScript("OnClick", function() SetFilter("spec") end)

    local function UpdateFilterVisuals()
        local function SetActive(btn, active)
            if active then
                btn:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.85)
            else
                btn:SetBackdropColor(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.85)
            end
        end
        SetActive(btnGeneral, state.filter == "general")
        SetActive(btnClass, state.filter == "class")
        SetActive(btnSpec, state.filter == "spec")
    end

    local rightDivider = right:CreateTexture(nil, "ARTWORK")
    rightDivider:SetColorTexture(THEME.borderLight[1], THEME.borderLight[2], THEME.borderLight[3], 0.6)
    rightDivider:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -58)
    rightDivider:SetPoint("TOPRIGHT", right, "TOPRIGHT", -8, -58)
    rightDivider:SetHeight(1)

    local spScroll = CreateFrame("ScrollFrame", nil, right, "UIPanelScrollFrameTemplate")
    spScroll:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -64)
    spScroll:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -28, 44)

    local spChild = CreateFrame("Frame", nil, spScroll)
    spChild:SetSize(1, 1)
    spScroll:SetScrollChild(spChild)

    -- Keep the spell picker scroll child width in sync
    spScroll:HookScript("OnSizeChanged", function(self)
        local w = self:GetWidth()
        if w and w > 1 then
            spChild:SetWidth(w)
        end
    end)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if spScroll and spChild then
                local w = spScroll:GetWidth()
                if w and w > 1 then
                    spChild:SetWidth(w)
                end
            end
        end)
    end

    local spellRows = {}

    -- Status line
    right.status = CreateLabel(right, "", 12, true)
    right.status:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 10, 14)
    right.status:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -10, 14)
    right.status:SetJustifyH("LEFT")

    local function GetCurrentSpellName()
        if state.selected and state.selected.modifier and state.selected.button then
            local binding = ClickCast:GetClickCastBinding(state.selected.button, state.selected.modifier)
            if binding and type(binding) == "string" and binding ~= "" and not binding:match("^macro:") then
                return binding
            end
        end
        return nil
    end

    function right:RefreshPicker()
        -- Active filter visuals
        UpdateFilterVisuals()

        -- Clear
        for i = 1, #spellRows do
            spellRows[i]:Hide()
            spellRows[i]:SetParent(nil)
        end
        wipe(spellRows)

        local list = ClickCast._spellCache and ClickCast._spellCache[state.filter] or nil
        if not list or #list == 0 then
            list = ClickCast._spellCache and ClickCast._spellCache.all or {}
        end

        local currentSpell = GetCurrentSpellName()
        local y = -2
        local rowH = 24
        local totalH = 0

        for i = 1, #list do
            local entry = list[i]
            local row = CreateFrame("Button", nil, spChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", spChild, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", spChild, "TOPRIGHT", 0, y)
            row:SetHeight(rowH)
            SetBackdrop(row, THEME.bgDark, THEME.border)
            row:SetBackdropColor(THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85)

            row.icon = CreateIcon(row, 18)
            row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
            row.icon:SetTexture(entry.icon)

            row.name = CreateLabel(row, entry.name, 12)
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.name:SetPoint("RIGHT", row, "RIGHT", -6, 0)

            local isSelectedSpell = false
            if state.draftSpell and state.draftSpell.spellID == entry.spellID then
                isSelectedSpell = true
            elseif currentSpell and currentSpell == entry.name then
                isSelectedSpell = true
            end

            if isSelectedSpell then
                row:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.30)
            end

            row:SetScript("OnEnter", function(self)
                if not isSelectedSpell then
                    self:SetBackdropColor(THEME.bgLight[1], THEME.bgLight[2], THEME.bgLight[3], 0.35)
                end
            end)
            row:SetScript("OnLeave", function(self)
                if isSelectedSpell then
                    self:SetBackdropColor(THEME.primary[1], THEME.primary[2], THEME.primary[3], 0.30)
                else
                    self:SetBackdropColor(THEME.bgDark[1], THEME.bgDark[2], THEME.bgDark[3], 0.85)
                end
            end)

            row:SetScript("OnClick", function()
                SetSpellForSelected(entry)
            end)

            spellRows[i] = row
            y = y - rowH - 2
            totalH = totalH + rowH + 2
        end

        spChild:SetHeight(totalH + 2)

        if state.selected and state.selected.modifier and state.selected.button then
            local b = ClickCast:GetClickCastBinding(state.selected.button, state.selected.modifier)
            if b and b ~= "" then
                SetStatus("Selected bind: " .. FormatBind(state.selected.modifier, state.selected.button) .. " → " .. b:gsub("^macro:", "") )
            else
                SetStatus("Selected bind: " .. FormatBind(state.selected.modifier, state.selected.button) .. " (no spell yet)")
            end
        elseif state.draft and state.draft.modifier and state.draft.button then
            SetStatus("Pick a spell for: " .. FormatBind(state.draft.modifier, state.draft.button))
        elseif state.draftSpell and state.draftSpell.name then
            SetStatus("Spell picked: " .. state.draftSpell.name .. ". Now click 'Bind Click'.")
        else
            SetStatus("Click a binding on the left to edit it, or use '+ Add Spell Binding'.")
        end
    end

    -- Track the currently open ClickCast UI so we can refresh it on spec/spellbook updates.
    self._activeUI = {
        embed = embed,
        refresh = function()
            if embed and embed.IsShown and embed:IsShown() then
                if left and left.RefreshList then left:RefreshList() end
                if right and right.RefreshPicker then right:RefreshPicker() end
            end
        end,
    }
    embed:HookScript('OnHide', function()
        if ClickCast.HideCaptureOverlay then
            ClickCast:HideCaptureOverlay()
        end
        if ClickCast._activeUI and ClickCast._activeUI.embed == embed then
            ClickCast._activeUI = nil
        end
    end)

    -- Initial render
    left:RefreshList()
    right:RefreshPicker()
end
