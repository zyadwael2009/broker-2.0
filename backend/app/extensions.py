"""Extension singletons. Kept in one place so anything can import them
without touching the app factory (avoids circular imports)."""
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
bcrypt = Bcrypt()
cors = CORS()

# Per-IP by default. Storage swapped to Redis in production via
# RATELIMIT_STORAGE_URI env var (see config.py). In-memory is fine for
# a single-process dev / small Gunicorn worker set.
limiter = Limiter(key_func=get_remote_address)
