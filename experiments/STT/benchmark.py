import os
import time
import torch
import logging
from transformers import pipeline
import numpy as np
import librosa

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# 환경 변수에서 설정값 읽기
MODEL_ID = os.environ.get("MODEL_ID", "openai/whisper-large-v3")
BATCH_SIZE = int(os.environ.get("BATCH_SIZE", 8))
CHUNK_LENGTH_S = int(os.environ.get("CHUNK_LENGTH_S", 30))
USE_FLASH_ATTENTION_2 = os.environ.get("USE_FLASH_ATTENTION_2", "False").lower() == "true"
TORCH_DTYPE_STR = os.environ.get("torch_dtype", "float16")

# Torch dtype 설정
TORCH_DTYPE = torch.float16 if TORCH_DTYPE_STR == "float16" else torch.float32

# 장치 설정 - 환경 변수에서 명시적으로 지정된 값이 있으면 사용
DEVICE = os.environ.get("DEVICE", None)
if DEVICE is None:
    # 명시적 설정이 없으면 가용성에 따라 자동 선택
    if torch.cuda.is_available():
        DEVICE = "cuda:0"
    else:
        DEVICE = "cpu"

# CPU에서는 float16 사용 불가 (CPU float16 지원은 제한적)
if DEVICE == "cpu" and TORCH_DTYPE == torch.float16:
    logging.warning("CPU device with float16 specified. Forcing dtype to float32 for CPU.")
    TORCH_DTYPE = torch.float32
    TORCH_DTYPE_STR = "float32"

logging.info(f"Device: {DEVICE}")
logging.info(f"Torch dtype: {TORCH_DTYPE}")
logging.info(f"Using Flash Attention 2: {USE_FLASH_ATTENTION_2}")
logging.info(f"Batch size: {BATCH_SIZE}")
logging.info(f"Chunk length (s): {CHUNK_LENGTH_S}")
logging.info(f"Loading model: {MODEL_ID}...")

# Attention 구현 설정
attn_implementation = "sdpa" # 기본값
if USE_FLASH_ATTENTION_2:
    if TORCH_DTYPE == torch.float16:
        try:
            import flash_attn
            attn_implementation = "flash_attention_2"
            logging.info("Setting attn_implementation to flash_attention_2")
        except ImportError:
            logging.warning("Flash Attention 2 requested but not installed. Falling back to SDPA.")
    else:
        logging.warning("Flash Attention 2 requires float16. Falling back to SDPA.")


# 모델 로딩
try:
    pipe = pipeline(
        "automatic-speech-recognition",
        model=MODEL_ID,
        torch_dtype=TORCH_DTYPE,
        device=DEVICE,
        model_kwargs={"attn_implementation": attn_implementation} if attn_implementation != "sdpa" else {}
    )
    logging.info("Model loaded successfully.")
except Exception as e:
    logging.error(f"Error loading model: {e}")
    exit(1)

# 테스트용 오디오 파일 로드
audio_path = "/app/audio.mp3"
try:
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"Audio file not found at {audio_path}")

    logging.info(f"Loading audio file: {audio_path}")
    # librosa를 사용하여 오디오 로드 (16kHz로 리샘플링)
    audio_input, sample_rate = librosa.load(audio_path, sr=16000)
    logging.info(f"Audio loaded successfully. Duration: {len(audio_input)/sample_rate:.2f} seconds")

except FileNotFoundError as e:
    logging.error(f"{e}. Please make sure the audio file is copied to the container at /app/audio.mp3.")
    exit(1)
except Exception as e:
    logging.error(f"Error loading audio file {audio_path}: {e}")
    exit(1)


# 추론 시간 측정
logging.info("Starting inference...")
start_time = time.time()

# 추론 실행
try:
    outputs = pipe(
        audio_input.copy(), # 로드된 실제 오디오 데이터 사용
        chunk_length_s=CHUNK_LENGTH_S,
        batch_size=BATCH_SIZE,
        generate_kwargs={"language": "korean"},
        return_timestamps=True,
    )
except Exception as e:
    logging.error(f"Error during inference: {e}")
    exit(1)

end_time = time.time()
inference_time = end_time - start_time

logging.info(f"Inference finished. Text: {outputs['text']}")
logging.info(f"--- Benchmark Result ---")
logging.info(f"Model: {MODEL_ID}")
logging.info(f"Dtype: {TORCH_DTYPE_STR}")
logging.info(f"Attention: {attn_implementation}")
logging.info(f"Batch Size: {BATCH_SIZE}")
logging.info(f"Chunk Length: {CHUNK_LENGTH_S}s")
logging.info(f"Inference Time: {inference_time:.6f} seconds")
logging.info(f"------------------------") 