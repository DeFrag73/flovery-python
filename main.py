from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from core.config import get_settings
from database import connect_db, close_db
from routers import products, admin
from routers import ui

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage startup and shutdown events."""
    print("⚡ Connecting to MongoDB...")
    await connect_db()
    print("✅ MongoDB connected.")
    yield
    print("🔌 Closing MongoDB connection...")
    await close_db()
    print("✅ MongoDB disconnected.")


app = FastAPI(
    title="Flower Catalog API",
    description=(
        "A mobile-first product showcase for flowers, soil, fertilizers, and accessories. "
        "Browse products publicly; manage them via authenticated admin routes."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── Static files (CSS, JS, images) ───────────────────────────────────────────
app.mount("/static", StaticFiles(directory="static"), name="static")

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
API_PREFIX = "/api/v1"

# UI routes (must be registered before API to avoid prefix conflicts)
app.include_router(ui.router)

# API routes
app.include_router(products.router, prefix=API_PREFIX)
app.include_router(admin.router, prefix=API_PREFIX)


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health_check():
    return {"status": "ok", "service": "flower-catalog-api"}
