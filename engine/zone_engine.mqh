//+------------------------------------------------------------------+
//| engine/zone_engine.mqh                                           |
//| Calculate H1 range zones                                         |
//+------------------------------------------------------------------+
#ifndef TRE_ZONE_ENGINE_MQH
#define TRE_ZONE_ENGINE_MQH

int TREZoneATRHandle = INVALID_HANDLE;
string TREZoneATRSymbol = "";
ENUM_TIMEFRAMES TREZoneATRTimeframe = PERIOD_CURRENT;
int TREZoneATRPeriod = 0;

void ZoneReleaseATRHandle()
{
   if(TREZoneATRHandle != INVALID_HANDLE)
      IndicatorRelease(TREZoneATRHandle);

   TREZoneATRHandle = INVALID_HANDLE;
   TREZoneATRSymbol = "";
   TREZoneATRTimeframe = PERIOD_CURRENT;
   TREZoneATRPeriod = 0;
}

void ZonePrepareConfigDisplay()
{
   ZoneUseSwingValidationText = UseSwingValidation ? "ON" : "OFF";
   ZoneUseATRValidationText = UseATRValidation ? "ON" : "OFF";
   ZoneCountText = IntegerToString(TRE_ZONE_COUNT);
   ZoneMinimumRangeText = DoubleToString(MinimumSwingRangePoints, 1);

   if(UseATRValidation)
   {
      ZoneATRTimeframeText = TimeframeToText(ATRTimeframe);
      ZoneATRPeriodText = IntegerToString(ATRPeriod);
      ZoneMinATRMultiplierText = DoubleToString(MinATRMultiplier, 1);
      ZoneMaxATRMultiplierText = DoubleToString(MaxATRMultiplier, 1);
   }
   else
   {
      ZoneATRTimeframeText = "N/A";
      ZoneATRPeriodText = "N/A";
      ZoneMinATRMultiplierText = "N/A";
      ZoneMaxATRMultiplierText = "N/A";
   }
}

void ZonePrepareRawSwingDisplay(double swingHigh,
                                double swingLow,
                                double point,
                                int digits)
{
   ZoneRawSwingHighText = DoubleToString(swingHigh, digits);
   ZoneRawSwingLowText = DoubleToString(swingLow, digits);
   ZoneSwingRangePriceText = "N/A";
   ZoneSwingRangePointsText = "N/A";
   ZoneSwingRangeText = "N/A";

   if(swingHigh <= 0 || swingLow <= 0 || swingHigh <= swingLow || point <= 0)
      return;

   double rangePrice = swingHigh - swingLow;
   double rangePoints = rangePrice / point;
   ZoneSwingRangePriceText = DoubleToString(rangePrice, digits);
   ZoneSwingRangePointsText = DoubleToString(rangePoints, 1);
   ZoneSwingRangeText = ZoneSwingRangePointsText;
}

bool ZoneReadATR(string symbol, double point, int digits)
{
   ZoneATRValue = 0;
   ZoneATRPoints = 0;
   ZoneMinATRRangePoints = 0;
   ZoneMaxATRRangePoints = 0;
   ZoneATRValidationText = UseATRValidation ? "NOT CHECKED" : "DISABLED";
   ZoneATRValuePriceText = "N/A";
   ZoneATRPointsText = "N/A";
   ZoneMinATRRangePointsText = "N/A";
   ZoneMaxATRRangePointsText = "N/A";

   if(!UseATRValidation)
      return true;

   if(ATRPeriod < 1 ||
      MinATRMultiplier <= 0 ||
      MaxATRMultiplier < MinATRMultiplier ||
      point <= 0)
   {
      ZoneATRValidationText = "INVALID CONFIG";
      return false;
   }

   if(TREZoneATRHandle == INVALID_HANDLE ||
      TREZoneATRSymbol != symbol ||
      TREZoneATRTimeframe != ATRTimeframe ||
      TREZoneATRPeriod != ATRPeriod)
   {
      ZoneReleaseATRHandle();
      TREZoneATRHandle = iATR(symbol, ATRTimeframe, ATRPeriod);
      TREZoneATRSymbol = symbol;
      TREZoneATRTimeframe = ATRTimeframe;
      TREZoneATRPeriod = ATRPeriod;
   }

   if(TREZoneATRHandle == INVALID_HANDLE)
   {
      ZoneATRValidationText = "UNAVAILABLE";
      return false;
   }

   double atrBuffer[1];

   // Shift 1 reads the latest completed candle and avoids forming-bar noise.
   if(CopyBuffer(TREZoneATRHandle, 0, 1, 1, atrBuffer) != 1 ||
      atrBuffer[0] <= 0)
   {
      ZoneATRValidationText = "UNAVAILABLE";
      return false;
   }

   ZoneATRValue = atrBuffer[0];
   ZoneATRPoints = ZoneATRValue / point;
   ZoneMinATRRangePoints = ZoneATRPoints * MinATRMultiplier;
   ZoneMaxATRRangePoints = ZoneATRPoints * MaxATRMultiplier;
   ZoneATRValuePriceText = DoubleToString(ZoneATRValue, digits);
   ZoneATRPointsText = DoubleToString(ZoneATRPoints, 1);
   ZoneMinATRRangePointsText = DoubleToString(ZoneMinATRRangePoints, 1);
   ZoneMaxATRRangePointsText = DoubleToString(ZoneMaxATRRangePoints, 1);
   return true;
}

