from datetime import timezone

from flask import Blueprint, jsonify, request
from sqlalchemy.orm import selectinload

from . import matcher
from .models import DetectionHistory, Ingredient, Recipe, RecipeIngredient, db

api = Blueprint("api", __name__, url_prefix="/api")


def _clamp(v, lo, hi, default):
    try:
        return max(lo, min(hi, float(v)))
    except (TypeError, ValueError):
        return default


def _error(msg, code=400):
    return jsonify(error=msg), code


def _known_ingredients():
    return {i.nama.lower(): i.nama for i in Ingredient.query.all()}


def _utama(recipe):
    return [b.ingredient.nama for b in recipe.bahan if b.tipe == "utama"]


def _opsional(recipe):
    return [b.ingredient.nama for b in recipe.bahan if b.tipe == "opsional"]


@api.get("/health")
def health():
    return jsonify(status="ok", resep=Recipe.query.count(), bahan=Ingredient.query.count())


@api.get("/ingredients")
def ingredients():
    names = [i.nama for i in Ingredient.query.order_by(Ingredient.nama).all()]
    return jsonify(ingredients=names)


@api.get("/recipes")
def recipes():
    rows = Recipe.query.options(selectinload(Recipe.bahan).selectinload(RecipeIngredient.ingredient)) \
        .order_by(Recipe.nama).all()
    return jsonify(recipes=[{"id": r.id, "nama": r.nama, "utama": _utama(r)} for r in rows])


@api.get("/recipes/<int:recipe_id>")
def recipe_detail(recipe_id):
    r = db.session.get(Recipe, recipe_id)
    if r is None:
        return _error("Resep tidak ditemukan.", 404)
    return jsonify(id=r.id, nama=r.nama, utama=_utama(r), opsional=_opsional(r),
                   bumbu_dapur=r.bumbu_dapur, langkah=[s.teks for s in r.langkah])


@api.post("/recommend")
def recommend():
    body = request.get_json(silent=True) or {}
    wanted = body.get("ingredients")
    if not isinstance(wanted, list):
        return _error("Field 'ingredients' harus berupa daftar nama bahan.")
    known = _known_ingredients()
    unknown = [w for w in wanted if not isinstance(w, str) or w.strip().lower() not in known]
    if unknown:
        return _error(f"Bahan tidak dikenali: {unknown}", 422)
    min_score = _clamp(body.get("min_score"), 0.3, 1.0, 0.6)
    rows = Recipe.query.options(selectinload(Recipe.bahan).selectinload(RecipeIngredient.ingredient)).all()
    data = [{"id": r.id, "nama": r.nama, "utama": _utama(r)} for r in rows]
    return jsonify(recipes=matcher.recommend(wanted, data, min_score=min_score))


@api.post("/history")
def add_history():
    body = request.get_json(silent=True) or {}
    bahan = body.get("bahan")
    if not isinstance(bahan, list) or not all(isinstance(b, str) for b in bahan):
        return _error("Field 'bahan' harus berupa daftar nama bahan.")
    known = _known_ingredients()
    unknown = [b for b in bahan if b.strip().lower() not in known]
    if unknown:
        return _error(f"Bahan tidak dikenali: {unknown}", 422)
    jumlah = body.get("jumlah_objek", len(bahan))
    if not isinstance(jumlah, int) or isinstance(jumlah, bool) or not 0 <= jumlah <= 1000:
        return _error("Field 'jumlah_objek' harus bilangan bulat 0 sampai 1000.")
    row = DetectionHistory(bahan=",".join(known[b.strip().lower()] for b in bahan),
                           jumlah_objek=jumlah)
    db.session.add(row)
    db.session.commit()
    return jsonify(id=row.id), 201


@api.get("/history")
def list_history():
    limit = int(_clamp(request.args.get("limit"), 1, 100, 20))
    rows = DetectionHistory.query.order_by(DetectionHistory.id.desc()).limit(limit).all()
    return jsonify(history=[{
        "id": h.id,
        "waktu": h.waktu.replace(tzinfo=timezone.utc).isoformat(),  # disimpan dalam UTC
        "bahan": h.bahan.split(",") if h.bahan else [],
        "jumlah_objek": h.jumlah_objek,
    } for h in rows])
