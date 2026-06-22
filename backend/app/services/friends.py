from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User, UserBlock, FriendRequest, Friendship


async def get_user_by_id(db: AsyncSession, user_id: str) -> User | None:
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    result = await db.execute(
        select(User).where(User.email.ilike(email))
    )
    return result.scalar_one_or_none()


async def is_blocked_either_way(db: AsyncSession, user_a: str, user_b: str) -> bool:
    result = await db.execute(
        select(UserBlock).where(
            or_(
                (UserBlock.blocker_id == user_a) & (UserBlock.blocked_id == user_b),
                (UserBlock.blocker_id == user_b) & (UserBlock.blocked_id == user_a),
            )
        )
    )
    return result.scalar_one_or_none() is not None


async def are_already_friends(db: AsyncSession, user_a: str, user_b: str) -> bool:
    result = await db.execute(
        select(Friendship).where(
            Friendship.user_id == user_a,
            Friendship.friend_id == user_b,
        )
    )
    return result.scalar_one_or_none() is not None


async def send_friend_request(
    db: AsyncSession,
    current_user_id: str,
    target_email: str,
) -> FriendRequest:
    target = await get_user_by_email(db, target_email)
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")

    target_user_id = target.id

    if current_user_id == target_user_id:
        raise HTTPException(status_code=400, detail="Cannot send a friend request to yourself")

    if await is_blocked_either_way(db, current_user_id, target_user_id):
        raise HTTPException(status_code=403, detail="Friend request not allowed")

    if await are_already_friends(db, current_user_id, target_user_id):
        raise HTTPException(
            status_code=400,
            detail="DEBUG: Friendship row still exists"
        )

    existing = await db.execute(
        select(FriendRequest).where(
            or_(
                (FriendRequest.sender_id == current_user_id) & (FriendRequest.receiver_id == target_user_id),
                (FriendRequest.sender_id == target_user_id) & (FriendRequest.receiver_id == current_user_id),
            ),
            FriendRequest.status.in_(["pending", "accepted"]),
        )
    )
    existing_request = existing.scalar_one_or_none()

    if existing_request:
        if existing_request.status == "pending":
            raise HTTPException(status_code=400, detail="A pending friend request already exists")
        if existing_request.status == "accepted":
            raise HTTPException(
                status_code=400,
                detail="DEBUG: accepted FriendRequest row still exists"
            )

    friend_request = FriendRequest(
        sender_id=current_user_id,
        receiver_id=target_user_id,
        status="pending",
    )
    db.add(friend_request)
    await db.commit()
    await db.refresh(friend_request)
    return friend_request


async def list_incoming_requests(
    db: AsyncSession,
    current_user_id: str,
) -> list[dict]:
    result = await db.execute(
        select(FriendRequest, User)
        .join(User, User.id == FriendRequest.sender_id)
        .where(
            FriendRequest.receiver_id == current_user_id,
            FriendRequest.status == "pending",
        )
        .order_by(FriendRequest.created_at.desc())
    )
    rows = result.all()

    return [
        {
            "id": req.id,
            "sender_id": req.sender_id,
            "receiver_id": req.receiver_id,
            "status": req.status,
            "sender_name": sender.name,
            "sender_email": sender.email,
            "receiver_name": None,
            "receiver_email": None,
            "created_at": req.created_at,
            "responded_at": req.responded_at,
        }
        for req, sender in rows
    ]


async def list_outgoing_requests(
    db: AsyncSession,
    current_user_id: str,
) -> list[dict]:
    result = await db.execute(
        select(FriendRequest, User)
        .join(User, User.id == FriendRequest.receiver_id)
        .where(
            FriendRequest.sender_id == current_user_id,
            FriendRequest.status == "pending",
        )
        .order_by(FriendRequest.created_at.desc())
    )
    rows = result.all()

    return [
        {
            "id": req.id,
            "sender_id": req.sender_id,
            "receiver_id": req.receiver_id,
            "status": req.status,
            "sender_name": None,
            "sender_email": None,
            "receiver_name": receiver.name,
            "receiver_email": receiver.email,
            "created_at": req.created_at,
            "responded_at": req.responded_at,
        }
        for req, receiver in rows
    ]


