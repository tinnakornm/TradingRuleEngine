//+------------------------------------------------------------------+
//| include/globals.mqh                                              |
//| Shared runtime state                                             |
//+------------------------------------------------------------------+
#ifndef TRE_GLOBALS_MQH
#define TRE_GLOBALS_MQH

enum MARKET_BIAS
{
   BIAS_WAIT = 0,
   BIAS_BUY  = 1,
   BIAS_SELL = 2
};

enum ENTRY_ACTION
{
   ACTION_WAIT = 0,
   ACTION_BUY_READY = 1,
   ACTION_SELL_READY = 2,
   ACTION_WATCH = 3,
   ACTION_NO_TRADE = 4
};

enum ZONE_SOURCE_MODE
{
   ZONE_SOURCE_SWING = 0,
   ZONE_SOURCE_FALLBACK = 1
};

#define TRE_MAX_TRADE_ROWS 3
#define TRE_MAX_STRUCTURE_SWINGS 64

enum ENUM_TRE_STRUCTURE_STAGE
{
   TRE_STRUCTURE_EMPTY = 0,
   TRE_STRUCTURE_FIRST_SWING = 1,
   TRE_STRUCTURE_PAIR_READY = 2,
   TRE_STRUCTURE_FORMING = 3,
   TRE_STRUCTURE_CONFIRMED_UPTREND = 4,
   TRE_STRUCTURE_CONFIRMED_DOWNTREND = 5
};

const int TRE_ZONE_COUNT = 6;

double RangeHigh = 0;
double RangeLow  = 0;
double ZoneSize  = 0;

double LastSwingHigh = 0;
double PrevSwingHigh = 0;
double LastSwingLow  = 0;
double PrevSwingLow  = 0;

double StructureLastSwingHigh = 0;
double StructurePrevSwingHigh = 0;
double StructureLastSwingLow  = 0;
double StructurePrevSwingLow  = 0;

string SwingEngineEnabledText = "YES";
string SwingEngineCalledText = "NO";
string BiasSwingTimeframeText = "N/A";
string StructureSwingTimeframeText = "N/A";
string BiasSwingNoSwingReasonText = "Not evaluated";
string StructureSwingNoSwingReasonText = "Not evaluated";
int BiasSwingLookbackRequested = 0;
int StructureSwingLookbackRequested = 0;
int BiasSwingBarsCopied = 0;
int StructureSwingBarsCopied = 0;
int BiasSwingLeftBars = 0;
int BiasSwingRightBars = 0;
int StructureSwingLeftBars = 0;
int StructureSwingRightBars = 0;
int BiasSwingHighCount = 0;
int BiasSwingLowCount = 0;
int StructureSwingHighCount = 0;
int StructureSwingLowCount = 0;
int StructureSwingDetectedHighCount = 0;
int StructureSwingDetectedLowCount = 0;
int BiasLastSwingHighBarIndex = -1;
int BiasLastSwingLowBarIndex = -1;
int StructureLastSwingHighBarIndex = -1;
int StructureLastSwingLowBarIndex = -1;
double StructureSwingHighValues[TRE_MAX_STRUCTURE_SWINGS];
double StructureSwingLowValues[TRE_MAX_STRUCTURE_SWINGS];
int StructureSwingHighIndexes[TRE_MAX_STRUCTURE_SWINGS];
int StructureSwingLowIndexes[TRE_MAX_STRUCTURE_SWINGS];
int StructureSwingHighStoredCount = 0;
int StructureSwingLowStoredCount = 0;
string StructureSwingMappingStatusText = "NOT CHECKED";
string StructureSwingMappingReasonText = "Not evaluated";
string PendingSwingHighCandidateText = "NO";
string PendingSwingHighStatusText = "NONE";
string PendingSwingLowCandidateText = "NO";
string PendingSwingLowStatusText = "NONE";
double PendingSwingHighPrice = 0;
double PendingSwingLowPrice = 0;
int PendingSwingHighBarIndex = -1;
int PendingSwingLowBarIndex = -1;
int PendingSwingHighRightBarsWaited = 0;
int PendingSwingLowRightBarsWaited = 0;
int PendingSwingHighRightBarsRequired = 0;
int PendingSwingLowRightBarsRequired = 0;

