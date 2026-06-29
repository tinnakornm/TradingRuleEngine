//+------------------------------------------------------------------+
//| engine/regime_engine.mqh                                         |
//| Alpha 1.0 market regime detection and profile switching          |
//+------------------------------------------------------------------+
#ifndef TRE_REGIME_ENGINE_MQH
#define TRE_REGIME_ENGINE_MQH

int TRERegimeEMAHandle = INVALID_HANDLE;
int TRERegimeATRHandle = INVALID_HANDLE;
string TRERegimeIndicatorSymbol = "";
ENUM_TIMEFRAMES TRERegimeIndicatorTF = PERIOD_CURRENT;
int TRERegimeEMAHandlePeriod = 0;
int TRERegimeATRHandlePeriod = 0;

string RegimeYesNo(bool value)
{
   return value ? "YES" : "NO";
}

int RegimeNormalizeScore(double score, double maximum)
{
   if(maximum <= 0)
      return 0;

   return (int)MathRound(
      MathMax(0.0, MathMin(1.0, score / maximum)) * 100.0);
}

void RegimeSetEvidence(TRE_EvidenceItem &item,
                       string name,
                       bool enabled,
                       bool passed,
                       double maximum,
                       string passReason,
                       string failReason,
                       string missing)
{
   if(!enabled)
   {
      TRE_SetEvidenceItem(item, name, TRE_STATUS_NA, 0, maximum,
                          "Evidence disabled by configuration", "N/A");
      return;
   }

   TRE_SetEvidenceItem(item,
                       name,
                       passed ? TRE_STATUS_PASS : TRE_STATUS_FAIL,
                       passed ? maximum : 0,
                       maximum,
                       passed ? passReason : failReason,
                       passed ? "N/A" : missing);
}

void RegimeSetWaitingEvidence(TRE_EvidenceItem &item,
                              string name,
                              double score,
                              double maximum,
                              string reason,
                              string missing)
{
   TRE_SetEvidenceItem(item, name, TRE_STATUS_WAIT, score, maximum,
                       reason, missing);
}

void RegimeReleaseIndicatorHandles()
{
   if(TRERegimeEMAHandle != INVALID_HANDLE)
      IndicatorRelease(TRERegimeEMAHandle);

   if(TRERegimeATRHandle != INVALID_HANDLE)
      IndicatorRelease(TRERegimeATRHandle);

   TRERegimeEMAHandle = INVALID_HANDLE;
   TRERegimeATRHandle = INVALID_HANDLE;
   TRERegimeIndicatorSymbol = "";
   TRERegimeIndicatorTF = PERIOD_CURRENT;
   TRERegimeEMAHandlePeriod = 0;
   TRERegimeATRHandlePeriod = 0;
}

bool RegimePrepareIndicatorHandles(string symbol)
{
   bool settingsChanged =
      (TRERegimeIndicatorSymbol != symbol ||
       TRERegimeIndicatorTF != RegimeTF ||
       TRERegimeEMAHandlePeriod != EffectiveRegimeEMAPeriod ||
       TRERegimeATRHandlePeriod != EffectiveRegimeATRPeriod);

   if(settingsChanged)
      RegimeReleaseIndicatorHandles();

   TRERegimeIndicatorSymbol = symbol;
   TRERegimeIndicatorTF = RegimeTF;
   TRERegimeEMAHandlePeriod = EffectiveRegimeEMAPeriod;
   TRERegimeATRHandlePeriod = EffectiveRegimeATRPeriod;

   if(RegimeUseEMAFilter && TRERegimeEMAHandle == INVALID_HANDLE)
   {
      TRERegimeEMAHandle = iMA(symbol,
                               RegimeTF,
                               EffectiveRegimeEMAPeriod,
                               0,
                               MODE_EMA,
                               PRICE_CLOSE);
   }

   if(RegimeUseATRExpansion && TRERegimeATRHandle == INVALID_HANDLE)
   {
      TRERegimeATRHandle = iATR(symbol,
                                RegimeTF,
                                EffectiveRegimeATRPeriod);
   }

   if(RegimeUseEMAFilter && TRERegimeEMAHandle == INVALID_HANDLE)
      return false;

   if(RegimeUseATRExpansion && TRERegimeATRHandle == INVALID_HANDLE)
      return false;

   return true;
}

bool RegimeReadBufferValue(int handle, int shift, double &value)
{
   double buffer[1];
   value = 0;

   if(handle == INVALID_HANDLE ||
      CopyBuffer(handle, 0, shift, 1, buffer) != 1)
   {
      return false;
   }

   value = buffer[0];
   return (value > 0);
}

bool RegimeReadATRData(double &currentATR, double &averageATR)
{
   currentATR = 0;
   averageATR = 0;

   if(!RegimeUseATRExpansion)
      return true;

   if(!RegimeReadBufferValue(TRERegimeATRHandle, 1, currentATR))
      return false;

   double values[];
   ArrayResize(values, EffectiveRegimeLookbackBars);
   int copied = CopyBuffer(TRERegimeATRHandle,
                           0,
                           1,
                           EffectiveRegimeLookbackBars,
                           values);

   if(copied != EffectiveRegimeLookbackBars)
      return false;

   for(int i = 0; i < copied; i++)
      averageATR += values[i];

   averageATR /= copied;
   return (averageATR > 0);
}

