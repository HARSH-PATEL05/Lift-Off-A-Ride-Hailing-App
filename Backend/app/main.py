from fastapi import FastAPI
from sqlalchemy import text

from app.db.database import engine

app = FastAPI(title="LiftOff Backend")


@app.get("/")
def home():
    return {
        "message": "LiftOff Backend Running"
    }


@app.get("/health/db")
def check_database():

    with engine.connect() as connection:

        result = connection.execute(
            text("SELECT version();")
        )

        version = result.scalar()

    return {
        "status": "Connected",
        "database": version
    }