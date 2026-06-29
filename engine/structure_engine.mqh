//+------------------------------------------------------------------+
//| engine/structure_engine.mqh                                      |
//| Authoritative EntryTF market structure state machine             |
//+------------------------------------------------------------------+
#ifndef TRE_STRUCTURE_ENGINE_MQH
#define TRE_STRUCTURE_ENGINE_MQH

#define TRE_STRUCTURE_PRESSURE_BARS 8
#define TRE_STRUCTURE_DIAGNOSTIC_EMA_PERIOD 20

string StructureStageToText(ENUM_TRE_STRUCTURE_STAGE stage)
{
   if(stage == TRE_STRUCTURE_FIRST_SWING)
      return "WAITING_SWING_PAIR";

   if(stage == TRE_STRUCTURE_PAIR_READY)
      return "BUILDING_STRUCTURE";

   if(stage == TRE_STRUCTURE_FORMING)
      return "WAITING_CONFIRMATION";

   if(stage == TRE_STRUCTURE_CONFIRMED_UPTREND)
      return "CONFIRMED";

   if(stage == TRE_STRUCTURE_CONFIRMED_DOWNTREND)
      return "CONFIRMED";

   return "WAITING_FIRST_SWING";
}

void StructureResetState()
{
   StructureStage = TRE_STRUCTURE_EMPTY;
   StructureStageText = "WAITING_FIRST_SWING";
   StructureConfirmedText = "UNCONFIRMED";
   StructureDirectionText = "Sideway";
   StructureReason = "No confirmed EntryTF swings";
   StructureStatusText = "Waiting";
   StructureBOSStateText = "WAIT";
   StructureCHOCHStateText = "WAIT";
   StructureConfidenceText = "N/A";
   StructureMissingEvidenceText =
      "Waiting for first confirmed swing high and swing low.";
   StructureValidationStageText = "WAITING_FIRST_SWING";
   StructureScore = 0;
   StructureSwingPairCount = 0;
   StructureHHCount = 0;
   StructureHLCount = 0;
   StructureLHCount = 0;
   StructureLLCount = 0;
   StructureDevelopmentStateText = "UNKNOWN";
   StructureEarlyWarningText = "NONE";
   StructureEarlyWarningReasonText = "N/A";
   StructureStrongDirectionalMoveText = "NONE";
   StructureRecentBearishCloseCount = 0;
   StructureRecentBullishCloseCount = 0;
   StructureConsecutiveBearishBars = 0;
   StructureConsecutiveBullishBars = 0;
   StructureRecentLowerLowCount = 0;
   StructureRecentHigherHighCount = 0;
   StructureRecentLowerCloseCount = 0;
   StructureRecentHigherCloseCount = 0;
   StructurePriceBelowEMAText = "N/A";
   StructurePriceAboveEMAText = "N/A";
   StructureEMASlopeDirectionText = "N/A";
   StructureDistanceFromEMAPointsText = "N/A";
   StructureInterpretationText = "N/A";
   StructureInterpretationLine1Text =
      "Waiting for structure evidence.";
   StructureInterpretationLine2Text = "N/A";
   StructureInterpretationLine3Text = "N/A";
   StructureSwingDetectionProgressText = "0% [----------]";
   StructureSwingPairProgressText = "0% [----------]";
   StructureBuildProgressText = "0% [----------]";
   StructureConfirmationProgressText = "0% [----------]";
   PendingSwingHighCandidateText = "NO";
   PendingSwingHighStatusText = "NONE";
   PendingSwingLowCandidateText = "NO";
   PendingSwingLowStatusText = "NONE";
   PendingSwingHighPrice = 0;
   PendingSwingLowPrice = 0;
   PendingSwingHighBarIndex = -1;
   PendingSwingLowBarIndex = -1;
   PendingSwingHighRightBarsWaited = 0;
   PendingSwingLowRightBarsWaited = 0;
   PendingSwingHighRightBarsRequired = 0;
   PendingSwingLowRightBarsRequired = 0;
}

