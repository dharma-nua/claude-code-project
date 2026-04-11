//+------------------------------------------------------------------+
//| hst_builder.mqh — HST v401 file creation                         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_HST_BUILDER_MQH
#define NNFXLITE_HST_BUILDER_MQH

//+------------------------------------------------------------------+
//| Create (or overwrite) an HST v401 file with header + 1 seed bar.
//| Returns true on success.
//| sourceSymbol = real symbol for MarketInfo (e.g. "EURUSD")
//| simSymbol    = offline symbol name (e.g. "EURUSD_SIM")
//+------------------------------------------------------------------+
bool HST_Build(string sourceSymbol, string simSymbol)
{
    string hstFile = simSymbol + "1440.hst";
    int    period  = 1440;  // D1
    int    digits  = (int)MarketInfo(sourceSymbol, MODE_DIGITS);

    Print("[HST] Creating offline symbol: ", simSymbol,
          " Period=D1 Digits=", digits);

    //--- Create/overwrite the HST file
    int handle = FileOpenHistory(hstFile, FILE_BIN | FILE_WRITE);
    if(handle < 0)
    {
        Print("[HST] ERROR: Failed to create ", hstFile,
              " Error=", GetLastError());
        return false;
    }

    //--- Write 148-byte HST v401 header ---

    // version (4 bytes)
    FileWriteInteger(handle, 401, LONG_VALUE);

    // copyright (64 bytes) — null-padded string
    string copyright = "NNFXLitePro1";
    uchar copyrightBytes[64];
    ArrayInitialize(copyrightBytes, 0);
    StringToCharArray(copyright, copyrightBytes, 0,
                      MathMin(StringLen(copyright), 63));
    for(int i = 0; i < 64; i++)
        FileWriteInteger(handle, copyrightBytes[i], CHAR_VALUE);

    // symbol (12 bytes) — null-padded
    uchar symbolBytes[12];
    ArrayInitialize(symbolBytes, 0);
    StringToCharArray(simSymbol, symbolBytes, 0,
                      MathMin(StringLen(simSymbol), 11));
    for(int i = 0; i < 12; i++)
        FileWriteInteger(handle, symbolBytes[i], CHAR_VALUE);

    // period (4 bytes)
    FileWriteInteger(handle, period, LONG_VALUE);

    // digits (4 bytes)
    FileWriteInteger(handle, digits, LONG_VALUE);

    // timesign (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);

    // last_sync (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);

    // unused (13 x 4 = 52 bytes)
    for(int i = 0; i < 13; i++)
        FileWriteInteger(handle, 0, LONG_VALUE);

    //--- Write 1 seed bar so MT4 lists the file in File > Open Offline
    datetime seedTime  = iTime(sourceSymbol, PERIOD_D1, 0);
    double   seedOpen  = iOpen(sourceSymbol, PERIOD_D1, 0);
    double   seedHigh  = iHigh(sourceSymbol, PERIOD_D1, 0);
    double   seedLow   = iLow(sourceSymbol, PERIOD_D1, 0);
    double   seedClose = iClose(sourceSymbol, PERIOD_D1, 0);
    long     seedVol   = iVolume(sourceSymbol, PERIOD_D1, 0);

    FileWriteLong(handle, (long)seedTime);        // time        8 bytes
    FileWriteDouble(handle, seedOpen);            // open        8 bytes
    FileWriteDouble(handle, seedHigh);            // high        8 bytes
    FileWriteDouble(handle, seedLow);             // low         8 bytes
    FileWriteDouble(handle, seedClose);           // close       8 bytes
    FileWriteLong(handle, seedVol);               // tick_volume 8 bytes
    FileWriteInteger(handle, 0, LONG_VALUE);      // spread      4 bytes
    FileWriteLong(handle, 0);                     // real_volume 8 bytes

    FileFlush(handle);
    FileClose(handle);

    Print("[HST] Created ", hstFile, " successfully (header + 1 seed bar).");
    return true;
}

#endif // NNFXLITE_HST_BUILDER_MQH
