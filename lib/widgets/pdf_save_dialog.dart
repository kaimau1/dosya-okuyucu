import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/pdf_save.dart';

/// "Üzerine yaz" mı, "kopyasını kaydet" mi? — PDF'e yazan her akışın ortak
/// sorusu (PDF araçları, imza, AI düzenleme).
///
/// *Niye seçenek:* üzerine yazmak geri alınamaz. Kullanıcı bazen özgün belgeyi
/// bozmadan denemek ister; eskiden tek yol üzerine yazmaktı.
/// Vazgeçilirse `null` döner.
Future<PdfSaveMode?> askPdfSaveMode(
  BuildContext context, {
  required String path,
  String? note,
}) {
  final name = p.basename(path);
  return showDialog<PdfSaveMode>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nasıl kaydedilsin?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note != null) ...[
            Text(note),
            const SizedBox(height: 12),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.save_outlined),
            title: const Text('Üzerine yaz'),
            subtitle: Text('$name değişir — geri alınamaz'),
            onTap: () => Navigator.pop(ctx, PdfSaveMode.overwrite),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_all_outlined),
            title: const Text('Kopyasını kaydet'),
            subtitle: const Text('Özgün dosya olduğu gibi kalır'),
            onTap: () => Navigator.pop(ctx, PdfSaveMode.copy),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
      ],
    ),
  );
}
