//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Main EA (attach to real D1 chart)            |
//| Bar-by-bar NNFX C1 backtest engine.                              |
//| NNFX Lite Pro 1                                                  |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict

#include <NNFXLite/global_vars.mqh>
#include <NNFXLite/bar_feeder.mqh>
#include <NNFXLite/signal_engine.mqh>
#include <NNFXLite/trade_engine.mqh>
#include <NNFXLite/stats_engine.mqh>
#include <NNFXLite/csv_exporter.mqh>

//+------------------------------------------------------------------+
//| Inputs
//+------------------------------------------------------------------+
extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;      // 1=slowest (2s) … 5=fastest (30ms)
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
int OnInit()
{
    if(DefaultSpeed < 1) DefaultSpeed = 1;
    if(DefaultSpeed > 5) DefaultSpeed = 5;

    //--- Bar feeder (needs offline chart with NNFXLitePanel attached)
    if(!BF_Init(SourceSymbol, SimSymbol, TestStartDate, TestEndDate, DefaultSpeed))
    {
        Print("[NNFXLitePro1] INIT FAILED: bar feeder init failed.");
        return INIT_FAILED;
    }
    Print("[NNFXLitePro1] Bar feeder ready. Bars=", BF_GetTotalBars(),
          " Speed=", BF_GetSpeedLevel(), " (", BF_GetSpeedMs(), "ms)");

    //--- Signal engine
    SE_Init(SimSymbol, C1_IndicatorName, C1_Mode,
            C1_FastBuffer, C1_SlowBuffer,
            C1_SignalBuffer, C1_CrossLevel,
            C1_HistBuffer, C1_HistDualBuffer, C1_HistBuyBuffer, C1_HistSellBuffer,
            C1_ParamValues, C1_ParamTypes);

    //--- Trade engine
    TE_Init(SimSymbol, SourceSymbol,
            ATR_Period, ATR_SL_Multiplier, ATR_TP_Multiplier, RiskPercent);

    //--- Stats engine
    ST_Init(StartingBalance);

    //--- CSV exporter
    if(!CE_Init(SourceSymbol, TestStartDate, TestEndDate))
        Print("[NNFXLitePro1] WARNING: CSV exporter init failed — trades will not be saved.");

    //--- Publish initial state for the panel
    GV_InitAll(StartingBalance, BF_GetTotalBars(), DefaultSpeed);

    //--- Start timer (fires every speedMs; main loop runs while PLAYING)
    EventSetMillisecondTimer(BF_GetSpeedMs());

    Print("[NNFXLitePro1] Ready. Press PLAY on the panel to begin.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    int state = GV_GetInt(NNFXLP_STATE);
    if(state == NNFXLP_STATE_PLAYING || state == NNFXLP_STATE_PAUSED)
    {
        Print("[NNFXLitePro1] EA removed mid-test — finalizing...");
        EndTest();
    }
    GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_STOPPED);
    Print("[NNFXLitePro1] EA deinitialized.");
}

//+------------------------------------------------------------------+
void OnTick() {}

//+------------------------------------------------------------------+
void OnTimer()
{
    //--- Handle any pending panel command first
    int cmd = GV_GetInt(NNFXLP_CMD);
    if(cmd != NNFXLP_CMD_NONE)
    {
        GV_SetInt(NNFXLP_CMD, NNFXLP_CMD_NONE);
        HandleCommand(cmd);
        return;   // don't process a bar in the same tick as a command
    }

    //--- Run one bar if PLAYING
    if(GV_GetInt(NNFXLP_STATE) == NNFXLP_STATE_PLAYING)
        ProcessNextBar();
}

