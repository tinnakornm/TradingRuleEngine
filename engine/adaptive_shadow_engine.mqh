//+------------------------------------------------------------------+
//| engine/adaptive_shadow_engine.mqh                                |
//| Research-only outcomes for candidates blocked by Adaptive V1     |
//+------------------------------------------------------------------+
#ifndef TRE_ADAPTIVE_SHADOW_ENGINE_MQH
#define TRE_ADAPTIVE_SHADOW_ENGINE_MQH

#define TRE_ADAPTIVE_SHADOW_GROUP_MAX 256

struct TRE_AdaptiveShadowTrade
{
   long shadowTradeID;
   long episodeID;
   int blockedAuditSerial;
   datetime blockedTime;
   string symbol;
   ENUM_TIMEFRAMES timeframe;
   int direction;
   int zone;
   double lot;
   double entryPrice;
   double expectedSLPrice;
   double expectedTPPrice;
   datetime shadowExitTime;
   double shadowExitPrice;
   string shadowExitReason;
   double shadowProfitUSD;
   int shadowHoldingBars;
   int shadowHoldingMinutes;
   bool wouldWin;
   bool wouldLoss;
   string status;
   datetime createdAt;
   bool dbOpenWritten;
   bool dbCloseWritten;
};

struct TRE_AdaptiveShadowEpisodeAggregate
{
   long episodeID;
   int tradeCount;
   double netProfit;
};

struct TRE_AdaptiveShadowPatternAggregate
{
   string pattern;
   int tradeCount;
   double netProfit;
};

TRE_AdaptiveShadowTrade TREAdaptiveShadowTrades[];
long AdaptiveShadowNextTradeID = 1;

int AdaptiveShadowTradeCount = 0;
int AdaptiveShadowClosedTradeCount = 0;
int AdaptiveShadowOpenTradeCount = 0;
int AdaptiveShadowWinCount = 0;
int AdaptiveShadowLossCount = 0;
double AdaptiveShadowNetProfit = 0;
double AdaptiveShadowGrossProfit = 0;
double AdaptiveShadowGrossLoss = 0;
double AdaptiveShadowProfitFactor = 0;
double AdaptiveShadowAvgHoldingBars = 0;
double AdaptiveShadowAvgHoldingMinutes = 0;
double AdaptiveEstimatedBenefit = 0;
int AdaptiveGoodBlockEpisodes = 0;
int AdaptiveBadBlockEpisodes = 0;
string AdaptiveShadowBestPattern = "NONE";
string AdaptiveShadowWorstPattern = "NONE";

double AdaptiveShadowNormalizePrice(string symbol, double price)
{
   double tickSize =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(tickSize > 0)
      price = MathRound(price / tickSize) * tickSize;
   return NormalizeDouble(price, digits);
}

int AdaptiveShadowBarsBetween(string symbol,
                              ENUM_TIMEFRAMES timeframe,
                              datetime openTime,
                              datetime endTime)
{
   if(openTime <= 0 || endTime < openTime)
      return -1;
   int openShift = iBarShift(symbol, timeframe, openTime, false);
   int endShift = iBarShift(symbol, timeframe, endTime, false);
   if(openShift < 0 || endShift < 0)
      return -1;
   return (int)MathMax(0, openShift - endShift);
}

int AdaptiveShadowHoldingBars(string symbol,
                              datetime openTime,
                              datetime endTime)
{
   int barsHeld = AdaptiveShadowBarsBetween(
      symbol, ExecutionTF, openTime, endTime);
   if(barsHeld >= 0)
      return barsHeld;
   barsHeld = AdaptiveShadowBarsBetween(
      symbol, EntryTF, openTime, endTime);
   return (barsHeld >= 0) ? barsHeld : 0;
}

bool AdaptiveShadowWeekendExitTime()
{
   if(!EnableWeekendProtection)
      return false;
   MqlDateTime serverTime;
   ZeroMemory(serverTime);
   if(!TimeToStruct(TimeCurrent(), serverTime))
      return false;
   int closeHour =
      (int)MathMax(0, MathMin(23, WeekendForceCloseHour));
   return (serverTime.day_of_week == (int)WeekendBlockDay &&
           serverTime.hour >= closeHour);
}

