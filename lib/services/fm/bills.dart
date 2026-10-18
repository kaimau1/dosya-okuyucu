import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/text_search.dart';
import '../gemini_service.dart';
import 'ai_buckets.dart';
import 'ai_extract.dart';
import 'ai_index.dart';

/// Bir faturadan/makbuzdan çıkarılan bilgi.
@immutable
class Bill {
  final String path;

  /// Çıkarım anındaki değişme zamanı: dosya değişirse bilgi tazelenir.
  final int modifiedMs;

  /// Kurum ("Enerjisa", "Türk Telekom", "Eryaman Konutları").
  final String issuer;

  /// Ödenecek toplam (bilinmiyorsa null).
  final double? amount;
  final String currency;

  /// Son ödeme tarihi (bilinmiyorsa null).
  final int? dueMs;

  /// Hangi ayın gideri: dönem > son ödeme > dosya tarihi.
  final int periodMs;

  /// Kullanıcı "ödendi" dedi mi (hatırlatma susar).
  final bool paid;

  /// Bilgi nereden: `ai` (Gemini) ya da `local` (cihazda metinden tahmin).
  final String source;

  const Bill({
    required this.path,
    required this.modifiedMs,
    required this.issuer,
    required this.amount,
    this.currency = 'TL',
    this.dueMs,
    required this.periodMs,
    this.paid = false,
    this.source = 'local',
  });

  Bill copyWith({bool? paid}) => Bill(
        path: path,
        modifiedMs: modifiedMs,
        issuer: issuer,
        amount: amount,
        currency: currency,
        dueMs: dueMs,
        periodMs: periodMs,
        paid: paid ?? this.paid,
        source: source,
      );

  Map<String, Object?> toJson() => {
        'path': path,
        'mod': modifiedMs,
        'issuer': issuer,
        'amount': amount,
        'cur': currency,
        'due': dueMs,
        'period': periodMs,
        'paid': paid,
        'src': source,
      };

  static Bill? fromJson(Object? raw) {
    if (raw is! Map || raw['path'] is! String) return null;
    return Bill(
      path: raw['path'] as String,
      modifiedMs: (raw['mod'] as num?)?.toInt() ?? 0,
      issuer: raw['issuer'] as String? ?? '',
      amount: (raw['amount'] as num?)?.toDouble(),
      currency: raw['cur'] as String? ?? 'TL',
      dueMs: (raw['due'] as num?)?.toInt(),
      periodMs: (raw['period'] as num?)?.toInt() ?? 0,
      paid: raw['paid'] == true,
      source: raw['src'] as String? ?? 'local',
    );
  }
}

/// Bir ayın gider özeti.
class BillMonth {
  final int year;
  final int month;
  final List<Bill> bills;
  const BillMonth(this.year, this.month, this.bills);

  /// Para birimi başına toplam (TL ile EUR toplanmaz).
  Map<String, double> get totals {
    final out = <String, double>{};
    for (final b in bills) {
      final a = b.amount;
      if (a == null) continue;
      out[b.currency] = (out[b.currency] ?? 0) + a;
    }
    return out;
  }
}

/// **Faturalar ve giderler** (2026-10-18, kullanıcının onayladığı öneri:
/// *"fatura ve makbuzdan tutar, son ödeme tarihi ve kurumu çıkarıp aylık
/// gider özeti göstermek, son günden önce hatırlatmak"*).
///
/// Adaylar AI analizinin "fatura"/"makbuz" dediği dosyalar (+ adında "fatura"
/// geçenler). Her dosya bir kez okunur:
/// - API anahtarı varsa metin Gemini'ye gider ve kurum/tutar/son ödeme/dönem
///   yapılandırılmış alınır,
/// - yoksa cihazda metinden tahmin edilir ([guessFromText]) — "TOPLAM 412,50
///   TL", "Son Ödeme Tarihi: 25.10.2026" kalıpları. Daha kaba ama ücretsiz ve
///   çevrimdışı.
///
/// Sonuç dosya yolu + değişme zamanıyla önbellekte: dosya değişmedikçe ikinci
/// kez okunmaz. Hatırlatmalar [reminders] ile yerel işe (bkz. `NativeExtras`)
/// yazılır; uygulama kapalıyken de son günden önce bildirim düşer.
class Bills extends ChangeNotifier {
  Bills._();

  static final instance = Bills._();

  static const _kBills = 'bills_v1';

  /// Hatırlatmanın kaç gün önceden başladığı.
  static const remindDays = 3;

  final Map<String, Bill> _bills = {};
  bool _loaded = false;
  bool _busy = false;

