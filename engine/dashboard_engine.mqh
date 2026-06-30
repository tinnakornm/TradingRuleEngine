//+------------------------------------------------------------------+
//| engine/dashboard_engine.mqh                                      |
//| Scalable tab dashboard UI                                        |
//+------------------------------------------------------------------+
#ifndef TRE_DASHBOARD_ENGINE_MQH
#define TRE_DASHBOARD_ENGINE_MQH

#define TRE_DASH_TAB_COUNT 12
#define TRE_DASH_MAX_LINES 96
#define TRE_SUMMARY_SUBTAB_COUNT 5
#define TRE_STRUCTURE_SUBTAB_COUNT 5
#define TRE_PRESSURE_SUBTAB_COUNT 1
#define TRE_DECISION_SUBTAB_COUNT 8
#define TRE_TRADE_SUBTAB_COUNT 3
#define TRE_RESEARCH_SUBTAB_COUNT 5
#define TRE_SUMMARY_CARD_COUNT 11
#define TRE_DASH_CONTENT_X 170

string DashboardValueOrNA(string value)
{
   if(value == "")
      return "N/A";

   return value;
}

string DashboardPriceOrNA(double value, int digits)
{
   if(value <= 0)
      return "N/A";

   return DoubleToString(value, digits);
}

string DashboardIndexOrNA(int value)
{
   if(value < 0)
      return "N/A";

   return IntegerToString(value);
}

string DashboardCountPercentage(int count, int total)
{
   double percentage =
      (total > 0) ? (100.0 * (double)count / (double)total) : 0;
   return IntegerToString(count) + " (" +
          DoubleToString(percentage, 1) + "%)";
}

string DashboardTabName(int tab)
{
   if(tab == 0) return "Summary";
   if(tab == 1) return "Market";
   if(tab == 2) return "Zone";
   if(tab == 3) return "Structure";
   if(tab == 4) return "Momentum";
   if(tab == 5) return "Risk";
   if(tab == 6) return "Pressure";
   if(tab == 7) return "Decision";
   if(tab == 8) return "Trade";
   if(tab == 9) return "Performance";
   if(tab == 10) return "Research";
   if(tab == 11) return "Debug";

   return "Summary";
}

string TradeSubTabName(int tab)
{
   if(tab == 0) return "Open";
   if(tab == 1) return "Pending";
   if(tab == 2) return "Execution";

   return "Open";
}

string SummarySubTabName(int tab)
{
   if(tab == 0) return "Overview";
   if(tab == 1) return "Scores";
   if(tab == 2) return "Execution";
   if(tab == 3) return "Research";
   if(tab == 4) return "Diagnostics";

   return "Overview";
}

string StructureSubTabName(int tab)
{
   if(tab == 0) return "Overview";
   if(tab == 1) return "State";
   if(tab == 2) return "Swing";
   if(tab == 3) return "Development";
   if(tab == 4) return "Debug";

   return "Overview";
}

string PressureSubTabName(int tab)
{
   return "Current";
}

string ResearchSubTabName(int tab)
{
   if(tab == 0) return "Experiment";
   if(tab == 1) return "Trade";
   if(tab == 2) return "Pressure";
   if(tab == 3) return "Validation";
   if(tab == 4) return "Episode";
   return "Experiment";
}

string DecisionSubTabName(int tab)
{
   if(tab == 0) return "Decision";
   if(tab == 1) return "Regime";
   if(tab == 2) return "Uptrend";
   if(tab == 3) return "Downtrend";
   if(tab == 4) return "Sideway";
   if(tab == 5) return "Raw";
   if(tab == 6) return "Switch";
   if(tab == 7) return "Weights";

   return "Decision";
}

color DashboardStatusColor(string status)
{
   if(status == "PASS") return clrGreen;
   if(status == "BLOCKED") return clrRed;
   if(status == "WAIT") return clrGoldenrod;
   if(status == "FAIL") return clrRed;
   if(status == "DISABLED" || status == "N/A") return clrGray;
   return clrBlack;
}

string ScoreStatus(int score, int maxScore)
{
   if(maxScore <= 0)
      return "N/A";

   if(score >= maxScore)
      return "PASS";

   if(score > 0)
      return "WAIT";

   return "FAIL";
}

string CurrentStructureText()
{
   return StructureConfirmedText;
}

string ConfidenceText()
{
   if(TotalScore >= 80) return "High";
   if(TotalScore >= 60) return "Medium";
   if(TotalScore >= 40) return "Low";
   return "Very Low";
}

string DashboardShortText(string text, int maxLength)
{
   if(StringLen(text) <= maxLength)
      return text;

   return StringSubstr(text, 0, maxLength - 3) + "...";
}

color ProfitColor(double value)
{
   if(value > 0) return clrGreen;
   if(value < 0) return clrRed;
   return clrBlack;
}

color ExecutionLotColor()
{
   if(ExecutionLotValidationText == "OK") return clrGreen;
   if(ExecutionLotValidationText == "ADJUSTED") return clrGoldenrod;
   if(ExecutionLotValidationText == "INVALID") return clrRed;
   return clrGray;
}

color MarketRegimeColor()
{
   if(MarketRegimeText == "Up" ||
      MarketRegimeText == "UPTREND") return clrSeaGreen;
   if(MarketRegimeText == "Down" ||
      MarketRegimeText == "DOWNTREND") return clrFireBrick;
   if(MarketRegimeText == "Sideway" ||
      MarketRegimeText == "SIDEWAY") return clrGoldenrod;
   return clrGray;
}

color MarginLevelColor()
{
   if(AccountMarginStatusText == "CRITICAL") return clrRed;
   if(AccountMarginStatusText == "DANGER") return clrFireBrick;
   if(AccountMarginStatusText == "CAUTION") return clrGoldenrod;
   if(AccountMarginStatusText == "HEALTHY") return clrSeaGreen;
   return clrGray;
}

color ExecutionStatusColor()
{
   if(LastExecutionAction == "BLOCKED" ||
      LastExecutionAction == "FAILED") return clrRed;
   if(StringFind(LastExecutionAction, "SENT") >= 0) return clrSeaGreen;
   if(ExecutionAllowedText == "YES") return clrSeaGreen;
   return clrGray;
}

color ZoneDisplayStatusColor(string status)
{
   if(status == "VALID" || status == "ON" || status == "YES") return clrGreen;
   if(status == "INVALID" || status == "INVALID CONFIG") return clrRed;
   if(status == "DISABLED" || status == "OFF" ||
      status == "N/A" || status == "NOT CHECKED" ||
      status == "UNAVAILABLE") return clrGray;
   return clrBlack;
}

int DashboardPanelHeight()
{
   if(ActiveDashboardTab == 0)
   {
      if(ActiveSummarySubTab == 0) return 430;
      if(ActiveSummarySubTab == 1) return 420;
      return RegimeDetectionWarningActive ? 900 : 820;
   }

   if(ActiveDashboardTab == 1) return 820;
   if(ActiveDashboardTab == 2) return 820;
   if(ActiveDashboardTab == 3)
   {
      if(ActiveStructureSubTab == 0) return 520;
      if(ActiveStructureSubTab == 1) return 400;
      if(ActiveStructureSubTab == 2) return 460;
      if(ActiveStructureSubTab == 3) return 520;
      return 500;
   }
   if(ActiveDashboardTab == 4) return 360;
   if(ActiveDashboardTab == 5) return 360;
   if(ActiveDashboardTab == 6)
      return 360;
   if(ActiveDashboardTab == 7)
   {
      if(ActiveDecisionSubTab == 1 &&
         RegimeDetectionWarningActive)
      {
         return 700;
      }

      return 600;
   }
   if(ActiveDashboardTab == 8) return 720;
   if(ActiveDashboardTab == 9) return 360;
   if(ActiveDashboardTab == 10) return 620;
   return 1480;
}

void DashboardDrawText(string name, int x, int y, string text, color clr, int fontSize = 9)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DashboardDrawSummaryCard(int card, string title, string value, string note, color accent)
{
   int col = card % 3;
   int row = card / 3;
   int x = TRE_DASH_CONTENT_X + (col * 250);
   int y = 92 + (row * 82);
   string bgName = "TRE_SUM_CARD_BG_" + IntegerToString(card);

   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 235);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 72);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrWhiteSmoke);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, accent);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   DashboardDrawText("TRE_SUM_CARD_TITLE_" + IntegerToString(card), x + 10, y + 8, title, clrDimGray, 8);
   DashboardDrawText("TRE_SUM_CARD_VALUE_" + IntegerToString(card), x + 10, y + 26, value, accent, 14);
   DashboardDrawText("TRE_SUM_CARD_NOTE_" + IntegerToString(card), x + 10, y + 52, note, clrBlack, 8);
}

void DashboardHideSummaryCards()
{
   for(int card = 0; card < TRE_SUMMARY_CARD_COUNT; card++)
   {
      string bgName = "TRE_SUM_CARD_BG_" + IntegerToString(card);
      string titleName = "TRE_SUM_CARD_TITLE_" + IntegerToString(card);
      string valueName = "TRE_SUM_CARD_VALUE_" + IntegerToString(card);
      string noteName = "TRE_SUM_CARD_NOTE_" + IntegerToString(card);

      if(ObjectFind(0, bgName) >= 0) ObjectDelete(0, bgName);
      if(ObjectFind(0, titleName) >= 0) ObjectDelete(0, titleName);
      if(ObjectFind(0, valueName) >= 0) ObjectDelete(0, valueName);
      if(ObjectFind(0, noteName) >= 0) ObjectDelete(0, noteName);
   }
}

void DashboardDeleteObjectByName(string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void DashboardDrawButton(int tab)
{
   string name = "TRE_DASH_TAB_" + IntegerToString(tab);
   int x = 20;
   int y = 58 + (tab * 28);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (tab == ActiveDashboardTab) ? clrWhite : clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, (tab == ActiveDashboardTab) ? clrSteelBlue : clrGainsboro);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 90);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, DashboardTabName(tab));
}

void DashboardDrawToggleButton()
{
   string name = "TRE_DASH_TOGGLE";
   int x = DashboardVisible ? 862 : 10;
   int y = DashboardVisible ? 26 : 24;
   int width = DashboardVisible ? 78 : 180;
   string text = DashboardVisible ? "Hide" : APP_NAME;

   // Keep the object alive so Strategy Tester can preserve its pressed state.
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, DashboardVisible ? clrFireBrick : clrSeaGreen);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

bool DashboardButtonPressed(string name)
{
   if(ObjectFind(0, name) < 0)
      return false;

   return (ObjectGetInteger(0, name, OBJPROP_STATE) != 0);
}

void DashboardPollButtonState()
{
   string toggleName = "TRE_DASH_TOGGLE";

   if(DashboardButtonPressed(toggleName))
   {
      ObjectSetInteger(0, toggleName, OBJPROP_STATE, false);
      ObjectDelete(0, toggleName);
      DashboardVisible = !DashboardVisible;
      return;
   }

   if(!DashboardVisible)
      return;

   for(int tab = 0; tab < TRE_DASH_TAB_COUNT; tab++)
   {
      string name = "TRE_DASH_TAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActiveDashboardTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   for(int tab = 0; tab < TRE_SUMMARY_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_SUMMARY_SUBTAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActiveSummarySubTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   for(int tab = 0; tab < TRE_DECISION_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_DECISION_SUBTAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActiveDecisionSubTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   for(int tab = 0; tab < TRE_STRUCTURE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_STRUCTURE_SUBTAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActiveStructureSubTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   for(int tab = 0; tab < TRE_PRESSURE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_PRESSURE_SUBTAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActivePressureSubTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   for(int tab = 0; tab < TRE_TRADE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_TRADE_SUBTAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActiveTradeSubTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   for(int tab = 0; tab < TRE_RESEARCH_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_RESEARCH_SUBTAB_" + IntegerToString(tab);

      if(!DashboardButtonPressed(name))
         continue;

      ActiveResearchSubTab = tab;
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }
}

