# Trading Rule Engine - Project Context

## 1. Project Mission

Trading Rule Engine is a Trading Rule Engine Lab.

The goal of this project is to convert human trading experience into measurable, testable, modular business rules. The engine should help observe market structure, validate rule behavior, and improve trading decisions through clear logic.

The first objective is research, learning, and rule validation. The priority is not aggressive profit.

## 2. Current Architecture

Current project status: Alpha 1.0

Project type: MT5 / MQL5 modular Expert Advisor framework.

Current folder structure:

- `GoldTradingEA.mq5` = main entry point / controller
- `include/config.mqh` = user input parameters
- `include/evidence.mqh` = reusable evidence item model and shared statuses
- `include/globals.mqh` = shared runtime state
- `include/common.mqh` = helper functions
- `include/version.mqh` = app name and version
- `engine/swing_engine.mqh` = swing detection
- `engine/trend_engine.mqh` = H4 bias / market structure
- `engine/zone_engine.mqh` = H1 zone calculation with swing, fixed, ATR, and lookback validation
- `engine/regime_engine.mqh` = regime detection, confirmation, hysteresis, and active-profile switching
- `engine/structure_engine.mqh` = swing confirmation reasoning
- `engine/momentum_engine.mqh` = simple candle momentum reasoning
- `engine/pressure_guard_engine.mqh` = passive short-term opposing-pressure guard
- `engine/entry_engine.mqh` = final explainable decision maker
- `engine/execution_engine.mqh` = guarded Strategy Tester execution only
- `engine/trade_engine.mqh` = read-only open position and pending order state
- `engine/journal_engine.mqh` = Strategy Tester-only experiment CSV logger
- `engine/draw_engine.mqh` = chart drawing objects
- `engine/dashboard_engine.mqh` = scalable tab dashboard UI and rule debugger

## 3. Core Design Rules

- Main file must not contain business logic.
- Each engine must have a single responsibility.
- Engines should not directly call each other.
- Main controller controls execution order.
- Dashboard must only display data, not calculate trading logic.
- Draw engine must only handle chart objects.
- `ExecutionMode` must default to `TRE_DISPLAY_ONLY`.
- Live chart execution is not allowed.
- Execution Engine is the only module allowed to own order execution.
- Backtest orders require both `TRE_BACKTEST_ONLY` and `MQL_TESTER`.
- `AutoTrade` remains OFF and is not used by Execution Engine.

Important: live charts remain DISPLAY ONLY. Alpha 1.0 may open simulated market orders only inside MT5 Strategy Tester when the user explicitly selects `TRE_BACKTEST_ONLY`. An optional max-holding-bars rule may close matching tester positions only when its separate input is enabled. It must not modify or close live positions, close positions manually, or place pending orders.

## 4. Trading Logic Summary

Current logic:

- H1 is used for zone calculation.
- H1 swing high and H1 swing low are preferred as the zone range source.
- If a valid H1 swing range is not available, the engine uses fallback Highest/Lowest lookback range.
- H4 is used for market bias.
- Zone 1-2 = buy area.
- Zone 3-4 = magnet / TP area.
- Zone 5-6 = sell area.
- Zone 6 = Strong Sell Area.
- Zone 5 = Sell Area.
- Zone 4 = Upper Magnet Area.
- Zone 3 = Lower Magnet Area.
- Zone 2 = Buy Area.
- Zone 1 = Strong Buy Area.
- H4 SELL ONLY + H1 Zone 5/6 = SELL READY.
- H4 BUY ONLY + H1 Zone 1/2 = BUY READY.
- Otherwise WAIT.

Alpha 0.6 adds an Explainable Decision Engine:

- Trend Engine explains market bias and assigns `TrendScore`.
- Zone Engine explains price location and assigns `ZoneScore`.
- Structure Engine explains swing confirmation and assigns `StructureScore`.
- Momentum Engine explains simple candle momentum and assigns `MomentumScore`.
- Entry Engine combines the scores into `TotalScore` and makes the final display-only decision.

Score rules:

