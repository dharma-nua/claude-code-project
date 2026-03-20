//+------------------------------------------------------------------+
//| trade_engine.mqh — Virtual trade state + ATR position sizing     |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_TRADE_ENGINE_MQH
#define NNFXLITE_TRADE_ENGINE_MQH

//+------------------------------------------------------------------+
//| Trade state
//+------------------------------------------------------------------+
bool     TE_inTrade;
int      TE_direction;    // +1 buy, -1 sell
double   TE_entryPrice;
double   TE_SL;
double   TE_TP;
double   TE_lotSize;
datetime TE_entryTime;
double   TE_lastPnL;      // P&L of the last closed trade

//+------------------------------------------------------------------+
//| Config
//+------------------------------------------------------------------+
string   TE_simSymbol;
string   TE_realSymbol;
int      TE_atrPeriod;
double   TE_slMult;
double   TE_tpMult;
double   TE_riskPct;

//+------------------------------------------------------------------+
void TE_Init(string simSymbol, string realSymbol,
             int atrPeriod, double slMult, double tpMult, double riskPct)
{
    TE_simSymbol  = simSymbol;
    TE_realSymbol = realSymbol;
    TE_atrPeriod  = atrPeriod;
    TE_slMult     = slMult;
    TE_tpMult     = tpMult;
    TE_riskPct    = riskPct;
    TE_inTrade    = false;
    TE_direction  = 0;
    TE_entryPrice = 0.0;
    TE_SL         = 0.0;
    TE_TP         = 0.0;
    TE_lotSize    = 0.0;
    TE_entryTime  = 0;
    TE_lastPnL    = 0.0;
    Print("[TE] Init: atrPeriod=", atrPeriod, " slMult=", slMult,
          " tpMult=", tpMult, " risk=", DoubleToStr(riskPct * 100, 1), "%");
}

//+------------------------------------------------------------------+
//| Lot size: risk-based, using real symbol tick math
//+------------------------------------------------------------------+
double TE_CalcLotSize(double balance, double entryPrice, double slPrice)
{
    double slDist    = MathAbs(entryPrice - slPrice);
    double tickSize  = MarketInfo(TE_realSymbol, MODE_TICKSIZE);
    double tickValue = MarketInfo(TE_realSymbol, MODE_TICKVALUE);

    if(slDist < tickSize || tickSize <= 0.0 || tickValue <= 0.0)
    {
        Print("[TE] CalcLotSize: bad inputs slDist=", slDist,
              " tickSize=", tickSize, " tickValue=", tickValue);
        return 0.0;
    }

    double riskAmount  = balance * TE_riskPct;
    double ticksAtRisk = slDist / tickSize;
    double valuePerLot = ticksAtRisk * tickValue;
    if(valuePerLot <= 0.0) return 0.0;

    double lots    = riskAmount / valuePerLot;
    double minLot  = MarketInfo(TE_realSymbol, MODE_MINLOT);
    double maxLot  = MarketInfo(TE_realSymbol, MODE_MAXLOT);
    double lotStep = MarketInfo(TE_realSymbol, MODE_LOTSTEP);
    if(lotStep > 0.0)
        lots = MathFloor(lots / lotStep) * lotStep;
    return MathMax(minLot, MathMin(maxLot, lots));
}

//+------------------------------------------------------------------+
//| P&L for a given exit price (positive = profit)
//+------------------------------------------------------------------+
double TE_CalcPnL(double exitPrice)
{
    double diff      = (TE_direction > 0) ? (exitPrice - TE_entryPrice)
                                          : (TE_entryPrice - exitPrice);
    double tickSize  = MarketInfo(TE_realSymbol, MODE_TICKSIZE);
    double tickValue = MarketInfo(TE_realSymbol, MODE_TICKVALUE);
    if(tickSize <= 0.0 || tickValue <= 0.0) return 0.0;
    return (diff / tickSize) * tickValue * TE_lotSize;
}

