//+------------------------------------------------------------------+
//| engine/execution_engine.mqh                                      |
//| Strategy Tester execution and execution diagnostics              |
//+------------------------------------------------------------------+
#ifndef TRE_EXECUTION_ENGINE_MQH
#define TRE_EXECUTION_ENGINE_MQH

#include <Trade/Trade.mqh>

CTrade TREBacktestTrade;

string TRE_ExecutionModeToText()
{
   if(ExecutionMode == TRE_SHADOW_JOURNAL) return "Shadow Journal";
   if(ExecutionMode == TRE_BACKTEST_ONLY) return "Backtest Only";
   if(ExecutionMode == TRE_LIVE_MANUAL_APPROVAL) return "Live Manual Approval (Reserved)";
   if(ExecutionMode == TRE_LIVE_AUTO) return "Live Auto (Reserved)";
   return "Display Only";
}

bool TRE_IsStrategyTester()
{
   return (MQLInfoInteger(MQL_TESTER) != 0);
}

bool TRE_CanExecute()
{
   if(ExecutionMode != TRE_BACKTEST_ONLY)
      return false;

   if(!TRE_IsStrategyTester())
      return false;

   return true;
}

void TRE_LogExecutionOnce(string message)
{
   static string previousMessage = "";

   if(message == previousMessage)
      return;

   previousMessage = message;
   Print(message);
}

string TRE_ExecutionTimeToText(datetime value)
{
   if(value <= 0)
      return "N/A";

   return TimeToString(value, TIME_DATE|TIME_MINUTES);
}

string TRE_WeekendDayToText(ENUM_DAY_OF_WEEK day)
{
   if(day == SUNDAY) return "Sunday";
   if(day == MONDAY) return "Monday";
   if(day == TUESDAY) return "Tuesday";
   if(day == WEDNESDAY) return "Wednesday";
   if(day == THURSDAY) return "Thursday";
   if(day == FRIDAY) return "Friday";
   if(day == SATURDAY) return "Saturday";
   return "Unknown";
}

int TRE_WeekendHour(int configuredHour)
{
   return (int)MathMax(0, MathMin(23, configuredHour));
}

void TRE_RefreshWeekendProtectionState()
{
   int blockHour = TRE_WeekendHour(WeekendBlockHour);
   int closeHour = TRE_WeekendHour(WeekendForceCloseHour);
   string day = TRE_WeekendDayToText(WeekendBlockDay);
   WeekendProtectionStatusText = EnableWeekendProtection ? "ON" : "OFF";
   WeekendBlockTimeText =
      day + " >= " + StringFormat("%02d:00", blockHour);
   WeekendForceCloseTimeText =
      day + " >= " + StringFormat("%02d:00", closeHour);
}

bool TRE_IsWeekendProtectionTime(int configuredHour)
{
   MqlDateTime serverTime;
   ZeroMemory(serverTime);
   if(!TimeToStruct(TimeCurrent(), serverTime))
      return false;
   return (serverTime.day_of_week == (int)WeekendBlockDay &&
           serverTime.hour >= TRE_WeekendHour(configuredHour));
}

void TRE_RegisterWeekendAudit(string decision,
                              string reason,
                              string detail)
{
   WeekendAuditDecision = decision;
   WeekendAuditReason = reason;
   WeekendAuditDetail = detail;
   WeekendAuditTime = TimeCurrent();
   WeekendAuditSerial++;
}

bool TRE_WeekendEntryBlocked(datetime signalBar)
{
   if(!EnableWeekendProtection ||
      !TRE_IsWeekendProtectionTime(WeekendBlockHour))
   {
      return false;
   }

   string reason = "BLOCK_WEEKEND_PROTECTION_FRIDAY_LATE_ENTRY";
   ExecutionCanExecuteText = "NO";
   LastExecutionAction = "BLOCKED";
   LastExecutionReason = reason;
   LastWeekendAction = reason;
   LastWeekendActionTimeText =
      TRE_ExecutionTimeToText(TimeCurrent());
   TRE_LogExecutionOnce(reason);

   if(signalBar != WeekendLastBlockedSignalBar)
   {
      WeekendLastBlockedSignalBar = signalBar;
      TRE_RegisterWeekendAudit(
         "BLOCK", reason,
         "RuleName=WeekendProtection;Decision=BLOCK;Reason=" + reason);
   }
   return true;
}

