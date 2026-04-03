from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

templates = Jinja2Templates(directory="templates")

router = APIRouter(tags=["UI"])


@router.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Render the public product catalog page."""
    return templates.TemplateResponse(
        request=request,
        name="index.html"
    )


@router.get("/catalog/{product_id}", response_class=HTMLResponse)
async def product_detail(request: Request, product_id: str):
    """Render the product detail page. JS fetches API data client-side."""
    return templates.TemplateResponse(
        request=request,
        name="product.html",
        context={"product_id": product_id}
    )


@router.get("/admin-panel", response_class=HTMLResponse)
async def admin_panel(request: Request):
    """Render the admin management dashboard."""
    return templates.TemplateResponse(
        request=request,
        name="admin.html"
    )