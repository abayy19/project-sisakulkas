# SisaKulkas (Flutter)

Aplikasi Android/iOS yang mendeteksi bahan makanan dari foto (YOLOv8, dijalankan di perangkat
dengan ONNX Runtime) lalu merekomendasikan masakan Indonesia. Semua proses ada di dalam aplikasi:
bisa dipakai tanpa internet dan foto tidak dikirim ke server.

## Isi folder ini
Folder ini **belum** berisi `android/` dan `ios/` (dibuat otomatis oleh Flutter). Isinya:

- `lib/` kode aplikasi (`core/` logika murni, `services/` pemanggil model, `ui/` tampilan)
- `assets/models/best.onnx` model, `assets/data/config.json` ukuran input dan nama kelas, `assets/data/recipes.json` resep
- `tool/selfcheck.dart` uji mandiri logika inti, `test/widget_test.dart` uji untuk `flutter test`

Workflow GitHub untuk build APK ada di `.github/workflows/build-apk.yml` di root repository.

## 1. Pasang alat
1. Pasang Flutter SDK dan Android Studio (Android SDK): https://docs.flutter.dev/get-started/install
2. Jalankan `flutter doctor` sampai semua bagian Android berstatus centang.

## 2. Buat folder platform (android/ dan ios/)
Pastikan semua file sudah di-commit ke Git terlebih dahulu, lalu dari folder `app_flutter`:
```
flutter create --org id.sisakulkas --project-name sisakulkas --platforms=android,ios .
flutter pub get
```
Jika ada file kita yang tertimpa (misalnya `lib/main.dart`), kembalikan dengan
`git checkout -- lib test pubspec.yaml`, lalu jalankan `flutter pub get` lagi.

## 3. Atur minSdk menjadi 24 (wajib)
Paket `onnxruntime_plus` membutuhkan Android API 24 ke atas. Buka
`android/app/build.gradle.kts` (atau `build.gradle` pada proyek lama) dan ubah baris minSdk:
```
minSdk = 24            // di build.gradle.kts
minSdkVersion 24       // di build.gradle
```
Jika lupa, build akan gagal dengan pesan bahwa minSdkVersion lebih kecil dari yang dibutuhkan library.

## 4. Jalankan
Sambungkan HP Android (aktifkan Opsi Pengembang dan Debugging USB), lalu:
```
flutter run
```
Catatan: pustaka native ONNX Runtime pada paket ini tersedia untuk arsitektur **arm32/arm64**.
Emulator Android berbasis x86 **tidak didukung**. Gunakan HP asli atau emulator ARM.

## 5. Buat APK
```
flutter build apk --release
```
Hasil: `build/app/outputs/flutter-apk/app-release.apk`. Tambahkan `--split-per-abi` untuk APK yang lebih kecil
(pilih `app-arm64-v8a-release.apk` untuk HP modern).

### Atau lewat GitHub Actions
Commit folder `android/` yang dihasilkan langkah 2 ke GitHub, buka tab Actions, jalankan **Build APK**,
lalu unduh APK dari bagian Artifacts.

## iOS (opsional, butuh Mac)
Tambahkan ke `ios/Runner/Info.plist`:
```
<key>NSCameraUsageDescription</key><string>Untuk memotret bahan makanan</string>
<key>NSPhotoLibraryUsageDescription</key><string>Untuk memilih foto bahan makanan</string>
```

## Pengujian
- `dart tool/selfcheck.dart` menguji pencocokan resep (dibandingkan dengan implementasi Python pada 80 kasus acak),
  letterbox, decode YOLO, dan NMS. Tidak butuh perangkat.
- `flutter test` menjalankan uji serupa lewat framework Flutter.

## Memperbarui
- **Model baru:** timpa `assets/models/best.onnx` dan `assets/data/config.json` (keduanya dihasilkan notebook training).
  Urutan nama kelas di `config.json` harus sama dengan urutan di model.
- **Resep:** edit `assets/data/recipes.json`. Nama bahan harus persis sama dengan nama kelas model.
- **Kelas yang diabaikan:** `kIgnoredClasses` di `lib/core/yolo.dart` (saat ini `image_9`).

## Cara kerja singkat
1. `image_picker` mengambil foto (kamera sistem atau galeri) dan memperkecilnya maksimal 1280 px.
2. `core/image_prep.dart` membaca foto, memutarnya sesuai EXIF, lalu membuat tensor 640x640 (letterbox) di isolate terpisah.
3. `services/detector.dart` menjalankan model dengan ONNX Runtime.
4. `core/yolo.dart` mengubah keluaran model menjadi kotak deteksi (decode + NMS).
5. `core/matcher.dart` mencocokkan bahan dengan resep. Hasil model disimpan, jadi mengubah ambang deteksi tidak menjalankan model lagi.

## Jika ada masalah
- *Gagal memuat model / aplikasi langsung tertutup:* pastikan dijalankan di HP arm64, bukan emulator x86.
- *Error minSdkVersion saat build:* ulangi langkah 3.
- *Bahan tidak terdeteksi:* turunkan ambang keyakinan di Pengaturan dalam aplikasi.
- *Pesan tipe data tensor:* kirim pesan error lengkapnya untuk diperiksa.
