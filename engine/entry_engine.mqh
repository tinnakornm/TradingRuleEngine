//+------------------------------------------------------------------+
//| engine/entry_engine.mqh                                          |
//| Final explainable decision maker and research score weighting    |
//+------------------------------------------------------------------+
#ifndef TRE_ENTRY_ENGINE_MQH
#define TRE_ENTRY_ENGINE_MQH

string EntryFormatScore(double value)
{
   if(MathAbs(value - MathRound(value)) < 0.000001)
      return DoubleToString(value, 0);

   return DoubleToString(value, 1);
}

string EntryRawStatus(double rawScore,
                      double passThreshold,
                      bool zeroIsFail)
{
   if(rawScore >= passThreshold)
      return TRE_STATUS_PASS;

   if(rawScore > 0)
      return TRE_STATUS_WAIT;

   return zeroIsFail ? TRE_STATUS_FAIL : TRE_STATUS_WAIT;
}

void EntryPrepareEngineScoreItems()
{
   TRE_SetEngineScoreItem(
      EngineScores[0], "Trend", TrendScore, 40,
      UseTrendScore, TrendWeight,
      EntryRawStatus(TrendScore, 40, false), TrendReason);
   TRE_SetEngineScoreItem(
      EngineScores[1], "Zone", ZoneScore, 30,
      UseZoneScore, ZoneWeight,
      EntryRawStatus(ZoneScore, 20, true), ZoneReason);
   TRE_SetEngineScoreItem(
      EngineScores[2], "Structure", StructureScore, 20,
      UseStructureScore, StructureWeight,
      EntryRawStatus(StructureScore, 20, false), StructureReason);
   TRE_SetEngineScoreItem(
      EngineScores[3], "Momentum", MomentumScore, 10,
      UseMomentumScore, MomentumWeight,
      EntryRawStatus(MomentumScore, 10, true), MomentumReason);
}

