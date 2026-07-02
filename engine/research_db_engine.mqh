//+------------------------------------------------------------------+
//| engine/research_db_engine.mqh                                   |
//| Optional fail-open SQLite research flight recorder              |
//+------------------------------------------------------------------+
#ifndef TRE_RESEARCH_DB_ENGINE_MQH
#define TRE_RESEARCH_DB_ENGINE_MQH

#define TRE_RESEARCH_DB_MAX_TRADES 64

struct TRE_ResearchDBTrade
{
   bool active;
   long tradeId;
   long signalId;
   ulong ticket;
   long identifier;
   long type;
   datetime openTime;
   datetime entryBar;
   int executionDelaySeconds;
   int executionDelayBars;
   double volume;
   double openPrice;
   double stopLoss;
   double takeProfit;
   double requestedSLPoints;
   double requestedTPPoints;
   double effectiveSLPoints;
   double effectiveTPPoints;
   double symbolPoint;
   double tickSize;
   double tickValue;
   double spreadAtEntry;
   double plannedRR;
   double maePoints;
   double mfePoints;
   double maxFloatingProfit;
   double maxFloatingLoss;
   string pressureDirection;
   string pressureLevel;
   double pressureScore;
   string regime;
   int zone;
   string decision;
};

int TREResearchDBHandle = INVALID_HANDLE;
bool TREResearchDBInitialized = false;
datetime TREResearchDBStartedAt = 0;
datetime TREResearchDBLastSignalBar = 0;
TRE_ResearchDBTrade TREResearchDBTrades[TRE_RESEARCH_DB_MAX_TRADES];

string ResearchDBTimeText(datetime value)
{
   if(value <= 0)
      return "N/A";
   return TimeToString(value, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
}

string ResearchDBTimestamp(datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return StringFormat("%04d%02d%02d_%02d%02d%02d",
                       parts.year, parts.mon, parts.day,
                       parts.hour, parts.min, parts.sec);
}

string ResearchDBSafeFilePart(string value)
{
   StringReplace(value, " ", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, "\\", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, "*", "_");
   StringReplace(value, "?", "_");
   return value;
}

string ResearchDBSQLText(string value)
{
   StringReplace(value, "'", "''");
   return "'" + value + "'";
}

string ResearchDBSQLInteger(long value)
{
   return IntegerToString(value);
}

string ResearchDBSQLID(long value)
{
   return (value > 0) ? IntegerToString(value) : "NULL";
}

string ResearchDBSQLDouble(double value)
{
   return DoubleToString(value, 12);
}

int ResearchDBBool(bool value)
{
   return value ? 1 : 0;
}

int ResearchDBTextBool(string value)
{
   StringToUpper(value);
   return (value == "YES" || value == "TRUE" ||
           value == "ON" || value == "PASS") ? 1 : 0;
}

double ResearchDBTextDouble(string value)
{
   if(value == "" || value == "N/A")
      return 0;
   return StringToDouble(value);
}

void ResearchDBFail(string operation)
{
   int errorCode = GetLastError();
   ResearchDBStatusText = "ERROR";
   ResearchDBLastErrorText =
      operation + " failed, error " + IntegerToString(errorCode);
   Print("TRE Research DB: ", ResearchDBLastErrorText);
   ResetLastError();
}

void ResearchDBVerbose(string message)
{
   if(ResearchDBVerboseLog)
      Print("TRE Research DB: ", message);
}

bool ResearchDBCanWrite()
{
   return (UseResearchDB &&
           TREResearchDBHandle != INVALID_HANDLE);
}

bool ResearchDBExecute(string sql, string operation)
{
   if(!ResearchDBCanWrite())
      return false;

   ResetLastError();
   if(!DatabaseExecute(TREResearchDBHandle, sql))
   {
      ResearchDBFail(operation);
      return false;
   }
   return true;
}

bool ResearchDBExecutePrepared(int request, string operation)
{
   if(request == INVALID_HANDLE)
   {
      ResearchDBFail(operation + " prepare");
      return false;
   }

   ResetLastError();
   bool result = DatabaseRead(request);
   int errorCode = GetLastError();
   DatabaseFinalize(request);

   if(!result && errorCode != ERR_DATABASE_NO_MORE_DATA)
   {
      ResearchDBFail(operation);
      return false;
   }
   ResetLastError();
   return true;
}

long ResearchDBLastInsertID()
{
   int request =
      DatabasePrepare(TREResearchDBHandle,
                      "SELECT last_insert_rowid()");
   if(request == INVALID_HANDLE)
   {
      ResearchDBFail("read last_insert_rowid");
      return 0;
   }

   long value = 0;
   ResetLastError();
   if(DatabaseRead(request))
      DatabaseColumnLong(request, 0, value);
   else if(GetLastError() != ERR_DATABASE_NO_MORE_DATA)
      ResearchDBFail("read last_insert_rowid");

   DatabaseFinalize(request);
   ResetLastError();
   return value;
}

long ResearchDBInsert(string sql, string operation)
{
   if(!ResearchDBExecute(sql, operation))
      return 0;
   return ResearchDBLastInsertID();
}

bool ResearchDBColumnExists(string tableName, string columnName)
{
   int request = DatabasePrepare(
      TREResearchDBHandle, "PRAGMA table_info(" + tableName + ")");
   if(request == INVALID_HANDLE)
      return false;
   bool found = false;
   while(DatabaseRead(request))
   {
      string name = "";
      if(DatabaseColumnText(request, 1, name) && name == columnName)
      {
         found = true;
         break;
      }
   }
   DatabaseFinalize(request);
   ResetLastError();
   return found;
}

bool ResearchDBEnsureColumn(string tableName, string columnName,
                            string columnType)
{
   if(ResearchDBColumnExists(tableName, columnName))
      return true;
   return ResearchDBExecute(
      "ALTER TABLE " + tableName + " ADD COLUMN " +
      columnName + " " + columnType,
      "add " + tableName + "." + columnName);
}

bool ResearchDBApplyFlightRecorderMigration()
{
   string tables[] = {
      "experiment","experiment","experiment","experiment","experiment",
      "experiment","experiment","experiment","experiment",
      "signal","signal","signal","signal","signal","signal","signal",
      "signal","signal","signal","signal","signal","signal","signal",
      "signal","signal","signal","signal",
      "zone_snapshot","zone_snapshot","zone_snapshot","zone_snapshot",
      "zone_snapshot","zone_snapshot","zone_snapshot","zone_snapshot",
      "zone_snapshot","zone_snapshot",
      "regime_snapshot","regime_snapshot","regime_snapshot",
      "pressure_snapshot","pressure_snapshot","pressure_snapshot",
      "pressure_snapshot","pressure_snapshot","pressure_snapshot",
      "decision_snapshot","decision_snapshot","decision_snapshot",
      "trade_open","trade_open"
   };
   string columns[] = {
      "experiment_name","git_commit","engine_version","zone_version",
      "structure_version","regime_version","pressure_version",
      "decision_version","profile_version",
      "server_time","zone_tf","bias_tf","entry_tf","execution_tf",
      "pressure_tf","regime_tf","open_price","high_price","low_price",
      "close_price","current_price","atr_value","adr_value","tick_volume",
      "candle_body","upper_shadow","lower_shadow",
      "zone_state","zone_upper","zone_lower","zone_width",
      "distance_to_zone","zone_age","touch_count","break_count",
      "rejection_count","swing_validation_result",
      "trend_strength","volatility_score","ema_slope",
      "bull_probability","bear_probability","ema_component",
      "momentum_component","structure_component","close_component",
      "candidate_score","candidate_confidence","decision_profile",
      "risk_percent","execution_reason"
   };
   string types[] = {
      "TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT",
      "TEXT","TEXT","TEXT","TEXT","TEXT","TEXT","TEXT",
      "REAL","REAL","REAL","REAL","REAL","REAL","REAL","INTEGER",
      "REAL","REAL","REAL",
      "TEXT","REAL","REAL","REAL","REAL","INTEGER","INTEGER","INTEGER",
      "INTEGER","TEXT",
      "TEXT","REAL","REAL",
      "REAL","REAL","REAL","REAL","REAL","REAL",
      "REAL","TEXT","TEXT","REAL","TEXT"
   };
   for(int i = 0; i < ArraySize(tables); i++)
      if(!ResearchDBEnsureColumn(tables[i], columns[i], types[i]))
         return false;
   if(!ResearchDBEnsureColumn("experiment",
         "use_pressure_execution_block", "INTEGER") ||
      !ResearchDBEnsureColumn("experiment",
         "pressure_execution_block_mode", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "pressure_execution_block_mode_id", "INTEGER") ||
      !ResearchDBEnsureColumn("experiment",
         "pressure_execution_block_mode_name", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_execution_block_enabled", "INTEGER") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_execution_block_mode", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_execution_block_mode_id", "INTEGER") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_execution_block_mode_name", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_execution_block_applied", "INTEGER") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_execution_block_reason", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "blocked_candidate_direction", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "blocked_pressure_direction", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "blocked_pressure_level", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "blocked_pressure_score", "REAL") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "actual_execution_decision", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "schema_version", "INTEGER") ||
      !ResearchDBEnsureColumn("experiment",
         "research_version", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "pressure_mode", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "profile", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "timeframe", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "date_start", "TEXT") ||
      !ResearchDBEnsureColumn("experiment",
         "date_end", "TEXT") ||
      !ResearchDBEnsureColumn("signal",
         "signal_bar", "TEXT") ||
      !ResearchDBEnsureColumn("signal",
         "candidate_direction", "TEXT") ||
      !ResearchDBEnsureColumn("signal",
         "signal_kind", "TEXT") ||
      !ResearchDBEnsureColumn("signal",
         "snapshot_version", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_open",
         "entry_time", "TEXT") ||
      !ResearchDBEnsureColumn("trade_open",
         "entry_bar", "TEXT") ||
      !ResearchDBEnsureColumn("trade_open",
         "execution_delay_seconds", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_open",
         "execution_delay_bars", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_close",
         "entry_time", "TEXT") ||
      !ResearchDBEnsureColumn("trade_close",
         "entry_bar", "TEXT") ||
      !ResearchDBEnsureColumn("trade_close",
         "exit_time", "TEXT") ||
      !ResearchDBEnsureColumn("trade_close",
         "exit_bar", "TEXT") ||
      !ResearchDBEnsureColumn("trade_close",
         "execution_delay_seconds", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_close",
         "execution_delay_bars", "INTEGER") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_guard_enabled", "INTEGER") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "pressure_guard_mode", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "profile", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "regime", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "zone", "INTEGER") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "structure", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "momentum", "TEXT") ||
      !ResearchDBEnsureColumn("policy_snapshot",
         "ema_state", "TEXT") ||
      !ResearchDBEnsureColumn("trade_close",
         "requested_sl_points", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "requested_tp_points", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "effective_sl_points", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "effective_tp_points", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "entry_price", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "sl_price", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "tp_price", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "close_reason", "TEXT") ||
      !ResearchDBEnsureColumn("trade_close",
         "actual_volume", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "symbol_point", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "tick_size", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "tick_value", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "spread_at_entry", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "gross_profit", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "net_profit", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "expected_loss_money", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "expected_profit_money", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "profit_deviation_money", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "profit_deviation_points", "REAL") ||
      !ResearchDBEnsureColumn("trade_close",
         "is_exact_sl_hit", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_close",
         "is_exact_tp_hit", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_close",
         "is_timeout_exit", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_close",
         "is_tester_close", "INTEGER") ||
      !ResearchDBEnsureColumn("trade_close",
         "audit_reason", "TEXT"))
      return false;
   return true;
}

bool ResearchDBCreateSchema()
{
   string experiment =
      "CREATE TABLE IF NOT EXISTS experiment("
      "experiment_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "created_at TEXT,symbol TEXT,account_server TEXT,account_login TEXT,"
      "ea_name TEXT,ea_version TEXT,execution_mode TEXT,"
      "is_strategy_tester INTEGER,market_label TEXT,manual_profile TEXT,"
      "use_auto_regime_detection INTEGER,allow_auto_profile_switch INTEGER,"
      "use_pressure_guard INTEGER,pressure_guard_mode TEXT,"
      "use_research_db INTEGER,use_csv_logger INTEGER,"
      "zone_tf TEXT,bias_tf TEXT,entry_tf TEXT,execution_tf TEXT,"
      "pressure_tf TEXT,regime_tf TEXT,"
      "zone_lookback_bars INTEGER,bias_lookback_bars INTEGER,"
      "regime_lookback_bars INTEGER,pressure_lookback_bars INTEGER,"
      "use_atr_validation INTEGER,atr_period INTEGER,"
      "atr_min_multiplier REAL,atr_max_multiplier REAL,"
      "backtest_fixed_lot REAL,backtest_sl_points REAL,"
      "backtest_tp_points REAL,backtest_magic_number INTEGER,"
      "use_backtest_max_holding_bars INTEGER,"
      "backtest_max_holding_bars INTEGER,"
      "pressure_medium_threshold REAL,pressure_high_threshold REAL,"
      "pressure_medium_penalty REAL,pressure_high_penalty REAL,"
      "pressure_high_downgrade_to_watch INTEGER,"
      "pressure_soft_block_only_in_sideway_or_unknown INTEGER,"
      "pressure_use_ema_filter INTEGER,pressure_ema_period INTEGER,"
      "pressure_use_structure_development INTEGER,"
      "pressure_use_momentum INTEGER)";

   string signal =
      "CREATE TABLE IF NOT EXISTS signal("
      "signal_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_time TEXT,bar_time TEXT,"
      "symbol TEXT,timeframe TEXT,bid REAL,ask REAL,last_close REAL,"
      "spread_points REAL,candidate_direction_before_pressure TEXT,"
      "decision_before_pressure TEXT,decision_after_pressure TEXT,"
      "final_decision TEXT,entry_reason TEXT,missing_condition TEXT,"
      "score_before_pressure REAL,pressure_penalty_applied REAL,"
      "score_after_pressure REAL,final_signal_score REAL,"
      "trend_score REAL,zone_score REAL,structure_score REAL,"
      "momentum_score REAL,pressure_score REAL,risk_score REAL,"
      "is_ready_signal INTEGER,is_trade_opened INTEGER,trade_id INTEGER,"
      "blocked_by_pressure INTEGER,downgraded_by_pressure INTEGER,"
      "zone_snapshot_id INTEGER,structure_snapshot_id INTEGER,"
      "regime_snapshot_id INTEGER,pressure_snapshot_id INTEGER,"
      "decision_snapshot_id INTEGER,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(zone_snapshot_id) "
      "REFERENCES zone_snapshot(zone_snapshot_id),"
      "FOREIGN KEY(structure_snapshot_id) "
      "REFERENCES structure_snapshot(structure_snapshot_id),"
      "FOREIGN KEY(regime_snapshot_id) "
      "REFERENCES regime_snapshot(regime_snapshot_id),"
      "FOREIGN KEY(pressure_snapshot_id) "
      "REFERENCES pressure_snapshot(pressure_snapshot_id),"
      "FOREIGN KEY(decision_snapshot_id) "
      "REFERENCES decision_snapshot(decision_snapshot_id))";

   string zone =
      "CREATE TABLE IF NOT EXISTS zone_snapshot("
      "zone_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,zone_tf TEXT,"
      "zone_id INTEGER,zone_label TEXT,zone_strength TEXT,"
      "zone_score REAL,zone_reason TEXT,zone_missing_condition TEXT,"
      "price REAL,zone_high REAL,zone_low REAL,zone_mid REAL,"
      "zone_width_points REAL,distance_to_zone_mid_points REAL,"
      "zone_source TEXT,swing_high REAL,swing_low REAL,"
      "swing_range_points REAL,fallback_used INTEGER,"
      "fallback_reason TEXT,use_swing_validation INTEGER,"
      "minimum_swing_range_points REAL,use_atr_validation INTEGER,"
      "atr_value REAL,atr_points REAL,atr_min_points REAL,"
      "atr_max_points REAL,atr_validation_result TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string structure =
      "CREATE TABLE IF NOT EXISTS structure_snapshot("
      "structure_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,entry_tf TEXT,"
      "confirmed_structure TEXT,structure_stage TEXT,"
      "validation_stage TEXT,development_state TEXT,"
      "structure_early_warning TEXT,"
      "structure_early_warning_reason TEXT,structure_score REAL,"
      "structure_confidence TEXT,structure_reason TEXT,"
      "missing_structure_reason TEXT,current_swing_high REAL,"
      "previous_swing_high REAL,current_swing_low REAL,"
      "previous_swing_low REAL,swing_high_count INTEGER,"
      "swing_low_count INTEGER,swing_pair_count INTEGER,"
      "hh_count INTEGER,hl_count INTEGER,lh_count INTEGER,ll_count INTEGER,"
      "bos_state TEXT,choch_state TEXT,strong_directional_move TEXT,"
      "recent_bearish_close_count INTEGER,"
      "recent_bullish_close_count INTEGER,"
      "consecutive_bearish_bars INTEGER,"
      "consecutive_bullish_bars INTEGER,recent_lower_low_count INTEGER,"
      "recent_higher_high_count INTEGER,recent_lower_close_count INTEGER,"
      "recent_higher_close_count INTEGER,price_above_ema INTEGER,"
      "price_below_ema INTEGER,ema_slope_direction TEXT,"
      "distance_from_ema_points REAL,pending_swing_high_status TEXT,"
      "pending_swing_high_price REAL,"
      "pending_swing_high_right_bars_waited INTEGER,"
      "pending_swing_high_right_bars_required INTEGER,"
      "pending_swing_low_status TEXT,pending_swing_low_price REAL,"
      "pending_swing_low_right_bars_waited INTEGER,"
      "pending_swing_low_right_bars_required INTEGER,"
      "mapping_status TEXT,mapping_reason TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string regime =
      "CREATE TABLE IF NOT EXISTS regime_snapshot("
      "regime_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,"
      "use_auto_regime_detection INTEGER,"
      "allow_auto_profile_switch INTEGER,manual_market_profile TEXT,"
      "detected_regime TEXT,best_candidate_regime TEXT,"
      "active_regime TEXT,regime_confidence REAL,"
      "uptrend_score REAL,sideway_score REAL,downtrend_score REAL,"
      "score_gap REAL,regime_switch_status TEXT,"
      "regime_blocking_reason TEXT,market_detection_status TEXT,"
      "auto_profile_switch_status TEXT,profile_source TEXT,"
      "regime_reason TEXT,regime_missing_condition TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string pressure =
      "CREATE TABLE IF NOT EXISTS pressure_snapshot("
      "pressure_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,use_pressure_guard INTEGER,"
      "pressure_guard_mode TEXT,pressure_tf TEXT,"
      "pressure_lookback_bars INTEGER,pressure_direction TEXT,"
      "pressure_level TEXT,pressure_score REAL,"
      "bullish_pressure_score REAL,bearish_pressure_score REAL,"
      "pressure_action TEXT,pressure_blocked_direction TEXT,"
      "pressure_reason TEXT,pressure_applies_to_candidate INTEGER,"
      "pressure_decision_impact TEXT,"
      "candidate_direction_before_pressure TEXT,"
      "decision_before_pressure TEXT,score_before_pressure REAL,"
      "pressure_penalty_applied REAL,score_after_pressure REAL,"
      "decision_after_pressure TEXT,consecutive_bullish_bars INTEGER,"
      "consecutive_bearish_bars INTEGER,recent_higher_closes INTEGER,"
      "recent_lower_closes INTEGER,recent_higher_highs INTEGER,"
      "recent_lower_lows INTEGER,price_above_ema INTEGER,"
      "price_below_ema INTEGER,ema_slope_direction TEXT,"
      "distance_from_ema_points REAL,structure_development_state TEXT,"
      "momentum_direction TEXT,strong_directional_move TEXT,"
      "bars_copied INTEGER,ema_value REAL,ema_previous_value REAL,"
      "ema_slope_points REAL,last_close REAL,last_high REAL,last_low REAL,"
      "bullish_evidence_count INTEGER,bearish_evidence_count INTEGER,"
      "calculation_status TEXT,missing_pressure_data_reason TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string decision =
      "CREATE TABLE IF NOT EXISTS decision_snapshot("
      "decision_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,candidate_direction TEXT,"
      "decision_before_pressure TEXT,decision_after_pressure TEXT,"
      "final_decision TEXT,trend_status TEXT,zone_status TEXT,"
      "structure_status TEXT,momentum_status TEXT,pressure_status TEXT,"
      "risk_status TEXT,trend_score_raw REAL,zone_score_raw REAL,"
      "structure_score_raw REAL,momentum_score_raw REAL,"
      "pressure_score_raw REAL,risk_score_raw REAL,"
      "trend_score_weighted REAL,zone_score_weighted REAL,"
      "structure_score_weighted REAL,momentum_score_weighted REAL,"
      "pressure_score_weighted REAL,risk_score_weighted REAL,"
      "total_score_before_pressure REAL,pressure_penalty_applied REAL,"
      "total_score_after_pressure REAL,decision_reason TEXT,"
      "missing_condition TEXT,blocking_factor TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string tradeOpen =
      "CREATE TABLE IF NOT EXISTS trade_open("
      "trade_open_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,trade_id INTEGER,"
      "ticket INTEGER,open_time TEXT,symbol TEXT,direction TEXT,"
      "volume_requested REAL,volume_executed REAL,open_price REAL,"
      "sl REAL,tp REAL,planned_risk_points REAL,"
      "planned_reward_points REAL,planned_rr REAL,magic_number INTEGER,"
      "comment TEXT,decision_after_pressure TEXT,"
      "pressure_direction TEXT,pressure_level TEXT,pressure_score REAL,"
      "active_regime TEXT,zone_id INTEGER,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string tradeClose =
      "CREATE TABLE IF NOT EXISTS trade_close("
      "trade_close_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,trade_id INTEGER,"
      "ticket INTEGER,open_time TEXT,close_time TEXT,symbol TEXT,"
      "direction TEXT,volume REAL,open_price REAL,close_price REAL,"
      "profit REAL,profit_points REAL,swap REAL,commission REAL,"
      "exit_reason TEXT,bars_held INTEGER,holding_minutes INTEGER,"
      "mae_points REAL,mfe_points REAL,max_floating_profit REAL,"
      "max_floating_loss REAL,planned_rr REAL,realized_rr REAL,"
      "pressure_direction_at_entry TEXT,pressure_level_at_entry TEXT,"
      "pressure_score_at_entry REAL,regime_at_entry TEXT,"
      "zone_at_entry INTEGER,decision_at_entry TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string tradeMarketSnapshot =
      "CREATE TABLE IF NOT EXISTS trade_market_snapshot("
      "/* IMMUTABLE IDENTITY: direction 1=buy, -1=sell. */ "
      "TradeID INTEGER PRIMARY KEY,MagicNumber INTEGER,Symbol TEXT,"
      "Timeframe INTEGER,OpenTime TEXT,Direction INTEGER,Lot REAL,"
      "EntryPrice REAL,"
      "/* STRUCTURE: swing direction 1=up, -1=down; lengths are points. */ "
      "CurrentSwingDirection INTEGER,CurrentSwingDepth INTEGER,"
      "CurrentSwingLength REAL,PreviousSwingDepth INTEGER,"
      "PreviousSwingLength REAL,CurrentZone INTEGER,ZoneScore REAL,"
      "ZoneWidth REAL,DistanceToZoneCenter REAL,DistanceToZoneEdge REAL,"
      "/* EMA FEATURES: values, one-bar slopes, comparisons, distances. */ "
      "EMA20 REAL,EMA50 REAL,EMA100 REAL,EMA200 REAL,"
      "EMA20Slope REAL,EMA50Slope REAL,EMA100Slope REAL,EMA200Slope REAL,"
      "EMA20Above50 INTEGER,EMA50Above100 INTEGER,"
      "EMA100Above200 INTEGER,EMAAlignmentScore INTEGER,"
      "DistanceEMA20_50 REAL,DistanceEMA50_100 REAL,"
      "DistanceEMA100_200 REAL,"
      "/* VOLATILITY AND TREND: raw indicator/candle measurements. */ "
      "ATR REAL,ATRPercent REAL,TrueRange REAL,"
      "AverageTrueRangeRatio REAL,DailyRange REAL,"
      "CurrentCandleRange REAL,ADX REAL,PlusDI REAL,MinusDI REAL,"
      "TrendStrength REAL,TrendAcceleration REAL,"
      "/* PRESSURE: MQL enum IDs and numeric scores, never labels. */ "
      "PressureState INTEGER,PressureScore REAL,PressureStrength REAL,"
      "PressureDirection INTEGER,PressureAge INTEGER,"
      "/* SESSION: 0=Asian,1=London,2=NewYork,3=AfterHours; holiday -1 unknown. */ "
      "DayOfWeek INTEGER,Hour INTEGER,TradingSession INTEGER,"
      "IsHoliday INTEGER,IsWeekend INTEGER,"
      "/* EXECUTION: spread is points; PointValue stores SYMBOL_POINT. */ "
      "Spread REAL,SpreadPercentATR REAL,TickSize REAL,"
      "PointValue REAL,Digits INTEGER,"
      "/* CURRENT CANDLE: unmodified EntryTF OHLC and shape. */ "
      "CurrentOpen REAL,CurrentHigh REAL,CurrentLow REAL,"
      "CurrentClose REAL,BodySize REAL,UpperShadow REAL,"
      "LowerShadow REAL,Bullish INTEGER,Bearish INTEGER,DojiScore REAL,"
      "/* MULTI TIMEFRAME: raw EMA50 and ATR values. */ "
      "M15EMA50 REAL,H1EMA50 REAL,H4EMA50 REAL,D1EMA50 REAL,"
      "H1ATR REAL,H4ATR REAL,D1ATR REAL,"
      "/* QUALITY FLAGS: immutable numeric flags from this row only. */ "
      "HasStrongTrend INTEGER,HasHighVolatility INTEGER,"
      "NearZoneCenter INTEGER,NearZoneEdge INTEGER,"
      "PressureConfirmed INTEGER,EMAFullyAligned INTEGER)";

   string schemaVersion =
      "CREATE TABLE IF NOT EXISTS research_schema_version("
      "schema_version INTEGER PRIMARY KEY,created_at TEXT,"
      "description TEXT)";

   string runNote =
      "CREATE TABLE IF NOT EXISTS research_run_note("
      "note_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,created_at TEXT,note_type TEXT,"
      "note_key TEXT,note_value TEXT,note_text TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id))";

   string policy =
      "CREATE TABLE IF NOT EXISTS policy_snapshot("
      "policy_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,"
      "actual_policy_name TEXT,actual_policy_decision TEXT,"
      "actual_policy_allows_trade INTEGER,"
      "pressure_advice_decision TEXT,pressure_advice_action TEXT,"
      "pressure_advice_allows_trade INTEGER,"
      "pressure_policy_mode TEXT,pressure_policy_is_governing INTEGER,"
      "final_execution_decision TEXT,trade_opened INTEGER,"
      "policy_mismatch_type TEXT,policy_interpretation TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string futureOutcome =
      "CREATE TABLE IF NOT EXISTS future_outcome("
      "future_outcome_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,symbol TEXT,"
      "bar_time TEXT,candidate_direction TEXT,horizon_bars INTEGER,"
      "future_close_time TEXT,future_close_price REAL,move_points REAL,"
      "move_favorable_points REAL,move_adverse_points REAL,"
      "would_hit_tp INTEGER,would_hit_sl INTEGER,reference_price REAL,"
      "reference_sl_points REAL,reference_tp_points REAL,"
      "outcome_label TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string analysisCache =
      "CREATE TABLE IF NOT EXISTS analysis_cache("
      "analysis_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,created_at TEXT,analysis_name TEXT,"
      "analysis_key TEXT,analysis_value REAL,analysis_text TEXT,"
      "source_query TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id))";

   string viewDefinition =
      "CREATE TABLE IF NOT EXISTS research_view_definition("
      "view_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "view_name TEXT UNIQUE,created_at TEXT,description TEXT,"
      "sql_text TEXT,is_active INTEGER)";

   string researchNotes =
      "CREATE TABLE IF NOT EXISTS research_notes("
      "note_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,trade_id INTEGER,"
      "category TEXT,status TEXT,title TEXT,note TEXT,"
      "created_at TEXT,created_by TEXT)";

   string ruleLibrary =
      "CREATE TABLE IF NOT EXISTS rule_library("
      "rule_id INTEGER PRIMARY KEY AUTOINCREMENT,rule_name TEXT,"
      "description TEXT,status TEXT,evidence_count INTEGER,"
      "confidence REAL,first_experiment INTEGER,latest_experiment INTEGER)";

   string hypothesisLibrary =
      "CREATE TABLE IF NOT EXISTS hypothesis_library("
      "hypothesis_id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,"
      "description TEXT,status TEXT,experiment_count INTEGER,"
      "signal_count INTEGER,trade_count INTEGER,conclusion TEXT)";

   string parameter =
      "CREATE TABLE IF NOT EXISTS parameter("
      "parameter_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,name TEXT,value TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id))";

   string featureSnapshot =
      "CREATE TABLE IF NOT EXISTS feature_snapshot("
      "feature_snapshot_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,signal_id INTEGER,feature_group TEXT,"
      "feature_name TEXT,value_text TEXT,value_real REAL,"
      "created_at TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id),"
      "FOREIGN KEY(signal_id) REFERENCES signal(signal_id))";

   string integrityEvent =
      "CREATE TABLE IF NOT EXISTS research_integrity_event("
      "integrity_event_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,created_at TEXT,event_type TEXT,"
      "signal_id INTEGER,trade_id INTEGER,severity TEXT,details TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id))";

   string researchEpisode =
      "CREATE TABLE IF NOT EXISTS research_episode("
      "episode_id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "experiment_id INTEGER,episode_start TEXT,episode_end TEXT,"
      "trade_count INTEGER,net_profit REAL,win_rate REAL,"
      "average_rr REAL,purpose TEXT,created_at TEXT,"
      "FOREIGN KEY(experiment_id) REFERENCES experiment(experiment_id))";

   string adaptiveLossClusterEpisode =
      "CREATE TABLE IF NOT EXISTS adaptive_loss_cluster_episode("
      "EpisodeID INTEGER PRIMARY KEY,Symbol TEXT,Timeframe TEXT,"
      "PatternDirection TEXT,PatternZone INTEGER,ActivatedTime TEXT,"
      "ExpiredTime TEXT,CooldownBars INTEGER,"
      "RemainingBarsAtStart INTEGER,LossClusterSize INTEGER,"
      "BlockedOpportunityCount INTEGER DEFAULT 0,"
      "FirstBlockedTime TEXT,LastBlockedTime TEXT,"
      "Status TEXT,CreatedAt TEXT)";

   string adaptiveShadowTrade =
      "CREATE TABLE IF NOT EXISTS adaptive_shadow_trade("
      "ShadowTradeID INTEGER PRIMARY KEY,EpisodeID INTEGER,"
      "BlockedAuditSerial INTEGER,BlockedTime TEXT,Symbol TEXT,"
      "Timeframe TEXT,Direction TEXT,Zone INTEGER,Lot REAL,"
      "EntryPrice REAL,ExpectedSLPrice REAL,ExpectedTPPrice REAL,"
      "ShadowExitTime TEXT,ShadowExitPrice REAL,"
      "ShadowExitReason TEXT,ShadowProfitUSD REAL,"
      "ShadowHoldingBars INTEGER,ShadowHoldingMinutes INTEGER,"
      "WouldWin INTEGER,WouldLoss INTEGER,Status TEXT,CreatedAt TEXT,"
      "FOREIGN KEY(EpisodeID) REFERENCES "
      "adaptive_loss_cluster_episode(EpisodeID))";

   if(!ResearchDBExecute("PRAGMA foreign_keys=ON", "enable foreign keys"))
      return false;
   if(!ResearchDBExecute(experiment, "create experiment table") ||
      !ResearchDBExecute(signal, "create signal table") ||
      !ResearchDBExecute(zone, "create zone_snapshot table") ||
      !ResearchDBExecute(structure, "create structure_snapshot table") ||
      !ResearchDBExecute(regime, "create regime_snapshot table") ||
      !ResearchDBExecute(pressure, "create pressure_snapshot table") ||
      !ResearchDBExecute(decision, "create decision_snapshot table") ||
      !ResearchDBExecute(tradeOpen, "create trade_open table") ||
      !ResearchDBExecute(tradeClose, "create trade_close table") ||
      !ResearchDBExecute(tradeMarketSnapshot,
                         "create trade_market_snapshot table") ||
      !ResearchDBExecute(schemaVersion,
                         "create research_schema_version table") ||
      !ResearchDBExecute(runNote, "create research_run_note table") ||
      !ResearchDBExecute(policy, "create policy_snapshot table") ||
      !ResearchDBExecute(futureOutcome, "create future_outcome table") ||
      !ResearchDBExecute(analysisCache, "create analysis_cache table") ||
      !ResearchDBExecute(viewDefinition,
                         "create research_view_definition table") ||
      !ResearchDBExecute(researchNotes, "create research_notes table") ||
      !ResearchDBExecute(ruleLibrary, "create rule_library table") ||
      !ResearchDBExecute(hypothesisLibrary,
                         "create hypothesis_library table") ||
      !ResearchDBExecute(parameter, "create parameter table") ||
      !ResearchDBExecute(featureSnapshot,
                         "create feature_snapshot table") ||
      !ResearchDBExecute(integrityEvent,
                         "create research_integrity_event table") ||
      !ResearchDBExecute(researchEpisode,
                         "create research_episode table") ||
      !ResearchDBExecute(adaptiveLossClusterEpisode,
                         "create adaptive loss cluster episode table") ||
      !ResearchDBExecute(adaptiveShadowTrade,
                         "create adaptive shadow trade table"))
      return false;

   if(!ResearchDBApplyFlightRecorderMigration())
      return false;

   return ResearchDBExecute(
      "CREATE INDEX IF NOT EXISTS idx_signal_experiment "
      "ON signal(experiment_id);"
      "CREATE INDEX IF NOT EXISTS idx_adaptive_episode_pattern "
      "ON adaptive_loss_cluster_episode("
      "PatternDirection,PatternZone);"
      "CREATE INDEX IF NOT EXISTS idx_adaptive_shadow_episode "
      "ON adaptive_shadow_trade(EpisodeID);"
      "CREATE INDEX IF NOT EXISTS idx_adaptive_shadow_pattern "
      "ON adaptive_shadow_trade(Direction,Zone);"
      "CREATE INDEX IF NOT EXISTS idx_zone_signal "
      "ON zone_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_structure_signal "
      "ON structure_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_regime_signal "
      "ON regime_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_pressure_signal "
      "ON pressure_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_decision_signal "
      "ON decision_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_trade_open_signal "
      "ON trade_open(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_trade_close_trade "
      "ON trade_close(trade_id);"
      "CREATE INDEX IF NOT EXISTS idx_policy_signal "
      "ON policy_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_future_signal "
      "ON future_outcome(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_feature_signal "
      "ON feature_snapshot(signal_id);"
      "CREATE INDEX IF NOT EXISTS idx_integrity_experiment "
      "ON research_integrity_event(experiment_id);"
      "CREATE INDEX IF NOT EXISTS idx_trade_open_experiment_trade "
      "ON trade_open(experiment_id,trade_id);"
      "CREATE INDEX IF NOT EXISTS idx_trade_close_experiment_trade "
      "ON trade_close(experiment_id,trade_id);"
      "CREATE INDEX IF NOT EXISTS idx_episode_experiment "
      "ON research_episode(experiment_id);",
      "create research indexes");
}

