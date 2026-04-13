//+------------------------------------------------------------------+
//| chart_attach.mqh — Auto-attach C1 indicator to offline chart     |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_CHART_ATTACH_MQH
#define NNFXLITE_CHART_ATTACH_MQH

//+------------------------------------------------------------------+
//| Write a full MT4 chart template that attaches the given custom
//| indicator in a subwindow, then apply it via ChartApplyTemplate.
//|
//| Format is taken from a real MT4-saved offline chart template
//| (history/deleted/EURUSD_SIM-Daily.tpl). MT4 is strict — the
//| minimal header that "looks reasonable" is rejected with Err 5020.
//|
//| Key requirements:
//|  - Full chart header (offline=1, period=1440, digits=5, etc.)
//|  - Custom indicator declared via <expert> sub-block,
//|    NOT via the old path= / apply= fields
//|  - Integer window heights (MT4 rejects float decimals)
//|  - Main window indicator name is lowercase "main"
//+------------------------------------------------------------------+
bool CA_ApplyC1Template(long chartId, string indName)
{
    if(chartId <= 0) return false;
    if(indName == "")
    {
        Print("[CA] Skipped: no C1 indicator name set.");
        return false;
    }

    StringTrimLeft(indName);
    StringTrimRight(indName);

    string tplName = "nnfxlite_c1.tpl";
    int h = FileOpen(tplName, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(h < 0)
    {
        Print("[CA] ERROR: cannot create template ", tplName,
              ". Err=", GetLastError());
        return false;
    }

    //--- Chart header (matches MT4 auto-saved offline chart template)
    FileWriteString(h, "<chart>\r\n");
    FileWriteString(h, "id=0\r\n");
    FileWriteString(h, "symbol=" + ChartSymbol(chartId) + "\r\n");
    FileWriteString(h, "period=1440\r\n");
    FileWriteString(h, "leftpos=0\r\n");
    FileWriteString(h, "offline=1\r\n");
    FileWriteString(h, "digits=5\r\n");
    FileWriteString(h, "scale=32\r\n");
    FileWriteString(h, "graph=0\r\n");
    FileWriteString(h, "fore=0\r\n");
    FileWriteString(h, "grid=1\r\n");
    FileWriteString(h, "volume=0\r\n");
    FileWriteString(h, "scroll=1\r\n");
    FileWriteString(h, "shift=0\r\n");
    FileWriteString(h, "ohlc=1\r\n");
    FileWriteString(h, "one_click=0\r\n");
    FileWriteString(h, "one_click_btn=1\r\n");
    FileWriteString(h, "askline=0\r\n");
    FileWriteString(h, "days=0\r\n");
    FileWriteString(h, "descriptions=0\r\n");
    FileWriteString(h, "shift_size=20\r\n");
    FileWriteString(h, "fixed_pos=0\r\n");
    FileWriteString(h, "window_left=26\r\n");
    FileWriteString(h, "window_top=26\r\n");
    FileWriteString(h, "window_right=1660\r\n");
    FileWriteString(h, "window_bottom=639\r\n");
    FileWriteString(h, "window_type=3\r\n");
    FileWriteString(h, "background_color=0\r\n");
    FileWriteString(h, "foreground_color=16777215\r\n");
    FileWriteString(h, "barup_color=65280\r\n");
    FileWriteString(h, "bardown_color=65280\r\n");
    FileWriteString(h, "bullcandle_color=0\r\n");
    FileWriteString(h, "bearcandle_color=16777215\r\n");
    FileWriteString(h, "chartline_color=65280\r\n");
    FileWriteString(h, "volumes_color=3329330\r\n");
    FileWriteString(h, "grid_color=4294967295\r\n");
    FileWriteString(h, "askline_color=255\r\n");
    FileWriteString(h, "stops_color=255\r\n");
    FileWriteString(h, "\r\n");

    //--- Main price window. Blank line before <window> matches MT4's format.
    FileWriteString(h, "<window>\r\n");
    FileWriteString(h, "height=100\r\n");
    FileWriteString(h, "fixed_height=0\r\n");
    FileWriteString(h, "<indicator>\r\n");
    FileWriteString(h, "name=main\r\n");
    FileWriteString(h, "</indicator>\r\n");
    FileWriteString(h, "</window>\r\n");
    FileWriteString(h, "\r\n");

    //--- Custom indicator subwindow. The <expert> block is what makes
    //    MT4 actually load the indicator — path= / apply= fields are
    //    NOT used for custom indicators and cause silent failure.
    FileWriteString(h, "<window>\r\n");
    FileWriteString(h, "height=50\r\n");
    FileWriteString(h, "fixed_height=0\r\n");
    FileWriteString(h, "<indicator>\r\n");
    FileWriteString(h, "name=Custom Indicator\r\n");
    FileWriteString(h, "<expert>\r\n");
    FileWriteString(h, "name=" + indName + "\r\n");
    FileWriteString(h, "flags=339\r\n");
    FileWriteString(h, "window_num=1\r\n");
    FileWriteString(h, "<inputs>\r\n");
    FileWriteString(h, "</inputs>\r\n");
    FileWriteString(h, "</expert>\r\n");
    FileWriteString(h, "period_flags=0\r\n");
    FileWriteString(h, "show_data=1\r\n");
    FileWriteString(h, "</indicator>\r\n");
    FileWriteString(h, "</window>\r\n");
    FileWriteString(h, "</chart>\r\n");
    FileClose(h);

    Print("[CA] Wrote template with custom indicator: ", indName);

    //--- Try common path variants. MT4 build variation means the
    //    "correct" path differs across installs; we try them in order
    //    and report which one worked.
    string tplPaths[3];
    tplPaths[0] = "Files\\" + tplName;
    tplPaths[1] = "\\Files\\" + tplName;
    tplPaths[2] = tplName;

    for(int i = 0; i < 3; i++)
    {
        ResetLastError();
        if(ChartApplyTemplate(chartId, tplPaths[i]))
        {
            ChartRedraw(chartId);
            Print("[CA] Attached C1 indicator to offline chart: ",
                  indName, " (path=", tplPaths[i], ")");
            return true;
        }
        Print("[CA] ChartApplyTemplate try ", (i+1), "/3 path='",
              tplPaths[i], "' failed. Err=", GetLastError());
    }

    Print("[CA] ERROR: All path variants failed. Indicator must be ",
          "attached manually via Navigator.");
    return false;
}

#endif // NNFXLITE_CHART_ATTACH_MQH
