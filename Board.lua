-- Wick's Trade Hall
-- Board.lua: the trade channel, as a board.
--
-- Ported from the TBC scanner. Reading chat is not restricted on this
-- client, only sending, so the board works here exactly as it always
-- did: watch the trade channels, decide what each message is about, and
-- keep one line per person per subject instead of the scroll.
--
-- The classifier is keyword based and deliberately conservative. A
-- message has to carry a trade signal at all, must not read like a group
-- or guild advert, and then falls through an ordered set of rules. It is
-- wrong sometimes. Wrong into Misc is cheap; wrong into a category you
-- are reading is not, which is why the blacklist runs before the rules.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore

local B = {}
ns.Board = B

B.listings = {}     -- newest first
B.lastSeen = {}     -- player -> { time, category, msg }, for the spam gate

local COOLDOWN     = 60     -- same person, same subject, ignored inside this
local MAX_PER_CAT  = 12
local AGE_OUT      = 20 * 60

-- ============================================================
-- Text
-- ============================================================

local function lower(s) return (s or ""):lower() end

local function cleanName(full)
    if not full then return "" end
    return full:match("^([^%-]+)") or full
end

local function wordSet(str)
    local set = {}
    for w in str:lower():gmatch("%S+") do set[w] = true end
    return set
end

local function containsAny(text, set)
    for w in text:gmatch("[%a%d]+") do
        if set[w] then return true end
    end
    return false
end