void DashboardDrawTopSubButton(string prefix,
                               int tab,
                               int activeTab,
                               string text)
{
   string name = prefix + IntegerToString(tab);
   bool compact = (StringFind(prefix, "TRE_DECISION_") == 0);
   int step = compact ? 92 : 116;
   int width = compact ? 88 : 110;
   int x = TRE_DASH_CONTENT_X + (tab * step);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 58);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR,
                    (tab == activeTab) ? clrWhite : clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,
                    (tab == activeTab) ? clrSeaGreen : clrGainsboro);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 90);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DashboardDrawTradeSubButton(int tab)
{
   string name = "TRE_TRADE_SUBTAB_" + IntegerToString(tab);
   int x = TRE_DASH_CONTENT_X + (tab * 96);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 92);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 92);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, (tab == ActiveTradeSubTab) ? clrWhite : clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, (tab == ActiveTradeSubTab) ? clrSeaGreen : clrGainsboro);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 90);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, TradeSubTabName(tab));
}

void DashboardSetLine(int row, string text, color clr = clrBlack, int fontSize = 9)
{
   string name = "TRE_DASH_CONTENT_" + IntegerToString(row);
   int y = 92 + (row * 16);

   DashboardDrawText(name, TRE_DASH_CONTENT_X, y, text, clr, fontSize);
}

void DashboardSetTradeLine(int row, string text, color clr = clrBlack, int fontSize = 9)
{
   string name = "TRE_DASH_CONTENT_" + IntegerToString(row);
   int y = 124 + (row * 16);

   DashboardDrawText(name, TRE_DASH_CONTENT_X, y, text, clr, fontSize);
}

void DashboardAddLine(int &row, string label, string value, color clr = clrBlack)
{
   DashboardSetLine(row, label + value, clr);
   row++;
}

void DashboardAddHeader(int &row, string text)
{
   DashboardSetLine(row, text, clrBlack, 10);
   row++;
   DashboardSetLine(row, "------------------------------------------------------------", clrGray);
   row++;
}

void DashboardAddRegimeEvidence(int &row,
                                TRE_EvidenceItem &item)
{
   string scoreText = DoubleToString(item.score, 1) +
                      " / " +
                      DoubleToString(item.maxScore, 1);
   DashboardAddLine(row,
                    item.name + " [" + item.status + "] : ",
                    scoreText,
                    DashboardStatusColor(item.status));
   DashboardAddLine(row, "  Reason              : ",
                    item.reason);
   DashboardAddLine(row, "  Missing             : ",
                    item.missing,
                    (item.missing == "N/A") ? clrGray
                                             : clrGoldenrod);
}

void DashboardAddRegimeDetectionWarning(int &row)
{
   if(!RegimeDetectionWarningActive)
      return;

   DashboardAddLine(row, "", "========================================",
                    clrGoldenrod);
   DashboardAddLine(row, "", "WARNING: Market Regime Detection is DISABLED",
                    clrGoldenrod);
   DashboardAddLine(row, "",
                    "Current EA instance is using manual runtime inputs.",
                    clrGoldenrod);
   DashboardAddLine(row, "",
                    "If unexpected after changing config.mqh,",
                    clrGoldenrod);
   DashboardAddLine(row, "",
                    "reload the EA or press Reset in EA Inputs.",
                    clrGoldenrod);
   DashboardAddLine(row, "", "========================================",
                    clrGoldenrod);
}

void DashboardAddTradeLine(int &row, string label, string value, color clr = clrBlack)
{
   DashboardSetTradeLine(row, label + value, clr);
   row++;
}

void DashboardAddTradeHeader(int &row, string text)
{
   DashboardSetTradeLine(row, text, clrBlack, 10);
   row++;
   DashboardSetTradeLine(row, "------------------------------------------------------------", clrGray);
   row++;
}

void DashboardBlankLine(int &row)
{
   row++;
}

void DashboardClearUnusedLines(int startRow)
{
   for(int row = startRow; row < TRE_DASH_MAX_LINES; row++)
   {
      string name = "TRE_DASH_CONTENT_" + IntegerToString(row);

      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
   }
}

void DashboardClearContentLines()
{
   DashboardClearUnusedLines(0);
}

void DashboardClearUnusedTradeLines(int startRow)
{
   for(int row = startRow; row < TRE_DASH_MAX_LINES; row++)
   {
      string name = "TRE_DASH_CONTENT_" + IntegerToString(row);

      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
   }
}

void DashboardCleanupLegacyObjects()
{
   static bool cleaned = false;

   if(cleaned)
      return;

   int total = ObjectsTotal(0, 0, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);

      if(StringFind(name, "TRE_DASH_C") == 0 ||
         StringFind(name, "TRE_DASH_LINE_") == 0)
      {
         ObjectDelete(0, name);
      }
   }

   cleaned = true;
}

void DashboardRenderTabs()
{
   for(int tab = 0; tab < TRE_DASH_TAB_COUNT; tab++)
   {
      if(tab == 10 && !UseResearchDB)
      {
         DashboardDeleteObjectByName(
            "TRE_DASH_TAB_" + IntegerToString(tab));
         continue;
      }
      DashboardDrawButton(tab);
   }
}

void DashboardRenderSummarySubTabs()
{
   for(int tab = 0; tab < TRE_SUMMARY_SUBTAB_COUNT; tab++)
      DashboardDrawTopSubButton("TRE_SUMMARY_SUBTAB_",
                                tab,
                                ActiveSummarySubTab,
                                SummarySubTabName(tab));
}

void DashboardRenderDecisionSubTabs()
{
   for(int tab = 0; tab < TRE_DECISION_SUBTAB_COUNT; tab++)
      DashboardDrawTopSubButton("TRE_DECISION_SUBTAB_",
                                tab,
                                ActiveDecisionSubTab,
                                DecisionSubTabName(tab));
}

void DashboardRenderStructureSubTabs()
{
   for(int tab = 0; tab < TRE_STRUCTURE_SUBTAB_COUNT; tab++)
      DashboardDrawTopSubButton("TRE_STRUCTURE_SUBTAB_",
                                tab,
                                ActiveStructureSubTab,
                                StructureSubTabName(tab));
}

void DashboardRenderPressureSubTabs()
{
   for(int tab = 0; tab < TRE_PRESSURE_SUBTAB_COUNT; tab++)
      DashboardDrawTopSubButton("TRE_PRESSURE_SUBTAB_",
                                tab,
                                ActivePressureSubTab,
                                PressureSubTabName(tab));
}

void DashboardRenderTradeSubTabs()
{
   for(int tab = 0; tab < TRE_TRADE_SUBTAB_COUNT; tab++)
      DashboardDrawTradeSubButton(tab);
}

void DashboardRenderResearchSubTabs()
{
   for(int tab = 0; tab < TRE_RESEARCH_SUBTAB_COUNT; tab++)
      DashboardDrawTopSubButton("TRE_RESEARCH_SUBTAB_",
                                tab,
                                ActiveResearchSubTab,
                                ResearchSubTabName(tab));
}

void DashboardHideSummarySubTabs()
{
   for(int tab = 0; tab < TRE_SUMMARY_SUBTAB_COUNT; tab++)
      DashboardDeleteObjectByName(
         "TRE_SUMMARY_SUBTAB_" + IntegerToString(tab));
}

void DashboardHideDecisionSubTabs()
{
   for(int tab = 0; tab < TRE_DECISION_SUBTAB_COUNT; tab++)
      DashboardDeleteObjectByName(
         "TRE_DECISION_SUBTAB_" + IntegerToString(tab));
}

void DashboardHideStructureSubTabs()
{
   for(int tab = 0; tab < TRE_STRUCTURE_SUBTAB_COUNT; tab++)
      DashboardDeleteObjectByName(
         "TRE_STRUCTURE_SUBTAB_" + IntegerToString(tab));
}

void DashboardHidePressureSubTabs()
{
   for(int tab = 0; tab < TRE_PRESSURE_SUBTAB_COUNT; tab++)
      DashboardDeleteObjectByName(
         "TRE_PRESSURE_SUBTAB_" + IntegerToString(tab));
}

void DashboardHideTradeSubTabs()
{
   for(int tab = 0; tab < TRE_TRADE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_TRADE_SUBTAB_" + IntegerToString(tab);

      if(ObjectFind(0, name) >= 0)
         ObjectDelete(0, name);
   }
}

void DashboardHideResearchSubTabs()
{
   for(int tab = 0; tab < TRE_RESEARCH_SUBTAB_COUNT; tab++)
      DashboardDeleteObjectByName(
         "TRE_RESEARCH_SUBTAB_" + IntegerToString(tab));
}

void DashboardHidePanelObjects()
{
   DashboardDeleteObjectByName("TRE_DASHBOARD_BG");
   DashboardDeleteObjectByName("TRE_DASH_TITLE");
   DashboardDeleteObjectByName("TRE_DASH_NAV_TITLE");
   DashboardHideSummaryCards();
   DashboardHideSummarySubTabs();
   DashboardHideStructureSubTabs();
   DashboardHidePressureSubTabs();
   DashboardHideDecisionSubTabs();
   DashboardHideTradeSubTabs();
   DashboardHideResearchSubTabs();

   for(int tab = 0; tab < TRE_DASH_TAB_COUNT; tab++)
      DashboardDeleteObjectByName("TRE_DASH_TAB_" + IntegerToString(tab));

   for(int row = 0; row < TRE_DASH_MAX_LINES; row++)
      DashboardDeleteObjectByName("TRE_DASH_CONTENT_" + IntegerToString(row));
}

void DashboardRenderSummaryCards()
{
   DashboardDrawSummaryCard(0, "DECISION", ActionToText(ActionState), DashboardShortText(EntryReason, 34), ActionColor(ActionState));
   DashboardDrawSummaryCard(1, "SIGNAL SCORE", IntegerToString(TotalScore) + " / 100", "Confidence: " + ConfidenceText(), ActionColor(ActionState));
   DashboardDrawSummaryCard(2, "FLOATING P/L", "$" + DoubleToString(TradeFloatingProfitTotal, 2), "Open positions: " + IntegerToString(TradePositionCount), ProfitColor(TradeFloatingProfitTotal));
   DashboardDrawSummaryCard(3, "PENDING", IntegerToString(TradePendingCount), "Pending orders", clrSteelBlue);
   DashboardDrawSummaryCard(4, "POSITION", TradePositionSummary, "Current Zone: " + IntegerToString(CurrentZone), (TradePositionCount > 0) ? clrSeaGreen : clrGray);
   DashboardDrawSummaryCard(5, "SHORT ADVICE", ActionToText(ActionState), DashboardShortText(MissingConditionText, 34), ActionColor(ActionState));
   DashboardDrawSummaryCard(6, "ACTIVE REGIME", ActiveRegimeText, "Best: " + RegimeBestCandidateText + " | " + RegimeConfidenceText, MarketRegimeColor());
   DashboardDrawSummaryCard(7, "MARGIN LEVEL", AccountMarginLevelText, AccountMarginStatusText, MarginLevelColor());
   DashboardDrawSummaryCard(8, "EXECUTION LOT", ExecutionLotSummaryValueText, ExecutionLotSummaryReasonText, ExecutionLotColor());
   DashboardDrawSummaryCard(9, "SCORE MIX", EngineScoreTotalText, DashboardShortText(EngineScoreMixCompactText, 34), DashboardStatusColor(TotalEngineStatusText));
   DashboardDrawSummaryCard(10, "PRESSURE", PressureDirectionText + " / " + PressureLevelText, DashboardShortText(PressureActionText + " | " + PressureBlockedDirectionText, 34), (PressureGuardStatusText == "BLOCKED") ? clrRed : ((PressureGuardStatusText == "DOWNGRADED" || PressureGuardStatusText == "SCORE_REDUCED" || PressureGuardStatusText == "WARNING") ? clrGoldenrod : clrSeaGreen));
}

