//+------------------------------------------------------------------+
//| engine/adaptive_loss_cluster_engine.mqh                          |
//| Pure v1: consecutive-loss Direction + Zone filter only           |
//+------------------------------------------------------------------+
#ifndef TRE_ADAPTIVE_LOSS_CLUSTER_ENGINE_MQH
#define TRE_ADAPTIVE_LOSS_CLUSTER_ENGINE_MQH

#define TRE_ADAPTIVE_V1_MAX_TRACKED 32
#define TRE_ADAPTIVE_V1_MAX_LOSSES 64
#define TRE_ADAPTIVE_V1_AUDIT_QUEUE 32

struct TRE_AdaptiveV1TrackedTrade
{
   bool active;
   long identifier;
   datetime openTime;
   int direction;
   int zone;
};

struct TRE_AdaptiveV1ClosedTrade
{
   int trackedIndex;
   long identifier;
   datetime closeTime;
   double profit;
   int direction;
   int zone;
};

TRE_AdaptiveV1TrackedTrade TREAdaptiveV1Tracked[
   TRE_ADAPTIVE_V1_MAX_TRACKED];
int TREAdaptiveV1LossDirection[TRE_ADAPTIVE_V1_MAX_LOSSES];
int TREAdaptiveV1LossZone[TRE_ADAPTIVE_V1_MAX_LOSSES];
int TREAdaptiveV1LossCount = 0;

bool AdaptiveV1BlockActive = false;
int AdaptiveV1BlockedDirection = 0;
int AdaptiveV1BlockedZone = 0;
int AdaptiveV1RemainingCooldownBars = 0;
datetime AdaptiveV1LastCooldownBar = 0;
string AdaptiveV1LastCandidateKey = "";
string AdaptiveV1LastBlockedCandidateKey = "";
int AdaptiveV1LastBlockedAuditSerial = 0;

int AdaptiveV1CurrentLossStreak = 0;
int AdaptiveV1MaxLossCluster = 0;
int AdaptiveEvaluationCount = 0;
int AdaptiveCandidateSignalCount = 0;
int AdaptiveTotalBlockedOpportunities = 0;
int AdaptiveExecutedTradeCount = 0;
int AdaptiveActivationCount = 0;
int AdaptiveExpireCount = 0;
long AdaptiveCurrentEpisodeID = 0;
int AdaptiveEpisodeCount = 0;
int AdaptiveActiveEpisodes = 0;
int AdaptiveExpiredEpisodes = 0;
int AdaptiveCurrentEpisodeBlockedOpportunities = 0;
int AdaptiveMaxBlockedOpportunitiesInEpisode = 0;
string AdaptiveMostBlockedPattern = "NONE";
string AdaptiveLastEpisodePattern = "NONE";
int AdaptiveLastEpisodeBlockedOpportunities = 0;
int AdaptiveV1LastBlockedDirection = 0;
int AdaptiveV1LastBlockedZone = 0;
string AdaptiveV1StatusText = "INACTIVE";
string AdaptiveV1PatternText = "NONE";
string AdaptiveV1LastActionText = "NONE";
int AdaptiveValidatedPatternCount = 0;
int AdaptiveIgnoredPatternCount = 0;
string AdaptiveActivatedPattern = "NONE";

int AdaptiveV1AuditSerial = 0;
string AdaptiveV1AuditEvent[TRE_ADAPTIVE_V1_AUDIT_QUEUE];
string AdaptiveV1AuditReason[TRE_ADAPTIVE_V1_AUDIT_QUEUE];
string AdaptiveV1AuditDetail[TRE_ADAPTIVE_V1_AUDIT_QUEUE];
datetime AdaptiveV1AuditTime[TRE_ADAPTIVE_V1_AUDIT_QUEUE];
long AdaptiveV1AuditEpisodeID[TRE_ADAPTIVE_V1_AUDIT_QUEUE];

int AdaptiveEffectiveThreshold()
{
   return (int)MathMax(1, LossClusterThreshold);
}

int AdaptiveEffectiveCooldown()
{
   return (int)MathMax(1, LossClusterCooldownBars);
}