long ResearchDBInsertExperiment(string symbol)
{
   string sql =
      "INSERT INTO experiment("
      "created_at,symbol,account_server,account_login,ea_name,ea_version,"
      "execution_mode,is_strategy_tester,market_label,manual_profile,"
      "use_auto_regime_detection,allow_auto_profile_switch,"
      "use_pressure_guard,pressure_guard_mode,use_research_db,"
      "use_csv_logger,zone_tf,bias_tf,entry_tf,execution_tf,pressure_tf,"
      "regime_tf,zone_lookback_bars,bias_lookback_bars,"
      "regime_lookback_bars,pressure_lookback_bars,use_atr_validation,"
      "atr_period,atr_min_multiplier,atr_max_multiplier,"
      "backtest_fixed_lot,backtest_sl_points,backtest_tp_points,"
      "backtest_magic_number,use_backtest_max_holding_bars,"
      "backtest_max_holding_bars,pressure_medium_threshold,"
      "pressure_high_threshold,pressure_medium_penalty,"
      "pressure_high_penalty,pressure_high_downgrade_to_watch,"
      "pressure_soft_block_only_in_sideway_or_unknown,"
      "pressure_use_ema_filter,pressure_ema_period,"
      "pressure_use_structure_development,pressure_use_momentum,"
      "experiment_name,git_commit,engine_version,zone_version,"
      "structure_version,regime_version,pressure_version,"
      "decision_version,profile_version,use_pressure_execution_block,"
      "pressure_execution_block_mode,pressure_execution_block_mode_id,"
      "pressure_execution_block_mode_name,schema_version,"
      "research_version,pressure_mode,profile,timeframe,date_start,"
      "date_end) VALUES(" +
      ResearchDBSQLText(ResearchDBTimeText(TREResearchDBStartedAt)) + "," +
      ResearchDBSQLText(symbol) + "," +
      ResearchDBSQLText(AccountInfoString(ACCOUNT_SERVER)) + "," +
      ResearchDBSQLText((string)AccountInfoInteger(ACCOUNT_LOGIN)) + "," +
      ResearchDBSQLText(APP_NAME) + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(TRE_ExecutionModeToText()) + "," +
      ResearchDBSQLInteger(ResearchDBBool(MQLInfoInteger(MQL_TESTER) != 0)) + "," +
      ResearchDBSQLText(BacktestMarketStatus) + "," +
      ResearchDBSQLText(TRE_MarketProfileToText(ManualMarketProfile)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UseAutoRegimeDetection)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(AllowAutoProfileSwitch)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UsePressureGuard)) + "," +
      ResearchDBSQLText(PressureGuardModeToText(PressureGuardMode)) + "," +
      "1," + ResearchDBSQLInteger(ResearchDBBool(EnableBacktestCSVLog)) + "," +
      ResearchDBSQLText(TimeframeToText(ZoneTF)) + "," +
      ResearchDBSQLText(TimeframeToText(BiasTF)) + "," +
      ResearchDBSQLText(TimeframeToText(EntryTF)) + "," +
      ResearchDBSQLText(TimeframeToText(ExecutionTF)) + "," +
      ResearchDBSQLText(TimeframeToText(EffectivePressureTF)) + "," +
      ResearchDBSQLText(TimeframeToText(RegimeTF)) + "," +
      ResearchDBSQLInteger(EffectiveZoneLookbackBars) + "," +
      ResearchDBSQLInteger(EffectiveBiasLookbackBars) + "," +
      ResearchDBSQLInteger(EffectiveRegimeLookbackBars) + "," +
      ResearchDBSQLInteger(EffectivePressureLookbackBars) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UseATRValidation)) + "," +
      ResearchDBSQLInteger(ATRPeriod) + "," +
      ResearchDBSQLDouble(MinATRMultiplier) + "," +
      ResearchDBSQLDouble(MaxATRMultiplier) + "," +
      ResearchDBSQLDouble(BacktestFixedLot) + "," +
      ResearchDBSQLDouble(BacktestSLPoints) + "," +
      ResearchDBSQLDouble(BacktestTPPoints) + "," +
      ResearchDBSQLInteger(BacktestMagicNumber) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UseBacktestMaxHoldingBars)) + "," +
      ResearchDBSQLInteger(EffectiveBacktestMaxHoldingBars) + "," +
      ResearchDBSQLDouble(EffectivePressureMediumThreshold) + "," +
      ResearchDBSQLDouble(EffectivePressureHighThreshold) + "," +
      ResearchDBSQLDouble(EffectivePressureMediumPenalty) + "," +
      ResearchDBSQLDouble(EffectivePressureHighPenalty) + "," +
      ResearchDBSQLInteger(ResearchDBBool(PressureHighDowngradeToWatch)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(
         PressureSoftBlockOnlyInSidewayOrUnknown)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(PressureUseEMAFilter)) + "," +
      ResearchDBSQLInteger(EffectivePressureEMAPeriod) + "," +
      ResearchDBSQLInteger(ResearchDBBool(
         PressureUseStructureDevelopment)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(PressureUseMomentum)) + "," +
      ResearchDBSQLText(BacktestExperimentName) + "," +
      ResearchDBSQLText("N/A") + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(APP_VERSION) + "," +
      ResearchDBSQLText(TRE_MarketProfileToText(ManualMarketProfile)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(
         UsePressureExecutionBlock)) + "," +
      ResearchDBSQLText(PressureExecutionBlockModeText) + "," +
      ResearchDBSQLInteger((int)PressureExecutionBlockMode) + "," +
      ResearchDBSQLText(PressureExecutionBlockModeToText(
         PressureExecutionBlockMode)) + "," +
      ResearchDBSQLInteger(ResearchDBSchemaVersion) + "," +
      ResearchDBSQLText("TRADE_RESULT_AUDIT_PHASE") + "," +
      ResearchDBSQLText(PressureExecutionBlockModeToText(
         PressureExecutionBlockMode)) + "," +
      ResearchDBSQLText(TRE_MarketProfileToText(
         ManualMarketProfile)) + "," +
      ResearchDBSQLText(TimeframeToText(_Period)) + "," +
      ResearchDBSQLText(ResearchDBTimeText(
         TREResearchDBStartedAt)) + "," +
      ResearchDBSQLText(ResearchDBTimeText(
         TREResearchDBStartedAt)) + ")";
   return ResearchDBInsert(sql, "insert experiment");
}

void ResearchDBWriteParameter(string name, string value)
{
   string sql =
      "INSERT INTO parameter(experiment_id,name,value) VALUES(" +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLText(name) + "," +
      ResearchDBSQLText(value) + ")";
   ResearchDBExecute(sql, "insert parameter " + name);
}

void ResearchDBWriteParameterSet()
{
   if(!ResearchDBWriteParameters)
      return;
   ResearchDBWriteParameter("ExperimentName", BacktestExperimentName);
   ResearchDBWriteParameter("RiskUSD", DoubleToString(RiskUSD, 2));
   ResearchDBWriteParameter("UseTrendScore", JournalBoolText(UseTrendScore));
   ResearchDBWriteParameter("UseZoneScore", JournalBoolText(UseZoneScore));
   ResearchDBWriteParameter("UseStructureScore",
                            JournalBoolText(UseStructureScore));
   ResearchDBWriteParameter("UseMomentumScore",
                            JournalBoolText(UseMomentumScore));
   ResearchDBWriteParameter("TrendWeight", DoubleToString(TrendWeight, 2));
   ResearchDBWriteParameter("ZoneWeight", DoubleToString(ZoneWeight, 2));
   ResearchDBWriteParameter("StructureWeight",
                            DoubleToString(StructureWeight, 2));
   ResearchDBWriteParameter("MomentumWeight",
                            DoubleToString(MomentumWeight, 2));
   ResearchDBWriteParameter("UseDirectionalFilter",
                            JournalBoolText(UseDirectionalFilter));
   ResearchDBWriteParameter("ResearchDBWriteSignals",
                            JournalBoolText(ResearchDBWriteSignals));
   ResearchDBWriteParameter("ResearchDBWriteTrades",
                            JournalBoolText(ResearchDBWriteTrades));
   ResearchDBWriteParameter("ResearchDBFlushEverySignal",
                            JournalBoolText(ResearchDBFlushEverySignal));
   ResearchDBWriteParameter("ResearchDBPressurePolicyIsGoverning",
                            JournalBoolText(
                               ResearchDBPressurePolicyIsGoverning));
   ResearchDBWriteParameter("UsePressureExecutionBlock",
                            JournalBoolText(
                               UsePressureExecutionBlock));
   ResearchDBWriteParameter("PressureExecutionBlockMode",
                            PressureExecutionBlockModeText);
   ResearchDBWriteParameter("PressureExecutionBlockModeID",
                            IntegerToString(
                               (int)PressureExecutionBlockMode));
   ResearchDBWriteParameter("ResearchSchemaVersion",
                            IntegerToString(ResearchDBSchemaVersion));
   ResearchDBWriteParameter("ResearchVersion",
                            "TRADE_RESULT_AUDIT_PHASE");
   ResearchDBWriteParameter("TransitionDoubleEntryBars", "3");
   ResearchDBWriteParameter("TransitionLowScoreGap", "10");
   ResearchDBWriteParameter("EnableWeekendProtection",
                            JournalBoolText(EnableWeekendProtection));
   ResearchDBWriteParameter("WeekendBlockDay",
                            TRE_WeekendDayToText(WeekendBlockDay));
   ResearchDBWriteParameter("WeekendBlockHour",
                            IntegerToString(
                               TRE_WeekendHour(WeekendBlockHour)));
   ResearchDBWriteParameter("WeekendForceCloseHour",
                            IntegerToString(
                               TRE_WeekendHour(WeekendForceCloseHour)));
   ResearchDBWriteParameter("EnableAdaptiveLossCluster",
                            JournalBoolText(EnableAdaptiveLossCluster));
   ResearchDBWriteParameter("LossClusterThreshold",
                            IntegerToString(
                               AdaptiveEffectiveThreshold()));
   ResearchDBWriteParameter("LossClusterCooldownBars",
                            IntegerToString(
                               AdaptiveEffectiveCooldown()));
   ResearchDBWriteParameter("AdaptiveClusterMode",
                            AdaptiveClusterModeText());
   ResearchDBWriteParameter("UseAdvancedAdaptiveCluster",
                            JournalBoolText(
                               UseAdvancedAdaptiveCluster));
   ResearchDBWriteParameter("AdaptiveEnableBUYZone1",
                            JournalBoolText(AdaptiveEnableBUYZone1));
   ResearchDBWriteParameter("AdaptiveEnableBUYZone2",
                            JournalBoolText(AdaptiveEnableBUYZone2));
   ResearchDBWriteParameter("AdaptiveEnableBUYZone3",
                            JournalBoolText(AdaptiveEnableBUYZone3));
   ResearchDBWriteParameter("AdaptiveEnableBUYZone4",
                            JournalBoolText(AdaptiveEnableBUYZone4));
   ResearchDBWriteParameter("AdaptiveEnableBUYZone5",
                            JournalBoolText(AdaptiveEnableBUYZone5));
   ResearchDBWriteParameter("AdaptiveEnableBUYZone6",
                            JournalBoolText(AdaptiveEnableBUYZone6));
   ResearchDBWriteParameter("AdaptiveEnableSELLZone1",
                            JournalBoolText(AdaptiveEnableSELLZone1));
   ResearchDBWriteParameter("AdaptiveEnableSELLZone2",
                            JournalBoolText(AdaptiveEnableSELLZone2));
   ResearchDBWriteParameter("AdaptiveEnableSELLZone3",
                            JournalBoolText(AdaptiveEnableSELLZone3));
   ResearchDBWriteParameter("AdaptiveEnableSELLZone4",
                            JournalBoolText(AdaptiveEnableSELLZone4));
   ResearchDBWriteParameter("AdaptiveEnableSELLZone5",
                            JournalBoolText(AdaptiveEnableSELLZone5));
   ResearchDBWriteParameter("AdaptiveEnableSELLZone6",
                            JournalBoolText(AdaptiveEnableSELLZone6));
}

int ResearchDBCountRows(string tableName)
{
   int request = DatabasePrepare(
      TREResearchDBHandle, "SELECT COUNT(*) FROM " + tableName);
   if(request == INVALID_HANDLE)
      return 0;
   long count = 0;
   ResetLastError();
   if(DatabaseRead(request))
      DatabaseColumnLong(request, 0, count);
   DatabaseFinalize(request);
   ResetLastError();
   return (int)count;
}

int ResearchDBCountQuery(string sql)
{
   int request = DatabasePrepare(TREResearchDBHandle, sql);
   if(request == INVALID_HANDLE)
      return 0;
   long count = 0;
   ResetLastError();
   if(DatabaseRead(request))
      DatabaseColumnLong(request, 0, count);
   DatabaseFinalize(request);
   ResetLastError();
   return (int)count;
}

double ResearchDBDoubleQuery(string sql)
{
   int request = DatabasePrepare(TREResearchDBHandle, sql);
   if(request == INVALID_HANDLE)
      return 0;
   double value = 0;
   ResetLastError();
   if(DatabaseRead(request))
      DatabaseColumnDouble(request, 0, value);
   DatabaseFinalize(request);
   ResetLastError();
   return value;
}

void ResearchDBRefreshAnalytics()
{
   string experiment =
      ResearchDBSQLInteger(ResearchDBExperimentID);
   string tradeScope = " FROM trade_close WHERE experiment_id=" +
                       experiment;
   string pressureScope =
      " FROM pressure_snapshot WHERE experiment_id=" + experiment;
   string signalScope = " FROM signal WHERE experiment_id=" +
                        experiment;

   ResearchAnalyticsWinCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + tradeScope + " AND profit>0");
   ResearchAnalyticsLossCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + tradeScope + " AND profit<0");
   ResearchAnalyticsTPCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + tradeScope + " AND UPPER(exit_reason)='TP'");
   ResearchAnalyticsSLCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + tradeScope + " AND UPPER(exit_reason)='SL'");
   ResearchAnalyticsTimeoutCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + tradeScope +
      " AND UPPER(exit_reason)='TIMEOUT'");
   ResearchAnalyticsNetProfit = ResearchDBDoubleQuery(
      "SELECT COALESCE(SUM(profit+COALESCE(swap,0)+"
      "COALESCE(commission,0)),0)" + tradeScope);
   ResearchAnalyticsProfitFactor = ResearchDBDoubleQuery(
      "SELECT COALESCE(SUM(CASE WHEN profit>0 THEN profit ELSE 0 END)/"
      "NULLIF(SUM(CASE WHEN profit<0 THEN -profit ELSE 0 END),0),0)" +
      tradeScope);
   ResearchAnalyticsDrawdown = ResearchDBDoubleQuery(
      "SELECT COALESCE(drawdown,0) FROM v_experiment_summary LIMIT 1");
   ResearchAnalyticsAverageMAE = ResearchDBDoubleQuery(
      "SELECT COALESCE(AVG(mae_points),0)" + tradeScope);
   ResearchAnalyticsAverageMFE = ResearchDBDoubleQuery(
      "SELECT COALESCE(AVG(mfe_points),0)" + tradeScope);
   ResearchAnalyticsAverageRR = ResearchDBDoubleQuery(
      "SELECT COALESCE(AVG(realized_rr),0)" + tradeScope);
   ResearchAnalyticsAverageHolding = ResearchDBDoubleQuery(
      "SELECT COALESCE(AVG(bars_held),0)" + tradeScope);
   ResearchAnalyticsAverageProfit = ResearchDBDoubleQuery(
      "SELECT COALESCE(AVG(profit),0)" + tradeScope + " AND profit>0");
   ResearchAnalyticsAverageLoss = ResearchDBDoubleQuery(
      "SELECT COALESCE(AVG(profit),0)" + tradeScope + " AND profit<0");
   ResearchAnalyticsLargestWin = ResearchDBDoubleQuery(
      "SELECT COALESCE(MAX(profit),0)" + tradeScope);
   ResearchAnalyticsLargestLoss = ResearchDBDoubleQuery(
      "SELECT COALESCE(MIN(profit),0)" + tradeScope);

   ResearchAnalyticsPressureLowCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + pressureScope +
      " AND pressure_level='LOW'");
   ResearchAnalyticsPressureMediumCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + pressureScope +
      " AND pressure_level='MEDIUM'");
   ResearchAnalyticsPressureHighCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + pressureScope +
      " AND pressure_level='HIGH'");
   ResearchAnalyticsPressureUpCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + pressureScope +
      " AND pressure_direction='UP'");
   ResearchAnalyticsPressureDownCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + pressureScope +
      " AND pressure_direction='DOWN'");
   ResearchAnalyticsPressureUnknownCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + pressureScope +
      " AND COALESCE(pressure_direction,'UNKNOWN') "
      "NOT IN ('UP','DOWN')");
   ResearchAnalyticsWatchCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + signalScope +
      " AND (decision_after_pressure='WATCH' "
      "OR final_decision='WATCH')");
   ResearchAnalyticsAllowCount = ResearchDBCountQuery(
      "SELECT COUNT(*)" + signalScope +
      " AND decision_after_pressure IN ('BUY READY','SELL READY')");
   ResearchAnalyticsEpisodeCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM research_episode WHERE experiment_id=" +
      experiment);
   ResearchAnalyticsEpisodeTradeCount = ResearchDBCountQuery(
      "SELECT COALESCE(SUM(trade_count),0) FROM research_episode "
      "WHERE experiment_id=" + experiment);
   ResearchAnalyticsEpisodeNetProfit = ResearchDBDoubleQuery(
      "SELECT COALESCE(SUM(net_profit),0) FROM research_episode "
      "WHERE experiment_id=" + experiment);
}

void ResearchDBRefreshDiagnostics()
{
   string experiment =
      ResearchDBSQLInteger(ResearchDBExperimentID);
   ResearchDBDiagnosticSignalCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM signal WHERE experiment_id=" + experiment);
   ResearchDBDiagnosticExecutedTradeCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM trade_open WHERE experiment_id=" + experiment);
   ResearchDBDiagnosticBlockedSignalCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM signal WHERE blocked_by_pressure=1 "
      "AND experiment_id=" + experiment);
   ResearchDBDiagnosticSavedLossCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM v_pressure_saved_or_missed "
      "WHERE pressure_shadow_result='SAVED_LOSS' "
      "AND experiment_id=" + experiment);
   ResearchDBDiagnosticMissedWinCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM v_pressure_saved_or_missed "
      "WHERE pressure_shadow_result='MISSED_WIN' "
      "AND experiment_id=" + experiment);
   ResearchDBDiagnosticAttributionErrorCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM v_trade_attribution_validation "
      "WHERE validation_result IN ('SIGNAL_MISMATCH',"
      "'TRADE_WITHOUT_SIGNAL','MULTIPLE_TRADES_PER_SIGNAL',"
      "'ORPHAN_SIGNAL','ORPHAN_TRADE') AND experiment_id=" +
      experiment);
   ResearchDBDiagnosticOrphanSignalCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM v_trade_attribution_validation "
      "WHERE validation_result='ORPHAN_SIGNAL' "
      "AND experiment_id=" + experiment);
   ResearchDBDiagnosticOrphanTradeCount = ResearchDBCountQuery(
      "SELECT COUNT(*) FROM v_trade_attribution_validation "
      "WHERE validation_result IN ('TRADE_WITHOUT_SIGNAL',"
      "'ORPHAN_TRADE') AND experiment_id=" + experiment);
   ResearchDBDiagnosticValidationStatus =
      (ResearchDBDiagnosticAttributionErrorCount == 0)
      ? "OK"
      : "ERROR";
   ResearchDBRefreshAnalytics();
}