- Bullish confirmed trend = 40.
- Bearish confirmed trend = 40.
- Sideway trend = 15.
- Unknown trend = 0.
- Zone 6 = 30.
- Zone 5 = 20.
- Zone 4 = 10.
- Zone 3 = 10.
- Zone 2 = 20.
- Zone 1 = 30.
- Confirmed structure = 20.
- Partial structure = 10.
- Unknown structure = 0.
- Momentum supports entry = 10.
- Momentum neutral = 5.
- Momentum against entry = 0.

Decision rules:

- 80-100 = BUY READY or SELL READY when bias and zone are aligned.
- 60-79 = WATCH.
- 40-59 = WAIT.
- Below 40 = NO TRADE.

Alpha 0.7 expands the dashboard into a Decision Dashboard:

- Market Information
- Market Bias
- Zone Analysis
- Market Structure
- Momentum Analysis
- Confirmation
- Entry Decision
- Why
- Rule Score
- Missing Condition
- Trade Management
- Performance
- Developer Debug

The dashboard should answer what the system sees, why it reached the decision, which rules passed, which rules are waiting, and which conditions are missing. Future rules should fit into the section layout without collapsing the modular architecture.

Alpha 0.8 refactors the dashboard into a tab architecture:

- Summary
- Market
- Zone
- Structure
- Momentum
- Risk
- Pressure
- Decision
- Trade
- Performance
- Debug

Only one tab is expanded at a time. Every tab represents an engine or future engine boundary. The dashboard must render engine output only; it must not become the owner of evaluation logic.

Alpha 1.0 Pressure Guard:

- Pressure Guard is separate from Regime and does not change regime state.
- It scores UP/DOWN pressure from recent candles, EMA, Structure Development,
  and Momentum.
- HIGH opposing pressure can block a ready candidate in BLOCK mode.
- MEDIUM opposing pressure downgrades a candidate to WATCH.
- WARN_ONLY never changes the candidate.
- Pressure Guard never reverses BUY into SELL or SELL into BUY.
- Default scope protects SIDEWAY/UNKNOWN contexts and excludes confirmed active
  UPTREND/DOWNTREND profiles.
- `PressureTF=PERIOD_CURRENT` follows EntryTF.
- Pressure has Overview, Evidence, Decision, and Debug sub-tabs.
- Pressure-blocked and downgraded candidates are exported in Signal CSV rows.
- Pressure Guard contains no order, close, pending-order, or trade-management
  calls.
- Controller order is Swing, Trend, Zone, Structure, Momentum, Regime,
  Pressure Guard, Entry, then guarded Execution.

Alpha 1.0 adds Market Regime Detection and Auto Profile Switching:

- `DetectedRegime` is the current UNKNOWN, SIDEWAY, UPTREND, or DOWNTREND observation.
- `ActiveRegime` is the only profile consumed by Entry Engine's Directional Filter.
- Manual behavior remains unchanged when `UseAutoRegimeDetection=false`.
- Detection can run without switching when `AllowAutoProfileSwitch=false`.
- Switching requires confidence threshold, consecutive confirmation bars, and active-profile hold bars.
- Confirmation and hold counters advance only on new `RegimeTF` bars.
- UPTREND/DOWNTREND scores use swing structure, EMA position/slope, H4 bias, and ATR/trend strength.
- SIDEWAY score uses incomplete directional structure, flat EMA, stable range, middle zone, and non-expanding ATR.
- Scores normalize to 0-100 using only enabled EMA/ATR evidence.
- Regime Engine exposes each evidence item's status, score, maximum, reason, and missing condition.
- Regime Engine also owns best-candidate selection, winning score, score gap, confidence interpretation, raw inputs, and switch before/after snapshots.
- `DetectedRegime=UNKNOWN` can mean below-threshold evidence or a tied/mixed best score; the blocking reason distinguishes these cases.
- Dashboard displays Regime Engine output and performs no regime calculation.
- CSV Parameter and Signal rows expose configuration, detected/best/active regimes, winning score, score gap, confidence, switch status, blocking reason, and switch decision reason.
- Summary uses Overview, Scores, and Details sub-tabs; Overview displays cards only.
- Decision uses Decision, Regime, Uptrend, Downtrend, Sideway, Raw, Switch, and Weights sub-tabs.
- Summary and Decision sub-tab buttons support Strategy Tester polling fallback.
- Dashboard panel height adapts to the active tab/sub-tab so compact views do not cover the full chart.

