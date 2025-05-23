# 1. Base image
FROM python:3.10-slim

# 2. Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV APP_HOME /app
ENV HF_HOME /app/huggingface_cache
ENV PYTHONPATH "${APP_HOME}:${PYTHONPATH}"

# 3. Set work directory
WORKDIR ${APP_HOME}

# 4. Install Python dependencies
# requirements.txt 복사 및 의존성 설치
COPY api/llm_qwen_api/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir -r /app/requirements.txt

# 5. 필요한 파일들만 선택적으로 복사 - COPY . /app 대신 사용
# API 코드 복사
COPY api/llm_qwen_api/main.py /app/api/llm_qwen_api/main.py
COPY api/llm_qwen_api/prompt_utils.py /app/api/llm_qwen_api/prompt_utils.py
# __init__.py 파일 추가로 api 패키지 인식 가능하게 함
RUN mkdir -p /app/api
RUN touch /app/api/__init__.py
RUN touch /app/api/llm_qwen_api/__init__.py

# 6. 모델 다운로드 스크립트 생성 및 실행
# 스크립트 경로를 조정하여 상대 경로 문제 회피
RUN echo 'import asyncio\nfrom fastapi import FastAPI\nimport sys\nsys.path.insert(0, "/app")\nfrom api.llm_qwen_api.main import lifespan\n\napp_dummy = FastAPI()\n\nasync def main():\n    async with lifespan(app_dummy):\n        pass\n\nasyncio.run(main())' > /app/preload_models.py
RUN python /app/preload_models.py

# 7. Expose port
EXPOSE 8008

# 8. Command to run the application
CMD ["uvicorn", "api.llm_qwen_api.main:app", "--host", "0.0.0.0", "--port", "8008", "--workers", "1"] 