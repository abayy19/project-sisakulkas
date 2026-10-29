// Uji mandiri logika inti (tanpa perangkat, tanpa paket tambahan).
// Jalankan dari folder proyek:  dart tool/selfcheck.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../lib/core/matcher.dart';
import '../lib/core/yolo.dart';

int _fail = 0;
int _ok = 0;
void check(bool cond, String msg) {
  if (cond) {
    _ok++;
  } else {
    _fail++;
    stderr.writeln('GAGAL: $msg');
  }
}

bool near(double a, double b, [double eps = 1e-3]) => (a - b).abs() <= eps;

String _read(String rel) => File.fromUri(Platform.script.resolve(rel)).readAsStringSync();

void main() {
  // ---------- 1. Pencocokan resep: sama persis dengan implementasi Python ----------
  final recipes = (jsonDecode(_read('../assets/data/recipes.json')) as List)
      .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
      .toList();
  check(recipes.length == 26, 'jumlah resep 26, dapat ${recipes.length}');

  final cases = jsonDecode(_read('parity.json')) as List;
  for (final c in cases) {
    final ings = (c['ingredients'] as List).cast<String>();
    final ms = (c['min_score'] as num).toDouble();
    final got = recommend(ings, recipes, minScore: ms);
    final exp = c['expected'] as List;
    final tag = '$ings min=$ms';
    check(got.length == exp.length, '$tag: jumlah ${got.length} != ${exp.length}');
    for (var i = 0; i < got.length && i < exp.length; i++) {
      check(got[i].recipe.nama == exp[i]['nama'], '$tag: urutan #$i ${got[i].recipe.nama} != ${exp[i]['nama']}');
      check(near(got[i].skor, (exp[i]['skor'] as num).toDouble(), 1e-5), '$tag: skor #$i');
      check(got[i].kurang.join('|') == (exp[i]['kurang'] as List).join('|'), '$tag: kurang #$i');
    }
  }

  // ---------- 2. Letterbox: foto 900x600 -> 640x640 ----------
  const w = 900, h = 600, size = 640;
  final rgb = Uint8List(w * h * 3);
  for (var i = 0; i < w * h; i++) {
    rgb[i * 3] = 200;
    rgb[i * 3 + 1] = 100;
    rgb[i * 3 + 2] = 50;
  }
  final lb = letterbox(rgb, w, h, size);
  check(near(lb.scale, 640 / 900, 1e-9), 'scale');
  check(lb.padX == 0 && lb.padY == 106, 'padding (0,106), dapat (${lb.padX},${lb.padY})');
  check(lb.tensor.length == 3 * size * size, 'panjang tensor');
  final area = size * size;
  check(near(lb.tensor[0], 114 / 255, 1e-6), 'area pad atas berwarna abu-abu 114');
  final centerIdx = 320 * size + 320;
  check(near(lb.tensor[centerIdx], 200 / 255, 1e-5), 'kanal R di tengah');
  check(near(lb.tensor[area + centerIdx], 100 / 255, 1e-5), 'kanal G di tengah');
  check(near(lb.tensor[2 * area + centerIdx], 50 / 255, 1e-5), 'kanal B di tengah');
  check(near(lb.tensor[(size - 1) * size + 5], 114 / 255, 1e-6), 'area pad bawah');

  // ---------- 3. Decode + NMS dengan keluaran buatan ----------
  const nc = 25, n = 8400;
  final names = (jsonDecode(_read('../assets/data/config.json'))['names'] as List).cast<String>();
  check(names.length == nc, '25 nama kelas');
  final pred = List.generate(4 + nc, (_) => List<double>.filled(n, 0.0));
  void put(int i, double cx, double cy, double bw, double bh, int cls, double s) {
    pred[0][i] = cx; pred[1][i] = cy; pred[2][i] = bw; pred[3][i] = bh; pred[4 + cls][i] = s;
  }
  final telur = names.indexOf('Telur'), cabe = names.indexOf('Cabe');
  final img9 = names.indexOf('Image_9'), tomat = names.indexOf('Tomat');
  put(100, 320, 320, 200, 200, telur, 0.90);
  put(101, 322, 320, 200, 200, telur, 0.80); // kembar -> harus ditekan NMS
  put(200, 500, 300, 100, 100, cabe, 0.60);
  put(300, 100, 300, 80, 80, img9, 0.95); // kelas diabaikan
  put(400, 100, 500, 80, 80, tomat, 0.20); // di bawah ambang 25%

  final d = decodeYolo(pred: pred, names: names, lb: lb, conf: 0.25);
  check(d.length == 2, 'tersisa 2 deteksi, dapat ${d.length}: $d');
  check(d.first.label == 'Telur' && near(d.first.conf, 0.90, 1e-6), 'deteksi pertama Telur 0.90');
  // Posisi sama dengan versi web: [0.3438, 0.2672, 0.6562, 0.7360]
  check(near(d.first.x1, 0.3438, 5e-4) && near(d.first.y1, 0.2672, 5e-4), 'sudut kiri-atas Telur');
  check(near(d.first.x2, 0.6562, 5e-4) && near(d.first.y2, 0.7360, 5e-4), 'sudut kanan-bawah Telur');
  check(d.any((e) => e.label == 'Cabe'), 'Cabe terdeteksi');
  check(!d.any((e) => e.label == 'Image_9'), 'Image_9 diabaikan');
  final low = decodeYolo(pred: pred, names: names, lb: lb, conf: 0.10);
  check(low.any((e) => e.label == 'Tomat'), 'Tomat muncul saat ambang 10%');
  try {
    decodeYolo(pred: pred.sublist(0, 20), names: names, lb: lb);
    check(false, 'jumlah kelas tidak cocok harus melempar error');
  } on FormatException {
    check(true, '');
  }

  stdout.writeln('Lolos: $_ok pemeriksaan, gagal: $_fail');
  exit(_fail == 0 ? 0 : 1);
}
