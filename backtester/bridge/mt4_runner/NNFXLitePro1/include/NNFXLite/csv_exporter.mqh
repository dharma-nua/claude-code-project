//+------------------------------------------------------------------+
//| csv_exporter.mqh — Trades + summary CSV output                  |
//| NNFX Lite Pro 1                                                  |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_CSV_EXPORTER_MQH
#define NNFXLITE_CSV_EXPORTER_MQH

//+------------------------------------------------------------------+
//| Module state
//+------------------------------------------------------------------+
string   CE_symbol;
string   CE_tradesFile;
string   CE_summaryFile;
datetime CE_startDate;
datetime CE_endDate;

//+------------------------------------------------------------------+
//| Init: create trades CSV file and write header.
//| Files go to the terminal's Common\Files folder (FILE_COMMON).
//+------------------------------------------------------------------+
bool CE_Init(string symbol, datetime startDate, datetime endDate)
{
    CE_symbol      = symbol;
    CE_startDate   = startDate;
    CE_endDate     = endDate;
    CE_tradesFile  = "NNFXLitePro1_" + symbol + "_trades.csv";
    CE_summaryFile = "NNFXLitePro1_" + symbol + "_summary.csv";

    int handle = FileOpen(CE_tradesFile,
                          FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle < 0)
    {
        Print("[CE] ERROR: Cannot create trades file '", CE_tradesFile,
              "' Err=", GetLastError());
        return false;
    }
    FileWriteString(handle,
        "Bar,Date,Direction,Entry,SL,TP,ExitReason,Lots,PnL,Balance\n");
    FileClose(handle);
    Print("[CE] Trades file ready: ", CE_tradesFile);
    return true;
}

//+------------------------------------------------------------------+
//| Append one closed trade row.
//+------------------------------------------------------------------+
void CE_WriteTrade(int    barNum,
                   datetime date,
                   int    direction,
                   double entry,
                   double sl,
                   double tp,
                   string exitReason,
                   double lots,
                   double pnl,
                   double balance)
{
    int handle = FileOpen(CE_tradesFile,
                          FILE_READ | FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle < 0)
    {
        Print("[CE] ERROR: Cannot open trades file for append. Err=", GetLastError());
        return;
    }
    FileSeek(handle, 0, SEEK_END);

    string line = IntegerToString(barNum)              + "," +
                  TimeToStr(date, TIME_DATE)           + "," +
                  (direction > 0 ? "BUY" : "SELL")    + "," +
                  DoubleToStr(entry, 5)                + "," +
                  DoubleToStr(sl, 5)                   + "," +
                  DoubleToStr(tp, 5)                   + "," +
                  exitReason                           + "," +
                  DoubleToStr(lots, 2)                 + "," +
                  DoubleToStr(pnl, 2)                  + "," +
                  DoubleToStr(balance, 2)              + "\n";

    FileWriteString(handle, line);
    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Write summary CSV — call once at end of test.
//+------------------------------------------------------------------+
void CE_FinishTest(int    wins,
                   int    losses,
                   double startBal,
                   double endBal,
                   double grossProfit,
                   double grossLoss)
{
    int handle = FileOpen(CE_summaryFile,
                          FILE_WRITE | FILE_TXT | FILE_COMMON);
    if(handle < 0)
    {
        Print("[CE] ERROR: Cannot create summary file. Err=", GetLastError());
        return;
    }

    int    total   = wins + losses;
    double winRate = (total > 0) ? ((double)wins / total * 100.0) : 0.0;
    double pf      = (grossLoss > 0.0) ? (grossProfit / grossLoss)
                                       : (grossProfit > 0.0 ? 99.99 : 0.0);
    double retPct  = (startBal > 0.0) ? ((endBal - startBal) / startBal * 100.0) : 0.0;

    FileWriteString(handle,
        "Symbol,StartDate,EndDate,StartBalance,EndBalance,"
        "Return%,Trades,Wins,Losses,WinRate%,ProfitFactor,"
        "GrossProfit,GrossLoss\n");

    string line = CE_symbol                               + "," +
                  TimeToStr(CE_startDate, TIME_DATE)     + "," +
                  TimeToStr(CE_endDate,   TIME_DATE)     + "," +
                  DoubleToStr(startBal, 2)               + "," +
                  DoubleToStr(endBal,   2)               + "," +
                  DoubleToStr(retPct,   2)               + "," +
                  IntegerToString(total)                 + "," +
                  IntegerToString(wins)                  + "," +
                  IntegerToString(losses)                + "," +
                  DoubleToStr(winRate, 1)                + "," +
                  DoubleToStr(pf,      3)                + "," +
                  DoubleToStr(grossProfit, 2)            + "," +
                  DoubleToStr(grossLoss,   2)            + "\n";

    FileWriteString(handle, line);
    FileClose(handle);

    Print("[CE] Summary written: ", CE_summaryFile);
    Print("[CE] Trades=", total, " Wins=", wins, " Losses=", losses,
          " WinRate=", DoubleToStr(winRate, 1), "%",
          " PF=", DoubleToStr(pf, 3),
          " Return=", DoubleToStr(retPct, 2), "%");
}

#endif // NNFXLITE_CSV_EXPORTER_MQH
