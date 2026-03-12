//+------------------------------------------------------------------+
//| state_machine.mqh — State machine, transitions, event dispatch  |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_STATE_MACHINE_MQH
#define NNFX_STATE_MACHINE_MQH

//+------------------------------------------------------------------+
//| State constants
#define SM_IDLE            0
#define SM_CONFIG_NEW      1
#define SM_CONFIG_LOADED   2
#define SM_WORKSPACE_TWEAK 3
#define SM_READY_TO_RUN    4
#define SM_SIM_RUNNING     5
#define SM_SIM_PAUSED      6
#define SM_SIM_FINISHED    7
#define SM_ERROR_STATE     8

//+------------------------------------------------------------------+
int    g_SM_State      = SM_IDLE;
int    g_SM_TransLogH  = INVALID_HANDLE;

//+------------------------------------------------------------------+
string SM_StateName(int state)
{
    switch(state)
    {
        case SM_IDLE:            return "IDLE";
        case SM_CONFIG_NEW:      return "CONFIG_NEW";
        case SM_CONFIG_LOADED:   return "CONFIG_LOADED";
        case SM_WORKSPACE_TWEAK: return "WORKSPACE_TWEAK";
        case SM_READY_TO_RUN:    return "READY_TO_RUN";
        case SM_SIM_RUNNING:     return "SIM_RUNNING";
        case SM_SIM_PAUSED:      return "SIM_PAUSED";
        case SM_SIM_FINISHED:    return "SIM_FINISHED";
        case SM_ERROR_STATE:     return "ERROR_STATE";
        default:                 return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
void SM_Init(string sessionId)
{
    g_SM_State = SM_IDLE;
    string logPath = "nnfx_sim/logs/" + sessionId + "_transitions.csv";
    g_SM_TransLogH = FileOpen(logPath, FILE_COMMON | FILE_WRITE | FILE_CSV | FILE_ANSI);
    if(g_SM_TransLogH != INVALID_HANDLE)
        FileWrite(g_SM_TransLogH, "timestamp", "old_state", "new_state", "reason");
    else
        Print("SM_Init: Cannot open transition log err=", GetLastError());
}

//+------------------------------------------------------------------+
void SM_Deinit()
{
    if(g_SM_TransLogH != INVALID_HANDLE)
    {
        FileClose(g_SM_TransLogH);
        g_SM_TransLogH = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
int SM_GetState() { return g_SM_State; }

//+------------------------------------------------------------------+
void SM_Transition(int newState, string reason)
{
    int oldState = g_SM_State;
    if(oldState == newState) return;

    string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
    Print("SM: ", SM_StateName(oldState), " -> ", SM_StateName(newState), " [", reason, "]");

    if(g_SM_TransLogH != INVALID_HANDLE)
        FileWrite(g_SM_TransLogH, ts, SM_StateName(oldState), SM_StateName(newState), reason);

    g_SM_State = newState;

    // Side effect: write snapshot on first launch
    if(newState == SM_SIM_RUNNING && oldState == SM_READY_TO_RUN)
    {
        if(!Persistence_WriteSnapshot())
        {
            SM_Transition(SM_ERROR_STATE, "Snapshot write failed");
            return;
        }
        // Lock config UI fields
        ObjectSetInteger(0, UI_PREFIX+"NEWSIM.EDIT.SYMBOL",       OBJPROP_READONLY, true);
        ObjectSetInteger(0, UI_PREFIX+"NEWSIM.EDIT.BALANCE",      OBJPROP_READONLY, true);
        ObjectSetInteger(0, UI_PREFIX+"NEWSIM.EDIT.START_DATE",   OBJPROP_READONLY, true);
        ObjectSetInteger(0, UI_PREFIX+"NEWSIM.EDIT.END_DATE",     OBJPROP_READONLY, true);

        // Start replay
        int totalBars = iBars(g_CFG_Symbol, PERIOD_D1);
        int startShift = totalBars - 2;
        if(startShift < 1) startShift = 1;
        RE_Start(startShift);

        // Setup trade/stats/reports
        TradeEngine_Init(g_CFG_Balance);
        TradeEngine_SetConfig(
            (SPREAD_MODE)g_CFG_SpreadMode, g_CFG_FixedSpreadPips, g_CFG_CommissionRT,
            20250001, "",
            g_CFG_SLMode, g_CFG_SLPips, g_CFG_ATRMult,
            g_CFG_TPMode, g_CFG_RR, g_CFG_TPATRMult,
            g_CFG_LotMode, g_CFG_RiskPct, g_CFG_FixedLot);
        StatsEngine_Init(g_CFG_Balance);
        ReportExporter_Init(g_CFG_SessionId);
    }

    // Side effect: finish sim
    if(newState == SM_SIM_FINISHED)
    {
        RE_Stop();
        ReportExporter_FlushAll();
        UI_ShowScreen(SCREEN_STATS);
    }
}

//+------------------------------------------------------------------+
// Forward declaration
void TradeEngine_CheckForNaturalClose(string sym);

//+------------------------------------------------------------------+
void SM_OnTick()
{
    // Detect SL/TP closes fired by live price ticks between bar steps
    if(g_SM_State == SM_SIM_RUNNING || g_SM_State == SM_SIM_PAUSED)
        TradeEngine_CheckForNaturalClose(Symbol());
}

//+------------------------------------------------------------------+
void SM_OnTimer(string testerCmd)
{
    // Poll TesterCmd for Strategy Tester fallback
    RE_PollTesterCmd(testerCmd);

    switch(g_SM_State)
    {
        case SM_SIM_RUNNING:
            RE_StepForward();
            break;
        default:
            break;
    }
}

//+------------------------------------------------------------------+
void SM_HandleButtonClick(string objName)
{
    // Reset button state immediately
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);

    // --- LAUNCHER ---
    if(objName == UI_PREFIX+"LAUNCHER.BTN.NEW_SIM")
    {
        SM_Transition(SM_CONFIG_NEW, "UserNewSim");
        UI_ShowScreen(SCREEN_NEWSIM);
        return;
    }
    if(objName == UI_PREFIX+"LAUNCHER.BTN.LOAD_SIM")
    {
        SM_Transition(SM_CONFIG_LOADED, "UserLoadSim");
        Persistence_LoadPreset("last_preset");
        UI_ShowScreen(SCREEN_WORKSPACE);
        return;
    }
    if(objName == UI_PREFIX+"LAUNCHER.BTN.DATA_CENTER")
    {
        UI_ShowScreen(SCREEN_DATACENTER);
        return;
    }

    // --- NEW SIM ---
    if(objName == UI_PREFIX+"NEWSIM.BTN.START")
    {
        UI_NewSimReadFields();
        SM_Transition(SM_WORKSPACE_TWEAK, "UserStartedConfig");
        UI_ShowScreen(SCREEN_WORKSPACE);
        return;
    }
    if(objName == UI_PREFIX+"NEWSIM.BTN.SAVE_PRESET")
    {
        Persistence_SavePresetFromUI();
        return;
    }
    if(objName == UI_PREFIX+"NEWSIM.BTN.LOAD_PRESET")
    {
        Persistence_LoadPresetToUI();
        return;
    }
    if(objName == UI_PREFIX+"NEWSIM.BTN.BACK")
    {
        SM_Transition(SM_IDLE, "UserBack");
        UI_ShowScreen(SCREEN_LAUNCHER);
        return;
    }

    // --- WORKSPACE ---
    if(objName == UI_PREFIX+"WORKSPACE.BTN.VALIDATE")
    {
        UI_WorkspaceValidate();
        return;
    }
    if(objName == UI_PREFIX+"WORKSPACE.BTN.LOCK_LAUNCH")
    {
        UI_WorkspaceReadFields();
        IndEngine_SetConfig(g_CFG_C1Name, g_CFG_C1Params, g_CFG_C1ParamTypes,
                            g_CFG_SigType, g_CFG_FastBuf, g_CFG_SlowBuf,
                            g_CFG_BuyThresh, g_CFG_SellThresh,
                            g_CFG_StateBuyRule, g_CFG_StateSellRule, g_CFG_StateLevel);
        SM_Transition(SM_READY_TO_RUN, "UserLocked");
        SM_Transition(SM_SIM_RUNNING, "AutoLaunch");
        UI_ShowScreen(SCREEN_HUD);
        return;
    }
    if(objName == UI_PREFIX+"WORKSPACE.BTN.BACK")
    {
        SM_Transition(SM_CONFIG_NEW, "UserBackFromWorkspace");
        UI_ShowScreen(SCREEN_NEWSIM);
        return;
    }
    if(StringFind(objName, UI_PREFIX+"WORKSPACE.BTN.SIG_TYPE") >= 0)
    {
        UI_WorkspaceSignalTypeSwitch(objName);
        return;
    }
    if(StringFind(objName, UI_PREFIX+"WORKSPACE.BTN.STATE_RULE") >= 0)
    {
        UI_WorkspaceStateRuleCycle(objName);
        return;
    }

    // --- DATA CENTER ---
    if(objName == UI_PREFIX+"DATACENTER.BTN.BACK")
    {
        UI_ShowScreen(SCREEN_LAUNCHER);
        return;
    }

    // --- HUD ---
    if(objName == UI_PREFIX+"HUD.BTN.PLAY")
    {
        if(g_SM_State == SM_SIM_PAUSED)
        {
            SM_Transition(SM_SIM_RUNNING, "UserPlay");
            RE_Resume();
        }
        return;
    }
    if(objName == UI_PREFIX+"HUD.BTN.PAUSE")
    {
        if(g_SM_State == SM_SIM_RUNNING)
        {
            SM_Transition(SM_SIM_PAUSED, "UserPause");
            RE_Pause();
        }
        return;
    }
    if(objName == UI_PREFIX+"HUD.BTN.NEXT")
    {
        RE_StepForward();
        return;
    }
    if(objName == UI_PREFIX+"HUD.BTN.PREV")
    {
        RE_StepBack();
        return;
    }
    if(objName == UI_PREFIX+"HUD.BTN.SPEED_UP")   { RE_SpeedUp();   return; }
    if(objName == UI_PREFIX+"HUD.BTN.SPEED_DN")   { RE_SpeedDown(); return; }
    if(objName == UI_PREFIX+"HUD.BTN.AUTO_TOGGLE") { UI_HUD_ToggleAuto(); return; }
    if(objName == UI_PREFIX+"HUD.BTN.BUY")         { UI_HUD_ManualBuy();  return; }
    if(objName == UI_PREFIX+"HUD.BTN.SELL")        { UI_HUD_ManualSell(); return; }
    if(objName == UI_PREFIX+"HUD.BTN.CLOSE_ALL")   { UI_HUD_CloseAll();   return; }
    if(objName == UI_PREFIX+"HUD.BTN.STATS")
    {
        UI_ShowScreen(SCREEN_STATS);
        return;
    }

    // --- STATS ---
    if(objName == UI_PREFIX+"STATS.BTN.BACK")
    {
        UI_ShowScreen(SCREEN_HUD);
        return;
    }
    if(objName == UI_PREFIX+"STATS.BTN.EXPORT_TRADES"  ||
       objName == UI_PREFIX+"STATS.BTN.EXPORT_SIGNALS" ||
       objName == UI_PREFIX+"STATS.BTN.EXPORT_SUMMARY")
    {
        ReportExporter_FlushAll();
        return;
    }
    if(StringFind(objName, UI_PREFIX+"STATS.BTN.TAB") >= 0)
    {
        UI_StatsTabSwitch(objName);
        return;
    }
}

//+------------------------------------------------------------------+
void SM_HandleEditEnd(string objName)
{
    // No special handling needed at this time
}

#endif // NNFX_STATE_MACHINE_MQH
