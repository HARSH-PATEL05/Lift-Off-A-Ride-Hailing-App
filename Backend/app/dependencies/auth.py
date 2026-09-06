from fastapi import Header, HTTPException, status
from supabase import create_client, Client

from app.core.config import settings


# Supabase client
supabase: Client = create_client(
    settings.SUPABASE_URL,
    settings.SUPABASE_KEY,
)


async def get_current_user(
    authorization: str | None = Header(default=None),
):
    """
    Extract the Supabase JWT from the Authorization header
    and verify the authenticated user with Supabase.
    """

    print("\n========== JWT AUTHENTICATION STARTED ==========")

    # Check Authorization header
    if authorization is None:
        print("❌ Authorization header missing")

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header missing",
        )

    # Expected format:
    # Authorization: Bearer <JWT>
    if not authorization.startswith("Bearer "):
        print("❌ Invalid Authorization header format")

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format",
        )

    # Extract JWT
    token = authorization.replace("Bearer ", "", 1)

    if not token:
        print("❌ JWT token missing")

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="JWT token missing",
        )

    print("✅ JWT received")
    print(f"JWT length: {len(token)}")

    try:
        # Verify token with Supabase
        print("\n🔍 Verifying JWT with Supabase...")

        response = supabase.auth.get_user(token)

        user = response.user

        if user is None:
            print("❌ Supabase returned no user")

            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired JWT",
            )

        # ─── TEMPORARY DEBUG OUTPUT ───

        print("\n========== VERIFIED SUPABASE USER ==========")

        print(f"User ID: {user.id}")
        print(f"Email: {user.email}")
        print(f"Phone: {user.phone}")

        print("\n---------- USER METADATA ----------")
        print(user.user_metadata)

        print("\n---------- APP METADATA ----------")
        print(user.app_metadata)

        print("\n---------- USER DETAILS ----------")
        print(user)

        print("\n===================================")

        # ─── TEMPORARY DEBUG OUTPUT END ───

        return user

    except HTTPException:
        raise

    except Exception as e:
        print("\n❌ JWT VERIFICATION ERROR")
        print(str(e))

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
        )