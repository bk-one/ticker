# Ticker

macOS menu bar app prototype that bootstraps with `AAPL` and renders live Yahoo Finance prices with a color-intensity signal.

## Implemented baseline

- SwiftUI `MenuBarExtra` app built as a Swift package.
- Menu bar label swaps selected known instruments to compact icons or glyphs, with text fallback for unmapped symbols.
- Logo-backed entries use bundled SVG assets rendered directly at runtime, avoiding raster thumbnail artifacts.
- Condensed ticker symbol styling to save horizontal space.
- Price formatting based on magnitude:
  - `>= 1000`: no decimals
  - `10 ... 999.99`: 2 decimals
  - `1 ... 9.99`: 3 decimals
  - `< 1`: 4 decimals
- Price color derived from the last close.
- Closed-market tinting and accessibility labels still apply when a mapped symbol is rendered as an icon.
- Loading placeholder on cold launch instead of a blank menu bar item.
- Automatic 15-second refresh.
- Shared quote/rendering path that works for stocks, commodities, and crypto symbols internally.

## Yahoo Finance research snapshot

Verified on March 20, 2026:

- `GET /v7/finance/quote?symbols=AAPL,GC=F` returned `Unauthorized`.
- `GET /v8/finance/chart/{symbol}` returned usable data for both equities and futures.
- `GET /v7/finance/spark?symbols=AAPL,GC=F&range=1d&interval=5m&indicators=close&includePrePost=true` returned batched data and is what this prototype uses.

Notes:

- The Yahoo interface is unofficial and may break without notice.
- The client is isolated in `TickerKit` so endpoint changes stay localized.
- `spark` is the current best baseline because it batches symbols and returns both the live price and previous close needed for the menu bar signal.

## Run it

1. Open the package in Xcode and run the `Ticker` scheme on macOS.
2. Or build and test from the terminal with `swift build` and `swift test`.

The app runs as an accessory app, so it behaves like a menu bar utility instead of a dock-first app.

## Project layout

- `Sources/Ticker`: app entry point and menu bar UI.
- `Sources/TickerKit`: Yahoo client, quote presentation logic, and refresh store.
- `Tests/TickerKitTests`: parsing and display-logic tests.
- `docs/research.md`: endpoint notes to carry into Uberblick.
