# backend/llm/send_to_fds.py
import grpc
from proto import intent_pb2, intent_pb2_grpc

def call_fds(user_id, amount, recipient):
    channel = grpc.insecure_channel("fds:7003")
    stub = intent_pb2_grpc.FDSStub(channel)
    request = intent_pb2.TransactionRequest(user_id=user_id, amount=amount, recipient=recipient)
    return stub.CheckTransaction(request)
