-- Wick's Trade Hall - Minimap Button
-- Draggable minimap icon

local WTH = _G.WTH

local C_GREEN = { 0.31, 0.78, 0.47, 1 }
local C_BG    = { 0.05, 0.04, 0.08, 0.97 }
local FONT    = "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local button
local isDragging = false
local minimapAngle = 220 -- default position (degrees)

local function UpdatePosition()
    local rad = math.rad(minimapAngle)
    local x = 80 * math.cos(rad)
    local y = 80 * math.sin(rad)
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    button = CreateFrame("Button", "WicksTradeHallMinimapBtn", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:EnableMouse(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    -- Circular background using the minimap mask texture
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(24, 24)
    bg:SetPoint("CENTER")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetVertexColor(C_BG[1], C_BG[2], C_BG[3], C_BG[4])

    -- Icon text
    local icon = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    icon:SetFont(FONT, 14, "OUTLINE")
    icon:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3])
    icon:SetText("W")
    icon:SetPoint("CENTER", 0, 0)

    -- Border ring overlay
    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetPoint("TOPLEFT")
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Tooltip
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Wick's Trade Hall", C_GREEN[1], C_GREEN[2], C_GREEN[3])
        GameTooltip:AddLine("Left-click: Toggle board", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: Options", 0.8, 0.8, 0.8)
        GameTooltip:Show()
        icon:SetTextColor(1, 1, 1)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        icon:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3])
    end)

    -- Click
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            if WTH.ToggleUI then WTH.ToggleUI() end
        elseif btn == "RightButton" then
            if WTH.ToggleOptions then WTH.ToggleOptions() end
        end
    end)

    -- Dragging around minimap
    button:SetScript("OnDragStart", function()
        isDragging = true
    end)
    button:SetScript("OnDragStop", function()
        isDragging = false
    end)

    button:SetScript("OnUpdate", function(self)
        if isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
            UpdatePosition()
        end
    end)

    -- Restore saved angle
    if WTH.config and WTH.config.minimapAngle then
        minimapAngle = WTH.config.minimapAngle
    end
    UpdatePosition()

    return button
end

---------------------------------------------------------------------------
-- Visibility
---------------------------------------------------------------------------
function WTH.UpdateMinimapVisibility()
    if not button then return end
    if WTH.config and WTH.config.minimapButton then
        button:Show()
    else
        button:Hide()
    end
end

---------------------------------------------------------------------------
-- Init on PLAYER_ENTERING_WORLD
---------------------------------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self)
    CreateMinimapButton()
    WTH.UpdateMinimapVisibility()

    -- Save angle on logout
    local saveFrame = CreateFrame("Frame")
    saveFrame:RegisterEvent("PLAYER_LOGOUT")
    saveFrame:SetScript("OnEvent", function()
        if WTH.config then
            WTH.config.minimapAngle = minimapAngle
        end
    end)

    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end)
