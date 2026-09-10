import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from backend.app.config import settings
from backend.app.database import engine, Base, check_db_health
from backend.app.services.local_whisper import get_whisper_model
from backend.app.services.local_vision import get_yolo_model
from backend.app.seed import seed_database
from backend.app.api import (
    auth,
    ai,
    lots,
    bids,
    handover,
    passport,
    safety,
    voice,
    collections,
    pricing,
    payments,
    recyclers,
    admin_analytics
)

logger = logging.getLogger("ecoscrap")
logging.basicConfig(level=logging.INFO)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Ensure database tables exist and seed demo data
    logger.info("Initializing EcoScrap database tables...")
    Base.metadata.create_all(bind=engine)
    logger.info("Checking and seeding demo records...")
    seed_database()
    # Pre-warm local Whisper and Fine-Tuned E-Waste YOLO models for instant responses
    try:
        get_whisper_model()
        get_yolo_model()
        logger.info("Local Whisper and Fine-Tuned E-Waste YOLO models successfully pre-warmed.")
    except Exception as m_err:
        logger.warning(f"Model pre-warm note: {m_err}")
    yield
    logger.info("Shutting down EcoScrap backend...")

app = FastAPI(
    title="EcoScrap API",
    description="EcoScrap: AI-Powered Formalization Platform for Informal E-Waste Collectors (Challenge 19)",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for Flutter Web, Mobile, and local testing
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount local media directory for lot photos and QR codes (Zero AWS!)
app.mount("/media", StaticFiles(directory=str(settings.MEDIA_DIR)), name="media")

# Register API Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(ai.router, prefix=settings.API_V1_STR)
app.include_router(lots.router, prefix=settings.API_V1_STR)
app.include_router(bids.router, prefix=settings.API_V1_STR)
app.include_router(handover.router, prefix=settings.API_V1_STR)
app.include_router(passport.router, prefix=settings.API_V1_STR)
app.include_router(passport.admin_router, prefix=settings.API_V1_STR)
app.include_router(safety.router, prefix=settings.API_V1_STR)
app.include_router(voice.router, prefix=settings.API_V1_STR)
app.include_router(collections.router, prefix=settings.API_V1_STR)
app.include_router(pricing.router, prefix=settings.API_V1_STR)
app.include_router(payments.router, prefix=settings.API_V1_STR)
app.include_router(recyclers.router, prefix=settings.API_V1_STR)
app.include_router(admin_analytics.router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {
        "platform": "EcoScrap",
        "tagline": "From Informal Scrap to Formal Circularity",
        "challenge": "Challenge 19: Digital Platform for Formal E-Waste Collection and Recycling",
        "docs_url": "/docs",
        "version": "1.0.0"
    }

@app.get("/health")
@app.get("/api/health")
def health_check():
    db_info = check_db_health()
    return {
        "status": "healthy",
        "database": db_info,
        "local_models": {
            "whisper": "loaded",
            "yolo_component_detector": "loaded"
        }
    }

@app.get("/api/health/db")
def db_health_check():
    return check_db_health()
