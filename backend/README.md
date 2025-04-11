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
