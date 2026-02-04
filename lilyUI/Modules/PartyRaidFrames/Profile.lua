--[[
    LilyUI Unit Frames - Profile Management
    Handles profile operations including save, load, import, and export
]]

local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Ensure PartyFrames module exists
LilyUI.PartyFrames = LilyUI.PartyFrames or {}
local UnitFrames = LilyUI.PartyFrames

-- ============================================================================
-- BASE64 ENCODING/DECODING
-- Used for profile import/export string encoding
-- ============================================================================

local Base64Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function EncodeBase64(inputData)
    local result = {}
    local padding = 0
    
    while (#inputData % 3) ~= 0 do
        inputData = inputData .. "\0"
        padding = padding + 1
    end
    
    for i = 1, #inputData, 3 do
        local byte1 = inputData:byte(i)
        local byte2 = inputData:byte(i + 1)
        local byte3 = inputData:byte(i + 2)
        
        local combined = (byte1 * 65536) + (byte2 * 256) + byte3
        
        local idx1 = math.floor(combined / 262144) + 1
        local idx2 = math.floor((combined % 262144) / 4096) + 1
        local idx3 = math.floor((combined % 4096) / 64) + 1
        local idx4 = (combined % 64) + 1
        
        result[#result + 1] = Base64Chars:sub(idx1, idx1)
        result[#result + 1] = Base64Chars:sub(idx2, idx2)
        result[#result + 1] = Base64Chars:sub(idx3, idx3)
        result[#result + 1] = Base64Chars:sub(idx4, idx4)
    end
    
    local encoded = table.concat(result)
    
    if padding > 0 then
        encoded = encoded:sub(1, -padding - 1) .. string.rep("=", padding)
    end
    
    return encoded
end

local function DecodeBase64(encodedData)
    local result = {}
    encodedData = encodedData:gsub("=", "")
    
    local charLookup = {}
    for i = 1, #Base64Chars do
        charLookup[Base64Chars:sub(i, i)] = i - 1
    end
    
    for i = 1, #encodedData, 4 do
        local chunk = encodedData:sub(i, i + 3)
        if #chunk < 2 then break end
        
        local val1 = charLookup[chunk:sub(1, 1)] or 0
        local val2 = charLookup[chunk:sub(2, 2)] or 0
        local val3 = charLookup[chunk:sub(3, 3)] or 0
        local val4 = charLookup[chunk:sub(4, 4)] or 0
        
        local combined = (val1 * 262144) + (val2 * 4096) + (val3 * 64) + val4
        
        result[#result + 1] = string.char(math.floor(combined / 65536) % 256)
        if #chunk >= 3 then
            result[#result + 1] = string.char(math.floor(combined / 256) % 256)
        end
        if #chunk >= 4 then
            result[#result + 1] = string.char(combined % 256)
        end
    end
    
    return table.concat(result)
end

-- ============================================================================
-- PROFILE OPERATIONS
-- ============================================================================

--[[
    Resets a profile to default values
    @param frameType string - "party" or "raid"
]]
function UnitFrames:ResetProfile(frameType)
    if not self.db then return end
    
    local defaults = frameType == "raid" and self.RaidDefaults or self.PartyDefaults
    local target = frameType == "raid" and self.db.raid or self.db.party
    
    if not defaults or not target then return end
    
    -- Clear existing values
    for key in pairs(target) do
        target[key] = nil
    end
    
    -- Copy defaults
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = self:DeepCopy(value)
        else
            target[key] = value
        end
    end
    
    -- Refresh display
    if self.UpdateAllFrames then
        self:UpdateAllFrames()
    end
    
    print("|cff00ff00LilyUI:|r " .. (frameType == "raid" and "Raid" or "Party") .. " frame settings reset to defaults.")
end

--[[
    Copies settings between party and raid profiles
    @param sourceType string - Source profile type ("party" or "raid")
    @param targetType string - Target profile type ("party" or "raid")
]]
function UnitFrames:CopyProfile(sourceType, targetType)
    if not self.db then return end
    
    local source = sourceType == "raid" and self.db.raid or self.db.party
    local target = targetType == "raid" and self.db.raid or self.db.party
    
    if not source or not target then return end
    if source == target then return end
    
    -- Copy all transferable settings
    local skipKeys = {
        -- Position keys are frame-type specific
        anchorX = true, anchorY = true,
        raidAnchorX = true, raidAnchorY = true,
        -- Lock states
        locked = true, raidLocked = true,
        -- Raid-specific layout
        raidUseGroups = true, raidGroupSpacing = true,
        raidRowColSpacing = true, raidGroupsPerRow = true,
    }
    
    for key, value in pairs(source) do
        if not skipKeys[key] then
            if type(value) == "table" then
                target[key] = self:DeepCopy(value)
            else
                target[key] = value
            end
        end
    end
    
    -- Refresh display
    if self.UpdateAllFrames then
        self:UpdateAllFrames()
    end
    
    print("|cff00ff00LilyUI:|r Settings copied from " .. sourceType .. " to " .. targetType .. " frames.")
end

-- ============================================================================
-- PROFILE LIST MANAGEMENT
-- ============================================================================

--[[
    Gets list of saved profiles
    @return table - List of profile names
]]
function UnitFrames:GetProfiles()
    if not self.db or not self.db.profiles then
        return {}
    end
    
    local profileList = {}
    for name in pairs(self.db.profiles) do
        table.insert(profileList, name)
    end
    
    table.sort(profileList)
    return profileList
end

--[[
    Saves current settings as a named profile
    @param profileName string - Name for the new profile
    @param frameType string - "party" or "raid"
]]
function UnitFrames:SaveProfile(profileName, frameType)
    if not self.db then return end
    if not profileName or profileName == "" then return end
    
    self.db.profiles = self.db.profiles or {}
    
    local source = frameType == "raid" and self.db.raid or self.db.party
    if not source then return end
    
    local profileKey = profileName .. "_" .. frameType
    self.db.profiles[profileKey] = self:DeepCopy(source)
    
    print("|cff00ff00LilyUI:|r Profile '" .. profileName .. "' saved for " .. frameType .. " frames.")
end

--[[
    Loads a saved profile
    @param profileName string - Name of profile to load
    @param frameType string - "party" or "raid"
]]
function UnitFrames:LoadProfile(profileName, frameType)
    if not self.db or not self.db.profiles then return end
    
    local profileKey = profileName .. "_" .. frameType
    local savedProfile = self.db.profiles[profileKey]
    
    if not savedProfile then
        print("|cffff0000lilyUI:|r Profile '" .. profileName .. "' not found.")
        return
    end
    
    local target = frameType == "raid" and self.db.raid or self.db.party
    if not target then return end
    
    -- Preserve position
    local savedX = target.anchorX or (frameType == "raid" and target.raidAnchorX)
    local savedY = target.anchorY or (frameType == "raid" and target.raidAnchorY)
    
    -- Clear and copy
    for key in pairs(target) do
        target[key] = nil
    end
    
    for key, value in pairs(savedProfile) do
        if type(value) == "table" then
            target[key] = self:DeepCopy(value)
        else
            target[key] = value
        end
    end
    
    -- Restore position
    if frameType == "raid" then
        target.raidAnchorX = savedX
        target.raidAnchorY = savedY
    else
        target.anchorX = savedX
        target.anchorY = savedY
    end
    
    -- Refresh display
    if self.UpdateAllFrames then
        self:UpdateAllFrames()
    end
    
    print("|cff00ff00LilyUI:|r Profile '" .. profileName .. "' loaded for " .. frameType .. " frames.")
end

--[[
    Deletes a saved profile
    @param profileName string - Name of profile to delete
    @param frameType string - "party" or "raid"
]]
function UnitFrames:DeleteProfile(profileName, frameType)
    if not self.db or not self.db.profiles then return end
    
    local profileKey = profileName .. "_" .. frameType
    
    if self.db.profiles[profileKey] then
        self.db.profiles[profileKey] = nil
        print("|cff00ff00LilyUI:|r Profile '" .. profileName .. "' deleted.")
    end
end

--[[
    Duplicates a profile with a new name
    @param sourceName string - Source profile name
    @param newName string - New profile name
    @param frameType string - "party" or "raid"
]]
function UnitFrames:DuplicateProfile(sourceName, newName, frameType)
    if not self.db or not self.db.profiles then return end
    
    local sourceKey = sourceName .. "_" .. frameType
    local sourceProfile = self.db.profiles[sourceKey]
    
    if not sourceProfile then
        print("|cffff0000lilyUI:|r Source profile '" .. sourceName .. "' not found.")
        return
    end
    
    local newKey = newName .. "_" .. frameType
    self.db.profiles[newKey] = self:DeepCopy(sourceProfile)
    
    print("|cff00ff00LilyUI:|r Profile '" .. sourceName .. "' duplicated as '" .. newName .. "'.")
end

-- ============================================================================
-- IMPORT/EXPORT
-- ============================================================================

--[[
    Exports profile data as a shareable string
    @param categories table - Categories to include (from ExportCategories)
    @param frameTypes table - Frame types to export ("party", "raid", or both)
    @param profileName string - Optional profile name (uses current if not specified)
    @return string - Encoded export string
]]
function UnitFrames:ExportProfile(categories, frameTypes, profileName)
    local LibSerialize = LibStub and LibStub("LibSerialize", true)
    local LibDeflate = LibStub and LibStub("LibDeflate", true)
    
    if not LibSerialize or not LibDeflate then
        print("|cffff0000lilyUI:|r Export requires LibSerialize and LibDeflate.")
        return nil
    end
    
    local exportData = {
        version = self.BUILD or "1.0.0",
        timestamp = time(),
        name = profileName or "Export",
        categories = categories,
        data = {},
    }
    
    -- Collect data for specified frame types
    for _, frameType in ipairs(frameTypes or {"party", "raid"}) do
        local source = frameType == "raid" and self.db.raid or self.db.party
        if source then
            if categories and self.ExtractCategorySettings then
                exportData.data[frameType] = self:ExtractCategorySettings(source, categories, frameType)
            else
                exportData.data[frameType] = self:DeepCopy(source)
            end
        end
    end
    
    -- Serialize and compress
    local serialized = LibSerialize:Serialize(exportData)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForPrint(compressed)
    
    return "NUF:" .. encoded
end

--[[
    Validates an import string
    @param importString string - The import string to validate
    @return boolean, table|string - Success and decoded data or error message
]]
function UnitFrames:ValidateImportString(importString)
    local LibSerialize = LibStub and LibStub("LibSerialize", true)
    local LibDeflate = LibStub and LibStub("LibDeflate", true)
    
    if not LibSerialize or not LibDeflate then
        return false, "Import requires LibSerialize and LibDeflate."
    end
    
    if not importString or importString == "" then
        return false, "Import string is empty."
    end
    
    -- Check for prefix
    if not importString:match("^NUF:") then
        return false, "Invalid import string format."
    end
    
    local encoded = importString:gsub("^NUF:", "")
    
    -- Decode
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then
        return false, "Failed to decode import string."
    end
    
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return false, "Failed to decompress import data."
    end
    
    local success, importData = LibSerialize:Deserialize(serialized)
    if not success then
        return false, "Failed to deserialize import data."
    end
    
    -- Validate structure
    if type(importData) ~= "table" then
        return false, "Invalid import data structure."
    end
    
    if not importData.data then
        return false, "Import data is missing settings."
    end
    
    return true, importData
end

--[[
    Imports profile data from a string
    @param importString string - The encoded import string
    @param targetType string - Target frame type ("party" or "raid" or "both")
    @return boolean - Success status
]]
function UnitFrames:ImportProfile(importString, targetType)
    local success, importData = self:ValidateImportString(importString)
    
    if not success then
        print("|cffff0000lilyUI:|r " .. (importData or "Import failed."))
        return false
    end
    
    local frameTypes = {}
    if targetType == "both" then
        frameTypes = {"party", "raid"}
    else
        frameTypes = {targetType}
    end
    
    for _, frameType in ipairs(frameTypes) do
        local sourceData = importData.data[frameType]
        if sourceData then
            local target = frameType == "raid" and self.db.raid or self.db.party
            if target then
                -- Preserve position
                local savedX = target.anchorX or (frameType == "raid" and target.raidAnchorX)
                local savedY = target.anchorY or (frameType == "raid" and target.raidAnchorY)
                
                -- Merge imported settings
                if self.MergeCategorySettings then
                    self:MergeCategorySettings(target, sourceData, importData.categories)
                else
                    for key, value in pairs(sourceData) do
                        if type(value) == "table" then
                            target[key] = self:DeepCopy(value)
                        else
                            target[key] = value
                        end
                    end
                end
                
                -- Restore position
                if frameType == "raid" then
                    target.raidAnchorX = savedX
                    target.raidAnchorY = savedY
                else
                    target.anchorX = savedX
                    target.anchorY = savedY
                end
            end
        end
    end
    
    -- Refresh display
    if self.UpdateAllFrames then
        self:UpdateAllFrames()
    end
    
    print("|cff00ff00LilyUI:|r Profile imported successfully.")
    return true
end

-- ============================================================================
-- SPEC-BASED PROFILE AUTO-SWITCHING
-- ============================================================================

--[[
    Checks if profile auto-switch should occur based on spec
]]
function UnitFrames:CheckProfileAutoSwitch()
    if not self.db then return end
    
    local partyDb = self:GetDB()
    local raidDb = self:GetRaidDB()
    
    if not partyDb.specProfileEnabled and not raidDb.specProfileEnabled then
        return
    end
    
    local specIndex = GetSpecialization()
    if not specIndex then return end
    
    -- Check party frame spec profile
    if partyDb.specProfileEnabled and partyDb.specProfiles then
        local profileName = partyDb.specProfiles[specIndex]
        if profileName and profileName ~= "" then
            self:LoadProfile(profileName, "party")
        end
    end
    
    -- Check raid frame spec profile
    if raidDb.specProfileEnabled and raidDb.specProfiles then
        local profileName = raidDb.specProfiles[specIndex]
        if profileName and profileName ~= "" then
            self:LoadProfile(profileName, "raid")
        end
    end
end

-- Register for spec change events
local specEventFrame = CreateFrame("Frame")
specEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
specEventFrame:SetScript("OnEvent", function(self, event, unit)
    if unit == "player" then
        C_Timer.After(0.5, function()
            UnitFrames:CheckProfileAutoSwitch()
        end)
    end
end)