int CurrentZone = 0;
int EffectiveBiasLookbackBars = 20;
int EffectiveZoneLookbackBars = 20;
int ZoneFallbackLookbackUsed = 20;

MARKET_BIAS MarketBias = BIAS_WAIT;
ENTRY_ACTION ActionState = ACTION_WAIT;
ZONE_SOURCE_MODE ZoneSourceMode = ZONE_SOURCE_FALLBACK;
ENUM_TRE_STRUCTURE_STAGE StructureStage = TRE_STRUCTURE_EMPTY;

string ZoneSourceText = "Fallback Lookback Range";
string ZoneStrengthText = "WAIT";
string ZoneSwingValidationText = "UNKNOWN";
string ZoneFallbackUsedText = "NO";
string ZoneFallbackReasonText = "N/A";
string ZoneSwingRangeText = "N/A";
string ZoneMinimumRangeText = "N/A";
string ZoneATRValidationText = "UNKNOWN";
string ZoneBasicPriceValidationText = "UNKNOWN";
string ZoneValidationReasonText = "Not evaluated";
string ZoneFallbackSourceText = "N/A";
string ZoneFallbackLookbackText = "N/A";

string ZoneUseSwingValidationText = "ON";
string ZoneUseATRValidationText = "ON";
string ZoneATRTimeframeText = "H1";
string ZoneATRPeriodText = "14";
string ZoneMinATRMultiplierText = "1.0";
string ZoneMaxATRMultiplierText = "5.0";
string ZoneCountText = "6";

string ZoneRawSwingHighText = "N/A";
string ZoneRawSwingLowText = "N/A";
string ZoneSwingRangePriceText = "N/A";
string ZoneSwingRangePointsText = "N/A";
string ZoneATRValuePriceText = "N/A";
string ZoneATRPointsText = "N/A";
string ZoneMinATRRangePointsText = "N/A";
string ZoneMaxATRRangePointsText = "N/A";
string ZoneCurrentPriceText = "N/A";

string ZoneNameText = "N/A";
string ZonePremiumDiscountText = "N/A";
string ZoneWidthPriceText = "N/A";
string ZoneQualityText = "N/A";
string ZoneRetestText = "N/A";
string ZoneBrokenText = "N/A";

double ZoneATRValue = 0;
double ZoneATRPoints = 0;
double ZoneMinATRRangePoints = 0;
double ZoneMaxATRRangePoints = 0;

string TrendReason = "Unknown";
string ZoneReason = "Unknown";
string StructureReason = "Unknown";
string MomentumReason = "Unknown";
string EntryReason = "Waiting for confirmation";
string MissingConditionText = "Waiting for rule evaluation";
string TrendDirectionText = "Unknown";
string TrendStrengthText = "Unknown";
string MarketRegimeText = "Unknown";
string StructureStatusText = "Unknown";
string StructureStageText = "WAITING_FIRST_SWING";
string StructureConfirmedText = "UNCONFIRMED";
string StructureDirectionText = "Sideway";
string StructureBOSStateText = "WAIT";
string StructureCHOCHStateText = "WAIT";
string StructureConfidenceText = "N/A";
string StructureMissingEvidenceText = "Need confirmed swing data";
string StructureValidationStageText = "WAITING_FIRST_SWING";
string StructureDevelopmentStateText = "UNKNOWN";
string StructureEarlyWarningText = "NONE";
string StructureEarlyWarningReasonText = "N/A";
string StructureStrongDirectionalMoveText = "NONE";
string StructurePriceBelowEMAText = "N/A";
string StructurePriceAboveEMAText = "N/A";
string StructureEMASlopeDirectionText = "N/A";
string StructureDistanceFromEMAPointsText = "N/A";
string StructureInterpretationText = "N/A";
string StructureInterpretationLine1Text = "Waiting for structure evidence.";
string StructureInterpretationLine2Text = "N/A";
string StructureInterpretationLine3Text = "N/A";
string StructureSwingDetectionProgressText = "0% [----------]";
string StructureSwingPairProgressText = "0% [----------]";
string StructureBuildProgressText = "0% [----------]";
string StructureConfirmationProgressText = "0% [----------]";
string MomentumCandleText = "Unknown";
string MomentumStrengthText = "Unknown";
string RiskLevelText = "N/A";

