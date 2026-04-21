# Categories

Every Trade chat message is classified into exactly one of seven categories based on keyword matching in `Categories.lua`.

| Category | What it catches |
|---|---|
| **WTS** | "WTS", "selling", "for sale", gold-per-item patterns |
| **WTB** | "WTB", "buying", "LFW" (looking for work — enchanters), "paying X g" |
| **WTT** | "WTT" (want to trade), barter offers |
| **ENCHANT** | Enchant-specific listings, mongoose / sunfire / battlemaster requests |
| **CRAFT** | Craft requests — primal fires, nether vortex, trade goods |
| **TRAVEL** | Summon offers (`WTS SUMMON`, `SUMMONS [ZONE]`), portal traders |
| **MISC** | Anything that doesn't match the above — guild recruits, raid sales, fun spam |

## Adjusting category classification

Keywords live in `Categories.lua`. If something's getting miscategorized:

1. Open an issue with the raw message text and what you expected.
2. Keyword additions go through the `KEYWORDS` table in `Categories.lua`.

## Age-based fading

Fresh listings are **white**. As they age toward the expiry window, they fade to **yellow**, then to **grey**. Expired listings drop off. Tune the expiry window in the options panel.
