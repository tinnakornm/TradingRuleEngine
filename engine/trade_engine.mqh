//+------------------------------------------------------------------+
//| engine/trade_engine.mqh                                          |
//| Read-only MT5 trade state for the Trade tab                      |
//+------------------------------------------------------------------+
#ifndef TRE_TRADE_ENGINE_MQH
#define TRE_TRADE_ENGINE_MQH

void TradeResetRow(int index)
{
   TradePositionTicket[index] = "N/A";
   TradePositionType[index] = "N/A";
   TradePositionVolume[index] = "N/A";
   TradePositionEntryPrice[index] = "N/A";
   TradePositionCurrentPrice[index] = "N/A";
   TradePositionStopLoss[index] = "N/A";
   TradePositionTakeProfit[index] = "N/A";
   TradePositionFloatingProfit[index] = "N/A";
   TradePositionSwap[index] = "N/A";
   TradePositionCommission[index] = "N/A";
   TradePositionTime[index] = "N/A";
   TradePositionComment[index] = "N/A";
   TradePositionStatus[index] = "NO POSITION";
   TradeRiskPoints[index] = "N/A";
   TradeRewardPoints[index] = "N/A";
   TradeCurrentMovePoints[index] = "N/A";
   TradeCurrentRR[index] = "N/A";
   TradePlannedRR[index] = "N/A";

   TradePendingTicket[index] = "N/A";
   TradePendingType[index] = "N/A";
   TradePendingVolume[index] = "N/A";
   TradePendingEntryPrice[index] = "N/A";
   TradePendingStopLoss[index] = "N/A";
   TradePendingTakeProfit[index] = "N/A";
   TradePendingDistancePoints[index] = "N/A";
   TradePendingOrderTime[index] = "N/A";
   TradePendingExpiration[index] = "N/A";
   TradePendingComment[index] = "N/A";
}

void TradeResetHistoryRow(int index)
{
   TradeHistoryID[index] = "N/A";
   TradeHistoryType[index] = "N/A";
   TradeHistoryVolume[index] = "N/A";
   TradeHistoryPriceStart[index] = "N/A";
   TradeHistoryPriceEnd[index] = "N/A";
   TradeHistoryProfit[index] = "N/A";
}

string TradeValueOrNA(string value)
{
   if(value == "")
      return "N/A";

   return value;
}

string MarginLevelStatus(double marginLevel)
{
   if(marginLevel <= 0)
      return "NO MARGIN";

   if(marginLevel < 100)
      return "CRITICAL";

   if(marginLevel < 200)
      return "DANGER";

   if(marginLevel < 500)
      return "CAUTION";

   return "HEALTHY";
}

void TradeReadAccountState()
{
   AccountMarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   if(AccountMarginLevel <= 0)
   {
      AccountMarginLevelText = "N/A";
      AccountMarginStatusText = "NO MARGIN";
      return;
   }

   AccountMarginLevelText = DoubleToString(AccountMarginLevel, 2) + "%";
   AccountMarginStatusText = MarginLevelStatus(AccountMarginLevel);
}

void TradeResetState()
{
   TradePositionCount = 0;
   TradePendingCount = 0;
   TradeFloatingProfitTotal = 0;
   AccountMarginLevel = 0;
   AccountMarginLevelText = "N/A";
   AccountMarginStatusText = "N/A";
   TradePositionSummary = "NONE";

   for(int i = 0; i < TRE_MAX_TRADE_ROWS; i++)
      TradeResetRow(i);
}

string PositionTypeToText(long type)
{
   if(type == POSITION_TYPE_BUY) return "BUY";
   if(type == POSITION_TYPE_SELL) return "SELL";
   return "N/A";
}

string PendingTypeToText(long type)
{
   if(type == ORDER_TYPE_BUY_LIMIT) return "BUY LIMIT";
   if(type == ORDER_TYPE_SELL_LIMIT) return "SELL LIMIT";
   if(type == ORDER_TYPE_BUY_STOP) return "BUY STOP";
   if(type == ORDER_TYPE_SELL_STOP) return "SELL STOP";
   if(type == ORDER_TYPE_BUY_STOP_LIMIT) return "BUY STOP LIMIT";
   if(type == ORDER_TYPE_SELL_STOP_LIMIT) return "SELL STOP LIMIT";
   return "N/A";
}

string PriceToText(double price, int digits)
{
   if(price <= 0)
      return "N/A";

   return DoubleToString(price, digits);
}

string TimeToText(datetime value)
{
   if(value <= 0)
      return "N/A";

   return TimeToString(value, TIME_DATE|TIME_MINUTES);
}

string RRToText(double value)
{
   return DoubleToString(value, 2);
}

