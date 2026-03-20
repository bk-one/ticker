# Research Notes

Date checked: March 20, 2026

## Yahoo Finance endpoint findings

Direct requests against Yahoo Finance showed:

- `/v7/finance/quote` is not a safe baseline anymore. A request for `AAPL,GC=F` returned an `Unauthorized` error payload.
- `/v8/finance/chart/{symbol}` still works for individual symbols and returns current market metadata plus time series data.
- `/v7/finance/spark` still works for batched fetches and returns enough metadata for a watchlist:
  - `shortName`
  - `currency`
  - `regularMarketPrice`
  - `previousClose`
  - `regularMarketTime`
  - `exchangeName`
  - intraday `close` values

## Why the baseline uses `spark`

- It batches multiple symbols in one request, which fits a menu bar watchlist better than one-request-per-symbol `chart`.
- It exposes the current price and previous close directly, so the app can calculate change and percentage change without extra calls.
- It includes intraday close values, which are enough for a compact sparkline.

## Implementation constraints

- This is an unofficial API. The app should expect schema drift, missing symbols, and occasional access changes.
- The data client should stay isolated behind one protocol so fallback strategies are cheap.
- The UI should surface stale data clearly instead of pretending the latest refresh worked.
- Commodity futures symbols such as `GC=F` need to be treated as first-class symbols, not edge cases.

## Likely next steps

- Add a `chart` fallback path if `spark` starts returning partial failures.
- Add launch-at-login support once the product requirements are fixed.
- Decide whether the bootstrap-only menu bar app should stay single-symbol or later grow into a configurable watchlist.
- Decide how much caching is needed for offline or startup behavior.
