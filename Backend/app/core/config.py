from dotenv import load_dotenv
import os

load_dotenv()  # auto-discovers .env in the working directory

DATABASE_URL = os.getenv("DATABASE_URL")

class Settings:
    SUPABASE_URL = os.getenv("SUPABASE_URL")
    SUPABASE_KEY = os.getenv("SUPABASE_KEY")
    DATA_ENCRYPTION_KEY = os.getenv("DATA_ENCRYPTION_KEY")
    DEFAULT_ROUTE_MATCH_THRESHOLD = 50.0
    RIDE_EDIT_CUTOFF_MINUTES = 10

settings = Settings()