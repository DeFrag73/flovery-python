from pydantic import BaseModel, Field, field_validator
from pydantic.functional_validators import BeforeValidator
from typing import Annotated, Optional
from bson import ObjectId


# Custom type that converts ObjectId to string
PyObjectId = Annotated[str, BeforeValidator(str)]


class ProductBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200, description="Product title")
    description: str = Field(..., min_length=1, description="Product description")
    care_notes: Optional[str] = Field(None, description="Plant care instructions")
    category: str = Field(
        ...,
        description="Product category",
        examples=["flowers", "soil", "fertilizers", "accessories"],
    )
    images: list[str] = Field(default=[], description="List of Cloudinary image URLs")

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        allowed = {"flowers", "soil", "fertilizers", "accessories"}
        if v.lower() not in allowed:
            raise ValueError(f"Category must be one of: {', '.join(sorted(allowed))}")
        return v.lower()


class ProductCreate(ProductBase):
    pass


class ProductUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, min_length=1)
    care_notes: Optional[str] = None
    category: Optional[str] = None
    images: Optional[list[str]] = None

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        allowed = {"flowers", "soil", "fertilizers", "accessories"}
        if v.lower() not in allowed:
            raise ValueError(f"Category must be one of: {', '.join(sorted(allowed))}")
        return v.lower()


class Product(ProductBase):
    id: PyObjectId = Field(alias="_id")

    model_config = {
        "populate_by_name": True,
        "arbitrary_types_allowed": True,
    }


class ProductListResponse(BaseModel):
    total: int
    products: list[Product]


class UploadResponse(BaseModel):
    uploaded: int
    urls: list[str]


class MessageResponse(BaseModel):
    message: str