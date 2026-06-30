//+------------------------------------------------------------------+
//| engine/pressure_guard_engine.mqh                                 |
//| Passive short-term directional pressure protection              |
//+------------------------------------------------------------------+
#ifndef TRE_PRESSURE_GUARD_ENGINE_MQH
#define TRE_PRESSURE_GUARD_ENGINE_MQH

string PressureDirectionToText(TRE_PRESSURE_DIRECTION direction)
{
   if(direction == PRESSURE_UP) return "UP";
   if(direction == PRESSURE_DOWN) return "DOWN";
   return "NONE";
}

string PressureLevelToText(TRE_PRESSURE_LEVEL level)
{
   if(level == PRESSURE_HIGH) return "HIGH";
   if(level == PRESSURE_MEDIUM) return "MEDIUM";
   return "LOW";
}

string PressureActionToText(TRE_PRESSURE_ACTION action)
{
   if(action == PRESSURE_WARN) return "WARN";
   if(action == PRESSURE_SOFT_REDUCE_SCORE)
      return "SOFT_REDUCE_SCORE";
   if(action == PRESSURE_SOFT_DOWNGRADE_TO_WATCH)
      return "SOFT_DOWNGRADE_TO_WATCH";
   if(action == PRESSURE_HARD_BLOCK_BUY)
      return "HARD_BLOCK_BUY";
   if(action == PRESSURE_HARD_BLOCK_SELL)
      return "HARD_BLOCK_SELL";
   return "ALLOW";
}

string PressureGuardModeToText(TRE_PRESSURE_GUARD_MODE mode)
{
   if(mode == PRESSURE_GUARD_DISPLAY_ONLY) return "DISPLAY_ONLY";
   if(mode == PRESSURE_GUARD_WARN_ONLY) return "WARN_ONLY";
   if(mode == PRESSURE_GUARD_SOFT_BLOCK) return "SOFT_BLOCK";
   if(mode == PRESSURE_GUARD_HARD_BLOCK) return "HARD_BLOCK";
   return "OFF";
}

string PressureDecisionImpactToText(TRE_PRESSURE_DECISION_IMPACT impact)
{
   if(impact == PRESSURE_IMPACT_WARNING_ONLY) return "WARNING_ONLY";
   if(impact == PRESSURE_IMPACT_SCORE_REDUCED) return "SCORE_REDUCED";
   if(impact == PRESSURE_IMPACT_DOWNGRADED_TO_WATCH)
      return "DOWNGRADED_TO_WATCH";
   if(impact == PRESSURE_IMPACT_HARD_BLOCKED) return "HARD_BLOCKED";
   return "NONE";
}

string PressureDirectionAdjective()
{
   if(PressureDirection == PRESSURE_UP) return "Bullish";
   if(PressureDirection == PRESSURE_DOWN) return "Bearish";
   return "Neutral";
}

bool PressureEMAAtShift(MqlRates &rates[],
                        int copied,
                        int shift,
                        int period,
                        double &ema)
{
   ema = 0;

   if(shift < 1 || period < 2 ||
      shift + period - 1 >= copied)
   {
      return false;
   }

   int oldest = shift + period - 1;
   ema = rates[oldest].close;
   double alpha = 2.0 / (period + 1.0);

   for(int index = oldest - 1; index >= shift; index--)
      ema = (rates[index].close * alpha) +
            (ema * (1.0 - alpha));

   return (ema > 0);
}

double PressureEvidenceScore(int value,
                             int fullThreshold,
                             int partialThreshold,
                             double maximum)
{
   if(value >= fullThreshold)
      return maximum;

   if(value >= partialThreshold)
      return maximum * 0.5;

   return 0;
}

int PressureNormalizeScore(double score, double maximum)
{
   if(maximum <= 0)
      return 0;

   return (int)MathRound(
      MathMax(0.0, MathMin(1.0, score / maximum)) * 100.0);
}

