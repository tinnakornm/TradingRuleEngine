//+------------------------------------------------------------------+
//| engine/market_snapshot_engine.mqh                                |
//| Immutable pre-entry market feature capture                       |
//+------------------------------------------------------------------+
#ifndef TRE_MARKET_SNAPSHOT_ENGINE_MQH
#define TRE_MARKET_SNAPSHOT_ENGINE_MQH

struct TRE_TradeMarketSnapshot
{
   long tradeId;
   int magicNumber;
   string symbol;
   int timeframe;
   datetime openTime;
   int direction;
   double lot;
   double entryPrice;

   int currentSwingDirection;
   int currentSwingDepth;
   double currentSwingLength;
   int previousSwingDepth;
   double previousSwingLength;
   int currentZone;
   double zoneScore;
   double zoneWidth;
   double distanceToZoneCenter;
   double distanceToZoneEdge;

   double ema20;
   double ema50;
   double ema100;
   double ema200;
   double ema20Slope;
   double ema50Slope;
   double ema100Slope;
   double ema200Slope;
   int ema20Above50;
   int ema50Above100;
   int ema100Above200;
   int emaAlignmentScore;
   double distanceEMA20_50;
   double distanceEMA50_100;
   double distanceEMA100_200;

   double atr;
   double atrPercent;
   double trueRange;
   double averageTrueRangeRatio;
   double dailyRange;
   double currentCandleRange;

   double adx;
   double plusDI;
   double minusDI;
   double trendStrength;
   double trendAcceleration;

   int pressureState;
   double pressureScore;
   double pressureStrength;
   int pressureDirection;
   int pressureAge;

   int dayOfWeek;
   int hour;
   int tradingSession;
   int isHoliday;
   int isWeekend;

   double spread;
   double spreadPercentATR;
   double tickSize;
   double pointValue;
   int digits;

   double currentOpen;
   double currentHigh;
   double currentLow;
   double currentClose;
   double bodySize;
   double upperShadow;
   double lowerShadow;
   int bullish;
   int bearish;
   double dojiScore;

   double m15EMA50;
   double h1EMA50;
   double h4EMA50;
   double d1EMA50;
   double h1ATR;
   double h4ATR;
   double d1ATR;

   int hasStrongTrend;
   int hasHighVolatility;
   int nearZoneCenter;
   int nearZoneEdge;
   int pressureConfirmed;
   int emaFullyAligned;
};

TRE_TradeMarketSnapshot TREPendingMarketSnapshot;
bool TREMarketSnapshotReady = false;
bool TREMarketSnapshotLocked = false;
int TREMarketSnapshotPressureAge = 0;
int TREMarketSnapshotLastPressureDirection = -1;
int TREMarketSnapshotLastPressureState = -1;
datetime TREMarketSnapshotLastPressureBar = 0;
string MarketSnapshotStatusText = "IDLE";
string MarketSnapshotLastCaptureTimeText = "N/A";
long MarketSnapshotLastTradeID = 0;

bool MarketSnapshotReadBuffer(int handle,
                              int buffer,
                              int shift,
                              double &value)
{
   value = 0;
   if(handle == INVALID_HANDLE)
      return false;
   double data[1];
   if(CopyBuffer(handle, buffer, shift, 1, data) != 1)
      return false;
   value = data[0];
   return MathIsValidNumber(value);
}

