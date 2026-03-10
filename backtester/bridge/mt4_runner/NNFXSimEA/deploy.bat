@echo off
REM ================================================================
REM  NNFXSimEA v2.0 Deployment Script
REM  Usage: deploy.bat [MT4_DATA_PATH]
REM  Default MT4 data path: C:\Users\win10pro\AppData\Roaming\MetaQuotes\Terminal\98A82F92176B73A2100FCD1F8ABD7255
REM ================================================================

SET MT4=%1
IF "%MT4%"=="" SET MT4=C:\Users\win10pro\AppData\Roaming\MetaQuotes\Terminal\98A82F92176B73A2100FCD1F8ABD7255

SET SRC=%~dp0

echo.
echo ================================================================
echo  NNFXSimEA v2.0 Deployer
echo  Source: %SRC%
echo  Target: %MT4%
echo ================================================================
echo.

REM Create destination directories
IF NOT EXIST "%MT4%\MQL4\Experts\" (
    echo Creating Experts directory...
    mkdir "%MT4%\MQL4\Experts\"
)
IF NOT EXIST "%MT4%\MQL4\Include\nnfx\" (
    echo Creating Include\nnfx directory...
    mkdir "%MT4%\MQL4\Include\nnfx\"
)

REM Copy main EA
echo Copying NNFXSimEA.mq4...
xcopy /Y "%SRC%NNFXSimEA.mq4" "%MT4%\MQL4\Experts\"
IF ERRORLEVEL 1 (
    echo ERROR: Failed to copy NNFXSimEA.mq4
    goto :error
)

REM Copy include files
echo Copying include files...
xcopy /Y /I "%SRC%include\nnfx\*" "%MT4%\MQL4\Include\nnfx\"
IF ERRORLEVEL 1 (
    echo ERROR: Failed to copy include files
    goto :error
)

echo.
echo ================================================================
echo  Deploy complete!
echo.
echo  Next steps:
echo  1. Open MetaEditor (in MT4: Tools > MetaEditor or F4)
echo  2. Open: MQL4\Experts\NNFXSimEA.mq4
echo  3. Press F7 to compile — should show 0 errors
echo  4. Attach NNFXSimEA to a D1 chart
echo  5. See NNFXSimEA_InstallNotes.txt for full usage guide
echo ================================================================
echo.
goto :end

:error
echo.
echo DEPLOY FAILED. Check paths and permissions.
echo.
exit /b 1

:end
exit /b 0
