//+------------------------------------------------------------------+
//| stats_engine.mqh — Trade accumulator and metrics                |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_STATS_ENGINE_MQH
#define NNFX_STATS_ENGINE_MQH

#define SE_MAX_TRADES 2000

//+------------------------------------------------------------------+
// Trade record
struct SE_TradeRecord
{
    int      ticket;
    int      type;             // OP_BUY / OP_SELL
    double   lots;
    double   entryPrice;
    double   exitPrice;
    double   slPips;
    double   tpPips;
    double   pnlPips;
    double   spreadPips;
    double   commission;
    datetime entryTime;
    datetime exitTime;
    string   closeReason;
    bool     closed;
};

SE_TradeRecord g_SE_Trades[SE_MAX_TRADES];
int            g_SE_TradeCount   = 0;
int            g_SE_OpenIdx      = -1;

// Running stats
double g_SE_TotalPnlPips    = 0.0;
double g_SE_TotalCommission = 0.0;
double g_SE_TotalSpread     = 0.0;
int    g_SE_Wins            = 0;
int    g_SE_Losses          = 0;
double g_SE_PeakBalance     = 0.0;
double g_SE_MaxDD           = 0.0;
double g_SE_StartBalance    = 0.0;

//+------------------------------------------------------------------+
void StatsEngine_Init(double startBalance)
{
    g_SE_TradeCount   = 0;
    g_SE_OpenIdx      = -1;
    g_SE_TotalPnlPips = 0.0;
    g_SE_TotalCommission = 0.0;
    g_SE_TotalSpread  = 0.0;
    g_SE_Wins         = 0;
    g_SE_Losses       = 0;
    g_SE_StartBalance = startBalance;
    g_SE_PeakBalance  = startBalance;
    g_SE_MaxDD        = 0.0;
}

//+------------------------------------------------------------------+
void StatsEngine_OnTradeOpen(int ticket, int type, double lots, double entryPrice,
                              double slPips, double tpPips, double spreadPips,
                              datetime entryTime)
{
    if(g_SE_TradeCount >= SE_MAX_TRADES) return;

    int idx = g_SE_TradeCount;
    g_SE_Trades[idx].ticket      = ticket;
    g_SE_Trades[idx].type        = type;
    g_SE_Trades[idx].lots        = lots;
    g_SE_Trades[idx].entryPrice  = entryPrice;
    g_SE_Trades[idx].exitPrice   = 0.0;
    g_SE_Trades[idx].slPips      = slPips;
    g_SE_Trades[idx].tpPips      = tpPips;
    g_SE_Trades[idx].pnlPips     = 0.0;
    g_SE_Trades[idx].spreadPips  = spreadPips;
    g_SE_Trades[idx].commission  = 0.0;
    g_SE_Trades[idx].entryTime   = entryTime;
    g_SE_Trades[idx].exitTime    = 0;
    g_SE_Trades[idx].closeReason = "";
    g_SE_Trades[idx].closed      = false;

    g_SE_OpenIdx = idx;
    g_SE_TradeCount++;
    g_SE_TotalSpread += spreadPips;
}

//+------------------------------------------------------------------+
void StatsEngine_OnTradeClose(int ticket, double exitPrice, double pnlPips,
                               double spreadPips, double commission,
                               datetime exitTime, string closeReason)
{
    // Find matching open trade
    for(int i = g_SE_TradeCount - 1; i >= 0; i--)
    {
        if(g_SE_Trades[i].ticket == ticket && !g_SE_Trades[i].closed)
        {
            g_SE_Trades[i].exitPrice   = exitPrice;
            g_SE_Trades[i].pnlPips     = pnlPips;
            g_SE_Trades[i].commission  = commission;
            g_SE_Trades[i].exitTime    = exitTime;
            g_SE_Trades[i].closeReason = closeReason;
            g_SE_Trades[i].closed      = true;

            g_SE_TotalPnlPips    += pnlPips;
            g_SE_TotalCommission += commission;
            if(pnlPips > 0) g_SE_Wins++;
            else             g_SE_Losses++;

            g_SE_OpenIdx = -1;
            return;
        }
    }
}

//+------------------------------------------------------------------+
// Populate summary values
void StatsEngine_GetSummary(int &totalTrades, int &wins, int &losses,
                             double &winRate, double &totalPips,
                             double &avgPips, double &maxDD,
                             double &expectancy, double &totalCommission,
                             double &avgSpread)
{
    totalTrades     = g_SE_Wins + g_SE_Losses;
    wins            = g_SE_Wins;
    losses          = g_SE_Losses;
    winRate         = (totalTrades > 0) ? (double)wins / totalTrades * 100.0 : 0.0;
    totalPips       = g_SE_TotalPnlPips;
    avgPips         = (totalTrades > 0) ? totalPips / totalTrades : 0.0;
    maxDD           = g_SE_MaxDD;
    totalCommission = g_SE_TotalCommission;
    avgSpread       = (totalTrades > 0) ? g_SE_TotalSpread / totalTrades : 0.0;

    // Expectancy: winRate% * avg_win - lossRate% * avg_loss
    double sumWins = 0.0, sumLosses = 0.0;
    int    wCnt    = 0,   lCnt     = 0;
    for(int i = 0; i < g_SE_TradeCount; i++)
    {
        if(!g_SE_Trades[i].closed) continue;
        if(g_SE_Trades[i].pnlPips > 0) { sumWins   += g_SE_Trades[i].pnlPips; wCnt++; }
        else                             { sumLosses += MathAbs(g_SE_Trades[i].pnlPips); lCnt++; }
    }
    double avgWin  = (wCnt > 0) ? sumWins / wCnt   : 0.0;
    double avgLoss = (lCnt > 0) ? sumLosses / lCnt : 0.0;
    double wr      = winRate / 100.0;
    expectancy     = wr * avgWin - (1.0 - wr) * avgLoss;
}

//+------------------------------------------------------------------+
// Sync max drawdown from trade engine (called after every close)
void StatsEngine_SetMaxDD(double dd)
{
    if(dd > g_SE_MaxDD) g_SE_MaxDD = dd;
}

#endif // NNFX_STATS_ENGINE_MQH
