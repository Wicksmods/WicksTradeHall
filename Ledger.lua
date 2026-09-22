-- Wick's Trade Hall
-- Ledger.lua: what a session earned.
--
-- Ported from Wick's Ledger on TBC, which the roster folds in here. The
-- shape is unchanged because it was right: a session is a start time, a
-- gold delta, a loot table and an XP delta, persisted on every change so
-- a crash or a reload does not lose it, and discarded after eight hours
-- because a session you forgot about is not a session.
--
-- What changed for Forever. Prices come from ns.Prices, which no longer
-- has an auction-addon chain to walk. Item lookups go through WickCore's
-- dialect. The level cap is read from the client rather than written as
-- 70. And the session lives in the char scope but is excluded from the
-- macro store: it is a running total, not a setting, and it would eat
-- the budget that keeps the real settings alive.

local ADDON, ns = ...
local Core = WickCore
local D = Core.Dialect

local L = {}
ns.Ledger = L

local MAX_HISTORY = 5
local STALE_AFTER = 8 * 60 * 60   -- a session older than this is forgotten

L.active      = false
L.startTime   = nil
L.startMoney  = nil
L.goldDelta   = 0
L.loot        = {}     -- key -> { itemID, link, icon, count, copper, source, isJunk }
L.totalCopper = 0
L.zoneName    = nil
L.startXP     = nil
L.xpDelta     = 0
L.maxLevel    = false

local function db() return ns.db and ns.db.char or nil end
local function say(msg) ns.A:Print(msg) end
local function touch()
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
end

-- ============================================================
-- Totals
-- ============================================================

local function recalc()
    local total = L.goldDelta
    for _, e in pairs(L.loot) do
        -- The junk bucket's copper is already a running total, not a
        -- per-item price, so it is not multiplied by the count.
        total = total + (e.isJunk and (e.copper or 0) or (e.copper or 0) * (e.count or 1))
    end
    L.totalCopper = total
end

function L:Elapsed()
    if not self.startTime then return 0 end
    return time() - self.startTime
end

function L:PerHour()
    local e = self:Elapsed()
    if e < 60 then return 0 end
    return math.floor(self.totalCopper / (e / 3600))
end

-- ============================================================
-- Persist and restore
-- ============================================================

local function persist()
    local c = db()
    if not c then return end
    if not L.active then c.session = nil return end
    c.session = {
        startTime = L.startTime, startMoney = L.startMoney,
        goldDelta = L.goldDelta, totalCopper = L.totalCopper,
        zoneName = L.zoneName, startXP = L.startXP,
        xpDelta = L.xpDelta, maxLevel = L.maxLevel, loot = L.loot,
    }
end
L.Persist = persist

local function restore()
    local c = db()
    local s = c and c.session
    if not s or not s.startTime then return false end
    -- A crash, a force quit, or a session left running overnight. Older
    -- than eight hours and the numbers mean nothing.
    if (time() - s.startTime) > STALE_AFTER then
        c.session = nil
        return false
    end
    L.active, L.startTime, L.startMoney = true, s.startTime, s.startMoney
    L.goldDelta, L.totalCopper = s.goldDelta or 0, s.totalCopper or 0
    L.zoneName, L.startXP = s.zoneName, s.startXP
    L.xpDelta, L.maxLevel = s.xpDelta or 0, s.maxLevel or false
    L.loot = s.loot or {}
    return true
end

local function commit()
    local c = db()
    if not c then return end
    if (L.totalCopper or 0) <= 0 then return end    -- nothing earned, nothing to keep
    c.history = c.history or {}
    table.insert(c.history, 1, {
        startTime = L.startTime, elapsed = L:Elapsed(), goldDelta = L.goldDelta,
        totalCopper = L.totalCopper, zoneName = L.zoneName, xpDelta = L.xpDelta,
    })
    while #c.history > MAX_HISTORY do table.remove(c.history) end
end

-- ============================================================
-- Experience
-- ============================================================

local function maxPlayerLevel()
    local f = rawget(_G, "GetMaxPlayerLevel")
    if f then
        local ok, n = pcall(f)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    return rawget(_G, "MAX_PLAYER_LEVEL") or 60
end

local function snapshotXP()
    local lvl = UnitLevel and UnitLevel("player") or 1
    if lvl >= maxPlayerLevel() then return nil, true end
    local f = rawget(_G, "UnitXP")
    if not f then return nil, false end
    local ok, xp = pcall(f, "player")
    return (ok and xp) or nil, false
end

local function xpSince()
    if L.maxLevel or not L.startXP then return L.xpDelta end
    local f, fmax = rawget(_G, "UnitXP"), rawget(_G, "UnitXPMax")
    if not f then return L.xpDelta end
    local ok, cur = pcall(f, "player")
    if not ok or type(cur) ~= "number" then return L.xpDelta end
    local d = cur - L.startXP
    if d < 0 then
        -- Levelled during the session: the bar wrapped.
        local okm, maxxp = pcall(fmax or function() end, "player")
        d = d + ((okm and maxxp) or 0)
    end
    return d
end

-- ============================================================
-- Control
-- ============================================================

function L:Start()
    if self.active then return false end
    self.active     = true
    self.startTime  = time()
    self.startMoney = GetMoney and GetMoney() or 0
    self.goldDelta, self.totalCopper = 0, 0
    self.loot = {}
    self.zoneName = GetRealZoneText and GetRealZoneText() or nil
    self.startXP, self.maxLevel = snapshotXP()
    self.xpDelta = 0
    persist()
    touch()
    say(("session started in %s."):format(self.zoneName or "here"))
    return true
end