bool TRE_CloseWeekendPosition(string symbol,
                              ulong ticket,
                              long identifier)
{
   // Weekend management repeats the existing tester-only safety contract.
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      !TRE_IsStrategyTester() ||
      !EnableWeekendProtection ||
      !TRE_IsWeekendProtectionTime(WeekendForceCloseHour))
   {
      return false;
   }

   long positionType = PositionGetInteger(POSITION_TYPE);
   string direction =
      (positionType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   datetime openTime =
      (datetime)PositionGetInteger(POSITION_TIME);
   datetime closeTime = TimeCurrent();
   double profit = PositionGetDouble(POSITION_PROFIT);
   int holdingMinutes =
      (int)MathMax(0, (long)(closeTime - openTime) / 60);

   TREBacktestTrade.SetExpertMagicNumber((ulong)BacktestMagicNumber);
   TREBacktestTrade.SetTypeFillingBySymbol(symbol);
   TREBacktestTrade.SetAsyncMode(false);
   ResetLastError();

   // Repeat every condition immediately before the trade operation.
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0 ||
      !EnableWeekendProtection ||
      !TRE_IsWeekendProtectionTime(WeekendForceCloseHour))
   {
      return false;
   }

   bool requestSent = TREBacktestTrade.PositionClose(ticket);
   int lastError = GetLastError();
   uint retcode = TREBacktestTrade.ResultRetcode();
   string description = TREBacktestTrade.ResultRetcodeDescription();
   bool accepted = requestSent &&
                   (retcode == TRADE_RETCODE_DONE ||
                    retcode == TRADE_RETCODE_DONE_PARTIAL);

   ExecutionLastTradeRetcode = IntegerToString((int)retcode) +
                               " / " + description;
   ExecutionLastErrorText = IntegerToString(lastError);

   if(!accepted)
   {
      WeekendLastCloseResultText = "FAILED";
      LastWeekendAction = "CLOSE FAILED";
      LastWeekendActionTimeText =
         TRE_ExecutionTimeToText(closeTime);
      LastExecutionAction = "WEEKEND CLOSE FAILED";
      LastExecutionReason = description;
      Print("[WEEKEND_PROTECTION] Ticket=", (long)ticket,
            " Symbol=", symbol,
            " Action=CLOSE_FAILED",
            " Retcode=", (int)retcode,
            " Error=", lastError,
            " Reason=", description);
      return false;
   }

   ulong closeDeal = TREBacktestTrade.ResultDeal();
   if(closeDeal > 0 && HistoryDealSelect(closeDeal))
      profit = HistoryDealGetDouble(closeDeal, DEAL_PROFIT);

   string reason = "CLOSE_WEEKEND_PROTECTION";
   WeekendLastClosedPositionIdentifier = identifier;
   WeekendLastCloseResultText = "OK";
   LastWeekendAction = reason;
   LastWeekendActionTimeText =
      TRE_ExecutionTimeToText(closeTime);
   LastExecutionAction = "WEEKEND CLOSED";
   LastExecutionReason = reason;
   string detail =
      "Ticket=" + IntegerToString((long)ticket) +
      ";Symbol=" + symbol +
      ";Direction=" + direction +
      ";OpenTime=" + TRE_ExecutionTimeToText(openTime) +
      ";CloseTime=" + TRE_ExecutionTimeToText(closeTime) +
      ";Profit=" + DoubleToString(profit, 2) +
      ";HoldingMinutes=" + IntegerToString(holdingMinutes) +
      ";Reason=" + reason;
   TRE_RegisterWeekendAudit("CLOSE", reason, detail);
   Print("[WEEKEND_PROTECTION] Ticket=", (long)ticket,
         " Symbol=", symbol,
         " Direction=", direction,
         " OpenTime=", TRE_ExecutionTimeToText(openTime),
         " CloseTime=", TRE_ExecutionTimeToText(closeTime),
         " Profit=", DoubleToString(profit, 2),
         " HoldingMinutes=", holdingMinutes,
         " Reason=", reason);
   return true;
}

bool TRE_ManageWeekendProtection(string symbol)
{
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      !TRE_IsStrategyTester() ||
      !EnableWeekendProtection ||
      !TRE_IsWeekendProtectionTime(WeekendForceCloseHour))
   {
      return false;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         PositionGetString(POSITION_SYMBOL) != symbol ||
         PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
      {
         continue;
      }

      long identifier = PositionGetInteger(POSITION_IDENTIFIER);
      if(TRE_CloseWeekendPosition(symbol, ticket, identifier))
         return true;

      // Retry the first eligible position on the next tick after a failure.
      return false;
   }
   return false;
}

