import os


class Config:
    """Konfigurasi dasar. Nilai rahasia dibaca dari environment variable, bukan ditulis di kode."""

    SQLALCHEMY_DATABASE_URI = os.environ.get("DATABASE_URL", "sqlite:///sisakulkas.db")
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    MAX_CONTENT_LENGTH = 1 * 1024 * 1024  # 1 MB, API ini hanya menerima JSON kecil


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite://"  # database di memori
