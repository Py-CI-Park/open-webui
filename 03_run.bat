@echo off
setlocal EnableExtensions

REM Open WebUI air-gapped runtime launcher.
REM Docker is not used. Ollama is intentionally installed and operated separately.

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "VENV=%ROOT%\.venv"
set "DATA_DIR=%ROOT%\data"

if not exist "%VENV%\Scripts\open-webui.exe" (
  echo [ERROR] Open WebUI is not installed. Run 02_offline_install.bat first.
  exit /b 1
)

cd /d "%ROOT%"

set "ENV=prod"
set "HOST=0.0.0.0"
set "PORT=8080"
set "DATA_DIR=%DATA_DIR%"
set "STATIC_DIR=%DATA_DIR%\static"

set "OFFLINE_MODE=true"
set "HF_HUB_OFFLINE=1"
set "TRANSFORMERS_OFFLINE=1"
set "ENABLE_VERSION_UPDATE_CHECK=false"
set "ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS=false"

set "SCARF_NO_ANALYTICS=true"
set "DO_NOT_TRACK=true"
set "ANONYMIZED_TELEMETRY=false"

set "HF_HOME=%DATA_DIR%\cache\embedding\models"
set "SENTENCE_TRANSFORMERS_HOME=%DATA_DIR%\cache\embedding\models"
set "WHISPER_MODEL_DIR=%DATA_DIR%\cache\whisper\models"
set "TIKTOKEN_CACHE_DIR=%DATA_DIR%\cache\tiktoken"
set "NLTK_DATA=%DATA_DIR%\cache\nltk"

set "RAG_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2"
set "AUXILIARY_EMBEDDING_MODEL=TaylorAI/bge-micro-v2"
set "WHISPER_MODEL=base"
set "TIKTOKEN_ENCODING_NAME=cl100k_base"

REM Ollama is separate. Adjust this URL for your closed-network Ollama server.
REM Same Windows server:
set "OLLAMA_BASE_URL=http://127.0.0.1:11434"
REM Separate closed-network server example:
REM set "OLLAMA_BASE_URL=http://192.168.0.50:11434"

echo Starting Open WebUI...
echo URL: http://127.0.0.1:%PORT%
echo LAN URL: http://SERVER_IP:%PORT%
echo DATA_DIR: %DATA_DIR%
echo OLLAMA_BASE_URL: %OLLAMA_BASE_URL%

"%VENV%\Scripts\open-webui.exe" serve --host %HOST% --port %PORT%