int TRE_BarsBetween(string symbol,
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

int TRE_CalculateHoldingBars(string symbol,
                             datetime openTime,
                             datetime endTime,
                             ENUM_TIMEFRAMES &holdingTF)
{
   holdingTF = ExecutionTF;
   int barsHeld = TRE_BarsBetween(symbol, ExecutionTF, openTime, endTime);

   if(barsHeld >= 0)
      return barsHeld;

   holdingTF = EntryTF;
   barsHeld = TRE_BarsBetween(symbol, EntryTF, openTime, endTime);

   return (barsHeld >= 0) ? barsHeld : 0;
}

void TRE_RefreshTimeoutState(string symbol)
{
   EffectiveBacktestMaxHoldingBars = (int)MathMax(1,
                                                   BacktestMaxHoldingBars);
   TimeoutEnabledText = UseBacktestMaxHoldingBars ? "ON" : "OFF";
   TimeoutMaxHoldingBarsText =
      IntegerToString(EffectiveBacktestMaxHoldingBars);
   TimeoutHoldingTFText = TimeframeToText(ExecutionTF);
   TimeoutPositionOpenTimeText = "N/A";
   TimeoutCurrentBarsHeld = 0;
   TimeoutCurrentBarsHeldText = "0";
   TradeManagementSummaryText = UseBacktestMaxHoldingBars
                                ? "Timeout ON " +
                                  TimeoutMaxHoldingBarsText + " bars"
                                : "Timeout OFF";

   if(!UseBacktestMaxHoldingBars)
   {
      TimeoutStatusText = "OFF";
      return;
   }

   bool positionFound = false;
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0 ||
         PositionGetString(POSITION_SYMBOL) != symbol ||
         PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
      {
         continue;
      }

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      ENUM_TIMEFRAMES holdingTF = ExecutionTF;
      int barsHeld = TRE_CalculateHoldingBars(symbol,
                                              openTime,
                                              TimeCurrent(),
                                              holdingTF);

      if(!positionFound || barsHeld > TimeoutCurrentBarsHeld)
      {
         positionFound = true;
         TimeoutCurrentBarsHeld = barsHeld;
         TimeoutCurrentBarsHeldText = IntegerToString(barsHeld);
         TimeoutPositionOpenTimeText =
            TRE_ExecutionTimeToText(openTime);
         TimeoutHoldingTFText = TimeframeToText(holdingTF);
      }
   }

   if(!positionFound)
   {
      TimeoutStatusText = (TimeoutLastCloseResultText == "OK")
                          ? "CLOSED"
                          : "NO POSITION";
      return;
   }

   TimeoutStatusText =
      (TimeoutCurrentBarsHeld >= EffectiveBacktestMaxHoldingBars)
      ? "CLOSE REQUIRED"
      : "OK";
}

bool TRE_CloseTimedOutPosition(string symbol,
                               ulong ticket,
                               long identifier,
                               int barsHeld)
{
   // Timeout management has its own explicit safety gate in addition to
   // the normal execution guard.
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      !TRE_IsStrategyTester() ||
      !UseBacktestMaxHoldingBars)
   {
      return false;
   }

   TREBacktestTrade.SetExpertMagicNumber((ulong)BacktestMagicNumber);
   TREBacktestTrade.SetTypeFillingBySymbol(symbol);
   TREBacktestTrade.SetAsyncMode(false);
   ResetLastError();

   // Repeat every safety condition immediately before the close request.
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0 ||
      !UseBacktestMaxHoldingBars)
   {
      return false;
   }

   bool requestSent = TREBacktestTrade.PositionClose(ticket);
   int lastError = GetLastError();
   uint retcode = TREBacktestTrade.ResultRetcode();
   string description = TREBacktestTrade.ResultRetcodeDescription();
   bool accepted = requestSent &&
                   (retcode == TRADE_RETCODE_DONE ||
                    retcode == TRADE_RETCODE_DONE_PARTIAL);

   TimeoutLastTicketText = IntegerToString((long)ticket);
   TimeoutLastReasonText = "TRE_TIMEOUT_EXIT";
   ExecutionLastTradeRetcode = IntegerToString((int)retcode) +
                               " / " + description;
   ExecutionLastErrorText = IntegerToString(lastError);

   if(accepted)
   {
      TimeoutLastPositionIdentifier = identifier;
      TimeoutLastCloseResultText = "OK";
      TimeoutStatusText = "CLOSED";
      LastExecutionAction = "TIMEOUT CLOSED";
      LastExecutionReason = "TRE_TIMEOUT_EXIT";
      Print("TRE Timeout Exit: ticket=", (long)ticket,
            " barsHeld=", barsHeld,
            " maxBars=", EffectiveBacktestMaxHoldingBars,
            " holdingTF=", TimeoutHoldingTFText);
      return true;
   }

   TimeoutLastCloseResultText = "FAILED";
   TimeoutStatusText = "FAILED";
   LastExecutionAction = "TIMEOUT FAILED";
   LastExecutionReason = description;
   Print("TRE Timeout Exit Failed: ticket=", (long)ticket,
         " retcode=", (int)retcode,
         " reason=", description,
         " lastError=", lastError);
   return false;
}

