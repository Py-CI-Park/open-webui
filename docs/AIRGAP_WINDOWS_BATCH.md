# Windows 폐쇄망 설치 및 실행 안내

이 문서는 Docker를 사용하지 않고 Windows x64 환경에서 Open WebUI를 폐쇄망에 구축하는 방법을 정리합니다. 운영 방식은 AeroOne과 동일하게 배치 파일 3개로 나눕니다.

- `01_online_package.bat`: 인터넷망 PC에서 오프라인 번들과 반입용 ZIP 생성
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
  offline-bundle 및 release ZIP 생성
      ↓ ZIP 반입 또는 offline-bundle 복사
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
  README-offline.txt   번들 정보
```

`source-stage`(빌드용 임시 소스 복사본)와 `.build-venv`(빌드 도구 전용 가상환경)는 wheel 빌드에만 쓰이고 `02_offline_install.bat`가 참조하지 않으므로, wheel을 `wheelhouse`로 복사한 직후 자동 삭제되어 최종 번들/릴리즈 ZIP에는 포함되지 않습니다.

릴리즈 ZIP:

```text
release\open-webui-airgap-windows-YYYYMMDD-HHMMSS.zip
```

이 ZIP은 폐쇄망 서버로 바로 반입할 수 있도록 아래 항목을 함께 담습니다.

```text
offline-bundle\
02_offline_install.bat
03_run.bat
AIRGAP_WINDOWS_BATCH.md
```

주요 동작:

- 저장소를 `offline-bundle\source-stage`로 격리 복사합니다.
- 실제 저장소 파일은 수정하지 않고, 임시 복사본의 `hatch_build.py`만 `npm install --force` 대신 `npm ci --force`를 쓰도록 패치합니다.
- `package-lock.json` 기준으로 프론트엔드를 포함한 Open WebUI wheel을 빌드합니다.
- `pip download --only-binary=:all:`로 의존성 wheel을 `wheelhouse`에 모읍니다.
- wheel 복사가 끝나면 `source-stage`와 `.build-venv`를 삭제해 릴리즈 ZIP에 빌드 전용 파일이 남지 않게 합니다.
- 폐쇄망에서 필요한 기본 캐시를 `seed-data`에 미리 받습니다.
  - RAG embedding: `sentence-transformers/all-MiniLM-L6-v2`
  - auxiliary embedding: `TaylorAI/bge-micro-v2`
  - Whisper: `base`
  - tiktoken: `cl100k_base`
  - NLTK: `punkt_tab`
- 생성된 wheelhouse만 사용해 오프라인 설치 검증을 수행합니다.
- `pip check`로 의존성 충돌을 확인합니다.
- `release\open-webui-airgap-windows-YYYYMMDD-HHMMSS.zip`을 생성합니다.

## 2. 폐쇄망 서버로 반입

인터넷망 PC에서 생성된 릴리즈 ZIP을 폐쇄망 서버로 복사한 뒤 압축을 풉니다.

```text
release\open-webui-airgap-windows-YYYYMMDD-HHMMSS.zip
```

압축 해제 후 구조:

```text
offline-bundle\
02_offline_install.bat
03_run.bat
AIRGAP_WINDOWS_BATCH.md
```

폐쇄망 서버에서는 `01_online_package.bat`를 실행하지 않습니다. ZIP 안에 포함된 `offline-bundle`을 사용합니다.

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

Ollama 모델 반입 방법 2가지:

- **온라인 PC에서 pull 후 폴더 복사(권장)**: 온라인 PC에서 `ollama pull <model>` 실행 → 기본 저장 위치(`%USERPROFILE%\.ollama\models`, blobs + manifests)를 통째로 USB 등으로 반입해 폐쇄망 서버의 동일 경로(또는 `OLLAMA_MODELS` 환경변수로 지정한 경로)에 덮어씁니다.
- **GGUF + Modelfile로 로컬 생성**: 반입한 `.gguf` 파일을 `ollama create mymodel -f Modelfile`로 폐쇄망에서 직접 등록합니다. 레지스트리 접근이 필요 없습니다.

## 5. 첫 접속 및 운영

### 최초 접속 / 관리자 계정

`03_run.bat` 기동 후 접속하면 **회원가입한 첫 번째 계정이 자동으로 admin 권한**을 갖습니다. 이후 가입자는 기본값(`DEFAULT_USER_ROLE=pending`)상 admin이 Admin Panel → Users에서 승인/역할을 지정하기 전까지 대기 상태입니다.

폐쇄망이어도 첫 계정 생성 직후 회원가입을 잠그는 것을 권장합니다(6장 보안 참고).

### 일상 운영

| 작업 | 방법 |
|---|---|
| 재시작 | `03_run.bat` 콘솔에서 Ctrl+C로 정상 종료 후 재실행 |
| 데이터 위치 | `data\` 폴더 전체(DB, 업로드 파일, 캐시) — 백업 대상은 이 폴더 전체 |
| 로그 확인 | `03_run.bat` 콘솔에 uvicorn 로그 출력. 파일로 남기려면 `03_run.bat > server.log 2>&1`처럼 리다이렉트 |
| 데이터 백업 | 서비스 중지 후 `data\` 폴더 전체 복사(SQLite 기반이라 파일 복사만으로 백업 가능) |
| 데이터 내보내기 | Admin Panel → Settings → Database → Export (`ENABLE_ADMIN_EXPORT` 기본 활성) |

### 사용자/그룹 관리

Admin Panel → Users에서 승인·역할(admin/user/pending) 변경, Admin Panel → Groups에서 모델 접근 권한을 그룹 단위로 제한할 수 있습니다.

## 6. 튜닝 및 개선 추천

이 저장소(0.9.6) `backend/open_webui/config.py`, `backend/open_webui/env.py` 실제 설정 코드를 확인해 정리한 내용입니다.

### RAG(문서 검색) 품질

| 설정 | 기본값 | 추천 |
|---|---|---|
| `CHUNK_SIZE` | 1000 | 기술 문서/코드가 많으면 500~800(검색 정밀도↑), 서술형 문서면 1200~1500 |
| `CHUNK_OVERLAP` | 100 | chunk 경계에서 문맥이 잘리면 150~200으로 |
| `RAG_TOP_K` | 3 | 근거 문서가 부족하면 5로, 단 컨텍스트 창 여유가 있을 때만 |
| `ENABLE_RAG_HYBRID_SEARCH` | false | 켜는 것을 추천. BM25(키워드) + 임베딩(의미) 하이브리드 검색이며 `rank-bm25`가 이미 wheelhouse에 포함되어 있어 추가 반입 없이 바로 활성화 가능 |
| `RAG_RERANKING_MODEL` | (미설정) | 검색 정확도가 중요하면 추가. 단, 폐쇄망에서는 `01_online_package.bat`의 seed-data 단계에 reranker 모델도 함께 받도록 수정해야 오프라인에서 동작 |

Admin Panel → Settings → Documents에서 UI로도 조정 가능합니다(코드 수정 불필요, DB에 저장되는 설정).

### 성능

- **멀티 워커**: `03_run.bat` 실행 전 `set "UVICORN_WORKERS=4"`(CPU 코어 수에 맞춰)로 동시 사용자 처리량 향상. 단 워커 2개 이상이면 `WEBSOCKET_MANAGER=redis`가 사실상 필수(안 그러면 워커 간 채팅 스트리밍 동기화가 깨져 실시간 응답이 끊기는 것처럼 보임). 폐쇄망이면 Redis도 별도 반입/설치 필요.
- **GPU**: Ollama 쪽에서 관리(Open WebUI는 API만 호출). 모델별 `num_gpu`, `num_ctx`, `num_thread`는 채팅 화면 모델의 "Advanced Params"에서 개별 조정.
- 동시 사용자가 적은(1~5명) 소규모 폐쇄망은 `UVICORN_WORKERS=1`(기본값) 그대로가 Redis 인프라 없이 더 단순하고 안정적입니다.

### 보안 (폐쇄망이어도 필요)

- `ENABLE_SIGNUP=false`: 첫 admin 계정 생성 후 회원가입을 잠그고, 이후 사용자는 Admin Panel에서 직접 생성.
- `JWT_EXPIRES_IN` 기본값 `4w`(4주) — 사내 정책에 맞게 `1d`, `12h` 등으로 단축 권장.
- 관리자 계정 비밀번호는 설치 직후 강한 값으로 변경(랜덤 초기값 방치 금지).
- 리버스 프록시(nginx/IIS)로 HTTPS를 감싸는 것을 권장(폐쇄망 내부라도 사내 트래픽 스니핑 리스크는 존재).

### 추가 기능 / 폐쇄망 팁

- **웹 검색 도구**는 외부 인터넷 호출이 필요해 폐쇄망에서는 꺼둔 상태를 유지해야 합니다.
- **Pipelines**로 사내 시스템(DB 조회, 결재 시스템 등) 연동 가능(별도 반입 필요).
- 임베딩/reranker/Whisper 등 모델을 바꾸거나 추가할 때마다 `01_online_package.bat`를 재실행해 새 release를 만들어야 폐쇄망에 반영됩니다(런타임 온라인 다운로드 불가).

## 7. 기존 DB 마이그레이션 (버전 업그레이드)

예전 버전(예: Peewee→SQLAlchemy 전환 이후인 0.6.x 이상)의 `webui.db`를 이 airgap 패키지의 새 설치에 그대로 붙여 계정·대화 기록을 유지할 수 있습니다.

### 왜 안전한가

- Open WebUI는 부팅 시마다 Alembic이 자동으로 `command.upgrade(..., 'head')`를 실행합니다(`backend/open_webui/config.py`의 `run_migrations()`). 기존 DB 스키마 버전이 무엇이든 필요한 마이그레이션만 순서대로 적용됩니다.
- `backend/open_webui/migrations/versions/`의 마이그레이션들은 이미 존재하는 테이블/컬럼/인덱스는 건너뛰고, legacy 테이블에 누락된 PK도 보정하도록 방어적으로 작성되어 있습니다(0.9.6 CHANGELOG에 명시).

### 적용 방법

1. 예전 서버의 `data\webui.db` 백업
2. 새 airgap 패키지(`02_offline_install.bat` 실행 후 생성된) `data\` 폴더에 그 `webui.db`를 복사(덮어쓰기) — `02_offline_install.bat`의 데이터 복사 단계는 `robocopy /E`(병합)라 기존 파일을 지우지 않으므로 seed-data 복사 전후 어느 시점에 넣어도 안전
3. `03_run.bat`로 기동 → 첫 부팅 시 자동으로 남은 마이그레이션이 적용됨

### 주의사항

| 항목 | 설명 |
|---|---|
| 반드시 사전 백업 | 마이그레이션 대부분은 `downgrade()`가 사실상 no-op이라 되돌리기 어려움 |
| `-wal` / `-shm` 파일 | 예전 서버에 `webui.db-wal`, `webui.db-shm`이 남아있다면 함께 복사(없다면 정상 종료된 것). 안 그러면 최근 대화 일부가 누락된 것처럼 보일 수 있음 |
| 대화 기록이 많다면 시간 여유 확보 | 0.8.0에서 추가된 chat message table 마이그레이션은 대화량이 많으면 다소 오래 걸릴 수 있음. 사용자 접속 없는 시간대에 첫 기동 권장 |
| 버전 혼용 금지 | 마이그레이션 진행/완료 전까지 예전 버전 서버가 같은 DB 파일에 동시에 붙지 않도록 할 것 |
| `ENABLE_DB_MIGRATIONS` | `03_run.bat`는 이 값을 건드리지 않아 기본값(`true`)으로 유지됨 — 별도 조치 불필요 |

Ollama는 DB 마이그레이션과 완전히 별개 시스템(Open WebUI는 API로만 호출)이므로, 최신 버전 Ollama를 그대로 계속 연결해 써도 무방합니다.

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
