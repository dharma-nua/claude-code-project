//+------------------------------------------------------------------+
//| trade_engine.mqh — Virtual paper trade engine (no real orders)  |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_TRADE_ENGINE_MQH
#define NNFX_TRADE_ENGINE_MQH

//+------------------------------------------------------------------+
enum SPREAD_MODE { SPREAD_FIXED_PIPS=0, SPREAD_CURRENT_MARKET=1 };

#define TE_SL_FIXED  0
#define TE_SL_ATR    1
#define TE_TP_RR     0
#define TE_TP_ATR    1
#define TE_LOT_FIXED 0
#define TE_LOT_RISK  1

//--- Config
SPREAD_MODE g_TE_SpreadMode      = SPREAD_FIXED_PIPS;
double      g_TE_FixedSpreadPips = 2.0;
double      g_TE_CommissionRT    = 0.0;
int         g_TE_SLMode          = TE_SL_ATR;
double      g_TE_SLPips          = 100.0;
double      g_TE_ATRMult         = 1.5;
int         g_TE_TPMode          = TE_TP_RR;
double      g_TE_RR              = 1.5;
double      g_TE_TPATRMult       = 2.0;
int         g_TE_LotMode         = TE_LOT_RISK;
double      g_TE_RiskPct         = 1.0;
double      g_TE_FixedLot        = 0.01;

//--- Virtual position (one position at a time)
bool     g_VT_IsOpen      = false;
int      g_VT_TicketSeq   = 0;
int      g_VT_Type        = -1;
double   g_VT_Lots        = 0.0;
double   g_VT_EntryPrice  = 0.0;
double   g_VT_SLPrice     = 0.0;
double   g_VT_TPPrice     = 0.0;
double   g_VT_SLPips      = 0.0;
double   g_VT_TPPips      = 0.0;
double   g_VT_SpreadPips  = 0.0;
datetime g_VT_EntryTime   = 0;

//--- Sim balance
double g_TE_SimBalance  = 10000.0;
double g_TE_PeakBalance = 10000.0;
double g_TE_MaxDD       = 0.0;

//--- Current sim bar shift (kept in sync by replay engine)
int g_TE_CurrentShift = 1;

//--- Compatibility aliases read by ui_manager / stats display
int    g_TE_OpenTicket     = -1;
int    g_TE_OpenType       = -1;
double g_TE_OpenLots       = 0.0;
double g_TE_OpenEntryPrice = 0.0;
double g_TE_OpenSLPips     = 0.0;
double g_TE_OpenTPPips     = 0.0;
double g_TE_OpenSpreadPips = 0.0;

//+------------------------------------------------------------------+
void TradeEngine_Init(double startBalance)
{
    g_TE_SimBalance   = startBalance;
    g_TE_PeakBalance  = startBalance;
    g_TE_MaxDD        = 0.0;
    g_VT_IsOpen       = false;
    g_VT_TicketSeq    = 0;
    g_TE_OpenTicket   = -1;
    g_TE_OpenType     = -1;
    g_TE_OpenLots     = 0.0;
    g_TE_CurrentShift = 1;
}

//+------------------------------------------------------------------+
void TradeEngine_SetConfig(SPREAD_MODE spreadMode, double fixedSpreadPips,
                            double commissionRT, int magic,
                            string allowedSymbols,
                            int slMode, double slPips, double atrMult,
                            int tpMode, double rr, double tpAtrMult,
                            int lotMode, double riskPct, double fixedLot)
{
    g_TE_SpreadMode      = spreadMode;
    g_TE_FixedSpreadPips = fixedSpreadPips;
    g_TE_CommissionRT    = commissionRT;
    g_TE_SLMode          = slMode;
    g_TE_SLPips          = slPips;
    g_TE_ATRMult         = atrMult;
    g_TE_TPMode          = tpMode;
    g_TE_RR              = rr;
    g_TE_TPATRMult       = tpAtrMult;
    g_TE_LotMode         = lotMode;
    g_TE_RiskPct         = riskPct;
    g_TE_FixedLot        = fixedLot;
}

//+------------------------------------------------------------------+
// Called by replay engine each bar step to keep current shift in sync
void TradeEngine_SetSimShift(int shift) { g_TE_CurrentShift = shift; }

//+------------------------------------------------------------------+
double _TE_PipSize(string sym)
{
    int d = (int)MarketInfo(sym, MODE_DIGITS);
    return (d == 3 || d == 5) ? Point * 10.0 : Point;
}

