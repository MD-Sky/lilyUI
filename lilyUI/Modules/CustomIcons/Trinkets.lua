local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Get CustomIcons module
local CustomIcons = LilyUI.CustomIcons
if not CustomIcons then
    error("lilyUI: CustomIcons module not initialized! Load CustomIcons.lua first.")
end

-- Get functions from CustomIcons
local CreateCustomItemIcon = CustomIcons.CreateCustomItemIcon
local UpdateCustomItemCooldown = CustomIcons.UpdateCustomItemCooldown
local GetAnchorFrame = CustomIcons.GetAnchorFrame
local ApplyCustomIconBorder = CustomIcons.ApplyCustomIconBorder

-- Storage for trinket/weapon slot icons
local trinketWeaponIcons = {} -- [slotID] = iconFrame
local slotMapping = {
    trinket1 = 13,
    trinket2 = 14,
    weapon1 = 16,
    weapon2 = 17,
}

-- Get item ID from inventory slot
local function GetItemIDFromSlot(slotID)
    if not slotID then return nil end
    return GetInventoryItemID("player", slotID)
end

-- Update trinket/weapon icon for a specific slot
local function UpdateTrinketWeaponIcon(slotID, slotKey)
    if not slotID or not LilyUI.trinketsTrackerFrame then return end
    
    local db = LilyUI.db.profile.customIcons
    if not db or not db.trinkets then return end
    
    -- Check if this slot should be tracked
    local shouldTrack = db.trinkets[slotKey]
    if not shouldTrack then
        -- Remove icon if it exists
        local icon = trinketWeaponIcons[slotID]
        if icon then
            icon:Hide()
            icon:SetParent(nil)
            trinketWeaponIcons[slotID] = nil
        end
        return
    end
    
    -- Get item ID from slot
    local itemID = GetItemIDFromSlot(slotID)
    if not itemID then
        -- No item in slot, hide icon if it exists
        local icon = trinketWeaponIcons[slotID]
        if icon then
            icon:Hide()
        end
        return
    end
    
    -- Check if icon already exists
    local icon = trinketWeaponIcons[slotID]
    if icon then
        -- Update existing icon if item changed
        if icon._LilyUI_itemID ~= itemID then
            -- Item changed, recreate icon
            icon:Hide()
            icon:SetParent(nil)
            trinketWeaponIcons[slotID] = nil
            icon = nil
        else
            -- Same item, just update cooldown
            UpdateCustomItemCooldown(itemID, icon)
            icon:Show()
            return
        end
    end
    
    -- Create new icon
    if not icon then
        icon = CreateCustomItemIcon(itemID, LilyUI.trinketsTrackerFrame)
        if icon then
            icon._LilyUI_slotID = slotID
            icon._LilyUI_slotKey = slotKey
            trinketWeaponIcons[slotID] = icon
            UpdateCustomItemCooldown(itemID, icon)
            if CustomIcons.ApplyTrinketsLayout then
                CustomIcons:ApplyTrinketsLayout()
            end
        else
            -- Item data not loaded yet, retry
            C_Timer.After(1, function()
                if CustomIcons.UpdateTrinketWeaponTracking then
                    CustomIcons:UpdateTrinketWeaponTracking()
                end
            end)
        end
    end
end

-- Update all trinket/weapon tracking based on toggles
function CustomIcons:UpdateTrinketWeaponTracking()
    if not LilyUI.trinketsTrackerFrame then return end
    
    for slotKey, slotID in pairs(slotMapping) do
        UpdateTrinketWeaponIcon(slotID, slotKey)
    end
    
    -- Relayout after updating
    if self.ApplyTrinketsLayout then
        self:ApplyTrinketsLayout()
    end
end

-- Update trinket cooldowns (called from UpdateAllCustomItemCooldowns)
function CustomIcons:UpdateTrinketCooldowns()
    for slotID, iconFrame in pairs(trinketWeaponIcons) do
        local itemID = GetItemIDFromSlot(slotID)
        if itemID and iconFrame then
            UpdateCustomItemCooldown(itemID, iconFrame)
        end
    end
