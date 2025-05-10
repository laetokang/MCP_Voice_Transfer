
# 📦 sLLMs 모듈 – Lightweight LLM-based NLU & Dialog Manager

`sLLMs`는 사용자 음성 발화에서 텍스트를 받아, **의도(intent)** 와 **필수 정보(slot)** 를 추출하고  **대화 흐름(Dialog Flow)** 을 제어하는 경량 LLM 기반 모듈입니다.  
온디바이스 모델 중심으로 설계되어, **빠른 응답성과 낮은 리소스 사용률**을 지향합니다.

---

## 🔹 주요 구성 요소

| 구성 | 설명 |
|------|------|
| `NLU Engine` | 사용자 발화 → intent 및 slot 추출 (phi3-mini 기반 LLM) |
| `Dialog Manager` | 멀티턴 흐름 제어, 슬롯 누락 시 재질문, 컨텍스트 캐시 |
| `Preprocessor` | STT 결과 정제, 자모 분해, 특수기호 제거 등 |
| `Output Formatter` | 일관된 JSON 출력 구조 생성 |

---

## ⚙️ 예시 입력 & 출력

```
Input: "엄마한테 삼만원만 보내줘"

Output:
{
  "intent": "송금",
  "slots": {
    "recipient": "엄마",
    "amount": 30000
  }
}
```

---

## 📈 성능 평가 기준

- **Intent Accuracy**
- **Slot Precision / Recall / F1-score**
- **응답 포맷 유효성 검사 (JSON 구조 체크)**

---

## 🧠 적용 기법 요약

| 문제 | 해결 방안 | 사용 기법 |
|------|------------|------------|
| 다양한 발화 구조 | Intent/Slot 기반 구조화 | Intent Classification + Slot Filling |
| 응답 불안정 | LLM 프롬프트 설계 | Few-shot Prompting |
| 누락 정보 처리 | 멀티턴 흐름 제어 | Dialog State Tracking |
| 문맥 기억 | 캐시 기반 context 유지 | Session Context Cache |
| 평가 필요 | 정량 지표 기반 비교 | Intent Accuracy, Slot F1 Score 등 |

---

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
```\\
## ✨ 특징 및 향후 확장 가능성

- **온디바이스 실행**으로 빠르고 효율적인 음성 인식 및 의도 분석
- **멀티턴 대화**를 지원하여 **누락된 슬롯**을 유도하는 자연스러운 대화 흐름
- **서버 fallback** 및 **RAG 연동**을 통해 **복잡한 질의에 대한 확장 가능성** 확보

---
