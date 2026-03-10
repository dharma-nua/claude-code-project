//+------------------------------------------------------------------+
//|  NNFXSimEA.mq4 — NNFX Sim EA Platform v2 Entry Point            |
//|  Soft4FX-style interactive chart simulator with C1 logic        |
//|  Architecture: chart-object UI, shift-based replay, typed params|
//+------------------------------------------------------------------+
#property strict
#property copyright "NNFX Sim EA v2.0"
#property version   "2.00"
#property description "NNFX Sim EA v2: Interactive D1 simulation with C1 indicator, NNFX SL/TP/MM, stats panel"

//--- TesterCmd fallback input for Strategy Tester
extern string TesterCmd = "";  // PLAY|PAUSE|NEXT|PREV|FASTER|SLOWER|AUTO_ON|AUTO_OFF|CLOSE_ALL

//--- Include order: dependencies first, state machine last
#include <nnfx/persistence.mqh>
#include <nnfx/indicator_engine.mqh>
#include <nnfx/stats_engine.mqh>
#include <nnfx/report_exporter.mqh>
#include <nnfx/trade_engine.mqh>
#include <nnfx/replay_engine.mqh>
#include <nnfx/ui_manager.mqh>
#include <nnfx/state_machine.mqh>

//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== NNFXSimEA v2.0 INIT ===");

    // Generate session ID
    string sessionId = Persistence_GenSessionId();
    Persistence_Init(sessionId);
    g_CFG_SessionId = sessionId;

    // Init subsystems
    IndEngine_Init();
    RE_Init();
    UI_Init();

    // Init state machine (opens transition log)
    SM_Init(sessionId);

    if(!IsTesting())
    {
        // Live chart: show launcher UI
        UI_ShowScreen(SCREEN_LAUNCHER);
        Print("NNFXSimEA: Live chart mode — Launcher shown. Session=", sessionId);
    }
    else
    {
        // Strategy Tester: no UI, auto-run via TesterCmd polling
        Print("NNFXSimEA: Strategy Tester mode — use TesterCmd input to control.");
        Print("NNFXSimEA: Available commands: PLAY PAUSE NEXT PREV FASTER SLOWER AUTO_ON AUTO_OFF CLOSE_ALL");
        // Start in idle; TesterCmd=PLAY will launch
        SM_Transition(SM_CONFIG_NEW, "TesterAutoInit");
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    RE_Stop();
    ReportExporter_FlushAll();
    ReportExporter_Close();
    SM_Deinit();
    Persistence_CloseAll();
    UI_ClearAll();
    Print("=== NNFXSimEA v2.0 DEINIT reason=", reason, " ===");
}

//+------------------------------------------------------------------+
void OnTick()
{
    SM_OnTick();
}

//+------------------------------------------------------------------+
void OnTimer()
{
    SM_OnTimer(TesterCmd);
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Button click
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        SM_HandleButtonClick(sparam);
        return;
    }

    // Edit field confirmed (Enter pressed)
    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        SM_HandleEditEnd(sparam);
        return;
    }

    // Chart resize
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        UI_OnChartResize();
        return;
    }

    // Keyboard hotkeys (live chart only)
    if(id == CHARTEVENT_KEYDOWN && !IsTesting())
    {
        RE_HandleKeyDown(lparam);
        return;
    }
}

//+------------------------------------------------------------------+
