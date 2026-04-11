//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Single-EA NNFX C1 backtester (v2)            |
//| Drag onto any live chart → launcher → Start → sim runs.          |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Includes
//+------------------------------------------------------------------+
#include <NNFXLite/hst_builder.mqh>
#include <NNFXLite/bar_feeder.mqh>
#include <NNFXLite/signal_engine.mqh>
#include <NNFXLite/trade_engine.mqh>
#include <NNFXLite/stats_engine.mqh>
#include <NNFXLite/csv_exporter.mqh>
#include <NNFXLite/hud_manager.mqh>
#include <NNFXLite/launcher.mqh>

//+------------------------------------------------------------------+
//| State constants
//+------------------------------------------------------------------+
#define STATE_LAUNCHER    0
#define STATE_STARTING    1
#define STATE_WAIT_CHART  2
#define STATE_PLAYING     3
#define STATE_PAUSED      4
#define STATE_STOPPED     5

//+------------------------------------------------------------------+
//| Inputs
//+------------------------------------------------------------------+
extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;      // 1=slowest (2s) ... 5=fastest (30ms)
extern double   RiskPercent       = 0.02;
extern int      ATR_Period        = 14;
extern double   ATR_SL_Multiplier = 1.5;
extern double   ATR_TP_Multiplier = 1.0;
extern string   C1_IndicatorName  = "";
extern int      C1_Mode           = 0;     // 0=TwoLine 1=ZeroLine 2=Histogram
extern int      C1_FastBuffer     = 0;
extern int      C1_SlowBuffer     = 1;
extern int      C1_SignalBuffer   = 0;
extern double   C1_CrossLevel     = 0.0;
extern int      C1_HistBuffer     = 0;
extern bool     C1_HistDualBuffer = false;
extern int      C1_HistBuyBuffer  = 0;
extern int      C1_HistSellBuffer = 1;
extern string   C1_ParamValues    = "";    // e.g. "14,0.5,true"
extern string   C1_ParamTypes     = "";    // e.g. "int,double,bool"

//+------------------------------------------------------------------+
//| Global state
//+------------------------------------------------------------------+
int    g_State;
long   g_HostChartId;
long   g_SimChartId;
uint   g_LastBarTime;
bool   g_HstBuilt;        // true after HST_Build succeeds
int    g_ChartRetries;     // ChartOpen retry counter

// Config read from launcher (may override externs)
string   g_Pair;
datetime g_StartDate;
datetime g_EndDate;
double   g_Balance;

