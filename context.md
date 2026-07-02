# Trading Rule Engine - Project Context

## 1. Project Mission

Trading Rule Engine is a Trading Rule Engine Lab.

The goal is to convert human trading experience into measurable, testable, modular business rules. The engine should observe market structure, validate rule behavior, and improve decisions through clear logic.

The first objective is research, learning, and rule validation. The priority is not aggressive profit.

The current direction is broader than a normal EA. The project is becoming a **Trading Rule Research Platform** where every rule can be measured, audited, shadow-tested, and cross-validated before being promoted.

## 2. Current Research Milestone

Current milestone: **Adaptive Rule Validation v1**

Latest accepted experiment: **EXP-003 Adaptive BUY Zone1 Cross Validation**

| Metric | Baseline 1 | EXP-003 |
|---|---:|---:|
| Trades | 267 | 251 |
| Wins | 131 | 127 |
| Losses | 136 | 124 |
| Profit Factor | 0.987 | 1.070 |
| Net Profit | -39.51 USD | +109.20 USD |
| Drawdown | 300.31 USD | 244.86 USD |

Interpretation:

- BUY Zone1 passed Shadow Validation and Cross Validation.
- BUY Zone1 becomes the first approved adaptive rule candidate.
- SELL Zone6 remains rejected/disabled for now because shadow results showed it would have missed profit.
- All other Direction+Zone patterns remain pending.

## 3. Core Philosophy

This project is not just an Expert Advisor.

It is a trading business rule engine.

The source code is replaceable. The validated rules are the real asset.

Every candidate rule should follow this pipeline:

```text
Idea
  ↓
Backtest
  ↓
Shadow Validation
  ↓
Cross Validation
  ↓
Rule Library
  ↓
Core Engine Candidate
```

A rule should not enter the trusted engine only because it looks logical. It must produce evidence.

## 4. Rule Library

### Approved

| Rule ID | Pattern | Rule | Evidence | Status |
|---|---|---|---|---|
| R-0001 | BUY Zone1 | Adaptive block after repeated BUY Zone1 losses | Shadow Validation + EXP-003 Cross Validation | APPROVED |

### Rejected for Now

| Pattern | Reason |
|---|---|
| SELL Zone6 | Shadow result was positive, so blocking would have missed profit in the tested dataset |

### Pending

- BUY Zone2
- BUY Zone3
- BUY Zone4
- BUY Zone5
- BUY Zone6
- SELL Zone1
- SELL Zone2
- SELL Zone3
- SELL Zone4
- SELL Zone5

## 5. Current Architecture

Project type: MT5 / MQL5 modular Expert Advisor framework.

Current project status: **Alpha 1.0**

Folder structure:

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
- `engine/structure_engine.mqh` = EntryTF swing confirmation reasoning
- `engine/momentum_engine.mqh` = candle momentum reasoning
- `engine/pressure_guard_engine.mqh` = passive short-term opposing-pressure guard
- `engine/pressure_execution_block_engine.mqh` = optional permission gate before execution
- `engine/market_snapshot_engine.mqh` = immutable pre-entry market feature payload
- `engine/adaptive_loss_cluster_engine.mqh` = deterministic pattern-scoped loss protection
- `engine/adaptive_shadow_engine.mqh` = research-only blocked-candidate outcome simulation
- `engine/adaptive_loss_cluster_engine_v2_reserved.mqh` = inactive advanced prototype reserved for future research
- `engine/entry_engine.mqh` = final explainable decision maker
- `engine/execution_engine.mqh` = guarded Strategy Tester execution only
- `engine/trade_engine.mqh` = read-only open position and pending order state
- `engine/journal_engine.mqh` = Strategy Tester-only CSV logger
- `engine/research_db_engine.mqh` = fail-open SQLite flight recorder and analytics schema
- `engine/draw_engine.mqh` = chart drawing objects
- `engine/dashboard_engine.mqh` = dashboard UI and rule debugger
- `tre_research_report.py` = read-only HTML/Markdown research report generator