bool TRE_ManageBacktestTimeout(string symbol)
{
   if(ExecutionMode != TRE_BACKTEST_ONLY ||
      !TRE_IsStrategyTester() ||
      !UseBacktestMaxHoldingBars)
   {
      return false;
   }

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0 ||
         PositionGetString(POSITION_SYMBOL) != symbol ||
         PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
      {
         continue;
      }

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      long identifier = PositionGetInteger(POSITION_IDENTIFIER);
      ENUM_TIMEFRAMES holdingTF = ExecutionTF;
      int barsHeld = TRE_CalculateHoldingBars(symbol,
                                              openTime,
                                              TimeCurrent(),
                                              holdingTF);
      TimeoutHoldingTFText = TimeframeToText(holdingTF);

      if(barsHeld < EffectiveBacktestMaxHoldingBars)
         continue;

      if(TRE_CloseTimedOutPosition(symbol,
                                   ticket,
                                   identifier,
                                   barsHeld))
      {
         return true;
      }

      // Alpha 0.9 manages at most one timeout candidate per engine cycle.
      return false;
   }

   return false;
}

int TRE_VolumeDigits(double step)
{
   for(int digits = 0; digits <= 8; digits++)
   {
      if(MathAbs(step - NormalizeDouble(step, digits)) < 0.000000001)
         return digits;
   }

   return 8;
}

void TRE_ReadSymbolConstraints(string symbol)
{
   ExecutionVolumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   ExecutionVolumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   ExecutionVolumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   ExecutionTickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   ExecutionTickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   ExecutionStopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   ExecutionFreezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   ExecutionDigits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   ExecutionPoint = SymbolInfoDouble(symbol, SYMBOL_POINT);
}

