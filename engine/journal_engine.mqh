//+------------------------------------------------------------------+
//| engine/journal_engine.mqh                                        |
//| Strategy Tester-only experiment CSV logger                       |
//+------------------------------------------------------------------+
#ifndef TRE_JOURNAL_ENGINE_MQH
#define TRE_JOURNAL_ENGINE_MQH

#define TRE_JOURNAL_MAX_TRADES 64

struct TRE_JournalTrade
{
   bool active;
   int tradeId;
   ulong ticket;
   long identifier;
   long type;
   datetime openTime;
   double lot;
   double entry;
   double stopLoss;
   double takeProfit;
   int zone;
   int score;
   string researchMode;
   string reason;
   double plannedRR;
   string trendStatus;
   string zoneStatus;
   string structureStatus;
   string momentumStatus;
};

int TREJournalHandle = INVALID_HANDLE;
bool TREJournalInitialized = false;
bool TREJournalFinalized = false;
datetime TREJournalStartTime = 0;
datetime TREJournalLastSignalBar = 0;
int TREJournalLastSignalAction = -1;
TRE_JournalTrade TREJournalTrades[TRE_JOURNAL_MAX_TRADES];

int TREJournalBuyTrades = 0;
int TREJournalSellTrades = 0;
int TREJournalWinTrades = 0;
int TREJournalLossTrades = 0;
double TREJournalGrossProfit = 0;
double TREJournalGrossLoss = 0;
double TREJournalNetProfit = 0;
double TREJournalWinningProfit = 0;
double TREJournalLosingProfit = 0;
double TREJournalLargestWin = 0;
double TREJournalLargestLoss = 0;
int TREJournalCurrentWinStreak = 0;
int TREJournalCurrentLossStreak = 0;
int TREJournalMaxWinStreak = 0;
int TREJournalMaxLossStreak = 0;
long TREJournalTotalHoldingBars = 0;
int TREJournalMaxBarsHeld = 0;
int TREJournalTimeoutClosedTrades = 0;
double TREJournalPeakEquity = 0;
double TREJournalMaxDrawdown = 0;

int TREJournalZoneTrades[7];
int TREJournalZoneClosedTrades[7];
int TREJournalZoneWins[7];
double TREJournalZoneProfit[7];

int TREJournalEnginePass[TRE_ENGINE_SCORE_COUNT];
int TREJournalEngineFail[TRE_ENGINE_SCORE_COUNT];
int TREJournalEngineWait[TRE_ENGINE_SCORE_COUNT];
int TREJournalEngineDisabled[TRE_ENGINE_SCORE_COUNT];

bool JournalCanWrite()
{
   return (MQLInfoInteger(MQL_TESTER) != 0 &&
           EnableBacktestCSVLog &&
           TREJournalHandle != INVALID_HANDLE &&
           !TREJournalFinalized);
}

string JournalBoolText(bool value)
{
   return value ? "true" : "false";
}

