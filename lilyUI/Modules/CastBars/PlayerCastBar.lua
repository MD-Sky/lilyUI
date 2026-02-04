local ADDON_NAME, ns = ...
local LilyUI = ns.Addon

-- Get CastBars module
local CastBars = LilyUI.CastBars
if not CastBars then
    error("lilyUI: CastBars module not initialized! Load CastBars.lua first.")
end

local CastBar_OnUpdate = CastBars.CastBar_OnUpdate
local CreateBorder = CastBars.CreateBorder
local GetClassColor = CastBars.GetClassColor

local function PixelSnap(value)
    return math.max(0, math.floor((value or 0) + 0.5))
end

-- PLAYER CAST BAR

function CastBars:GetCastBar()
    if LilyUI.castBar then return LilyUI.castBar end

    local cfg    = LilyUI.db.profile.castBar
    local anchor = _G[cfg.attachTo] or UIParent
    local anchorPoint = cfg.anchorPoint or "CENTER"

    local bar = CreateFrame("Frame", ADDON_NAME .. "CastBar", anchor)
    bar:SetFrameStrata("MEDIUM")

    local height = cfg.height or 10
    bar:SetHeight(LilyUI:Scale(height))
    bar:SetPoint("CENTER", anchor, anchorPoint, LilyUI:Scale(cfg.offsetX or 0), LilyUI:Scale(cfg.offsetY or 18))
    -- Use pixel-snapped width from the anchor (viewer or frame)
    bar:SetWidth(PixelSnap(anchor.__cdmIconWidth or anchor:GetWidth()))

    CreateBorder(bar)

    -- Status bar
    bar.status = CreateFrame("StatusBar", nil, bar)
    -- Use GetTexture helper: if cfg.texture is set, use it; otherwise use global texture
    local tex = LilyUI:GetTexture(LilyUI.db.profile.castBar.texture)
    bar.status:SetStatusBarTexture(tex)

    local sbTex = bar.status:GetStatusBarTexture()
    if sbTex then
        sbTex:SetDrawLayer("ARTWORK")  -- Draw above segment backgrounds for empowered casts
    end

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar.status)
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    bar.icon = bar:CreateTexture(nil, "ARTWORK")
    bar.icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    -- Text
    bar.spellName = bar.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.spellName:SetJustifyH("LEFT")

    bar.timeText = bar.status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.timeText:SetJustifyH("RIGHT")

    bar:Hide()

    -- Empowered stages storage
    bar.empoweredStages = {}

    LilyUI.castBar = bar
    return bar
end

