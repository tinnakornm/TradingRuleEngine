//+------------------------------------------------------------------+
//| engine/adaptive_loss_cluster_engine_v2_reserved.mqh              |
//| Reserved advanced feature-similarity prototype; not included     |
//+------------------------------------------------------------------+
#ifndef TRE_ADAPTIVE_LOSS_CLUSTER_ENGINE_V2_RESERVED_MQH
#define TRE_ADAPTIVE_LOSS_CLUSTER_ENGINE_V2_RESERVED_MQH

#define TRE_ADAPTIVE_MAX_TRACKED_TRADES 32
#define TRE_ADAPTIVE_MAX_CLUSTER_LOSSES 32
#define TRE_ADAPTIVE_FEATURE_COUNT 6

struct TRE_AdaptivePattern
{
   int direction;
   int zone;
   int pressure;
   int emaAlignment;
   int swingDirection;
   int atrBucket;
};

struct TRE_AdaptiveTrackedTrade
{
   bool active;
   long identifier;
   datetime openTime;
   TRE_AdaptivePattern pattern;
};

TRE_AdaptiveTrackedTrade TREAdaptiveTracked[
   TRE_ADAPTIVE_MAX_TRACKED_TRADES];
TRE_AdaptivePattern TREAdaptiveLossPatterns[
   TRE_ADAPTIVE_MAX_CLUSTER_LOSSES];
double TREAdaptiveLossMoney[TRE_ADAPTIVE_MAX_CLUSTER_LOSSES];
int TREAdaptiveLossCount = 0;

bool AdaptiveFilterActive = false;
TRE_AdaptivePattern TREAdaptiveBlockedPattern;
int AdaptiveFilterRemainingBars = 0;
datetime TREAdaptiveLastCooldownBar = 0;
datetime TREAdaptiveLastEvaluationBar = 0;
int TREAdaptiveLastEvaluationDirection = 0;
double TREAdaptiveClusterAverageLoss = 0;

string AdaptiveFilterStatusText = "INACTIVE";
string AdaptiveFilterPatternText = "NONE";
string AdaptiveFilterExpiredText = "NO";
string AdaptiveFilterLastReasonText = "N/A";
int AdaptiveFilterBlockedTrades = 0;
int AdaptiveFilterExpiredCount = 0;
int AdaptiveFilterCreatedCount = 0;
int AdaptiveFilterCandidateCount = 0;
int AdaptiveFilterTotalClusterLength = 0;
int AdaptiveFilterLastClusterSize = 0;
double AdaptiveFilterEstimatedSavedLoss = 0;
double AdaptiveFilterAverageClusterLength = 0;
double AdaptiveFilterHitRate = 0;

int AdaptiveAuditSerial = 0;
string AdaptiveAuditDecision = "NONE";
string AdaptiveAuditReason = "N/A";
string AdaptiveAuditDetail = "N/A";

int AdaptiveEffectiveThreshold()
{
   return (int)MathMax(1, LossClusterThreshold);
}

int AdaptiveEffectiveCooldown()
{
   return (int)MathMax(1, LossClusterCooldownBars);
}

int AdaptivePressureSignature(int direction, int state)
{
   return (direction * 10) + state;
}

int AdaptiveATRBucket(double atrPercent)
{
   if(atrPercent < 0.25) return 0;
   if(atrPercent < 0.75) return 1;
   return 2;
}

int AdaptiveCurrentSwingDirection()
{
   if(StructureLastSwingHighBarIndex >= 0 &&
      (StructureLastSwingLowBarIndex < 0 ||
       StructureLastSwingHighBarIndex <
       StructureLastSwingLowBarIndex))
   {
      return -1;
   }
   if(StructureLastSwingLowBarIndex >= 0)
      return 1;
   return 0;
}

string AdaptiveDirectionText(int direction)
{
   return (direction > 0) ? "BUY" : "SELL";
}

