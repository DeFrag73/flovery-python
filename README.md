# 🌸 Flower Catalog API

A mobile-first product showcase backend for flowers, soil, fertilizers, and accessories.
Built with **FastAPI**, **MongoDB (Motor)**, and **Cloudinary**.

---

## Project Structure

```
flower-catalog/
├── main.py                        # FastAPI app + lifespan
├── database.py                    # Motor client + DB dependency
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── core/
│   ├── config.py                  # Pydantic settings (reads .env)
│   └── auth.py                    # Admin token dependency
├── models/
│   └── product.py                 # Pydantic models
├── routers/
│   ├── products.py                # Public GET routes
│   └── admin.py                   # Protected CRUD + upload routes
└── services/
    └── cloudinary_service.py      # Cloudinary upload logic
```

---

## Quick Start (Docker)

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env with your Cloudinary credentials and a strong ADMIN_API_TOKEN
```

### 2. Build and start

```bash
docker compose up --build -d
```

### 3. Verify

```bash
curl http://localhost:8000/health
# → {"status":"ok","service":"flower-catalog-api"}
```

Interactive docs: **http://localhost:8000/docs**

### 4. Stop

```bash
docker compose down          # stop containers
docker compose down -v       # also delete MongoDB data volume
```

---

## API Reference

### Public Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/products` | List all products |
| GET | `/api/v1/products?category=flowers` | Filter by category |
| GET | `/api/v1/products/{id}` | Get single product |

### Admin Endpoints (require `X-Admin-Token` header)

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/admin/upload` | Upload images → returns URLs |
| POST | `/api/v1/admin/products` | Create product |
| PUT | `/api/v1/admin/products/{id}` | Update product |
| DELETE | `/api/v1/admin/products/{id}` | Delete product |

### Valid Categories
`flowers` · `soil` · `fertilizers` · `accessories`

---

## Example Usage

### Upload images

```bash
curl -X POST http://localhost:8000/api/v1/admin/upload \
  -H "X-Admin-Token: your_token_here" \
  -F "files=@rose.jpg" \
  -F "files=@rose2.jpg"
```

### Create a product

```bash
curl -X POST http://localhost:8000/api/v1/admin/products \
  -H "X-Admin-Token: your_token_here" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Red Rose",
    "description": "Classic romantic red rose",
    "care_notes": "Water twice a week. Full sun preferred.",
    "category": "flowers",
    "images": ["https://res.cloudinary.com/..."]
  }'
```

### List products

```bash
curl http://localhost:8000/api/v1/products?category=flowers
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `MONGO_URL` | ✅ | MongoDB connection string |
| `MONGO_DB_NAME` | ✅ | Database name (default: `flower_catalog`) |
| `CLOUDINARY_CLOUD_NAME` | ✅ | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | ✅ | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | ✅ | Cloudinary API secret |
| `CLOUDINARY_FOLDER` | — | Upload folder (default: `flower-catalog`) |
| `ADMIN_API_TOKEN` | ✅ | Secret token for admin routes |
| `CORS_ORIGINS` | — | Allowed origins (default: `["*"]`) |

---

## Local Development (without Docker)

```bash
python -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env            # fill in your values

uvicorn main:app --reload
```