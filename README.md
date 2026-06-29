# Trading Rule Engine - Alpha 1.0

Modular refactor of the GoldMicro Zone Dashboard.

## Status

Display Only by default. Simulated market orders are permitted only when
`ExecutionMode` is `TRE_BACKTEST_ONLY` and MT5 confirms the EA is running in
Strategy Tester. Live chart execution is always blocked in this version.

## Installation

Copy the `GoldTradingEA` folder into:

`MQL5/Experts/`

Then open MetaEditor and compile:

`GoldTradingEA.mq5`

Attach the EA to the GOLDmicro chart.

## Architecture

- `GoldTradingEA.mq5` = main entry point
- `include/config.mqh` = user inputs
- `include/evidence.mqh` = reusable evidence item model and shared statuses
- `include/globals.mqh` = shared runtime state
- `include/common.mqh` = common helpers
- `engine/swing_engine.mqh` = swing detection
- `engine/trend_engine.mqh` = market bias from swing structure
- `engine/zone_engine.mqh` = H1 zone calculation with swing, fixed, ATR, and lookback validation
- `engine/regime_engine.mqh` = regime scoring, confirmation, hysteresis, and active-profile switching
- `engine/structure_engine.mqh` = swing confirmation reasoning
- `engine/momentum_engine.mqh` = simple candle momentum reasoning
- `engine/pressure_guard_engine.mqh` = passive opposing-pressure protection
- `engine/entry_engine.mqh` = final explainable decision maker
- `engine/execution_engine.mqh` = guarded Strategy Tester execution only
- `engine/trade_engine.mqh` = read-only position, pending order, and account state
- `engine/journal_engine.mqh` = Strategy Tester-only experiment CSV export
- `engine/draw_engine.mqh` = chart objects
- `engine/dashboard_engine.mqh` = scalable tab dashboard UI

## Safety

`ExecutionMode` defaults to `TRE_DISPLAY_ONLY`. Orders are allowed only when
both conditions are true:

- `ExecutionMode == TRE_BACKTEST_ONLY`
- `MQLInfoInteger(MQL_TESTER)` confirms Strategy Tester runtime

`TRE_LIVE_MANUAL_APPROVAL` and `TRE_LIVE_AUTO` are reserved and behave as
Display Only. The legacy `AutoTrade` input is not used by Execution Engine.
Live charts cannot execute, even when Backtest Only is selected.

`EngineRefreshSeconds` controls the display-only timer refresh interval. The
controller evaluates analysis engines from both `OnTick()` and `OnTimer()`, so
the dashboard and read-only account state continue to refresh when the market
is closed and no price ticks arrive. Order execution and timeout closes are
called from `OnTick()` only. Candle and price analysis still uses the most
recent available market data.

## Alpha 0.9 Strategy Tester Mode

Alpha 0.9 adds research execution inside MT5 Strategy Tester only.

- `TRE_DISPLAY_ONLY` never sends orders.
- `TRE_SHADOW_JOURNAL` is reserved and behaves as Display Only.
- `TRE_BACKTEST_ONLY` can send market orders only inside Strategy Tester.
- Live Manual Approval and Live Auto are reserved and cannot execute.
- BUY READY opens one fixed-lot BUY with configured SL and TP.
- SELL READY opens one fixed-lot SELL with configured SL and TP.
- Requested lot is clamped and rounded to `SYMBOL_VOLUME_MIN`, `MAX`, and `STEP`.
- SL and TP distances are expanded to at least `SYMBOL_TRADE_STOPS_LEVEL + 10` points.
- Order prices are aligned to `SYMBOL_TRADE_TICK_SIZE`.
- Position count, direction rules, and `BacktestMaxPositionsPerSymbol` are checked before sending.
- `BacktestOneTradePerBar` prevents repeated attempts from the same chart bar.
- `UseBacktestMaxHoldingBars` can close a stuck tester position after the configured number of `ExecutionTF` bars.
- Holding-bar calculation falls back to `EntryTF` only when ExecutionTF history is unavailable.
- Timeout close defaults to OFF and is guarded by Backtest Only, Strategy Tester, and the timeout input.
- No pending order, user-triggered manual close, trailing stop, break even, grid, averaging, or martingale logic is implemented.