void EntryCalculateWeightedScores()
{
   bool zoneOnlyActive = AllowZoneOnlyResearchDecision &&
                         (MQLInfoInteger(MQL_TESTER) != 0);
   EffectiveZoneOnlyReadyThreshold = (int)MathMax(
      0, MathMin(100, ZoneOnlyReadyThreshold));

   if(zoneOnlyActive)
   {
      ResearchDecisionModeText = "Zone Only";
      ResearchBiasIgnoredText = "YES";
      ResearchMarketBiasRequiredText = "NO";
      ResearchBiasOverrideText = "YES";
      ResearchSummaryDecisionSourceText = "Zone Engine";
      ResearchDecisionSourceText = "Zone Only Research";
      ResearchWarningText = "RESEARCH MODE: Zone-only decision. Market Bias is ignored.";
   }
   else if(AllowZoneOnlyResearchDecision)
   {
      ResearchDecisionModeText = "Zone Only (Tester Required)";
      ResearchBiasIgnoredText = "NO";
      ResearchMarketBiasRequiredText = "YES";
      ResearchBiasOverrideText = "NO";
      ResearchSummaryDecisionSourceText = "Standard Rule Engine";
      ResearchDecisionSourceText = "Standard Rule Engine";
      ResearchWarningText = "Zone-only override requires Strategy Tester.";
   }
   else
   {
      ResearchDecisionModeText = "Standard";
      ResearchBiasIgnoredText = "NO";
      ResearchMarketBiasRequiredText = "YES";
      ResearchBiasOverrideText = "NO";
      ResearchSummaryDecisionSourceText = "Standard Rule Engine";
      ResearchDecisionSourceText = "Standard Rule Engine";
      ResearchWarningText = "N/A";
   }

   EntryPrepareEngineScoreItems();
   WeightedScoreTotal = 0;
   WeightedScoreMax = 0;

   for(int i = 0; i < TRE_ENGINE_SCORE_COUNT; i++)
   {
      TRE_EngineScoreItem item = EngineScores[i];

      if(!item.enabled || item.configuredWeight <= 0)
      {
         item.effectiveWeight = 0;
         item.weightedScore = 0;
         item.status = TRE_STATUS_DISABLED;
         item.reason = item.enabled ? "Weight is zero" : "Disabled by research config";
         EngineScores[i] = item;
         continue;
      }

      item.effectiveWeight = item.configuredWeight;
      double ratio = (item.rawMax > 0) ? item.rawScore / item.rawMax : 0;
      ratio = MathMax(0.0, MathMin(1.0, ratio));

      // In Zone Only research, a zone that passes its entry threshold receives
      // its full configured weight even when the raw zone is 20 out of 30.
      if(zoneOnlyActive && i == 1 && item.status == TRE_STATUS_PASS)
         ratio = 1.0;

      item.weightedScore = ratio * item.effectiveWeight;
      WeightedScoreTotal += item.weightedScore;
      WeightedScoreMax += item.effectiveWeight;
      EngineScores[i] = item;
   }

   if(WeightedScoreMax > 0)
      TotalScore = (int)MathRound((WeightedScoreTotal / WeightedScoreMax) * 100.0);
   else
      TotalScore = 0;

   ConfirmationScore = TotalScore;
   TotalEngineStatusText = (TotalScore >= 80)
                           ? TRE_STATUS_PASS
                           : ((TotalScore >= 40) ? TRE_STATUS_WAIT
                                                : TRE_STATUS_FAIL);

   TrendEngineStatusText = EngineScores[0].status;
   ZoneEngineStatusText = EngineScores[1].status;
   StructureEngineStatusText = EngineScores[2].status;
   MomentumEngineStatusText = EngineScores[3].status;

   for(int i = 0; i < TRE_ENGINE_SCORE_COUNT; i++)
   {
      TRE_EngineScoreItem item = EngineScores[i];
      EngineScoreDisplayText[i] =
         EntryFormatScore(item.weightedScore) + " / " +
         EntryFormatScore(item.effectiveWeight) + "  " +
         item.status + " | " + item.reason;
   }

   EngineScoreMixCompactText =
      "T" + EntryFormatScore(EngineScores[0].weightedScore) + "/" +
      EntryFormatScore(EngineScores[0].effectiveWeight) + " Z" +
      EntryFormatScore(EngineScores[1].weightedScore) + "/" +
      EntryFormatScore(EngineScores[1].effectiveWeight) + " S" +
      EntryFormatScore(EngineScores[2].weightedScore) + "/" +
      EntryFormatScore(EngineScores[2].effectiveWeight) + " M" +
      EntryFormatScore(EngineScores[3].weightedScore) + "/" +
      EntryFormatScore(EngineScores[3].effectiveWeight);
   EngineScoreTotalText = "Total " + IntegerToString(TotalScore) +
                          " " + TotalEngineStatusText;

   string formula = "";

   for(int i = 0; i < TRE_ENGINE_SCORE_COUNT; i++)
   {
      if(i > 0)
         formula += " + ";

      formula += (EngineScores[i].status == TRE_STATUS_DISABLED)
                 ? EngineScores[i].name + " disabled"
                 : EngineScores[i].name;
   }

   EngineScoreFormulaText = formula + " = " +
                            IntegerToString(TotalScore) +
                            " / 100 " + TotalEngineStatusText;
}

void EntryLogZoneResearchDecision(ENTRY_ACTION action)
{
   static datetime previousBarTime = 0;
   static int previousZone = 0;
   static int previousAction = -1;

   datetime barTime = iTime(GetTradeSymbol(), _Period, 0);

   if(previousBarTime == barTime &&
      previousZone == CurrentZone &&
      previousAction == (int)action)
   {
      return;
   }

   previousBarTime = barTime;
   previousZone = CurrentZone;
   previousAction = (int)action;

   Print("TRE Zone Research Decision: ", ActionToText(action),
         " from Zone ", IntegerToString(CurrentZone),
         ", bias ignored");
}

