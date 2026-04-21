-- Wick's Trade Hall - Options
-- Settings panel with themed UI

local WTH = _G.WTH
local Cat = WTH.Categories

---------------------------------------------------------------------------
-- Theme colors
---------------------------------------------------------------------------
local C_BG          = { 0.05, 0.04, 0.08, 0.97 }
local C_HEADER_BG   = { 0.09, 0.07, 0.16, 1 }
local C_BUTTON_BG   = { 0.07, 0.06, 0.12, 1 }
local C_BORDER      = { 0.22, 0.18, 0.36, 1 }
local C_GREEN       = { 0.31, 0.78, 0.47, 1 }
local C_TEXT_DIM    = { 0.42, 0.35, 0.54, 1 }
local C_TEXT_NORMAL = { 0.83, 0.78, 0.63, 1 }

local FONT = "Fonts\\FRIZQT__.TTF"

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function NewTexture(parent, layer, c)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    if c then
        if c[4] then t:SetColorTexture(c[1], c[2], c[3], c[4])
        else t:SetColorTexture(c[1], c[2], c[3], 1) end
    end
    return t
end

local function NewText(parent, size, r, g, b, a)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetFont(FONT, (size or 11) + 1, "")
    f:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    return f
end

local function AddBorder(frame, r, g, b, a)
    r, g, b, a = r or 0.22, g or 0.18, b or 0.36, a or 1
    local e = {}
    e[1] = NewTexture(frame, "BORDER"); e[1]:SetColorTexture(r,g,b,a)
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
    e[2] = NewTexture(frame, "BORDER"); e[2]:SetColorTexture(r,g,b,a)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3] = NewTexture(frame, "BORDER"); e[3]:SetColorTexture(r,g,b,a)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4] = NewTexture(frame, "BORDER"); e[4]:SetColorTexture(r,g,b,a)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
    return e
end

---------------------------------------------------------------------------
-- Options panel
---------------------------------------------------------------------------
local optPanel
local yOffset -- tracks vertical layout position

local function SectionHeader(parent, text, y)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 0, y)
    header:SetPoint("RIGHT", 0, 0)
    header:SetHeight(20)

    local bg = NewTexture(header, "BACKGROUND", { C_GREEN[1], C_GREEN[2], C_GREEN[3], 0.03 })
    bg:SetAllPoints()

    local top = NewTexture(header, "ARTWORK", { C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.4 })
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    local bot = NewTexture(header, "ARTWORK", { C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.4 })
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)

    local label = NewText(header, 9, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    label:SetFont(FONT, 11, "OUTLINE")
    label:SetText(text:upper())
    label:SetPoint("LEFT", 10, 0)

    return -24
end

local function MakeCheckbox(parent, y, label, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 14, y)
    cb:SetSize(22, 22)
    cb:SetChecked(getter())
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)

    local text = NewText(parent, 10, C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3])
    text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    text:SetText(label)

    return -24
end