Backtest inputs:

- `BacktestFixedLot`
- `BacktestSLPoints`
- `BacktestTPPoints`
- `BacktestMagicNumber`
- `BacktestOrderComment`
- `BacktestMaxPositionsPerSymbol`
- `BacktestAllowSameDirectionAdd`
- `BacktestAllowOppositePosition`
- `BacktestOneTradePerBar`
- `UseBacktestMaxHoldingBars`
- `BacktestMaxHoldingBars`

Summary includes a compact Execution card. Trade now has `Open`, `Pending`, and
`Execution` sub-tabs. Execution Monitor displays runtime permission, decision,
requested and normalized lot, broker volume limits, requested and effective
SL/TP distances, stop/freeze levels, position limits, bar throttle state, last
order details, trade retcode, and terminal error. Debug exposes the raw symbol
trading constraints.

### Max Holding Bars Research

The optional timeout rule closes a matching backtest position when
`BarsHeld >= BacktestMaxHoldingBars`. It uses `ExecutionTF`, with `EntryTF` as
a history fallback. Execution Engine owns the close request and repeats all
Backtest Only and Strategy Tester guards immediately before `PositionClose`.
Dashboard only renders the resulting management state.

Trade displays open time, holding timeframe, bars held, threshold, status,
last timeout ticket, and reason. CSV parameters include the timeout switch,
threshold, and holding timeframe. Timeout deals are internally identified as
`TIMEOUT`; Summary reports timeout closes, average bars held, and maximum bars
held. Suggested controlled comparisons are Timeout OFF, 12, 24, and 48 while
other research settings remain unchanged.

Strategy Tester Visualization may not dispatch dashboard clicks through
`OnChartEvent()` like a live chart. Alpha 0.9 also polls each `OBJ_BUTTON`
pressed state during Tick and Timer cycles, allowing main tabs, Trade sub-tabs,
and Hide/Show to remain interactive during visual backtests. Dashboard buttons
use an explicit click priority above the panel background so tab clicks are not
captured by the background object.

### Zone Research Lookbacks

Alpha 0.9 exposes separate Strategy Tester inputs for lookback research:

- `BiasLookbackBars` controls H4 swing detection used by Trend/Bias Engine.
- `ZoneLookbackBars` controls H1 swing search and fallback Highest/Lowest range.
- Both default to `20`.
- Values below `3` are evaluated as `3` and produce a configuration warning.
- MT5 Strategy Tester handles manual combinations and optimization; the EA does not implement its own optimizer.

Market, Zone, and Debug tabs display the configured or effective research
values. The EA prints the research configuration once during initialization.

### ATR Zone Validation

Zone Engine reads ATR from the latest completed `ATRTimeframe` candle using an
MQL5 indicator handle. Validation runs in this order:

1. Swing prices must be positive and Swing High must exceed Swing Low.
2. Swing range points must pass `MinimumSwingRangePoints` when fixed validation is enabled.
3. Swing range must remain between ATR points multiplied by `MinATRMultiplier` and `MaxATRMultiplier`.
4. Invalid swing ranges fall back to the `ZoneLookbackBars` Highest/Lowest range.

Defaults are ATR validation ON, period `14`, timeframe H1, minimum multiplier
`1.0`, maximum multiplier `5.0`, and fixed minimum range `10` points. Zone and
Debug tabs expose ATR value, points, thresholds, result, and fallback reason.
The latest forming candle is not used.

### Zone Dashboard Layout

Alpha 0.9 organizes the Zone tab into four sections:

- Input Config shows the effective research and validation settings.
- Raw Data shows detected swing, ATR, and current price values.
- Validation shows basic, fixed, ATR, and fallback outcomes with an engine-owned reason.
- Output shows the final zone range and labels consumed by Decision Engine.

Price fields such as `Swing Range Price`, `ATR Value Price`, and
`Zone Width Price` are price distances. Fields ending in `Points` are symbol
points. When ATR validation is off, ATR configuration details and raw ATR
values display `N/A`. Debug contains a compact Zone block with the same
engine-produced state.

### Evidence Scoring Framework

