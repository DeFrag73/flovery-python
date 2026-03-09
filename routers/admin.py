
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase
from bson import ObjectId
from bson.errors import InvalidId

from database import get_database
from models.product import (
    Product,
    ProductCreate,
    ProductUpdate,
    ProductListResponse,
    MessageResponse,
    UploadResponse,
)
from core.auth import require_admin_token
from services.cloudinary_service import upload_images

router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
    dependencies=[Depends(require_admin_token)],
)


def _object_id_or_404(id: str) -> ObjectId:
    try:
        return ObjectId(id)
    except (InvalidId, Exception):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id '{id}' not found.",
        )


# ── Image Upload ──────────────────────────────────────────────────────────────

@router.post(
    "/upload",
    response_model=UploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload images to Cloudinary",
)
async def upload_product_images(
    files: list[UploadFile] = File(..., description="One or more image files"),
):
    """
    Accepts multiple image files via multipart/form-data.
    Uploads them to Cloudinary (converted to webp) and returns the secure URLs.
    """
    urls = await upload_images(files)
    return UploadResponse(uploaded=len(urls), urls=urls)


# ── Admin Product List (includes inactive) ────────────────────────────────────

@router.get(
    "/products",
    response_model=ProductListResponse,
    summary="List all products (including inactive)",
)
async def admin_list_products(
    page: int = Query(1, ge=1),
    page_size: int = Query(50, ge=1, le=200),
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Returns ALL products for admin management, including inactive ones."""
    query: dict = {}
    total = await db["products"].count_documents(query)
    pages = max(1, -(-total // page_size))
    skip = (page - 1) * page_size
    cursor = db["products"].find(query).sort("title", 1).skip(skip).limit(page_size)
    docs = await cursor.to_list(length=page_size)
    return ProductListResponse(
        total=total, page=page, page_size=page_size, pages=pages,
        products=[Product(**doc) for doc in docs],
    )


# ── Product CRUD ──────────────────────────────────────────────────────────────

@router.post(
    "/products",
    response_model=Product,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new product",
)
async def create_product(
    payload: ProductCreate,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    doc = payload.model_dump()
    result = await db["products"].insert_one(doc)
    created = await db["products"].find_one({"_id": result.inserted_id})
    return Product(**created)


@router.put(
    "/products/{id}",
    response_model=Product,
    summary="Update a product",
)
async def update_product(
    id: str,
    payload: ProductUpdate,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    oid = _object_id_or_404(id)
    update_data = payload.model_dump(exclude_unset=True)
    if not update_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No fields provided for update.",
        )
    result = await db["products"].update_one({"_id": oid}, {"$set": update_data})
    if result.matched_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id '{id}' not found.",
        )
    updated = await db["products"].find_one({"_id": oid})
    return Product(**updated)


@router.patch(
    "/products/{id}/toggle-active",
    response_model=Product,
    summary="Toggle product active/inactive",
)
async def toggle_product_active(
    id: str,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    """Toggles the `is_active` field of a product."""
    oid = _object_id_or_404(id)
    doc = await db["products"].find_one({"_id": oid})
    if not doc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id '{id}' not found.",
        )
    new_status = not doc.get("is_active", True)
    await db["products"].update_one({"_id": oid}, {"$set": {"is_active": new_status}})
    updated = await db["products"].find_one({"_id": oid})
    return Product(**updated)


@router.delete(
    "/products/{id}",
    response_model=MessageResponse,
    summary="Delete a product",
)
async def delete_product(
    id: str,
    db: AsyncIOMotorDatabase = Depends(get_database),
):
    oid = _object_id_or_404(id)
    result = await db["products"].delete_one({"_id": oid})
    if result.deleted_count == 0:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product with id '{id}' not found.",
        )
    return MessageResponse(message=f"Product '{id}' deleted successfully.")