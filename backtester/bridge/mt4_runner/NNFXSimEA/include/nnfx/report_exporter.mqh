//+------------------------------------------------------------------+
//| report_exporter.mqh — CSV export: signals, trades, summary      |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_REPORT_EXPORTER_MQH
#define NNFX_REPORT_EXPORTER_MQH

int    g_RE_SignalH  = INVALID_HANDLE;
int    g_RE_TradeH   = INVALID_HANDLE;
int    g_RE_SummaryH = INVALID_HANDLE;
string g_RE_SessionId = "";

//+------------------------------------------------------------------+
void ReportExporter_Init(string sessionId)
{
    g_RE_SessionId = sessionId;
    string sigPath  = "nnfx_sim/reports/" + sessionId + "_signals.csv";
    string trdPath  = "nnfx_sim/reports/" + sessionId + "_trades.csv";
    string sumPath  = "nnfx_sim/reports/" + sessionId + "_summary.csv";

    g_RE_SignalH  = FileOpen(sigPath,  FILE_COMMON | FILE_WRITE | FILE_CSV | FILE_ANSI);
    g_RE_TradeH   = FileOpen(trdPath,  FILE_COMMON | FILE_WRITE | FILE_CSV | FILE_ANSI);
    g_RE_SummaryH = FileOpen(sumPath,  FILE_COMMON | FILE_WRITE | FILE_CSV | FILE_ANSI);

    if(g_RE_SignalH == INVALID_HANDLE)
        Print("ReportExporter: Cannot open signals CSV err=", GetLastError());
    else
        FileWrite(g_RE_SignalH,
            "session_id", "timestamp", "symbol", "timeframe",
            "shift", "signal", "sig_type",
            "buf1", "buf2", "spread_pips", "note");

    if(g_RE_TradeH == INVALID_HANDLE)
        Print("ReportExporter: Cannot open trades CSV err=", GetLastError());
    else
        FileWrite(g_RE_TradeH,
            "session_id", "event", "timestamp", "symbol",
            "ticket", "type", "lots",
            "price", "sl", "tp",
            "sl_pips", "tp_pips",
            "spread_mode", "spread_used_pips", "commission_applied");

    if(g_RE_SummaryH == INVALID_HANDLE)
        Print("ReportExporter: Cannot open summary CSV err=", GetLastError());
    else
        FileWrite(g_RE_SummaryH,
            "session_id", "metric", "value");
}

//+------------------------------------------------------------------+
void ReportExporter_WriteSignalRow(int shift, int signal, int sigType,
                                    double buf1, double buf2,
                                    double spreadPips, string note)
{
    if(g_RE_SignalH == INVALID_HANDLE) return;
    string ts  = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
    string sym = Symbol();
    FileWrite(g_RE_SignalH,
        g_RE_SessionId,
        ts, sym, "D1",
        IntegerToString(shift),
        IntegerToString(signal),
        IntegerToString(sigType),
        DoubleToString(buf1, 6),
        DoubleToString(buf2, 6),
        DoubleToString(spreadPips, 2),
        note);
}

//+------------------------------------------------------------------+
void ReportExporter_WriteTradeRow(string event, int ticket, int type, double lots,
                                   double price, double sl, double tp,
                                   double slPips, double tpPips,
                                   double spreadPips, double commission)
{
    if(g_RE_TradeH == INVALID_HANDLE) return;
    string ts     = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES);
    string sym    = Symbol();
    string typeStr = (type == OP_BUY) ? "BUY" : "SELL";
    int    d      = Digits;
    string spreadModeStr = (g_TE_SpreadMode == SPREAD_FIXED_PIPS) ? "FIXED" : "MARKET";

    FileWrite(g_RE_TradeH,
        g_RE_SessionId,
        event, ts, sym,
        IntegerToString(ticket),
        typeStr,
        DoubleToString(lots, 2),
        DoubleToString(price, d),
        DoubleToString(sl, d),
        DoubleToString(tp, d),
        DoubleToString(slPips, 2),
        DoubleToString(tpPips, 2),
        spreadModeStr,
        DoubleToString(spreadPips, 2),
        DoubleToString(commission, 2));
}

//+------------------------------------------------------------------+
void ReportExporter_WriteSummary()
{
    if(g_RE_SummaryH == INVALID_HANDLE) return;

    int    totalTrades, wins, losses;
    double winRate, totalPips, avgPips, maxDD, expectancy, totalCommission, avgSpread;
    StatsEngine_GetSummary(totalTrades, wins, losses, winRate, totalPips,
                            avgPips, maxDD, expectancy, totalCommission, avgSpread);

    FileWrite(g_RE_SummaryH, g_RE_SessionId, "total_trades",     IntegerToString(totalTrades));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "wins",             IntegerToString(wins));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "losses",           IntegerToString(losses));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "win_rate_pct",     DoubleToString(winRate, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "total_pips",       DoubleToString(totalPips, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "avg_pips",         DoubleToString(avgPips, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "max_drawdown_pct", DoubleToString(maxDD, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "expectancy_pips",  DoubleToString(expectancy, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "total_commission", DoubleToString(totalCommission, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "avg_spread_pips",  DoubleToString(avgSpread, 2));
    FileWrite(g_RE_SummaryH, g_RE_SessionId, "snapshot_file",
              "nnfx_sim/sessions/" + g_RE_SessionId + "_snapshot.ini");
}

//+------------------------------------------------------------------+
void ReportExporter_FlushAll()
{
    ReportExporter_WriteSummary();
    // Flush by closing and reopening in append mode — or just leave open
    Print("ReportExporter: Flushed all reports for session ", g_RE_SessionId);
}

//+------------------------------------------------------------------+
void ReportExporter_Close()
{
    if(g_RE_SignalH  != INVALID_HANDLE) { FileClose(g_RE_SignalH);  g_RE_SignalH  = INVALID_HANDLE; }
    if(g_RE_TradeH   != INVALID_HANDLE) { FileClose(g_RE_TradeH);   g_RE_TradeH   = INVALID_HANDLE; }
    if(g_RE_SummaryH != INVALID_HANDLE) { FileClose(g_RE_SummaryH); g_RE_SummaryH = INVALID_HANDLE; }
}

#endif // NNFX_REPORT_EXPORTER_MQH