Alpha 0.9 introduces reusable `TRE_EvidenceItem` output with:

- Evidence name
- PASS, FAIL, WAIT, DISABLED, or N/A status
- Received and maximum score
- Reason
- Missing condition

Trend Engine is the first implementation. It exposes Higher High, Higher Low,
Lower High, Lower Low, Swing Direction, Market Structure, Trend Strength, and
Bias Confirmation evidence. `TrendEvidenceScore` is diagnostic on a theoretical
0-80 scale. Existing `TrendScore` remains 0-40 and keeps the established Entry
Engine contract.

Market tab displays trend summary and evidence details. Summary shows the short
bias reason and blocking factor. Decision tab displays Entry Engine-owned
status, score, and reason rows for Trend, Zone, Structure, Momentum, and Total.
Future engines can reuse the same evidence structure without moving evaluation
logic into Dashboard.

### Research Weight Controls

Alpha 0.9 allows each decision score to be enabled or disabled independently:

- `UseTrendScore`
- `UseZoneScore`
- `UseStructureScore`
- `UseMomentumScore`

Configured weights default to Trend 40, Zone 30, Structure 20, and Momentum 10.
Entry Engine converts each raw engine score into its weighted contribution and
normalizes the active-weight total to the existing 0-100 decision scale.
Disabled engines contribute `0 / 0` and report `DISABLED`. Default inputs
produce the same totals as the previous 40+30+20+10 calculation.

`AllowZoneOnlyResearchDecision` defaults to false. When enabled inside Strategy
Tester, a passing Zone 1/2 or Zone 5/6 can supply its full configured weight and
provide BUY READY or SELL READY after the normalized score reaches
`ZoneOnlyReadyThreshold`, which defaults to 80. Zone 3/4 returns WATCH at or
above the threshold. Scores below the threshold return NO TRADE. Market Bias is
explicitly ignored only while this tester-only mode is active.

`ManualMarketProfile` and `UseDirectionalFilter` add a manual research filter
without automatic regime detection. UPTREND allows BUY and blocks SELL,
DOWNTREND allows SELL and blocks BUY, while SIDEWAY and UNKNOWN allow both.
The filter defaults to OFF. A blocked ready candidate becomes WATCH; it is
never converted into the opposite direction. Summary and Decision expose the
profile, allowed directions, result, reason, and blocking factor.

## Swing Engine Integration

Swing Engine runs before Trend, Zone, Regime, and Structure in every controller
cycle. It publishes two independent confirmed-swing contexts:

- Bias swings use `BiasTF` and are consumed by Trend Engine and Regime Engine.
- Structure swings use `EntryTF` and are consumed only by Structure Engine.

Both contexts use `CopyRates` with `ArraySetAsSeries(true)`. A candidate swing
must be greater or lower than `SwingDepth` bars on both sides. Candidate shift
starts at `SwingDepth + 1`, so the current forming candle is never used as a
confirmation bar.

`BiasLookbackBars=8` is valid but restrictive. With `SwingDepth=2`, only a
small candidate window remains after left/right confirmation, so two confirmed
highs and two confirmed lows may not exist. This is a data result rather than
automatic proof of an engine failure. The Structure tab exposes bars copied,
confirmation depth, counts, bar indexes, and the exact no-swing reason for both
timeframes. Missing prices display as `N/A` instead of `0.00`.

## Authoritative Market Structure Layer

Structure Engine is the owner of EntryTF market-structure interpretation.
Swing Engine publishes the confirmed EntryTF pivot sequence; Structure Engine
consumes only that sequence and does not read BiasTF swing values, Market Bias,
or Zone state.

Internal stages:

- `EMPTY`: no confirmed EntryTF swing data.
- `FIRST_SWING`: only a high or low side is available.
- `PAIR_READY`: at least one confirmed high and low exist, but a second pair is
  still required for directional comparison.
- `STRUCTURE_FORMING`: two pairs exist but HH/HL or LH/LL are not aligned.
- `CONFIRMED_UPTREND`: latest high and low relationships are HH + HL.
- `CONFIRMED_DOWNTREND`: latest high and low relationships are LH + LL.