bool MarketSnapshotReadEMA(string symbol,
                           ENUM_TIMEFRAMES timeframe,
                           int period,
                           double &current,
                           double &previous)
{
   current = 0;
   previous = 0;
   int handle = iMA(symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;
   bool valid =
      MarketSnapshotReadBuffer(handle, 0, 0, current) &&
      MarketSnapshotReadBuffer(handle, 0, 1, previous);
   IndicatorRelease(handle);
   return valid;
}

bool MarketSnapshotReadATR(string symbol,
                           ENUM_TIMEFRAMES timeframe,
                           int period,
                           double &value)
{
   value = 0;
   int handle = iATR(symbol, timeframe, (int)MathMax(2, period));
   if(handle == INVALID_HANDLE)
      return false;
   bool valid = MarketSnapshotReadBuffer(handle, 0, 0, value);
   IndicatorRelease(handle);
   return valid;
}

void MarketSnapshotObservePressure(string symbol)
{
   datetime bar = iTime(symbol, EntryTF, 0);
   int direction = (int)PressureDirection;
   int state = (int)PressureLevel;
   if(TREMarketSnapshotLastPressureDirection < 0 ||
      direction != TREMarketSnapshotLastPressureDirection ||
      state != TREMarketSnapshotLastPressureState)
   {
      TREMarketSnapshotPressureAge = 0;
      TREMarketSnapshotLastPressureDirection = direction;
      TREMarketSnapshotLastPressureState = state;
      TREMarketSnapshotLastPressureBar = bar;
      return;
   }
   if(bar > 0 && bar != TREMarketSnapshotLastPressureBar)
   {
      TREMarketSnapshotPressureAge++;
      TREMarketSnapshotLastPressureBar = bar;
   }
}

int MarketSnapshotTradingSession(int hour)
{
   if(hour >= 0 && hour < 7) return 0;   // Asian
   if(hour >= 7 && hour < 13) return 1;  // London
   if(hour >= 13 && hour < 21) return 2; // New York
   return 3;                             // After hours
}

int MarketSnapshotComparison(double left, double right)
{
   return (left > right) ? 1 : -1;
}

void MarketSnapshotCapture(string symbol, ENTRY_ACTION action)
{
   if(TREMarketSnapshotLocked ||
      !UseResearchDB ||
      !ResearchDBWriteTrades ||
      ExecutionMode != TRE_BACKTEST_ONLY ||
      MQLInfoInteger(MQL_TESTER) == 0)
      return;

   ZeroMemory(TREPendingMarketSnapshot);
   TREPendingMarketSnapshot.tradeId = 0;
   TREPendingMarketSnapshot.magicNumber = BacktestMagicNumber;
   TREPendingMarketSnapshot.symbol = symbol;
   TREPendingMarketSnapshot.timeframe = (int)EntryTF;
   TREPendingMarketSnapshot.openTime = TimeCurrent();
   TREPendingMarketSnapshot.direction =
      (action == ACTION_BUY_READY) ? 1 : -1;
   TREPendingMarketSnapshot.isHoliday = -1; // No holiday calendar is loaded.

   MqlTick tick;
   ZeroMemory(tick);
   SymbolInfoTick(symbol, tick);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double currentPrice =
      (action == ACTION_BUY_READY) ? tick.ask : tick.bid;
   TREPendingMarketSnapshot.entryPrice = currentPrice;

   // MARKET STRUCTURE: capture published swing/zone state without re-evaluation.
   TREPendingMarketSnapshot.currentSwingDepth =
      (int)MathMax(1, SwingDepth);
   TREPendingMarketSnapshot.previousSwingDepth =
      (int)MathMax(1, SwingDepth);
   if(StructureLastSwingHighBarIndex >= 0 &&
      (StructureLastSwingLowBarIndex < 0 ||
       StructureLastSwingHighBarIndex <
       StructureLastSwingLowBarIndex))
   {
      TREPendingMarketSnapshot.currentSwingDirection = -1;
      if(point > 0 && StructureLastSwingHigh > 0)
         TREPendingMarketSnapshot.currentSwingLength =
            MathAbs(currentPrice - StructureLastSwingHigh) / point;
   }
   else if(StructureLastSwingLowBarIndex >= 0)
   {
      TREPendingMarketSnapshot.currentSwingDirection = 1;
      if(point > 0 && StructureLastSwingLow > 0)
         TREPendingMarketSnapshot.currentSwingLength =
            MathAbs(currentPrice - StructureLastSwingLow) / point;
   }
   if(point > 0 &&
      StructureLastSwingHigh > 0 && StructureLastSwingLow > 0)
   {
      TREPendingMarketSnapshot.previousSwingLength =
         MathAbs(StructureLastSwingHigh -
                 StructureLastSwingLow) / point;
   }
   TREPendingMarketSnapshot.currentZone = CurrentZone;
   TREPendingMarketSnapshot.zoneScore = ZoneScore;
   TREPendingMarketSnapshot.zoneWidth = ZoneSize;
   if(CurrentZone >= 1 && CurrentZone <= TRE_ZONE_COUNT &&
      ZoneSize > 0)
   {
      double zoneLow = RangeLow + ((CurrentZone - 1) * ZoneSize);
      double zoneHigh = zoneLow + ZoneSize;
      double center = (zoneLow + zoneHigh) * 0.5;
      TREPendingMarketSnapshot.distanceToZoneCenter =
         MathAbs(currentPrice - center);
      TREPendingMarketSnapshot.distanceToZoneEdge =
         MathMin(MathAbs(currentPrice - zoneLow),
                 MathAbs(currentPrice - zoneHigh));
   }

   // EMA FEATURES: current forming EntryTF bar and one-bar raw slopes.
   double previous = 0;
   bool ema20Valid =
      MarketSnapshotReadEMA(symbol, EntryTF, 20,
                            TREPendingMarketSnapshot.ema20, previous);
   TREPendingMarketSnapshot.ema20Slope =
      TREPendingMarketSnapshot.ema20 - previous;
   bool ema50Valid =
      MarketSnapshotReadEMA(symbol, EntryTF, 50,
                            TREPendingMarketSnapshot.ema50, previous);
   TREPendingMarketSnapshot.ema50Slope =
      TREPendingMarketSnapshot.ema50 - previous;
   bool ema100Valid =
      MarketSnapshotReadEMA(symbol, EntryTF, 100,
                            TREPendingMarketSnapshot.ema100, previous);
   TREPendingMarketSnapshot.ema100Slope =
      TREPendingMarketSnapshot.ema100 - previous;
   bool ema200Valid =
      MarketSnapshotReadEMA(symbol, EntryTF, 200,
                            TREPendingMarketSnapshot.ema200, previous);
   TREPendingMarketSnapshot.ema200Slope =
      TREPendingMarketSnapshot.ema200 - previous;
   bool emaSetValid =
      ema20Valid && ema50Valid && ema100Valid && ema200Valid;
   if(emaSetValid)
   {
      TREPendingMarketSnapshot.ema20Above50 =
         (TREPendingMarketSnapshot.ema20 >
          TREPendingMarketSnapshot.ema50) ? 1 : 0;
      TREPendingMarketSnapshot.ema50Above100 =
         (TREPendingMarketSnapshot.ema50 >
          TREPendingMarketSnapshot.ema100) ? 1 : 0;
      TREPendingMarketSnapshot.ema100Above200 =
         (TREPendingMarketSnapshot.ema100 >
          TREPendingMarketSnapshot.ema200) ? 1 : 0;
      TREPendingMarketSnapshot.emaAlignmentScore =
         MarketSnapshotComparison(TREPendingMarketSnapshot.ema20,
                                  TREPendingMarketSnapshot.ema50) +
         MarketSnapshotComparison(TREPendingMarketSnapshot.ema50,
                                  TREPendingMarketSnapshot.ema100) +
         MarketSnapshotComparison(TREPendingMarketSnapshot.ema100,
                                  TREPendingMarketSnapshot.ema200);
      TREPendingMarketSnapshot.distanceEMA20_50 =
         MathAbs(TREPendingMarketSnapshot.ema20 -
                 TREPendingMarketSnapshot.ema50);
      TREPendingMarketSnapshot.distanceEMA50_100 =
         MathAbs(TREPendingMarketSnapshot.ema50 -
                 TREPendingMarketSnapshot.ema100);
      TREPendingMarketSnapshot.distanceEMA100_200 =
         MathAbs(TREPendingMarketSnapshot.ema100 -
                 TREPendingMarketSnapshot.ema200);
   }

   // CANDLE AND VOLATILITY: use the exact current EntryTF candle.
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, EntryTF, 0, 2, rates);
   if(copied >= 1)
   {
      TREPendingMarketSnapshot.currentOpen = rates[0].open;
      TREPendingMarketSnapshot.currentHigh = rates[0].high;
      TREPendingMarketSnapshot.currentLow = rates[0].low;
      TREPendingMarketSnapshot.currentClose = rates[0].close;
      TREPendingMarketSnapshot.currentCandleRange =
         rates[0].high - rates[0].low;
      TREPendingMarketSnapshot.bodySize =
         MathAbs(rates[0].close - rates[0].open);
      TREPendingMarketSnapshot.upperShadow =
         MathMax(0.0, rates[0].high -
                 MathMax(rates[0].open, rates[0].close));
      TREPendingMarketSnapshot.lowerShadow =
         MathMax(0.0, MathMin(rates[0].open, rates[0].close) -
                 rates[0].low);
      TREPendingMarketSnapshot.bullish =
         (rates[0].close > rates[0].open) ? 1 : 0;
      TREPendingMarketSnapshot.bearish =
         (rates[0].close < rates[0].open) ? 1 : 0;
      TREPendingMarketSnapshot.dojiScore =
         (TREPendingMarketSnapshot.currentCandleRange > 0)
         ? 1.0 - (TREPendingMarketSnapshot.bodySize /
                  TREPendingMarketSnapshot.currentCandleRange)
         : 0;
      double previousClose =
         (copied >= 2) ? rates[1].close : rates[0].close;
      TREPendingMarketSnapshot.trueRange =
         MathMax(rates[0].high - rates[0].low,
                 MathMax(MathAbs(rates[0].high - previousClose),
                         MathAbs(rates[0].low - previousClose)));
   }
   MarketSnapshotReadATR(symbol, EntryTF, ATRPeriod,
                         TREPendingMarketSnapshot.atr);
   TREPendingMarketSnapshot.atrPercent =
      (TREPendingMarketSnapshot.currentClose > 0)
      ? (TREPendingMarketSnapshot.atr /
         TREPendingMarketSnapshot.currentClose) * 100.0
      : 0;
   TREPendingMarketSnapshot.averageTrueRangeRatio =
      (TREPendingMarketSnapshot.atr > 0)
      ? TREPendingMarketSnapshot.trueRange /
        TREPendingMarketSnapshot.atr
      : 0;
   double dailyHigh = iHigh(symbol, PERIOD_D1, 0);
   double dailyLow = iLow(symbol, PERIOD_D1, 0);
   TREPendingMarketSnapshot.dailyRange =
      (dailyHigh > dailyLow) ? dailyHigh - dailyLow : 0;

   // TREND FEATURES: raw ADX and directional-index buffers.
   int adxHandle = iADX(symbol, EntryTF, 14);
   double previousADX = 0;
   MarketSnapshotReadBuffer(
      adxHandle, 0, 0, TREPendingMarketSnapshot.adx);
   MarketSnapshotReadBuffer(adxHandle, 0, 1, previousADX);
   MarketSnapshotReadBuffer(
      adxHandle, 1, 0, TREPendingMarketSnapshot.plusDI);
   MarketSnapshotReadBuffer(
      adxHandle, 2, 0, TREPendingMarketSnapshot.minusDI);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   TREPendingMarketSnapshot.trendStrength =
      MathAbs(TREPendingMarketSnapshot.plusDI -
              TREPendingMarketSnapshot.minusDI);
   TREPendingMarketSnapshot.trendAcceleration =
      TREPendingMarketSnapshot.adx - previousADX;

   // PRESSURE: store enum IDs and raw scores, never text classifications.
   TREPendingMarketSnapshot.pressureState = (int)PressureLevel;
   TREPendingMarketSnapshot.pressureScore = PressureScore;
   TREPendingMarketSnapshot.pressureStrength =
      MathMax(BullishPressureScore, BearishPressureScore);
   TREPendingMarketSnapshot.pressureDirection =
      (int)PressureDirection;
   TREPendingMarketSnapshot.pressureAge =
      TREMarketSnapshotPressureAge;

   // SESSION: numeric weekday/hour/session; holiday remains unknown (-1).
   MqlDateTime serverTime;
   ZeroMemory(serverTime);
   if(TimeToStruct(TimeCurrent(), serverTime))
   {
      TREPendingMarketSnapshot.dayOfWeek = serverTime.day_of_week;
      TREPendingMarketSnapshot.hour = serverTime.hour;
      TREPendingMarketSnapshot.tradingSession =
         MarketSnapshotTradingSession(serverTime.hour);
      TREPendingMarketSnapshot.isWeekend =
         (serverTime.day_of_week == 0 ||
          serverTime.day_of_week == 6) ? 1 : 0;
   }

   // EXECUTION: point-based spread and broker symbol precision.
   TREPendingMarketSnapshot.spread =
      (point > 0) ? (tick.ask - tick.bid) / point : 0;
   TREPendingMarketSnapshot.spreadPercentATR =
      (TREPendingMarketSnapshot.atr > 0)
      ? ((tick.ask - tick.bid) /
         TREPendingMarketSnapshot.atr) * 100.0
      : 0;
   TREPendingMarketSnapshot.tickSize =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   TREPendingMarketSnapshot.pointValue = point;
   TREPendingMarketSnapshot.digits =
      (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   // MULTI TIMEFRAME: raw EMA50 and ATR values.
   MarketSnapshotReadEMA(symbol, PERIOD_M15, 50,
                         TREPendingMarketSnapshot.m15EMA50, previous);
   MarketSnapshotReadEMA(symbol, PERIOD_H1, 50,
                         TREPendingMarketSnapshot.h1EMA50, previous);
   MarketSnapshotReadEMA(symbol, PERIOD_H4, 50,
                         TREPendingMarketSnapshot.h4EMA50, previous);
   MarketSnapshotReadEMA(symbol, PERIOD_D1, 50,
                         TREPendingMarketSnapshot.d1EMA50, previous);
   MarketSnapshotReadATR(symbol, PERIOD_H1, ATRPeriod,
                         TREPendingMarketSnapshot.h1ATR);
   MarketSnapshotReadATR(symbol, PERIOD_H4, ATRPeriod,
                         TREPendingMarketSnapshot.h4ATR);
   MarketSnapshotReadATR(symbol, PERIOD_D1, ATRPeriod,
                         TREPendingMarketSnapshot.d1ATR);

   // QUALITY FLAGS: numeric flags derived only from this immutable payload.
   TREPendingMarketSnapshot.hasStrongTrend =
      (TREPendingMarketSnapshot.adx >= 25.0) ? 1 : 0;
   TREPendingMarketSnapshot.hasHighVolatility =
      (TREPendingMarketSnapshot.averageTrueRangeRatio >= 1.5) ? 1 : 0;
   TREPendingMarketSnapshot.nearZoneCenter =
      (ZoneSize > 0 &&
       TREPendingMarketSnapshot.distanceToZoneCenter <=
       ZoneSize * 0.10) ? 1 : 0;
   TREPendingMarketSnapshot.nearZoneEdge =
      (ZoneSize > 0 &&
       TREPendingMarketSnapshot.distanceToZoneEdge <=
       ZoneSize * 0.10) ? 1 : 0;
   bool pressureAligned =
      (action == ACTION_BUY_READY &&
       PressureDirection == PRESSURE_UP) ||
      (action == ACTION_SELL_READY &&
       PressureDirection == PRESSURE_DOWN);
   TREPendingMarketSnapshot.pressureConfirmed =
      (pressureAligned &&
       PressureScore >= EffectivePressureMediumThreshold) ? 1 : 0;
   TREPendingMarketSnapshot.emaFullyAligned =
      (emaSetValid &&
       MathAbs(TREPendingMarketSnapshot.emaAlignmentScore) == 3)
      ? 1 : 0;

   TREMarketSnapshotReady = true;
   MarketSnapshotStatusText = "CAPTURED_PRE_ENTRY";
   MarketSnapshotLastCaptureTimeText =
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
}

void MarketSnapshotEngine(string symbol)
{
   MarketSnapshotObservePressure(symbol);
}

void MarketSnapshotBindExecution(ENTRY_ACTION action,
                                 double lot,
                                 double entryPrice)
{
   if(!TREMarketSnapshotReady || TREMarketSnapshotLocked)
      return;
   TREPendingMarketSnapshot.direction =
      (action == ACTION_BUY_READY) ? 1 : -1;
   TREPendingMarketSnapshot.lot = lot;
   TREPendingMarketSnapshot.entryPrice = entryPrice;
   TREPendingMarketSnapshot.openTime = TimeCurrent();
}

void MarketSnapshotCommitExecution()
{
   if(!TREMarketSnapshotReady)
      return;
   TREMarketSnapshotLocked = true;
   MarketSnapshotStatusText = "LOCKED_PENDING_DB";
}

void MarketSnapshotCancelExecution()
{
   if(TREMarketSnapshotLocked)
      return;
   TREMarketSnapshotReady = false;
   MarketSnapshotStatusText = "ORDER_NOT_OPENED";
}

void MarketSnapshotConsume(long tradeId)
{
   MarketSnapshotLastTradeID = tradeId;
   TREMarketSnapshotReady = false;
   TREMarketSnapshotLocked = false;
   ZeroMemory(TREPendingMarketSnapshot);
   MarketSnapshotStatusText = "IMMUTABLE_STORED";
}

void MarketSnapshotReleaseAdaptiveOnly()
{
   TREMarketSnapshotReady = false;
   TREMarketSnapshotLocked = false;
   ZeroMemory(TREPendingMarketSnapshot);
   MarketSnapshotStatusText = "ADAPTIVE_PATTERN_CAPTURED";
}

#endif