string AdaptiveClusterModeText()
{
   if(AdaptiveClusterMode == ADAPTIVE_CLUSTER_ADVANCED_RESERVED)
      return "ADVANCED_RESERVED_DISABLED";
   return "SIMPLE_DIRECTION_ZONE";
}

bool AdaptiveV1Enabled()
{
   return (EnableAdaptiveLossCluster &&
           AdaptiveClusterMode == SIMPLE_DIRECTION_ZONE &&
           !UseAdvancedAdaptiveCluster);
}

string AdaptiveV1DirectionText(int direction)
{
   if(direction > 0) return "BUY";
   if(direction < 0) return "SELL";
   return "NONE";
}

string AdaptiveV1Pattern(int direction, int zone)
{
   return AdaptiveV1DirectionText(direction) +
          " Zone" + IntegerToString(zone);
}

bool AdaptiveRuleValidationApproved(int direction, int zone)
{
   if(direction > 0)
   {
      if(zone == 1) return AdaptiveEnableBUYZone1;
      if(zone == 2) return AdaptiveEnableBUYZone2;
      if(zone == 3) return AdaptiveEnableBUYZone3;
      if(zone == 4) return AdaptiveEnableBUYZone4;
      if(zone == 5) return AdaptiveEnableBUYZone5;
      if(zone == 6) return AdaptiveEnableBUYZone6;
      return false;
   }
   if(direction < 0)
   {
      if(zone == 1) return AdaptiveEnableSELLZone1;
      if(zone == 2) return AdaptiveEnableSELLZone2;
      if(zone == 3) return AdaptiveEnableSELLZone3;
      if(zone == 4) return AdaptiveEnableSELLZone4;
      if(zone == 5) return AdaptiveEnableSELLZone5;
      if(zone == 6) return AdaptiveEnableSELLZone6;
   }
   return false;
}

int AdaptiveConfiguredApprovedPatternCount()
{
   int count = 0;
   for(int zone = 1; zone <= 6; zone++)
   {
      if(AdaptiveRuleValidationApproved(1, zone)) count++;
      if(AdaptiveRuleValidationApproved(-1, zone)) count++;
   }
   return count;
}

string AdaptiveRuleValidationPatternList(bool approved)
{
   int approvedCount = AdaptiveConfiguredApprovedPatternCount();
   if(approved && approvedCount == 12)
      return "ALL";
   if(!approved && approvedCount == 0)
      return "ALL";
   if(!approved && approvedCount == 1 &&
      AdaptiveEnableBUYZone1)
   {
      return "ALL EXCEPT BUY Z1";
   }

   string result = "";
   for(int direction = 1; direction >= -1; direction -= 2)
   {
      for(int zone = 1; zone <= 6; zone++)
      {
         if(AdaptiveRuleValidationApproved(direction, zone) != approved)
            continue;
         if(result != "")
            result += ", ";
         result += AdaptiveV1DirectionText(direction) +
                   " Z" + IntegerToString(zone);
      }
   }
   return (result == "") ? "NONE" : result;
}

string AdaptiveV1CandidateKey(string symbol,
                              datetime barTime,
                              int direction,
                              int zone,
                              string blockedPattern)
{
   return symbol + "|" + TimeframeToText(EntryTF) + "|" +
          IntegerToString((long)barTime) + "|" +
          AdaptiveV1DirectionText(direction) + "|" +
          IntegerToString(zone) + "|" + blockedPattern;
}

void AdaptiveV1QueueAudit(string eventName,
                          string reason,
                          string detail,
                          long episodeID = 0)
{
   int index = AdaptiveV1AuditSerial %
               TRE_ADAPTIVE_V1_AUDIT_QUEUE;
   AdaptiveV1AuditEvent[index] = eventName;
   AdaptiveV1AuditReason[index] = reason;
   AdaptiveV1AuditDetail[index] = detail;
   AdaptiveV1AuditTime[index] = TimeCurrent();
   AdaptiveV1AuditEpisodeID[index] = episodeID;
   AdaptiveV1AuditSerial++;
}