local function MakeSlider(parent, y, label, min, max, step, getter, setter)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 14, y)
    container:SetPoint("RIGHT", -14, 0)
    container:SetHeight(44)

    local title = NewText(container, 9, C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3])
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(label)

    local valueText = NewText(container, 9, C_GREEN[1], C_GREEN[2], C_GREEN[3])
    valueText:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -16)
    slider:SetPoint("TOPRIGHT", 0, -16)
    slider:SetHeight(16)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(getter())

    -- Hide default text
    local regions = { slider:GetRegions() }
    for _, r in ipairs(regions) do
        if r:IsObjectType("FontString") then r:Hide() end
    end

    valueText:SetText(tostring(math.floor(getter())))

    -- Min/max labels
    local minLabel = NewText(container, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    minLabel:SetText(tostring(min))

    local maxLabel = NewText(container, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    maxLabel:SetText(tostring(max))

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        setter(val)
        valueText:SetText(tostring(math.floor(val)))
    end)

    return -52
end

local function CreateOptionsPanel()
    optPanel = CreateFrame("Frame", "WicksTradeHallOptions", UIParent, "BackdropTemplate")
    optPanel:SetFrameStrata("DIALOG")
    optPanel:SetClampedToScreen(true)
    optPanel:SetMovable(true)
    optPanel:EnableMouse(true)
    optPanel:SetSize(340, 520)
    optPanel:SetPoint("CENTER", 200, 0)

    -- Background
    local bg = NewTexture(optPanel, "BACKGROUND", C_BG)
    bg:SetAllPoints()
    AddBorder(optPanel)

    -- Corner accents
    local corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    for _, point in ipairs(corners) do
        local h = NewTexture(optPanel, "OVERLAY"); h:SetColorTexture(C_GREEN[1], C_GREEN[2], C_GREEN[3], 1)
        h:SetPoint(point, optPanel, point, 0, 0); h:SetSize(10, 2)
        local v = NewTexture(optPanel, "OVERLAY"); v:SetColorTexture(C_GREEN[1], C_GREEN[2], C_GREEN[3], 1)
        v:SetPoint(point, optPanel, point, 0, 0); v:SetSize(2, 10)
    end

    -- Dragging
    optPanel:RegisterForDrag("LeftButton")
    optPanel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    optPanel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Header
    local header = CreateFrame("Frame", nil, optPanel)
    header:SetPoint("TOPLEFT", optPanel, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", optPanel, "TOPRIGHT", -1, -1)
    header:SetHeight(34)

    local headerBG = NewTexture(header, "BACKGROUND", C_HEADER_BG)
    headerBG:SetAllPoints()

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetFont(FONT, 15, "OUTLINE")
    title:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3])
    title:SetPoint("LEFT", 12, 0)
    title:SetText("Settings")

    -- Accent line
    local accent = NewTexture(header, "ARTWORK", { C_GREEN[1], C_GREEN[2], C_GREEN[3], 0.35 })
    accent:SetPoint("BOTTOMLEFT", 40, 0)
    accent:SetPoint("BOTTOMRIGHT", -40, 0)
    accent:SetHeight(1)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("TOPRIGHT", -8, -9)
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    closeText:SetFont(FONT, 14, "OUTLINE")
    closeText:SetText("X")
    closeText:SetTextColor(0.6, 0.5, 0.7)
    closeText:SetAllPoints()
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(0.6, 0.5, 0.7) end)
    closeBtn:SetScript("OnClick", function() optPanel:Hide() end)

    -------------------------------------------------------------------
    -- Scroll frame
    -------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, optPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 4, -38)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(600) -- will be adjusted
    scrollFrame:SetScrollChild(scrollChild)

    local cfg = WTH.config
    local y = -8

    -------------------------------------------------------------------
    -- Timing
    -------------------------------------------------------------------
    y = y + SectionHeader(scrollChild, "Timing", y)

    y = y + MakeSlider(scrollChild, y, "Listing Expiry (seconds)", 30, 600, 10,
        function() return cfg.expirySecs end,
        function(v) cfg.expirySecs = v end)

    y = y + MakeSlider(scrollChild, y, "Spam Cooldown (seconds)", 5, 120, 5,
        function() return cfg.cooldownSecs end,
        function(v) cfg.cooldownSecs = v end)

    y = y + MakeSlider(scrollChild, y, "Max Per Category", 10, 200, 10,
        function() return cfg.maxPerCategory end,
        function(v) cfg.maxPerCategory = v end)

    -------------------------------------------------------------------
    -- Categories
    -------------------------------------------------------------------
    y = y + SectionHeader(scrollChild, "Category Visibility", y)

    for _, catKey in ipairs(Cat.ORDER) do
        local meta = Cat.META[catKey]
        local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 14, y)
        cb:SetSize(22, 22)
        cb:SetChecked(cfg.categoryVisible[catKey])
        cb:SetScript("OnClick", function(self)
            cfg.categoryVisible[catKey] = self:GetChecked() and true or false
        end)

        local label = NewText(scrollChild, 10, meta.color[1], meta.color[2], meta.color[3])
        label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        label:SetText(meta.label)

        y = y - 24
    end

    -------------------------------------------------------------------
    -- Channels
    -------------------------------------------------------------------
    y = y + SectionHeader(scrollChild, "Channel Scanning", y)

    y = y + MakeCheckbox(scrollChild, y, "Auto-detect Trade/Services channels",
        function() return cfg.autoWatch end,
        function(v) cfg.autoWatch = v end)

    y = y + MakeCheckbox(scrollChild, y, "Scan Say/Yell chat",
        function() return cfg.scanSayYell end,
        function(v) cfg.scanSayYell = v end)

    -- Manual channel IDs (1-8)
    local chLabel = NewText(scrollChild, 9, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    chLabel:SetPoint("TOPLEFT", 14, y)
    chLabel:SetText("Additional channel IDs:")
    y = y - 18

    for i = 1, 8 do
        local col = ((i - 1) % 4)
        local row = math.floor((i - 1) / 4)
        local xOff = 14 + col * 75

        local cb = CreateFrame("CheckButton", nil, scrollChild, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", xOff, y - row * 24)
        cb:SetSize(22, 22)
        cb:SetChecked(cfg.channelIDs[i] or false)
        cb:SetScript("OnClick", function(self)
            cfg.channelIDs[i] = self:GetChecked() and true or nil
        end)

        local label = NewText(scrollChild, 9, C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3])
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        label:SetText("Ch " .. i)
    end
    y = y - 52

    -------------------------------------------------------------------
    -- Misc
    -------------------------------------------------------------------
    y = y + SectionHeader(scrollChild, "Miscellaneous", y)

    y = y + MakeCheckbox(scrollChild, y, "Sound alert on new listing",
        function() return cfg.soundAlert end,
        function(v) cfg.soundAlert = v end)

    y = y + MakeCheckbox(scrollChild, y, "Chat alert on new listing",
        function() return cfg.chatAlert end,
        function(v) cfg.chatAlert = v end)

    y = y + MakeCheckbox(scrollChild, y, "Duplicate message suppression",
        function() return cfg.dupeSuppression end,
        function(v) cfg.dupeSuppression = v end)

    y = y + MakeCheckbox(scrollChild, y, "Show realm suffix on names",
        function() return cfg.showRealm end,
        function(v) cfg.showRealm = v end)

    y = y + MakeCheckbox(scrollChild, y, "Show minimap button",
        function() return cfg.minimapButton end,
        function(v)
            cfg.minimapButton = v
            if WTH.UpdateMinimapVisibility then WTH.UpdateMinimapVisibility() end
        end)

    -------------------------------------------------------------------
    -- Reset button
    -------------------------------------------------------------------
    y = y - 12
    local resetBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 24)
    resetBtn:SetPoint("TOPLEFT", 14, y)
    resetBtn:SetText("Reset Defaults")
    resetBtn:SetScript("OnClick", function()
        wipe(WTH.config)
        -- Re-apply defaults
        local defaults = {
            expirySecs = 180, cooldownSecs = 30, maxPerCategory = 50,
            dupeThreshold = 0.75, soundAlert = false, chatAlert = false,
            dupeSuppression = true, showRealm = false, scanSayYell = false,
            minimapButton = true, channelIDs = { [2] = true }, autoWatch = true,
            categoryVisible = {
                WTS = true, WTB = true, WTT = true, ENCHANT = true,
                CRAFT = true, TRAVEL = true, MISC = true,
            },
            windowWidth = 520, windowHeight = 420,
        }
        for k, v in pairs(defaults) do
            WTH.config[k] = v
        end
        -- Rebuild panel to reflect changes
        optPanel:Hide()
        optPanel = nil
        WTH.ToggleOptions()
    end)

    -- Set scroll child height
    scrollChild:SetHeight(math.abs(y) + 20)

    optPanel:Hide()
end

function WTH.ToggleOptions()
    if not optPanel then CreateOptionsPanel() end
    if optPanel:IsShown() then
        optPanel:Hide()
    else
        optPanel:Show()
    end
end
