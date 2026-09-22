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
local Core = WickCore
local Chrome, R = Core.Chrome, Core.Restrict
local C = Chrome.Colors

local UI = {}
ns.UI = UI

local BAR_H, BAR_W, PAD = 24, 190, 6
local ROW_H = 18

local function tint(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

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
    go.glyph = Chrome:Text(go, 12)
    go.glyph:SetPoint("CENTER")
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
        -- A filled square to stop, an arrow to start.
        f.go.glyph:SetText(Lg.active and "|cffE04B4B\226\150\160|r" or "|cff4FC778\226\150\182|r")
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

    p.rows = {}
    p.note = Chrome:Text(p.body, 11, C.muted)
    p.note:SetPoint("BOTTOMLEFT", 0, 4)
    p.note:SetPoint("BOTTOMRIGHT", 0, 4)
    p.note:SetJustifyH("LEFT")
    p.note:SetWordWrap(true)

    p:SetScript("OnShow", function() UI:Refresh() end)
    return p
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
    r.left = Chrome:Text(r, 11)
    r.left:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
    r.left:SetJustifyH("LEFT")
    r.right = Chrome:Text(r, 11, C.muted)
    r.right:SetPoint("RIGHT")
    r.right:SetJustifyH("RIGHT")
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

    for _, r in ipairs(p.rows) do r:Hide() end

    if self.tab == "board" then
        local Bd = ns.Board
        local counts = Bd:Counts()
        local parts = {}
        for _, cat in ipairs(Bd.ORDER) do
            local n = counts[cat] or 0
            if n > 0 then
                local m = Bd.META[cat]
                parts[#parts + 1] = ("|cff%02x%02x%02x%s %d|r"):format(
                    m.color[1] * 255, m.color[2] * 255, m.color[3] * 255, m.short, n)
            end
        end
        p.summary:SetText("Trade board")
        tint(p.summary, C.text)
        p.detail:SetText(#parts > 0 and table.concat(parts, "   ") or "")

        local list = Bd:Get(self.boardCat)
        if #list == 0 then
            local chans = 0
            for id in pairs(Bd:Channels()) do if Bd:Watching(id) then chans = chans + 1 end end
            p.note:SetText(chans > 0
                and ("Watching %d channel%s. Nothing has come through yet."):format(chans, chans == 1 and "" or "s")
                or "No trade channel found. Join one and it will be picked up.")
            return
        end
        local now = time()
        for i, l in ipairs(list) do
            if i > 12 then break end
            local r = row(p, i)
            local m = Bd.META[l.category] or Bd.META.MISC
            r.icon:SetTexture(nil)
            r.left:SetText(("|cff%02x%02x%02x%s|r  %s: %s"):format(
                m.color[1] * 255, m.color[2] * 255, m.color[3] * 255, m.short, l.name, l.message))
            r.left:SetWordWrap(false)
            tint(r.left, C.text)
            local mins = math.floor((now - (l.lastSeen or now)) / 60)
            r.right:SetText(mins < 1 and "now" or (mins .. "m"))
            r:Show()
        end
        p.note:SetText(("%d listing%s. Anything unrepeated for twenty minutes drops off."):format(
            #Bd.listings, #Bd.listings == 1 and "" or "s"))
        return
    end

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