-- An item link reads as its name; everything else in the markup goes.
local function stripLinks(msg)
    if not msg then return "" end
    local out = msg:gsub("|c%x+|H.-|h%[(.-)%]|h|r", "%1")
    out = out:gsub("|H.-|h%[(.-)%]|h", "%1")
    out = out:gsub("|c%x+", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return (out:gsub("^%s+", ""):gsub("%s+$", ""))
end
B.StripLinks = stripLinks

-- Rough sameness, for catching a person reposting the same advert with
-- one word changed. Word overlap is enough and is cheap.
local function similarity(a, b)
    if not a or not b then return 0 end
    if a == b then return 1 end
    local seen, shared, total = {}, 0, 0
    for w in lower(a):gmatch("[%a%d]+") do seen[w] = true; total = total + 1 end
    local bTotal = 0
    for w in lower(b):gmatch("[%a%d]+") do
        bTotal = bTotal + 1
        if seen[w] then shared = shared + 1 end
    end
    local bigger = math.max(total, bTotal)
    if bigger == 0 then return 0 end
    return shared / bigger
end

-- ============================================================
-- Categories
-- ============================================================

B.ORDER = { "WTS", "WTB", "WTT", "ENCHANT", "CRAFT", "TRAVEL", "MISC" }
B.META = {
    WTS     = { label = "Selling",    short = "WTS",   color = { 0.90, 0.30, 0.30 } },
    WTB     = { label = "Buying",     short = "WTB",   color = { 0.30, 0.90, 0.40 } },
    WTT     = { label = "Trading",    short = "WTT",   color = { 0.90, 0.80, 0.20 } },
    ENCHANT = { label = "Enchanting", short = "ENCH",  color = { 0.72, 0.40, 0.92 } },
    CRAFT   = { label = "Crafting",   short = "CRAFT", color = { 0.30, 0.55, 0.95 } },
    TRAVEL  = { label = "Travel",     short = "TRVL",  color = { 0.30, 0.85, 0.85 } },
    MISC    = { label = "Misc",       short = "MISC",  color = { 0.60, 0.60, 0.60 } },
}

local TRADE_SIGNAL = wordSet(
    "wts wtb wtt selling buying trading sell buy trade offer offering " ..
    "lf iso need want have got pst cod free boost boosting " ..
    "enchant enchanting craft crafting jewelcrafting alchemy " ..
    "tailoring leatherworking blacksmithing engineering " ..
    "port portal ports portals summon summons summoning mage warlock " ..
    "gold price each stack cheap discount bulk priced " ..
    "transmute arcanite mooncloth flask elixir potion gem cut gems socket " ..
    "recipe pattern formula schematic plans design " ..
    "boe epic rare legendary gear armor weapon " ..
    "service services can do your will make tip tips " ..
    "enchanter enchants enchantment mats materials")

local BLACKLIST = wordSet(
    "lfg lfr lf1m lf2m lf3m lfm " ..
    "guild recruiting recruitment join apply " ..
    "raid raiding instance dungeon group party " ..
    "arena battleground pvp duel " ..
    "leveling questing quest help stuck " ..
    "ding grats congrats achievement " ..
    "server restart maintenance")

local TRADE_OVERRIDE = wordSet("wts wtb wtt selling buying trading")

local WTS_WORDS = wordSet("wts selling sell have got offering offer cheap discount bulk priced price each stack")
local WTB_STRONG = wordSet("wtb buying buy")
local WTB_WEAK = wordSet("lf looking need want iso")
local WTB_REINFORCE = wordSet("gold cod price paying pay pst recipe pattern formula schematic plans boe epic rare gear armor weapon gem flask elixir potion")
local WTT_WORDS = wordSet("wtt trade trading swap swapping exchange")
-- Split, because pooling these was wrong twice over. "Enchanting in
-- Undercity" is the commonest enchant advert there is and it fell into
-- Misc, because the whole set needed a service word alongside it. And
-- "gloves" on its own could carry a message into Enchanting, which is
-- the opposite mistake.
--
-- A word that can only mean enchanting is enough by itself. A word that
-- merely might, a slot or a stat or a formula name, still needs company.
local ENCH_STRONG = wordSet("enchant enchants enchanting enchanter enchanters ench enchantment enchantments")
local ENCH_WEAK = wordSet(
    "crusader fiery icy chill lifestealing demonslaying " ..
    "agility strength spirit stamina intellect healing spellpower " ..
    "2h weapon chest boots bracer bracers cloak gloves shield " ..
    "formula scroll rod runed")
-- Service words only. Widening this to wts/lf/gold was tempting and
-- wrong: it would have read "WTS gloves cheap" as an enchant.
local ENCH_CONTEXT = wordSet("tip tips free service services can do your will make lfw")
local CRAFT_WORDS = wordSet(
    "craft crafting crafter crafts blacksmithing blacksmith bs tailoring tailor " ..
    "leatherworking leatherworker lw alchemy alchemist engineering engineer engi " ..
    "transmute arcanite mooncloth flask flasks elixir elixirs potion potions gem gems cut socket")
local CRAFT_CONTEXT = wordSet("tip tips service services can do your will make recipe recipes pattern formula schematic plans design have")
-- Classic cities, not the TBC list this came from.
local TRAVEL_WORDS = wordSet(
    "port portal ports portals porting summon summons summoning taxi ride " ..
    "stormwind ironforge darnassus orgrimmar undercity thunderbluff " ..
    "moonglade dalaran stonard theramore booty")
local TRAVEL_CONTEXT = wordSet("mage warlock lock tip tips free pst")

local RULES = {
    { cat = "WTT", fn = function(t) return containsAny(t, WTT_WORDS) end },
    { cat = "ENCHANT", fn = function(t)
        -- Says enchanting outright: that is the subject, whichever
        -- direction the message is going. Someone advertising and
        -- someone looking both belong on the same shelf.
        if containsAny(t, ENCH_STRONG) then return true end
        return containsAny(t, ENCH_WEAK) and containsAny(t, ENCH_CONTEXT)
    end },
    { cat = "TRAVEL", fn = function(t)
        if containsAny(t, TRAVEL_WORDS) and containsAny(t, TRAVEL_CONTEXT) then return true end
        return containsAny(t, TRAVEL_WORDS) and (t:find("port") or t:find("summon")) and true or false
    end },
    { cat = "CRAFT", fn = function(t)
        return containsAny(t, CRAFT_WORDS) and containsAny(t, CRAFT_CONTEXT)
    end },
    { cat = "WTB", fn = function(t)
        if containsAny(t, WTB_STRONG) then return true end
        return containsAny(t, WTB_WEAK) and containsAny(t, WTB_REINFORCE)
    end },
    { cat = "WTS", fn = function(t) return containsAny(t, WTS_WORDS) end },
}

function B:Classify(text)
    if not text or text == "" then return nil end
    local t = lower(text)
    if not containsAny(t, TRADE_SIGNAL) then return nil end
    -- A group or guild advert is not trade, unless it says outright that
    -- it is selling something.
    if containsAny(t, BLACKLIST) and not containsAny(t, TRADE_OVERRIDE) then return nil end
    for _, rule in ipairs(RULES) do
        if rule.fn(t) then return rule.cat end
    end
    return "MISC"
end

-- ============================================================
-- Which channels
-- ============================================================

local channelName = {}   -- id -> lowercase name

local AUTO_WATCH = { "trade", "commerce", "services", "vente", "handel", "comercio" }

function B:RebuildChannels()
    channelName = {}
    local f = rawget(_G, "GetChannelList")
    if not f then return channelName end
    local ok, list = pcall(function() return { f() } end)
    if not ok then return channelName end
    -- id, name, disabled, in threes.
    for i = 1, #list, 3 do
        local id, name = list[i], list[i + 1]
        if id and name then channelName[id] = lower(tostring(name)) end
    end
    return channelName
end

function B:Channels()
    if next(channelName) == nil then self:RebuildChannels() end
    return channelName
end

function B:Watching(id)
    local name = self:Channels()[id]
    if not name then return false end
    for _, sub in ipairs(AUTO_WATCH) do
        if name:find(sub, 1, true) then return true end
    end
    return false
end

-- ============================================================
-- The board
-- ============================================================

function B:Add(author, category, message, guid)
    local now = time()
    local name = cleanName(author)

    -- One person shouting the same subject over and over is one listing,
    -- not twenty. Inside the cooldown it is dropped entirely; a near
    -- repeat has to wait three times as long.
    local prev = self.lastSeen[name]
    if prev and prev.category == category then
        local age = now - prev.time
        if age < COOLDOWN then return false end
        if similarity(prev.msg, message) > 0.8 and age < COOLDOWN * 3 then return false end
    end
    self.lastSeen[name] = { time = now, category = category, msg = message }

    -- Already on the board for this subject: refresh it and bubble it up.
    for i, l in ipairs(self.listings) do
        if l.name == name and l.category == category then
            l.raw, l.message, l.lastSeen = message, stripLinks(message), now
            table.remove(self.listings, i)
            table.insert(self.listings, 1, l)
            if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
            return true
        end
    end

    table.insert(self.listings, 1, {
        name = name, fullName = author, guid = guid, category = category,
        raw = message, message = stripLinks(message), firstSeen = now, lastSeen = now,
    })

    local count = 0
    for i = #self.listings, 1, -1 do
        if self.listings[i].category == category then
            count = count + 1
            if count > MAX_PER_CAT then table.remove(self.listings, i) end
        end
    end

    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return true
end

-- Anything nobody has repeated in twenty minutes is gone. A board of
-- stale adverts is worse than an empty one.
function B:Prune()
    local now, removed = time(), 0
    for i = #self.listings, 1, -1 do
        if (now - (self.listings[i].lastSeen or 0)) > AGE_OUT then
            table.remove(self.listings, i)
            removed = removed + 1
        end
    end
    if removed > 0 and ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return removed
end

function B:Clear()
    local n = #self.listings
    self.listings, self.lastSeen = {}, {}
    if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    return n
end

-- Listings in one category, or all of them, newest first.
function B:Get(category)
    if not category or category == "ALL" then return self.listings end
    local out = {}
    for _, l in ipairs(self.listings) do
        if l.category == category then out[#out + 1] = l end
    end
    return out
end

function B:Counts()
    local out = {}
    for _, l in ipairs(self.listings) do out[l.category] = (out[l.category] or 0) + 1 end
    return out
end

-- ============================================================
-- Reading chat
-- ============================================================

function B:Handle(msg, author, channelID)
    if not msg or msg == "" or not author then return false end
    if channelID and not self:Watching(channelID) then return false end
    -- Classify on the text, not the markup: an item link should read as
    -- the item's name.
    local cat = self:Classify(stripLinks(msg))
    if not cat then return false end
    return self:Add(author, cat, msg, nil)
end

function B:Init()
    if self.inited then return end
    self.inited = true
    ns.RegisterEvents({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
                        "CHAT_MSG_CHANNEL_NOTICE", "CHANNEL_UI_UPDATE", "PLAYER_ENTERING_WORLD" })

    ns:On("CHAT_MSG_CHANNEL", function(_, msg, author, _, _, _, _, _, channelNumber)
        B:Handle(msg, author, tonumber(channelNumber))
    end)
    -- Say and yell carry the trade of a capital's bank steps.
    ns:On("CHAT_MSG_SAY", function(_, msg, author) B:Handle(msg, author, nil) end)
    ns:On("CHAT_MSG_YELL", function(_, msg, author) B:Handle(msg, author, nil) end)

    local function rebuild() B:RebuildChannels() end
    ns:On("CHAT_MSG_CHANNEL_NOTICE", rebuild)
    ns:On("CHANNEL_UI_UPDATE", rebuild)
    ns:On("PLAYER_ENTERING_WORLD", rebuild)

    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(60, function() B:Prune() end)
    end
end