bool StructureEMAAtShift(MqlRates &rates[],
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

void StructureUpdatePendingCandidates(MqlRates &rates[],
                                      int copied,
                                      int depth)
{
   int effectiveDepth = (int)MathMax(1, depth);
   PendingSwingHighRightBarsRequired = effectiveDepth;
   PendingSwingLowRightBarsRequired = effectiveDepth;

   if(copied <= effectiveDepth + 2)
      return;

   bool newestHigh = true;
   bool newestLow = true;

   for(int shift = 2; shift <= effectiveDepth + 1; shift++)
   {
      if(rates[1].high <= rates[shift].high)
         newestHigh = false;

      if(rates[1].low >= rates[shift].low)
         newestLow = false;
   }

   if(newestHigh)
   {
      PendingSwingHighCandidateText = "YES";
      PendingSwingHighPrice = rates[1].high;
      PendingSwingHighBarIndex = 1;
      PendingSwingHighStatusText = "INVALIDATED_BY_NEW_HIGH";
   }
   else
   {
      for(int candidate = 2;
          candidate <= effectiveDepth &&
          candidate + effectiveDepth < copied;
          candidate++)
      {
         bool olderBarsPass = true;
         bool newerBarsPass = true;

         for(int offset = 1; offset <= effectiveDepth; offset++)
         {
            if(rates[candidate].high <=
               rates[candidate + offset].high)
            {
               olderBarsPass = false;
            }
         }

         for(int newer = 1; newer < candidate; newer++)
         {
            if(rates[newer].high >= rates[candidate].high)
               newerBarsPass = false;
         }

         if(olderBarsPass && newerBarsPass)
         {
            PendingSwingHighCandidateText = "YES";
            PendingSwingHighPrice = rates[candidate].high;
            PendingSwingHighBarIndex = candidate;
            PendingSwingHighRightBarsWaited = candidate - 1;
            PendingSwingHighStatusText = "WAITING_RIGHT_BARS";
            break;
         }
      }
   }

   if(newestLow)
   {
      PendingSwingLowCandidateText = "YES";
      PendingSwingLowPrice = rates[1].low;
      PendingSwingLowBarIndex = 1;
      PendingSwingLowStatusText = "INVALIDATED_BY_NEW_LOW";
   }
   else
   {
      for(int candidate = 2;
          candidate <= effectiveDepth &&
          candidate + effectiveDepth < copied;
          candidate++)
      {
         bool olderBarsPass = true;
         bool newerBarsPass = true;

         for(int offset = 1; offset <= effectiveDepth; offset++)
         {
            if(rates[candidate].low >=
               rates[candidate + offset].low)
            {
               olderBarsPass = false;
            }
         }

         for(int newer = 1; newer < candidate; newer++)
         {
            if(rates[newer].low <= rates[candidate].low)
               newerBarsPass = false;
         }

         if(olderBarsPass && newerBarsPass)
         {
            PendingSwingLowCandidateText = "YES";
            PendingSwingLowPrice = rates[candidate].low;
            PendingSwingLowBarIndex = candidate;
            PendingSwingLowRightBarsWaited = candidate - 1;
            PendingSwingLowStatusText = "WAITING_RIGHT_BARS";
            break;
         }
      }
   }
}

void StructureSetDevelopmentState()
{
   if(StructureStage == TRE_STRUCTURE_CONFIRMED_UPTREND)
   {
      StructureDevelopmentStateText = "CONFIRMED_UPTREND";
      return;
   }

   if(StructureStage == TRE_STRUCTURE_CONFIRMED_DOWNTREND)
   {
      StructureDevelopmentStateText = "CONFIRMED_DOWNTREND";
      return;
   }

   if(StructureStrongDirectionalMoveText == "UP")
   {
      StructureDevelopmentStateText = "DEVELOPING_UPTREND";
      return;
   }

   if(StructureStrongDirectionalMoveText == "DOWN")
   {
      StructureDevelopmentStateText = "DEVELOPING_DOWNTREND";
      return;
   }

   if(StructureSwingHighCount == 0 &&
      StructureSwingLowCount == 0)
   {
      StructureDevelopmentStateText = "COLLECTING_SWINGS";
      return;
   }

   if(StructureSwingHighCount > 0 &&
      StructureSwingLowCount == 0)
   {
      StructureDevelopmentStateText =
         (StructureSwingHighCount >= 2)
         ? "HIGH_SEQUENCE_ONLY"
         : "WAITING_FIRST_LOW";
      return;
   }

   if(StructureSwingLowCount > 0 &&
      StructureSwingHighCount == 0)
   {
      StructureDevelopmentStateText =
         (StructureSwingLowCount >= 2)
         ? "LOW_SEQUENCE_ONLY"
         : "WAITING_FIRST_HIGH";
      return;
   }

   if(StructureHHCount > 0 || StructureHLCount > 0)
   {
      if(StructureLHCount == 0 && StructureLLCount == 0)
         StructureDevelopmentStateText = "POTENTIAL_UPTREND";
      else
         StructureDevelopmentStateText = "MIXED_STRUCTURE";

      return;
   }

   if(StructureLHCount > 0 || StructureLLCount > 0)
   {
      if(StructureHHCount == 0 && StructureHLCount == 0)
         StructureDevelopmentStateText = "POTENTIAL_DOWNTREND";
      else
         StructureDevelopmentStateText = "MIXED_STRUCTURE";

      return;
   }

   StructureDevelopmentStateText = "RANGE_BOUND";
}

void StructureSetEarlyWarning()
{
   if(StructureStrongDirectionalMoveText == "DOWN" &&
      StructureLastSwingLow <= 0)
   {
      StructureEarlyWarningText =
         "BEARISH_PRESSURE_WITHOUT_CONFIRMED_LOW";
      StructureEarlyWarningReasonText =
         "Price is making lower closes and lower lows, but pivot swing low is not confirmed because new lows keep forming.";
   }
   else if(StructureStrongDirectionalMoveText == "UP" &&
           StructureLastSwingHigh <= 0)
   {
      StructureEarlyWarningText =
         "BULLISH_PRESSURE_WITHOUT_CONFIRMED_HIGH";
      StructureEarlyWarningReasonText =
         "Price is making higher closes and higher highs, but pivot swing high is not confirmed because new highs keep forming.";
   }
   else if(StructureDirectionText == "Sideway" &&
           StructureDevelopmentStateText == "DEVELOPING_DOWNTREND")
   {
      StructureEarlyWarningText = "POTENTIAL_BEARISH_SHIFT";
      StructureEarlyWarningReasonText =
         "Confirmed structure is UNCONFIRMED while recent EntryTF pressure is bearish.";
   }
   else if(StructureDirectionText == "Sideway" &&
           StructureDevelopmentStateText == "DEVELOPING_UPTREND")
   {
      StructureEarlyWarningText = "POTENTIAL_BULLISH_SHIFT";
      StructureEarlyWarningReasonText =
         "Confirmed structure is UNCONFIRMED while recent EntryTF pressure is bullish.";
   }

   if(StructureDirectionText == "Sideway" &&
      StructureDevelopmentStateText == "DEVELOPING_DOWNTREND")
   {
      StructureInterpretationText =
         "Confirmed structure is UNCONFIRMED, but diagnostic pressure indicates Developing Downtrend.";
   }
   else if(StructureDirectionText == "Sideway" &&
           StructureDevelopmentStateText == "DEVELOPING_UPTREND")
   {
      StructureInterpretationText =
         "Confirmed structure is UNCONFIRMED, but diagnostic pressure indicates Developing Uptrend.";
   }
   else if(StructureDirectionText == "Sideway" &&
           PendingSwingLowStatusText == "WAITING_RIGHT_BARS")
   {
      StructureInterpretationText =
         "Waiting for right bars to confirm swing low.";
   }
   else if(StructureDirectionText == "Sideway" &&
           PendingSwingLowStatusText == "INVALIDATED_BY_NEW_LOW")
   {
      StructureInterpretationText =
         "Swing low candidate keeps moving because price continues making new lows.";
   }
   else
   {
      StructureInterpretationText = "N/A";
   }
}

string StructureProgressText(int percent)
{
   int safePercent = (int)MathMax(0, MathMin(100, percent));
   int filled = (int)MathRound(safePercent / 10.0);
   string bar = "[";

   for(int i = 0; i < 10; i++)
      bar += (i < filled) ? "#" : "-";

   bar += "]";
   return IntegerToString(safePercent) + "% " + bar;
}

void StructureUpdateUXPresentation()
{
   if(StructureStage == TRE_STRUCTURE_CONFIRMED_UPTREND)
      StructureConfirmedText = "CONFIRMED_UPTREND";
   else if(StructureStage == TRE_STRUCTURE_CONFIRMED_DOWNTREND)
      StructureConfirmedText = "CONFIRMED_DOWNTREND";
   else
      StructureConfirmedText = "UNCONFIRMED";

   int swingDetectionProgress = 0;

   if(StructureSwingHighCount >= 1)
      swingDetectionProgress += 50;

   if(StructureSwingLowCount >= 1)
      swingDetectionProgress += 50;

   int pairProgress =
      (StructureSwingPairCount >= 2)
      ? 100
      : ((StructureSwingPairCount == 1) ? 50 : 0);
   int buildProgress = 0;
   int confirmationProgress = 0;

   if(StructureStage == TRE_STRUCTURE_FIRST_SWING)
   {
      buildProgress = 20;
      confirmationProgress = 10;
   }
   else if(StructureStage == TRE_STRUCTURE_PAIR_READY)
   {
      buildProgress = 50;
      confirmationProgress = 30;
   }
   else if(StructureStage == TRE_STRUCTURE_FORMING)
   {
      buildProgress = 80;
      confirmationProgress = 60;
   }
   else if(StructureStage == TRE_STRUCTURE_CONFIRMED_UPTREND ||
           StructureStage == TRE_STRUCTURE_CONFIRMED_DOWNTREND)
   {
      buildProgress = 100;
      confirmationProgress = 100;
   }

   StructureSwingDetectionProgressText =
      StructureProgressText(swingDetectionProgress);
   StructureSwingPairProgressText =
      StructureProgressText(pairProgress);
   StructureBuildProgressText =
      StructureProgressText(buildProgress);
   StructureConfirmationProgressText =
      StructureProgressText(confirmationProgress);

   StructureInterpretationLine1Text =
      "Structure is not yet confirmed.";
   StructureInterpretationLine2Text =
      StructureMissingEvidenceText;
   StructureInterpretationLine3Text = "N/A";

   if(StructureConfirmedText == "CONFIRMED_UPTREND")
   {
      StructureInterpretationLine1Text =
         "Bullish market structure is confirmed.";
      StructureInterpretationLine2Text =
         "Higher High and Higher Low are aligned.";
      StructureInterpretationLine3Text = "N/A";
   }
   else if(StructureConfirmedText == "CONFIRMED_DOWNTREND")
   {
      StructureInterpretationLine1Text =
         "Bearish market structure is confirmed.";
      StructureInterpretationLine2Text =
         "Lower High and Lower Low are aligned.";
      StructureInterpretationLine3Text = "N/A";
   }
   else if(StructureDevelopmentStateText == "DEVELOPING_DOWNTREND")
   {
      StructureInterpretationLine1Text =
         "Market is showing strong bearish pressure.";

      if(StructureLastSwingLow <= 0)
      {
         StructureMissingEvidenceText =
            "Waiting for first confirmed swing low. Price continues making new lows, therefore pivot confirmation has not completed.";
         StructureInterpretationLine2Text =
            "Confirmation is delayed because no swing low is confirmed.";
         StructureInterpretationLine3Text =
            "Current movement should not be interpreted as sideways.";
      }
      else
      {
         StructureInterpretationLine2Text =
            "Waiting for an aligned confirmed swing pair.";
         StructureInterpretationLine3Text =
            "Developing pressure is not confirmed structure yet.";
      }
   }
   else if(StructureDevelopmentStateText == "DEVELOPING_UPTREND")
   {
      StructureInterpretationLine1Text =
         "Market is showing strong bullish pressure.";

      if(StructureLastSwingHigh <= 0)
      {
         StructureMissingEvidenceText =
            "Waiting for first confirmed swing high. Price continues making new highs, therefore pivot confirmation has not completed.";
         StructureInterpretationLine2Text =
            "Confirmation is delayed because no swing high is confirmed.";
         StructureInterpretationLine3Text =
            "Current movement should not be interpreted as sideways.";
      }
      else
      {
         StructureInterpretationLine2Text =
            "Waiting for an aligned confirmed swing pair.";
         StructureInterpretationLine3Text =
            "Developing pressure is not confirmed structure yet.";
      }
   }
   else if(StructureDevelopmentStateText == "POTENTIAL_DOWNTREND")
   {
      StructureInterpretationLine1Text =
         "Bearish structure evidence is developing.";
      StructureInterpretationLine2Text =
         "Waiting for the remaining confirmed swing relationship.";
   }
   else if(StructureDevelopmentStateText == "POTENTIAL_UPTREND")
   {
      StructureInterpretationLine1Text =
         "Bullish structure evidence is developing.";
      StructureInterpretationLine2Text =
         "Waiting for the remaining confirmed swing relationship.";
   }
   else if(StructureDevelopmentStateText == "RANGE_BOUND")
   {
      StructureInterpretationLine1Text =
         "No directional structure is confirmed.";
      StructureInterpretationLine2Text =
         "Diagnostic pressure is currently range-bound.";
   }

   StructureInterpretationText =
      StructureInterpretationLine1Text + " " +
      StructureInterpretationLine2Text;

   if(StructureInterpretationLine3Text != "N/A")
      StructureInterpretationText += " " +
                                     StructureInterpretationLine3Text;
}

void StructureUpdateDevelopmentDiagnostics(string symbol)
{
   int requested = (int)MathMax(
      TRE_STRUCTURE_DIAGNOSTIC_EMA_PERIOD + 3,
      TRE_STRUCTURE_PRESSURE_BARS + SwingDepth + 3);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, EntryTF, 0, requested, rates);

   if(copied <= 3)
   {
      StructureDevelopmentStateText = "NO_DATA";
      StructureEarlyWarningReasonText =
         "EntryTF history is unavailable for development diagnostics.";
      StructureUpdateUXPresentation();
      return;
   }

   int recentBars =
      (int)MathMin(TRE_STRUCTURE_PRESSURE_BARS, copied - 2);

   for(int shift = 1; shift <= recentBars; shift++)
   {
      if(rates[shift].close < rates[shift].open)
         StructureRecentBearishCloseCount++;
      else if(rates[shift].close > rates[shift].open)
         StructureRecentBullishCloseCount++;

      if(rates[shift].low < rates[shift + 1].low)
         StructureRecentLowerLowCount++;

      if(rates[shift].high > rates[shift + 1].high)
         StructureRecentHigherHighCount++;

      if(rates[shift].close < rates[shift + 1].close)
         StructureRecentLowerCloseCount++;
      else if(rates[shift].close > rates[shift + 1].close)
         StructureRecentHigherCloseCount++;
   }

   for(int shift = 1; shift <= recentBars; shift++)
   {
      if(rates[shift].close < rates[shift].open)
         StructureConsecutiveBearishBars++;
      else
         break;
   }

   for(int shift = 1; shift <= recentBars; shift++)
   {
      if(rates[shift].close > rates[shift].open)
         StructureConsecutiveBullishBars++;
      else
         break;
   }

   double emaCurrent = 0;
   double emaPrevious = 0;
   bool emaReady =
      StructureEMAAtShift(rates, copied, 1,
                          TRE_STRUCTURE_DIAGNOSTIC_EMA_PERIOD,
                          emaCurrent) &&
      StructureEMAAtShift(rates, copied, 2,
                          TRE_STRUCTURE_DIAGNOSTIC_EMA_PERIOD,
                          emaPrevious);
   bool priceAboveEMA = false;
   bool priceBelowEMA = false;
   string emaSlope = "N/A";

   if(emaReady)
   {
      priceAboveEMA = (rates[1].close > emaCurrent);
      priceBelowEMA = (rates[1].close < emaCurrent);
      StructurePriceAboveEMAText = priceAboveEMA ? "YES" : "NO";
      StructurePriceBelowEMAText = priceBelowEMA ? "YES" : "NO";

      if(emaCurrent > emaPrevious)
         emaSlope = "UP";
      else if(emaCurrent < emaPrevious)
         emaSlope = "DOWN";
      else
         emaSlope = "FLAT";

      StructureEMASlopeDirectionText = emaSlope;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(point > 0)
      {
         StructureDistanceFromEMAPointsText =
            DoubleToString((rates[1].close - emaCurrent) / point, 1);
      }
   }

   bool strongDown =
      ((StructureConsecutiveBearishBars >= 3 ||
        StructureRecentBearishCloseCount >= 5) &&
       StructureRecentLowerLowCount >= 3 &&
       StructureRecentLowerCloseCount >= 3 &&
       (!emaReady || (priceBelowEMA && emaSlope == "DOWN")));
   bool strongUp =
      ((StructureConsecutiveBullishBars >= 3 ||
        StructureRecentBullishCloseCount >= 5) &&
       StructureRecentHigherHighCount >= 3 &&
       StructureRecentHigherCloseCount >= 3 &&
       (!emaReady || (priceAboveEMA && emaSlope == "UP")));

   if(strongDown && !strongUp)
      StructureStrongDirectionalMoveText = "DOWN";
   else if(strongUp && !strongDown)
      StructureStrongDirectionalMoveText = "UP";

   StructureUpdatePendingCandidates(rates, copied, SwingDepth);
   StructureSetDevelopmentState();
   StructureSetEarlyWarning();
   StructureUpdateUXPresentation();
}

