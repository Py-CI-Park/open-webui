# Windows 폐쇄망 설치 및 실행 안내

이 문서는 Docker를 사용하지 않고 Windows x64 환경에서 Open WebUI를 폐쇄망에 구축하는 방법을 정리합니다. 운영 방식은 AeroOne과 동일하게 배치 파일 3개로 나눕니다.

- `01_online_package.bat`: 인터넷망 PC에서 오프라인 번들 생성
- `02_offline_install.bat`: 폐쇄망 서버에서 로컬 wheelhouse로 설치
- `03_run.bat`: 폐쇄망 서버에서 Open WebUI 실행

Ollama는 Open WebUI와 별개로 설치/운영합니다. Open WebUI는 실행 시 `OLLAMA_BASE_URL`로 폐쇄망 내 Ollama 서버에 연결합니다.

## 전제 조건

### 인터넷망 패키징 PC

- Windows x64
- Python 3.11
- Node.js/npm
- 인터넷 접속 가능
- 이 저장소 전체 소스와 `package-lock.json`

### 폐쇄망 서버

- Windows x64
- Docker 불필요
- 인터넷 불필요
- `offline-bundle` 폴더와 배치 파일 3개 필요
- Ollama는 별도 서버 또는 같은 서버에 사전 설치/실행

`02_offline_install.bat`는 폐쇄망 서버에 Python 3.11이 없을 경우 `offline-bundle\installers`에 포함된 Python 3.11 설치 파일을 사용합니다. VC++ 런타임 설치 파일도 같은 번들에 포함됩니다.

## 전체 흐름

```text
인터넷망 PC
  01_online_package.bat
      ↓
  offline-bundle 생성
      ↓ 복사
폐쇄망 서버
  02_offline_install.bat
      ↓
  03_run.bat
```

## 1. 인터넷망 패키징

인터넷이 되는 Windows PC에서 저장소 루트에서 실행합니다.

```bat
01_online_package.bat
```

생성 결과:

```text
offline-bundle\
  dist\                Open WebUI 빌드 wheel
  wheelhouse\          폐쇄망 pip 설치용 Python wheel 전체
  seed-data\           런타임 캐시 seed 데이터
  installers\          Python 3.11, VC++ 런타임 설치 파일
  source-stage\        빌드용 임시 소스 복사본
  README-offline.txt   번들 정보
```

주요 동작:

- 저장소를 `offline-bundle\source-stage`로 격리 복사합니다.
- 실제 저장소 파일은 수정하지 않고, 임시 복사본의 `hatch_build.py`만 `npm install --force` 대신 `npm ci --force`를 쓰도록 패치합니다.
- `package-lock.json` 기준으로 프론트엔드를 포함한 Open WebUI wheel을 빌드합니다.
- `pip download --only-binary=:all:`로 의존성 wheel을 `wheelhouse`에 모읍니다.
- 폐쇄망에서 필요한 기본 캐시를 `seed-data`에 미리 받습니다.
  - RAG embedding: `sentence-transformers/all-MiniLM-L6-v2`
  - auxiliary embedding: `TaylorAI/bge-micro-v2`
  - Whisper: `base`
  - tiktoken: `cl100k_base`
  - NLTK: `punkt_tab`
- 생성된 wheelhouse만 사용해 오프라인 설치 검증을 수행합니다.
- `pip check`로 의존성 충돌을 확인합니다.

## 2. 폐쇄망 서버로 복사

인터넷망 PC에서 생성된 아래 항목을 폐쇄망 서버의 같은 폴더 구조로 복사합니다.

```text
01_online_package.bat
02_offline_install.bat
03_run.bat
offline-bundle\
```

폐쇄망 서버에서는 `01_online_package.bat`를 실행하지 않습니다. 이미 생성된 `offline-bundle`을 사용합니다.

## 3. 폐쇄망 설치

폐쇄망 서버의 저장소 루트 또는 배치 파일이 있는 폴더에서 실행합니다.

```bat
02_offline_install.bat
```

주요 동작:

- `offline-bundle\wheelhouse` 존재 여부를 확인합니다.
- Python 3.11이 없으면 번들에 포함된 Python 3.11을 로컬 폴더 `Python311`에 설치합니다.
- VC++ 런타임 설치 파일이 있으면 설치합니다.
- `.venv`를 새로 생성합니다.
- 인터넷 없이 다음 방식으로 Open WebUI를 설치합니다.

```bat
pip install --no-index --find-links offline-bundle\wheelhouse open-webui
```

- `pip check`와 `import open_webui`를 실행해 설치를 검증합니다.
- `offline-bundle\seed-data`를 `data`로 복사합니다.
- 런타임 캐시 폴더를 생성합니다.

