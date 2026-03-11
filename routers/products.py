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
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """
    Returns active products with pagination.
    Optionally filter by `?category=flowers|soil|fertilizers|accessories`.
    """
    query: dict = {"is_active": {"$ne": False}}  # backward-compatible: missing field = active
    if category:
        query["category"] = category.lower()

    total = await db["products"].count_documents(query)
    pages = max(1, -(-total // page_size))  # ceiling division

    skip = (page - 1) * page_size
    cursor = db["products"].find(query).sort("title", 1).skip(skip).limit(page_size)
    docs = await cursor.to_list(length=page_size)

    return ProductListResponse(
        total=total,
        page=page,
        page_size=page_size,
        pages=pages,
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