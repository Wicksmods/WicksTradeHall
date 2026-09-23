-- Wick's Trade Hall
-- Prices.lua: what a looted item is worth.
--
-- On TBC this walked a chain: TSM, then Auctionator, then Auctioneer,
-- then the vendor price. None of those three exist on Forever, so there
-- is no chain left to walk and the honest answer is the vendor price.
--
-- Which the client will not always give. C_Item.GetItemInfo only answers
-- for an item the character has actually encountered, and a grey that
-- just dropped is exactly the case it fails on. Wick's Gear hit the same
-- wall and solved it by shipping the data; the same applies here, and
-- ns.VENDOR is where a scraped price table will land. Until it does,
-- an unpriced item is counted as zero and says so rather than guessing.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore
local D = Core.Dialect

local P = {}
ns.Prices = P

-- itemID -> copper. Generated alongside the gear data; absent for now.
ns.VENDOR = ns.VENDOR or {}

-- copper, source. source is one of "vendor", "shipped", "unknown", and
-- the UI shows it so a total is never mistaken for more than it is.
function P:Get(itemID)
    if not itemID then return 0, "unknown" end
    local info = D.GetItemInfo(itemID)
    if info and type(info.sellPrice) == "number" and info.sellPrice > 0 then
        return info.sellPrice, "vendor"
    end
    local shipped = ns.VENDOR[itemID]
    if type(shipped) == "number" and shipped > 0 then
        return shipped, "shipped"
    end
    return 0, "unknown"
end

-- How much of a total we are actually sure about. A session where half
-- the loot could not be priced should not read as a confident number.
function P:Confidence(loot)
    local known, total = 0, 0
    for _, e in pairs(loot or {}) do
        total = total + 1
        if e.source == "vendor" or e.source == "shipped" then known = known + 1 end
    end
    if total == 0 then return 1, 0, 0 end
    return known / total, known, total
end

-- ============================================================
-- Formatting
-- ============================================================

local GOLD   = "|cffffd700g|r"
local SILVER = "|cffc7c7cfs|r"
local COPPER = "|cffeda55fc|r"

function P:Format(copper)
    copper = math.floor(tonumber(copper) or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local c = copper % 100
    local out
    if g > 0 then out = ("%d%s %d%s %d%s"):format(g, GOLD, s, SILVER, c, COPPER)
    elseif s > 0 then out = ("%d%s %d%s"):format(s, SILVER, c, COPPER)
    else out = ("%d%s"):format(c, COPPER) end
    return (neg and "-" or "") .. out
end

-- Whole gold, for the per-hour line where the copper is noise.
function P:FormatShort(copper)
    copper = math.floor(tonumber(copper) or 0)
    local neg = copper < 0
    copper = math.abs(copper)
    local g = math.floor(copper / 10000)
    if g > 0 then return (neg and "-" or "") .. ("%d%s"):format(g, GOLD) end
    local s = math.floor((copper % 10000) / 100)
    if s > 0 then return (neg and "-" or "") .. ("%d%s"):format(s, SILVER) end
    return (neg and "-" or "") .. ("%d%s"):format(copper % 100, COPPER)
end