end

-- Create the trinkets tracker frame
function CustomIcons:CreateTrinketsTrackerFrame()
    if LilyUI.trinketsTrackerFrame then return LilyUI.trinketsTrackerFrame end
    
    local db = LilyUI.db.profile.customIcons
    if not db or not db.enabled then return nil end
    
    local frame = CreateFrame("Frame", "LilyUI_TrinketsTrackerFrame", UIParent)
    frame:SetSize(200, 40)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    
    -- Default position (slightly offset from items frame)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    
    frame._LilyUI_TrinketsTracker = true
    
    LilyUI.trinketsTrackerFrame = frame
    
    -- Load trinket/weapon icons
    if self.UpdateTrinketWeaponTracking then
        self:UpdateTrinketWeaponTracking()
    end
    
    -- Hook into equipment changes
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            local slotID = ...
            -- Check if this is a tracked slot
            if trinketWeaponIcons[slotID] then
                C_Timer.After(0.1, function()
                    if CustomIcons.UpdateTrinketWeaponTracking then
                        CustomIcons:UpdateTrinketWeaponTracking()
                    end
                end)
            end
        end
    end)
    
    -- Apply layout
    if self.ApplyTrinketsLayout then
        self:ApplyTrinketsLayout()
    end
    
    return frame
end