void RenderSummaryTab(string symbol)
{
   DashboardClearContentLines();
   DashboardRenderSummarySubTabs();
   DashboardHideSummaryCards();

   if(ActiveSummarySubTab == 0)
   {
      DashboardRenderSummaryCards();
      return;
   }

   int row = 0;

   if(ActiveSummarySubTab == 1)
   {
      DashboardAddHeader(row, "[ENGINE SCORES]");

      for(int i = 0; i < TRE_ENGINE_SCORE_COUNT; i++)
         DashboardAddLine(row, EngineScores[i].name + " : ",
                          EngineScoreDisplayText[i],
                          DashboardStatusColor(EngineScores[i].status));

      DashboardAddLine(row, "Total                 : ",
                       EngineScoreTotalText,
                       DashboardStatusColor(TotalEngineStatusText));
      DashboardAddHeader(row, "[DECISION SNAPSHOT]");
      DashboardAddLine(row, "Decision              : ", ActionToText(ActionState), ActionColor(ActionState));
      DashboardAddLine(row, "Entry Reason          : ", EntryReason, ActionColor(ActionState));
      DashboardAddLine(row, "Missing Condition     : ", MissingConditionText, clrGoldenrod);
      DashboardAddLine(row, "Market Bias           : ", BiasToText(MarketBias), BiasColor(MarketBias));
      DashboardAddLine(row, "Zone / Strength       : ", IntegerToString(CurrentZone) + " / " + ZoneStrengthText);
      DashboardAddLine(row, "Detected / Active     : ", DetectedRegimeText + " / " + ActiveRegimeText);
      DashboardAddLine(row, "Best Candidate        : ", RegimeBestCandidateText);
      DashboardAddLine(row, "Regime Confidence     : ", RegimeConfidenceText);
      DashboardAddLine(row, "Directional Filter    : ", DirectionalFilterResultText);
      DashboardClearUnusedLines(row);
      return;
   }

   if(ActiveSummarySubTab == 2)
   {
      DashboardAddHeader(row, "[EXECUTION]");
      DashboardAddLine(row, "Decision              : ",
                       ActionToText(ActionState), ActionColor(ActionState));
      DashboardAddLine(row, "Execution Mode        : ", ExecutionModeText);
      DashboardAddLine(row, "Execution Allowed     : ",
                       ExecutionAllowedText, ExecutionStatusColor());
      DashboardAddLine(row, "Requested / Actual Lot: ",
                       ExecutionLotSummaryValueText + " | " +
                       ExecutionLotSummaryReasonText,
                       ExecutionLotColor());
      DashboardAddLine(row, "Last Execution        : ",
                       LastExecutionAction, ExecutionStatusColor());
      DashboardAddLine(row, "Execution Reason      : ",
                       LastExecutionReason, ExecutionStatusColor());
      DashboardAddLine(row, "Trade Management      : ",
                       TradeManagementSummaryText);
      DashboardAddLine(row, "Open Positions        : ",
                       IntegerToString(TradePositionCount));
      DashboardAddLine(row, "Pending Orders        : ",
                       IntegerToString(TradePendingCount));
   }
   else if(ActiveSummarySubTab == 3)
   {
      DashboardAddHeader(row, "[RESEARCH]");
      DashboardAddLine(row, "Research DB Enabled   : ",
                       UseResearchDB ? "YES" : "NO");
      DashboardAddLine(row, "Experiment ID         : ",
                       IntegerToString(ResearchDBExperimentID));
      DashboardAddLine(row, "Signals               : ",
                       IntegerToString(ResearchDBDiagnosticSignalCount));
      DashboardAddLine(row, "Executed Trades       : ",
                       IntegerToString(
                          ResearchDBDiagnosticExecutedTradeCount));
      DashboardAddLine(row, "Blocked Signals       : ",
                       IntegerToString(
                          ResearchDBDiagnosticBlockedSignalCount));
      DashboardAddLine(row, "Net Profit            : ",
                       DoubleToString(ResearchAnalyticsNetProfit, 2),
                       ProfitColor(ResearchAnalyticsNetProfit));
      DashboardAddLine(row, "Validation            : ",
                       ResearchDBDiagnosticValidationStatus);
      DashboardAddLine(row, "Open Research tab for detailed analytics",
                       "");
   }
   else
   {
      DashboardAddHeader(row, "[DIAGNOSTICS]");
      DashboardAddLine(row, "Market Detection      : ",
                       MarketDetectionStatusText);
      DashboardAddLine(row, "Regime Switch         : ",
                       RegimeSwitchStatusText);
      DashboardAddLine(row, "Regime Blocking       : ",
                       RegimeBlockingReasonText);
      DashboardAddLine(row, "Pressure Calculation  : ",
                       PressureCalculationStatusText);
      DashboardAddLine(row, "Research DB Status    : ",
                       ResearchDBStatusText);
      DashboardAddLine(row, "DB Last Error         : ",
                       ResearchDBLastErrorText);
      DashboardAddLine(row, "Attribution Errors    : ",
                       IntegerToString(
                          ResearchDBDiagnosticAttributionErrorCount));
      DashboardAddLine(row, "Orphan Trades         : ",
                       IntegerToString(
                          ResearchDBDiagnosticOrphanTradeCount));
      DashboardAddRegimeDetectionWarning(row);
   }

   DashboardClearUnusedLines(row);
}

void RenderMarketTab(string symbol)
{
   int row = 0;
   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   DashboardAddHeader(row, "TAB 2 : Market / Responsible Engine: Market Engine");
   DashboardAddHeader(row, "[MARKET / TREND SUMMARY]");
   DashboardAddLine(row, "Bias Lookback Bars    : ", IntegerToString(EffectiveBiasLookbackBars));
   DashboardAddLine(row, "Bias TF               : ", TimeframeToText(BiasTF));
   DashboardAddLine(row, "Market Bias           : ", BiasToText(MarketBias), BiasColor(MarketBias));
   DashboardAddLine(row, "Trend Direction       : ", TrendDirectionText);
   DashboardAddLine(row, "Trend Strength        : ", TrendStrengthText);
   DashboardAddLine(row, "Trend Score           : ", IntegerToString(TrendScore) + " / 40", DashboardStatusColor(ScoreStatus(TrendScore, 40)));
   DashboardAddLine(row, "Trend Evidence Score  : ", DoubleToString(TrendEvidenceScore, 0) + " / " + DoubleToString(TrendEvidenceMaxScore, 0));
   DashboardAddLine(row, "Trend Confidence      : ", TrendConfidenceText);
   DashboardAddLine(row, "Trend Reason          : ", TrendReason);
   DashboardAddLine(row, "Bias Reason           : ", TrendBiasReasonText);
   DashboardAddLine(row, "Blocking Factor       : ", TrendBlockingFactorText);
   DashboardAddLine(row, "Market Regime         : ", MarketRegimeText, MarketRegimeColor());
   DashboardAddLine(row, "Spread                : ", IntegerToString((int)spread) + " points");
   DashboardAddLine(row, "Bias Source           : ", TimeframeToText(BiasTF) + " Structure, Swing Analysis");
   DashboardAddLine(row, "Swing High / Prev     : ", DashboardPriceOrNA(LastSwingHigh, digits) + " / " + DashboardPriceOrNA(PrevSwingHigh, digits));
   DashboardAddLine(row, "Swing Low / Prev      : ", DashboardPriceOrNA(LastSwingLow, digits) + " / " + DashboardPriceOrNA(PrevSwingLow, digits));

   DashboardAddHeader(row, "[TREND EVIDENCE]");

   for(int i = 0; i < TrendEvidenceItemCount; i++)
   {
      TRE_EvidenceItem item = TrendEvidence[i];
      string scoreText = DoubleToString(item.score, 0) + "/" +
                         DoubleToString(item.maxScore, 0);

      DashboardAddLine(row, item.name + " : ",
                       item.status + "  " + scoreText,
                       DashboardStatusColor(item.status));
      DashboardAddLine(row, "  Reason             : ", item.reason);
      DashboardAddLine(row, "  Missing            : ", item.missing,
                       (item.missing == "N/A") ? clrGray : clrGoldenrod);
   }

   DashboardClearUnusedLines(row);
}

void RenderZoneTab()
{
   int row = 0;

   DashboardAddHeader(row, "TAB 3 : Zone / Responsible Engine: Zone Engine");

   DashboardAddHeader(row, "[INPUT CONFIG]");
   DashboardAddLine(row, "Zone Lookback Bars    : ", IntegerToString(EffectiveZoneLookbackBars));
   DashboardAddLine(row, "Bias Lookback Bars    : ", IntegerToString(EffectiveBiasLookbackBars));
   DashboardAddLine(row, "Use Swing Validation : ", ZoneUseSwingValidationText, ZoneDisplayStatusColor(ZoneUseSwingValidationText));
   DashboardAddLine(row, "Minimum Range Points : ", ZoneMinimumRangeText);
   DashboardAddLine(row, "Use ATR Validation   : ", ZoneUseATRValidationText, ZoneDisplayStatusColor(ZoneUseATRValidationText));
   DashboardAddLine(row, "ATR Timeframe        : ", ZoneATRTimeframeText);
   DashboardAddLine(row, "ATR Period           : ", ZoneATRPeriodText);
   DashboardAddLine(row, "Min ATR Multiplier   : ", ZoneMinATRMultiplierText);
   DashboardAddLine(row, "Max ATR Multiplier   : ", ZoneMaxATRMultiplierText);
   DashboardAddLine(row, "Zone Count           : ", ZoneCountText);

   DashboardAddHeader(row, "[RAW DATA]");
   DashboardAddLine(row, "Swing High           : ", ZoneRawSwingHighText);
   DashboardAddLine(row, "Swing Low            : ", ZoneRawSwingLowText);
   DashboardAddLine(row, "Swing Range Price    : ", ZoneSwingRangePriceText);
   DashboardAddLine(row, "Swing Range Points   : ", ZoneSwingRangePointsText);
   DashboardAddLine(row, "ATR Value Price      : ", ZoneATRValuePriceText);
   DashboardAddLine(row, "ATR Points           : ", ZoneATRPointsText);
   DashboardAddLine(row, "Min ATR Range Points : ", ZoneMinATRRangePointsText);
   DashboardAddLine(row, "Max ATR Range Points : ", ZoneMaxATRRangePointsText);
   DashboardAddLine(row, "Current Price        : ", ZoneCurrentPriceText);

   DashboardAddHeader(row, "[VALIDATION]");
   DashboardAddLine(row, "Basic Price Validation: ", ZoneBasicPriceValidationText, ZoneDisplayStatusColor(ZoneBasicPriceValidationText));
   DashboardAddLine(row, "Swing Validation     : ", ZoneSwingValidationText, ZoneDisplayStatusColor(ZoneSwingValidationText));
   DashboardAddLine(row, "ATR Validation       : ", ZoneATRValidationText, ZoneDisplayStatusColor(ZoneATRValidationText));
   DashboardAddLine(row, "Validation Reason    : ", ZoneValidationReasonText);
   DashboardAddLine(row, "Fallback Used        : ", ZoneFallbackUsedText, ZoneDisplayStatusColor(ZoneFallbackUsedText));
   DashboardAddLine(row, "Fallback Reason      : ", ZoneFallbackReasonText);
   DashboardAddLine(row, "Fallback Source      : ", ZoneFallbackSourceText);
   DashboardAddLine(row, "Fallback Lookback Bars: ", ZoneFallbackLookbackText);

   DashboardAddHeader(row, "[OUTPUT]");
   DashboardAddLine(row, "Current Zone         : ", IntegerToString(CurrentZone));
   DashboardAddLine(row, "Zone ID               : ", IntegerToString(CurrentZone));
   DashboardAddLine(row, "Zone Name             : ", ZoneNameText);
   DashboardAddLine(row, "Zone Strength         : ", ZoneStrengthText);
   DashboardAddLine(row, "Premium / Discount    : ", ZonePremiumDiscountText);
   DashboardAddLine(row, "Zone Source           : ", ZoneSourceText);
   DashboardAddLine(row, "Zone Width Price      : ", ZoneWidthPriceText);
   DashboardAddLine(row, "Zone Quality          : ", ZoneQualityText);
   DashboardAddLine(row, "Retest                : ", ZoneRetestText);
   DashboardAddLine(row, "Broken                : ", ZoneBrokenText);
   DashboardAddLine(row, "Zone Reason           : ", ZoneReason);
   DashboardAddLine(row, "Zone Score            : ", IntegerToString(ZoneScore) + " / 30", DashboardStatusColor(ScoreStatus(ZoneScore, 30)));

   DashboardClearUnusedLines(row);
}