int TrendScore = 0;
int ZoneScore = 0;
int StructureScore = 0;
int StructureSwingPairCount = 0;
int StructureHHCount = 0;
int StructureHLCount = 0;
int StructureLHCount = 0;
int StructureLLCount = 0;
int StructureRecentBearishCloseCount = 0;
int StructureRecentBullishCloseCount = 0;
int StructureConsecutiveBearishBars = 0;
int StructureConsecutiveBullishBars = 0;
int StructureRecentLowerLowCount = 0;
int StructureRecentHigherHighCount = 0;
int StructureRecentLowerCloseCount = 0;
int StructureRecentHigherCloseCount = 0;
int MomentumScore = 0;
int TotalScore = 0;
int ConfirmationScore = 0;

TRE_EvidenceItem TrendEvidence[TRE_TREND_EVIDENCE_COUNT];
int TrendEvidenceItemCount = TRE_TREND_EVIDENCE_COUNT;
double TrendEvidenceScore = 0;
double TrendEvidenceMaxScore = 80;
string TrendConfidenceText = "N/A";
string TrendBiasReasonText = "Not evaluated";
string TrendBlockingFactorText = "Not evaluated";

string TrendEngineStatusText = "WAIT";
string ZoneEngineStatusText = "WAIT";
string StructureEngineStatusText = "WAIT";
string MomentumEngineStatusText = "WAIT";
string TotalEngineStatusText = "WAIT";

TRE_EngineScoreItem EngineScores[TRE_ENGINE_SCORE_COUNT];
double WeightedScoreTotal = 0;
double WeightedScoreMax = 100;
string EngineScoreDisplayText[TRE_ENGINE_SCORE_COUNT];
string EngineScoreFormulaText = "Not evaluated";
string EngineScoreMixCompactText = "T0 Z0 S0 M0";
string EngineScoreTotalText = "Total 0 FAIL";
string ResearchDecisionModeText = "Standard";
int EffectiveZoneOnlyReadyThreshold = 80;
string ResearchBiasIgnoredText = "NO";
string ResearchMarketBiasRequiredText = "YES";
string ResearchBiasOverrideText = "NO";
string ResearchSummaryDecisionSourceText = "Standard Rule Engine";
string ResearchDecisionSourceText = "Standard Rule Engine";
string ResearchWarningText = "N/A";

string ManualMarketProfileText = "UNKNOWN";
string DirectionalFilterEnabledText = "OFF";
string DirectionalFilterAllowedDirectionText = "BUY + SELL";
string DirectionalFilterBlockedDirectionText = "NONE";
string DirectionalFilterAllowBuyText = "YES";
string DirectionalFilterAllowSellText = "YES";
string DirectionalFilterResultText = "DISABLED";
string DirectionalFilterReasonText = "Directional filter disabled";
string DirectionalFilterBlockingFactorText = "N/A";
ENTRY_ACTION DirectionalFilterCandidateAction = ACTION_WAIT;
bool DirectionalFilterBlocked = false;

