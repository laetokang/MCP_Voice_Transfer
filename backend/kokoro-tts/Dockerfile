FROM python:3.10-slim

WORKDIR /app

# 시스템 종속성 설치
RUN apt-get update && apt-get install -y \
    wget ffmpeg git \
 && rm -rf /var/lib/apt/lists/*

# 파이썬 종속성 설치
COPY ./requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 모델 파일 다운로드 제거 - KPipeline이 자동으로 처리
RUN set -e && \
    mkdir models && \
    wget --tries=3 https://huggingface.co/hexgrad/Kokoro-82M/resolve/main/voices/af_heart.pt -O models/kokoro.pt

# Spacy 모델 다운로드 및 설치 (영어)
RUN python -m spacy download en_core_web_sm

# 앱 소스 복사
COPY ./app.py ./app.py

# TTS 서비스 포트 (컨테이너 내부 포트)
EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]