Default Research Mode:

- `UseAutoRegimeDetection=true` by default.
- `AllowAutoProfileSwitch=false` by default.
- This combination is `AUTO DETECTION SHADOW MODE`.
- Shadow Mode observes, explains, and logs regime output without changing Entry
  decisions or the active profile.
- `ManualMarketProfile` remains the source of `ActiveRegime`.
- Dashboard and CSV expose Market Detection Status, Auto Profile Switch Status,
  Profile Source, detected/best/active regimes, confidence, and blocking reason.
- Default Shadow Mode reports `DETECTED_ONLY` and
  `AUTO_PROFILE_SWITCH_OFF`.
- Detection OFF reports `AUTO_DETECTION_OFF`.

MT5 input persistence diagnostics:

- MT5 stores `input` values per attached EA instance.
- Editing a source default does not overwrite an existing chart instance.
- New attachments or the EA Inputs `Reset` button load source defaults.
- OnInit prints a TRE INPUT CONFIGURATION block and a TRE RUNTIME STATE block.
- Dashboard exposes `Source Code Default`, `Runtime Inputs`, or
  `EA Properties (Saved Instance)` as diagnostic input source.
- Detection OFF shows a yellow reload/reset warning.
- These diagnostics do not alter regime, profile, entry, or execution logic.

Alpha 1.0 Swing Engine integration audit:

- Controller calls Swing Engine before Trend Engine and Structure Engine.
- Swing Engine publishes separate BiasTF and EntryTF swing contexts.
- Trend and Regime consume BiasTF swings; Structure consumes EntryTF swings.
- Confirmed swings require `SwingDepth` bars on both left and right.
- Swing data is loaded with `CopyRates` and `ArraySetAsSeries(true)`.
- Candidate scanning excludes the current forming candle from confirmation.
- Structure tab exposes Swing Debug for both contexts, including bars copied,
  counts, indexes, and no-swing reason.
- Missing swing prices display as `N/A`, not `0.00`.
- `BiasLookbackBars=8` is supported but can be too restrictive to produce two
  confirmed highs and lows when `SwingDepth=2`.

Alpha 1.0 authoritative Structure Engine:

- Swing Engine publishes one confirmed EntryTF pivot sequence for Structure.
- Structure Engine does not consume BiasTF pivots, Market Bias, or Zone state.
- Internal stages are EMPTY, FIRST_SWING, PAIR_READY, STRUCTURE_FORMING,
  CONFIRMED_UPTREND, and CONFIRMED_DOWNTREND.
- One confirmed high plus one confirmed low produces PAIR_READY rather than
  Unknown.
- HH, HL, LH, and LL counts cover the available EntryTF lookback sequence.
- Latest aligned HH + HL confirms uptrend; LH + LL confirms downtrend.
- Mixed latest relationships remain externally Sideway with an explicit
  missing-evidence reason.
- Current price breaks produce separate BOS state; an opposite break against a
  confirmed structure also produces CHOCH state.
- Structure Score remains on the existing 0-20 Entry Engine contract.
- Dashboard and CSV expose stage, counts, pair count, BOS, CHOCH, score,
  confidence, missing evidence, validation stage, and current/previous pivots.
- Stored EntryTF swing sequence is canonical; published counts/current/previous
  values are rebuilt from it after every scan.
- Structure stage reads the published contract only, preventing raw detector
  counts and stored sequence state from diverging.
- Structure Debug exposes detector, stored, and published counts plus mapping
  status and reason.
- Structure Development diagnostics track EntryTF directional candles,
  consecutive bars, recent higher highs/lower lows, higher/lower closes,
  diagnostic EMA 20 position/slope/distance, and pending pivot confirmation.