//+------------------------------------------------------------------+
double TradeEngine_GetSpreadPips(string sym)
{
    if(g_TE_SpreadMode == SPREAD_FIXED_PIPS)
        return g_TE_FixedSpreadPips;
    double spread = MarketInfo(sym, MODE_SPREAD);
    int d = (int)MarketInfo(sym, MODE_DIGITS);
    return (d == 3 || d == 5) ? spread / 10.0 : spread;
}

//+------------------------------------------------------------------+
bool TradeEngine_HasOpenPos(string sym) { return g_VT_IsOpen; }

//+------------------------------------------------------------------+
bool _TE_CalcSLTP(string sym, double &slPips, double &tpPips,
                   double &slDist, double &tpDist, string &reason)
{
    double pipSize = _TE_PipSize(sym);
    double atr     = iATR(sym, PERIOD_D1, 14, g_TE_CurrentShift + 1);

    if(g_TE_SLMode == TE_SL_ATR)
    {
        if(atr == 0 || atr == EMPTY_VALUE || !MathIsValidNumber(atr))
        { reason = "ATR invalid"; return false; }
        slDist = atr * g_TE_ATRMult;
        slPips = slDist / pipSize;
    }
    else
    {
        slPips = g_TE_SLPips;
        slDist = slPips * pipSize;
    }

    if(g_TE_TPMode == TE_TP_ATR)
    {
        if(atr == 0 || atr == EMPTY_VALUE || !MathIsValidNumber(atr))
        { reason = "ATR invalid (TP)"; return false; }
        tpDist = atr * g_TE_TPATRMult;
        tpPips = tpDist / pipSize;
    }
    else
    {
        tpPips = slPips * g_TE_RR;
        tpDist = tpPips * pipSize;
    }
    return true;
}

//+------------------------------------------------------------------+
bool _TE_CalcLots(string sym, double slPips, double &lots, string &reason)
{
    if(g_TE_LotMode == TE_LOT_FIXED)
    { lots = g_TE_FixedLot; return true; }

    double pipValue = MarketInfo(sym, MODE_TICKVALUE);
    int d = (int)MarketInfo(sym, MODE_DIGITS);
    if(d == 3 || d == 5) pipValue *= 10.0;
    if(pipValue == 0) { reason = "pipValue=0"; return false; }

    double riskMoney = g_TE_SimBalance * g_TE_RiskPct / 100.0;
    double rawLots   = riskMoney / (slPips * pipValue);

    double minLot  = MarketInfo(sym, MODE_MINLOT);
    double maxLot  = MarketInfo(sym, MODE_MAXLOT);
    double lotStep = MarketInfo(sym, MODE_LOTSTEP);
    if(lotStep <= 0) lotStep = 0.01;

    lots = MathFloor(rawLots / lotStep) * lotStep;
    lots = NormalizeDouble(lots, 2);
    lots = MathMax(minLot, MathMin(maxLot, lots));
    if(lots < minLot) { reason = StringFormat("Lot too small: %.5f", lots); return false; }
    return true;
}

//+------------------------------------------------------------------+
// Internal: open virtual position
void _VT_Open(string sym, int dir, double entryPrice,
               double slPips, double tpPips,
               double slPrice, double tpPrice,
               double lots, double spreadPips)
{
    g_VT_TicketSeq++;
    g_VT_IsOpen     = true;
    g_VT_Type       = dir;
    g_VT_Lots       = lots;
    g_VT_EntryPrice = entryPrice;
    g_VT_SLPrice    = slPrice;
    g_VT_TPPrice    = tpPrice;
    g_VT_SLPips     = slPips;
    g_VT_TPPips     = tpPips;
    g_VT_SpreadPips = spreadPips;
    g_VT_EntryTime  = iTime(sym, PERIOD_D1, g_TE_CurrentShift);

    g_TE_OpenTicket     = g_VT_TicketSeq;
    g_TE_OpenType       = dir;
    g_TE_OpenLots       = lots;
    g_TE_OpenEntryPrice = entryPrice;
    g_TE_OpenSLPips     = slPips;
    g_TE_OpenTPPips     = tpPips;
    g_TE_OpenSpreadPips = spreadPips;

    StatsEngine_OnTradeOpen(g_VT_TicketSeq, dir, lots, entryPrice,
                             slPips, tpPips, spreadPips, g_VT_EntryTime);
    ReportExporter_WriteTradeRow("OPEN", g_VT_TicketSeq, dir, lots, entryPrice,
                                  slPrice, tpPrice, slPips, tpPips, spreadPips, 0.0);

    Print(StringFormat("VT Open: %s ticket=%d lots=%.2f entry=%.5f SL=%.5f TP=%.5f spread=%.1fpips",
          dir == OP_BUY ? "BUY" : "SELL", g_VT_TicketSeq, lots, entryPrice, slPrice, tpPrice, spreadPips));
}