ENUM_TRE_MARKET_PROFILE DetectedRegime = TRE_PROFILE_UNKNOWN;
ENUM_TRE_MARKET_PROFILE ActiveRegime = TRE_PROFILE_UNKNOWN;
ENUM_TRE_MARKET_PROFILE RegimeConfirmationCandidate = TRE_PROFILE_UNKNOWN;
string DetectedRegimeText = "UNKNOWN";
string ActiveRegimeText = "UNKNOWN";
string RegimeConfidenceText = "0 / 100";
string RegimeSwitchStatusText = "DETECTED_ONLY";
string RegimeBlockingReasonText = "AUTO_PROFILE_SWITCH_OFF";
string RegimeResearchModeText = "AUTO DETECTION SHADOW MODE";
string MarketDetectionStatusText = "ACTIVE";
string AutoProfileSwitchStatusText = "OFF";
string RegimeProfileSourceText = "MANUAL";
string RegimeInputSourceText = "Source Code Default";
bool RegimeDetectionWarningActive = false;
string RegimeUptrendReasonText = "Not evaluated";
string RegimeDowntrendReasonText = "Not evaluated";
string RegimeSidewayReasonText = "Not evaluated";
string RegimeEMAValueText = "N/A";
string RegimeEMASlopeText = "N/A";
string RegimeATRValueText = "N/A";
string RegimeATRExpansionText = "N/A";
string RegimeBestCandidateText = "UNKNOWN";
string RegimeRawDetectedText = "UNKNOWN";
string RegimePreviousDetectedText = "UNKNOWN";
string RegimeCandidateText = "UNKNOWN";
string RegimeThresholdResultText = "FAIL";
string RegimeConfidenceCommentText = "WEAK";
string RegimeActiveBeforeSwitchText = "UNKNOWN";
string RegimeActiveAfterSwitchText = "UNKNOWN";
string RegimeSwitchAllowedText = "NO";
string RegimeSwitchDecisionReasonText = "Not evaluated";
string RegimeCurrentPriceText = "N/A";
string RegimeOpenText = "N/A";
string RegimeHighText = "N/A";
string RegimeLowText = "N/A";
string RegimeCloseText = "N/A";
string RegimeLookbackHighText = "N/A";
string RegimeLookbackLowText = "N/A";
string RegimeLookbackRangePointsText = "N/A";
string RegimeEMAPreviousValueText = "N/A";
string RegimeEMASlopePointsText = "N/A";
string RegimeATRPointsText = "N/A";
string RegimeATRAveragePointsText = "N/A";
string RegimeH4BiasText = "WAIT";
string RegimeMidZoneTouchCountText = "N/A";
TRE_EvidenceItem RegimeUptrendEvidence[TRE_REGIME_EVIDENCE_COUNT];
TRE_EvidenceItem RegimeDowntrendEvidence[TRE_REGIME_EVIDENCE_COUNT];
TRE_EvidenceItem RegimeSidewayEvidence[TRE_REGIME_EVIDENCE_COUNT];
int UptrendScore = 0;
int DowntrendScore = 0;
int SidewayScore = 0;
int RegimeWinningScore = 0;
int RegimeScoreGap = 0;
int RegimeCandidateConfidence = 0;
int RegimeSwingHighCount = 0;
int RegimeSwingLowCount = 0;
int RegimeHigherHighCount = 0;
int RegimeHigherLowCount = 0;
int RegimeLowerHighCount = 0;
int RegimeLowerLowCount = 0;
int RegimeCloseAboveEMACount = 0;
int RegimeCloseBelowEMACount = 0;
int RegimeConfidence = 0;
int RegimeConfirmationCount = 0;
int RegimeActiveHoldCount = 0;
int EffectiveRegimeLookbackBars = 20;
int EffectiveRegimeConfirmBars = 3;
int EffectiveRegimeSwitchThreshold = 70;
int EffectiveRegimeHoldBars = 6;
int EffectiveRegimeEMAPeriod = 50;
int EffectiveRegimeATRPeriod = 14;
datetime RegimeLastEvaluatedBarTime = 0;

