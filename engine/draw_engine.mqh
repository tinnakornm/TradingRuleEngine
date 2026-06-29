//+------------------------------------------------------------------+
//| engine/draw_engine.mqh                                           |
//| Draw zones and swing lines                                       |
//+------------------------------------------------------------------+
#ifndef TRE_DRAW_ENGINE_MQH
#define TRE_DRAW_ENGINE_MQH

void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width = 1)
{
   if(price <= 0)
      return;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

void DrawZones()
{
   if(ZoneSize <= 0)
      return;

   for(int i = 0; i <= TRE_ZONE_COUNT; i++)
   {
      double level = RangeLow + (ZoneSize * i);
      string name = "TRE_ZONE_LINE_" + IntegerToString(i);

      color lineColor = clrGold;

      if(i == 0 || i == 1)
         lineColor = clrLimeGreen;
      else if(i == 5 || i == 6)
         lineColor = clrTomato;

      DrawHLine(name, level, lineColor, STYLE_DOT, 1);
   }
}

void DrawSwingLines()
{
   DrawHLine("TRE_SWING_HIGH_LAST", LastSwingHigh, clrRed, STYLE_SOLID, 1);
   DrawHLine("TRE_SWING_HIGH_PREV", PrevSwingHigh, clrTomato, STYLE_DASH, 1);
   DrawHLine("TRE_SWING_LOW_LAST", LastSwingLow, clrDodgerBlue, STYLE_SOLID, 1);
   DrawHLine("TRE_SWING_LOW_PREV", PrevSwingLow, clrDeepSkyBlue, STYLE_DASH, 1);
}

void DrawEngine()
{
   DrawZones();
   DrawSwingLines();
}

#endif
