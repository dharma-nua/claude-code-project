//+------------------------------------------------------------------+
//| NNFXLitePanel.mq4 — Control panel + HUD indicator               |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <NNFXLite/global_vars.mqh>

int OnInit()
{
    IndicatorShortName("NNFXLitePanel");
    Print("[NNFXLitePanel] Indicator initialized (stub).");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    Print("[NNFXLitePanel] Indicator deinitialized.");
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    return rates_total;
}
