//+------------------------------------------------------------------+
//| bar_feeder.mqh — HST bar writing + offline chart refresh         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_BAR_FEEDER_MQH
#define NNFXLITE_BAR_FEEDER_MQH

//+------------------------------------------------------------------+
//| Speed intervals in milliseconds (level 1=slowest, 5=fastest)
int BF_SpeedIntervals[5] = {2000, 800, 300, 100, 30};

//+------------------------------------------------------------------+
//| Bar feeder state
string   BF_simSymbol;
string   BF_realSymbol;
long     BF_offlineChartId;
int      BF_cursorIndex;    // current shift on real chart (counting down from high)
int      BF_endBarIndex;    // stop when cursorIndex < this
int      BF_totalBars;
int      BF_barsFed;
int      BF_speedLevel;     // 1-5
int      BF_speedMs;        // timer interval in ms
string   BF_hstFilename;    // filename for FileOpenHistory

//+------------------------------------------------------------------+
long BF_FindOfflineChart(string simSymbol)
{
    long chartId = ChartFirst();
    while(chartId >= 0)
    {
        if(ChartSymbol(chartId) == simSymbol && ChartPeriod(chartId) == PERIOD_D1)
        {
            int indicatorCount = ChartIndicatorsTotal(chartId, 0);
            for(int i = 0; i < indicatorCount; i++)
            {
                if(ChartIndicatorName(chartId, 0, i) == "NNFXLitePanel")
                {
                    Print("[BF] Found offline chart ID=", chartId, " with NNFXLitePanel");
                    return chartId;
                }
            }
            Print("[BF] Found chart for ", simSymbol, " but NNFXLitePanel not attached.");
        }
        chartId = ChartNext(chartId);
    }
    return -1;
}

//+------------------------------------------------------------------+
bool BF_RewriteHSTHeader()
{
    int handle = FileOpenHistory(BF_hstFilename, FILE_BIN | FILE_WRITE);
    if(handle < 0)
    {
        Print("[BF] ERROR: Cannot open HST file: ", BF_hstFilename, " Err=", GetLastError());
        return false;
    }

    int digits = (int)MarketInfo(BF_realSymbol, MODE_DIGITS);

    FileWriteInteger(handle, 401, LONG_VALUE);      // version (4 bytes)

    uchar copyrightBytes[64];
    ArrayInitialize(copyrightBytes, 0);
    string copyright = "NNFXLitePro1";
    StringToCharArray(copyright, copyrightBytes, 0, MathMin(StringLen(copyright), 63));
    for(int i = 0; i < 64; i++)
        FileWriteInteger(handle, copyrightBytes[i], CHAR_VALUE);  // copyright (64 bytes)

    uchar symbolBytes[12];
    ArrayInitialize(symbolBytes, 0);
    StringToCharArray(BF_simSymbol, symbolBytes, 0, MathMin(StringLen(BF_simSymbol), 11));
    for(int i = 0; i < 12; i++)
        FileWriteInteger(handle, symbolBytes[i], CHAR_VALUE);     // symbol (12 bytes)

    FileWriteInteger(handle, 1440, LONG_VALUE);     // period (4 bytes)
    FileWriteInteger(handle, digits, LONG_VALUE);   // digits (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);        // timesign (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);        // last_sync (4 bytes)
    for(int i = 0; i < 13; i++)
        FileWriteInteger(handle, 0, LONG_VALUE);    // unused 13x4=52 bytes

    FileFlush(handle);
    FileClose(handle);
    return true;
}

