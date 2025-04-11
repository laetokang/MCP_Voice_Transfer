# backend/fds/listener.py
from event.redis import subscribe_event

def handle_intent(msg):
    print("FDS received intent:", msg)
    # 판단 후 transfer 호출 or gRPC

subscribe_event("intent_detected", handle_intent)
