# Trading Rule Engine

Trading Rule Engine is a modular MT5 / MQL5 research platform for converting discretionary trading experience into measurable, testable, and reproducible trading rules.

The goal is not immediate aggressive profit. The goal is to build a validated rule library through repeatable evidence: backtest, audit, shadow outcome, cross validation, and controlled promotion into the runtime engine.

## Current Status

- Project status: **Alpha 1.0**
- Current focus: **Adaptive Rule Validation**
- Current validated adaptive rule: **BUY Zone1**
- Current research schema: **SQLite schema v9**
- Latest compile status: **0 errors, 0 warnings**
- Live execution: **not allowed**
- Strategy Tester execution: allowed only when `ExecutionMode == TRE_BACKTEST_ONLY` and MT5 confirms `MQL_TESTER`

## Latest Research Milestone

### EXP-003: Adaptive BUY Zone1 Cross Validation

This experiment validates whether the previously discovered BUY Zone1 adaptive pattern still improves performance when tested against the clean Baseline 1 dataset.

| Metric | Baseline 1 | EXP-003 Adaptive BUY Zone1 | Change |
|---|---:|---:|---:|
| Trades | 267 | 251 | -16 |
| Wins | 131 | 127 | -4 |
| Losses | 136 | 124 | -12 |
| Profit Factor | 0.987 | 1.070 | +0.083 |
| Net Profit | -39.51 USD | +109.20 USD | +148.71 USD |
| Drawdown | 300.31 USD | 244.86 USD | -55.45 USD |

Result: **BUY Zone1 is the first approved adaptive rule candidate.**

The key point is not only that the result improved. The important milestone is that the rule passed a first cross-validation flow:

```text
Shadow Validation
        ↓
Cross Validation
        ↓
Rule Library Approval
```

## Research Philosophy

Every new trading rule must pass an evidence pipeline before it becomes a trusted part of the system.

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

The most valuable asset of this project is not the source code. The most valuable asset is the validated trading rule library.

## Runtime Safety

`ExecutionMode` defaults to `TRE_DISPLAY_ONLY`.

Orders are allowed only when both conditions are true:

- `ExecutionMode == TRE_BACKTEST_ONLY`
- `MQLInfoInteger(MQL_TESTER)` confirms Strategy Tester runtime

Reserved live modes remain non-executable in Alpha 1.0:

- `TRE_LIVE_MANUAL_APPROVAL`
- `TRE_LIVE_AUTO`

The legacy `AutoTrade` input is not used by Execution Engine. Live charts cannot execute orders in this version.

## Current Architecture

```text
GoldTradingEA.mq5
    ↓
Swing Engine
    ↓
Trend Engine
    ↓
Zone Engine
    ↓
Regime Engine
    ↓
Structure Engine
    ↓
Momentum Engine
    ↓
Pressure Guard
    ↓
Entry Engine
    ↓
Weekend Protection
    ↓
Adaptive Loss Cluster
    ↓
Market Snapshot
    ↓
Execution Engine
    ↓
Trade Engine / Journal / Research DB
    ↓
Dashboard
```

## Main Modules

- `GoldTradingEA.mq5` — main controller
- `include/config.mqh` — user inputs
- `include/evidence.mqh` — reusable evidence model
- `include/globals.mqh` — shared runtime state
- `include/common.mqh` — helpers
- `include/version.mqh` — app name and version
- `engine/swing_engine.mqh` — confirmed swing detection
- `engine/trend_engine.mqh` — market bias from higher timeframe structure
- `engine/zone_engine.mqh` — H1 zone calculation with swing, ATR, and fallback validation
- `engine/regime_engine.mqh` — detected/active regime and optional profile switching
- `engine/structure_engine.mqh` — EntryTF structure and BOS/CHOCH interpretation
- `engine/momentum_engine.mqh` — candle momentum reasoning
- `engine/pressure_guard_engine.mqh` — passive short-term opposing-pressure guard
- `engine/pressure_execution_block_engine.mqh` — optional pressure permission gate
- `engine/entry_engine.mqh` — explainable final decision maker
- `engine/execution_engine.mqh` — Strategy Tester-only guarded order execution
- `engine/adaptive_loss_cluster_engine.mqh` — deterministic Direction+Zone adaptive filter
- `engine/adaptive_shadow_engine.mqh` — research-only blocked-candidate outcome simulation
- `engine/market_snapshot_engine.mqh` — immutable pre-entry feature capture
- `engine/research_db_engine.mqh` — SQLite research flight recorder and analytics views
- `engine/dashboard_engine.mqh` — scalable dashboard UI
- `tre_research_report.py` — read-only research report generator