void TradeCalculateRR(int row,
                      long positionType,
                      double entry,
                      double current,
                      double stopLoss,
                      double takeProfit,
                      double point)
{
   if(entry <= 0 || current <= 0 || stopLoss <= 0 || takeProfit <= 0 || point <= 0)
      return;

   double risk = 0;
   double reward = 0;
   double currentMove = 0;

   if(positionType == POSITION_TYPE_BUY)
   {
      risk = entry - stopLoss;
      reward = takeProfit - entry;
      currentMove = current - entry;
   }
   else if(positionType == POSITION_TYPE_SELL)
   {
      risk = stopLoss - entry;
      reward = entry - takeProfit;
      currentMove = entry - current;
   }

   if(risk <= 0)
   {
      TradeRiskPoints[row] = "INVALID";
      TradeRewardPoints[row] = "INVALID";
      TradeCurrentMovePoints[row] = "INVALID";
      TradeCurrentRR[row] = "INVALID";
      TradePlannedRR[row] = "INVALID";
      return;
   }

   TradeRiskPoints[row] = DoubleToString(risk / point, 1);
   TradeRewardPoints[row] = DoubleToString(reward / point, 1);
   TradeCurrentMovePoints[row] = DoubleToString(currentMove / point, 1);
   TradeCurrentRR[row] = RRToText(currentMove / risk);
   TradePlannedRR[row] = RRToText(reward / risk);
}

void TradeReadPositions(string symbol)
{
   int total = PositionsTotal();
   int row = 0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      TradePositionCount++;
      TradeFloatingProfitTotal += PositionGetDouble(POSITION_PROFIT);

      if(row >= TRE_MAX_TRADE_ROWS)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double current = (type == POSITION_TYPE_BUY) ? ask : bid;

      if(current <= 0)
         current = PositionGetDouble(POSITION_PRICE_CURRENT);

      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);

      TradePositionSummary = PositionTypeToText(type);
      TradePositionTicket[row] = IntegerToString((long)ticket);
      TradePositionType[row] = PositionTypeToText(type);
      TradePositionVolume[row] = DoubleToString(volume, 2);
      TradePositionEntryPrice[row] = PriceToText(entry, digits);
      TradePositionCurrentPrice[row] = PriceToText(current, digits);
      TradePositionStopLoss[row] = PriceToText(stopLoss, digits);
      TradePositionTakeProfit[row] = PriceToText(takeProfit, digits);
      TradePositionFloatingProfit[row] = DoubleToString(profit, 2);
      TradePositionSwap[row] = DoubleToString(swap, 2);
      TradePositionCommission[row] = "N/A";
      TradePositionTime[row] = TimeToText(positionTime);
      TradePositionComment[row] = TradeValueOrNA(PositionGetString(POSITION_COMMENT));
      TradePositionStatus[row] = "OPEN POSITION";

      TradeCalculateRR(row, type, entry, current, stopLoss, takeProfit, point);
      row++;
   }

   if(TradePositionCount == 0)
      TradePositionSummary = "NONE";
   else if(TradePositionCount > 1)
      TradePositionSummary = "MULTIPLE";
}

void TradeReadPendingOrders(string symbol)
{
   int total = OrdersTotal();
   int row = 0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

   for(int i = 0; i < total; i++)
   {
      ulong ticket = OrderGetTicket(i);

      if(ticket == 0)
         continue;

      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;

      long type = OrderGetInteger(ORDER_TYPE);

      if(type != ORDER_TYPE_BUY_LIMIT &&
         type != ORDER_TYPE_SELL_LIMIT &&
         type != ORDER_TYPE_BUY_STOP &&
         type != ORDER_TYPE_SELL_STOP &&
         type != ORDER_TYPE_BUY_STOP_LIMIT &&
         type != ORDER_TYPE_SELL_STOP_LIMIT)
      {
         continue;
      }

      TradePendingCount++;

      if(row >= TRE_MAX_TRADE_ROWS)
         continue;

      double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
      double entry = OrderGetDouble(ORDER_PRICE_OPEN);
      double stopLoss = OrderGetDouble(ORDER_SL);
      double takeProfit = OrderGetDouble(ORDER_TP);
      datetime setupTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      double referencePrice = (type == ORDER_TYPE_SELL_LIMIT ||
                               type == ORDER_TYPE_SELL_STOP ||
                               type == ORDER_TYPE_SELL_STOP_LIMIT) ? bid : ask;

      TradePendingTicket[row] = IntegerToString((long)ticket);
      TradePendingType[row] = PendingTypeToText(type);
      TradePendingVolume[row] = DoubleToString(volume, 2);
      TradePendingEntryPrice[row] = PriceToText(entry, digits);
      TradePendingStopLoss[row] = PriceToText(stopLoss, digits);
      TradePendingTakeProfit[row] = PriceToText(takeProfit, digits);
      TradePendingDistancePoints[row] = (point > 0 && entry > 0 && referencePrice > 0)
         ? DoubleToString(MathAbs(entry - referencePrice) / point, 1)
         : "N/A";
      TradePendingOrderTime[row] = TimeToText(setupTime);
      TradePendingExpiration[row] = TimeToText(expiration);
      TradePendingComment[row] = TradeValueOrNA(OrderGetString(ORDER_COMMENT));
      row++;
   }
}

