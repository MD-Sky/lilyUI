local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Lightweight in-game debug window for LilyUI.
-- Toggle with: /lilydebug

local MAX_LINES = 300
local max = math.max

local Debug = {
    lines = {},
    frame = nil,
}

local function NowStamp()
    local t = date and date("%H:%M:%S") or "--:--:--"
    return t
end

local function ResizeEdit(f)
    if not f or not f.scroll or not f.edit then
        return
    end

    local scroll = f.scroll
    local edit = f.edit
    local sw = scroll:GetWidth() or 0
    local fw = f:GetWidth() or 0
    local width = sw - 24
    if width <= 0 then
        width = fw - 60
    end
    if width > 0 then
        edit:SetWidth(width)
    end

    local sh = scroll:GetHeight() or 0
    local h = (edit.GetStringHeight and edit:GetStringHeight() or 0) + 20
    edit:SetHeight(max(h, sh))
    if scroll.UpdateScrollChildRect then
        scroll:UpdateScrollChildRect()
    end
end

local function EnsureFrame()
    if Debug.frame then
        return Debug.frame
    end

    local f = CreateFrame("Frame", "LilyUIDebugFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 360)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.07, 0.08, 0.10, 0.92)
    f:SetBackdropBorderColor(0.28, 0.28, 0.32, 0.95)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    title:SetText("LilyUI Debug")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    local clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clear:SetSize(70, 20)
    clear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -38, -8)
    clear:SetText("Clear")

    local selectAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    selectAll:SetSize(90, 20)
    selectAll:SetPoint("RIGHT", clear, "LEFT", -6, 0)
    selectAll:SetText("Select All")

    local copyHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    copyHint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    copyHint:SetText("Tip: click inside, Ctrl+A then Ctrl+C")

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:EnableMouse(true)
    if edit.EnableKeyboard then
        edit:EnableKeyboard(true)
    end
    edit:SetFontObject(ChatFontNormal)
    edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    edit:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    edit:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)
    edit:SetScript("OnKeyDown", function(self, key)
        if (key == "A" or key == "a") and IsControlKeyDown and IsControlKeyDown() then
            self:HighlightText(0, -1)
            return
        end
        if key == "ESCAPE" then
            self:ClearFocus()
            return
        end
    end)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
    edit:SetScript("OnTextChanged", function()
        ResizeEdit(f)
    end)
    scroll:SetScrollChild(edit)

    clear:SetScript("OnClick", function()
        wipe(Debug.lines)
        edit:SetText("")
    end)
    selectAll:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText(0, -1)
    end)

    f.title = title
    f.scroll = scroll
    f.edit = edit

    f:SetScript("OnSizeChanged", function()
        ResizeEdit(f)
    end)

    Debug.frame = f
    ResizeEdit(f)
    return f
end

function Debug:Toggle(show)
    local f = EnsureFrame()
    if show == nil then
        show = not f:IsShown()
    end
    if show then
        f:Show()
        f.edit:SetFocus()
        f.edit:HighlightText(0, 0)
    else
        f:Hide()
    end
end

function Debug:Clear()
    wipe(self.lines)
    local f = EnsureFrame()
    if f and f.edit then
        f.edit:SetText("")
    end
end