string AdaptivePressureText(int signature)
{
   int direction = signature / 10;
   int state = signature % 10;
   string directionText = "NONE";
   string stateText = "LOW";
   if(direction == (int)PRESSURE_UP) directionText = "UP";
   else if(direction == (int)PRESSURE_DOWN) directionText = "DOWN";
   if(state == (int)PRESSURE_HIGH) stateText = "HIGH";
   else if(state == (int)PRESSURE_MEDIUM) stateText = "MEDIUM";
   return directionText + "/" + stateText;
}

string AdaptivePatternText(TRE_AdaptivePattern &pattern)
{
   return "D=" + AdaptiveDirectionText(pattern.direction) +
          " Z=" + IntegerToString(pattern.zone) +
          " P=" + AdaptivePressureText(pattern.pressure) +
          " EMA=" + IntegerToString(pattern.emaAlignment);
}

int AdaptivePatternFeature(TRE_AdaptivePattern &pattern, int feature)
{
   if(feature == 0) return pattern.direction;
   if(feature == 1) return pattern.zone;
   if(feature == 2) return pattern.pressure;
   if(feature == 3) return pattern.emaAlignment;
   if(feature == 4) return pattern.swingDirection;
   return pattern.atrBucket;
}

int AdaptiveModalFeature(int feature, int &frequency)
{
   int mode = 0;
   frequency = 0;
   for(int i = 0; i < TREAdaptiveLossCount; i++)
   {
      int candidate =
         AdaptivePatternFeature(TREAdaptiveLossPatterns[i], feature);
      int count = 0;
      for(int j = 0; j < TREAdaptiveLossCount; j++)
      {
         if(AdaptivePatternFeature(
               TREAdaptiveLossPatterns[j], feature) == candidate)
            count++;
      }
      if(count > frequency)
      {
         frequency = count;
         mode = candidate;
      }
   }
   return mode;
}

void AdaptiveRefreshStatistics()
{
   AdaptiveFilterAverageClusterLength =
      (AdaptiveFilterCreatedCount > 0)
      ? (double)AdaptiveFilterTotalClusterLength /
        AdaptiveFilterCreatedCount
      : 0;
   AdaptiveFilterHitRate =
      (AdaptiveFilterCandidateCount > 0)
      ? 100.0 * AdaptiveFilterBlockedTrades /
        AdaptiveFilterCandidateCount
      : 0;
}

void AdaptiveActivateFilter()
{
   if(TREAdaptiveLossCount < AdaptiveEffectiveThreshold())
      return;

   int modes[TRE_ADAPTIVE_FEATURE_COUNT];
   int stableFeatures = 0;
   for(int feature = 0; feature < TRE_ADAPTIVE_FEATURE_COUNT; feature++)
   {
      int frequency = 0;
      modes[feature] = AdaptiveModalFeature(feature, frequency);
      if(frequency * 100 >= TREAdaptiveLossCount * 70)
         stableFeatures++;
   }

   // At least 70% of six features means five or more stable features.
   if(stableFeatures * 100 <
      TRE_ADAPTIVE_FEATURE_COUNT * 70)
   {
      return;
   }

   TREAdaptiveBlockedPattern.direction = modes[0];
   TREAdaptiveBlockedPattern.zone = modes[1];
   TREAdaptiveBlockedPattern.pressure = modes[2];
   TREAdaptiveBlockedPattern.emaAlignment = modes[3];
   TREAdaptiveBlockedPattern.swingDirection = modes[4];
   TREAdaptiveBlockedPattern.atrBucket = modes[5];

   double lossTotal = 0;
   for(int i = 0; i < TREAdaptiveLossCount; i++)
      lossTotal += MathAbs(TREAdaptiveLossMoney[i]);
   TREAdaptiveClusterAverageLoss =
      (TREAdaptiveLossCount > 0)
      ? lossTotal / TREAdaptiveLossCount
      : 0;

   AdaptiveFilterActive = true;
   AdaptiveFilterRemainingBars = AdaptiveEffectiveCooldown();
   TREAdaptiveLastCooldownBar = 0;
   AdaptiveFilterStatusText = "ACTIVE";
   AdaptiveFilterExpiredText = "NO";
   AdaptiveFilterPatternText =
      AdaptivePatternText(TREAdaptiveBlockedPattern);
   AdaptiveFilterCreatedCount++;
   AdaptiveFilterTotalClusterLength += TREAdaptiveLossCount;
   AdaptiveFilterLastClusterSize = TREAdaptiveLossCount;
   AdaptiveRefreshStatistics();
   Print("[ADAPTIVE_LOSS_CLUSTER] action=ACTIVATE pattern=",
         AdaptiveFilterPatternText,
         " cluster_size=", TREAdaptiveLossCount,
         " stable_features=", stableFeatures, "/",
         TRE_ADAPTIVE_FEATURE_COUNT,
         " cooldown_bars=", AdaptiveFilterRemainingBars);

   // Start a fresh consecutive sequence after creating a filter.
   TREAdaptiveLossCount = 0;
}

