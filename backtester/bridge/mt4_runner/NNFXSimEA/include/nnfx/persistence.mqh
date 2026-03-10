//+------------------------------------------------------------------+
//| persistence.mqh — INI read/write, session/preset/snapshot mgmt  |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_PERSISTENCE_MQH
#define NNFX_PERSISTENCE_MQH

//+------------------------------------------------------------------+
//| Session Config Structure (global, shared across modules)        |
//+------------------------------------------------------------------+
string g_CFG_Symbol          = "EURUSD";
string g_CFG_StartDate       = "2020.01.01";
string g_CFG_EndDate         = "2024.12.31";
double g_CFG_Balance         = 10000.0;
int    g_CFG_Leverage        = 100;
int    g_CFG_SpreadMode      = 0;          // 0=FIXED_PIPS, 1=CURRENT_MARKET
double g_CFG_FixedSpreadPips = 2.0;
double g_CFG_CommissionRT    = 0.0;

string g_CFG_C1Name          = "";
string g_CFG_C1Params        = "";
string g_CFG_C1ParamTypes    = "";
int    g_CFG_SigType         = 0;         // 0=CROSS, 1=ZERO_CROSS, 2=STATE_CHANGE
int    g_CFG_FastBuf         = 0;
int    g_CFG_SlowBuf         = 1;
double g_CFG_BuyThresh       = 0.0;
double g_CFG_SellThresh      = 0.0;
int    g_CFG_StateBuyRule    = 0;
int    g_CFG_StateSellRule   = 1;
double g_CFG_StateLevel      = 0.0;

int    g_CFG_SLMode          = 1;         // 0=FIXED, 1=ATR
double g_CFG_SLPips          = 100.0;
double g_CFG_ATRMult         = 1.5;
int    g_CFG_TPMode          = 0;         // 0=RR, 1=ATR
double g_CFG_RR              = 1.5;
double g_CFG_TPATRMult       = 2.0;
int    g_CFG_LotMode         = 1;         // 0=FIXED, 1=RISK_PCT
double g_CFG_RiskPct         = 1.0;
double g_CFG_FixedLot        = 0.01;

string g_CFG_SessionId       = "";

//+------------------------------------------------------------------+
void Persistence_Init(string sessionId)
{
    g_CFG_SessionId = sessionId;
}

//+------------------------------------------------------------------+
// Generate a pseudo-UUID from time + account
string Persistence_GenSessionId()
{
    string s = StringFormat("%d_%d_%d",
        (int)TimeCurrent(),
        AccountNumber(),
        MathRand());
    return s;
}

//+------------------------------------------------------------------+
// Write a single INI key=value
void _INI_Write(int h, string key, string val)
{
    FileWriteString(h, key + "=" + val + "\n");
}

//+------------------------------------------------------------------+
// Write an INI section header
void _INI_Section(int h, string section)
{
    FileWriteString(h, "[" + section + "]\n");
}

//+------------------------------------------------------------------+
// Parse a single INI line into key/val (returns false if no '=')
bool _INI_ParseLine(string line, string &key, string &val)
{
    int eq = StringFind(line, "=");
    if(eq < 0) return false;
    key = StringSubstr(line, 0, eq);
    val = StringSubstr(line, eq + 1);
    StringTrimRight(key); StringTrimLeft(key);
    StringTrimRight(val); StringTrimLeft(val);
    return true;
}

//+------------------------------------------------------------------+
// Skip comment lines and section headers
bool _INI_IsDataLine(string line)
{
    if(StringLen(line) == 0) return false;
    string c = StringSubstr(line, 0, 1);
    if(c == ";" || c == "#" || c == "[") return false;
    return true;
}

