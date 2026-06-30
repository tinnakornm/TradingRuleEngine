//+------------------------------------------------------------------+
//| include/common.mqh                                               |
//| Common helper functions                                          |
//+------------------------------------------------------------------+
#ifndef TRE_COMMON_MQH
#define TRE_COMMON_MQH

string GetTradeSymbol()
{
   if(InpSymbol == "")
      return _Symbol;

   return InpSymbol;
}

int TRE_ValidatedLookbackBars(int configuredBars)
{
   return (configuredBars < 3) ? 3 : configuredBars;
}

void TRE_InitializeResearchConfig()
{
   EffectiveBiasLookbackBars = TRE_ValidatedLookbackBars(BiasLookbackBars);
   EffectiveZoneLookbackBars = TRE_ValidatedLookbackBars(ZoneLookbackBars);
   ZoneFallbackLookbackUsed = EffectiveZoneLookbackBars;
   EffectiveBacktestMaxHoldingBars =
      (int)MathMax(1, BacktestMaxHoldingBars);
   EffectiveRegimeLookbackBars = (int)MathMax(6, RegimeLookbackBars);
   EffectiveRegimeConfirmBars = (int)MathMax(1, RegimeConfirmBars);
   EffectiveRegimeSwitchThreshold =
      (int)MathMax(0, MathMin(100, RegimeSwitchThreshold));
   EffectiveRegimeHoldBars = (int)MathMax(0, RegimeHoldBars);
   EffectiveRegimeEMAPeriod = (int)MathMax(2, RegimeEMAPeriod);
   EffectiveRegimeATRPeriod = (int)MathMax(2, RegimeATRPeriod);
   EffectivePressureLookbackBars =
      (int)MathMax(3, PressureLookbackBars);
   EffectivePressureMediumThreshold =
      (int)MathMax(0, MathMin(100, PressureMediumThreshold));
   EffectivePressureHighThreshold =
      (int)MathMax(EffectivePressureMediumThreshold,
                   MathMin(100, PressureHighThreshold));
   EffectivePressureMediumPenalty =
      (int)MathMax(0, MathMin(100, PressureMediumPenalty));
   EffectivePressureHighPenalty =
      (int)MathMax(0, MathMin(100, PressureHighPenalty));
   EffectivePressureEMAPeriod =
      (int)MathMax(2, PressureEMAPeriod);
   EffectivePressureTF =
      (PressureTF == PERIOD_CURRENT) ? EntryTF : PressureTF;
   ActiveRegime = ManualMarketProfile;
   ActiveRegimeText = TRE_MarketProfileToText(ActiveRegime);
   RegimeActiveHoldCount = EffectiveRegimeHoldBars;
   RegimeDetectionWarningActive = !UseAutoRegimeDetection;

   if(TRE_DEFAULT_USE_AUTO_REGIME_DETECTION &&
      !UseAutoRegimeDetection)
   {
      RegimeInputSourceText = "EA Properties (Saved Instance)";
   }
   else if(AllowAutoProfileSwitch ||
           ManualMarketProfile != TRE_PROFILE_UNKNOWN ||
           RegimeTF != PERIOD_H1 ||
           RegimeLookbackBars != 20 ||
           RegimeConfirmBars != 3 ||
           RegimeSwitchThreshold != 70 ||
           RegimeHoldBars != 6)
   {
      RegimeInputSourceText = "Runtime Inputs";
   }
   else
   {
      RegimeInputSourceText = "Source Code Default";
   }

   Print("TRE Research Config: BiasLookbackBars=", BiasLookbackBars,
         " ZoneLookbackBars=", ZoneLookbackBars,
         " BacktestMaxHoldingBars=", BacktestMaxHoldingBars,
         " RegimeLookbackBars=", RegimeLookbackBars);

   if(BiasLookbackBars < 3)
      Print("TRE Config Warning: BiasLookbackBars too small, forced to 3");

   if(ZoneLookbackBars < 3)
      Print("TRE Config Warning: ZoneLookbackBars too small, forced to 3");

   if(BacktestMaxHoldingBars < 1)
      Print("TRE Config Warning: BacktestMaxHoldingBars too small, forced to 1");

   if(RegimeLookbackBars < 6)
      Print("TRE Config Warning: RegimeLookbackBars too small, forced to 6");

   if(RegimeConfirmBars < 1)
      Print("TRE Config Warning: RegimeConfirmBars too small, forced to 1");

   if(RegimeSwitchThreshold < 0 || RegimeSwitchThreshold > 100)
      Print("TRE Config Warning: RegimeSwitchThreshold forced into 0-100");

   if(RegimeHoldBars < 0)
      Print("TRE Config Warning: RegimeHoldBars too small, forced to 0");

   if(PressureLookbackBars < 3)
      Print("TRE Config Warning: PressureLookbackBars too small, forced to 3");

   if(PressureMediumThreshold < 0 ||
      PressureMediumThreshold > 100)
   {
      Print("TRE Config Warning: PressureMediumThreshold forced into 0-100");
   }

   if(PressureHighThreshold < EffectivePressureMediumThreshold ||
      PressureHighThreshold > 100)
   {
      Print("TRE Config Warning: PressureHighThreshold forced above medium and into 0-100");
   }

   if(PressureMediumPenalty < 0 || PressureMediumPenalty > 100)
      Print("TRE Config Warning: PressureMediumPenalty forced into 0-100");

   if(PressureHighPenalty < 0 || PressureHighPenalty > 100)
      Print("TRE Config Warning: PressureHighPenalty forced into 0-100");

   if(PressureEMAPeriod < 2)
      Print("TRE Config Warning: PressureEMAPeriod too small, forced to 2");
}

string TimeframeToText(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
   }

   return "TF";
}

string TRE_MarketProfileToText(ENUM_TRE_MARKET_PROFILE profile)
{
   if(profile == TRE_PROFILE_UPTREND) return "UPTREND";
   if(profile == TRE_PROFILE_SIDEWAY) return "SIDEWAY";
   if(profile == TRE_PROFILE_DOWNTREND) return "DOWNTREND";
   return "UNKNOWN";
}

string BiasToText(MARKET_BIAS bias)
{
   if(bias == BIAS_SELL) return "SELL ONLY";
   if(bias == BIAS_BUY)  return "BUY ONLY";
   return "WAIT";
}

string ActionToText(ENTRY_ACTION action)
{
   if(action == ACTION_SELL_READY) return "SELL READY";
   if(action == ACTION_BUY_READY)  return "BUY READY";
   if(action == ACTION_WATCH)      return "WATCH";
   if(action == ACTION_NO_TRADE)   return "NO TRADE";
   return "WAIT";
}

color BiasColor(MARKET_BIAS bias)
{
   if(bias == BIAS_SELL) return clrRed;
   if(bias == BIAS_BUY)  return clrGreen;
   return clrOrange;
}

color ActionColor(ENTRY_ACTION action)
{
   if(action == ACTION_SELL_READY) return clrRed;
   if(action == ACTION_BUY_READY)  return clrGreen;
   if(action == ACTION_WATCH)      return clrDodgerBlue;
   if(action == ACTION_NO_TRADE)   return clrGray;
   return clrOrange;
}

void ClearTREObjects()
{
   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, "TRE_") == 0 ||
         StringFind(name, "DASH") >= 0 ||
         StringFind(name, "ZONE") >= 0 ||
         StringFind(name, "SWING") >= 0)
      {
         ObjectDelete(0, name);
      }
   }
}

#endif
