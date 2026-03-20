//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Main EA (attaches to real chart)             |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict

#include <NNFXLite/global_vars.mqh>
#include <NNFXLite/bar_feeder.mqh>
#include <NNFXLite/signal_engine.mqh>

extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;  // Speed level 1-5 (1=slowest 2s/bar, 5=fastest 30ms/bar)
extern double   RiskPercent       = 0.02;
extern int      ATR_Period        = 14;
extern double   ATR_SL_Multiplier = 1.5;
extern double   ATR_TP_Multiplier = 1.0;
extern string   C1_IndicatorName  = "";
extern int      C1_Mode           = 0;
extern int      C1_FastBuffer     = 0;
extern int      C1_SlowBuffer     = 1;
extern int      C1_SignalBuffer   = 0;
extern double   C1_CrossLevel     = 0.0;
extern int      C1_HistBuffer     = 0;
extern bool     C1_HistDualBuffer = false;
extern int      C1_HistBuyBuffer  = 0;
extern int      C1_HistSellBuffer = 1;
extern string   C1_ParamValues    = "";  // comma-separated values: e.g. "14,0.5,true"
extern string   C1_ParamTypes     = "";  // comma-separated types:  e.g. "int,double,bool"

int OnInit()
{
    if(DefaultSpeed < 1) DefaultSpeed = 1;
    if(DefaultSpeed > 5) DefaultSpeed = 5;
    Print("[NNFXLitePro1] EA initialized (stub). Source=", SourceSymbol, " Sim=", SimSymbol);

    if(!BF_Init(SourceSymbol, SimSymbol, TestStartDate, TestEndDate, DefaultSpeed))
    {
        Print("[NNFXLitePro1] INIT FAILED: bar feeder init failed.");
        return INIT_FAILED;
    }
    Print("[NNFXLitePro1] Bar feeder ready. Total bars=", BF_GetTotalBars(),
          " Speed=", BF_GetSpeedLevel(), " (", BF_GetSpeedMs(), "ms)");

    SE_Init(SimSymbol, C1_IndicatorName, C1_Mode,
            C1_FastBuffer, C1_SlowBuffer,
            C1_SignalBuffer, C1_CrossLevel,
            C1_HistBuffer, C1_HistDualBuffer, C1_HistBuyBuffer, C1_HistSellBuffer,
            C1_ParamValues, C1_ParamTypes);

    // TEMP TEST: Feed 30 bars and check signals
    for(int i = 0; i < 30; i++)
    {
        if(!BF_FeedNextBar()) break;
        if(i < 2) continue; // need at least 2 bars for crossover detection
        int sig = SE_GetSignal();
        if(sig != 0)
            Print("[TEST] Bar ", i+1, " Signal=", (sig > 0 ? "BUY" : "SELL"));
    }
    // END TEMP TEST

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    Print("[NNFXLitePro1] EA deinitialized.");
}

void OnTick() {}

void OnTimer()
{
    // Main loop — wired in Task 9.
}