void AdaptiveRuleValidationIgnore(string symbol,
                                  int direction,
                                  int zone)
{
   AdaptiveIgnoredPatternCount++;
   string pattern = AdaptiveV1Pattern(direction, zone);
   string detail =
      "RuleName=RuleValidation;Decision=IGNORE;" +
      "Reason=PATTERN_NOT_APPROVED;" +
      "Pattern=" + pattern +
      ";Direction=" + AdaptiveV1DirectionText(direction) +
      ";Zone=" + IntegerToString(zone) +
      ";Symbol=" + symbol +
      ";Timeframe=" + TimeframeToText(EntryTF);
   AdaptiveV1QueueAudit(
      "RULE_VALIDATION_IGNORE", "PATTERN_NOT_APPROVED", detail);
   AdaptiveV1LastActionText = "IGNORE " + pattern;
   Print("[RULE_VALIDATION] ", detail);
}

double AdaptiveAverageBlockedOpportunitiesPerEpisode()
{
   if(AdaptiveEpisodeCount <= 0)
      return 0.0;
   return (double)AdaptiveTotalBlockedOpportunities /
          (double)AdaptiveEpisodeCount;
}

long AdaptiveV1CreateEpisodeID()
{
   // Each research run owns a new DB file, so the activation ordinal is the
   // clearest stable lifecycle key and preserves chronological ordering.
   return (long)AdaptiveEpisodeCount;
}

bool AdaptiveV1PositionStillOpen(long identifier)
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

bool AdaptiveV1ReadClosedProfit(long identifier,
                                datetime openTime,
                                datetime &closeTime,
                                double &profit)
{
   closeTime = 0;
   profit = 0;
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

      // Pure v1 loss definition is DEAL_PROFIT only, exactly as specified.
      profit += HistoryDealGetDouble(deal, DEAL_PROFIT);
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      datetime dealTime =
         (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(!closeFound || dealTime > closeTime)
         closeTime = dealTime;
      closeFound = true;
   }
   return closeFound;
}

void AdaptiveV1AppendLoss(int direction, int zone)
{
   if(TREAdaptiveV1LossCount >= TRE_ADAPTIVE_V1_MAX_LOSSES)
   {
      for(int i = 1; i < TRE_ADAPTIVE_V1_MAX_LOSSES; i++)
      {
         TREAdaptiveV1LossDirection[i - 1] =
            TREAdaptiveV1LossDirection[i];
         TREAdaptiveV1LossZone[i - 1] =
            TREAdaptiveV1LossZone[i];
      }
      TREAdaptiveV1LossCount = TRE_ADAPTIVE_V1_MAX_LOSSES - 1;
   }
   TREAdaptiveV1LossDirection[TREAdaptiveV1LossCount] = direction;
   TREAdaptiveV1LossZone[TREAdaptiveV1LossCount] = zone;
   TREAdaptiveV1LossCount++;
}

bool AdaptiveV1LastNMatch(int count,
                          int &direction,
                          int &zone)
{
   if(count <= 0 || TREAdaptiveV1LossCount < count)
      return false;
   int start = TREAdaptiveV1LossCount - count;
   direction = TREAdaptiveV1LossDirection[start];
   zone = TREAdaptiveV1LossZone[start];
   for(int i = start + 1; i < TREAdaptiveV1LossCount; i++)
   {
      if(TREAdaptiveV1LossDirection[i] != direction ||
         TREAdaptiveV1LossZone[i] != zone)
      {
         return false;
      }
   }
   return true;
}

