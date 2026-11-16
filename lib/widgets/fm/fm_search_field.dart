import 'package:flutter/material.dart';

import '../../core/text_search.dart';
import '../../models/fm_filter.dart';

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

  /// Klavyedeki "Ara" tuşu (AI/içerik araması gibi canlı koşmayan kipler).
  final ValueChanged<String>? onSubmitted;

  const FmSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
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
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      );
}

/// Bellekteki bir listeyi süzmek için ortak eşleşme kuralı: Türkçe-duyarlı,
/// büyük/küçük harf duyarsız, ad içinde geçme.
bool fmMatches(String name, String query, {String? path}) {
  final q = turkishFold(query.trim());
  if (q.isEmpty) return true;
  if (turkishFold(name).contains(q)) return true;
  // İkinci ad da bulunur (bkz. [FmFilter.aliasOf]).
  final alias = path == null ? '' : FmFilter.aliasOf?.call(path) ?? '';
  return alias.isNotEmpty && turkishFold(alias).contains(q);
}
