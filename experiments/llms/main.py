from fastapi import FastAPI
from pydantic import BaseModel
import time
import json
import requests
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
import re

# FastAPI 앱 생성
app = FastAPI()

# 텍스트 입력 모델
class TextInput(BaseModel):
    text: str  # 클라이언트로부터 받은 텍스트

# LLM 모델 및 토크나이저 로딩
qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct")
qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct", torch_dtype=torch.float16).to("cuda")

# 프롬프트 생성 함수
def unified_system_prompt(input_text: str) -> list:
    system_message = {
        "role": "system",
        "content": f"""
        다음 문장을 분석하여 intent, amount, recipient, response를 예시 형식에 맞게 추출해 주세요.

        **intent**는 다음 중 하나입니다:
        - `transfer`: 사용자가 금전을 송금하려는 의도
        - `confirm`: 이전 발화의 확인 또는 반복
        - `cancel`: 이전 동작을 취소하거나 거절하는 의도
        - `inquiry`: 송금 및 관련 정보 확인 요청
        - `other`: 시스템과 관련 없는 일상적인 대화 또는 분류 불가한 문장
        - `system_response`: 시스템의 재질문 또는 안내 응답

        **amount**는 숫자만 (없으면 `None`)
        **recipient**는 사람 이름 (없으면 `None`)
        **response**는 고객님에게 제공할 자연스러운 안내 응답

        예시:
        text: "엄마한테 삼만원 보내줘"

        {{ "intent": "transfer", "amount": 30000, "recipient": "엄마", "response": "엄마님께 30,000원을 송금해드릴까요?" }}

        **주의**:
        - `intent`는 반드시 위의 범주 중 하나로만 반환되어야 합니다.
        - `amount`는 명시된 숫자를 기반으로 하며 없을 경우 `None`을 반환합니다.
        - `recipient`는 발화에서 언급된 사람의 이름을 추출합니다. 없을 경우 `None`입니다.
        - `response`는 사용자의 발화에 대해 자연스러운 한국어 안내문을 생성해야 합니다.

        **사용자 발화:**
        {input_text}
        """
    }

    user_message = {
        "role": "user",
        "content": input_text
    }

    return [system_message, user_message]
    # return [user_message]


# LLM 모델에 텍스트를 보내고 추론을 받는 함수
def run_inference_qwen(input_text: str, tokenizer, model, max_new_tokens=128):
    # 프롬프트 구성
    messages = unified_system_prompt(input_text)
    prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    
    # 토크나이즈 및 디바이스 이동
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    
    # 모델 추론
    start = time.time()
    outputs = model.generate(**inputs, max_new_tokens=max_new_tokens, do_sample=False, use_cache=False)
    end = time.time()

    # 디코딩 및 프롬프트 제거
    generated = tokenizer.decode(outputs[0], skip_special_tokens=True)
    output_text = generated.replace(prompt, "").strip()

    # 'assistant' 이후 텍스트만 남기기
    assistant_split = re.split(r"\bassistant\b", output_text, flags=re.IGNORECASE)
    assistant_response = assistant_split[-1].strip()

    # JSON 파싱
    match = re.search(r'\{\s*"intent":.*?\}', assistant_response, re.DOTALL)
    if match:
        try:
            parsed_json = json.loads(match.group())
            return output_text, parsed_json, round(end - start, 2)
        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 실패: {e}")
            return output_text, None, round(end - start, 2)
    else:
        print("⚠️ assistant 이후 JSON 객체를 찾을 수 없습니다.")
        return output_text, None, round(end - start, 2)

# FastAPI 엔드포인트 정의
@app.post("/process")
async def process_text(input: TextInput):
    result, parsing, elapsed = run_inference_qwen(input.text, qwen_tokenizer, qwen)

    if parsing is None:
        return {
            "error": "Parsing failed",
            "text": input.text,
            "raw_output": result,
            "_meta": {"inference_time": elapsed}
        }

    return {
        "text": input.text,
        "intent": parsing["intent"],
        "slots": {
            "recipient": parsing.get("recipient"),
            "amount": parsing.get("amount")
        },
        "response": parsing.get("response", ""),
        "_meta": {"inference_time": elapsed}
    }
