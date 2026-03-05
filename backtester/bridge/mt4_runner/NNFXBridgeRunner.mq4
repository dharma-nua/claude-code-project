//+------------------------------------------------------------------+
//|  NNFXBridgeRunner.mq4                                            |
//|  Exports D1 candles + iCustom signals to CSV for backtester.     |
//|  Reads bridge_config_<BridgeRunId>.ini from Common/Files/.       |
//+------------------------------------------------------------------+
#property strict

input string BridgeRunId = "";   // Set by tester .set file

//--- Parsed config
string g_IndicatorName = "";
string g_Symbols[10];
int    g_SymbolCount   = 0;
string g_FromDate      = "";
string g_ToDate        = "";
string g_OutputSubdir  = "";
bool   g_Initialized   = false;

//+------------------------------------------------------------------+
int OnInit()
{
   if (BridgeRunId == "") {
      Print("NNFXBridgeRunner: BridgeRunId is empty. Aborting.");
      ExpertRemove();
      return INIT_FAILED;
   }

   string cfgFile = "bridge_config_" + BridgeRunId + ".ini";
   if (!_ParseBridgeConfig(cfgFile)) {
      _WriteDoneMarker("failed\nCould not read bridge config: " + cfgFile);
      ExpertRemove();
      return INIT_FAILED;
   }

   g_Initialized = true;
   EventSetTimer(1);  // Fire OnTimer after 1 second
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
void OnTimer()
{
   EventKillTimer();
   if (!g_Initialized) return;

   string outDir = g_OutputSubdir + "/";
   string candlesFile = outDir + "normalized_candles.csv";
   string signalsFile = outDir + "normalized_signals.csv";

   // Open output CSV file handles (FILE_COMMON | FILE_WRITE | FILE_CSV)
   int hCandles = FileOpen(candlesFile, FILE_COMMON | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   int hSignals = FileOpen(signalsFile, FILE_COMMON | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');

   if (hCandles == INVALID_HANDLE || hSignals == INVALID_HANDLE) {
      _WriteDoneMarker("failed\nCannot open output CSV files in Common/Files/" + outDir);
      ExpertRemove();
      return;
   }

   // Write headers
   FileWrite(hCandles, "timestamp", "symbol", "timeframe", "open", "high", "low", "close", "volume");
   FileWrite(hSignals, "timestamp", "symbol", "signal");

   datetime dtFrom = _ParseDate(g_FromDate);
   datetime dtTo   = _ParseDate(g_ToDate);

   for (int s = 0; s < g_SymbolCount; s++) {
      string sym = g_Symbols[s];
      int totalBars = iBars(sym, PERIOD_D1);
      if (totalBars <= 0) {
         Print("NNFXBridgeRunner: No D1 bars for ", sym, ". Skipping.");
         continue;
      }

      for (int i = totalBars - 1; i >= 0; i--) {
         datetime barTime = iTime(sym, PERIOD_D1, i);
         if (barTime < dtFrom || barTime > dtTo) continue;

         string ts    = TimeToString(barTime, TIME_DATE | TIME_MINUTES);
         double op    = iOpen(sym,   PERIOD_D1, i);
         double hi    = iHigh(sym,   PERIOD_D1, i);
         double lo    = iLow(sym,    PERIOD_D1, i);
         double cl    = iClose(sym,  PERIOD_D1, i);
         long   vol   = iVolume(sym, PERIOD_D1, i);

         FileWrite(hCandles,
            ts, sym, "D1",
            DoubleToString(op, 5),
            DoubleToString(hi, 5),
            DoubleToString(lo, 5),
            DoubleToString(cl, 5),
            (string)vol
         );

         // Get raw iCustom value on buffer 0
         double sigRaw = iCustom(sym, PERIOD_D1, g_IndicatorName, 0, i);
         int    sig    = _MapSignal(sigRaw);

         FileWrite(hSignals, ts, sym, (string)sig);
      }
   }

   FileClose(hCandles);
   FileClose(hSignals);

   _WriteDoneMarker("done");
   ExpertRemove();
}

//+------------------------------------------------------------------+
void OnTick() {}

//+------------------------------------------------------------------+
// Helpers
//+------------------------------------------------------------------+
bool _ParseBridgeConfig(string filename)
{
   int h = FileOpen(filename, FILE_COMMON | FILE_READ | FILE_TXT | FILE_ANSI);
   if (h == INVALID_HANDLE) return false;

   while (!FileIsEnding(h)) {
      string line = FileReadString(h);
      if (StringLen(line) == 0) continue;

      int eq = StringFind(line, "=");
      if (eq < 0) continue;

      string key = StringSubstr(line, 0, eq);
      string val = StringSubstr(line, eq + 1);
      StringTrimRight(key); StringTrimLeft(key);
      StringTrimRight(val); StringTrimLeft(val);

      if (key == "indicator_name")  g_IndicatorName = val;
      else if (key == "from_date")  g_FromDate      = val;
      else if (key == "to_date")    g_ToDate        = val;
      else if (key == "output_subdir") g_OutputSubdir = val;
      else if (key == "symbols") {
         g_SymbolCount = 0;
         string parts[];
         int n = StringSplit(val, ',', parts);
         for (int i = 0; i < n && i < 10; i++) {
            StringTrimRight(parts[i]); StringTrimLeft(parts[i]);
            g_Symbols[g_SymbolCount++] = parts[i];
         }
      }
   }

   FileClose(h);
   return (g_IndicatorName != "" && g_SymbolCount > 0);
}

//+------------------------------------------------------------------+
void _WriteDoneMarker(string content)
{
   string markerPath = g_OutputSubdir + "/bridge_done_" + BridgeRunId + ".txt";
   int h = FileOpen(markerPath, FILE_COMMON | FILE_WRITE | FILE_TXT | FILE_ANSI);
   if (h == INVALID_HANDLE) {
      Print("NNFXBridgeRunner: Cannot write done marker at ", markerPath);
      return;
   }
   FileWriteString(h, content + "\n");
   FileClose(h);
}

//+------------------------------------------------------------------+
int _MapSignal(double raw)
{
   if (raw == EMPTY_VALUE) return 0;
   if (raw > 0.5)  return 1;
   if (raw < -0.5) return -1;
   return 0;
}

//+------------------------------------------------------------------+
datetime _ParseDate(string s)
{
   // Accepts YYYY.MM.DD
   if (StringLen(s) < 10) return 0;
   string y = StringSubstr(s, 0, 4);
   string m = StringSubstr(s, 5, 2);
   string d = StringSubstr(s, 8, 2);
   return StringToTime(y + "." + m + "." + d + " 00:00");
}
