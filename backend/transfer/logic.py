import uuid
from .db import load_accounts, save_accounts
from .models import Account

def create_account(name: str, balance: int) -> Account:
    acc = Account(id=str(uuid.uuid4()), name=name, balance=balance)
    accounts = load_accounts()
    accounts.append(acc)
    save_accounts(accounts)
    return acc

def get_account_by_name(name: str) -> Account | None:
    accounts = load_accounts()
    for acc in accounts:
        if acc.name == name:
            return acc
    return None
