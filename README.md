# MCP_Voice_Transfer

# 전체 흐름 예시
![dLLVQnfF57sVJt7nQGMJ_7wlWYMM8WJI6h3jKryMtJPIkygwba8fsCG4gHPCeoYfiGPCOe81DNzg8P-cZpkptw7NyRfsOgL_V36vS-wPS-wS6LUpjcxPkLSffiVjj0LYgoSEpaIhmZ9OJyQJ6TsqmHT9vMpRmENQ0BGdQo0A7T6k-NsWPo6SoQZWi9cmqia4n0phTJ9kI13zhGBNrnyYKvCF2w15zAmTtbYRKEA](https://github.com/user-attachments/assets/50a5d7e4-082b-4570-92b2-db86f93f86d5)
1. 플러터 앱 내 음성 송금 기능 ON 설정
2. 사용자: "헤이 플러터, 철수한테 만 원 보내줘"
3. Android Service가 웨이크워드 감지 + 음성 인식 시작
4. 음성 텍스트 → LLM 서버로 전달
5. LLM 서버: 의도 감지 → { intent: 송금, 대상: 철수, 금액: 10000 }
6. 이상거래탐지 내 송금 내역 전달
7. 음성 인증
8. 앱 or Android Service가 송금 서버에 API 호출
9. 송금 성공 → 결과를 Android TTS로 읽어줌 ("철수에게 1만 원 송금했습니다")
10. 앱이 있다면 → 송금 내역 저장 + UI로 보여줌

<br>

# 프로젝트 프로세스

## 🧭 프로젝트 로드맵

### [1단계] 기본 백엔드 로직 구성 (FastAPI 기반)

- **[1] 더미 계좌 생성**✅
  - 사용자별 계좌번호, 이름, 초기 잔액 설정
  - 샘플 JSON / SQLite 등으로 저장

- **[2] 시뮬레이션 송금 처리**✅
  - 잔액 확인 → 송금 성공/실패 처리
  - 트랜잭션 ID, 타임스탬프 반환

- **[4] `/intent` API 구현**
  - 발화 예시: `"엄마한테 3만원 보내줘"`
  - 결과 예시: `{"intent": "송금", "to": "엄마", "amount": 30000}`

- **[5] `/transfer` API 구현**
  - `/intent` 결과를 받아 실제 송금 시뮬레이션 수행

- **[6] `/log` API (대화 로그 저장)**
  - 입력, 의도, 응답 결과 등을 JSON or MongoDB에 저장

---

### [2단계] 시뮬레이터와 예외 처리

- **[7] 텍스트 기반 시뮬레이터**
  - CLI 기반으로 대화 흐름 시뮬레이션 가능 (예: `input()` + REST 호출)

- **[8] 슬롯 누락 예외 처리**
  - 누락된 슬롯(`to`, `amount`)에 대한 추가 질문 설계
  - 예: "엄마한테 보내줘" → 금액 누락 → "얼마를 보내드릴까요?"

- **[9] 인증 단계 모킹**
  - 예시: 지문 인증 or 인증 코드 입력 흐름을 가짜 토큰으로 대체

---

### [3단계] 모바일 연동 및 OS 확장

- **[10] Android STT + TTS 연동**
  - STT: 사용자 발화 → 텍스트 변환
  - TTS: 서버 응답 → 음성 안내로 출력

- **[11] FastAPI 연동 Android 클라이언트**
  - Retrofit 등으로 `/intent`, `/transfer` 호출
  - 챗 UI 또는 음성 기반 UI 제공

- **[12] OS 서비스로 확장**
  - `VoiceInteractionService` 활용
  - 웨이크업 키워드 ("아라야") → 바로 송금 대화 시작 가능


<br>


# 📊 시스템 아키텍처 개요
![TLNVJzjM57w_VyLHNmPQArGU-p2LbMr2AXDQCkrXtOENc11XREIOLjKqAQK6PP29T4tQmEmiMGbaKwevFw2HrhzcZxx7_yFEpR7he6n8WOllzvtZyttVWVibHxETlHr3E4N7q07zAhe322U139g0XvrmKW4yzl3eF3hm01jkj4-ddt7OX0Ly_GOlo_0neEl9eGjHeud-M4wgyg8lNtgBGfIsY-QkPcixaBDsTYr](https://github.com/user-attachments/assets/eae07919-165f-429b-9834-acbf78405abc)

</br>

## 2. 모델 성능 검증

###  1. STT 모듈 (음성 → 텍스트 변환)

- **검증 목표**: 음성 입력에 대해 정확한 텍스트 변환 수행 여부 확인
- **평가 지표**: `WER (Word Error Rate)`
- **WER 계산 방식**: WER = (Substitutions + Insertions + Deletions) / Total Words

- - **예시**:
  - 
| 실제 문장              | STT 결과                         | WER |
|------------------------|----------------------------------|-----|
| 엄마한테 오만원 보내줘 | 엄마 한테 5만 원 보내 줘         | 0% (거의 정확) |


### 2. NLU (Intent / Slot 분석)

- **검증 목표**: 사용자의 의도를 정확히 분류하고, 슬롯을 추출하는 능력 평가
- **평가 지표**:
- Intent: Accuracy
- Slot: Precision / Recall / F1-score

**예시 데이터**:

```json
{
  "text": "아빠한테 만원 보내줘",
  "intent": "transfer",
  "slots": {
    "recipient": "아빠",
    "amount": "10000"
  }
}
```

### 3. 음성 로그 데이터 처리

- **검증 목표**: 사용자-시스템 간 대화 흐름과 송금 요청/응답을 정확히 기록하고 관리

#### 검증 항목
- 로그 정합성 (누락된 필드 없음)
- 대화 흐름 추적 가능 여부
- 검색 정확도 (특정 조건 거래 필터링 등)

#### 예시 로그 구조 (JSON)
```json
{
  "timestamp": "2025-04-06T10:00:00Z",
  "text": "엄마한테 3만원 보내줘",
  "intent": "transfer",
  "slots": {
    "recipient": "엄마",
    "amount": 30000
  },
  "authenticated": true,
  "transfer_status": "success"
}
```

### 4. 이상거래 탐지 시스템

- **검증 목표**: 비정상/의심 거래 탐지 정확도 측정
- **사용 데이터**: [IEEE-CIS Fraud Detection Dataset (Kaggle)](https://www.kaggle.com/competitions/ieee-fraud-detection)

#### 평가 지표

- **Precision**: 탐지된 거래 중 실제 이상거래일 확률  
  → `Precision = TP / (TP + FP)`
  
- **Recall**: 전체 이상거래 중 모델이 탐지한 비율  
  → `Recall = TP / (TP + FN)`
  
- **F1-score**: Precision과 Recall의 조화 평균  
  → `F1 = 2 * (Precision * Recall) / (Precision + Recall)`
  
- **AUC (Area Under Curve)**: ROC 곡선 아래 면적, 전체 분류 성능 지표  
  → 1에 가까울수록 성능 우수



---

## 📌 기술 스택

- **백엔드**: FastAPI, SQLite or Redis
- **LLM 연동**: ???Ollama + EXAONE-DEEP
- **모바일**: Flutter or Android(Java/Kotlin)
- **음성 처리**: ???Android STT / TTS API
- **MCP**: 모델 호출 인터페이스 규약 기반 REST API

---

## 🛡️ 보안 주의

> 본 시스템은 실제 금융기관 API를 사용하지 않으며,  
> 모든 송금 처리와 인증은 **더미 데이터 기반 시뮬레이션**으로 동작합니다.