TRE_PRESSURE_DIRECTION PressureDirection = PRESSURE_NONE;
TRE_PRESSURE_LEVEL PressureLevel = PRESSURE_LOW;
TRE_PRESSURE_ACTION PressureAction = PRESSURE_ALLOW;
ENTRY_ACTION PressureCandidateAction = ACTION_WAIT;
string PressureDirectionText = "NONE";
string PressureLevelText = "LOW";
string PressureActionText = "ALLOW";
string PressureBlockedDirectionText = "NONE";
string PressureReasonText = "Not evaluated";
string PressureMissingConditionText = "N/A";
string PressureAppliesToCandidateText = "NO";
string PressureGuardStatusText = "NOT EVALUATED";
string PressureCandidateDirectionText = "NONE";
string PressureCandidateRegimeText = "UNKNOWN";
string PressureBeforeDecisionText = "WAIT";
string PressureAfterDecisionText = "WAIT";
string PressureDowngradeReasonText = "N/A";
string PressureBlockReasonText = "N/A";
string PressureMomentumDirectionText = "NEUTRAL";
string PressureEMAValueText = "N/A";
string PressureEMASlopePointsText = "N/A";
string PressurePriceAboveEMAText = "N/A";
string PressurePriceBelowEMAText = "N/A";
string PressureEMASlopeDirectionText = "N/A";
string PressureLastCloseText = "N/A";
string PressureLastHighText = "N/A";
string PressureLastLowText = "N/A";
string PressureEffectiveTFText = "M15";
int PressureScore = 0;
int BullishPressureScore = 0;
int BearishPressureScore = 0;
int PressureBarsCopied = 0;
int PressureBullishEvidenceCount = 0;
int PressureBearishEvidenceCount = 0;
int PressureRecentHigherCloseCount = 0;
int PressureRecentLowerCloseCount = 0;
int PressureRecentHigherHighCount = 0;
int PressureRecentLowerLowCount = 0;
int PressureConsecutiveBullishBars = 0;
int PressureConsecutiveBearishBars = 0;
int EffectivePressureLookbackBars = 8;
int EffectivePressureMediumThreshold = 60;
int EffectivePressureHighThreshold = 75;
int EffectivePressureEMAPeriod = 50;
ENUM_TIMEFRAMES EffectivePressureTF = PERIOD_M15;

string JournalCSVEnabledText = "NO";
string JournalCSVFileName = "N/A";
string JournalCSVLocationText = "N/A";
string JournalMarketLabelText = "UNKNOWN";
string JournalCSVLastWriteText = "N/A";
string JournalCSVStatusText = "NOT INITIALIZED";
int JournalSignalsLogged = 0;
int JournalTradesOpenLogged = 0;
int JournalTradesCloseLogged = 0;
int JournalSignalsBlockedByDirectionalFilter = 0;
int JournalBuySignalsBlocked = 0;
int JournalSellSignalsBlocked = 0;

double MomentumBodyPercent = 0;
double MomentumUpperWickPercent = 0;
double MomentumLowerWickPercent = 0;

int ActiveDashboardTab = 0;
int ActiveSummarySubTab = 0;
int ActiveDecisionSubTab = 0;
int ActiveStructureSubTab = 0;
int ActivePressureSubTab = 0;
int ActiveTradeSubTab = 0;
bool DashboardVisible = true;

int TradePositionCount = 0;
int TradePendingCount = 0;
double TradeFloatingProfitTotal = 0;
double AccountMarginLevel = 0;

string TradePositionSummary = "NONE";
string AccountMarginLevelText = "N/A";
string AccountMarginStatusText = "N/A";
string ExecutionModeText = "Display Only";
string ExecutionAllowedText = "NO";
string ExecutionRuntimeText = "Live Chart";
string LastExecutionAction = "NONE";
string LastExecutionReason = "No execution attempt";

double ExecutionVolumeMin = 0;
double ExecutionVolumeMax = 0;
double ExecutionVolumeStep = 0;
double ExecutionTickSize = 0;
double ExecutionTickValue = 0;
double ExecutionPoint = 0;
long ExecutionStopsLevel = 0;
long ExecutionFreezeLevel = 0;
int ExecutionDigits = 0;