string JournalTimeText(datetime value)
{
   if(value <= 0)
      return "N/A";

   return TimeToString(value, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
}

string JournalPriceText(double value, string symbol)
{
   if(value <= 0)
      return "N/A";

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return DoubleToString(value, digits);
}

void JournalAddCSVField(string &fields[], string value)
{
   int size = ArraySize(fields);
   ArrayResize(fields, size + 1);
   fields[size] = value;
}

string JournalEscapeCSVField(string value)
{
   bool needsQuotes =
      (StringFind(value, ",") >= 0 ||
       StringFind(value, "\"") >= 0 ||
       StringFind(value, "\r") >= 0 ||
       StringFind(value, "\n") >= 0);

   if(!needsQuotes)
      return value;

   StringReplace(value, "\"", "\"\"");
   return "\"" + value + "\"";
}

void JournalWriteCSVRow(string &fields[])
{
   string line = "";

   for(int i = 0; i < ArraySize(fields); i++)
   {
      if(i > 0)
         line += ",";

      line += JournalEscapeCSVField(fields[i]);
   }

   FileWriteString(TREJournalHandle, line + "\r\n");
}

void JournalWriteSignalHeader()
{
   string fields[];
   string names =
      "SIGNAL|SignalID|Time|Symbol|Decision|Zone|Bias|Regime|" +
      "SignalScore|TrendScore|ZoneScore|StructureScore|" +
      "MomentumScore|EntryReason|MissingCondition|" +
      "ManualMarketProfile|DirectionalFilter|FilterResult|" +
      "FilterReason|AllowedDirection|CandidateDecision|" +
      "UseAutoRegimeDetection|AllowAutoProfileSwitch|RegimeTF|" +
      "RegimeLookbackBars|RegimeConfirmBars|RegimeSwitchThreshold|" +
      "RegimeHoldBars|DetectedRegime|BestCandidateRegime|" +
      "ActiveRegime|RegimeConfidence|MarketDetectionStatus|" +
      "AutoProfileSwitchStatus|ProfileSource|WinningScore|ScoreGap|" +
      "ThresholdResult|ConfidenceComment|UptrendScore|SidewayScore|" +
      "DowntrendScore|RegimeSwitchStatus|RegimeBlockingReason|" +
      "RegimeSwitchDecisionReason|StructureStage|HHCount|HLCount|" +
      "LHCount|LLCount|SwingPairCount|BOSState|CHOCHState|" +
      "StructureConfidence|MissingStructureReason|CurrentSwingHigh|" +
      "PreviousSwingHigh|CurrentSwingLow|PreviousSwingLow|" +
      "StructureValidationStage|StructureDevelopmentState|" +
      "StructureEarlyWarning|StructureEarlyWarningReason|" +
      "StrongDirectionalMove|RecentBearishCloseCount|" +
      "RecentBullishCloseCount|ConsecutiveBearishBars|" +
      "ConsecutiveBullishBars|RecentLowerLowCount|" +
      "RecentHigherHighCount|PendingSwingHighStatus|" +
      "PendingSwingHighPrice|PendingSwingHighRightBarsWaited|" +
      "PendingSwingHighRightBarsRequired|PendingSwingLowStatus|" +
      "PendingSwingLowPrice|PendingSwingLowRightBarsWaited|" +
      "PendingSwingLowRightBarsRequired|UsePressureGuard|" +
      "PressureGuardMode|PressureDirection|PressureLevel|" +
      "PressureScore|BullishPressureScore|BearishPressureScore|" +
      "PressureAction|BlockedDirection|PressureReason|" +
      "CandidateDirectionBeforePressure|DecisionAfterPressure";
   StringSplit(names, '|', fields);
   JournalWriteCSVRow(fields);
}

string JournalSafeFilePart(string value)
{
   StringReplace(value, " ", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, "\\", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, ",", "_");
   return value;
}

string JournalNormalizeMarketLabel()
{
   string label = BacktestMarketStatus;
   StringTrimLeft(label);
   StringTrimRight(label);
   StringToUpper(label);

   if(label == "")
      label = "UNKNOWN";

   return label;
}

string JournalAllowedDirectionText()
{
   if(DirectionalFilterAllowBuyText == "YES" &&
      DirectionalFilterAllowSellText == "NO")
      return "BUY_ONLY";

   if(DirectionalFilterAllowBuyText == "NO" &&
      DirectionalFilterAllowSellText == "YES")
      return "SELL_ONLY";

   return "BUY_SELL";
}

string JournalTimestamp(datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return StringFormat("%04d%02d%02d_%02d%02d",
                       parts.year,
                       parts.mon,
                       parts.day,
                       parts.hour,
                       parts.min);
}

string JournalBuildFileNameBase(string symbol)
{
   return "TRE_EXP_SYM_" +
          JournalSafeFilePart(symbol) + "_MARKET_" +
          JournalSafeFilePart(JournalMarketLabelText) + "_PROFILE_" +
          TRE_MarketProfileToText(ManualMarketProfile) + "_FILTER_" +
          (UseDirectionalFilter ? "ON" : "OFF") + "_REG_" +
          (UseAutoRegimeDetection ? "ON" : "OFF") + "_SW_" +
          (AllowAutoProfileSwitch ? "ON" : "OFF") + "_ZTF_" +
          TimeframeToText(ZoneTF) + "_BTF_" +
          TimeframeToText(BiasTF) + "_ENTRY_" +
          TimeframeToText(EntryTF) + "_EXEC_" +
          TimeframeToText(ExecutionTF) + "_ZLB" +
          IntegerToString(EffectiveZoneLookbackBars) + "_BLB" +
          IntegerToString(EffectiveBiasLookbackBars) + "_ATR_" +
          (UseATRValidation ? "ON" : "OFF") + "_ATR" +
          IntegerToString(ATRPeriod) + "_ATR" +
          EntryFormatScore(MinATRMultiplier) + "-" +
          EntryFormatScore(MaxATRMultiplier) + "_SL" +
          EntryFormatScore(BacktestSLPoints) + "_TP" +
          EntryFormatScore(BacktestTPPoints) + "_HOLD_" +
          (UseBacktestMaxHoldingBars ? "ON" : "OFF") +
          IntegerToString(EffectiveBacktestMaxHoldingBars) + "_" +
          JournalTimestamp(TREJournalStartTime);
}

string JournalAllocateFileName(string symbol)
{
   string baseName = JournalBuildFileNameBase(symbol);
   string candidate = baseName + ".csv";

   // Tester agents may clear their local Files sandbox between runs.
   // FILE_COMMON keeps experiment files and collision checks persistent.
   if(!FileIsExist(candidate, FILE_COMMON))
      return candidate;

   for(int suffix = 1; suffix <= 9999; suffix++)
   {
      candidate = baseName + "_" + StringFormat("%03d", suffix) + ".csv";
      if(!FileIsExist(candidate, FILE_COMMON))
         return candidate;
   }

   return "";
}

void JournalTouch()
{
   if(TREJournalHandle == INVALID_HANDLE)
      return;

   FileFlush(TREJournalHandle);
   JournalCSVLastWriteText = JournalTimeText(TimeCurrent());
   JournalCSVStatusText = "OK";
}

void JournalWriteExperiment(string symbol)
{
   FileWrite(TREJournalHandle, "[PARAMETER]");
   FileWrite(TREJournalHandle, "PARAMETER", "Name", "Value");
   FileWrite(TREJournalHandle, "PARAMETER", "ExportFormat", "Backtest Export v2");
   FileWrite(TREJournalHandle, "PARAMETER", "ExperimentName", BacktestExperimentName);
   FileWrite(TREJournalHandle, "PARAMETER", "TREVersion", APP_VERSION);
   FileWrite(TREJournalHandle, "PARAMETER", "GitCommit", "N/A");
   FileWrite(TREJournalHandle, "PARAMETER", "ExecutionMode", TRE_ExecutionModeToText());
   FileWrite(TREJournalHandle, "PARAMETER", "MarketLabel", JournalMarketLabelText);
   FileWrite(TREJournalHandle, "PARAMETER", "DateRangeStart", JournalTimeText(TREJournalStartTime));
   FileWrite(TREJournalHandle, "PARAMETER", "DateRangeEnd", "PENDING");
   FileWrite(TREJournalHandle, "PARAMETER", "Symbol", symbol);
   FileWrite(TREJournalHandle, "PARAMETER", "ResearchMode",
             AllowZoneOnlyResearchDecision ? "Zone Only" : "Normal");
}

void JournalWriteParameters()
{
   FileWrite(TREJournalHandle, "PARAMETER", "ZoneTF", TimeframeToText(ZoneTF));
   FileWrite(TREJournalHandle, "PARAMETER", "BiasTF", TimeframeToText(BiasTF));
   FileWrite(TREJournalHandle, "PARAMETER", "EntryTF", TimeframeToText(EntryTF));
   FileWrite(TREJournalHandle, "PARAMETER", "ExecutionTF", TimeframeToText(ExecutionTF));
   FileWrite(TREJournalHandle, "PARAMETER", "BiasLookbackBars", BiasLookbackBars);
   FileWrite(TREJournalHandle, "PARAMETER", "ZoneLookbackBars", ZoneLookbackBars);
   FileWrite(TREJournalHandle, "PARAMETER", "ZoneCount", TRE_ZONE_COUNT);
   FileWrite(TREJournalHandle, "PARAMETER", "SwingDepth", SwingDepth);
   FileWrite(TREJournalHandle, "PARAMETER", "SwingValidation", JournalBoolText(UseSwingValidation));
   FileWrite(TREJournalHandle, "PARAMETER", "MinimumSwingRangePoints", MinimumSwingRangePoints);
   FileWrite(TREJournalHandle, "PARAMETER", "ATRValidation", JournalBoolText(UseATRValidation));
   FileWrite(TREJournalHandle, "PARAMETER", "ATRPeriod", ATRPeriod);
   FileWrite(TREJournalHandle, "PARAMETER", "ATRTimeframe", TimeframeToText(ATRTimeframe));
   FileWrite(TREJournalHandle, "PARAMETER", "MinATRMultiplier", MinATRMultiplier);
   FileWrite(TREJournalHandle, "PARAMETER", "MaxATRMultiplier", MaxATRMultiplier);
   FileWrite(TREJournalHandle, "PARAMETER", "RiskUSD", RiskUSD);
   FileWrite(TREJournalHandle, "PARAMETER", "BacktestLot", BacktestFixedLot);
   FileWrite(TREJournalHandle, "PARAMETER", "TrendEnabled", JournalBoolText(UseTrendScore));
   FileWrite(TREJournalHandle, "PARAMETER", "ZoneEnabled", JournalBoolText(UseZoneScore));
   FileWrite(TREJournalHandle, "PARAMETER", "StructureEnabled", JournalBoolText(UseStructureScore));
   FileWrite(TREJournalHandle, "PARAMETER", "MomentumEnabled", JournalBoolText(UseMomentumScore));
   FileWrite(TREJournalHandle, "PARAMETER", "WeightTrend", TrendWeight);
   FileWrite(TREJournalHandle, "PARAMETER", "WeightZone", ZoneWeight);
   FileWrite(TREJournalHandle, "PARAMETER", "WeightStructure", StructureWeight);
   FileWrite(TREJournalHandle, "PARAMETER", "WeightMomentum", MomentumWeight);
   FileWrite(TREJournalHandle, "PARAMETER", "AllowZoneOnlyResearchDecision",
             JournalBoolText(AllowZoneOnlyResearchDecision));
   FileWrite(TREJournalHandle, "PARAMETER", "DecisionThreshold", ZoneOnlyReadyThreshold);
   FileWrite(TREJournalHandle, "PARAMETER", "ManualMarketProfile",
             TRE_MarketProfileToText(ManualMarketProfile));
   FileWrite(TREJournalHandle, "PARAMETER", "UseDirectionalFilter",
             JournalBoolText(UseDirectionalFilter));
   FileWrite(TREJournalHandle, "PARAMETER", "UseAutoRegimeDetection",
             JournalBoolText(UseAutoRegimeDetection));
   FileWrite(TREJournalHandle, "PARAMETER", "AllowAutoProfileSwitch",
             JournalBoolText(AllowAutoProfileSwitch));
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeTF",
             TimeframeToText(RegimeTF));
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeLookbackBars",
             RegimeLookbackBars);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeConfirmBars",
             RegimeConfirmBars);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeSwitchThreshold",
             RegimeSwitchThreshold);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeHoldBars",
             RegimeHoldBars);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeUseEMAFilter",
             JournalBoolText(RegimeUseEMAFilter));
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeEMAPeriod",
             RegimeEMAPeriod);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeUseATRExpansion",
             JournalBoolText(RegimeUseATRExpansion));
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeATRPeriod",
             RegimeATRPeriod);
   FileWrite(TREJournalHandle, "PARAMETER", "UsePressureGuard",
             JournalBoolText(UsePressureGuard));
   FileWrite(TREJournalHandle, "PARAMETER", "PressureGuardMode",
             PressureGuardModeToText(PressureGuardMode));
   FileWrite(TREJournalHandle, "PARAMETER", "PressureLookbackBars",
             PressureLookbackBars);
   FileWrite(TREJournalHandle, "PARAMETER", "PressureTF",
             TimeframeToText(EffectivePressureTF));
   FileWrite(TREJournalHandle, "PARAMETER", "PressureMediumThreshold",
             PressureMediumThreshold);
   FileWrite(TREJournalHandle, "PARAMETER", "PressureHighThreshold",
             PressureHighThreshold);
   FileWrite(TREJournalHandle, "PARAMETER", "DetectedRegime",
             DetectedRegimeText);
   FileWrite(TREJournalHandle, "PARAMETER", "ActiveRegime",
             ActiveRegimeText);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeConfidence",
             RegimeConfidence);
   FileWrite(TREJournalHandle, "PARAMETER", "UptrendScore",
             UptrendScore);
   FileWrite(TREJournalHandle, "PARAMETER", "DowntrendScore",
             DowntrendScore);
   FileWrite(TREJournalHandle, "PARAMETER", "SidewayScore",
             SidewayScore);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeSwitchStatus",
             RegimeSwitchStatusText);
   FileWrite(TREJournalHandle, "PARAMETER", "RegimeBlockingReason",
             RegimeBlockingReasonText);
   FileWrite(TREJournalHandle, "PARAMETER", "BacktestSLPoints", BacktestSLPoints);
   FileWrite(TREJournalHandle, "PARAMETER", "BacktestTPPoints", BacktestTPPoints);
   FileWrite(TREJournalHandle, "PARAMETER", "BacktestMaxPositionsPerSymbol",
             BacktestMaxPositionsPerSymbol);
   FileWrite(TREJournalHandle, "PARAMETER", "BacktestOneTradePerBar",
             JournalBoolText(BacktestOneTradePerBar));
   FileWrite(TREJournalHandle, "PARAMETER", "UseBacktestMaxHoldingBars",
             JournalBoolText(UseBacktestMaxHoldingBars));
   FileWrite(TREJournalHandle, "PARAMETER", "BacktestMaxHoldingBars",
             BacktestMaxHoldingBars);
   FileWrite(TREJournalHandle, "PARAMETER", "HoldingBarsTF",
             TimeframeToText(ExecutionTF));
}

