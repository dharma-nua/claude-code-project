//+------------------------------------------------------------------+
//| replay_engine.mqh — Shift-based bar replay with timer/hotkeys   |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_REPLAY_ENGINE_MQH
#define NNFX_REPLAY_ENGINE_MQH

#define RE_VLINE_OBJ  "NNFX_SIM.RE.VLINE"

// Speed presets in milliseconds
#define RE_SPEED_SLOW   2000
#define RE_SPEED_MEDIUM 1000
#define RE_SPEED_FAST    500
#define RE_SPEED_FASTER  250
#define RE_SPEED_TURBO   100

int    g_RE_CursorShift    = 0;       // Bars back from bar 0
int    g_RE_StartShift     = 0;       // Initial shift when sim started
int    g_RE_MaxShift       = 1000;    // Max bars back allowed
int    g_RE_StepIntervalMs = RE_SPEED_MEDIUM;
bool   g_RE_Running        = false;
bool   g_RE_AutoMode       = false;   // Auto-trade on each step
datetime g_RE_StartTime    = 0;
datetime g_RE_EndTime      = 0;

// Forward declarations
void SM_Transition(int newState, string reason);
void UI_UpdateHUD();
void TradeEngine_OnBar(string sym, int tf, int shift);
void TradeEngine_CheckForNaturalClose(string sym);

//+------------------------------------------------------------------+
void RE_Init()
{
    g_RE_CursorShift    = 0;
    g_RE_Running        = false;
    g_RE_AutoMode       = false;
    g_RE_StepIntervalMs = RE_SPEED_MEDIUM;
}

//+------------------------------------------------------------------+
// Start replay from a given shift (bars back from current bar 0)
void RE_Start(int startShift)
{
    g_RE_CursorShift = startShift;
    g_RE_StartShift  = startShift;
    g_RE_Running     = true;

    // Draw VLine cursor
    string sym = Symbol();
    datetime barTime = iTime(sym, PERIOD_D1, g_RE_CursorShift);
    if(ObjectFind(0, RE_VLINE_OBJ) >= 0)
        ObjectDelete(0, RE_VLINE_OBJ);
    ObjectCreate(0, RE_VLINE_OBJ, OBJ_VLINE, 0, barTime, 0);
    ObjectSetInteger(0, RE_VLINE_OBJ, OBJPROP_COLOR, clrDodgerBlue);
    ObjectSetInteger(0, RE_VLINE_OBJ, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, RE_VLINE_OBJ, OBJPROP_STYLE, STYLE_DASH);

    // Disable chart autoscroll
    ChartSetInteger(0, CHART_AUTOSCROLL, false);

    // Start timer
    EventSetMillisecondTimer(g_RE_StepIntervalMs);

    Print("RE_Start: shift=", startShift, " time=", TimeToString(barTime));
}

//+------------------------------------------------------------------+
void RE_Stop()
{
    g_RE_Running = false;
    EventKillTimer();
    if(ObjectFind(0, RE_VLINE_OBJ) >= 0)
        ObjectDelete(0, RE_VLINE_OBJ);
}

//+------------------------------------------------------------------+
void RE_Pause()
{
    g_RE_Running = false;
    EventKillTimer();
}

//+------------------------------------------------------------------+
void RE_Resume()
{
    g_RE_Running = true;
    EventSetMillisecondTimer(g_RE_StepIntervalMs);
}