double ExecutionRequestedLot = 0;
double ExecutionNormalizedLot = 0;
double ExecutionRequestedSLPoints = 0;
double ExecutionEffectiveSLPoints = 0;
double ExecutionRequestedTPPoints = 0;
double ExecutionEffectiveTPPoints = 0;
int ExecutionPositionCount = 0;
datetime ExecutionLastSignalBarTime = 0;
datetime ExecutionLastBarTime = 0;

string ExecutionCanExecuteText = "NO";
string ExecutionLotValidationText = "UNKNOWN";
string ExecutionLotReasonText = "Not evaluated";
string ExecutionLotSummaryValueText = "N/A";
string ExecutionLotSummaryReasonText = "Not evaluated";
string ExecutionSLTPValidationText = "UNKNOWN";
string ExecutionOneTradePerBarText = "ON";
string ExecutionLastSignalBarText = "N/A";
string ExecutionLastBarText = "N/A";
string ExecutionLastOrderType = "N/A";
string ExecutionLastOrderTicket = "N/A";
string ExecutionLastOrderLot = "N/A";
string ExecutionLastOrderEntry = "N/A";
string ExecutionLastOrderSL = "N/A";
string ExecutionLastOrderTP = "N/A";
string ExecutionLastTradeRetcode = "N/A";
string ExecutionLastErrorText = "N/A";

string TimeoutEnabledText = "OFF";
string TimeoutHoldingTFText = "M5";
string TimeoutPositionOpenTimeText = "N/A";
string TimeoutCurrentBarsHeldText = "0";
string TimeoutMaxHoldingBarsText = "24";
string TimeoutStatusText = "OFF";
string TimeoutLastTicketText = "N/A";
string TimeoutLastReasonText = "N/A";
string TimeoutLastCloseResultText = "N/A";
string TradeManagementSummaryText = "Timeout OFF";
int TimeoutCurrentBarsHeld = 0;
int EffectiveBacktestMaxHoldingBars = 24;
long TimeoutLastPositionIdentifier = 0;

string TradePositionTicket[TRE_MAX_TRADE_ROWS];
string TradePositionType[TRE_MAX_TRADE_ROWS];
string TradePositionVolume[TRE_MAX_TRADE_ROWS];
string TradePositionEntryPrice[TRE_MAX_TRADE_ROWS];
string TradePositionCurrentPrice[TRE_MAX_TRADE_ROWS];
string TradePositionStopLoss[TRE_MAX_TRADE_ROWS];
string TradePositionTakeProfit[TRE_MAX_TRADE_ROWS];
string TradePositionFloatingProfit[TRE_MAX_TRADE_ROWS];
string TradePositionSwap[TRE_MAX_TRADE_ROWS];
string TradePositionCommission[TRE_MAX_TRADE_ROWS];
string TradePositionTime[TRE_MAX_TRADE_ROWS];
string TradePositionComment[TRE_MAX_TRADE_ROWS];
string TradePositionStatus[TRE_MAX_TRADE_ROWS];
string TradeRiskPoints[TRE_MAX_TRADE_ROWS];
string TradeRewardPoints[TRE_MAX_TRADE_ROWS];
string TradeCurrentMovePoints[TRE_MAX_TRADE_ROWS];
string TradeCurrentRR[TRE_MAX_TRADE_ROWS];
string TradePlannedRR[TRE_MAX_TRADE_ROWS];

string TradePendingTicket[TRE_MAX_TRADE_ROWS];
string TradePendingType[TRE_MAX_TRADE_ROWS];
string TradePendingVolume[TRE_MAX_TRADE_ROWS];
string TradePendingEntryPrice[TRE_MAX_TRADE_ROWS];
string TradePendingStopLoss[TRE_MAX_TRADE_ROWS];
string TradePendingTakeProfit[TRE_MAX_TRADE_ROWS];
string TradePendingDistancePoints[TRE_MAX_TRADE_ROWS];
string TradePendingOrderTime[TRE_MAX_TRADE_ROWS];
string TradePendingExpiration[TRE_MAX_TRADE_ROWS];
string TradePendingComment[TRE_MAX_TRADE_ROWS];

#endif