void JournalWriteHeaders()
{
   FileWrite(TREJournalHandle, "[SIGNAL]");
   JournalWriteSignalHeader();
   FileWrite(TREJournalHandle, "[TRADE_OPEN]");
   FileWrite(TREJournalHandle,
             "TRADE_OPEN", "TradeID", "Time", "Ticket", "Type", "Symbol",
             "Lot", "Entry", "SL", "TP", "Zone", "Bias", "Regime",
             "Score", "ResearchMode", "Reason", "RiskReward",
             "TrendStatus", "ZoneStatus", "StructureStatus", "MomentumStatus");
   FileWrite(TREJournalHandle, "[TRADE_CLOSE]");
   FileWrite(TREJournalHandle,
             "TRADE_CLOSE", "TradeID", "CloseTime", "Ticket", "Type",
             "Symbol", "Lot", "Entry", "ClosePrice", "SL", "TP",
             "Profit", "Swap", "Commission", "NetProfit", "CloseReason",
             "BarsHeld", "RiskReward", "ProfitUSD", "TradeDurationBars",
             "ExitReason");
}

void JournalResetTracking()
{
   for(int i = 0; i < TRE_JOURNAL_MAX_TRADES; i++)
   {
      TREJournalTrades[i].active = false;
      TREJournalTrades[i].tradeId = 0;
      TREJournalTrades[i].ticket = 0;
      TREJournalTrades[i].identifier = 0;
   }

   for(int zone = 0; zone <= 6; zone++)
   {
      TREJournalZoneTrades[zone] = 0;
      TREJournalZoneClosedTrades[zone] = 0;
      TREJournalZoneWins[zone] = 0;
      TREJournalZoneProfit[zone] = 0;
   }

   for(int engine = 0; engine < TRE_ENGINE_SCORE_COUNT; engine++)
   {
      TREJournalEnginePass[engine] = 0;
      TREJournalEngineFail[engine] = 0;
      TREJournalEngineWait[engine] = 0;
      TREJournalEngineDisabled[engine] = 0;
   }
}

