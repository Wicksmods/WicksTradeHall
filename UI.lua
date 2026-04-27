-- Wick's Trade Hall - UI
-- Main bulletin board display with themed styling

local WTH = _G.WTH
local Cat = WTH.Categories

---------------------------------------------------------------------------
-- Theme colors
---------------------------------------------------------------------------
-- Wick brand palette (locked) — see memory/reference_wick_brand_style.md
-- Fel #4FC778 · Void #0D0A14 · Shadow #171124 · Border #383058 · Text #D4C8A1
local C_BG          = { 0.051, 0.039, 0.078, 0.97 }
local C_HEADER_BG   = { 0.090, 0.067, 0.141, 1 }
local C_ALT_ROW_BG  = { 0.12, 0.10, 0.20, 0.6 }
local C_BUTTON_BG   = { 0.07, 0.06, 0.12, 1 }
local C_BUTTON_ACTIVE = { 0.10, 0.22, 0.15, 1 }
local C_BORDER      = { 0.220, 0.188, 0.345, 1 }
local C_BORDER_DIM  = { 0.16, 0.12, 0.28, 1 }
local C_GREEN       = { 0.310, 0.780, 0.471, 1 }
local C_TEXT_DIM    = { 0.42, 0.35, 0.54, 1 }
local C_TEXT_NORMAL = { 0.831, 0.784, 0.631, 1 }
local C_ROW_HOVER   = { 0.310, 0.780, 0.471, 0.06 }

local FONT = "Fonts\\FRIZQT__.TTF"
local ROW_HEIGHT = 36
local VISIBLE_ROWS = 10
local HEADER_H = 22
local MIN_WIDTH, MIN_HEIGHT = 440, 300
local MAX_WIDTH, MAX_HEIGHT = 800, 700

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

local function AddCornerAccents(frame, size, r, g, b, a)
    size = size or 10
    r, g, b, a = r or C_GREEN[1], g or C_GREEN[2], b or C_GREEN[3], a or C_GREEN[4]
    local corners = {
        "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
    }
    for _, point in ipairs(corners) do
        local h = NewTexture(frame, "OVERLAY"); h:SetColorTexture(r,g,b,a)
        h:SetPoint(point, frame, point, 0, 0)
        h:SetSize(size, 2)
        local v = NewTexture(frame, "OVERLAY"); v:SetColorTexture(r,g,b,a)
        v:SetPoint(point, frame, point, 0, 0)
        v:SetSize(2, size)
    end
end

---------------------------------------------------------------------------
-- Age-based color fading: white -> yellow -> grey
---------------------------------------------------------------------------
local function AgeColor(listing)
    local age = time() - listing.lastSeen
    local expiry = WTH.config.expirySecs
    local pct = age / expiry -- 0 = fresh, 1 = about to expire

    if pct < 0.33 then
        return 1, 1, 1 -- white
    elseif pct < 0.66 then
        local t = (pct - 0.33) / 0.33
        return 1, 1, 1 - t * 0.6 -- white -> yellow
    else
        local t = (pct - 0.66) / 0.34
        return 1 - t * 0.4, 1 - t * 0.4, 0.4 - t * 0.1 -- yellow -> grey
    end
end

---------------------------------------------------------------------------
-- Extract item links from raw message for tooltips
---------------------------------------------------------------------------
local function ExtractItemLinks(rawText)
    if not rawText then return {} end
    local links = {}
    for link in rawText:gmatch("|c%x+|H(item:[%d:%-]+)|h%[([^%]]+)%]|h|r") do
        table.insert(links, link)
    end
    return links
end

---------------------------------------------------------------------------
-- Item icon extraction from raw message
---------------------------------------------------------------------------
local function GetFirstItemInfo(rawText)
    if not rawText then return nil, nil end
    local itemLink = rawText:match("|c%x+|H(item:[%d:%-]+)|h%[([^%]]+)%]|h|r")
    if itemLink then
        if GetItemInfoInstant then
            local _, _, _, _, icon = GetItemInfoInstant(itemLink)
            return itemLink, icon
        else
            local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemLink)
            return itemLink, icon
        end
    end
    return nil, nil
end

