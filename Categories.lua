-- Wick's Trade Hall - Categories
-- Keyword-based message classification

local WTH = _G.WTH
local Cat = {}
WTH.Categories = Cat

---------------------------------------------------------------------------
-- Category definitions
---------------------------------------------------------------------------
Cat.ORDER = { "WTS", "WTB", "WTT", "ENCHANT", "CRAFT", "TRAVEL", "MISC" }

Cat.META = {
    WTS     = { label = "Selling",    shortLabel = "WTS",     color = { 0.90, 0.30, 0.30 }, hex = "e64d4d" },
    WTB     = { label = "Buying",     shortLabel = "WTB",     color = { 0.30, 0.90, 0.40 }, hex = "4de666" },
    WTT     = { label = "Trading",    shortLabel = "WTT",     color = { 0.90, 0.80, 0.20 }, hex = "e6cc33" },
    ENCHANT = { label = "Enchanting", shortLabel = "ENCH",    color = { 0.72, 0.40, 0.92 }, hex = "b866eb" },
    CRAFT   = { label = "Crafting",   shortLabel = "CRAFT",   color = { 0.30, 0.55, 0.95 }, hex = "4d8cf2" },
    TRAVEL  = { label = "Travel",     shortLabel = "TRAVEL",  color = { 0.30, 0.85, 0.85 }, hex = "4dd9d9" },
    MISC    = { label = "Misc",       shortLabel = "MISC",    color = { 0.60, 0.60, 0.60 }, hex = "999999" },
}

---------------------------------------------------------------------------
-- Keyword sets
---------------------------------------------------------------------------

-- Broad trade signals - at least one must appear for any classification
local TRADE_SIGNAL = WTH.WordSet(
    "wts wtb wtt selling buying trading sell buy trade offer offering " ..
    "lf lfm looking iso need want have got pst cod free boost boosting " ..
    "enchant enchanting craft crafting jewel jewelcrafting alchemy " ..
    "tailoring leatherworking blacksmithing engineering inscription " ..
    "port portal ports portals summon summons summoning mage warlock " ..
    "taxi ride mount flying fly shuttle " ..
    "gold price each stack cheap discount bulk priced " ..
    "transmute arcanite mooncloth spellcloth shadowcloth primal nether " ..
    "flask elixir potion gem cut gems socket meta " ..
    "recipe pattern formula schematic plans design " ..
    "boe epic rare legendary gear armor weapon " ..
    "service services can do your will make tip tips"
)

-- Blacklist: messages with these words are likely NOT trade
local BLACKLIST = WTH.WordSet(
    "lfg lfr lf1m lf2m lf3m lfm " ..
    "guild recruiting recruitment join apply " ..
    "raid raiding instance dungeon group party " ..
    "arena battleground pvp duel " ..
    "leveling questing quest help stuck " ..
    "ding grats congrats achievement " ..
    "server restart maintenance"
)

-- Strong trade verbs that override blacklist
local TRADE_OVERRIDE = WTH.WordSet("wts wtb wtt selling buying trading")

---------------------------------------------------------------------------
-- Category-specific keyword sets
---------------------------------------------------------------------------

-- WTS: selling
local WTS_KEYWORDS = WTH.WordSet(
    "wts selling sell have got offering offer " ..
    "cheap discount bulk priced price each stack"
)

-- WTB: buying
local WTB_STRONG = WTH.WordSet("wtb buying buy")
local WTB_WEAK = WTH.WordSet("lf looking need want iso")
local WTB_REINFORCE = WTH.WordSet(
    "gold cod price paying pay pst " ..
    "recipe pattern formula schematic plans " ..
    "boe epic rare gear armor weapon " ..
    "gem primal nether flask elixir potion"
)

-- WTT: trading
local WTT_KEYWORDS = WTH.WordSet("wtt trade trading swap swapping exchange")

-- Enchanting
local ENCHANT_KEYWORDS = WTH.WordSet(
    "enchant enchanting enchants enchanter " ..
    "mongoose spellpower sunfire soulfrost " ..
    "crusader fiery icy chill lifestealing " ..
    "savagery major healing major spellpower " ..
    "2h weapon chest boots bracer cloak gloves"
)
local ENCHANT_CONTEXT = WTH.WordSet("tip tips free service services can do your will")

