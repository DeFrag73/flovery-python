from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from core.config import get_settings

settings = get_settings()

client: AsyncIOMotorClient | None = None


async def connect_db() -> None:
    global client
    client = AsyncIOMotorClient(settings.MONGO_URL)
    # Ping to verify connection
    await client.admin.command("ping")


async def close_db() -> None:
    global client
    if client:
        client.close()


def get_database() -> AsyncIOMotorDatabase:
    if client is None:
        raise RuntimeError("Database client not initialized. Call connect_db() first.")
    return client[settings.MONGO_DB_NAME]