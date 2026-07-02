# Changelog

All notable project changes are documented here.

This project tracks both code changes and research evidence because the goal is not only to build an EA, but to build a validated trading rule engine.

## [Alpha 1.0] - 2026-07-02

### Added

- Adaptive Loss Cluster Filter v1 Pure.
- Static Rule Validation Layer v1.
- Direction+Zone-only adaptive pattern approval.
- Adaptive episode lifecycle tracking.
- Adaptive shadow trade measurement.
- Adaptive pattern shadow result views.
- Immutable market snapshot table for pre-entry feature capture.
- Trade outlier forensics views.
- Weekend Protection entry block and forced tester close.
- Research History documentation file.

### Changed

- Adaptive architecture was simplified from an advanced similarity prototype to a deterministic v1 runtime rule.
- Adaptive v1 now evaluates only:
  - Direction
  - Zone
- Rule Validation now decides whether a detected Direction+Zone cluster is allowed to activate.
- Advanced adaptive feature similarity remains reserved and inactive.
- Dashboard wording separates blocked opportunities from reduced trades.
- Adaptive metrics now separate:
  - evaluations
  - candidate signals
  - blocked opportunities
  - executed trades
  - activations
  - expiries
  - episodes
  - shadow outcomes

### Disabled / Reserved

The following are not used by Adaptive v1:

- Pressure similarity
- EMA similarity
- modal similarity
- feature weighting
- trend score matching
- structure score matching
- momentum score matching
- automatic self-learning
- lot increase
- global stop trading

The previous advanced prototype is reserved for future research and must not affect v1 runtime behavior.

### Safety

- Live execution remains blocked.
- Orders are allowed only inside Strategy Tester with `TRE_BACKTEST_ONLY` and `MQL_TESTER`.
- Reserved live modes remain non-executable.
- No Martingale, grid, averaging loss, pending order, trailing stop, or break-even behavior was added.

## Research Change: EXP-003 Adaptive BUY Zone1

### Purpose

Validate whether the BUY Zone1 adaptive pattern still improves performance when tested against Baseline 1.

### Configuration

| Parameter | Value |
|---|---:|
| EnableAdaptiveLossCluster | true |
| LossClusterThreshold | 3 |
| LossClusterCooldownBars | 20 |
| AdaptiveClusterMode | SIMPLE_DIRECTION_ZONE |
| UseAdvancedAdaptiveCluster | false |
| AdaptiveEnableBUYZone1 | true |
| AdaptiveEnableBUYZone2-6 | false |
| AdaptiveEnableSELLZone1-6 | false |
| UseTrendScore | false |
| UseZoneScore | true |
| UseStructureScore | false |
| UseMomentumScore | false |
| EnableWeekendProtection | true |
| WeekendBlockDay | Friday |
| WeekendBlockHour | 23 |
| WeekendForceCloseHour | 23 |
| SL | 2000 points |
| TP | 4000 points |
| Manual profile | SIDEWAY |
| Zone TF | H1 |
| Bias TF | H4 |
| Entry TF | M15 |
| Execution TF | M5 |

### Result

| Metric | Baseline 1 | EXP-003 | Change |
|---|---:|---:|---:|
| Trades | 267 | 251 | -16 |
| Wins | 131 | 127 | -4 |
| Losses | 136 | 124 | -12 |
| Profit Factor | 0.987 | 1.070 | +0.083 |
| Net Profit | -39.51 USD | +109.20 USD | +148.71 USD |
| Drawdown | 300.31 USD | 244.86 USD | -55.45 USD |

### Adaptive Metrics

| Metric | Value |
|---|---:|
| Total evaluations | 299,972 |
| Candidate signals | 308 |
| Blocked opportunities | 54 |
| Executed trades | 251 |
| Activations | 5 |
| Expiries | 5 |
| Block rate vs candidates | 17.53% |

### Episode Metrics

| Metric | Value |
|---|---:|
| Total episodes | 5 |
| Expired episodes | 5 |
| Total blocked opportunities | 54 |
| Average blocked opportunities per episode | 10.8 |
| Maximum blocked opportunities per episode | 14 |
| Most frequent pattern | BUY Zone1 |
| Most blocked pattern | BUY Zone1 |

### Shadow Metrics

| Metric | Value |
|---|---:|
| Shadow trades | 54 |
| Shadow wins | 22 |
| Shadow losses | 32 |
| Shadow net profit | -123.10 USD |
| Shadow profit factor | 0.778 |
| Estimated adaptive benefit | +123.10 USD |
| Good block episodes | 3 |
| Bad block episodes | 2 |

### Conclusion

BUY Zone1 is approved as **Rule R-0001**.

This approval is based on:

- prior shadow validation
- EXP-003 cross validation
- improved PF
- improved net profit
- reduced loss count
- positive estimated adaptive benefit

SELL Zone6 remains disabled because previous shadow evidence showed it would have missed profit.

## Documentation

### Added

- `RESEARCH_HISTORY.md`

### Revised

- `README.md`
- `context.md`
- `CHANGELOG.md`

The documentation now treats the project as a Trading Rule Research Platform rather than a simple EA.