bool ZoneIsSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int shift, int depth)
{
   double center = iHigh(symbol, tf, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= depth; i++)
   {
      if(center <= iHigh(symbol, tf, shift - i)) return false;
      if(center <= iHigh(symbol, tf, shift + i)) return false;
   }

   return true;
}

bool ZoneIsSwingLow(string symbol, ENUM_TIMEFRAMES tf, int shift, int depth)
{
   double center = iLow(symbol, tf, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= depth; i++)
   {
      if(center >= iLow(symbol, tf, shift - i)) return false;
      if(center >= iLow(symbol, tf, shift + i)) return false;
   }

   return true;
}

bool CalculateSwingRange(string symbol, double &rangeHigh, double &rangeLow)
{
   EffectiveZoneLookbackBars = TRE_ValidatedLookbackBars(ZoneLookbackBars);

   double swingHigh = 0;
   double swingLow = 0;

   // Swing-based zones are preferred because they follow recent market
   // structure instead of only using an extreme inside a fixed lookback window.
   for(int shift = SwingDepth + 1; shift < EffectiveZoneLookbackBars; shift++)
   {
      if(swingHigh == 0 && ZoneIsSwingHigh(symbol, ZoneTF, shift, SwingDepth))
         swingHigh = iHigh(symbol, ZoneTF, shift);

      if(swingLow == 0 && ZoneIsSwingLow(symbol, ZoneTF, shift, SwingDepth))
         swingLow = iLow(symbol, ZoneTF, shift);

      if(swingHigh > 0 && swingLow > 0)
         break;
   }

   rangeHigh = swingHigh;
   rangeLow = swingLow;
   return (swingHigh > 0 && swingLow > 0 && swingHigh > swingLow);
}

bool ValidateSwingRange(double rangeHigh, double rangeLow, double point)
{
   if(!UseATRValidation)
      ZoneATRValidationText = "DISABLED";

   if(rangeHigh <= 0 || rangeLow <= 0 || rangeHigh <= rangeLow)
   {
      ZoneBasicPriceValidationText = "INVALID";
      ZoneSwingValidationText = "INVALID";
      ZoneValidationReasonText = "Bad swing price";
      ZoneFallbackReasonText = ZoneValidationReasonText;
      return false;
   }

   ZoneBasicPriceValidationText = "VALID";

   if(point <= 0)
   {
      ZoneSwingValidationText = "INVALID";
      ZoneValidationReasonText = "Symbol point unavailable";
      ZoneFallbackReasonText = ZoneValidationReasonText;
      return false;
   }

   double swingRangePoints = (rangeHigh - rangeLow) / point;

   if(!UseSwingValidation)
   {
      ZoneSwingValidationText = "DISABLED";
   }
   else if(swingRangePoints < MinimumSwingRangePoints)
   {
      ZoneSwingValidationText = "INVALID";
      ZoneValidationReasonText = "Swing range is below fixed minimum range";
      ZoneFallbackReasonText = ZoneValidationReasonText;
      return false;
   }

   if(UseATRValidation && ZoneATRValidationText == "INVALID CONFIG")
   {
      ZoneSwingValidationText = "INVALID";
      ZoneValidationReasonText = "ATR configuration is invalid";
      ZoneFallbackReasonText = ZoneValidationReasonText;
      return false;
   }

   if(UseATRValidation && ZoneATRPoints > 0)
   {
      if(swingRangePoints < ZoneMinATRRangePoints)
      {
         ZoneSwingValidationText = "INVALID";
         ZoneATRValidationText = "INVALID";
         ZoneValidationReasonText = "Swing range is below ATR minimum range";
         ZoneFallbackReasonText = ZoneValidationReasonText;
         return false;
      }

      if(swingRangePoints > ZoneMaxATRRangePoints)
      {
         ZoneSwingValidationText = "INVALID";
         ZoneATRValidationText = "INVALID";
         ZoneValidationReasonText = "Swing range is above ATR maximum range";
         ZoneFallbackReasonText = ZoneValidationReasonText;
         return false;
      }

      ZoneATRValidationText = "VALID";
      ZoneValidationReasonText = "Swing range is within ATR threshold";
   }
   else if(UseATRValidation)
   {
      if(ZoneATRValidationText == "NOT CHECKED")
         ZoneATRValidationText = "UNAVAILABLE";

      ZoneValidationReasonText = "Swing range is valid; ATR data unavailable";
   }
   else if(!UseATRValidation)
   {
      ZoneValidationReasonText = UseSwingValidation
                                 ? "Swing range is valid; ATR validation disabled"
                                 : "ATR validation disabled";
   }

   ZoneSwingValidationText = UseSwingValidation ? "VALID" : "DISABLED";
   return true;
}

