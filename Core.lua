-- Wick's Trade Hall - Core
-- Namespace, configuration, listing management, utilities

local ADDON_NAME = "WicksTradeHall"
local WTH = {}
_G.WTH = WTH

WTH.version = "1.0.0"
WTH.listings = {}
WTH._lastSeen = {} -- spam tracking: playerName-category -> {time, msg}

---------------------------------------------------------------------------
-- Default config
---------------------------------------------------------------------------
local DEFAULTS = {
    expirySecs      = 180,
    cooldownSecs    = 30,
    maxPerCategory  = 50,
    dupeThreshold   = 0.75,
    soundAlert      = false,
    chatAlert       = false,
    dupeSuppression = true,
    showRealm       = false,
    scanSayYell     = false,
    minimapButton   = true,
    -- channel scanning: keys are channel IDs (numbers) set to true
    channelIDs      = { [2] = true },  -- Trade channel default
    autoWatch       = true,  -- auto-detect Trade/Services channels
    -- category visibility
    categoryVisible = {
        WTS     = true,
        WTB     = true,
        WTT     = true,
        ENCHANT = true,
        CRAFT   = true,
        TRAVEL  = true,
        MISC    = true,
    },
    -- window position (saved on move/resize)
    windowPoint     = nil,
    windowWidth     = 520,
    windowHeight    = 420,
}

---------------------------------------------------------------------------
-- Utility: deep merge defaults into target
---------------------------------------------------------------------------
local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

---------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------
function WTH.Lower(s)
    return (s or ""):lower()
end

function WTH.CleanName(fullName)
    if not fullName then return "" end
    return fullName:match("^([^%-]+)") or fullName
end

function WTH.FormatAge(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    else
        return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
    end
end

-- Convert space-separated string into a set table for O(1) lookup
function WTH.WordSet(str)
    local set = {}
    for word in str:lower():gmatch("%S+") do
        set[word] = true
    end
    return set
end

-- Tokenize text into words and check if any exist in the provided set
function WTH.ContainsAny(text, wordSet)
    for word in text:gmatch("[%a%d]+") do
        if wordSet[word] then return true end
    end
    return false
end

-- Strip WoW link markup for display: |cff...|Hitem:...|h[Text]|h|r -> Text
function WTH.StripLinks(text)
    if not text then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x|H[^|]+|h%[([^%]]+)%]|h|r", "%1")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H[^|]+|h", "")
    text = text:gsub("|h", "")
    return text
end

-- Simple similarity ratio (word overlap) between two strings
function WTH.Similarity(a, b)
    if not a or not b then return 0 end
    a, b = a:lower(), b:lower()
    local wordsA = {}
    local total = 0
    local matches = 0
    for w in a:gmatch("%a+") do wordsA[w] = true end
    for w in b:gmatch("%a+") do
        total = total + 1
        if wordsA[w] then matches = matches + 1 end
    end
    if total == 0 then return 1 end
    return matches / total
end

---------------------------------------------------------------------------
-- Listing management
---------------------------------------------------------------------------
function WTH.AddListing(playerName, category, message, guid)
    local cfg = WTH.config
    local now = time()
    local name = WTH.CleanName(playerName)

    -- Spam cooldown check
    local prev = WTH._lastSeen[name]
    if prev and prev.category == category then
        local age = now - prev.time
        if age < cfg.cooldownSecs then
            return  -- same player, same category, too soon
        end
        -- If enough time passed but message is nearly identical, still skip
        if cfg.dupeSuppression and WTH.Similarity(prev.msg, message) > cfg.dupeThreshold then
            if age < cfg.cooldownSecs * 3 then
                return
            end
        end
    end
    WTH._lastSeen[name] = { time = now, category = category, msg = message }

    -- Check for existing listing from same player in same category - update it
    for i, listing in ipairs(WTH.listings) do
        if listing.name == name and listing.category == category then
            listing.rawMessage = message
            listing.message = WTH.StripLinks(message)
            listing.lastSeen = now
            -- Bubble to top
            table.remove(WTH.listings, i)
            table.insert(WTH.listings, 1, listing)
            if WTH.RefreshUI then WTH.RefreshUI() end
            return
        end
    end

    -- Create new listing
    local listing = {
        name       = name,
        fullName   = playerName,
        guid       = guid,
        category   = category,
        rawMessage = message,
        message    = WTH.StripLinks(message),
        firstSeen  = now,
        lastSeen   = now,
    }
    table.insert(WTH.listings, 1, listing)

    -- Cap per-category
    local catCount = 0
    for i = #WTH.listings, 1, -1 do
        if WTH.listings[i].category == category then
            catCount = catCount + 1
            if catCount > cfg.maxPerCategory then
                table.remove(WTH.listings, i)
            end
        end
    end

    if cfg.soundAlert then PlaySound(1210) end
    if cfg.chatAlert then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff4fc878[WTH]|r " .. listing.name .. ": " .. message
        )
    end

    if WTH.RefreshUI then WTH.RefreshUI() end