double TRE_NormalizeVolume(double requestedLot)
{
   ExecutionRequestedLot = requestedLot;
   ExecutionNormalizedLot = 0;
   ExecutionLotValidationText = "INVALID";
   ExecutionLotReasonText = "Invalid symbol volume constraints";
   ExecutionLotSummaryValueText = DoubleToString(requestedLot, 2) +
                                  " -> N/A";
   ExecutionLotSummaryReasonText = "Invalid broker volume limits";

   if(requestedLot <= 0 ||
      ExecutionVolumeMin <= 0 ||
      ExecutionVolumeMax < ExecutionVolumeMin ||
      ExecutionVolumeStep <= 0)
   {
      return 0;
   }

   double clampedLot = MathMax(ExecutionVolumeMin,
                               MathMin(ExecutionVolumeMax, requestedLot));
   double stepCount = MathRound((clampedLot - ExecutionVolumeMin) /
                                ExecutionVolumeStep);
   double normalizedLot = ExecutionVolumeMin +
                          (stepCount * ExecutionVolumeStep);
   normalizedLot = MathMax(ExecutionVolumeMin,
                           MathMin(ExecutionVolumeMax, normalizedLot));
   normalizedLot = NormalizeDouble(normalizedLot,
                                   TRE_VolumeDigits(ExecutionVolumeStep));

   ExecutionNormalizedLot = normalizedLot;

   if(requestedLot < ExecutionVolumeMin)
   {
      ExecutionLotValidationText = "ADJUSTED";
      ExecutionLotReasonText = "Raised to symbol minimum volume";
      ExecutionLotSummaryValueText =
         DoubleToString(requestedLot, 2) + " -> " +
         DoubleToString(normalizedLot, 2);
      ExecutionLotSummaryReasonText =
         "Broker minimum " + DoubleToString(ExecutionVolumeMin, 2);
   }
   else if(requestedLot > ExecutionVolumeMax)
   {
      ExecutionLotValidationText = "ADJUSTED";
      ExecutionLotReasonText = "Reduced to symbol maximum volume";
      ExecutionLotSummaryValueText =
         DoubleToString(requestedLot, 2) + " -> " +
         DoubleToString(normalizedLot, 2);
      ExecutionLotSummaryReasonText =
         "Broker maximum " + DoubleToString(ExecutionVolumeMax, 2);
   }
   else if(MathAbs(requestedLot - normalizedLot) > 0.000000001)
   {
      ExecutionLotValidationText = "ADJUSTED";
      ExecutionLotReasonText = "Rounded to symbol volume step";
      ExecutionLotSummaryValueText =
         DoubleToString(requestedLot, 2) + " -> " +
         DoubleToString(normalizedLot, 2);
      ExecutionLotSummaryReasonText =
         "Broker step " + DoubleToString(ExecutionVolumeStep, 2);
   }
   else
   {
      ExecutionLotValidationText = "OK";
      ExecutionLotReasonText = "OK";
      ExecutionLotSummaryValueText = DoubleToString(normalizedLot, 2);
      ExecutionLotSummaryReasonText = "Broker accepted";
   }

   if(ExecutionLotValidationText == "ADJUSTED")
   {
      string logMessage = "TRE Volume normalized: requested=" +
                          DoubleToString(requestedLot, 2) +
                          " normalized=" + DoubleToString(normalizedLot, 2) +
                          " min=" + DoubleToString(ExecutionVolumeMin, 2) +
                          " step=" + DoubleToString(ExecutionVolumeStep, 2);
      static string previousVolumeLog = "";

      if(logMessage != previousVolumeLog)
      {
         previousVolumeLog = logMessage;
         Print(logMessage);
      }
   }

   return normalizedLot;
}

bool TRE_PrepareStopDistances()
{
   ExecutionRequestedSLPoints = BacktestSLPoints;
   ExecutionRequestedTPPoints = BacktestTPPoints;
   ExecutionEffectiveSLPoints = 0;
   ExecutionEffectiveTPPoints = 0;
   ExecutionSLTPValidationText = "INVALID";

   if(ExecutionPoint <= 0 ||
      BacktestSLPoints <= 0 ||
      BacktestTPPoints <= 0 ||
      ExecutionStopsLevel < 0)
   {
      return false;
   }

   double minimumPoints = (double)ExecutionStopsLevel + 10.0;
   ExecutionEffectiveSLPoints = MathMax(BacktestSLPoints, minimumPoints);
   ExecutionEffectiveTPPoints = MathMax(BacktestTPPoints, minimumPoints);

   if(ExecutionEffectiveSLPoints != BacktestSLPoints ||
      ExecutionEffectiveTPPoints != BacktestTPPoints)
   {
      ExecutionSLTPValidationText = "ADJUSTED";
   }
   else
   {
      ExecutionSLTPValidationText = "OK";
   }

   return true;
}

double TRE_NormalizeTradePrice(double price)
{
   if(ExecutionTickSize > 0)
      price = MathRound(price / ExecutionTickSize) * ExecutionTickSize;

   return NormalizeDouble(price, ExecutionDigits);
}

int TRE_CountBacktestPositions(string symbol)
{
   int count = 0;
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
         continue;

      count++;
   }

   return count;
}

bool TRE_PositionRulesAllow(string symbol,
                            ENTRY_ACTION action,
                            string &reason)
{
   int buyCount = 0;
   int sellCount = 0;
   int total = PositionsTotal();

   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
         continue;

      long positionType = PositionGetInteger(POSITION_TYPE);

      if(positionType == POSITION_TYPE_BUY)
         buyCount++;
      else if(positionType == POSITION_TYPE_SELL)
         sellCount++;
   }

   ExecutionPositionCount = buyCount + sellCount;

   if(BacktestMaxPositionsPerSymbol <= 0)
   {
      reason = "Max positions configuration is invalid";
      return false;
   }

   if(ExecutionPositionCount >= BacktestMaxPositionsPerSymbol)
   {
      reason = "Max positions reached";
      return false;
   }

   bool isBuy = (action == ACTION_BUY_READY);
   int sameDirectionCount = isBuy ? buyCount : sellCount;
   int oppositeDirectionCount = isBuy ? sellCount : buyCount;

   if(sameDirectionCount > 0 && !BacktestAllowSameDirectionAdd)
   {
      reason = "Same direction add is disabled";
      return false;
   }

   if(oppositeDirectionCount > 0 && !BacktestAllowOppositePosition)
   {
      reason = "Opposite position is disabled";
      return false;
   }

   reason = "OK";
   return true;
}

