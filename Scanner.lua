-- Wick's Trade Hall - Scanner
-- Handles incoming chat events, filters by channel,
-- classifies messages and hands them to Core

WTH.Scanner = {}
local Scanner = WTH.Scanner

-- ── Channel name cache ─────────────────────────────────────
-- Maps channelID (number) → lowercase channel name
-- Updated whenever a channel is joined/left
local channelNameCache = {}

local function RebuildChannelCache()
    local list = { GetChannelList() }
    channelNameCache = {}
    -- GetChannelList returns: id, name, disabled, ...  in groups of 3
    for i = 1, #list, 3 do
        local id   = list[i]
        local name = list[i + 1]
        if id and name then
            channelNameCache[id] = WTH.Lower(name)
        end
    end
end

-- Register channel-list change events so our cache stays fresh
local channelWatcher = CreateFrame("Frame", "WTHChannelWatcher")
channelWatcher:RegisterEvent("CHANNEL_UI_UPDATE")
channelWatcher:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
channelWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
channelWatcher:SetScript("OnEvent", function()
    RebuildChannelCache()
end)

-- ── Channel matching ───────────────────────────────────────

-- Channel names we always watch regardless of user config
-- (lowercase substrings – if the channel name CONTAINS any of these, scan it)
local AUTO_WATCH_SUBSTRINGS = {
    "trade",
    "commerce",
    "services",
    "vente",       -- frFR
    "handel",      -- deDE
    "comercio",    -- esES
}

local function IsAutoWatched(nameLower)
    for _, substr in ipairs(AUTO_WATCH_SUBSTRINGS) do
        if nameLower:find(substr, 1, true) then
            return true
        end
    end
    return false
end

local function ShouldScanChannel(channelID)
    local cfg = WTH.config or {}
    -- User-configured channel IDs
    if cfg.channelIDs and cfg.channelIDs[channelID] then
        return true
    end
    -- Auto-watch by channel name
    if cfg.autoWatch ~= false then
        local name = channelNameCache[channelID]
        if name and IsAutoWatched(name) then
            return true
        end
    end
    return false
end

-- ── Message handlers ───────────────────────────────────────

-- Handle CHAT_MSG_CHANNEL
-- Signature: msg, author, language, channelString, target, flags, unknown, channelNumber, channelName, unknown2, counter, guid
function Scanner.OnChannelMessage(msg, author, _, _, _, _, _, channelNumber, _, _, _, guid)
    if not msg or not author or msg == "" then return end
    local cid = tonumber(channelNumber)
    if not cid then return end
    if not ShouldScanChannel(cid) then return end

    Scanner.ProcessMessage(msg, author, guid or "")
end

-- Handle CHAT_MSG_SAY / CHAT_MSG_YELL
function Scanner.OnSayYell(msg, author, _, _, _, _, _, _, _, _, _, guid)
    if not msg or not author or msg == "" then return end
    Scanner.ProcessMessage(msg, author, guid or "")
end

-- Core processing: classify and store
function Scanner.ProcessMessage(msg, author, guid)
    local msgLower = WTH.Lower(msg)

    -- Strip item/spell links down to their text for matching
    -- e.g. |cff...|h[Thunderfury]|h|r  →  thunderfury
    msgLower = msgLower:gsub("|c%x+|h%[(.-)%]|h|r", "%1")
    msgLower = msgLower:gsub("|c%x+|Hitem:.-%|h%[(.-)%]|h|r", "%1")
    -- Strip remaining link markup
    msgLower = msgLower:gsub("|[cChH][^|]*", ""):gsub("|r", "")

    local category = WTH.Categories.Classify(msgLower)
    if not category then return end

    -- Check if this category is enabled
    local cfg = WTH.config or {}
    local vis = cfg.categoryVisible and cfg.categoryVisible[category]
    if vis == false or vis == 0 then
        return
    end

    WTH.AddListing(author, category, msg, guid)
end

-- ── Expose channel cache for Options UI ───────────────────
function Scanner.GetChannelList()
    if next(channelNameCache) == nil then
        RebuildChannelCache()
    end
    local copy = {}
    for id, name in pairs(channelNameCache) do copy[id] = name end
    return copy
end

-- Initial build
RebuildChannelCache()