function L:Stop()
    if not self.active then return false end
    self.active = false
    self.goldDelta = (GetMoney and GetMoney() or 0) - (self.startMoney or 0)
    self.xpDelta = xpSince()
    recalc()
    commit()
    persist()
    touch()
    say(("session ended, %s earned."):format(ns.Prices:Format(self.totalCopper)))
    return true
end

-- Hard lock: leaving the instance pauses rather than ends, so a run that
-- takes a summon or a graveyard trip is still one session.
function L:Pause()
    if not self.active then return false end
    self.goldDelta = (GetMoney and GetMoney() or 0) - (self.startMoney or 0)
    self.xpDelta = xpSince()
    recalc()
    self.active = false
    persist()
    touch()
    say("session paused. Re-enter to pick it up.")
    return true
end

function L:Resume()
    if self.active then return false end
    if not restore() then return false end
    -- The gold moved while we were away; keep the delta honest by moving
    -- the starting point with it rather than counting the gap as earned.
    self.startMoney = (GetMoney and GetMoney() or 0) - self.goldDelta
    self.active = true
    persist()
    touch()
    say("session resumed.")
    return true
end

function L:Reset()
    self.active = false
    self.startTime, self.startMoney = nil, nil
    self.goldDelta, self.totalCopper = 0, 0
    self.loot, self.zoneName = {}, nil
    self.startXP, self.xpDelta, self.maxLevel = nil, 0, false
    persist()
    touch()
end

function L:History()
    local c = db()
    return (c and c.history) or {}
end

-- ============================================================
-- Loot
-- ============================================================

local LOOT_PATTERNS = { "You receive loot: (.+)$", "You loot (.+)$" }

function L:ParseLoot(msg)
    local body
    for _, pat in ipairs(LOOT_PATTERNS) do
        body = msg and msg:match(pat)
        if body then break end
    end
    if not body then return nil end
    body = body:gsub("%.$", "")
    local count = 1
    local suffix = body:match(" x(%d+)$")
    if suffix then
        count = tonumber(suffix)
        body = body:gsub(" x%d+$", "")
    end
    local link = body:match("|H(item:[^|]+)|h")
    local id = link and tonumber(link:match("item:(%d+)"))
    return id, body, count
end

function L:AddLoot(msg)
    if not self.active then return false end
    local itemID, link, count = self:ParseLoot(msg)
    if not itemID then return false end

    local info = D.GetItemInfo(itemID)
    local quality = info and info.quality

    -- Greys collapse into one Junk row. Twenty separate lines of vendor
    -- trash tells you nothing; one line with a total tells you what the
    -- trip was worth.
    if quality == 0 then
        local copper = select(1, ns.Prices:Get(itemID)) * count
        local j = self.loot.junk
        if j then
            j.count, j.copper = j.count + count, j.copper + copper
        else
            self.loot.junk = { itemID = 0, icon = "Interface\\Icons\\INV_Misc_Bag_07",
                               count = count, copper = copper, source = "vendor", isJunk = true }
        end
        recalc(); persist(); touch()
        return true
    end

    local copper, source = ns.Prices:Get(itemID)
    local key = tostring(itemID)
    local e = self.loot[key]
    if e then
        e.count = e.count + count
        -- The item may have arrived from the server since we last looked.
        if e.source == "unknown" and source ~= "unknown" then e.copper, e.source = copper, source end
    else
        self.loot[key] = { itemID = itemID, link = link, icon = info and info.icon,
                           count = count, copper = copper, source = source }
    end
    recalc(); persist(); touch()
    return true
end

-- Item data arrives late on this client, so anything counted as unknown
-- is asked again whenever the server answers.
function L:Reprice()
    local changed = false
    for key, e in pairs(self.loot) do
        if not e.isJunk and e.source == "unknown" then
            local copper, source = ns.Prices:Get(e.itemID)
            if source ~= "unknown" then
                e.copper, e.source = copper, source
                if not e.icon then
                    local info = D.GetItemInfo(e.itemID)
                    e.icon = info and info.icon
                end
                changed = true
            end
        end
    end
    if changed then recalc(); persist(); touch() end
    return changed
end

-- ============================================================
-- Events
-- ============================================================

function L:Init()
    if self.inited then return end
    self.inited = true

    ns.RegisterEvents({ "PLAYER_MONEY", "CHAT_MSG_LOOT", "PLAYER_XP_UPDATE",
                        "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD" })

    ns:On("PLAYER_MONEY", function()
        if not L.active then return end
        L.goldDelta = (GetMoney and GetMoney() or 0) - (L.startMoney or 0)
        recalc(); persist(); touch()
    end)

    ns:On("CHAT_MSG_LOOT", function(_, msg) L:AddLoot(msg) end)

    ns:On("PLAYER_XP_UPDATE", function()
        if not L.active then return end
        L.xpDelta = xpSince()
        persist(); touch()
    end)

    ns:On("GET_ITEM_INFO_RECEIVED", function() L:Reprice() end)

    -- Auto mode: a session per instance run.
    ns:On("PLAYER_ENTERING_WORLD", function()
        local p = ns.db and ns.db.profile
        if not p or not p.autoMode then return end
        local inInstance, kind = IsInInstance and IsInInstance()
        if inInstance and not L.active then
            if p.hardLock and db() and db().session then L:Resume() else L:Start() end
        elseif not inInstance and L.active then
            -- Released to a graveyard outside after a wipe: they are
            -- coming back, so this is not the end of the run.
            if UnitIsGhost and UnitIsGhost("player") then return end
            if p.hardLock then L:Pause() else L:Stop() end
        end
    end)
end

-- Picked up at login, after the saved variables are bound.
function L:RestoreAtLogin()
    if restore() then
        say(("session resumed in %s."):format(self.zoneName or "here"))
        touch()
    end
end
