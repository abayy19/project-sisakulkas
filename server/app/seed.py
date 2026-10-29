"""Mengisi database dengan data awal dari data/recipes.json dan data/config.json."""
import json
from pathlib import Path

from .models import Ingredient, Recipe, RecipeIngredient, RecipeStep, db

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
IGNORED = {"image_9"}  # kelas tidak bermakna dari dataset


def seed(reset: bool = False) -> dict:
    """Idempoten: aman dijalankan berulang kali. reset=True menghapus data resep lebih dulu."""
    if reset:
        RecipeStep.query.delete()
        RecipeIngredient.query.delete()
        Recipe.query.delete()
        Ingredient.query.delete()
        db.session.commit()

    cfg = json.loads((DATA_DIR / "config.json").read_text(encoding="utf-8"))
    recipes = json.loads((DATA_DIR / "recipes.json").read_text(encoding="utf-8"))

    # 1. Bahan: semua kelas model (kecuali yang diabaikan)
    ing = {i.nama.lower(): i for i in Ingredient.query.all()}
    for nama in cfg["names"]:
        if nama.lower() in IGNORED or nama.lower() in ing:
            continue
        obj = Ingredient(nama=nama)
        db.session.add(obj)
        ing[nama.lower()] = obj
    db.session.flush()

    # 2. Resep
    dibuat = 0
    for r in recipes:
        if Recipe.query.filter_by(nama=r["nama"]).first():
            continue
        rec = Recipe(nama=r["nama"], bumbu_dapur=r.get("pantry", ""))
        urutan = 0
        for tipe in ("utama", "opsional"):
            for b in r.get(tipe, []):
                if b.lower() not in ing:
                    raise ValueError(f"Bahan '{b}' pada resep '{r['nama']}' bukan kelas model.")
                urutan += 1
                rec.bahan.append(RecipeIngredient(ingredient=ing[b.lower()], tipe=tipe,
                                                  urutan=urutan))
        for n, teks in enumerate(r["langkah"], start=1):
            rec.langkah.append(RecipeStep(urutan=n, teks=teks))
        db.session.add(rec)
        dibuat += 1
    db.session.commit()
    return {
        "bahan": Ingredient.query.count(),
        "resep": Recipe.query.count(),
        "resep_baru": dibuat,
        "langkah": RecipeStep.query.count(),
    }