void ResearchDBInsertRunNote(string noteType, string noteKey,
                             string noteValue, string noteText)
{
   string sql =
      "INSERT INTO research_run_note("
      "experiment_id,created_at,note_type,note_key,note_value,note_text"
      ") VALUES(" +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(noteType) + "," +
      ResearchDBSQLText(noteKey) + "," +
      ResearchDBSQLText(noteValue) + "," +
      ResearchDBSQLText(noteText) + ")";
   ResearchDBExecute(sql, "insert research run note");
}

string ResearchDBAdaptiveDetailValue(string detail, string key)
{
   string marker = key + "=";
   int start = StringFind(detail, marker);
   if(start < 0)
      return "";
   start += StringLen(marker);
   int finish = StringFind(detail, ";", start);
   if(finish < 0)
      finish = StringLen(detail);
   return StringSubstr(detail, start, finish - start);
}

void ResearchDBApplyAdaptiveEpisodeAudit(string eventName,
                                         long episodeID,
                                         string detail,
                                         datetime eventTime)
{
   if(episodeID <= 0)
      return;

   string eventText = ResearchDBTimeText(eventTime);
   if(eventName == "ADAPTIVE_ACTIVATE")
   {
      string sql =
         "INSERT OR IGNORE INTO adaptive_loss_cluster_episode("
         "EpisodeID,Symbol,Timeframe,PatternDirection,PatternZone,"
         "ActivatedTime,ExpiredTime,CooldownBars,RemainingBarsAtStart,"
         "LossClusterSize,BlockedOpportunityCount,FirstBlockedTime,"
         "LastBlockedTime,Status,CreatedAt) VALUES(" +
         ResearchDBSQLInteger(episodeID) + "," +
         ResearchDBSQLText(
            ResearchDBAdaptiveDetailValue(detail, "Symbol")) + "," +
         ResearchDBSQLText(
            ResearchDBAdaptiveDetailValue(detail, "Timeframe")) + "," +
         ResearchDBSQLText(
            ResearchDBAdaptiveDetailValue(
               detail, "BlockedDirection")) + "," +
         ResearchDBSQLInteger(
            StringToInteger(
               ResearchDBAdaptiveDetailValue(
                  detail, "BlockedZone"))) + "," +
         ResearchDBSQLText(eventText) + ",NULL," +
         ResearchDBSQLInteger(
            StringToInteger(
               ResearchDBAdaptiveDetailValue(
                  detail, "CooldownBars"))) + "," +
         ResearchDBSQLInteger(
            StringToInteger(
               ResearchDBAdaptiveDetailValue(
                  detail, "RemainingBarsAtStart"))) + "," +
         ResearchDBSQLInteger(
            StringToInteger(
               ResearchDBAdaptiveDetailValue(
                  detail, "LossClusterSize"))) +
         ",0,NULL,NULL,'ACTIVE'," +
         ResearchDBSQLText(eventText) + ")";
      ResearchDBExecute(sql, "insert adaptive episode");
      return;
   }

   if(eventName == "ADAPTIVE_BLOCK_OPPORTUNITY")
   {
      string sql =
         "UPDATE adaptive_loss_cluster_episode SET "
         "BlockedOpportunityCount=BlockedOpportunityCount+1,"
         "FirstBlockedTime=COALESCE(FirstBlockedTime," +
         ResearchDBSQLText(eventText) + "),LastBlockedTime=" +
         ResearchDBSQLText(eventText) +
         " WHERE EpisodeID=" + ResearchDBSQLInteger(episodeID) +
         " AND Status='ACTIVE'";
      ResearchDBExecute(sql, "update adaptive blocked opportunity");
      return;
   }

   if(eventName == "ADAPTIVE_EXPIRE")
   {
      string sql =
         "UPDATE adaptive_loss_cluster_episode SET Status='EXPIRED',"
         "ExpiredTime=" + ResearchDBSQLText(eventText) +
         " WHERE EpisodeID=" + ResearchDBSQLInteger(episodeID) +
         " AND Status='ACTIVE'";
      ResearchDBExecute(sql, "expire adaptive episode");
   }
}

void ResearchDBCaptureAdaptiveShadowTrades()
{
   if(!ResearchDBCanWrite())
      return;

   for(int i = 0; i < ArraySize(TREAdaptiveShadowTrades); i++)
   {
      if(!TREAdaptiveShadowTrades[i].dbOpenWritten)
      {
         string insertSQL =
            "INSERT OR IGNORE INTO adaptive_shadow_trade("
            "ShadowTradeID,EpisodeID,BlockedAuditSerial,BlockedTime,"
            "Symbol,Timeframe,Direction,Zone,Lot,EntryPrice,"
            "ExpectedSLPrice,ExpectedTPPrice,ShadowExitTime,"
            "ShadowExitPrice,ShadowExitReason,ShadowProfitUSD,"
            "ShadowHoldingBars,ShadowHoldingMinutes,WouldWin,WouldLoss,"
            "Status,CreatedAt) VALUES(" +
            ResearchDBSQLInteger(
               TREAdaptiveShadowTrades[i].shadowTradeID) + "," +
            ResearchDBSQLInteger(
               TREAdaptiveShadowTrades[i].episodeID) + "," +
            ResearchDBSQLInteger(
               TREAdaptiveShadowTrades[i].blockedAuditSerial) + "," +
            ResearchDBSQLText(
               ResearchDBTimeText(
                  TREAdaptiveShadowTrades[i].blockedTime)) + "," +
            ResearchDBSQLText(
               TREAdaptiveShadowTrades[i].symbol) + "," +
            ResearchDBSQLText(
               TimeframeToText(
                  TREAdaptiveShadowTrades[i].timeframe)) + "," +
            ResearchDBSQLText(
               AdaptiveV1DirectionText(
                  TREAdaptiveShadowTrades[i].direction)) + "," +
            ResearchDBSQLInteger(
               TREAdaptiveShadowTrades[i].zone) + "," +
            ResearchDBSQLDouble(
               TREAdaptiveShadowTrades[i].lot) + "," +
            ResearchDBSQLDouble(
               TREAdaptiveShadowTrades[i].entryPrice) + "," +
            ResearchDBSQLDouble(
               TREAdaptiveShadowTrades[i].expectedSLPrice) + "," +
            ResearchDBSQLDouble(
               TREAdaptiveShadowTrades[i].expectedTPPrice) +
            ",NULL,NULL,NULL,0,0,0,0,0,'OPEN'," +
            ResearchDBSQLText(
               ResearchDBTimeText(
                  TREAdaptiveShadowTrades[i].createdAt)) + ")";
         if(ResearchDBExecute(
               insertSQL, "insert adaptive shadow trade"))
         {
            TREAdaptiveShadowTrades[i].dbOpenWritten = true;
         }
      }

      if(TREAdaptiveShadowTrades[i].status != "CLOSED" ||
         !TREAdaptiveShadowTrades[i].dbOpenWritten ||
         TREAdaptiveShadowTrades[i].dbCloseWritten)
      {
         continue;
      }

      string updateSQL =
         "UPDATE adaptive_shadow_trade SET ShadowExitTime=" +
         ResearchDBSQLText(
            ResearchDBTimeText(
               TREAdaptiveShadowTrades[i].shadowExitTime)) +
         ",ShadowExitPrice=" +
         ResearchDBSQLDouble(
            TREAdaptiveShadowTrades[i].shadowExitPrice) +
         ",ShadowExitReason=" +
         ResearchDBSQLText(
            TREAdaptiveShadowTrades[i].shadowExitReason) +
         ",ShadowProfitUSD=" +
         ResearchDBSQLDouble(
            TREAdaptiveShadowTrades[i].shadowProfitUSD) +
         ",ShadowHoldingBars=" +
         ResearchDBSQLInteger(
            TREAdaptiveShadowTrades[i].shadowHoldingBars) +
         ",ShadowHoldingMinutes=" +
         ResearchDBSQLInteger(
            TREAdaptiveShadowTrades[i].shadowHoldingMinutes) +
         ",WouldWin=" +
         ResearchDBSQLInteger(
            ResearchDBBool(TREAdaptiveShadowTrades[i].wouldWin)) +
         ",WouldLoss=" +
         ResearchDBSQLInteger(
            ResearchDBBool(TREAdaptiveShadowTrades[i].wouldLoss)) +
         ",Status='CLOSED' WHERE ShadowTradeID=" +
         ResearchDBSQLInteger(
            TREAdaptiveShadowTrades[i].shadowTradeID);
      if(ResearchDBExecute(
            updateSQL, "close adaptive shadow trade"))
      {
         TREAdaptiveShadowTrades[i].dbCloseWritten = true;
      }
   }
}

void ResearchDBInitializeSchemaMetadata()
{
   string versionSQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(2," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Analysis view support and shadow-policy research fields") + ")";
   if(!ResearchDBExecute(versionSQL, "insert schema version 2"))
      return;

   string version3SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(3," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Trading Decision Flight Recorder Alpha 2.0 knowledge schema") +
      ")";
   if(!ResearchDBExecute(version3SQL, "insert schema version 3"))
      return;

   string version4SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(4," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Deterministic signal-trade attribution and pressure validation") +
      ")";
   if(!ResearchDBExecute(version4SQL, "insert schema version 4"))
      return;

   string version5SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(5," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Research analytics views, episode infrastructure, and dashboard separation") +
      ")";
   if(!ResearchDBExecute(version5SQL, "insert schema version 5"))
      return;

   string version6SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(6," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Fixed SL TP realized-result audit and money deviation fields") +
      ")";
   if(!ResearchDBExecute(version6SQL, "insert schema version 6"))
      return;

   string version7SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(7," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Immutable pre-entry trade market snapshot features") + ")";
   if(!ResearchDBExecute(version7SQL, "insert schema version 7"))
      return;

   string version8SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(8," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Adaptive Loss Cluster V1 episode lifecycle analytics") + ")";
   if(!ResearchDBExecute(version8SQL, "insert schema version 8"))
      return;

   string version9SQL =
      "INSERT OR IGNORE INTO research_schema_version("
      "schema_version,created_at,description) VALUES(9," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(
         "Research-only Adaptive V1 blocked-opportunity shadow outcomes") +
      ")";
   if(!ResearchDBExecute(version9SQL, "insert schema version 9"))
      return;

   ResearchDBInsertRunNote(
      "RUN_CONTEXT", "pressure_policy_status",
      "SHADOW_OR_SOFT_ADVISORY",
      "Pressure may advise WATCH while actual execution can still follow existing entry/execution policy.");

   ResearchDBInsertRunNote(
      "RUN_CONTEXT", "auto_profile_switch",
      AllowAutoProfileSwitch ? "ON" : "OFF",
      AllowAutoProfileSwitch
      ? "Regime detection and profile switching are explicitly enabled."
      : "Regime detection is active, but profile switching is disabled unless explicitly enabled.");
}

string ResearchDBViewSignalLifecycle()
{
   return
      "CREATE VIEW IF NOT EXISTS v_signal_lifecycle AS "
      "SELECT s.experiment_id,s.signal_id,s.signal_time,s.symbol,"
      "s.candidate_direction_before_pressure,s.decision_before_pressure,"
      "s.decision_after_pressure,s.final_decision,"
      "s.score_before_pressure,s.pressure_penalty_applied,"
      "s.score_after_pressure,z.zone_id,z.zone_label,"
      "st.confirmed_structure,st.development_state,"
      "r.detected_regime,r.best_candidate_regime,r.active_regime,"
      "p.pressure_direction,p.pressure_level,p.pressure_score,"
      "p.pressure_action,p.pressure_decision_impact,"
      "CASE WHEN t.trade_id IS NULL THEN 0 ELSE 1 END "
      "AS is_trade_opened,t.trade_id,tc.profit,tc.profit_points,"
      "tc.exit_reason,tc.bars_held,tc.mae_points,tc.mfe_points "
      "FROM signal s "
      "LEFT JOIN zone_snapshot z "
      "ON z.zone_snapshot_id=s.zone_snapshot_id "
      "LEFT JOIN structure_snapshot st "
      "ON st.structure_snapshot_id=s.structure_snapshot_id "
      "LEFT JOIN regime_snapshot r "
      "ON r.regime_snapshot_id=s.regime_snapshot_id "
      "LEFT JOIN pressure_snapshot p "
      "ON p.pressure_snapshot_id=s.pressure_snapshot_id "
      "LEFT JOIN trade_open t ON t.experiment_id=s.experiment_id "
      "AND t.signal_id=s.signal_id "
      "LEFT JOIN trade_close tc ON tc.experiment_id=s.experiment_id "
      "AND tc.trade_id=t.trade_id";
}

string ResearchDBViewAdaptiveLossClusterMetrics()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_loss_cluster_metrics AS "
      "SELECT e.experiment_id AS ExperimentID,"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_EVALUATE' THEN 1 ELSE 0 END) "
      "AS TotalEvaluations,"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_CANDIDATE' THEN 1 ELSE 0 END) "
      "AS CandidateSignals,"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_BLOCK_OPPORTUNITY' "
      "THEN 1 ELSE 0 END) AS BlockedOpportunities,"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_EXECUTE_PASS' THEN 1 ELSE 0 END) "
      "AS ExecutedTrades,"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_ACTIVATE' THEN 1 ELSE 0 END) "
      "AS ActivationCount,"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_EXPIRE' THEN 1 ELSE 0 END) "
      "AS ExpireCount,"
      "COALESCE((SELECT x.note_value FROM research_run_note x "
      "WHERE x.experiment_id=e.experiment_id "
      "AND x.note_key='adaptive_v1_last_blocked_direction' "
      "ORDER BY x.note_id DESC LIMIT 1),'NONE') AS BlockedDirection,"
      "COALESCE((SELECT x.note_value FROM research_run_note x "
      "WHERE x.experiment_id=e.experiment_id "
      "AND x.note_key='adaptive_v1_last_blocked_zone' "
      "ORDER BY x.note_id DESC LIMIT 1),'0') AS BlockedZone,"
      "CASE WHEN SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_CANDIDATE' THEN 1 ELSE 0 END)=0 "
      "THEN 0.0 ELSE 100.0*SUM(CASE WHEN "
      "n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_BLOCK_OPPORTUNITY' "
      "THEN 1 ELSE 0 END)/"
      "SUM(CASE WHEN n.note_type='AdaptiveLossClusterV1' "
      "AND n.note_key='ADAPTIVE_CANDIDATE' THEN 1 ELSE 0 END) END "
      "AS BlockRateCandidatePct "
      "FROM experiment e LEFT JOIN research_run_note n "
      "ON n.experiment_id=e.experiment_id GROUP BY e.experiment_id";
}

string ResearchDBViewAdaptiveEpisodeSummary()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_episode_summary AS "
      "SELECT COUNT(*) AS TotalEpisodes,"
      "COALESCE(SUM(CASE WHEN Status='ACTIVE' THEN 1 ELSE 0 END),0) "
      "AS ActiveEpisodes,"
      "COALESCE(SUM(CASE WHEN Status='EXPIRED' THEN 1 ELSE 0 END),0) "
      "AS ExpiredEpisodes,"
      "COALESCE(SUM(BlockedOpportunityCount),0) "
      "AS TotalBlockedOpportunities,"
      "COALESCE(AVG(BlockedOpportunityCount),0.0) "
      "AS AvgBlockedOpportunitiesPerEpisode,"
      "COALESCE(MAX(BlockedOpportunityCount),0) "
      "AS MaxBlockedOpportunitiesPerEpisode,"
      "COALESCE(SUM(CASE WHEN PatternDirection='BUY' AND PatternZone=1 "
      "THEN 1 ELSE 0 END),0) AS BUYZone1Episodes,"
      "COALESCE(SUM(CASE WHEN PatternDirection='SELL' AND PatternZone=6 "
      "THEN 1 ELSE 0 END),0) AS SELLZone6Episodes,"
      "COALESCE(SUM(CASE WHEN PatternDirection='SELL' AND PatternZone=5 "
      "THEN 1 ELSE 0 END),0) AS SELLZone5Episodes,"
      "COALESCE((SELECT PatternDirection||' Zone'||PatternZone "
      "FROM adaptive_loss_cluster_episode GROUP BY PatternDirection,"
      "PatternZone ORDER BY COUNT(*) DESC,PatternDirection,PatternZone "
      "LIMIT 1),'NONE') AS MostFrequentPattern,"
      "COALESCE((SELECT PatternDirection||' Zone'||PatternZone "
      "FROM adaptive_loss_cluster_episode GROUP BY PatternDirection,"
      "PatternZone HAVING SUM(BlockedOpportunityCount)>0 "
      "ORDER BY SUM(BlockedOpportunityCount) DESC,"
      "PatternDirection,PatternZone LIMIT 1),'NONE') "
      "AS MostBlockedPattern FROM adaptive_loss_cluster_episode";
}

string ResearchDBViewAdaptiveEpisodeDetail()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_episode_detail AS "
      "SELECT EpisodeID,PatternDirection,PatternZone,ActivatedTime,"
      "ExpiredTime,CooldownBars,LossClusterSize,"
      "BlockedOpportunityCount,FirstBlockedTime,LastBlockedTime,Status,"
      "ROUND((julianday(COALESCE(ExpiredTime,LastBlockedTime,"
      "ActivatedTime))-"
      "julianday(ActivatedTime))*1440.0,2) AS DurationMinutes,"
      "CASE WHEN (julianday(COALESCE(ExpiredTime,LastBlockedTime,"
      "ActivatedTime))-"
      "julianday(ActivatedTime))*24.0<=0 THEN 0.0 ELSE ROUND("
      "BlockedOpportunityCount/((julianday(COALESCE(ExpiredTime,"
      "LastBlockedTime,ActivatedTime))-julianday(ActivatedTime))*"
      "24.0),4) END "
      "AS BlockedOpportunityPerHour "
      "FROM adaptive_loss_cluster_episode ORDER BY EpisodeID";
}

string ResearchDBViewAdaptivePatternSummary()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_pattern_summary AS "
      "SELECT PatternDirection,PatternZone,COUNT(*) AS EpisodeCount,"
      "SUM(BlockedOpportunityCount) AS TotalBlockedOpportunities,"
      "AVG(BlockedOpportunityCount) AS AvgBlockedOpportunities,"
      "MAX(BlockedOpportunityCount) AS MaxBlockedOpportunities,"
      "MIN(ActivatedTime) AS FirstActivation,"
      "MAX(ActivatedTime) AS LastActivation "
      "FROM adaptive_loss_cluster_episode "
      "GROUP BY PatternDirection,PatternZone "
      "ORDER BY TotalBlockedOpportunities DESC";
}

string ResearchDBViewAdaptiveShadowSummary()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_shadow_summary AS "
      "SELECT COUNT(*) AS TotalShadowTrades,"
      "COALESCE(SUM(CASE WHEN Status='CLOSED' "
      "THEN 1 ELSE 0 END),0) "
      "AS ClosedShadowTrades,"
      "COALESCE(SUM(CASE WHEN Status='OPEN' "
      "THEN 1 ELSE 0 END),0) "
      "AS OpenShadowTrades,"
      "COALESCE(SUM(CASE WHEN WouldWin=1 "
      "THEN 1 ELSE 0 END),0) AS ShadowWins,"
      "COALESCE(SUM(CASE WHEN WouldLoss=1 "
      "THEN 1 ELSE 0 END),0) AS ShadowLosses,"
      "COALESCE(SUM(CASE WHEN Status='CLOSED' "
      "THEN ShadowProfitUSD ELSE 0 END),0.0) AS ShadowNetProfit,"
      "COALESCE(SUM(CASE WHEN ShadowProfitUSD>0 "
      "THEN ShadowProfitUSD ELSE 0 END),0.0) AS ShadowGrossProfit,"
      "ABS(COALESCE(SUM(CASE WHEN ShadowProfitUSD<0 "
      "THEN ShadowProfitUSD ELSE 0 END),0.0)) AS ShadowGrossLoss,"
      "CASE WHEN ABS(COALESCE(SUM(CASE WHEN ShadowProfitUSD<0 "
      "THEN ShadowProfitUSD ELSE 0 END),0.0))=0 THEN NULL "
      "ELSE COALESCE(SUM(CASE WHEN ShadowProfitUSD>0 "
      "THEN ShadowProfitUSD ELSE 0 END),0.0)/ABS(SUM(CASE WHEN "
      "ShadowProfitUSD<0 THEN ShadowProfitUSD ELSE 0 END)) END "
      "AS ShadowProfitFactor,"
      "COALESCE(AVG(CASE WHEN Status='CLOSED' "
      "THEN ShadowProfitUSD END),0.0) AS AvgShadowProfit,"
      "COALESCE(AVG(CASE WHEN Status='CLOSED' "
      "THEN ShadowHoldingBars END),0.0) AS AvgShadowHoldingBars,"
      "COALESCE(AVG(CASE WHEN Status='CLOSED' "
      "THEN ShadowHoldingMinutes END),0.0) "
      "AS AvgShadowHoldingMinutes FROM adaptive_shadow_trade";
}

string ResearchDBViewAdaptiveEpisodeShadowResult()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_episode_shadow_result AS "
      "SELECT e.EpisodeID,e.PatternDirection,e.PatternZone,"
      "e.ActivatedTime,e.ExpiredTime,e.BlockedOpportunityCount,"
      "COUNT(s.ShadowTradeID) AS ShadowTradeCount,"
      "SUM(CASE WHEN s.WouldWin=1 THEN 1 ELSE 0 END) "
      "AS ShadowWinCount,"
      "SUM(CASE WHEN s.WouldLoss=1 THEN 1 ELSE 0 END) "
      "AS ShadowLossCount,"
      "COALESCE(SUM(CASE WHEN s.Status='CLOSED' "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0) AS ShadowNetProfit,"
      "CASE WHEN ABS(COALESCE(SUM(CASE WHEN s.ShadowProfitUSD<0 "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0))=0 THEN NULL "
      "ELSE COALESCE(SUM(CASE WHEN s.ShadowProfitUSD>0 "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0)/ABS(SUM(CASE WHEN "
      "s.ShadowProfitUSD<0 THEN s.ShadowProfitUSD ELSE 0 END)) END "
      "AS ShadowProfitFactor,"
      "COALESCE(AVG(CASE WHEN s.Status='CLOSED' "
      "THEN s.ShadowProfitUSD END),0.0) AS AvgShadowProfit,"
      "CASE WHEN COUNT(s.ShadowTradeID)=0 THEN 'NO_DATA' "
      "WHEN COALESCE(SUM(CASE WHEN s.Status='CLOSED' "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0)<0 THEN 'GOOD_BLOCK' "
      "WHEN COALESCE(SUM(CASE WHEN s.Status='CLOSED' "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0)>0 THEN 'BAD_BLOCK' "
      "ELSE 'NEUTRAL' END AS EpisodeJudgement "
      "FROM adaptive_loss_cluster_episode e "
      "LEFT JOIN adaptive_shadow_trade s ON s.EpisodeID=e.EpisodeID "
      "GROUP BY e.EpisodeID,e.PatternDirection,e.PatternZone,"
      "e.ActivatedTime,e.ExpiredTime,e.BlockedOpportunityCount";
}

string ResearchDBViewAdaptivePatternShadowResult()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_adaptive_pattern_shadow_result AS "
      "WITH episode_result AS (SELECT e.EpisodeID,"
      "e.PatternDirection AS Direction,e.PatternZone AS Zone,"
      "COUNT(s.ShadowTradeID) AS ShadowTradeCount,"
      "SUM(CASE WHEN s.WouldWin=1 THEN 1 ELSE 0 END) AS Wins,"
      "SUM(CASE WHEN s.WouldLoss=1 THEN 1 ELSE 0 END) AS Losses,"
      "COALESCE(SUM(CASE WHEN s.Status='CLOSED' "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0) AS NetProfit,"
      "COALESCE(SUM(CASE WHEN s.ShadowProfitUSD>0 "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0) AS GrossProfit,"
      "ABS(COALESCE(SUM(CASE WHEN s.ShadowProfitUSD<0 "
      "THEN s.ShadowProfitUSD ELSE 0 END),0.0)) AS GrossLoss "
      "FROM adaptive_loss_cluster_episode e "
      "LEFT JOIN adaptive_shadow_trade s ON s.EpisodeID=e.EpisodeID "
      "GROUP BY e.EpisodeID,e.PatternDirection,e.PatternZone) "
      "SELECT Direction,Zone,COUNT(*) AS EpisodeCount,"
      "SUM(ShadowTradeCount) AS ShadowTradeCount,"
      "SUM(Wins) AS ShadowWinCount,SUM(Losses) AS ShadowLossCount,"
      "SUM(NetProfit) AS ShadowNetProfit,"
      "CASE WHEN SUM(GrossLoss)=0 THEN NULL "
      "ELSE SUM(GrossProfit)/SUM(GrossLoss) END AS ShadowProfitFactor,"
      "CASE WHEN SUM(ShadowTradeCount)=0 THEN 0.0 "
      "ELSE SUM(NetProfit)/SUM(ShadowTradeCount) END "
      "AS AvgShadowProfit,"
      "SUM(CASE WHEN ShadowTradeCount>0 AND NetProfit<0 "
      "THEN 1 ELSE 0 END) AS GoodBlockEpisodes,"
      "SUM(CASE WHEN ShadowTradeCount>0 AND NetProfit>0 "
      "THEN 1 ELSE 0 END) AS BadBlockEpisodes,"
      "-1.0*SUM(NetProfit) AS NetAdaptiveBenefit "
      "FROM episode_result GROUP BY Direction,Zone "
      "ORDER BY NetAdaptiveBenefit DESC";
}

string ResearchDBViewPressureAdviceExecution()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_advice_vs_execution AS "
      "SELECT s.experiment_id,s.signal_id,s.signal_time,"
      "s.candidate_direction_before_pressure,s.decision_before_pressure,"
      "s.decision_after_pressure,p.pressure_action,"
      "p.pressure_direction,p.pressure_level,p.pressure_score,"
      "s.pressure_penalty_applied,p.pressure_decision_impact,"
      "CASE WHEN t.trade_id IS NULL THEN 0 ELSE 1 END "
      "AS is_trade_opened,t.trade_id,tc.profit,tc.exit_reason,"
      "ps.policy_mismatch_type,ps.policy_interpretation "
      "FROM signal s LEFT JOIN pressure_snapshot p "
      "ON p.pressure_snapshot_id=s.pressure_snapshot_id "
      "LEFT JOIN policy_snapshot ps ON ps.signal_id=s.signal_id "
      "LEFT JOIN trade_open t ON t.signal_id=s.signal_id "
      "LEFT JOIN trade_close tc ON tc.experiment_id=s.experiment_id "
      "AND tc.trade_id=t.trade_id";
}

string ResearchDBViewPressureShadowValue()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_shadow_value AS "
      "SELECT experiment_id,pressure_decision_impact,pressure_action,"
      "pressure_direction,pressure_level,"
      "candidate_direction_before_pressure,"
      "SUM(CASE WHEN trade_id>0 THEN 1 ELSE 0 END) AS trade_count,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "COALESCE(SUM(profit),0) AS net_profit,AVG(profit) AS avg_profit,"
      "AVG(mae_points) AS avg_mae,AVG(mfe_points) AS avg_mfe,"
      "AVG(bars_held) AS avg_bars_held "
      "FROM v_signal_lifecycle GROUP BY experiment_id,"
      "pressure_decision_impact,pressure_action,pressure_direction,"
      "pressure_level,candidate_direction_before_pressure";
}