- Development State, Early Warning, Strong Directional Move, and interpretation
  are diagnostic only; they do not change Structure Score or any decision.
- Structure dashboard sub-tabs are Overview, State, Swing, Development, and
  Debug, with only one visible at a time.
- Structure UX separates Confirmed Structure from Development State.
- Confirmed Structure uses CONFIRMED_UPTREND, CONFIRMED_DOWNTREND, RANGE, or
  UNCONFIRMED; Sideway is never used as an unconfirmed placeholder.
- Display stages are WAITING_FIRST_SWING, WAITING_SWING_PAIR,
  BUILDING_STRUCTURE, WAITING_CONFIRMATION, and CONFIRMED.
- Overview renders human interpretation, refined missing evidence, and progress
  for swing detection, swing pair, structure build, and confirmation.
- Stage 2 UX output does not change swing, structure, BOS, CHOCH, decision, or
  execution rules.
- Signal CSV rows export development pressure and pending swing diagnostics.
- Structure runs after Zone and before Momentum in the current controller; its
  confirmed-state rules remain independent of Zone and Trend outputs.
- Trend, Regime, Entry, Trade, and Execution logic are unchanged by this
  refactor.

Main dashboard tabs are displayed as a vertical side menu on the left. Active tab content renders to the right of the menu so the chart remains easier to inspect.

The dashboard has a toggle button. When hidden, dashboard objects are removed and only a small button labeled with the app name remains so the chart can be inspected more clearly.

The main controller runs analysis from both `OnTick()` and `OnTimer()`. `EngineRefreshSeconds` controls the timer interval, allowing the dashboard and read-only account state to refresh while the market is closed. Market analysis uses the latest available candle and price data until new ticks arrive. Execution Engine is called only from `OnTick()` so timer refreshes cannot send backtest orders or timeout closes.

Alpha 0.9 adds Strategy Tester execution:

