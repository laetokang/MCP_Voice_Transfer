# %% library load

# pip install transformers==4.50.0

import sys
import torch
import transformers
# import onnx
# import onnxruntime
import tokenizers
import numpy

import re
import time
import json

from transformers import AutoModelForCausalLM, AutoTokenizer
# !pip install prompt_templates

# %% data load
with open("/workspace/MCP_Voice_Transfer/experiments/llms/test/samples.json") as f:
    samples=json.load(f)
    
print(samples)

#%%
qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct")
qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-0.5B-Instruct",torch_dtype=torch.float16).to("cuda")

#%%
qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-1.5B-Instruct")
qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen2.5-1.5B-Instruct",torch_dtype=torch.float16).to("cuda")

#%% transformers-4.52.0.dev0 |  pip-25.1.1
qwen_tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3-0.6B-Base")
qwen = AutoModelForCausalLM.from_pretrained("Qwen/Qwen3-0.6B-Base")


#%% prompt_templates.py
def unified_system_prompt1(input_text: str) -> list:

    system_message = {
        "role": "system",
        "content": """
당신은 사용자의 금융 발화를 분석하는 AI 송금 도우미입니다. 다음 지침에 따라 작동하세요:

1. 사용자의 문장에서 다음 항목을 추출하세요:
    - intent: 다음 중 하나 (transfer, confirm, cancel, inquiry, other, system_response)
    - amount: 숫자만 추출 (없으면 null)
    - recipient: 사람 이름 등 (없으면 null)

2. 사용자의 발화에 어울리는 자연스러운 안내 응답(response)을 생성하세요.

3. 다음 JSON 형식으로 하나의 객체로 응답하세요. 다른 텍스트는 출력하지 마세요.

예시:
{
  "intent": "transfer",
  "amount": 30000,
  "recipient": "엄마",
  "response": "엄마님께 30,000원을 송금해드릴까요?"
}
"""
    }

    user_message = {
        "role": "user",
        "content": input_text
    }

    return [system_message, user_message]

#%% new_prompt
def unified_system_prompt2(input_text: str) -> list:
    system_message = {
            "role": "system",
            "content": """
당신은 사용자의 금융 발화를 분석하는 AI 송금 도우미입니다. 다음 지침에 따라 작동하세요:

1. 사용자의 문장에서 다음 항목을 추출하세요:
    - **intent**: 사용자의 요청 의도 (다음 중 하나: transfer, confirm, cancel, inquiry, other, system_response)
    - **amount**: 금액만 추출 (금액이 명시되지 않으면 null로 설정)
    - **recipient**: 송금 대상 사람 이름 (이름이 명시되지 않으면 null로 설정)

2. 사용자의 발화에 어울리는 자연스러운 안내 응답(response)을 생성하세요:
    - **intent**가 `transfer`일 경우: "송금"과 관련된 문장을 만들어야 합니다.
    - **intent**가 `inquiry`일 경우: "잔액 조회" 또는 "상태 확인"과 관련된 문장을 만들어야 합니다.
    - **intent**가 `confirm`일 경우: "확인"과 관련된 문장을 만들어야 합니다.
    - **intent**가 `cancel`일 경우: "취소"와 관련된 문장을 만들어야 합니다.

3. 다음 JSON 형식으로 응답하세요. 다른 텍스트는 출력하지 마세요.

예시:
{
  "intent": "transfer",    // 사용자의 의도
  "amount": 30000,         // 추출된 금액 (없으면 null)
  "recipient": "엄마",      // 수신자 (없으면 null)
  "response": "엄마님께 30,000원을 송금해드릴까요?"  // 사용자에게 제공할 응답
}
"""
        }
        
    user_message = {
        "role": "user",
        "content": input_text
    }

    return [system_message, user_message]

#%%
def unified_system_prompt3(input_text: str) -> list:
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


# %%
import json
import re
import time

def run_inference_qwen(input_text: str, unified_system_prompt,tokenizer, model, max_new_tokens=128):
    # 프롬프트 구성 (ChatML)
    messages = unified_system_prompt(input_text)
    prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)

    # 토크나이즈 및 디바이스 이동
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)

    # 모델 추론
    start = time.time()
    outputs = model.generate(
        **inputs,
        max_new_tokens=max_new_tokens,
        do_sample=False,
        use_cache=False
    )
    end = time.time()

    # 디코딩 및 프롬프트 제거
    generated = tokenizer.decode(outputs[0], skip_special_tokens=True)
    output_text = generated.replace(prompt, "").strip()
    
    # 'assistant' 이후 텍스트만 남기기
    assistant_split = re.split(r"\bassistant\b", output_text, flags=re.IGNORECASE)
    if len(assistant_split) < 2:
        print("⚠️ 'assistant' 이후 내용을 찾지 못했습니다.")
        return output_text, None, round(end - start, 2)

    assistant_response = assistant_split[-1].strip()

    # JSON 파싱 시도
    match = re.search(r'\{\s*"intent":.*?\}', assistant_response, re.DOTALL)
    if match:
        try:
            # JSON 파싱
            parsed_json = json.loads(match.group())
            return output_text, parsed_json, round(end - start, 2)
        except json.JSONDecodeError as e:
            print(f"❌ JSON 파싱 실패: {e}")
            # 파싱 실패 시 None 반환 및 에러 메시지
            return output_text, None, round(end - start, 2)
    else:
        print("⚠️ assistant 이후 JSON 객체를 찾을 수 없습니다.")
        return output_text, None, round(end - start, 2)