bool AdaptiveShadowProfit(TRE_AdaptiveShadowTrade &trade,
                          double exitPrice,
                          double &profit)
{
   ENUM_ORDER_TYPE orderType =
      (trade.direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcProfit(orderType, trade.symbol, trade.lot,
                      trade.entryPrice, exitPrice, profit))
   {
      return true;
   }

   double tickSize =
      SymbolInfoDouble(trade.symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue =
      SymbolInfoDouble(trade.symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0)
   {
      profit = 0;
      return false;
   }
   double movement = (trade.direction > 0)
                     ? exitPrice - trade.entryPrice
                     : trade.entryPrice - exitPrice;
   profit = (movement / tickSize) * tickValue * trade.lot;
   return true;
}

void AdaptiveShadowRefreshMetrics()
{
   AdaptiveShadowTradeCount = ArraySize(TREAdaptiveShadowTrades);
   AdaptiveShadowClosedTradeCount = 0;
   AdaptiveShadowOpenTradeCount = 0;
   AdaptiveShadowWinCount = 0;
   AdaptiveShadowLossCount = 0;
   AdaptiveShadowNetProfit = 0;
   AdaptiveShadowGrossProfit = 0;
   AdaptiveShadowGrossLoss = 0;
   AdaptiveShadowProfitFactor = 0;
   AdaptiveShadowAvgHoldingBars = 0;
   AdaptiveShadowAvgHoldingMinutes = 0;
   AdaptiveEstimatedBenefit = 0;
   AdaptiveGoodBlockEpisodes = 0;
   AdaptiveBadBlockEpisodes = 0;
   AdaptiveShadowBestPattern = "NONE";
   AdaptiveShadowWorstPattern = "NONE";

   TRE_AdaptiveShadowEpisodeAggregate
      episodes[TRE_ADAPTIVE_SHADOW_GROUP_MAX];
   TRE_AdaptiveShadowPatternAggregate
      patterns[TRE_ADAPTIVE_SHADOW_GROUP_MAX];
   ZeroMemory(episodes);
   ZeroMemory(patterns);
   int episodeCount = 0;
   int patternCount = 0;
   double holdingBarsTotal = 0;
   double holdingMinutesTotal = 0;

   for(int i = 0; i < ArraySize(TREAdaptiveShadowTrades); i++)
   {
      TRE_AdaptiveShadowTrade trade = TREAdaptiveShadowTrades[i];
      if(trade.status != "CLOSED")
      {
         AdaptiveShadowOpenTradeCount++;
         continue;
      }

      AdaptiveShadowClosedTradeCount++;
      AdaptiveShadowNetProfit += trade.shadowProfitUSD;
      holdingBarsTotal += trade.shadowHoldingBars;
      holdingMinutesTotal += trade.shadowHoldingMinutes;
      if(trade.shadowProfitUSD > 0)
      {
         AdaptiveShadowWinCount++;
         AdaptiveShadowGrossProfit += trade.shadowProfitUSD;
      }
      else if(trade.shadowProfitUSD < 0)
      {
         AdaptiveShadowLossCount++;
         AdaptiveShadowGrossLoss += trade.shadowProfitUSD;
      }

      int episodeIndex = -1;
      for(int j = 0; j < episodeCount; j++)
      {
         if(episodes[j].episodeID == trade.episodeID)
         {
            episodeIndex = j;
            break;
         }
      }
      if(episodeIndex < 0 &&
         episodeCount < TRE_ADAPTIVE_SHADOW_GROUP_MAX)
      {
         episodeIndex = episodeCount++;
         episodes[episodeIndex].episodeID = trade.episodeID;
      }
      if(episodeIndex >= 0)
      {
         episodes[episodeIndex].tradeCount++;
         episodes[episodeIndex].netProfit += trade.shadowProfitUSD;
      }

      string pattern =
         AdaptiveV1Pattern(trade.direction, trade.zone);
      int patternIndex = -1;
      for(int j = 0; j < patternCount; j++)
      {
         if(patterns[j].pattern == pattern)
         {
            patternIndex = j;
            break;
         }
      }
      if(patternIndex < 0 &&
         patternCount < TRE_ADAPTIVE_SHADOW_GROUP_MAX)
      {
         patternIndex = patternCount++;
         patterns[patternIndex].pattern = pattern;
      }
      if(patternIndex >= 0)
      {
         patterns[patternIndex].tradeCount++;
         patterns[patternIndex].netProfit += trade.shadowProfitUSD;
      }
   }

   if(AdaptiveShadowClosedTradeCount > 0)
   {
      AdaptiveShadowAvgHoldingBars =
         holdingBarsTotal / AdaptiveShadowClosedTradeCount;
      AdaptiveShadowAvgHoldingMinutes =
         holdingMinutesTotal / AdaptiveShadowClosedTradeCount;
   }
   if(AdaptiveShadowGrossLoss < 0)
   {
      AdaptiveShadowProfitFactor =
         AdaptiveShadowGrossProfit /
         MathAbs(AdaptiveShadowGrossLoss);
   }
   AdaptiveEstimatedBenefit = -AdaptiveShadowNetProfit;

   for(int i = 0; i < episodeCount; i++)
   {
      if(episodes[i].netProfit < 0)
         AdaptiveGoodBlockEpisodes++;
      else if(episodes[i].netProfit > 0)
         AdaptiveBadBlockEpisodes++;
   }

   if(patternCount > 0)
   {
      int best = 0;
      int worst = 0;
      for(int i = 1; i < patternCount; i++)
      {
         if(patterns[i].netProfit < patterns[best].netProfit)
            best = i;
         if(patterns[i].netProfit > patterns[worst].netProfit)
            worst = i;
      }
      AdaptiveShadowBestPattern = patterns[best].pattern;
      AdaptiveShadowWorstPattern = patterns[worst].pattern;
   }
}

bool AdaptiveShadowOpen(string symbol,
                        ENTRY_ACTION action,
                        int zone,
                        long episodeID,
                        int blockedAuditSerial)
{
   if(!AdaptiveV1Enabled() || episodeID <= 0 ||
      blockedAuditSerial <= 0 ||
      ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0)
   {
      return false;
   }

   for(int i = 0; i < ArraySize(TREAdaptiveShadowTrades); i++)
   {
      if(TREAdaptiveShadowTrades[i].blockedAuditSerial ==
         blockedAuditSerial)
      {
         return false;
      }
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) ||
      tick.ask <= 0 || tick.bid <= 0 ||
      ExecutionNormalizedLot <= 0 ||
      ExecutionPoint <= 0 ||
      ExecutionEffectiveSLPoints <= 0 ||
      ExecutionEffectiveTPPoints <= 0)
   {
      return false;
   }

   bool isBuy = (action == ACTION_BUY_READY);
   double entry = AdaptiveShadowNormalizePrice(
      symbol, isBuy ? tick.ask : tick.bid);
   double stopLoss = AdaptiveShadowNormalizePrice(
      symbol,
      isBuy ? entry - ExecutionEffectiveSLPoints * ExecutionPoint
            : entry + ExecutionEffectiveSLPoints * ExecutionPoint);
   double takeProfit = AdaptiveShadowNormalizePrice(
      symbol,
      isBuy ? entry + ExecutionEffectiveTPPoints * ExecutionPoint
            : entry - ExecutionEffectiveTPPoints * ExecutionPoint);

   int index = ArraySize(TREAdaptiveShadowTrades);
   if(ArrayResize(TREAdaptiveShadowTrades, index + 1) != index + 1)
      return false;

   TREAdaptiveShadowTrades[index].shadowTradeID =
      AdaptiveShadowNextTradeID++;
   TREAdaptiveShadowTrades[index].episodeID = episodeID;
   TREAdaptiveShadowTrades[index].blockedAuditSerial =
      blockedAuditSerial;
   TREAdaptiveShadowTrades[index].blockedTime = TimeCurrent();
   TREAdaptiveShadowTrades[index].symbol = symbol;
   TREAdaptiveShadowTrades[index].timeframe = EntryTF;
   TREAdaptiveShadowTrades[index].direction = isBuy ? 1 : -1;
   TREAdaptiveShadowTrades[index].zone = zone;
   TREAdaptiveShadowTrades[index].lot = ExecutionNormalizedLot;
   TREAdaptiveShadowTrades[index].entryPrice = entry;
   TREAdaptiveShadowTrades[index].expectedSLPrice = stopLoss;
   TREAdaptiveShadowTrades[index].expectedTPPrice = takeProfit;
   TREAdaptiveShadowTrades[index].shadowExitTime = 0;
   TREAdaptiveShadowTrades[index].shadowExitPrice = 0;
   TREAdaptiveShadowTrades[index].shadowExitReason = "";
   TREAdaptiveShadowTrades[index].shadowProfitUSD = 0;
   TREAdaptiveShadowTrades[index].shadowHoldingBars = 0;
   TREAdaptiveShadowTrades[index].shadowHoldingMinutes = 0;
   TREAdaptiveShadowTrades[index].wouldWin = false;
   TREAdaptiveShadowTrades[index].wouldLoss = false;
   TREAdaptiveShadowTrades[index].status = "OPEN";
   TREAdaptiveShadowTrades[index].createdAt = TimeCurrent();
   TREAdaptiveShadowTrades[index].dbOpenWritten = false;
   TREAdaptiveShadowTrades[index].dbCloseWritten = false;
   AdaptiveShadowRefreshMetrics();

   Print("[ADAPTIVE_SHADOW] action=OPEN shadow_id=",
         TREAdaptiveShadowTrades[index].shadowTradeID,
         " episode_id=", episodeID,
         " direction=", AdaptiveV1DirectionText(
            TREAdaptiveShadowTrades[index].direction),
         " zone=", zone,
         " entry=", DoubleToString(entry, ExecutionDigits));
   return true;
}