- Default mode is `TRE_DISPLAY_ONLY`.
- `TRE_BACKTEST_ONLY` is the only executable mode.
- Execution additionally requires `MQLInfoInteger(MQL_TESTER)`.
- BUY READY and SELL READY may open fixed-lot market orders with configured SL and TP.
- Execution Engine reads symbol volume, tick, point, digits, stops, and freeze constraints before sending.
- Requested lot is normalized to symbol minimum, maximum, and volume step.
- SL/TP distances are auto-adjusted to at least Stops Level plus 10 points.
- Position checks use symbol, `BacktestMagicNumber`, maximum positions, and direction permissions.
- `BacktestOneTradePerBar` prevents repeated attempts from the same chart bar.
- `UseBacktestMaxHoldingBars` defaults to false.
- When enabled, Execution Engine closes a matching tester position at `BarsHeld >= BacktestMaxHoldingBars`.
- Holding bars use `ExecutionTF` and fall back to `EntryTF` only when required history is unavailable.
- Timeout close repeats `TRE_BACKTEST_ONLY`, `MQL_TESTER`, and timeout-enabled guards immediately before `PositionClose`.
- Timeout state is produced by Execution Engine; Dashboard only displays it.
- Only Execution Engine may use `CTrade`.
- Trade Engine remains read-only.
- Summary includes an Execution card.
- Trade tab has Open, Pending, and Execution Monitor sub-tabs.
- Execution Monitor exposes constraints, normalization, validation, throttle, order result, retcode, and error state.
- Debug exposes raw symbol trading constraints.
- Dashboard button state is polled during Tick and Timer cycles as a Strategy Tester Visualization fallback, with tab buttons placed above the panel in click priority.
- Reserved Shadow Journal, Live Manual Approval, and Live Auto modes do not execute.
- `BiasLookbackBars` controls H4 swing detection consumed by Trend/Bias Engine.
- `ZoneLookbackBars` controls H1 swing search and fallback Highest/Lowest range.
- Both research inputs default to 20 and are available to Strategy Tester optimization.
- Lookback values below 3 use an effective minimum of 3 and print a warning.
- Market, Zone, and Debug tabs expose configured or effective lookback values.
- Zone Engine reads ATR from the latest completed candle through an indicator handle.
- ATR validation defaults to ON with period 14, H1 timeframe, minimum multiplier 1.0, and maximum multiplier 5.0.
- Swing validation order is basic price, fixed minimum points, ATR range, then lookback fallback.
- ATR rejects ranges below its minimum or above its maximum relative to current volatility.
- Zone and Debug tabs expose ATR value, points, thresholds, validation result, and fallback reason.
- Zone tab is organized into Input Config, Raw Data, Validation, and Output sections.
- Zone Engine owns raw display values, validation reasons, fallback state, and final output labels.
- Price fields represent price distance; fields ending in Points represent symbol points.
- ATR configuration and raw ATR values display `N/A` when ATR validation is disabled.
- Debug contains a compact Zone block for research diagnostics.
- Alpha 0.9 introduces the reusable `TRE_EvidenceItem` framework.
- Evidence items expose name, status, score, maximum score, reason, and missing condition.
- Trend Engine owns eight initial evidence items: HH, HL, LH, LL, Swing Direction, Market Structure, Trend Strength, and Bias Confirmation.
- Trend Evidence Score is diagnostic on a theoretical 0-80 scale.
- Existing TrendScore remains on the 0-40 Entry Engine contract.
- Market tab renders Trend evidence; Summary renders bias reason and blocking factor.
- Entry Engine owns engine-level PASS, FAIL, and WAIT statuses displayed by Decision tab.
- Zone, Structure, Momentum, Risk, and Execution evidence are future extensions.
- Alpha 0.9 adds Research Weight Controls for Trend, Zone, Structure, and Momentum.
- Entry Engine owns raw-to-weighted conversion, active-weight normalization, statuses, and score formula text.
- Default enabled weights remain 40, 30, 20, and 10, preserving the existing score total.
- Disabled engines contribute 0 / 0 and expose `DISABLED`.
- `AllowZoneOnlyResearchDecision` defaults to false and is active only in Strategy Tester.
- `ZoneOnlyReadyThreshold` defaults to 80.
- Zone-only mode returns BUY READY for passing Zone 1/2 and SELL READY for passing Zone 5/6 at or above threshold.
- Zone 3/4 returns WATCH at or above threshold; lower scores return NO TRADE.
- Zone-only mode explicitly ignores Market Bias and identifies Zone Engine as the decision source.
- Summary and Decision show Bias Ignored/Override, threshold, source, and an orange research warning.
- Ready decisions are logged once per chart bar and zone.
- Summary includes Score Mix and Engine Scores; Decision includes detailed controls and formula.
- `ManualMarketProfile` provides UNKNOWN, UPTREND, SIDEWAY, and DOWNTREND research profiles.
- `UseDirectionalFilter` defaults to false and does not perform automatic market-regime detection.
- UPTREND allows BUY and blocks SELL; DOWNTREND allows SELL and blocks BUY; SIDEWAY and UNKNOWN allow both.
- A blocked ready candidate becomes WATCH and is never converted into the opposite direction.
- Summary and Decision display profile, allowed directions, filter result, reason, and blocking factor.
- Alpha 0.9 adds a Strategy Tester-only Backtest Experiment CSV Logger v2.
- CSV filenames include symbol, market label, manual profile, directional-filter state, all timeframes, lookbacks, ATR settings, SL, TP, holding timeout, and timestamp.
- `BacktestMarketStatus` is normalized once and used by both the filename and the Parameter MarketLabel row.
- CSV files use persistent `FILE_COMMON` storage because Strategy Tester can clear an agent's private Files sandbox between runs.
- Existing experiment files are never overwritten; filename collisions receive `_001`, `_002`, and later suffixes.
- Debug displays the persistent CSV location and complete final filename currently being written.
- CSV sections are Parameter, Signal, Trade Open, Trade Close, Summary, Zone Statistics, and Engine Statistics.
- Parameter rows include version, commit placeholder, date range, risk, validation, research, enabled engines, and weights.
- Parameter and Signal rows include manual profile and directional-filter state; blocked signals retain their original candidate direction.
- Summary counts total, BUY, and SELL signals blocked by the directional filter.
- Parameter rows include max-holding-bars settings and holding timeframe.
- Timeout closes are recorded as `TIMEOUT`; Summary includes timeout close count, average bars held, and maximum bars held.
- Trade rows include planned/realized RR, duration bars, exit reason, profit USD, and engine status snapshots.
- Summary includes largest win/loss, streaks, peak-equity drawdown, and average holding bars.
- Zone 1-6 statistics include counts, closed counts, win rates, and average profit.
- Engine statistics count PASS, FAIL, WAIT, and DISABLED at entry.
- Journal Engine observes positions and deal history without modifying orders.
- Debug exposes CSV filename, counters, last write time, and status.

