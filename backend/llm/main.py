# backend/llm/main.py
import time
import json
# from event.redis import publish_event
# llm/send_to_fds.py 또는 fds/main.py
# from proto import intent_pb2, intent_pb2_grpc
# Load model directly
from transformers import AutoTokenizer, AutoModelForCausalLM

tokenizer = AutoTokenizer.from_pretrained("microsoft/Phi-3-mini-4k-instruct", trust_remote_code=True)
model = AutoModelForCausalLM.from_pretrained("microsoft/Phi-3-mini-4k-instruct", trust_remote_code=True,attn_implementation="eager" )

def run_chatbot_inference(input_text:str):
  prompt=f"""
  사용자의 문장을 분석하여 의도(intent), 엔티티(entity), 응답 메시지를 생성하세요.
출력 형식은 다음과 같이 JSON으로 작성하세요:
{{
  "intent": "...",
  "amount": ...,
  "recipient": "...",
  "response": "..."
}} 

문장: "{input_text}"

"""
  inputs=tokenizer(prompt,return_tensors="pt")
  
  start=time.time()
  outputs=model.generate(
    **inputs,
    max_new_tokens=100,
    do_sample=False,
    temperature=0.7,
    top_p=0.9
  )
  end = time.time()
  generated=tokenizer.decode(outputs[0],skip_special_tokens=True)
  json_str=generated.replace(prompt,"").strip()
  
  try:
    result=json.loads(json_str)
    print("🧠 LLM 결과:\n", result)
    
    #Redis 이벤트 발행
    if result["intent"]=="송금":
      # publish_event("intent_detected", {
      #   "user_id": "user1",
      #   "amount": result.get("amount"),
      #   "recipient": result.get("recipient")
      # })
      print(result.get("amount"), result.get("recipient"))

    # 사용자 응답 출력
    print("💬 사용자에게 안내할 메시지:\n", result["response"])
  
  except Exception as e:
    print('json 파싱 실패:',e)
    print("원문:",json_str)
  
  print(f"처리 시간:{round(end-start,2)}초")
