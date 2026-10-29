import pytest

from app import create_app
from app.config import TestConfig
from app.models import db
from app.seed import seed


@pytest.fixture()
def client():
    app = create_app(TestConfig)
    with app.app_context():
        seed()
        yield app.test_client()
        db.session.remove()
        db.drop_all()
