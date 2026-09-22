# Wick's Trade Hall

The economy addon for **World of Warcraft: Forever**, built on
[WickCore](https://github.com/Wicksmods/WickCore). Wick's Ledger folds in
here.

## What it does

**This session.** Gold, loot, experience and time, with what that comes
to an hour. It starts itself when you enter an instance and, with hard
lock on, pauses when you step out instead of ending, so one dungeon is
one session however many times you take a summon or run back from a
graveyard. Greys collapse into a single Junk row. The last five sessions
that earned anything are kept per character.

A session is persisted on every change, so a reload or a crash does not
lose it. One left running for eight hours is forgotten rather than
reported, because the numbers would mean nothing.

**The trade board.** The trade channel as a categorised board rather than
a wall of scroll. Not built yet; the tab says so.

## About prices

Loot is valued at its vendor price, and that is the honest ceiling here.
TSM, Auctionator and Auctioneer are what this read on TBC and none of
them exist on Forever, so there is no chain left to walk. This client
also will not price an item the character has never encountered, which is
exactly the case a fresh grey drop presents.

So anything that cannot be priced counts as nothing and is marked as
such. A total that quietly included guesses would be worse than one that
admits what it does not know. Shipped vendor prices, the way Wick's Gear
ships item data, will close most of that gap.

## Commands

| | |
|---|---|
| `/wth` | the window |
| `/wth board` | the trade board |
| `/wth start` / `stop` / `reset` | the session by hand |
| `/wth bar` | show or hide the session bar |
| `/wth lock` / `unlock` | the bar's position |
| `/wth status` | what it can see |

`/wtradehall` is an alias.

## The suite

Wick's Bags, Wick's Comforts, Wick's Gear, Wick's Trade Hall, and one kit
per class. <https://wicksmods.com>

## Compatibility

World of Warcraft: Forever, 1.60.x, Interface 16001. Requires WickCore.

## License

MIT for code (see [LICENSE](LICENSE)). Brand chrome and the "Wick's" wordmark are trademarked, see [TRADEMARK.md](https://github.com/Wicksmods/WickSuite/blob/main/TRADEMARK.md).