bool CalculateFallbackRange(string symbol, double &rangeHigh, double &rangeLow)
{
   EffectiveZoneLookbackBars = TRE_ValidatedLookbackBars(ZoneLookbackBars);
   ZoneFallbackLookbackUsed = EffectiveZoneLookbackBars;

   int highIndex = iHighest(symbol, ZoneTF, MODE_HIGH, EffectiveZoneLookbackBars, 1);
   int lowIndex  = iLowest(symbol, ZoneTF, MODE_LOW, EffectiveZoneLookbackBars, 1);

   if(highIndex < 0 || lowIndex < 0)
      return false;

   rangeHigh = iHigh(symbol, ZoneTF, highIndex);
   rangeLow  = iLow(symbol, ZoneTF, lowIndex);

   return (rangeHigh > rangeLow && rangeLow > 0);
}

string ZoneStrengthByZone(int zone)
{
   if(zone == 6) return "Strong Sell Area";
   if(zone == 5) return "Sell Area";
   if(zone == 4) return "Upper Magnet Area";
   if(zone == 3) return "Lower Magnet Area";
   if(zone == 2) return "Buy Area";
   if(zone == 1) return "Strong Buy Area";

   return "WAIT";
}

string ZoneNameByZone(int zone)
{
   if(zone == 6) return "Strong Sell";
   if(zone == 5) return "Weak Sell";
   if(zone == 4 || zone == 3) return "Neutral";
   if(zone == 2) return "Weak Buy";
   if(zone == 1) return "Strong Buy";
   return "N/A";
}

string ZonePremiumDiscountByZone(int zone)
{
   if(zone >= 5) return "Premium";
   if(zone <= 2 && zone > 0) return "Discount";
   if(zone == 3 || zone == 4) return "Equilibrium";
   return "N/A";
}

void ZonePrepareOutputDisplay(int digits)
{
   ZoneNameText = ZoneNameByZone(CurrentZone);
   ZonePremiumDiscountText = ZonePremiumDiscountByZone(CurrentZone);
   ZoneWidthPriceText = (ZoneSize > 0)
                        ? DoubleToString(ZoneSize, digits)
                        : "N/A";
   ZoneQualityText = (CurrentZone > 0) ? "Fresh" : "N/A";
   ZoneRetestText = "N/A";
   ZoneBrokenText = "N/A";
}

int ZoneScoreByZone(int zone)
{
   if(zone == 6) return 30;
   if(zone == 5) return 20;
   if(zone == 4) return 10;
   if(zone == 3) return 10;
   if(zone == 2) return 20;
   if(zone == 1) return 30;

   return 0;
}

string ZoneReasonByZone(int zone)
{
   if(zone == 6) return "Price inside Strong Sell Area";
   if(zone == 5) return "Price inside Sell Area";
   if(zone == 4) return "Price inside Magnet Zone";
   if(zone == 3) return "Price inside Magnet Zone";
   if(zone == 2) return "Price inside Buy Area";
   if(zone == 1) return "Price inside Strong Buy Area";

   return "Zone not available";
}

