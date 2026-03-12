//+------------------------------------------------------------------+
//| trade_engine.mqh — Open/Close/MM/SL/TP with spread/commission   |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_TRADE_ENGINE_MQH
#define NNFX_TRADE_ENGINE_MQH

//+------------------------------------------------------------------+
enum SPREAD_MODE { SPREAD_FIXED_PIPS=0, SPREAD_CURRENT_MARKET=1 };

// SL/TP/Lot mode constants (mirror g_CFG values)
#define TE_SL_FIXED  0
#define TE_SL_ATR    1
#define TE_TP_RR     0
#define TE_TP_ATR    1
#define TE_LOT_FIXED 0
#define TE_LOT_RISK  1

//+------------------------------------------------------------------+
// Trade engine config (set via TradeEngine_SetConfig)
SPREAD_MODE g_TE_SpreadMode       = SPREAD_FIXED_PIPS;
double      g_TE_FixedSpreadPips  = 2.0;
double      g_TE_CommissionRT     = 0.0;
int         g_TE_Magic            = 20250001;
int         g_TE_SLMode           = TE_SL_ATR;
double      g_TE_SLPips           = 100.0;
double      g_TE_ATRMult          = 1.5;
int         g_TE_TPMode           = TE_TP_RR;
double      g_TE_RR               = 1.5;
double      g_TE_TPATRMult        = 2.0;
int         g_TE_LotMode          = TE_LOT_RISK;
double      g_TE_RiskPct          = 1.0;
double      g_TE_FixedLot         = 0.01;
int         g_TE_Slippage         = 3;
string      g_TE_AllowedSymbols   = "";
bool        g_TE_AutoMode         = false;

// Open position tracking
int    g_TE_OpenTicket     = -1;
int    g_TE_OpenType       = -1;
double g_TE_OpenLots       = 0.0;
double g_TE_OpenEntryPrice = 0.0;
double g_TE_OpenSLPips     = 0.0;
double g_TE_OpenTPPips     = 0.0;
double g_TE_OpenSpreadPips = 0.0;

// Sim balance tracking
double g_TE_SimBalance     = 10000.0;
double g_TE_PeakBalance    = 10000.0;
double g_TE_MaxDD          = 0.0;

//+------------------------------------------------------------------+
// Forward declarations
void StatsEngine_OnTradeOpen(int ticket, int type, double lots, double entryPrice,
                              double slPips, double tpPips, double spreadPips,
                              datetime entryTime);
void StatsEngine_OnTradeClose(int ticket, double exitPrice, double pnlPips,
                               double spreadPips, double commission,
                               datetime exitTime, string closeReason);
void ReportExporter_WriteTradeRow(string event, int ticket, int type, double lots,
                                   double price, double sl, double tp,
                                   double slPips, double tpPips,
                                   double spreadPips, double commission);

//+------------------------------------------------------------------+
void TradeEngine_Init(double startingBalance)
{
    g_TE_SimBalance  = startingBalance;
    g_TE_PeakBalance = startingBalance;
    g_TE_MaxDD       = 0.0;
    g_TE_OpenTicket  = -1;
    g_TE_OpenType    = -1;
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
    g_TE_Magic           = magic;
    g_TE_AllowedSymbols  = allowedSymbols;
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

    // SPREAD_CURRENT_MARKET
    double spread = MarketInfo(sym, MODE_SPREAD);
    int d = (int)MarketInfo(sym, MODE_DIGITS);
    double spPips = (d == 3 || d == 5) ? spread / 10.0 : spread;
    Print("TradeEngine: Market spread sampled=", spPips, " pips");
    return spPips;
}

//+------------------------------------------------------------------+
// Cost in pips (spread only; commission deducted on close)
double TradeEngine_GetExecutionCost(string sym, double lots)
{
    return TradeEngine_GetSpreadPips(sym);
}

//+------------------------------------------------------------------+
bool _TE_IsAllowed(string sym)
{
    if(g_TE_AllowedSymbols == "") return true;
    string parts[];
    int n = StringSplit(g_TE_AllowedSymbols, ',', parts);
    for(int i = 0; i < n; i++)
    {
        StringTrimLeft(parts[i]); StringTrimRight(parts[i]);
        if(parts[i] == sym) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
bool TradeEngine_HasOpenPos(string sym)
{
    if(g_TE_OpenTicket < 0) return false;
    // Verify via order pool
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderSymbol() != sym) continue;
        if(OrderMagicNumber() != g_TE_Magic) continue;
        if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
        return true;
    }
    g_TE_OpenTicket = -1;
    g_TE_OpenType   = -1;
    return false;
}