## 6. Engine Responsibility Rules

- Main file must not contain business logic.
- Each engine must have one responsibility.
- Engines should expose state, not own unrelated decisions.
- Dashboard displays engine output only; it must not calculate trading logic.
- Draw Engine handles chart objects only.
- Trade Engine is read-only.
- Execution Engine is the only module allowed to own order execution.
- Research DB records evidence only; it must not control trading.
- Shadow Engine measures hypothetical outcomes only; it must not affect equity, margin, entry, adaptive trigger, or cooldown.

Short version:

```text
Research decides.
Adaptive executes approved runtime rules.
Execution sends orders only in Strategy Tester.
Dashboard only displays.
```

## 7. Non-Negotiable Safety Rules

- Never enable live execution in Alpha 1.0.
- Never change default `ExecutionMode` from `TRE_DISPLAY_ONLY`.
- Orders require both `TRE_BACKTEST_ONLY` and `MQL_TESTER`.
- `TRE_LIVE_MANUAL_APPROVAL` and `TRE_LIVE_AUTO` are reserved and non-executable.
- No pending orders in this version.
- No manual close button behavior in this version.
- No trailing stop in this version.
- No break-even logic in this version.
- No grid.
- No averaging loss.
- No Martingale.
- Adaptive Loss Cluster v1 must not increase lot size.
- Adaptive Loss Cluster v1 must not create a global stop-trading state.
- Adaptive Rule Validation may only allow or reject a detected Direction+Zone activation.
- Adaptive Rule Validation must not rewrite its own inputs at runtime.

## 8. Current Trading Logic Summary

Current default research logic:

- H1 is used for zone calculation.
- H4 is used for bias.
- M15 is the entry timeframe.
- M5 is the execution/holding timeframe.
- Zone 1-2 = buy area.
- Zone 3-4 = magnet / TP area.
- Zone 5-6 = sell area.
- Zone-only research decision is currently used in the active research flow.
- `UseZoneScore=true` is required for the current entry candidate generation.
- Trend, Structure, and Momentum scoring can remain disabled in controlled zone research.

Zone labels:

- Zone 1 = Strong Buy Area
- Zone 2 = Buy Area
- Zone 3 = Lower Magnet Area
- Zone 4 = Upper Magnet Area
- Zone 5 = Sell Area
- Zone 6 = Strong Sell Area

## 9. Adaptive Loss Cluster v1 Pure

Adaptive v1 is deliberately simple.

It uses only:

- Direction
- Zone

It does not use:

- Pressure
- EMA
- ADX
- similarity score
- feature weighting
- modal matching
- ML
- self-learning

Trigger:

```text
Loss
Loss
Loss
    ↓
Same Direction + Same Zone?
    ↓
Rule Validation Approved?
    ↓
Activate cooldown block for that exact pattern
```

Example:

```text
BUY Zone1 Loss
BUY Zone1 Loss
BUY Zone1 Loss
    ↓
BUY Zone1 approved
    ↓
Block BUY Zone1 for 20 EntryTF bars
```

Rejected pattern example:

```text
SELL Zone6 Loss
SELL Zone6 Loss
SELL Zone6 Loss
    ↓
SELL Zone6 not approved
    ↓
Ignore, no cooldown, no episode, no shadow trade
```

## 10. Adaptive Measurement Terms

Use these terms carefully:

- **Evaluation** = filter was evaluated.
- **Candidate Signal** = normal strategy and risk gates produced a real order candidate before Adaptive.
- **Blocked Opportunity** = a valid candidate was blocked by Adaptive.
- **Executed Trade** = order was accepted by the tester/broker.
- **Episode** = one full adaptive lifecycle: activate → blocked opportunities → expire.
- **Reduced Trades** = Baseline trade count minus Adaptive trade count. This is separate from blocked opportunities.
- **Shadow Trade** = research-only simulation of a blocked opportunity.

