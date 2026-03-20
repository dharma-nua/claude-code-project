//+------------------------------------------------------------------+
//| NNFXLiteSetup.mq4 — Offline symbol creator (script)             |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property show_inputs

extern string SourceSymbol = "EURUSD";
extern bool   ForceReset   = false;

void OnStart()
{
    Print("[NNFXLiteSetup] Script started (stub). Source=", SourceSymbol);
}
