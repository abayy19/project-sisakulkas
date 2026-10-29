/// Menjalankan model YOLOv8 (format ONNX) di perangkat dengan ONNX Runtime.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:onnxruntime_plus/onnxruntime_plus.dart';

import '../core/yolo.dart';

class Detector {
  final OrtSession _session;
  final OrtSessionOptions _options;
  final String _inputName;

  /// Nama kelas sesuai urutan indeks model (dari assets/data/config.json).
  final List<String> names;

  /// Ukuran input model (piksel, persegi).
  final int imgsz;

  Detector._(this._session, this._options, this._inputName, this.names, this.imgsz);

  static Future<Detector> load() async {
    OrtEnv.instance.init();
    final cfg = jsonDecode(await rootBundle.loadString('assets/data/config.json'))
        as Map<String, dynamic>;
    final names = (cfg['names'] as List).cast<String>();
    final imgsz = (cfg['imgsz'] as num?)?.toInt() ?? 640;

    final data = await rootBundle.load('assets/models/best.onnx');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final options = OrtSessionOptions()..setIntraOpNumThreads(2);
    final session = OrtSession.fromBuffer(bytes, options);
    return Detector._(session, options, session.inputNames.first, names, imgsz);
  }

  /// Menjalankan model dan mengembalikan keluaran mentah [4 + jumlahKelas][n].
  /// Hasil ini bisa didecode berulang kali dengan ambang berbeda tanpa menjalankan model lagi.
  Future<List<List<double>>> infer(Letterbox lb) async {
    // Bungkus dalam list agar elemen terdalamnya Float32List, sehingga tipe
    // tensor terbaca sebagai float32 (list double biasa akan dibaca sebagai float64).
    final input = OrtValueTensor.createTensorWithDataList(
        [lb.tensor], [1, 3, lb.size, lb.size]);
    final runOptions = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = await _session.runAsync(runOptions, {_inputName: input});
      final out = outputs?.first;
      if (out == null) throw StateError('Model tidak menghasilkan keluaran.');
      final raw = (out as OrtValueTensor).value as List; // [1][4+nc][n]
      final channels = raw[0] as List;
      return [
        for (final row in channels)
          row is List<double> ? row : (row as List).cast<double>()
      ];
    } finally {
      input.release();
      runOptions.release();
      outputs?.forEach((e) => e?.release());
    }
  }

  void dispose() {
    _session.release();
    _options.release();
    OrtEnv.instance.release();
  }
}