void AdaptiveV1Activate(string symbol,
                        int direction,
                        int zone,
                        int clusterSize)
{
   // Pure v1 owns one temporary pattern at a time; never replace it early.
   if(AdaptiveV1BlockActive)
      return;

   if(!AdaptiveRuleValidationApproved(direction, zone))
   {
      AdaptiveRuleValidationIgnore(symbol, direction, zone);
      return;
   }

   AdaptiveValidatedPatternCount++;
   AdaptiveActivatedPattern = AdaptiveV1Pattern(direction, zone);
   AdaptiveV1BlockActive = true;
   AdaptiveV1BlockedDirection = direction;
   AdaptiveV1BlockedZone = zone;
   AdaptiveV1RemainingCooldownBars = AdaptiveEffectiveCooldown();
   AdaptiveV1LastCooldownBar = iTime(symbol, EntryTF, 0);
   AdaptiveActivationCount++;
   AdaptiveEpisodeCount++;
   AdaptiveActiveEpisodes = 1;
   AdaptiveCurrentEpisodeID = AdaptiveV1CreateEpisodeID();
   AdaptiveCurrentEpisodeBlockedOpportunities = 0;
   AdaptiveLastEpisodePattern = AdaptiveV1Pattern(direction, zone);
   AdaptiveLastEpisodeBlockedOpportunities = 0;
   AdaptiveV1StatusText = "ACTIVE";
   AdaptiveV1PatternText = AdaptiveV1Pattern(direction, zone);
   AdaptiveV1LastActionText = "ACTIVATE " + AdaptiveV1PatternText;

   string activatedTime =
      TimeToString(TimeCurrent(),
                   TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   string detail =
      "RuleName=AdaptiveLossClusterV1;Event=ADAPTIVE_ACTIVATE;" +
      "EpisodeID=" + IntegerToString(AdaptiveCurrentEpisodeID) +
      ";Symbol=" + symbol +
      ";Timeframe=" + TimeframeToText(EntryTF) +
      ";BlockedDirection=" + AdaptiveV1DirectionText(direction) +
      ";BlockedZone=" + IntegerToString(zone) +
      ";LossClusterSize=" + IntegerToString(clusterSize) +
      ";CooldownBars=" +
      IntegerToString(AdaptiveV1RemainingCooldownBars) +
      ";RemainingBarsAtStart=" +
      IntegerToString(AdaptiveV1RemainingCooldownBars) +
      ";ActivatedTime=" + activatedTime;
   AdaptiveV1QueueAudit(
      "ADAPTIVE_ACTIVATE", "ADAPTIVE_ACTIVATE", detail,
      AdaptiveCurrentEpisodeID);
   Print("[ADAPTIVE_LOSS_CLUSTER_V1] ", detail);
}

void AdaptiveV1ProcessOutcome(string symbol,
                              int direction,
                              int zone,
                              double profit)
{
   if(profit >= 0)
   {
      // Win or break-even resets the complete consecutive-loss sequence.
      AdaptiveV1CurrentLossStreak = 0;
      TREAdaptiveV1LossCount = 0;
      AdaptiveV1LastActionText = "LOSS_STREAK_RESET";
      return;
   }

   AdaptiveV1CurrentLossStreak++;
   AdaptiveV1MaxLossCluster =
      (int)MathMax(AdaptiveV1MaxLossCluster,
                   AdaptiveV1CurrentLossStreak);
   AdaptiveV1AppendLoss(direction, zone);

   int threshold = AdaptiveEffectiveThreshold();
   if(AdaptiveV1CurrentLossStreak < threshold)
      return;

   int matchedDirection = 0;
   int matchedZone = 0;
   if(AdaptiveV1LastNMatch(
         threshold, matchedDirection, matchedZone))
   {
      AdaptiveV1Activate(
         symbol, matchedDirection, matchedZone, threshold);
   }
}

void AdaptiveV1SortClosed(
   TRE_AdaptiveV1ClosedTrade &closed[],
   int count)
{
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = i + 1; j < count; j++)
      {
         if(closed[j].closeTime < closed[i].closeTime ||
            (closed[j].closeTime == closed[i].closeTime &&
             closed[j].identifier < closed[i].identifier))
         {
            TRE_AdaptiveV1ClosedTrade temp = closed[i];
            closed[i] = closed[j];
            closed[j] = temp;
         }
      }
   }
}