bool TradeHistoryPositionStillOpen(long identifier)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0 &&
         PositionGetInteger(POSITION_IDENTIFIER) == identifier)
         return true;
   }
   return false;
}

int TradeFindHistoryPosition(long &identifiers[], long identifier)
{
   for(int i = 0; i < TradeHistoryCount; i++)
      if(identifiers[i] == identifier)
         return i;
   return -1;
}

void TradeReadHistory(string symbol)
{
   if(ActiveTradeSubTab != 3)
      return;

   if(!HistorySelect(0, TimeCurrent()))
      return;

   int totalDeals = HistoryDealsTotal();
   static int lastHistoryDeals = -1;
   static string lastHistorySymbol = "";
   if(totalDeals == lastHistoryDeals &&
      symbol == lastHistorySymbol)
      return;

   lastHistoryDeals = totalDeals;
   lastHistorySymbol = symbol;
   TradeHistoryCount = 0;
   for(int row = 0; row < TRE_MAX_TRADE_HISTORY_ROWS; row++)
      TradeResetHistoryRow(row);

   long identifiers[TRE_MAX_TRADE_HISTORY_ROWS];
   long types[TRE_MAX_TRADE_HISTORY_ROWS];
   double entryVolume[TRE_MAX_TRADE_HISTORY_ROWS];
   double entryValue[TRE_MAX_TRADE_HISTORY_ROWS];
   double exitVolume[TRE_MAX_TRADE_HISTORY_ROWS];
   double exitValue[TRE_MAX_TRADE_HISTORY_ROWS];
   double netProfit[TRE_MAX_TRADE_HISTORY_ROWS];

   for(int row = 0; row < TRE_MAX_TRADE_HISTORY_ROWS; row++)
   {
      identifiers[row] = 0;
      types[row] = -1;
      entryVolume[row] = 0;
      entryValue[row] = 0;
      exitVolume[row] = 0;
      exitValue[row] = 0;
      netProfit[row] = 0;
   }

   for(int i = totalDeals - 1;
       i >= 0 && TradeHistoryCount < TRE_MAX_TRADE_HISTORY_ROWS;
       i--)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != symbol)
         continue;

      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      long identifier =
         HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(identifier <= 0 ||
         TradeHistoryPositionStillOpen(identifier) ||
         TradeFindHistoryPosition(identifiers, identifier) >= 0)
         continue;

      identifiers[TradeHistoryCount] = identifier;
      TradeHistoryCount++;
   }

   for(int i = 0; i < totalDeals; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != symbol)
         continue;

      long identifier =
         HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      int row = TradeFindHistoryPosition(identifiers, identifier);
      if(row < 0)
         continue;

      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
      double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double price = HistoryDealGetDouble(deal, DEAL_PRICE);

      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
      {
         entryVolume[row] += volume;
         entryValue[row] += price * volume;
         if(types[row] < 0)
            types[row] =
               (dealType == DEAL_TYPE_BUY)
               ? POSITION_TYPE_BUY
               : POSITION_TYPE_SELL;
      }

      if(entry == DEAL_ENTRY_OUT ||
         entry == DEAL_ENTRY_OUT_BY ||
         entry == DEAL_ENTRY_INOUT)
      {
         exitVolume[row] += volume;
         exitValue[row] += price * volume;
      }

      netProfit[row] +=
         HistoryDealGetDouble(deal, DEAL_PROFIT) +
         HistoryDealGetDouble(deal, DEAL_SWAP) +
         HistoryDealGetDouble(deal, DEAL_COMMISSION) +
         HistoryDealGetDouble(deal, DEAL_FEE);
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   for(int row = 0; row < TradeHistoryCount; row++)
   {
      double startPrice =
         (entryVolume[row] > 0)
         ? entryValue[row] / entryVolume[row]
         : 0;
      double endPrice =
         (exitVolume[row] > 0)
         ? exitValue[row] / exitVolume[row]
         : 0;
      TradeHistoryID[row] = IntegerToString(identifiers[row]);
      TradeHistoryType[row] = PositionTypeToText(types[row]);
      TradeHistoryVolume[row] = DoubleToString(exitVolume[row], 2);
      TradeHistoryPriceStart[row] =
         PriceToText(startPrice, digits);
      TradeHistoryPriceEnd[row] =
         PriceToText(endPrice, digits);
      TradeHistoryProfit[row] = DoubleToString(netProfit[row], 2);
   }
}

void TradeEngine(string symbol)
{
   TradeResetState();
   TradeReadAccountState();
   TradeReadPositions(symbol);
   TradeReadPendingOrders(symbol);
   TradeReadHistory(symbol);
}

#endif