bool RegimeCalculateHalfRanges(string symbol,
                               double &recentRange,
                               double &previousRange,
                               double &recentHigh,
                               double &recentLow,
                               double &previousHigh,
                               double &previousLow)
{
   recentRange = 0;
   previousRange = 0;
   int halfBars = (int)MathMax(3, EffectiveRegimeLookbackBars / 2);
   recentHigh = 0;
   recentLow = DBL_MAX;
   previousHigh = 0;
   previousLow = DBL_MAX;

   for(int shift = 1; shift <= halfBars; shift++)
   {
      double high = iHigh(symbol, RegimeTF, shift);
      double low = iLow(symbol, RegimeTF, shift);

      if(high <= 0 || low <= 0)
         return false;

      recentHigh = MathMax(recentHigh, high);
      recentLow = MathMin(recentLow, low);
   }

   for(int shift = halfBars + 1; shift <= halfBars * 2; shift++)
   {
      double high = iHigh(symbol, RegimeTF, shift);
      double low = iLow(symbol, RegimeTF, shift);

      if(high <= 0 || low <= 0)
         return false;

      previousHigh = MathMax(previousHigh, high);
      previousLow = MathMin(previousLow, low);
   }

   recentRange = recentHigh - recentLow;
   previousRange = previousHigh - previousLow;
   return (recentRange > 0 && previousRange > 0);
}

bool RegimeIsSwingHigh(string symbol, int shift)
{
   double center = iHigh(symbol, RegimeTF, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= SwingDepth; i++)
   {
      if(center <= iHigh(symbol, RegimeTF, shift - i) ||
         center <= iHigh(symbol, RegimeTF, shift + i))
      {
         return false;
      }
   }

   return true;
}

bool RegimeIsSwingLow(string symbol, int shift)
{
   double center = iLow(symbol, RegimeTF, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= SwingDepth; i++)
   {
      if(center >= iLow(symbol, RegimeTF, shift - i) ||
         center >= iLow(symbol, RegimeTF, shift + i))
      {
         return false;
      }
   }

   return true;
}

void RegimeCountSwingStructure(string symbol)
{
   RegimeSwingHighCount = 0;
   RegimeSwingLowCount = 0;
   RegimeHigherHighCount = 0;
   RegimeHigherLowCount = 0;
   RegimeLowerHighCount = 0;
   RegimeLowerLowCount = 0;
   double newerHigh = 0;
   double newerLow = 0;

   for(int shift = SwingDepth + 1;
       shift < EffectiveRegimeLookbackBars;
       shift++)
   {
      if(RegimeIsSwingHigh(symbol, shift))
      {
         double value = iHigh(symbol, RegimeTF, shift);
         RegimeSwingHighCount++;

         if(newerHigh > 0)
         {
            if(newerHigh > value)
               RegimeHigherHighCount++;
            else if(newerHigh < value)
               RegimeLowerHighCount++;
         }

         newerHigh = value;
      }

      if(RegimeIsSwingLow(symbol, shift))
      {
         double value = iLow(symbol, RegimeTF, shift);
         RegimeSwingLowCount++;

         if(newerLow > 0)
         {
            if(newerLow > value)
               RegimeHigherLowCount++;
            else if(newerLow < value)
               RegimeLowerLowCount++;
         }

         newerLow = value;
      }
   }
}

void RegimeCountEMACloses(string symbol)
{
   RegimeCloseAboveEMACount = 0;
   RegimeCloseBelowEMACount = 0;

   if(!RegimeUseEMAFilter)
      return;

   for(int shift = 1; shift <= EffectiveRegimeLookbackBars; shift++)
   {
      double ema = 0;
      double close = iClose(symbol, RegimeTF, shift);

      if(close <= 0 ||
         !RegimeReadBufferValue(TRERegimeEMAHandle, shift, ema))
      {
         continue;
      }

      if(close > ema)
         RegimeCloseAboveEMACount++;
      else if(close < ema)
         RegimeCloseBelowEMACount++;
   }
}

