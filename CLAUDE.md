# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MetaTrader 5 (MQL5) programs for scalping XAUUSD (gold). Each `.mq5` file is fully self-contained (no shared `.mqh` includes besides the standard `<Trade/Trade.mqh>`), so helpers like `PointValue`, `NormalizePrice`, `ClosedShift`, `LastSwingHigh/Low`, `StructureDir`, and the dashboard row/panel functions are **duplicated** across files. A fix to shared logic usually needs to be applied to each file that has a copy.

Comments, input labels, log messages and panel text are in **French without accents** (e.g. "Bougies", "Cloture", "deja"). Keep that convention.

| File | Type | Role |
|---|---|---|
| `XAUUSD_Scalping_EA.mq5` | Expert Advisor | Automated trading: confluence score → order with SL/TP, BE/trailing, daily limits, news filter, backtest stats |
| `XAUUSD_Signal_Guide.mq5` | Indicator | Visual-only version of the EA's logic: BUY/SELL arrows, panel, levels; no orders |
| `XAUUSD_Signal_Pro.mq5` | Indicator | Runs 3 modes in parallel (SCALPING M15/M5/M1 bias H1, INTRADAY H1/M15/M5 bias H4, SWING D1/H4/H1 bias W1) via per-TF `CTFData` objects and `ModeDef`; `ComputeAdvice()` scores which mode suits the market (trend, ADX, spread vs trigger ATR, volatility, session, past results) and drives the panel focus in AUTO. Stricter filters (grade A+/A/B, TP capped at next S/R, SL bounds in ATR, RSI anti-chase), TP/SL stats per mode, entry classified as TREND/BREAKOUT/RETEST/MEANREV (`info.setup`), key levels drawn by `DrawKeyLevels` (nearest unbroken swing S/R per TF M5–D1, PDH/PDL/PDC, PWH/PWL, PMH/PML, round numbers) and fed into S/R candidates via `AddKeyCandidates`, card-style panel (anti-flicker: smoothed spread `gSpreadAvg`, advisor recomputed once per M1 bar with hysteresis `InpAdviceHysteresis` + `InpAdviceConfirmBars` and focus locked while a trade is active, chart objects updated in place via `Keep`/`KeepPurge` instead of delete+redraw, key levels recomputed only on bar close, panel redrawn by the 1 s timer, history processed in chunks of `InpBarsPerCall` bars per tick when the market is live (`gCatchingUp` progress banner), MARCHE FERME / CONNEXION PERDUE banner from `QuoteAge()`, fixed-height rows, scale `gFit` only shrinks until the chart is resized), optional "Gold Night" dark chart theme (`ApplyChartTheme` on init, original colors restored in `OnDeinit`). Its `ClosedShift` also works when the chart TF is higher than the target TF. Prefix `XAU_SP_` |
| `XAUUSD_Signal_Executor.mq5` | Expert Advisor | Companion of Signal Pro (indicators cannot trade). Attach on the same chart: catches the click on the panel banner (`XAU_SP_P_BAN*` objects), confirms with an in-chart box (`CONFIRMER`/`ANNULER` buttons, `XSP_EX_` objects, auto-cancel after `InpConfirmSeconds`; `MessageBox` only if `InpConfirmMode = CONFIRM_POPUP`, since on macOS/Wine it can hide behind MT5 and freeze the terminal), sizes the lot (risk % or fixed) and opens the position with the signal's SL/TP. Never trades without a click. Bridge = terminal global variables `XSP_<symbol>_*` (`SIG_*` published by the indicator, `RES_*` + `ALIVE` heartbeat written by the EA) |
| `XAUUSD_Trade_Desk.mq5` | Expert Advisor | Standalone trend-following assistant, independent of the other files. 2 modes on fixed TFs (`gTF[]` = M5/M15/H1/H4): SCALPING (bias H1, trend M15, entry M5) and INTRADAY (bias H4, trend H1, entry M15). 2 setups in trend direction only (`SetupPullback`, `SetupRetest`), per-mode check-list `chk[]` shown on the card panel. `TFData` arrays are series copied from shift 1 (index 0 = last closed bar). Manual by default (card button + second click to confirm), auto if `InpExecMode = EXEC_AUTO`, in the tester, or when switched on with the panel button `BTN_AU` (`SetAuto`, second click to confirm; the choice is kept in the terminal global variable `XTD_<symbol>_<magic>_AUTO` and dropped on parameter change / EA removal). `GuardReason()` is the gating order (algo trading → session → spread → news → daily loss → daily trades → consecutive losses → max positions). Magic = `InpMagic` (scalping) / `InpMagic + 1` (intraday). Prefix `XAU_TD_` |
| `XAUUSD_Scalping_V3.2.mq5` | Indicator | Older indicator (internally labelled **V3.3** despite the filename); EMA/ATR/ADX with 0–100 score |

Only `XAUUSD_Scalping_V3.2.mq5` is tracked in git so far; the EA and Signal Guide are new.

## Build / test