function CastBars:UpdateCastBarLayout()
    local cfg = LilyUI.db.profile.castBar
    
    -- Set default cast bar alpha to 0 only if custom cast bar is enabled
    local defaultCastBar = _G["PlayerCastingBarFrame"] or _G["CastingBarFrame"]
    if defaultCastBar then
        if cfg.enabled then
            -- Custom cast bar is enabled, hide the default one
            defaultCastBar:SetAlpha(0)
            -- Hook OnShow to keep it at alpha 0 and hide child regions (including "Interrupted" text)
            if not defaultCastBar.__nephuiAlphaHooked then
                defaultCastBar.__nephuiAlphaHooked = true
                
                -- Hide all child regions (including "Interrupted" text)
                local function HideChildRegions(frame)
                    if not frame then return end
                    
                    -- Hide all regions (textures, fontstrings, etc.)
                    if frame.GetRegions then
                        for _, region in ipairs({ frame:GetRegions() }) do
                            if region and region.SetAlpha then
                                region:SetAlpha(0)
                            end
                            if region and region.Hide then
                                region:Hide()
                            end
                        end
                    end
                    
                    -- Hide all child frames
                    if frame.GetChildren then
                        for _, child in ipairs({ frame:GetChildren() }) do
                            if child then
                                child:SetAlpha(0)
                                if child.Hide then
                                    child:Hide()
                                end
                                -- Recursively hide children of children
                                HideChildRegions(child)
                            end
                        end
                    end
                end
                
                -- Hide child regions initially
                HideChildRegions(defaultCastBar)
                
                -- Hook OnShow to keep it at alpha 0 and hide children
                defaultCastBar:HookScript("OnShow", function(self)
                    local cfg = LilyUI.db.profile.castBar
                    if cfg and cfg.enabled then
                        self:SetAlpha(0)
                        HideChildRegions(self)
                    end
                end)
                
                -- Hook OnUpdate to continuously hide any new child regions (like "Interrupted" text)
                defaultCastBar:HookScript("OnUpdate", function(self)
                    local cfg = LilyUI.db.profile.castBar
                    if cfg and cfg.enabled then
                        HideChildRegions(self)
                    end
                end)
            end
        else
            -- Custom cast bar is disabled, restore the default one
            defaultCastBar:SetAlpha(1)
            -- Note: The hooks check cfg.enabled so they won't interfere when disabled
            -- Blizzard's code will handle showing child regions when the cast bar is shown
        end
    end
    
    if not LilyUI.castBar then return end

    local bar    = LilyUI.castBar
    local anchor = _G[cfg.attachTo] or UIParent
    local anchorPoint = cfg.anchorPoint or "CENTER"
    local height = cfg.height or 10

    bar:ClearAllPoints()
    bar:SetPoint("CENTER", anchor, anchorPoint, LilyUI:Scale(cfg.offsetX or 0), LilyUI:Scale(cfg.offsetY or 18))
    bar:SetHeight(LilyUI:Scale(height))

    local width = cfg.width or 0
    if width <= 0 then
        width = PixelSnap(anchor.__cdmIconWidth or anchor:GetWidth())
        -- Width is already in pixels, no need to scale again
    else
        width = LilyUI:Scale(width)
    end
    
    bar:SetWidth(width)

    if bar.border then
        bar.border:ClearAllPoints()
        local borderOffset = LilyUI:Scale(1)
        bar.border:SetPoint("TOPLEFT", bar, -borderOffset, borderOffset)
        bar.border:SetPoint("BOTTOMRIGHT", bar, borderOffset, -borderOffset)
    end

    local showIcon = cfg.showIcon ~= false

    -- Icon: left side
    bar.icon:ClearAllPoints()
    if showIcon then
        bar.icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        bar.icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        -- Use bar height directly (already in pixels from SetHeight)
        bar.icon:SetWidth(bar:GetHeight())
        bar.icon:Show()
    else
        bar.icon:SetWidth(0)
        bar.icon:Hide()
    end

    bar.status:ClearAllPoints()
    if showIcon then
        bar.status:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 0, 0)
    else
        bar.status:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    end
    bar.status:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)

    bar.bg:ClearAllPoints()
    bar.bg:SetAllPoints(bar.status)

    -- Update background color
    local bgColor = cfg.bgColor or { 0.1, 0.1, 0.1, 1 }
    bar.bg:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 1)

    -- Use GetTexture helper: if cfg.texture is set, use it; otherwise use global texture
    local tex = LilyUI:GetTexture(cfg.texture)
    bar.status:SetStatusBarTexture(tex)

    local sbTex = bar.status:GetStatusBarTexture()
    if sbTex then
        sbTex:SetDrawLayer("BACKGROUND")
    end

    -- Color
    local r, g, b, a

    if cfg.useClassColor then
        r, g, b = GetClassColor()
        a = 1
    elseif cfg.color then
        r, g, b, a = cfg.color[1], cfg.color[2], cfg.color[3], cfg.color[4] or 1
    else
        r, g, b, a = 1, 0.7, 0, 1
    end

    bar.status:SetStatusBarColor(r, g, b, a or 1)

    bar.spellName:ClearAllPoints()
    bar.spellName:SetPoint("LEFT", bar.status, "LEFT", LilyUI:Scale(4), 0)

    bar.timeText:ClearAllPoints()
    bar.timeText:SetPoint("RIGHT", bar.status, "RIGHT", LilyUI:Scale(-4), 0)

    local font, _, flags = bar.spellName:GetFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)
    
    -- Show/hide time text based on setting
    if cfg.showTimeText ~= false then
        bar.timeText:Show()
    else
        bar.timeText:Hide()
    end

    -- Reinitialize empowered stages if bar is currently showing an empowered cast
    if bar.isEmpowered and bar.numStages and bar.numStages > 0 then
        if CastBars.InitializeEmpoweredStages then
            CastBars:InitializeEmpoweredStages(bar)
        end
    end
end