void RegimeResetOutput()
{
   DetectedRegime = TRE_PROFILE_UNKNOWN;
   DetectedRegimeText = "UNKNOWN";
   UptrendScore = 0;
   DowntrendScore = 0;
   SidewayScore = 0;
   RegimeConfidence = 0;
   RegimeConfidenceText = "0 / 100";
   RegimeEMAValueText = RegimeUseEMAFilter ? "N/A" : "DISABLED";
   RegimeEMASlopeText = RegimeUseEMAFilter ? "N/A" : "DISABLED";
   RegimeATRValueText = RegimeUseATRExpansion ? "N/A" : "DISABLED";
   RegimeATRExpansionText =
      RegimeUseATRExpansion ? "N/A" : "DISABLED";
   RegimeBestCandidateText = "UNKNOWN";
   RegimeRawDetectedText = "UNKNOWN";
   RegimeThresholdResultText = "FAIL";
   RegimeConfidenceCommentText = "WEAK";
   RegimeWinningScore = 0;
   RegimeScoreGap = 0;
   RegimeCandidateConfidence = 0;
   RegimeCurrentPriceText = "N/A";
   RegimeOpenText = "N/A";
   RegimeHighText = "N/A";
   RegimeLowText = "N/A";
   RegimeCloseText = "N/A";
   RegimeLookbackHighText = "N/A";
   RegimeLookbackLowText = "N/A";
   RegimeLookbackRangePointsText = "N/A";
   RegimeEMAPreviousValueText =
      RegimeUseEMAFilter ? "N/A" : "DISABLED";
   RegimeEMASlopePointsText =
      RegimeUseEMAFilter ? "N/A" : "DISABLED";
   RegimeATRPointsText =
      RegimeUseATRExpansion ? "N/A" : "DISABLED";
   RegimeATRAveragePointsText =
      RegimeUseATRExpansion ? "N/A" : "DISABLED";
   RegimeH4BiasText = BiasToText(MarketBias);
   RegimeMidZoneTouchCountText = "N/A";
   RegimeSwingHighCount = 0;
   RegimeSwingLowCount = 0;
   RegimeHigherHighCount = 0;
   RegimeHigherLowCount = 0;
   RegimeLowerHighCount = 0;
   RegimeLowerLowCount = 0;
   RegimeCloseAboveEMACount = 0;
   RegimeCloseBelowEMACount = 0;
   RegimeUptrendReasonText = "Data unavailable";
   RegimeDowntrendReasonText = "Data unavailable";
   RegimeSidewayReasonText = "Data unavailable";

   RegimeSetWaitingEvidence(RegimeUptrendEvidence[0],
                            "HH_HL_Structure", 0, 25,
                            "Not evaluated", "Need swing structure");
   RegimeSetWaitingEvidence(RegimeUptrendEvidence[1],
                            "PriceAboveEMA", 0, 15,
                            "Not evaluated", "Need EMA data");
   RegimeSetWaitingEvidence(RegimeUptrendEvidence[2],
                            "EMASlopeUp", 0, 15,
                            "Not evaluated", "Need EMA slope");
   RegimeSetWaitingEvidence(RegimeUptrendEvidence[3],
                            "BullishBias", 0, 15,
                            "Not evaluated", "Need H4 BUY bias");
   RegimeSetWaitingEvidence(RegimeUptrendEvidence[4],
                            "ATRTrendExpansion", 0, 15,
                            "Not evaluated", "Need ATR expansion");
   RegimeSetWaitingEvidence(RegimeUptrendEvidence[5],
                            "HigherCloseSequence", 0, 15,
                            "Not evaluated", "Need rising closes");

   RegimeSetWaitingEvidence(RegimeDowntrendEvidence[0],
                            "LH_LL_Structure", 0, 25,
                            "Not evaluated", "Need swing structure");
   RegimeSetWaitingEvidence(RegimeDowntrendEvidence[1],
                            "PriceBelowEMA", 0, 15,
                            "Not evaluated", "Need EMA data");
   RegimeSetWaitingEvidence(RegimeDowntrendEvidence[2],
                            "EMASlopeDown", 0, 15,
                            "Not evaluated", "Need EMA slope");
   RegimeSetWaitingEvidence(RegimeDowntrendEvidence[3],
                            "BearishBias", 0, 15,
                            "Not evaluated", "Need H4 SELL bias");
   RegimeSetWaitingEvidence(RegimeDowntrendEvidence[4],
                            "ATRTrendExpansion", 0, 15,
                            "Not evaluated", "Need ATR expansion");
   RegimeSetWaitingEvidence(RegimeDowntrendEvidence[5],
                            "LowerCloseSequence", 0, 15,
                            "Not evaluated", "Need falling closes");

   RegimeSetWaitingEvidence(RegimeSidewayEvidence[0],
                            "FlatEMA", 0, 20,
                            "Not evaluated", "Need flat EMA");
   RegimeSetWaitingEvidence(RegimeSidewayEvidence[1],
                            "StableRange", 0, 20,
                            "Not evaluated", "Need stable range");
   RegimeSetWaitingEvidence(RegimeSidewayEvidence[2],
                            "NoCleanTrendStructure", 0, 20,
                            "Not evaluated", "Need mixed structure");
   RegimeSetWaitingEvidence(RegimeSidewayEvidence[3],
                            "MidZoneRotation", 0, 15,
                            "Not evaluated", "Need Zone 3 or 4");
   RegimeSetWaitingEvidence(RegimeSidewayEvidence[4],
                            "ATRNotExpanding", 0, 15,
                            "Not evaluated", "Need stable ATR");
   RegimeSetWaitingEvidence(RegimeSidewayEvidence[5],
                            "RangeRespect", 0, 10,
                            "Not evaluated", "Need closes inside range");
}