//+------------------------------------------------------------------+
// Internal: close virtual position at a given price
void _VT_Close(string sym, double closePrice, string reason)
{
    if(!g_VT_IsOpen) return;

    datetime closeTime = iTime(sym, PERIOD_D1, g_TE_CurrentShift);
    double   pipSize   = _TE_PipSize(sym);
    int      d         = (int)MarketInfo(sym, MODE_DIGITS);

    double pnlPips = (g_VT_Type == OP_BUY)
                   ? (closePrice - g_VT_EntryPrice) / pipSize
                   : (g_VT_EntryPrice - closePrice) / pipSize;

    double pipValue  = MarketInfo(sym, MODE_TICKVALUE);
    if(d == 3 || d == 5) pipValue *= 10.0;
    double commission = (g_TE_CommissionRT > 0 && pipValue > 0)
                      ? g_TE_CommissionRT * g_VT_Lots : 0.0;

    double pnlMoney = pnlPips * pipValue * g_VT_Lots - commission;
    g_TE_SimBalance += pnlMoney;
    if(g_TE_SimBalance > g_TE_PeakBalance) g_TE_PeakBalance = g_TE_SimBalance;
    double dd = (g_TE_PeakBalance > 0)
              ? (g_TE_PeakBalance - g_TE_SimBalance) / g_TE_PeakBalance * 100.0 : 0.0;
    if(dd > g_TE_MaxDD) g_TE_MaxDD = dd;
    StatsEngine_SetMaxDD(g_TE_MaxDD);

    StatsEngine_OnTradeClose(g_VT_TicketSeq, closePrice, pnlPips,
                              g_VT_SpreadPips, commission, closeTime, reason);
    ReportExporter_WriteTradeRow("CLOSE", g_VT_TicketSeq, g_VT_Type, g_VT_Lots,
                                  closePrice, g_VT_SLPrice, g_VT_TPPrice,
                                  0, 0, g_VT_SpreadPips, commission);

    Print(StringFormat("VT Close: ticket=%d reason=%s price=%.5f pnlPips=%.2f pnlMoney=%.2f bal=%.2f",
          g_VT_TicketSeq, reason, closePrice, pnlPips, pnlMoney, g_TE_SimBalance));

    g_VT_IsOpen         = false;
    g_TE_OpenTicket     = -1;
    g_TE_OpenType       = -1;
    g_TE_OpenLots       = 0.0;
    g_TE_OpenEntryPrice = 0.0;
}

//+------------------------------------------------------------------+
// Check bar OHLC for SL/TP hit — call at the START of each bar step
void TradeEngine_CheckBarClose(string sym, int shift)
{
    if(!g_VT_IsOpen) return;

    double hi = iHigh(sym, PERIOD_D1, shift);
    double lo = iLow(sym, PERIOD_D1, shift);

    if(g_VT_Type == OP_BUY)
    {
        if(lo <= g_VT_SLPrice)        _VT_Close(sym, g_VT_SLPrice, "SL");
        else if(hi >= g_VT_TPPrice)   _VT_Close(sym, g_VT_TPPrice, "TP");
    }
    else
    {
        if(hi >= g_VT_SLPrice)        _VT_Close(sym, g_VT_SLPrice, "SL");
        else if(lo <= g_VT_TPPrice)   _VT_Close(sym, g_VT_TPPrice, "TP");
    }
}

