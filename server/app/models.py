from datetime import datetime, timezone

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Ingredient(db.Model):
    """Bahan makanan. Nama sama persis dengan nama kelas pada model YOLOv8."""

    __tablename__ = "ingredient"
    id = db.Column(db.Integer, primary_key=True)
    nama = db.Column(db.String(50), unique=True, nullable=False)


class Recipe(db.Model):
    __tablename__ = "recipe"
    id = db.Column(db.Integer, primary_key=True)
    nama = db.Column(db.String(100), unique=True, nullable=False)
    bumbu_dapur = db.Column(db.Text, nullable=False, default="")

    bahan = db.relationship("RecipeIngredient", back_populates="recipe",
                            cascade="all, delete-orphan",
                            order_by="RecipeIngredient.urutan")
    langkah = db.relationship("RecipeStep", back_populates="recipe",
                              cascade="all, delete-orphan", order_by="RecipeStep.urutan")


class RecipeIngredient(db.Model):
    """Tabel penghubung: bahan apa saja yang dibutuhkan sebuah resep."""

    __tablename__ = "recipe_ingredient"
    recipe_id = db.Column(db.Integer, db.ForeignKey("recipe.id", ondelete="CASCADE"),
                          primary_key=True)
    ingredient_id = db.Column(db.Integer, db.ForeignKey("ingredient.id"), primary_key=True)
    tipe = db.Column(db.String(10), nullable=False)  # 'utama' atau 'opsional'
    urutan = db.Column(db.Integer, nullable=False)   # urutan penulisan bahan dalam resep

    __table_args__ = (db.CheckConstraint("tipe IN ('utama', 'opsional')", name="ck_tipe"),)

    recipe = db.relationship("Recipe", back_populates="bahan")
    ingredient = db.relationship("Ingredient")


class RecipeStep(db.Model):
    __tablename__ = "recipe_step"
    id = db.Column(db.Integer, primary_key=True)
    recipe_id = db.Column(db.Integer, db.ForeignKey("recipe.id", ondelete="CASCADE"),
                          nullable=False)
    urutan = db.Column(db.Integer, nullable=False)
    teks = db.Column(db.Text, nullable=False)

    recipe = db.relationship("Recipe", back_populates="langkah")


class DetectionHistory(db.Model):
    """Riwayat hasil deteksi. Foto tidak disimpan, hanya daftar bahan."""

    __tablename__ = "detection_history"
    id = db.Column(db.Integer, primary_key=True)
    waktu = db.Column(db.DateTime, nullable=False,
                      default=lambda: datetime.now(timezone.utc))
    bahan = db.Column(db.Text, nullable=False)  # daftar bahan dipisah koma
    jumlah_objek = db.Column(db.Integer, nullable=False, default=0)
