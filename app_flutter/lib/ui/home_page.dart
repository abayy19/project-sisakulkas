import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';

import '../core/image_prep.dart';
import '../core/matcher.dart';
import '../core/yolo.dart';
import '../services/detector.dart';
import 'boxes_painter.dart';
import 'recipe_card.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _picker = ImagePicker();

  Detector? _detector;
  List<Recipe> _recipes = const [];

  PreparedImage? _prep;
  List<List<double>>? _pred; // keluaran mentah model, dipakai ulang saat ambang diubah
  List<Detection> _detections = const [];
  List<String> _ingredients = [];

  double _conf = 0.25;
  double _minScore = 0.6;
  String? _highlight;

  bool _loadingModel = true;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _detector?.dispose();
    super.dispose();
  }

  void _setMsg(String? m, [bool isError = false]) {
    _message = m;
    _messageIsError = isError;
  }

  Future<void> _init() async {
    try {
      final json = jsonDecode(await rootBundle.loadString('assets/data/recipes.json')) as List;
      final recipes =
          json.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
      final det = await Detector.load();
      if (!mounted) {
        det.dispose();
        return;
      }
      setState(() {
        _recipes = recipes;
        _detector = det;
        _loadingModel = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingModel = false;
        _setMsg('Model gagal dimuat: $e', true);
      });
    }
  }

  Color _colorOf(String label) {
    final i = _detector?.names.indexOf(label) ?? -1;
    return AppColors.boxPalette[(i < 0 ? 0 : i) % AppColors.boxPalette.length];
  }

  // ---------- alur utama ----------

  Future<void> _pick(ImageSource source) async {
    final det = _detector;
    if (det == null) {
      setState(() => _setMsg('Model belum siap. Tunggu sebentar lalu coba lagi.', true));
      return;
    }
    try {
      // Foto diperkecil oleh sistem (maks 1280 px) agar pemrosesan cepat dan hemat memori.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
      );
      if (file == null) return;
      setState(() {
        _busy = true;
        _setMsg(null);
      });
      final bytes = await file.readAsBytes();
      final prep = await prepareImage(bytes, det.imgsz);
      final pred = await det.infer(prep.letterbox);
      if (!mounted) return;
      setState(() {
        _prep = prep;
        _pred = pred;
        _applyConf(det);
      });
    } catch (e) {
      if (mounted) setState(() => _setMsg('Gagal memproses foto: $e', true));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mendecode ulang keluaran model dengan ambang saat ini (tanpa menjalankan model lagi).
  void _applyConf(Detector det) {
    final prep = _prep;
    final pred = _pred;
    if (prep == null || pred == null) return;
    final d = decodeYolo(pred: pred, names: det.names, lb: prep.letterbox, conf: _conf);
    final seen = <String>{};
    _detections = d;
    _ingredients = [
      for (final e in d)
        if (seen.add(e.label)) e.label
    ];
    _highlight = null;
    _setMsg(_ingredients.isEmpty
        ? 'Tidak ada bahan terdeteksi. Coba foto yang lebih dekat dan terang, '
            'turunkan ambang di Pengaturan, atau tambahkan bahan secara manual.'
        : null);
  }

  void _addIngredient(String label) {
    if (_ingredients.contains(label)) return;
    setState(() => _ingredients = [..._ingredients, label]);
  }

  void _removeIngredient(String label) {
    setState(() {
      _ingredients = _ingredients.where((e) => e != label).toList();
      if (_highlight == label) _highlight = null;
    });
  }

  // ---------- tampilan ----------

  @override
  Widget build(BuildContext context) {
    final canPick = !_busy && !_loadingModel && _detector != null;
    return Scaffold(
      appBar: AppBar(title: const Text('SisaKulkas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const Text(
              'Apa isi kulkasmu hari ini?',
              style: TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Foto bahan yang kamu punya, lalu pilih masakan yang bisa langsung dibuat. '
              'Foto diproses di perangkatmu dan tidak dikirim ke mana pun.',
              style: TextStyle(color: AppColors.mute, fontSize: 15),
            ),
            const SizedBox(height: 16),
            if (_message != null) _banner(),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canPick ? () => _pick(ImageSource.camera) : null,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Ambil foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPick ? () => _pick(ImageSource.gallery) : null,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Pilih foto'),
                  ),
                ),
              ],
            ),
            if (_loadingModel || (_busy && _prep == null)) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(_loadingModel ? 'Memuat model...' : 'Mendeteksi bahan...',
                  style: const TextStyle(color: AppColors.mute)),
            ],
            if (_prep != null) ...[
              const SizedBox(height: 16),
              _photo(_prep!),
            ],
            const SizedBox(height: 16),
            _shelf(),
            if (_prep != null) ..._recipeSection(),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    final color = _messageIsError ? const Color(0xFFFFD9D4) : AppColors.butter;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Text(_message!, style: const TextStyle(color: AppColors.ink)),
    );
  }

  Widget _photo(PreparedImage p) {
    final visible = _detections.where((d) => _ingredients.contains(d.label)).toList();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: p.width / p.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(p.displayJpg, fit: BoxFit.fill, gaplessPlayback: true),
              CustomPaint(
                painter: BoxesPainter(
                  detections: visible,
                  highlight: _highlight,
                  colorOf: _colorOf,
                ),
              ),
              if (_busy)
                Container(
                  color: const Color(0xE6E3EEEB),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shelf() {
    final det = _detector;
    final options = <String>[
      if (det != null)
        for (final n in det.names)
          if (!kIgnoredClasses.contains(normalizeName(n)) && !_ingredients.contains(n)) n
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bahan yang kamu punya',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          const Text(
            'Ketuk bahan untuk menyorot posisinya di foto. '
            'Hapus yang keliru, tambahkan yang terlewat.',
            style: TextStyle(color: AppColors.mute, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (_ingredients.isEmpty)
            const Text('Belum ada bahan.', style: TextStyle(color: AppColors.mute))
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final label in _ingredients)
                  InputChip(
                    avatar: Icon(Icons.circle, size: 14, color: _colorOf(label)),
                    label: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    selected: _highlight == label,
                    onPressed: () => setState(
                        () => _highlight = _highlight == label ? null : label),
                    onDeleted: () => _removeIngredient(label),
                    deleteButtonTooltipMessage: 'Hapus $label',
                  ),
              ],
            ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            isExpanded: true,
            value: null,
            hint: const Text('Tambah bahan...'),
            items: [
              for (final n in options) DropdownMenuItem(value: n, child: Text(n)),
            ],
            onChanged: (v) {
              if (v != null) _addIngredient(v);
            },
          ),
          ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: EdgeInsets.zero,
            title: const Text('Pengaturan',
                style: TextStyle(fontWeight: FontWeight.w700)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Ambang keyakinan deteksi: ${(_conf * 100).round()}%'),
              ),
              Slider(
                value: _conf,
                min: 0.1,
                max: 0.9,
                divisions: 16,
                label: '${(_conf * 100).round()}%',
                onChanged: (v) => setState(() {
                  _conf = v;
                  final det = _detector;
                  if (det != null) _applyConf(det);
                }),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Makin rendah, makin banyak bahan terdeteksi tetapi lebih sering keliru. '
                  'Jika ada bahan yang terlewat, coba turunkan.',
                  style: TextStyle(color: AppColors.mute, fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Kecocokan minimal resep: ${(_minScore * 100).round()}%'),
              ),
              Slider(
                value: _minScore,
                min: 0.3,
                max: 1.0,
                divisions: 7,
                label: '${(_minScore * 100).round()}%',
                onChanged: (v) => setState(() => _minScore = v),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Persentase bahan utama resep yang sudah kamu punya.',
                  style: TextStyle(color: AppColors.mute, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _recipeSection() {
    final heading = const Padding(
      padding: EdgeInsets.only(top: 24, bottom: 4),
      child: Text('Masakan untukmu',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
    );
    if (_ingredients.isEmpty) {
      return [
        heading,
        const Text('Belum ada bahan. Tambahkan bahan atau ambil foto lain.',
            style: TextStyle(color: AppColors.mute)),
      ];
    }
    final matches = recommend(_ingredients, _recipes, minScore: _minScore);
    if (matches.isEmpty) {
      return [
        heading,
        const Text(
          'Belum ada resep yang cocok. Tambahkan bahan, atau turunkan kecocokan minimal di Pengaturan.',
          style: TextStyle(color: AppColors.mute),
        ),
      ];
    }
    final siap = matches.where((m) => m.siap).toList();
    final hampir = matches.where((m) => !m.siap).toList();
    Widget group(String title, List<RecipeMatch> items) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('$title (${items.length})',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              for (final m in items) RecipeCard(match: m),
            ],
          ),
        );
    return [
      heading,
      if (siap.isNotEmpty) group('Bisa dibuat sekarang', siap),
      if (hampir.isNotEmpty) group('Tinggal kurang beberapa bahan', hampir),
    ];
  }
}