void AdaptiveShadowClose(int index,
                         double exitPrice,
                         string exitReason)
{
   if(index < 0 || index >= ArraySize(TREAdaptiveShadowTrades) ||
      TREAdaptiveShadowTrades[index].status != "OPEN")
   {
      return;
   }

   datetime exitTime = TimeCurrent();
   double profit = 0;
   AdaptiveShadowProfit(
      TREAdaptiveShadowTrades[index], exitPrice, profit);
   TREAdaptiveShadowTrades[index].shadowExitTime = exitTime;
   TREAdaptiveShadowTrades[index].shadowExitPrice = exitPrice;
   TREAdaptiveShadowTrades[index].shadowExitReason = exitReason;
   TREAdaptiveShadowTrades[index].shadowProfitUSD = profit;
   TREAdaptiveShadowTrades[index].shadowHoldingBars =
      AdaptiveShadowHoldingBars(
         TREAdaptiveShadowTrades[index].symbol,
         TREAdaptiveShadowTrades[index].blockedTime,
         exitTime);
   TREAdaptiveShadowTrades[index].shadowHoldingMinutes =
      (int)MathMax(
         0,
         (long)(exitTime -
                TREAdaptiveShadowTrades[index].blockedTime) / 60);
   TREAdaptiveShadowTrades[index].wouldWin = (profit > 0);
   TREAdaptiveShadowTrades[index].wouldLoss = (profit < 0);
   TREAdaptiveShadowTrades[index].status = "CLOSED";
   AdaptiveShadowRefreshMetrics();

   Print("[ADAPTIVE_SHADOW] action=CLOSE shadow_id=",
         TREAdaptiveShadowTrades[index].shadowTradeID,
         " episode_id=", TREAdaptiveShadowTrades[index].episodeID,
         " reason=", exitReason,
         " profit=", DoubleToString(profit, 2));
}