## 4. 폐쇄망 실행

```bat
03_run.bat
```

기본 접속 주소:

```text
http://127.0.0.1:8080
http://SERVER_IP:8080
```

`03_run.bat`의 기본 실행 설정:

```bat
set "HOST=0.0.0.0"
set "PORT=8080"
set "OFFLINE_MODE=true"
set "HF_HUB_OFFLINE=1"
set "TRANSFORMERS_OFFLINE=1"
set "ENABLE_VERSION_UPDATE_CHECK=false"
set "ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS=false"
```

위 설정은 폐쇄망에서 외부 업데이트 확인, Hugging Face 온라인 접근, frontmatter 기반 동적 pip 설치를 막기 위한 설정입니다.

## Ollama 연결

Ollama는 이 배치 구성에 포함하지 않습니다. 폐쇄망 안에서 별도로 설치하고 실행합니다.

같은 Windows 서버에서 Ollama가 실행 중이면 기본값을 그대로 사용합니다.

```bat
set "OLLAMA_BASE_URL=http://127.0.0.1:11434"
```

별도 폐쇄망 서버에서 Ollama를 실행한다면 `03_run.bat`에서 주소를 바꿉니다.

```bat
REM set "OLLAMA_BASE_URL=http://192.168.0.50:11434"
```

폐쇄망에서는 Ollama 모델도 별도로 반입되어 있어야 합니다. Open WebUI 오프라인 번들은 Ollama 모델 파일을 포함하지 않습니다.

## 검증 결과

배치 파일 작성 전 동일한 흐름을 임시 테스트 폴더에서 직접 검증했습니다.

검증 항목:

- 인터넷망 패키징 시뮬레이션
  - Open WebUI wheel 생성 성공
  - 프론트엔드 빌드 포함 성공
  - Python wheelhouse 생성 성공
  - seed-data 캐시 생성 성공
- 폐쇄망 설치 시뮬레이션
  - `--no-index --find-links` 설치 성공
  - `pip check` 성공
  - `import open_webui` 성공
- 실행 시뮬레이션
  - `03_run.bat` 방식으로 서버 기동 성공
  - `/health` 호출 HTTP 200 확인
  - 응답 본문: `{ "status": true }`
- 테스트 후 정리
  - 대용량 임시 테스트 번들 삭제
  - `node_modules`, `build`, `.svelte-kit`, `dist` 삭제

최종 루트 배치 파일은 위 검증에 사용한 흐름을 운영용 경로 기준으로 정리한 것입니다.

## 문제 해결

### `package-lock.json is required` 오류

인터넷망 패키징은 재현 가능한 프론트엔드 빌드를 위해 `package-lock.json`이 필요합니다. 저장소 루트에 `package-lock.json`이 있는지 확인합니다.

### Node.js/npm 오류

`01_online_package.bat`는 프론트엔드 빌드를 수행하므로 인터넷망 PC에 Node.js/npm이 필요합니다. 폐쇄망 서버에는 Node.js/npm이 필요하지 않습니다.

### Python 3.11 오류

Open WebUI는 Python 3.11 계열을 기준으로 설치합니다. 인터넷망 PC에는 `py -3.11`이 동작해야 합니다. 폐쇄망 서버는 Python 3.11이 없어도 번들에 포함된 설치 파일로 로컬 설치를 시도합니다.

### 폐쇄망에서 패키지 다운로드를 시도하는 경우

`02_offline_install.bat`가 다음 옵션으로 실행되는지 확인합니다.

```bat
--no-index --find-links "%WHEELHOUSE%"
```

이 옵션이 적용되면 pip는 인터넷 인덱스를 사용하지 않고 `offline-bundle\wheelhouse`만 사용합니다.

### 실행 중 모델 다운로드 오류

`03_run.bat`는 기본 embedding/Whisper/tiktoken/NLTK 캐시를 `data\cache` 아래에서 찾도록 설정합니다. `offline-bundle\seed-data`가 `data`로 복사되었는지 확인합니다.

추가 모델, 다른 embedding 모델, 다른 Whisper 모델을 쓰려면 인터넷망에서 해당 캐시를 추가로 준비해 폐쇄망으로 반입해야 합니다.

### Open WebUI는 뜨지만 Ollama 모델이 보이지 않는 경우

- Ollama 프로세스가 별도로 실행 중인지 확인합니다.
- `03_run.bat`의 `OLLAMA_BASE_URL`이 실제 Ollama 주소와 포트인지 확인합니다.
- 방화벽에서 Ollama 포트 `11434`와 Open WebUI 포트 `8080` 접근을 허용합니다.
- Ollama 모델은 Open WebUI 번들에 포함되지 않으므로 Ollama 쪽에 별도 반입되어 있어야 합니다.