bool RegimeCalculateScores(string symbol)
{
   RegimeResetOutput();
   int requiredBars = EffectiveRegimeLookbackBars;

   if(RegimeUseEMAFilter)
      requiredBars = (int)MathMax(requiredBars,
                                  EffectiveRegimeEMAPeriod);

   if(RegimeUseATRExpansion)
      requiredBars = (int)MathMax(requiredBars,
                                  EffectiveRegimeATRPeriod);

   if(Bars(symbol, RegimeTF) < requiredBars + 3)
   {
      return false;
   }

   if(!RegimePrepareIndicatorHandles(symbol))
      return false;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double regimeOpen = iOpen(symbol, RegimeTF, 1);
   double regimeHigh = iHigh(symbol, RegimeTF, 1);
   double regimeLow = iLow(symbol, RegimeTF, 1);
   double closePrice = iClose(symbol, RegimeTF, 1);
   double emaCurrent = 0;
   double emaPrevious = 0;
   double currentATR = 0;
   double averageATR = 0;
   double recentRange = 0;
   double previousRange = 0;
   double recentHigh = 0;
   double recentLow = 0;
   double previousHigh = 0;
   double previousLow = 0;

   if(currentPrice <= 0)
      currentPrice = iClose(symbol, RegimeTF, 0);

   if(regimeOpen <= 0 || regimeHigh <= 0 ||
      regimeLow <= 0 || closePrice <= 0 || point <= 0 ||
      !RegimeCalculateHalfRanges(symbol,
                                 recentRange,
                                 previousRange,
                                 recentHigh,
                                 recentLow,
                                 previousHigh,
                                 previousLow))
   {
      return false;
   }

   if(RegimeUseEMAFilter &&
      (!RegimeReadBufferValue(TRERegimeEMAHandle, 1, emaCurrent) ||
       !RegimeReadBufferValue(TRERegimeEMAHandle, 2, emaPrevious)))
   {
      return false;
   }

   if(!RegimeReadATRData(currentATR, averageATR))
      return false;

   bool higherHigh = (LastSwingHigh > 0 &&
                      PrevSwingHigh > 0 &&
                      LastSwingHigh > PrevSwingHigh);
   bool higherLow = (LastSwingLow > 0 &&
                     PrevSwingLow > 0 &&
                     LastSwingLow > PrevSwingLow);
   bool lowerHigh = (LastSwingHigh > 0 &&
                     PrevSwingHigh > 0 &&
                     LastSwingHigh < PrevSwingHigh);
   bool lowerLow = (LastSwingLow > 0 &&
                    PrevSwingLow > 0 &&
                    LastSwingLow < PrevSwingLow);
   bool bullishStructure = higherHigh && higherLow;
   bool bearishStructure = lowerHigh && lowerLow;
   bool noCleanStructure = !bullishStructure && !bearishStructure;
   bool structureAvailable =
      (LastSwingHigh > 0 && PrevSwingHigh > 0 &&
       LastSwingLow > 0 && PrevSwingLow > 0);

   double flatThreshold = 0;

   if(RegimeUseATRExpansion && currentATR > 0)
      flatThreshold = currentATR * 0.05;
   else
      flatThreshold = closePrice * 0.0005;

   double emaSlope = RegimeUseEMAFilter
                     ? emaCurrent - emaPrevious
                     : 0;
   bool priceAboveEMA = RegimeUseEMAFilter &&
                        closePrice > emaCurrent;
   bool priceBelowEMA = RegimeUseEMAFilter &&
                        closePrice < emaCurrent;
   bool emaSlopeUp = RegimeUseEMAFilter &&
                     emaSlope > flatThreshold;
   bool emaSlopeDown = RegimeUseEMAFilter &&
                       emaSlope < -flatThreshold;
   bool emaFlat = RegimeUseEMAFilter &&
                  MathAbs(emaSlope) <= flatThreshold;
   bool atrExpanding = RegimeUseATRExpansion &&
                       currentATR > averageATR * 1.05;
   bool atrNonExpanding = RegimeUseATRExpansion &&
                          currentATR <= averageATR * 1.05;
   double rangeRatio = (previousRange > 0)
                       ? recentRange / previousRange
                       : 0;
   bool stableRange = (rangeRatio >= 0.75 &&
                       rangeRatio <= 1.25);
   bool middleZone = (CurrentZone == 3 || CurrentZone == 4);
   double closeOne = iClose(symbol, RegimeTF, 1);
   double closeTwo = iClose(symbol, RegimeTF, 2);
   double closeThree = iClose(symbol, RegimeTF, 3);
   bool higherCloseSequence =
      (closeOne > closeTwo && closeTwo > closeThree);
   bool lowerCloseSequence =
      (closeOne < closeTwo && closeTwo < closeThree);
   bool rangeRespect =
      (closeOne >= previousLow && closeOne <= previousHigh &&
       closeTwo >= previousLow && closeTwo <= previousHigh &&
       closeThree >= previousLow && closeThree <= previousHigh);

   RegimeCountSwingStructure(symbol);
   RegimeCountEMACloses(symbol);

   if(!structureAvailable)
   {
      RegimeSetWaitingEvidence(RegimeUptrendEvidence[0],
                               "HH_HL_Structure", 0, 25,
                               "H4 swing structure is incomplete",
                               "Need current and previous H4 swings");
      RegimeSetWaitingEvidence(RegimeDowntrendEvidence[0],
                               "LH_LL_Structure", 0, 25,
                               "H4 swing structure is incomplete",
                               "Need current and previous H4 swings");
   }
   else
   {
      if(bullishStructure)
      {
         RegimeSetEvidence(RegimeUptrendEvidence[0],
                           "HH_HL_Structure", true, true, 25,
                           "Higher High and Higher Low confirmed",
                           "", "");
      }
      else if(higherHigh || higherLow)
      {
         RegimeSetWaitingEvidence(RegimeUptrendEvidence[0],
                                  "HH_HL_Structure", 12.5, 25,
                                  "Partial bullish swing structure",
                                  "Need both Higher High and Higher Low");
      }
      else
      {
         RegimeSetEvidence(RegimeUptrendEvidence[0],
                           "HH_HL_Structure", true, false, 25,
                           "", "Bullish swing structure not confirmed",
                           "Need Higher High and Higher Low");
      }

      if(bearishStructure)
      {
         RegimeSetEvidence(RegimeDowntrendEvidence[0],
                           "LH_LL_Structure", true, true, 25,
                           "Lower High and Lower Low confirmed",
                           "", "");
      }
      else if(lowerHigh || lowerLow)
      {
         RegimeSetWaitingEvidence(RegimeDowntrendEvidence[0],
                                  "LH_LL_Structure", 12.5, 25,
                                  "Partial bearish swing structure",
                                  "Need both Lower High and Lower Low");
      }
      else
      {
         RegimeSetEvidence(RegimeDowntrendEvidence[0],
                           "LH_LL_Structure", true, false, 25,
                           "", "Bearish swing structure not confirmed",
                           "Need Lower High and Lower Low");
      }
   }

   RegimeSetEvidence(RegimeUptrendEvidence[1],
                     "PriceAboveEMA", RegimeUseEMAFilter,
                     priceAboveEMA, 15,
                     "Regime close is above EMA",
                     "Regime close is not above EMA",
                     "Need close above EMA");
   RegimeSetEvidence(RegimeUptrendEvidence[2],
                     "EMASlopeUp", RegimeUseEMAFilter,
                     emaSlopeUp, 15,
                     "EMA slope is rising",
                     "EMA slope is not rising",
                     "Need positive EMA slope");
   RegimeSetEvidence(RegimeUptrendEvidence[3],
                     "BullishBias", true,
                     MarketBias == BIAS_BUY, 15,
                     "H4 bias is BUY ONLY",
                     "H4 bullish bias is not confirmed",
                     "Need H4 BUY ONLY bias");
   RegimeSetEvidence(RegimeUptrendEvidence[4],
                     "ATRTrendExpansion", RegimeUseATRExpansion,
                     atrExpanding, 15,
                     "ATR is expanding above its average",
                     "ATR is not expanding",
                     "Need ATR expansion");
   RegimeSetEvidence(RegimeUptrendEvidence[5],
                     "HigherCloseSequence", true,
                     higherCloseSequence, 15,
                     "Three completed closes are rising",
                     "Completed closes are not rising",
                     "Need three rising closes");

   RegimeSetEvidence(RegimeDowntrendEvidence[1],
                     "PriceBelowEMA", RegimeUseEMAFilter,
                     priceBelowEMA, 15,
                     "Regime close is below EMA",
                     "Regime close is not below EMA",
                     "Need close below EMA");
   RegimeSetEvidence(RegimeDowntrendEvidence[2],
                     "EMASlopeDown", RegimeUseEMAFilter,
                     emaSlopeDown, 15,
                     "EMA slope is falling",
                     "EMA slope is not falling",
                     "Need negative EMA slope");
   RegimeSetEvidence(RegimeDowntrendEvidence[3],
                     "BearishBias", true,
                     MarketBias == BIAS_SELL, 15,
                     "H4 bias is SELL ONLY",
                     "H4 bearish bias is not confirmed",
                     "Need H4 SELL ONLY bias");
   RegimeSetEvidence(RegimeDowntrendEvidence[4],
                     "ATRTrendExpansion", RegimeUseATRExpansion,
                     atrExpanding, 15,
                     "ATR is expanding above its average",
                     "ATR is not expanding",
                     "Need ATR expansion");
   RegimeSetEvidence(RegimeDowntrendEvidence[5],
                     "LowerCloseSequence", true,
                     lowerCloseSequence, 15,
                     "Three completed closes are falling",
                     "Completed closes are not falling",
                     "Need three falling closes");

   RegimeSetEvidence(RegimeSidewayEvidence[0],
                     "FlatEMA", RegimeUseEMAFilter,
                     emaFlat, 20,
                     "EMA slope is inside flat threshold",
                     "EMA slope is directional",
                     "Need a flat EMA");
   RegimeSetEvidence(RegimeSidewayEvidence[1],
                     "StableRange", true,
                     stableRange, 20,
                     "Recent and previous half-ranges are stable",
                     "Half-range size changed materially",
                     "Need range ratio between 0.75 and 1.25");
   RegimeSetEvidence(RegimeSidewayEvidence[2],
                     "NoCleanTrendStructure", true,
                     noCleanStructure, 20,
                     "No complete HH/HL or LH/LL structure",
                     "Clean directional structure exists",
                     "Need mixed or incomplete structure");
   RegimeSetEvidence(RegimeSidewayEvidence[3],
                     "MidZoneRotation", true,
                     middleZone, 15,
                     "Price is in Zone 3 or Zone 4",
                     "Price is outside the middle zones",
                     "Need price rotation in Zone 3 or 4");
   RegimeSetEvidence(RegimeSidewayEvidence[4],
                     "ATRNotExpanding", RegimeUseATRExpansion,
                     atrNonExpanding, 15,
                     "ATR is not expanding above average",
                     "ATR expansion indicates directional volatility",
                     "Need non-expanding ATR");
   RegimeSetEvidence(RegimeSidewayEvidence[5],
                     "RangeRespect", true,
                     rangeRespect, 10,
                     "Three closes remain inside previous half-range",
                     "A recent close escaped the previous half-range",
                     "Need closes to respect prior range");

   double upRaw = 0;
   double upMax = 0;
   double downRaw = 0;
   double downMax = 0;
   double sideRaw = 0;
   double sideMax = 0;

   for(int i = 0; i < TRE_REGIME_EVIDENCE_COUNT; i++)
   {
      if(RegimeUptrendEvidence[i].status != TRE_STATUS_NA)
      {
         upRaw += RegimeUptrendEvidence[i].score;
         upMax += RegimeUptrendEvidence[i].maxScore;
      }

      if(RegimeDowntrendEvidence[i].status != TRE_STATUS_NA)
      {
         downRaw += RegimeDowntrendEvidence[i].score;
         downMax += RegimeDowntrendEvidence[i].maxScore;
      }

      if(RegimeSidewayEvidence[i].status != TRE_STATUS_NA)
      {
         sideRaw += RegimeSidewayEvidence[i].score;
         sideMax += RegimeSidewayEvidence[i].maxScore;
      }
   }

   UptrendScore = RegimeNormalizeScore(upRaw, upMax);
   DowntrendScore = RegimeNormalizeScore(downRaw, downMax);
   SidewayScore = RegimeNormalizeScore(sideRaw, sideMax);

   if(RegimeUseEMAFilter)
   {
      RegimeEMAValueText = DoubleToString(emaCurrent, digits);
      RegimeEMAPreviousValueText = DoubleToString(emaPrevious, digits);
      RegimeEMASlopeText = DoubleToString(emaSlope, digits);
      RegimeEMASlopePointsText = DoubleToString(emaSlope / point, 1);
   }

   if(RegimeUseATRExpansion)
   {
      RegimeATRValueText = DoubleToString(currentATR, digits);
      RegimeATRPointsText = DoubleToString(currentATR / point, 1);
      RegimeATRAveragePointsText =
         DoubleToString(averageATR / point, 1);
      RegimeATRExpansionText = atrExpanding ? "EXPANDING"
                                            : "NON-EXPANDING";
   }

   RegimeCurrentPriceText = DoubleToString(currentPrice, digits);
   RegimeOpenText = DoubleToString(regimeOpen, digits);
   RegimeHighText = DoubleToString(regimeHigh, digits);
   RegimeLowText = DoubleToString(regimeLow, digits);
   RegimeCloseText = DoubleToString(closePrice, digits);
   double lookbackHigh = MathMax(recentHigh, previousHigh);
   double lookbackLow = MathMin(recentLow, previousLow);
   RegimeLookbackHighText = DoubleToString(lookbackHigh, digits);
   RegimeLookbackLowText = DoubleToString(lookbackLow, digits);
   RegimeLookbackRangePointsText =
      DoubleToString((lookbackHigh - lookbackLow) / point, 1);
   RegimeH4BiasText = BiasToText(MarketBias);
   RegimeMidZoneTouchCountText = middleZone ? "1" : "0";
   RegimeUptrendReasonText =
      "PASS evidence " + DoubleToString(upRaw, 1) +
      " / " + DoubleToString(upMax, 1);
   RegimeDowntrendReasonText =
      "PASS evidence " + DoubleToString(downRaw, 1) +
      " / " + DoubleToString(downMax, 1);
   RegimeSidewayReasonText =
      "PASS evidence " + DoubleToString(sideRaw, 1) +
      " / " + DoubleToString(sideMax, 1);

   RegimeWinningScore = (int)MathMax(
      UptrendScore,
      MathMax(DowntrendScore, SidewayScore));
   RegimeConfidence = RegimeWinningScore;
   int highestCount = 0;

   if(UptrendScore == RegimeWinningScore)
      highestCount++;

   if(DowntrendScore == RegimeWinningScore)
      highestCount++;

   if(SidewayScore == RegimeWinningScore)
      highestCount++;

   int secondScore = 0;

   if(UptrendScore < RegimeWinningScore)
      secondScore = MathMax(secondScore, UptrendScore);

   if(DowntrendScore < RegimeWinningScore)
      secondScore = MathMax(secondScore, DowntrendScore);

   if(SidewayScore < RegimeWinningScore)
      secondScore = MathMax(secondScore, SidewayScore);

   RegimeScoreGap = (highestCount == 1)
                    ? RegimeWinningScore - secondScore
                    : 0;
   RegimeThresholdResultText =
      (RegimeWinningScore >= EffectiveRegimeSwitchThreshold)
      ? "PASS"
      : "FAIL";

   if(highestCount != 1)
   {
      RegimeBestCandidateText = "MIXED";
      RegimeRawDetectedText = "UNKNOWN";
   }
   else if(UptrendScore == RegimeWinningScore)
   {
      RegimeBestCandidateText = "UPTREND";
      RegimeRawDetectedText = "UPTREND";
   }
   else if(DowntrendScore == RegimeWinningScore)
   {
      RegimeBestCandidateText = "DOWNTREND";
      RegimeRawDetectedText = "DOWNTREND";
   }
   else
   {
      RegimeBestCandidateText = "SIDEWAY";
      RegimeRawDetectedText = "SIDEWAY";
   }

   if(RegimeWinningScore < EffectiveRegimeSwitchThreshold)
      RegimeConfidenceCommentText = "WEAK";
   else if(highestCount != 1 || RegimeScoreGap < 15)
      RegimeConfidenceCommentText = "MIXED";
   else
      RegimeConfidenceCommentText = "STRONG";

   if(highestCount != 1 ||
      RegimeWinningScore < EffectiveRegimeSwitchThreshold)
   {
      DetectedRegime = TRE_PROFILE_UNKNOWN;
   }
   else if(UptrendScore == RegimeWinningScore)
   {
      DetectedRegime = TRE_PROFILE_UPTREND;
   }
   else if(DowntrendScore == RegimeWinningScore)
   {
      DetectedRegime = TRE_PROFILE_DOWNTREND;
   }
   else
   {
      DetectedRegime = TRE_PROFILE_SIDEWAY;
   }

   DetectedRegimeText = TRE_MarketProfileToText(DetectedRegime);
   RegimeCandidateConfidence = RegimeWinningScore;
   RegimeConfidenceText = IntegerToString(RegimeConfidence) +
                          " / 100";
   return true;
}

