//+------------------------------------------------------------------+
//| NNFXLiteSetup.mq4 — Offline symbol HST creator (script)         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property show_inputs

extern string SourceSymbol = "EURUSD";
extern bool   ForceReset   = false;

//+------------------------------------------------------------------+
void OnStart()
{
    string simSymbol  = SourceSymbol + "_SIM";
    string hstFile    = simSymbol + "1440.hst";
    int    period     = 1440;  // D1
    int    digits     = (int)MarketInfo(SourceSymbol, MODE_DIGITS);

    Print("[NNFXLiteSetup] Creating offline symbol: ", simSymbol,
          " Period=D1 Digits=", digits);

    //--- Check if HST file already exists
    int checkHandle = FileOpenHistory(hstFile, FILE_BIN | FILE_READ);
    if(checkHandle >= 0)
    {
        FileClose(checkHandle);
        if(!ForceReset)
        {
            Print("[NNFXLiteSetup] WARNING: ", hstFile,
                  " already exists. Set ForceReset=true to overwrite.");
            Print("[NNFXLiteSetup] Skipping creation. Existing file is intact.");
            PrintInstructions(simSymbol);
            return;
        }
        Print("[NNFXLiteSetup] ForceReset=true — overwriting existing file.");
    }

    //--- Create the HST file with v401 header
    int handle = FileOpenHistory(hstFile, FILE_BIN | FILE_WRITE);
    if(handle < 0)
    {
        Print("[NNFXLiteSetup] ERROR: Failed to create ", hstFile,
              " Error=", GetLastError());
        return;
    }

    //--- Write 148-byte HST v401 header
    // version (4 bytes)
    FileWriteInteger(handle, 401, LONG_VALUE);

    // copyright (64 bytes) — null-padded string
    string copyright = "NNFXLitePro1";
    uchar copyrightBytes[64];
    ArrayInitialize(copyrightBytes, 0);
    StringToCharArray(copyright, copyrightBytes, 0, MathMin(StringLen(copyright), 63));
    for(int i = 0; i < 64; i++)
        FileWriteInteger(handle, copyrightBytes[i], CHAR_VALUE);

    // symbol (12 bytes) — null-padded
    uchar symbolBytes[12];
    ArrayInitialize(symbolBytes, 0);
    StringToCharArray(simSymbol, symbolBytes, 0, MathMin(StringLen(simSymbol), 11));
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

    FileFlush(handle);
    FileClose(handle);

    Print("[NNFXLiteSetup] Created ", hstFile, " successfully (148-byte header, 0 bars).");
    PrintInstructions(simSymbol);
}

//+------------------------------------------------------------------+
void PrintInstructions(string simSymbol)
{
    string baseSymbol = StringSubstr(simSymbol, 0, StringLen(simSymbol) - 4);
    Print("[NNFXLiteSetup] ========================================");
    Print("[NNFXLiteSetup] NEXT STEPS:");
    Print("[NNFXLiteSetup]   1. In MT4: File > Open Offline > select ", simSymbol, ", D1 > Open");
    Print("[NNFXLiteSetup]   2. Attach NNFXLitePanel indicator to the offline chart");
    Print("[NNFXLiteSetup]   3. Open your real ", baseSymbol, " D1 chart");
    Print("[NNFXLiteSetup]   4. Attach NNFXLitePro1 EA to the real chart");
    Print("[NNFXLiteSetup] ========================================");
}
