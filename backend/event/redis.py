# backend/event/redis.py
import redis
import json

r = redis.Redis(host="redis", port=6379, decode_responses=True)

def publish_event(channel, data: dict):
    r.publish(channel, json.dumps(data))

def subscribe_event(channel, handler):
    pubsub = r.pubsub()
    pubsub.subscribe(channel)
    for msg in pubsub.listen():
        if msg["type"] == "message":
            handler(json.loads(msg["data"]))