void RegimeUpdateConfirmation(bool newRegimeBar)
{
   if(!newRegimeBar)
      return;

   if(RegimeActiveHoldCount < 1000000)
      RegimeActiveHoldCount++;

   if(DetectedRegime == TRE_PROFILE_UNKNOWN)
   {
      RegimeConfirmationCandidate = TRE_PROFILE_UNKNOWN;
      RegimeConfirmationCount = 0;
      return;
   }

   if(DetectedRegime != RegimeConfirmationCandidate)
   {
      RegimeConfirmationCandidate = DetectedRegime;
      RegimeConfirmationCount = 1;
      return;
   }

   if(RegimeConfirmationCount < EffectiveRegimeConfirmBars)
      RegimeConfirmationCount++;
}

void RegimeApplyProfileSwitch(bool dataReady, bool newRegimeBar)
{
   RegimeActiveBeforeSwitchText =
      TRE_MarketProfileToText(ActiveRegime);
   RegimeActiveAfterSwitchText = RegimeActiveBeforeSwitchText;
   RegimeCandidateText =
      TRE_MarketProfileToText(RegimeConfirmationCandidate);
   RegimeSwitchAllowedText = "NO";
   RegimeSwitchDecisionReasonText = "Not evaluated";

   if(!UseAutoRegimeDetection)
   {
      RegimeResearchModeText = "MANUAL PROFILE MODE";
      MarketDetectionStatusText = "OFF";
      AutoProfileSwitchStatusText = "OFF";
      RegimeProfileSourceText = "MANUAL";
      DetectedRegime = TRE_PROFILE_UNKNOWN;
      DetectedRegimeText = "UNKNOWN";
      ActiveRegime = ManualMarketProfile;
      ActiveRegimeText = TRE_MarketProfileToText(ActiveRegime);
      RegimeSwitchStatusText = "MANUAL";
      RegimeBlockingReasonText = "AUTO_DETECTION_OFF";
      RegimeSwitchDecisionReasonText =
         "Manual profile remains active";
      RegimeActiveAfterSwitchText = ActiveRegimeText;
      MarketRegimeText = ActiveRegimeText;
      return;
   }

   RegimeUpdateConfirmation(newRegimeBar);
   RegimeCandidateText =
      TRE_MarketProfileToText(RegimeConfirmationCandidate);
   MarketDetectionStatusText = "ACTIVE";

   if(!AllowAutoProfileSwitch)
   {
      RegimeResearchModeText = "AUTO DETECTION SHADOW MODE";
      AutoProfileSwitchStatusText = "OFF";
      RegimeProfileSourceText = "MANUAL";
      ActiveRegime = ManualMarketProfile;
      ActiveRegimeText = TRE_MarketProfileToText(ActiveRegime);
      RegimeSwitchStatusText = "DETECTED_ONLY";
      RegimeBlockingReasonText = "AUTO_PROFILE_SWITCH_OFF";
      RegimeSwitchDecisionReasonText =
         "Shadow mode observes and logs; manual profile remains active";
      RegimeActiveAfterSwitchText = ActiveRegimeText;
      MarketRegimeText = ActiveRegimeText;
      return;
   }

   RegimeResearchModeText = "AUTO PROFILE SWITCH MODE";
   AutoProfileSwitchStatusText = "ON";
   RegimeProfileSourceText = "AUTO";

   if(!dataReady || DetectedRegime == TRE_PROFILE_UNKNOWN)
   {
      RegimeSwitchStatusText = "BLOCKED";
      if(!dataReady)
         RegimeBlockingReasonText = "UNKNOWN";
      else if(RegimeWinningScore < EffectiveRegimeSwitchThreshold)
         RegimeBlockingReasonText = "BELOW_THRESHOLD";
      else if(RegimeBestCandidateText == "MIXED")
         RegimeBlockingReasonText = "MIXED_SCORE";
      else
         RegimeBlockingReasonText = "UNKNOWN";

      RegimeSwitchDecisionReasonText =
         "Switch blocked: " + RegimeBlockingReasonText;
   }
   else if(RegimeConfidence < EffectiveRegimeSwitchThreshold)
   {
      RegimeSwitchStatusText = "BLOCKED";
      RegimeBlockingReasonText = "BELOW_THRESHOLD";
      RegimeSwitchDecisionReasonText =
         "Candidate confidence is below switch threshold";
   }
   else if(RegimeConfirmationCount < EffectiveRegimeConfirmBars)
   {
      RegimeSwitchStatusText = "WAIT";
      RegimeBlockingReasonText = "WAIT_CONFIRMATION";
      RegimeSwitchDecisionReasonText =
         "Waiting for consecutive confirmation bars";
   }
   else if(DetectedRegime == ActiveRegime)
   {
      RegimeSwitchStatusText = "ACTIVE";
      RegimeBlockingReasonText = "N/A";
      RegimeSwitchAllowedText = "YES";
      RegimeSwitchDecisionReasonText =
         "Detected regime already matches active regime";
   }
   else if(RegimeActiveHoldCount < EffectiveRegimeHoldBars)
   {
      RegimeSwitchStatusText = "WAIT";
      RegimeBlockingReasonText = "HOLD_BARS_NOT_REACHED";
      RegimeSwitchDecisionReasonText =
         "Active profile has not completed its hold period";
   }
   else
   {
      RegimeSwitchAllowedText = "YES";
      ActiveRegime = DetectedRegime;
      ActiveRegimeText = TRE_MarketProfileToText(ActiveRegime);
      RegimeActiveHoldCount = 0;
      RegimeSwitchStatusText = "SWITCHED";
      RegimeBlockingReasonText = "N/A";
      RegimeSwitchDecisionReasonText =
         "Threshold, confirmation, and hold rules passed";
      Print("TRE Regime Switch: ActiveRegime=", ActiveRegimeText,
            " confidence=", RegimeConfidence,
            " confirmation=", RegimeConfirmationCount);
   }

   ActiveRegimeText = TRE_MarketProfileToText(ActiveRegime);
   RegimeActiveAfterSwitchText = ActiveRegimeText;
   MarketRegimeText = ActiveRegimeText;
}

void RegimeEngine(string symbol)
{
   datetime currentRegimeBar = iTime(symbol, RegimeTF, 0);
   bool newRegimeBar = (currentRegimeBar > 0 &&
                        currentRegimeBar != RegimeLastEvaluatedBarTime);

   bool dataReady = (RegimeCurrentPriceText != "N/A");

   if(UseAutoRegimeDetection)
   {
      if(newRegimeBar)
      {
         RegimePreviousDetectedText = DetectedRegimeText;
         dataReady = RegimeCalculateScores(symbol);
         RegimeLastEvaluatedBarTime = currentRegimeBar;
      }
   }
   else
   {
      RegimeResetOutput();
      dataReady = false;

      if(newRegimeBar)
         RegimeLastEvaluatedBarTime = currentRegimeBar;
   }

   RegimeApplyProfileSwitch(dataReady, newRegimeBar);
}

#endif
