@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Open WebUI offline installer for air-gapped Windows x64 server.
REM Run after copying offline-bundle from the online packaging PC.
REM Docker is not used. Ollama is intentionally installed and operated separately.

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "BUNDLE=%ROOT%\offline-bundle"
set "WHEELHOUSE=%BUNDLE%\wheelhouse"
set "DATA_DIR=%ROOT%\data"
set "VENV=%ROOT%\.venv"

if not exist "%WHEELHOUSE%" (
  echo [ERROR] Wheelhouse not found: %WHEELHOUSE%
  echo [ERROR] Copy offline-bundle first or run 01_online_package.bat on the online PC.
  exit /b 1
)

for /f "delims=" %%P in ('py -3.11 -c "import sys; print(sys.executable)" 2^>nul') do set "PYEXE=%%P"

if not defined PYEXE (
  if exist "%BUNDLE%\installers\python-3.11.9-amd64.exe" (
    echo [INFO] Installing bundled Python 3.11...
    start /wait "" "%BUNDLE%\installers\python-3.11.9-amd64.exe" /quiet InstallAllUsers=0 TargetDir="%ROOT%\Python311" Include_pip=1 Include_launcher=0 PrependPath=0
    set "PYEXE=%ROOT%\Python311\python.exe"
  ) else (
    echo [ERROR] Python 3.11 not found and bundled installer is missing.
    exit /b 1
  )
)

if not exist "%PYEXE%" (
  echo [ERROR] Python executable not found: %PYEXE%
  exit /b 1
)

if exist "%BUNDLE%\installers\vc_redist.x64.exe" (
  echo [INFO] Installing VC++ runtime...
  start /wait "" "%BUNDLE%\installers\vc_redist.x64.exe" /quiet /norestart
)

echo [1/5] Creating virtual environment...
rmdir /s /q "%VENV%" 2>nul
"%PYEXE%" -m venv "%VENV%"
if errorlevel 1 exit /b 1

echo [2/5] Installing Open WebUI offline...
"%VENV%\Scripts\python.exe" -m pip install --no-index --find-links "%WHEELHOUSE%" open-webui
if errorlevel 1 exit /b 1

echo [3/5] Verifying installed packages...
"%VENV%\Scripts\python.exe" -m pip check
if errorlevel 1 exit /b 1
"%VENV%\Scripts\python.exe" -c "import open_webui; print('open_webui import OK')"
if errorlevel 1 exit /b 1

echo [4/5] Copying seeded cache/data...
mkdir "%DATA_DIR%" 2>nul
if exist "%BUNDLE%\seed-data" (
  robocopy "%BUNDLE%\seed-data" "%DATA_DIR%" /E
  if errorlevel 8 exit /b 1
)

echo [5/5] Creating runtime directories...
mkdir "%DATA_DIR%\cache\embedding\models" 2>nul
mkdir "%DATA_DIR%\cache\whisper\models" 2>nul
mkdir "%DATA_DIR%\cache\tiktoken" 2>nul
mkdir "%DATA_DIR%\cache\nltk" 2>nul
mkdir "%DATA_DIR%\static" 2>nul

echo.
echo [OK] Offline installation complete.
echo Run:
echo %ROOT%\03_run.bat
