```
nlp_base : intent 및 간단한 response 반환 가능
result: prompt_a 테스트 결과 값
result1: prompt_b 테스트 결과 값
sampling : 정답 데이터 set, 단 reponse 생성 X, 이후 추가 예정
```

## 🔧 **단계별 개발 방향성**

### 🔹 1단계: **단일 경량 모델 기반 MVP 구조 정착**

- 목표: 전체 시스템의 데이터 흐름 정립 & 병목 지점 파악
- 방법:
    - phi3-mini를 그대로 사용 (튜닝 없이)
    - `intent + slot + 대화 제어 응답`까지 **모두 프롬프트 레벨에서 해결**
    - STT/TTS는 병렬 처리 구조(스레드 or 큐) 설계 고려

📌 *이 단계에선 "속도보다 구조 완성"이 중요*

---

### 🔹 2단계: **NLU / Dialog 분리 or 백업 로직 추가**

- 목표: LLM 부담을 분산하고, 실시간성 확보
- 전략 A) 모델 1개 유지, 역할만 분리
    - `intent/slot`만 추출 → Dialog 흐름은 **rule-based fallback**
    - 예: `"엄마한테 보내줘"` → 모델이 slot만 뽑고, 누락 판단은 시스템이 함
- 전략 B) 구조 분리 시도 (추후)
    - NLU: 경량 LLM (phi3-mini, TinyLlama 등)
    - DM: rule + RAG 기반 응답
    - 필요시 **MOA 방식 탐색**: Task별 분기 + model-router 구성

📌 *이 단계에선 "성능 저하 없이 구조 분리"가 핵심*

---

### 🔹 3단계: **온디바이스 or RAG 결합 확장**

- 목표: 클라우드 의존 최소화 + 실제 사용자 데이터 기반 응답
- 고려 요소:
    - 의도 분류는 **ONNX로 추출한 NLU 모델로 온디바이스**
    - 대화 흐름은 RAG 또는 rule 기반으로 보완
    - slot-based instruction prompting으로 모델 부하 최소화

---

## 🚧 기술적으로 고려할 현실적 제약

| 이슈 | 해결 실마리 |
| --- | --- |
| ⏱️ 추론 지연 | - 프롬프트 최적화 (`template → compressed`)
- 캐시된 slot 재사용 (`context window` 절약) |
| 📦 리소스 한계 | - 양자화(Q4), INT4 변환 (GGUF)
- 모델 serve는 Ollama 또는 llama.cpp 기반 고려 |
| 🔁 병렬처리 | - STT/TTS 병렬화: FastAPI + asyncio or Redis queue 사용 |
