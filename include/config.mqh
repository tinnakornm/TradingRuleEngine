//+------------------------------------------------------------------+
//| include/config.mqh                                               |
//| User configurable parameters                                     |
//+------------------------------------------------------------------+
#ifndef TRE_CONFIG_MQH
#define TRE_CONFIG_MQH

enum ENUM_TRE_EXECUTION_MODE
{
   TRE_DISPLAY_ONLY = 0,
   TRE_SHADOW_JOURNAL = 1,
   TRE_BACKTEST_ONLY = 2,
   TRE_LIVE_MANUAL_APPROVAL = 3,
   TRE_LIVE_AUTO = 4
};

enum ENUM_TRE_MARKET_PROFILE
{
   TRE_PROFILE_UNKNOWN = 0,
   TRE_PROFILE_UPTREND = 1,
   TRE_PROFILE_SIDEWAY = 2,
   TRE_PROFILE_DOWNTREND = 3
};

enum TRE_PRESSURE_DIRECTION
{
   PRESSURE_NONE = 0,
   PRESSURE_UP = 1,
   PRESSURE_DOWN = 2
};

enum TRE_PRESSURE_LEVEL
{
   PRESSURE_LOW = 0,
   PRESSURE_MEDIUM = 1,
   PRESSURE_HIGH = 2
};

enum TRE_PRESSURE_ACTION
{
   PRESSURE_ALLOW = 0,
   PRESSURE_WARN = 1,
   PRESSURE_SOFT_REDUCE_SCORE = 2,
   PRESSURE_SOFT_DOWNGRADE_TO_WATCH = 3,
   PRESSURE_HARD_BLOCK_BUY = 4,
   PRESSURE_HARD_BLOCK_SELL = 5
};

enum TRE_PRESSURE_GUARD_MODE
{
   PRESSURE_GUARD_OFF = 0,
   PRESSURE_GUARD_DISPLAY_ONLY = 1,
   PRESSURE_GUARD_WARN_ONLY = 2,
   PRESSURE_GUARD_SOFT_BLOCK = 3,
   PRESSURE_GUARD_HARD_BLOCK = 4
};

enum TRE_PRESSURE_DECISION_IMPACT
{
   PRESSURE_IMPACT_NONE = 0,
   PRESSURE_IMPACT_WARNING_ONLY = 1,
   PRESSURE_IMPACT_SCORE_REDUCED = 2,
   PRESSURE_IMPACT_DOWNGRADED_TO_WATCH = 3,
   PRESSURE_IMPACT_HARD_BLOCKED = 4
};

enum ENUM_PRESSURE_EXECUTION_BLOCK_MODE
{
   PRESSURE_EXECUTION_SHADOW = 0,
   PRESSURE_EXECUTION_DIRECTION_BLOCK = 1,
   PRESSURE_EXECUTION_HIGH_ONLY_BLOCK = 2,
   PRESSURE_EXECUTION_MEDIUM_HIGH_BLOCK = 3
};

enum ENUM_ADAPTIVE_CLUSTER_MODE
{
   SIMPLE_DIRECTION_ZONE = 0,
   ADAPTIVE_CLUSTER_ADVANCED_RESERVED = 1
};

input string InpSymbol        = "GOLDmicro";
input ENUM_TIMEFRAMES ZoneTF  = PERIOD_H1;
input ENUM_TIMEFRAMES BiasTF  = PERIOD_H4;
input ENUM_TIMEFRAMES EntryTF = PERIOD_M15;
input ENUM_TIMEFRAMES ExecutionTF = PERIOD_M5;

// BiasLookbackBars = lookback bars used by H4 Swing/Trend/Bias research.
input int BiasLookbackBars    = 8;
// ZoneLookbackBars = lookback bars used by H1 swing and fallback range.
input int ZoneLookbackBars    = 16;
// Alpha 0.8 keeps zone behavior fixed at Zone 1 through Zone 6.
input int ZoneCount           = 6;
input int SwingDepth          = 2;

input bool UseSwingValidation = true;
input int MinimumSwingRangePoints = 10;
input bool UseATRValidation = true;
input int ATRPeriod = 14;
input ENUM_TIMEFRAMES ATRTimeframe = PERIOD_H1;
input double MinATRMultiplier = 1.0;
input double MaxATRMultiplier = 5.0;

input double RiskUSD          = 2.0;
input bool AutoTrade          = false;

// Keeps display-only evaluation alive when the market is closed and no ticks arrive.
input int EngineRefreshSeconds = 2;

