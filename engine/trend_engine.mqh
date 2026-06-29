//+------------------------------------------------------------------+
//| engine/trend_engine.mqh                                          |
//| Convert swing structure to market bias and explainable evidence  |
//+------------------------------------------------------------------+
#ifndef TRE_TREND_ENGINE_MQH
#define TRE_TREND_ENGINE_MQH

void TrendResetEvidence()
{
   TRE_SetEvidenceItem(TrendEvidence[0], "Higher High", TRE_STATUS_WAIT, 0, 10,
                       "Waiting for swing high data",
                       "Need current and previous swing highs");
   TRE_SetEvidenceItem(TrendEvidence[1], "Higher Low", TRE_STATUS_WAIT, 0, 10,
                       "Waiting for swing low data",
                       "Need current and previous swing lows");
   TRE_SetEvidenceItem(TrendEvidence[2], "Lower High", TRE_STATUS_WAIT, 0, 10,
                       "Waiting for swing high data",
                       "Need current and previous swing highs");
   TRE_SetEvidenceItem(TrendEvidence[3], "Lower Low", TRE_STATUS_WAIT, 0, 10,
                       "Waiting for swing low data",
                       "Need current and previous swing lows");
   TRE_SetEvidenceItem(TrendEvidence[4], "Swing Direction", TRE_STATUS_WAIT, 0, 10,
                       "Swing direction is not available",
                       "Need aligned swing highs and lows");
   TRE_SetEvidenceItem(TrendEvidence[5], "Market Structure", TRE_STATUS_WAIT, 0, 10,
                       "Market structure is incomplete",
                       "Need HH + HL or LH + LL");
   TRE_SetEvidenceItem(TrendEvidence[6], "Trend Strength", TRE_STATUS_WAIT, 0, 10,
                       "Trend strength is not available",
                       "Need confirmed directional structure");
   TRE_SetEvidenceItem(TrendEvidence[7], "Bias Confirmation", TRE_STATUS_WAIT, 0, 10,
                       "Bias is not confirmed",
                       "Need confirmed bullish or bearish structure");

   TrendEvidenceScore = 0;
   TrendEvidenceMaxScore = 80;
}

void TrendSetComparisonEvidence(int index,
                                string name,
                                bool conditionPassed,
                                bool oppositeCondition,
                                string passReason,
                                string failReason,
                                string missing)
{
   if(conditionPassed)
   {
      TRE_SetEvidenceItem(TrendEvidence[index], name, TRE_STATUS_PASS, 10, 10,
                          passReason, "N/A");
      return;
   }

   if(oppositeCondition)
   {
      TRE_SetEvidenceItem(TrendEvidence[index], name, TRE_STATUS_FAIL, 0, 10,
                          failReason, missing);
      return;
   }

   TRE_SetEvidenceItem(TrendEvidence[index], name, TRE_STATUS_WAIT, 0, 10,
                       "Swing values are equal", missing);
}

void TrendCalculateEvidenceScore()
{
   TrendEvidenceScore = 0;

   for(int i = 0; i < TrendEvidenceItemCount; i++)
      TrendEvidenceScore += TrendEvidence[i].score;
}

