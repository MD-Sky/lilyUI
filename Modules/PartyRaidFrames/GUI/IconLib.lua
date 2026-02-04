--[[
    LilyUI Unit Frames - Media Library
    Provides font and texture utilities via LibSharedMedia integration
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- Cache LibSharedMedia reference
local function FetchSharedMedia()
    if LibStub then
        return LibStub("LibSharedMedia-3.0", true)
    end
    return nil
end

-- ============================================================================
-- BUILT-IN FONTS
-- Fallback fonts when LibSharedMedia is not available
-- ============================================================================

UnitFrames.BuiltInFonts = {
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\SKURRI.TTF",
}

-- ============================================================================
-- BUILT-IN TEXTURES
-- Fallback textures when LibSharedMedia is not available
-- ============================================================================

UnitFrames.BuiltInTextures = {
    ["Solid"] = "Interface\\Buttons\\WHITE8x8",
    ["Blizzard"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Blizzard Raid"] = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}

-- ============================================================================
-- FONT UTILITIES
-- ============================================================================

--[[
    Returns a table of available fonts for dropdown menus
    @return table - Font name to display name mapping
]]
function UnitFrames:GetFontList()
    local fontTable = {}
    local media = FetchSharedMedia()
    
    if media then
        local availableFonts = media:List("font")
        for _, fontName in ipairs(availableFonts) do
            fontTable[fontName] = fontName
        end
    else
        for displayName, _ in pairs(self.BuiltInFonts) do
            fontTable[displayName] = displayName
        end
    end
    
    return fontTable
end

--[[
    Resolves a font name to its file path
    @param fontIdentifier string - Font name or path
    @return string - Resolved font file path
]]
function UnitFrames:GetFontPath(fontIdentifier)
    if not fontIdentifier then
        return "Fonts\\FRIZQT__.TTF"
    end
    
    -- Check if it's already a path
    if fontIdentifier:find("\\") or fontIdentifier:find("/") then
        return fontIdentifier
    end
    
    -- Try LibSharedMedia first
    local media = FetchSharedMedia()
    if media then
        local resolved = media:Fetch("font", fontIdentifier)
        if resolved then
            return resolved
        end
    end
    
    -- Check built-in fonts
    if self.BuiltInFonts[fontIdentifier] then
        return self.BuiltInFonts[fontIdentifier]
    end
    
    -- Default fallback
    return "Fonts\\FRIZQT__.TTF"
end

--[[
    Gets the display name for a font path
    @param fontPath string - Font file path
    @return string - Display name for the font
]]
function UnitFrames:GetFontDisplayName(fontPath)
    if not fontPath then
        return "Friz Quadrata TT"
    end
    
    -- Check built-in fonts
    for displayName, path in pairs(self.BuiltInFonts) do
        if path == fontPath then
            return displayName
        end
    end
    
    -- Try LibSharedMedia
    local media = FetchSharedMedia()
    if media then
        local availableFonts = media:List("font")
        for _, fontName in ipairs(availableFonts) do
            if media:Fetch("font", fontName) == fontPath then
                return fontName
            end
        end
    end
    
    -- Return path as-is if no match found
    return fontPath
end

-- ============================================================================
-- TEXTURE UTILITIES
-- ============================================================================

--[[
    Returns a table of available textures for dropdown menus
    @param includeSolid boolean - Whether to include the solid color option
    @return table - Texture name to display name mapping
]]
function UnitFrames:GetTextureList(includeSolid)
    local textureTable = {}
    local media = FetchSharedMedia()
    
    if media then
        local availableTextures = media:List("statusbar")
        for _, textureName in ipairs(availableTextures) do
            textureTable[textureName] = textureName
        end
    else
        for displayName, _ in pairs(self.BuiltInTextures) do
            textureTable[displayName] = displayName
        end
    end
    
    -- Always include Solid option
    if includeSolid ~= false then
        textureTable["Solid"] = "Solid"
    end
    
    return textureTable
end

--[[
    Resolves a texture name to its file path
    @param textureIdentifier string - Texture name or path
    @return string - Resolved texture file path
]]
function UnitFrames:GetTexturePath(textureIdentifier)
    if not textureIdentifier then
        return "Interface\\Buttons\\WHITE8x8"
    end
    
    -- Handle special "Solid" case
    if textureIdentifier == "Solid" or textureIdentifier == "" then
        return "Interface\\Buttons\\WHITE8x8"
    end
    
    -- Check if it's already a path
    if textureIdentifier:find("\\") or textureIdentifier:find("/") then
        return textureIdentifier
    end
    
    -- Try LibSharedMedia first
    local media = FetchSharedMedia()
    if media then
        local resolved = media:Fetch("statusbar", textureIdentifier)
        if resolved then
            return resolved
        end
    end
    
    -- Check built-in textures
    if self.BuiltInTextures[textureIdentifier] then
        return self.BuiltInTextures[textureIdentifier]
    end
    
    -- Default fallback
    return "Interface\\Buttons\\WHITE8x8"
end

--[[
    Gets the display name for a texture path
    @param texturePath string - Texture file path
    @return string - Display name for the texture
]]
function UnitFrames:GetTextureDisplayName(texturePath)
    if not texturePath then
        return "Solid"
    end
    
    -- Check for solid texture
    if texturePath == "Interface\\Buttons\\WHITE8x8" then
        return "Solid"
    end
    
    -- Check built-in textures
    for displayName, path in pairs(self.BuiltInTextures) do
        if path == texturePath then
            return displayName
        end
    end
    
    -- Try LibSharedMedia
    local media = FetchSharedMedia()
    if media then
        local availableTextures = media:List("statusbar")
        for _, textureName in ipairs(availableTextures) do
            if media:Fetch("statusbar", textureName) == texturePath then
                return textureName
            end
        end
    end
    
    -- Return path as-is if no match found
    return texturePath
end

-- ============================================================================
-- BORDER TEXTURE UTILITIES
-- ============================================================================

UnitFrames.BuiltInBorders = {
    ["Solid"] = "Interface\\Buttons\\WHITE8x8",
    ["Tooltip"] = "Interface\\Tooltips\\UI-Tooltip-Border",
    ["Dialog"] = "Interface\\DialogFrame\\UI-DialogBox-Border",
}

--[[
    Returns a table of available border textures
    @return table - Border name to display name mapping
]]
function UnitFrames:GetBorderList()
    local borderTable = {}
    local media = FetchSharedMedia()
    
    if media then
        local availableBorders = media:List("border")
        for _, borderName in ipairs(availableBorders) do
            borderTable[borderName] = borderName
        end
    end
    
    -- Always include built-in options
    for displayName, _ in pairs(self.BuiltInBorders) do
        borderTable[displayName] = displayName
    end
    
    return borderTable
end

--[[
    Resolves a border name to its file path
    @param borderIdentifier string - Border name or path
    @return string - Resolved border file path
]]
function UnitFrames:GetBorderPath(borderIdentifier)
    if not borderIdentifier or borderIdentifier == "Solid" then
        return "Interface\\Buttons\\WHITE8x8"
    end
    
    -- Check if it's already a path
    if borderIdentifier:find("\\") or borderIdentifier:find("/") then
        return borderIdentifier
    end
    
    -- Try LibSharedMedia first
    local media = FetchSharedMedia()
    if media then
        local resolved = media:Fetch("border", borderIdentifier)
        if resolved then
            return resolved
        end
    end
    
    -- Check built-in borders
    if self.BuiltInBorders[borderIdentifier] then
        return self.BuiltInBorders[borderIdentifier]
    end
    
    -- Default fallback
    return "Interface\\Buttons\\WHITE8x8"
end

-- ============================================================================
-- SOUND UTILITIES
-- ============================================================================

--[[
    Returns a table of available sounds
    @return table - Sound name to display name mapping
]]
function UnitFrames:GetSoundList()
    local soundTable = {}
    local media = FetchSharedMedia()
    
    if media then
        local availableSounds = media:List("sound")
        for _, soundName in ipairs(availableSounds) do
            soundTable[soundName] = soundName
        end
    end
    
    return soundTable
end

--[[
    Resolves a sound name to its file path
    @param soundIdentifier string - Sound name or path
    @return string|nil - Resolved sound file path or nil
]]
function UnitFrames:GetSoundPath(soundIdentifier)
    if not soundIdentifier then
        return nil
    end
    
    -- Check if it's already a path
    if soundIdentifier:find("\\") or soundIdentifier:find("/") then
        return soundIdentifier
    end
    
    -- Try LibSharedMedia
    local media = FetchSharedMedia()
    if media then
        local resolved = media:Fetch("sound", soundIdentifier)
        if resolved then
            return resolved
        end
    end
    
    return nil
end
