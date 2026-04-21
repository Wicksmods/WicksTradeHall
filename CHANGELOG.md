# Wick's Trade Hall — Changelog

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
