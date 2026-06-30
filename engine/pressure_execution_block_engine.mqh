//+------------------------------------------------------------------+
//| engine/pressure_execution_block_engine.mqh                       |
//| Optional research-only permission gate before order execution    |
//+------------------------------------------------------------------+
#ifndef TRE_PRESSURE_EXECUTION_BLOCK_ENGINE_MQH
#define TRE_PRESSURE_EXECUTION_BLOCK_ENGINE_MQH

datetime TREPressureBlockLastCountedBar = 0;
string TREPressureBlockLastCountedDirection = "NONE";
datetime TREPressureBlockLastLogBar = 0;
string TREPressureBlockLastLogKey = "";

string PressureExecutionBlockModeToText(
   ENUM_PRESSURE_EXECUTION_BLOCK_MODE mode)
{
   if(mode == PRESSURE_EXECUTION_DIRECTION_BLOCK)
      return "DIRECTION_BLOCK";
   if(mode == PRESSURE_EXECUTION_HIGH_ONLY_BLOCK)
      return "HIGH_ONLY_BLOCK";
   if(mode == PRESSURE_EXECUTION_MEDIUM_HIGH_BLOCK)
      return "MEDIUM_HIGH_BLOCK";
   return "SHADOW";
}

bool PressureExecutionLevelAllowsBlock(
   ENUM_PRESSURE_EXECUTION_BLOCK_MODE mode)
{
   if(mode == PRESSURE_EXECUTION_DIRECTION_BLOCK)
      return true;
   if(mode == PRESSURE_EXECUTION_HIGH_ONLY_BLOCK)
      return (PressureLevel == PRESSURE_HIGH);
   if(mode == PRESSURE_EXECUTION_MEDIUM_HIGH_BLOCK)
      return (PressureLevel == PRESSURE_MEDIUM ||
              PressureLevel == PRESSURE_HIGH);
   return false;
}

void PressureExecutionBlockLog(string symbol,
                               string action,
                               string reason)
{
   datetime barTime = iTime(symbol, _Period, 0);
   string key =
      PressureExecutionBlockModeText + "|" +
      PressureExecutionBlockCandidateText + "|" +
      PressureDirectionText + "|" +
      PressureLevelText + "|" + action + "|" + reason;

   if(barTime == TREPressureBlockLastLogBar &&
      key == TREPressureBlockLastLogKey)
      return;

   TREPressureBlockLastLogBar = barTime;
   TREPressureBlockLastLogKey = key;
   Print("[PRESSURE_EXEC_BLOCK] mode=",
         PressureExecutionBlockModeText,
         " candidate=", PressureExecutionBlockCandidateText,
         " pressure_direction=", PressureDirectionText,
         " pressure_level=", PressureLevelText,
         " action=", action,
         " reason=", reason);
}

void PressureExecutionBlockEngine(string symbol)
{
   PressureExecutionBlockApplied = false;
   PressureExecutionBlockModeText =
      PressureExecutionBlockModeToText(
         PressureExecutionBlockMode);
   PressureExecutionBlockCandidateText =
      (ActionState == ACTION_BUY_READY)
      ? "BUY"
      : ((ActionState == ACTION_SELL_READY) ? "SELL" : "NONE");
   PressureExecutionBlockActionText = "ALLOW";
   PressureExecutionBlockReasonText = "No execution block applied";
   PressureExecutionBlockStatusText =
      UsePressureExecutionBlock ? "ENABLED" : "DISABLED";

   if(!UsePressureExecutionBlock)
      return;

   if(PressureExecutionBlockMode == PRESSURE_EXECUTION_SHADOW)
   {
      PressureExecutionBlockStatusText = "SHADOW";
      PressureExecutionBlockReasonText =
         "Shadow mode records pressure without blocking execution";
      PressureExecutionBlockLog(
         symbol, "ALLOW", PressureExecutionBlockReasonText);
      return;
   }

   if(ActionState != ACTION_BUY_READY &&
      ActionState != ACTION_SELL_READY)
   {
      PressureExecutionBlockReasonText =
         "No BUY or SELL candidate is ready";
      PressureExecutionBlockLog(
         symbol, "ALLOW", PressureExecutionBlockReasonText);
      return;
   }

   bool opposing =
      (ActionState == ACTION_BUY_READY &&
       PressureDirection == PRESSURE_DOWN) ||
      (ActionState == ACTION_SELL_READY &&
       PressureDirection == PRESSURE_UP);
   if(!opposing)
   {
      PressureExecutionBlockReasonText =
         "Pressure does not oppose the candidate";
      PressureExecutionBlockLog(
         symbol, "ALLOW", PressureExecutionBlockReasonText);
      return;
   }

   if(!PressureExecutionLevelAllowsBlock(
         PressureExecutionBlockMode))
   {
      PressureExecutionBlockReasonText =
         "Pressure level is outside the selected block mode";
      PressureExecutionBlockLog(
         symbol, "ALLOW", PressureExecutionBlockReasonText);
      return;
   }

   string candidate = PressureExecutionBlockCandidateText;
   PressureExecutionBlockApplied = true;
   PressureExecutionBlockStatusText = "ACTIVE";
   PressureExecutionBlockActionText = "BLOCKED_BY_PRESSURE";
   PressureExecutionBlockReasonText =
      PressureDirectionText + " " + PressureLevelText +
      " pressure opposes " + candidate + " candidate";
   PressureExecutionBlockLog(
      symbol, "BLOCKED", PressureExecutionBlockReasonText);

   datetime barTime = iTime(symbol, _Period, 0);
   if(barTime != TREPressureBlockLastCountedBar ||
      candidate != TREPressureBlockLastCountedDirection)
   {
      TREPressureBlockLastCountedBar = barTime;
      TREPressureBlockLastCountedDirection = candidate;
      PressureExecutionBlockTotal++;
      if(candidate == "BUY")
         PressureExecutionBlockBuyCount++;
      else
         PressureExecutionBlockSellCount++;
      if(PressureLevel == PRESSURE_HIGH)
         PressureExecutionBlockHighCount++;
      else if(PressureLevel == PRESSURE_MEDIUM)
         PressureExecutionBlockMediumCount++;
      PressureExecutionBlockLastTimeText =
         TimeToString(TimeCurrent(),
                      TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   }

   ActionState = ACTION_WATCH;
   EntryReason =
      "Pressure Execution Block: " +
      PressureExecutionBlockReasonText;
   MissingConditionText =
      "Execution permission blocked by opposing pressure";
}

#endif