The engine counts all HH, HL, LH, and LL relationships available in the
published EntryTF lookback sequence. Current price above the latest confirmed
swing high produces `BULLISH_BOS`; price below the latest confirmed swing low
produces `BEARISH_BOS`. A bullish break against confirmed downtrend structure,
or a bearish break against confirmed uptrend structure, is additionally marked
as CHOCH.

Structure scores retain the existing 0-20 contract consumed by Entry Engine:
EMPTY 0, FIRST_SWING 2, PAIR_READY 5, STRUCTURE_FORMING 10, and confirmed
structure 20. Dashboard and CSV expose stage, evidence counts, swing-pair count,
BOS, CHOCH, confidence, validation stage, missing evidence, and current/previous
pivots. The public state is available to future Trend, Regime, Trade Management,
Invalidation, and replay modules without moving calculation into those modules.

The confirmed EntryTF sequence is the canonical swing source. After every scan,
Swing Engine publishes count, current pivot, previous pivot, and bar index from
that sequence in one mapping step. Structure Engine never mixes raw detector
counts with stored-sequence state. Structure Debug displays detector, stored,
and published counts plus mapping validation so count/value inconsistencies are
visible immediately.

Structure Development diagnostics are observation-only. They measure recent
EntryTF candle direction, consecutive bars, higher highs/lower lows,
higher/lower closes, price relative to a diagnostic EMA 20, EMA slope, and
distance from EMA. They also expose pending high/low candidates and right-bar
confirmation progress. These values produce Development State, Strong
Directional Move, Early Warning, and an interpretation message, but they do
not change Structure Score, confirmed stage, Entry, Regime, Trade, or
Execution behavior.

The Structure dashboard is split into one-visible-at-a-time sub-tabs:

- Overview: confirmed state, score, reason, missing evidence, and warnings.
- State: pair and HH/HL/LH/LL evidence plus BOS and CHOCH.
- Swing: confirmed pivots and pending candidate progress.
- Development: directional pressure and EMA diagnostics.
- Debug: detector/stored/published mapping and Swing Engine inputs.

Signal CSV rows include the same development and pending-candidate fields. The
long Signal row uses an escaped CSV writer so explanations containing commas
remain valid columns.

Structure Stage 2 UX separates confirmed and developing evidence. The
`Confirmed Structure` field displays only `CONFIRMED_UPTREND`,
`CONFIRMED_DOWNTREND`, `RANGE`, or `UNCONFIRMED`; it never uses Sideway as an
unconfirmed placeholder.
Development State remains visible beside it as a first-class diagnostic.
Presentation stage names describe progress: `WAITING_FIRST_SWING`,
`WAITING_SWING_PAIR`, `BUILDING_STRUCTURE`, `WAITING_CONFIRMATION`, and
`CONFIRMED`.

Overview includes human-readable interpretation lines, refined missing
evidence, and four independent progress indicators for Swing Detection, Swing
Pair, Structure Build, and Confirmation. These are presentation outputs derived
from the existing state machine and do not change its rules or scores.

Controller evaluation order is Swing, Trend, Zone, Structure, Momentum,
Regime, Pressure Guard, Entry, and guarded Execution.

## Pressure Guard Engine

Pressure Guard is a short-term protection layer separate from broad Regime
context. It scores bullish and bearish pressure from consecutive EntryTF
candles, higher/lower closes, higher highs/lower lows, EMA position and slope,
Structure Development State, and Momentum direction.

Default mode is `BLOCK`. HIGH opposing pressure can prevent a ready candidate;
MEDIUM opposing pressure downgrades it to WATCH. `WARN_ONLY` records and
displays the conflict without changing the candidate. The guard never creates
an opposite signal. With `PressureBlockOnlyInSidewayOrUnknown=true`, confirmed
UPTREND or DOWNTREND active profiles remain outside guard scope.

`PressureTF=PERIOD_CURRENT` means follow `EntryTF`; another timeframe can be
selected explicitly. Pressure has Overview, Evidence, Decision, and Debug
sub-tabs plus a Summary card. Signal CSV rows include pressure scores, action,
reason, candidate direction, and decision after pressure. Blocked and
downgraded candidates are logged even though their final action is no longer
READY.

