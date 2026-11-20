/// **Form: otomatik doldurma profili + form oluşturma** — Faz 39 madde 9.
///
/// * Profil (ad, soyad, e-posta, telefon, adres…) cihazda
///   `SharedPreferences`'ta durur, hiçbir yere gönderilmez. KVKK: kimlik
///   numarası gibi alanlar BİLİNÇLİ olarak profilde yok.
/// * Alan eşleme: alan etiketinin sadeleştirilmiş hâli Türkçe/İngilizce anahtar
///   sözcüklerle karşılaştırılır ([matchKey], saf + testli). Yalnız BOŞ metin
///   alanları doldurulur — kullanıcının yazdığı ezilmez.
/// * Form oluşturma: verilen kutulara metin / onay kutusu / imza alanı
///   (Syncfusion AcroForm alanları) eklenir.
/// * Alan vurgusu ve düzleştirme zaten vardı (`PdfFormOverlay`,
///   `PdfFormFiller.fill(flatten:)`).
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show Rect;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_tools.dart' show PdfToolsException;

/// Profil anahtarları (sıra = arayüz sırası).
enum ProfileKey {
  fullName,
  firstName,
  lastName,
  email,
  phone,
  address,
  city,
  postalCode,
  company,
  date,
}

/// Yeni form alanı türü.
enum NewFieldKind { text, checkbox, signature }

class NewFormField {
  final int page;
  final Rect bounds;
  final NewFieldKind kind;
  final String name;
  const NewFormField(this.page, this.bounds, this.kind, this.name);
}

abstract final class PdfFormPro {
  static const _prefsKey = 'pdf_autofill_profile';

  static Future<Map<ProfileKey, String>> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    try {
      final map = (jsonDecode(raw) as Map).cast<String, Object?>();
      return {
        for (final k in ProfileKey.values)
          if (map[k.name] is String && (map[k.name] as String).isNotEmpty)
            k: map[k.name] as String,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProfile(Map<ProfileKey, String> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode({
      for (final e in profile.entries)
        if (e.value.trim().isNotEmpty && e.key != ProfileKey.date)
          e.key.name: e.value.trim(),
    }));
  }

  /// Saf: etiketi sadeleştirir (küçük harf, Türkçe harfler ASCII'ye, harf
  /// dışı → boşluk).
  static String normalize(String label) {
    const map = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
      'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'I': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
    };
    final sb = StringBuffer();
    for (final ch in label.split('')) {
      sb.write(map[ch] ?? ch.toLowerCase());
    }
    // camelCase alan adları ("firstName") → "first name".
    final spaced = label.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    final base = spaced == label ? sb.toString() : normalize(spaced);
    return base
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Saf: etiket → profil anahtarı (yoksa `null`). Önce uzun/özgül kalıplar.
  static ProfileKey? matchKey(String label) {
    final n = ' ${normalize(label)} ';
    bool has(List<String> words) => words.any((w) => n.contains(' $w '));
    if (has(['ad soyad', 'adi soyadi', 'ad soyadi', 'isim soyisim', 'full name',
      'name surname', 'adiniz soyadiniz', 'ad ve soyad'])) {
      return ProfileKey.fullName;
    }
    if (has(['soyad', 'soyadi', 'soyadiniz', 'soyisim', 'surname', 'last name',
      'family name', 'lastname'])) {
      return ProfileKey.lastName;
    }
    if (has(['e posta', 'eposta', 'email', 'e mail', 'mail'])) {
      return ProfileKey.email;
    }
    if (has(['telefon', 'tel', 'gsm', 'cep', 'phone', 'mobile', 'telefon no'])) {
      return ProfileKey.phone;
    }
    if (has(['posta kodu', 'zip', 'postal code', 'postcode', 'zip code'])) {
      return ProfileKey.postalCode;
    }
    if (has(['adres', 'adresi', 'address', 'ikametgah'])) {
      return ProfileKey.address;
    }
    if (has(['il', 'sehir', 'city', 'town'])) return ProfileKey.city;
    if (has(['firma', 'sirket', 'kurum', 'company', 'organization',
      'organisation', 'isyeri'])) {
      return ProfileKey.company;
    }
    if (has(['tarih', 'date', 'bugun'])) return ProfileKey.date;
    if (has(['ad', 'adi', 'adiniz', 'isim', 'name', 'first name', 'firstname',
      'given name'])) {
      return ProfileKey.firstName;
    }
    return null;
  }

  /// Saf: profil değeri (ad soyad yoksa ad + soyad birleşir; tarih bugün).
  static String? valueFor(ProfileKey key, Map<ProfileKey, String> profile,
      {DateTime? today}) {
    if (key == ProfileKey.date) {
      final d = today ?? DateTime.now();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(d.day)}.${two(d.month)}.${d.year}';
    }
    final v = profile[key];
    if (v != null && v.isNotEmpty) return v;
    if (key == ProfileKey.fullName) {
      final parts = [profile[ProfileKey.firstName], profile[ProfileKey.lastName]]
          .whereType<String>()
          .where((s) => s.isNotEmpty);
      return parts.isEmpty ? null : parts.join(' ');
    }
    return null;
  }

