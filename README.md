# MCP_Voice_Transfer
![dLLVQnfF57sVJt7nQGMJ_7wlWYMM8WJI6h3jKryMtJPIkygwba8fsCG4gHPCeoYfiGPCOe81DNzg8P-cZpkptw7NyRfsOgL_V36vS-wPS-wS6LUpjcxPkLSffiVjj0LYgoSEpaIhmZ9OJyQJ6TsqmHT9vMpRmENQ0BGdQo0A7T6k-NsWPo6SoQZWi9cmqia4n0phTJ9kI13zhGBNrnyYKvCF2w15zAmTtbYRKEA](https://github.com/user-attachments/assets/50a5d7e4-082b-4570-92b2-db86f93f86d5)




# 전체 흐름 예시
1. 사용자: "헤이 플러터, 철수한테 만 원 보내줘"
2. Android Service가 웨이크워드 감지 + 음성 인식 시작
3. 음성 텍스트 → LLM 서버로 전달
4. LLM 서버: 의도 감지 → { intent: 송금, 대상: 철수, 금액: 10000 }
5. 앱 or Android Service가 송금 서버에 API 호출
6. 송금 성공 → 결과를 Android TTS로 읽어줌 ("철수에게 1만 원 송금했습니다")
7. 앱이 있다면 → 송금 내역 저장 + UI로 보여줌

# 프로젝트 프로세스

## 1. 프로젝트 세팅

[1] 오픈뱅킹 계정 등록(API 승인 신청 대기중)

[2] Postman 토큰 테스트

[3] 송금 API 파라미터 이해

[4] FastAPI /intent 구현

[5] FastAPI /transfer 구현

[6] 대화 로그 저장 (/log)

[7] 텍스트 기반 시뮬레이터 만들기

[8] 슬롯 누락 예외 처리 설계

[9] 인증 단계 모킹

[10] Android STT + TTS 연동

[11] FastAPI 연동 Android 클라이언트 구축

[12] OS 서비스로 확장 (VoiceInteractionService 등)

<br>

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



