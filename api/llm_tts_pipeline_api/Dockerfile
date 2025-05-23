# 1. Base image
FROM python:3.10-slim

# 2. Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV APP_HOME /app

# 3. Set work directory
WORKDIR $APP_HOME

# 4. Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy application code
COPY . .

# 6. Expose port (파이프라인 API가 사용할 포트, 예: 8009)
EXPOSE 8009

# 7. Command to run the application
# QWEN_LLM_API_URL 및 KOKORO_TTS_API_URL 환경 변수를 사용하여 실행 시 주소 변경 가능
# 예: docker run -e QWEN_LLM_API_URL=http://host.docker.internal:8008 ...
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8009"] 