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
echo  INTEGRATION TEST CHECKLIST (v2 — single EA)
echo ================================================================
echo  LAUNCHER:
echo    [ ] 1. Open any live chart (e.g. EURUSD D1).
echo    [ ] 2. Drag NNFXLitePro1 EA onto it.
echo           Launcher screen appears with Pair, Start/End Date, Balance.
echo           Fields pre-filled from extern inputs, editable.
echo    [ ] 3. Click START SIMULATION.
echo           Journal: HST build success, offline chart opens.
echo           HUD appears: "State: PLAYING", bars start feeding.
echo.
echo  PLAYBACK:
echo    [ ] 4. Click PAUSE — state changes to PAUSED, bars stop.
echo    [ ] 5. Click STEP — exactly one bar advances.
echo    [ ] 6. Click RESUME — state changes to PLAYING, bars resume.
echo    [ ] 7. Click ^>^> FWD / ^<^< SLW — speed changes (1-5).
echo           Journal: "Speed -^> N (Xms)"
echo    [ ] 8. Click STOP (or let test run to completion).
echo           Journal: "[NNFXLitePro1] Sim finished."
echo           CSVs written to MT4 Common\Files\.
echo.
echo  ERROR CASES:
echo    [ ] 9.  Remove EA mid-sim — graceful shutdown, CSV written.
echo    [ ] 10. Invalid date range on launcher — error in log, stays.
echo    [ ] 11. Empty pair name — error in log, stays on launcher.
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