void TRE_RefreshExecutionState(string symbol)
{
   TRE_RefreshWeekendProtectionState();
   ExecutionModeText = TRE_ExecutionModeToText();
   ExecutionRuntimeText = TRE_IsStrategyTester() ? "Strategy Tester" : "Live Chart";
   ExecutionAllowedText = TRE_CanExecute() ? "YES" : "NO";
   ExecutionOneTradePerBarText = BacktestOneTradePerBar ? "ON" : "OFF";
   ExecutionLastSignalBarText = TRE_ExecutionTimeToText(ExecutionLastSignalBarTime);
   ExecutionLastBarText = TRE_ExecutionTimeToText(ExecutionLastBarTime);
   TRE_RefreshTimeoutState(symbol);

   TRE_ReadSymbolConstraints(symbol);
   TRE_NormalizeVolume(BacktestFixedLot);
   TRE_PrepareStopDistances();
   ExecutionPositionCount = TRE_CountBacktestPositions(symbol);
   ExecutionCanExecuteText = (TRE_CanExecute() &&
                              ExecutionNormalizedLot > 0 &&
                              ExecutionLotValidationText != "INVALID" &&
                              ExecutionSLTPValidationText != "INVALID")
                             ? "YES"
                             : "NO";

   if(BacktestMaxPositionsPerSymbol <= 0 ||
      ExecutionPositionCount >= BacktestMaxPositionsPerSymbol)
   {
      ExecutionCanExecuteText = "NO";
   }

   datetime currentBarTime = iTime(symbol, _Period, 0);

   if(BacktestOneTradePerBar &&
      currentBarTime > 0 &&
      ExecutionLastBarTime == currentBarTime)
   {
      ExecutionCanExecuteText = "NO";
   }

   if(ExecutionMode == TRE_DISPLAY_ONLY)
   {
      LastExecutionAction = "NONE";
      LastExecutionReason = "Display Only mode";
      TRE_LogExecutionOnce("TRE Execution Disabled: Display Only mode");
      return;
   }

   if(ExecutionMode != TRE_BACKTEST_ONLY)
   {
      LastExecutionAction = "BLOCKED";
      LastExecutionReason = "Mode reserved; Display Only behavior";
      TRE_LogExecutionOnce("TRE Execution Disabled: Selected mode is reserved");
      return;
   }

   if(!TRE_IsStrategyTester())
   {
      LastExecutionAction = "BLOCKED";
      LastExecutionReason = "Not running in Strategy Tester";
      TRE_LogExecutionOnce("TRE Execution Blocked: Not running in Strategy Tester");
   }
}

bool TRE_OrderCandidatePreflightAllows(string symbol)
{
   if(ExecutionNormalizedLot <= 0 ||
      ExecutionLotValidationText == "INVALID")
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "Invalid normalized volume";
      TRE_LogExecutionOnce("TRE Order Failed: Invalid normalized volume");
      return false;
   }

   if(ExecutionSLTPValidationText == "INVALID")
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "Invalid SL/TP configuration";
      TRE_LogExecutionOnce("TRE Order Failed: Invalid SL/TP configuration");
      return false;
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick) || tick.ask <= 0 || tick.bid <= 0)
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "No valid market price";
      TRE_LogExecutionOnce("TRE Order Failed: No valid market price");
      return false;
   }
   return true;
}

