# Project Handoff - Trading Rule Engine Alpha 1.0

## Current State

Trading Rule Engine is now a research platform for validating trading rules, not only an EA.

Latest major milestone:

- EXP-003 Adaptive BUY Zone1 cross validation passed.
- BUY Zone1 is approved as Rule R-0001.
- SELL Zone6 remains disabled/rejected for now.

## Must Preserve

- Live execution blocked.
- `ExecutionMode` default remains `TRE_DISPLAY_ONLY`.
- Orders only in Strategy Tester with `TRE_BACKTEST_ONLY` and `MQL_TESTER`.
- Adaptive v1 uses Direction + Zone only.
- Advanced adaptive similarity remains inactive.
- Shadow trades are measurement only.
- Research DB must never control trading.

## Approved Rule

```text
R-0001: Adaptive BUY Zone1
Trigger: repeated BUY Zone1 losses
Threshold: 3
Cooldown: 20 EntryTF bars
Validation: approved
```

## Current Important Inputs

```text
EnableAdaptiveLossCluster = true
LossClusterThreshold = 3
LossClusterCooldownBars = 20
AdaptiveClusterMode = SIMPLE_DIRECTION_ZONE
UseAdvancedAdaptiveCluster = false
AdaptiveEnableBUYZone1 = true
All other AdaptiveEnableBUY/SELL Zone inputs = false
UseZoneScore = true
UseTrendScore = false
UseStructureScore = false
UseMomentumScore = false
EnableWeekendProtection = true
WeekendBlockDay = Friday
WeekendBlockHour = 23
WeekendForceCloseHour = 23
```

## Latest Experiment Numbers

```text
Baseline 1:
Trades = 267
PF = 0.987
Net = -39.51 USD

EXP-003:
Trades = 251
PF = 1.070
Net = +109.20 USD

Improvement = +148.71 USD
```

## Next Work

- Test next pattern one at a time.
- Keep BUY Zone1 enabled as approved baseline candidate.
- Do not enable SELL Zone6 by default.
- Continue writing every experiment into `RESEARCH_HISTORY.md`.
