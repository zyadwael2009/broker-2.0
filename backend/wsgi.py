"""WSGI entry point. Used by gunicorn, PythonAnywhere, `flask run`, etc."""
from app import create_app

app = create_app()