//+------------------------------------------------------------------+
// Load config values from an open INI file handle
void _INI_LoadConfig(int h)
{
    while(!FileIsEnding(h))
    {
        string line = FileReadString(h);
        if(!_INI_IsDataLine(line)) continue;

        string key, val;
        if(!_INI_ParseLine(line, key, val)) continue;

        if(key == "symbol")               g_CFG_Symbol        = val;
        else if(key == "start_date")      g_CFG_StartDate     = val;
        else if(key == "end_date")        g_CFG_EndDate       = val;
        else if(key == "starting_balance") g_CFG_Balance      = StringToDouble(val);
        else if(key == "leverage")        g_CFG_Leverage      = (int)StringToInteger(val);
        else if(key == "spread_mode")     g_CFG_SpreadMode    = (int)StringToInteger(val);
        else if(key == "fixed_spread_pips") g_CFG_FixedSpreadPips = StringToDouble(val);
        else if(key == "commission_per_lot_rt") g_CFG_CommissionRT = StringToDouble(val);
        else if(key == "c1_indicator_name") g_CFG_C1Name      = val;
        else if(key == "c1_indicator_params") g_CFG_C1Params  = val;
        else if(key == "c1_indicator_param_types") g_CFG_C1ParamTypes = val;
        else if(key == "signal_type")     g_CFG_SigType       = (int)StringToInteger(val);
        else if(key == "fast_buffer")     g_CFG_FastBuf       = (int)StringToInteger(val);
        else if(key == "slow_buffer")     g_CFG_SlowBuf       = (int)StringToInteger(val);
        else if(key == "buy_threshold")   g_CFG_BuyThresh     = StringToDouble(val);
        else if(key == "sell_threshold")  g_CFG_SellThresh    = StringToDouble(val);
        else if(key == "state_buy_rule")  g_CFG_StateBuyRule  = (int)StringToInteger(val);
        else if(key == "state_sell_rule") g_CFG_StateSellRule = (int)StringToInteger(val);
        else if(key == "state_level")     g_CFG_StateLevel    = StringToDouble(val);
        else if(key == "sl_mode")         g_CFG_SLMode        = (int)StringToInteger(val);
        else if(key == "sl_pips")         g_CFG_SLPips        = StringToDouble(val);
        else if(key == "sl_atr_mult")     g_CFG_ATRMult       = StringToDouble(val);
        else if(key == "tp_mode")         g_CFG_TPMode        = (int)StringToInteger(val);
        else if(key == "tp_rr")           g_CFG_RR            = StringToDouble(val);
        else if(key == "tp_atr_mult")     g_CFG_TPATRMult     = StringToDouble(val);
        else if(key == "lot_mode")        g_CFG_LotMode       = (int)StringToInteger(val);
        else if(key == "risk_pct")        g_CFG_RiskPct       = StringToDouble(val);
        else if(key == "fixed_lot")       g_CFG_FixedLot      = StringToDouble(val);
    }
}

//+------------------------------------------------------------------+
// Write all config values to an open INI file handle
void _INI_WriteConfig(int h)
{
    _INI_Write(h, "symbol",               g_CFG_Symbol);
    _INI_Write(h, "start_date",           g_CFG_StartDate);
    _INI_Write(h, "end_date",             g_CFG_EndDate);
    _INI_Write(h, "starting_balance",     DoubleToString(g_CFG_Balance, 2));
    _INI_Write(h, "leverage",             IntegerToString(g_CFG_Leverage));
    _INI_Write(h, "spread_mode",          IntegerToString(g_CFG_SpreadMode));
    _INI_Write(h, "fixed_spread_pips",    DoubleToString(g_CFG_FixedSpreadPips, 2));
    _INI_Write(h, "commission_per_lot_rt", DoubleToString(g_CFG_CommissionRT, 2));
    _INI_Write(h, "c1_indicator_name",    g_CFG_C1Name);
    _INI_Write(h, "c1_indicator_params",  g_CFG_C1Params);
    _INI_Write(h, "c1_indicator_param_types", g_CFG_C1ParamTypes);
    _INI_Write(h, "signal_type",          IntegerToString(g_CFG_SigType));
    _INI_Write(h, "fast_buffer",          IntegerToString(g_CFG_FastBuf));
    _INI_Write(h, "slow_buffer",          IntegerToString(g_CFG_SlowBuf));
    _INI_Write(h, "buy_threshold",        DoubleToString(g_CFG_BuyThresh, 6));
    _INI_Write(h, "sell_threshold",       DoubleToString(g_CFG_SellThresh, 6));
    _INI_Write(h, "state_buy_rule",       IntegerToString(g_CFG_StateBuyRule));
    _INI_Write(h, "state_sell_rule",      IntegerToString(g_CFG_StateSellRule));
    _INI_Write(h, "state_level",          DoubleToString(g_CFG_StateLevel, 6));
    _INI_Write(h, "sl_mode",              IntegerToString(g_CFG_SLMode));
    _INI_Write(h, "sl_pips",              DoubleToString(g_CFG_SLPips, 2));
    _INI_Write(h, "sl_atr_mult",          DoubleToString(g_CFG_ATRMult, 4));
    _INI_Write(h, "tp_mode",              IntegerToString(g_CFG_TPMode));
    _INI_Write(h, "tp_rr",                DoubleToString(g_CFG_RR, 4));
    _INI_Write(h, "tp_atr_mult",          DoubleToString(g_CFG_TPATRMult, 4));
    _INI_Write(h, "lot_mode",             IntegerToString(g_CFG_LotMode));
    _INI_Write(h, "risk_pct",             DoubleToString(g_CFG_RiskPct, 4));
    _INI_Write(h, "fixed_lot",            DoubleToString(g_CFG_FixedLot, 5));
}

//+------------------------------------------------------------------+
bool Persistence_SavePreset(string presetName)
{
    string path = "nnfx_sim/presets/" + presetName + ".ini";
    int h = FileOpen(path, FILE_COMMON | FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE)
    {
        Print("Persistence_SavePreset: Cannot write ", path, " err=", GetLastError());
        return false;
    }
    _INI_WriteConfig(h);
    FileClose(h);
    Print("Persistence_SavePreset: Saved to ", path);
    return true;
}

//+------------------------------------------------------------------+
bool Persistence_LoadPreset(string presetName)
{
    string path = "nnfx_sim/presets/" + presetName + ".ini";
    int h = FileOpen(path, FILE_COMMON | FILE_READ | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE)
    {
        Print("Persistence_LoadPreset: Cannot read ", path, " err=", GetLastError());
        return false;
    }
    _INI_LoadConfig(h);
    FileClose(h);
    Print("Persistence_LoadPreset: Loaded from ", path);
    return true;
}

