import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from fastapi import FastAPI, HTTPException, Body
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import logging
from contextlib import asynccontextmanager

from prompt_utils import run_inference, PROMPT_FUNCTIONS

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 모델 및 토크나이저 전역 변수
model = None
tokenizer = None
MODEL_ID = "Qwen/Qwen2.5-0.5B-Instruct" # Hugging Face Hub 모델 ID로 복구
# MODEL_ID = "../../models/Qwen2.5-0.5B-Instruct" # 로컬 경로로 수정 (프로젝트 루트 기준)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 애플리케이션 시작 시 모델 로드
    global model, tokenizer
    logger.info(f"Loading model: {MODEL_ID}")
    try:
        tokenizer = AutoTokenizer.from_pretrained(MODEL_ID)
        # FP16 사용 및 CUDA로 이동 (사용 가능할 경우)
        # if torch.cuda.is_available():
        #     model = AutoModelForCausalLM.from_pretrained(MODEL_ID, torch_dtype=torch.float16).to("cuda")
        #     logger.info("Model loaded on CUDA with float16.")
        # else:
        #     model = AutoModelForCausalLM.from_pretrained(MODEL_ID)
        #     logger.info("Model loaded on CPU.")
        
        # 명시적으로 CPU에 모델 로드 및 torch_dtype 제거
        model = AutoModelForCausalLM.from_pretrained(MODEL_ID)
        logger.info("Model explicitly loaded on CPU.")

        # Instruct 모델의 경우 pad_token_id가 없을 수 있음. eos_token_id로 설정.
        if tokenizer.pad_token_id is None:
            tokenizer.pad_token_id = tokenizer.eos_token_id
            logger.info(f"tokenizer.pad_token_id set to tokenizer.eos_token_id: {tokenizer.eos_token_id}")

    except Exception as e:
        logger.error(f"Error loading model or tokenizer: {e}", exc_info=True)
        # 모델 로드 실패 시 애플리케이션이 정상적으로 시작되지 않을 수 있음
        # 실제 운영 환경에서는 더 강력한 오류 처리 및 알림 필요
        raise RuntimeError(f"Failed to load model or tokenizer: {e}") from e
    yield
    # 애플리케이션 종료 시 정리 (필요한 경우)
    logger.info("Application shutdown.")
    model = None
    tokenizer = None

app = FastAPI(lifespan=lifespan)

class InferenceRequest(BaseModel):
    input_text: str
    prompt_version: str = "prompt4" # 기본 프롬프트 버전
    max_new_tokens: int = 128

class InferenceResponse(BaseModel):
    parsed_result: dict
    inference_time: float
    # raw_output: Optional[str] = None # 필요시 원본 출력도 포함 가능

@app.post("/infer", response_model=InferenceResponse)
async def infer_llm(request: InferenceRequest = Body(...)):
    if model is None or tokenizer is None:
        logger.error("Model or tokenizer not loaded.")
        raise HTTPException(status_code=503, detail="Model is not available. Please try again later.")

    if request.prompt_version not in PROMPT_FUNCTIONS:
        raise HTTPException(status_code=400, detail=f"Invalid prompt_version. Available versions: {list(PROMPT_FUNCTIONS.keys())}")

    logger.info(f"Received inference request for prompt '{request.prompt_version}': {request.input_text[:50]}...")

    try:
        parsed_json, inference_time = run_inference(
            input_text=request.input_text,
            prompt_func_key=request.prompt_version,
            tokenizer=tokenizer,
            model=model,
            max_new_tokens=request.max_new_tokens
        )
        
        logger.info(f"Inference successful. Time taken: {inference_time:.3f}s")
        # 에러가 내부적으로 처리되어 parsed_json에 포함될 수 있음
        if parsed_json and "error" in parsed_json:
             # 모델 내부에서 발생한 에러 (예: JSON 파싱 실패)
            logger.warning(f"Error during inference process: {parsed_json.get('error')}")
            # 클라이언트에게는 성공적으로 처리되었으나, 결과에 에러가 있음을 알릴 수 있음
            # 혹은 상황에 따라 500 에러를 발생시킬 수도 있음
            # 여기서는 일단 성공으로 처리하고, 에러 내용은 parsed_json에 담아 반환
            return InferenceResponse(
                parsed_result=parsed_json, 
                inference_time=inference_time
            )

        return InferenceResponse(
            parsed_result=parsed_json, 
            inference_time=inference_time
        )

    except ValueError as ve:
        logger.warning(f"Value error during inference: {ve}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Unexpected error during inference: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="An unexpected error occurred during inference.")

@app.get("/")
async def root():
    return {"message": "Qwen LLM Inference API is running."}

# API 실행 방법 (터미널에서):
# uvicorn MCP_Voice_Transfer.api.llm_qwen_api.main:app --reload --port 8008 