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
   PRESSURE_DOWNGRADE_TO_WATCH = 1,
   PRESSURE_BLOCK_BUY = 2,
   PRESSURE_BLOCK_SELL = 3
};

enum TRE_PRESSURE_GUARD_MODE
{
   PRESSURE_GUARD_OFF = 0,
   PRESSURE_GUARD_WARN_ONLY = 1,
   PRESSURE_GUARD_DOWNGRADE = 2,
   PRESSURE_GUARD_BLOCK = 3
};

input string InpSymbol        = "GOLDmicro";
input ENUM_TIMEFRAMES ZoneTF  = PERIOD_H1;
input ENUM_TIMEFRAMES BiasTF  = PERIOD_H4;
input ENUM_TIMEFRAMES EntryTF = PERIOD_M15;
input ENUM_TIMEFRAMES ExecutionTF = PERIOD_M5;

// BiasLookbackBars = lookback bars used by H4 Swing/Trend/Bias research.
input int BiasLookbackBars    = 20;
// ZoneLookbackBars = lookback bars used by H1 swing and fallback range.
input int ZoneLookbackBars    = 20;
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
input TRE_PRESSURE_GUARD_MODE PressureGuardMode = PRESSURE_GUARD_BLOCK;
input int PressureLookbackBars = 8;
// PERIOD_CURRENT means follow EntryTF; choose another value to override it.
input ENUM_TIMEFRAMES PressureTF = PERIOD_CURRENT;
input int PressureMediumThreshold = 60;
input int PressureHighThreshold = 75;
input bool PressureBlockOnlyInSidewayOrUnknown = true;
input bool PressureUseEMAFilter = true;
input int PressureEMAPeriod = 50;
input bool PressureUseStructureDevelopment = true;
input bool PressureUseMomentum = true;

input bool EnableBacktestCSVLog = true;
input string BacktestMarketStatus = "UNKNOWN";
input string BacktestExperimentName = "ZONE_RESEARCH";

#endif
