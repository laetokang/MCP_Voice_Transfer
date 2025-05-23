from fastapi import FastAPI, HTTPException, Body, Query
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import httpx
import logging
import io
from deep_translator import GoogleTranslator

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# 외부 API 주소
QWEN_LLM_API_URL = "http://qwen-llm-api:8008/infer"
KOKORO_TTS_API_URL = "http://backend-kokoro-tts-english:7006/tts"

class PipelineRequest(BaseModel):
    text: str  # curl 명령과 일치하도록 user_input → text로 변경
    llm_prompt_version: str = "prompt4"
    max_new_tokens: int = 128
    tts_language: str = "en"
    tts_voice: str = "af_heart"  # 기본값으로 af_heart 설정

@app.get("/")
async def root():
    return {"message": "LLM-TTS Pipeline API is running."}

@app.post("/pipeline/tts")
async def pipeline_tts(request: PipelineRequest = Body(...)):
    logger.info(f"Pipeline request received: Text - {request.text[:50]}..., TTS Voice - {request.tts_voice}")
    
    # 1. LLM API 호출 (Qwen LLM API)
    llm_payload = {
        "input_text": request.text,
        "prompt_version": request.llm_prompt_version,
        "max_new_tokens": request.max_new_tokens
    }
    
    try:
        async with httpx.AsyncClient() as client:
            logger.info(f"Calling Qwen LLM API with payload: {llm_payload}")
            response = await client.post(QWEN_LLM_API_URL, json=llm_payload, timeout=60.0)
            response.raise_for_status()
            llm_data = response.json()
            
            # LLM 응답에서 실제 텍스트 추출
            parsed_result = llm_data.get("parsed_result", {})
            llm_response_text = parsed_result.get("raw_output") # 1순위: raw_output
            if not llm_response_text:
                llm_response_text = parsed_result.get("response") # 2순위: 기존 response 키

            if not llm_response_text:
                # 만약 raw_output 과 response 둘 다 없다면, parsed_result 전체를 문자열로 사용 (최후의 수단)
                if parsed_result: # parsed_result가 비어있지 않다면
                     llm_response_text = str(parsed_result)
                elif llm_data: # parsed_result는 없지만 llm_data는 있다면 (예: { "output": "text" } 형태의 직접적인 응답)
                     llm_response_text = str(llm_data.get("output", str(llm_data))) # "output" 키를 시도하거나 전체를 문자열로
                else: # 둘 다 비어있으면
                     llm_response_text = "" # 빈 문자열로 초기화
                
                if llm_response_text: # 폴백으로 뭔가 채워졌다면 로그 남김
                    logger.warning(f"LLM 'raw_output' and 'response' are empty. Using fallback: {llm_response_text[:100]}...")
            
            # 최종적으로 llm_response_text가 비어있을 경우에만 에러를 발생
            if not llm_response_text:
                 logger.error("LLM response text is ultimately empty even after fallbacks.")
                 raise HTTPException(status_code=500, detail="LLM returned an empty or unusable response.")

            logger.info(f"LLM original response (or fallback): {llm_response_text}")

            # 요청된 TTS 언어가 영어이고, LLM 응답이 있을 경우 영어로 번역
            if request.tts_language == "en" and llm_response_text:
                try:
                    translated_text = GoogleTranslator(source='auto', target='en').translate(llm_response_text)
                    logger.info(f"Translated LLM response to English: {translated_text}")
                    tts_input_text = translated_text
                except Exception as e:
                    logger.error(f"Error translating text to English: {e}")
                    # 번역 실패 시 원본 텍스트 사용
                    tts_input_text = llm_response_text 
            else:
                tts_input_text = llm_response_text
            
    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error calling LLM API: {e.response.status_code} - {e.response.text}", exc_info=True)
        raise HTTPException(status_code=e.response.status_code, detail=f"Error calling LLM API: {e.response.text}")
    except httpx.RequestError as e:
        logger.error(f"Request error calling LLM API: {e}", exc_info=True)
        raise HTTPException(status_code=503, detail=f"LLM API is unavailable: {e}")
    except Exception as e:
        logger.error(f"Unexpected error processing LLM response: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="An unexpected error occurred after LLM processing.")

    logger.info(f"Text for TTS: {tts_input_text}")

    # 2. TTS API 호출
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            tts_params = {"text": tts_input_text, "voice": request.tts_voice}
            logger.info(f"Calling Kokoro TTS API: {KOKORO_TTS_API_URL} with params: {tts_params}")
            response = await client.post(KOKORO_TTS_API_URL, params=tts_params)
            response.raise_for_status()
            
            content_type = response.headers.get("content-type", "audio/wav")
            
            async def audio_stream_generator():
                async for chunk in response.aiter_bytes():
                    yield chunk
            
            logger.info(f"Streaming audio response from TTS API with content-type: {content_type}")
            return StreamingResponse(audio_stream_generator(), media_type=content_type)

    except httpx.HTTPStatusError as e:
        logger.error(f"HTTP error calling TTS API: {e.response.status_code} - {e.response.text}", exc_info=True)
        error_detail_tts = e.response.json().get("detail", str(e.response.text)) if e.response.content else str(e.response.status_code)
        raise HTTPException(status_code=e.response.status_code, detail=f"Error calling TTS API: {error_detail_tts}")
    except httpx.RequestError as e:
        logger.error(f"Request error calling TTS API: {e}", exc_info=True)
        raise HTTPException(status_code=503, detail=f"TTS API is unavailable: {e}")
    except Exception as e:
        logger.error(f"Unexpected error processing TTS response: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="An unexpected error occurred after TTS processing.")
