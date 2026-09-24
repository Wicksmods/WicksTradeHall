# Wick's Trade Hall (Forever) - Changelog

## 0.9.2 — 2026-09-24

### Fixed

- The board no longer fills your chat with errors during a fight. The
  client hands an addon the text of a chat line as something it is not
  allowed to read while restrictions are up, and the board was reading
  it. Lines said during a fight are skipped instead.
- The same guard covers the session tracker, which reads loot lines.

## 0.9.1

### The board reads as a board

Every listing carries a category badge and the icon of the first item it
names, with filters along the top, a search box, and an age that fades as
it gets old. Right-click a line to open a whisper, shift-click to put the
item in your chat box. Neither sends anything: posting is restricted on
this client.

### Fixed

- A taxi or a summon reads as travel rather than falling into Misc. The
  words that can only mean getting somewhere now classify on their own,
  while a city name still needs company, because half the channel says
  where it is standing while selling ore.
- The session total was counting most loot as nothing. It listened for
  the client to answer about an item but never asked, and a fresh drop is
  exactly the case the client stays quiet about.

## 0.9.0

One version across the suite for the Forever beta. Every addon carried a
number of its own that said nothing about how finished it was, so they are
aligned here and the suite goes to 1.0.0 together at launch.

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
