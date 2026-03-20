//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Main EA (attaches to real chart)             |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict

#include <NNFXLite/global_vars.mqh>

extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;
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
extern string   C1_ParamValues    = "";
extern string   C1_ParamTypes     = "";

int OnInit()
{
    Print("[NNFXLitePro1] EA initialized (stub). Source=", SourceSymbol, " Sim=", SimSymbol);
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
