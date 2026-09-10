import logging
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, declarative_base
from backend.app.config import settings

logger = logging.getLogger("ecoscrap.database")
logging.basicConfig(level=logging.INFO)

Base = declarative_base()

def get_engine():
    # Attempt connecting to PostgreSQL (try configured URL, admin pwd, and postgres pwd)
    urls_to_try = [
        settings.DATABASE_URL,
        f"postgresql://{settings.POSTGRES_USER}:admin@{settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}/{settings.POSTGRES_DB}",
        f"postgresql://{settings.POSTGRES_USER}:postgres@{settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}/{settings.POSTGRES_DB}",
    ]
    seen = set()
    candidate_urls = [u for u in urls_to_try if u and not (u in seen or seen.add(u))]

    for url in candidate_urls:
        try:
            pg_engine = create_engine(
                url,
                pool_pre_ping=True,
                connect_args={"connect_timeout": 3} if "postgresql" in url else {}
            )
            with pg_engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            logger.info(f"Connected to PostgreSQL database: {settings.POSTGRES_DB} at {settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}")
            return pg_engine
        except Exception:
            continue

    logger.warning(
        f"PostgreSQL connection to {settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}/{settings.POSTGRES_DB} unavailable. "
        f"Falling back to local SQLite database at {settings.SQLITE_FALLBACK_URL}"
    )
    sqlite_engine = create_engine(
        settings.SQLITE_FALLBACK_URL,
        connect_args={"check_same_thread": False}
    )
    return sqlite_engine

engine = get_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def check_db_health() -> dict:
    """
    Returns live health telemetry for the active database engine.
    """
    try:
        with engine.connect() as conn:
            if "postgresql" in engine.url.drivername:
                res = conn.execute(text("SELECT current_database(), current_user, version();"))
                row = res.fetchone()
                return {
                    "status": "connected",
                    "engine": "postgresql",
                    "database": row[0] if row else settings.POSTGRES_DB,
                    "user": row[1] if row else settings.POSTGRES_USER,
                    "server": f"{settings.POSTGRES_SERVER}:{settings.POSTGRES_PORT}",
                    "version": str(row[2]).split(",")[0] if row and len(row) > 2 else ""
                }
            else:
                return {
                    "status": "connected",
                    "engine": "sqlite",
                    "database": "sqlite_fallback",
                    "url": settings.SQLITE_FALLBACK_URL
                }
    except Exception as e:
        return {"status": "error", "error": str(e)}
