from fastapi import FastAPI
from gateway.router import intent, transfer

app = FastAPI(
    title="MCP Gateway",
    description="음성 송금 시스템을 위한 Gateway API",
    version="1.0.0"
)

# 라우터 등록
app.include_router(intent.router, prefix="/api")
app.include_router(transfer.router, prefix="/api")

@app.get("/")
async def root():
    return {"msg": "MCP Gateway is running"}