## Adaptive Loss Cluster v1 Pure

Adaptive v1 is intentionally simple and deterministic.

It uses only:

- Direction
- Zone

It does not use:

- Pressure similarity
- EMA similarity
- modal similarity
- weighted feature similarity
- self-learning
- lot increase
- Martingale
- global trading stop

When repeated losses occur in the same Direction+Zone pair, the system checks Rule Validation before activation. Only approved patterns are allowed to create a cooldown block.

Current default approved pattern:

- `BUY Zone1 = true`

Current default rejected or disabled patterns:

- `BUY Zone2` through `BUY Zone6 = false`
- `SELL Zone1` through `SELL Zone6 = false`

SELL Zone6 is disabled because Shadow Validation showed it would have missed profitable trades in the tested dataset.

## EXP-003 Configuration Snapshot

Observed from `EXP3-Adaptive-BUY-Zone1.db`.

| Parameter | Value |
|---|---:|
| Symbol | GOLDmicro |
| Test range | 2026.04.02 00:00:00 → 2026.05.01 23:57:59 |
| Manual profile | SIDEWAY |
| Zone TF | H1 |
| Bias TF | H4 |
| Entry TF | M15 |
| Execution TF | M5 |
| Zone lookback | 16 |
| Bias lookback | 8 |
| ATR validation | ON |
| ATR period | 14 |
| ATR range | 1.0 – 5.0 ATR |
| Execution mode | Backtest Only |
| Fixed lot input | 1.0 |
| SL | 2000 points |
| TP | 4000 points |
| Max holding bars | ON, 24 bars |
| Weekend Protection | ON, Friday >= 23:00 |
| UseTrendScore | false |
| UseZoneScore | true |
| UseStructureScore | false |
| UseMomentumScore | false |
| EnableAdaptiveLossCluster | true |
| LossClusterThreshold | 3 |
| LossClusterCooldownBars | 20 |
| AdaptiveClusterMode | SIMPLE_DIRECTION_ZONE |
| UseAdvancedAdaptiveCluster | false |
| AdaptiveEnableBUYZone1 | true |
| All other adaptive pattern approvals | false |

## Research Database

The SQLite Research DB is a fail-open flight recorder. It must not block the EA if write errors occur.

Current schema capabilities:

- deterministic signal/trade attribution
- immutable pre-entry market snapshots
- fixed SL/TP result audit
- trade distribution analytics
- pressure and execution analytics
- trade outlier analysis
- adaptive episode lifecycle analytics
- adaptive shadow outcome analytics

Important views include:

- `v_experiment_summary`
- `v_trade_distribution`
- `v_trade_anomaly`
- `vw_trade_outlier_analysis`
- `vw_trade_execution_quality`
- `vw_trade_weekend_gap`
- `vw_adaptive_loss_cluster_metrics`
- `vw_adaptive_episode_summary`
- `vw_adaptive_episode_detail`
- `vw_adaptive_pattern_summary`
- `vw_adaptive_shadow_summary`
- `vw_adaptive_episode_shadow_result`
- `vw_adaptive_pattern_shadow_result`

## Rule Library Status

| Pattern | Status | Evidence |
|---|---|---|
| BUY Zone1 | APPROVED | Shadow Validation + Cross Validation |
| SELL Zone6 | REJECTED FOR NOW | Shadow showed missed profit |
| All other Direction+Zone patterns | PENDING | Not yet validated |

## Installation

Copy the `GoldTradingEA` folder into:

```text
MQL5/Experts/
```

Then open MetaEditor and compile:

```text
GoldTradingEA.mq5
```

Attach the EA to the GOLDmicro chart.

## Development Rule

Every material code change should be paired with a research result when possible:

```text
Code Change
    ↓
Backtest
    ↓
Research DB
    ↓
README Update
    ↓
CHANGELOG Update
    ↓
RESEARCH_HISTORY Update
    ↓
Git Commit
```
