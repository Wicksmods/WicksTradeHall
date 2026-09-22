-- Wick's Trade Hall
-- Core.lua: WickCore addon object, saved variables, event dispatch, slash command.
--
-- The economy addon for World of Warcraft: Forever, and the umbrella the
-- roster folds Wick's Ledger into. Two things in one window: what this
-- session earned, and what the trade channel is offering.
--
-- Both are reading, not doing. SendChatMessage is restricted on this
-- client, so nothing here posts; the board is a reader and always was.

local ADDON, ns = ...

local Core = WickCore
assert(Core, "Wick's Trade Hall requires WickCore. Enable the WickCore addon.")
local D, R = Core.Dialect, Core.Restrict

ns.version = "0.1.0"

local PROFILE_DEFAULTS = {
    autoMode  = true,     -- a session per instance run
    hardLock  = true,     -- leaving pauses rather than ends
    showBar   = true,
    barLocked = true,
    bar       = {},
    window    = {},
}

local CHAR_DEFAULTS = {
    session = nil,        -- the run in progress
    history = {},         -- the last five that finished
}

local A = Core:NewAddon("WicksTradeHall", {
    title    = "Wick's Trade Hall",
    version  = ns.version,
    savedVar = "WicksTradeHallSaved",
    defaults = { profile = PROFILE_DEFAULTS, char = CHAR_DEFAULTS, global = {} },
    -- A session is a running total, not a setting. Keeping it out of the
    -- macro store means a long night of looting cannot crowd out the
    -- settings that actually need to survive a logout.
    storeExclude = { "char" },
})
ns.A = A

-- ============================================================
-- Event dispatcher
-- ============================================================
local events = {}
function ns:On(event, fn)
    events[event] = events[event] or {}
    table.insert(events[event], fn)
end

local frame = CreateFrame("Frame", "WicksTradeHallEvents")
ns.eventFrame = frame
frame:SetScript("OnEvent", function(_, event, ...)
    if not events[event] then return end
    for _, fn in ipairs(events[event]) do
        local ok, err = pcall(fn, event, ...)
        if not ok then A:Print(("error in %s: %s"):format(event, tostring(err))) end
    end
end)
function ns.RegisterEvents(list)
    for _, ev in ipairs(list) do pcall(frame.RegisterEvent, frame, ev) end
end

-- ============================================================
-- Lifecycle
-- ============================================================
function A:OnInitialize()
    ns.db = self.db
    self.db:On("OnProfileChanged", function()
        if ns.UI and ns.UI.ApplyBarVisibility then ns.UI:ApplyBarVisibility() end
    end)
end

function A:OnEnable()
    ns.Ledger:Init()
    if ns.Board and ns.Board.Init then ns.Board:Init() end
    if ns.UI and ns.UI.Init then ns.UI:Init() end
    ns.Ledger:RestoreAtLogin()

    self:Print("loaded. /wth for the ledger, /wth board for the trade channel.")

    self:RegisterLauncher({
        onClick = function(_, button)
            if button == "RightButton" then ns.UI:Toggle("board") else ns.UI:Toggle("ledger") end
        end,
        tooltip = function(tt)
            tt:AddLine(Core.Chrome:TitleMarkup("Wick's Trade Hall"))
            tt:AddLine("Left-click: this session   Right-click: the trade board", 0.5, 0.5, 0.5)
        end,
    })

    self:RegisterOptions(function(page, addon)
        local O = Core.Options
        local db = addon.db.profile
        local y = O:Heading(page, "Sessions", 0)
        y = O:Check(page, "Start a session when you enter an instance",
            function() return db.autoMode ~= false end,
            function(v) db.autoMode = v end, y)
        y = O:Check(page, "Leaving pauses rather than ends it",
            function() return db.hardLock ~= false end,
            function(v) db.hardLock = v end, y)
        y = O:Note(page, "With both on, a dungeon run is one session however many times you step out for a summon or run back from a graveyard. A session left going for eight hours is forgotten rather than reported.", y)

        y = O:Heading(page, "The bar", y - 6)
        y = O:Check(page, "Show the session bar", function() return db.showBar ~= false end,
            function(v) db.showBar = v; ns.UI:ApplyBarVisibility() end, y)
        y = O:Check(page, "Lock it", function() return db.barLocked ~= false end,
            function(v) db.barLocked = v end, y)

        y = O:Heading(page, "Prices", y - 6)
        y = O:Note(page, "Loot is valued at its vendor price. The auction addons this read on TBC do not exist on Forever, and this client will not price an item the character has never seen, so anything it cannot value is counted as nothing and marked. Shipped prices will close that gap.", y)

        y = O:Button(page, "Open", function() ns.UI:Toggle() end, y - 4, 90)
        y = O:ProfileSection(page, addon, y - 8)
    end)