-- Apply layout to trinkets/weapons (similar to ApplyCustomIconsLayout)
function CustomIcons:ApplyTrinketsLayout()
    if not LilyUI.trinketsTrackerFrame then return end
    
    local db = LilyUI.db.profile.customIcons
    if not db or not db.enabled then return end
    
    local settings = db.trinkets or {}
    local container = LilyUI.trinketsTrackerFrame
    local icons = {}
    
    -- Collect trinket/weapon icons in order: trinket1, trinket2, weapon1, weapon2
    local hideUnusable = settings.hideUnusableItems or false
    local slotOrder = {13, 14, 16, 17}  -- trinket1, trinket2, weapon1, weapon2
    for _, slotID in ipairs(slotOrder) do
        local icon = trinketWeaponIcons[slotID]
        if icon then
            -- Check if we should hide unusable items
            if hideUnusable then
                local itemID = GetItemIDFromSlot(slotID)
                if itemID and CustomIcons.IsItemUsable and CustomIcons.IsItemUsable(itemID) then
                    table.insert(icons, icon)
                    icon:Show()  -- Ensure it's shown if usable
                else
                    icon:Hide()  -- Hide if not usable or no item
                end
            else
                -- Show all tracked items when toggle is disabled
                if icon:IsShown() then
                    table.insert(icons, icon)
                end
            end
        end
    end
    
    local count = #icons
    if count == 0 then return end
    
    -- Get settings (exclude trinket toggles)
    local iconSize = settings.iconSize or 40
    local spacing = settings.spacing or -9
    local rowLimit = settings.rowLimit or 0
    local growthDirection = settings.growthDirection or "Centered"
    local aspectRatioValue = settings.aspectRatioCrop or 1.0
    
    -- Calculate icon dimensions with aspect ratio
    local iconWidth = iconSize
    local iconHeight = iconSize
    if aspectRatioValue > 1.0 then
        -- Wider than tall
        iconHeight = iconSize / aspectRatioValue
    elseif aspectRatioValue < 1.0 then
        -- Taller than wide
        iconWidth = iconSize * aspectRatioValue
    end
    
    -- Apply borders and set icon sizes
    for _, icon in ipairs(icons) do
        icon:SetSize(iconWidth, iconHeight)
        icon:ClearAllPoints()
        -- Apply border
        ApplyCustomIconBorder(icon, settings)
    end
    
    -- Handle anchoring
    local anchorFrame = GetAnchorFrame(settings.anchorFrame)
    local offsetX = settings.offsetX or 0
    local offsetY = settings.offsetY or 0
    
    -- Position container relative to anchor frame
    if anchorFrame and anchorFrame ~= UIParent then
        container:ClearAllPoints()
        container:SetPoint("CENTER", anchorFrame, "CENTER", offsetX, offsetY)
    elseif settings.anchorFrame and settings.anchorFrame ~= "" then
        -- Anchor frame specified but doesn't exist yet - retry after a delay
        C_Timer.After(0.5, function()
            if self.ApplyTrinketsLayout then
                self:ApplyTrinketsLayout()
            end
        end)
        return  -- Don't apply layout yet, wait for anchor frame
    else
        -- Default position if no anchor
        container:ClearAllPoints()
        container:SetPoint("CENTER", UIParent, "CENTER", offsetX, offsetY - 250)
    end
    
    -- Apply layout based on growth direction
    if rowLimit <= 0 then
        -- Single row
        local totalWidth = count * iconWidth + (count - 1) * spacing
        local startX
        
        if growthDirection == "Left" then
            -- Left growth: first icon at center, others grow left
            startX = iconWidth / 2
            for i, icon in ipairs(icons) do
                local x = startX - (i - 1) * (iconWidth + spacing)
                icon:SetPoint("CENTER", container, "CENTER", x, 0)
                icon:Show()
            end
        elseif growthDirection == "Right" then
            -- Right growth: first icon at center, others grow right
            startX = -iconWidth / 2
            for i, icon in ipairs(icons) do
                local x = startX + (i - 1) * (iconWidth + spacing)
                icon:SetPoint("CENTER", container, "CENTER", x, 0)
                icon:Show()
            end
        else
            -- Centered (default)
            startX = -totalWidth / 2 + iconWidth / 2
            for i, icon in ipairs(icons) do
                local x = startX + (i - 1) * (iconWidth + spacing)
                icon:SetPoint("CENTER", container, "CENTER", x, 0)
                icon:Show()
            end
        end
    else
        -- Multi-row layout
        local numRows = math.ceil(count / rowLimit)
        local rowSpacing = iconHeight + spacing
        
        for i, icon in ipairs(icons) do
            local row = math.ceil(i / rowLimit)
            local rowStart = (row - 1) * rowLimit + 1
            local rowEnd = math.min(row * rowLimit, count)
            local rowCount = rowEnd - rowStart + 1
            local positionInRow = i - rowStart + 1
            
            local rowWidth = rowCount * iconWidth + (rowCount - 1) * spacing
            local x, y
            
            if growthDirection == "Left" then
                -- Left growth: first icon in row at center, others grow left
                local firstIconX = iconWidth / 2
                x = firstIconX - (positionInRow - 1) * (iconWidth + spacing)
            elseif growthDirection == "Right" then
                -- Right growth: first icon in row at center, others grow right
                local firstIconX = -iconWidth / 2
                x = firstIconX + (positionInRow - 1) * (iconWidth + spacing)
            else
                -- Centered (default)
                local startX = -rowWidth / 2 + iconWidth / 2
                x = startX + (positionInRow - 1) * (iconWidth + spacing)
            end
            
            -- Vertical position (main row at y=0)
            y = -(row - 1) * rowSpacing
            
            icon:SetPoint("CENTER", container, "CENTER", x, y)
            icon:Show()
        end
    end
    
    -- Update all cooldowns
    if CustomIcons.UpdateAllCustomItemCooldowns then
        CustomIcons.UpdateAllCustomItemCooldowns()
    end
end

-- Expose to main addon for backwards compatibility
LilyUI.CreateTrinketsTrackerFrame = function(self) return CustomIcons:CreateTrinketsTrackerFrame() end
LilyUI.ApplyTrinketsLayout = function(self) return CustomIcons:ApplyTrinketsLayout() end
LilyUI.UpdateTrinketWeaponTracking = function(self) return CustomIcons:UpdateTrinketWeaponTracking() end

