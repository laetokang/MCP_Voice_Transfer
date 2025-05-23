import json
import re
import time
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

# ##############################################
# ## PROMPT DEFINITIONS (from QWEN_TEST.py) ##
# ##############################################

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
    user_message = {"role": "user", "content": input_text}
    return [system_message, user_message]

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
    user_message = {"role": "user", "content": input_text}
    return [system_message, user_message]

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
        {{input_text}}
        """
    }
    user_message = {"role": "user", "content": input_text}
    return [system_message, user_message]

def unified_system_prompt4(input_text: str) -> list:
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
        
        text: "송금할래"
        {{"intent": "transfer","amount": null,"recipient": null,"response": "송금하실 대상과 금액을 말씀해주세요."}}
        
        text: "보내지 마",
        {{"intent": "cancel","recipient": null,"amount": null,"response": "요청하신 송금을 취소했습니다."}}
        
        text: "아, 삼만원 보내는 거였지",
        {{"intent": "confirm","recipient": null,"amount": 30000,"response": "30,000원 송금 요청으로 확인했습니다."}}
  

        **주의**:
        - `intent`는 반드시 위의 범주 중 하나로만 반환되어야 합니다.
        - `amount`는 명시된 숫자를 기반으로 하며 없을 경우 `None`을 반환합니다.
        - `recipient`는 발화에서 언급된 사람의 이름을 추출합니다. 없을 경우 `None`입니다.
        - `response`는 사용자의 발화에 대해 자연스러운 한국어 안내문을 생성해야 합니다.

        **사용자 발화:**
        {{input_text}}
        """
    }
    user_message = {"role": "user", "content": input_text}
    return [system_message, user_message]


PROMPT_FUNCTIONS = {
    "prompt1": unified_system_prompt1,
    "prompt2": unified_system_prompt2,
    "prompt3": unified_system_prompt3,
    "prompt4": unified_system_prompt4,
}

# ##############################################
# ## INFERENCE FUNCTION (from QWEN_TEST.py) ##
# ##############################################

def run_inference(
    input_text: str, 
    prompt_func_key: str, 
    tokenizer: AutoTokenizer, 
    model: AutoModelForCausalLM, 
    max_new_tokens=128
):
    prompt_func = PROMPT_FUNCTIONS.get(prompt_func_key)
    if not prompt_func:
        raise ValueError(f"Invalid prompt_func_key: {{prompt_func_key}}")

    messages = prompt_func(input_text)
    
    # Ensure the model and tokenizer are on the same device, especially if model was moved to GPU
    if model.device.type == "cuda" and hasattr(tokenizer, 'pad_token_id') and tokenizer.pad_token_id is None:
        tokenizer.pad_token_id = tokenizer.eos_token_id # Set pad_token_id to eos_token_id if not set

    # Prepare the prompt for the model
    # For some models, explicitly setting add_generation_prompt=True is important.
    # For others, the template might already include it or it's not needed.
    # If using a base model (not instruct-tuned), this part might need adjustment.
    try:
        chat_template_inputs = tokenizer.apply_chat_template(
            messages, 
            tokenize=False, 
            add_generation_prompt=True # Important for instruct/chat models
        )
    except Exception as e:
        # Fallback or error if chat template application fails
        # This might happen if the tokenizer doesn't have a default chat template
        # or if the messages format is not what the template expects.
        print(f"Error applying chat template: {e}. Using basic concatenation as fallback.")
        # Basic fallback: concatenate content. This might not be optimal for chat models.
        chat_template_inputs = "\\n".join([msg["content"] for msg in messages if "content" in msg])


    inputs = tokenizer(chat_template_inputs, return_tensors="pt").to(model.device)

    start_time = time.time()
    try:
        outputs = model.generate(
            **inputs,
            max_new_tokens=max_new_tokens,
            do_sample=False, # For deterministic output, change if sampling is needed
            use_cache=True   # Can be true for faster generation in some cases
        )
    except Exception as e:
        print(f"Error during model.generate: {e}")
        return {"error": str(e)}, None, 0.0

    end_time = time.time()
    inference_time = round(end_time - start_time, 3)

    # Decode the output
    # outputs[0] contains the full sequence (input_ids + generated_ids)
    # We need to slice the generated part only if inputs are not part of outputs in tokenizer.decode
    # For many setups, decoding outputs[0] and then removing the prompt is standard.
    
    # generated_ids = outputs[0][inputs.input_ids.shape[1]:] # Get only generated token ids
    # generated_text = tokenizer.decode(generated_ids, skip_special_tokens=True)

    full_generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)

    # Remove the input prompt part from the full generated text
    # This can be tricky if the exact prompt isn't perfectly reproduced or if special tokens are handled differently
    # A common way is to remove the `chat_template_inputs` text if it's at the beginning
    if full_generated_text.startswith(chat_template_inputs.replace("<|im_end|>", "").strip()): # chat_template_inputs might have special tokens not in final output
         output_text = full_generated_text[len(chat_template_inputs.replace("<|im_end|>", "").strip()):].strip()
    else:
        # Fallback or more robust prompt removal needed if the above is not working consistently
        # For Qwen, response is typically after 'assistant\n'
        assistant_marker = "assistant" # Adjust if model uses a different marker like <|im_start|>assistant
        # Try to find the assistant marker
        # The exact output format depends on the model and its chat template.
        # This part might need to be adjusted based on the actual model output.
        
        # Let's look for the last occurrence of assistant marker if model is chat-tuned
        # and tokenizer.apply_chat_template added it.
        # The previous `re.split` logic from QWEN_TEST.py was:
        # assistant_split = re.split(r"\\bassistant\\b", output_text, flags=re.IGNORECASE)
        # This assumes 'assistant' is a word boundary.
        # A simpler split if the template always adds something like "\nassistant\n"
        parts = full_generated_text.split(assistant_marker + "\n")
        if len(parts) > 1:
            output_text = parts[-1].strip()
        else: # If no clear assistant marker, take the whole thing after prompt
            # This might be the case for base models or if add_generation_prompt was false/handled differently
            # Check if chat_template_inputs is part of full_generated_text and remove it.
            # This is a heuristic and might need refinement.
            input_len = len(tokenizer.decode(inputs.input_ids[0], skip_special_tokens=True))
            output_text = full_generated_text[input_len:].strip()


    # JSON parsing (from QWEN_TEST.py)
    # The regex tries to find a JSON object starting with {"intent": ... }
    # This is specific to the expected output format.
    match = re.search(r'\{\s*"intent":.*?\}', output_text, re.DOTALL | re.IGNORECASE) # Added IGNORECASE
    
    parsed_json = None
    error_message = None

    if match:
        json_str = match.group(0) # Get the first matched group which should be the JSON string
        try:
            parsed_json = json.loads(json_str)
        except json.JSONDecodeError as e:
            error_message = f"JSON parsing failed: {e}. Extracted string: {json_str}"
            print(f"❌ {error_message}")
            # Return the raw output text if JSON parsing fails
            parsed_json = {"error": "JSON parsing failed", "raw_output": output_text}
    else:
        error_message = "Could not find valid JSON in the model output."
        print(f"⚠️ {error_message}")
        # Return raw output if no JSON is found
        parsed_json = {"error": "No JSON found in output", "raw_output": output_text}

    return parsed_json, inference_time 