end

function WTH.SweepExpired()
    local cfg = WTH.config
    local expiry = cfg.expirySecs
    local now = time()
    local changed = false
    for i = #WTH.listings, 1, -1 do
        if (now - WTH.listings[i].lastSeen) >= expiry then
            table.remove(WTH.listings, i)
            changed = true
        end
    end
    if changed and WTH.RefreshUI then
        WTH.RefreshUI()
    end
end

function WTH.ClearAll()
    WTH.listings = {}
    WTH._lastSeen = {}
    if WTH.RefreshUI then WTH.RefreshUI() end
end

---------------------------------------------------------------------------
-- Main event frame - handles init AND chat dispatch
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "WTHEventFrame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eventFrame:RegisterEvent("CHAT_MSG_SAY")
eventFrame:RegisterEvent("CHAT_MSG_YELL")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == ADDON_NAME then
            if type(WicksTradeHallDB) ~= "table" then WicksTradeHallDB = {} end
            WTH.config = WicksTradeHallDB
            ApplyDefaults(WTH.config, DEFAULTS)
            DEFAULT_CHAT_FRAME:AddMessage("|cff4fc878[WTH]|r v" .. WTH.version .. " loaded. |cffffd700/wth|r to open.")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        WTH.OnEnteringWorld()
    elseif event == "CHAT_MSG_CHANNEL" then
        if WTH.Scanner then WTH.Scanner.OnChannelMessage(...) end
    elseif event == "CHAT_MSG_SAY" and WTH.config and WTH.config.scanSayYell then
        if WTH.Scanner then WTH.Scanner.OnSayYell(...) end
    elseif event == "CHAT_MSG_YELL" and WTH.config and WTH.config.scanSayYell then
        if WTH.Scanner then WTH.Scanner.OnSayYell(...) end
    end
end)

function WTH.OnEnteringWorld()
    if WTH._sweepTimer then return end
    WTH._sweepTimer = CreateFrame("Frame", "WTHSweepFrame")
    WTH._sweepTimer._elapsed = 0
    WTH._sweepTimer:SetScript("OnUpdate", function(self, dt)
        self._elapsed = self._elapsed + dt
        local interval = 15
        if self._elapsed >= interval then
            self._elapsed = 0
            WTH.SweepExpired()
        end
    end)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_WICKSTRADEHALL1 = "/wth"
SLASH_WICKSTRADEHALL2 = "/tradehall"
SlashCmdList["WICKSTRADEHALL"] = function(msg)
    msg = WTH.Lower(msg):match("^%s*(.-)%s*$")
    if msg == "debug" then
        WTH._debug = not WTH._debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fc878[WTH]|r Debug: " .. (WTH._debug and "ON" or "OFF"))
    elseif msg == "options" or msg == "config" or msg == "settings" then
        if WTH.ToggleOptions then WTH.ToggleOptions() end
    elseif msg == "clear" then
        WTH.ClearAll()
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fc878[WTH]|r Listings cleared.")
    elseif msg == "version" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4fc878[WTH]|r v" .. WTH.version)
    else
        if WTH.ToggleUI then WTH.ToggleUI() end
    end
end