Alpha 0.8 Trade tab update:

- Trade Engine reads MT5 open positions for the current symbol.
- Trade Engine reads MT5 pending orders for the current symbol.
- Trade Engine reads MT5 account margin level for display-only portfolio health monitoring.
- TAB 8 displays tickets, type, volume, entry, current price, SL, TP, floating P/L, swap, commission placeholder, time, comment, current RR, planned RR, and pending order distance.
- TAB 8 has sub-tabs for open positions and pending orders.
- This is read-only account state display. It must not send, modify, close, or delete trades.

Alpha 0.8 Summary tab update:

- TAB 1 uses large summary cards for decision, signal score, floating P/L, pending order count, current position, short advice, market regime, and margin level.
- Summary cards are for fast reading only. Detailed rule explanations still belong in their engine tabs.

Alpha 0.8 Zone validation update:

- Zone Engine validates detected H1 swing range before using it.
- `UseSwingValidation` controls whether swing validation is active.
- `MinimumSwingRangePoints` controls the minimum acceptable swing size.
- If the swing range is too small or no valid swing exists, Zone Engine falls back to the lookback Highest/Lowest range.
- Alpha 0.9 replaces the ATR placeholder with completed-candle ATR range validation.
- Dashboard displays swing range, minimum range, validation result, fallback used, fallback reason, and selected zone source.

## 5. Risk Philosophy

- The system must prioritize survival before profit.
- Risk per trade is currently planned around 2 USD.
- Future SL should be based on swing structure.
- Lot size should be calculated from risk and SL distance.
- No martingale.
- No revenge trade.
- No averaging loss.

## 6. Development Roadmap

Alpha 0.9:

- Strategy Tester execution mode for rule-validation research
- Double safety guard using execution mode and `MQL_TESTER`
- One backtest position per symbol and magic number
- Fixed lot, SL, TP, magic number, and comment inputs
- Broker-aware volume normalization
- Stops-level SL/TP adjustment and tick-size price alignment
- Configurable position limit and direction permissions
- One-trade-per-bar signal throttle
- Execution Monitor under Trade tab
- Execution status and reasons in Summary and Debug
- Separate Bias and Zone lookback inputs for Zone Research
- Strategy Tester comparison of lookback combinations
- ATR-based swing range validation with volatility-relative minimum and maximum
- Reusable Evidence Scoring Framework with Trend Engine evidence
- Decision tab engine-score and blocker display
- Configurable research engine weights and enable/disable controls
- Summary Score Mix card and engine-score breakdown
- Backtest Experiment CSV export for external research analysis
- Manual market-profile directional filter with blocked-signal CSV statistics
- Backtest max-holding-bars timeout research using ExecutionTF with EntryTF fallback
- No live execution
- No pending order execution
- No user-triggered manual position management

Alpha 1.0:

- Market Regime Engine with separate detected and active profiles
- Optional detection-only mode without automatic switching
- Threshold and confirmation-bar profile switching
- Hold-bar hysteresis to reduce profile flip-flopping
- EMA, ATR, swing, H4 bias, zone, and range evidence
- Per-direction evidence diagnostics and raw Regime Engine inputs
- Regime candidate, score-gap, and profile-switch snapshots in Dashboard and CSV
- Passive Pressure Guard with warning, downgrade, and block research modes
- Pressure main tab, Summary card, and Signal CSV diagnostics
- Horizontal Summary and Decision sub-tabs prevent dashboard overflow
- Manual profile compatibility when auto detection is OFF
- No live-execution expansion