void RenderStructureTab(string symbol)
{
   int row = 0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   DashboardRenderStructureSubTabs();

   if(ActiveStructureSubTab == 0)
   {
      DashboardAddHeader(row, "[STRUCTURE OVERVIEW]");
      DashboardAddLine(row, "Confirmed Structure   : ", CurrentStructureText());
      DashboardAddLine(row, "Development State     : ", StructureDevelopmentStateText);
      DashboardAddLine(row, "Structure Stage       : ", StructureStageText);
      DashboardAddLine(row, "Validation Stage      : ", StructureValidationStageText);
      DashboardAddLine(row, "Structure Score       : ", IntegerToString(StructureScore) + " / 20", DashboardStatusColor(ScoreStatus(StructureScore, 20)));
      DashboardAddLine(row, "Structure Confidence  : ", StructureConfidenceText);
      DashboardAddLine(row, "Early Warning         : ", StructureEarlyWarningText,
                       (StructureEarlyWarningText == "NONE") ? clrGray : clrGoldenrod);
      DashboardAddLine(row, "Strong Direction Move : ", StructureStrongDirectionalMoveText);
      DashboardAddLine(row, "Interpretation        : ", StructureInterpretationLine1Text,
                       clrGoldenrod);
      DashboardAddLine(row, "                       ", StructureInterpretationLine2Text,
                       (StructureInterpretationLine2Text == "N/A") ? clrGray : clrGoldenrod);
      DashboardAddLine(row, "                       ", StructureInterpretationLine3Text,
                       (StructureInterpretationLine3Text == "N/A") ? clrGray : clrGoldenrod);
      DashboardAddLine(row, "Missing Evidence      : ", StructureMissingEvidenceText,
                       (StructureMissingEvidenceText == "N/A") ? clrGreen : clrGoldenrod);
      DashboardAddHeader(row, "[STRUCTURE PROGRESS]");
      DashboardAddLine(row, "Swing Detection       : ", StructureSwingDetectionProgressText);
      DashboardAddLine(row, "Swing Pair            : ", StructureSwingPairProgressText);
      DashboardAddLine(row, "Structure Build       : ", StructureBuildProgressText);
      DashboardAddLine(row, "Confirmation          : ", StructureConfirmationProgressText);
   }
   else if(ActiveStructureSubTab == 1)
   {
      DashboardAddHeader(row, "[STRUCTURE STATE]");
      DashboardAddLine(row, "Confirmed Structure   : ", StructureConfirmedText);
      DashboardAddLine(row, "Development State     : ", StructureDevelopmentStateText);
      DashboardAddLine(row, "Swing Pair Count      : ", IntegerToString(StructureSwingPairCount));
      DashboardAddLine(row, "HH Count              : ", IntegerToString(StructureHHCount));
      DashboardAddLine(row, "HL Count              : ", IntegerToString(StructureHLCount));
      DashboardAddLine(row, "LH Count              : ", IntegerToString(StructureLHCount));
      DashboardAddLine(row, "LL Count              : ", IntegerToString(StructureLLCount));
      DashboardAddLine(row, "BOS State             : ", StructureBOSStateText);
      DashboardAddLine(row, "CHOCH State           : ", StructureCHOCHStateText);
      DashboardAddLine(row, "Current Status        : ", StructureStatusText);
   }
   else if(ActiveStructureSubTab == 2)
   {
      DashboardAddHeader(row, "[CONFIRMED SWINGS]");
      DashboardAddLine(row, "Current Swing High    : ", DashboardPriceOrNA(StructureLastSwingHigh, digits));
      DashboardAddLine(row, "Previous Swing High   : ", DashboardPriceOrNA(StructurePrevSwingHigh, digits));
      DashboardAddLine(row, "Current Swing Low     : ", DashboardPriceOrNA(StructureLastSwingLow, digits));
      DashboardAddLine(row, "Previous Swing Low    : ", DashboardPriceOrNA(StructurePrevSwingLow, digits));
      DashboardAddHeader(row, "[PENDING SWING CANDIDATES]");
      DashboardAddLine(row, "Pending High Candidate: ", PendingSwingHighCandidateText);
      DashboardAddLine(row, "Pending High Status   : ", PendingSwingHighStatusText);
      DashboardAddLine(row, "Pending High Price    : ", DashboardPriceOrNA(PendingSwingHighPrice, digits));
      DashboardAddLine(row, "Pending High Bar Index: ", DashboardIndexOrNA(PendingSwingHighBarIndex));
      DashboardAddLine(row, "High Right Wait/Need  : ", IntegerToString(PendingSwingHighRightBarsWaited) + " / " + IntegerToString(PendingSwingHighRightBarsRequired));
      DashboardAddLine(row, "Pending Low Candidate : ", PendingSwingLowCandidateText);
      DashboardAddLine(row, "Pending Low Status    : ", PendingSwingLowStatusText);
      DashboardAddLine(row, "Pending Low Price     : ", DashboardPriceOrNA(PendingSwingLowPrice, digits));
      DashboardAddLine(row, "Pending Low Bar Index : ", DashboardIndexOrNA(PendingSwingLowBarIndex));
      DashboardAddLine(row, "Low Right Wait/Need   : ", IntegerToString(PendingSwingLowRightBarsWaited) + " / " + IntegerToString(PendingSwingLowRightBarsRequired));
   }
   else if(ActiveStructureSubTab == 3)
   {
      DashboardAddHeader(row, "[STRUCTURE DEVELOPMENT]");
      DashboardAddLine(row, "Development State     : ", StructureDevelopmentStateText);
      DashboardAddLine(row, "Early Warning         : ", StructureEarlyWarningText,
                       (StructureEarlyWarningText == "NONE") ? clrGray : clrGoldenrod);
      DashboardAddLine(row, "Early Warning Reason  : ", StructureEarlyWarningReasonText,
                       (StructureEarlyWarningReasonText == "N/A") ? clrGray : clrGoldenrod);
      DashboardAddLine(row, "Strong Direction Move : ", StructureStrongDirectionalMoveText);
      DashboardAddLine(row, "Recent Bearish Closes : ", IntegerToString(StructureRecentBearishCloseCount));
      DashboardAddLine(row, "Recent Bullish Closes : ", IntegerToString(StructureRecentBullishCloseCount));
      DashboardAddLine(row, "Consecutive Bearish   : ", IntegerToString(StructureConsecutiveBearishBars));
      DashboardAddLine(row, "Consecutive Bullish   : ", IntegerToString(StructureConsecutiveBullishBars));
      DashboardAddLine(row, "Recent Lower Lows     : ", IntegerToString(StructureRecentLowerLowCount));
      DashboardAddLine(row, "Recent Higher Highs   : ", IntegerToString(StructureRecentHigherHighCount));
      DashboardAddLine(row, "Recent Lower Closes   : ", IntegerToString(StructureRecentLowerCloseCount));
      DashboardAddLine(row, "Recent Higher Closes  : ", IntegerToString(StructureRecentHigherCloseCount));
      DashboardAddLine(row, "Price Below EMA       : ", StructurePriceBelowEMAText);
      DashboardAddLine(row, "Price Above EMA       : ", StructurePriceAboveEMAText);
      DashboardAddLine(row, "EMA Slope Direction   : ", StructureEMASlopeDirectionText);
      DashboardAddLine(row, "Distance From EMA Pts : ", StructureDistanceFromEMAPointsText);
   }
   else
   {
      DashboardAddHeader(row, "[STRUCTURE DEBUG]");
      DashboardAddLine(row, "Engine Enabled/Called : ", SwingEngineEnabledText + " / " + SwingEngineCalledText);
      DashboardAddLine(row, "Timeframe Used        : ", StructureSwingTimeframeText);
      DashboardAddLine(row, "Lookback Requested    : ", IntegerToString(StructureSwingLookbackRequested));
      DashboardAddLine(row, "Effective Bars Copied : ", IntegerToString(StructureSwingBarsCopied));
      DashboardAddLine(row, "Left / Right Confirm  : ", IntegerToString(StructureSwingLeftBars) + " / " + IntegerToString(StructureSwingRightBars));
      DashboardAddLine(row, "Detector High / Low   : ", IntegerToString(StructureSwingDetectedHighCount) + " / " + IntegerToString(StructureSwingDetectedLowCount));
      DashboardAddLine(row, "Stored High / Low     : ", IntegerToString(StructureSwingHighStoredCount) + " / " + IntegerToString(StructureSwingLowStoredCount));
      DashboardAddLine(row, "Published High / Low  : ", IntegerToString(StructureSwingHighCount) + " / " + IntegerToString(StructureSwingLowCount));
      DashboardAddLine(row, "Mapping Status        : ", StructureSwingMappingStatusText,
                       (StructureSwingMappingStatusText == "VALID") ? clrGreen : clrGoldenrod);
      DashboardAddLine(row, "Mapping Reason        : ", StructureSwingMappingReasonText);
      DashboardAddLine(row, "Last High Bar Index   : ", DashboardIndexOrNA(StructureLastSwingHighBarIndex));
      DashboardAddLine(row, "Last Low Bar Index    : ", DashboardIndexOrNA(StructureLastSwingLowBarIndex));
      DashboardAddLine(row, "No-Swing Reason       : ", StructureSwingNoSwingReasonText,
                       (StructureSwingNoSwingReasonText == "N/A") ? clrGreen : clrGoldenrod);
   }

   DashboardClearUnusedLines(row);
}

void RenderMomentumTab()
{
   int row = 0;

   DashboardAddHeader(row, "TAB 5 : Momentum / Responsible Engine: Momentum Engine");
   DashboardAddLine(row, "Current Candle        : ", MomentumCandleText);
   DashboardAddLine(row, "Pattern               : ", MomentumReason);
   DashboardAddLine(row, "Momentum Strength     : ", MomentumStrengthText);
   DashboardAddLine(row, "Body %                : ", DoubleToString(MomentumBodyPercent, 1));
   DashboardAddLine(row, "Upper Wick            : ", DoubleToString(MomentumUpperWickPercent, 1));
   DashboardAddLine(row, "Lower Wick            : ", DoubleToString(MomentumLowerWickPercent, 1));
   DashboardAddLine(row, "Volume                : ", "N/A");
   DashboardAddLine(row, "Momentum Score        : ", IntegerToString(MomentumScore) + " / 10", DashboardStatusColor(ScoreStatus(MomentumScore, 10)));

   DashboardClearUnusedLines(row);
}