bool TRE_SendBacktestOrder(string symbol, ENTRY_ACTION action)
{
   // This guard is intentionally repeated immediately before every order path.
   if(!TRE_CanExecute())
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "BLOCKED";
      LastExecutionReason = "Execution safety guard rejected order";
      TRE_LogExecutionOnce("TRE Execution Blocked: Safety guard rejected order");
      return false;
   }

   if(ExecutionNormalizedLot <= 0 ||
      ExecutionLotValidationText == "INVALID")
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "Invalid normalized volume";
      TRE_LogExecutionOnce("TRE Order Failed: Invalid normalized volume");
      return false;
   }

   if(ExecutionSLTPValidationText == "INVALID")
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "Invalid SL/TP configuration";
      TRE_LogExecutionOnce("TRE Order Failed: Invalid SL/TP configuration");
      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(symbol, tick) || tick.ask <= 0 || tick.bid <= 0)
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "No valid market price";
      TRE_LogExecutionOnce("TRE Order Failed: No valid market price");
      return false;
   }

   bool isBuy = (action == ACTION_BUY_READY);
   string side = isBuy ? "BUY" : "SELL";
   double entry = TRE_NormalizeTradePrice(isBuy ? tick.ask : tick.bid);
   double stopLoss = TRE_NormalizeTradePrice(
      isBuy ? entry - (ExecutionEffectiveSLPoints * ExecutionPoint)
            : entry + (ExecutionEffectiveSLPoints * ExecutionPoint));
   double takeProfit = TRE_NormalizeTradePrice(
      isBuy ? entry + (ExecutionEffectiveTPPoints * ExecutionPoint)
            : entry - (ExecutionEffectiveTPPoints * ExecutionPoint));

   ExecutionLastOrderType = side;
   ExecutionLastOrderTicket = "N/A";
   ExecutionLastOrderLot = DoubleToString(ExecutionNormalizedLot, 2);
   ExecutionLastOrderEntry = DoubleToString(entry, ExecutionDigits);
   ExecutionLastOrderSL = DoubleToString(stopLoss, ExecutionDigits);
   ExecutionLastOrderTP = DoubleToString(takeProfit, ExecutionDigits);
   ExecutionLastTradeRetcode = "N/A";
   ExecutionLastErrorText = "0";
   // Capture raw features only after every entry filter has passed and
   // immediately before the synchronous Buy/Sell request.
   MarketSnapshotCapture(symbol, action);
   MarketSnapshotBindExecution(action,
                               ExecutionNormalizedLot,
                               entry);

   TREBacktestTrade.SetExpertMagicNumber((ulong)BacktestMagicNumber);
   TREBacktestTrade.SetTypeFillingBySymbol(symbol);
   ResetLastError();

   bool requestSent = false;

   if(isBuy)
   {
      if(!TRE_CanExecute())
      {
         MarketSnapshotCancelExecution();
         return false;
      }

      requestSent = TREBacktestTrade.Buy(ExecutionNormalizedLot,
                                         symbol,
                                         entry,
                                         stopLoss,
                                         takeProfit,
                                         BacktestOrderComment);
   }
   else
   {
      if(!TRE_CanExecute())
      {
         MarketSnapshotCancelExecution();
         return false;
      }

      requestSent = TREBacktestTrade.Sell(ExecutionNormalizedLot,
                                          symbol,
                                          entry,
                                          stopLoss,
                                          takeProfit,
                                          BacktestOrderComment);
   }

   int lastError = GetLastError();
   uint retcode = TREBacktestTrade.ResultRetcode();
   string retcodeDescription = TREBacktestTrade.ResultRetcodeDescription();
   bool accepted = requestSent &&
                   (retcode == TRADE_RETCODE_DONE ||
                    retcode == TRADE_RETCODE_DONE_PARTIAL ||
                    retcode == TRADE_RETCODE_PLACED);

   ExecutionLastTradeRetcode = IntegerToString((int)retcode) +
                               " / " + retcodeDescription;
   ExecutionLastErrorText = IntegerToString(lastError);

   if(accepted)
   {
      ulong ticket = TREBacktestTrade.ResultOrder();

      if(ticket == 0)
         ticket = TREBacktestTrade.ResultDeal();

      ExecutionLastOrderTicket = IntegerToString((long)ticket);
      LastExecutionAction = side + " SENT";
      LastExecutionReason = "Backtest order sent successfully";
      AdaptiveV1RecordExecutedTrade(symbol, action, CurrentZone);
      MarketSnapshotCommitExecution();
      bool adaptiveRegistered =
         AdaptiveLossClusterRegisterOpenPosition(
            symbol, action, CurrentZone);
      if(AdaptiveV1Enabled() && !adaptiveRegistered)
      {
         Print("[ADAPTIVE_LOSS_CLUSTER] action=TRACK_FAILED symbol=",
               symbol,
               " reason=Opened position was not available for tracking");
      }
      if(!UseResearchDB || !ResearchDBWriteTrades)
         MarketSnapshotReleaseAdaptiveOnly();
      ExecutionPositionCount = TRE_CountBacktestPositions(symbol);

      if(ExecutionPositionCount >= BacktestMaxPositionsPerSymbol)
         ExecutionCanExecuteText = "NO";

      Print("TRE Backtest Order Sent: ", side,
            " lot=", DoubleToString(ExecutionNormalizedLot, 2),
            " entry=", DoubleToString(entry, ExecutionDigits),
            " sl=", DoubleToString(stopLoss, ExecutionDigits),
            " tp=", DoubleToString(takeProfit, ExecutionDigits));
      return true;
   }

   LastExecutionAction = "FAILED";
   LastExecutionReason = retcodeDescription;
   MarketSnapshotCancelExecution();
   ExecutionCanExecuteText = "NO";
   Print("TRE Order Failed: retcode=", IntegerToString((int)retcode),
         " reason=", retcodeDescription,
         " lastError=", IntegerToString(lastError));
   return false;
}

