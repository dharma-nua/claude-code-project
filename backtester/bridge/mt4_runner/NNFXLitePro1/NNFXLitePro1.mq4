//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — TEMPORARY compile stub (Task 1)               |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property version   "2.00"
#property strict

#include <NNFXLite/hst_builder.mqh>

int OnInit()
{
    bool ok = HST_Build("EURUSD", "EURUSD_SIM");
    Print("[STUB] HST_Build returned: ", ok);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
