@echo off
setlocal

set MT4_MQL4=C:\Users\win10pro\AppData\Roaming\MetaQuotes\Terminal\98A82F92176B73A2100FCD1F8ABD7255\MQL4
set SRC=%~dp0

echo [NNFXLitePro1] Deploying to: %MT4_MQL4%
echo.

:: ---- Main EA -------------------------------------------------------
echo Copying NNFXLitePro1.mq4  ^(Experts^)...
xcopy /Y "%SRC%NNFXLitePro1.mq4"  "%MT4_MQL4%\Experts\"
if errorlevel 1 goto :err

:: ---- Panel indicator -----------------------------------------------
echo Copying NNFXLitePanel.mq4  ^(Indicators^)...
xcopy /Y "%SRC%NNFXLitePanel.mq4"  "%MT4_MQL4%\Indicators\"
if errorlevel 1 goto :err

:: ---- Setup script --------------------------------------------------
echo Copying NNFXLiteSetup.mq4  ^(Scripts^)...
xcopy /Y "%SRC%NNFXLiteSetup.mq4"  "%MT4_MQL4%\Scripts\"
if errorlevel 1 goto :err

:: ---- Include files -------------------------------------------------
if not exist "%MT4_MQL4%\Include\NNFXLite\" (
    mkdir "%MT4_MQL4%\Include\NNFXLite\"
)
echo Copying include\NNFXLite\*.mqh ...
xcopy /Y "%SRC%include\NNFXLite\*.mqh"  "%MT4_MQL4%\Include\NNFXLite\"
if errorlevel 1 goto :err

echo.
echo [NNFXLitePro1] Deploy complete.
echo.
echo ================================================================
echo  INTEGRATION TEST CHECKLIST
echo ================================================================
echo  SETUP (one time per symbol):
echo    [ ] 1. In MT4: Navigator ^> Scripts ^> NNFXLiteSetup
echo           Drag onto EURUSD chart.
echo           Check journal: "Created EURUSD_SIM1440.hst successfully"
echo    [ ] 2. File ^> Open Offline ^> EURUSD_SIM D1 ^> Open
echo           (If EURUSD_SIM not listed: restart MT4 after step 1)
echo    [ ] 3. Drag NNFXLitePanel onto the EURUSD_SIM offline chart.
echo           Check journal: "[NNFXLitePanel] Initialized"
echo           Verify HUD appears: "State: waiting for EA"
echo.
echo  ATTACH EA:
echo    [ ] 4. Open EURUSD real D1 chart.
echo    [ ] 5. Drag NNFXLitePro1 EA onto it. Set inputs:
echo              SourceSymbol  = EURUSD
echo              SimSymbol     = EURUSD_SIM
echo              TestStartDate = 2021.01.01
echo              TestEndDate   = 2023.12.31
echo              StartingBalance = 10000
echo              C1_IndicatorName = (your indicator name, or leave blank)
echo    [ ] 6. Allow live trading (checkbox in EA properties).
echo           Check journal: "[NNFXLitePro1] Ready. Press PLAY..."
echo           Panel should show: "State: STOPPED  Bar: 0 / NNN"
echo.
echo  PLAYBACK:
echo    [ ] 7. Click PLAY on the panel.
echo           Bars start appearing on the offline chart.
echo           Panel updates: bar counter, date, balance advance.
echo    [ ] 8. Click PAUSE — bar feeding stops.
echo           Click STEP — exactly one bar advances.
echo    [ ] 9. Click >> FWD / << SLW — speed changes (1-5).
echo           Journal shows: "Speed -> N (Xms)"
echo    [ ] 10. Let test run to completion (or click STOP).
echo            Journal: "[NNFXLitePro1] Test finished."
echo            CSVs written to MT4 Common\Files\:
echo              NNFXLitePro1_EURUSD_trades.csv
echo              NNFXLitePro1_EURUSD_summary.csv
echo.
echo  SIGNAL TEST (optional, needs a real C1 indicator):
echo    [ ] 11. Re-attach EA with C1_IndicatorName set.
echo            Run test. Check journal for "[TE] Opened" entries.
echo            Verify trades.csv has rows with TP/SL exit reasons.
echo            Cross-check ProfitFactor in summary.csv.
echo ================================================================
echo.
goto :end

:err
echo.
echo [NNFXLitePro1] ERROR: Copy failed (errorlevel %errorlevel%).
echo Check that MT4 is not locking any files.
exit /b 1

:end
endlocal
pause