void ZoneEngine(string symbol)
{
   EffectiveZoneLookbackBars = TRE_ValidatedLookbackBars(ZoneLookbackBars);
   ZoneFallbackLookbackUsed = EffectiveZoneLookbackBars;

   double rangeHigh = 0;
   double rangeLow = 0;
   double swingHigh = 0;
   double swingLow = 0;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);

   ZoneReason = "Zone not available";
   ZoneScore = 0;
   ZoneBasicPriceValidationText = "UNKNOWN";
   ZoneValidationReasonText = "Not evaluated";
   ZoneSwingValidationText = "UNKNOWN";
   ZoneFallbackUsedText = "NO";
   ZoneFallbackReasonText = "N/A";
   ZoneFallbackSourceText = "N/A";
   ZoneFallbackLookbackText = "N/A";
   ZoneSwingRangeText = "N/A";
   ZoneATRValidationText = UseATRValidation ? "NOT CHECKED" : "DISABLED";
   ZoneCurrentPriceText = (price > 0) ? DoubleToString(price, digits) : "N/A";
   CurrentZone = 0;
   ZoneSize = 0;

   ZonePrepareConfigDisplay();
   ZoneReadATR(symbol, point, digits);

   bool swingRangeFound = CalculateSwingRange(symbol, swingHigh, swingLow);
   ZonePrepareRawSwingDisplay(swingHigh, swingLow, point, digits);
   bool swingRangeValid = ValidateSwingRange(swingHigh, swingLow, point);

   if(swingRangeFound && swingRangeValid)
   {
      rangeHigh = swingHigh;
      rangeLow = swingLow;
      ZoneSourceMode = ZONE_SOURCE_SWING;
      ZoneSourceText = TimeframeToText(ZoneTF) + " Swing Range";
   }
   else if(CalculateFallbackRange(symbol, rangeHigh, rangeLow))
   {
      ZoneSourceMode = ZONE_SOURCE_FALLBACK;
      ZoneSourceText = "Lookback Range";
      ZoneFallbackUsedText = "YES";
      ZoneFallbackSourceText = "Lookback Range";
      ZoneFallbackLookbackText = IntegerToString(ZoneFallbackLookbackUsed);
   }
   else
   {
      RangeHigh = 0;
      RangeLow = 0;
      ZoneSize = 0;
      CurrentZone = 0;
      ZoneStrengthText = "WAIT";
      ZoneReason = "No valid zone range";
      ZoneScore = 0;
      ZoneSourceMode = ZONE_SOURCE_FALLBACK;
      ZoneSourceText = "N/A";
      ZoneFallbackUsedText = "NO";
      ZoneFallbackReasonText = "No valid zone range";
      ZoneFallbackSourceText = "N/A";
      ZoneFallbackLookbackText = "N/A";
      ZonePrepareOutputDisplay(digits);
      return;
   }

   RangeHigh = rangeHigh;
   RangeLow  = rangeLow;

   if(RangeHigh <= RangeLow)
   {
      ZoneSize = 0;
      CurrentZone = 0;
      ZoneStrengthText = "WAIT";
      ZoneReason = "No valid zone range";
      ZoneScore = 0;
      ZoneSourceText = "N/A";
      ZoneFallbackReasonText = "No valid zone range";
      ZonePrepareOutputDisplay(digits);
      return;
   }

   ZoneSize = (RangeHigh - RangeLow) / TRE_ZONE_COUNT;

   if(price <= RangeLow)
   {
      CurrentZone = 1;
      ZoneStrengthText = ZoneStrengthByZone(CurrentZone);
      ZoneReason = ZoneReasonByZone(CurrentZone);
      ZoneScore = ZoneScoreByZone(CurrentZone);
      ZonePrepareOutputDisplay(digits);
      return;
   }

   if(price >= RangeHigh)
   {
      CurrentZone = TRE_ZONE_COUNT;
      ZoneStrengthText = ZoneStrengthByZone(CurrentZone);
      ZoneReason = ZoneReasonByZone(CurrentZone);
      ZoneScore = ZoneScoreByZone(CurrentZone);
      ZonePrepareOutputDisplay(digits);
      return;
   }

   double position = (price - RangeLow) / ZoneSize;
   CurrentZone = (int)MathFloor(position) + 1;

   if(CurrentZone < 1) CurrentZone = 1;
   if(CurrentZone > TRE_ZONE_COUNT) CurrentZone = TRE_ZONE_COUNT;

   ZoneStrengthText = ZoneStrengthByZone(CurrentZone);
   ZoneReason = ZoneReasonByZone(CurrentZone);
   ZoneScore = ZoneScoreByZone(CurrentZone);
   ZonePrepareOutputDisplay(digits);
}

#endif