  /// Saf: alan (ad/etiket → mevcut değer) listesinden doldurma önerisi.
  /// Yalnız boş alanlar.
  static Map<String, String> suggest(
    List<({String name, String label, String value})> fields,
    Map<ProfileKey, String> profile, {
    DateTime? today,
  }) {
    final out = <String, String>{};
    for (final f in fields) {
      if (f.value.trim().isNotEmpty) continue;
      final key = matchKey(f.label) ?? matchKey(f.name);
      if (key == null) continue;
      final v = valueFor(key, profile, today: today);
      if (v != null) out[f.name] = v;
    }
    return out;
  }

  // ── Form oluşturma ───────────────────────────────────────────────────────

  static Future<List<int>> addFields(List<int> bytes, List<NewFormField> fields,
      {List<int>? fontBytes, String? password}) async {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final used = <String>{
        for (var i = 0; i < doc.form.fields.count; i++)
          doc.form.fields[i].name ?? '',
      };
      String unique(String base) {
        var name = base.trim().isEmpty ? 'Alan' : base.trim();
        var n = 2;
        final root = name;
        while (used.contains(name)) {
          name = '$root$n';
          n++;
        }
        used.add(name);
        return name;
      }

      for (final f in fields) {
        if (f.page < 0 || f.page >= doc.pages.count) continue;
        final page = doc.pages[f.page];
        final name = unique(f.name);
        final PdfField field = switch (f.kind) {
          NewFieldKind.text => PdfTextBoxField(page, name, f.bounds,
              font: fontBytes == null
                  ? PdfStandardFont(PdfFontFamily.helvetica, 10)
                  : PdfTrueTypeFont(fontBytes, 10),
              borderColor: PdfColor(120, 120, 120),
              multiline: f.bounds.height > 30),
          NewFieldKind.checkbox => PdfCheckBoxField(page, name, f.bounds,
              borderColor: PdfColor(120, 120, 120)),
          NewFieldKind.signature => PdfSignatureField(page, name,
              bounds: f.bounds, borderColor: PdfColor(120, 120, 120)),
        };
        doc.form.fields.add(field);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  // ── Düz PDF'te alan algılama (P18) ──────────────────────────────────────

  static const _boxGlyphs = {'☐', '□', '❏', '❑', '▢'};

  /// Düz (formsuz) PDF'te doldurulacak yerleri bulur: `____` ve `.....`
  /// dizileri → metin alanı, `☐`/`□` → onay kutusu. Alan adı satırda diziden
  /// önceki etikettir ("Adı Soyadı: ____" → "Adı Soyadı"; otomatik doldurma
  /// eşlemesi bunu kullanır). Var olan form alanıyla çakışan atlanır.
  /// Koordinatlar ham sayfa puntosu (sol-üst).
  ///
  /// ponytail: yalnız metin katmanı; çizgi/kutu VEKTÖRLERİ okunmaz ve
  /// döndürülmüş sayfa atlanır — çizgili form için sonra yol nesnesi
  /// (pdf_objects) okuyan sezgi eklenir.
  static List<NewFormField> detectFields(List<int> bytes, {String? password}) {
    final doc = PdfDocument(inputBytes: bytes, password: password);
    try {
      final taken = <int, List<Rect>>{};
      for (var i = 0; i < doc.form.fields.count; i++) {
        final f = doc.form.fields[i];
        final pg = f.page;
        if (pg == null) continue;
        (taken[doc.pages.indexOf(pg)] ??= []).add(f.bounds);
      }
      final extractor = PdfTextExtractor(doc);
      final out = <NewFormField>[];
      for (var i = 0; i < doc.pages.count; i++) {
        if (doc.pages[i].rotation.index % 4 != 0) continue;
        final busy = taken[i] ?? const <Rect>[];
        for (final line
            in extractor.extractTextLines(startPageIndex: i, endPageIndex: i)) {
          final glyphs = [for (final w in line.wordCollection) ...w.glyphs];
          for (final f in fieldsInLine(i, glyphs)) {
            if (busy.any((b) => b.overlaps(f.bounds))) continue;
            out.add(f);
          }
        }
      }
      return out;
    } finally {
      doc.dispose();
    }
  }

  /// Tek satırın glifleri → alanlar (saf; [detectFields] çağırır).
  static List<NewFormField> fieldsInLine(int page, List<TextGlyph> glyphs) {
    final out = <NewFormField>[];
    final label = StringBuffer();
    var g = 0;
    while (g < glyphs.length) {
      final t = glyphs[g].text;
      if (_boxGlyphs.contains(t)) {
        final b = glyphs[g].bounds;
        final side = b.height.clamp(8.0, 24.0).toDouble();
        out.add(NewFormField(
            page,
            Rect.fromCenter(center: b.center, width: side, height: side),
            NewFieldKind.checkbox,
            _labelOf(label)));
        label.clear();
        g++;
        continue;
      }
      if (t != '_' && t != '.' && t != '…') {
        // Sözcük arası boşluk glif değildir; aralıktan geri kur.
        if (g > 0 &&
            glyphs[g].bounds.left - glyphs[g - 1].bounds.right >
                glyphs[g].bounds.height * 0.15) {
          label.write(' ');
        }
        label.write(t);
        g++;
        continue;
      }
      // Dolgu dizisi: araya glif boyundan geniş boşluk girerse kopar.
      final under = t == '_';
      var end = g;
      var weight = 0;
      while (end < glyphs.length) {
        final c = glyphs[end].text;
        if (under ? c != '_' : (c != '.' && c != '…')) break;
        if (end > g) {
          final gap = glyphs[end].bounds.left - glyphs[end - 1].bounds.right;
          if (gap > glyphs[end].bounds.height) break;
        }
        weight += c == '…' ? 3 : 1;
        end++;
      }
      if (weight >= (under ? 3 : 5)) {
        final first = glyphs[g].bounds;
        final last = glyphs[end - 1].bounds;
        final h = first.height.clamp(12.0, 28.0).toDouble();
        out.add(NewFormField(
            page,
            Rect.fromLTRB(
                first.left, first.bottom - h, last.right, first.bottom),
            NewFieldKind.text,
            _labelOf(label)));
        label.clear();
      } else {
        for (var k = g; k < end; k++) {
          label.write(glyphs[k].text);
        }
      }
      g = end;
    }
    return out;
  }

  static String _labelOf(StringBuffer b) {
    var s = b.toString().replaceAll(RegExp(r'[\s:.\-–]+$'), '').trim();
    if (s.length > 40) s = s.substring(s.length - 40).trim();
    return s;
  }

  static Future<List<NewFormField>> detectFieldsInBackground(List<int> bytes,
          {String? password}) =>
      Isolate.run(() {
        try {
          return detectFields(bytes, password: password);
        } catch (e) {
          throw PdfToolsException('$e');
        }
      });

  static Future<List<int>> addFieldsInBackground(
          List<int> bytes, List<NewFormField> fields,
          {List<int>? fontBytes, String? password}) =>
      Isolate.run(() async {
        try {
          return await addFields(bytes, fields,
              fontBytes: fontBytes, password: password);
        } catch (e) {
          throw PdfToolsException('$e');
        }
      });
}
