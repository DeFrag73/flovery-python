from fastapi import APIRouter, Depends, HTTPException, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from bson import ObjectId
from bson.errors import InvalidId

from database import get_database
from models.product import Product, ProductListResponse

router = APIRouter(prefix="/products", tags=["Products (Public)"])


def _object_id_or_404(id: str) -> ObjectId:
    try:
        return ObjectId(id)
    except (InvalidId, Exception):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id '{id}' not found.",
        )


@router.get("", response_model=ProductListResponse, summary="List all products")
async def list_products(
    category: str | None = Query(None, description="Filter by category"),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Returns all products. Optionally filter by `?category=flowers|soil|fertilizers|accessories`.
    """
    query: dict = {}
    if category:
        query["category"] = category.lower()

    cursor = db["products"].find(query).sort("title", 1)
    docs = await cursor.to_list(length=1000)
    total = await db["products"].count_documents(query)

    return ProductListResponse(
        total=total,
        products=[Product(**doc) for doc in docs],
    )


@router.get("/{id}", response_model=Product, summary="Get a single product")
async def get_product(
    id: str,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Returns a single product by its MongoDB ObjectId."""
    oid = _object_id_or_404(id)
    doc = await db["products"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id '{id}' not found.",
        )
    return Product(**doc)