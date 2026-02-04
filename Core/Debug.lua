local ADDON_NAME, ns = ...
local NephUI = ns.Addon

-- Lightweight in-game debug window for LilyUI.
-- Toggle with: /lilydebug

local MAX_LINES = 500

local Debug = {
    lines = {},
    frame = nil,
}

local function NowStamp()
    local t = date and date("%H:%M:%S") or "--:--:--"
    return t
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
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(1)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
    edit:SetScript("OnTextChanged", function(self)
        scroll:UpdateScrollChildRect()
    end)
    scroll:SetScrollChild(edit)

    clear:SetScript("OnClick", function()
        wipe(Debug.lines)
        edit:SetText("")
    end)

    f.title = title
    f.scroll = scroll
    f.edit = edit

    Debug.frame = f
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
    end
end

function NephUI:DebugLog(msg)
    local line = "[" .. NowStamp() .. "] " .. tostring(msg)
    Debug:Append(line)
end

-- Convenience: NephUI:DebugPrintf("x=%s", x)
function NephUI:DebugPrintf(fmt, ...)
    local ok, out = pcall(string.format, fmt, ...)
    if ok then
        self:DebugLog(out)
    else
        self:DebugLog("DebugPrintf error: " .. tostring(out))
    end
end

-- Slash command
SLASH_LILYDEBUG1 = "/lilydebug"
SlashCmdList.LILYDEBUG = function(msg)
    msg = (msg and msg:lower()) or ""

    if msg == "" then
        Debug:Toggle()
        return
    end

    if msg == "clear" then
        local f = EnsureFrame()
        wipe(Debug.lines)
        if f and f.edit then
            f.edit:SetText("")
        end
        return
    end

    if msg == "clickcast" or msg == "click cast" then
        local UF = NephUI and NephUI.PartyFrames
        local hasUF = UF ~= nil
        local hasClickCastNS = hasUF and UF.ClickCast ~= nil
        local db = hasUF and UF.GetClickCastDB and UF:GetClickCastDB() or nil
        local enabled = (db and db.clickCastEnabled ~= false) and true or false
        local bindCount = 0
        if hasUF and UF.ClickCastBindings then
            for _ in pairs(UF.ClickCastBindings) do bindCount = bindCount + 1 end
        end
        NephUI:DebugLog("ClickCast dump:")
        NephUI:DebugLog("- UF present: " .. tostring(hasUF))
        NephUI:DebugLog("- UF.ClickCast namespace: " .. tostring(hasClickCastNS))
        NephUI:DebugLog("- Enabled: " .. tostring(enabled))
        NephUI:DebugLog("- Runtime bindings: " .. tostring(bindCount))
        NephUI:DebugLog("- InCombatLockdown: " .. tostring(InCombatLockdown and InCombatLockdown() or false))
        Debug:Toggle(true)
        return
    end

    NephUI:DebugLog("Usage: /lilydebug (toggle) | /lilydebug clear | /lilydebug clickcast")
    Debug:Toggle(true)
end

ns.Debug = Debug