string ResearchDBViewTradePerformance()
{
   return
      "CREATE VIEW IF NOT EXISTS v_trade_performance_summary AS "
      "SELECT experiment_id,COUNT(*) AS total_trades,"
      "COUNT(*) AS closed_trades,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "COALESCE(SUM(profit+swap+commission),0) AS net_profit,"
      "COALESCE(SUM(CASE WHEN profit+swap+commission>0 "
      "THEN profit+swap+commission ELSE 0 END),0) AS gross_profit,"
      "COALESCE(SUM(CASE WHEN profit+swap+commission<0 "
      "THEN profit+swap+commission ELSE 0 END),0) AS gross_loss,"
      "CASE WHEN SUM(CASE WHEN profit+swap+commission<0 "
      "THEN -(profit+swap+commission) ELSE 0 END)>0 "
      "THEN SUM(CASE WHEN profit+swap+commission>0 "
      "THEN profit+swap+commission ELSE 0 END)/"
      "SUM(CASE WHEN profit+swap+commission<0 "
      "THEN -(profit+swap+commission) ELSE 0 END) ELSE NULL END "
      "AS profit_factor,AVG(profit+swap+commission) AS avg_profit,"
      "AVG(mae_points) AS avg_mae,AVG(mfe_points) AS avg_mfe,"
      "AVG(bars_held) AS avg_bars_held "
      "FROM trade_close GROUP BY experiment_id";
}

string ResearchDBViewZonePressurePerformance()
{
   return
      "CREATE VIEW IF NOT EXISTS v_zone_pressure_performance AS "
      "SELECT experiment_id,zone_id,zone_label,"
      "candidate_direction_before_pressure,pressure_direction,"
      "pressure_level,"
      "SUM(CASE WHEN trade_id>0 THEN 1 ELSE 0 END) AS trade_count,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "COALESCE(SUM(profit),0) AS net_profit,AVG(profit) AS avg_profit,"
      "AVG(mae_points) AS avg_mae,AVG(mfe_points) AS avg_mfe "
      "FROM v_signal_lifecycle GROUP BY experiment_id,zone_id,zone_label,"
      "candidate_direction_before_pressure,pressure_direction,"
      "pressure_level";
}

string ResearchDBViewRegimePerformance()
{
   return
      "CREATE VIEW IF NOT EXISTS v_regime_performance AS "
      "SELECT experiment_id,detected_regime,best_candidate_regime,"
      "active_regime,candidate_direction_before_pressure,"
      "SUM(CASE WHEN trade_id>0 THEN 1 ELSE 0 END) AS trade_count,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "COALESCE(SUM(profit),0) AS net_profit,AVG(profit) AS avg_profit,"
      "AVG(mae_points) AS avg_mae,AVG(mfe_points) AS avg_mfe "
      "FROM v_signal_lifecycle GROUP BY experiment_id,detected_regime,"
      "best_candidate_regime,active_regime,"
      "candidate_direction_before_pressure";
}

string ResearchDBViewPressureSavedOrMissed()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_saved_or_missed AS "
      "SELECT l.experiment_id,l.signal_id,l.signal_time,"
      "l.candidate_direction_before_pressure,l.decision_before_pressure,"
      "l.decision_after_pressure,l.pressure_direction,l.pressure_level,"
      "l.pressure_score,l.pressure_action,l.pressure_decision_impact,"
      "l.is_trade_opened,l.trade_id,l.profit,l.mae_points,l.mfe_points,"
      "l.exit_reason,CASE "
      "WHEN s.blocked_by_pressure=1 AND l.is_trade_opened=0 "
      "AND fo.would_hit_sl=1 AND COALESCE(fo.would_hit_tp,0)=0 "
      "THEN 'SAVED_LOSS' "
      "WHEN s.blocked_by_pressure=1 AND l.is_trade_opened=0 "
      "AND fo.would_hit_tp=1 AND COALESCE(fo.would_hit_sl,0)=0 "
      "THEN 'MISSED_WIN' "
      "WHEN s.blocked_by_pressure=1 AND l.is_trade_opened=0 "
      "THEN 'BLOCKED_PENDING_OUTCOME' "
      "WHEN l.is_trade_opened=1 THEN 'EXECUTED_TRADE' "
      "WHEN l.pressure_decision_impact='SCORE_REDUCED' "
      "THEN 'SOFT_WARNING' "
      "ELSE 'NO_PRESSURE_WARNING' END AS pressure_shadow_result "
      "FROM v_signal_lifecycle l JOIN signal s "
      "ON s.signal_id=l.signal_id "
      "LEFT JOIN (SELECT signal_id,MAX(would_hit_tp) AS would_hit_tp,"
      "MAX(would_hit_sl) AS would_hit_sl FROM future_outcome "
      "GROUP BY signal_id) fo ON fo.signal_id=l.signal_id";
}

string ResearchDBViewPressureZoneRiskMatrix()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_zone_risk_matrix AS "
      "SELECT experiment_id,zone_id,zone_label,"
      "candidate_direction_before_pressure,pressure_direction,"
      "pressure_level,COUNT(trade_id) AS trade_count,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "COALESCE(SUM(profit),0) AS net_profit,AVG(profit) AS avg_profit,"
      "AVG(mae_points) AS avg_mae,AVG(mfe_points) AS avg_mfe,"
      "CASE WHEN SUM(CASE WHEN profit<0 THEN -profit ELSE 0 END)>0 "
      "THEN SUM(CASE WHEN profit>0 THEN profit ELSE 0 END)/"
      "SUM(CASE WHEN profit<0 THEN -profit ELSE 0 END) "
      "ELSE NULL END AS profit_factor "
      "FROM v_signal_lifecycle WHERE trade_id>0 "
      "GROUP BY experiment_id,zone_id,zone_label,"
      "candidate_direction_before_pressure,pressure_direction,"
      "pressure_level";
}

string ResearchDBViewBestPracticeCandidate()
{
   return
      "CREATE VIEW IF NOT EXISTS v_best_practice_candidate AS "
      "SELECT 'ZONE_'||COALESCE(CAST(zone_id AS TEXT),'NA')||'_'||"
      "COALESCE(candidate_direction_before_pressure,'NONE')||"
      "'_PRESSURE_'||COALESCE(pressure_direction,'NONE')||'_'||"
      "COALESCE(pressure_level,'NONE') AS rule_candidate,"
      "zone_id,zone_label,candidate_direction_before_pressure,"
      "pressure_direction,pressure_level,trade_count,win_count,"
      "loss_count,net_profit,avg_profit,avg_mae,avg_mfe,"
      "CASE WHEN trade_count>=5 AND net_profit<0 "
      "AND loss_count>win_count THEN 'AVOID_OR_BLOCK' "
      "WHEN trade_count>=5 AND net_profit>0 "
      "AND win_count>=loss_count THEN 'ALLOW_OR_PROMOTE' "
      "ELSE 'NEED_MORE_DATA' END AS suggested_action "
      "FROM v_pressure_zone_risk_matrix";
}

string ResearchDBViewPressurePolicySummary()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_policy_summary AS "
      "SELECT experiment_id,pressure_decision_impact,pressure_action,"
      "pressure_direction,pressure_level,"
      "candidate_direction_before_pressure,COUNT(*) AS signal_count,"
      "SUM(CASE WHEN trade_id>0 THEN 1 ELSE 0 END) AS trade_count,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "COALESCE(SUM(profit),0) AS net_profit,AVG(profit) AS avg_profit,"
      "AVG(mae_points) AS avg_mae,AVG(mfe_points) AS avg_mfe "
      "FROM v_signal_lifecycle GROUP BY experiment_id,"
      "pressure_decision_impact,pressure_action,pressure_direction,"
      "pressure_level,candidate_direction_before_pressure";
}

string ResearchDBViewTradeAttributionValidation()
{
   return
      "CREATE VIEW IF NOT EXISTS v_trade_attribution_validation AS "
      "SELECT s.experiment_id,s.signal_id,t.trade_id,"
      "s.candidate_direction_before_pressure AS candidate_direction,"
      "s.decision_after_pressure,s.blocked_by_pressure,"
      "CASE WHEN t.trade_id IS NULL THEN 0 ELSE 1 END "
      "AS is_trade_opened,COALESCE(t.entry_time,t.open_time) "
      "AS execution_time,COALESCE(t.execution_delay_seconds,0) "
      "AS execution_delay,CASE "
      "WHEN (SELECT COUNT(*) FROM trade_open tx "
      "WHERE tx.experiment_id=s.experiment_id "
      "AND tx.signal_id=s.signal_id)>1 "
      "THEN 'MULTIPLE_TRADES_PER_SIGNAL' "
      "WHEN s.blocked_by_pressure=1 AND t.trade_id IS NOT NULL "
      "THEN 'SIGNAL_MISMATCH' "
      "WHEN t.trade_id IS NOT NULL AND "
      "COALESCE(s.snapshot_version,0)>=4 AND "
      "COALESCE(s.signal_kind,'')<>'EXECUTION' "
      "THEN 'SIGNAL_MISMATCH' "
      "WHEN t.trade_id IS NOT NULL AND "
      "COALESCE(t.execution_delay_seconds,0)<0 "
      "THEN 'SIGNAL_MISMATCH' "
      "WHEN t.trade_id IS NOT NULL AND "
      "COALESCE(s.candidate_direction_before_pressure,'NONE')<>"
      "COALESCE(t.direction,'NONE') THEN 'SIGNAL_MISMATCH' "
      "WHEN t.trade_id IS NOT NULL THEN 'OK' "
      "WHEN s.blocked_by_pressure=1 THEN 'BLOCKED' "
      "WHEN COALESCE(s.is_trade_opened,0)=1 OR "
      "COALESCE(s.trade_id,0)>0 THEN 'ORPHAN_SIGNAL' "
      "ELSE 'OK' END AS validation_result "
      "FROM signal s LEFT JOIN trade_open t "
      "ON t.experiment_id=s.experiment_id AND t.signal_id=s.signal_id "
      "UNION ALL SELECT t.experiment_id,NULL,t.trade_id,NULL,NULL,0,1,"
      "COALESCE(t.entry_time,t.open_time),"
      "COALESCE(t.execution_delay_seconds,0),"
      "CASE WHEN t.signal_id IS NULL THEN 'TRADE_WITHOUT_SIGNAL' "
      "ELSE 'ORPHAN_TRADE' END "
      "FROM trade_open t LEFT JOIN signal s "
      "ON s.experiment_id=t.experiment_id AND s.signal_id=t.signal_id "
      "WHERE s.signal_id IS NULL";
}

string ResearchDBViewPressureExecutionSummary()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_execution_summary AS "
      "SELECT p.experiment_id,p.pressure_execution_block_mode_name "
      "AS pressure_mode,p.pressure_execution_block_enabled,"
      "p.pressure_execution_block_applied,"
      "COUNT(*) AS signal_count,"
      "SUM(CASE WHEN t.trade_id IS NOT NULL THEN 1 ELSE 0 END) "
      "AS trade_count,"
      "SUM(CASE WHEN p.pressure_execution_block_applied=1 "
      "THEN 1 ELSE 0 END) AS block_count,"
      "SUM(CASE WHEN p.pressure_execution_block_applied=1 "
      "AND t.trade_id IS NOT NULL THEN 1 ELSE 0 END) "
      "AS block_mismatch_count "
      "FROM policy_snapshot p LEFT JOIN trade_open t "
      "ON t.experiment_id=p.experiment_id AND t.signal_id=p.signal_id "
      "GROUP BY p.experiment_id,"
      "p.pressure_execution_block_mode_name,"
      "p.pressure_execution_block_enabled,"
      "p.pressure_execution_block_applied";
}

string ResearchDBViewPressureBlockStatistics()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_block_statistics AS "
      "SELECT s.experiment_id AS Experiment,"
      "COALESCE(e.pressure_mode,e.pressure_execution_block_mode_name,"
      "'UNKNOWN') AS Pressure_Mode,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 "
      "AND m.is_trade_opened=0 THEN 1 ELSE 0 END) AS Blocked_Trades,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 "
      "AND s.candidate_direction_before_pressure='BUY' "
      "AND m.is_trade_opened=0 THEN 1 ELSE 0 END) AS Blocked_BUY,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 "
      "AND s.candidate_direction_before_pressure='SELL' "
      "AND m.is_trade_opened=0 THEN 1 ELSE 0 END) AS Blocked_SELL,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 "
      "AND m.pressure_level='HIGH' AND m.is_trade_opened=0 "
      "THEN 1 ELSE 0 END) AS Blocked_HIGH,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 "
      "AND m.pressure_level='MEDIUM' AND m.is_trade_opened=0 "
      "THEN 1 ELSE 0 END) AS Blocked_MEDIUM,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 "
      "AND m.pressure_level='LOW' AND m.is_trade_opened=0 "
      "THEN 1 ELSE 0 END) AS Blocked_LOW,"
      "SUM(CASE WHEN m.pressure_shadow_result='SAVED_LOSS' "
      "THEN 1 ELSE 0 END) AS Saved_Loss,"
      "SUM(CASE WHEN m.pressure_shadow_result='MISSED_WIN' "
      "THEN 1 ELSE 0 END) AS Missed_Win,"
      "SUM(CASE WHEN m.pressure_shadow_result='SAVED_LOSS' "
      "THEN 1 WHEN m.pressure_shadow_result='MISSED_WIN' "
      "THEN -1 ELSE 0 END) AS Net_Benefit "
      "FROM signal s JOIN experiment e "
      "ON e.experiment_id=s.experiment_id "
      "JOIN v_pressure_saved_or_missed m ON m.signal_id=s.signal_id "
      "GROUP BY s.experiment_id,"
      "COALESCE(e.pressure_mode,e.pressure_execution_block_mode_name,"
      "'UNKNOWN')";
}

string ResearchDBViewExperimentSummary()
{
   return
      "CREATE VIEW IF NOT EXISTS v_experiment_summary AS "
      "WITH trade_net AS (SELECT experiment_id,trade_id,close_time,"
      "(profit+COALESCE(swap,0)+COALESCE(commission,0)) AS net "
      "FROM trade_close),equity AS (SELECT experiment_id,trade_id,"
      "close_time,net,SUM(net) OVER(PARTITION BY experiment_id "
      "ORDER BY close_time,trade_id ROWS BETWEEN UNBOUNDED PRECEDING "
      "AND CURRENT ROW) AS cumulative FROM trade_net),peaks AS ("
      "SELECT experiment_id,trade_id,cumulative,"
      "MAX(cumulative) OVER(PARTITION BY experiment_id "
      "ORDER BY close_time,trade_id ROWS BETWEEN UNBOUNDED PRECEDING "
      "AND CURRENT ROW) AS running_peak FROM equity),drawdowns AS ("
      "SELECT experiment_id,MAX((CASE WHEN running_peak>0 "
      "THEN running_peak ELSE 0 END)-cumulative) AS max_drawdown "
      "FROM peaks GROUP BY experiment_id),stats AS ("
      "SELECT experiment_id,COUNT(*) AS trades,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS wins,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS losses,"
      "SUM(profit+COALESCE(swap,0)+COALESCE(commission,0)) "
      "AS net_profit,SUM(CASE WHEN profit>0 THEN profit ELSE 0 END)/"
      "NULLIF(SUM(CASE WHEN profit<0 THEN -profit ELSE 0 END),0) "
      "AS profit_factor,AVG(mae_points) AS average_mae,"
      "AVG(mfe_points) AS average_mfe,AVG(realized_rr) AS average_rr,"
      "AVG(bars_held) AS average_holding_bars "
      "FROM trade_close GROUP BY experiment_id) "
      "SELECT e.experiment_name,e.engine_version,e.schema_version,"
      "e.symbol,e.timeframe,e.date_start,e.date_end,e.profile,"
      "e.pressure_mode,e.execution_mode,"
      "COALESCE((SELECT COUNT(*) FROM signal s "
      "WHERE s.experiment_id=e.experiment_id),0) AS total_signals,"
      "COALESCE(st.trades,0) AS total_trades,"
      "COALESCE(st.wins,0) AS wins,COALESCE(st.losses,0) AS losses,"
      "st.profit_factor,COALESCE(st.net_profit,0) AS net_profit,"
      "COALESCE(dd.max_drawdown,0) AS drawdown,"
      "st.average_mae,st.average_mfe,st.average_rr,"
      "st.average_holding_bars AS average_holding "
      "FROM experiment e LEFT JOIN stats st "
      "ON st.experiment_id=e.experiment_id LEFT JOIN drawdowns dd "
      "ON dd.experiment_id=e.experiment_id";
}

string ResearchDBViewPressureStatistics()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_statistics AS "
      "WITH base AS (SELECT experiment_id,"
      "COALESCE(NULLIF(pressure_level,''),'UNKNOWN') AS level,"
      "COALESCE(NULLIF(pressure_direction,''),'UNKNOWN') AS direction "
      "FROM pressure_snapshot),totals AS (SELECT experiment_id,"
      "COUNT(*) AS total FROM base GROUP BY experiment_id) "
      "SELECT b.experiment_id,'LEVEL' AS pressure_group,"
      "'LOW' AS pressure_value,"
      "SUM(CASE WHEN b.level='LOW' THEN 1 ELSE 0 END) AS count,"
      "100.0*SUM(CASE WHEN b.level='LOW' THEN 1 ELSE 0 END)/"
      "NULLIF(t.total,0) AS percentage FROM base b JOIN totals t "
      "ON t.experiment_id=b.experiment_id GROUP BY b.experiment_id "
      "UNION ALL SELECT b.experiment_id,'LEVEL','MEDIUM',"
      "SUM(CASE WHEN b.level='MEDIUM' THEN 1 ELSE 0 END),"
      "100.0*SUM(CASE WHEN b.level='MEDIUM' THEN 1 ELSE 0 END)/"
      "NULLIF(t.total,0) FROM base b JOIN totals t "
      "ON t.experiment_id=b.experiment_id GROUP BY b.experiment_id "
      "UNION ALL SELECT b.experiment_id,'LEVEL','HIGH',"
      "SUM(CASE WHEN b.level='HIGH' THEN 1 ELSE 0 END),"
      "100.0*SUM(CASE WHEN b.level='HIGH' THEN 1 ELSE 0 END)/"
      "NULLIF(t.total,0) FROM base b JOIN totals t "
      "ON t.experiment_id=b.experiment_id GROUP BY b.experiment_id "
      "UNION ALL SELECT b.experiment_id,'DIRECTION','UP',"
      "SUM(CASE WHEN b.direction='UP' THEN 1 ELSE 0 END),"
      "100.0*SUM(CASE WHEN b.direction='UP' THEN 1 ELSE 0 END)/"
      "NULLIF(t.total,0) FROM base b JOIN totals t "
      "ON t.experiment_id=b.experiment_id GROUP BY b.experiment_id "
      "UNION ALL SELECT b.experiment_id,'DIRECTION','DOWN',"
      "SUM(CASE WHEN b.direction='DOWN' THEN 1 ELSE 0 END),"
      "100.0*SUM(CASE WHEN b.direction='DOWN' THEN 1 ELSE 0 END)/"
      "NULLIF(t.total,0) FROM base b JOIN totals t "
      "ON t.experiment_id=b.experiment_id GROUP BY b.experiment_id "
      "UNION ALL SELECT b.experiment_id,'DIRECTION','UNKNOWN',"
      "SUM(CASE WHEN b.direction NOT IN ('UP','DOWN') "
      "THEN 1 ELSE 0 END),"
      "100.0*SUM(CASE WHEN b.direction NOT IN ('UP','DOWN') "
      "THEN 1 ELSE 0 END)/NULLIF(t.total,0) "
      "FROM base b JOIN totals t ON t.experiment_id=b.experiment_id "
      "GROUP BY b.experiment_id";
}

string ResearchDBViewPressureExecution()
{
   return
      "CREATE VIEW IF NOT EXISTS v_pressure_execution AS "
      "SELECT s.experiment_id,COUNT(*) AS signals,"
      "SUM(CASE WHEN s.blocked_by_pressure=1 THEN 1 ELSE 0 END) "
      "AS blocked,"
      "SUM(CASE WHEN t.trade_id IS NOT NULL THEN 1 ELSE 0 END) "
      "AS executed,"
      "SUM(CASE WHEN s.decision_after_pressure='WATCH' "
      "OR s.final_decision='WATCH' THEN 1 ELSE 0 END) AS watch,"
      "SUM(CASE WHEN s.decision_after_pressure IN "
      "('BUY READY','SELL READY') THEN 1 ELSE 0 END) AS allow,"
      "100.0*SUM(CASE WHEN t.trade_id IS NOT NULL THEN 1 ELSE 0 END)/"
      "NULLIF(COUNT(*),0) AS execution_rate "
      "FROM signal s LEFT JOIN trade_open t "
      "ON t.experiment_id=s.experiment_id AND t.signal_id=s.signal_id "
      "GROUP BY s.experiment_id";
}

string ResearchDBViewTradeDistribution()
{
   return
      "CREATE VIEW IF NOT EXISTS v_trade_distribution AS "
      "SELECT experiment_id,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss,"
      "SUM(CASE WHEN UPPER(exit_reason)='TP' THEN 1 ELSE 0 END) AS tp,"
      "SUM(CASE WHEN UPPER(exit_reason)='SL' THEN 1 ELSE 0 END) AS sl,"
      "SUM(CASE WHEN UPPER(exit_reason)='TIMEOUT' "
      "THEN 1 ELSE 0 END) AS timeout,"
      "AVG(CASE WHEN profit>0 THEN profit END) AS average_profit,"
      "AVG(CASE WHEN profit<0 THEN profit END) AS average_loss,"
      "MAX(profit) AS largest_win,MIN(profit) AS largest_loss "
      "FROM trade_close GROUP BY experiment_id";
}

string ResearchDBViewTradeAnomaly()
{
   return
      "CREATE VIEW IF NOT EXISTS v_trade_anomaly AS "
      "SELECT tc.experiment_id,tc.trade_id,tc.signal_id,"
      "tc.requested_sl_points,tc.requested_tp_points,"
      "tc.effective_sl_points,tc.effective_tp_points,"
      "tc.entry_price,tc.sl_price,tc.tp_price,tc.close_price,"
      "tc.close_reason,tc.actual_volume,tc.symbol_point,tc.tick_size,"
      "tc.tick_value,tc.spread_at_entry,tc.commission,tc.swap,"
      "tc.gross_profit,tc.net_profit,tc.expected_loss_money,"
      "tc.expected_profit_money,tc.profit_deviation_money,"
      "tc.profit_deviation_points,tc.is_exact_sl_hit,"
      "tc.is_exact_tp_hit,tc.is_timeout_exit,tc.is_tester_close,"
      "tc.audit_reason,CASE "
      "WHEN tc.close_reason='TP' AND tc.is_exact_tp_hit=0 "
      "THEN 'TP_PRICE_MISMATCH' "
      "WHEN tc.close_reason='SL' AND tc.is_exact_sl_hit=0 "
      "THEN 'SL_PRICE_MISMATCH' "
      "WHEN tc.close_reason IN "
      "('TIMEOUT','TESTER_CLOSE','CLOSE_WEEKEND_PROTECTION') "
      "THEN 'NON_FIXED_EXIT' "
      "WHEN ABS(COALESCE(tc.profit_deviation_money,0))>0.01 "
      "THEN 'MONEY_DEVIATION' ELSE 'OK' END AS flag "
      "FROM trade_close tc";
}

string ResearchDBViewTradeEpisode()
{
   return
      "CREATE VIEW IF NOT EXISTS v_trade_episode AS "
      "SELECT episode_id,experiment_id,episode_start AS start,"
      "episode_end AS end,trade_count AS trades,net_profit,"
      "win_rate,average_rr,purpose FROM research_episode";
}

string ResearchDBViewResearchValidation()
{
   return
      "CREATE VIEW IF NOT EXISTS v_research_validation AS "
      "SELECT e.experiment_id,"
      "(SELECT COUNT(*) FROM signal s "
      "WHERE s.experiment_id=e.experiment_id) AS signals,"
      "(SELECT COUNT(*) FROM trade_open t "
      "WHERE t.experiment_id=e.experiment_id) AS trades,"
      "(SELECT COUNT(*) FROM signal s WHERE s.experiment_id="
      "e.experiment_id AND s.blocked_by_pressure=1) AS blocked,"
      "(SELECT COUNT(*) FROM v_trade_attribution_validation v "
      "WHERE v.validation_result IN "
      "('ORPHAN_SIGNAL','ORPHAN_TRADE','TRADE_WITHOUT_SIGNAL') "
      "AND v.experiment_id=e.experiment_id) "
      "AS orphan,"
      "(SELECT COUNT(*) FROM (SELECT signal_id FROM trade_open t "
      "WHERE t.experiment_id=e.experiment_id GROUP BY signal_id "
      "HAVING COUNT(*)>1))+(SELECT COUNT(*) FROM (SELECT trade_id "
      "FROM trade_open t WHERE t.experiment_id=e.experiment_id "
      "GROUP BY trade_id HAVING COUNT(*)>1)) AS duplicate,"
      "(SELECT COUNT(*) FROM v_trade_attribution_validation v "
      "WHERE v.validation_result IN ('SIGNAL_MISMATCH',"
      "'TRADE_WITHOUT_SIGNAL','MULTIPLE_TRADES_PER_SIGNAL',"
      "'ORPHAN_SIGNAL','ORPHAN_TRADE') "
      "AND v.experiment_id=e.experiment_id) AS attribution_errors "
      "FROM experiment e";
}