void RenderRiskTab(string symbol)
{
   int row = 0;
   long spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);

   DashboardAddHeader(row, "TAB 6 : Risk / Responsible Engine: Risk Engine");
   DashboardAddLine(row, "Spread                : ", IntegerToString((int)spread) + " points");
   DashboardAddLine(row, "ATR Filter            : ", "WAIT");
   DashboardAddLine(row, "News Filter           : ", "WAIT");
   DashboardAddLine(row, "Session Filter        : ", "WAIT");
   DashboardAddLine(row, "RR Filter             : ", "WAIT");
   DashboardAddLine(row, "Risk Level            : ", RiskLevelText);
   DashboardAddLine(row, "Max Daily Loss        : ", "N/A");
   DashboardAddLine(row, "Current Drawdown      : ", "N/A");
   DashboardAddLine(row, "Risk Score            : ", "N/A");
   DashboardAddLine(row, "Future Parameters     : ", "Add here without changing other tabs", clrGray);

   DashboardClearUnusedLines(row);
}

void RenderPressureTab()
{
   int row = 0;
   DashboardRenderPressureSubTabs();

   DashboardAddHeader(row, "[CURRENT PRESSURE]");
   DashboardAddLine(row, "Current Pressure      : ",
                    PressureDirectionText + " " + PressureLevelText);
   DashboardAddLine(row, "Current Direction     : ",
                    PressureDirectionText);
   DashboardAddLine(row, "Pressure Level        : ", PressureLevelText);
   DashboardAddLine(row, "Pressure Score        : ",
                    IntegerToString(PressureScore) + " / 100");
   DashboardAddLine(row, "Current Action        : ", PressureActionText);
   DashboardAddLine(row, "Decision Impact       : ",
                    PressureDecisionImpactText);
   DashboardAddLine(row, "Execution Block       : ",
                    PressureExecutionBlockApplied ? "BLOCKED" : "ALLOW",
                    PressureExecutionBlockApplied ? clrRed : clrSeaGreen);
   DashboardAddLine(row, "Block Reason          : ",
                    PressureExecutionBlockReasonText);

   DashboardClearUnusedLines(row);
}

void RenderDecisionTab()
{
   int row = 0;
   DashboardRenderDecisionSubTabs();

   if(ActiveDecisionSubTab == 0)
   {
      DashboardAddHeader(row, "[ENTRY DECISION]");
      DashboardAddLine(row, "Decision              : ", ActionToText(ActionState), ActionColor(ActionState));
      DashboardAddLine(row, "BUY                   : ", (ActionState == ACTION_BUY_READY) ? "READY" : "WAIT");
      DashboardAddLine(row, "SELL                  : ", (ActionState == ACTION_SELL_READY) ? "READY" : "WAIT");
      DashboardAddLine(row, "Signal Score          : ", IntegerToString(TotalScore) + " / 100", ActionColor(ActionState));
      DashboardAddLine(row, "Confidence            : ", ConfidenceText());
      DashboardAddLine(row, "Current Reason        : ", EntryReason, ActionColor(ActionState));
      DashboardAddLine(row, "Missing Condition     : ", MissingConditionText, clrGoldenrod);
      DashboardAddHeader(row, "[PROFILE FILTER]");
      DashboardAddLine(row, "Manual Profile        : ", ManualMarketProfileText);
      DashboardAddLine(row, "Active Profile        : ", ActiveRegimeText, MarketRegimeColor());
      DashboardAddLine(row, "Directional Filter    : ", DirectionalFilterEnabledText);
      DashboardAddLine(row, "Allow Buy             : ", DirectionalFilterAllowBuyText);
      DashboardAddLine(row, "Allow Sell            : ", DirectionalFilterAllowSellText);
      DashboardAddLine(row, "Filter Result         : ", DirectionalFilterResultText,
                       DashboardStatusColor(DirectionalFilterResultText));
      DashboardAddLine(row, "Filter Reason         : ", DirectionalFilterReasonText);
      DashboardAddLine(row, "Blocking Factor       : ", DirectionalFilterBlockingFactorText,
                       (DirectionalFilterResultText == "BLOCKED") ? clrRed : clrGray);
   }
   else if(ActiveDecisionSubTab == 1)
   {
      DashboardAddHeader(row, "[REGIME SUMMARY]");
      DashboardAddLine(row, "Research Mode         : ", RegimeResearchModeText);
      DashboardAddLine(row, "Input Source          : ", RegimeInputSourceText);
      DashboardAddLine(row, "Market Detection Status: ", MarketDetectionStatusText);
      DashboardAddLine(row, "Auto Profile Switch Status: ", AutoProfileSwitchStatusText);
      DashboardAddLine(row, "Profile Source        : ", RegimeProfileSourceText);
      DashboardAddLine(row, "Manual Profile        : ", ManualMarketProfileText);
      DashboardAddLine(row, "Detected Regime       : ", DetectedRegimeText);
      DashboardAddLine(row, "Best Candidate Regime : ", RegimeBestCandidateText);
      DashboardAddLine(row, "Active Regime         : ", ActiveRegimeText, MarketRegimeColor());
      DashboardAddLine(row, "Confidence            : ", RegimeConfidenceText);
      DashboardAddLine(row, "Winning Score         : ", IntegerToString(RegimeWinningScore) + " / 100");
      DashboardAddLine(row, "Score Gap             : ", IntegerToString(RegimeScoreGap));
      DashboardAddLine(row, "Threshold Result      : ", RegimeThresholdResultText,
                       DashboardStatusColor(RegimeThresholdResultText));
      DashboardAddLine(row, "Confidence Comment    : ", RegimeConfidenceCommentText);
      DashboardAddLine(row, "Uptrend Score         : ", IntegerToString(UptrendScore) + " / 100");
      DashboardAddLine(row, "Downtrend Score       : ", IntegerToString(DowntrendScore) + " / 100");
      DashboardAddLine(row, "Sideway Score         : ", IntegerToString(SidewayScore) + " / 100");
      DashboardAddLine(row, "Regime TF / Lookback  : ", TimeframeToText(RegimeTF) + " / " + IntegerToString(EffectiveRegimeLookbackBars));
      DashboardAddLine(row, "Switch Threshold      : ", IntegerToString(EffectiveRegimeSwitchThreshold));
      DashboardAddLine(row, "Confirm Bars          : ", IntegerToString(RegimeConfirmationCount) + " / " + IntegerToString(EffectiveRegimeConfirmBars));
      DashboardAddLine(row, "Hold Bars             : ", IntegerToString(RegimeActiveHoldCount) + " / " + IntegerToString(EffectiveRegimeHoldBars));
      DashboardAddLine(row, "Switch Status         : ", RegimeSwitchStatusText);
      DashboardAddLine(row, "Blocking Reason       : ", RegimeBlockingReasonText);
      DashboardAddRegimeDetectionWarning(row);
   }
   else if(ActiveDecisionSubTab == 2)
   {
      DashboardAddHeader(row, "[UPTREND EVIDENCE]");

      for(int i = 0; i < TRE_REGIME_EVIDENCE_COUNT; i++)
         DashboardAddRegimeEvidence(row, RegimeUptrendEvidence[i]);
   }
   else if(ActiveDecisionSubTab == 3)
   {
      DashboardAddHeader(row, "[DOWNTREND EVIDENCE]");

      for(int i = 0; i < TRE_REGIME_EVIDENCE_COUNT; i++)
         DashboardAddRegimeEvidence(row, RegimeDowntrendEvidence[i]);
   }
   else if(ActiveDecisionSubTab == 4)
   {
      DashboardAddHeader(row, "[SIDEWAY EVIDENCE]");

      for(int i = 0; i < TRE_REGIME_EVIDENCE_COUNT; i++)
         DashboardAddRegimeEvidence(row, RegimeSidewayEvidence[i]);
   }
   else if(ActiveDecisionSubTab == 5)
   {
      DashboardAddHeader(row, "[REGIME RAW INPUTS]");
      DashboardAddLine(row, "Current Price         : ", RegimeCurrentPriceText);
      DashboardAddLine(row, "Completed OHLC        : ",
                       RegimeOpenText + " / " + RegimeHighText +
                       " / " + RegimeLowText + " / " + RegimeCloseText);
      DashboardAddLine(row, "Lookback High / Low   : ",
                       RegimeLookbackHighText + " / " +
                       RegimeLookbackLowText);
      DashboardAddLine(row, "Lookback Range Points : ", RegimeLookbackRangePointsText);
      DashboardAddLine(row, "EMA Current / Previous: ",
                       RegimeEMAValueText + " / " +
                       RegimeEMAPreviousValueText);
      DashboardAddLine(row, "EMA Slope Points      : ", RegimeEMASlopePointsText);
      DashboardAddLine(row, "ATR Current / Average : ",
                       RegimeATRPointsText + " / " +
                       RegimeATRAveragePointsText);
      DashboardAddLine(row, "ATR State             : ", RegimeATRExpansionText);
      DashboardAddLine(row, "H4 Bias               : ", RegimeH4BiasText);
      DashboardAddLine(row, "Current Zone          : ", IntegerToString(CurrentZone));
      DashboardAddLine(row, "Middle Zone Touch     : ", RegimeMidZoneTouchCountText);
      DashboardAddHeader(row, "[LOOKBACK COUNTS]");
      DashboardAddLine(row, "Swing High / Low      : ",
                       IntegerToString(RegimeSwingHighCount) + " / " +
                       IntegerToString(RegimeSwingLowCount));
      DashboardAddLine(row, "Higher High / Low     : ",
                       IntegerToString(RegimeHigherHighCount) + " / " +
                       IntegerToString(RegimeHigherLowCount));
      DashboardAddLine(row, "Lower High / Low      : ",
                       IntegerToString(RegimeLowerHighCount) + " / " +
                       IntegerToString(RegimeLowerLowCount));
      DashboardAddLine(row, "Closes Above / Below  : ",
                       IntegerToString(RegimeCloseAboveEMACount) + " / " +
                       IntegerToString(RegimeCloseBelowEMACount));
   }
   else if(ActiveDecisionSubTab == 6)
   {
      DashboardAddHeader(row, "[PROFILE SWITCH DECISION]");
      DashboardAddLine(row, "Previous Detected     : ", RegimePreviousDetectedText);
      DashboardAddLine(row, "Raw Detected          : ", RegimeRawDetectedText);
      DashboardAddLine(row, "Best Candidate        : ", RegimeBestCandidateText);
      DashboardAddLine(row, "Confirmation Candidate: ", RegimeCandidateText);
      DashboardAddLine(row, "Candidate Confidence  : ", IntegerToString(RegimeCandidateConfidence) + " / 100");
      DashboardAddLine(row, "Threshold             : ", IntegerToString(EffectiveRegimeSwitchThreshold));
      DashboardAddLine(row, "Threshold Result      : ", RegimeThresholdResultText,
                       DashboardStatusColor(RegimeThresholdResultText));
      DashboardAddLine(row, "Confirmation Bars     : ",
                       IntegerToString(RegimeConfirmationCount) + " / " +
                       IntegerToString(EffectiveRegimeConfirmBars));
      DashboardAddLine(row, "Active Hold Bars      : ",
                       IntegerToString(RegimeActiveHoldCount) + " / " +
                       IntegerToString(EffectiveRegimeHoldBars));
      DashboardAddLine(row, "Active Before         : ", RegimeActiveBeforeSwitchText);
      DashboardAddLine(row, "Switch Allowed        : ", RegimeSwitchAllowedText,
                       (RegimeSwitchAllowedText == "YES") ? clrGreen : clrGoldenrod);
      DashboardAddLine(row, "Active After          : ", RegimeActiveAfterSwitchText);
      DashboardAddLine(row, "Switch Status         : ", RegimeSwitchStatusText);
      DashboardAddLine(row, "Blocking Reason       : ", RegimeBlockingReasonText);
      DashboardAddLine(row, "Decision Reason       : ", RegimeSwitchDecisionReasonText);
   }
   else
   {
      DashboardAddHeader(row, "[RESEARCH WEIGHTS]");
      DashboardAddLine(row, "Research Decision Mode: ", ResearchDecisionModeText);
      DashboardAddLine(row, "Market Bias Required  : ", ResearchMarketBiasRequiredText);
      DashboardAddLine(row, "Bias Override         : ", ResearchBiasOverrideText,
                       (ResearchBiasOverrideText == "YES") ? clrGoldenrod : clrGray);
      DashboardAddLine(row, "Decision Source       : ", ResearchDecisionSourceText);
      DashboardAddLine(row, "Zone Ready Threshold  : ", IntegerToString(EffectiveZoneOnlyReadyThreshold));
      DashboardAddLine(row, "Research Warning      : ", ResearchWarningText,
                       (ResearchWarningText == "N/A") ? clrGray : clrGoldenrod);
      DashboardAddLine(row, "Use Trend / Weight    : ", (UseTrendScore ? "ON / " : "OFF / ") + DoubleToString(TrendWeight, 1));
      DashboardAddLine(row, "Use Zone / Weight     : ", (UseZoneScore ? "ON / " : "OFF / ") + DoubleToString(ZoneWeight, 1));
      DashboardAddLine(row, "Use Structure / Weight: ", (UseStructureScore ? "ON / " : "OFF / ") + DoubleToString(StructureWeight, 1));
      DashboardAddLine(row, "Use Momentum / Weight : ", (UseMomentumScore ? "ON / " : "OFF / ") + DoubleToString(MomentumWeight, 1));
      DashboardAddLine(row, "Final Formula         : ", EngineScoreFormulaText);
      DashboardAddHeader(row, "[ENGINE SCORES]");

      for(int i = 0; i < TRE_ENGINE_SCORE_COUNT; i++)
         DashboardAddLine(row, EngineScores[i].name + " : ",
                          EngineScoreDisplayText[i],
                          DashboardStatusColor(EngineScores[i].status));

      DashboardAddLine(row, "Total                 : ",
                       EngineScoreTotalText + " | " + EntryReason,
                       DashboardStatusColor(TotalEngineStatusText));
   }

   DashboardClearUnusedLines(row);
}