//+------------------------------------------------------------------+
// Called each bar in auto mode
void TradeEngine_OnBar(string sym, int tf, int shift)
{
    if(tf != PERIOD_D1) return;

    double slPips = 0, tpPips = 0, slDist = 0, tpDist = 0;
    string reason = "";
    if(!_TE_CalcSLTP(sym, slPips, tpPips, slDist, tpDist, reason))
    { Print("TradeEngine_OnBar: SL/TP failed: ", reason); return; }

    double lots = 0;
    if(!_TE_CalcLots(sym, slPips, lots, reason))
    { Print("TradeEngine_OnBar: lot failed: ", reason); return; }

    double pipSize    = _TE_PipSize(sym);
    double spreadPips = TradeEngine_GetSpreadPips(sym);
    int    signal     = IndEngine_GetSignal(sym, tf, shift);

    if(!g_VT_IsOpen)
    {
        if(signal == 1)
        {
            double entry = iOpen(sym, PERIOD_D1, shift) + spreadPips * pipSize;
            _VT_Open(sym, OP_BUY,  entry, slPips, tpPips,
                     entry - slDist, entry + tpDist, lots, spreadPips);
        }
        else if(signal == -1)
        {
            double entry = iOpen(sym, PERIOD_D1, shift);
            _VT_Open(sym, OP_SELL, entry, slPips, tpPips,
                     entry + slDist, entry - tpDist, lots, spreadPips);
        }
    }
    else
    {
        if(g_VT_Type == OP_BUY && signal == -1)
        {
            double entry = iOpen(sym, PERIOD_D1, shift);
            _VT_Close(sym, entry, "OppositeSignal");
            _VT_Open(sym, OP_SELL, entry, slPips, tpPips,
                     entry + slDist, entry - tpDist, lots, spreadPips);
        }
        else if(g_VT_Type == OP_SELL && signal == 1)
        {
            double entry = iOpen(sym, PERIOD_D1, shift) + spreadPips * pipSize;
            _VT_Close(sym, entry, "OppositeSignal");
            _VT_Open(sym, OP_BUY,  entry, slPips, tpPips,
                     entry - slDist, entry + tpDist, lots, spreadPips);
        }
    }
}

//+------------------------------------------------------------------+
void TradeEngine_ClosePosition(string sym, string reason)
{
    if(!g_VT_IsOpen) return;
    double closePrice = iClose(sym, PERIOD_D1, g_TE_CurrentShift);
    _VT_Close(sym, closePrice, reason);
}

//+------------------------------------------------------------------+
void TradeEngine_CloseAll(string sym)
{
    TradeEngine_ClosePosition(sym, "CloseAll");
}

//+------------------------------------------------------------------+
void TradeEngine_ManualBuy(string sym, double manualLots, double manualSLPips, double manualTPPips)
{
    if(g_VT_IsOpen) { Print("TradeEngine: position already open"); return; }

    double spreadPips = TradeEngine_GetSpreadPips(sym);
    double pipSize    = _TE_PipSize(sym);
    double slPips     = (manualSLPips > 0) ? manualSLPips : g_TE_SLPips;
    double tpPips     = (manualTPPips > 0) ? manualTPPips : slPips * g_TE_RR;
    double slDist     = slPips * pipSize;
    double tpDist     = tpPips * pipSize;

    double lots = manualLots;
    if(lots <= 0) { string r = ""; _TE_CalcLots(sym, slPips, lots, r); }
    if(lots <= 0) lots = g_TE_FixedLot;

    double entry = iClose(sym, PERIOD_D1, g_TE_CurrentShift) + spreadPips * pipSize;
    _VT_Open(sym, OP_BUY, entry, slPips, tpPips,
             entry - slDist, entry + tpDist, lots, spreadPips);
}

//+------------------------------------------------------------------+
void TradeEngine_ManualSell(string sym, double manualLots, double manualSLPips, double manualTPPips)
{
    if(g_VT_IsOpen) { Print("TradeEngine: position already open"); return; }

    double spreadPips = TradeEngine_GetSpreadPips(sym);
    double pipSize    = _TE_PipSize(sym);
    double slPips     = (manualSLPips > 0) ? manualSLPips : g_TE_SLPips;
    double tpPips     = (manualTPPips > 0) ? manualTPPips : slPips * g_TE_RR;
    double slDist     = slPips * pipSize;
    double tpDist     = tpPips * pipSize;

    double lots = manualLots;
    if(lots <= 0) { string r = ""; _TE_CalcLots(sym, slPips, lots, r); }
    if(lots <= 0) lots = g_TE_FixedLot;

    double entry = iClose(sym, PERIOD_D1, g_TE_CurrentShift);
    _VT_Open(sym, OP_SELL, entry, slPips, tpPips,
             entry + slDist, entry - tpDist, lots, spreadPips);
}

#endif // NNFX_TRADE_ENGINE_MQH
