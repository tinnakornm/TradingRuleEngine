//+------------------------------------------------------------------+
//| engine/swing_engine.mqh                                          |
//| Publish confirmed BiasTF and EntryTF swing structure             |
//+------------------------------------------------------------------+
#ifndef TRE_SWING_ENGINE_MQH
#define TRE_SWING_ENGINE_MQH

bool SwingSeriesHigh(MqlRates &rates[],
                     int copied,
                     int shift,
                     int depth)
{
   if(shift - depth < 1 || shift + depth >= copied)
      return false;

   double center = rates[shift].high;

   if(center <= 0)
      return false;

   for(int i = 1; i <= depth; i++)
   {
      if(center <= rates[shift - i].high ||
         center <= rates[shift + i].high)
      {
         return false;
      }
   }

   return true;
}

bool SwingSeriesLow(MqlRates &rates[],
                    int copied,
                    int shift,
                    int depth)
{
   if(shift - depth < 1 || shift + depth >= copied)
      return false;

   double center = rates[shift].low;

   if(center <= 0)
      return false;

   for(int i = 1; i <= depth; i++)
   {
      if(center >= rates[shift - i].low ||
         center >= rates[shift + i].low)
      {
         return false;
      }
   }

   return true;
}

string SwingAvailabilityReason(int copied,
                               int requested,
                               int highCount,
                               int lowCount)
{
   if(copied <= 0)
      return "CopyRates returned no history";

   if(copied < requested)
      return "History incomplete: fewer bars copied than requested";

   if(highCount == 0 && lowCount == 0)
      return "No confirmed swing high or low inside lookback";

   if(highCount < 2 && lowCount < 2)
      return "Need second confirmed swing high and swing low";

   if(highCount < 2)
      return "Need second confirmed swing high";

   if(lowCount < 2)
      return "Need second confirmed swing low";

   return "N/A";
}

void SwingDetectContext(string symbol,
                        ENUM_TIMEFRAMES timeframe,
                        int lookback,
                        int depth,
                        double &lastHigh,
                        double &previousHigh,
                        double &lastLow,
                        double &previousLow,
                        int &barsCopied,
                        int &highCount,
                        int &lowCount,
                        int &lastHighIndex,
                        int &lastLowIndex,
                        string &noSwingReason,
                        bool publishStructureSequence)
{
   lastHigh = 0;
   previousHigh = 0;
   lastLow = 0;
   previousLow = 0;
   barsCopied = 0;
   highCount = 0;
   lowCount = 0;
   lastHighIndex = -1;
   lastLowIndex = -1;
   noSwingReason = "Not evaluated";

   if(publishStructureSequence)
   {
      StructureSwingHighStoredCount = 0;
      StructureSwingLowStoredCount = 0;
      ArrayInitialize(StructureSwingHighValues, 0);
      ArrayInitialize(StructureSwingLowValues, 0);
      ArrayInitialize(StructureSwingHighIndexes, -1);
      ArrayInitialize(StructureSwingLowIndexes, -1);
   }

   int effectiveDepth = (int)MathMax(1, depth);
   int requestedBars = lookback + effectiveDepth + 1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   barsCopied = CopyRates(symbol, timeframe, 0, requestedBars, rates);

   if(barsCopied <= 0)
   {
      noSwingReason =
         SwingAvailabilityReason(barsCopied, requestedBars, 0, 0);
      return;
   }

   // Start at depth + 1 so every right-side confirmation bar is closed.
   for(int shift = effectiveDepth + 1;
       shift <= lookback && shift + effectiveDepth < barsCopied;
       shift++)
   {
      if(SwingSeriesHigh(rates, barsCopied, shift, effectiveDepth))
      {
         highCount++;

         if(publishStructureSequence &&
            StructureSwingHighStoredCount < TRE_MAX_STRUCTURE_SWINGS)
         {
            int index = StructureSwingHighStoredCount;
            StructureSwingHighValues[index] = rates[shift].high;
            StructureSwingHighIndexes[index] = shift;
            StructureSwingHighStoredCount++;
         }

         if(lastHigh <= 0)
         {
            lastHigh = rates[shift].high;
            lastHighIndex = shift;
         }
         else if(previousHigh <= 0)
         {
            previousHigh = rates[shift].high;
         }
      }

      if(SwingSeriesLow(rates, barsCopied, shift, effectiveDepth))
      {
         lowCount++;

         if(publishStructureSequence &&
            StructureSwingLowStoredCount < TRE_MAX_STRUCTURE_SWINGS)
         {
            int index = StructureSwingLowStoredCount;
            StructureSwingLowValues[index] = rates[shift].low;
            StructureSwingLowIndexes[index] = shift;
            StructureSwingLowStoredCount++;
         }

         if(lastLow <= 0)
         {
            lastLow = rates[shift].low;
            lastLowIndex = shift;
         }
         else if(previousLow <= 0)
         {
            previousLow = rates[shift].low;
         }
      }
   }

   noSwingReason =
      SwingAvailabilityReason(barsCopied,
                              requestedBars,
                              highCount,
                              lowCount);
}