function CastBars:OnPlayerSpellcastStart(unit, castGUID, spellID)
    local cfg = LilyUI.db.profile.castBar
    if not cfg.enabled then
        if LilyUI.castBar then LilyUI.castBar:Hide() end
        return
    end

    -- UnitCastingInfo now returns: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId, numStages, isEmpowered, castBarID
    -- Regular casts are never empowered - empowered casts come through UnitChannelInfo or UNIT_SPELLCAST_EMPOWER_START
    local name, _, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, unitSpellID, numStages, isEmpowered, castBarID = UnitCastingInfo("player")
    if not name or not startTimeMS or not endTimeMS then
        if LilyUI.castBar then LilyUI.castBar:Hide() end
        return
    end

    local bar = self:GetCastBar()
    self:UpdateCastBarLayout()

    bar.isChannel = false
    bar.castGUID  = castGUID
    bar.castBarID = castBarID  -- Store castBarID for cast tracking
    
    -- Regular casts are never empowered - don't initialize empowered stages here
    bar.isEmpowered = false
    bar.numStages = 0

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    local font = LilyUI:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    local now = GetTime()
    bar.startTime = startTimeMS / 1000
    bar.endTime   = endTimeMS / 1000

    -- Safety: if start time is very old, clamp to now
    if bar.startTime < now - 5 then
        local dur = (endTimeMS - startTimeMS) / 1000
        bar.startTime = now
        bar.endTime   = now + dur
    end

    -- Regular casts don't have empowered stages - only channels/empower events do
    -- Clean up any existing empowered stages from previous cast
    if bar.empoweredStages then
        for _, stage in ipairs(bar.empoweredStages) do
            if stage then
                stage:Hide()
                if stage.border then
                    stage.border:Hide()
                end
            end
        end
    end
    if bar.empoweredSegments then
        for _, segment in ipairs(bar.empoweredSegments) do
            if segment then
                segment:Hide()
            end
        end
    end
    if bar.empoweredGlow then
        bar.empoweredGlow:Hide()
    end

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

function CastBars:OnPlayerSpellcastStop(unit, castGUID, spellID)
    if not LilyUI.castBar then return end

    if castGUID and LilyUI.castBar.castGUID and castGUID ~= LilyUI.castBar.castGUID then
        return
    end

    -- Check if player is still channeling - if so, don't hide the cast bar
    -- This handles the case where a spell is attempted during a channel (GCD locked)
    -- and UNIT_SPELLCAST_STOP/FAILED fires, but the channel continues
    if LilyUI.castBar.isChannel then
        local name, _, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, unitSpellID, numStages, isEmpowered, castBarID = UnitChannelInfo("player")
        if name and startTimeMS and endTimeMS then
            -- Still channeling, update the cast bar instead of hiding it
            LilyUI.castBar.icon:SetTexture(texture)
            LilyUI.castBar.spellName:SetText(name)
            LilyUI.castBar.startTime = startTimeMS / 1000
            LilyUI.castBar.endTime = endTimeMS / 1000
            LilyUI.castBar.castBarID = castBarID
            return
        end
    end

    LilyUI.castBar.castGUID  = nil
    LilyUI.castBar.castBarID = nil
    LilyUI.castBar.isChannel = nil
    LilyUI.castBar.isEmpowered = nil
    LilyUI.castBar.numStages = nil
    LilyUI.castBar.lastNumStages = nil
    LilyUI.castBar.currentEmpoweredStage = nil
    if LilyUI.castBar.empoweredStages then
        for _, stage in ipairs(LilyUI.castBar.empoweredStages) do
            if stage then
                stage:Hide()
                if stage.border then
                    stage.border:Hide()
                end
            end
        end
    end
    if LilyUI.castBar.empoweredSegments then
        for _, segment in ipairs(LilyUI.castBar.empoweredSegments) do
            if segment then
                segment:Hide()
            end
        end
    end
    if LilyUI.castBar.empoweredGlow then
        LilyUI.castBar.empoweredGlow:Hide()
    end
    LilyUI.castBar:Hide()
    LilyUI.castBar:SetScript("OnUpdate", nil)
end

