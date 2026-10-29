// Uji logika inti. Jalankan dengan:  flutter test
// (menggantikan widget_test.dart bawaan `flutter create`)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sisakulkas/core/matcher.dart';
import 'package:sisakulkas/core/yolo.dart';

void main() {
  final recipes = (jsonDecode(File('assets/data/recipes.json').readAsStringSync()) as List)
      .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
      .toList();

  test('Telur + Bawang Merah + Cabe: Telur Dadar paling atas dan siap dibuat', () {
    final r = recommend(['Telur', 'Bawang Merah', 'Cabe'], recipes);
    expect(r, isNotEmpty);
    expect(r.first.recipe.nama, 'Telur Dadar');
    expect(r.first.siap, isTrue);
  });

  test('Letterbox 900x600 -> 640: padding atas/bawah 106 piksel', () {
    final rgb = Uint8List(900 * 600 * 3)..fillRange(0, 900 * 600 * 3, 128);
    final lb = letterbox(rgb, 900, 600, 640);
    expect(lb.padX, 0);
    expect(lb.padY, 106);
    expect(lb.tensor.length, 3 * 640 * 640);
  });

  test('Decode: kelas Image_9 diabaikan dan duplikat ditekan NMS', () {
    final names = (jsonDecode(File('assets/data/config.json').readAsStringSync())['names'] as List)
        .cast<String>();
    final lb = letterbox(Uint8List(900 * 600 * 3), 900, 600, 640);
    final pred = List.generate(4 + names.length, (_) => List<double>.filled(8400, 0));
    void put(int i, double cx, double cy, double w, double h, int cls, double s) {
      pred[0][i] = cx; pred[1][i] = cy; pred[2][i] = w; pred[3][i] = h;
      pred[4 + cls][i] = s;
    }
    final telur = names.indexOf('Telur');
    put(10, 320, 320, 200, 200, telur, 0.9);
    put(11, 322, 320, 200, 200, telur, 0.8);
    put(12, 100, 300, 80, 80, names.indexOf('Image_9'), 0.95);
    final d = decodeYolo(pred: pred, names: names, lb: lb);
    expect(d.length, 1);
    expect(d.first.label, 'Telur');
  });
}