-- Crafting
local CRAFT_KEYWORDS = WTH.WordSet(
    "craft crafting crafter crafts " ..
    "blacksmithing blacksmith bs " ..
    "tailoring tailor " ..
    "leatherworking leatherworker lw " ..
    "jewelcrafting jeweler jc " ..
    "alchemy alchemist " ..
    "engineering engineer engi " ..
    "inscription scribe " ..
    "transmute arcanite mooncloth spellcloth shadowcloth " ..
    "primal nether nethers " ..
    "flask flasks elixir elixirs potion potions " ..
    "gem gems cut cutting socket meta"
)
local CRAFT_CONTEXT = WTH.WordSet(
    "tip tips service services can do your will make " ..
    "recipe recipes pattern formula schematic plans design have"
)

-- Travel
local TRAVEL_KEYWORDS = WTH.WordSet(
    "port portal ports portals porting " ..
    "summon summons summoning " ..
    "taxi ride shuttle flying fly " ..
    "shattrath shatt dalaran darnassus ironforge stormwind orgrimmar " ..
    "thunderbluff undercity silvermoon exodar " ..
    "stonard theramore"
)
local TRAVEL_CONTEXT = WTH.WordSet("mage warlock lock tip tips free pst")

---------------------------------------------------------------------------
-- Classification rules (checked in order, first match wins)
---------------------------------------------------------------------------
local RULES = {
    -- WTT must come before WTS/WTB since "wtt" is definitive
    { cat = "WTT",     fn = function(t) return WTH.ContainsAny(t, WTT_KEYWORDS) end },

    -- Enchanting: enchant keywords + context or just "enchanting" as a service
    { cat = "ENCHANT", fn = function(t)
        if WTH.ContainsAny(t, ENCHANT_KEYWORDS) and WTH.ContainsAny(t, ENCHANT_CONTEXT) then
            return true
        end
        -- "enchanting services" / "free enchants" type messages
        return t:find("enchant") and (t:find("service") or t:find("free") or t:find("tip"))
    end },

    -- Travel: portal/summon keywords
    { cat = "TRAVEL",  fn = function(t)
        if WTH.ContainsAny(t, TRAVEL_KEYWORDS) and WTH.ContainsAny(t, TRAVEL_CONTEXT) then
            return true
        end
        return WTH.ContainsAny(t, TRAVEL_KEYWORDS) and (t:find("port") or t:find("summon"))
    end },

    -- Crafting: craft keywords + context
    { cat = "CRAFT",   fn = function(t)
        return WTH.ContainsAny(t, CRAFT_KEYWORDS) and WTH.ContainsAny(t, CRAFT_CONTEXT)
    end },

    -- WTB: strong keywords always win; weak keywords need reinforcement
    { cat = "WTB",     fn = function(t)
        if WTH.ContainsAny(t, WTB_STRONG) then return true end
        if WTH.ContainsAny(t, WTB_WEAK) and WTH.ContainsAny(t, WTB_REINFORCE) then
            return true
        end
        return false
    end },

    -- WTS: selling keywords (checked after WTB to avoid conflicts)
    { cat = "WTS",     fn = function(t)
        return WTH.ContainsAny(t, WTS_KEYWORDS)
    end },
}

---------------------------------------------------------------------------
-- Main classification function
---------------------------------------------------------------------------
function Cat.Classify(text)
    if not text or text == "" then return nil end
    local lower = text:lower()

    -- Must contain at least one trade signal word
    if not WTH.ContainsAny(lower, TRADE_SIGNAL) then
        return nil
    end

    -- Blacklist check (unless overridden by strong trade verbs)
    if WTH.ContainsAny(lower, BLACKLIST) and not WTH.ContainsAny(lower, TRADE_OVERRIDE) then
        return nil
    end

    -- Check rules in order
    for _, rule in ipairs(RULES) do
        if rule.fn(lower) then
            return rule.cat
        end
    end

    -- Fallback to MISC if trade signal exists
    return "MISC"
end
