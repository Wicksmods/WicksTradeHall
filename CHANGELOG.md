# Wick's Trade Hall — Changelog

## 1.0.4 — 2026-04-26

### Title bar slim revert + close-button glyph fix

Reverted the heavier 32px header from 1.0.3 back to the slim CD-Tracker chrome that the suite shipped pre-harmonization — 22px tall, FRIZQT 12 (no outline), plain `×` close button, drop the fel-green underline. Kept the two-tone title color (`Wick's` in fel-green, `Trade Hall` in cream) since that's the part of the 1.0.3 work that worked. Listing count stays in the header to the left of the close button. The header `…` menu button has been removed (Options is still reachable from the status bar at the bottom of the panel).

Also: the previous `✕` (U+2715) close glyph was rendering as a tofu/missing-glyph box in `Fonts\FRIZQT__.TTF`. Swapped to `×` (U+00D7) which renders cleanly. This is the visible bug fix users will notice most.

No functional changes.

## 1.0.3 — 2026-04-25

### Title bar harmonization

Header now matches the canonical Wick suite spec — 32px tall, two-tone title (`Wick's` in fel-green, `Trade Hall` in cream, FRIZQT 14 outlined), bordered ✕ close button, fel-green underline at the bottom of the header. Listing count and a `…` menu button now live in the header right side, between the title and the close button.

No functional changes.

## 1.0.2 — 2026-04-21

### Brand identity pass

Normalized the five locked Wick brand palette tokens to hex-exact values. Part of a coordinated pass across the Wick addon suite (BIS Tracker, CD Tracker, Trade Hall).

**Visual impact:** imperceptible — shifts are <2 sRGB units per channel.

| Token          | Before                            | After                               |
|----------------|-----------------------------------|-------------------------------------|
| C_BG           | `0.05, 0.04, 0.08, 0.97`          | `0.051, 0.039, 0.078, 0.97`         |
| C_HEADER_BG    | `0.09, 0.07, 0.16, 1`             | `0.090, 0.067, 0.141, 1`            |
| C_BORDER       | `0.22, 0.18, 0.36, 1`             | `0.220, 0.188, 0.345, 1`            |
| C_GREEN        | `0.31, 0.78, 0.47, 1`             | `0.310, 0.780, 0.471, 1`            |
| C_TEXT_NORMAL  | `0.83, 0.78, 0.63, 1`             | `0.831, 0.784, 0.631, 1`            |

Addon-local tokens (`C_ALT_ROW_BG`, `C_BUTTON_BG`, `C_BUTTON_ACTIVE`, `C_BORDER_DIM`, `C_TEXT_DIM`) are derived UI shades, not part of the locked brand palette, and were left untouched.

Brand spec: `memory/reference_wick_brand_style.md`.

## 1.0.1

- Prior release (no changelog recorded).