Pressure Engine does not send orders, close positions, alter Regime, or manage
trades. Execution remains separately guarded by Backtest Only and
`MQL_TESTER`.

## Alpha 1.0 Regime Engine

Alpha 1.0 separates the observed regime from the profile used by Entry Engine:

- `DetectedRegime` is the highest UPTREND, DOWNTREND, or SIDEWAY score at or above `RegimeSwitchThreshold`.
- `ActiveRegime` is the profile consumed by Directional Filter.
- With `UseAutoRegimeDetection=false`, ActiveRegime remains the manual profile.
- With detection ON and `AllowAutoProfileSwitch=false`, detection is display/log only.
- Auto switching requires threshold, `RegimeConfirmBars`, and `RegimeHoldBars`.
- Confirmation and hold counters advance only on a new `RegimeTF` bar.

UPTREND and DOWNTREND scores combine swing structure, price relative to EMA,
EMA slope, H4 bias, and ATR/trend strength. SIDEWAY combines incomplete
directional structure, flat EMA, stable half-lookback ranges, Zone 3/4, and
non-expanding ATR. Scores normalize to 0-100 using only enabled EMA/ATR
evidence.

## Default Research Mode

Alpha 1.0 runs passive regime research by default:

- Auto regime detection is ON.
- Auto profile switching is OFF.
- The system reports `AUTO DETECTION SHADOW MODE`.
- Shadow Mode observes, explains, and logs market regime without changing
  trading decisions.
- `ManualMarketProfile` remains the active decision profile unless automatic
  profile switching is explicitly enabled.
- H1 regime timeframe and 20-bar lookback
- Three confirmation bars and six hold bars
- Switch threshold 70
- EMA 50 and ATR 14 evidence enabled

In Shadow Mode, Market Detection Status is `ACTIVE`, Auto Profile Switch Status
is `OFF`, Profile Source is `MANUAL`, switch status is `DETECTED_ONLY`, and the
blocking reason is `AUTO_PROFILE_SWITCH_OFF`. Turning detection off reports
`AUTO_DETECTION_OFF`. Neither state changes Execution Engine safeguards.

### Why config defaults do not update an attached EA

MT5 stores `input` values with each attached EA instance. Changing a default in
`config.mqh` changes new attachments and values restored with the Inputs
`Reset` button; it does not overwrite the saved runtime inputs of an EA that is
already attached to a chart.

The startup audit prints both input configuration and resulting regime runtime
state. Dashboard also reports the diagnostic input source:

- `Source Code Default` when regime inputs match project defaults.
- `Runtime Inputs` when the active configuration differs from defaults.
- `EA Properties (Saved Instance)` when the source default enables detection
  but the attached instance still supplies `false`.

When detection is disabled, Summary and Decision show a yellow warning with
instructions to reload the EA or press Reset in EA Inputs. This is diagnostic
only and does not alter regime, profile, entry, or execution logic.

Decision Dashboard displays manual, detected, best-candidate, and active
profiles separately. It also exposes the winning score, score gap, threshold
result, confidence comment, confirmation/hold progress, switch snapshots, raw
EMA/ATR/range values, and every evidence item's status, score, reason, and
missing condition. Entry Engine reads only ActiveRegime; raw DetectedRegime
cannot bypass switching confirmation.

Regime interpretation:

- `DetectedRegime=UNKNOWN` with a best candidate below the threshold means the
  evidence is too weak to classify.
- `BestCandidate=MIXED` means two or more regime scores tied for first place.
- A small `ScoreGap` is reported as mixed confidence even when one score wins.
- `ActiveRegime` can differ from `DetectedRegime` while confirmation or hold
  bars are incomplete, or while automatic switching is disabled.
- `BlockingReason` and the Switch sub-tab explain exactly why a candidate did
  not become active.

To keep the chart visible, Alpha 1.0 splits dense dashboard pages into
horizontal sub-tabs:

- Summary: Overview, Scores, Details
- Decision: Decision, Regime, Uptrend, Downtrend, Sideway, Raw, Switch, Weights
- Trade: Open, Pending, Execution