void EntryPrepareDirectionalFilter()
{
   ManualMarketProfileText = TRE_MarketProfileToText(ManualMarketProfile);
   ActiveRegimeText = TRE_MarketProfileToText(ActiveRegime);
   DirectionalFilterEnabledText = UseDirectionalFilter ? "ON" : "OFF";
   DirectionalFilterAllowBuyText = "YES";
   DirectionalFilterAllowSellText = "YES";
   DirectionalFilterAllowedDirectionText = "BUY + SELL";
   DirectionalFilterBlockedDirectionText = "NONE";
   DirectionalFilterCandidateAction = ACTION_WAIT;
   DirectionalFilterBlocked = false;
   DirectionalFilterBlockingFactorText = "N/A";

   if(!UseDirectionalFilter)
   {
      DirectionalFilterResultText = "DISABLED";
      DirectionalFilterReasonText = "Directional filter disabled";
      return;
   }

   if(ActiveRegime == TRE_PROFILE_UPTREND)
   {
      DirectionalFilterAllowSellText = "NO";
      DirectionalFilterAllowedDirectionText = "BUY ONLY";
      DirectionalFilterBlockedDirectionText = "SELL";
   }
   else if(ActiveRegime == TRE_PROFILE_DOWNTREND)
   {
      DirectionalFilterAllowBuyText = "NO";
      DirectionalFilterAllowedDirectionText = "SELL ONLY";
      DirectionalFilterBlockedDirectionText = "BUY";
   }

   DirectionalFilterResultText = "WAIT";
   DirectionalFilterReasonText = "Waiting for BUY or SELL candidate";
}

bool EntryApplyDirectionalFilter(ENTRY_ACTION candidate)
{
   DirectionalFilterCandidateAction = candidate;

   if(!UseDirectionalFilter)
      return true;

   bool buyBlocked = (candidate == ACTION_BUY_READY &&
                      DirectionalFilterAllowBuyText == "NO");
   bool sellBlocked = (candidate == ACTION_SELL_READY &&
                       DirectionalFilterAllowSellText == "NO");

   if(!buyBlocked && !sellBlocked)
   {
      string direction = (candidate == ACTION_BUY_READY) ? "BUY" : "SELL";
      DirectionalFilterResultText = "PASS";
      DirectionalFilterReasonText = direction + " allowed in " +
                                    ActiveRegimeText + " active profile";
      return true;
   }

   string blockedDirection = buyBlocked ? "BUY" : "SELL";
   DirectionalFilterBlocked = true;
   DirectionalFilterResultText = "BLOCKED";
   DirectionalFilterReasonText = blockedDirection + " blocked in " +
                                 ActiveRegimeText + " active profile";
   DirectionalFilterBlockingFactorText =
      "Manual profile allows " +
      DirectionalFilterAllowedDirectionText;
   ActionState = ACTION_WATCH;
   EntryReason = "Directional filter blocked " + blockedDirection +
                 " in " + ActiveRegimeText + " active profile";
   MissingConditionText = DirectionalFilterBlockingFactorText;

   Print("TRE Directional Filter: ", DirectionalFilterReasonText,
         " | Candidate=", ActionToText(candidate),
         " | Decision=WATCH");
   return false;
}

bool EntryApplyPressureGuard(ENTRY_ACTION candidate,
                             string readyReason)
{
   ENTRY_ACTION guardedAction = PressureGuardApply(candidate);

   if(guardedAction != candidate)
   {
      ActionState = guardedAction;
      EntryReason = PressureReasonText;
      MissingConditionText = PressureMissingConditionText;
      return false;
   }

   ActionState = candidate;
   EntryReason = readyReason;
   return true;
}