//+------------------------------------------------------------------+
void _RE_UpdateVLine()
{
    string sym = Symbol();
    datetime barTime = iTime(sym, PERIOD_D1, g_RE_CursorShift);
    if(barTime == 0) return;

    if(ObjectFind(0, RE_VLINE_OBJ) < 0)
    {
        ObjectCreate(0, RE_VLINE_OBJ, OBJ_VLINE, 0, barTime, 0);
        ObjectSetInteger(0, RE_VLINE_OBJ, OBJPROP_COLOR, clrDodgerBlue);
        ObjectSetInteger(0, RE_VLINE_OBJ, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, RE_VLINE_OBJ, OBJPROP_STYLE, STYLE_DASH);
    }
    else
    {
        ObjectMove(0, RE_VLINE_OBJ, 0, barTime, 0);
    }
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
void RE_StepForward()
{
    if(g_RE_CursorShift <= 1)
    {
        // Reached end
        SM_Transition(7, "ReachedEndOfData");  // SIM_FINISHED=7
        RE_Pause();
        return;
    }

    g_RE_CursorShift--;
    _RE_UpdateVLine();

    // Detect SL/TP closes that fired during the previous bar
    TradeEngine_CheckForNaturalClose(Symbol());

    // Auto-trade
    if(g_RE_AutoMode)
        TradeEngine_OnBar(Symbol(), PERIOD_D1, g_RE_CursorShift);

    UI_UpdateHUD();
}

//+------------------------------------------------------------------+
void RE_StepBack()
{
    if(g_RE_CursorShift >= g_RE_StartShift)
    {
        Print("RE_StepBack: already at start");
        return;
    }
    g_RE_CursorShift++;
    _RE_UpdateVLine();
    UI_UpdateHUD();
}

//+------------------------------------------------------------------+
void RE_SetSpeed(int ms)
{
    g_RE_StepIntervalMs = ms;
    if(g_RE_Running)
    {
        EventKillTimer();
        EventSetMillisecondTimer(g_RE_StepIntervalMs);
    }
}

//+------------------------------------------------------------------+
void RE_SpeedUp()
{
    if(g_RE_StepIntervalMs > RE_SPEED_TURBO)
    {
        if(g_RE_StepIntervalMs >= RE_SPEED_SLOW)   RE_SetSpeed(RE_SPEED_MEDIUM);
        else if(g_RE_StepIntervalMs >= RE_SPEED_MEDIUM) RE_SetSpeed(RE_SPEED_FAST);
        else if(g_RE_StepIntervalMs >= RE_SPEED_FAST)   RE_SetSpeed(RE_SPEED_FASTER);
        else                                             RE_SetSpeed(RE_SPEED_TURBO);
    }
}

//+------------------------------------------------------------------+
void RE_SpeedDown()
{
    if(g_RE_StepIntervalMs < RE_SPEED_SLOW)
    {
        if(g_RE_StepIntervalMs <= RE_SPEED_TURBO)  RE_SetSpeed(RE_SPEED_FASTER);
        else if(g_RE_StepIntervalMs <= RE_SPEED_FASTER) RE_SetSpeed(RE_SPEED_FAST);
        else if(g_RE_StepIntervalMs <= RE_SPEED_FAST)   RE_SetSpeed(RE_SPEED_MEDIUM);
        else                                             RE_SetSpeed(RE_SPEED_SLOW);
    }
}

//+------------------------------------------------------------------+
void RE_ToggleAuto()
{
    g_RE_AutoMode = !g_RE_AutoMode;
    Print("RE_ToggleAuto: autoMode=", g_RE_AutoMode);
}

//+------------------------------------------------------------------+
datetime RE_GetCurrentTime()
{
    return iTime(Symbol(), PERIOD_D1, g_RE_CursorShift);
}

//+------------------------------------------------------------------+
int RE_GetCurrentShift() { return g_RE_CursorShift; }

//+------------------------------------------------------------------+
// Keyboard hotkey handler — call from OnChartEvent CHARTEVENT_KEYDOWN
void RE_HandleKeyDown(long key)
{
    // Space = 32 = play/pause toggle
    if(key == 32)
    {
        if(g_RE_Running)
        {
            SM_Transition(6, "KeySpace:Pause");  // SIM_PAUSED=6
            RE_Pause();
        }
        else
        {
            SM_Transition(5, "KeySpace:Play");   // SIM_RUNNING=5
            RE_Resume();
        }
        return;
    }
    // Right arrow = 39 = next bar
    if(key == 39) { RE_StepForward(); return; }
    // Left arrow = 37 = prev bar
    if(key == 37) { RE_StepBack(); return; }
    // + = 107 or 187 = speed up
    if(key == 107 || key == 187) { RE_SpeedUp(); return; }
    // - = 109 or 189 = speed down
    if(key == 109 || key == 189) { RE_SpeedDown(); return; }
    // A = 65 = auto toggle
    if(key == 65) { RE_ToggleAuto(); return; }
    // X = 88 = close all
    if(key == 88) { TradeEngine_CloseAll(Symbol()); return; }
}

//+------------------------------------------------------------------+
// Poll TesterCmd from OnTimer
string g_RE_LastTesterCmd = "";

void RE_PollTesterCmd(string cmd)
{
    if(cmd == "" || cmd == g_RE_LastTesterCmd) return;
    g_RE_LastTesterCmd = cmd;

    if(cmd == "PLAY")
    {
        SM_Transition(5, "TesterCmd:PLAY");
        RE_Resume();
    }
    else if(cmd == "PAUSE")
    {
        SM_Transition(6, "TesterCmd:PAUSE");
        RE_Pause();
    }
    else if(cmd == "NEXT")   { RE_StepForward(); }
    else if(cmd == "PREV")   { RE_StepBack(); }
    else if(cmd == "FASTER") { RE_SpeedUp(); }
    else if(cmd == "SLOWER") { RE_SpeedDown(); }
    else if(cmd == "AUTO_ON")  { g_RE_AutoMode = true; }
    else if(cmd == "AUTO_OFF") { g_RE_AutoMode = false; }
    else if(cmd == "CLOSE_ALL") { TradeEngine_CloseAll(Symbol()); }
}

#endif // NNFX_REPLAY_ENGINE_MQH