function CastBars:OnPlayerSpellcastChannelStart(unit, castGUID, spellID)
    local cfg = LilyUI.db.profile.castBar
    if not cfg.enabled then
        if LilyUI.castBar then LilyUI.castBar:Hide() end
        return
    end

    -- UnitChannelInfo now returns: name, text, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, spellId, numStages, isEmpowered, castBarID
    -- Check UnitChannelInfo for empowered casts - if EmpowerStages (numStages) is present, it's empowered
    local name, _, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, unitSpellID, numStages, isEmpowered, castBarID = UnitChannelInfo("player")
    if not name or not startTimeMS or not endTimeMS then
        if LilyUI.castBar then LilyUI.castBar:Hide() end
        return
    end

    local bar = self:GetCastBar()
    self:UpdateCastBarLayout()

    bar.isChannel = true
    bar.castGUID  = castGUID
    bar.castBarID = castBarID  -- Store castBarID for cast tracking
    
    -- Check if this is an empowered channel - if numStages (EmpowerStages) is present, it's empowered
    -- Following FeelUI's approach: check for EmpowerStages from UnitChannelInfo
    local isEmpoweredCast = (numStages and numStages > 0) or false
    
    bar.isEmpowered = isEmpoweredCast
    bar.numStages = numStages or 0

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    local font = LilyUI:GetGlobalFont()
    bar.spellName:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.spellName:SetShadowOffset(0, 0)

    bar.timeText:SetFont(font, cfg.textSize or 10, "OUTLINE")
    bar.timeText:SetShadowOffset(0, 0)

    bar.startTime = startTimeMS / 1000
    bar.endTime   = endTimeMS / 1000

    -- Initialize empowered stages only if this is actually an empowered channel
    if bar.isEmpowered and bar.numStages > 0 then
        -- Delay initialization slightly to ensure bar is properly sized
        C_Timer.After(0.01, function()
            if bar.isEmpowered and bar.numStages > 0 then
                if CastBars.InitializeEmpoweredStages then
                    CastBars:InitializeEmpoweredStages(bar)
                end
            end
        end)
    else
        -- Clean up any existing empowered stages if this is a regular channel
        if bar.empoweredStages then
            for _, stage in ipairs(bar.empoweredStages) do
                if stage then
                    stage:Hide()
                    if stage.border then
                        stage.border:Hide()
                    end
                end
            end
        end
        if bar.empoweredSegments then
            for _, segment in ipairs(bar.empoweredSegments) do
                if segment then
                    segment:Hide()
                end
            end
        end
        if bar.empoweredGlow then
            bar.empoweredGlow:Hide()
        end
    end

    bar:SetScript("OnUpdate", CastBar_OnUpdate)
    bar:Show()
end

function CastBars:OnPlayerSpellcastChannelUpdate(unit, castGUID, spellID)
    if not LilyUI.castBar then return end
    if LilyUI.castBar.castGUID and castGUID and castGUID ~= LilyUI.castBar.castGUID then
        return
    end

    local name, _, texture, startTimeMS, endTimeMS, isTradeSkill, castID, notInterruptible, unitSpellID, numStages, isEmpowered, castBarID = UnitChannelInfo("player")
    if not name or not startTimeMS or not endTimeMS then
        return
    end

    local bar = LilyUI.castBar
    bar.isChannel = true
    bar.castGUID  = castGUID
    bar.castBarID = castBarID  -- Update castBarID
    
    -- Update empowered status - check for EmpowerStages (numStages) from UnitChannelInfo
    local isEmpoweredCast = (numStages and numStages > 0) or false
    bar.isEmpowered = isEmpoweredCast
    bar.numStages = numStages or 0

    bar.icon:SetTexture(texture)
    bar.spellName:SetText(name)

    bar.startTime = startTimeMS / 1000
    bar.endTime   = endTimeMS / 1000
    
    -- Reinitialize empowered stages if needed
    if bar.isEmpowered and bar.numStages > 0 then
        if bar.numStages ~= (bar.lastNumStages or 0) then
            bar.lastNumStages = bar.numStages
            if CastBars.InitializeEmpoweredStages then
                CastBars:InitializeEmpoweredStages(bar)
            end
        end
    end
end

-- Expose to main addon for backwards compatibility
LilyUI.GetCastBar = function(self) return CastBars:GetCastBar() end
LilyUI.UpdateCastBarLayout = function(self) return CastBars:UpdateCastBarLayout() end
LilyUI.OnPlayerSpellcastStart = function(self, unit, castGUID, spellID) return CastBars:OnPlayerSpellcastStart(unit, castGUID, spellID) end
LilyUI.OnPlayerSpellcastStop = function(self, unit, castGUID, spellID) return CastBars:OnPlayerSpellcastStop(unit, castGUID, spellID) end
LilyUI.OnPlayerSpellcastChannelStart = function(self, unit, castGUID, spellID) return CastBars:OnPlayerSpellcastChannelStart(unit, castGUID, spellID) end
LilyUI.OnPlayerSpellcastChannelUpdate = function(self, unit, castGUID, spellID) return CastBars:OnPlayerSpellcastChannelUpdate(unit, castGUID, spellID) end