Summary Overview contains only the large cards. Scores and detailed status are
rendered separately. Decision separates entry/profile output, regime summary,
direction-specific evidence, raw inputs, switching diagnostics, and research
weights. Sub-tab buttons support both normal chart click events and Strategy
Tester button-state polling. The white dashboard panel also resizes to the
active view so compact sub-tabs leave the chart below them visible.

The CSV Signal section records `BestCandidateRegime`, `WinningScore`,
`ScoreGap`, threshold/confidence interpretation, and switch decision reason so
regime changes can be analyzed without reopening MT5.

Summary and Decision show Research Mode, Bias Ignored/Override, Market Bias
Required, Decision Source, ready threshold, and an orange warning. BUY READY
and SELL READY decisions are logged once per chart bar and zone. Outside
Strategy Tester the override is inactive. This setting does not weaken
Execution Engine's separate Backtest Only and `MQL_TESTER` guards.

Summary contains a Score Mix card and compact Engine Scores block. Decision
shows research mode, enabled engines, configured weights, Entry Engine's final
formula, weighted scores, statuses, and reasons.

### Backtest Experiment CSV v2

`EnableBacktestCSVLog` defaults to true but the logger writes only when
`MQLInfoInteger(MQL_TESTER)` confirms Strategy Tester. Live charts never create
the CSV. Files use this experiment-oriented name:

`TRE_EXP_SYM_<Symbol>_MARKET_<Label>_PROFILE_<Profile>_FILTER_<ONOFF>_REG_<ONOFF>_SW_<ONOFF>_ZTF_<ZoneTF>_BTF_<BiasTF>_ENTRY_<EntryTF>_EXEC_<ExecutionTF>_ZLB<n>_BLB<n>_ATR_<ONOFF>_ATR<Period>_ATR<Min>-<Max>_SL<n>_TP<n>_HOLD_<ONOFF><Bars>_<timestamp>.csv`

The file is written with `FILE_COMMON` to the persistent MetaTrader
`Terminal/Common/Files` directory. Tester agents can clear their private
`MQL5/Files` sandbox between runs, so that private directory is not suitable
for collision-safe experiment history. `BacktestMarketStatus` is normalized
once and the same Market Label is used in both the filename and `[PARAMETER]`.
Strategy Tester time can start at the configured test date, so an existing
filename is never overwritten: the logger appends `_001`, `_002`, and so on
until it finds a free name. The Debug tab displays the persistent location and
complete final filename currently being written.

Export v2 uses `[PARAMETER]`, `[SIGNAL]`, `[TRADE_OPEN]`,
`[TRADE_CLOSE]`, `[SUMMARY]`, `[ZONE_STATISTICS]`, and
`[ENGINE_STATISTICS]` markers. Parameters include version, commit placeholder,
market label, date range, timeframes, validation settings, risk, execution,
research mode, enabled engines, weights, and Regime Engine configuration.

Signal rows remain deduplicated per chart bar and direction. Trade rows add
planned/realized risk-reward, duration bars, exit reason, profit USD, and engine
status snapshots. Summary adds largest win/loss, consecutive streaks, peak
equity drawdown, and average holding bars. Zone statistics include entry count,
closed count, win rate, and average profit for Zones 1-6. Engine statistics
count PASS, FAIL, WAIT, and DISABLED at trade entry. Tracked slots are reused
after close, so the logger is not limited to 64 total trades. Debug continues
to show filename, counters, last write, and logger status. Parameter and Signal
rows include the manual market profile and filter state. Blocked BUY/SELL
candidates are logged as WATCH with their original candidate direction and
filter reason. Summary counts total, BUY, and SELL signals blocked by the
directional filter. Timeout parameters are recorded in `[PARAMETER]`,
timeout exits use `TIMEOUT` in `[TRADE_CLOSE]`, and Summary includes timeout
close count plus average and maximum bars held. Signal rows also record
detected/active regimes, confidence, all three regime scores, switch status,
and blocking reason.

## Alpha 0.8 Tab Dashboard

Alpha 0.8 refactors the Decision Dashboard into a scalable tab architecture. Only one tab is expanded at a time, so the Rule Engine can grow toward 50-100 parameters without making the dashboard unreadable.

