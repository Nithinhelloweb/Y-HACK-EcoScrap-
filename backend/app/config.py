import os
from pathlib import Path
from pydantic_settings import BaseSettings

BASE_DIR = Path(__file__).resolve().parent.parent

class Settings(BaseSettings):
    PROJECT_NAME: str = "EcoScrap"
    API_V1_STR: str = "/api"
    SECRET_KEY: str = "ecoscrap-super-secret-key-2026"
    
    # Database configuration (Postgres by default with automatic local fallback)
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "admin"
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_PORT: str = "5432"
    POSTGRES_DB: str = "ecoscrap"
    
    DATABASE_URL: str = ""
    
    def model_post_init(self, __context):
        if not self.DATABASE_URL:
            self.DATABASE_URL = f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
    # Local fallback SQLite path if PostgreSQL is offline
    SQLITE_FALLBACK_URL: str = f"sqlite:///{BASE_DIR}/ecoscrap.db"
    
    # Media directories for photos and QR codes
    MEDIA_DIR: Path = BASE_DIR / "media"
    PHOTOS_DIR: Path = BASE_DIR / "media" / "lots"
    QR_DIR: Path = BASE_DIR / "media" / "qr"

    model_config = {
        "env_file": [str(BASE_DIR / ".env"), str(BASE_DIR.parent / ".env"), ".env"],
        "extra": "ignore",
        "case_sensitive": True
    }

settings = Settings()

# Ensure media folders exist
settings.MEDIA_DIR.mkdir(parents=True, exist_ok=True)
settings.PHOTOS_DIR.mkdir(parents=True, exist_ok=True)
settings.QR_DIR.mkdir(parents=True, exist_ok=True)