void ExecutionEngine(string symbol)
{
   TRE_RefreshExecutionState(symbol);

   bool weekendClosed = TRE_ManageWeekendProtection(symbol);
   if(weekendClosed)
   {
      TRE_RefreshExecutionState(symbol);
      // Preserve close attribution; a ready signal will be blocked next tick.
      return;
   }

   bool weekendCloseWindow =
      (EnableWeekendProtection &&
       TRE_IsWeekendProtectionTime(WeekendForceCloseHour));
   bool timeoutClosed =
      weekendCloseWindow ? false : TRE_ManageBacktestTimeout(symbol);

   if(timeoutClosed)
   {
      TRE_RefreshExecutionState(symbol);
      // Make a timeout loss visible to the adaptive filter before re-entry.
      AdaptiveCaptureClosedTrades(symbol);
   }

   if(!TRE_CanExecute())
      return;

   if(ActionState != ACTION_BUY_READY && ActionState != ACTION_SELL_READY)
   {
      if(LastExecutionAction == "NONE")
         LastExecutionReason = "Decision is " + ActionToText(ActionState);

      return;
   }

   datetime signalBarTime = iTime(symbol, _Period, 0);
   ExecutionLastSignalBarTime = signalBarTime;
   ExecutionLastSignalBarText = TRE_ExecutionTimeToText(signalBarTime);

   if(TRE_WeekendEntryBlocked(signalBarTime))
      return;

   string positionReason = "";

   if(!TRE_PositionRulesAllow(symbol, ActionState, positionReason))
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "BLOCKED";
      LastExecutionReason = positionReason;
      TRE_LogExecutionOnce("TRE Execution Blocked: " + positionReason);
      return;
   }

   if(BacktestOneTradePerBar &&
      signalBarTime > 0 &&
      ExecutionLastBarTime == signalBarTime)
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "BLOCKED";
      LastExecutionReason = "One trade per bar limit";
      TRE_LogExecutionOnce("TRE Execution Blocked: One trade per bar limit");
      return;
   }

   if(signalBarTime <= 0)
   {
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "FAILED";
      LastExecutionReason = "Signal bar time unavailable";
      TRE_LogExecutionOnce("TRE Order Failed: Signal bar time unavailable");
      return;
   }

   if(!TRE_OrderCandidatePreflightAllows(symbol))
      return;

   // All normal strategy, execution-risk, weekend, position and per-bar
   // guards have passed. Without Adaptive V1 this is an order candidate.
   string adaptiveReason = "";
   if(!AdaptiveLossClusterAllowsEntry(
         symbol, ActionState, adaptiveReason))
   {
      AdaptiveShadowOpen(
         symbol, ActionState, CurrentZone,
         AdaptiveCurrentEpisodeID,
         AdaptiveV1LastBlockedAuditSerial);
      ExecutionCanExecuteText = "NO";
      LastExecutionAction = "BLOCKED";
      LastExecutionReason = adaptiveReason;
      TRE_LogExecutionOnce(
         "TRE Execution Blocked: " + adaptiveReason);
      return;
   }

   // Record the attempt before sending so a failed request cannot repeat each tick.
   ExecutionLastBarTime = signalBarTime;
   ExecutionLastBarText = TRE_ExecutionTimeToText(signalBarTime);
   TRE_SendBacktestOrder(symbol, ActionState);
}

#endif