void TrendEngine()
{
   // SwingEngine applies BiasLookbackBars before publishing H4 structure.
   TrendResetEvidence();

   MarketBias = BIAS_WAIT;
   TrendReason = "Not enough structure evidence";
   TrendDirectionText = "Unknown";
   TrendStrengthText = "Unknown";
   MarketRegimeText = "Unknown";
   TrendConfidenceText = "N/A";
   TrendBiasReasonText = "Not enough structure evidence";
   TrendBlockingFactorText = "Swing structure data is incomplete";
   TrendScore = 0;

   if(LastSwingHigh == 0 || PrevSwingHigh == 0 ||
      LastSwingLow == 0 || PrevSwingLow == 0)
   {
      TrendCalculateEvidenceScore();
      return;
   }

   bool lowerHigh = LastSwingHigh < PrevSwingHigh;
   bool lowerLow = LastSwingLow < PrevSwingLow;
   bool higherHigh = LastSwingHigh > PrevSwingHigh;
   bool higherLow = LastSwingLow > PrevSwingLow;
   bool bearishStructure = lowerHigh && lowerLow;
   bool bullishStructure = higherHigh && higherLow;

   TrendSetComparisonEvidence(
      0, "Higher High", higherHigh, lowerHigh,
      "Current swing high is above previous swing high",
      "Current swing high is below previous swing high",
      "Need a swing high above the previous swing high");
   TrendSetComparisonEvidence(
      1, "Higher Low", higherLow, lowerLow,
      "Current swing low is above previous swing low",
      "Current swing low is below previous swing low",
      "Need price to hold above the previous swing low");
   TrendSetComparisonEvidence(
      2, "Lower High", lowerHigh, higherHigh,
      "Current swing high is below previous swing high",
      "Current swing high is above previous swing high",
      "Need a swing high below the previous swing high");
   TrendSetComparisonEvidence(
      3, "Lower Low", lowerLow, higherLow,
      "Current swing low is below previous swing low",
      "Current swing low is above previous swing low",
      "Need a break below the previous swing low");

   if(bearishStructure || bullishStructure)
   {
      string direction = bullishStructure ? "bullish" : "bearish";
      TRE_SetEvidenceItem(TrendEvidence[4], "Swing Direction", TRE_STATUS_PASS, 10, 10,
                          "High and low swings align " + direction,
                          "N/A");
      TRE_SetEvidenceItem(TrendEvidence[5], "Market Structure", TRE_STATUS_PASS, 10, 10,
                          bullishStructure ? "Higher High and Higher Low confirmed"
                                           : "Lower High and Lower Low confirmed",
                          "N/A");
      TRE_SetEvidenceItem(TrendEvidence[6], "Trend Strength", TRE_STATUS_PASS, 10, 10,
                          "Directional structure is strong",
                          "N/A");
      TRE_SetEvidenceItem(TrendEvidence[7], "Bias Confirmation", TRE_STATUS_PASS, 10, 10,
                          bullishStructure ? "BUY ONLY bias confirmed"
                                           : "SELL ONLY bias confirmed",
                          "N/A");

      MarketBias = bullishStructure ? BIAS_BUY : BIAS_SELL;
      TrendReason = bullishStructure ? "H4 Bullish Structure"
                                     : "H4 Bearish Structure";
      TrendDirectionText = bullishStructure ? "Bullish" : "Bearish";
      TrendStrengthText = "Strong";
      MarketRegimeText = bullishStructure ? "Up" : "Down";
      TrendConfidenceText = "High";
      TrendBiasReasonText = bullishStructure
                            ? "Higher High and Higher Low confirmed"
                            : "Lower High and Lower Low confirmed";
      TrendBlockingFactorText = "N/A";

      // Keep the existing 0-40 contract consumed by Entry Engine.
      TrendScore = 40;
      TrendCalculateEvidenceScore();
      return;
   }

   TRE_SetEvidenceItem(TrendEvidence[4], "Swing Direction", TRE_STATUS_WAIT, 0, 10,
                       "High and low swings point in different directions",
                       "Need HH + HL or LH + LL alignment");
   TRE_SetEvidenceItem(TrendEvidence[5], "Market Structure", TRE_STATUS_WAIT, 0, 10,
                       "Directional market structure is incomplete",
                       "Need one aligned swing pair");
   TRE_SetEvidenceItem(TrendEvidence[6], "Trend Strength", TRE_STATUS_WAIT, 5, 10,
                       "Only partial structure evidence is available",
                       "Need a second directional swing confirmation");
   TRE_SetEvidenceItem(TrendEvidence[7], "Bias Confirmation", TRE_STATUS_WAIT, 0, 10,
                       "Bullish and bearish evidence is mixed",
                       "Need confirmed directional structure");

   if(lowerHigh)
   {
      TrendReason = "H4 Lower High";
      TrendDirectionText = "Bearish";
      MarketRegimeText = "Down";
      TrendBlockingFactorText = "Lower Low not confirmed";
   }
   else if(lowerLow)
   {
      TrendReason = "H4 Lower Low";
      TrendDirectionText = "Bearish";
      MarketRegimeText = "Down";
      TrendBlockingFactorText = "Lower High not confirmed";
   }
   else if(higherHigh)
   {
      TrendReason = "H4 Higher High";
      TrendDirectionText = "Bullish";
      MarketRegimeText = "Up";
      TrendBlockingFactorText = "Higher Low not confirmed";
   }
   else if(higherLow)
   {
      TrendReason = "H4 Higher Low";
      TrendDirectionText = "Bullish";
      MarketRegimeText = "Up";
      TrendBlockingFactorText = "Higher High not confirmed";
   }
   else
   {
      TrendReason = "H4 Sideway Structure";
      TrendDirectionText = "Sideway";
      MarketRegimeText = "Sideway";
      TrendBlockingFactorText = "Directional swing break not confirmed";
   }

   TrendStrengthText = "Weak";
   TrendConfidenceText = "Low";
   TrendBiasReasonText = "Not enough bullish or bearish evidence";
   TrendScore = 15;
   MarketBias = BIAS_WAIT;
   TrendCalculateEvidenceScore();
}

#endif
