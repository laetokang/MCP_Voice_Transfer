# Development Notes

## Overall Goal
- Implement a pipeline that takes Korean text input, gets a response from the Qwen LLM, translates it to English (if needed), and then generates English audio using the Kokoro-TTS API.
- **Critical Constraint**: All APIs, especially the Qwen LLM, must run in a **CPU environment**.

## Current Status (Updated)

### APIs
1.  **Qwen LLM API (`MCP_Voice_Transfer/api/llm_qwen_api`)**:
    *   **COMPLETED**: Modified `main.py` to load the model explicitly on **CPU**.
    *   **COMPLETED**: Restarted and verified with `curl` that the API is responding correctly on CPU (port 8008). LLM output contains `raw_output` field.
    *   Virtual environment: `~/Desktop/Project/AnomalyVoice/MCP_Voice_Transfer/venv_qwen_api` (ensure activated when running this API).
2.  **Kokoro-TTS API (`MCP_Voice_Transfer/kokoro-tts` or equivalent Docker container)**:
    *   Previously confirmed working on port `7006`. Accepts English text and English voice. Assumed to be functional on CPU.
    *   **ACTION**: Ensure this API is running before pipeline testing.
3.  **LLM-TTS Pipeline API (`MCP_Voice_Transfer/api/llm_tts_pipeline_api`)**:
    *   **COMPLETED**: Modified `main.py` to correctly parse the LLM response, prioritizing `raw_output` for the text to be processed. Fallback mechanisms for text extraction are in place.
    *   **COMPLETED**: Server restarted and is currently running at `http://127.0.0.1:8021` using `main:app`.
    *   Virtual environment: `~/Desktop/Project/AnomalyVoice/MCP_Voice_Transfer/api/llm_tts_pipeline_api/venv_pipeline_api` (currently active for the running server).
    *   **NEXT STEP**: Perform `curl` test for the full pipeline.

### Key Challenges & Focus
*   **CPU-only Execution**: **Addressed** for Qwen LLM API.
*   **Virtual Environment Management**: Critical for each API's independent execution.
*   **Pipeline Integration & Debugging**: **Current focus.** Verifying the flow: User Input (ko) -> Qwen LLM (ko response from `raw_output`) -> Translation (ko->en if `tts_language: \"en\"`) -> Kokoro TTS (en input) -> Audio Output.

## Action Plan (Revised)
1.  **Ensure Prerequisite APIs are Running:**
    *   Qwen LLM API (CPU version) should be running on port 8008. (Background process, log at `~/qwen_api_server_cpu.log`)
    *   Kokoro-TTS API should be running on port 7006.