Alpha 0.8:

- Modular architecture
- Tab-based Decision Dashboard and rule debugger
- H1 swing-based zone with lookback fallback
- Zone Source display
- Zone Strength display
- Trend reason and score
- Zone reason and score
- Structure reason and score
- Momentum reason and score
- Entry reason and total score
- Missing condition display
- Parameter and debug display
- One active dashboard tab at a time
- Hide/Show dashboard toggle for full chart inspection
- Read-only Trade tab for current open positions and pending orders
- Big Summary cards for key status, P/L, pending count, and short advice
- Market Regime summary card showing Up, Down, or Sideway
- Margin Level summary card for future crisis/risk decision support
- Timer-based display refresh while the market is closed
- Swing range validation with smart lookback fallback
- Future 50-100 parameter expansion without redesign
- H4 swing bias
- Display-only operation

Next versions:

- Risk engine
- Signal scoring
- Pending order suggestion
- Manual approval mode
- Auto pending only after validation and a separately approved live-execution version

## 7. AI Agent Instructions

When modifying this project:

- Preserve modular architecture.
- Do not collapse files into one file.
- Do not add or expand trade execution unless explicitly requested.
- Keep all order calls inside `engine/execution_engine.mqh`.
- Preserve both `TRE_BACKTEST_ONLY` and `MQL_TESTER` guards.
- Never call Execution Engine from timer refresh.
- Explain all major logic changes.
- Update `README.md` and `context.md` when architecture or rules change.
- Prefer simple, readable MQL5 over clever code.
- Keep the code suitable for MetaEditor compilation.
- Dashboard placeholders must use `N/A` or `WAIT` until the real rule engine exists.
- Dashboard tabs must display engine output and avoid owning business evaluation.
- Dashboard must not calculate evidence status, score, reason, or missing conditions.
- Dashboard must not calculate weighted scores, active totals, or research formulas.
- Trade tab may display read-only output from Trade Engine and Execution Engine diagnostics, but it must never call trading functions.

## 8. Current Philosophy

This project is not just an EA.

It is a Trading Business Rule Engine.

The most valuable asset is not the source code, but the validated trading rules.

## 9. Non-Negotiable Safety Rules

- Never enable `AutoTrade` by default.
- Never change the default `ExecutionMode` from `TRE_DISPLAY_ONLY`.
- Never allow live execution in Alpha 1.0.
- Every order call must be owned by Execution Engine and guarded by both `TRE_BACKTEST_ONLY` and `MQL_TESTER`.
- Timeout position close must additionally require `UseBacktestMaxHoldingBars`.
- `TRE_LIVE_MANUAL_APPROVAL` and `TRE_LIVE_AUTO` must remain non-executable placeholders.
- Do not add pending orders, user-triggered manual closes, break even, or trailing stop behavior in this version.
- Any future trading function must first support:
  - Display only
  - Suggestion only
  - Manual approval
  - Auto execution
- Default mode must always be Display Only or Suggestion Only.

## 10. Current Research Handoff

Use this section as the starting context for ChatGPT or another AI agent.

### Completed Features

- Explainable weighted decisions from Trend, Zone, Structure, and Momentum.
- Alpha 1.0 Regime Engine with separate DetectedRegime and ActiveRegime.
- Optional auto profile switching with threshold, confirmation, and hold-bar hysteresis.
- Zone-only research decisions for Strategy Tester experiments.
- Manual market profiles: UNKNOWN, UPTREND, SIDEWAY, and DOWNTREND.
- Optional directional filter:
  - UPTREND allows BUY and blocks SELL.
  - DOWNTREND allows SELL and blocks BUY.
  - SIDEWAY and UNKNOWN allow both.