void AdaptiveCaptureClosedTrades(string symbol = "")
{
   if(!AdaptiveV1Enabled())
      return;

   TRE_AdaptiveV1ClosedTrade closed[];
   ArrayResize(closed, TRE_ADAPTIVE_V1_MAX_TRACKED);
   int closedCount = 0;
   for(int i = 0; i < TRE_ADAPTIVE_V1_MAX_TRACKED; i++)
   {
      if(!TREAdaptiveV1Tracked[i].active ||
         AdaptiveV1PositionStillOpen(
            TREAdaptiveV1Tracked[i].identifier))
      {
         continue;
      }

      datetime closeTime = 0;
      double profit = 0;
      if(!AdaptiveV1ReadClosedProfit(
            TREAdaptiveV1Tracked[i].identifier,
            TREAdaptiveV1Tracked[i].openTime,
            closeTime, profit))
      {
         continue;
      }

      closed[closedCount].trackedIndex = i;
      closed[closedCount].identifier =
         TREAdaptiveV1Tracked[i].identifier;
      closed[closedCount].closeTime = closeTime;
      closed[closedCount].profit = profit;
      closed[closedCount].direction =
         TREAdaptiveV1Tracked[i].direction;
      closed[closedCount].zone =
         TREAdaptiveV1Tracked[i].zone;
      closedCount++;
   }

   AdaptiveV1SortClosed(closed, closedCount);
   for(int i = 0; i < closedCount; i++)
   {
      int trackedIndex = closed[i].trackedIndex;
      AdaptiveV1ProcessOutcome(
         symbol,
         closed[i].direction,
         closed[i].zone,
         closed[i].profit);
      TREAdaptiveV1Tracked[trackedIndex].active = false;
   }
}