string ResearchDBViewTransitionDoubleEntryRisk()
{
   return
      "CREATE VIEW IF NOT EXISTS v_transition_double_entry_risk AS "
      "WITH settings AS (SELECT e.experiment_id,"
      "COALESCE((SELECT CAST(p.value AS INTEGER) FROM parameter p "
      "WHERE p.experiment_id=e.experiment_id "
      "AND p.name='TransitionDoubleEntryBars' "
      "ORDER BY p.parameter_id DESC LIMIT 1),3) AS window_bars,"
      "COALESCE((SELECT CAST(p.value AS REAL) FROM parameter p "
      "WHERE p.experiment_id=e.experiment_id "
      "AND p.name='TransitionLowScoreGap' "
      "ORDER BY p.parameter_id DESC LIMIT 1),10) AS low_score_gap,"
      "CASE e.execution_tf WHEN 'M1' THEN 1 WHEN 'M5' THEN 5 "
      "WHEN 'M15' THEN 15 WHEN 'M30' THEN 30 WHEN 'H1' THEN 60 "
      "WHEN 'H4' THEN 240 WHEN 'D1' THEN 1440 ELSE 1 END "
      "AS bar_minutes FROM experiment e),raw AS ("
      "SELECT tc.experiment_id,tc.trade_id,tc.signal_id,tc.symbol,"
      "tc.direction,COALESCE(tc.entry_time,tc.open_time) AS entry_time,"
      "COALESCE(tc.exit_time,tc.close_time) AS close_time,"
      "COALESCE(tc.net_profit,tc.profit+COALESCE(tc.swap,0)+"
      "COALESCE(tc.commission,0)) AS profit,"
      "r.active_regime,r.detected_regime,r.best_candidate_regime,"
      "MAX(COALESCE(r.uptrend_score,0),COALESCE(r.sideway_score,0),"
      "COALESCE(r.downtrend_score,0)) AS winning_score,"
      "COALESCE(r.score_gap,0) AS score_gap,"
      "r.regime_switch_status AS switch_status,"
      "p.pressure_direction,p.pressure_level,p.pressure_score,"
      "st.structure_stage,st.bos_state,st.choch_state,"
      "st.development_state,"
      "ROW_NUMBER() OVER(PARTITION BY tc.experiment_id,tc.symbol "
      "ORDER BY COALESCE(tc.entry_time,tc.open_time),tc.trade_id) "
      "AS global_sequence "
      "FROM trade_close tc JOIN signal s "
      "ON s.experiment_id=tc.experiment_id AND s.signal_id=tc.signal_id "
      "LEFT JOIN regime_snapshot r "
      "ON r.regime_snapshot_id=s.regime_snapshot_id "
      "LEFT JOIN pressure_snapshot p "
      "ON p.pressure_snapshot_id=s.pressure_snapshot_id "
      "LEFT JOIN structure_snapshot st "
      "ON st.structure_snapshot_id=s.structure_snapshot_id),sequenced AS ("
      "SELECT raw.*,LAG(trade_id) OVER w AS previous_trade_id,"
      "LAG(profit) OVER w AS previous_profit,"
      "LAG(entry_time) OVER w AS previous_entry_time,"
      "LAG(close_time) OVER w AS previous_close_time,"
      "LAG(global_sequence) OVER w AS previous_global_sequence "
      "FROM raw WINDOW w AS (PARTITION BY experiment_id,symbol,direction "
      "ORDER BY entry_time,trade_id)),measured AS ("
      "SELECT q.*,cfg.window_bars,cfg.low_score_gap,"
      "CASE WHEN previous_entry_time IS NULL THEN NULL ELSE CAST(ROUND(("
      "julianday(REPLACE(entry_time,'.','-'))-"
      "julianday(REPLACE(previous_entry_time,'.','-')))*1440.0/"
      "cfg.bar_minutes) AS INTEGER) END AS bars_since_previous_entry,"
      "CASE WHEN previous_close_time IS NULL THEN NULL ELSE CAST(ROUND(("
      "julianday(REPLACE(entry_time,'.','-'))-"
      "julianday(REPLACE(previous_close_time,'.','-')))*1440.0/"
      "cfg.bar_minutes) AS INTEGER) END AS bars_since_previous_close,"
      "CASE WHEN COALESCE(detected_regime,'UNKNOWN')<>"
      "COALESCE(active_regime,'UNKNOWN') THEN 1 ELSE 0 END AS w_detected,"
      "CASE WHEN COALESCE(best_candidate_regime,'UNKNOWN')<>"
      "COALESCE(active_regime,'UNKNOWN') THEN 1 ELSE 0 END AS w_best,"
      "CASE WHEN score_gap<=cfg.low_score_gap THEN 1 ELSE 0 END AS w_gap,"
      "CASE WHEN UPPER(COALESCE(switch_status,'')) IN "
      "('DETECTED_ONLY','CONFIRMING','HOLDING') THEN 1 ELSE 0 END "
      "AS w_switch,"
      "CASE WHEN (direction='BUY' AND pressure_direction='DOWN') OR "
      "(direction='SELL' AND pressure_direction='UP') "
      "THEN 1 ELSE 0 END AS w_pressure_direction,"
      "CASE WHEN pressure_level IN ('MEDIUM','HIGH') "
      "THEN 1 ELSE 0 END AS w_pressure_level,"
      "CASE WHEN UPPER(COALESCE(choch_state,'')) NOT IN "
      "('','NONE','N/A','NO CHOCH') OR "
      "(direction='BUY' AND (UPPER(COALESCE(bos_state,'')) LIKE '%DOWN%' "
      "OR UPPER(COALESCE(bos_state,'')) LIKE '%BEAR%')) OR "
      "(direction='SELL' AND (UPPER(COALESCE(bos_state,'')) LIKE '%UP%' "
      "OR UPPER(COALESCE(bos_state,'')) LIKE '%BULL%')) "
      "THEN 1 ELSE 0 END AS w_structure,"
      "CASE WHEN direction='BUY' AND ("
      "UPPER(COALESCE(development_state,'')) LIKE '%DOWN%' OR "
      "UPPER(COALESCE(development_state,'')) LIKE '%BEAR%' OR "
      "UPPER(COALESCE(development_state,'')) LIKE '%SELL%') THEN 1 "
      "WHEN direction='SELL' AND ("
      "UPPER(COALESCE(development_state,'')) LIKE '%UP%' OR "
      "UPPER(COALESCE(development_state,'')) LIKE '%BULL%' OR "
      "UPPER(COALESCE(development_state,'')) LIKE '%BUY%') THEN 1 "
      "ELSE 0 END AS w_development "
      "FROM sequenced q JOIN settings cfg "
      "ON cfg.experiment_id=q.experiment_id),warnings AS ("
      "SELECT measured.*,(w_detected+w_best+w_gap+w_switch+"
      "w_pressure_direction+w_pressure_level+w_structure+w_development) "
      "AS transition_warning_count,RTRIM("
      "CASE WHEN w_detected=1 THEN 'DETECTED_ACTIVE_MISMATCH;' ELSE '' END||"
      "CASE WHEN w_best=1 THEN 'BEST_ACTIVE_MISMATCH;' ELSE '' END||"
      "CASE WHEN w_gap=1 THEN 'LOW_SCORE_GAP;' ELSE '' END||"
      "CASE WHEN w_switch=1 THEN 'SWITCH_TRANSITION;' ELSE '' END||"
      "CASE WHEN w_pressure_direction=1 THEN 'OPPOSING_PRESSURE;' ELSE '' END||"
      "CASE WHEN w_pressure_level=1 THEN 'MEDIUM_HIGH_PRESSURE;' ELSE '' END||"
      "CASE WHEN w_structure=1 THEN 'CHOCH_OR_OPPOSITE_BOS;' ELSE '' END||"
      "CASE WHEN w_development=1 THEN 'OPPOSING_DEVELOPMENT;' ELSE '' END,"
      "';') AS transition_warning_reason FROM measured) "
      "SELECT experiment_id,trade_id,signal_id,direction,entry_time,"
      "close_time,profit,previous_trade_id,previous_profit,"
      "bars_since_previous_entry,bars_since_previous_close,"
      "active_regime,detected_regime,best_candidate_regime,"
      "winning_score,score_gap,switch_status,pressure_direction,"
      "pressure_level,pressure_score,structure_stage,bos_state,"
      "choch_state,development_state,transition_warning_count,"
      "transition_warning_reason,CASE "
      "WHEN profit<0 AND previous_profit<0 AND "
      "((global_sequence-previous_global_sequence)=1 OR "
      "bars_since_previous_entry BETWEEN 0 AND window_bars) "
      "AND transition_warning_count>=3 THEN 'HIGH_RISK_DOUBLE_ENTRY' "
      "WHEN profit<0 AND previous_profit<0 AND "
      "((global_sequence-previous_global_sequence)=1 OR "
      "bars_since_previous_entry BETWEEN 0 AND window_bars) "
      "AND transition_warning_count>=1 THEN 'TRANSITION_REPEAT_LOSS' "
      "WHEN profit<0 AND previous_profit<0 AND "
      "((global_sequence-previous_global_sequence)=1 OR "
      "bars_since_previous_entry BETWEEN 0 AND window_bars) "
      "THEN 'REPEAT_LOSS' ELSE 'NORMAL' END AS risk_label "
      "FROM warnings";
}

string ResearchDBViewTransitionDoubleEntrySummary()
{
   return
      "CREATE VIEW IF NOT EXISTS v_transition_double_entry_summary AS "
      "SELECT experiment_id,direction,active_regime,detected_regime,"
      "pressure_level,risk_label,COUNT(*) AS trade_count,"
      "SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END) AS win_count,"
      "SUM(CASE WHEN profit<0 THEN 1 ELSE 0 END) AS loss_count,"
      "100.0*SUM(CASE WHEN profit>0 THEN 1 ELSE 0 END)/"
      "NULLIF(COUNT(*),0) AS win_rate,"
      "COALESCE(SUM(CASE WHEN profit>0 THEN profit ELSE 0 END),0) "
      "AS gross_profit,"
      "COALESCE(SUM(CASE WHEN profit<0 THEN profit ELSE 0 END),0) "
      "AS gross_loss,"
      "SUM(CASE WHEN profit>0 THEN profit ELSE 0 END)/"
      "NULLIF(-SUM(CASE WHEN profit<0 THEN profit ELSE 0 END),0) "
      "AS profit_factor,AVG(profit) AS avg_profit,"
      "MIN(CASE WHEN profit<0 THEN profit END) AS max_loss,"
      "SUM(CASE WHEN risk_label<>'NORMAL' AND profit<0 "
      "THEN 1 ELSE 0 END) AS consecutive_loss_count,"
      "SUM(CASE WHEN risk_label IN "
      "('TRANSITION_REPEAT_LOSS','HIGH_RISK_DOUBLE_ENTRY') "
      "THEN 1 ELSE 0 END) AS blocked_candidate_count_estimate "
      "FROM v_transition_double_entry_risk GROUP BY experiment_id,"
      "direction,active_regime,detected_regime,pressure_level,risk_label";
}

string ResearchDBViewTradeOutlierAnalysis()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_trade_outlier_analysis AS "
      "/* V2 SOURCE: normalize stable tables without optional audit columns. */ "
      "WITH trade_history AS ("
      "SELECT tc.experiment_id,tc.trade_id,tc.signal_id,tc.symbol,"
      "tc.direction,tc.open_time,tc.close_time,tc.bars_held,"
      "tc.holding_minutes,tc.open_price,tc.close_price,tc.volume,"
      "tc.profit,tc.profit_points,tc.swap,tc.commission,tc.exit_reason "
      "FROM trade_close tc),"
      "trade_audit AS ("
      "/* V2 AUDIT: derive point size and expectations from stable trade_open. */ "
      "SELECT h.experiment_id,h.trade_id,"
      "COALESCE(t.planned_risk_points,0) AS expected_sl_points,"
      "COALESCE(t.planned_reward_points,0) AS expected_tp_points,"
      "CASE WHEN ABS(COALESCE(t.planned_risk_points,0))>0 "
      "AND ABS(COALESCE(t.sl,0)-COALESCE(t.open_price,0))>0 "
      "THEN ABS(t.sl-t.open_price)/ABS(t.planned_risk_points) "
      "WHEN ABS(COALESCE(t.planned_reward_points,0))>0 "
      "AND ABS(COALESCE(t.tp,0)-COALESCE(t.open_price,0))>0 "
      "THEN ABS(t.tp-t.open_price)/ABS(t.planned_reward_points) "
      "ELSE NULL END AS symbol_point,"
      "CASE WHEN ABS(COALESCE(h.profit_points,0))>0.00000001 "
      "THEN -ABS(t.planned_risk_points)*"
      "ABS(h.profit/h.profit_points) ELSE NULL END "
      "AS expected_loss_usd,"
      "CASE WHEN ABS(COALESCE(h.profit_points,0))>0.00000001 "
      "THEN ABS(t.planned_reward_points)*"
      "ABS(h.profit/h.profit_points) ELSE NULL END "
      "AS expected_profit_usd,"
      "CASE WHEN h.exit_reason='TP' AND "
      "ABS(h.profit_points-t.planned_reward_points)>1 "
      "THEN 'TP_DISTANCE_MISMATCH' "
      "WHEN h.exit_reason='SL' AND "
      "ABS(h.profit_points+t.planned_risk_points)>1 "
      "THEN 'SL_DISTANCE_MISMATCH' "
      "WHEN h.exit_reason='TIMEOUT' THEN 'TIMEOUT_EXIT' "
      "WHEN h.exit_reason='TESTER_CLOSE' THEN 'TESTER_CLOSE' "
      "ELSE COALESCE(h.exit_reason,'UNKNOWN') END AS audit_reason "
      "FROM trade_history h LEFT JOIN trade_open t "
      "ON t.experiment_id=h.experiment_id AND t.trade_id=h.trade_id),"
      "context AS ("
      "/* V2 CONTEXT: optional market snapshots remain nullable LEFT JOINs. */ "
      "SELECT h.*,a.expected_sl_points,a.expected_tp_points,"
      "a.symbol_point,a.expected_loss_usd,a.expected_profit_usd,"
      "a.audit_reason,"
      "(h.profit+COALESCE(h.swap,0)+COALESCE(h.commission,0)) "
      "AS actual_profit_usd,s.atr_value,s.spread_points,"
      "p.pressure_direction,p.pressure_level,p.pressure_score,"
      "z.zone_id,z.zone_score,p.ema_value,"
      "(SELECT CAST(pr.value AS INTEGER) FROM parameter pr "
      "WHERE pr.experiment_id=h.experiment_id "
      "AND pr.name='SwingDepth' ORDER BY pr.parameter_id DESC LIMIT 1) "
      "AS swing_depth "
      "FROM trade_history h LEFT JOIN trade_audit a "
      "ON a.experiment_id=h.experiment_id AND a.trade_id=h.trade_id "
      "LEFT JOIN signal s ON s.experiment_id=h.experiment_id "
      "AND s.signal_id=h.signal_id "
      "LEFT JOIN pressure_snapshot p "
      "ON p.pressure_snapshot_id=s.pressure_snapshot_id "
      "LEFT JOIN zone_snapshot z "
      "ON z.zone_snapshot_id=s.zone_snapshot_id),"
      "ratios AS ("
      "/* V1 MONEY ANALYSIS: preserve the original outlier contract. */ "
      "SELECT context.*,CASE WHEN actual_profit_usd>=0 "
      "THEN actual_profit_usd/NULLIF(expected_profit_usd,0) "
      "ELSE ABS(actual_profit_usd)/NULLIF(ABS(expected_loss_usd),0) "
      "END AS profit_ratio FROM context),"
      "classified AS ("
      "SELECT ratios.*,ABS(profit_ratio) AS absolute_ratio,"
      "CASE WHEN actual_profit_usd>=0 "
      "THEN actual_profit_usd-expected_profit_usd "
      "ELSE ABS(actual_profit_usd)-ABS(expected_loss_usd) END "
      "AS deviation_usd FROM ratios),"
      "price_time AS ("
      "/* V2 PRICE/TIME: calculate theoretical prices and elapsed time. */ "
      "SELECT classified.*,"
      "COALESCE(holding_minutes,("
      "julianday(REPLACE(close_time,'.','-'))-"
      "julianday(REPLACE(open_time,'.','-')))*1440.0) "
      "AS holding_minutes_v2,"
      "CASE WHEN UPPER(direction)='BUY' "
      "THEN open_price-expected_sl_points*symbol_point "
      "WHEN UPPER(direction)='SELL' "
      "THEN open_price+expected_sl_points*symbol_point END "
      "AS expected_sl_price,"
      "CASE WHEN UPPER(direction)='BUY' "
      "THEN open_price+expected_tp_points*symbol_point "
      "WHEN UPPER(direction)='SELL' "
      "THEN open_price-expected_tp_points*symbol_point END "
      "AS expected_tp_price,"
      "ABS(close_price-open_price)/NULLIF(symbol_point,0) "
      "AS actual_distance_points,"
      "CASE WHEN actual_profit_usd>=0 THEN expected_tp_points "
      "ELSE expected_sl_points END AS expected_distance_points "
      "FROM classified),"
      "execution_metrics AS ("
      "/* V2 EXECUTION: normalize distance, schedule, and volatility metrics. */ "
      "SELECT price_time.*,"
      "ABS(actual_distance_points-expected_distance_points) "
      "AS distance_error_points,"
      "100.0*ABS(actual_distance_points-expected_distance_points)/"
      "NULLIF(ABS(expected_distance_points),0) "
      "AS distance_error_percent,"
      "holding_minutes_v2/60.0 AS holding_hours,"
      "holding_minutes_v2/1440.0 AS holding_days,"
      "CAST(strftime('%w',REPLACE(open_time,'.','-')) AS INTEGER) "
      "AS open_day_number,"
      "CAST(strftime('%w',REPLACE(close_time,'.','-')) AS INTEGER) "
      "AS close_day_number,"
      "CAST(strftime('%H',REPLACE(open_time,'.','-')) AS INTEGER) "
      "AS open_hour_number,"
      "CAST(strftime('%H',REPLACE(close_time,'.','-')) AS INTEGER) "
      "AS close_hour_number,"
      "ABS(atr_value/NULLIF(symbol_point,0))/"
      "NULLIF(ABS(expected_sl_points),0) AS atr_percent_of_sl,"
      "ABS(spread_points)/NULLIF(ABS(expected_sl_points),0) "
      "AS spread_percent_of_sl "
      "FROM price_time),"
      "quality AS ("
      "/* V2 QUALITY: derive weekend/session and execution classification. */ "
      "SELECT execution_metrics.*,"
      "CASE WHEN (open_day_number=5 AND close_day_number=1) "
      "OR holding_days>=2 THEN 1 ELSE 0 END AS is_weekend_hold,"
      "CASE WHEN open_hour_number>=0 AND open_hour_number<7 "
      "THEN 'Asian' WHEN open_hour_number>=7 AND open_hour_number<13 "
      "THEN 'London' WHEN open_hour_number>=13 AND open_hour_number<21 "
      "THEN 'NewYork' ELSE 'AfterHours' END AS trading_session,"
      "CASE WHEN distance_error_percent<2 THEN 'PERFECT' "
      "WHEN distance_error_percent<5 THEN 'GOOD' "
      "WHEN distance_error_percent<10 THEN 'WARNING' "
      "ELSE 'BAD' END AS execution_quality "
      "FROM execution_metrics),"
      "root_cause AS ("
      "/* V2 ROOT CAUSE: apply the requested precedence without gating trades. */ "
      "SELECT quality.*,CASE WHEN is_weekend_hold=1 THEN 'Weekend Gap' "
      "WHEN spread_percent_of_sl>0.20 THEN 'Large Spread' "
      "WHEN distance_error_percent>10 THEN 'Execution' "
      "WHEN holding_hours>24 THEN 'Long Holding' "
      "WHEN atr_percent_of_sl>0.80 THEN 'Extreme Volatility' "
      "ELSE 'Unknown' END AS root_cause_text FROM quality) "
      "/* V1 OUTPUT: retain every original column in its original order. */ "
      "SELECT trade_id AS TradeID,symbol AS Symbol,"
      "direction AS Direction,REPLACE(open_time,'.','-') AS OpenTime,"
      "REPLACE(close_time,'.','-') AS CloseTime,"
      "CAST(ROUND(holding_minutes_v2) AS INTEGER) "
      "AS HoldingMinutes,bars_held AS HoldingBars,"
      "open_price AS OpenPrice,close_price AS ClosePrice,volume AS Lot,"
      "expected_sl_points AS ExpectedSLPoints,"
      "expected_tp_points AS ExpectedTPPoints,"
      "ROUND(expected_loss_usd,2) AS ExpectedLossUSD,"
      "ROUND(expected_profit_usd,2) AS ExpectedProfitUSD,"
      "ROUND(actual_profit_usd,2) AS ActualProfitUSD,"
      "ROUND(profit_ratio,2) AS ProfitRatio,"
      "ROUND(absolute_ratio,2) AS AbsoluteRatio,"
      "exit_reason AS ExitReason,audit_reason AS AuditReason,"
      "atr_value AS ATR,spread_points AS Spread,"
      "TRIM(COALESCE(pressure_direction,'UNKNOWN')||' '||"
      "COALESCE(pressure_level,'UNKNOWN')||' '||"
      "ROUND(COALESCE(pressure_score,0),1)) AS Pressure,"
      "zone_id AS ZoneID,zone_score AS ZoneScore,"
      "swing_depth AS SwingDepth,ema_value AS MA,"
      "CASE WHEN absolute_ratio>=4 THEN 'CRITICAL' "
      "WHEN absolute_ratio>=2 THEN 'HIGH' "
      "WHEN absolute_ratio>=1.2 THEN 'MEDIUM' "
      "ELSE 'NORMAL' END AS OutlierLevel,"
      "ROUND(deviation_usd,2) AS DeviationUSD,"
      "/* V2 PRICE ANALYSIS. */ "
      "ROUND(expected_sl_price,8) AS ExpectedSLPrice,"
      "ROUND(expected_tp_price,8) AS ExpectedTPPrice,"
      "ROUND(close_price,8) AS ActualExitPrice,"
      "ROUND(ABS(close_price-expected_sl_price),8) "
      "AS SLPriceDifference,"
      "ROUND(ABS(close_price-expected_tp_price),8) "
      "AS TPPriceDifference,"
      "ROUND(expected_distance_points,1) AS ExpectedDistancePoints,"
      "ROUND(actual_distance_points,1) AS ActualDistancePoints,"
      "ROUND(distance_error_points,1) AS DistanceErrorPoints,"
      "ROUND(distance_error_percent,2) AS DistanceErrorPercent,"
      "/* V2 TIME AND SESSION ANALYSIS. */ "
      "CASE open_day_number WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' "
      "WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday' "
      "WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' "
      "WHEN 6 THEN 'Saturday' END AS OpenDayOfWeek,"
      "CASE close_day_number WHEN 0 THEN 'Sunday' WHEN 1 THEN 'Monday' "
      "WHEN 2 THEN 'Tuesday' WHEN 3 THEN 'Wednesday' "
      "WHEN 4 THEN 'Thursday' WHEN 5 THEN 'Friday' "
      "WHEN 6 THEN 'Saturday' END AS CloseDayOfWeek,"
      "open_hour_number AS OpenHour,close_hour_number AS CloseHour,"
      "ROUND(holding_hours,2) AS HoldingHours,"
      "ROUND(holding_days,2) AS HoldingDays,"
      "is_weekend_hold AS IsWeekendHold,"
      "trading_session AS TradingSession,"
      "/* V2 VOLATILITY, QUALITY, AND ROOT CAUSE. */ "
      "ROUND(atr_percent_of_sl,2) AS ATRPercentOfSL,"
      "ROUND(spread_percent_of_sl,2) AS SpreadPercentOfSL,"
      "execution_quality AS ExecutionQuality,"
      "root_cause_text AS RootCause "
      "FROM root_cause WHERE absolute_ratio>=1.20 "
      "ORDER BY absolute_ratio DESC,ABS(actual_profit_usd) DESC";
}

string ResearchDBViewTradeOutlierSummary()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_trade_outlier_summary AS "
      "/* Summarize all closed trades against filtered outlier rows. */ "
      "WITH totals AS (SELECT COUNT(*) AS total_trades "
      "FROM trade_close),outliers AS ("
      "SELECT * FROM vw_trade_outlier_analysis) "
      "SELECT totals.total_trades AS TotalTrades,"
      "COUNT(outliers.TradeID) AS OutlierTrades,"
      "ROUND(100.0*COUNT(outliers.TradeID)/"
      "NULLIF(totals.total_trades,0),2) AS OutlierPercent,"
      "COALESCE(SUM(CASE WHEN outliers.OutlierLevel='CRITICAL' "
      "THEN 1 ELSE 0 END),0) AS CriticalCount,"
      "COALESCE(SUM(CASE WHEN outliers.OutlierLevel='HIGH' "
      "THEN 1 ELSE 0 END),0) AS HighCount,"
      "COALESCE(SUM(CASE WHEN outliers.OutlierLevel='MEDIUM' "
      "THEN 1 ELSE 0 END),0) AS MediumCount,"
      "ROUND(MIN(CASE WHEN outliers.ActualProfitUSD<0 "
      "THEN outliers.ActualProfitUSD END),2) AS LargestLoss,"
      "ROUND(MAX(CASE WHEN outliers.ActualProfitUSD>0 "
      "THEN outliers.ActualProfitUSD END),2) AS LargestProfit,"
      "ROUND(AVG(outliers.HoldingMinutes),2) AS AverageHoldingMinutes,"
      "ROUND(AVG(outliers.HoldingBars),2) AS AverageHoldingBars,"
      "/* V2 ROOT-CAUSE COUNTS. */ "
      "COALESCE(SUM(CASE WHEN outliers.RootCause='Weekend Gap' "
      "THEN 1 ELSE 0 END),0) AS WeekendGapCount,"
      "COALESCE(SUM(CASE WHEN outliers.RootCause='Execution' "
      "THEN 1 ELSE 0 END),0) AS ExecutionIssueCount,"
      "COALESCE(SUM(CASE WHEN outliers.RootCause='Long Holding' "
      "THEN 1 ELSE 0 END),0) AS LongHoldingCount,"
      "COALESCE(SUM(CASE WHEN outliers.RootCause='Large Spread' "
      "THEN 1 ELSE 0 END),0) AS LargeSpreadCount,"
      "COALESCE(SUM(CASE WHEN outliers.RootCause='Extreme Volatility' "
      "THEN 1 ELSE 0 END),0) AS HighATRCount,"
      "/* V2 DISTANCE AND HOLDING AGGREGATES. */ "
      "ROUND(AVG(outliers.DistanceErrorPoints),1) "
      "AS AverageDistanceError,"
      "ROUND(MAX(outliers.DistanceErrorPoints),1) "
      "AS MaximumDistanceError,"
      "ROUND(AVG(outliers.HoldingHours),2) AS AverageHoldingHours,"
      "ROUND(AVG(outliers.HoldingDays),2) AS AverageHoldingDays,"
      "(SELECT o.TradeID FROM outliers o "
      "WHERE o.DistanceErrorPercent IS NOT NULL "
      "ORDER BY o.DistanceErrorPercent DESC,o.TradeID LIMIT 1) "
      "AS WorstExecutionTradeID,"
      "(SELECT o.TradeID FROM outliers o "
      "WHERE o.DistanceErrorPercent IS NOT NULL "
      "ORDER BY o.DistanceErrorPercent ASC,o.TradeID LIMIT 1) "
      "AS BestExecutionTradeID "
      "FROM totals LEFT JOIN outliers ON 1=1";
}

string ResearchDBViewTradeExecutionQuality()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_trade_execution_quality AS "
      "/* V2 EXECUTION QUALITY: ranked forensic projection only. */ "
      "SELECT TradeID,ExecutionQuality,RootCause,DistanceErrorPoints,"
      "DistanceErrorPercent,HoldingHours,HoldingDays,TradingSession,"
      "ROW_NUMBER() OVER (ORDER BY DistanceErrorPercent DESC,"
      "TradeID) AS ExecutionRank "
      "FROM vw_trade_outlier_analysis "
      "ORDER BY DistanceErrorPercent DESC,TradeID";
}

string ResearchDBViewTradeWeekendGap()
{
   return
      "CREATE VIEW IF NOT EXISTS vw_trade_weekend_gap AS "
      "/* V2 WEEKEND GAP: Friday-to-Monday or two-day holding outliers. */ "
      "SELECT TradeID,OpenTime,CloseTime,HoldingDays,"
      "ActualProfitUSD AS ActualProfit,"
      "ExpectedProfitUSD AS ExpectedProfit,DistanceErrorPercent,"
      "ExecutionQuality,RootCause "
      "FROM vw_trade_outlier_analysis WHERE IsWeekendHold=1 "
      "ORDER BY DistanceErrorPercent DESC,TradeID";
}

bool ResearchDBStoreViewDefinition(string name, string description,
                                   string sql)
{
   string insertSQL =
      "INSERT OR IGNORE INTO research_view_definition("
      "view_name,created_at,description,sql_text,is_active) VALUES(" +
      ResearchDBSQLText(name) + "," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(description) + "," +
      ResearchDBSQLText(sql) + ",1)";
   return ResearchDBExecute(insertSQL,
                            "store view definition " + name);
}

