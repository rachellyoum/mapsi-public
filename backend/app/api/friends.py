from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_db_user
from app.db.deps import get_db
from app.db.models import User
from app.schemas.friends import (
    FriendRequestCreate,
    BlockRequest,
    FriendRequestOut,
    FriendUserOut,
    FriendsCountOut,
)
from app.services.friends import (
    send_friend_request,
    list_incoming_requests,
    list_outgoing_requests,
    accept_friend_request,
    decline_friend_request,
    list_friends,
    friends_count,
    unfriend_user,
    block_user,
)

router = APIRouter(prefix="/friends", tags=["friends"])


@router.post("/request")
async def post_friend_request(
    payload: FriendRequestCreate,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    req = await send_friend_request(db, user.id, payload.email)
    return {"id": req.id, "email": payload.email, "status": req.status}


@router.get("/requests/incoming", response_model=list[FriendRequestOut])
async def get_incoming_requests(
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_incoming_requests(db, user.id)


@router.get("/requests/outgoing", response_model=list[FriendRequestOut])
async def get_outgoing_requests(
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_outgoing_requests(db, user.id)


@router.post("/request/{request_id}/accept")
async def post_accept_request(
    request_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    req = await accept_friend_request(db, user.id, request_id)
    return {"id": req.id, "status": req.status}


@router.post("/request/{request_id}/decline")
async def post_decline_request(
    request_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    req = await decline_friend_request(db, user.id, request_id)
    return {"id": req.id, "status": req.status}


@router.get("", response_model=list[FriendUserOut])
async def get_friends(
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    return await list_friends(db, user.id)


@router.get("/count", response_model=FriendsCountOut)
async def get_friends_count(
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    count = await friends_count(db, user.id)
    return {"count": count}


@router.delete("/{friend_user_id}", status_code=204)
async def delete_friend(
    friend_user_id: str,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    await unfriend_user(db, user.id, friend_user_id)
    return Response(status_code=204)


@router.post("/block")
async def post_block(
    payload: BlockRequest,
    user: User = Depends(get_current_db_user),
    db: AsyncSession = Depends(get_db),
):
    block = await block_user(db, user.id, payload.email)
    return {"id": block.id, "email": payload.email}