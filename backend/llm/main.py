# backend/llm/main.py
from event.redis import publish_event
# llm/send_to_fds.py 또는 fds/main.py
from proto import intent_pb2, intent_pb2_grpc


publish_event("intent_detected", {
  "user_id": "kim",
  "amount": 20000,
  "recipient": "엄마"
})
