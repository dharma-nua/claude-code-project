//+------------------------------------------------------------------+
//| stats_engine.mqh — Running trade accumulators + metrics         |
//| NNFX Lite Pro 1                                                  |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_STATS_ENGINE_MQH
#define NNFXLITE_STATS_ENGINE_MQH

//+------------------------------------------------------------------+
//| Accumulators
//+------------------------------------------------------------------+
double ST_balance;
double ST_startBalance;
int    ST_wins;
int    ST_losses;
double ST_grossProfit;
double ST_grossLoss;

//+------------------------------------------------------------------+
void ST_Init(double startBalance)
{
    ST_startBalance = startBalance;
    ST_balance      = startBalance;
    ST_wins         = 0;
    ST_losses       = 0;
    ST_grossProfit  = 0.0;
    ST_grossLoss    = 0.0;
    Print("[ST] Init: startBalance=", DoubleToStr(startBalance, 2));
}

//+------------------------------------------------------------------+
//| Record a closed trade.
//| exitResult: +1 = TP/win, -1 = SL/loss, 0 = force close (pnl decides)
//+------------------------------------------------------------------+
void ST_AddTrade(int exitResult, double pnl)
{
    ST_balance += pnl;

    bool isWin = (exitResult > 0) || (exitResult == 0 && pnl > 0);

    if(isWin)
    {
        ST_wins++;
        if(pnl > 0.0) ST_grossProfit += pnl;
    }
    else
    {
        ST_losses++;
        if(pnl < 0.0) ST_grossLoss += MathAbs(pnl);
    }
}

//+------------------------------------------------------------------+
//| Getters
//+------------------------------------------------------------------+
int    ST_GetWins()         { return ST_wins; }
int    ST_GetLosses()       { return ST_losses; }
int    ST_GetTotalTrades()  { return ST_wins + ST_losses; }
double ST_GetBalance()      { return ST_balance; }
double ST_GetStartBalance() { return ST_startBalance; }
double ST_GetGrossProfit()  { return ST_grossProfit; }
double ST_GetGrossLoss()    { return ST_grossLoss; }

double ST_GetProfitFactor()
{
    if(ST_grossLoss <= 0.0)
        return (ST_grossProfit > 0.0) ? 99.99 : 0.0;
    return ST_grossProfit / ST_grossLoss;
}

double ST_GetWinRate()
{
    int total = ST_wins + ST_losses;
    if(total == 0) return 0.0;
    return (double)ST_wins / total * 100.0;
}

double ST_GetReturnPct()
{
    if(ST_startBalance <= 0.0) return 0.0;
    return (ST_balance - ST_startBalance) / ST_startBalance * 100.0;
}

#endif // NNFXLITE_STATS_ENGINE_MQH