#%%
result, pasing, elapsed = run_inference_qwen("안녕",unified_system_prompt3, qwen_tokenizer, qwen)
print("🔍 추론 결과:", result)
print("🧩 파싱된 JSON:\n", pasing)
print("⏱️ 처리 시간:", elapsed, "초")

#%%
print(samples[6]['text'])
result, pasing, elapsed = run_inference_qwen(samples[6]['text'],unified_system_prompt3, qwen_tokenizer, qwen)
print("🔍 추론 결과:", result)
print("🧩 파싱된 JSON:\n", pasing)
print("⏱️ 처리 시간:", elapsed, "초")

#%%
# 파싱 결과 처리
parsed = []  # 여러 파싱 결과를 담을 리스트
raw_outputs = []  # 원본 결과를 담을 리스트
total_time = 0  # 총 시간

for sample in samples:
    # 추론 실행 (파싱, 응답 생성)
    result, parsing, elapsed = run_inference_qwen(sample["text"],unified_system_prompt3, qwen_tokenizer, qwen)
    total_time += elapsed  # 실행 시간 누적

    # 파싱 실패 처리 (parsing이 None인 경우)
    if parsing is None:
        meta = {"error": "Parsing failed", "inference_time": elapsed}
        parsed.append({
            "text": sample["text"],
            "intent": None,  # 파싱 실패 시 None
            "slots": {
                "recipient": None,  # 파싱 실패 시 None
                "amount": None  # 파싱 실패 시 None
            },
            "response": "",  # 응답이 비어 있는 경우
            "_meta": meta  # 파싱 실패 시 에러 메시지 포함
        })
    else:
        # 파싱 성공 시
        meta = {"inference_time": elapsed}
        parsed.append({
            "text": sample["text"],
            "intent": parsing["intent"],
            "slots": {
                "recipient": parsing["recipient"],
                "amount": parsing["amount"]
            },
            "response": "",  # 응답이 비어 있는 경우
            "_meta": meta  # 추론 시간 저장
        })
    
    # 원본 결과를 raw_outputs에 저장
    raw_outputs.append({
        "text": sample["text"],
        "raw_output": result  # 원본 결과 저장
    })

# 저장
with open("results_qwen3.json", "w", encoding="utf-8") as f:
    json.dump(parsed, f, indent=2, ensure_ascii=False)  # parsed 리스트 저장

with open("raw_outputs3.json", "w", encoding="utf-8") as f:
    json.dump(raw_outputs, f, indent=2, ensure_ascii=False)  # raw_outputs 리스트 저장


#%% ASSESMENT

# 평가 지표 초기화
correct_intent = 0
correct_recipient = 0
correct_amount = 0
parsing_success = 0

# results_qwen.json 파일 열기
with open("results_qwen3.json", "r", encoding="utf-8") as f:
    results = json.load(f)  # 이미 저장된 파싱 결과 파일을 읽어옵니다.

# 총 샘플 수
total = len(samples)

# 평가
for result, ex in zip(results, samples):
    meta = result.get("_meta", {})

    # 파싱 성공 여부
    if "error" not in meta:
        parsing_success += 1

    # 예측값
    pred_intent = result.get("intent")
    pred_recipient = result.get("slots", {}).get("recipient")
    pred_amount = result.get("slots", {}).get("amount")

    # 정답값
    true_intent = ex["intent"]
    true_recipient = ex["slots"]["recipient"]
    true_amount = ex["slots"]["amount"]

    # 평가
    if pred_intent == true_intent:
        correct_intent += 1
    if pred_recipient == true_recipient:
        correct_recipient += 1
    if pred_amount == true_amount:
        correct_amount += 1
    # 총 처리 시간 누적
    total_time += meta.get("inference_time", 0)


# 평균 처리 시간 계산 (초 단위)
average_time = total_time / total if total > 0 else 0

# 총 샘플 수
total = len(samples)

# 평가 결과 정리
evaluation = {
    "Intent 정확도": f"{correct_intent}/{total} ({correct_intent/total:.0%})",
    "Recipient 정확도": f"{correct_recipient}/{total} ({correct_recipient/total:.0%})",
    "Amount 정확도": f"{correct_amount}/{total} ({correct_amount/total:.0%})",
    "파싱 성공률": f"{parsing_success}/{total} ({parsing_success/total:.0%})",
     "평균 처리 시간": f"{average_time:.4f} 초"  # 평균 처리 시간 추가
}

# 결과 출력
print(evaluation)

# %%