end

function WicksTradeHall_Toggle() if ns.UI then ns.UI:Toggle() end end

-- ============================================================
-- Slash command
-- ============================================================
A:RegisterSlash(function(_, msg)
    msg = Core.trim(msg or "")
    local lower = msg:lower()
    local Ledger, P = ns.Ledger, ns.Prices

    if lower == "" or lower == "show" or lower == "toggle" then ns.UI:Toggle() return end
    if lower == "board" or lower == "trade" then ns.UI:Toggle("board") return end
    if lower == "options" or lower == "config" then A:OpenOptions() return end

    if lower == "start" then
        if not Ledger:Start() then A:Print("a session is already running.") end
        return
    end
    if lower == "stop" or lower == "end" then
        if not Ledger:Stop() then A:Print("no session running.") end
        return
    end
    if lower == "reset" then Ledger:Reset(); A:Print("session cleared.") return end

    if lower == "clear" then
        local n = ns.Board:Clear()
        A:Print(("cleared %d listing%s."):format(n, n == 1 and "" or "s"))
        return
    end
    if lower == "channels" then
        local chans = ns.Board:Channels()
        local any = false
        for id, name in pairs(chans) do
            any = true
            A:Print(("  %d. %s%s"):format(id, name, ns.Board:Watching(id) and "  (watched)" or ""))
        end
        if not any then A:Print("no channels joined.") end
        return
    end
    if lower == "bar" then
        local db = A.db.profile
        db.showBar = not (db.showBar ~= false)
        ns.UI:ApplyBarVisibility()
        A:Print("bar " .. (db.showBar and "shown" or "hidden") .. ".")
        return
    end
    if lower == "lock" then A.db.profile.barLocked = true; A:Print("bar locked.") return end
    if lower == "unlock" then A.db.profile.barLocked = false; A:Print("bar unlocked: drag it, then /wth lock.") return end

    if lower == "status" then
        if not Ledger.active and (Ledger.totalCopper or 0) == 0 then
            A:Print("no session. /wth start to begin one.")
        else
            local e = Ledger:Elapsed()
            A:Print(("%s in %s, %dm elapsed"):format(Ledger.active and "running" or "stopped",
                Ledger.zoneName or "?", math.floor(e / 60)))
            A:Print(("earned %s, %s an hour"):format(P:Format(Ledger.totalCopper), P:FormatShort(Ledger:PerHour())))
            local conf, known, total = P:Confidence(Ledger.loot)
            A:Print(("gold %s, loot %d kinds, %d of them priced"):format(P:Format(Ledger.goldDelta), total, known))
            if conf < 1 then A:Print("the rest could not be priced, so they count as nothing.") end
        end
        local h = Ledger:History()
        A:Print(("%d session%s in history."):format(#h, #h == 1 and "" or "s"))
        local watched = 0
        for id in pairs(ns.Board:Channels()) do if ns.Board:Watching(id) then watched = watched + 1 end end
        A:Print(("board: %d listing%s from %d watched channel%s."):format(
            #ns.Board.listings, #ns.Board.listings == 1 and "" or "s",
            watched, watched == 1 and "" or "s"))
        return
    end

    A:Print("commands: show | board | start | stop | reset | clear | channels | bar | lock | unlock | options | status")
end, "/wth", "/wtradehall")