void RenderTradeTab()
{
   int row = 0;

   DashboardRenderTradeSubTabs();
   DashboardAddTradeHeader(row, "TAB 9 : Trade / " + TradeSubTabName(ActiveTradeSubTab));

   if(ActiveTradeSubTab == 0)
   {
      DashboardAddTradeLine(row, "Section               : ", "Open Positions");
      DashboardAddTradeLine(row, "Current Position      : ", TradePositionSummary);
      DashboardAddTradeLine(row, "Position Count        : ", IntegerToString(TradePositionCount));

      if(TradePositionCount == 0)
      {
         DashboardAddTradeLine(row, "Position Ticket       : ", "N/A");
         DashboardAddTradeLine(row, "Position Type         : ", "N/A");
         DashboardAddTradeLine(row, "Volume                : ", "N/A");
         DashboardAddTradeLine(row, "Entry Price           : ", "N/A");
         DashboardAddTradeLine(row, "Current Price         : ", "N/A");
         DashboardAddTradeLine(row, "Stop Loss             : ", "N/A");
         DashboardAddTradeLine(row, "Take Profit           : ", "N/A");
         DashboardAddTradeLine(row, "Floating Profit       : ", "N/A");
         DashboardAddTradeLine(row, "Swap                  : ", "N/A");
         DashboardAddTradeLine(row, "Commission            : ", "N/A");
         DashboardAddTradeLine(row, "Position Time         : ", "N/A");
         DashboardAddTradeLine(row, "Position Comment      : ", "N/A");
         DashboardAddTradeLine(row, "Trade Status          : ", "NO POSITION");
      }
      else
      {
         int maxPositions = (TradePositionCount < TRE_MAX_TRADE_ROWS) ? TradePositionCount : TRE_MAX_TRADE_ROWS;

         for(int i = 0; i < maxPositions; i++)
         {
            DashboardAddTradeLine(row, "Position #" + IntegerToString(i + 1) + "          : ", TradePositionType[i]);
            DashboardAddTradeLine(row, "Ticket / Volume       : ", TradePositionTicket[i] + " / " + TradePositionVolume[i]);
            DashboardAddTradeLine(row, "Entry / Current       : ", TradePositionEntryPrice[i] + " / " + TradePositionCurrentPrice[i]);
            DashboardAddTradeLine(row, "SL / TP               : ", TradePositionStopLoss[i] + " / " + TradePositionTakeProfit[i]);
            DashboardAddTradeLine(row, "Floating / Swap       : ", TradePositionFloatingProfit[i] + " / " + TradePositionSwap[i]);
            DashboardAddTradeLine(row, "Comm / Time           : ", TradePositionCommission[i] + " / " + TradePositionTime[i]);
            DashboardAddTradeLine(row, "Comment / Status      : ", TradePositionComment[i] + " / " + TradePositionStatus[i]);
         }
      }

      DashboardBlankLine(row);
      DashboardAddTradeLine(row, "Section               : ", "Risk / Reward");
      DashboardAddTradeLine(row, "Risk Points           : ", TradeRiskPoints[0]);
      DashboardAddTradeLine(row, "Reward Points         : ", TradeRewardPoints[0]);
      DashboardAddTradeLine(row, "Current Move Points   : ", TradeCurrentMovePoints[0]);
      DashboardAddTradeLine(row, "Current RR            : ", TradeCurrentRR[0]);
      DashboardAddTradeLine(row, "Planned RR            : ", TradePlannedRR[0]);

      DashboardBlankLine(row);
      DashboardAddTradeLine(row, "[TRADE MANAGEMENT]    : ", "");
      DashboardAddTradeLine(row, "Timeout Enabled       : ", TimeoutEnabledText);
      DashboardAddTradeLine(row, "Holding TF            : ", TimeoutHoldingTFText);
      DashboardAddTradeLine(row, "Position Open Time    : ", TimeoutPositionOpenTimeText);
      DashboardAddTradeLine(row, "Max Holding Bars      : ", TimeoutMaxHoldingBarsText);
      DashboardAddTradeLine(row, "Current Bars Held     : ", TimeoutCurrentBarsHeldText);
      DashboardAddTradeLine(row, "Timeout Status        : ", TimeoutStatusText);
      DashboardAddTradeLine(row, "Last Timeout Exit     : ", TimeoutLastTicketText);
      DashboardAddTradeLine(row, "Last Timeout Reason   : ", TimeoutLastReasonText);
   }
   else if(ActiveTradeSubTab == 1)
   {
      DashboardAddTradeLine(row, "Section               : ", "Pending Orders");
      DashboardAddTradeLine(row, "Pending Count         : ", IntegerToString(TradePendingCount));

      if(TradePendingCount == 0)
      {
         DashboardAddTradeLine(row, "Pending Orders        : ", "NONE");
      }
      else
      {
         int maxOrders = (TradePendingCount < TRE_MAX_TRADE_ROWS) ? TradePendingCount : TRE_MAX_TRADE_ROWS;

         for(int i = 0; i < maxOrders; i++)
         {
            DashboardAddTradeLine(row, "Pending #" + IntegerToString(i + 1) + "           : ", TradePendingType[i]);
            DashboardAddTradeLine(row, "Ticket / Volume       : ", TradePendingTicket[i] + " / " + TradePendingVolume[i]);
            DashboardAddTradeLine(row, "Entry / SL / TP       : ", TradePendingEntryPrice[i] + " / " + TradePendingStopLoss[i] + " / " + TradePendingTakeProfit[i]);
            DashboardAddTradeLine(row, "Distance / Time       : ", TradePendingDistancePoints[i] + " / " + TradePendingOrderTime[i]);
            DashboardAddTradeLine(row, "Expire / Comment      : ", TradePendingExpiration[i] + " / " + TradePendingComment[i]);
         }
      }
   }
   else
   {
      DashboardAddTradeLine(row, "Section               : ", "Execution Monitor");
      DashboardAddTradeLine(row, "Runtime               : ", ExecutionRuntimeText);
      DashboardAddTradeLine(row, "Execution Mode        : ", ExecutionModeText);
      DashboardAddTradeLine(row, "Execution Allowed     : ", ExecutionAllowedText, ExecutionStatusColor());
      DashboardAddTradeLine(row, "Can Execute           : ", ExecutionCanExecuteText, ExecutionStatusColor());
      DashboardAddTradeLine(row, "Decision              : ", ActionToText(ActionState), ActionColor(ActionState));
      DashboardAddTradeLine(row, "Signal Score          : ", IntegerToString(TotalScore) + " / 100");
      DashboardBlankLine(row);
      DashboardAddTradeLine(row, "Requested Lot         : ", DoubleToString(ExecutionRequestedLot, 4));
      DashboardAddTradeLine(row, "Normalized Lot        : ", DoubleToString(ExecutionNormalizedLot, 4));
      DashboardAddTradeLine(row, "Lot Validation        : ", ExecutionLotValidationText);
      DashboardAddTradeLine(row, "Lot Reason            : ", ExecutionLotReasonText);
      DashboardAddTradeLine(row, "Volume Min / Max      : ", DoubleToString(ExecutionVolumeMin, 4) + " / " + DoubleToString(ExecutionVolumeMax, 4));
      DashboardAddTradeLine(row, "Volume Step           : ", DoubleToString(ExecutionVolumeStep, 4));
      DashboardBlankLine(row);
      DashboardAddTradeLine(row, "Requested SL Points   : ", DoubleToString(ExecutionRequestedSLPoints, 1));
      DashboardAddTradeLine(row, "Effective SL Points   : ", DoubleToString(ExecutionEffectiveSLPoints, 1));
      DashboardAddTradeLine(row, "Requested TP Points   : ", DoubleToString(ExecutionRequestedTPPoints, 1));
      DashboardAddTradeLine(row, "Effective TP Points   : ", DoubleToString(ExecutionEffectiveTPPoints, 1));
      DashboardAddTradeLine(row, "Stops / Freeze Level  : ", IntegerToString((int)ExecutionStopsLevel) + " / " + IntegerToString((int)ExecutionFreezeLevel));
      DashboardAddTradeLine(row, "SLTP Validation       : ", ExecutionSLTPValidationText);
      DashboardBlankLine(row);
      DashboardAddTradeLine(row, "Position Count        : ", IntegerToString(ExecutionPositionCount));
      DashboardAddTradeLine(row, "Max Positions         : ", IntegerToString(BacktestMaxPositionsPerSymbol));
      DashboardAddTradeLine(row, "One Trade Per Bar     : ", ExecutionOneTradePerBarText);
      DashboardAddTradeLine(row, "Last Signal Bar Time  : ", ExecutionLastSignalBarText);
      DashboardAddTradeLine(row, "Last Execution Bar    : ", ExecutionLastBarText);
      DashboardBlankLine(row);
      DashboardAddTradeLine(row, "Last Action           : ", LastExecutionAction, ExecutionStatusColor());
      DashboardAddTradeLine(row, "Last Reason           : ", LastExecutionReason, ExecutionStatusColor());
      DashboardAddTradeLine(row, "Last Order Type       : ", ExecutionLastOrderType);
      DashboardAddTradeLine(row, "Last Order Ticket     : ", ExecutionLastOrderTicket);
      DashboardAddTradeLine(row, "Last Order Lot        : ", ExecutionLastOrderLot);
      DashboardAddTradeLine(row, "Last Entry / SL / TP  : ", ExecutionLastOrderEntry + " / " + ExecutionLastOrderSL + " / " + ExecutionLastOrderTP);
      DashboardAddTradeLine(row, "Last Trade Retcode    : ", ExecutionLastTradeRetcode);
      DashboardAddTradeLine(row, "Last Error            : ", ExecutionLastErrorText);
   }

   DashboardBlankLine(row);
   DashboardAddTradeLine(row, "Mode                  : ",
                         (ActiveTradeSubTab == 2)
                         ? "Backtest monitor. Live execution blocked."
                         : "Read-only account state display.",
                         clrGreen);

   DashboardClearUnusedTradeLines(row);
}