void StructureCountSwingEvidence()
{
   for(int i = 0; i < StructureSwingHighStoredCount - 1; i++)
   {
      double newer = StructureSwingHighValues[i];
      double older = StructureSwingHighValues[i + 1];

      if(newer > older)
         StructureHHCount++;
      else if(newer < older)
         StructureLHCount++;
   }

   for(int i = 0; i < StructureSwingLowStoredCount - 1; i++)
   {
      double newer = StructureSwingLowValues[i];
      double older = StructureSwingLowValues[i + 1];

      if(newer > older)
         StructureHLCount++;
      else if(newer < older)
         StructureLLCount++;
   }

   StructureSwingPairCount =
      (int)MathMin(StructureSwingHighCount,
                   StructureSwingLowCount);
}

void StructureSetIncompleteStage()
{
   bool hasHigh =
      (StructureSwingHighCount >= 1 &&
       StructureLastSwingHigh > 0);
   bool hasLow =
      (StructureSwingLowCount >= 1 &&
       StructureLastSwingLow > 0);
   bool hasTwoHighs =
      (StructureSwingHighCount >= 2 &&
       StructurePrevSwingHigh > 0);
   bool hasTwoLows =
      (StructureSwingLowCount >= 2 &&
       StructurePrevSwingLow > 0);

   if(!hasHigh && !hasLow)
      return;

   if(!hasHigh || !hasLow)
   {
      StructureStage = TRE_STRUCTURE_FIRST_SWING;
      StructureStageText = StructureStageToText(StructureStage);
      StructureReason = "First confirmed swing is available";
      StructureConfidenceText = "Very Low";
      StructureMissingEvidenceText =
         !hasHigh ? "Waiting for first confirmed swing high."
                  : "Waiting for first confirmed swing low.";
      StructureValidationStageText = "WAITING_SWING_PAIR";
      StructureScore = 2;
      return;
   }

   if(!hasTwoHighs || !hasTwoLows)
   {
      StructureStage = TRE_STRUCTURE_PAIR_READY;
      StructureStageText = StructureStageToText(StructureStage);
      StructureReason = "First swing high and low pair is ready";
      StructureConfidenceText = "Low";

      if(!hasTwoHighs && !hasTwoLows)
      {
         StructureMissingEvidenceText =
            "Waiting for second confirmed swing high and swing low.";
      }
      else if(!hasTwoHighs)
      {
         StructureMissingEvidenceText =
            "Waiting for second confirmed swing high.";
      }
      else
      {
         StructureMissingEvidenceText =
            "Waiting for second confirmed swing low.";
      }

      StructureValidationStageText = "BUILDING_STRUCTURE";
      StructureScore = 5;
   }
}

