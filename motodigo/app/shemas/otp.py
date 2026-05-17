# app/schemas/otp.py
from pydantic import BaseModel


class OTPSend(BaseModel):
    phone: str  # Format international ex: +237600000000


class OTPVerify(BaseModel):
    phone: str
    code: str