//+------------------------------------------------------------------+
int OnInit()
{
    if(DefaultSpeed < 1) DefaultSpeed = 1;
    if(DefaultSpeed > 5) DefaultSpeed = 5;

    g_HostChartId = ChartID();
    g_SimChartId  = 0;
    g_State       = STATE_LAUNCHER;

    LAUNCH_Create(SourceSymbol, TestStartDate, TestEndDate, StartingBalance);

    EventSetMillisecondTimer(200);

    Print("[NNFXLitePro1] v2 — Launcher ready. Configure and click START.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();

    if(g_State == STATE_PLAYING || g_State == STATE_PAUSED)
    {
        Print("[NNFXLitePro1] EA removed mid-sim — finalizing...");
        EndTest();
    }

    HUD_Destroy(g_SimChartId);
    LAUNCH_Destroy();

    Print("[NNFXLitePro1] EA deinitialized.");
}

//+------------------------------------------------------------------+
void OnTick() {}

//+------------------------------------------------------------------+
void OnTimer()
{
    switch(g_State)
    {
        case STATE_LAUNCHER:
            OnTimer_Launcher();
            break;
        case STATE_STARTING:
            OnTimer_Starting();
            break;
        case STATE_WAIT_CHART:
            OnTimer_WaitChart();
            break;
        case STATE_PLAYING:
            OnTimer_Playing();
            break;
        case STATE_PAUSED:
            OnTimer_Paused();
            break;
        // STATE_STOPPED: do nothing, timer should be killed
    }
}

//+------------------------------------------------------------------+
//| LAUNCHER state: poll Start button
//+------------------------------------------------------------------+
void OnTimer_Launcher()
{
    if(!LAUNCH_PollStartButton())
        return;

    // Read config from launcher fields
    if(!LAUNCH_ReadConfig(g_Pair, g_StartDate, g_EndDate, g_Balance))
    {
        Print("[NNFXLitePro1] Config validation failed — staying on launcher.");
        return;
    }

    Print("[NNFXLitePro1] Start clicked. Initializing sim...");
    g_HstBuilt     = false;
    g_ChartRetries = 0;
    g_State        = STATE_STARTING;
}

//+------------------------------------------------------------------+
//| STARTING state: build HST, then transition to WAIT_CHART
//+------------------------------------------------------------------+
void OnTimer_Starting()
{
    string simSymbol = g_Pair + "_SIM";

    //--- Build HST file
    if(!HST_Build(g_Pair, simSymbol))
    {
        Print("[NNFXLitePro1] ERROR: HST build failed. Returning to launcher.");
        LAUNCH_Create(SourceSymbol, TestStartDate, TestEndDate, StartingBalance);
        g_State = STATE_LAUNCHER;
        return;
    }

    //--- Update launcher to show instructions
    LAUNCH_Destroy();
    LAUNCH_Label(LAUNCH_LBL_TITLE, LAUNCH_X, LAUNCH_Y_TITLE,
                 "Open the offline chart:", clrGold, 12);
    LAUNCH_Label(LAUNCH_LBL_PAIR, LAUNCH_X, LAUNCH_Y_FIRST,
                 "File > Open Offline", clrWhite, 10);
    LAUNCH_Label(LAUNCH_LBL_START, LAUNCH_X, LAUNCH_Y_FIRST + LAUNCH_ROW_H,
                 "Select: " + simSymbol + ", D1", clrWhite, 10);
    LAUNCH_Label(LAUNCH_LBL_END, LAUNCH_X, LAUNCH_Y_FIRST + LAUNCH_ROW_H * 2,
                 "Click Open", clrWhite, 10);
    LAUNCH_Label(LAUNCH_LBL_BAL, LAUNCH_X, LAUNCH_Y_FIRST + LAUNCH_ROW_H * 3,
                 "Waiting for chart...", clrYellow, 10);
    ChartRedraw(g_HostChartId);

    Print("[NNFXLitePro1] HST built. Please open offline chart: ",
          "File > Open Offline > ", simSymbol, " D1");

    g_ChartRetries = 0;
    g_State = STATE_WAIT_CHART;
}

//+------------------------------------------------------------------+
//| WAIT_CHART state: scan for offline chart, init engines when found
//+------------------------------------------------------------------+
void OnTimer_WaitChart()
{
    string simSymbol = g_Pair + "_SIM";

    //--- Scan all open charts for our sim symbol
    long chartId = ChartFirst();
    while(chartId >= 0)
    {
        if(ChartSymbol(chartId) == simSymbol && chartId != g_HostChartId)
        {
            g_SimChartId = chartId;
            Print("[NNFXLitePro1] Found offline chart! ID=", g_SimChartId);
            InitEnginesAndPlay(simSymbol);
            return;
        }
        chartId = ChartNext(chartId);
    }

    //--- Not found yet — log periodically
    g_ChartRetries++;
    if(g_ChartRetries % 25 == 0)  // every ~5 seconds
    {
        Print("[NNFXLitePro1] Still waiting for offline chart ",
              simSymbol, " ... (", g_ChartRetries * 200 / 1000, "s)");
    }
}

//+------------------------------------------------------------------+
//| Init all engines and transition to PLAYING
//+------------------------------------------------------------------+
void InitEnginesAndPlay(string simSymbol)
{
    //--- Bring sim chart to front
    ChartSetInteger(g_HostChartId, CHART_BRING_TO_TOP, false);
    ChartSetInteger(g_SimChartId,  CHART_BRING_TO_TOP, true);

    //--- Remove instructions from host chart
    LAUNCH_Destroy();

    //--- Draw HUD on offline chart
    HUD_Create(g_SimChartId);

    //--- Init bar feeder
    if(!BF_Init(g_Pair, simSymbol, g_StartDate, g_EndDate, DefaultSpeed))
    {
        Print("[NNFXLitePro1] ERROR: Bar feeder init failed.");
        HUD_Destroy(g_SimChartId);
        g_SimChartId = 0;
        LAUNCH_Create(SourceSymbol, TestStartDate, TestEndDate, StartingBalance);
        g_State = STATE_LAUNCHER;
        return;
    }
    Print("[NNFXLitePro1] Bar feeder ready. Bars=", BF_GetTotalBars(),
          " Speed=", BF_GetSpeedLevel(), " (", BF_GetSpeedMs(), "ms)");

    //--- Init signal engine
    SE_Init(simSymbol, C1_IndicatorName, C1_Mode,
            C1_FastBuffer, C1_SlowBuffer,
            C1_SignalBuffer, C1_CrossLevel,
            C1_HistBuffer, C1_HistDualBuffer, C1_HistBuyBuffer, C1_HistSellBuffer,
            C1_ParamValues, C1_ParamTypes);

    //--- Init trade engine
    TE_Init(simSymbol, g_Pair,
            ATR_Period, ATR_SL_Multiplier, ATR_TP_Multiplier, RiskPercent);

    //--- Init stats engine
    ST_Init(g_Balance);

    //--- Init CSV exporter
    if(!CE_Init(g_Pair, g_StartDate, g_EndDate))
        Print("[NNFXLitePro1] WARNING: CSV exporter init failed.");

    //--- Go to PLAYING — auto-play
    g_LastBarTime = GetTickCount();
    g_State = STATE_PLAYING;

    HUD_SetState(g_SimChartId, "State: PLAYING", clrLimeGreen);

    Print("[NNFXLitePro1] Sim started. Auto-playing.");
}

//+------------------------------------------------------------------+
//| PLAYING state: poll buttons + feed bars
//+------------------------------------------------------------------+
void OnTimer_Playing()
{
    //--- Poll HUD buttons
    int cmd = HUD_PollButtons(g_SimChartId);
    if(cmd != HUD_CMD_NONE)
    {
        HandleCommand(cmd);
        if(g_State != STATE_PLAYING) return;
    }

    //--- Feed bars based on elapsed time
    uint now = GetTickCount();
    uint elapsed = now - g_LastBarTime;
    int speedMs = BF_GetSpeedMs();

    if(elapsed < (uint)speedMs) return;

    int barsToFeed = (int)(elapsed / speedMs);
    if(barsToFeed < 1) barsToFeed = 1;
    if(barsToFeed > 10) barsToFeed = 10;  // cap to avoid stalls

    for(int i = 0; i < barsToFeed; i++)
    {
        ProcessNextBar();
        if(g_State != STATE_PLAYING) break;  // EndTest may have changed state
    }

    g_LastBarTime = GetTickCount();
}

//+------------------------------------------------------------------+
//| PAUSED state: poll buttons only
//+------------------------------------------------------------------+
void OnTimer_Paused()
{
    int cmd = HUD_PollButtons(g_SimChartId);
    if(cmd != HUD_CMD_NONE)
        HandleCommand(cmd);
}

//+------------------------------------------------------------------+
//| Handle a command from HUD button polling
//+------------------------------------------------------------------+
void HandleCommand(int cmd)
{
    switch(cmd)
    {
        case HUD_CMD_RESUME:
            if(g_State == STATE_PAUSED)
            {
                g_State = STATE_PLAYING;
                g_LastBarTime = GetTickCount();
                HUD_SetState(g_SimChartId, "State: PLAYING", clrLimeGreen);
                Print("[NNFXLitePro1] RESUMED");
            }
            break;

        case HUD_CMD_PAUSE:
            if(g_State == STATE_PLAYING)
            {
                g_State = STATE_PAUSED;
                HUD_SetState(g_SimChartId, "State: PAUSED", clrYellow);
                Print("[NNFXLitePro1] PAUSED");
            }
            break;

        case HUD_CMD_STEP:
            if(g_State == STATE_PAUSED)
            {
                Print("[NNFXLitePro1] STEP");
                ProcessNextBar();
            }
            break;

        case HUD_CMD_FASTER:
            BF_SetSpeed(BF_GetSpeedLevel() + 1);
            Print("[NNFXLitePro1] Speed -> ", BF_GetSpeedLevel(),
                  " (", BF_GetSpeedMs(), "ms)");
            break;

        case HUD_CMD_SLOWER:
            BF_SetSpeed(BF_GetSpeedLevel() - 1);
            Print("[NNFXLitePro1] Speed -> ", BF_GetSpeedLevel(),
                  " (", BF_GetSpeedMs(), "ms)");
            break;

        case HUD_CMD_STOP:
            Print("[NNFXLitePro1] STOP — finalizing sim.");
            EndTest();
            break;
    }
}

//+------------------------------------------------------------------+
//| Feed one bar and process signals / exits
//+------------------------------------------------------------------+
void ProcessNextBar()
{
    if(!BF_FeedNextBar())
    {
        Print("[NNFXLitePro1] All bars fed — sim complete.");
        EndTest();
        return;
    }

    // Refresh offline chart to show the new bar
    string simSymbol = g_Pair + "_SIM";
    ChartSetSymbolPeriod(g_SimChartId, simSymbol, PERIOD_D1);

    int barNum = BF_GetCurrentBarNum();

    // Need at least 2 bars for crossover detection
    if(barNum < 2)
    {
        // Still update HUD with progress
        HUD_Update(g_SimChartId, barNum, BF_GetTotalBars(),
                   BF_GetCurrentDate(), ST_GetBalance(), BF_GetSpeedLevel(),
                   ST_GetWins(), ST_GetLosses(), ST_GetProfitFactor(),
                   0, 0.0, 0.0, 0.0);
        return;
    }

    //--- Check exit on open trade
    if(TE_InTrade())
    {
        int exitResult = TE_CheckExit();
        if(exitResult != 0)
        {
            int    dir   = TE_GetDirection();
            double entry = TE_GetEntry();
            double sl    = TE_GetSL();
            double tp    = TE_GetTP();
            double lots  = TE_GetLotSize();
            double pnl   = TE_GetLastPnL();
            string reason = (exitResult > 0 ? "TP" : "SL");

            ST_AddTrade(exitResult, pnl);
            CE_WriteTrade(barNum, BF_GetCurrentDate(),
                          dir, entry, sl, tp, reason,
                          lots, pnl, ST_GetBalance());
        }
    }

    //--- Check for new signal if flat
    if(!TE_InTrade())
    {
        int sig = SE_GetSignal();
        if(sig != 0)
            TE_OpenTrade(sig, ST_GetBalance());
    }

    //--- Update HUD
    HUD_Update(g_SimChartId, barNum, BF_GetTotalBars(),
               BF_GetCurrentDate(), ST_GetBalance(), BF_GetSpeedLevel(),
               ST_GetWins(), ST_GetLosses(), ST_GetProfitFactor(),
               TE_InTrade() ? TE_GetDirection() : 0,
               TE_InTrade() ? TE_GetEntry() : 0.0,
               TE_InTrade() ? TE_GetSL() : 0.0,
               TE_InTrade() ? TE_GetTP() : 0.0);
}

//+------------------------------------------------------------------+
//| Finalize: force-close open trade, write CSVs, mark stopped
//+------------------------------------------------------------------+
void EndTest()
{
    //--- Force-close any open trade
    if(TE_InTrade())
    {
        int    dir   = TE_GetDirection();
        double entry = TE_GetEntry();
        double sl    = TE_GetSL();
        double tp    = TE_GetTP();
        double lots  = TE_GetLotSize();

        TE_ForceClose();
        double pnl = TE_GetLastPnL();
        ST_AddTrade((pnl >= 0.0 ? 1 : -1), pnl);
        CE_WriteTrade(BF_GetCurrentBarNum(), BF_GetCurrentDate(),
                      dir, entry, sl, tp, "CLOSE",
                      lots, pnl, ST_GetBalance());
    }

    //--- Write summary CSV
    CE_FinishTest(ST_GetWins(), ST_GetLosses(),
                  g_Balance, ST_GetBalance(),
                  ST_GetGrossProfit(), ST_GetGrossLoss());

    //--- Mark stopped
    g_State = STATE_STOPPED;
    EventKillTimer();

    HUD_SetState(g_SimChartId, "State: STOPPED", clrDimGray);

    Print("[NNFXLitePro1] Sim finished.",
          " Trades=", ST_GetTotalTrades(),
          " Wins=", ST_GetWins(),
          " Losses=", ST_GetLosses(),
          " Balance=", DoubleToStr(ST_GetBalance(), 2),
          " PF=", DoubleToStr(ST_GetProfitFactor(), 3));
}