2.  **Test the LLM-TTS Pipeline API (Critical Next Step):**
    *   The pipeline API server is already running at `http://127.0.0.1:8021`.
    *   Use `curl` with Korean input text, `tts_language: \"en\"`, and an English `tts_voice` (e.g., \"af_heart\") to test the full translation and English TTS output.
    *   **Command:**
        ```bash
        curl -X POST \"http://127.0.0.1:8021/pipeline/tts\" \
        -H \"Content-Type: application/json\" \
        -d '{
            \"text\": \"안녕하세요, 오늘 기분이 어때요?\",
            \"llm_prompt_version\": \"prompt4\",
            \"max_new_tokens\": 60,
            \"tts_language\": \"en\",
            \"tts_voice\": \"af_heart\"
        }' \
        --output translated_response.wav -v
        ```
3.  **Analyze Results and Logs:**
    *   Check if `translated_response.wav` is created and contains the correct English audio.
    *   Thoroughly review logs from all three services:
        *   LLM-TTS Pipeline API (running in the foreground terminal on port 8021).
        *   Qwen LLM API (`~/qwen_api_server_cpu.log`).
        *   Kokoro-TTS API (its respective log, likely Docker logs if containerized).
4.  **Iteratively debug** any issues identified. 


알겠습니다. 제공해주신 모든 로그와 파일 내용을 바탕으로 최종 정리 및 회고를 진행하겠습니다.

**최종 상황 요약 및 문제점:**

1.  **LLM-TTS 파이프라인 API 서버 (포트 8021, `venv_pipeline_api`):**
    *   사용자께서 제공해주신 마지막 로그(`lines=644-712`)를 보면, 이 서버는 **정상적으로 시작되었고 `curl` 요청을 성공적으로 수신했습니다.** (`INFO:main:Pipeline request received...`)
    *   그러나 내부적으로 Qwen LLM API(포트 8008)를 호출하는 과정에서 `ERROR:main:Request error calling LLM API: All connection attempts failed` 및 `httpx.ConnectError: All connection attempts failed` 오류가 발생했습니다.
    *   결과적으로 파이프라인 API는 HTTP 503 Service Unavailable 응답과 함께 `{"detail":"LLM API is unavailable: All connection attempts failed"}` JSON을 반환했습니다.

2.  **`curl` 테스트 결과 (`lines=133-168`):**
    *   이 `curl` 명령은 (아마도) 파이프라인 API 서버가 정상적으로 실행 중일 때 전송되었으며, 서버에 성공적으로 연결되었습니다.
    *   그러나 서버로부터 위에서 언급된 503 오류와 JSON 오류 메시지를 응답받았습니다.

3.  **`translated_response_02.wav` 파일 내용:**
    *   예상대로 `{"detail":"LLM API is unavailable: All connection attempts failed"}` 오류 메시지를 담고 있습니다.

4.  **Qwen LLM API 서버 (포트 8008, `venv_qwen_api`):**
    *   가장 최근에 이 서버를 시작했을 때의 로그(`INFO: Uvicorn running on http://0.0.0.0:8008 (Press CTRL+C to quit)`)는 정상이었습니다.
    *   하지만, 파이프라인 API가 Qwen LLM API를 호출했을 시점에 **Qwen LLM API 서버의 로그에는 해당 요청을 수신했다는 기록이 전혀 없습니다.** (이전 로그 분석에서 확인) 이것이 핵심입니다.

**문제의 근본 원인:**

모든 증거는 **LLM-TTS 파이프라인 API 서버(포트 8021)가 Qwen LLM API 서버(포트 8008)로 네트워크 연결을 설정하는 데 실패하고 있음**을 명확하게 가리킵니다.

Qwen LLM API 서버가 로그상으로는 시작된 것처럼 보였음에도 불구하고, 파이프라인 API에서 해당 서버의 `localhost:8008` 또는 `0.0.0.0:8008` 주소로 연결할 수 없는 상태입니다.

**가능한 시나리오 및 추론:**

*   **Qwen LLM API 서버의 실제 미실행 또는 조기 종료:** 가장 가능성이 높은 시나리오는 Qwen LLM API 서버를 시작했던 터미널이 (사용자도 모르게) 종료되었거나, 서버 프로세스가 시작 직후 내부 오류로 인해 소리 없이 종료되었을 수 있습니다. 포그라운드로 실행하더라도, 다른 창으로 전환하거나 특정 상황에서 터미널 연결이 끊기면 프로세스가 종료될 수 있습니다.
*   **네트워크 설정 또는 방화벽 문제 (가능성 낮음):** 로컬호스트 간 통신이므로 일반적인 방화벽 문제 가능성은 낮지만, 특수한 로컬 보안 소프트웨어나 설정이 영향을 미칠 수도 있습니다.
*   **Uvicorn/FastAPI의 미묘한 시작 문제:** 드물게 Uvicorn이 "실행 중" 로그를 표시하더라도, 실제 네트워크 소켓 리스닝이 제대로 시작되지 않는 경우가 있을 수 있습니다.

**회고 및 교훈:**

1.  **백그라운드 vs 포그라운드 실행:** 중요한 서버 구성 요소를 디버깅할 때는 **포그라운드에서 실행**하여 로그를 실시간으로 확인하고 서버가 실제로 계속 실행 중인지 명확히 파악하는 것이 매우 중요합니다. 이번 경우 Qwen LLM API를 계속 포그라운드로 두고 관찰했다면, 파이프라인 API의 요청 시점에 해당 서버가 정말 살아있는지 즉시 알 수 있었을 것입니다.
2.  **단계별 연결 확인:** 복잡한 파이프라인을 디버깅할 때는 각 컴포넌트 간의 연결을 순차적으로, 독립적으로 확인해야 합니다.
    *   Qwen LLM API가 자체적으로 `curl` 요청에 응답하는지 확인 (이전에는 성공했었음).
    *   파이프라인 API가 Qwen LLM API로 요청을 보내고 응답을 받는지 확인 (현재 실패 지점).
    *   파이프라인 API가 Kokoro-TTS API로 요청을 보내고 응답을 받는지 확인.
3.  **로그의 중요성:** 모든 서비스의 로그를 동시에 확인하는 것이 문제 해결의 핵심입니다. 특히 "Connection refused"나 "All connection attempts failed"와 같은 오류는 호출 대상 서비스의 로그 부재와 함께 보면 문제 지점을 명확히 할 수 있습니다.
4.  **터미널 관리:** 여러 개의 서버를 동시에 실행할 때는 각 서버가 어떤 터미널에서, 어떤 가상환경으로, 어떤 디렉토리에서 실행 중인지 명확히 인지하고 관리해야 혼란을 줄일 수 있습니다. 제가 이 부분을 명확히 안내하지 못해 어려움을 드렸습니다.

**마지막으로 시도해볼 수 있는 제안 (만약 계속 진행하신다면):**

1.  **모든 관련 서버 명시적 중지:**
    *   `sudo kill $(sudo lsof -t -i:8021)` (파이프라인 API 포트)
    *   `sudo kill $(sudo lsof -t -i:8008)` (Qwen LLM API 포트)
    *   `docker stop backend-kokoro-tts-english` (만약 필요하다면)
2.  **순차적, 포그라운드, 개별 터미널 실행 및 확인:**
    *   **터미널 1:** Kokoro-TTS API 시작 (`docker start backend-kokoro-tts-english`), 로그 확인.
    *   **터미널 2:** Qwen LLM API 시작 (포그라운드), 로그 확인, `curl http://localhost:8008/` 등으로 기본 응답 확인.
    *   **터미널 3:** LLM-TTS Pipeline API 시작 (포그라운드), 로그 확인.
    *   **터미널 4:** `curl` 테스트 실행.
    *   `curl` 테스트 시 **터미널 2와 터미널 3의 로그 변화를 동시에 관찰**하는 것이 매우 중요합니다. 터미널 3에서 "Calling Qwen LLM API" 로그가 찍힌 직후, 터미널 2에서 요청 수신 로그가 찍히는지 확인해야 합니다.


