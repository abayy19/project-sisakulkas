/// Pencocokan bahan yang dimiliki dengan database resep.
/// Logikanya sama dengan matcher.py dan app.js pada versi web.
library;

class Recipe {
  final String nama;
  final List<String> utama;
  final List<String> opsional;
  final String pantry;
  final List<String> langkah;

  const Recipe({
    required this.nama,
    required this.utama,
    required this.opsional,
    required this.pantry,
    required this.langkah,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        nama: j['nama'] as String,
        utama: (j['utama'] as List).cast<String>(),
        opsional: (j['opsional'] as List? ?? const []).cast<String>(),
        pantry: (j['pantry'] as String?) ?? '',
        langkah: (j['langkah'] as List).cast<String>(),
      );
}

/// Hasil pencocokan satu resep.
class RecipeMatch {
  final Recipe recipe;

  /// Bahan utama yang dimiliki dibagi total bahan utama (0..1).
  final double skor;
  final List<String> ada;
  final List<String> kurang;

  const RecipeMatch(this.recipe, this.skor, this.ada, this.kurang);

  bool get siap => kurang.isEmpty;
}

String normalizeName(String s) => s.trim().toLowerCase();

/// Mengembalikan resep yang cocok, diurutkan dari skor tertinggi, lalu yang
/// paling sedikit kekurangan bahannya, lalu yang paling banyak bahan miliknya,
/// lalu berdasarkan nama.
List<RecipeMatch> recommend(
  Iterable<String> ingredients,
  List<Recipe> recipes, {
  double minScore = 0.6,
  int limit = 30,
}) {
  final have = ingredients.map(normalizeName).toSet();
  final out = <RecipeMatch>[];
  for (final r in recipes) {
    final ada = r.utama.where((b) => have.contains(normalizeName(b))).toList();
    final kurang =
        r.utama.where((b) => !have.contains(normalizeName(b))).toList();
    if (ada.isEmpty) continue;
    final skor = ada.length / r.utama.length;
    if (skor < minScore - 1e-9) continue;
    out.add(RecipeMatch(r, skor, ada, kurang));
  }
  out.sort((a, b) {
    var c = b.skor.compareTo(a.skor);
    if (c != 0) return c;
    c = a.kurang.length.compareTo(b.kurang.length);
    if (c != 0) return c;
    c = b.ada.length.compareTo(a.ada.length);
    if (c != 0) return c;
    return a.recipe.nama.compareTo(b.recipe.nama);
  });
  return out.length > limit ? out.sublist(0, limit) : out;
}