void StructureEvaluateBreaks(double price)
{
   if(price <= 0 ||
      StructureLastSwingHigh <= 0 ||
      StructureLastSwingLow <= 0)
   {
      return;
   }

   if(price > StructureLastSwingHigh)
   {
      StructureBOSStateText = "BULLISH_BOS";

      if(StructureStage == TRE_STRUCTURE_CONFIRMED_DOWNTREND)
      {
         StructureCHOCHStateText = "BULLISH_CHOCH";
      }

      return;
   }

   if(price < StructureLastSwingLow)
   {
      StructureBOSStateText = "BEARISH_BOS";

      if(StructureStage == TRE_STRUCTURE_CONFIRMED_UPTREND)
      {
         StructureCHOCHStateText = "BEARISH_CHOCH";
      }
   }
}

void StructureEngine(string symbol)
{
   StructureResetState();
   StructureCountSwingEvidence();

   bool hasTwoHighs =
      (StructureSwingHighCount >= 2 &&
       StructureLastSwingHigh > 0 &&
       StructurePrevSwingHigh > 0);
   bool hasTwoLows =
      (StructureSwingLowCount >= 2 &&
       StructureLastSwingLow > 0 &&
       StructurePrevSwingLow > 0);

   if(!hasTwoHighs || !hasTwoLows)
   {
      StructureSetIncompleteStage();
      StructureEvaluateBreaks(SymbolInfoDouble(symbol, SYMBOL_BID));
      StructureUpdateDevelopmentDiagnostics(symbol);
      return;
   }

   bool latestHH =
      (StructureLastSwingHigh > StructurePrevSwingHigh);
   bool latestLH =
      (StructureLastSwingHigh < StructurePrevSwingHigh);
   bool latestHL =
      (StructureLastSwingLow > StructurePrevSwingLow);
   bool latestLL =
      (StructureLastSwingLow < StructurePrevSwingLow);

   if(latestHH && latestHL)
   {
      StructureStage = TRE_STRUCTURE_CONFIRMED_UPTREND;
      StructureDirectionText = "Bullish";
      StructureReason = "Higher High and Higher Low aligned";
      StructureStatusText = "Confirmed";
      StructureConfidenceText = "High";
      StructureMissingEvidenceText = "N/A";
      StructureValidationStageText = "CONFIRMED";
      StructureScore = 20;
   }
   else if(latestLH && latestLL)
   {
      StructureStage = TRE_STRUCTURE_CONFIRMED_DOWNTREND;
      StructureDirectionText = "Bearish";
      StructureReason = "Lower High and Lower Low aligned";
      StructureStatusText = "Confirmed";
      StructureConfidenceText = "High";
      StructureMissingEvidenceText = "N/A";
      StructureValidationStageText = "CONFIRMED";
      StructureScore = 20;
   }
   else
   {
      StructureStage = TRE_STRUCTURE_FORMING;
      StructureDirectionText = "Sideway";
      StructureReason = "Swing directions are mixed";
      StructureStatusText = "Waiting";
      StructureConfidenceText = "Medium";
      StructureMissingEvidenceText =
         "Waiting for aligned swing sequence: HH + HL or LH + LL.";
      StructureValidationStageText = "WAITING_CONFIRMATION";
      StructureScore = 10;
   }

   StructureStageText = StructureStageToText(StructureStage);
   StructureEvaluateBreaks(SymbolInfoDouble(symbol, SYMBOL_BID));
   StructureUpdateDevelopmentDiagnostics(symbol);
}

#endif
