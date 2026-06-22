from datetime import datetime
from pydantic import BaseModel, EmailStr


class FriendRequestCreate(BaseModel):
    email: EmailStr


class BlockRequest(BaseModel):
    email: EmailStr


class FriendUserOut(BaseModel):
    id: str
    name: str | None = None
    email: str | None = None

    model_config = {"from_attributes": True}


class FriendRequestOut(BaseModel):
    id: str
    sender_id: str
    receiver_id: str
    status: str
    sender_name: str | None = None
    sender_email: str | None = None
    receiver_name: str | None = None
    receiver_email: str | None = None
    created_at: datetime
    responded_at: datetime | None = None


class FriendsCountOut(BaseModel):
    count: int