void ResearchDBPrepareAnalysisViews()
{
   string names[33] =
   {
      "v_signal_lifecycle",
      "v_pressure_advice_vs_execution",
      "v_pressure_shadow_value",
      "v_trade_performance_summary",
      "v_zone_pressure_performance",
      "v_regime_performance",
      "v_pressure_saved_or_missed",
      "v_pressure_zone_risk_matrix",
      "v_best_practice_candidate",
      "v_pressure_policy_summary",
      "v_trade_attribution_validation",
      "v_pressure_execution_summary",
      "v_pressure_block_statistics",
      "v_experiment_summary",
      "v_pressure_statistics",
      "v_pressure_execution",
      "v_trade_distribution",
      "v_trade_anomaly",
      "v_trade_episode",
      "v_research_validation",
      "v_transition_double_entry_risk",
      "v_transition_double_entry_summary",
      "vw_trade_outlier_analysis",
      "vw_trade_outlier_summary",
      "vw_trade_execution_quality",
      "vw_trade_weekend_gap",
      "vw_adaptive_loss_cluster_metrics",
      "vw_adaptive_episode_summary",
      "vw_adaptive_episode_detail",
      "vw_adaptive_pattern_summary",
      "vw_adaptive_shadow_summary",
      "vw_adaptive_episode_shadow_result",
      "vw_adaptive_pattern_shadow_result"
   };
   string descriptions[33] =
   {
      "Signal context, policy, and realized trade lifecycle",
      "Pressure advice compared with actual execution",
      "Grouped value of pressure shadow decisions",
      "Closed-trade performance by experiment",
      "Zone and pressure grouped performance",
      "Regime and candidate-direction grouped performance",
      "Pressure shadow warnings classified as saved loss or missed win",
      "Zone and pressure risk matrix with profit factor",
      "Observed combinations converted into simple rule candidates",
      "Pressure policy effectiveness grouped by impact and direction",
      "Deterministic signal-to-trade attribution validation",
      "Pressure execution permission outcomes by experiment",
      "Blocked direction and saved-or-missed outcome statistics",
      "Cross-experiment engine, pressure, and performance comparison",
      "Pressure level and direction distribution with percentages",
      "Signal, block, watch, allow, and execution rates",
      "Trade result, exit reason, and profit distribution",
      "Expected versus realized TP and SL anomaly detection",
      "Future trade episode analysis infrastructure",
      "One-row research database integrity summary",
      "Repeated same-direction loss risk near regime, pressure, or structure transitions",
      "Grouped performance and estimated block candidates for transition double-entry risk",
      "V2 abnormal profit, price distance, time, volatility, execution quality, and root cause",
      "V2 counts, causes, distance errors, holding averages, and execution extremes",
      "Ranked V2 execution quality for trade outliers",
      "V2 weekend and multi-day holding gap outliers",
      "Adaptive V1 evaluation, candidate, opportunity, execution, and lifecycle metrics",
      "Adaptive episode totals, states, opportunity counts, and leading patterns",
      "Adaptive episode lifecycle timing and blocked-opportunity rate",
      "Adaptive Direction and Zone episode performance summary",
      "Research-only Adaptive shadow trade outcome totals",
      "Adaptive episode usefulness from linked shadow outcomes",
      "Direction and Zone Adaptive benefit from shadow outcomes"
   };
   string sql[33];
   sql[0] = ResearchDBViewSignalLifecycle();
   sql[1] = ResearchDBViewPressureAdviceExecution();
   sql[2] = ResearchDBViewPressureShadowValue();
   sql[3] = ResearchDBViewTradePerformance();
   sql[4] = ResearchDBViewZonePressurePerformance();
   sql[5] = ResearchDBViewRegimePerformance();
   sql[6] = ResearchDBViewPressureSavedOrMissed();
   sql[7] = ResearchDBViewPressureZoneRiskMatrix();
   sql[8] = ResearchDBViewBestPracticeCandidate();
   sql[9] = ResearchDBViewPressurePolicySummary();
   sql[10] = ResearchDBViewTradeAttributionValidation();
   sql[11] = ResearchDBViewPressureExecutionSummary();
   sql[12] = ResearchDBViewPressureBlockStatistics();
   sql[13] = ResearchDBViewExperimentSummary();
   sql[14] = ResearchDBViewPressureStatistics();
   sql[15] = ResearchDBViewPressureExecution();
   sql[16] = ResearchDBViewTradeDistribution();
   sql[17] = ResearchDBViewTradeAnomaly();
   sql[18] = ResearchDBViewTradeEpisode();
   sql[19] = ResearchDBViewResearchValidation();
   sql[20] = ResearchDBViewTransitionDoubleEntryRisk();
   sql[21] = ResearchDBViewTransitionDoubleEntrySummary();
   sql[22] = ResearchDBViewTradeOutlierAnalysis();
   sql[23] = ResearchDBViewTradeOutlierSummary();
   sql[24] = ResearchDBViewTradeExecutionQuality();
   sql[25] = ResearchDBViewTradeWeekendGap();
   sql[26] = ResearchDBViewAdaptiveLossClusterMetrics();
   sql[27] = ResearchDBViewAdaptiveEpisodeSummary();
   sql[28] = ResearchDBViewAdaptiveEpisodeDetail();
   sql[29] = ResearchDBViewAdaptivePatternSummary();
   sql[30] = ResearchDBViewAdaptiveShadowSummary();
   sql[31] = ResearchDBViewAdaptiveEpisodeShadowResult();
   sql[32] = ResearchDBViewAdaptivePatternShadowResult();

   ResearchDBActualViewCreateStatusText = "CREATED";
   ResearchDBLastViewCreateErrorText = "N/A";
   for(int i = 0; i < 33; i++)
   {
      if(!ResearchDBStoreViewDefinition(
            names[i], descriptions[i], sql[i]))
         continue;

      // Adaptive analytics evolved during Alpha 1.0 research. Recreate only
      // these views so existing databases cannot retain misleading wording.
      if(i >= 26)
      {
         DatabaseExecute(
            TREResearchDBHandle,
            "DROP VIEW IF EXISTS " + names[i]);
      }

      ResetLastError();
      if(!DatabaseExecute(TREResearchDBHandle, sql[i]))
      {
         int errorCode = GetLastError();
         ResearchDBActualViewCreateStatusText = "PARTIAL";
         ResearchDBLastViewCreateErrorText =
            names[i] + " error " + IntegerToString(errorCode);
         Print("TRE Research DB View: ",
               ResearchDBLastViewCreateErrorText);
         ResetLastError();
      }
   }
   ResearchDBViewDefinitionCount =
      ResearchDBCountRows("research_view_definition");
}

double ResearchDBAverageDailyRange(string symbol, int bars)
{
   double total = 0;
   int count = 0;
   for(int shift = 1; shift <= bars; shift++)
   {
      double high = iHigh(symbol, PERIOD_D1, shift);
      double low = iLow(symbol, PERIOD_D1, shift);
      if(high > low && low > 0)
      {
         total += high - low;
         count++;
      }
   }
   return (count > 0) ? total / count : 0;
}

string ResearchDBScoreConfidence(int score)
{
   if(score >= 80) return "High";
   if(score >= 60) return "Medium";
   if(score >= 40) return "Low";
   return "Very Low";
}

string ResearchDBRecordedDecisionAfterPressure()
{
   return PressureExecutionBlockApplied
          ? "BLOCKED_BY_PRESSURE"
          : DecisionAfterPressure;
}

string ResearchDBRecordedFinalDecision()
{
   return PressureExecutionBlockApplied
          ? "BLOCKED_BY_PRESSURE"
          : ActionToText(ActionState);
}

long ResearchDBInsertSignalBase(string symbol, datetime barTime,
                                string signalKind)
{
   MqlTick tick;
   ZeroMemory(tick);
   SymbolInfoTick(symbol, tick);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = (point > 0) ? (tick.ask - tick.bid) / point : 0;
   double barOpen = iOpen(symbol, EntryTF, 1);
   double barHigh = iHigh(symbol, EntryTF, 1);
   double barLow = iLow(symbol, EntryTF, 1);
   double lastClose = iClose(symbol, EntryTF, 1);
   long tickVolume = iVolume(symbol, EntryTF, 1);
   double candleBody = MathAbs(lastClose - barOpen);
   double upperShadow = barHigh - MathMax(barOpen, lastClose);
   double lowerShadow = MathMin(barOpen, lastClose) - barLow;
   bool ready = (ActionState == ACTION_BUY_READY ||
                 ActionState == ACTION_SELL_READY);
   bool blocked =
      (PressureDecisionImpact == PRESSURE_IMPACT_HARD_BLOCKED ||
       PressureExecutionBlockApplied);
   bool downgraded =
      (PressureDecisionImpact == PRESSURE_IMPACT_DOWNGRADED_TO_WATCH);

   string sql =
      "INSERT INTO signal("
      "experiment_id,signal_time,bar_time,symbol,timeframe,bid,ask,"
      "last_close,spread_points,candidate_direction_before_pressure,"
      "decision_before_pressure,decision_after_pressure,final_decision,"
      "entry_reason,missing_condition,score_before_pressure,"
      "pressure_penalty_applied,score_after_pressure,final_signal_score,"
      "trend_score,zone_score,structure_score,momentum_score,"
      "pressure_score,risk_score,is_ready_signal,is_trade_opened,"
      "trade_id,blocked_by_pressure,downgraded_by_pressure,"
      "zone_snapshot_id,structure_snapshot_id,regime_snapshot_id,"
      "pressure_snapshot_id,decision_snapshot_id,server_time,"
      "zone_tf,bias_tf,entry_tf,execution_tf,pressure_tf,regime_tf,"
      "open_price,high_price,low_price,close_price,current_price,"
      "atr_value,adr_value,tick_volume,candle_body,upper_shadow,"
      "lower_shadow,signal_bar,candidate_direction,signal_kind,"
      "snapshot_version) VALUES(" +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(ResearchDBTimeText(barTime)) + "," +
      ResearchDBSQLText(symbol) + "," +
      ResearchDBSQLText(TimeframeToText(_Period)) + "," +
      ResearchDBSQLDouble(tick.bid) + "," +
      ResearchDBSQLDouble(tick.ask) + "," +
      ResearchDBSQLDouble(lastClose) + "," +
      ResearchDBSQLDouble(spread) + "," +
      ResearchDBSQLText(CandidateDirectionBeforePressure) + "," +
      ResearchDBSQLText(DecisionBeforePressure) + "," +
      ResearchDBSQLText(ResearchDBRecordedDecisionAfterPressure()) + "," +
      ResearchDBSQLText(ResearchDBRecordedFinalDecision()) + "," +
      ResearchDBSQLText(EntryReason) + "," +
      ResearchDBSQLText(MissingConditionText) + "," +
      ResearchDBSQLDouble(ScoreBeforePressure) + "," +
      ResearchDBSQLDouble(PressurePenaltyApplied) + "," +
      ResearchDBSQLDouble(ScoreAfterPressure) + "," +
      ResearchDBSQLDouble(TotalScore) + "," +
      ResearchDBSQLDouble(TrendScore) + "," +
      ResearchDBSQLDouble(ZoneScore) + "," +
      ResearchDBSQLDouble(StructureScore) + "," +
      ResearchDBSQLDouble(MomentumScore) + "," +
      ResearchDBSQLDouble(PressureScore) + ",0," +
      ResearchDBSQLInteger(ResearchDBBool(ready)) + ",0,0," +
      ResearchDBSQLInteger(ResearchDBBool(blocked)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(downgraded)) +
      ",NULL,NULL,NULL,NULL,NULL," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(TimeframeToText(ZoneTF)) + "," +
      ResearchDBSQLText(TimeframeToText(BiasTF)) + "," +
      ResearchDBSQLText(TimeframeToText(EntryTF)) + "," +
      ResearchDBSQLText(TimeframeToText(ExecutionTF)) + "," +
      ResearchDBSQLText(TimeframeToText(EffectivePressureTF)) + "," +
      ResearchDBSQLText(TimeframeToText(RegimeTF)) + "," +
      ResearchDBSQLDouble(barOpen) + "," +
      ResearchDBSQLDouble(barHigh) + "," +
      ResearchDBSQLDouble(barLow) + "," +
      ResearchDBSQLDouble(lastClose) + "," +
      ResearchDBSQLDouble(tick.bid) + "," +
      ResearchDBSQLDouble(ZoneATRValue) + "," +
      ResearchDBSQLDouble(ResearchDBAverageDailyRange(symbol, 14)) + "," +
      ResearchDBSQLInteger(tickVolume) + "," +
      ResearchDBSQLDouble(candleBody) + "," +
      ResearchDBSQLDouble(MathMax(0.0, upperShadow)) + "," +
      ResearchDBSQLDouble(MathMax(0.0, lowerShadow)) + "," +
      ResearchDBSQLText(ResearchDBTimeText(barTime)) + "," +
      ResearchDBSQLText(CandidateDirectionBeforePressure) + "," +
      ResearchDBSQLText(signalKind) + "," +
      ResearchDBSQLInteger(ResearchDBSchemaVersion) + ")";
   return ResearchDBInsert(sql, "insert signal");
}

long ResearchDBInsertZoneSnapshot(string symbol, long signalId)
{
   if(!ResearchDBWriteZoneSnapshot)
      return 0;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double low = 0;
   double high = 0;
   if(CurrentZone >= 1 && CurrentZone <= TRE_ZONE_COUNT && ZoneSize > 0)
   {
      low = RangeLow + ((CurrentZone - 1) * ZoneSize);
      high = low + ZoneSize;
   }
   double mid = (high > low) ? (high + low) / 2.0 : 0;
   double widthPoints = (point > 0) ? (high - low) / point : 0;
   double distancePoints = (point > 0 && mid > 0)
                           ? (price - mid) / point : 0;
   double swingRangePoints =
      ResearchDBTextDouble(ZoneSwingRangePointsText);

   string sql =
      "INSERT INTO zone_snapshot VALUES(NULL," +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLText(TimeframeToText(ZoneTF)) + "," +
      ResearchDBSQLInteger(CurrentZone) + "," +
      ResearchDBSQLText(ZoneNameText) + "," +
      ResearchDBSQLText(ZoneStrengthText) + "," +
      ResearchDBSQLDouble(ZoneScore) + "," +
      ResearchDBSQLText(ZoneReason) + "," +
      ResearchDBSQLText(ZoneValidationReasonText) + "," +
      ResearchDBSQLDouble(price) + "," +
      ResearchDBSQLDouble(high) + "," +
      ResearchDBSQLDouble(low) + "," +
      ResearchDBSQLDouble(mid) + "," +
      ResearchDBSQLDouble(widthPoints) + "," +
      ResearchDBSQLDouble(distancePoints) + "," +
      ResearchDBSQLText(ZoneSourceText) + "," +
      ResearchDBSQLDouble(LastSwingHigh) + "," +
      ResearchDBSQLDouble(LastSwingLow) + "," +
      ResearchDBSQLDouble(swingRangePoints) + "," +
      ResearchDBSQLInteger(ResearchDBTextBool(ZoneFallbackUsedText)) + "," +
      ResearchDBSQLText(ZoneFallbackReasonText) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UseSwingValidation)) + "," +
      ResearchDBSQLDouble(MinimumSwingRangePoints) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UseATRValidation)) + "," +
      ResearchDBSQLDouble(ZoneATRValue) + "," +
      ResearchDBSQLDouble(ZoneATRPoints) + "," +
      ResearchDBSQLDouble(ZoneMinATRRangePoints) + "," +
      ResearchDBSQLDouble(ZoneMaxATRRangePoints) + "," +
      ResearchDBSQLText(ZoneATRValidationText) + "," +
      ResearchDBSQLText(ZoneQualityText) + "," +
      ResearchDBSQLDouble(high) + "," +
      ResearchDBSQLDouble(low) + "," +
      ResearchDBSQLDouble(high - low) + "," +
      ResearchDBSQLDouble((point > 0 && mid > 0)
                          ? MathAbs(price - mid) / point : 0) + "," +
      "NULL,NULL,NULL,NULL," +
      ResearchDBSQLText(ZoneSwingValidationText) + ")";
   return ResearchDBInsert(sql, "insert zone snapshot");
}

long ResearchDBInsertStructureSnapshot(long signalId)
{
   if(!ResearchDBWriteStructureSnapshot)
      return 0;
   string sql =
      "INSERT INTO structure_snapshot VALUES(NULL," +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLText(TimeframeToText(EntryTF)) + "," +
      ResearchDBSQLText(StructureConfirmedText) + "," +
      ResearchDBSQLText(StructureStageText) + "," +
      ResearchDBSQLText(StructureValidationStageText) + "," +
      ResearchDBSQLText(StructureDevelopmentStateText) + "," +
      ResearchDBSQLText(StructureEarlyWarningText) + "," +
      ResearchDBSQLText(StructureEarlyWarningReasonText) + "," +
      ResearchDBSQLDouble(StructureScore) + "," +
      ResearchDBSQLText(StructureConfidenceText) + "," +
      ResearchDBSQLText(StructureReason) + "," +
      ResearchDBSQLText(StructureMissingEvidenceText) + "," +
      ResearchDBSQLDouble(StructureLastSwingHigh) + "," +
      ResearchDBSQLDouble(StructurePrevSwingHigh) + "," +
      ResearchDBSQLDouble(StructureLastSwingLow) + "," +
      ResearchDBSQLDouble(StructurePrevSwingLow) + "," +
      ResearchDBSQLInteger(StructureSwingHighCount) + "," +
      ResearchDBSQLInteger(StructureSwingLowCount) + "," +
      ResearchDBSQLInteger(StructureSwingPairCount) + "," +
      ResearchDBSQLInteger(StructureHHCount) + "," +
      ResearchDBSQLInteger(StructureHLCount) + "," +
      ResearchDBSQLInteger(StructureLHCount) + "," +
      ResearchDBSQLInteger(StructureLLCount) + "," +
      ResearchDBSQLText(StructureBOSStateText) + "," +
      ResearchDBSQLText(StructureCHOCHStateText) + "," +
      ResearchDBSQLText(StructureStrongDirectionalMoveText) + "," +
      ResearchDBSQLInteger(StructureRecentBearishCloseCount) + "," +
      ResearchDBSQLInteger(StructureRecentBullishCloseCount) + "," +
      ResearchDBSQLInteger(StructureConsecutiveBearishBars) + "," +
      ResearchDBSQLInteger(StructureConsecutiveBullishBars) + "," +
      ResearchDBSQLInteger(StructureRecentLowerLowCount) + "," +
      ResearchDBSQLInteger(StructureRecentHigherHighCount) + "," +
      ResearchDBSQLInteger(StructureRecentLowerCloseCount) + "," +
      ResearchDBSQLInteger(StructureRecentHigherCloseCount) + "," +
      ResearchDBSQLInteger(ResearchDBTextBool(
         StructurePriceAboveEMAText)) + "," +
      ResearchDBSQLInteger(ResearchDBTextBool(
         StructurePriceBelowEMAText)) + "," +
      ResearchDBSQLText(StructureEMASlopeDirectionText) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(
         StructureDistanceFromEMAPointsText)) + "," +
      ResearchDBSQLText(PendingSwingHighStatusText) + "," +
      ResearchDBSQLDouble(PendingSwingHighPrice) + "," +
      ResearchDBSQLInteger(PendingSwingHighRightBarsWaited) + "," +
      ResearchDBSQLInteger(PendingSwingHighRightBarsRequired) + "," +
      ResearchDBSQLText(PendingSwingLowStatusText) + "," +
      ResearchDBSQLDouble(PendingSwingLowPrice) + "," +
      ResearchDBSQLInteger(PendingSwingLowRightBarsWaited) + "," +
      ResearchDBSQLInteger(PendingSwingLowRightBarsRequired) + "," +
      ResearchDBSQLText(StructureSwingMappingStatusText) + "," +
      ResearchDBSQLText(StructureSwingMappingReasonText) + ")";
   return ResearchDBInsert(sql, "insert structure snapshot");
}

long ResearchDBInsertRegimeSnapshot(long signalId)
{
   if(!ResearchDBWriteRegimeSnapshot)
      return 0;
   string reason = RegimeUptrendReasonText + " | " +
                   RegimeSidewayReasonText + " | " +
                   RegimeDowntrendReasonText;
   string sql =
      "INSERT INTO regime_snapshot VALUES(NULL," +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UseAutoRegimeDetection)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(AllowAutoProfileSwitch)) + "," +
      ResearchDBSQLText(ManualMarketProfileText) + "," +
      ResearchDBSQLText(DetectedRegimeText) + "," +
      ResearchDBSQLText(RegimeBestCandidateText) + "," +
      ResearchDBSQLText(ActiveRegimeText) + "," +
      ResearchDBSQLDouble(RegimeConfidence) + "," +
      ResearchDBSQLDouble(UptrendScore) + "," +
      ResearchDBSQLDouble(SidewayScore) + "," +
      ResearchDBSQLDouble(DowntrendScore) + "," +
      ResearchDBSQLDouble(RegimeScoreGap) + "," +
      ResearchDBSQLText(RegimeSwitchStatusText) + "," +
      ResearchDBSQLText(RegimeBlockingReasonText) + "," +
      ResearchDBSQLText(MarketDetectionStatusText) + "," +
      ResearchDBSQLText(AutoProfileSwitchStatusText) + "," +
      ResearchDBSQLText(RegimeProfileSourceText) + "," +
      ResearchDBSQLText(reason) + "," +
      ResearchDBSQLText(RegimeSwitchDecisionReasonText) + "," +
      ResearchDBSQLText(TrendStrengthText) + ",NULL," +
      ResearchDBSQLDouble(ResearchDBTextDouble(
         RegimeEMASlopePointsText)) + ")";
   return ResearchDBInsert(sql, "insert regime snapshot");
}

long ResearchDBInsertPressureSnapshot(long signalId)
{
   if(!ResearchDBWritePressureSnapshot)
      return 0;
   string sql =
      "INSERT INTO pressure_snapshot VALUES(NULL," +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UsePressureGuard)) + "," +
      ResearchDBSQLText(PressureGuardModeToText(PressureGuardMode)) + "," +
      ResearchDBSQLText(PressureEffectiveTFText) + "," +
      ResearchDBSQLInteger(EffectivePressureLookbackBars) + "," +
      ResearchDBSQLText(PressureDirectionText) + "," +
      ResearchDBSQLText(PressureLevelText) + "," +
      ResearchDBSQLDouble(PressureScore) + "," +
      ResearchDBSQLDouble(BullishPressureScore) + "," +
      ResearchDBSQLDouble(BearishPressureScore) + "," +
      ResearchDBSQLText(PressureActionText) + "," +
      ResearchDBSQLText(PressureBlockedDirectionText) + "," +
      ResearchDBSQLText(PressureReasonText) + "," +
      ResearchDBSQLInteger(ResearchDBTextBool(
         PressureAppliesToCandidateText)) + "," +
      ResearchDBSQLText(PressureDecisionImpactText) + "," +
      ResearchDBSQLText(CandidateDirectionBeforePressure) + "," +
      ResearchDBSQLText(DecisionBeforePressure) + "," +
      ResearchDBSQLDouble(ScoreBeforePressure) + "," +
      ResearchDBSQLDouble(PressurePenaltyApplied) + "," +
      ResearchDBSQLDouble(ScoreAfterPressure) + "," +
      ResearchDBSQLText(DecisionAfterPressure) + "," +
      ResearchDBSQLInteger(PressureConsecutiveBullishBars) + "," +
      ResearchDBSQLInteger(PressureConsecutiveBearishBars) + "," +
      ResearchDBSQLInteger(PressureRecentHigherCloseCount) + "," +
      ResearchDBSQLInteger(PressureRecentLowerCloseCount) + "," +
      ResearchDBSQLInteger(PressureRecentHigherHighCount) + "," +
      ResearchDBSQLInteger(PressureRecentLowerLowCount) + "," +
      ResearchDBSQLInteger(ResearchDBTextBool(
         PressurePriceAboveEMAText)) + "," +
      ResearchDBSQLInteger(ResearchDBTextBool(
         PressurePriceBelowEMAText)) + "," +
      ResearchDBSQLText(PressureEMASlopeDirectionText) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(
         PressureDistanceFromEMAPointsText)) + "," +
      ResearchDBSQLText(StructureDevelopmentStateText) + "," +
      ResearchDBSQLText(PressureMomentumDirectionText) + "," +
      ResearchDBSQLText(StructureStrongDirectionalMoveText) + "," +
      ResearchDBSQLInteger(PressureBarsCopied) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(PressureEMAValueText)) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(
         PressureEMAPreviousValueText)) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(
         PressureEMASlopePointsText)) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(PressureLastCloseText)) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(PressureLastHighText)) + "," +
      ResearchDBSQLDouble(ResearchDBTextDouble(PressureLastLowText)) + "," +
      ResearchDBSQLInteger(PressureBullishEvidenceCount) + "," +
      ResearchDBSQLInteger(PressureBearishEvidenceCount) + "," +
      ResearchDBSQLText(PressureCalculationStatusText) + "," +
      ResearchDBSQLText(MissingPressureDataReasonText) + "," +
      ResearchDBSQLDouble(BullishPressureScore / 100.0) + "," +
      ResearchDBSQLDouble(BearishPressureScore / 100.0) +
      ",NULL,NULL,NULL,NULL)";
   return ResearchDBInsert(sql, "insert pressure snapshot");
}

long ResearchDBInsertDecisionSnapshot(long signalId)
{
   if(!ResearchDBWriteDecisionSnapshot)
      return 0;
   string sql =
      "INSERT INTO decision_snapshot VALUES(NULL," +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLText(CandidateDirectionBeforePressure) + "," +
      ResearchDBSQLText(DecisionBeforePressure) + "," +
      ResearchDBSQLText(ResearchDBRecordedDecisionAfterPressure()) + "," +
      ResearchDBSQLText(ResearchDBRecordedFinalDecision()) + "," +
      ResearchDBSQLText(TrendEngineStatusText) + "," +
      ResearchDBSQLText(ZoneEngineStatusText) + "," +
      ResearchDBSQLText(StructureEngineStatusText) + "," +
      ResearchDBSQLText(MomentumEngineStatusText) + "," +
      ResearchDBSQLText(PressureGuardStatusText) + "," +
      ResearchDBSQLText(RiskLevelText) + "," +
      ResearchDBSQLDouble(TrendScore) + "," +
      ResearchDBSQLDouble(ZoneScore) + "," +
      ResearchDBSQLDouble(StructureScore) + "," +
      ResearchDBSQLDouble(MomentumScore) + "," +
      ResearchDBSQLDouble(PressureScore) + ",0," +
      ResearchDBSQLDouble(EngineScores[0].weightedScore) + "," +
      ResearchDBSQLDouble(EngineScores[1].weightedScore) + "," +
      ResearchDBSQLDouble(EngineScores[2].weightedScore) + "," +
      ResearchDBSQLDouble(EngineScores[3].weightedScore) + ",0,0," +
      ResearchDBSQLDouble(ScoreBeforePressure) + "," +
      ResearchDBSQLDouble(PressurePenaltyApplied) + "," +
      ResearchDBSQLDouble(ScoreAfterPressure) + "," +
      ResearchDBSQLText(EntryReason) + "," +
      ResearchDBSQLText(MissingConditionText) + "," +
      ResearchDBSQLText(DirectionalFilterBlockingFactorText) + "," +
      ResearchDBSQLDouble(ScoreBeforePressure) + "," +
      ResearchDBSQLText(ResearchDBScoreConfidence(
         ScoreBeforePressure)) + "," +
      ResearchDBSQLText(ResearchDecisionModeText) + ")";
   return ResearchDBInsert(sql, "insert decision snapshot");
}

bool ResearchDBDecisionAllowsTrade(string decision)
{
   return (decision == "BUY READY" || decision == "SELL READY");
}

bool ResearchDBPressureIsGoverning()
{
   return ResearchDBPressurePolicyIsGoverning ||
          (UsePressureExecutionBlock &&
           PressureExecutionBlockMode != PRESSURE_EXECUTION_SHADOW);
}

string ResearchDBActualPolicyName()
{
   if(!ResearchDBPressurePolicyIsGoverning)
   {
      if(UsePressureExecutionBlock &&
         PressureExecutionBlockMode != PRESSURE_EXECUTION_SHADOW)
         return "PRESSURE_HARD_POLICY";
      return "BASE_ENTRY_POLICY";
   }
   if(PressureGuardMode == PRESSURE_GUARD_HARD_BLOCK)
      return "PRESSURE_HARD_POLICY";
   if(PressureGuardMode == PRESSURE_GUARD_SOFT_BLOCK)
      return "PRESSURE_SOFT_POLICY";
   return "BASE_ENTRY_POLICY";
}

