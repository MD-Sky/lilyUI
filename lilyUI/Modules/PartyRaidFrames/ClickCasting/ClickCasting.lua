--[[
    LilyUI Unit Frames - Click Casting System
    Provides built-in click casting functionality
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Click casting storage
UnitFrames.ClickCastBindings = UnitFrames.ClickCastBindings or {}
UnitFrames.ClickCastFrames = UnitFrames.ClickCastFrames or {}

-- ============================================================================
-- CLICK CAST DATABASE HELPERS
-- ============================================================================

-- Ensure click casting settings exist in the party frames DB and return it
function UnitFrames:GetClickCastDB()
    local db = self.GetDB and self:GetDB() or {}
    -- Defaults: enabled unless explicitly disabled
    if db.clickCastEnabled == nil then db.clickCastEnabled = true end
    if db.useClique == nil then db.useClique = false end
    db.clickCastBindings = db.clickCastBindings or {}
    return db
end

-- Load bindings from DB into runtime table
function UnitFrames:LoadClickCastBindings()
    local db = self:GetClickCastDB()
    wipe(self.ClickCastBindings)
    for key, binding in pairs(db.clickCastBindings) do
        -- Shallow copy is enough (flat table)
        self.ClickCastBindings[key] = {
            button = binding.button,
            modifier = binding.modifier,
            spell = binding.spell,
            isMacro = binding.isMacro,
        }
    end
end

-- Persist current runtime bindings back into DB
function UnitFrames:SaveClickCastBindings()
    local db = self:GetClickCastDB()
    db.clickCastBindings = db.clickCastBindings or {}
    wipe(db.clickCastBindings)
    for key, binding in pairs(self.ClickCastBindings) do
        db.clickCastBindings[key] = {
            button = binding.button,
            modifier = binding.modifier,
            spell = binding.spell,
            isMacro = binding.isMacro,
        }
    end
end


-- ============================================================================
-- CLICK CAST BINDING MANAGEMENT
-- ============================================================================

--[[
    Set a click cast binding
    @param button string - Mouse button (e.g., "LeftButton", "MiddleButton")
    @param modifier string - Modifier key ("shift", "ctrl", "alt", or combinations)
    @param spellOrMacro string - Spell name or macro text
    @param isMacro boolean - Whether this is a macro
]]
function UnitFrames:SetClickCastBinding(button, modifier, spellOrMacro, isMacro)
    local key = self:BuildBindingKey(button, modifier)

    self.ClickCastBindings[key] = {
        button = button,
        modifier = modifier,
        spell = spellOrMacro,
        isMacro = isMacro,
    }

    -- Persist
    self:SaveClickCastBindings()

    -- Update all registered frames
    self:UpdateAllClickCastFrames()
end

--[[
    Remove a click cast binding
    @param button string - Mouse button
    @param modifier string - Modifier key
]]
function UnitFrames:RemoveClickCastBinding(button, modifier)
    local key = self:BuildBindingKey(button, modifier)
    self.ClickCastBindings[key] = nil
    self:SaveClickCastBindings()
    self:UpdateAllClickCastFrames()
end

--[[
    Clear all click cast bindings
]]
function UnitFrames:ClearAllClickCastBindings()
    wipe(self.ClickCastBindings)
    self:SaveClickCastBindings()
    self:UpdateAllClickCastFrames()
end

--[[
    Build a binding key from button and modifier
    @param button string - Mouse button
    @param modifier string - Modifier key
    @return string - Combined key
]]
function UnitFrames:BuildBindingKey(button, modifier)
    if modifier and modifier ~= "" then
        return modifier:lower() .. "-" .. button
    end
    return button
end

-- ============================================================================
-- FRAME REGISTRATION
-- ============================================================================

--[[
    Register a frame for click casting
    @param frame Frame - The unit frame to register
]]
function UnitFrames:RegisterClickCast(frame)
    if not frame or self.ClickCastFrames[frame] then return end
    
    self.ClickCastFrames[frame] = true
    
    -- Apply current bindings to frame
    self:ApplyClickCastToFrame(frame)
end

--[[
    Unregister a frame from click casting
    @param frame Frame - The unit frame to unregister
]]
function UnitFrames:UnregisterClickCast(frame)
    if not frame then return end
    
    self.ClickCastFrames[frame] = nil
    
    -- Remove click cast attributes
    self:ClearClickCastFromFrame(frame)
end

-- ============================================================================
-- FRAME CLICK CAST APPLICATION
-- ============================================================================

--[[
    Apply click cast bindings to a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:ApplyClickCastToFrame(frame)
    if not frame or InCombatLockdown() then return end
    
    -- Clear existing bindings first
    self:ClearClickCastFromFrame(frame)
    
    -- Apply each binding
    for key, binding in pairs(self.ClickCastBindings) do
        self:ApplySingleBinding(frame, binding)
    end
end

--[[
    Apply a single binding to a frame
    @param frame Frame - The unit frame
    @param binding table - Binding data
]]
function UnitFrames:ApplySingleBinding(frame, binding)
    if not frame or not binding then return end
    
    local button = binding.button
    local modifier = binding.modifier or ""
    
    -- Build attribute names based on modifier
    local typeAttr = "type"
    local spellAttr = "spell"
    local macrotextAttr = "macrotext"
    
    if modifier ~= "" then
        -- Convert modifier to attribute prefix
        local modPrefix = self:GetModifierPrefix(modifier)
        typeAttr = modPrefix .. "type"
        spellAttr = modPrefix .. "spell"
        macrotextAttr = modPrefix .. "macrotext"
    end
    
    -- Set button number
    local buttonNum = self:GetButtonNumber(button)
    if buttonNum then
        typeAttr = typeAttr .. buttonNum
        spellAttr = spellAttr .. buttonNum
        macrotextAttr = macrotextAttr .. buttonNum
    end
    
    -- Apply binding
    if binding.isMacro then
        frame:SetAttribute(typeAttr, "macro")
        frame:SetAttribute(macrotextAttr, binding.spell)
    else
        frame:SetAttribute(typeAttr, "spell")
        frame:SetAttribute(spellAttr, binding.spell)
    end
end

--[[
    Clear click cast bindings from a frame
    @param frame Frame - The unit frame
]]
function UnitFrames:ClearClickCastFromFrame(frame)
    if not frame or InCombatLockdown() then return end
    
    -- Reset to default targeting behavior
    frame:SetAttribute("type1", "target")
    frame:SetAttribute("type2", "togglemenu")
    
    -- Clear modifier-based attributes
    local modifiers = {"shift-", "ctrl-", "alt-", "shift-ctrl-", "shift-alt-", "ctrl-alt-", "shift-ctrl-alt-"}
    local buttons = {"1", "2", "3", "4", "5"}
    
    for _, mod in ipairs(modifiers) do
        for _, btn in ipairs(buttons) do
            frame:SetAttribute(mod .. "type" .. btn, nil)
            frame:SetAttribute(mod .. "spell" .. btn, nil)
            frame:SetAttribute(mod .. "macrotext" .. btn, nil)
        end
    end
end

--[[
    Get modifier prefix for attributes
    @param modifier string - Modifier string (e.g., "shift", "ctrl-alt")
    @return string - Attribute prefix
]]
function UnitFrames:GetModifierPrefix(modifier)
    if not modifier or modifier == "" then
        return ""
    end
    
    -- Normalize modifier string
    modifier = modifier:lower()
    
    -- Build prefix
    local parts = {}
    if modifier:find("shift") then table.insert(parts, "shift") end
    if modifier:find("ctrl") or modifier:find("control") then table.insert(parts, "ctrl") end
    if modifier:find("alt") then table.insert(parts, "alt") end
    
    if #parts == 0 then
        return ""
    end
    
    return table.concat(parts, "-") .. "-"
end

--[[
    Get button number from button name
    @param button string - Button name (e.g., "LeftButton", "Button4")
    @return string - Button number
]]
function UnitFrames:GetButtonNumber(button)
    local buttonMap = {
        ["LeftButton"] = "1",
        ["RightButton"] = "2",
        ["MiddleButton"] = "3",
        ["Button4"] = "4",
        ["Button5"] = "5",
    }
    return buttonMap[button]
end

-- ============================================================================
-- BATCH OPERATIONS
-- ============================================================================

--[[
    Update click cast bindings on all registered frames
]]
function UnitFrames:UpdateAllClickCastFrames()
    if InCombatLockdown() then
        -- Queue for after combat
        self.pendingClickCastUpdate = true
        return
    end
    
    for frame in pairs(self.ClickCastFrames) do
        self:ApplyClickCastToFrame(frame)
    end
end

-- ============================================================================
-- DEFAULT BINDINGS
-- ============================================================================

--[[
    Setup default click cast bindings for a healer
]]
function UnitFrames:SetupHealerDefaults()
    local _, class = UnitClass("player")
    
    local defaults = {}
    
    if class == "PRIEST" then
        defaults = {
            {button = "LeftButton", modifier = "", spell = "Flash Heal"},
            {button = "LeftButton", modifier = "shift", spell = "Power Word: Shield"},
            {button = "LeftButton", modifier = "ctrl", spell = "Renew"},
            {button = "MiddleButton", modifier = "", spell = "Holy Word: Serenity"},
            {button = "MiddleButton", modifier = "shift", spell = "Purify"},
        }
    elseif class == "PALADIN" then
        defaults = {
            {button = "LeftButton", modifier = "", spell = "Flash of Light"},
            {button = "LeftButton", modifier = "shift", spell = "Holy Shock"},
            {button = "LeftButton", modifier = "ctrl", spell = "Word of Glory"},
            {button = "MiddleButton", modifier = "", spell = "Cleanse"},
            {button = "MiddleButton", modifier = "shift", spell = "Blessing of Protection"},
        }
    elseif class == "DRUID" then
        defaults = {
            {button = "LeftButton", modifier = "", spell = "Regrowth"},
            {button = "LeftButton", modifier = "shift", spell = "Rejuvenation"},
            {button = "LeftButton", modifier = "ctrl", spell = "Lifebloom"},
            {button = "MiddleButton", modifier = "", spell = "Swiftmend"},
            {button = "MiddleButton", modifier = "shift", spell = "Nature's Cure"},
        }
    elseif class == "SHAMAN" then
        defaults = {
            {button = "LeftButton", modifier = "", spell = "Healing Surge"},
            {button = "LeftButton", modifier = "shift", spell = "Riptide"},
            {button = "LeftButton", modifier = "ctrl", spell = "Healing Wave"},
            {button = "MiddleButton", modifier = "", spell = "Chain Heal"},
            {button = "MiddleButton", modifier = "shift", spell = "Purify Spirit"},
        }
    elseif class == "MONK" then
        defaults = {
            {button = "LeftButton", modifier = "", spell = "Vivify"},
            {button = "LeftButton", modifier = "shift", spell = "Enveloping Mist"},
            {button = "LeftButton", modifier = "ctrl", spell = "Renewing Mist"},
            {button = "MiddleButton", modifier = "", spell = "Detox"},
            {button = "MiddleButton", modifier = "shift", spell = "Life Cocoon"},
        }
    elseif class == "EVOKER" then
        defaults = {
            {button = "LeftButton", modifier = "", spell = "Living Flame"},
            {button = "LeftButton", modifier = "shift", spell = "Reversion"},
            {button = "LeftButton", modifier = "ctrl", spell = "Echo"},
            {button = "MiddleButton", modifier = "", spell = "Naturalize"},
            {button = "MiddleButton", modifier = "shift", spell = "Verdant Embrace"},
        }
    end
    
    -- Apply defaults
    for _, binding in ipairs(defaults) do
        self:SetClickCastBinding(binding.button, binding.modifier, binding.spell, false)
    end
end

-- ============================================================================
-- CLIQUE INTEGRATION
-- ============================================================================

--[[
    Register frames with Clique addon if present
]]
function UnitFrames:RegisterWithClique()
    if not ClickCastFrames then return end
    
    -- Register player frame
    if self.playerFrame then
        ClickCastFrames[self.playerFrame] = true
    end
    
    -- Register party frames
    for _, frame in pairs(self.partyFrames) do
        ClickCastFrames[frame] = true
    end
    
    -- Register raid frames
    for _, frame in pairs(self.raidFrames) do
        ClickCastFrames[frame] = true
    end
end

-- ============================================================================
-- COMBAT LOCKDOWN HANDLING
-- ============================================================================

-- Register for combat end to process pending updates
local clickCastEventFrame = CreateFrame("Frame")
clickCastEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
clickCastEventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if UnitFrames.pendingClickCastUpdate then
            UnitFrames.pendingClickCastUpdate = nil
            UnitFrames:UpdateAllClickCastFrames()
        end
    end
end)