---------------------------------------------------------------------------
-- Row creation (file-scoped so RefreshUI can call it)
---------------------------------------------------------------------------
local panel, rows, scrollOffset, searchText, activeFilter

local function CreateRow(index)
    local content = panel.content
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 2, -2 - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -2, 0)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Background (alternating)
    local rowBG = NewTexture(row, "BACKGROUND")
    rowBG:SetAllPoints()
    if index % 2 == 0 then
        rowBG:SetColorTexture(C_ALT_ROW_BG[1], C_ALT_ROW_BG[2], C_ALT_ROW_BG[3], C_ALT_ROW_BG[4])
    else
        rowBG:SetColorTexture(0, 0, 0, 0)
    end
    row._bgTex = rowBG
    row._isEven = (index % 2 == 0)

    -- Hover overlay
    local hover = NewTexture(row, "HIGHLIGHT", C_ROW_HOVER)
    hover:SetAllPoints()

    -- Separator
    local rowSep = NewTexture(row, "ARTWORK", { C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.25 })
    rowSep:SetPoint("BOTTOMLEFT", 10, 0)
    rowSep:SetPoint("BOTTOMRIGHT", -10, 0)
    rowSep:SetHeight(1)

    -- Category badge
    local badge = CreateFrame("Frame", nil, row)
    badge:SetSize(38, 14)
    badge:SetPoint("LEFT", 6, 0)
    local badgeBG = NewTexture(badge, "BACKGROUND")
    badgeBG:SetAllPoints()
    local badgeBorder = AddBorder(badge)
    local badgeLabel = badge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    badgeLabel:SetFont(FONT, 10, "OUTLINE")
    badgeLabel:SetPoint("CENTER")
    row._badge = badge
    row._badgeBG = badgeBG
    row._badgeBorder = badgeBorder
    row._badgeLabel = badgeLabel

    -- Item icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", badge, "RIGHT", 6, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row._icon = icon

    local iconBorder = CreateFrame("Frame", nil, row)
    iconBorder:SetPoint("TOPLEFT", icon, -1, 1)
    iconBorder:SetPoint("BOTTOMRIGHT", icon, 1, -1)
    AddBorder(iconBorder, C_BORDER[1], C_BORDER[2], C_BORDER[3])
    row._iconBorder = iconBorder

    -- Player name
    local nameText = NewText(row, 10, C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3])
    nameText:SetPoint("LEFT", icon, "RIGHT", 6, 6)
    nameText:SetWidth(100)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row._nameText = nameText

    -- Message text
    local msgText = NewText(row, 10, 1, 1, 1)
    msgText:SetPoint("LEFT", icon, "RIGHT", 6, -6)
    msgText:SetPoint("RIGHT", -60, -6)
    msgText:SetJustifyH("LEFT")
    msgText:SetWordWrap(false)
    row._msgText = msgText

    -- Age text
    local ageText = NewText(row, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    ageText:SetPoint("RIGHT", -8, 0)
    ageText:SetJustifyH("RIGHT")
    row._ageText = ageText

    -- Tooltip on hover for item links
    row:SetScript("OnEnter", function(self)
        if self._rawMessage then
            local itemLink = self._rawMessage:match("|c%x+|H(item:[%d:%-]+)|h%[([^%]]+)%]|h|r")
            if itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemLink)
                GameTooltip:Show()
            end
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Click to inspect item / whisper player
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" and self._rawMessage then
            local itemLink = self._rawMessage:match("(|c%x+|Hitem:[%d:%-]+|h%[[^%]]+%]|h|r)")
            if itemLink and IsShiftKeyDown() then
                if ChatFrame1EditBox:IsShown() then
                    ChatFrame1EditBox:Insert(itemLink)
                end
            elseif itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(itemLink:match("|H(item:[%d:%-]+)|h"))
                GameTooltip:Show()
            end
        elseif button == "RightButton" and self._fullName then
            ChatFrame_OpenChat("/w " .. self._fullName .. " ")
        end
    end)

    row:Hide()
    return row
end

---------------------------------------------------------------------------
-- Main panel
---------------------------------------------------------------------------

