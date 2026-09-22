# Wick's Trade Hall (Forever) - Changelog

## 0.1.0 - 2026-09-22

First build for World of Warcraft: Forever. The economy addon, and the
umbrella Wick's Ledger folds into.

- Session earnings: gold delta, loot, experience and time, with gold per
  hour. Starts itself when you enter an instance and, with hard lock on,
  pauses rather than ends when you step out, so a summon or a run back
  from a graveyard does not split one dungeon into three sessions.
- Greys collapse into a single Junk row carrying a running total.
- Persisted on every change and restored at login; a session older than
  eight hours is forgotten rather than reported.
- The last five sessions that earned something are kept per character.
- Prices are the vendor price. TSM, Auctionator and Auctioneer do not
  exist here, so there is no chain left to walk, and this client will not
  price an item the character has never seen. Anything unpriceable counts
  as nothing and is marked, rather than quietly flattering the total.
  Items repriced when the server answers late.
- The session is kept out of the macro store: it is a running total, not
  a setting, and it would crowd out the settings that need to survive.
- Trade board: the trade channel as a board. Seven categories, one line
  per person per subject, anything nobody repeats for twenty minutes
  drops off. Channels with trade, commerce or services in the name are
  watched automatically; say and yell are read too, for the bank steps.
  A group or guild advert is not a listing unless it says outright that
  it is selling something. Item links read as the item's name.
- The session bar has a start and stop button. Auto mode covers instance
  runs, but outside one there was no way to begin a session without the
  slash command.