//+------------------------------------------------------------------+
bool Persistence_SaveSession(string sessionId)
{
    string path = "nnfx_sim/sessions/" + sessionId + ".ini";
    int h = FileOpen(path, FILE_COMMON | FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE)
    {
        Print("Persistence_SaveSession: Cannot write ", path, " err=", GetLastError());
        return false;
    }
    _INI_WriteConfig(h);
    FileClose(h);
    return true;
}

//+------------------------------------------------------------------+
bool Persistence_LoadSession(string sessionId)
{
    string path = "nnfx_sim/sessions/" + sessionId + ".ini";
    int h = FileOpen(path, FILE_COMMON | FILE_READ | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE)
    {
        Print("Persistence_LoadSession: Cannot read ", path, " err=", GetLastError());
        return false;
    }
    _INI_LoadConfig(h);
    FileClose(h);
    return true;
}

//+------------------------------------------------------------------+
// Write deterministic run snapshot before first replay step
bool Persistence_WriteSnapshot()
{
    string path = "nnfx_sim/sessions/" + g_CFG_SessionId + "_snapshot.ini";
    int h = FileOpen(path, FILE_COMMON | FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(h == INVALID_HANDLE)
    {
        Print("Persistence_WriteSnapshot: Cannot write ", path, " err=", GetLastError());
        return false;
    }

    string nowStr = TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);

    // [meta]
    FileWriteString(h, "[meta]\n");
    _INI_Write(h, "ea_version",        "2.0");
    _INI_Write(h, "build_timestamp",   "2025-03-10T00:00:00");
    _INI_Write(h, "session_id",        g_CFG_SessionId);
    _INI_Write(h, "snapshot_written",  nowStr);
    FileWriteString(h, "\n");

    // [sim_config]
    FileWriteString(h, "[sim_config]\n");
    _INI_Write(h, "symbol",               g_CFG_Symbol);
    _INI_Write(h, "start_date",           g_CFG_StartDate);
    _INI_Write(h, "end_date",             g_CFG_EndDate);
    _INI_Write(h, "starting_balance",     DoubleToString(g_CFG_Balance, 2));
    _INI_Write(h, "leverage",             IntegerToString(g_CFG_Leverage));
    _INI_Write(h, "spread_mode",          IntegerToString(g_CFG_SpreadMode));
    _INI_Write(h, "fixed_spread_pips",    DoubleToString(g_CFG_FixedSpreadPips, 2));
    _INI_Write(h, "commission_per_lot_rt", DoubleToString(g_CFG_CommissionRT, 2));
    FileWriteString(h, "\n");

    // [strategy]
    FileWriteString(h, "[strategy]\n");
    _INI_Write(h, "c1_indicator_name",    g_CFG_C1Name);
    _INI_Write(h, "c1_indicator_params",  g_CFG_C1Params);
    _INI_Write(h, "signal_type",          IntegerToString(g_CFG_SigType));
    _INI_Write(h, "fast_buffer",          IntegerToString(g_CFG_FastBuf));
    _INI_Write(h, "slow_buffer",          IntegerToString(g_CFG_SlowBuf));
    _INI_Write(h, "buy_threshold",        DoubleToString(g_CFG_BuyThresh, 6));
    _INI_Write(h, "sell_threshold",       DoubleToString(g_CFG_SellThresh, 6));
    _INI_Write(h, "state_buy_rule",       IntegerToString(g_CFG_StateBuyRule));
    _INI_Write(h, "state_sell_rule",      IntegerToString(g_CFG_StateSellRule));
    _INI_Write(h, "state_level",          DoubleToString(g_CFG_StateLevel, 6));
    FileWriteString(h, "\n");

    // [risk]
    FileWriteString(h, "[risk]\n");
    string slModeStr = (g_CFG_SLMode == 1) ? "ATR" : "FIXED";
    string tpModeStr = (g_CFG_TPMode == 0) ? "RR" : "ATR";
    string lotModeStr = (g_CFG_LotMode == 1) ? "RISK_PCT" : "FIXED";
    _INI_Write(h, "sl_mode",      slModeStr);
    _INI_Write(h, "tp_mode",      tpModeStr);
    _INI_Write(h, "sl_atr_mult",  DoubleToString(g_CFG_ATRMult, 4));
    _INI_Write(h, "tp_rr",        DoubleToString(g_CFG_RR, 4));
    _INI_Write(h, "lot_mode",     lotModeStr);
    _INI_Write(h, "risk_pct",     DoubleToString(g_CFG_RiskPct, 4));
    _INI_Write(h, "fixed_lot",    DoubleToString(g_CFG_FixedLot, 5));

    FileClose(h);
    Print("Persistence_WriteSnapshot: Written to ", path);
    return true;
}

//+------------------------------------------------------------------+
void Persistence_CloseAll()
{
    // No persistent handles to close in this module (handles opened/closed per call)
}

#endif // NNFX_PERSISTENCE_MQH
