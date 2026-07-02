//+------------------------------------------------------------------+
//| GoldTradingEA.mq5                                                |
//| Trading Rule Engine - Alpha 1.0                                  |
//| Modular refactor from GoldMicro Zone Dashboard v0.3              |
//| Live-safe with Strategy Tester execution mode                    |
//+------------------------------------------------------------------+
#property strict

#include "include/version.mqh"
#include "include/config.mqh"
#include "include/evidence.mqh"
#include "include/globals.mqh"
#include "include/common.mqh"

#include "engine/swing_engine.mqh"
#include "engine/trend_engine.mqh"
#include "engine/zone_engine.mqh"
#include "engine/regime_engine.mqh"
#include "engine/structure_engine.mqh"
#include "engine/momentum_engine.mqh"
#include "engine/pressure_guard_engine.mqh"
#include "engine/entry_engine.mqh"
#include "engine/pressure_execution_block_engine.mqh"
#include "engine/market_snapshot_engine.mqh"
#include "engine/adaptive_loss_cluster_engine.mqh"
#include "engine/adaptive_shadow_engine.mqh"
#include "engine/execution_engine.mqh"
#include "engine/trade_engine.mqh"
#include "engine/journal_engine.mqh"
#include "engine/research_db_engine.mqh"
#include "engine/draw_engine.mqh"
#include "engine/dashboard_engine.mqh"

void RunEngineCycle(bool allowBacktestExecution)
{
   string symbol = GetTradeSymbol();

   // Strategy Tester may not dispatch chart click events, so poll button state.
   DashboardPollButtonState();

   SwingEngine(symbol);
   TrendEngine();
   ZoneEngine(symbol);
   StructureEngine(symbol);
   MomentumEngine(symbol);
   RegimeEngine(symbol);
   PressureGuardEngine(symbol);
   EntryEngine();
   PressureExecutionBlockEngine(symbol);
   AdaptiveLossClusterEngine(symbol);
   MarketSnapshotEngine(symbol);

   if(allowBacktestExecution)
      ExecutionEngine(symbol);
   else
      TRE_RefreshExecutionState(symbol);

   AdaptiveShadowEngine(symbol);
   TradeEngine(symbol);
   JournalEngine(symbol);
   ResearchDBEngine(symbol);
   DrawEngine();
   DashboardEngine(symbol);
}

int OnInit()
{
   int refreshSeconds = (EngineRefreshSeconds < 1) ? 1 : EngineRefreshSeconds;
   EventSetTimer(refreshSeconds);
   TRE_InitializeResearchConfig();
   JournalInitialize(GetTradeSymbol());
   ResearchDBInitialize(GetTradeSymbol());

   Print("----------------------------------------");
   Print("TRE INPUT CONFIGURATION");
   Print("----------------------------------------");
   Print("UseAutoRegimeDetection=",
         UseAutoRegimeDetection);
   Print("AllowAutoProfileSwitch=",
         AllowAutoProfileSwitch);
   Print("ManualMarketProfile=",
         TRE_MarketProfileToText(ManualMarketProfile));
   Print("RegimeTF=", TimeframeToText(RegimeTF));
   Print("RegimeLookbackBars=", RegimeLookbackBars);
   Print("RegimeConfirmBars=", RegimeConfirmBars);
   Print("RegimeSwitchThreshold=", RegimeSwitchThreshold);
   Print("RegimeHoldBars=", RegimeHoldBars);
   Print("EnableWeekendProtection=", EnableWeekendProtection);
   Print("WeekendBlockTime=",
         TRE_WeekendDayToText(WeekendBlockDay), " >= ",
         TRE_WeekendHour(WeekendBlockHour), ":00");
   Print("WeekendForceCloseTime=",
         TRE_WeekendDayToText(WeekendBlockDay), " >= ",
         TRE_WeekendHour(WeekendForceCloseHour), ":00");
   Print("EnableAdaptiveLossCluster=",
         EnableAdaptiveLossCluster);
   Print("LossClusterThreshold=",
         AdaptiveEffectiveThreshold());
   Print("LossClusterCooldownBars=",
         AdaptiveEffectiveCooldown());
   Print("AdaptiveClusterMode=",
         AdaptiveClusterModeText());
   Print("UseAdvancedAdaptiveCluster=",
         UseAdvancedAdaptiveCluster,
         " (reserved/inactive)");
   Print("AdaptiveRuleValidation=STATIC_V1");
   Print("AdaptiveApprovedPatterns=",
         AdaptiveRuleValidationPatternList(true));
   Print("AdaptiveRejectedPatterns=",
         AdaptiveRuleValidationPatternList(false));
   Print("InputSource=", RegimeInputSourceText);
   Print(APP_NAME, " ", APP_VERSION, " started.");
   RunEngineCycle(false);
   Print("----------------------------------------");
   Print("TRE RUNTIME STATE");
   Print("----------------------------------------");
   Print("MarketDetectionStatus=",
         MarketDetectionStatusText);
   Print("AutoProfileSwitchStatus=",
         AutoProfileSwitchStatusText);
   Print("ProfileSource=", RegimeProfileSourceText);
   Print("ResearchMode=", RegimeResearchModeText);
   Print("DetectedRegime=", DetectedRegimeText);
   Print("ActiveRegime=", ActiveRegimeText);
   Print("RegimeSwitchStatus=", RegimeSwitchStatusText);
   Print("RegimeBlockingReason=", RegimeBlockingReasonText);
   return(INIT_SUCCEEDED);
}

void OnTick()
{
   RunEngineCycle(true);
}

void OnTimer()
{
   // Timer refresh never sends orders. Backtest execution is tick-driven only.
   RunEngineCycle(false);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ResearchDBFinalize();
   JournalFinalize(GetTradeSymbol());
   ZoneReleaseATRHandle();
   RegimeReleaseIndicatorHandles();
   ClearTREObjects();
   Comment("");
   Print(APP_NAME, " ", APP_VERSION, " stopped.");
}

double OnTester()
{
   ResearchDBFinalize();
   JournalFinalize(GetTradeSymbol());
   return 0.0;
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   DashboardHandleChartEvent(id, sparam);
}
