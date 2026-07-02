# Research History

This file records controlled experiments for Trading Rule Engine.

The purpose is to preserve not only what changed, but why the change was accepted or rejected.

## Research Method

Every candidate rule should follow this evidence path:

```text
Idea
  ↓
Backtest
  ↓
Shadow Validation
  ↓
Cross Validation
  ↓
Rule Library Decision
```

Do not promote a rule only because it looks logical. Promote it only when the evidence supports it.

## Experiment Index

| Experiment | Rule / Change | Dataset | Status |
|---|---|---|---|
| EXP-001 | Baseline 1 | BaseLine1.db | Reference |
| EXP-002 | Weekend Protection | Validation Rev3 / Rev4 | Passed |
| EXP-003 | Adaptive BUY Zone1 | EXP3-Adaptive-BUY-Zone1.db | Approved |

## EXP-001 - Baseline 1

### Purpose

Create a clean comparison baseline before adaptive rule validation.

### Result

| Metric | Value |
|---|---:|
| Trades | 267 |
| Wins | 131 |
| Losses | 136 |
| Win Rate | 49.06% |
| Profit Factor | 0.987 |
| Net Profit | -39.51 USD |
| Drawdown | 300.31 USD |
| Average MAE | 1261.28 |
| Average MFE | 1489.35 |
| Average Holding | 19.17 |

### Status

Reference baseline.

## EXP-002 - Weekend Protection

### Purpose

Remove abnormal Friday-to-Monday / multi-day weekend gap outliers.

### Rule

- Block new entries on Friday broker/server time from 23:00.
- Force-close matching EA symbol/magic tester position from Friday 23:00.
- Apply only in Strategy Tester execution mode.

### Observed Result

| Metric | Before | After |
|---|---:|---:|
| Trades | 267 | 263 |
| Weekend Gap Outliers | 2 | 0 |
| Total Outliers | 3 | 1 |

### Interpretation

Weekend Protection reduced abnormal execution outliers with small trade-count cost.

### Status

Passed as a core safety filter for research backtests.

## EXP-003 - Adaptive BUY Zone1 Cross Validation

### Purpose

Validate whether BUY Zone1, discovered through Adaptive Shadow research, improves performance on Baseline 1 when it is the only approved adaptive pattern.

### Rule Under Test

```text
If repeated losses occur in BUY Zone1
and BUY Zone1 is approved by Rule Validation,
activate Adaptive Loss Cluster cooldown for BUY Zone1 only.
```

### Configuration

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
| Weekend schedule | Friday >= 23:00 |
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
| AdaptiveEnableBUYZone2-6 | false |
| AdaptiveEnableSELLZone1-6 | false |

### Performance Comparison

| Metric | Baseline 1 | EXP-003 | Change |
|---|---:|---:|---:|
| Trades | 267 | 251 | -16 |
| Wins | 131 | 127 | -4 |
| Losses | 136 | 124 | -12 |
| Profit Factor | 0.987 | 1.070 | +0.083 |
| Net Profit | -39.51 USD | +109.20 USD | +148.71 USD |
| Drawdown | 300.31 USD | 244.86 USD | -55.45 USD |
| Average MAE | 1261.28 | 1199.84 | -61.43 |
| Average MFE | 1489.35 | 1441.27 | -48.07 |
| Average Holding | 19.17 | 19.80 | +0.62 |

### Adaptive Metrics

| Metric | Value |
|---|---:|
| Total evaluations | 299,972 |
| Candidate signals | 308 |
| Blocked opportunities | 54 |
| Executed trades | 251 |
| Activation count | 5 |
| Expire count | 5 |
| Block rate vs candidate signals | 17.53% |
| Blocked direction | BUY |
| Blocked zone | 1 |

### Episode Metrics

| Metric | Value |
|---|---:|
| Total episodes | 5 |
| Active episodes | 0 |
| Expired episodes | 5 |
| Total blocked opportunities | 54 |
| Average blocked opportunities per episode | 10.8 |
| Maximum blocked opportunities per episode | 14 |
| BUY Zone1 episodes | 5 |
| Most frequent pattern | BUY Zone1 |
| Most blocked pattern | BUY Zone1 |

### Shadow Outcome

| Metric | Value |
|---|---:|
| Shadow trades | 54 |
| Closed shadow trades | 54 |
| Open shadow trades | 0 |
| Shadow wins | 22 |
| Shadow losses | 32 |
| Shadow net profit | -123.10 USD |
| Shadow gross profit | 432.25 USD |
| Shadow gross loss | 555.35 USD |
| Shadow profit factor | 0.778 |
| Average shadow profit | -2.28 USD |
| Average shadow holding bars | 14.81 |
| Average shadow holding minutes | 77.39 |
| Estimated adaptive benefit | +123.10 USD |
| Good block episodes | 3 |
| Bad block episodes | 2 |

### Decision

BUY Zone1 is approved as the first adaptive rule.

Rule ID: **R-0001**

Status: **APPROVED**

Reason:

- Cross validation improved net profit from -39.51 USD to +109.20 USD.
- Profit Factor improved from 0.987 to 1.070.
- Loss count reduced from 136 to 124.
- Shadow outcome showed that blocked BUY Zone1 opportunities would have lost -123.10 USD.

## Current Rule Library

### Approved

| Rule ID | Pattern | Status | Evidence |
|---|---|---|---|
| R-0001 | BUY Zone1 | APPROVED | Shadow Validation + EXP-003 Cross Validation |

### Rejected for Now

| Pattern | Status | Reason |
|---|---|---|
| SELL Zone6 | REJECTED FOR NOW | Previous shadow result was positive; blocking would have missed profit |

### Pending

| Pattern | Status |
|---|---|
| BUY Zone2 | PENDING |
| BUY Zone3 | PENDING |
| BUY Zone4 | PENDING |
| BUY Zone5 | PENDING |
| BUY Zone6 | PENDING |
| SELL Zone1 | PENDING |
| SELL Zone2 | PENDING |
| SELL Zone3 | PENDING |
| SELL Zone4 | PENDING |
| SELL Zone5 | PENDING |

## Next Recommended Experiments

Run one pattern at a time. Do not enable multiple new patterns together before validation.

Suggested sequence:

1. SELL Zone6 isolated retest, because current evidence is mixed/rejected.
2. BUY Zone2 isolated validation.
3. SELL Zone5 isolated validation.
4. BUY Zone6 isolated validation.
5. Multi-pattern test only after at least two patterns are individually approved.

Each experiment should update:

- `RESEARCH_HISTORY.md`
- `CHANGELOG.md`
- `README.md` current milestone if the status changes
- Research DB archive