void JournalInitialize(string symbol)
{
   if(TREJournalInitialized)
      return;

   TREJournalInitialized = true;
   TREJournalFinalized = false;
   JournalSignalsLogged = 0;
   JournalTradesOpenLogged = 0;
   JournalTradesCloseLogged = 0;
   JournalSignalsBlockedByDirectionalFilter = 0;
   JournalBuySignalsBlocked = 0;
   JournalSellSignalsBlocked = 0;
   TREJournalBuyTrades = 0;
   TREJournalSellTrades = 0;
   TREJournalWinTrades = 0;
   TREJournalLossTrades = 0;
   TREJournalGrossProfit = 0;
   TREJournalGrossLoss = 0;
   TREJournalNetProfit = 0;
   TREJournalWinningProfit = 0;
   TREJournalLosingProfit = 0;
   TREJournalLargestWin = 0;
   TREJournalLargestLoss = 0;
   TREJournalCurrentWinStreak = 0;
   TREJournalCurrentLossStreak = 0;
   TREJournalMaxWinStreak = 0;
   TREJournalMaxLossStreak = 0;
   TREJournalTotalHoldingBars = 0;
   TREJournalMaxBarsHeld = 0;
   TREJournalTimeoutClosedTrades = 0;
   TREJournalPeakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   TREJournalMaxDrawdown = 0;
   TREJournalStartTime = TimeCurrent();
   JournalResetTracking();

   if(MQLInfoInteger(MQL_TESTER) == 0)
   {
      JournalCSVEnabledText = "NO";
      JournalCSVStatusText = "BLOCKED: Strategy Tester only";
      return;
   }

   if(!EnableBacktestCSVLog)
   {
      JournalCSVEnabledText = "NO";
      JournalCSVStatusText = "DISABLED";
      return;
   }

   JournalCSVEnabledText = "YES";
   JournalCSVLocationText = TerminalInfoString(TERMINAL_COMMONDATA_PATH) +
                            "\\Files";
   JournalMarketLabelText = JournalNormalizeMarketLabel();
   JournalCSVFileName = JournalAllocateFileName(symbol);

   if(JournalCSVFileName == "")
   {
      JournalCSVStatusText = "ERROR: no unique filename available";
      return;
   }

   ResetLastError();
   TREJournalHandle = FileOpen(JournalCSVFileName,
                               FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,
                               ',');

   if(TREJournalHandle == INVALID_HANDLE)
   {
      JournalCSVStatusText = "ERROR " + IntegerToString(GetLastError());
      return;
   }

   Print("TRE CSV Experiment: MarketLabel=", JournalMarketLabelText,
         " File=", JournalCSVFileName,
         " Location=", JournalCSVLocationText);
   JournalWriteExperiment(symbol);
   JournalWriteParameters();
   JournalWriteHeaders();
   JournalTouch();
}

