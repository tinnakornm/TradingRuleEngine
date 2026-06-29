//+------------------------------------------------------------------+
//| engine/momentum_engine.mqh                                       |
//| Simple candle momentum without indicators                        |
//+------------------------------------------------------------------+
#ifndef TRE_MOMENTUM_ENGINE_MQH
#define TRE_MOMENTUM_ENGINE_MQH

void MomentumEngine(string symbol)
{
   MomentumReason = "Unknown";
   MomentumCandleText = "Unknown";
   MomentumStrengthText = "Unknown";
   MomentumBodyPercent = 0;
   MomentumUpperWickPercent = 0;
   MomentumLowerWickPercent = 0;
   MomentumScore = 0;

   double open1 = iOpen(symbol, ZoneTF, 1);
   double close1 = iClose(symbol, ZoneTF, 1);
   double high1 = iHigh(symbol, ZoneTF, 1);
   double low1 = iLow(symbol, ZoneTF, 1);
   double high2 = iHigh(symbol, ZoneTF, 2);
   double low2 = iLow(symbol, ZoneTF, 2);

   if(open1 <= 0 || close1 <= 0 || high1 <= low1)
      return;

   bool insideBar = (high1 < high2 && low1 > low2);
   double range = high1 - low1;
   double body = MathAbs(close1 - open1);
   double bodyRatio = body / range;
   double upperWick = high1 - MathMax(open1, close1);
   double lowerWick = MathMin(open1, close1) - low1;

   MomentumBodyPercent = bodyRatio * 100.0;
   MomentumUpperWickPercent = (upperWick / range) * 100.0;
   MomentumLowerWickPercent = (lowerWick / range) * 100.0;

   if(insideBar)
   {
      MomentumReason = "Inside Bar";
      MomentumCandleText = "Inside Bar";
      MomentumStrengthText = "Weak";
      MomentumScore = 5;
      return;
   }

   if(bodyRatio < 0.25)
   {
      MomentumReason = "Small Candle";
      MomentumCandleText = "Doji";
      MomentumStrengthText = "Weak";
      MomentumScore = 5;
      return;
   }

   bool strongBull = (close1 > open1 && bodyRatio >= 0.60);
   bool strongBear = (close1 < open1 && bodyRatio >= 0.60);

   if(strongBull)
   {
      MomentumReason = "Strong Bull Candle";
      MomentumCandleText = "Bullish";
      MomentumStrengthText = "Strong";
      MomentumScore = (MarketBias == BIAS_BUY) ? 10 : 0;
      return;
   }

   if(strongBear)
   {
      MomentumReason = "Strong Bear Candle";
      MomentumCandleText = "Bearish";
      MomentumStrengthText = "Strong";
      MomentumScore = (MarketBias == BIAS_SELL) ? 10 : 0;
      return;
   }

   MomentumReason = "Neutral Candle";
   MomentumCandleText = (close1 >= open1) ? "Bullish" : "Bearish";
   MomentumStrengthText = "Normal";
   MomentumScore = 5;
}

#endif
