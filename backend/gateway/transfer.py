from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import json
from pathlib import Path

router = APIRouter()

DATA_PATH = Path(__file__).resolve().parent.parent.parent / "data" / "accounts.json"

class TransferRequest(BaseModel):
    from_user: str
    to_user: str
    amount: int

@router.post("/transfer")
async def transfer_money(req: TransferRequest):
    if not DATA_PATH.exists():
        raise HTTPException(status_code=500, detail="계좌 데이터 없음")

    with open(DATA_PATH, "r+", encoding="utf-8") as f:
        data = json.load(f)

        from_acc = data.get(req.from_user)
        to_acc = data.get(req.to_user)

        if not from_acc or not to_acc:
            raise HTTPException(status_code=404, detail="계좌 정보 오류")

        if from_acc["balance"] < req.amount:
            raise HTTPException(status_code=400, detail="잔액 부족")

        from_acc["balance"] -= req.amount
        to_acc["balance"] += req.amount

        f.seek(0)
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.truncate()

    return {"status": "success", "from": req.from_user, "to": req.to_user, "amount": req.amount}
