@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Open WebUI offline bundle creator for Internet-connected Windows x64 PC.
REM Docker is not used. Ollama is intentionally installed and operated separately.

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "SRC=%ROOT%"
set "BUNDLE=%ROOT%\offline-bundle"
set "STAGE=%BUNDLE%\source-stage"
set "DIST=%BUNDLE%\dist"
set "WHEELHOUSE=%BUNDLE%\wheelhouse"
set "SEED_DATA=%BUNDLE%\seed-data"
set "INSTALLERS=%BUNDLE%\installers"
set "BUILD_VENV=%BUNDLE%\.build-venv"

if not exist "%SRC%\pyproject.toml" (
  echo [ERROR] Open WebUI source not found: %SRC%
  exit /b 1
)

if not exist "%SRC%\package-lock.json" (
  echo [ERROR] package-lock.json is required for reproducible npm ci builds.
  exit /b 1
)

rmdir /s /q "%BUNDLE%" 2>nul
mkdir "%DIST%" "%WHEELHOUSE%" "%SEED_DATA%" "%INSTALLERS%"
if errorlevel 1 exit /b 1

where npm >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js/npm is required on the online packaging PC.
  exit /b 1
)

for /f "delims=" %%P in ('py -3.11 -c "import sys; print(sys.executable)" 2^>nul') do set "BASE_PY=%%P"
if not defined BASE_PY (
  echo [ERROR] Python 3.11 is required on the online packaging PC.
  exit /b 1
)

echo [1/8] Downloading offline installers...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe' -OutFile '%INSTALLERS%\python-3.11.9-amd64.exe'"
if errorlevel 1 exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile '%INSTALLERS%\vc_redist.x64.exe'"
if errorlevel 1 exit /b 1

echo [2/8] Creating isolated source stage...
robocopy "%SRC%" "%STAGE%" /MIR /XD .git .gjc .venv Python311 data offline-bundle node_modules .svelte-kit build dist __pycache__ /XF .env >nul
if errorlevel 8 exit /b 1

REM Upstream hatch_build.py uses npm install, which can ignore the lockfile enough to break frontend builds.
REM Patch only the disposable source-stage copy so the real repository is not modified.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%STAGE%\hatch_build.py'; $s=Get-Content $p -Raw; $s=$s -replace \"subprocess\.run\(\[npm, 'install', '--force'\], check=True\)\", \"subprocess.run([npm, 'ci', '--force'], check=True)\"; Set-Content -Path $p -Value $s -Encoding UTF8"
if errorlevel 1 exit /b 1

echo [3/8] Creating build virtual environment...
"%BASE_PY%" -m venv "%BUILD_VENV%"
if errorlevel 1 exit /b 1
set "PYEXE=%BUILD_VENV%\Scripts\python.exe"

echo [4/8] Installing build tools...
"%PYEXE%" -m pip install --upgrade pip build wheel
if errorlevel 1 exit /b 1

echo [5/8] Building Open WebUI wheel with frontend...
pushd "%STAGE%"
"%PYEXE%" -m build --wheel --outdir "%DIST%"
if errorlevel 1 exit /b 1
popd

set "OW_WHEEL="
for %%F in ("%DIST%\open_webui-*.whl") do set "OW_WHEEL=%%~fF"
if not defined OW_WHEEL (
  echo [ERROR] Open WebUI wheel was not created.
  exit /b 1
)
copy /Y "%OW_WHEEL%" "%WHEELHOUSE%\"
if errorlevel 1 exit /b 1

echo [6/8] Downloading Python dependency wheels...
"%PYEXE%" -m pip download --dest "%WHEELHOUSE%" --only-binary=:all: "%OW_WHEEL%"
if errorlevel 1 exit /b 1
"%PYEXE%" -m pip download --dest "%WHEELHOUSE%" --only-binary=:all: pip setuptools wheel
if errorlevel 1 exit /b 1

echo [7/8] Verifying offline install and pre-downloading runtime caches...
"%BASE_PY%" -m venv "%BUNDLE%\.seed-venv"
if errorlevel 1 exit /b 1
"%BUNDLE%\.seed-venv\Scripts\python.exe" -m pip install --no-index --find-links "%WHEELHOUSE%" open-webui
if errorlevel 1 exit /b 1

set "DATA_DIR=%SEED_DATA%"
set "HF_HOME=%SEED_DATA%\cache\embedding\models"
set "SENTENCE_TRANSFORMERS_HOME=%SEED_DATA%\cache\embedding\models"
set "WHISPER_MODEL_DIR=%SEED_DATA%\cache\whisper\models"
set "TIKTOKEN_CACHE_DIR=%SEED_DATA%\cache\tiktoken"
set "NLTK_DATA=%SEED_DATA%\cache\nltk"
set "RAG_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2"
set "AUXILIARY_EMBEDDING_MODEL=TaylorAI/bge-micro-v2"
set "WHISPER_MODEL=base"
set "TIKTOKEN_ENCODING_NAME=cl100k_base"

"%BUNDLE%\.seed-venv\Scripts\python.exe" -c "import os, nltk, tiktoken; from sentence_transformers import SentenceTransformer; from faster_whisper import WhisperModel; SentenceTransformer(os.environ['RAG_EMBEDDING_MODEL'], device='cpu'); SentenceTransformer(os.environ['AUXILIARY_EMBEDDING_MODEL'], device='cpu'); WhisperModel(os.environ['WHISPER_MODEL'], device='cpu', compute_type='int8', download_root=os.environ['WHISPER_MODEL_DIR']); tiktoken.get_encoding(os.environ['TIKTOKEN_ENCODING_NAME']); nltk.download('punkt_tab', download_dir=os.environ['NLTK_DATA'])"
if errorlevel 1 exit /b 1
"%BUNDLE%\.seed-venv\Scripts\python.exe" -m pip check
if errorlevel 1 exit /b 1
rmdir /s /q "%BUNDLE%\.seed-venv"

echo [8/8] Writing bundle info...
(
  echo Open WebUI offline bundle
  echo Docker: not used
  echo Ollama: separated
  echo Source: %SRC%
  echo Created: %DATE% %TIME%
  echo Python: 3.11 x64
  echo Install: 02_offline_install.bat
  echo Run: 03_run.bat
) > "%BUNDLE%\README-offline.txt"

echo.
echo [OK] Offline bundle created:
echo %BUNDLE%