Blocked opportunities are not automatically equal to reduced trades.

## 11. Research DB Status

Current schema: **v9**

Main capabilities:

- deterministic signal/trade attribution
- immutable `trade_market_snapshot` per executed TradeID
- fixed SL/TP result audit
- trade outlier views
- weekend gap view
- adaptive episode lifecycle table
- adaptive shadow trade table
- adaptive metrics views
- pattern shadow result views

Important views:

- `v_experiment_summary`
- `v_trade_distribution`
- `v_trade_anomaly`
- `vw_trade_outlier_analysis`
- `vw_trade_outlier_summary`
- `vw_trade_execution_quality`
- `vw_trade_weekend_gap`
- `vw_adaptive_loss_cluster_metrics`
- `vw_adaptive_episode_summary`
- `vw_adaptive_episode_detail`
- `vw_adaptive_pattern_summary`
- `vw_adaptive_shadow_summary`
- `vw_adaptive_episode_shadow_result`
- `vw_adaptive_pattern_shadow_result`

## 12. Latest Observed Research Configuration

Observed from EXP-003:

| Parameter | Value |
|---|---:|
| Symbol | GOLDmicro |
| Date range | 2026.04.02 00:00:00 → 2026.05.01 23:57:59 |
| Execution mode | Backtest Only |
| Manual profile | SIDEWAY |
| Zone TF | H1 |
| Bias TF | H4 |
| Entry TF | M15 |
| Execution TF | M5 |
| Zone lookback | 16 |
| Bias lookback | 8 |
| ATR validation | ON |
| ATR period | 14 |
| ATR min/max | 1.0 / 5.0 |
| Fixed lot input | 1.0 |
| SL | 2000 points |
| TP | 4000 points |
| Magic number | 8808 |
| Max holding bars | ON, 24 |
| Weekend Protection | ON |
| Weekend block/close | Friday >= 23:00 |
| UseTrendScore | false |
| UseZoneScore | true |
| UseStructureScore | false |
| UseMomentumScore | false |
| UsePressureExecutionBlock | false |
| PressureExecutionBlockMode | SHADOW |
| EnableAdaptiveLossCluster | true |
| LossClusterThreshold | 3 |
| LossClusterCooldownBars | 20 |
| AdaptiveClusterMode | SIMPLE_DIRECTION_ZONE |
| UseAdvancedAdaptiveCluster | false |
| AdaptiveEnableBUYZone1 | true |
| All other AdaptiveEnable inputs | false |

## 13. Current Development Roadmap

### Immediate

- Keep BUY Zone1 as approved adaptive pattern.
- Test the next pattern one at a time.
- Do not enable multiple new patterns together before validation.
- Update `RESEARCH_HISTORY.md` after each experiment.

### Near Term

- Build Rule Library table in code or DB.
- Add experiment naming discipline.
- Add easier report export for adaptive episode and shadow results.

### Later

- Risk engine based on actual SL distance.
- Position sizing from risk, not fixed lot.
- Trade management research.
- Additional regime/profile cross validation.
- Future ML only after the feature warehouse is large enough.

## 14. AI Agent Instructions

When modifying this project:

- Preserve modular architecture.
- Do not collapse files into one file.
- Do not expand execution capability unless explicitly requested.
- Keep all order calls inside `engine/execution_engine.mqh`.
- Preserve both `TRE_BACKTEST_ONLY` and `MQL_TESTER` guards.
- Never call Execution Engine from timer refresh.
- Dashboard must not own business logic.
- Dashboard placeholders must use `N/A` or `WAIT` until the real engine exists.
- Prefer simple, readable MQL5 over clever code.
- Keep the project compile-clean in MetaEditor.
- Update README, context, CHANGELOG, and RESEARCH_HISTORY when architecture or research status changes.
