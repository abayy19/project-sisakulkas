# SisaKulkas - Server dan Database

API (Flask) untuk data resep dan riwayat deteksi. Database: SQLite untuk pengembangan,
PostgreSQL untuk produksi (lewat SQLAlchemy).

## Menjalankan
```
cd server
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env               # opsional; tanpa .env dipakai SQLite lokal

flask --app wsgi seed              # isi data awal (aman dijalankan berulang)
flask --app wsgi run --port 5000   # server pengembangan
# atau, mode produksi:
gunicorn -b 0.0.0.0:5000 -w 2 wsgi:app
```
`DATABASE_URL` dibaca dari environment variable (contoh ada di `.env.example`).

## Endpoint
| Metode | Alamat | Fungsi |
|---|---|---|
| GET | /api/health | Cek server hidup, jumlah resep dan bahan |
| GET | /api/ingredients | Daftar bahan yang dikenali model |
| GET | /api/recipes | Daftar resep |
| GET | /api/recipes/{id} | Detail resep dan langkahnya |
| POST | /api/recommend | Body `{"ingredients": [...], "min_score": 0.6}` -> resep terurut |
| POST | /api/history | Body `{"bahan": [...], "jumlah_objek": 3}` -> simpan riwayat |
| GET | /api/history?limit=20 | Riwayat terbaru |

## Pengujian
```
pytest
```
Berisi 12 tes, termasuk perbandingan 80 kasus acak dengan implementasi acuan.

## Menambah resep
Edit `data/recipes.json` (nama bahan harus sama persis dengan nama kelas model di
`data/config.json`), lalu `flask --app wsgi seed`. Resep yang sudah ada tidak diubah;
gunakan `flask --app wsgi seed --reset` untuk mengisi ulang dari nol.

## PostgreSQL (produksi)
Pasang `psycopg[binary]`, lalu atur `DATABASE_URL=postgresql+psycopg://user:sandi@host:5432/sisakulkas`.
Catatan: koneksi PostgreSQL belum diuji pada tahap ini.
