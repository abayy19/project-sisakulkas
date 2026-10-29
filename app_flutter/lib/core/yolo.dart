/// Pra-pemrosesan (letterbox) dan pasca-pemrosesan (decode + NMS) untuk YOLOv8.
/// Ditulis sebagai Dart murni agar bisa diuji tanpa perangkat.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Kelas dataset yang tidak bermakna (label nyasar) dan harus diabaikan.
const Set<String> kIgnoredClasses = {'image_9'};

/// Satu hasil deteksi. Koordinat kotak dinormalisasi 0..1 terhadap gambar asli.
class Detection {
  final String label;
  final double conf;
  final double x1, y1, x2, y2;

  const Detection(this.label, this.conf, this.x1, this.y1, this.x2, this.y2);

  @override
  String toString() =>
      'Detection($label ${(conf * 100).round()}% [${x1.toStringAsFixed(4)}, ${y1.toStringAsFixed(4)}, ${x2.toStringAsFixed(4)}, ${y2.toStringAsFixed(4)}])';
}

/// Hasil letterbox: tensor input model beserta parameter untuk mengembalikan
/// koordinat ke gambar asli.
class Letterbox {
  /// Tensor [1, 3, size, size] diratakan, urutan RGB, nilai 0..1.
  final Float32List tensor;
  final int size;
  final double scale;
  final int padX, padY;
  final int origW, origH;

  const Letterbox({
    required this.tensor,
    required this.size,
    required this.scale,
    required this.padX,
    required this.padY,
    required this.origW,
    required this.origH,
  });
}

/// Mengubah gambar RGB ([w] x [h], 3 byte per piksel) menjadi tensor
/// [size] x [size] dengan menjaga rasio (sisa diisi abu-abu 114, seperti Ultralytics).
Letterbox letterbox(Uint8List rgb, int w, int h, int size) {
  if (rgb.length != w * h * 3) {
    throw ArgumentError('Ukuran data RGB (${rgb.length}) tidak sesuai ${w}x$h.');
  }
  final scale = math.min(size / w, size / h);
  final nw = math.max(1, (w * scale).round());
  final nh = math.max(1, (h * scale).round());
  final padX = ((size - nw) / 2).floor();
  final padY = ((size - nh) / 2).floor();
  final area = size * size;
  final t = Float32List(3 * area)..fillRange(0, 3 * area, 114 / 255);

  final sx = w / nw;
  final sy = h / nh;
  for (var y = 0; y < nh; y++) {
    final fy = math.max(0.0, math.min(h - 1.0, (y + 0.5) * sy - 0.5));
    final y0 = fy.floor();
    final y1 = math.min(y0 + 1, h - 1);
    final wy = fy - y0;
    for (var x = 0; x < nw; x++) {
      final fx = math.max(0.0, math.min(w - 1.0, (x + 0.5) * sx - 0.5));
      final x0 = fx.floor();
      final x1 = math.min(x0 + 1, w - 1);
      final wx = fx - x0;
      final i00 = (y0 * w + x0) * 3;
      final i01 = (y0 * w + x1) * 3;
      final i10 = (y1 * w + x0) * 3;
      final i11 = (y1 * w + x1) * 3;
      final o = (padY + y) * size + (padX + x);
      for (var c = 0; c < 3; c++) {
        final top = rgb[i00 + c] * (1 - wx) + rgb[i01 + c] * wx;
        final bot = rgb[i10 + c] * (1 - wx) + rgb[i11 + c] * wx;
        t[c * area + o] = (top * (1 - wy) + bot * wy) / 255.0;
      }
    }
  }
  return Letterbox(
      tensor: t, size: size, scale: scale, padX: padX, padY: padY, origW: w, origH: h);
}

class _Cand {
  final int cls;
  final double conf;
  final double x1, y1, x2, y2;
  const _Cand(this.cls, this.conf, this.x1, this.y1, this.x2, this.y2);
}

double _iou(_Cand a, _Cand b) {
  final x1 = math.max(a.x1, b.x1), y1 = math.max(a.y1, b.y1);
  final x2 = math.min(a.x2, b.x2), y2 = math.min(a.y2, b.y2);
  final inter = math.max(0.0, x2 - x1) * math.max(0.0, y2 - y1);
  final ua = (a.x2 - a.x1) * (a.y2 - a.y1) + (b.x2 - b.x1) * (b.y2 - b.y1) - inter;
  return ua > 0 ? inter / ua : 0.0;
}

/// Mengubah keluaran mentah YOLOv8 menjadi daftar deteksi.
///
/// [pred] berbentuk [4 + jumlahKelas][n]: baris 0..3 adalah cx, cy, w, h
/// (piksel pada gambar letterbox), baris berikutnya adalah skor tiap kelas.
List<Detection> decodeYolo({
  required List<List<double>> pred,
  required List<String> names,
  required Letterbox lb,
  double conf = 0.25,
  double iou = 0.7,
  Set<String> ignored = kIgnoredClasses,
  int maxDet = 100,
}) {
  final nc = names.length;
  if (pred.length != nc + 4) {
    throw FormatException(
        'Format model tidak sesuai: ${pred.length - 4} kelas di model, $nc kelas di config.json.');
  }
  final n = pred[0].length;
  final ignoredIdx = <int>{
    for (var k = 0; k < nc; k++)
      if (ignored.contains(names[k].trim().toLowerCase())) k
  };
  double cl(double v, double m) => v < 0 ? 0 : (v > m ? m : v);

  final cands = <_Cand>[];
  for (var i = 0; i < n; i++) {
    var best = -1;
    var bs = 0.0;
    for (var k = 0; k < nc; k++) {
      final s = pred[4 + k][i];
      if (s > bs) {
        bs = s;
        best = k;
      }
    }
    if (best < 0 || bs < conf || ignoredIdx.contains(best)) continue;
    final cx = pred[0][i], cy = pred[1][i], w = pred[2][i], h = pred[3][i];
    final x1 = cl((cx - w / 2 - lb.padX) / lb.scale, lb.origW.toDouble()) / lb.origW;
    final y1 = cl((cy - h / 2 - lb.padY) / lb.scale, lb.origH.toDouble()) / lb.origH;
    final x2 = cl((cx + w / 2 - lb.padX) / lb.scale, lb.origW.toDouble()) / lb.origW;
    final y2 = cl((cy + h / 2 - lb.padY) / lb.scale, lb.origH.toDouble()) / lb.origH;
    if (x2 <= x1 || y2 <= y1) continue;
    cands.add(_Cand(best, bs, x1, y1, x2, y2));
  }

  // NMS per kelas
  cands.sort((a, b) => b.conf.compareTo(a.conf));
  final kept = <_Cand>[];
  for (final c in cands) {
    if (kept.length >= maxDet) break;
    if (kept.every((k) => k.cls != c.cls || _iou(k, c) < iou)) kept.add(c);
  }
  return [
    for (final k in kept) Detection(names[k.cls], k.conf, k.x1, k.y1, k.x2, k.y2)
  ];
}
