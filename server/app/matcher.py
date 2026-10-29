"""Pencocokan bahan dengan resep. Logika sama dengan versi web dan aplikasi Flutter."""


def norm(s: str) -> str:
    return s.strip().lower()


def recommend(ingredients, recipes, min_score=0.6, limit=30):
    """recipes: daftar dict {id, nama, utama:[...]}. Urutan hasil: skor desc,
    kekurangan asc, bahan dimiliki desc, nama asc."""
    have = {norm(i) for i in ingredients}
    out = []
    for r in recipes:
        ada = [b for b in r["utama"] if norm(b) in have]
        kurang = [b for b in r["utama"] if norm(b) not in have]
        if not ada:
            continue
        skor = len(ada) / len(r["utama"])
        if skor < min_score - 1e-9:
            continue
        out.append({"id": r["id"], "nama": r["nama"], "skor": round(skor, 4),
                    "siap": not kurang, "ada": ada, "kurang": kurang})
    out.sort(key=lambda x: (-x["skor"], len(x["kurang"]), -len(x["ada"]), x["nama"]))
    return out[:limit]
