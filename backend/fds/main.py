# backend/fds/main.py
import grpc
from concurrent import futures
from proto import intent_pb2, intent_pb2_grpc

class FDSService(intent_pb2_grpc.FDSServicer):
    def CheckTransaction(self, request, context):
        # rule-based 판단
        is_fraud = request.amount > 1000000
        return intent_pb2.FDSResponse(is_fraud=is_fraud, reason="Too much")

server = grpc.server(futures.ThreadPoolExecutor(max_workers=5))
intent_pb2_grpc.add_FDSServicer_to_server(FDSService(), server)
server.add_insecure_port("[::]:7003")
server.start()
