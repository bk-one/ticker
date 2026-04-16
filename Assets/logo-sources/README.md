# Logo Sources

- `google.svg`
- `meta.svg`
- `tesla.svg`
- `netflix.svg`
- `spotify.svg`
- `shell.svg`
- `nike.svg`
- `starbucks.svg`
- `ethereum.svg`
- `solana.svg`
- `xrp.svg`
- `dogecoin.svg`

The files above were sourced from `simple-icons/simple-icons`, which is published under `CC0 1.0`.

- `gold.svg`
- `silver.svg`
- `oil.svg`
- `gas.svg`

The commodity pictograms above were created locally for this project.

Runtime notes:

- `scripts/render_logo_assets.sh` syncs these source SVGs into `Sources/TickerKit/Resources/logo-svg/` for bundling.
- The app renders the bundled SVG paths directly at menu bar size instead of rasterizing them first.

Current intentional fallback set:

- `AAPL` and `BTC-USD` still use SF Symbols because the built-in symbols are already strong at menu bar size.
- `AMZN`, `MSFT`, and `AMGN` remain on the existing fallback path until a cleaner bundled logo source is selected.