void PressureResetOutput()
{
   PressureDirection = PRESSURE_NONE;
   PressureLevel = PRESSURE_LOW;
   PressureAction = PRESSURE_ALLOW;
   PressureDecisionImpact = PRESSURE_IMPACT_NONE;
   PressureCandidateAction = ACTION_WAIT;
   PressureDirectionText = "NONE";
   PressureLevelText = "LOW";
   PressureActionText = "ALLOW";
   PressureBlockedDirectionText = "NONE";
   PressureReasonText = "No opposing pressure detected";
   PressureMissingConditionText = "N/A";
   PressureAppliesToCandidateText = "NO";
   PressureGuardStatusText = UsePressureGuard ? "READY" : "DISABLED";
   CandidateDirectionBeforePressure = "NONE";
   DecisionBeforePressure = "WAIT";
   DecisionAfterPressure = "WAIT";
   PressureDecisionImpactText = "NONE";
   RegimeUsedForPressureScopeText =
      (ActiveRegime != TRE_PROFILE_UNKNOWN)
      ? ActiveRegimeText
      : DetectedRegimeText;
   PressureScopeAllowed = true;
   PressureScopeAllowedText = "YES";
   ScoreBeforePressure = 0;
   PressurePenaltyApplied = 0;
   ScoreAfterPressure = 0;
   PressureDowngradeReasonText = "N/A";
   PressureBlockReasonText = "N/A";
   PressureMomentumDirectionText = "NEUTRAL";
   PressureEMAValueText = "N/A";
   PressureEMAPreviousValueText = "N/A";
   PressureEMASlopePointsText = "N/A";
   PressureDistanceFromEMAPointsText = "N/A";
   PressurePriceAboveEMAText = "N/A";
   PressurePriceBelowEMAText = "N/A";
   PressureEMASlopeDirectionText = "N/A";
   PressureLastCloseText = "N/A";
   PressureLastHighText = "N/A";
   PressureLastLowText = "N/A";
   PressureEffectiveTFText = TimeframeToText(EffectivePressureTF);
   PressureCalculationStatusText = "NOT CALCULATED";
   MissingPressureDataReasonText = "N/A";
   PressureScore = 0;
   BullishPressureScore = 0;
   BearishPressureScore = 0;
   PressureBarsCopied = 0;
   PressureBullishEvidenceCount = 0;
   PressureBearishEvidenceCount = 0;
   PressureRecentHigherCloseCount = 0;
   PressureRecentLowerCloseCount = 0;
   PressureRecentHigherHighCount = 0;
   PressureRecentLowerLowCount = 0;
   PressureConsecutiveBullishBars = 0;
   PressureConsecutiveBearishBars = 0;
}

