local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

if not LilyUI then
    return
end

local SpellProvider = ns.SpellProvider or {}
ns.SpellProvider = SpellProvider
LilyUI.SpellProvider = SpellProvider

local _G = _G
local C_Spell = C_Spell
local C_SpellBook = C_SpellBook
local CreateFrame = CreateFrame
local Enum = Enum
local GetSpellInfo = GetSpellInfo
local GetSpellTexture = GetSpellTexture
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local ipairs, pairs, type, tostring, tonumber = ipairs, pairs, type, tostring, tonumber
local strlower = string.lower
local tinsert, sort = table.insert, table.sort
local wipe = wipe

function SpellProvider:ToggleDebugWindow(show)
    if ns and ns.Debug and ns.Debug.Toggle then
        ns.Debug:Toggle(show)
    end
end

function SpellProvider:ClearLog()
    if ns and ns.Debug and ns.Debug.Clear then
        ns.Debug:Clear()
    end
end

function SpellProvider:Log(msg)
    if not msg or msg == "" then
        return
    end
    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("SpellFinder", "%s", tostring(msg))
        return
    end
end

local function DebugLog(msg)
    if not msg then return end
    local text = "[SpellProvider] " .. tostring(msg)
    SpellProvider:Log(text)
    local UF = LilyUI and LilyUI.PartyFrames
    if UF and UF.devMode and UF.DebugPrint then
        UF:DebugPrint(text)
    end
end

SLASH_LILYSPELLDEBUG1 = "/lilyspelldebug"
SlashCmdList.LILYSPELLDEBUG = function(msg)
    msg = (msg and msg:lower()) or ""
    if msg == "on" or msg == "enable" then
        SpellProvider.debugEnabled = true
        SpellProvider:ToggleDebugWindow(true)
        if LilyUI and LilyUI.DebugWindowLog then
            LilyUI:DebugWindowLog("System", "SpellFinder debug enabled")
        end
        return
    end
    if msg == "off" or msg == "disable" then
        SpellProvider.debugEnabled = false
        SpellProvider:ToggleDebugWindow(true)
        if LilyUI and LilyUI.DebugWindowLog then
            LilyUI:DebugWindowLog("System", "SpellFinder debug disabled")
        end
        return
    end
    if msg == "clear" then
        SpellProvider:ClearLog()
        return
    end
    SpellProvider.debugEnabled = true
    SpellProvider:ToggleDebugWindow()
    if LilyUI and LilyUI.DebugWindowLog then
        LilyUI:DebugWindowLog("System", "SpellFinder debug enabled")
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

local function SafeLower(value)
    if type(value) == "string" then
        return value:lower()
    end
    if value == nil then return nil end
    local ok, str = pcall(tostring, value)
    if ok and type(str) == "string" then
        return str:lower()
    end
    return nil
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
    return nil
end

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

local function EnsureCacheTables(self)
    self._cache = self._cache or {}
    self._cache.all = self._cache.all or {}
    self._cache.general = self._cache.general or {}
    self._cache.class = self._cache.class or {}
    self._cache.spec = self._cache.spec or {}
    wipe(self._cache.all)
    wipe(self._cache.general)
    wipe(self._cache.class)
    wipe(self._cache.spec)
end

local function SortByName(a, b)
    local an = a and a.name or ""
    local bn = b and b.name or ""
    return tostring(an) < tostring(bn)
end

function SpellProvider:IsBuilt()
    return self._cacheBuilt == true
end

function SpellProvider:EnsureBuilt(force)
    if force then
        self._cacheBuilt = false
    end
    if self._cacheBuilt and self._cache and self._cache.all then
        return
    end
    self:BuildCache()
end