long ResearchDBInsertPolicySnapshot(long signalId)
{
   bool actualAllows =
      (ActionState == ACTION_BUY_READY ||
       ActionState == ACTION_SELL_READY);
   bool adviceAllows =
      ResearchDBDecisionAllowsTrade(DecisionAfterPressure);
   bool governing = ResearchDBPressureIsGoverning();
   string mismatch = "NONE";
   string interpretation =
      "Actual and advisory policy do not currently conflict.";

   if(PressureExecutionBlockApplied)
   {
      mismatch = "GOVERNING_POLICY_BLOCKED";
      interpretation =
         "Directional pressure execution policy blocked the ready candidate.";
   }
   else if(governing && !adviceAllows && actualAllows)
   {
      mismatch = "GOVERNING_POLICY_MISMATCH";
      interpretation =
         "Pressure policy denied the candidate but execution permission remained ready.";
   }
   else if(governing && !adviceAllows && !actualAllows)
   {
      interpretation =
         "Pressure advice and actual execution permission both prevented a trade.";
   }
   else if(!governing && adviceAllows && !actualAllows)
   {
      mismatch = "ADVISORY_ALLOW_BUT_NO_TRADE";
      interpretation =
         "Pressure allowed the candidate but the actual entry policy did not allow a trade.";
   }
   else if(!governing && !adviceAllows && actualAllows)
   {
      interpretation =
         "Pressure advice differs from the trade-eligible base entry policy; trade outcome is pending.";
   }

   string sql =
      "INSERT INTO policy_snapshot("
      "experiment_id,signal_id,actual_policy_name,"
      "actual_policy_decision,actual_policy_allows_trade,"
      "pressure_advice_decision,pressure_advice_action,"
      "pressure_advice_allows_trade,pressure_policy_mode,"
      "pressure_policy_is_governing,final_execution_decision,"
      "trade_opened,policy_mismatch_type,policy_interpretation,"
      "pressure_execution_block_enabled,pressure_execution_block_mode,"
      "pressure_execution_block_mode_id,"
      "pressure_execution_block_mode_name,"
      "pressure_execution_block_applied,pressure_execution_block_reason,"
      "blocked_candidate_direction,blocked_pressure_direction,"
      "blocked_pressure_level,blocked_pressure_score,"
      "actual_execution_decision,pressure_guard_enabled,"
      "pressure_guard_mode,profile,regime,zone,structure,momentum,"
      "ema_state) VALUES(" +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLText(ResearchDBActualPolicyName()) + "," +
      ResearchDBSQLText(ActionToText(ActionState)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(actualAllows)) + "," +
      ResearchDBSQLText(DecisionAfterPressure) + "," +
      ResearchDBSQLText(PressureActionText) + "," +
      ResearchDBSQLInteger(ResearchDBBool(adviceAllows)) + "," +
      ResearchDBSQLText(PressureGuardModeToText(PressureGuardMode)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(governing)) + "," +
      ResearchDBSQLText(ResearchDBRecordedFinalDecision()) + ",0," +
      ResearchDBSQLText(mismatch) + "," +
      ResearchDBSQLText(interpretation) + "," +
      ResearchDBSQLInteger(ResearchDBBool(
         UsePressureExecutionBlock)) + "," +
      ResearchDBSQLText(PressureExecutionBlockModeText) + "," +
      ResearchDBSQLInteger((int)PressureExecutionBlockMode) + "," +
      ResearchDBSQLText(PressureExecutionBlockModeToText(
         PressureExecutionBlockMode)) + "," +
      ResearchDBSQLInteger(ResearchDBBool(
         PressureExecutionBlockApplied)) + "," +
      ResearchDBSQLText(PressureExecutionBlockReasonText) + "," +
      ResearchDBSQLText(PressureExecutionBlockApplied
                        ? PressureExecutionBlockCandidateText : "NONE") + "," +
      ResearchDBSQLText(PressureExecutionBlockApplied
                        ? PressureDirectionText : "NONE") + "," +
      ResearchDBSQLText(PressureExecutionBlockApplied
                        ? PressureLevelText : "NONE") + "," +
      ResearchDBSQLDouble(PressureExecutionBlockApplied
                          ? PressureScore : 0) + "," +
      ResearchDBSQLText(ResearchDBRecordedFinalDecision()) + "," +
      ResearchDBSQLInteger(ResearchDBBool(UsePressureGuard)) + "," +
      ResearchDBSQLText(PressureGuardModeToText(
         PressureGuardMode)) + "," +
      ResearchDBSQLText(ManualMarketProfileText) + "," +
      ResearchDBSQLText(ActiveRegimeText) + "," +
      ResearchDBSQLInteger(CurrentZone) + "," +
      ResearchDBSQLText(StructureConfirmedText) + "," +
      ResearchDBSQLText(MomentumCandleText + " " +
                        MomentumStrengthText) + "," +
      ResearchDBSQLText(PressureEMASlopeDirectionText) + ")";
   return ResearchDBInsert(sql, "insert policy snapshot");
}

bool ResearchDBLinkSnapshots(long signalId, long zoneId,
                             long structureId, long regimeId,
                             long pressureId, long decisionId)
{
   string sql =
      "UPDATE signal SET zone_snapshot_id=" +
      ResearchDBSQLID(zoneId) + ",structure_snapshot_id=" +
      ResearchDBSQLID(structureId) + ",regime_snapshot_id=" +
      ResearchDBSQLID(regimeId) + ",pressure_snapshot_id=" +
      ResearchDBSQLID(pressureId) + ",decision_snapshot_id=" +
      ResearchDBSQLID(decisionId) + " WHERE signal_id=" +
      ResearchDBSQLInteger(signalId);
   return ResearchDBExecute(sql, "link signal snapshots");
}

void ResearchDBInsertFeatureSnapshot(long signalId,
                                     string featureGroup,
                                     string featureName,
                                     string valueText,
                                     double valueReal)
{
   string sql =
      "INSERT INTO feature_snapshot("
      "experiment_id,signal_id,feature_group,feature_name,value_text,"
      "value_real,created_at) VALUES(" +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLInteger(signalId) + "," +
      ResearchDBSQLText(featureGroup) + "," +
      ResearchDBSQLText(featureName) + "," +
      ResearchDBSQLText(valueText) + "," +
      ResearchDBSQLDouble(valueReal) + "," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + ")";
   ResearchDBExecute(sql, "insert feature snapshot");
}

long ResearchDBRecordSignal(string symbol, bool forceSnapshot,
                            string signalKind)
{
   if(!ResearchDBCanWrite() ||
      (!ResearchDBWriteSignals && !forceSnapshot))
      return 0;

   datetime barTime = iTime(symbol, _Period, 0);
   if(barTime <= 0 ||
      (!forceSnapshot && barTime == TREResearchDBLastSignalBar))
      return 0;

   bool transaction = DatabaseTransactionBegin(TREResearchDBHandle);
   if(!transaction)
   {
      ResearchDBFail("begin signal transaction");
      return 0;
   }

   long signalId =
      ResearchDBInsertSignalBase(symbol, barTime, signalKind);
   long zoneId = 0;
   long structureId = 0;
   long regimeId = 0;
   long pressureId = 0;
   long decisionId = 0;
   long policyId = 0;

   bool snapshotsWritten = (signalId > 0);
   if(signalId > 0)
   {
      zoneId = ResearchDBInsertZoneSnapshot(symbol, signalId);
      structureId = ResearchDBInsertStructureSnapshot(signalId);
      regimeId = ResearchDBInsertRegimeSnapshot(signalId);
      pressureId = ResearchDBInsertPressureSnapshot(signalId);
      decisionId = ResearchDBInsertDecisionSnapshot(signalId);
      policyId = ResearchDBInsertPolicySnapshot(signalId);
      ResearchDBInsertFeatureSnapshot(
         signalId, "BIAS", "trend_direction",
         TrendDirectionText, TrendScore);
      ResearchDBInsertFeatureSnapshot(
         signalId, "EMA", "pressure_ema_state",
         PressureEMASlopeDirectionText,
         ResearchDBTextDouble(PressureEMASlopePointsText));
      ResearchDBInsertFeatureSnapshot(
         signalId, "ATR", "zone_atr",
         ZoneATRValidationText, ZoneATRValue);
      ResearchDBInsertFeatureSnapshot(
         signalId, "MOMENTUM", "candle_state",
         MomentumCandleText + " " + MomentumStrengthText,
         MomentumScore);
      snapshotsWritten =
         (!ResearchDBWriteZoneSnapshot || zoneId > 0) &&
         (!ResearchDBWriteStructureSnapshot || structureId > 0) &&
         (!ResearchDBWriteRegimeSnapshot || regimeId > 0) &&
         (!ResearchDBWritePressureSnapshot || pressureId > 0) &&
         (!ResearchDBWriteDecisionSnapshot || decisionId > 0) &&
         (policyId > 0);
   }

   bool linked =
      (snapshotsWritten &&
       ResearchDBLinkSnapshots(signalId, zoneId, structureId,
                               regimeId, pressureId, decisionId));
   if(!linked)
   {
      DatabaseTransactionRollback(TREResearchDBHandle);
      return 0;
   }
   if(!DatabaseTransactionCommit(TREResearchDBHandle))
   {
      DatabaseTransactionRollback(TREResearchDBHandle);
      ResearchDBFail("commit signal transaction");
      return 0;
   }

   TREResearchDBLastSignalBar = barTime;
   ResearchDBLastSignalID = signalId;
   ResearchDBTotalSignalsWritten++;
   ResearchDBPolicySnapshotCount++;
   ResearchDBLastWriteTimeText = ResearchDBTimeText(TimeCurrent());
   ResearchDBLastErrorText = "N/A";
   ResearchDBStatusText = "OK";

   if(ResearchDBFlushEverySignal)
      ResearchDBExecute("PRAGMA optimize", "flush signal database");

   ResearchDBVerbose("signal " + IntegerToString(signalId) + " written");
   return signalId;
}

int ResearchDBFindTrade(long identifier)
{
   for(int i = 0; i < TRE_RESEARCH_DB_MAX_TRADES; i++)
      if(TREResearchDBTrades[i].active &&
         TREResearchDBTrades[i].identifier == identifier)
         return i;
   return -1;
}

int ResearchDBFreeTradeSlot()
{
   for(int i = 0; i < TRE_RESEARCH_DB_MAX_TRADES; i++)
      if(!TREResearchDBTrades[i].active)
         return i;
   return -1;
}

bool ResearchDBPositionStillOpen(long identifier)
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      if(PositionGetTicket(i) > 0 &&
         PositionGetInteger(POSITION_IDENTIFIER) == identifier)
         return true;
   }
   return false;
}

void ResearchDBInsertIntegrityEvent(string eventType, long signalId,
                                    long tradeId, string severity,
                                    string details)
{
   string sql =
      "INSERT INTO research_integrity_event("
      "experiment_id,created_at,event_type,signal_id,trade_id,"
      "severity,details) VALUES(" +
      ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) + "," +
      ResearchDBSQLText(eventType) + "," +
      ResearchDBSQLID(signalId) + "," +
      ResearchDBSQLID(tradeId) + "," +
      ResearchDBSQLText(severity) + "," +
      ResearchDBSQLText(details) + ")";
   ResearchDBExecute(sql, "insert integrity event");
}

bool ResearchDBHasUntrackedPosition(string symbol)
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      if(PositionGetTicket(i) > 0 &&
         PositionGetString(POSITION_SYMBOL) == symbol &&
         PositionGetInteger(POSITION_MAGIC) == BacktestMagicNumber &&
         ResearchDBFindTrade(
            PositionGetInteger(POSITION_IDENTIFIER)) < 0)
         return true;
   }
   return false;
}

void ResearchDBLinkTradeToSignal(long signalId, long tradeId)
{
   // Phase 2 snapshots are immutable. Attribution is represented only by
   // trade_open.signal_id and derived views; signal/policy rows are not
   // rewritten after their transaction commits.
   if(signalId <= 0)
      ResearchDBInsertIntegrityEvent(
         "TRADE_WITHOUT_SIGNAL", 0, tradeId, "ERROR",
         "Executed trade could not create an originating signal snapshot");
}

void ResearchDBAppendSnapshotField(string &columns,
                                   string &values,
                                   string name,
                                   string value)
{
   if(columns != "")
   {
      columns += ",";
      values += ",";
   }
   columns += name;
   values += value;
}

bool ResearchDBStorePendingMarketSnapshot(long tradeId)
{
   if(!ResearchDBCanWrite() ||
      !TREMarketSnapshotReady ||
      !TREMarketSnapshotLocked)
   {
      return false;
   }
   if(tradeId > 0)
      TREPendingMarketSnapshot.tradeId = tradeId;
   if(TREPendingMarketSnapshot.tradeId <= 0)
      return false;

   TRE_TradeMarketSnapshot snapshot = TREPendingMarketSnapshot;
   string columns = "";
   string values = "";

   // GENERAL
   ResearchDBAppendSnapshotField(
      columns, values, "TradeID",
      ResearchDBSQLInteger(snapshot.tradeId));
   ResearchDBAppendSnapshotField(
      columns, values, "MagicNumber",
      ResearchDBSQLInteger(snapshot.magicNumber));
   ResearchDBAppendSnapshotField(
      columns, values, "Symbol",
      ResearchDBSQLText(snapshot.symbol));
   ResearchDBAppendSnapshotField(
      columns, values, "Timeframe",
      ResearchDBSQLInteger(snapshot.timeframe));
   ResearchDBAppendSnapshotField(
      columns, values, "OpenTime",
      ResearchDBSQLText(ResearchDBTimeText(snapshot.openTime)));
   ResearchDBAppendSnapshotField(
      columns, values, "Direction",
      ResearchDBSQLInteger(snapshot.direction));
   ResearchDBAppendSnapshotField(
      columns, values, "Lot",
      ResearchDBSQLDouble(snapshot.lot));
   ResearchDBAppendSnapshotField(
      columns, values, "EntryPrice",
      ResearchDBSQLDouble(snapshot.entryPrice));

   // MARKET STRUCTURE
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentSwingDirection",
      ResearchDBSQLInteger(snapshot.currentSwingDirection));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentSwingDepth",
      ResearchDBSQLInteger(snapshot.currentSwingDepth));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentSwingLength",
      ResearchDBSQLDouble(snapshot.currentSwingLength));
   ResearchDBAppendSnapshotField(
      columns, values, "PreviousSwingDepth",
      ResearchDBSQLInteger(snapshot.previousSwingDepth));
   ResearchDBAppendSnapshotField(
      columns, values, "PreviousSwingLength",
      ResearchDBSQLDouble(snapshot.previousSwingLength));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentZone",
      ResearchDBSQLInteger(snapshot.currentZone));
   ResearchDBAppendSnapshotField(
      columns, values, "ZoneScore",
      ResearchDBSQLDouble(snapshot.zoneScore));
   ResearchDBAppendSnapshotField(
      columns, values, "ZoneWidth",
      ResearchDBSQLDouble(snapshot.zoneWidth));
   ResearchDBAppendSnapshotField(
      columns, values, "DistanceToZoneCenter",
      ResearchDBSQLDouble(snapshot.distanceToZoneCenter));
   ResearchDBAppendSnapshotField(
      columns, values, "DistanceToZoneEdge",
      ResearchDBSQLDouble(snapshot.distanceToZoneEdge));

   // EMA FEATURES
   ResearchDBAppendSnapshotField(columns, values, "EMA20",
                                 ResearchDBSQLDouble(snapshot.ema20));
   ResearchDBAppendSnapshotField(columns, values, "EMA50",
                                 ResearchDBSQLDouble(snapshot.ema50));
   ResearchDBAppendSnapshotField(columns, values, "EMA100",
                                 ResearchDBSQLDouble(snapshot.ema100));
   ResearchDBAppendSnapshotField(columns, values, "EMA200",
                                 ResearchDBSQLDouble(snapshot.ema200));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA20Slope",
      ResearchDBSQLDouble(snapshot.ema20Slope));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA50Slope",
      ResearchDBSQLDouble(snapshot.ema50Slope));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA100Slope",
      ResearchDBSQLDouble(snapshot.ema100Slope));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA200Slope",
      ResearchDBSQLDouble(snapshot.ema200Slope));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA20Above50",
      ResearchDBSQLInteger(snapshot.ema20Above50));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA50Above100",
      ResearchDBSQLInteger(snapshot.ema50Above100));
   ResearchDBAppendSnapshotField(
      columns, values, "EMA100Above200",
      ResearchDBSQLInteger(snapshot.ema100Above200));
   ResearchDBAppendSnapshotField(
      columns, values, "EMAAlignmentScore",
      ResearchDBSQLInteger(snapshot.emaAlignmentScore));
   ResearchDBAppendSnapshotField(
      columns, values, "DistanceEMA20_50",
      ResearchDBSQLDouble(snapshot.distanceEMA20_50));
   ResearchDBAppendSnapshotField(
      columns, values, "DistanceEMA50_100",
      ResearchDBSQLDouble(snapshot.distanceEMA50_100));
   ResearchDBAppendSnapshotField(
      columns, values, "DistanceEMA100_200",
      ResearchDBSQLDouble(snapshot.distanceEMA100_200));

   // VOLATILITY AND TREND
   ResearchDBAppendSnapshotField(columns, values, "ATR",
                                 ResearchDBSQLDouble(snapshot.atr));
   ResearchDBAppendSnapshotField(
      columns, values, "ATRPercent",
      ResearchDBSQLDouble(snapshot.atrPercent));
   ResearchDBAppendSnapshotField(
      columns, values, "TrueRange",
      ResearchDBSQLDouble(snapshot.trueRange));
   ResearchDBAppendSnapshotField(
      columns, values, "AverageTrueRangeRatio",
      ResearchDBSQLDouble(snapshot.averageTrueRangeRatio));
   ResearchDBAppendSnapshotField(
      columns, values, "DailyRange",
      ResearchDBSQLDouble(snapshot.dailyRange));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentCandleRange",
      ResearchDBSQLDouble(snapshot.currentCandleRange));
   ResearchDBAppendSnapshotField(columns, values, "ADX",
                                 ResearchDBSQLDouble(snapshot.adx));
   ResearchDBAppendSnapshotField(columns, values, "PlusDI",
                                 ResearchDBSQLDouble(snapshot.plusDI));
   ResearchDBAppendSnapshotField(columns, values, "MinusDI",
                                 ResearchDBSQLDouble(snapshot.minusDI));
   ResearchDBAppendSnapshotField(
      columns, values, "TrendStrength",
      ResearchDBSQLDouble(snapshot.trendStrength));
   ResearchDBAppendSnapshotField(
      columns, values, "TrendAcceleration",
      ResearchDBSQLDouble(snapshot.trendAcceleration));

   // PRESSURE AND SESSION
   ResearchDBAppendSnapshotField(
      columns, values, "PressureState",
      ResearchDBSQLInteger(snapshot.pressureState));
   ResearchDBAppendSnapshotField(
      columns, values, "PressureScore",
      ResearchDBSQLDouble(snapshot.pressureScore));
   ResearchDBAppendSnapshotField(
      columns, values, "PressureStrength",
      ResearchDBSQLDouble(snapshot.pressureStrength));
   ResearchDBAppendSnapshotField(
      columns, values, "PressureDirection",
      ResearchDBSQLInteger(snapshot.pressureDirection));
   ResearchDBAppendSnapshotField(
      columns, values, "PressureAge",
      ResearchDBSQLInteger(snapshot.pressureAge));
   ResearchDBAppendSnapshotField(
      columns, values, "DayOfWeek",
      ResearchDBSQLInteger(snapshot.dayOfWeek));
   ResearchDBAppendSnapshotField(
      columns, values, "Hour",
      ResearchDBSQLInteger(snapshot.hour));
   ResearchDBAppendSnapshotField(
      columns, values, "TradingSession",
      ResearchDBSQLInteger(snapshot.tradingSession));
   ResearchDBAppendSnapshotField(
      columns, values, "IsHoliday",
      ResearchDBSQLInteger(snapshot.isHoliday));
   ResearchDBAppendSnapshotField(
      columns, values, "IsWeekend",
      ResearchDBSQLInteger(snapshot.isWeekend));

   // EXECUTION AND CANDLE
   ResearchDBAppendSnapshotField(columns, values, "Spread",
                                 ResearchDBSQLDouble(snapshot.spread));
   ResearchDBAppendSnapshotField(
      columns, values, "SpreadPercentATR",
      ResearchDBSQLDouble(snapshot.spreadPercentATR));
   ResearchDBAppendSnapshotField(
      columns, values, "TickSize",
      ResearchDBSQLDouble(snapshot.tickSize));
   ResearchDBAppendSnapshotField(
      columns, values, "PointValue",
      ResearchDBSQLDouble(snapshot.pointValue));
   ResearchDBAppendSnapshotField(
      columns, values, "Digits",
      ResearchDBSQLInteger(snapshot.digits));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentOpen",
      ResearchDBSQLDouble(snapshot.currentOpen));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentHigh",
      ResearchDBSQLDouble(snapshot.currentHigh));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentLow",
      ResearchDBSQLDouble(snapshot.currentLow));
   ResearchDBAppendSnapshotField(
      columns, values, "CurrentClose",
      ResearchDBSQLDouble(snapshot.currentClose));
   ResearchDBAppendSnapshotField(
      columns, values, "BodySize",
      ResearchDBSQLDouble(snapshot.bodySize));
   ResearchDBAppendSnapshotField(
      columns, values, "UpperShadow",
      ResearchDBSQLDouble(snapshot.upperShadow));
   ResearchDBAppendSnapshotField(
      columns, values, "LowerShadow",
      ResearchDBSQLDouble(snapshot.lowerShadow));
   ResearchDBAppendSnapshotField(
      columns, values, "Bullish",
      ResearchDBSQLInteger(snapshot.bullish));
   ResearchDBAppendSnapshotField(
      columns, values, "Bearish",
      ResearchDBSQLInteger(snapshot.bearish));
   ResearchDBAppendSnapshotField(
      columns, values, "DojiScore",
      ResearchDBSQLDouble(snapshot.dojiScore));

   // MULTI TIMEFRAME AND QUALITY FLAGS
   ResearchDBAppendSnapshotField(
      columns, values, "M15EMA50",
      ResearchDBSQLDouble(snapshot.m15EMA50));
   ResearchDBAppendSnapshotField(
      columns, values, "H1EMA50",
      ResearchDBSQLDouble(snapshot.h1EMA50));
   ResearchDBAppendSnapshotField(
      columns, values, "H4EMA50",
      ResearchDBSQLDouble(snapshot.h4EMA50));
   ResearchDBAppendSnapshotField(
      columns, values, "D1EMA50",
      ResearchDBSQLDouble(snapshot.d1EMA50));
   ResearchDBAppendSnapshotField(columns, values, "H1ATR",
                                 ResearchDBSQLDouble(snapshot.h1ATR));
   ResearchDBAppendSnapshotField(columns, values, "H4ATR",
                                 ResearchDBSQLDouble(snapshot.h4ATR));
   ResearchDBAppendSnapshotField(columns, values, "D1ATR",
                                 ResearchDBSQLDouble(snapshot.d1ATR));
   ResearchDBAppendSnapshotField(
      columns, values, "HasStrongTrend",
      ResearchDBSQLInteger(snapshot.hasStrongTrend));
   ResearchDBAppendSnapshotField(
      columns, values, "HasHighVolatility",
      ResearchDBSQLInteger(snapshot.hasHighVolatility));
   ResearchDBAppendSnapshotField(
      columns, values, "NearZoneCenter",
      ResearchDBSQLInteger(snapshot.nearZoneCenter));
   ResearchDBAppendSnapshotField(
      columns, values, "NearZoneEdge",
      ResearchDBSQLInteger(snapshot.nearZoneEdge));
   ResearchDBAppendSnapshotField(
      columns, values, "PressureConfirmed",
      ResearchDBSQLInteger(snapshot.pressureConfirmed));
   ResearchDBAppendSnapshotField(
      columns, values, "EMAFullyAligned",
      ResearchDBSQLInteger(snapshot.emaFullyAligned));

   // INSERT OR IGNORE is the immutability guard: no UPDATE path exists.
   string sql =
      "INSERT OR IGNORE INTO trade_market_snapshot(" +
      columns + ") VALUES(" + values + ")";
   if(!ResearchDBExecute(sql, "insert immutable trade market snapshot"))
      return false;

   MarketSnapshotConsume(snapshot.tradeId);
   ResearchDBLastWriteTimeText = ResearchDBTimeText(TimeCurrent());
   return true;
}