void PressureGuardEngine(string symbol)
{
   PressureResetOutput();

   if(!UsePressureGuard ||
      PressureGuardMode == PRESSURE_GUARD_OFF)
   {
      PressureGuardStatusText = "DISABLED";
      PressureCalculationStatusText = "SKIPPED";
      PressureReasonText = "Pressure Guard is disabled";
      return;
   }

   int requiredBars = EffectivePressureLookbackBars + 2;

   if(PressureUseEMAFilter)
   {
      requiredBars =
         (int)MathMax(requiredBars,
                      EffectivePressureEMAPeriod + 3);
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   PressureBarsCopied =
      CopyRates(symbol, EffectivePressureTF, 0, requiredBars, rates);

   if(PressureBarsCopied <= EffectivePressureLookbackBars + 1)
   {
      PressureGuardStatusText = "NO_DATA";
      PressureCalculationStatusText = "NO_DATA";
      PressureReasonText = "PressureTF history is incomplete";
      PressureMissingConditionText = "Need more PressureTF bars";
      MissingPressureDataReasonText = PressureMissingConditionText;
      return;
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   PressureLastCloseText = DoubleToString(rates[1].close, digits);
   PressureLastHighText = DoubleToString(rates[1].high, digits);
   PressureLastLowText = DoubleToString(rates[1].low, digits);

   for(int shift = 1;
       shift <= EffectivePressureLookbackBars;
       shift++)
   {
      if(rates[shift].close > rates[shift + 1].close)
         PressureRecentHigherCloseCount++;
      else if(rates[shift].close < rates[shift + 1].close)
         PressureRecentLowerCloseCount++;

      if(rates[shift].high > rates[shift + 1].high)
         PressureRecentHigherHighCount++;

      if(rates[shift].low < rates[shift + 1].low)
         PressureRecentLowerLowCount++;
   }

   for(int shift = 1;
       shift <= EffectivePressureLookbackBars;
       shift++)
   {
      if(rates[shift].close > rates[shift].open)
         PressureConsecutiveBullishBars++;
      else
         break;
   }

   for(int shift = 1;
       shift <= EffectivePressureLookbackBars;
       shift++)
   {
      if(rates[shift].close < rates[shift].open)
         PressureConsecutiveBearishBars++;
      else
         break;
   }

   bool priceAboveEMA = false;
   bool priceBelowEMA = false;
   bool emaSlopeUp = false;
   bool emaSlopeDown = false;
   double emaCurrent = 0;
   double emaPrevious = 0;
   bool emaReady = !PressureUseEMAFilter;

   if(PressureUseEMAFilter)
   {
      emaReady =
         PressureEMAAtShift(rates, PressureBarsCopied, 1,
                            EffectivePressureEMAPeriod,
                            emaCurrent) &&
         PressureEMAAtShift(rates, PressureBarsCopied, 2,
                            EffectivePressureEMAPeriod,
                            emaPrevious);

      if(emaReady)
      {
         priceAboveEMA = (rates[1].close > emaCurrent);
         priceBelowEMA = (rates[1].close < emaCurrent);
         emaSlopeUp = (emaCurrent > emaPrevious);
         emaSlopeDown = (emaCurrent < emaPrevious);
         PressureEMAValueText = DoubleToString(emaCurrent, digits);
         PressureEMAPreviousValueText =
            DoubleToString(emaPrevious, digits);
         PressurePriceAboveEMAText =
            priceAboveEMA ? TRE_STATUS_PASS : TRE_STATUS_FAIL;
         PressurePriceBelowEMAText =
            priceBelowEMA ? TRE_STATUS_PASS : TRE_STATUS_FAIL;
         PressureEMASlopeDirectionText =
            emaSlopeUp ? "UP" : (emaSlopeDown ? "DOWN" : "FLAT");

         if(point > 0)
         {
            PressureEMASlopePointsText =
               DoubleToString((emaCurrent - emaPrevious) / point, 1);
            PressureDistanceFromEMAPointsText =
               DoubleToString((rates[1].close - emaCurrent) / point, 1);
         }
      }
      else
      {
         PressurePriceAboveEMAText = TRE_STATUS_WAIT;
         PressurePriceBelowEMAText = TRE_STATUS_WAIT;
         PressureEMASlopeDirectionText = TRE_STATUS_WAIT;
         MissingPressureDataReasonText =
            "EMA evidence is not ready";
      }
   }

   double bullRaw = 0;
   double bearRaw = 0;
   double maximum = 45;
   int sequenceFull =
      (int)MathMax(3, EffectivePressureLookbackBars / 2);

   bullRaw += PressureEvidenceScore(
      PressureConsecutiveBullishBars, 3, 2, 15);
   bearRaw += PressureEvidenceScore(
      PressureConsecutiveBearishBars, 3, 2, 15);
   bullRaw += PressureEvidenceScore(
      PressureRecentHigherCloseCount, sequenceFull, 2, 15);
   bearRaw += PressureEvidenceScore(
      PressureRecentLowerCloseCount, sequenceFull, 2, 15);
   bullRaw += PressureEvidenceScore(
      PressureRecentHigherHighCount, sequenceFull, 2, 15);
   bearRaw += PressureEvidenceScore(
      PressureRecentLowerLowCount, sequenceFull, 2, 15);

   if(PressureUseEMAFilter)
   {
      maximum += 30;

      if(emaReady && priceAboveEMA)
         bullRaw += 15;

      if(emaReady && priceBelowEMA)
         bearRaw += 15;

      if(emaReady && emaSlopeUp)
         bullRaw += 15;

      if(emaReady && emaSlopeDown)
         bearRaw += 15;
   }

   if(PressureUseStructureDevelopment)
   {
      maximum += 15;

      if(StructureDevelopmentStateText == "DEVELOPING_UPTREND")
         bullRaw += 15;

      if(StructureDevelopmentStateText == "DEVELOPING_DOWNTREND")
         bearRaw += 15;
   }

   if(PressureUseMomentum)
   {
      maximum += 10;

      if(MomentumCandleText == "Bullish")
      {
         PressureMomentumDirectionText = "BULLISH";
         bullRaw += (MomentumStrengthText == "Strong") ? 10 : 5;
      }
      else if(MomentumCandleText == "Bearish")
      {
         PressureMomentumDirectionText = "BEARISH";
         bearRaw += (MomentumStrengthText == "Strong") ? 10 : 5;
      }
   }

   BullishPressureScore = PressureNormalizeScore(bullRaw, maximum);
   BearishPressureScore = PressureNormalizeScore(bearRaw, maximum);
   PressureBullishEvidenceCount =
      (PressureConsecutiveBullishBars >= 2 ? 1 : 0) +
      (PressureRecentHigherCloseCount >= 2 ? 1 : 0) +
      (PressureRecentHigherHighCount >= 2 ? 1 : 0) +
      (priceAboveEMA ? 1 : 0) +
      (emaSlopeUp ? 1 : 0) +
      (StructureDevelopmentStateText == "DEVELOPING_UPTREND" ? 1 : 0) +
      (PressureMomentumDirectionText == "BULLISH" ? 1 : 0);
   PressureBearishEvidenceCount =
      (PressureConsecutiveBearishBars >= 2 ? 1 : 0) +
      (PressureRecentLowerCloseCount >= 2 ? 1 : 0) +
      (PressureRecentLowerLowCount >= 2 ? 1 : 0) +
      (priceBelowEMA ? 1 : 0) +
      (emaSlopeDown ? 1 : 0) +
      (StructureDevelopmentStateText == "DEVELOPING_DOWNTREND" ? 1 : 0) +
      (PressureMomentumDirectionText == "BEARISH" ? 1 : 0);

   if(BullishPressureScore > BearishPressureScore)
      PressureDirection = PRESSURE_UP;
   else if(BearishPressureScore > BullishPressureScore)
      PressureDirection = PRESSURE_DOWN;
   else
      PressureDirection = PRESSURE_NONE;

   PressureScore =
      (int)MathMax(BullishPressureScore, BearishPressureScore);

   if(PressureScore >= EffectivePressureHighThreshold)
      PressureLevel = PRESSURE_HIGH;
   else if(PressureScore >= EffectivePressureMediumThreshold)
      PressureLevel = PRESSURE_MEDIUM;
   else
      PressureLevel = PRESSURE_LOW;

   PressureDirectionText =
      PressureDirectionToText(PressureDirection);
   PressureLevelText = PressureLevelToText(PressureLevel);
   PressureReasonText =
      PressureDirectionText + " pressure " +
      IntegerToString(PressureScore) + "/100 (" +
      PressureLevelText + ")";
   PressureGuardStatusText = "READY";
   PressureCalculationStatusText = "CALCULATED";
}

bool PressureSoftBlockScopeAllows()
{
   if(!PressureSoftBlockOnlyInSidewayOrUnknown)
      return true;

   if(ActiveRegime == TRE_PROFILE_UPTREND ||
      ActiveRegime == TRE_PROFILE_DOWNTREND ||
      DetectedRegime == TRE_PROFILE_UPTREND ||
      DetectedRegime == TRE_PROFILE_DOWNTREND)
   {
      return false;
   }

   return true;
}

ENTRY_ACTION PressureGuardApply(ENTRY_ACTION candidate,
                                int candidateScore)
{
   PressureCandidateAction = candidate;
   CandidateDirectionBeforePressure =
      (candidate == ACTION_BUY_READY)
      ? "BUY"
      : ((candidate == ACTION_SELL_READY) ? "SELL" : "NONE");
   DecisionBeforePressure = ActionToText(candidate);
   DecisionAfterPressure = DecisionBeforePressure;
   ScoreBeforePressure = candidateScore;
   ScoreAfterPressure = candidateScore;
   PressurePenaltyApplied = 0;
   PressureDecisionImpact = PRESSURE_IMPACT_NONE;
   PressureDecisionImpactText = "NONE";
   RegimeUsedForPressureScopeText =
      (ActiveRegime != TRE_PROFILE_UNKNOWN)
      ? ActiveRegimeText
      : DetectedRegimeText;
   PressureScopeAllowed = PressureSoftBlockScopeAllows();
   PressureScopeAllowedText = PressureScopeAllowed ? "YES" : "NO";

   if(candidate != ACTION_BUY_READY &&
      candidate != ACTION_SELL_READY)
   {
      PressureGuardStatusText = "NO_CANDIDATE";
      return candidate;
   }

   if(!UsePressureGuard ||
      PressureGuardMode == PRESSURE_GUARD_OFF)
   {
      PressureGuardStatusText = "DISABLED";
      return candidate;
   }

   bool opposing =
      (candidate == ACTION_BUY_READY &&
       PressureDirection == PRESSURE_DOWN) ||
      (candidate == ACTION_SELL_READY &&
       PressureDirection == PRESSURE_UP);

   if(!opposing || PressureLevel == PRESSURE_LOW)
   {
      PressureGuardStatusText = "ALLOW";
      PressureReasonText =
         PressureDirectionAdjective() + " pressure is " +
         PressureLevelText + ", allowing " +
         CandidateDirectionBeforePressure + ".";
      return candidate;
   }

   PressureAppliesToCandidateText = "YES";
   PressureBlockedDirectionText =
      (candidate == ACTION_BUY_READY) ? "BUY" : "SELL";
   PressureMissingConditionText =
      "Opposing " + PressureDirectionText + " " +
      PressureLevelText + " pressure against " +
      PressureBlockedDirectionText;

   if(PressureGuardMode == PRESSURE_GUARD_DISPLAY_ONLY)
   {
      PressureGuardStatusText = "DISPLAY_ONLY";
      PressureReasonText =
         PressureDirectionAdjective() + " pressure is " +
         PressureLevelText + " against " +
         PressureBlockedDirectionText +
         ", display only.";
      return candidate;
   }

   if(PressureGuardMode == PRESSURE_GUARD_WARN_ONLY)
   {
      PressureAction = PRESSURE_WARN;
      PressureActionText = PressureActionToText(PressureAction);
      PressureDecisionImpact = PRESSURE_IMPACT_WARNING_ONLY;
      PressureDecisionImpactText =
         PressureDecisionImpactToText(PressureDecisionImpact);
      PressureGuardStatusText = "WARNING";
      PressureReasonText =
         PressureDirectionAdjective() + " pressure is " +
         PressureLevelText + " against " +
         PressureBlockedDirectionText + ", warning only.";
      return candidate;
   }

   if(PressureGuardMode == PRESSURE_GUARD_SOFT_BLOCK)
   {
      if(!PressureScopeAllowed)
      {
         PressureGuardStatusText = "OUT_OF_SCOPE";
         PressureReasonText =
            "Confirmed directional regime is outside soft-block scope.";
         return candidate;
      }

      PressurePenaltyApplied =
         (PressureLevel == PRESSURE_HIGH)
         ? EffectivePressureHighPenalty
         : EffectivePressureMediumPenalty;
      ScoreAfterPressure =
         (int)MathMax(0, candidateScore - PressurePenaltyApplied);

      if(PressureLevel == PRESSURE_HIGH &&
         PressureHighDowngradeToWatch)
      {
         PressureAction = PRESSURE_SOFT_DOWNGRADE_TO_WATCH;
         PressureDecisionImpact =
            PRESSURE_IMPACT_DOWNGRADED_TO_WATCH;
         DecisionAfterPressure = ActionToText(ACTION_WATCH);
         PressureDowngradeReasonText = PressureMissingConditionText;
         PressureReasonText =
            PressureDirectionAdjective() + " pressure is HIGH against " +
            PressureBlockedDirectionText + ", downgrading " +
            DecisionBeforePressure + " to WATCH.";
         PressureGuardStatusText = "DOWNGRADED";
         PressureActionText = PressureActionToText(PressureAction);
         PressureDecisionImpactText =
            PressureDecisionImpactToText(PressureDecisionImpact);
         return ACTION_WATCH;
      }

      PressureAction = PRESSURE_SOFT_REDUCE_SCORE;
      PressureDecisionImpact = PRESSURE_IMPACT_SCORE_REDUCED;
      PressureReasonText =
         PressureDirectionAdjective() + " pressure is " +
         PressureLevelText + " against " +
         PressureBlockedDirectionText + ", reducing score by " +
         IntegerToString(PressurePenaltyApplied) + ".";
      PressureGuardStatusText = "SCORE_REDUCED";
      PressureActionText = PressureActionToText(PressureAction);
      PressureDecisionImpactText =
         PressureDecisionImpactToText(PressureDecisionImpact);
      return candidate;
   }

   PressureAction =
      (candidate == ACTION_BUY_READY)
      ? PRESSURE_HARD_BLOCK_BUY
      : PRESSURE_HARD_BLOCK_SELL;
   PressureDecisionImpact = PRESSURE_IMPACT_HARD_BLOCKED;
   PressureActionText = PressureActionToText(PressureAction);
   PressureDecisionImpactText =
      PressureDecisionImpactToText(PressureDecisionImpact);
   PressureBlockReasonText = PressureMissingConditionText;
   PressureReasonText =
      PressureDirectionAdjective() + " pressure is " +
      PressureLevelText + " against " +
      PressureBlockedDirectionText + ", hard blocking the candidate.";
   DecisionAfterPressure = ActionToText(ACTION_NO_TRADE);
   PressureGuardStatusText = "BLOCKED";
   return ACTION_NO_TRADE;
}

#endif