void JournalWriteSignalRow(string symbol,
                           datetime signalBar,
                           ENTRY_ACTION candidateAction)
{
   string fields[];
   JournalAddCSVField(fields, "SIGNAL");
   JournalAddCSVField(fields, IntegerToString(JournalSignalsLogged));
   JournalAddCSVField(fields, JournalTimeText(signalBar));
   JournalAddCSVField(fields, symbol);
   JournalAddCSVField(fields, ActionToText(ActionState));
   JournalAddCSVField(fields, IntegerToString(CurrentZone));
   JournalAddCSVField(fields, BiasToText(MarketBias));
   JournalAddCSVField(fields, MarketRegimeText);
   JournalAddCSVField(fields, IntegerToString(TotalScore));
   JournalAddCSVField(fields, IntegerToString(TrendScore));
   JournalAddCSVField(fields, IntegerToString(ZoneScore));
   JournalAddCSVField(fields, IntegerToString(StructureScore));
   JournalAddCSVField(fields, IntegerToString(MomentumScore));
   JournalAddCSVField(fields, EntryReason);
   JournalAddCSVField(fields, MissingConditionText);
   JournalAddCSVField(fields, ManualMarketProfileText);
   JournalAddCSVField(fields, DirectionalFilterEnabledText);
   JournalAddCSVField(fields, DirectionalFilterResultText);
   JournalAddCSVField(fields, DirectionalFilterReasonText);
   JournalAddCSVField(fields, JournalAllowedDirectionText());
   JournalAddCSVField(fields, ActionToText(candidateAction));
   JournalAddCSVField(fields, JournalBoolText(UseAutoRegimeDetection));
   JournalAddCSVField(fields, JournalBoolText(AllowAutoProfileSwitch));
   JournalAddCSVField(fields, TimeframeToText(RegimeTF));
   JournalAddCSVField(fields, IntegerToString(EffectiveRegimeLookbackBars));
   JournalAddCSVField(fields, IntegerToString(EffectiveRegimeConfirmBars));
   JournalAddCSVField(fields, IntegerToString(EffectiveRegimeSwitchThreshold));
   JournalAddCSVField(fields, IntegerToString(EffectiveRegimeHoldBars));
   JournalAddCSVField(fields, DetectedRegimeText);
   JournalAddCSVField(fields, RegimeBestCandidateText);
   JournalAddCSVField(fields, ActiveRegimeText);
   JournalAddCSVField(fields, IntegerToString(RegimeConfidence));
   JournalAddCSVField(fields, MarketDetectionStatusText);
   JournalAddCSVField(fields, AutoProfileSwitchStatusText);
   JournalAddCSVField(fields, RegimeProfileSourceText);
   JournalAddCSVField(fields, IntegerToString(RegimeWinningScore));
   JournalAddCSVField(fields, IntegerToString(RegimeScoreGap));
   JournalAddCSVField(fields, RegimeThresholdResultText);
   JournalAddCSVField(fields, RegimeConfidenceCommentText);
   JournalAddCSVField(fields, IntegerToString(UptrendScore));
   JournalAddCSVField(fields, IntegerToString(SidewayScore));
   JournalAddCSVField(fields, IntegerToString(DowntrendScore));
   JournalAddCSVField(fields, RegimeSwitchStatusText);
   JournalAddCSVField(fields, RegimeBlockingReasonText);
   JournalAddCSVField(fields, RegimeSwitchDecisionReasonText);
   JournalAddCSVField(fields, StructureStageText);
   JournalAddCSVField(fields, IntegerToString(StructureHHCount));
   JournalAddCSVField(fields, IntegerToString(StructureHLCount));
   JournalAddCSVField(fields, IntegerToString(StructureLHCount));
   JournalAddCSVField(fields, IntegerToString(StructureLLCount));
   JournalAddCSVField(fields, IntegerToString(StructureSwingPairCount));
   JournalAddCSVField(fields, StructureBOSStateText);
   JournalAddCSVField(fields, StructureCHOCHStateText);
   JournalAddCSVField(fields, StructureConfidenceText);
   JournalAddCSVField(fields, StructureMissingEvidenceText);
   JournalAddCSVField(fields,
                      JournalPriceText(StructureLastSwingHigh, symbol));
   JournalAddCSVField(fields,
                      JournalPriceText(StructurePrevSwingHigh, symbol));
   JournalAddCSVField(fields,
                      JournalPriceText(StructureLastSwingLow, symbol));
   JournalAddCSVField(fields,
                      JournalPriceText(StructurePrevSwingLow, symbol));
   JournalAddCSVField(fields, StructureValidationStageText);
   JournalAddCSVField(fields, StructureDevelopmentStateText);
   JournalAddCSVField(fields, StructureEarlyWarningText);
   JournalAddCSVField(fields, StructureEarlyWarningReasonText);
   JournalAddCSVField(fields, StructureStrongDirectionalMoveText);
   JournalAddCSVField(fields,
                      IntegerToString(StructureRecentBearishCloseCount));
   JournalAddCSVField(fields,
                      IntegerToString(StructureRecentBullishCloseCount));
   JournalAddCSVField(fields,
                      IntegerToString(StructureConsecutiveBearishBars));
   JournalAddCSVField(fields,
                      IntegerToString(StructureConsecutiveBullishBars));
   JournalAddCSVField(fields,
                      IntegerToString(StructureRecentLowerLowCount));
   JournalAddCSVField(fields,
                      IntegerToString(StructureRecentHigherHighCount));
   JournalAddCSVField(fields, PendingSwingHighStatusText);
   JournalAddCSVField(fields,
                      JournalPriceText(PendingSwingHighPrice, symbol));
   JournalAddCSVField(fields,
                      IntegerToString(PendingSwingHighRightBarsWaited));
   JournalAddCSVField(fields,
                      IntegerToString(PendingSwingHighRightBarsRequired));
   JournalAddCSVField(fields, PendingSwingLowStatusText);
   JournalAddCSVField(fields,
                      JournalPriceText(PendingSwingLowPrice, symbol));
   JournalAddCSVField(fields,
                      IntegerToString(PendingSwingLowRightBarsWaited));
   JournalAddCSVField(fields,
                      IntegerToString(PendingSwingLowRightBarsRequired));
   JournalAddCSVField(fields, JournalBoolText(UsePressureGuard));
   JournalAddCSVField(fields,
                      PressureGuardModeToText(PressureGuardMode));
   JournalAddCSVField(fields, PressureDirectionText);
   JournalAddCSVField(fields, PressureLevelText);
   JournalAddCSVField(fields, IntegerToString(PressureScore));
   JournalAddCSVField(fields, IntegerToString(BullishPressureScore));
   JournalAddCSVField(fields, IntegerToString(BearishPressureScore));
   JournalAddCSVField(fields, PressureActionText);
   JournalAddCSVField(fields, PressureBlockedDirectionText);
   JournalAddCSVField(fields, PressureReasonText);
   JournalAddCSVField(fields, PressureCandidateDirectionText);
   JournalAddCSVField(fields, PressureAfterDecisionText);
   JournalWriteCSVRow(fields);
}

void JournalLogSignal(string symbol)
{
   if(!JournalCanWrite())
      return;

   bool readySignal = (ActionState == ACTION_BUY_READY ||
                       ActionState == ACTION_SELL_READY);
   bool blockedSignal = (DirectionalFilterBlocked &&
                          (DirectionalFilterCandidateAction == ACTION_BUY_READY ||
                           DirectionalFilterCandidateAction == ACTION_SELL_READY));
   bool pressureGuardedSignal =
      ((PressureGuardStatusText == "BLOCKED" ||
        PressureGuardStatusText == "DOWNGRADED") &&
       (PressureCandidateAction == ACTION_BUY_READY ||
        PressureCandidateAction == ACTION_SELL_READY));

   if(!readySignal && !blockedSignal && !pressureGuardedSignal)
      return;

   datetime signalBar = iTime(symbol, _Period, 0);
   ENTRY_ACTION candidateAction = blockedSignal
                                   ? DirectionalFilterCandidateAction
                                   : (pressureGuardedSignal
                                      ? PressureCandidateAction
                                      : ActionState);
   int signalAction = (int)candidateAction;

   if(TREJournalLastSignalBar == signalBar &&
      TREJournalLastSignalAction == signalAction)
   {
      return;
   }

   TREJournalLastSignalBar = signalBar;
   TREJournalLastSignalAction = signalAction;
   JournalSignalsLogged++;

   if(blockedSignal)
   {
      JournalSignalsBlockedByDirectionalFilter++;

      if(candidateAction == ACTION_BUY_READY)
         JournalBuySignalsBlocked++;
      else
         JournalSellSignalsBlocked++;
   }

   JournalWriteSignalRow(symbol, signalBar, candidateAction);
   JournalTouch();
}