void RenderPerformanceTab()
{
   int row = 0;

   DashboardAddHeader(row, "TAB 10 : Performance / Responsible Engine: Performance Engine");
   DashboardAddLine(row, "Signals Today         : ", "N/A");
   DashboardAddLine(row, "Trades Today          : ", "0");
   DashboardAddLine(row, "Win                   : ", "N/A");
   DashboardAddLine(row, "Loss                  : ", "N/A");
   DashboardAddLine(row, "Win Rate              : ", "N/A");
   DashboardAddLine(row, "Average RR            : ", "N/A");
   DashboardAddLine(row, "Profit Factor         : ", "N/A");
   DashboardAddLine(row, "Expectancy            : ", "N/A");
   DashboardAddLine(row, "Maximum Drawdown      : ", "N/A");

   DashboardClearUnusedLines(row);
}

void RenderResearchTab(string symbol)
{
   int row = 0;
   DashboardRenderResearchSubTabs();

   if(!UseResearchDB)
   {
      DashboardAddHeader(row, "[RESEARCH DISABLED]");
      DashboardAddLine(row, "UseResearchDB         : ", "false");
      DashboardAddLine(row, "Research analytics require UseResearchDB=true",
                       "");
      DashboardClearUnusedLines(row);
      return;
   }

   if(ActiveResearchSubTab == 0)
   {
      DashboardAddHeader(row, "[EXPERIMENT]");
      DashboardAddLine(row, "Experiment Name       : ",
                       BacktestExperimentName);
      DashboardAddLine(row, "Experiment ID         : ",
                       IntegerToString(ResearchDBExperimentID));
      DashboardAddLine(row, "Engine Version        : ", APP_VERSION);
      DashboardAddLine(row, "Schema Version        : ",
                       IntegerToString(ResearchDBSchemaVersion));
      DashboardAddLine(row, "Symbol / Timeframe    : ",
                       symbol + " / " + TimeframeToText(_Period));
      DashboardAddLine(row, "Profile               : ",
                       ManualMarketProfileText);
      DashboardAddLine(row, "Pressure Mode         : ",
                       PressureExecutionBlockModeText);
      DashboardAddLine(row, "Execution Mode        : ", ExecutionModeText);
      DashboardAddLine(row, "Signals / Trades      : ",
                       IntegerToString(ResearchDBDiagnosticSignalCount) +
                       " / " +
                       IntegerToString(
                          ResearchDBDiagnosticExecutedTradeCount));
      DashboardAddLine(row, "Wins / Losses         : ",
                       IntegerToString(ResearchAnalyticsWinCount) +
                       " / " +
                       IntegerToString(ResearchAnalyticsLossCount));
      DashboardAddLine(row, "Profit Factor         : ",
                       DoubleToString(
                          ResearchAnalyticsProfitFactor, 2));
      DashboardAddLine(row, "Net Profit            : ",
                       DoubleToString(ResearchAnalyticsNetProfit, 2),
                       ProfitColor(ResearchAnalyticsNetProfit));
      DashboardAddLine(row, "Drawdown              : ",
                       DoubleToString(ResearchAnalyticsDrawdown, 2));
      DashboardAddLine(row, "Avg MAE / MFE         : ",
                       DoubleToString(ResearchAnalyticsAverageMAE, 1) +
                       " / " +
                       DoubleToString(ResearchAnalyticsAverageMFE, 1));
      DashboardAddLine(row, "Avg RR / Holding      : ",
                       DoubleToString(ResearchAnalyticsAverageRR, 2) +
                       " / " +
                       DoubleToString(
                          ResearchAnalyticsAverageHolding, 1));
   }
   else if(ActiveResearchSubTab == 1)
   {
      DashboardAddHeader(row, "[TRADE STATISTICS]");
      DashboardAddLine(row, "Win / Loss            : ",
                       IntegerToString(ResearchAnalyticsWinCount) +
                       " / " +
                       IntegerToString(ResearchAnalyticsLossCount));
      DashboardAddLine(row, "TP / SL / Timeout     : ",
                       IntegerToString(ResearchAnalyticsTPCount) + " / " +
                       IntegerToString(ResearchAnalyticsSLCount) + " / " +
                       IntegerToString(ResearchAnalyticsTimeoutCount));
      DashboardAddLine(row, "Average Profit        : ",
                       DoubleToString(
                          ResearchAnalyticsAverageProfit, 2));
      DashboardAddLine(row, "Average Loss          : ",
                       DoubleToString(
                          ResearchAnalyticsAverageLoss, 2));
      DashboardAddLine(row, "Largest Win           : ",
                       DoubleToString(
                          ResearchAnalyticsLargestWin, 2));
      DashboardAddLine(row, "Largest Loss          : ",
                       DoubleToString(
                          ResearchAnalyticsLargestLoss, 2));
      DashboardAddLine(row, "Average RR            : ",
                       DoubleToString(ResearchAnalyticsAverageRR, 2));
      DashboardAddLine(row, "Average Holding Bars  : ",
                       DoubleToString(
                          ResearchAnalyticsAverageHolding, 1));
   }
   else if(ActiveResearchSubTab == 2)
   {
      int pressureTotal =
         ResearchAnalyticsPressureLowCount +
         ResearchAnalyticsPressureMediumCount +
         ResearchAnalyticsPressureHighCount;
      DashboardAddHeader(row, "[PRESSURE STATISTICS]");
      DashboardAddLine(row, "LOW                   : ",
                       DashboardCountPercentage(
                          ResearchAnalyticsPressureLowCount,
                          pressureTotal));
      DashboardAddLine(row, "MEDIUM                : ",
                       DashboardCountPercentage(
                          ResearchAnalyticsPressureMediumCount,
                          pressureTotal));
      DashboardAddLine(row, "HIGH                  : ",
                       DashboardCountPercentage(
                          ResearchAnalyticsPressureHighCount,
                          pressureTotal));
      DashboardAddLine(row, "UP                    : ",
                       DashboardCountPercentage(
                          ResearchAnalyticsPressureUpCount,
                          pressureTotal));
      DashboardAddLine(row, "DOWN                  : ",
                       DashboardCountPercentage(
                          ResearchAnalyticsPressureDownCount,
                          pressureTotal));
      DashboardAddLine(row, "UNKNOWN               : ",
                       DashboardCountPercentage(
                          ResearchAnalyticsPressureUnknownCount,
                          pressureTotal));
      DashboardAddHeader(row, "[PRESSURE EXECUTION]");
      DashboardAddLine(row, "Signals               : ",
                       IntegerToString(
                          ResearchDBDiagnosticSignalCount));
      DashboardAddLine(row, "Blocked               : ",
                       IntegerToString(
                          ResearchDBDiagnosticBlockedSignalCount));
      DashboardAddLine(row, "Executed              : ",
                       IntegerToString(
                          ResearchDBDiagnosticExecutedTradeCount));
      DashboardAddLine(row, "WATCH / ALLOW         : ",
                       IntegerToString(ResearchAnalyticsWatchCount) +
                       " / " +
                       IntegerToString(ResearchAnalyticsAllowCount));
   }
   else if(ActiveResearchSubTab == 3)
   {
      DashboardAddHeader(row, "[RESEARCH VALIDATION]");
      DashboardAddLine(row, "Signals               : ",
                       IntegerToString(
                          ResearchDBDiagnosticSignalCount));
      DashboardAddLine(row, "Trades                : ",
                       IntegerToString(
                          ResearchDBDiagnosticExecutedTradeCount));
      DashboardAddLine(row, "Blocked               : ",
                       IntegerToString(
                          ResearchDBDiagnosticBlockedSignalCount));
      DashboardAddLine(row, "Orphan Signals        : ",
                       IntegerToString(
                          ResearchDBDiagnosticOrphanSignalCount));
      DashboardAddLine(row, "Orphan Trades         : ",
                       IntegerToString(
                          ResearchDBDiagnosticOrphanTradeCount));
      DashboardAddLine(row, "Attribution Errors    : ",
                       IntegerToString(
                          ResearchDBDiagnosticAttributionErrorCount));
      DashboardAddLine(row, "Validation Status     : ",
                       ResearchDBDiagnosticValidationStatus,
                       (ResearchDBDiagnosticValidationStatus == "OK")
                       ? clrGreen : clrRed);
      DashboardAddLine(row, "DB Last Error         : ",
                       ResearchDBLastErrorText);
   }
   else
   {
      DashboardAddHeader(row, "[EPISODE INFRASTRUCTURE]");
      DashboardAddLine(row, "Episodes              : ",
                       IntegerToString(ResearchAnalyticsEpisodeCount));
      DashboardAddLine(row, "Episode Trades        : ",
                       IntegerToString(
                          ResearchAnalyticsEpisodeTradeCount));
      DashboardAddLine(row, "Episode Net Profit    : ",
                       DoubleToString(
                          ResearchAnalyticsEpisodeNetProfit, 2));
      DashboardAddLine(row, "Episode Algorithm     : ",
                       "NOT IMPLEMENTED");
      DashboardAddLine(row, "Purpose               : ",
                       "Future performance-regime research");
   }

   DashboardClearUnusedLines(row);
}