//+------------------------------------------------------------------+
bool BF_Init(string realSymbol, string simSymbol,
             datetime startDate, datetime endDate, int defaultSpeed)
{
    BF_realSymbol  = realSymbol;
    BF_simSymbol   = simSymbol;
    BF_hstFilename = simSymbol + "1440.hst";
    BF_barsFed     = 0;

    BF_offlineChartId = BF_FindOfflineChart(simSymbol);
    if(BF_offlineChartId < 0)
    {
        Print("[BF] ERROR: Offline chart not found. Run NNFXLiteSetup, open offline chart, attach NNFXLitePanel.");
        return false;
    }

    int startShift = iBarShift(realSymbol, PERIOD_D1, startDate, false);
    int endShift   = iBarShift(realSymbol, PERIOD_D1, endDate, false);

    if(startShift < 0 || endShift < 0)
    {
        Print("[BF] ERROR: Cannot find bars for date range. Start=", TimeToStr(startDate), " End=", TimeToStr(endDate));
        return false;
    }
    if(startShift <= endShift)
    {
        Print("[BF] ERROR: StartDate must be before EndDate. StartShift=", startShift, " EndShift=", endShift);
        return false;
    }

    BF_cursorIndex = startShift;
    BF_endBarIndex = endShift;
    BF_totalBars   = startShift - endShift + 1;

    Print("[BF] Range: ", TimeToStr(startDate), " to ", TimeToStr(endDate),
          " | Shifts: ", startShift, " -> ", endShift, " | Bars: ", BF_totalBars);

    BF_SetSpeed(defaultSpeed);

    if(!BF_RewriteHSTHeader())
    {
        Print("[BF] ERROR: Failed to rewrite HST header.");
        return false;
    }

    Print("[BF] Init complete. Total bars=", BF_totalBars, " Speed=", BF_speedLevel, " (", BF_speedMs, "ms)");
    return true;
}

//+------------------------------------------------------------------+
// Returns false when all bars have been fed
bool BF_FeedNextBar()
{
    if(BF_cursorIndex < BF_endBarIndex)
        return false;

    datetime barTime  = iTime(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barOpen  = iOpen(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barHigh  = iHigh(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barLow   = iLow(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barClose = iClose(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    long     barVol   = iVolume(BF_realSymbol, PERIOD_D1, BF_cursorIndex);

    int handle = FileOpenHistory(BF_hstFilename, FILE_BIN | FILE_WRITE | FILE_READ);
    if(handle < 0)
    {
        Print("[BF] ERROR: Cannot open HST for writing. Err=", GetLastError());
        return false;
    }

    FileSeek(handle, 0, SEEK_END);

    // 60-byte bar record (HST v401)
    FileWriteLong(handle, (long)barTime);      // time        8 bytes
    FileWriteDouble(handle, barOpen);           // open        8 bytes
    FileWriteDouble(handle, barHigh);           // high        8 bytes
    FileWriteDouble(handle, barLow);            // low         8 bytes
    FileWriteDouble(handle, barClose);          // close       8 bytes
    FileWriteLong(handle, barVol);              // tick_volume 8 bytes
    FileWriteInteger(handle, 0, LONG_VALUE);    // spread      4 bytes
    FileWriteLong(handle, 0);                   // real_volume 8 bytes

    FileFlush(handle);
    FileClose(handle);

    ChartSetSymbolPeriod(BF_offlineChartId, BF_simSymbol, PERIOD_D1);

    BF_barsFed++;
    BF_cursorIndex--;
    return true;
}

//+------------------------------------------------------------------+
void BF_SetSpeed(int level)
{
    if(level < 1) level = 1;
    if(level > 5) level = 5;
    BF_speedLevel = level;
    BF_speedMs    = BF_SpeedIntervals[level - 1];
}

int      BF_GetSpeedLevel()      { return BF_speedLevel; }
int      BF_GetSpeedMs()         { return BF_speedMs; }
int      BF_GetCurrentBarNum()   { return BF_barsFed; }
int      BF_GetTotalBars()       { return BF_totalBars; }
long     BF_GetOfflineChartId()  { return BF_offlineChartId; }

datetime BF_GetCurrentDate()
{
    if(BF_barsFed == 0) return 0;
    return iTime(BF_realSymbol, PERIOD_D1, BF_cursorIndex + 1);
}

#endif // NNFXLITE_BAR_FEEDER_MQH
