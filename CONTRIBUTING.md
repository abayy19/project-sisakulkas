# Panduan Kontribusi

## Branch
- `main`: kode stabil. **Tidak boleh di-push langsung**; hanya lewat pull request.
- `develop`: tempat integrasi fitur.
- `feature/<nama-fitur>`, `fix/<nama-perbaikan>`: dibuat dari `develop`.

## Alur
1. Ambil tugas dari papan **Projects** (GitHub Issues), pindahkan ke "In progress".
2. `git switch develop && git pull && git switch -c feature/<nama-fitur>`
3. Commit kecil dengan pesan jelas, format: `feat: ...`, `fix: ...`, `docs: ...`, `test: ...`, `chore: ...`
4. Push dan buka pull request ke `develop`. Isi templat PR.
5. Minimal **satu anggota lain** meninjau. CI harus hijau sebelum merge.
6. Rilis: PR dari `develop` ke `main` dibuat oleh Project Manager.

## Aturan
- Jangan commit rahasia (`.env`, kunci API, keystore). Gunakan `.env.example` sebagai contoh.
- Tambahkan atau perbarui tes untuk perubahan logika.
- Satu pull request, satu tujuan.