void AdaptiveAppendLoss(TRE_AdaptivePattern &pattern, double netProfit)
{
   if(TREAdaptiveLossCount >= TRE_ADAPTIVE_MAX_CLUSTER_LOSSES)
   {
      for(int i = 1; i < TRE_ADAPTIVE_MAX_CLUSTER_LOSSES; i++)
      {
         TREAdaptiveLossPatterns[i - 1] =
            TREAdaptiveLossPatterns[i];
         TREAdaptiveLossMoney[i - 1] = TREAdaptiveLossMoney[i];
      }
      TREAdaptiveLossCount = TRE_ADAPTIVE_MAX_CLUSTER_LOSSES - 1;
   }
   TREAdaptiveLossPatterns[TREAdaptiveLossCount] = pattern;
   TREAdaptiveLossMoney[TREAdaptiveLossCount] = netProfit;
   TREAdaptiveLossCount++;
   AdaptiveActivateFilter();
}

bool AdaptivePositionStillOpen(long identifier)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0 &&
         PositionGetInteger(POSITION_IDENTIFIER) == identifier)
      {
         return true;
      }
   }
   return false;
}

bool AdaptiveReadClosedProfit(long identifier,
                              datetime openTime,
                              double &netProfit)
{
   netProfit = 0;
   if(!HistorySelect(openTime, TimeCurrent()))
      return false;
   bool closeFound = false;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         HistoryDealGetInteger(deal, DEAL_POSITION_ID) != identifier)
      {
         continue;
      }
      netProfit += HistoryDealGetDouble(deal, DEAL_PROFIT);
      netProfit += HistoryDealGetDouble(deal, DEAL_SWAP);
      netProfit += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         closeFound = true;
   }
   return closeFound;
}

void AdaptiveCaptureClosedTrades()
{
   for(int i = 0; i < TRE_ADAPTIVE_MAX_TRACKED_TRADES; i++)
   {
      if(!TREAdaptiveTracked[i].active ||
         AdaptivePositionStillOpen(TREAdaptiveTracked[i].identifier))
      {
         continue;
      }

      double netProfit = 0;
      if(!AdaptiveReadClosedProfit(
            TREAdaptiveTracked[i].identifier,
            TREAdaptiveTracked[i].openTime,
            netProfit))
      {
         continue;
      }

      if(netProfit < 0)
      {
         AdaptiveAppendLoss(TREAdaptiveTracked[i].pattern, netProfit);
      }
      else
      {
         // A win or break-even ends the consecutive-loss sequence.
         TREAdaptiveLossCount = 0;
      }
      TREAdaptiveTracked[i].active = false;
   }
}

void AdaptiveUpdateCooldown(string symbol)
{
   if(!AdaptiveFilterActive)
      return;
   datetime bar = iTime(symbol, EntryTF, 0);
   if(bar <= 0)
      return;
   if(TREAdaptiveLastCooldownBar == 0)
   {
      TREAdaptiveLastCooldownBar = bar;
      return;
   }
   if(bar == TREAdaptiveLastCooldownBar)
      return;
   TREAdaptiveLastCooldownBar = bar;
   AdaptiveFilterRemainingBars =
      (int)MathMax(0, AdaptiveFilterRemainingBars - 1);
   if(AdaptiveFilterRemainingBars > 0)
      return;

   AdaptiveFilterActive = false;
   AdaptiveFilterStatusText = "EXPIRED";
   AdaptiveFilterExpiredText = "YES";
   AdaptiveFilterExpiredCount++;
   Print("[ADAPTIVE_LOSS_CLUSTER] action=EXPIRE pattern=",
         AdaptiveFilterPatternText);
}

