import 'package:flutter/material.dart';

import '../../core/text_search.dart';

/// AppBar başlığına oturan **yerinde arama** alanı.
///
/// Kullanıcı isteği (2026-07-25): "her alanda ayrı olarak dosya ara seçeneği
/// olmalı ve olabildiğince hızlı çalışmalı". Kategori/Fotoğraflar/Çöp gibi
/// ekranların listesi ZATEN bellektedir → burada disk taraması yoktur, süzme
/// anlıktır (`fmMatches`). Depolamanın tamamında arama ayrı ekranda
/// (`SearchScreen` + `SearchIndex`) yapılır.
class FmSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const FmSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Ara…',
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          filled: false,
        ),
        onChanged: onChanged,
      );
}

/// Bellekteki bir listeyi süzmek için ortak eşleşme kuralı: Türkçe-duyarlı,
/// büyük/küçük harf duyarsız, ad içinde geçme.
bool fmMatches(String name, String query) {
  final q = turkishFold(query.trim());
  if (q.isEmpty) return true;
  return turkishFold(name).contains(q);
}