function SpellProvider:BuildCache()
    if GetTime then
        local now = GetTime()
        if self._lastBuildTime and (now - self._lastBuildTime) < 1.0 then
            if self.debugEnabled and LilyUI and LilyUI.DebugWindowLog then
                LilyUI:DebugWindowLog("SpellFinder", "[SpellProvider] throttled rebuild")
            end
            return
        end
        self._lastBuildTime = now
    end
    DebugLog("build start")
    EnsureCacheTables(self)

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
        local spellName = nil
        local icon = nil
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and info then
                spellName = info.name
                icon = info.iconID or info.icon
            end
        end
        if not spellName or spellName == "" then
            spellName = select(1, CompatGetSpellInfo(spellID))
        end
        if not spellName or spellName == "" then
            spellName = CompatGetSpellName(spellID)
        end
        if not spellName or spellName == "" then
            return
        end

        if not icon then
            local _, _, tex = CompatGetSpellInfo(spellID)
            icon = tex
        end
        if (not icon) and C_Spell and C_Spell.GetSpellTexture then
            local ok, t = pcall(C_Spell.GetSpellTexture, spellID)
            if ok then icon = t end
        end

        seen[spellID] = true
        local nameLower = SafeLower(spellName) or SafeLower(tostring(spellName))
        local entry = {
            spellID = spellID,
            name = spellName,
            nameLower = nameLower,
            icon = icon,
            lineName = skillLineName,
            lineIndex = skillLineIndex,
        }
        tinsert(self._cache.all, entry)

        local lineLower = skillLineName and strlower(skillLineName)
        local isGeneral = (skillLineIndex == 1) or (lineLower == "general")
        local isSpec = false
        if specName and skillLineName and strlower(specName) == strlower(skillLineName) then
            isSpec = true
        end

        if isGeneral then
            tinsert(self._cache.general, entry)
        elseif isSpec then
            tinsert(self._cache.spec, entry)
        else
            tinsert(self._cache.class, entry)
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
                    local id = itemInfo.actionID or itemInfo.spellID
                    if (typeSpell and itemType == typeSpell) or (typeFuture and itemType == typeFuture) or (not typeSpell and id) then
                        AddSpell(id, lineName, i)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
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

    sort(self._cache.all, SortByName)
    sort(self._cache.general, SortByName)
    sort(self._cache.class, SortByName)
    sort(self._cache.spec, SortByName)

    self._cacheBuilt = true
    DebugLog("built count=" .. tostring(#self._cache.all))
    if #self._cache.all == 0 then
        DebugLog("build produced 0 spells")
    end
    SpellProvider:Log("[SF] Provider built. totalSpells=" .. tostring(#self._cache.all))
end

function SpellProvider:GetCache()
    self:EnsureBuilt()
    return self._cache or { all = {} }
end

function SpellProvider:GetCategory(filter)
    local cache = self:GetCache()
    if type(filter) == "string" and cache[filter] then
        return cache[filter]
    end
    return cache.all or {}
end

function SpellProvider:GetAllSpells()
    local cache = self:GetCache()
    return cache.all or {}
end

function SpellProvider:Filter(spells, query)
    local list = type(spells) == "table" and spells or {}
    local q = SafeTrim(query or "")
    if q == "" then
        return list
    end

    local filtered = {}

    if q:match("^%d+$") or q:match("Hspell:%d+") or q:match("spell:%d+") then
        local spellId = ParseSpellId(q)
        if spellId and spellId > 0 then
            local found = nil
            for _, entry in ipairs(list) do
                if entry and entry.spellID == spellId then
                    found = entry
                    break
                end
            end
            if found then
                filtered[1] = found
            else
                local info = nil
                if C_Spell and C_Spell.GetSpellInfo then
                    local ok, t = pcall(C_Spell.GetSpellInfo, spellId)
                    if ok then info = t end
                end
                local name = (info and info.name) or (GetSpellInfo and GetSpellInfo(spellId)) or nil
                if name and name ~= "" then
                    local icon = (info and (info.iconID or info.icon)) or (GetSpellTexture and GetSpellTexture(spellId)) or nil
                    if not icon and C_Spell and C_Spell.GetSpellTexture then
                        local ok, t = pcall(C_Spell.GetSpellTexture, spellId)
                        if ok then icon = t end
                    end
                    filtered[1] = {
                        spellID = spellId,
                        name = tostring(name),
                        nameLower = SafeLower(name) or SafeLower(tostring(name)),
                        icon = icon,
                        isExternal = true,
                    }
                end
            end
        end
        return filtered
    end

    local qLower = SafeLower(q) or ""
    for _, entry in ipairs(list) do
        local nameLower = entry and (entry.nameLower or SafeLower(entry.name) or "") or ""
        if nameLower ~= "" and nameLower:find(qLower, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end

local function FireRefreshCallbacks(self)
    if not self._refreshCallbacks then return end
    local callbacks = self._refreshCallbacks
    self._refreshCallbacks = nil
    for i = 1, #callbacks do
        local cb = callbacks[i]
        if type(cb) == "function" then
            local ok, err = pcall(cb)
            if not ok then
                DebugLog("refresh callback error: " .. tostring(err))
            end
        end
    end
end

function SpellProvider:RefreshSoon(callback)
    local cache = self._cache
    local count = cache and cache.all and #cache.all or 0
    if type(callback) == "function" then
        self._refreshCallbacks = self._refreshCallbacks or {}
        tinsert(self._refreshCallbacks, callback)
    end

    if count > 0 then
        FireRefreshCallbacks(self)
        return
    end

    if not self._refreshEventFrame then
        local provider = self
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("SPELLS_CHANGED")
        ef:SetScript("OnEvent", function()
            ef:UnregisterEvent("SPELLS_CHANGED")
            provider._refreshEventFrame = nil
            provider._cacheBuilt = false
            provider:EnsureBuilt(true)
            DebugLog("SPELLS_CHANGED -> rebuilt")
            FireRefreshCallbacks(provider)
        end)
        self._refreshEventFrame = ef
    end

    if C_Timer and C_Timer.After and not self._refreshQueued then
        self._refreshQueued = true
        C_Timer.After(0.2, function()
            self._refreshQueued = nil
            self._cacheBuilt = false
            self:EnsureBuilt(true)
            DebugLog("timer refresh -> rebuilt")
            FireRefreshCallbacks(self)
        end)
    end
end