input ENUM_TRE_EXECUTION_MODE ExecutionMode = TRE_DISPLAY_ONLY;
input double BacktestFixedLot = 0.01;
input double BacktestSLPoints = 1000;
input double BacktestTPPoints = 2000;
input int BacktestMagicNumber = 8808;
input string BacktestOrderComment = "TRE_BACKTEST";
input int BacktestMaxPositionsPerSymbol = 1;
input bool BacktestAllowSameDirectionAdd = false;
input bool BacktestAllowOppositePosition = false;
input bool BacktestOneTradePerBar = true;
input bool UseBacktestMaxHoldingBars = false;
input int BacktestMaxHoldingBars = 24;
input bool EnableWeekendProtection = true;
input ENUM_DAY_OF_WEEK WeekendBlockDay = FRIDAY;
input int WeekendBlockHour = 23;
input int WeekendForceCloseHour = 23;
input bool EnableAdaptiveLossCluster = true;
input int LossClusterThreshold = 3;
input int LossClusterCooldownBars = 20;
input ENUM_ADAPTIVE_CLUSTER_MODE AdaptiveClusterMode =
   SIMPLE_DIRECTION_ZONE;
input bool UseAdvancedAdaptiveCluster = false;
input bool AdaptiveEnableBUYZone1 = true;
input bool AdaptiveEnableBUYZone2 = false;
input bool AdaptiveEnableBUYZone3 = false;
input bool AdaptiveEnableBUYZone4 = false;
input bool AdaptiveEnableBUYZone5 = false;
input bool AdaptiveEnableBUYZone6 = false;
input bool AdaptiveEnableSELLZone1 = false;
input bool AdaptiveEnableSELLZone2 = false;
input bool AdaptiveEnableSELLZone3 = false;
input bool AdaptiveEnableSELLZone4 = false;
input bool AdaptiveEnableSELLZone5 = false;
input bool AdaptiveEnableSELLZone6 = false;

input bool UseTrendScore = true;
input bool UseZoneScore = true;
input bool UseStructureScore = true;
input bool UseMomentumScore = true;

input double TrendWeight = 40.0;
input double ZoneWeight = 30.0;
input double StructureWeight = 20.0;
input double MomentumWeight = 10.0;

input bool AllowZoneOnlyResearchDecision = false;
input int ZoneOnlyReadyThreshold = 80;
input ENUM_TRE_MARKET_PROFILE ManualMarketProfile = TRE_PROFILE_UNKNOWN;
input bool UseDirectionalFilter = false;

#define TRE_DEFAULT_USE_AUTO_REGIME_DETECTION true

input bool UseAutoRegimeDetection = TRE_DEFAULT_USE_AUTO_REGIME_DETECTION;
input bool AllowAutoProfileSwitch = false;
input ENUM_TIMEFRAMES RegimeTF = PERIOD_H1;
input int RegimeLookbackBars = 20;
input int RegimeConfirmBars = 3;
input int RegimeSwitchThreshold = 70;
input int RegimeHoldBars = 6;
input bool RegimeUseEMAFilter = true;
input int RegimeEMAPeriod = 50;
input bool RegimeUseATRExpansion = true;
input int RegimeATRPeriod = 14;

input bool UsePressureGuard = true;
input TRE_PRESSURE_GUARD_MODE PressureGuardMode = PRESSURE_GUARD_DISPLAY_ONLY;
input int PressureLookbackBars = 8;
// PERIOD_CURRENT means follow EntryTF; choose another value to override it.
input ENUM_TIMEFRAMES PressureTF = PERIOD_CURRENT;
input int PressureMediumThreshold = 60;
input int PressureHighThreshold = 75;
input int PressureMediumPenalty = 15;
input int PressureHighPenalty = 30;
input bool PressureHighDowngradeToWatch = true;
input bool PressureSoftBlockOnlyInSidewayOrUnknown = true;
input bool PressureUseEMAFilter = true;
input int PressureEMAPeriod = 50;
input bool PressureUseStructureDevelopment = true;
input bool PressureUseMomentum = true;

input bool UsePressureExecutionBlock = false;
input ENUM_PRESSURE_EXECUTION_BLOCK_MODE PressureExecutionBlockMode =
   PRESSURE_EXECUTION_SHADOW;

input bool EnableBacktestCSVLog = true;
input string BacktestMarketStatus = "UNKNOWN";
input string BacktestExperimentName = "ZONE_RESEARCH";

input bool UseResearchDB = false;
input string ResearchDBFolder = "TRE_RESEARCH";
input string ResearchDBFilenamePrefix = "TRE_RESEARCH";
input bool ResearchDBUseCommonFiles = true;
input bool ResearchDBWriteSignals = true;
input bool ResearchDBWriteTrades = true;
input bool ResearchDBWriteZoneSnapshot = true;
input bool ResearchDBWriteStructureSnapshot = true;
input bool ResearchDBWriteRegimeSnapshot = true;
input bool ResearchDBWritePressureSnapshot = true;
input bool ResearchDBWriteDecisionSnapshot = true;
input bool ResearchDBWriteParameters = true;
input bool ResearchDBFlushEverySignal = true;
input bool ResearchDBVerboseLog = false;
// Research label only; this does not alter Entry or Execution behavior.
input bool ResearchDBPressurePolicyIsGoverning = false;

#endif