void EntryEngine()
{
   ActionState = ACTION_WAIT;
   EntryCalculateWeightedScores();
   EntryPrepareDirectionalFilter();

   bool zoneOnlyActive = AllowZoneOnlyResearchDecision &&
                         (MQLInfoInteger(MQL_TESTER) != 0);
   bool zoneBuySetup = (CurrentZone >= 1 && CurrentZone <= 2 &&
                        ZoneEngineStatusText == TRE_STATUS_PASS);
   bool zoneSellSetup = (CurrentZone >= 5 && CurrentZone <= 6 &&
                         ZoneEngineStatusText == TRE_STATUS_PASS);
   bool buySetup = zoneOnlyActive
                   ? zoneBuySetup
                   : (MarketBias == BIAS_BUY && CurrentZone <= 2);
   bool sellSetup = zoneOnlyActive
                    ? zoneSellSetup
                    : (MarketBias == BIAS_SELL && CurrentZone >= 5);

   MissingConditionText = "";

   if(TrendEngineStatusText != TRE_STATUS_PASS &&
      TrendEngineStatusText != TRE_STATUS_DISABLED)
      MissingConditionText += "Trend confirmation; ";

   if(ZoneEngineStatusText != TRE_STATUS_PASS &&
      ZoneEngineStatusText != TRE_STATUS_DISABLED)
      MissingConditionText += "Entry zone; ";

   if(StructureEngineStatusText != TRE_STATUS_PASS &&
      StructureEngineStatusText != TRE_STATUS_DISABLED)
      MissingConditionText += "Break structure; ";

   if(MomentumEngineStatusText != TRE_STATUS_PASS &&
      MomentumEngineStatusText != TRE_STATUS_DISABLED)
      MissingConditionText += "Momentum confirmation; ";

   if(!zoneOnlyActive && !buySetup && !sellSetup)
      MissingConditionText += "Bias-zone alignment; ";

   if(zoneOnlyActive && !zoneBuySetup && !zoneSellSetup)
      MissingConditionText += "Zone-only entry area; ";

   if(MissingConditionText == "")
      MissingConditionText = "None";

   RiskLevelText = (TotalScore >= 80)
                   ? "Low"
                   : ((TotalScore >= 60) ? "Medium" : "High");

   if(zoneOnlyActive)
   {
      if(TotalScore < EffectiveZoneOnlyReadyThreshold)
      {
         ActionState = ACTION_NO_TRADE;
         EntryReason = "Zone-only research score below ready threshold";
         return;
      }

      if(zoneSellSetup)
      {
         if(!EntryApplyDirectionalFilter(ACTION_SELL_READY))
            return;

         string readyReason =
            "Zone-only research: Zone " +
            IntegerToString(CurrentZone) + " " +
            ZoneStrengthText;

         if(!EntryApplyPressureGuard(ACTION_SELL_READY,
                                     readyReason))
            return;

         EntryLogZoneResearchDecision(ActionState);
         return;
      }

      if(zoneBuySetup)
      {
         if(!EntryApplyDirectionalFilter(ACTION_BUY_READY))
            return;

         string readyReason =
            "Zone-only research: Zone " +
            IntegerToString(CurrentZone) + " " +
            ZoneStrengthText;

         if(!EntryApplyPressureGuard(ACTION_BUY_READY,
                                     readyReason))
            return;

         EntryLogZoneResearchDecision(ActionState);
         return;
      }

      if(CurrentZone == 3 || CurrentZone == 4)
      {
         ActionState = ACTION_WATCH;
         EntryReason = "Zone-only research: magnet zone";
         return;
      }

      ActionState = ACTION_NO_TRADE;
      EntryReason = "Zone-only research: Zone score not passed";
      return;
   }

   if(TotalScore >= 80)
   {
      if(sellSetup)
      {
         if(!EntryApplyDirectionalFilter(ACTION_SELL_READY))
            return;

         if(!EntryApplyPressureGuard(
               ACTION_SELL_READY,
               "H4 bearish + sell zone + confirmation"))
         {
            return;
         }

         return;
      }

      if(buySetup)
      {
         if(!EntryApplyDirectionalFilter(ACTION_BUY_READY))
            return;

         if(!EntryApplyPressureGuard(
               ACTION_BUY_READY,
               "H4 bullish + buy zone + confirmation"))
         {
            return;
         }

         return;
      }

      ActionState = ACTION_WATCH;
      EntryReason = "High score but entry zone not aligned";
      return;
   }

   if(TotalScore >= 60)
   {
      ActionState = ACTION_WATCH;
      EntryReason = "Setup forming, wait for confirmation";
      return;
   }

   if(TotalScore >= 40)
   {
      ActionState = ACTION_WAIT;
      EntryReason = "Mixed evidence, wait";
      return;
   }

   ActionState = ACTION_NO_TRADE;
   EntryReason = "Score too low";
}

#endif
