from fastapi import FastAPI, HTTPException
from kokoro import KPipeline
import soundfile as sf
from fastapi.responses import FileResponse
import torch
import os
import logging

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()
pipeline_instance = None # 전역 변수로 선언, 초기값은 None

@app.on_event("startup")
async def startup_event():
    global pipeline_instance # 전역 변수 사용 명시
    logger.info("FastAPI application startup event: Attempting to initialize KPipeline...")
    try:
        pipeline_instance = KPipeline(lang_code='a', device='cpu')
        logger.info("KPipeline initialized successfully during startup.")
    except Exception as e:
        logger.error(f"Error initializing KPipeline during startup: {e}", exc_info=True)
        # pipeline_instance는 None으로 유지됨

@app.get("/")
def read_root():
    logger.info("Root endpoint / called.")
    if pipeline_instance is None:
        return {"status": "Kokoro TTS API is running, but KPipeline failed to initialize."}
    return {"status": "Kokoro TTS API is running and KPipeline is initialized."}

@app.post("/tts")
async def text_to_speech(text: str, voice: str = "af_heart"):
    logger.info(f"TTS request received. Text: '{text[:30]}...', Voice: {voice}")
    if pipeline_instance is None:
        logger.error("Cannot process TTS request because KPipeline is not initialized.")
        raise HTTPException(status_code=500, detail="KPipeline not initialized.")
    try:
        logger.info("Calling KPipeline to generate audio...")
        # 전역 pipeline_instance 사용
        generator = pipeline_instance(text, voice=voice) 
        audio_segments = []
        for i, (_, _, audio) in enumerate(generator):
            audio_segments.append(audio)
            logger.debug(f"Generated audio segment {i}")

        if not audio_segments:
            logger.warning("KPipeline generated no audio segments.")
            raise HTTPException(status_code=500, detail="No audio segments generated.")

        audio_combined = torch.cat(audio_segments)
        logger.info("Audio segments combined.")

        audio_path = "output.wav"
        sf.write(audio_path, audio_combined.numpy(), 24000)
        logger.info(f"Audio saved to {audio_path}")

        return FileResponse(audio_path, media_type="audio/wav")

    except Exception as e:
        logger.error(f"Error during TTS processing: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))