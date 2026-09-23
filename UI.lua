-- Wick's Trade Hall
-- UI.lua: the session bar and the window behind it.
--
-- The bar is the piece meant to stay on screen: one row with what this
-- session has earned and what that is an hour. The window has the detail,
-- a tab per job, and is where the trade board will live.
--
-- Most of the chrome is WickCore's. On TBC this addon carried its own
-- panel, minimap button and options page, which is a thousand lines the
-- platform now provides.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore
local Chrome, R = Core.Chrome, Core.Restrict
local C = Chrome.Colors

local UI = {}
ns.UI = UI

-- Board.lua loads before this one, so the categories are here to build the
-- filter strip with rather than only inside Refresh.
local Bd = ns.Board

local BAR_H, BAR_W, PAD = 24, 190, 6
local ROW_H = 18

local FILL = "Interface\\BUTTONS\\WHITE8X8"
local STOP_RED = { 0.88, 0.29, 0.29, 1 }

local function tint(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

-- A colour table as the hex an escape code wants. %x needs whole
-- numbers and a palette is fractions, which threw the first time this
-- drew a category label.
local function hexOf(c)
    return ("%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5),
        math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function elapsedText(sec)
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dm"):format(m)
end

-- ============================================================
-- The bar
-- ============================================================

function UI:BuildBar()
    if self.bar then return self.bar end
    local db = ns.db and ns.db.profile

    local f = CreateFrame("Frame", "WicksTradeHallBar", UIParent)
    self.bar = f
    f:SetSize(BAR_W, BAR_H)
    f:SetPoint("CENTER", 0, 240)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s)
        -- A lock stops a nudge, not a deliberate move: shift overrides it.
        if Chrome:DragAllowed(db and db.barLocked) then s:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        if db then db.bar = db.bar or {}; Chrome:SavePosition(s, db.bar) end
    end)
    if db and db.bar and db.bar.point then Chrome:RestorePosition(f, db.bar) end

    local bg = Chrome:Texture(f, "BACKGROUND", C.voidBG); bg:SetAllPoints()
    Chrome:AddBorder(f)

    -- Start and stop, on the bar. Auto mode covers instance runs, but
    -- outside one there was no way to begin a session without the slash
    -- command, which makes a tracker you cannot start an ornament.
    local go = CreateFrame("Button", nil, f)
    go:SetSize(16, 16)
    go:SetPoint("LEFT", PAD, 0)
    -- Drawn, not typed. A play triangle and a stop square as text meant
    -- U+25B6 and U+25A0, and this client's font has neither, so the bar
    -- showed an empty box. These are built from a flat texture the client
    -- certainly has: the same one the health bar overlay in Comforts uses.
    go.rows = {}
    for i = 1, 8 do
        local t = go:CreateTexture(nil, "ARTWORK")
        t:SetTexture(FILL)
        t:SetHeight(2)
        t:SetPoint("LEFT", go, "LEFT", 3, 7 - (i - 1) * 2)
        go.rows[i] = t
    end

    -- A right-pointing triangle is rows that widen towards the middle; a
    -- square is rows of one width. The same eight textures do both.
    local TRIANGLE = { 2, 5, 8, 10, 10, 8, 5, 2 }
    function go:SetShape(playing, c)
        for i, t in ipairs(self.rows) do
            t:SetWidth(playing and 10 or TRIANGLE[i])
            t:SetColorTexture(c[1], c[2], c[3], 1)
        end
    end
    go:SetScript("OnClick", function()
        if ns.Ledger.active then ns.Ledger:Stop() else ns.Ledger:Start() end
        UI:RefreshBar()
    end)
    go:SetScript("OnEnter", function(s2)
        GameTooltip:SetOwner(s2, "ANCHOR_BOTTOM")
        GameTooltip:SetText(ns.Ledger.active and "Stop this session" or "Start a session", 1, 1, 1)
        if ns.Ledger.active then
            GameTooltip:AddLine("It is filed in history if it earned anything.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    go:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.go = go

    f.total = Chrome:Text(f, 12)
    f.total:SetPoint("LEFT", go, "RIGHT", 5, 0)
    f.total:SetJustifyH("LEFT")

    f.rate = Chrome:Text(f, 10, C.muted)
    f.rate:SetPoint("RIGHT", -PAD, 0)
    f.rate:SetJustifyH("RIGHT")

    f:SetScript("OnEnter", function(s)
        local Lg, P = ns.Ledger, ns.Prices
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Wick's Trade Hall", 1, 1, 1)
        if Lg.active or (Lg.totalCopper or 0) ~= 0 then
            GameTooltip:AddLine(("%s in %s"):format(Lg.active and "Running" or "Stopped",
                Lg.zoneName or "here"), 0.83, 0.78, 0.63)
            GameTooltip:AddLine(("Gold %s"):format(P:Format(Lg.goldDelta)), 1, 1, 1)
            local conf, known, total = P:Confidence(Lg.loot)
            if total > 0 then
                GameTooltip:AddLine(("Loot %d kinds, %d priced"):format(total, known), 1, 1, 1)
                if conf < 1 then
                    GameTooltip:AddLine("The rest could not be priced and count as nothing.",
                        0.85, 0.65, 0.25, true)
                end
            end
            if not Lg.maxLevel and (Lg.xpDelta or 0) > 0 then
                GameTooltip:AddLine(("Experience %d"):format(Lg.xpDelta), 0.6, 0.6, 0.6)
            end
        else
            GameTooltip:AddLine("No session. Click to open, /wth start to begin one.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:AddLine("Click: the window   Right-click: the trade board", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then UI:Toggle("board") else UI:Toggle("ledger") end
    end)

    -- The clock moves even when nothing is looted, so the rate has to be
    -- redrawn on its own. Once a second is plenty for a number in gold.
    f.elapsed = 0
    f:SetScript("OnUpdate", function(s, dt)
        s.elapsed = s.elapsed + dt
        if s.elapsed < 1 then return end
        s.elapsed = 0
        if ns.Ledger.active then UI:RefreshBar() end
    end)

    return f
end

function UI:RefreshBar()
    local f = self.bar
    if not f or not f:IsShown() then return end
    local Lg, P = ns.Ledger, ns.Prices
    if f.go then
        -- A square to stop it, a triangle to start it.
        f.go:SetShape(Lg.active, Lg.active and STOP_RED or C.fel)
    end
    if not Lg.active and (Lg.totalCopper or 0) == 0 then
        f.total:SetText("no session")
        tint(f.total, C.muted)
        f.rate:SetText("")
        return
    end
    f.total:SetText(P:Format(Lg.totalCopper))
    tint(f.total, (Lg.totalCopper or 0) < 0 and { 0.80, 0.30, 0.30, 1 } or C.text)
    f.rate:SetText(("%s/hr  %s"):format(P:FormatShort(Lg:PerHour()), elapsedText(Lg:Elapsed())))
    tint(f.rate, Lg.active and C.fel or C.muted)
end

function UI:ApplyBarVisibility()
    local db = ns.db and ns.db.profile
    if db and db.showBar ~= false then
        self:BuildBar()
        self.bar:Show()
        self:RefreshBar()
    elseif self.bar then
        self.bar:Hide()
    end
end

-- ============================================================
-- The window
-- ============================================================

function UI:Build()
    if self.panel then return self.panel end
    local db = ns.db and ns.db.profile

    local p = Chrome:NewPanel("WicksTradeHallPanel", {
        title = "Wick's Trade Hall", width = 440, height = 330, strata = "DIALOG",
        resizable = true, minWidth = 380, minHeight = 240, db = db and db.window,
    })
    self.panel = p

    p.tabs = {}
    local function tab(key, label, x)
        local b = Chrome:Button(p.content, label, 92)
        b:SetPoint("TOPLEFT", x, 0)
        b:SetScript("OnClick", function() UI:Select(key) end)
        p.tabs[key] = b
        return b
    end
    tab("ledger", "This session", 0)
    tab("board", "Trade board", 96)

    p.body = CreateFrame("Frame", nil, p.content)
    p.body:SetPoint("TOPLEFT", 0, -30)
    p.body:SetPoint("BOTTOMRIGHT", 0, 0)

    p.summary = Chrome:Text(p.body, 12)
    p.summary:SetPoint("TOPLEFT", 0, 0)
    p.summary:SetPoint("TOPRIGHT", 0, 0)
    p.summary:SetJustifyH("LEFT")

    p.detail = Chrome:Text(p.body, 11, C.muted)
    p.detail:SetPoint("TOPLEFT", 0, -20)
    p.detail:SetPoint("TOPRIGHT", 0, -20)
    p.detail:SetJustifyH("LEFT")

    -- The board's own strip: a button per category and a search box. Built
    -- with the panel and simply hidden on the ledger tab, so switching tabs
    -- costs nothing.
    p.filters = {}
    local fx = 0
    local function filterBtn(key, label, w)
        local b = Chrome:Button(p.body, label, w, 16)
        b:SetPoint("TOPLEFT", fx, -22)
        fx = fx + w + 3
        b:SetScript("OnClick", function()
            UI.boardCat = (key ~= "ALL") and key or nil
            UI:Refresh()
        end)
        p.filters[key] = b
        return b
    end
    filterBtn("ALL", "All", 30)
    for _, key in ipairs(Bd.ORDER) do
        filterBtn(key, (Bd.META[key] or {}).short or key, 38)
    end

    local search = CreateFrame("EditBox", nil, p.body)
    search:SetSize(110, 16)
    search:SetPoint("TOPRIGHT", 0, -22)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetTextInsets(4, 4, 0, 0)
    Chrome:Texture(search, "BACKGROUND", C.shadow):SetAllPoints()
    Chrome:AddBorder(search)
    search:SetScript("OnTextChanged", function(e) UI.boardSearch = e:GetText(); UI:Refresh() end)
    search:SetScript("OnEscapePressed", function(e) e:SetText(""); e:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(e) e:ClearFocus() end)
    p.search = search
    p.searchHint = Chrome:Text(search, 10, C.muted)
    p.searchHint:SetPoint("LEFT", 5, 0)
    p.searchHint:SetText("search")

    p.rows = {}
    p.note = Chrome:Text(p.body, 11, C.muted)
    p.note:SetPoint("BOTTOMLEFT", 0, 4)
    p.note:SetPoint("BOTTOMRIGHT", 0, 4)
    p.note:SetJustifyH("LEFT")
    p.note:SetWordWrap(true)

    p:SetScript("OnShow", function() UI:Refresh() end)
    return p
end

-- Older adverts fade. A board where everything shouts equally loudly is
-- the scroll it is meant to replace.
local function ageAlpha(seconds)
    if seconds < 120 then return 1 end
    if seconds > 900 then return 0.45 end
    return 1 - 0.55 * ((seconds - 120) / 780)
end

local BOARD_ROW_H = 26

local function boardRow(p, i)
    p.brows = p.brows or {}
    local r = p.brows[i]
    if r then return r end
    r = CreateFrame("Button", nil, p.body)
    r:SetHeight(BOARD_ROW_H)
    r:SetPoint("TOPLEFT", 0, -44 - (i - 1) * BOARD_ROW_H)
    r:SetPoint("TOPRIGHT", 0, -44 - (i - 1) * BOARD_ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    r.stripe = Chrome:Texture(r, "BACKGROUND", C.shadow)
    r.stripe:SetAllPoints()
    r.stripe:SetAlpha(0.35)
    r.hl = Chrome:Texture(r, "HIGHLIGHT", C.border)
    r.hl:SetAllPoints()
    r.hl:SetAlpha(0.25)

    -- Category badge: a tinted box, the way the TBC board had it, so the
    -- kind of advert reads before the words do.
    r.badge = CreateFrame("Frame", nil, r)
    r.badge:SetSize(40, 14)
    r.badge:SetPoint("LEFT", 2, 0)
    r.badgeBg = Chrome:Texture(r.badge, "BACKGROUND")
    r.badgeBg:SetAllPoints()
    r.badgeText = Chrome:Text(r.badge, 9)
    r.badgeText:SetPoint("CENTER")

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 46, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.age = Chrome:Text(r, 10, C.muted)
    r.age:SetPoint("TOPRIGHT", -2, -3)
    r.age:SetJustifyH("RIGHT")
    r.age:SetWidth(34)

    r.who = Chrome:Text(r, 11, C.fel)
    r.who:SetPoint("TOPLEFT", 66, -2)
    r.who:SetJustifyH("LEFT")
    r.who:SetWordWrap(false)
    r.who:SetPoint("RIGHT", r.age, "LEFT", -4, 0)

    r.msg = Chrome:Text(r, 10, C.muted)
    r.msg:SetPoint("TOPLEFT", 66, -13)
    r.msg:SetPoint("RIGHT", -2, 0)
    r.msg:SetJustifyH("LEFT")
    r.msg:SetWordWrap(false)
    if r.msg.SetMaxLines then r.msg:SetMaxLines(1) end

    r:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) then
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.link)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)

    r:SetScript("OnClick", function(self, button)
        -- Shift to put the item in chat, right-click to open a whisper.
        -- Neither sends anything: posting is restricted on this client, so
        -- the most it does is fill the box and leave it to the player.
        if IsShiftKeyDown and IsShiftKeyDown() and self.link and ChatEdit_InsertLink then
            ChatEdit_InsertLink(self.link)
            return
        end
        if button == "RightButton" and self.who_full and ChatFrame_OpenChat then
            ChatFrame_OpenChat("/w " .. self.who_full .. " ")
        end
    end)

    p.brows[i] = r
    return r
end

local function row(p, i)
    local r = p.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, p.body)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -44 - (i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", 0, -44 - (i - 1) * ROW_H)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetPoint("LEFT")
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.right = Chrome:Text(r, 11, C.muted)
    r.right:SetPoint("RIGHT")
    r.right:SetWidth(42)
    r.right:SetJustifyH("RIGHT")
    r.left = Chrome:Text(r, 11)
    r.left:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    -- Bounded on the right, or a long trade advert runs off the panel and
    -- over whatever is behind it. One line, cut where the age begins.
    r.left:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
    r.left:SetJustifyH("LEFT")
    r.left:SetWordWrap(false)
    if r.left.SetMaxLines then r.left:SetMaxLines(1) end
    p.rows[i] = r
    return r
end

function UI:Select(key)
    self:Build()
    self.tab = key or "ledger"
    self:Refresh()
end

function UI:Refresh()
    self:RefreshBar()
    local p = self.panel
    if not p or not p:IsShown() then return end
    local Lg, P = ns.Ledger, ns.Prices

    for _, r in ipairs(p.rows) do
        r:Hide()
        r.icon:SetWidth(14)
    end

    if self.tab == "board" then
        -- The strip belongs to this tab only.
        for _, b in pairs(p.filters) do b:Show() end
        p.search:Show()
        p.searchHint:SetShown((p.search:GetText() or "") == "")
        p.summary:SetText("Trade board")
        tint(p.summary, C.text)
        p.detail:SetText("")

        local now = time()
        local list = Bd:Filter(self.boardCat, self.boardSearch)

        -- Mark which filter is on, so the board says what it is showing.
        for key, b in pairs(p.filters) do
            local on = (key == "ALL" and self.boardCat == nil) or key == self.boardCat
            if b.SetAlpha then b:SetAlpha(on and 1 or 0.55) end
        end

        for _, r in ipairs(p.rows) do r:Hide() end
        for _, r in ipairs(p.brows or {}) do r:Hide() end

        local room = math.max(1, math.floor(((tonumber(p.body:GetHeight()) or 200) - 66) / BOARD_ROW_H))
        for i = 1, math.min(#list, room) do
            local l = list[i]
            local r = boardRow(p, i)
            local m = Bd.META[l.category] or Bd.META.MISC
            local c = m.color

            r.badgeBg:SetColorTexture(c[1], c[2], c[3], 0.18)
            r.badgeText:SetText(m.short)
            r.badgeText:SetTextColor(c[1], c[2], c[3], 1)

            local link, _, icon = Bd:FirstItem(l.raw)
            r.link = link
            if icon then
                r.icon:SetTexture(icon)
                r.icon:Show()
                r.who:SetPoint("TOPLEFT", 66, -2)
                r.msg:SetPoint("TOPLEFT", 66, -13)
            else
                r.icon:Hide()
                r.who:SetPoint("TOPLEFT", 48, -2)
                r.msg:SetPoint("TOPLEFT", 48, -13)
            end

            r.who:SetText(l.name or "?")
            r.who_full = l.fullName or l.name
            r.msg:SetText(l.message or "")

            local age = now - (l.lastSeen or now)
            local mins = math.floor(age / 60)
            r.age:SetText(mins < 1 and "now" or (mins .. "m"))
            r:SetAlpha(ageAlpha(age))
            r.stripe:SetShown(i % 2 == 0)
            r:Show()
        end

        local shown = math.min(#list, room)
        if #Bd.listings == 0 then
            p.note:SetText("Nothing yet. The board fills from the trade channels you are in.")
        elseif #list == 0 then
            p.note:SetText("Nothing matches. Clear the search or pick All.")
        else
            p.note:SetText(("%d of %d listing%s%s. Right-click to whisper, shift-click to link. Anything unrepeated for twenty minutes drops off."):format(
                shown, #Bd.listings, #Bd.listings == 1 and "" or "s",
                shown < #list and (", " .. (#list - shown) .. " more below") or ""))
        end
        return
    end

    -- The ledger tab has no use for the board's strip.
    for _, b in pairs(p.filters) do b:Hide() end
    p.search:Hide()
    p.searchHint:Hide()

    if not Lg.active and (Lg.totalCopper or 0) == 0 then
        p.summary:SetText("No session")
        tint(p.summary, C.muted)
        p.detail:SetText("")
        local h = Lg:History()
        if #h > 0 then
            for i, e in ipairs(h) do
                local r = row(p, i)
                r.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
                r.left:SetText(("%s  %s"):format(e.zoneName or "?", elapsedText(e.elapsed or 0)))
                r.right:SetText(P:Format(e.totalCopper))
                r:Show()
            end
            p.note:SetText("The last sessions that earned something. /wth start begins another.")
        else
            p.note:SetText("Nothing yet. /wth start, or let it start itself when you enter an instance.")
        end
        return
    end

    p.summary:SetText(("%s  %s/hr"):format(P:Format(Lg.totalCopper), P:FormatShort(Lg:PerHour())))
    tint(p.summary, C.text)
    p.detail:SetText(("%s in %s, %s elapsed"):format(Lg.active and "Running" or "Stopped",
        Lg.zoneName or "here", elapsedText(Lg:Elapsed())))

    local i = 1
    local r = row(p, i); i = i + 1
    r.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    r.left:SetText("Gold")
    r.right:SetText(P:Format(Lg.goldDelta))
    r:Show()

    -- Biggest first: the line that explains the total should be at the top.
    local items = {}
    for key, e in pairs(Lg.loot) do
        items[#items + 1] = { key = key, e = e, worth = e.isJunk and e.copper or (e.copper * (e.count or 1)) }
    end
    table.sort(items, function(a, b) return a.worth > b.worth end)

    for _, it in ipairs(items) do
        if i > 12 then break end
        local e = it.e
        local rr = row(p, i); i = i + 1
        rr.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local name = e.isJunk and ("Junk x%d"):format(e.count)
            or ((e.link and e.link:match("%[(.-)%]")) or ("item " .. tostring(e.itemID)))
                .. (e.count > 1 and (" x" .. e.count) or "")
        rr.left:SetText(name)
        tint(rr.left, e.source == "unknown" and C.muted or C.text)
        rr.right:SetText(e.source == "unknown" and "not priced" or P:Format(it.worth))
        rr:Show()
    end

    local conf, known, total = P:Confidence(Lg.loot)
    if total > 0 and conf < 1 then
        p.note:SetText(("%d of %d kinds could not be priced, so they count as nothing. This client will not price an item the character has never seen."):format(total - known, total))
    elseif not Lg.maxLevel and (Lg.xpDelta or 0) > 0 then
        p.note:SetText(("Experience this session: %d"):format(Lg.xpDelta))
    else
        p.note:SetText("")
    end
end

function UI:Toggle(which)
    self:Build()
    if which and self.panel:IsShown() and self.tab ~= which then
        self:Select(which)
        return
    end
    if self.panel:IsShown() then self.panel:Hide() else self:Select(which or self.tab or "ledger"); self.panel:Show() end
end

function UI:Init()
    self.tab = "ledger"
    self:ApplyBarVisibility()
end