void AdaptiveShadowEngine(string symbol)
{
   if(!AdaptiveV1Enabled() ||
      ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0)
   {
      return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) ||
      tick.ask <= 0 || tick.bid <= 0)
   {
      return;
   }

   bool weekendExit = AdaptiveShadowWeekendExitTime();
   for(int i = 0; i < ArraySize(TREAdaptiveShadowTrades); i++)
   {
      if(TREAdaptiveShadowTrades[i].status != "OPEN" ||
         TREAdaptiveShadowTrades[i].symbol != symbol)
      {
         continue;
      }

      bool isBuy = (TREAdaptiveShadowTrades[i].direction > 0);
      double exitPrice = isBuy ? tick.bid : tick.ask;
      string reason = "";
      if((isBuy &&
          exitPrice <= TREAdaptiveShadowTrades[i].expectedSLPrice) ||
         (!isBuy &&
          exitPrice >= TREAdaptiveShadowTrades[i].expectedSLPrice))
      {
         reason = "SHADOW_SL";
      }
      else if((isBuy &&
               exitPrice >=
               TREAdaptiveShadowTrades[i].expectedTPPrice) ||
              (!isBuy &&
               exitPrice <=
               TREAdaptiveShadowTrades[i].expectedTPPrice))
      {
         reason = "SHADOW_TP";
      }
      else if(weekendExit)
      {
         reason = "SHADOW_WEEKEND";
      }
      else if(UseBacktestMaxHoldingBars &&
              AdaptiveShadowHoldingBars(
                 symbol,
                 TREAdaptiveShadowTrades[i].blockedTime,
                 TimeCurrent()) >=
              EffectiveBacktestMaxHoldingBars)
      {
         reason = "SHADOW_TIMEOUT";
      }

      if(reason != "")
      {
         AdaptiveShadowClose(
            i, AdaptiveShadowNormalizePrice(symbol, exitPrice), reason);
      }
   }
}

#endif