bool AdaptiveBuildCurrentPattern(string symbol,
                                 ENTRY_ACTION action,
                                 TRE_AdaptivePattern &pattern)
{
   pattern.direction =
      (action == ACTION_BUY_READY) ? 1 : -1;
   pattern.zone = CurrentZone;
   pattern.pressure =
      AdaptivePressureSignature(
         (int)PressureDirection, (int)PressureLevel);
   pattern.swingDirection = AdaptiveCurrentSwingDirection();

   double ema20 = 0;
   double ema50 = 0;
   double ema100 = 0;
   double ema200 = 0;
   double previous = 0;
   bool emaValid =
      MarketSnapshotReadEMA(symbol, EntryTF, 20, ema20, previous) &&
      MarketSnapshotReadEMA(symbol, EntryTF, 50, ema50, previous) &&
      MarketSnapshotReadEMA(symbol, EntryTF, 100, ema100, previous) &&
      MarketSnapshotReadEMA(symbol, EntryTF, 200, ema200, previous);
   if(!emaValid)
      return false;
   pattern.emaAlignment =
      MarketSnapshotComparison(ema20, ema50) +
      MarketSnapshotComparison(ema50, ema100) +
      MarketSnapshotComparison(ema100, ema200);

   double atr = 0;
   double close = iClose(symbol, EntryTF, 0);
   if(!MarketSnapshotReadATR(symbol, EntryTF, ATRPeriod, atr) ||
      close <= 0)
   {
      return false;
   }
   pattern.atrBucket = AdaptiveATRBucket((atr / close) * 100.0);
   return true;
}

bool AdaptivePatternMatches(TRE_AdaptivePattern &candidate)
{
   return (
      candidate.direction == TREAdaptiveBlockedPattern.direction &&
      candidate.zone == TREAdaptiveBlockedPattern.zone &&
      candidate.pressure == TREAdaptiveBlockedPattern.pressure &&
      candidate.emaAlignment ==
         TREAdaptiveBlockedPattern.emaAlignment);
}

void AdaptiveRegisterBlockAudit(string symbol,
                                TRE_AdaptivePattern &candidate)
{
   string reason = "BLOCK_ADAPTIVE_LOSS_CLUSTER_PATTERN";
   AdaptiveAuditDecision = "BLOCK";
   AdaptiveAuditReason = reason;
   AdaptiveAuditDetail =
      "Rule=AdaptiveLossCluster;Decision=BLOCK;MatchedPattern=" +
      AdaptivePatternText(candidate) +
      ";LossClusterSize=" +
      IntegerToString(AdaptiveFilterLastClusterSize) +
      ";RemainingCooldown=" +
      IntegerToString(AdaptiveFilterRemainingBars);
   AdaptiveAuditSerial++;
   AdaptiveFilterLastReasonText = reason;
   Print("[ADAPTIVE_LOSS_CLUSTER] action=BLOCK symbol=", symbol,
         " pattern=", AdaptivePatternText(candidate),
         " loss_cluster_size=", AdaptiveFilterLastClusterSize,
         " remaining_cooldown=", AdaptiveFilterRemainingBars);
}