function Debug:Append(line)
    if not line or line == "" then
        return
    end
    self.lines[#self.lines + 1] = line
    if #self.lines > MAX_LINES then
        table.remove(self.lines, 1)
    end

    local f = EnsureFrame()
    if f and f.edit then
        f.edit:SetText(table.concat(self.lines, "\n"))
        f.edit:SetCursorPosition(#f.edit:GetText())
        ResizeEdit(f)
        if f.scroll then
            f.scroll:UpdateScrollChildRect()
            f.scroll:SetVerticalScroll(f.scroll:GetVerticalScrollRange())
        end
    end
end

local function ShouldLogCategory(category)
    if category == "CombatAuras" then
        local UF = LilyUI and LilyUI.PartyFrames
        if UF and UF.devMode then
            return true
        end
        local db = UF and UF.GetDB and UF:GetDB() or nil
        return db and db.combatAuraDebugEnabled == true
    end
    if category == "SpellFinder" or category == "Lists" then
        local UF = LilyUI and LilyUI.PartyFrames
        if UF and UF.devMode then
            return true
        end
        local db = UF and UF.GetDB and UF:GetDB() or nil
        if db and db.combatAuraDebugEnabled == true then
            return true
        end
        local provider = LilyUI and LilyUI.SpellProvider
        return provider and provider.debugEnabled == true
    end
    return true
end

function LilyUI:DebugWindowLog(category, fmt, ...)
    local cat = category or "System"
    if not ShouldLogCategory(cat) then
        return
    end

    local msg = fmt
    if select("#", ...) > 0 and type(fmt) == "string" then
        local ok, out = pcall(string.format, fmt, ...)
        if ok then
            msg = out
        else
            msg = fmt
        end
    end

    local line = "[" .. NowStamp() .. "] [" .. tostring(cat) .. "] " .. tostring(msg)
    Debug:Append(line)
end

-- Backwards compatibility
function LilyUI:DebugLogCategory(category, fmt, ...)
    return self:DebugWindowLog(category, fmt, ...)
end

function LilyUI:SpellDebug(category, fmt, ...)
    self:DebugWindowLog(category, fmt, ...)
end

function LilyUI:DebugLog(msg)
    self:DebugWindowLog("System", "%s", tostring(msg))
end

-- Convenience: LilyUI:DebugPrintf("x=%s", x)
function LilyUI:DebugPrintf(fmt, ...)
    local ok, out = pcall(string.format, fmt, ...)
    if ok then
        self:DebugWindowLog("System", "%s", out)
    else
        self:DebugWindowLog("System", "DebugPrintf error: %s", tostring(out))
    end
end

-- Slash command
SLASH_LILYDEBUG1 = "/lilydebug"
SlashCmdList.LILYDEBUG = function(msg)
    msg = (msg and msg:lower()) or ""

    if msg == "" then
        local f = EnsureFrame()
        local show = not f:IsShown()
        Debug:Toggle(show)
        if show then
            LilyUI:DebugWindowLog("System", "Debug window opened OK")
        end
        return
    end

    if msg == "clear" then
        Debug:Clear()
        return
    end

    if msg == "clickcast" or msg == "click cast" then
        local UF = LilyUI and LilyUI.PartyFrames
        local hasUF = UF ~= nil
        local hasClickCastNS = hasUF and UF.ClickCast ~= nil
        local db = hasUF and UF.GetClickCastDB and UF:GetClickCastDB() or nil
        local enabled = (db and db.clickCastEnabled ~= false) and true or false
        local bindCount = 0
        if hasUF and UF.ClickCastBindings then
            for _ in pairs(UF.ClickCastBindings) do bindCount = bindCount + 1 end
        end
        LilyUI:DebugWindowLog("System", "ClickCast dump:")
        LilyUI:DebugWindowLog("System", "- UF present: %s", tostring(hasUF))
        LilyUI:DebugWindowLog("System", "- UF.ClickCast namespace: %s", tostring(hasClickCastNS))
        LilyUI:DebugWindowLog("System", "- Enabled: %s", tostring(enabled))
        LilyUI:DebugWindowLog("System", "- Runtime bindings: %s", tostring(bindCount))
        LilyUI:DebugWindowLog("System", "- InCombatLockdown: %s", tostring(InCombatLockdown and InCombatLockdown() or false))
        Debug:Toggle(true)
        return
    end

    if msg == "spell on" or msg == "spell enable" then
        if LilyUI and LilyUI.SpellProvider then
            LilyUI.SpellProvider.debugEnabled = true
        end
        LilyUI:DebugWindowLog("System", "SpellFinder debug enabled")
        Debug:Toggle(true)
        return
    end

    if msg == "spell off" or msg == "spell disable" then
        if LilyUI and LilyUI.SpellProvider then
            LilyUI.SpellProvider.debugEnabled = false
        end
        LilyUI:DebugWindowLog("System", "SpellFinder debug disabled")
        Debug:Toggle(true)
        return
    end

    if msg == "aura on" or msg == "aura enable" then
        local UF = LilyUI and LilyUI.PartyFrames
        local db = UF and UF.GetDB and UF:GetDB() or nil
        if db then
            db.combatAuraDebugEnabled = true
        end
        LilyUI:DebugWindowLog("System", "CombatAuras debug enabled")
        Debug:Toggle(true)
        return
    end

    if msg == "aura off" or msg == "aura disable" then
        local UF = LilyUI and LilyUI.PartyFrames
        local db = UF and UF.GetDB and UF:GetDB() or nil
        if db then
            db.combatAuraDebugEnabled = false
        end
        LilyUI:DebugWindowLog("System", "CombatAuras debug disabled")
        Debug:Toggle(true)
        return
    end

    LilyUI:DebugWindowLog("System", "Usage: /lilydebug (toggle) | /lilydebug clear | /lilydebug clickcast | /lilydebug spell on|off | /lilydebug aura on|off")
    Debug:Toggle(true)
end

ns.Debug = Debug