int JournalFindTradeByIdentifier(long identifier)
{
   for(int i = 0; i < TRE_JOURNAL_MAX_TRADES; i++)
   {
      if(TREJournalTrades[i].active &&
         TREJournalTrades[i].identifier == identifier)
      {
         return i;
      }
   }

   return -1;
}

int JournalFindFreeTradeSlot()
{
   for(int i = 0; i < TRE_JOURNAL_MAX_TRADES; i++)
   {
      if(!TREJournalTrades[i].active && TREJournalTrades[i].tradeId == 0)
         return i;
   }

   return -1;
}

string JournalPositionTypeText(long type)
{
   return (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
}

double JournalRiskReward(long type,
                         double entry,
                         double stopLoss,
                         double targetPrice)
{
   double risk = (type == POSITION_TYPE_BUY)
                 ? entry - stopLoss
                 : stopLoss - entry;
   double reward = (type == POSITION_TYPE_BUY)
                   ? targetPrice - entry
                   : entry - targetPrice;

   if(risk <= 0)
      return 0;

   return reward / risk;
}

void JournalCountEngineStatus(int engineIndex, string status)
{
   if(status == TRE_STATUS_PASS)
      TREJournalEnginePass[engineIndex]++;
   else if(status == TRE_STATUS_FAIL)
      TREJournalEngineFail[engineIndex]++;
   else if(status == TRE_STATUS_DISABLED)
      TREJournalEngineDisabled[engineIndex]++;
   else
      TREJournalEngineWait[engineIndex]++;
}

void JournalUpdateDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(equity > TREJournalPeakEquity)
      TREJournalPeakEquity = equity;

   double drawdown = TREJournalPeakEquity - equity;

   if(drawdown > TREJournalMaxDrawdown)
      TREJournalMaxDrawdown = drawdown;
}

void JournalCaptureOpenTrades(string symbol)
{
   if(!JournalCanWrite())
      return;

   int total = PositionsTotal();
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0 ||
         PositionGetString(POSITION_SYMBOL) != symbol ||
         PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
      {
         continue;
      }

      long identifier = PositionGetInteger(POSITION_IDENTIFIER);

      if(JournalFindTradeByIdentifier(identifier) >= 0)
         continue;

      int slot = JournalFindFreeTradeSlot();

      if(slot < 0)
      {
         JournalCSVStatusText = "TRACKING LIMIT REACHED";
         return;
      }

      JournalTradesOpenLogged++;
      TRE_JournalTrade trade;
      trade.active = true;
      trade.tradeId = JournalTradesOpenLogged;
      trade.ticket = ticket;
      trade.identifier = identifier;
      trade.type = PositionGetInteger(POSITION_TYPE);
      trade.openTime = (datetime)PositionGetInteger(POSITION_TIME);
      trade.lot = PositionGetDouble(POSITION_VOLUME);
      trade.entry = PositionGetDouble(POSITION_PRICE_OPEN);
      trade.stopLoss = PositionGetDouble(POSITION_SL);
      trade.takeProfit = PositionGetDouble(POSITION_TP);
      trade.zone = CurrentZone;
      trade.score = TotalScore;
      trade.researchMode = ResearchDecisionModeText;
      trade.reason = EntryReason;
      trade.plannedRR = JournalRiskReward(trade.type,
                                          trade.entry,
                                          trade.stopLoss,
                                          trade.takeProfit);
      trade.trendStatus = TrendEngineStatusText;
      trade.zoneStatus = ZoneEngineStatusText;
      trade.structureStatus = StructureEngineStatusText;
      trade.momentumStatus = MomentumEngineStatusText;
      TREJournalTrades[slot] = trade;

      if(trade.type == POSITION_TYPE_BUY)
         TREJournalBuyTrades++;
      else
         TREJournalSellTrades++;

      if(trade.zone >= 1 && trade.zone <= 6)
         TREJournalZoneTrades[trade.zone]++;

      JournalCountEngineStatus(0, trade.trendStatus);
      JournalCountEngineStatus(1, trade.zoneStatus);
      JournalCountEngineStatus(2, trade.structureStatus);
      JournalCountEngineStatus(3, trade.momentumStatus);

      FileWrite(TREJournalHandle,
                "TRADE_OPEN",
                trade.tradeId,
                JournalTimeText(trade.openTime),
                (long)trade.ticket,
                JournalPositionTypeText(trade.type),
                symbol,
                DoubleToString(trade.lot, 4),
                DoubleToString(trade.entry, digits),
                DoubleToString(trade.stopLoss, digits),
                DoubleToString(trade.takeProfit, digits),
                trade.zone,
                BiasToText(MarketBias),
                MarketRegimeText,
                trade.score,
                trade.researchMode,
                trade.reason,
                DoubleToString(trade.plannedRR, 2),
                trade.trendStatus,
                trade.zoneStatus,
                trade.structureStatus,
                trade.momentumStatus);
      JournalTouch();
   }
}

bool JournalPositionStillOpen(long identifier)
{
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      if(PositionGetTicket(i) == 0)
         continue;

      if(PositionGetInteger(POSITION_IDENTIFIER) == identifier)
         return true;
   }

   return false;
}

string JournalCloseReason(long reason)
{
   if(reason == DEAL_REASON_TP) return "TP";
   if(reason == DEAL_REASON_SL) return "SL";
   if(reason == DEAL_REASON_CLIENT ||
      reason == DEAL_REASON_MOBILE ||
      reason == DEAL_REASON_WEB) return "MANUAL";
   if(reason == DEAL_REASON_EXPERT) return "TESTER_CLOSE";
   return "UNKNOWN";
}