bool AdaptiveLossClusterAllowsEntry(string symbol,
                                    ENTRY_ACTION action,
                                    string &reason)
{
   reason = "OK";
   if(!EnableAdaptiveLossCluster || !AdaptiveFilterActive)
      return true;

   TRE_AdaptivePattern candidate;
   if(!AdaptiveBuildCurrentPattern(symbol, action, candidate))
   {
      reason = "Adaptive pattern inputs unavailable; fail-open";
      return true;
   }

   datetime bar = iTime(symbol, EntryTF, 0);
   bool freshEvaluation =
      (bar != TREAdaptiveLastEvaluationBar ||
       candidate.direction != TREAdaptiveLastEvaluationDirection);
   if(freshEvaluation)
   {
      TREAdaptiveLastEvaluationBar = bar;
      TREAdaptiveLastEvaluationDirection = candidate.direction;
      AdaptiveFilterCandidateCount++;
   }

   if(!AdaptivePatternMatches(candidate))
   {
      AdaptiveRefreshStatistics();
      return true;
   }

   reason = "BLOCK_ADAPTIVE_LOSS_CLUSTER_PATTERN";
   if(freshEvaluation)
   {
      AdaptiveFilterBlockedTrades++;
      AdaptiveFilterEstimatedSavedLoss +=
         TREAdaptiveClusterAverageLoss;
      AdaptiveRegisterBlockAudit(symbol, candidate);
      AdaptiveRefreshStatistics();
   }
   return false;
}

int AdaptiveFindTracked(long identifier)
{
   for(int i = 0; i < TRE_ADAPTIVE_MAX_TRACKED_TRADES; i++)
      if(TREAdaptiveTracked[i].active &&
         TREAdaptiveTracked[i].identifier == identifier)
         return i;
   return -1;
}

int AdaptiveFreeTrackedSlot()
{
   for(int i = 0; i < TRE_ADAPTIVE_MAX_TRACKED_TRADES; i++)
      if(!TREAdaptiveTracked[i].active)
         return i;
   return -1;
}

bool AdaptiveLossClusterRegisterOpenPosition(string symbol)
{
   if(!EnableAdaptiveLossCluster || !TREMarketSnapshotReady)
      return false;

   int selected = -1;
   datetime newest = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         PositionGetString(POSITION_SYMBOL) != symbol ||
         PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
      {
         continue;
      }
      long identifier = PositionGetInteger(POSITION_IDENTIFIER);
      if(AdaptiveFindTracked(identifier) >= 0)
         continue;
      datetime openTime =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(selected < 0 || openTime >= newest)
      {
         selected = i;
         newest = openTime;
      }
   }
   if(selected < 0 || PositionGetTicket(selected) == 0)
      return false;

   long identifier = PositionGetInteger(POSITION_IDENTIFIER);
   int slot = AdaptiveFreeTrackedSlot();
   if(identifier <= 0 || slot < 0)
      return false;

   TREAdaptiveTracked[slot].active = true;
   TREAdaptiveTracked[slot].identifier = identifier;
   TREAdaptiveTracked[slot].openTime =
      (datetime)PositionGetInteger(POSITION_TIME);
   TREAdaptiveTracked[slot].pattern.direction =
      TREPendingMarketSnapshot.direction;
   TREAdaptiveTracked[slot].pattern.zone =
      TREPendingMarketSnapshot.currentZone;
   TREAdaptiveTracked[slot].pattern.pressure =
      AdaptivePressureSignature(
         TREPendingMarketSnapshot.pressureDirection,
         TREPendingMarketSnapshot.pressureState);
   TREAdaptiveTracked[slot].pattern.emaAlignment =
      TREPendingMarketSnapshot.emaAlignmentScore;
   TREAdaptiveTracked[slot].pattern.swingDirection =
      TREPendingMarketSnapshot.currentSwingDirection;
   TREAdaptiveTracked[slot].pattern.atrBucket =
      AdaptiveATRBucket(TREPendingMarketSnapshot.atrPercent);
   return true;
}

void AdaptiveLossClusterEngine(string symbol)
{
   if(!EnableAdaptiveLossCluster)
   {
      AdaptiveFilterStatusText = "DISABLED";
      return;
   }
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0)
   {
      AdaptiveFilterStatusText = "TESTER_ONLY";
      return;
   }

   AdaptiveUpdateCooldown(symbol);
   AdaptiveCaptureClosedTrades();
   if(!AdaptiveFilterActive &&
      AdaptiveFilterStatusText != "EXPIRED")
   {
      AdaptiveFilterStatusText = "INACTIVE";
   }
   AdaptiveRefreshStatistics();
}

#endif