//+------------------------------------------------------------------+
bool _TE_CalcSLTP(string sym, double &slPips, double &tpPips,
                   double &slDist, double &tpDist, string &reason)
{
    double pipSize = _TE_PipSize(sym);
    double atr     = iATR(sym, PERIOD_D1, 14, 1);

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
    {
        lots = g_TE_FixedLot;
        return true;
    }

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
void TradeEngine_OpenTrade(string sym, int dir, double lots,
                            double slDist, double tpDist,
                            double slPips, double tpPips,
                            double spreadPips)
{
    RefreshRates();
    int d = (int)MarketInfo(sym, MODE_DIGITS);
    int pipsMult = (d == 3 || d == 5) ? 10 : 1;

    double price, sl, tp;
    if(dir == OP_BUY)
    {
        price = MarketInfo(sym, MODE_ASK);
        sl    = price - slDist;
        tp    = price + tpDist;
    }
    else
    {
        price = MarketInfo(sym, MODE_BID);
        sl    = price + slDist;
        tp    = price - tpDist;
    }
    sl = NormalizeDouble(sl, d);
    tp = NormalizeDouble(tp, d);

    int ticket = OrderSend(sym, dir, lots, price, g_TE_Slippage * pipsMult,
                           sl, tp, "NNFX_SIM", g_TE_Magic, 0,
                           dir == OP_BUY ? clrBlue : clrRed);

    if(ticket < 0)
    {
        int err = GetLastError();
        if(err == ERR_REQUOTE || err == ERR_OFF_QUOTES)
        {
            RefreshRates();
            price  = (dir == OP_BUY) ? MarketInfo(sym, MODE_ASK) : MarketInfo(sym, MODE_BID);
            sl     = (dir == OP_BUY) ? price - slDist : price + slDist;
            tp     = (dir == OP_BUY) ? price + tpDist : price - tpDist;
            sl     = NormalizeDouble(sl, d);
            tp     = NormalizeDouble(tp, d);
            ticket = OrderSend(sym, dir, lots, price, g_TE_Slippage * pipsMult,
                               sl, tp, "NNFX_SIM", g_TE_Magic, 0,
                               dir == OP_BUY ? clrBlue : clrRed);
        }
    }

    if(ticket < 0)
    {
        Print("TradeEngine: OrderSend FAILED err=", GetLastError());
        return;
    }

    g_TE_OpenTicket     = ticket;
    g_TE_OpenType       = dir;
    g_TE_OpenLots       = lots;
    g_TE_OpenEntryPrice = price;
    g_TE_OpenSLPips     = slPips;
    g_TE_OpenTPPips     = tpPips;
    g_TE_OpenSpreadPips = spreadPips;

    StatsEngine_OnTradeOpen(ticket, dir, lots, price, slPips, tpPips, spreadPips, TimeCurrent());
    ReportExporter_WriteTradeRow("OPEN", ticket, dir, lots, price, sl, tp,
                                  slPips, tpPips, spreadPips, 0.0);

    Print(StringFormat("TE OpenTrade: %s ticket=%d lots=%.2f price=%.5f SL=%.5f TP=%.5f spread=%.1f",
          dir == OP_BUY ? "BUY" : "SELL", ticket, lots, price, sl, tp, spreadPips));
}

//+------------------------------------------------------------------+
void TradeEngine_ClosePosition(string sym, string reason)
{
    if(g_TE_OpenTicket < 0) return;
    if(!OrderSelect(g_TE_OpenTicket, SELECT_BY_TICKET)) return;

    RefreshRates();
    int d = (int)MarketInfo(sym, MODE_DIGITS);
    int pipsMult = (d == 3 || d == 5) ? 10 : 1;
    double closePrice = (OrderType() == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);

    bool ok = OrderClose(g_TE_OpenTicket, OrderLots(), closePrice, g_TE_Slippage * pipsMult, clrYellow);
    if(!ok)
    {
        Print("TradeEngine: OrderClose FAILED ticket=", g_TE_OpenTicket, " err=", GetLastError());
        return;
    }

    // Calculate P&L in pips
    double pipSize = _TE_PipSize(sym);
    double pnlPips = 0.0;
    if(OrderType() == OP_BUY)
        pnlPips = (closePrice - g_TE_OpenEntryPrice) / pipSize;
    else
        pnlPips = (g_TE_OpenEntryPrice - closePrice) / pipSize;

    // Deduct commission (round-turn)
    double pipValue = MarketInfo(sym, MODE_TICKVALUE);
    if(d == 3 || d == 5) pipValue *= 10.0;
    double commission = 0.0;
    if(pipValue > 0 && g_TE_CommissionRT > 0)
        commission = g_TE_CommissionRT * g_TE_OpenLots;

    // Net pips after commission
    double netPips = pnlPips - (pipValue > 0 ? commission / (g_TE_OpenLots * pipValue) : 0.0);

    // Update sim balance
    if(OrderSelect(g_TE_OpenTicket, SELECT_BY_TICKET))
    {
        double profit = OrderProfit() + OrderSwap() + OrderCommission();
        g_TE_SimBalance += profit - commission;
    }
    if(g_TE_SimBalance > g_TE_PeakBalance) g_TE_PeakBalance = g_TE_SimBalance;
    double dd = (g_TE_PeakBalance - g_TE_SimBalance) / g_TE_PeakBalance * 100.0;
    if(dd > g_TE_MaxDD) g_TE_MaxDD = dd;

    StatsEngine_OnTradeClose(g_TE_OpenTicket, closePrice, pnlPips,
                              g_TE_OpenSpreadPips, commission,
                              TimeCurrent(), reason);
    ReportExporter_WriteTradeRow("CLOSE", g_TE_OpenTicket, g_TE_OpenType,
                                  g_TE_OpenLots, closePrice,
                                  OrderStopLoss(), OrderTakeProfit(),
                                  0, 0, g_TE_OpenSpreadPips, commission);

    Print(StringFormat("TE ClosePosition: ticket=%d reason=%s price=%.5f pnlPips=%.2f",
          g_TE_OpenTicket, reason, closePrice, pnlPips));

    g_TE_OpenTicket     = -1;
    g_TE_OpenType       = -1;
    g_TE_OpenLots       = 0.0;
    g_TE_OpenEntryPrice = 0.0;
}

//+------------------------------------------------------------------+
void TradeEngine_CloseAll(string sym)
{
    TradeEngine_ClosePosition(sym, "CloseAll");
}

//+------------------------------------------------------------------+
// Called each bar in auto mode
void TradeEngine_OnBar(string sym, int tf, int shift)
{
    // D1 guard
    if(tf != PERIOD_D1)
    {
        Print("TradeEngine_OnBar: blocked — not D1");
        return;
    }
    // Allowlist guard
    if(!_TE_IsAllowed(sym))
    {
        Print("TradeEngine_OnBar: blocked — symbol not in allowlist: ", sym);
        return;
    }

    int signal = IndEngine_GetSignal(sym, tf, shift);

    double slPips = 0, tpPips = 0, slDist = 0, tpDist = 0;
    string reason = "";
    if(!_TE_CalcSLTP(sym, slPips, tpPips, slDist, tpDist, reason))
    {
        Print("TradeEngine_OnBar: SL/TP calc failed: ", reason);
        return;
    }

    double lots = 0;
    if(!_TE_CalcLots(sym, slPips, lots, reason))
    {
        Print("TradeEngine_OnBar: lot calc failed: ", reason);
        return;
    }

    double spreadPips = TradeEngine_GetSpreadPips(sym);
    bool   hasPos     = TradeEngine_HasOpenPos(sym);

    if(!hasPos)
    {
        if(signal == 1)
            TradeEngine_OpenTrade(sym, OP_BUY, lots, slDist, tpDist, slPips, tpPips, spreadPips);
        else if(signal == -1)
            TradeEngine_OpenTrade(sym, OP_SELL, lots, slDist, tpDist, slPips, tpPips, spreadPips);
    }
    else
    {
        // Reverse on opposite signal
        if(g_TE_OpenType == OP_BUY && signal == -1)
        {
            TradeEngine_ClosePosition(sym, "OppositeSignal");
            TradeEngine_OpenTrade(sym, OP_SELL, lots, slDist, tpDist, slPips, tpPips, spreadPips);
        }
        else if(g_TE_OpenType == OP_SELL && signal == 1)
        {
            TradeEngine_ClosePosition(sym, "OppositeSignal");
            TradeEngine_OpenTrade(sym, OP_BUY, lots, slDist, tpDist, slPips, tpPips, spreadPips);
        }
    }
}

//+------------------------------------------------------------------+
// Detect trades closed naturally by MT4 (SL/TP hit) and record them.
// Call once per bar step before auto-trade logic.
void TradeEngine_CheckForNaturalClose(string sym)
{
    if(g_TE_OpenTicket < 0) return;

    // Still in active order pool?
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
        if(OrderTicket() == g_TE_OpenTicket) return;   // Still open — nothing to do
    }

    // Not active — pull from history
    if(!OrderSelect(g_TE_OpenTicket, SELECT_BY_TICKET))
    {
        Print("TradeEngine: NaturalClose — ticket not in history, clearing. ticket=", g_TE_OpenTicket);
        g_TE_OpenTicket     = -1;
        g_TE_OpenType       = -1;
        g_TE_OpenLots       = 0.0;
        g_TE_OpenEntryPrice = 0.0;
        return;
    }

    double closePrice = OrderClosePrice();
    datetime closeTime = OrderCloseTime();

    // Infer close reason by proximity to SL/TP
    string closeReason = "Natural";
    double sl = OrderStopLoss();
    double tp = OrderTakeProfit();
    int    d  = (int)MarketInfo(sym, MODE_DIGITS);
    double tol = Point * (d == 3 || d == 5 ? 10 : 1) * 2;
    if(sl > 0 && MathAbs(closePrice - sl) <= tol) closeReason = "SL";
    else if(tp > 0 && MathAbs(closePrice - tp) <= tol) closeReason = "TP";

    // P&L in pips
    double pipSize = _TE_PipSize(sym);
    double pnlPips = (g_TE_OpenType == OP_BUY)
                   ? (closePrice - g_TE_OpenEntryPrice) / pipSize
                   : (g_TE_OpenEntryPrice - closePrice) / pipSize;

    // Commission
    double pipValue = MarketInfo(sym, MODE_TICKVALUE);
    if(d == 3 || d == 5) pipValue *= 10.0;
    double commission = (pipValue > 0 && g_TE_CommissionRT > 0)
                      ? g_TE_CommissionRT * g_TE_OpenLots : 0.0;

    // Update sim balance
    double profit = OrderProfit() + OrderSwap() + OrderCommission();
    g_TE_SimBalance += profit - commission;
    if(g_TE_SimBalance > g_TE_PeakBalance) g_TE_PeakBalance = g_TE_SimBalance;
    double dd = (g_TE_PeakBalance > 0)
              ? (g_TE_PeakBalance - g_TE_SimBalance) / g_TE_PeakBalance * 100.0 : 0.0;
    if(dd > g_TE_MaxDD) g_TE_MaxDD = dd;

    StatsEngine_OnTradeClose(g_TE_OpenTicket, closePrice, pnlPips,
                              g_TE_OpenSpreadPips, commission,
                              closeTime, closeReason);
    ReportExporter_WriteTradeRow("CLOSE", g_TE_OpenTicket, g_TE_OpenType,
                                  g_TE_OpenLots, closePrice, sl, tp,
                                  0, 0, g_TE_OpenSpreadPips, commission);

    Print(StringFormat("TE NaturalClose: ticket=%d reason=%s price=%.5f pnlPips=%.2f bal=%.2f",
          g_TE_OpenTicket, closeReason, closePrice, pnlPips, g_TE_SimBalance));

    g_TE_OpenTicket     = -1;
    g_TE_OpenType       = -1;
    g_TE_OpenLots       = 0.0;
    g_TE_OpenEntryPrice = 0.0;
}

