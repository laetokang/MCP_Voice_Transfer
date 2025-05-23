import os
import time
import torch
import librosa
import numpy as np
from transformers import AutoModelForSpeechSeq2Seq, AutoProcessor, pipeline
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# 테스트할 모델 목록 (실제 존재하는 모델들만 포함)
MODELS = [
    {
        "name": "Distil-Whisper Large-v2",
        "model_id": "distil-whisper/distil-large-v2",
        "dtype": torch.float16,
    },
    {
        "name": "Distil-Whisper Medium",  # Large-v3 버전이 없으므로 Medium도 테스트
        "model_id": "distil-whisper/distil-medium.en",
        "dtype": torch.float16,
    },
    {
        "name": "Whisper Large-v3 (Fast)",  # Turbo 버전 대신 Fast 설정으로 테스트
        "model_id": "openai/whisper-large-v3",
        "dtype": torch.float16,
        "fast": True,
    }
]

# 장치 설정
DEVICE = os.environ.get("DEVICE", "cuda:0" if torch.cuda.is_available() else "cpu")
logging.info(f"Using device: {DEVICE}")

# 오디오 파일 로드
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

results = []

# 각 모델 테스트
for model_config in MODELS:
    model_name = model_config["name"]
    model_id = model_config["model_id"]
    dtype = model_config["dtype"]
    is_fast = model_config.get("fast", False)
    
    logging.info(f"Testing model: {model_name} ({model_id})")
    
    try:
        # CPU에서는 float16이 제대로 지원되지 않으므로 float32로 변경
        if DEVICE == "cpu" and dtype == torch.float16:
            logging.warning("Using CPU, changing dtype to float32")
            dtype = torch.float32
        
        # 모델 및 프로세서 로드
        logging.info(f"Loading model with dtype: {dtype}")
        processor = AutoProcessor.from_pretrained(model_id)
        model = AutoModelForSpeechSeq2Seq.from_pretrained(
            model_id,
            torch_dtype=dtype,
            low_cpu_mem_usage=True
        )
        model = model.to(DEVICE)
        
        # 파이프라인 생성
        pipe_kwargs = {
            "model": model,
            "tokenizer": processor.tokenizer,
            "feature_extractor": processor.feature_extractor,
            "device": DEVICE
        }
        
        pipe = pipeline("automatic-speech-recognition", **pipe_kwargs)
        
        # 추론 설정
        generate_kwargs = {"language": "korean"}
        
        # 속도 최적화를 위한 설정 (옵션)
        if is_fast:
            generate_kwargs.update({
                "do_sample": False,
                "num_beams": 1
            })
        
        # 추론 시간 측정
        logging.info("Starting inference...")
        start_time = time.time()
        
        outputs = pipe(
            audio_input, 
            chunk_length_s=30, 
            batch_size=8, 
            generate_kwargs=generate_kwargs,
            return_timestamps=True
        )
        
        end_time = time.time()
        inference_time = end_time - start_time
        
        # 결과 기록
        logging.info(f"Inference finished. Text: {outputs['text']}")
        logging.info(f"Model: {model_name}")
        logging.info(f"Inference Time: {inference_time:.6f} seconds")
        
        results.append({
            "model": model_name,
            "time": inference_time,
            "text": outputs['text']
        })
        
    except Exception as e:
        logging.error(f"Error testing model {model_name}: {e}")
        results.append({
            "model": model_name,
            "time": None,
            "text": f"Error: {str(e)}"
        })
    
    # GPU 메모리 정리
    if DEVICE.startswith("cuda"):
        torch.cuda.empty_cache()

# 결과 요약 출력
logging.info("\n\n=== RESULTS SUMMARY ===")
for result in results:
    if result["time"] is not None:
        logging.info(f"{result['model']}: {result['time']:.6f}초 - \"{result['text']}\"")
    else:
        logging.info(f"{result['model']}: 실패 - {result['text']}")
logging.info("=====================\n") 