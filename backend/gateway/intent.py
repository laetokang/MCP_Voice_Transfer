from fastapi import APIRouter, Request
from pydantic import BaseModel
from event.redis import publish_event

router = APIRouter()

class IntentRequest(BaseModel):
    text: str
    user_id: str

@router.post("/intent")
async def process_intent(req: IntentRequest):
    # 간단한 룰 기반 예시 (실제로는 LLM 결과가 와야 함)
    intent = "transfer" if "보내줘" in req.text else "unknown"
    to = "엄마" if "엄마" in req.text else "미상"
    amount = 30000 if "3만" in req.text else 0

    # Redis 이벤트 발행
    publish_event("intent_detected", {
        "user_id": req.user_id,
        "intent": intent,
        "recipient": to,
        "amount": amount
    })

    return {"status": "published", "intent": intent, "to": to, "amount": amount}