local function CreatePanel()
    panel = CreateFrame("Frame", "WicksTradeHallFrame", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetResizable(true)
    panel:EnableMouse(true)

    -- Size bounds (TBC compat)
    if panel.SetResizeBounds then
        panel:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
    else
        panel:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
        panel:SetMaxResize(MAX_WIDTH, MAX_HEIGHT)
    end

    -- Restore position/size
    local cfg = WTH.config
    local w = cfg.windowWidth or 520
    local h = cfg.windowHeight or 420
    panel:SetSize(w, h)

    if cfg.windowPoint then
        panel:SetPoint(
            cfg.windowPoint.point,
            UIParent,
            cfg.windowPoint.relPoint,
            cfg.windowPoint.x,
            cfg.windowPoint.y
        )
    else
        panel:SetPoint("CENTER")
    end

    -- Background
    local bg = NewTexture(panel, "BACKGROUND", C_BG)
    bg:SetAllPoints()

    -- Border + corner accents
    AddBorder(panel)
    AddCornerAccents(panel, 12)

    -- Dragging
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        WTH.config.windowPoint = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -------------------------------------------------------------------
    -- Header (slim, plain texture on main frame)
    -------------------------------------------------------------------
    local headerBG = NewTexture(panel, "BACKGROUND", C_HEADER_BG)
    headerBG:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -1)
    headerBG:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -1)
    headerBG:SetHeight(HEADER_H)

    -- 1px separator below the header
    local headerSep = NewTexture(panel, "BORDER", C_BORDER)
    headerSep:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -HEADER_H - 1)
    headerSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -HEADER_H - 1)
    headerSep:SetHeight(1)

    -- Title — slim font, two-tone color preserved
    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 12, "")
    title:SetText("|cff4FC778Wick's|r |cffD4C8A1Trade Hall|r")
    title:SetPoint("LEFT", panel, "TOPLEFT", 10, -HEADER_H / 2)

    -- Close (×) button — plain text, no border
    local closeBtn = CreateFrame("Button", nil, panel)
    closeBtn:SetSize(HEADER_H - 4, HEADER_H - 4)
    closeBtn:SetPoint("RIGHT", panel, "TOPRIGHT", -4, -HEADER_H / 2)

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont(FONT, 14, "")
    closeText:SetText("×")
    closeText:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    closeText:SetAllPoints()
    closeText:SetJustifyH("CENTER")
    closeText:SetJustifyV("MIDDLE")
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3], 1) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1) end)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Listing count (sits left of the close button)
    local countText = NewText(panel, 9, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    countText:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    panel.countText = countText

    -------------------------------------------------------------------
    -- Filter bar (category toggles)
    -------------------------------------------------------------------
    local filterBar = CreateFrame("Frame", nil, panel)
    filterBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -HEADER_H - 2)
    filterBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -HEADER_H - 2)
    filterBar:SetHeight(28)

    local filterBG = NewTexture(filterBar, "BACKGROUND", { 0.06, 0.05, 0.10, 1 })
    filterBG:SetAllPoints()

    local filterBtns = {}
    local xOff = 8
    -- "All" button first
    local allBtn = CreateFrame("Button", nil, filterBar)
    allBtn:SetSize(32, 20)
    allBtn:SetPoint("LEFT", xOff, 0)
    local allBG = NewTexture(allBtn, "BACKGROUND", C_BUTTON_ACTIVE)
    allBG:SetAllPoints()
    AddBorder(allBtn, C_GREEN[1], C_GREEN[2], C_GREEN[3])
    local allLabel = NewText(allBtn, 8, C_GREEN[1], C_GREEN[2], C_GREEN[3])
    allLabel:SetFont(FONT, 10, "OUTLINE")
    allLabel:SetText("ALL")
    allLabel:SetPoint("CENTER")
    allBtn._active = true
    allBtn._bg = allBG
    allBtn._label = allLabel
    xOff = xOff + 36

    for _, catKey in ipairs(Cat.ORDER) do
        local meta = Cat.META[catKey]
        local btn = CreateFrame("Button", nil, filterBar)
        btn:SetSize(38, 20)
        btn:SetPoint("LEFT", xOff, 0)

        local btnBG = NewTexture(btn, "BACKGROUND", C_BUTTON_BG)
        btnBG:SetAllPoints()
        local borders = AddBorder(btn, C_BORDER_DIM[1], C_BORDER_DIM[2], C_BORDER_DIM[3])

        local label = NewText(btn, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
        label:SetFont(FONT, 10, "OUTLINE")
        label:SetText(meta.shortLabel)
        label:SetPoint("CENTER")

        btn._catKey = catKey
        btn._bg = btnBG
        btn._borders = borders
        btn._label = label
        btn._active = false

        btn:SetScript("OnClick", function(self)
            if activeFilter == catKey then
                -- Deactivate: show all
                activeFilter = nil
                self._active = false
                self._bg:SetColorTexture(unpack(C_BUTTON_BG))
                for _, b in ipairs(self._borders) do
                    b:SetColorTexture(C_BORDER_DIM[1], C_BORDER_DIM[2], C_BORDER_DIM[3], 1)
                end
                self._label:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
                -- Re-activate "All"
                allBtn._active = true
                allBtn._bg:SetColorTexture(unpack(C_BUTTON_ACTIVE))
                allBtn._label:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3])
            else
                -- Activate this category
                activeFilter = catKey
                -- Reset all buttons
                allBtn._active = false
                allBtn._bg:SetColorTexture(unpack(C_BUTTON_BG))
                allBtn._label:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
                for _, ob in ipairs(filterBtns) do
                    ob._active = false
                    ob._bg:SetColorTexture(unpack(C_BUTTON_BG))
                    for _, b in ipairs(ob._borders) do
                        b:SetColorTexture(C_BORDER_DIM[1], C_BORDER_DIM[2], C_BORDER_DIM[3], 1)
                    end
                    ob._label:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
                end
                -- Highlight selected
                self._active = true
                local c = meta.color
                self._bg:SetColorTexture(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 1)
                for _, b in ipairs(self._borders) do
                    b:SetColorTexture(c[1], c[2], c[3], 1)
                end
                self._label:SetTextColor(c[1], c[2], c[3])
            end
            scrollOffset = 0
            WTH.RefreshUI()
        end)

        btn:SetScript("OnEnter", function(self)
            if not self._active then
                local c = Cat.META[self._catKey].color
                for _, b in ipairs(self._borders) do
                    b:SetColorTexture(c[1], c[2], c[3], 0.6)
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self._active then
                for _, b in ipairs(self._borders) do
                    b:SetColorTexture(C_BORDER_DIM[1], C_BORDER_DIM[2], C_BORDER_DIM[3], 1)
                end
            end
        end)

        table.insert(filterBtns, btn)
        xOff = xOff + 42
    end

    -- "All" button click
    allBtn:SetScript("OnClick", function()
        activeFilter = nil
        allBtn._active = true
        allBtn._bg:SetColorTexture(unpack(C_BUTTON_ACTIVE))
        allBtn._label:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3])
        for _, ob in ipairs(filterBtns) do
            ob._active = false
            ob._bg:SetColorTexture(unpack(C_BUTTON_BG))
            for _, b in ipairs(ob._borders) do
                b:SetColorTexture(C_BORDER_DIM[1], C_BORDER_DIM[2], C_BORDER_DIM[3], 1)
            end
            ob._label:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
        end
        scrollOffset = 0
        WTH.RefreshUI()
    end)

    -------------------------------------------------------------------
    -- Search bar
    -------------------------------------------------------------------
    local searchBar = CreateFrame("Frame", nil, panel)
    searchBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 8, -4)
    searchBar:SetPoint("TOPRIGHT", filterBar, "BOTTOMRIGHT", -8, -4)
    searchBar:SetHeight(22)

    local searchBG = NewTexture(searchBar, "BACKGROUND", C_BUTTON_BG)
    searchBG:SetAllPoints()
    AddBorder(searchBar)

    local searchIcon = NewText(searchBar, 9, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    searchIcon:SetFont(FONT, 11, "OUTLINE")
    searchIcon:SetText("Search:")
    searchIcon:SetPoint("LEFT", 6, 0)

    local searchBox = CreateFrame("EditBox", nil, searchBar)
    searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 4, 0)
    searchBox:SetPoint("RIGHT", -6, 0)
    searchBox:SetHeight(18)
    searchBox:SetFont(FONT, 12, "")
    searchBox:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3])
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText():lower()
        if searchText == "" then searchText = nil end
        scrollOffset = 0
        WTH.RefreshUI()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -------------------------------------------------------------------
    -- Content area (listing rows)
    -------------------------------------------------------------------
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", searchBar, "BOTTOMLEFT", -8, -4)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 24)
    panel.content = content

    -- Separator under search
    local sep = NewTexture(content, "ARTWORK", { C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.4 })
    sep:SetPoint("TOPLEFT", 10, 0)
    sep:SetPoint("TOPRIGHT", -10, 0)
    sep:SetHeight(1)

    rows = {}

    -------------------------------------------------------------------
    -- Scroll handling
    -------------------------------------------------------------------
    scrollOffset = 0

    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", function(self, delta)
        scrollOffset = scrollOffset - delta
        if scrollOffset < 0 then scrollOffset = 0 end
        WTH.RefreshUI()
    end)

    -------------------------------------------------------------------
    -- Status bar
    -------------------------------------------------------------------
    local statusBar = CreateFrame("Frame", nil, panel)
    statusBar:SetPoint("BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", 0, 0)
    statusBar:SetHeight(22)

    local statusBG = NewTexture(statusBar, "BACKGROUND", { 0, 0, 0, 0.2 })
    statusBG:SetAllPoints()
    local statusBorder = NewTexture(statusBar, "ARTWORK", { C_BORDER[1], C_BORDER[2], C_BORDER[3], 0.4 })
    statusBorder:SetPoint("TOPLEFT"); statusBorder:SetPoint("TOPRIGHT"); statusBorder:SetHeight(1)

    local statusText = NewText(statusBar, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    statusText:SetPoint("LEFT", 10, 0)
    panel.statusText = statusText

    -- Options button in status bar
    local optBtn = CreateFrame("Button", nil, statusBar)
    optBtn:SetSize(50, 16)
    optBtn:SetPoint("RIGHT", -8, 0)
    local optBG = NewTexture(optBtn, "BACKGROUND", C_BUTTON_BG)
    optBG:SetAllPoints()
    AddBorder(optBtn)
    local optLabel = NewText(optBtn, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    optLabel:SetFont(FONT, 10, "OUTLINE")
    optLabel:SetText("Options")
    optLabel:SetPoint("CENTER")
    optBtn:SetScript("OnClick", function()
        if WTH.ToggleOptions then WTH.ToggleOptions() end
    end)
    optBtn:SetScript("OnEnter", function() optLabel:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3]) end)
    optBtn:SetScript("OnLeave", function() optLabel:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3]) end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, statusBar)
    clearBtn:SetSize(40, 16)
    clearBtn:SetPoint("RIGHT", optBtn, "LEFT", -4, 0)
    local clearBG = NewTexture(clearBtn, "BACKGROUND", C_BUTTON_BG)
    clearBG:SetAllPoints()
    AddBorder(clearBtn)
    local clearLabel = NewText(clearBtn, 8, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    clearLabel:SetFont(FONT, 10, "OUTLINE")
    clearLabel:SetText("Clear")
    clearLabel:SetPoint("CENTER")
    clearBtn:SetScript("OnClick", function() WTH.ClearAll() end)
    clearBtn:SetScript("OnEnter", function() clearLabel:SetTextColor(1, 0.3, 0.3) end)
    clearBtn:SetScript("OnLeave", function() clearLabel:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3]) end)

    -------------------------------------------------------------------
    -- Resize grip
    -------------------------------------------------------------------
    local grip = CreateFrame("Frame", nil, panel)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:EnableMouse(true)

    local gripTex = NewText(grip, 10, C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    gripTex:SetFont(FONT, 12, "OUTLINE")
    gripTex:SetText("//")
    gripTex:SetPoint("BOTTOMRIGHT", -2, 2)

    grip:SetScript("OnMouseDown", function()
        panel:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        panel:StopMovingOrSizing()
        WTH.config.windowWidth = panel:GetWidth()
        WTH.config.windowHeight = panel:GetHeight()
        WTH.RefreshUI()
    end)
    grip:SetScript("OnEnter", function()
        gripTex:SetTextColor(C_GREEN[1], C_GREEN[2], C_GREEN[3])
    end)
    grip:SetScript("OnLeave", function()
        gripTex:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3])
    end)

    panel:Hide()
    return panel
