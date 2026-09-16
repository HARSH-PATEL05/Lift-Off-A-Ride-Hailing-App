from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.core.config import DATABASE_URL


# Validate database configuration
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not configured")


# Database engine
engine = create_engine(DATABASE_URL)


# Database session factory
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


# Base class for all database models
Base = declarative_base()


# Dependency for FastAPI routes
def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()