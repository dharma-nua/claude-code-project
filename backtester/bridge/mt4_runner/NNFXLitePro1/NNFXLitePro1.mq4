//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — TEMPORARY compile stub (Task 2)               |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property version   "2.00"
#property strict

#include <NNFXLite/hst_builder.mqh>
#include <NNFXLite/hud_manager.mqh>

int OnInit()
{
    // Compile check only — functions exist and signatures are correct
    // HST_Build("EURUSD", "EURUSD_SIM");
    // HUD_Create(ChartID());
    // HUD_Update(ChartID(), 0, 100, 0, 10000.0, 3, 0, 0, 0.0, 0, 0.0, 0.0, 0.0);
    // int cmd = HUD_PollButtons(ChartID());
    // HUD_SetState(ChartID(), "Test", clrWhite);
    // HUD_Destroy(ChartID());
    Print("[STUB] hud_manager.mqh compiled OK");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
