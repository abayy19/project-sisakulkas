# SisaKulkas

Aplikasi yang mendeteksi bahan makanan dari foto (YOLOv8) lalu merekomendasikan masakan Indonesia
dari bahan yang tersedia.

Proyek kelompok mata kuliah Proyek Perangkat Lunak. Dosen: Anggun Fergina, M.Kom.

## Struktur repository
| Folder | Isi | Bahasa |
|---|---|---|
| `app_flutter/` | Aplikasi mobile (deteksi di perangkat dengan ONNX Runtime) | Dart, Flutter |
| `server/` | API resep dan riwayat, database | Python, Flask, SQLAlchemy |
| `ml/` | Notebook training dan ekspor model (Google Colab) | Python, Ultralytics |
| `docs/` | Dokumen tugas dan laporan | PDF |

Panduan menjalankan ada di README masing-masing folder.

## Tim
| Nama | Peran |
|---|---|
| Pirni | Project Manager (repository, jadwal, koordinasi) |
| Nazwa Azzahra | Data Engineer (dataset, database, server) |
| M. Denindra Pratama | ML Engineer (training, ekspor ONNX) |
| Shelva Meriana N | Developer aplikasi Flutter |
| M. Rizky Akbar | QA dan Dokumentasi |

## Cara berkontribusi
Lihat [CONTRIBUTING.md](CONTRIBUTING.md).
