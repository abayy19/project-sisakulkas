import 'package:flutter/material.dart';

import '../core/matcher.dart';
import 'theme.dart';

class RecipeCard extends StatelessWidget {
  final RecipeMatch match;

  const RecipeCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final r = match.recipe;
    final siap = match.siap;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: siap ? AppColors.butter : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.ink, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(r.nama,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            siap ? 'Semua bahan utama sudah ada' : 'Kurang: ${match.kurang.join(', ')}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: siap ? AppColors.pandan : AppColors.chili,
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in r.utama)
                _NeedChip(label: b, have: match.ada.contains(b)),
            ],
          ),
          const SizedBox(height: 12),
          if (r.opsional.isNotEmpty)
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'Bahan opsional: ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: r.opsional.join(', ')),
            ])),
          if (r.pantry.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'Bumbu dapur: ',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: r.pantry),
            ])),
          ],
          const SizedBox(height: 10),
          const Text('Langkah:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (var i = 0; i < r.langkah.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${i + 1}. ${r.langkah[i]}'),
            ),
        ],
      ),
    );
  }
}

class _NeedChip extends StatelessWidget {
  final String label;
  final bool have;

  const _NeedChip({required this.label, required this.have});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: have ? AppColors.pandan : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: have ? AppColors.pandan : AppColors.chili,
          width: 2,
        ),
      ),
      child: Text(
        have ? label : '$label (belum ada)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: have ? Colors.white : AppColors.chili,
        ),
      ),
    );
  }
}
