from fastapi import FastAPI
from sqlalchemy import text
from fastapi.middleware.cors import CORSMiddleware

from app.db.database import engine
from app.db.database import Base, engine


from app.db.models.user import User
from app.db.models.aadhar_document import Aadhaar
from app.db.models.driving_licence import DrivingLicence
from app.db.models.vehicle_rc import VehicleRC


from app.routes import auth, verification


Base.metadata.create_all(bind=engine)

app = FastAPI(title="LiftOff Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:8080",
        "http://127.0.0.1:8080",#http://localhost:8080/
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(verification.router)

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