void RenderDebugTab(string symbol)
{
   int row = 0;

   DashboardAddHeader(row, "TAB 12 : Developer Debug / Responsible Engine: Developer Engine");
   DashboardAddLine(row, "Rule Version          : ", APP_VERSION);
   DashboardAddLine(row, "Config Version        : ", "Alpha 1.0");
   DashboardAddLine(row, "Parameter Count       : ", "68");
   DashboardAddLine(row, "Evaluation Time       : ", "N/A");
   DashboardAddLine(row, "Memory Usage          : ", "N/A");
   DashboardAddLine(row, "Current Preset        : ", "Default");
   DashboardAddLine(row, "Rule Hash             : ", "N/A");
   DashboardAddLine(row, "Loaded Modules        : ", "Swing, Trend, Zone, Regime");
   DashboardAddLine(row, "Loaded Modules        : ", "Structure, Momentum, Entry, Execution");
   DashboardAddLine(row, "Symbol                : ", symbol);
   DashboardAddHeader(row, "[ZONE DEBUG]");
   DashboardAddLine(row, "ZoneLookbackBars      : ", IntegerToString(EffectiveZoneLookbackBars));
   DashboardAddLine(row, "BiasLookbackBars      : ", IntegerToString(EffectiveBiasLookbackBars));
   DashboardAddLine(row, "SwingRangePrice       : ", ZoneSwingRangePriceText);
   DashboardAddLine(row, "SwingRangePoints      : ", ZoneSwingRangePointsText);
   DashboardAddLine(row, "ATRPoints             : ", ZoneATRPointsText);
   DashboardAddLine(row, "MinATRRangePoints     : ", ZoneMinATRRangePointsText);
   DashboardAddLine(row, "MaxATRRangePoints     : ", ZoneMaxATRRangePointsText);
   DashboardAddLine(row, "ValidationReason      : ", ZoneValidationReasonText);
   DashboardAddLine(row, "FallbackUsed          : ", ZoneFallbackUsedText);
   DashboardAddLine(row, "ZoneSource            : ", ZoneSourceText);
   DashboardAddLine(row, "Execution Mode        : ", ExecutionModeText);
   DashboardAddLine(row, "Execution Allowed     : ", ExecutionAllowedText, ExecutionStatusColor());
   DashboardAddLine(row, "Runtime               : ", ExecutionRuntimeText);
   DashboardAddLine(row, "Last Execution Action : ", LastExecutionAction, ExecutionStatusColor());
   DashboardAddLine(row, "Last Execution Reason : ", LastExecutionReason, ExecutionStatusColor());
   DashboardAddLine(row, "Symbol Volume Min     : ", DoubleToString(ExecutionVolumeMin, 4));
   DashboardAddLine(row, "Symbol Volume Max     : ", DoubleToString(ExecutionVolumeMax, 4));
   DashboardAddLine(row, "Symbol Volume Step    : ", DoubleToString(ExecutionVolumeStep, 4));
   DashboardAddLine(row, "Trade Tick Size       : ", DoubleToString(ExecutionTickSize, ExecutionDigits));
   DashboardAddLine(row, "Trade Tick Value      : ", DoubleToString(ExecutionTickValue, 4));
   DashboardAddLine(row, "Stops Level           : ", IntegerToString((int)ExecutionStopsLevel));
   DashboardAddLine(row, "Freeze Level          : ", IntegerToString((int)ExecutionFreezeLevel));
   DashboardAddLine(row, "Symbol Point          : ", DoubleToString(ExecutionPoint, ExecutionDigits));
   DashboardAddLine(row, "Symbol Digits         : ", IntegerToString(ExecutionDigits));
   DashboardAddLine(row, "Legacy AutoTrade      : ", (AutoTrade ? "ON" : "OFF") + " / Not used by Execution Engine", AutoTrade ? clrRed : clrGreen);
   DashboardAddLine(row, "Active Tab            : ", DashboardTabName(ActiveDashboardTab));

   DashboardAddHeader(row, "[TIMEOUT MANAGEMENT]");
   DashboardAddLine(row, "UseBacktestMaxHolding : ", UseBacktestMaxHoldingBars ? "true" : "false");
   DashboardAddLine(row, "BacktestMaxHoldingBars: ", IntegerToString(BacktestMaxHoldingBars));
   DashboardAddLine(row, "HoldingBarsTF         : ", TimeoutHoldingTFText);
   DashboardAddLine(row, "LastTimeoutTicket     : ", TimeoutLastTicketText);
   DashboardAddLine(row, "LastTimeoutCloseResult: ", TimeoutLastCloseResultText);

   DashboardAddHeader(row, "[CSV JOURNAL]");
   DashboardAddLine(row, "CSV Log Enabled       : ", JournalCSVEnabledText);
   DashboardAddLine(row, "CSV Market Label      : ", JournalMarketLabelText);
   DashboardAddLine(row, "CSV Location          : ", JournalCSVLocationText);
   DashboardAddLine(row, "CSV File              : ", StringSubstr(JournalCSVFileName, 0, 60));
   if(StringLen(JournalCSVFileName) > 60)
      DashboardAddLine(row, "CSV File (cont.)      : ", StringSubstr(JournalCSVFileName, 60, 60));
   if(StringLen(JournalCSVFileName) > 120)
      DashboardAddLine(row, "CSV File (cont.)      : ", StringSubstr(JournalCSVFileName, 120, 60));
   if(StringLen(JournalCSVFileName) > 180)
      DashboardAddLine(row, "CSV File (cont.)      : ", StringSubstr(JournalCSVFileName, 180));
   DashboardAddLine(row, "Signals Logged        : ", IntegerToString(JournalSignalsLogged));
   DashboardAddLine(row, "Trades Open Logged    : ", IntegerToString(JournalTradesOpenLogged));
   DashboardAddLine(row, "Trades Close Logged   : ", IntegerToString(JournalTradesCloseLogged));
   DashboardAddLine(row, "CSV Last Write        : ", JournalCSVLastWriteText);
   DashboardAddLine(row, "CSV Status            : ", JournalCSVStatusText);

   DashboardAddHeader(row, "[RESEARCH DB]");
   DashboardAddLine(row, "Use Research DB       : ", UseResearchDB ? "true" : "false");
   DashboardAddLine(row, "Research DB Status    : ", ResearchDBStatusText,
                    (ResearchDBStatusText == "ERROR") ? clrRed :
                    ((ResearchDBStatusText == "OK") ? clrGreen : clrGray));
   DashboardAddLine(row, "Research DB Path      : ", StringSubstr(ResearchDBPathText, 0, 70));
   if(StringLen(ResearchDBPathText) > 70)
      DashboardAddLine(row, "DB Path (cont.)       : ", StringSubstr(ResearchDBPathText, 70));
   DashboardAddLine(row, "Research DB Filename  : ", ResearchDBFilenameText);
   DashboardAddLine(row, "Experiment ID         : ", IntegerToString(ResearchDBExperimentID));
   DashboardAddLine(row, "Last Signal ID        : ", IntegerToString(ResearchDBLastSignalID));
   DashboardAddLine(row, "Last Trade ID         : ", IntegerToString(ResearchDBLastTradeID));
   DashboardAddLine(row, "Last DB Write Time    : ", ResearchDBLastWriteTimeText);
   DashboardAddLine(row, "Last DB Error         : ", ResearchDBLastErrorText,
                    (ResearchDBLastErrorText == "N/A") ? clrGray : clrRed);
   DashboardAddLine(row, "DB Signals Written    : ", IntegerToString(ResearchDBTotalSignalsWritten));
   DashboardAddLine(row, "DB Trades Open Written: ", IntegerToString(ResearchDBTotalTradesOpenedWritten));
   DashboardAddLine(row, "DB Trades Close Writ. : ", IntegerToString(ResearchDBTotalTradesClosedWritten));
   DashboardAddLine(row, "DB Schema Version     : ", IntegerToString(ResearchDBSchemaVersion));
   DashboardAddLine(row, "Pressure Policy Gov.  : ", ResearchDBPressurePolicyIsGoverning ? "YES" : "NO");
   DashboardAddLine(row, "Policy Snapshot Count : ", IntegerToString(ResearchDBPolicySnapshotCount));
   DashboardAddLine(row, "Future Outcome Count  : ", IntegerToString(ResearchDBFutureOutcomeCount));
   DashboardAddLine(row, "Analysis Cache Count  : ", IntegerToString(ResearchDBAnalysisCacheCount));
   DashboardAddLine(row, "View Definition Count : ", IntegerToString(ResearchDBViewDefinitionCount));
   DashboardAddLine(row, "Actual View Status    : ", ResearchDBActualViewCreateStatusText,
                    (ResearchDBActualViewCreateStatusText == "CREATED") ? clrGreen : clrGoldenrod);
   DashboardAddLine(row, "Last View Error       : ", ResearchDBLastViewCreateErrorText,
                    (ResearchDBLastViewCreateErrorText == "N/A") ? clrGray : clrRed);

   DashboardAddHeader(row, "[RESEARCH DB DIAGNOSTICS]");
   DashboardAddLine(row, "Signals               : ",
                    IntegerToString(ResearchDBDiagnosticSignalCount));
   DashboardAddLine(row, "Executed Trades       : ",
                    IntegerToString(
                       ResearchDBDiagnosticExecutedTradeCount));
   DashboardAddLine(row, "Blocked Signals       : ",
                    IntegerToString(
                       ResearchDBDiagnosticBlockedSignalCount));
   DashboardAddLine(row, "Saved Loss Candidates : ",
                    IntegerToString(ResearchDBDiagnosticSavedLossCount));
   DashboardAddLine(row, "Missed Win Candidates : ",
                    IntegerToString(ResearchDBDiagnosticMissedWinCount));
   DashboardAddLine(row, "Attribution Errors    : ",
                    IntegerToString(
                       ResearchDBDiagnosticAttributionErrorCount));
   DashboardAddLine(row, "Orphan Signals        : ",
                    IntegerToString(
                       ResearchDBDiagnosticOrphanSignalCount));
   DashboardAddLine(row, "Orphan Trades         : ",
                    IntegerToString(
                       ResearchDBDiagnosticOrphanTradeCount));
   DashboardAddLine(row, "Validation Status     : ",
                    ResearchDBDiagnosticValidationStatus,
                    (ResearchDBDiagnosticValidationStatus == "OK")
                    ? clrGreen : clrRed);

   DashboardClearUnusedLines(row);
}

void DashboardRenderActiveTab(string symbol)
{
   if(ActiveDashboardTab != 8)
      DashboardHideTradeSubTabs();

   if(ActiveDashboardTab != 0)
   {
      DashboardHideSummaryCards();
      DashboardHideSummarySubTabs();
   }

   if(ActiveDashboardTab != 7)
      DashboardHideDecisionSubTabs();

   if(ActiveDashboardTab != 3)
      DashboardHideStructureSubTabs();

   if(ActiveDashboardTab != 6)
      DashboardHidePressureSubTabs();

   if(ActiveDashboardTab != 10)
      DashboardHideResearchSubTabs();

   if(ActiveDashboardTab == 0) { RenderSummaryTab(symbol); return; }
   if(ActiveDashboardTab == 1) { RenderMarketTab(symbol); return; }
   if(ActiveDashboardTab == 2) { RenderZoneTab(); return; }
   if(ActiveDashboardTab == 3) { RenderStructureTab(symbol); return; }
   if(ActiveDashboardTab == 4) { RenderMomentumTab(); return; }
   if(ActiveDashboardTab == 5) { RenderRiskTab(symbol); return; }
   if(ActiveDashboardTab == 6) { RenderPressureTab(); return; }
   if(ActiveDashboardTab == 7) { RenderDecisionTab(); return; }
   if(ActiveDashboardTab == 8) { RenderTradeTab(); return; }
   if(ActiveDashboardTab == 9) { RenderPerformanceTab(); return; }
   if(ActiveDashboardTab == 10 && UseResearchDB)
      { RenderResearchTab(symbol); return; }
   if(ActiveDashboardTab == 11) { RenderDebugTab(symbol); return; }

   ActiveDashboardTab = 0;
   RenderSummaryTab(symbol);
}

void DashboardEngine(string symbol)
{
   DashboardCleanupLegacyObjects();

   if(!DashboardVisible)
   {
      DashboardHidePanelObjects();
      DashboardDrawToggleButton();
      return;
   }

   string bgName = "TRE_DASHBOARD_BG";

   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 940);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, DashboardPanelHeight());
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   DashboardDrawText("TRE_DASH_TITLE", TRE_DASH_CONTENT_X, 30, APP_NAME + " " + APP_VERSION + " - " + ExecutionModeText, clrBlack, 10);
   DashboardDrawText("TRE_DASH_NAV_TITLE", 24, 34, "TABS", clrDimGray, 8);
   DashboardRenderTabs();
   DashboardRenderActiveTab(symbol);
   DashboardDrawToggleButton();
}

void DashboardHandleChartEvent(const int id, const string sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(sparam == "TRE_DASH_TOGGLE")
   {
      DashboardVisible = !DashboardVisible;
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ObjectDelete(0, sparam);
      DashboardEngine(GetTradeSymbol());
      return;
   }

   for(int tab = 0; tab < TRE_DASH_TAB_COUNT; tab++)
   {
      string name = "TRE_DASH_TAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActiveDashboardTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }

   for(int tab = 0; tab < TRE_SUMMARY_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_SUMMARY_SUBTAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActiveSummarySubTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }

   for(int tab = 0; tab < TRE_DECISION_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_DECISION_SUBTAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActiveDecisionSubTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }

   for(int tab = 0; tab < TRE_STRUCTURE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_STRUCTURE_SUBTAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActiveStructureSubTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }

   for(int tab = 0; tab < TRE_PRESSURE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_PRESSURE_SUBTAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActivePressureSubTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }

   for(int tab = 0; tab < TRE_TRADE_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_TRADE_SUBTAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActiveTradeSubTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }

   for(int tab = 0; tab < TRE_RESEARCH_SUBTAB_COUNT; tab++)
   {
      string name = "TRE_RESEARCH_SUBTAB_" + IntegerToString(tab);

      if(sparam == name)
      {
         ActiveResearchSubTab = tab;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         DashboardEngine(GetTradeSymbol());
         return;
      }
   }
}

#endif