end

---------------------------------------------------------------------------
-- Get filtered listings
---------------------------------------------------------------------------
local function GetFilteredListings()
    local result = {}
    for _, listing in ipairs(WTH.listings) do
        local show = true
        -- Category filter
        if activeFilter and listing.category ~= activeFilter then
            show = false
        end
        -- Search filter
        if show and searchText then
            local msg = listing.message:lower()
            local name = listing.name:lower()
            if not msg:find(searchText, 1, true) and not name:find(searchText, 1, true) then
                show = false
            end
        end
        if show then
            table.insert(result, listing)
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Refresh UI
---------------------------------------------------------------------------
function WTH.RefreshUI()
    if not panel or not panel:IsShown() then return end

    local filtered = GetFilteredListings()
    local totalFiltered = #filtered
    local totalAll = #WTH.listings

    -- Clamp scroll
    local contentH = panel.content:GetHeight()
    local maxRows = math.floor(contentH / ROW_HEIGHT)
    local maxOffset = math.max(0, totalFiltered - maxRows)
    if scrollOffset > maxOffset then scrollOffset = maxOffset end

    -- Ensure enough row frames
    while #rows < maxRows do
        table.insert(rows, CreateRow(#rows + 1))
    end

    -- Populate rows
    for i = 1, #rows do
        local row = rows[i]
        local idx = scrollOffset + i
        local listing = filtered[idx]

        if listing and i <= maxRows then
            local meta = Cat.META[listing.category]

            -- Badge
            local c = meta.color
            row._badgeBG:SetColorTexture(c[1], c[2], c[3], 0.15)
            for _, b in ipairs(row._badgeBorder) do
                b:SetColorTexture(c[1], c[2], c[3], 0.3)
            end
            row._badgeLabel:SetTextColor(c[1], c[2], c[3])
            row._badgeLabel:SetText(meta.shortLabel)

            -- Icon
            local itemLink, icon = GetFirstItemInfo(listing.rawMessage)
            if icon then
                row._icon:SetTexture(icon)
                row._icon:Show()
                row._iconBorder:Show()
            else
                row._icon:Hide()
                row._iconBorder:Hide()
            end

            -- Name
            local displayName = WTH.config.showRealm and listing.fullName or listing.name
            row._nameText:SetText(displayName)
            row._nameText:SetTextColor(c[1], c[2], c[3])

            -- Message with age fading
            local ar, ag, ab = AgeColor(listing)
            row._msgText:SetText(listing.message)
            row._msgText:SetTextColor(ar, ag, ab)

            -- Age
            local age = time() - listing.lastSeen
            row._ageText:SetText(WTH.FormatAge(age))

            -- Store data for clicks
            row._rawMessage = listing.rawMessage
            row._fullName = listing.fullName

            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", -2, 0)
            row:Show()
        else
            row:Hide()
        end
    end

    -- Count text
    if activeFilter or searchText then
        panel.countText:SetText(totalFiltered .. "/" .. totalAll .. " listings")
    else
        panel.countText:SetText(totalAll .. " listings")
    end

    -- Status
    panel.statusText:SetText("/wth | Right-click to whisper | Shift-click to link")
end

---------------------------------------------------------------------------
-- Toggle
---------------------------------------------------------------------------
function WTH.ToggleUI()
    if not panel then CreatePanel() end
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
        WTH.RefreshUI()
    end
end

-- Periodic refresh while shown
local refreshFrame = CreateFrame("Frame")
local refreshElapsed = 0
refreshFrame:SetScript("OnUpdate", function(self, dt)
    refreshElapsed = refreshElapsed + dt
    if refreshElapsed >= 1 then
        refreshElapsed = 0
        if panel and panel:IsShown() then
            WTH.RefreshUI()
        end
    end
end)
