/// Membaca foto (JPG/PNG), memutarnya sesuai data EXIF, lalu menyiapkan tensor
/// untuk model. Dijalankan di isolate terpisah agar tampilan tidak macet.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'yolo.dart';

class PreparedImage {
  /// Gambar yang sudah diputar sesuai EXIF, dipakai untuk ditampilkan.
  /// Kotak deteksi dihitung terhadap gambar yang sama, jadi posisinya pasti pas.
  final Uint8List displayJpg;
  final Letterbox letterbox;

  const PreparedImage(this.displayJpg, this.letterbox);

  int get width => letterbox.origW;
  int get height => letterbox.origH;
}

class _Args {
  final Uint8List bytes;
  final int size;
  const _Args(this.bytes, this.size);
}

PreparedImage _prepare(_Args a) {
  final decoded = img.decodeImage(a.bytes);
  if (decoded == null) {
    throw const FormatException('Foto tidak bisa dibaca. Gunakan file JPG atau PNG.');
  }
  final baked = img.bakeOrientation(decoded);
  final rgb = baked.getBytes(order: img.ChannelOrder.rgb);
  final lb = letterbox(rgb, baked.width, baked.height, a.size);
  final jpg = img.encodeJpg(baked, quality: 90);
  return PreparedImage(jpg, lb);
}

Future<PreparedImage> prepareImage(Uint8List bytes, int size) =>
    compute(_prepare, _Args(bytes, size));