void AdaptiveV1UpdateCooldown(string symbol)
{
   if(!AdaptiveV1BlockActive)
      return;
   datetime bar = iTime(symbol, EntryTF, 0);
   if(bar <= 0 || bar == AdaptiveV1LastCooldownBar)
      return;

   AdaptiveV1LastCooldownBar = bar;
   AdaptiveV1RemainingCooldownBars =
      (int)MathMax(0, AdaptiveV1RemainingCooldownBars - 1);
   if(AdaptiveV1RemainingCooldownBars > 0)
      return;

   string expiredTime =
      TimeToString(TimeCurrent(),
                   TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   string detail =
      "RuleName=AdaptiveLossClusterV1;Event=ADAPTIVE_EXPIRE;" +
      "EpisodeID=" + IntegerToString(AdaptiveCurrentEpisodeID) + ";" +
      "BlockedDirection=" +
      AdaptiveV1DirectionText(AdaptiveV1BlockedDirection) +
      ";BlockedZone=" +
      IntegerToString(AdaptiveV1BlockedZone) +
      ";ExpiredTime=" + expiredTime;
   AdaptiveV1QueueAudit(
      "ADAPTIVE_EXPIRE", "ADAPTIVE_EXPIRE", detail,
      AdaptiveCurrentEpisodeID);
   Print("[ADAPTIVE_LOSS_CLUSTER_V1] ", detail);

   AdaptiveV1BlockActive = false;
   AdaptiveV1RemainingCooldownBars = 0;
   AdaptiveExpireCount++;
   AdaptiveExpiredEpisodes++;
   AdaptiveActiveEpisodes = 0;
   AdaptiveV1StatusText = "EXPIRED";
   AdaptiveV1LastActionText = "EXPIRE " + AdaptiveV1PatternText;
   AdaptiveV1PatternText = "NONE";
   AdaptiveV1BlockedDirection = 0;
   AdaptiveV1BlockedZone = 0;
   AdaptiveCurrentEpisodeID = 0;
}

bool AdaptiveLossClusterAllowsEntry(string symbol,
                                    ENTRY_ACTION action,
                                    string &reason)
{
   reason = "OK";
   if(!AdaptiveV1Enabled())
      return true;

   int candidateDirection =
      (action == ACTION_BUY_READY) ? 1 : -1;
   int candidateZone = CurrentZone;
   datetime bar = iTime(symbol, EntryTF, 0);
   string blockedPattern = AdaptiveV1BlockActive
                           ? AdaptiveV1Pattern(
                                AdaptiveV1BlockedDirection,
                                AdaptiveV1BlockedZone)
                           : "NONE";
   string candidateKey = AdaptiveV1CandidateKey(
      symbol, bar, candidateDirection, candidateZone, blockedPattern);

   if(candidateKey != AdaptiveV1LastCandidateKey)
   {
      AdaptiveV1LastCandidateKey = candidateKey;
      AdaptiveCandidateSignalCount++;
      string candidateDetail =
         "RuleName=AdaptiveLossClusterV1;Event=ADAPTIVE_CANDIDATE;" +
         "EpisodeID=" + IntegerToString(AdaptiveCurrentEpisodeID) +
         ";" +
         "Symbol=" + symbol +
         ";Timeframe=" + TimeframeToText(EntryTF) +
         ";BarTime=" +
         TimeToString(bar, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +
         ";CandidateDirection=" +
         AdaptiveV1DirectionText(candidateDirection) +
         ";CandidateZone=" + IntegerToString(candidateZone) +
         ";BlockedPattern=" + blockedPattern;
      AdaptiveV1QueueAudit(
         "ADAPTIVE_CANDIDATE", "ADAPTIVE_CANDIDATE",
         candidateDetail, AdaptiveCurrentEpisodeID);
   }

   AdaptiveEvaluationCount++;
   string evaluationDetail =
      "RuleName=AdaptiveLossClusterV1;Event=ADAPTIVE_EVALUATE;" +
      "EpisodeID=" + IntegerToString(AdaptiveCurrentEpisodeID) + ";" +
      "Symbol=" + symbol +
      ";Timeframe=" + TimeframeToText(EntryTF) +
      ";BarTime=" +
      TimeToString(bar, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +
      ";CandidateDirection=" +
      AdaptiveV1DirectionText(candidateDirection) +
      ";CandidateZone=" + IntegerToString(candidateZone) +
      ";BlockedPattern=" + blockedPattern;
   AdaptiveV1QueueAudit(
      "ADAPTIVE_EVALUATE", "ADAPTIVE_EVALUATE",
      evaluationDetail, AdaptiveCurrentEpisodeID);

   if(!AdaptiveV1BlockActive)
      return true;

   if(candidateDirection != AdaptiveV1BlockedDirection ||
      candidateZone != AdaptiveV1BlockedZone)
   {
      return true;
   }

   reason = "BLOCK_ADAPTIVE_LOSS_CLUSTER_V1";
   if(candidateKey == AdaptiveV1LastBlockedCandidateKey)
      return false;

   AdaptiveV1LastBlockedCandidateKey = candidateKey;
   AdaptiveTotalBlockedOpportunities++;
   AdaptiveCurrentEpisodeBlockedOpportunities++;
   AdaptiveLastEpisodeBlockedOpportunities =
      AdaptiveCurrentEpisodeBlockedOpportunities;
   if(AdaptiveCurrentEpisodeBlockedOpportunities >
      AdaptiveMaxBlockedOpportunitiesInEpisode)
   {
      AdaptiveMaxBlockedOpportunitiesInEpisode =
         AdaptiveCurrentEpisodeBlockedOpportunities;
      AdaptiveMostBlockedPattern = blockedPattern;
   }
   AdaptiveV1LastBlockedDirection = candidateDirection;
   AdaptiveV1LastBlockedZone = candidateZone;
   AdaptiveV1LastActionText =
      "BLOCK OPPORTUNITY " +
      AdaptiveV1Pattern(candidateDirection, candidateZone);

   string detail =
      "RuleName=AdaptiveLossClusterV1;Event=ADAPTIVE_BLOCK_OPPORTUNITY;" +
      "EpisodeID=" + IntegerToString(AdaptiveCurrentEpisodeID) +
      ";" +
      "BlockedAuditSerial=" +
      IntegerToString(AdaptiveV1AuditSerial + 1) + ";" +
      "Reason=" + reason +
      ";Symbol=" + symbol +
      ";Timeframe=" + TimeframeToText(EntryTF) +
      ";BarTime=" +
      TimeToString(bar, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +
      ";CandidateDirection=" +
      AdaptiveV1DirectionText(candidateDirection) +
      ";CandidateZone=" + IntegerToString(candidateZone) +
      ";BlockedDirection=" +
      AdaptiveV1DirectionText(AdaptiveV1BlockedDirection) +
      ";BlockedZone=" + IntegerToString(AdaptiveV1BlockedZone) +
      ";BlockedPattern=" + blockedPattern +
      ";RemainingCooldownBars=" +
      IntegerToString(AdaptiveV1RemainingCooldownBars);
   AdaptiveV1LastBlockedAuditSerial = AdaptiveV1AuditSerial + 1;
   AdaptiveV1QueueAudit(
      "ADAPTIVE_BLOCK_OPPORTUNITY", reason, detail,
      AdaptiveCurrentEpisodeID);
   Print("[ADAPTIVE_LOSS_CLUSTER_V1] ", detail);
   return false;
}

void AdaptiveV1RecordExecutedTrade(string symbol,
                                   ENTRY_ACTION action,
                                   int entryZone)
{
   if(!AdaptiveV1Enabled())
      return;

   AdaptiveExecutedTradeCount++;
   int direction = (action == ACTION_BUY_READY) ? 1 : -1;
   datetime bar = iTime(symbol, EntryTF, 0);
   string detail =
      "RuleName=AdaptiveLossClusterV1;Event=ADAPTIVE_EXECUTE_PASS;" +
      "EpisodeID=" + IntegerToString(AdaptiveCurrentEpisodeID) + ";" +
      "Symbol=" + symbol +
      ";Timeframe=" + TimeframeToText(EntryTF) +
      ";BarTime=" +
      TimeToString(bar, TIME_DATE|TIME_MINUTES|TIME_SECONDS) +
      ";CandidateDirection=" + AdaptiveV1DirectionText(direction) +
      ";CandidateZone=" + IntegerToString(entryZone);
   AdaptiveV1QueueAudit(
      "ADAPTIVE_EXECUTE_PASS", "ORDER_ACCEPTED", detail,
      AdaptiveCurrentEpisodeID);
   AdaptiveV1LastActionText =
      "EXECUTE " + AdaptiveV1Pattern(direction, entryZone);
}

int AdaptiveV1FindTracked(long identifier)
{
   for(int i = 0; i < TRE_ADAPTIVE_V1_MAX_TRACKED; i++)
   {
      if(TREAdaptiveV1Tracked[i].active &&
         TREAdaptiveV1Tracked[i].identifier == identifier)
      {
         return i;
      }
   }
   return -1;
}

int AdaptiveV1FreeTrackedSlot()
{
   for(int i = 0; i < TRE_ADAPTIVE_V1_MAX_TRACKED; i++)
      if(!TREAdaptiveV1Tracked[i].active)
         return i;
   return -1;
}

bool AdaptiveLossClusterRegisterOpenPosition(
   string symbol,
   ENTRY_ACTION action,
   int entryZone)
{
   if(!AdaptiveV1Enabled())
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
      if(AdaptiveV1FindTracked(identifier) >= 0)
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
   int slot = AdaptiveV1FreeTrackedSlot();
   if(identifier <= 0 || slot < 0)
      return false;

   TREAdaptiveV1Tracked[slot].active = true;
   TREAdaptiveV1Tracked[slot].identifier = identifier;
   TREAdaptiveV1Tracked[slot].openTime =
      (datetime)PositionGetInteger(POSITION_TIME);
   TREAdaptiveV1Tracked[slot].direction =
      (action == ACTION_BUY_READY) ? 1 : -1;
   TREAdaptiveV1Tracked[slot].zone = entryZone;
   return true;
}

void AdaptiveLossClusterEngine(string symbol)
{
   if(!EnableAdaptiveLossCluster)
   {
      AdaptiveV1StatusText = "DISABLED";
      return;
   }
   if(AdaptiveClusterMode != SIMPLE_DIRECTION_ZONE ||
      UseAdvancedAdaptiveCluster)
   {
      AdaptiveV1StatusText = "ADVANCED_RESERVED_DISABLED";
      return;
   }
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0)
   {
      AdaptiveV1StatusText = "TESTER_ONLY";
      return;
   }

   AdaptiveV1UpdateCooldown(symbol);
   AdaptiveCaptureClosedTrades(symbol);
   if(!AdaptiveV1BlockActive &&
      AdaptiveV1StatusText != "EXPIRED")
   {
      AdaptiveV1StatusText = "INACTIVE";
   }
}

#endif