The main dashboard tabs are displayed as a vertical side menu on the left so the active tab content can stay readable while leaving chart space easier to inspect.

The dashboard has a toggle button. When hidden, the panel, tabs, cards, and text are removed from the chart and only a small button labeled with the app name remains, making it easier to inspect the full graph.

Tabs:

- Summary
- Market
- Zone
- Structure
- Momentum
- Risk
- Decision
- Trade
- Performance
- Debug

The dashboard renders runtime state produced by engines. It must not own trading or evaluation logic. Future engines such as Liquidity, Order Block, FVG, Session, News, and AI Confidence should expose their own data model and then be displayed in a tab without redesigning existing tabs.

Summary tab update:

- TAB 1 now starts with large summary cards for decision, signal score, floating P/L, pending count, current position, short advice, market regime, and margin level.
- Summary cards are intended for quick reading before opening detailed tabs.

Trade tab update:

- `engine/trade_engine.mqh` reads current open positions for the selected symbol.
- `engine/trade_engine.mqh` reads pending orders for the selected symbol.
- `engine/trade_engine.mqh` reads account margin level for display-only portfolio health monitoring.
- TAB 8 has `Open`, `Pending`, and `Execution` sub-tabs.
- TAB 8 displays position, pending order, floating P/L, SL/TP, RR, volume, ticket, type, time, and comment.
- Open and Pending are read-only account state displays.
- Execution is a monitor for the separate Execution Engine; Dashboard never sends orders.

Zone validation update:

- `engine/zone_engine.mqh` validates detected H1 swing range before using it.
- `MinimumSwingRangePoints` controls the minimum acceptable swing size.
- If swing range is too small or no valid swing exists, Zone Engine falls back to the lookback Highest/Lowest range.
- Alpha 0.9 adds ATR-relative minimum and maximum range validation.

## Alpha 0.7 Decision Dashboard

Alpha 0.7 expands the dashboard into a Decision Dashboard and rule debugger. It is designed to answer:

- How the system currently sees the market.
- Why the decision is BUY, SELL, WAIT, WATCH, or NO TRADE.
- Which conditions are still missing.
- How much each rule contributes to the score.
- Which parameters are currently active.

Dashboard sections:

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

Rules that do not have an engine yet are shown as `N/A` or `WAIT`. The dashboard must not invent calculations that are not implemented.

## Alpha 0.6 Explainable Decision Engine

Alpha 0.6 transforms the dashboard from a status display into an Explainable Decision Engine. The engine must show both what the current decision is and why that decision was reached.

Every engine contributes part of the final decision:

- Trend Engine explains H4 market bias and assigns `TrendScore`.
- Zone Engine explains price location and assigns `ZoneScore`.
- Structure Engine explains swing confirmation and assigns `StructureScore`.
- Momentum Engine explains simple candle momentum and assigns `MomentumScore`.
- Entry Engine combines all scores into `TotalScore` and makes the final decision.

Scores:

- Trend confirmed bullish or bearish = 40
- Trend sideway = 15
- Trend unknown = 0
- Zone 6 = 30
- Zone 5 = 20
- Zone 4 = 10
- Zone 3 = 10
- Zone 2 = 20
- Zone 1 = 30
- Structure confirmed = 20
- Structure partial = 10
- Structure unknown = 0
- Momentum supports entry = 10
- Momentum neutral = 5
- Momentum against entry = 0

Decision:

- 80-100 = BUY READY or SELL READY when bias and zone are aligned
- 60-79 = WATCH
- 40-59 = WAIT
- Below 40 = NO TRADE

## Alpha 0.5 Zone Engine

The Zone Engine now prefers a recent H1 swing high and H1 swing low as the range source. Swing-based zones are preferred because they follow recent market structure instead of only using fixed lookback extremes.

If a valid H1 swing range cannot be calculated, the engine falls back to the previous Highest/Lowest lookback range.

Dashboard additions:

- `Zone Source`
- `Zone Strength`

Zone strength labels:

- Zone 6 = Strong Sell Area
- Zone 5 = Sell Area
- Zone 4 = Upper Magnet Area
- Zone 3 = Lower Magnet Area
- Zone 2 = Buy Area
- Zone 1 = Strong Buy Area
