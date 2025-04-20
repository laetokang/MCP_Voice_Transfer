
#  sLLMs 모듈 – Lightweight LLM-based NLU & Dialog Manager

`sLLMs`는 사용자 발화 텍스트를 받아 **의도(intent)** 및 **슬롯(slot)**을 추출하고,  슬롯 누락 여부에 따라 **대화 흐름(Dialog Flow)**을 제어하는 **경량 LLM 기반 모듈**입니다.


---

## 🔹 주요 구성 요소

| 구성 | 설명 |
|------|------|
| `NLU Engine` | 사용자 발화 → intent 및 slot 추출 (phi3-mini 기반 LLM) |
| `Dialog Manager` | 멀티턴 흐름 제어, 슬롯 누락 시 재질문, 컨텍스트 캐시 |
| `Preprocessor` | STT 결과 정제, 자모 분해, 특수기호 제거 등 |
| `Output Formatter` | 일관된 JSON 출력 구조 생성 |

---

## 🔁 전체 처리 흐름 요약 (sLLMs 관점)

```
사용자 음성 입력
    ↓
[features/stt]             : 음성 → 텍스트 변환
    ↓
[backend/slms]             : 의도(Intent), 슬롯(Slot) 추출 + 대화 흐름 제어
      ├─ NLU Engine        : phi3-mini 기반 추론
      ├─ Dialog Manager    : 슬롯 누락 시 재질문 or 이전 대화 활용
      └─ Formatter         : 응답 JSON 생성
    ↓
[features/dialog]          : (필요 시) 추가 슬롯 채움 or 컨텍스트 반영
    ↓
[features/voice_auth]      : 화자 인증 여부 판단
    ↓
[features/tts]             : 응답 텍스트를 음성으로 변환
```

## 🗂️ 모듈 파일 구조 예시

```
slms/
├── main.py             # FastAPI 엔드포인트
├── nlu.py              # LLM inference + 프롬프트
├── dialog_manager.py   # 멀티턴 흐름 처리
├── cache.py            # 세션/캐시 관리 (in-memory or Redis)
├── preprocessor.py     # 텍스트 전처리
├── formatter.py        # JSON 응답 포맷
└── prompt_examples.py  # few-shot 예시 모음
```


---

## 📈 성능 평가 기준

- **Intent Accuracy**
- **Slot Precision / Recall / F1-score**
- **응답 포맷 유효성 검사 (JSON 구조 체크)**

---


## ✨ 특징 및 향후 확장 가능성

- **온디바이스 실행**으로 빠르고 효율적인 음성 인식 및 의도 분석
- **멀티턴 대화**를 지원하여 **누락된 슬롯**을 유도하는 자연스러운 대화 흐름
- **서버 fallback** 및 **RAG 연동**을 통해 **복잡한 질의에 대한 확장 가능성** 확보

---