  bool get busy => _busy;
  List<Bill> get all => _bills.values.toList(growable: false);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kBills);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final e in list) {
            final b = Bill.fromJson(e);
            if (b != null) _bills[b.path] = b;
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kBills, jsonEncode([for (final b in _bills.values) b.toJson()]));
      await p.setString(kReminderPrefs, jsonEncode(reminders()));
    } catch (_) {}
  }

  /// Yerel işin (Kotlin) okuduğu hatırlatma listesi anahtarı.
  static const kReminderPrefs = 'bill_reminders';

  /// AI analizinde fatura/makbuz sayılan dosyalar.
  static List<AiRecord> candidates([Iterable<AiRecord>? source]) {
    final out = <AiRecord>[];
    for (final r in source ?? AiIndex.all()) {
      final type = AiBuckets.canonicalDocType(r.docType);
      final name = asciiFold(r.name);
      if (type == 'fatura' ||
          type == 'makbuz' ||
          name.contains('fatur') ||
          name.contains('makbuz') ||
          name.contains('invoice') ||
          name.contains('receipt')) {
        out.add(r);
      }
    }
    return out;
  }

  /// Okunmamış ya da değişmiş adaylar.
  List<AiRecord> pending([Iterable<AiRecord>? source]) => [
        for (final r in candidates(source))
          if (_bills[r.path]?.modifiedMs != r.modifiedMs) r,
      ];

  /// Bekleyen adayları okur. [gemini] null ise yalnız cihaz tahmini.
  Future<int> refresh({
    GeminiService? gemini,
    void Function(int done, int total)? onProgress,
    int? nowMs,
  }) async {
    await ensureLoaded();
    await AiIndex.ensureLoaded();
    if (_busy) return 0;
    _busy = true;
    notifyListeners();
    var done = 0;
    final todo = pending();
    try {
      // Silinmiş/artık aday olmayan dosyaların kaydı düşer.
      final alive = {for (final r in candidates()) r.path};
      _bills.removeWhere((path, _) => !alive.contains(path));
      for (final r in todo) {
        onProgress?.call(done, todo.length);
        final excerpt = await AiExtract.excerpt(AiBuckets.entryOf(r),
            maxChars: 3500);
        Bill? bill;
        if (gemini != null && !excerpt.isEmpty) {
          try {
            bill = await _askGemini(gemini, r, excerpt.text);
          } catch (_) {
            // Kota/ağ hatası: cihaz tahminine düş, iş durmasın.
          }
        }
        bill ??= guessFromText(r.path, r.modifiedMs, excerpt.text,
            fallbackIssuer: r.title);
        final old = _bills[r.path];
        _bills[r.path] = old != null && old.paid ? bill.copyWith(paid: true) : bill;
        done++;
      }
    } finally {
      _busy = false;
      await _save();
    }
    return done;
  }

  Future<Bill?> _askGemini(GeminiService gemini, AiRecord r, String text) async {
    final raw = await gemini.generateJson(
      systemInstruction:
          'Aşağıdaki metin bir fatura, makbuz ya da ödeme belgesinden alındı. '
          'Kurumu (faturayı kesen), ÖDENECEK TOPLAM tutarı, para birimini, son '
          'ödeme tarihini ve faturanın ait olduğu dönemi çıkar. Bilmediğini '
          'UYDURMA, boş bırak. Tarihler YYYY-AA-GG, dönem YYYY-AA.',
      prompt: 'Dosya: ${r.name}\n\n$text',
      schema: const {
        'type': 'object',
        'properties': {
          'kurum': {'type': 'string'},
          'tutar': {'type': 'number'},
          'para_birimi': {'type': 'string'},
          'son_odeme': {'type': 'string'},
          'donem': {'type': 'string'},
        },
      },
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final due = _parseIsoDate(decoded['son_odeme'] as String?);
    final period = _parseIsoDate('${decoded['donem'] ?? ''}-01');
    final amount = (decoded['tutar'] as num?)?.toDouble();
    return Bill(
      path: r.path,
      modifiedMs: r.modifiedMs,
      issuer: (decoded['kurum'] as String? ?? '').trim().isEmpty
          ? r.title
          : (decoded['kurum'] as String).trim(),
      amount: amount != null && amount > 0 ? amount : null,
      currency: _currency(decoded['para_birimi'] as String?),
      dueMs: due,
      periodMs: period ?? due ?? r.modifiedMs,
      source: 'ai',
    );
  }

  static String _currency(String? raw) {
    final c = asciiFold(raw ?? '').trim();
    if (c.isEmpty || c == 'tl' || c == 'try' || c.contains('lira')) return 'TL';
    if (c.contains('eur') || c == '€') return 'EUR';
    if (c.contains('usd') || c.contains('dolar') || c == r'$') return 'USD';
    return raw!.trim().toUpperCase();
  }

  static int? _parseIsoDate(String? raw) {
    final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw ?? '');
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d).millisecondsSinceEpoch;
  }

  /// **Cihaz üstünde tahmin** (API anahtarı yokken).
  ///
  /// Tutar: "toplam / ödenecek / tutar" sözcüğünü izleyen EN BÜYÜK sayı (ara
  /// toplam ve KDV satırları genelde daha küçük). Son ödeme: "son ödeme"
  /// sözcüğünü izleyen ilk tarih. Kurum: belgenin ilk anlamlı satırı.
  @visibleForTesting
  static Bill guessFromText(String path, int modifiedMs, String text,
      {String fallbackIssuer = ''}) {
    final folded = asciiFold(text);
    double? amount;
    for (final m in RegExp(
            r'(toplam|odenecek|tutar|total|amount)[^0-9\n]{0,40}([0-9][0-9.\s]*,[0-9]{2}|[0-9]+\.[0-9]{2})')
        .allMatches(folded)) {
      final v = parseAmount(m[2]!);
      if (v != null && (amount == null || v > amount)) amount = v;
    }
    int? due;
    final dueMatch = RegExp(
            r'son\s*odeme[^0-9\n]{0,30}(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})')
        .firstMatch(folded);
    if (dueMatch != null) {
      var y = int.parse(dueMatch[3]!);
      if (y < 100) y += 2000;
      final mo = int.parse(dueMatch[2]!), d = int.parse(dueMatch[1]!);
      if (mo >= 1 && mo <= 12 && d >= 1 && d <= 31) {
        due = DateTime(y, mo, d).millisecondsSinceEpoch;
      }
    }
    var issuer = fallbackIssuer.trim();
    if (issuer.isEmpty) {
      for (final line in text.split('\n')) {
        final t = line.trim();
        if (t.length >= 3 && RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(t)) {
          issuer = t.length > 40 ? t.substring(0, 40) : t;
          break;
        }
      }
    }
    return Bill(
      path: path,
      modifiedMs: modifiedMs,
      issuer: issuer,
      amount: amount,
      dueMs: due,
      periodMs: due ?? modifiedMs,
      currency: folded.contains('eur') && !folded.contains(' tl')
          ? 'EUR'
          : 'TL',
    );
  }

  /// "1.234,56" / "1234.56" / "412,50" → sayı.
  @visibleForTesting
  static double? parseAmount(String raw) {
    var s = raw.replaceAll(RegExp(r'\s'), '');
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    final v = double.tryParse(s);
    return v == null || v <= 0 ? null : v;
  }

  Future<void> setPaid(String path, bool paid) async {
    final b = _bills[path];
    if (b == null) return;
    _bills[path] = b.copyWith(paid: paid);
    await _save();
  }

  /// Ay ay gruplanmış giderler, en yeni ay önce.
  List<BillMonth> months() {
    final groups = <int, List<Bill>>{};
    for (final b in _bills.values) {
      final d = DateTime.fromMillisecondsSinceEpoch(b.periodMs);
      groups.putIfAbsent(d.year * 100 + d.month, () => []).add(b);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        BillMonth(k ~/ 100, k % 100,
            groups[k]!..sort((a, b) => b.periodMs.compareTo(a.periodMs))),
    ];
  }

  /// Ödenmemiş ve son ödemesi [remindDays] gün içinde (ya da geçmiş, en çok
  /// 7 gün) olan faturalar — yaklaşan önce.
  List<Bill> upcoming({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    const day = 24 * 60 * 60 * 1000;
    final out = [
      for (final b in _bills.values)
        if (!b.paid &&
            b.dueMs != null &&
            b.dueMs! >= now - 7 * day &&
            b.dueMs! <= now + remindDays * day)
          b,
    ]..sort((a, b) => a.dueMs!.compareTo(b.dueMs!));
    return out;
  }

  /// Yerel işin okuyacağı hatırlatmalar: ödenmemiş, son ödemesi gelecekte
  /// ya da son 7 günde olan her fatura (iş kendi gününe göre süzer).
  List<Map<String, Object>> reminders({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    const day = 24 * 60 * 60 * 1000;
    return [
      for (final b in _bills.values)
        if (!b.paid && b.dueMs != null && b.dueMs! >= now - 7 * day)
          {
            'title': b.issuer,
            'amount': b.amount == null ? '' : formatAmount(b.amount!, b.currency),
            'due': b.dueMs!,
          },
    ];
  }

  static String formatAmount(double v, String currency) {
    final whole = v.truncate();
    final cents = ((v - whole) * 100).round().abs().toString().padLeft(2, '0');
    final digits = whole.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
      buf.write(digits[i]);
    }
    return '${v < 0 ? '-' : ''}$buf,$cents $currency';
  }

  @visibleForTesting
  void debugReset() {
    _bills.clear();
    _loaded = false;
    _busy = false;
  }

  @visibleForTesting
  void debugPut(Bill b) => _bills[b.path] = b;
}
