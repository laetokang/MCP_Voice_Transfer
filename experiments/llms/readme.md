## LLM API 실행 방법
CUDA 12.8 환경 기준
Qwen/Qwen2.5-0.5B-Instruct + FastAPI 기반 경량 추론 서버

✅ 1. 필수 패키지 설치
```bash
pip install fastapi uvicorn
pip install transformers==4.50.0
```

✅ 2. FastAPI 서버 실행
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

✅ 3. Swagger UI 접속
브라우저에서 아래 주소 접속:

```bash
http://localhost:8000/docs
```

📦 실행 파일: main.py
📡 엔드포인트: POST /process
🔁 입력: { "text": "엄마한테 삼만원 보내줘" }
✅ 출력: intent, recipient, amount, response 포함 JSON