void ResearchDBCaptureOpenTrades(string symbol)
{
   if(!ResearchDBCanWrite() || !ResearchDBWriteTrades)
      return;

   int total = PositionsTotal();
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   MqlTick entryTick;
   ZeroMemory(entryTick);
   SymbolInfoTick(symbol, entryTick);
   double spreadAtEntry =
      (point > 0) ? (entryTick.ask - entryTick.bid) / point : 0;
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         PositionGetString(POSITION_SYMBOL) != symbol ||
         PositionGetInteger(POSITION_MAGIC) != BacktestMagicNumber)
         continue;

      long identifier = PositionGetInteger(POSITION_IDENTIFIER);
      if(ResearchDBFindTrade(identifier) >= 0)
         continue;

      int slot = ResearchDBFreeTradeSlot();
      if(slot < 0)
      {
         ResearchDBLastErrorText = "Trade tracking limit reached";
         ResearchDBStatusText = "ERROR";
         Print("TRE Research DB: ", ResearchDBLastErrorText);
         return;
      }

      TRE_ResearchDBTrade trade;
      trade.active = true;
      trade.tradeId = ResearchDBTotalTradesOpenedWritten + 1;
      trade.ticket = ticket;
      trade.identifier = identifier;
      trade.type = PositionGetInteger(POSITION_TYPE);
      trade.openTime = (datetime)PositionGetInteger(POSITION_TIME);
      string direction =
         (trade.type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      bool currentExecution =
         LastExecutionAction == direction + " SENT";
      trade.signalId =
         currentExecution
         ? ResearchDBRecordSignal(symbol, true, "EXECUTION")
         : 0;
      int entryShift =
         iBarShift(symbol, ExecutionTF, trade.openTime, false);
      trade.entryBar =
         (entryShift >= 0)
         ? iTime(symbol, ExecutionTF, entryShift)
         : 0;
      trade.executionDelaySeconds = 0;
      trade.executionDelayBars = 0;
      trade.volume = PositionGetDouble(POSITION_VOLUME);
      trade.openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      trade.stopLoss = PositionGetDouble(POSITION_SL);
      trade.takeProfit = PositionGetDouble(POSITION_TP);
      trade.requestedSLPoints = ExecutionRequestedSLPoints;
      trade.requestedTPPoints = ExecutionRequestedTPPoints;
      trade.effectiveSLPoints = ExecutionEffectiveSLPoints;
      trade.effectiveTPPoints = ExecutionEffectiveTPPoints;
      trade.symbolPoint = point;
      trade.tickSize = tickSize;
      trade.tickValue = tickValue;
      trade.spreadAtEntry = spreadAtEntry;
      trade.plannedRR = JournalRiskReward(
         trade.type, trade.openPrice, trade.stopLoss, trade.takeProfit);
      trade.maePoints = 0;
      trade.mfePoints = 0;
      trade.maxFloatingProfit = 0;
      trade.maxFloatingLoss = 0;
      trade.pressureDirection = PressureDirectionText;
      trade.pressureLevel = PressureLevelText;
      trade.pressureScore = PressureScore;
      trade.regime = ActiveRegimeText;
      trade.zone = CurrentZone;
      trade.decision = DecisionAfterPressure;

      double riskPoints = (point > 0)
                          ? MathAbs(trade.openPrice - trade.stopLoss) / point
                          : 0;
      double rewardPoints = (point > 0)
                            ? MathAbs(trade.takeProfit - trade.openPrice) / point
                            : 0;
      string sql =
         "INSERT INTO trade_open("
         "experiment_id,signal_id,trade_id,ticket,open_time,symbol,"
         "direction,volume_requested,volume_executed,open_price,sl,tp,"
         "planned_risk_points,planned_reward_points,planned_rr,"
         "magic_number,comment,decision_after_pressure,"
         "pressure_direction,pressure_level,pressure_score,"
         "active_regime,zone_id,risk_percent,execution_reason,"
         "entry_time,entry_bar,execution_delay_seconds,"
         "execution_delay_bars) VALUES(" +
         ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
         ResearchDBSQLID(trade.signalId) + "," +
         ResearchDBSQLInteger(trade.tradeId) + "," +
         ResearchDBSQLInteger((long)trade.ticket) + "," +
         ResearchDBSQLText(ResearchDBTimeText(trade.openTime)) + "," +
         ResearchDBSQLText(symbol) + "," +
         ResearchDBSQLText(direction) + "," +
         ResearchDBSQLDouble(ExecutionRequestedLot) + "," +
         ResearchDBSQLDouble(trade.volume) + "," +
         ResearchDBSQLDouble(trade.openPrice) + "," +
         ResearchDBSQLDouble(trade.stopLoss) + "," +
         ResearchDBSQLDouble(trade.takeProfit) + "," +
         ResearchDBSQLDouble(riskPoints) + "," +
         ResearchDBSQLDouble(rewardPoints) + "," +
         ResearchDBSQLDouble(trade.plannedRR) + "," +
         ResearchDBSQLInteger(BacktestMagicNumber) + "," +
         ResearchDBSQLText(PositionGetString(POSITION_COMMENT)) + "," +
         ResearchDBSQLText(trade.decision) + "," +
         ResearchDBSQLText(trade.pressureDirection) + "," +
         ResearchDBSQLText(trade.pressureLevel) + "," +
         ResearchDBSQLDouble(trade.pressureScore) + "," +
         ResearchDBSQLText(trade.regime) + "," +
         ResearchDBSQLInteger(trade.zone) + "," +
         ResearchDBSQLDouble(
            (AccountInfoDouble(ACCOUNT_BALANCE) > 0)
            ? (RiskUSD / AccountInfoDouble(ACCOUNT_BALANCE)) * 100.0
            : 0) + "," +
         ResearchDBSQLText(LastExecutionReason) + "," +
         ResearchDBSQLText(ResearchDBTimeText(trade.openTime)) + "," +
         ResearchDBSQLText(ResearchDBTimeText(trade.entryBar)) + "," +
         ResearchDBSQLInteger(trade.executionDelaySeconds) + "," +
         ResearchDBSQLInteger(trade.executionDelayBars) + ")";
      long rowId = ResearchDBInsert(sql, "insert trade open");
      if(rowId <= 0)
         continue;

      if(currentExecution && TREMarketSnapshotLocked &&
         !ResearchDBStorePendingMarketSnapshot(trade.tradeId))
      {
         ResearchDBInsertIntegrityEvent(
            "MARKET_SNAPSHOT_WRITE_FAILED",
            trade.signalId, trade.tradeId, "ERROR",
            "Immutable pre-entry market snapshot could not be stored");
      }

      TREResearchDBTrades[slot] = trade;
      ResearchDBTotalTradesOpenedWritten++;
      ResearchDBLastTradeID = trade.tradeId;
      ResearchDBLinkTradeToSignal(trade.signalId, trade.tradeId);
      ResearchDBLastWriteTimeText = ResearchDBTimeText(TimeCurrent());
      ResearchDBStatusText = "OK";
   }
}

void ResearchDBUpdateOpenTradeExcursions(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   for(int i = 0; i < TRE_RESEARCH_DB_MAX_TRADES; i++)
   {
      if(!TREResearchDBTrades[i].active)
         continue;
      int total = PositionsTotal();
      for(int pos = 0; pos < total; pos++)
      {
         if(PositionGetTicket(pos) == 0 ||
            PositionGetInteger(POSITION_IDENTIFIER) !=
            TREResearchDBTrades[i].identifier)
            continue;

         double current = PositionGetDouble(POSITION_PRICE_CURRENT);
         double floating = PositionGetDouble(POSITION_PROFIT);
         double move = 0;
         if(point > 0)
         {
            move = (TREResearchDBTrades[i].type == POSITION_TYPE_BUY)
                   ? (current - TREResearchDBTrades[i].openPrice) / point
                   : (TREResearchDBTrades[i].openPrice - current) / point;
         }
         if(move > TREResearchDBTrades[i].mfePoints)
            TREResearchDBTrades[i].mfePoints = move;
         if(move < 0 && -move > TREResearchDBTrades[i].maePoints)
            TREResearchDBTrades[i].maePoints = -move;
         if(floating > TREResearchDBTrades[i].maxFloatingProfit)
            TREResearchDBTrades[i].maxFloatingProfit = floating;
         if(floating < TREResearchDBTrades[i].maxFloatingLoss)
            TREResearchDBTrades[i].maxFloatingLoss = floating;
         break;
      }
   }
}

bool ResearchDBReadCloseDeal(TRE_ResearchDBTrade &trade,
                             datetime &closeTime, double &closePrice,
                             double &profit, double &swap,
                             double &commission, string &reason)
{
   if(!HistorySelect(trade.openTime, TimeCurrent()))
      return false;
   bool found = false;
   long finalReason = -1;
   profit = 0;
   swap = 0;
   commission = 0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         HistoryDealGetInteger(deal, DEAL_POSITION_ID) != trade.identifier)
         continue;
      profit += HistoryDealGetDouble(deal, DEAL_PROFIT);
      swap += HistoryDealGetDouble(deal, DEAL_SWAP);
      commission += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      datetime time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(!found || time >= closeTime)
      {
         found = true;
         closeTime = time;
         closePrice = HistoryDealGetDouble(deal, DEAL_PRICE);
         finalReason = HistoryDealGetInteger(deal, DEAL_REASON);
      }
   }
   reason = JournalCloseReason(finalReason);
   if(TimeoutLastCloseResultText == "OK" &&
      trade.identifier == TimeoutLastPositionIdentifier)
      reason = "TIMEOUT";
   else if(WeekendLastCloseResultText == "OK" &&
           trade.identifier == WeekendLastClosedPositionIdentifier)
      reason = "CLOSE_WEEKEND_PROTECTION";
   return found;
}

void ResearchDBCaptureClosedTrades(string symbol)
{
   if(!ResearchDBCanWrite() || !ResearchDBWriteTrades)
      return;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   for(int i = 0; i < TRE_RESEARCH_DB_MAX_TRADES; i++)
   {
      if(!TREResearchDBTrades[i].active ||
         ResearchDBPositionStillOpen(TREResearchDBTrades[i].identifier))
         continue;

      TRE_ResearchDBTrade trade = TREResearchDBTrades[i];
      datetime closeTime = 0;
      double closePrice = 0;
      double profit = 0;
      double swap = 0;
      double commission = 0;
      string reason = "UNKNOWN";
      if(!ResearchDBReadCloseDeal(trade, closeTime, closePrice,
                                  profit, swap, commission, reason))
         continue;

      double profitPoints = 0;
      if(point > 0)
         profitPoints = (trade.type == POSITION_TYPE_BUY)
                        ? (closePrice - trade.openPrice) / point
                        : (trade.openPrice - closePrice) / point;
      ENUM_TIMEFRAMES holdingTF = ExecutionTF;
      int barsHeld = TRE_CalculateHoldingBars(
         symbol, trade.openTime, closeTime, holdingTF);
      int minutesHeld = (int)MathMax(
         0, (long)(closeTime - trade.openTime) / 60);
      int exitShift = iBarShift(symbol, ExecutionTF, closeTime, false);
      datetime exitBar =
         (exitShift >= 0) ? iTime(symbol, ExecutionTF, exitShift) : 0;
      double realizedRR = JournalRiskReward(
         trade.type, trade.openPrice, trade.stopLoss, closePrice);
      double netProfit = profit + swap + commission;
      TRE_TradeCloseAudit audit;
      TRE_BuildTradeCloseAudit(
         trade.type, trade.openPrice, trade.stopLoss, trade.takeProfit,
         closePrice, trade.volume, trade.effectiveSLPoints,
         trade.effectiveTPPoints, trade.symbolPoint, trade.tickSize,
         trade.tickValue, profit, commission, swap, reason, audit);
      string direction =
         (trade.type == POSITION_TYPE_BUY) ? "BUY" : "SELL";

      string sql =
         "INSERT INTO trade_close("
         "experiment_id,signal_id,trade_id,ticket,open_time,close_time,"
         "symbol,direction,volume,open_price,close_price,profit,"
         "profit_points,swap,commission,exit_reason,bars_held,"
         "holding_minutes,mae_points,mfe_points,max_floating_profit,"
         "max_floating_loss,planned_rr,realized_rr,"
         "pressure_direction_at_entry,pressure_level_at_entry,"
         "pressure_score_at_entry,regime_at_entry,zone_at_entry,"
         "decision_at_entry,entry_time,entry_bar,exit_time,exit_bar,"
         "execution_delay_seconds,execution_delay_bars,"
         "requested_sl_points,requested_tp_points,"
         "effective_sl_points,effective_tp_points,entry_price,"
         "sl_price,tp_price,close_reason,actual_volume,symbol_point,"
         "tick_size,tick_value,spread_at_entry,gross_profit,net_profit,"
         "expected_loss_money,expected_profit_money,"
         "profit_deviation_money,profit_deviation_points,"
         "is_exact_sl_hit,is_exact_tp_hit,is_timeout_exit,"
         "is_tester_close,audit_reason) VALUES(" +
         ResearchDBSQLInteger(ResearchDBExperimentID) + "," +
         ResearchDBSQLID(trade.signalId) + "," +
         ResearchDBSQLInteger(trade.tradeId) + "," +
         ResearchDBSQLInteger((long)trade.ticket) + "," +
         ResearchDBSQLText(ResearchDBTimeText(trade.openTime)) + "," +
         ResearchDBSQLText(ResearchDBTimeText(closeTime)) + "," +
         ResearchDBSQLText(symbol) + "," +
         ResearchDBSQLText(direction) + "," +
         ResearchDBSQLDouble(trade.volume) + "," +
         ResearchDBSQLDouble(trade.openPrice) + "," +
         ResearchDBSQLDouble(closePrice) + "," +
         ResearchDBSQLDouble(profit) + "," +
         ResearchDBSQLDouble(profitPoints) + "," +
         ResearchDBSQLDouble(swap) + "," +
         ResearchDBSQLDouble(commission) + "," +
         ResearchDBSQLText(reason) + "," +
         ResearchDBSQLInteger(barsHeld) + "," +
         ResearchDBSQLInteger(minutesHeld) + "," +
         ResearchDBSQLDouble(trade.maePoints) + "," +
         ResearchDBSQLDouble(trade.mfePoints) + "," +
         ResearchDBSQLDouble(trade.maxFloatingProfit) + "," +
         ResearchDBSQLDouble(trade.maxFloatingLoss) + "," +
         ResearchDBSQLDouble(trade.plannedRR) + "," +
         ResearchDBSQLDouble(realizedRR) + "," +
         ResearchDBSQLText(trade.pressureDirection) + "," +
         ResearchDBSQLText(trade.pressureLevel) + "," +
         ResearchDBSQLDouble(trade.pressureScore) + "," +
         ResearchDBSQLText(trade.regime) + "," +
         ResearchDBSQLInteger(trade.zone) + "," +
         ResearchDBSQLText(trade.decision) + "," +
         ResearchDBSQLText(ResearchDBTimeText(trade.openTime)) + "," +
         ResearchDBSQLText(ResearchDBTimeText(trade.entryBar)) + "," +
         ResearchDBSQLText(ResearchDBTimeText(closeTime)) + "," +
         ResearchDBSQLText(ResearchDBTimeText(exitBar)) + "," +
         ResearchDBSQLInteger(trade.executionDelaySeconds) + "," +
         ResearchDBSQLInteger(trade.executionDelayBars) + "," +
         ResearchDBSQLDouble(trade.requestedSLPoints) + "," +
         ResearchDBSQLDouble(trade.requestedTPPoints) + "," +
         ResearchDBSQLDouble(trade.effectiveSLPoints) + "," +
         ResearchDBSQLDouble(trade.effectiveTPPoints) + "," +
         ResearchDBSQLDouble(trade.openPrice) + "," +
         ResearchDBSQLDouble(trade.stopLoss) + "," +
         ResearchDBSQLDouble(trade.takeProfit) + "," +
         ResearchDBSQLText(reason) + "," +
         ResearchDBSQLDouble(trade.volume) + "," +
         ResearchDBSQLDouble(trade.symbolPoint) + "," +
         ResearchDBSQLDouble(trade.tickSize) + "," +
         ResearchDBSQLDouble(trade.tickValue) + "," +
         ResearchDBSQLDouble(trade.spreadAtEntry) + "," +
         ResearchDBSQLDouble(profit) + "," +
         ResearchDBSQLDouble(netProfit) + "," +
         ResearchDBSQLDouble(audit.expectedLossMoney) + "," +
         ResearchDBSQLDouble(audit.expectedProfitMoney) + "," +
         ResearchDBSQLDouble(audit.profitDeviationMoney) + "," +
         ResearchDBSQLDouble(audit.profitDeviationPoints) + "," +
         ResearchDBSQLInteger(ResearchDBBool(audit.exactSLHit)) + "," +
         ResearchDBSQLInteger(ResearchDBBool(audit.exactTPHit)) + "," +
         ResearchDBSQLInteger(ResearchDBBool(audit.timeoutExit)) + "," +
         ResearchDBSQLInteger(ResearchDBBool(audit.testerClose)) + "," +
         ResearchDBSQLText(audit.auditReason) + ")";
      if(ResearchDBInsert(sql, "insert trade close") <= 0)
         continue;

      ResearchDBTotalTradesClosedWritten++;
      ResearchDBLastTradeID = trade.tradeId;
      ResearchDBLastWriteTimeText = ResearchDBTimeText(TimeCurrent());
      ResearchDBStatusText = "OK";
      TREResearchDBTrades[i].active = false;
   }
}

void ResearchDBUpdateExperimentEnd()
{
   ResearchDBExecute(
      "UPDATE experiment SET date_end=" +
      ResearchDBSQLText(ResearchDBTimeText(TimeCurrent())) +
      " WHERE experiment_id=" +
      ResearchDBSQLInteger(ResearchDBExperimentID),
      "update experiment end time");
}

void ResearchDBInitialize(string symbol)
{
   ResearchDBStatusText = UseResearchDB ? "INITIALIZING" : "DISABLED";
   if(!UseResearchDB || TREResearchDBInitialized)
      return;

   TREResearchDBInitialized = true;
   TREResearchDBStartedAt = TimeCurrent();
   if(TREResearchDBStartedAt <= 0)
      TREResearchDBStartedAt = TimeLocal();

   string folder = ResearchDBSafeFilePart(ResearchDBFolder);
   string prefix = ResearchDBSafeFilePart(ResearchDBFilenamePrefix);
   string safeSymbol = ResearchDBSafeFilePart(symbol);
   int commonFlag = ResearchDBUseCommonFiles ? FILE_COMMON : 0;
   if(folder != "")
      FolderCreate(folder, commonFlag);

   string base = prefix + "_" + safeSymbol + "_" +
                 ResearchDBTimestamp(TREResearchDBStartedAt);
   string filename = base + ".db";
   string relative = (folder == "") ? filename : folder + "\\" + filename;
   for(int suffix = 1; FileIsExist(relative, commonFlag); suffix++)
   {
      if(suffix > 999)
      {
         ResearchDBStatusText = "ERROR";
         ResearchDBLastErrorText =
            "No available database filename after 999 collisions";
         Print("TRE Research DB: ", ResearchDBLastErrorText);
         return;
      }
      filename = base + "_" + StringFormat("%03d", suffix) + ".db";
      relative = (folder == "") ? filename : folder + "\\" + filename;
   }

   ResearchDBFilenameText = filename;
   string root = ResearchDBUseCommonFiles
                 ? TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files"
                 : TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files";
   ResearchDBPathText =
      (folder == "") ? root : root + "\\" + folder;

   uint flags = DATABASE_OPEN_READWRITE | DATABASE_OPEN_CREATE;
   if(ResearchDBUseCommonFiles)
      flags |= DATABASE_OPEN_COMMON;
   ResetLastError();
   TREResearchDBHandle = DatabaseOpen(relative, flags);
   if(TREResearchDBHandle == INVALID_HANDLE)
   {
      ResearchDBFail("open " + relative);
      return;
   }

   ResearchDBExecute(
      ResearchDBFlushEverySignal
      ? "PRAGMA synchronous=FULL"
      : "PRAGMA synchronous=NORMAL",
      "configure synchronous mode");
   if(!ResearchDBCreateSchema())
      return;

   ResearchDBExperimentID = ResearchDBInsertExperiment(symbol);
   if(ResearchDBExperimentID <= 0)
      return;
   ResearchDBWriteParameterSet();
   ResearchDBInitializeSchemaMetadata();
   ResearchDBPrepareAnalysisViews();
   if(ResearchDBStatusText == "ERROR")
      return;
   ResearchDBPolicySnapshotCount =
      ResearchDBCountRows("policy_snapshot");
   ResearchDBFutureOutcomeCount =
      ResearchDBCountRows("future_outcome");
   ResearchDBAnalysisCacheCount =
      ResearchDBCountRows("analysis_cache");
   ResearchDBRefreshDiagnostics();
   ResearchDBStatusText = "OK";
   ResearchDBLastErrorText = "N/A";
   ResearchDBLastWriteTimeText = ResearchDBTimeText(TimeCurrent());
   ResearchDBVerbose("initialized " + ResearchDBPathText +
                     "\\" + ResearchDBFilenameText);
}

void ResearchDBEngine(string symbol)
{
   if(!ResearchDBCanWrite() || ResearchDBExperimentID <= 0)
      return;
   if(TREMarketSnapshotLocked &&
      TREPendingMarketSnapshot.tradeId > 0)
   {
      ResearchDBStorePendingMarketSnapshot(
         TREPendingMarketSnapshot.tradeId);
   }
   static int lastWeekendAuditSerial = 0;
   if(WeekendAuditSerial != lastWeekendAuditSerial)
   {
      lastWeekendAuditSerial = WeekendAuditSerial;
      ResearchDBInsertRunNote(
         "WeekendProtection",
         WeekendAuditDecision,
         WeekendAuditReason,
         WeekendAuditDetail);
   }
   static int lastAdaptiveV1AuditSerial = 0;
   if(AdaptiveV1AuditSerial - lastAdaptiveV1AuditSerial >
      TRE_ADAPTIVE_V1_AUDIT_QUEUE)
   {
      lastAdaptiveV1AuditSerial =
         AdaptiveV1AuditSerial - TRE_ADAPTIVE_V1_AUDIT_QUEUE;
   }
   while(lastAdaptiveV1AuditSerial < AdaptiveV1AuditSerial)
   {
      int auditIndex =
         lastAdaptiveV1AuditSerial %
         TRE_ADAPTIVE_V1_AUDIT_QUEUE;
      ResearchDBApplyAdaptiveEpisodeAudit(
         AdaptiveV1AuditEvent[auditIndex],
         AdaptiveV1AuditEpisodeID[auditIndex],
         AdaptiveV1AuditDetail[auditIndex],
         AdaptiveV1AuditTime[auditIndex]);
      string adaptiveNoteType =
         (AdaptiveV1AuditEvent[auditIndex] ==
          "RULE_VALIDATION_IGNORE")
         ? "RuleValidation"
         : "AdaptiveLossClusterV1";
      ResearchDBInsertRunNote(
         adaptiveNoteType,
         AdaptiveV1AuditEvent[auditIndex],
         AdaptiveV1AuditReason[auditIndex],
         AdaptiveV1AuditDetail[auditIndex]);
      lastAdaptiveV1AuditSerial++;
   }
   ResearchDBCaptureAdaptiveShadowTrades();
   bool executionSent =
      (LastExecutionAction == "BUY SENT" ||
       LastExecutionAction == "SELL SENT");
   bool hasFreshExecution =
      ResearchDBWriteTrades && executionSent &&
      ResearchDBHasUntrackedPosition(symbol);
   if(!hasFreshExecution)
      ResearchDBRecordSignal(symbol, false, "OBSERVATION");
   ResearchDBCaptureOpenTrades(symbol);
   ResearchDBUpdateOpenTradeExcursions(symbol);
   ResearchDBCaptureClosedTrades(symbol);

   static datetime lastDiagnosticBar = 0;
   datetime currentBar = iTime(symbol, _Period, 0);
   if(hasFreshExecution || currentBar != lastDiagnosticBar)
   {
      lastDiagnosticBar = currentBar;
      ResearchDBUpdateExperimentEnd();
      ResearchDBRefreshDiagnostics();
   }
}

void ResearchDBWriteAdaptiveV1Summary()
{
   static bool written = false;
   if(written || !ResearchDBCanWrite() ||
      ResearchDBExperimentID <= 0)
   {
      return;
   }
   written = true;
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_enabled",
      AdaptiveV1Enabled() ? "1" : "0",
      "Pure Direction+Zone adaptive filter enabled state");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_mode",
      AdaptiveClusterModeText(),
      "Advanced feature similarity is reserved and inactive");
   ResearchDBInsertRunNote(
      "RULE_VALIDATION_SUMMARY", "ValidatedPatternCount",
      IntegerToString(AdaptiveValidatedPatternCount),
      "Approved loss-cluster detections that activated Adaptive V1");
   ResearchDBInsertRunNote(
      "RULE_VALIDATION_SUMMARY", "IgnoredPatternCount",
      IntegerToString(AdaptiveIgnoredPatternCount),
      "Detected loss-cluster patterns rejected by static validation");
   ResearchDBInsertRunNote(
      "RULE_VALIDATION_SUMMARY", "AdaptiveActivatedPattern",
      AdaptiveActivatedPattern,
      "Most recent approved Direction and Zone activation pattern");
   ResearchDBInsertRunNote(
      "RULE_VALIDATION_SUMMARY", "ConfiguredApprovedPatternCount",
      IntegerToString(AdaptiveConfiguredApprovedPatternCount()),
      "Number of Direction and Zone inputs enabled for activation");
   ResearchDBInsertRunNote(
      "RULE_VALIDATION_SUMMARY", "ConfiguredRejectedPatternCount",
      IntegerToString(
         12 - AdaptiveConfiguredApprovedPatternCount()),
      "Number of Direction and Zone inputs disabled for activation");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_total_evaluations",
      IntegerToString(AdaptiveEvaluationCount),
      "Total Adaptive V1 filter evaluations");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_candidate_signals",
      IntegerToString(AdaptiveCandidateSignalCount),
      "Total confirmed unique order candidates before Adaptive V1");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_blocked_opportunities",
      IntegerToString(AdaptiveTotalBlockedOpportunities),
      "Total unique confirmed candidates blocked by Adaptive V1");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_executed_trades",
      IntegerToString(AdaptiveExecutedTradeCount),
      "Total Adaptive V1 pass candidates with accepted orders");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_activations",
      IntegerToString(AdaptiveActivationCount),
      "Total Direction+Zone temporary blocks activated");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_expires",
      IntegerToString(AdaptiveExpireCount),
      "Total cooldown blocks expired");
   ResearchDBInsertRunNote(
      "ADAPTIVE_EPISODE_SUMMARY", "adaptive_episode_count",
      IntegerToString(AdaptiveEpisodeCount),
      "Total Adaptive V1 activation episodes");
   ResearchDBInsertRunNote(
      "ADAPTIVE_EPISODE_SUMMARY",
      "adaptive_total_blocked_opportunities",
      IntegerToString(AdaptiveTotalBlockedOpportunities),
      "Total confirmed candidate opportunities blocked across episodes");
   ResearchDBInsertRunNote(
      "ADAPTIVE_EPISODE_SUMMARY",
      "adaptive_avg_blocked_opportunities_per_episode",
      DoubleToString(
         AdaptiveAverageBlockedOpportunitiesPerEpisode(), 6),
      "Average blocked opportunities per Adaptive V1 episode");
   ResearchDBInsertRunNote(
      "ADAPTIVE_EPISODE_SUMMARY",
      "adaptive_max_blocked_opportunities_per_episode",
      IntegerToString(AdaptiveMaxBlockedOpportunitiesInEpisode),
      "Maximum blocked opportunities observed in one episode");
   ResearchDBInsertRunNote(
      "ADAPTIVE_EPISODE_SUMMARY", "adaptive_most_blocked_pattern",
      AdaptiveMostBlockedPattern,
      "Direction and Zone episode with the most blocked opportunities");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_shadow_trade_count",
      IntegerToString(AdaptiveShadowTradeCount),
      "Total research-only trades simulated from blocked opportunities");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_shadow_net_profit",
      DoubleToString(AdaptiveShadowNetProfit, 8),
      "Net hypothetical result of closed Adaptive shadow trades");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_shadow_profit_factor",
      DoubleToString(AdaptiveShadowProfitFactor, 8),
      "Gross shadow profit divided by absolute gross shadow loss");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_estimated_benefit",
      DoubleToString(AdaptiveEstimatedBenefit, 8),
      "Negative shadow net profit; positive means blocking was beneficial");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_good_block_episodes",
      IntegerToString(AdaptiveGoodBlockEpisodes),
      "Episodes whose closed shadow trades have negative net profit");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_bad_block_episodes",
      IntegerToString(AdaptiveBadBlockEpisodes),
      "Episodes whose closed shadow trades have positive net profit");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_best_pattern",
      AdaptiveShadowBestPattern,
      "Direction and Zone with the highest estimated Adaptive benefit");
   ResearchDBInsertRunNote(
      "ADAPTIVE_SHADOW_SUMMARY", "adaptive_worst_pattern",
      AdaptiveShadowWorstPattern,
      "Direction and Zone with the lowest estimated Adaptive benefit");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_max_loss_cluster",
      IntegerToString(AdaptiveV1MaxLossCluster),
      "Maximum consecutive DEAL_PROFIT loss streak observed");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY",
      "adaptive_v1_last_blocked_direction",
      AdaptiveV1DirectionText(AdaptiveV1LastBlockedDirection),
      "Most recent blocked candidate direction");
   ResearchDBInsertRunNote(
      "ADAPTIVE_V1_SUMMARY", "adaptive_v1_last_blocked_zone",
      IntegerToString(AdaptiveV1LastBlockedZone),
      "Most recent blocked candidate zone");
}

void ResearchDBFinalize()
{
   if(TREResearchDBHandle != INVALID_HANDLE)
   {
      if(ResearchDBExperimentID > 0)
      {
         ResearchDBCaptureAdaptiveShadowTrades();
         ResearchDBWriteAdaptiveV1Summary();
         ResearchDBUpdateExperimentEnd();
         ResearchDBRefreshDiagnostics();
      }
      DatabaseClose(TREResearchDBHandle);
      TREResearchDBHandle = INVALID_HANDLE;
   }
   if(UseResearchDB && ResearchDBStatusText != "ERROR")
      ResearchDBStatusText = "CLOSED";
}

#endif
