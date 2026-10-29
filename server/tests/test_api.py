import json
from pathlib import Path

from app.models import DetectionHistory, Ingredient, Recipe, RecipeStep, db
from app.seed import seed

PARITY = json.loads((Path(__file__).parent / "parity.json").read_text(encoding="utf-8"))


def test_health(client):
    r = client.get("/api/health")
    assert r.status_code == 200
    assert r.json == {"status": "ok", "resep": 26, "bahan": 24}


def test_seed_awal_sesuai_data(client):
    assert Ingredient.query.count() == 24          # 25 kelas model dikurangi Image_9
    assert Recipe.query.count() == 26
    assert RecipeStep.query.count() > 26 * 2


def test_seed_idempoten(client):
    hasil = seed()
    assert hasil["resep_baru"] == 0
    assert Recipe.query.count() == 26


def test_ingredients_tidak_memuat_kelas_abaian(client):
    names = client.get("/api/ingredients").json["ingredients"]
    assert "Telur" in names and "Image_9" not in names and len(names) == 24


def test_daftar_dan_detail_resep(client):
    daftar = client.get("/api/recipes").json["recipes"]
    assert len(daftar) == 26
    detail = client.get(f"/api/recipes/{daftar[0]['id']}").json
    assert detail["langkah"] and "bumbu_dapur" in detail
    assert client.get("/api/recipes/99999").status_code == 404


def test_rekomendasi_dasar(client):
    r = client.post("/api/recommend", json={"ingredients": ["Telur", "Bawang Merah", "Cabe"]})
    assert r.status_code == 200
    first = r.json["recipes"][0]
    assert first["nama"] == "Telur Dadar" and first["siap"] is True


def test_rekomendasi_validasi(client):
    assert client.post("/api/recommend", json={"ingredients": "Telur"}).status_code == 400
    r = client.post("/api/recommend", json={"ingredients": ["Naga"]})
    assert r.status_code == 422 and "Naga" in r.json["error"]
    assert client.post("/api/recommend", data="bukan json").status_code == 400


def test_rekomendasi_nama_tidak_peka_huruf_besar(client):
    r = client.post("/api/recommend", json={"ingredients": ["telur", "BAWANG MERAH"]})
    assert r.status_code == 200 and r.json["recipes"]


def test_rekomendasi_sama_dengan_implementasi_acuan(client):
    """80 kasus acak: urutan, skor, dan bahan kurang harus sama dengan implementasi Python acuan."""
    for case in PARITY:
        r = client.post("/api/recommend",
                        json={"ingredients": case["ingredients"], "min_score": case["min_score"]})
        got = [(x["nama"], x["skor"], x["kurang"]) for x in r.json["recipes"]]
        exp = [(x["nama"], round(x["skor"], 4), x["kurang"]) for x in case["expected"]]
        assert got == exp, case["ingredients"]


def test_riwayat(client):
    r = client.post("/api/history", json={"bahan": ["telur", "Cabe"], "jumlah_objek": 3})
    assert r.status_code == 201
    rows = client.get("/api/history").json["history"]
    assert rows[0]["bahan"] == ["Telur", "Cabe"] and rows[0]["jumlah_objek"] == 3
    assert DetectionHistory.query.count() == 1


def test_riwayat_validasi(client):
    assert client.post("/api/history", json={"bahan": "Telur"}).status_code == 400
    assert client.post("/api/history", json={"bahan": ["Naga"]}).status_code == 422
    assert client.post("/api/history", json={"bahan": [], "jumlah_objek": -1}).status_code == 400
    assert client.post("/api/history", json={"bahan": [], "jumlah_objek": True}).status_code == 400


def test_alamat_tidak_ada(client):
    r = client.get("/api/tidak-ada")
    assert r.status_code == 404 and "error" in r.json