async def accept_friend_request(
    db: AsyncSession,
    current_user_id: str,
    request_id: str,
) -> FriendRequest:
    result = await db.execute(
        select(FriendRequest).where(FriendRequest.id == request_id)
    )
    req = result.scalar_one_or_none()

    if not req:
        raise HTTPException(status_code=404, detail="Friend request not found")

    if req.receiver_id != current_user_id:
        raise HTTPException(status_code=403, detail="You cannot accept this friend request")

    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Friend request is not pending")

    if await is_blocked_either_way(db, req.sender_id, req.receiver_id):
        raise HTTPException(status_code=403, detail="Friend request cannot be accepted")

    req.status = "accepted"
    req.responded_at = datetime.now(timezone.utc)

    if not await are_already_friends(db, req.sender_id, req.receiver_id):
        db.add(Friendship(user_id=req.sender_id, friend_id=req.receiver_id))
        db.add(Friendship(user_id=req.receiver_id, friend_id=req.sender_id))

    await db.commit()
    await db.refresh(req)
    return req


async def decline_friend_request(
    db: AsyncSession,
    current_user_id: str,
    request_id: str,
) -> FriendRequest:
    result = await db.execute(
        select(FriendRequest).where(FriendRequest.id == request_id)
    )
    req = result.scalar_one_or_none()

    if not req:
        raise HTTPException(status_code=404, detail="Friend request not found")

    if req.receiver_id != current_user_id:
        raise HTTPException(status_code=403, detail="You cannot decline this friend request")

    if req.status != "pending":
        raise HTTPException(status_code=400, detail="Friend request is not pending")

    req.status = "declined"
    req.responded_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(req)
    return req


async def list_friends(
    db: AsyncSession,
    current_user_id: str,
) -> list[dict]:
    result = await db.execute(
        select(Friendship, User)
        .join(User, User.id == Friendship.friend_id)
        .where(Friendship.user_id == current_user_id)
        .order_by(User.name.asc(), User.email.asc())
    )
    rows = result.all()

    return [
        {
            "id": user.id,
            "name": user.name,
            "email": user.email,
        }
        for friendship, user in rows
    ]


async def friends_count(
    db: AsyncSession,
    current_user_id: str,
) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(Friendship)
        .where(Friendship.user_id == current_user_id)
    )
    return result.scalar_one()


async def unfriend_user(
    db: AsyncSession,
    current_user_id: str,
    target_user_id: str,
) -> None:
    result = await db.execute(
        select(Friendship).where(
            or_(
                (Friendship.user_id == current_user_id) & (Friendship.friend_id == target_user_id),
                (Friendship.user_id == target_user_id) & (Friendship.friend_id == current_user_id),
            )
        )
    )
    friendships = result.scalars().all()

    if not friendships:
        raise HTTPException(status_code=404, detail="Friendship not found")

    for friendship in friendships:
        await db.delete(friendship)

    # delete old accepted/pending/declined friend request between these users
    requests = await db.execute(
        select(FriendRequest).where(
            or_(
                (FriendRequest.sender_id == current_user_id) & (FriendRequest.receiver_id == target_user_id),
                (FriendRequest.sender_id == target_user_id) & (FriendRequest.receiver_id == current_user_id),
            )
        )
    )

    for req in requests.scalars().all():
        await db.delete(req)

    await db.commit()


async def block_user(
    db: AsyncSession,
    current_user_id: str,
    target_email: str,
) -> UserBlock:
    target = await get_user_by_email(db, target_email)
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")

    target_user_id = target.id

    if current_user_id == target_user_id:
        raise HTTPException(status_code=400, detail="Cannot block yourself")

    existing = await db.execute(
        select(UserBlock).where(
            UserBlock.blocker_id == current_user_id,
            UserBlock.blocked_id == target_user_id,
        )
    )
    block = existing.scalar_one_or_none()
    if block:
        raise HTTPException(status_code=400, detail="User already blocked")

    friendships = await db.execute(
        select(Friendship).where(
            or_(
                (Friendship.user_id == current_user_id) & (Friendship.friend_id == target_user_id),
                (Friendship.user_id == target_user_id) & (Friendship.friend_id == current_user_id),
            )
        )
    )
    for friendship in friendships.scalars().all():
        await db.delete(friendship)

    requests = await db.execute(
        select(FriendRequest).where(
            or_(
                (FriendRequest.sender_id == current_user_id) & (FriendRequest.receiver_id == target_user_id),
                (FriendRequest.sender_id == target_user_id) & (FriendRequest.receiver_id == current_user_id),
            )
        )
    )
    for req in requests.scalars().all():
        await db.delete(req)

    block = UserBlock(
        blocker_id=current_user_id,
        blocked_id=target_user_id,
    )
    db.add(block)
    await db.commit()
    await db.refresh(block)
    return block