//+------------------------------------------------------------------+
//| Handle a command from the panel
//+------------------------------------------------------------------+
void HandleCommand(int cmd)
{
    switch(cmd)
    {
        case NNFXLP_CMD_PLAY:
            if(GV_GetInt(NNFXLP_STATE) != NNFXLP_STATE_PLAYING)
            {
                GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_PLAYING);
                EventSetMillisecondTimer(BF_GetSpeedMs());
                Print("[NNFXLitePro1] PLAY");
            }
            break;

        case NNFXLP_CMD_PAUSE:
            GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_PAUSED);
            Print("[NNFXLitePro1] PAUSED");
            break;

        case NNFXLP_CMD_STEP:
            if(GV_GetInt(NNFXLP_STATE) == NNFXLP_STATE_PAUSED)
            {
                Print("[NNFXLitePro1] STEP");
                ProcessNextBar();
            }
            break;

        case NNFXLP_CMD_FASTER:
            BF_SetSpeed(BF_GetSpeedLevel() + 1);
            GV_SetInt(NNFXLP_SPEED, BF_GetSpeedLevel());
            EventSetMillisecondTimer(BF_GetSpeedMs());
            Print("[NNFXLitePro1] Speed -> ", BF_GetSpeedLevel(),
                  " (", BF_GetSpeedMs(), "ms)");
            break;

        case NNFXLP_CMD_SLOWER:
            BF_SetSpeed(BF_GetSpeedLevel() - 1);
            GV_SetInt(NNFXLP_SPEED, BF_GetSpeedLevel());
            EventSetMillisecondTimer(BF_GetSpeedMs());
            Print("[NNFXLitePro1] Speed -> ", BF_GetSpeedLevel(),
                  " (", BF_GetSpeedMs(), "ms)");
            break;

        case NNFXLP_CMD_STOP:
            Print("[NNFXLitePro1] STOP — finalizing test.");
            EndTest();
            break;
    }
}

//+------------------------------------------------------------------+
//| Feed one bar and process signals / exits
//+------------------------------------------------------------------+
void ProcessNextBar()
{
    //--- Feed the next bar from the real chart into the HST
    if(!BF_FeedNextBar())
    {
        Print("[NNFXLitePro1] All bars fed — test complete.");
        EndTest();
        return;
    }

    int barNum = BF_GetCurrentBarNum();

    //--- Need at least 2 bars on the sim chart for crossover detection
    if(barNum < 2) return;

    //--- Check exit on open trade (reads bar at shift 1 — just fed)
    if(TE_InTrade())
    {
        int exitResult = TE_CheckExit();
        if(exitResult != 0)
        {
            //  Cache before state clears
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

            GV_SetDouble(NNFXLP_BAL,    ST_GetBalance());
            GV_SetInt(NNFXLP_WINS,      ST_GetWins());
            GV_SetInt(NNFXLP_LOSSES,    ST_GetLosses());
            GV_SetDouble(NNFXLP_PF,     ST_GetProfitFactor());
            GV_SetInt(NNFXLP_TRADE,     0);
            GV_SetDouble(NNFXLP_ENTRY,  0.0);
            GV_SetDouble(NNFXLP_SL,     0.0);
            GV_SetDouble(NNFXLP_TP,     0.0);
        }
    }

    //--- Check for new signal if flat
    if(!TE_InTrade())
    {
        int sig = SE_GetSignal();
        if(sig != 0)
        {
            if(TE_OpenTrade(sig, ST_GetBalance()))
            {
                GV_SetInt(NNFXLP_TRADE,    TE_GetDirection());
                GV_SetDouble(NNFXLP_ENTRY, TE_GetEntry());
                GV_SetDouble(NNFXLP_SL,    TE_GetSL());
                GV_SetDouble(NNFXLP_TP,    TE_GetTP());
            }
        }
    }

    //--- Update progress GVs for the panel
    GV_SetInt(NNFXLP_BAR_CUR,      barNum);
    GV_SetDatetime(NNFXLP_DATE,    BF_GetCurrentDate());
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

        GV_SetDouble(NNFXLP_BAL,   ST_GetBalance());
        GV_SetInt(NNFXLP_WINS,     ST_GetWins());
        GV_SetInt(NNFXLP_LOSSES,   ST_GetLosses());
        GV_SetDouble(NNFXLP_PF,    ST_GetProfitFactor());
        GV_SetInt(NNFXLP_TRADE,    0);
        GV_SetDouble(NNFXLP_ENTRY, 0.0);
        GV_SetDouble(NNFXLP_SL,    0.0);
        GV_SetDouble(NNFXLP_TP,    0.0);
    }

    //--- Write summary CSV
    CE_FinishTest(ST_GetWins(), ST_GetLosses(),
                  StartingBalance, ST_GetBalance(),
                  ST_GetGrossProfit(), ST_GetGrossLoss());

    //--- Mark stopped
    GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_STOPPED);

    Print("[NNFXLitePro1] Test finished.",
          " Trades=", ST_GetTotalTrades(),
          " Wins=", ST_GetWins(),
          " Losses=", ST_GetLosses(),
          " Balance=", DoubleToStr(ST_GetBalance(), 2),
          " PF=", DoubleToStr(ST_GetProfitFactor(), 3));
}
