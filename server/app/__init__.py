import click
from flask import Flask, jsonify

from .config import Config
from .models import db
from .routes import api
from .seed import seed as run_seed


def create_app(config=Config):
    app = Flask(__name__)
    app.config.from_object(config)
    app.json.sort_keys = False  # urutan kunci JSON sesuai penulisan
    db.init_app(app)
    app.register_blueprint(api)

    with app.app_context():
        db.create_all()  # membuat tabel jika belum ada

    @app.errorhandler(404)
    def not_found(_):
        return jsonify(error="Alamat tidak ditemukan."), 404

    @app.errorhandler(413)
    def too_large(_):
        return jsonify(error="Permintaan terlalu besar."), 413

    @app.cli.command("seed")
    @click.option("--reset", is_flag=True, help="Hapus data resep lalu isi ulang.")
    def seed_command(reset):
        """Isi database dengan data awal (bahan dan resep)."""
        hasil = run_seed(reset=reset)
        click.echo(f"Seed selesai: {hasil}")

    return app
