# 🧠 MCP_Voice_Transfer - Backend System

## 📦 구조 개요

```
backend/
├── auth/              # 인증 모듈 (지문/음성 모킹 등)
├── data/              # 계좌, 로그 등 JSON 저장
├── event/             # Redis Pub/Sub 처리
├── fds/               # 이상거래 탐지
├── gateway/           # FastAPI Gateway + router
├── llm/               # Intent 분석 + gRPC client
├── proto/             # gRPC 메시지 정의 및 컴파일
├── shared/            # 공통 유틸, 로거 등
├── transfer/          # 송금 처리 로직
├── requirements.txt   # 의존성 명세
└── docker-compose.yml # 전체 서비스 실행
```

## ✅ 실행법 (로컬 개발 기준)

```bash
# 의존성 설치
pip install -r requirements.txt

# 각 서비스별 실행 (예: gateway)
cd backend/gateway
uvicorn main:app --reload --port 8000

# 또는 전체 실행
docker-compose up --build
```

## 🌐 주요 API

| 경로                | 설명                  |
|---------------------|-----------------------|
| `POST /api/intent`  | 의도 분석 + 이벤트 발행 |
| `POST /api/transfer`| 송금 수행 (더미)        |
| `POST /api/auth`    | 사용자 인증 모킹        |
| `POST /api/log`     | 로그 저장 (JSON 파일)   |
| `GET /api/healthcheck` | 시스템 상태 확인     |






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