//+------------------------------------------------------------------+
// Manual trade from HUD
void TradeEngine_ManualBuy(string sym, double manualLots, double manualSL, double manualTP)
{
    double slPips = manualSL;
    double tpPips = manualTP;
    double pipSize = _TE_PipSize(sym);
    double slDist  = slPips * pipSize;
    double tpDist  = tpPips * pipSize;
    double spreadPips = TradeEngine_GetSpreadPips(sym);

    double lots = manualLots;
    if(lots <= 0)
    {
        string reason = "";
        if(slPips <= 0) slPips = g_TE_SLPips;
        _TE_CalcLots(sym, slPips, lots, reason);
    }
    if(lots <= 0) lots = g_TE_FixedLot;

    TradeEngine_OpenTrade(sym, OP_BUY, lots, slDist, tpDist, slPips, tpPips, spreadPips);
}

//+------------------------------------------------------------------+
void TradeEngine_ManualSell(string sym, double manualLots, double manualSL, double manualTP)
{
    double slPips = manualSL;
    double tpPips = manualTP;
    double pipSize = _TE_PipSize(sym);
    double slDist  = slPips * pipSize;
    double tpDist  = tpPips * pipSize;
    double spreadPips = TradeEngine_GetSpreadPips(sym);

    double lots = manualLots;
    if(lots <= 0)
    {
        string reason = "";
        if(slPips <= 0) slPips = g_TE_SLPips;
        _TE_CalcLots(sym, slPips, lots, reason);
    }
    if(lots <= 0) lots = g_TE_FixedLot;

    TradeEngine_OpenTrade(sym, OP_SELL, lots, slDist, tpDist, slPips, tpPips, spreadPips);
}

#endif // NNFX_TRADE_ENGINE_MQH