void SwingPublishStructureSequence()
{
   StructureSwingHighCount = StructureSwingHighStoredCount;
   StructureSwingLowCount = StructureSwingLowStoredCount;

   StructureLastSwingHigh =
      (StructureSwingHighStoredCount >= 1)
      ? StructureSwingHighValues[0]
      : 0;
   StructurePrevSwingHigh =
      (StructureSwingHighStoredCount >= 2)
      ? StructureSwingHighValues[1]
      : 0;
   StructureLastSwingLow =
      (StructureSwingLowStoredCount >= 1)
      ? StructureSwingLowValues[0]
      : 0;
   StructurePrevSwingLow =
      (StructureSwingLowStoredCount >= 2)
      ? StructureSwingLowValues[1]
      : 0;

   StructureLastSwingHighBarIndex =
      (StructureSwingHighStoredCount >= 1)
      ? StructureSwingHighIndexes[0]
      : -1;
   StructureLastSwingLowBarIndex =
      (StructureSwingLowStoredCount >= 1)
      ? StructureSwingLowIndexes[0]
      : -1;

   bool highMappingValid =
      ((StructureSwingHighCount == 0 &&
        StructureLastSwingHigh <= 0) ||
       (StructureSwingHighCount >= 1 &&
        StructureLastSwingHigh > 0));
   bool previousHighValid =
      ((StructureSwingHighCount < 2 &&
        StructurePrevSwingHigh <= 0) ||
       (StructureSwingHighCount >= 2 &&
        StructurePrevSwingHigh > 0));
   bool lowMappingValid =
      ((StructureSwingLowCount == 0 &&
        StructureLastSwingLow <= 0) ||
       (StructureSwingLowCount >= 1 &&
        StructureLastSwingLow > 0));
   bool previousLowValid =
      ((StructureSwingLowCount < 2 &&
        StructurePrevSwingLow <= 0) ||
       (StructureSwingLowCount >= 2 &&
        StructurePrevSwingLow > 0));

   bool mappingValid =
      highMappingValid && previousHighValid &&
      lowMappingValid && previousLowValid;
   bool truncated =
      (StructureSwingDetectedHighCount >
       StructureSwingHighStoredCount ||
       StructureSwingDetectedLowCount >
       StructureSwingLowStoredCount);

   if(!mappingValid)
      StructureSwingMappingStatusText = "INVALID";
   else if(truncated)
      StructureSwingMappingStatusText = "TRUNCATED";
   else
      StructureSwingMappingStatusText = "VALID";

   StructureSwingMappingReasonText =
      "Detected H/L " +
      IntegerToString(StructureSwingDetectedHighCount) + "/" +
      IntegerToString(StructureSwingDetectedLowCount) +
      ", Stored H/L " +
      IntegerToString(StructureSwingHighStoredCount) + "/" +
      IntegerToString(StructureSwingLowStoredCount) +
      ", Published H/L " +
      IntegerToString(StructureSwingHighCount) + "/" +
      IntegerToString(StructureSwingLowCount);
}

void SwingEngine(string symbol)
{
   EffectiveBiasLookbackBars =
      TRE_ValidatedLookbackBars(BiasLookbackBars);
   int effectiveDepth = (int)MathMax(1, SwingDepth);

   SwingEngineCalledText = "YES";
   BiasSwingTimeframeText = TimeframeToText(BiasTF);
   StructureSwingTimeframeText = TimeframeToText(EntryTF);
   BiasSwingLookbackRequested = EffectiveBiasLookbackBars;
   StructureSwingLookbackRequested = EffectiveBiasLookbackBars;
   BiasSwingLeftBars = effectiveDepth;
   BiasSwingRightBars = effectiveDepth;
   StructureSwingLeftBars = effectiveDepth;
   StructureSwingRightBars = effectiveDepth;

   SwingDetectContext(symbol,
                      BiasTF,
                      EffectiveBiasLookbackBars,
                      effectiveDepth,
                      LastSwingHigh,
                      PrevSwingHigh,
                      LastSwingLow,
                      PrevSwingLow,
                      BiasSwingBarsCopied,
                      BiasSwingHighCount,
                      BiasSwingLowCount,
                      BiasLastSwingHighBarIndex,
                      BiasLastSwingLowBarIndex,
                      BiasSwingNoSwingReasonText,
                      false);

   SwingDetectContext(symbol,
                      EntryTF,
                      EffectiveBiasLookbackBars,
                      effectiveDepth,
                      StructureLastSwingHigh,
                      StructurePrevSwingHigh,
                      StructureLastSwingLow,
                      StructurePrevSwingLow,
                      StructureSwingBarsCopied,
                      StructureSwingDetectedHighCount,
                      StructureSwingDetectedLowCount,
                      StructureLastSwingHighBarIndex,
                      StructureLastSwingLowBarIndex,
                      StructureSwingNoSwingReasonText,
                      true);

   SwingPublishStructureSequence();
}

#endif
