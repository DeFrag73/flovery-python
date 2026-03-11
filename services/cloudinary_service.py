import cloudinary
import cloudinary.uploader
from fastapi import UploadFile, HTTPException, status
from core.config import get_settings

settings = get_settings()

# Configure Cloudinary once at import time
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET,
    secure=True,
)

ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/gif", "image/webp"}
MAX_FILE_SIZE_MB = 10
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024


async def upload_images(files: list[UploadFile]) -> list[str]:
    """Upload multiple images to Cloudinary and return their secure URLs as webp."""
    if not files:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No files provided.",
        )

    urls: list[str] = []

    for file in files:
        # Validate content type
        if file.content_type not in ALLOWED_CONTENT_TYPES:
            raise HTTPException(
                status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                detail=f"File '{file.filename}' has unsupported type '{file.content_type}'. "
                       f"Allowed: {', '.join(ALLOWED_CONTENT_TYPES)}",
            )

        # Read and validate file size
        contents = await file.read()
        if len(contents) > MAX_FILE_SIZE_BYTES:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"File '{file.filename}' exceeds {MAX_FILE_SIZE_MB}MB limit.",
            )

        try:
            result = cloudinary.uploader.upload(
                contents,
                folder=settings.CLOUDINARY_FOLDER,
                format="webp",           # Convert output to webp
                quality="auto:good",     # Smart compression
                fetch_format="auto",
                resource_type="image",
            )
            urls.append(result["secure_url"])
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Cloudinary upload failed for '{file.filename}': {str(exc)}",
            )

    return urls


async def delete_image(public_id: str) -> None:
    """Delete a single image from Cloudinary by its public_id."""
    try:
        cloudinary.uploader.destroy(public_id)
    except Exception as exc:
        # Log but don't raise — image cleanup is best-effort
        print(f"[cloudinary_service] Warning: could not delete {public_id}: {exc}")