There is no build system, linter, or test suite in the repo. Code is compiled with MetaEditor (part of MT5, Windows):
- Copy/symlink the file into `MQL5/Experts/` (EA) or `MQL5/Indicators/` (indicators) of the MT5 data folder, then compile (F7) in MetaEditor. On macOS MT5 runs under Wine; `metaeditor64.exe /compile:"<file>.mq5" /log` works from the CLI if available.
- "Testing" = MT5 Strategy Tester on XAUUSD. The EA prints a stats summary in `OnDeinit` via `PrintBacktestStats()` only when `MQL_TESTER` is set. The dashboard and chart drawing are skipped during optimization (`MQL_OPTIMIZATION`), and the news filter is skipped in the tester unless `InpNewsInTester` is true.

On this Mac, compiling from the CLI works with the Wine bundled in `MetaTrader 5.app`: copy the file into the MT5 `MQL5/Experts/` or `MQL5/Indicators/` folder (prefix `~/Library/Application Support/net.metaquotes.wine.metatrader5`), `cd` to `drive_c/Program Files/MetaTrader 5`, then run `wine MetaEditor64.exe "/compile:MQL5\Experts\<file>.mq5" "/log:<path>"` with `WINEPREFIX` set to that prefix (the log is UTF-16). A source path outside the MT5 folder fails to resolve `<Trade/Trade.mqh>`.

If compiling is not possible, review MQL5 changes carefully (array series direction, handle lifetimes, `CopyBuffer` return counts).

## Shared trading model (all three files)

Multi-timeframe top-down analysis, independent of the chart timeframe:
- **M15** = trend/direction (EMA 10/20/50 alignment + spread vs ATR, swing structure HH/HL vs LH/LL, VWAP in the EA)
- **M5** = zone: support/resistance, pullback to EMA, breakout + retest, Bollinger
- **M1** = trigger: price action (pin bar, engulfing, BOS)
- Optional **H1** bias filter and ADX range filter in the indicators.

No single indicator opens a trade; a weighted **confluence score** must reach a minimum (`InpMinScore` in EA/Guide — weights `InpW_*`; `Min_Score` on a 0–100 scale in V3.x).

**Non-repainting is a core invariant:** signals are evaluated only on *closed* bars. `ClosedShift(tf, time)` maps a closed M1 (or chart) bar to the last fully *closed* bar on a higher timeframe (it bumps the shift by one if the higher-TF bar was still open at that time). Don't read shift 0 of a higher TF when computing signals.

## EA flow (`XAUUSD_Scalping_EA.mq5`)

`OnTick` → `ManagePositions()` (break-even / trailing on every tick) → `RefreshDailyStats()` → `BuildSnapshot()` (copies all indicator buffers and fills the global `MarketSnapshot gSnap`: trends, zones, price action, buy/sell scores, `PrepareTradeLevels`, `ApplyStatusFilters`) → on a **new M1 bar only** `EvaluateAndTrade()` → `OpenBuy/OpenSell` → `UpdateDashboard()` / `DrawChartLevels()`.

- `ApplyStatusFilters` sets `gSnap.status` (`STATUS_READY/WAIT/BLOCKED`) and a human-readable `gSnap.reason` shown on the dashboard; the order of checks there is the gating order (hours → spread → news → daily limits → max positions → cooldown → volatility → M15 neutral → score/M1 signal → risk/RR → M5 zone).
- Anti-duplicate: `MakeSetupId(dir, time, level)` vs `gLastSetupId` prevents re-trading the same setup.
- Positions are identified by `InpMagic`; all chart objects use `OBJ_PREFIX` (`XAU_EA_`, `XAU_SG_`, `XAU_SP_`, `XAU33_`) and are removed with `ObjectsDeleteAll` on deinit.
- Indicator handles are created in `OnInit` and released in `OnDeinit` via `ReleaseH`. Adding an indicator means adding it in both places plus the `INVALID_HANDLE` check.

## Indicators

Both indicators use `OnCalculate` with 5 plot buffers (EMA10/20/50 lines + BUY/SELL arrows), arrays set to non-series (`ArraySetAsSeries(..., false)`), and reload higher-TF data (`LoadMTF` / `LoadMTFData`) on new bars or every ~900 ms. Arrows are only computed up to `rates_total - 2` (last closed bar) and limited to a history window (`InpHistoryBars` / `Signal_History_Bars`).

`XAUUSD_Signal_Pro.mq5` performance rules (it was slow when combined with the EA): copy only new bars in `OnCalculate` (`toCopy = rates_total - prev_calculated + 1`; ATR is an `INDICATOR_CALCULATIONS` buffer so tail copies keep indexes), never redraw on every tick (chart levels on new bar / signal / focus change, panel via the 1 s timer), panel objects go through a per-slot signature cache (`CacheHit`) so unchanged objects get no `ObjectSet*` calls, `ChartRedraw` only when something changed, bridge global variables written only on change. Only one active instance per chart: `OwnerKey()` + `_HB` heartbeat global variable; a duplicate goes dormant and removes itself. The EA auto-attaches the indicator 3 s after start and only if `IndicatorPresent()` is false.

The dashboard panel (all files) is built from rows (`AddRow`/`RowTitle`/`NextColumn`, `ROW_TEXT/SEP/TITLE`, `MAX_ROWS`) and auto-sizes width using `TextWidthPx`; it redraws on `CHARTEVENT_CHART_CHANGE`.