- Blocked candidates become WATCH and are recorded in CSV; they are never reversed.
- Optional max-holding-bars timeout exit for backtests.
- Timeout bars use `ExecutionTF`, with `EntryTF` as the history fallback.
- Persistent Backtest Export v2 CSV files with parameters, signals, trades, summary, zone statistics, and engine statistics.
- Dashboard displays requested versus normalized execution lot.

### CSV Location

Backtest CSV files are stored with `FILE_COMMON` under:

`C:\Users\tinnakorn\AppData\Roaming\MetaQuotes\Terminal\Common\Files`

The Strategy Tester agent's private `MQL5\Files` directory is no longer the authoritative export location because MT5 may clear it between runs. Duplicate experiment names receive `_001`, `_002`, and later suffixes.

### Latest Observed Research Configuration

- Symbol: GOLDmicro
- Zone TF: H1
- Bias TF: H4
- Entry TF: M15
- Execution TF: M5
- Zone lookback: 16
- Bias lookback: 8
- ATR validation: ON, period 14, range 1.0-5.0 ATR
- Zone-only decision: ON
- Manual profile: SIDEWAY
- Directional filter: OFF
- SL: 2000 points
- TP: 4000 points
- Max holding timeout: OFF, configured value 24 bars
- Execution mode: Backtest Only

These are observed test inputs, not mandatory defaults.

Alpha 1.0 defaults auto regime detection to ON and auto profile switching to
OFF. This is passive Shadow Mode; the manual profile still controls decisions.
This preserves the manual-profile baseline until a controlled experiment
explicitly enables either feature.

### Important Lot Finding

- The tester input requested `BacktestFixedLot = 0.01`.
- GOLDmicro reported `SYMBOL_VOLUME_MIN = 0.10` and volume step `0.01`.
- Execution Engine therefore normalized `0.01` to `0.10`.
- Historical tester logs from before the timeout update show the same normalization; this is not a timeout regression.
- No actual `0.01` GOLDmicro order was found in the inspected tester logs.
- To execute exactly `0.01`, the selected symbol/account must support minimum volume `0.01`.
- `RiskUSD` is currently research/configuration data and does not calculate execution lot yet. The latest observed test input was `RiskUSD = 4000`, while execution still used fixed-lot normalization.

### CSV Interpretation Notes

- Use the actual `TRADE_OPEN` volume when comparing profit, loss, drawdown, or expectancy.
- Do not assume `BacktestLot` equals the executed volume when it is below broker minimum.
- `MarketLabel` remains UNKNOWN unless `BacktestMarketStatus` is changed in Strategy Tester Inputs.
- Analyze `DetectedRegime` separately from `ActiveRegime`; only ActiveRegime controls Directional Filter.
- Use `BestCandidateRegime`, `WinningScore`, and `ScoreGap` to distinguish weak classification from mixed evidence.
- Inspect the Uptrend, Downtrend, Sideway, Raw, and Switch sub-tabs before changing thresholds; they expose the calculation without moving logic into Dashboard.
- A detected regime does not become active until threshold, confirmation bars, and hold bars pass.
- Tester timestamps can equal the simulated test start; collision suffixes distinguish repeated experiments.
- Timeout exits are internally flagged and written as `TIMEOUT` rather than generic `TESTER_CLOSE`.
- Summary includes directional-filter block counts, timeout close count, average bars held, and maximum bars held.

### Recommended Next Analysis

- Compare profile groups separately: UPTREND, DOWNTREND, and SIDEWAY.
- Compare manual baseline, detection-only, and auto-switch experiments separately.
- Measure switch count, blocking reasons, and performance before and after each active-profile switch.
- Compare timeout OFF, 12, 24, and 48 bars while keeping all other inputs unchanged.
- Compare Profit Factor, Net Profit, Max Drawdown, Average Bars Held, signal count, and trade count.
- Break results down by Zone 1-6 and BUY/SELL direction.
- Normalize comparisons for the actual executed lot of `0.10`.
- Treat `RiskUSD` as non-operative until a dedicated Risk Engine calculates lot from stop distance.

### Verification Status

The latest source compiled in MetaEditor with `0 errors, 0 warnings`. A new Strategy Tester run is required after every compile so MT5 loads the latest `.ex5`.