//+------------------------------------------------------------------+
//| Open a virtual trade.
//| Call after BF_FeedNextBar() — reads bar shift 1 on sim symbol.
//| Returns false if cannot open (already in trade, no ATR, etc.).
//+------------------------------------------------------------------+
bool TE_OpenTrade(int direction, double balance)
{
    if(TE_inTrade)
    {
        Print("[TE] OpenTrade: already in trade — skipped.");
        return false;
    }

    int barsAvail = iBars(TE_simSymbol, PERIOD_D1);
    if(barsAvail < TE_atrPeriod + 2)
    {
        Print("[TE] OpenTrade: not enough bars for ATR (have=", barsAvail,
              " need=", TE_atrPeriod + 2, ")");
        return false;
    }

    double atr = iATR(TE_simSymbol, PERIOD_D1, TE_atrPeriod, 1);
    if(atr <= 0.0 || atr == EMPTY_VALUE || !MathIsValidNumber(atr))
    {
        Print("[TE] OpenTrade: invalid ATR=", atr);
        return false;
    }

    double entry = iClose(TE_simSymbol, PERIOD_D1, 1);
    if(entry <= 0.0)
    {
        Print("[TE] OpenTrade: invalid entry price=", entry);
        return false;
    }

    double sl, tp;
    if(direction > 0)   // BUY
    {
        sl = entry - atr * TE_slMult;
        tp = entry + atr * TE_tpMult;
    }
    else                // SELL
    {
        sl = entry + atr * TE_slMult;
        tp = entry - atr * TE_tpMult;
    }

    double lots = TE_CalcLotSize(balance, entry, sl);
    if(lots <= 0.0)
    {
        Print("[TE] OpenTrade: lot size calc failed.");
        return false;
    }

    TE_inTrade    = true;
    TE_direction  = direction;
    TE_entryPrice = entry;
    TE_SL         = sl;
    TE_TP         = tp;
    TE_lotSize    = lots;
    TE_entryTime  = iTime(TE_simSymbol, PERIOD_D1, 1);
    TE_lastPnL    = 0.0;

    Print("[TE] Opened: ", (direction > 0 ? "BUY" : "SELL"),
          " Entry=", DoubleToStr(entry, 5),
          " SL=", DoubleToStr(sl, 5),
          " TP=", DoubleToStr(tp, 5),
          " ATR=", DoubleToStr(atr, 5),
          " Lots=", DoubleToStr(lots, 2));
    return true;
}

//+------------------------------------------------------------------+
//| Check if the just-fed bar (shift 1) hit SL or TP.
//| If both hit in the same bar, SL wins (conservative).
//| Sets TE_lastPnL and clears TE_inTrade on exit.
//| Returns: +1 = TP hit, -1 = SL hit, 0 = still open / no trade
//+------------------------------------------------------------------+
int TE_CheckExit()
{
    if(!TE_inTrade) return 0;

    double barHigh = iHigh(TE_simSymbol, PERIOD_D1, 1);
    double barLow  = iLow(TE_simSymbol, PERIOD_D1, 1);

    bool slHit = false;
    bool tpHit = false;

    if(TE_direction > 0)    // LONG
    {
        slHit = (barLow  <= TE_SL);
        tpHit = (barHigh >= TE_TP);
    }
    else                    // SHORT
    {
        slHit = (barHigh >= TE_SL);
        tpHit = (barLow  <= TE_TP);
    }

    if(slHit)   // SL wins over TP on same bar
    {
        TE_lastPnL = TE_CalcPnL(TE_SL);
        TE_inTrade = false;
        Print("[TE] SL hit. PnL=", DoubleToStr(TE_lastPnL, 2));
        return -1;
    }
    if(tpHit)
    {
        TE_lastPnL = TE_CalcPnL(TE_TP);
        TE_inTrade = false;
        Print("[TE] TP hit. PnL=", DoubleToStr(TE_lastPnL, 2));
        return +1;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Force-close at current bar close (end of test or signal flip)
//+------------------------------------------------------------------+
void TE_ForceClose()
{
    if(!TE_inTrade) return;
    double exitPrice = iClose(TE_simSymbol, PERIOD_D1, 1);
    if(exitPrice <= 0.0)
        exitPrice = iClose(TE_simSymbol, PERIOD_D1, 2);
    TE_lastPnL = TE_CalcPnL(exitPrice);
    TE_inTrade = false;
    Print("[TE] Force closed at ", DoubleToStr(exitPrice, 5),
          " PnL=", DoubleToStr(TE_lastPnL, 2));
}

//+------------------------------------------------------------------+
//| Getters
//+------------------------------------------------------------------+
bool     TE_InTrade()      { return TE_inTrade; }
int      TE_GetDirection() { return TE_direction; }
double   TE_GetEntry()     { return TE_entryPrice; }
double   TE_GetSL()        { return TE_SL; }
double   TE_GetTP()        { return TE_TP; }
double   TE_GetLotSize()   { return TE_lotSize; }
double   TE_GetLastPnL()   { return TE_lastPnL; }
datetime TE_GetEntryTime() { return TE_entryTime; }

#endif // NNFXLITE_TRADE_ENGINE_MQH