bool JournalReadCloseDeal(TRE_JournalTrade &trade,
                          datetime &closeTime,
                          double &closePrice,
                          double &profit,
                          double &swap,
                          double &commission,
                          string &closeReason)
{
   if(!HistorySelect(trade.openTime, TimeCurrent()))
      return false;

   bool closeFound = false;
   long finalReason = -1;
   int total = HistoryDealsTotal();
   profit = 0;
   swap = 0;
   commission = 0;

   for(int i = 0; i < total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);

      if(dealTicket == 0 ||
         HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) != trade.identifier)
      {
         continue;
      }

      profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      swap += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      commission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

      long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

      if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY)
         continue;

      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);

      if(!closeFound || dealTime >= closeTime)
      {
         closeFound = true;
         closeTime = dealTime;
         closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         finalReason = HistoryDealGetInteger(dealTicket, DEAL_REASON);
      }
   }

   closeReason = JournalCloseReason(finalReason);
   return closeFound;
}

void JournalWriteClosedTrade(int index, string symbol)
{
   TRE_JournalTrade trade = TREJournalTrades[index];
   datetime closeTime = 0;
   double closePrice = 0;
   double profit = 0;
   double swap = 0;
   double commission = 0;
   string closeReason = "UNKNOWN";

   if(!JournalReadCloseDeal(trade,
                            closeTime,
                            closePrice,
                            profit,
                            swap,
                            commission,
                            closeReason))
   {
      return;
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   ENUM_TIMEFRAMES holdingTF = ExecutionTF;
   int barsHeld = TRE_CalculateHoldingBars(symbol,
                                           trade.openTime,
                                           closeTime,
                                           holdingTF);

   if(TimeoutLastCloseResultText == "OK" &&
      trade.identifier == TimeoutLastPositionIdentifier)
   {
      closeReason = "TIMEOUT";
   }

   double netProfit = profit + swap + commission;
   double realizedRR = JournalRiskReward(trade.type,
                                         trade.entry,
                                         trade.stopLoss,
                                         closePrice);

   JournalTradesCloseLogged++;
   TREJournalTotalHoldingBars += barsHeld;

   if(barsHeld > TREJournalMaxBarsHeld)
      TREJournalMaxBarsHeld = barsHeld;

   if(closeReason == "TIMEOUT")
      TREJournalTimeoutClosedTrades++;

   if(netProfit > 0)
   {
      TREJournalWinTrades++;
      TREJournalGrossProfit += netProfit;
      TREJournalWinningProfit += netProfit;
      TREJournalCurrentWinStreak++;
      TREJournalCurrentLossStreak = 0;

      if(netProfit > TREJournalLargestWin)
         TREJournalLargestWin = netProfit;

      if(TREJournalCurrentWinStreak > TREJournalMaxWinStreak)
         TREJournalMaxWinStreak = TREJournalCurrentWinStreak;
   }
   else
   {
      TREJournalLossTrades++;
      TREJournalGrossLoss += netProfit;
      TREJournalLosingProfit += netProfit;
      TREJournalCurrentLossStreak++;
      TREJournalCurrentWinStreak = 0;

      if(netProfit < TREJournalLargestLoss)
         TREJournalLargestLoss = netProfit;

      if(TREJournalCurrentLossStreak > TREJournalMaxLossStreak)
         TREJournalMaxLossStreak = TREJournalCurrentLossStreak;
   }

   TREJournalNetProfit += netProfit;

   if(trade.zone >= 1 && trade.zone <= 6)
   {
      TREJournalZoneClosedTrades[trade.zone]++;

      if(netProfit > 0)
         TREJournalZoneWins[trade.zone]++;

      TREJournalZoneProfit[trade.zone] += netProfit;
   }

   FileWrite(TREJournalHandle,
             "TRADE_CLOSE",
             trade.tradeId,
             JournalTimeText(closeTime),
             (long)trade.ticket,
             JournalPositionTypeText(trade.type),
             symbol,
             DoubleToString(trade.lot, 4),
             DoubleToString(trade.entry, digits),
             DoubleToString(closePrice, digits),
             DoubleToString(trade.stopLoss, digits),
             DoubleToString(trade.takeProfit, digits),
             DoubleToString(profit, 2),
             DoubleToString(swap, 2),
             DoubleToString(commission, 2),
             DoubleToString(netProfit, 2),
             closeReason,
             barsHeld,
             DoubleToString(realizedRR, 2),
             DoubleToString(netProfit, 2),
             barsHeld,
             closeReason);

   TREJournalTrades[index].active = false;
   TREJournalTrades[index].tradeId = 0;
   TREJournalTrades[index].ticket = 0;
   TREJournalTrades[index].identifier = 0;
   JournalTouch();
}

void JournalCaptureClosedTrades(string symbol)
{
   if(!JournalCanWrite())
      return;

   for(int i = 0; i < TRE_JOURNAL_MAX_TRADES; i++)
   {
      if(!TREJournalTrades[i].active)
         continue;

      if(JournalPositionStillOpen(TREJournalTrades[i].identifier))
         continue;

      JournalWriteClosedTrade(i, symbol);
   }
}

void JournalEngine(string symbol)
{
   if(!JournalCanWrite())
      return;

   JournalUpdateDrawdown();
   JournalLogSignal(symbol);
   JournalCaptureOpenTrades(symbol);
   JournalCaptureClosedTrades(symbol);
}

void JournalWriteSummary()
{
   int totalTrades = JournalTradesCloseLogged;
   double winRate = (totalTrades > 0)
                    ? ((double)TREJournalWinTrades / totalTrades) * 100.0
                    : 0;
   string profitFactor = (TREJournalGrossLoss < 0)
                         ? DoubleToString(TREJournalGrossProfit /
                                          MathAbs(TREJournalGrossLoss), 2)
                         : "N/A";
   string averageProfit = (TREJournalWinTrades > 0)
                          ? DoubleToString(TREJournalWinningProfit /
                                           TREJournalWinTrades, 2)
                          : "N/A";
   string averageLoss = (TREJournalLossTrades > 0)
                        ? DoubleToString(TREJournalLosingProfit /
                                         TREJournalLossTrades, 2)
                        : "N/A";
   string expectedPayoff = (totalTrades > 0)
                           ? DoubleToString(TREJournalNetProfit /
                                            totalTrades, 2)
                           : "N/A";
   string averageHoldingBars = (totalTrades > 0)
                               ? DoubleToString((double)TREJournalTotalHoldingBars /
                                                totalTrades, 2)
                               : "N/A";

   FileWrite(TREJournalHandle, "[SUMMARY]");
   FileWrite(TREJournalHandle, "SUMMARY", "TotalTrades", totalTrades);
   FileWrite(TREJournalHandle, "SUMMARY", "BuyTrades", TREJournalBuyTrades);
   FileWrite(TREJournalHandle, "SUMMARY", "SellTrades", TREJournalSellTrades);
   FileWrite(TREJournalHandle, "SUMMARY", "WinTrades", TREJournalWinTrades);
   FileWrite(TREJournalHandle, "SUMMARY", "LossTrades", TREJournalLossTrades);
   FileWrite(TREJournalHandle, "SUMMARY", "WinRate", DoubleToString(winRate, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "GrossProfit", DoubleToString(TREJournalGrossProfit, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "GrossLoss", DoubleToString(TREJournalGrossLoss, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "NetProfit", DoubleToString(TREJournalNetProfit, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "ProfitFactor", profitFactor);
   FileWrite(TREJournalHandle, "SUMMARY", "LargestWin", DoubleToString(TREJournalLargestWin, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "LargestLoss", DoubleToString(TREJournalLargestLoss, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "MaxConsecutiveWins", TREJournalMaxWinStreak);
   FileWrite(TREJournalHandle, "SUMMARY", "MaxConsecutiveLosses", TREJournalMaxLossStreak);
   FileWrite(TREJournalHandle, "SUMMARY", "MaxDrawdown", DoubleToString(TREJournalMaxDrawdown, 2));
   FileWrite(TREJournalHandle, "SUMMARY", "AverageWin", averageProfit);
   FileWrite(TREJournalHandle, "SUMMARY", "AverageLoss", averageLoss);
   FileWrite(TREJournalHandle, "SUMMARY", "ExpectedPayoff", expectedPayoff);
   FileWrite(TREJournalHandle, "SUMMARY", "AverageHoldingBars", averageHoldingBars);
   FileWrite(TREJournalHandle, "SUMMARY", "AverageBarsHeld", averageHoldingBars);
   FileWrite(TREJournalHandle, "SUMMARY", "MaxBarsHeld", TREJournalMaxBarsHeld);
   FileWrite(TREJournalHandle, "SUMMARY", "TimeoutClosedTrades",
             TREJournalTimeoutClosedTrades);
   FileWrite(TREJournalHandle, "SUMMARY",
             "SignalsBlockedByDirectionalFilter",
             JournalSignalsBlockedByDirectionalFilter);
   FileWrite(TREJournalHandle, "SUMMARY",
             "BuySignalsBlocked",
             JournalBuySignalsBlocked);
   FileWrite(TREJournalHandle, "SUMMARY",
             "SellSignalsBlocked",
             JournalSellSignalsBlocked);
}

void JournalWriteZoneStatistics()
{
   FileWrite(TREJournalHandle, "[ZONE_STATISTICS]");

   for(int zone = 1; zone <= 6; zone++)
   {
      string zoneName = "Zone" + IntegerToString(zone);
      string winRate = (TREJournalZoneClosedTrades[zone] > 0)
                       ? DoubleToString(
                            ((double)TREJournalZoneWins[zone] /
                             TREJournalZoneClosedTrades[zone]) * 100.0, 2)
                       : "N/A";
      string averageProfit = (TREJournalZoneClosedTrades[zone] > 0)
                             ? DoubleToString(
                                  TREJournalZoneProfit[zone] /
                                  TREJournalZoneClosedTrades[zone], 2)
                             : "N/A";

      FileWrite(TREJournalHandle,
                "ZONE_STATISTICS",
                zoneName + "Count",
                TREJournalZoneTrades[zone]);
      FileWrite(TREJournalHandle,
                "ZONE_STATISTICS",
                zoneName + "ClosedCount",
                TREJournalZoneClosedTrades[zone]);
      FileWrite(TREJournalHandle,
                "ZONE_STATISTICS",
                zoneName + "WinRate",
                winRate);
      FileWrite(TREJournalHandle,
                "ZONE_STATISTICS",
                zoneName + "AverageProfit",
                averageProfit);
   }
}

string JournalEngineName(int index)
{
   if(index == 0) return "Trend";
   if(index == 1) return "Zone";
   if(index == 2) return "Structure";
   if(index == 3) return "Momentum";
   return "Unknown";
}

void JournalWriteEngineStatistics()
{
   FileWrite(TREJournalHandle, "[ENGINE_STATISTICS]");

   for(int engine = 0; engine < TRE_ENGINE_SCORE_COUNT; engine++)
   {
      string name = JournalEngineName(engine);
      FileWrite(TREJournalHandle, "ENGINE_STATISTICS", name, "PASS",
                TREJournalEnginePass[engine]);
      FileWrite(TREJournalHandle, "ENGINE_STATISTICS", name, "FAIL",
                TREJournalEngineFail[engine]);
      FileWrite(TREJournalHandle, "ENGINE_STATISTICS", name, "WAIT",
                TREJournalEngineWait[engine]);
      FileWrite(TREJournalHandle, "ENGINE_STATISTICS", name, "DISABLED",
                TREJournalEngineDisabled[engine]);
   }
}

void JournalFinalize(string symbol)
{
   if(TREJournalFinalized)
      return;

   if(!JournalCanWrite())
   {
      TREJournalFinalized = true;
      return;
   }

   JournalUpdateDrawdown();
   JournalCaptureOpenTrades(symbol);
   JournalCaptureClosedTrades(symbol);
   FileWrite(TREJournalHandle, "PARAMETER", "DateRangeEnd", JournalTimeText(TimeCurrent()));
   JournalWriteSummary();
   JournalWriteZoneStatistics();
   JournalWriteEngineStatistics();
   JournalTouch();
   JournalCSVStatusText = "FINALIZED";
   FileClose(TREJournalHandle);
   TREJournalHandle = INVALID_HANDLE;
   TREJournalFinalized = true;
}

#endif
