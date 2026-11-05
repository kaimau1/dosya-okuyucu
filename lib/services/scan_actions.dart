import 'dart:convert' show utf8;
import 'dart:io';

import 'package:path/path.dart' as p;

/// Fiş/faturadan çıkarılan gider (Faz 35 / ek 6: "makbuz → Excel gider
/// satırı"). Metin cihazda ayrıştırılır, hiçbir yere gönderilmez.
class ReceiptInfo {
  final DateTime? date;
  final double? total;
  final String? merchant;
  const ReceiptInfo({this.date, this.total, this.merchant});

  bool get isEmpty => date == null && total == null;

  static final _date = RegExp(r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})\b');
  static final _totalLine = RegExp(
      r'(GENEL\s*TOPLAM|TOPLAM|TOTAL|TUTAR|ÖDENECEK|ODENECEK)',
      caseSensitive: false);
  static final _amount = RegExp(r'(\d{1,3}(?:[.\s]\d{3})*(?:[.,]\d{2})|\d+[.,]\d{2})');

  /// Tarih: ilk geçerli gg.aa.yyyy; tutar: "TOPLAM" geçen satırlardaki en
  /// büyük tutar (yoksa belgedeki en büyük); satıcı: ilk harf ağırlıklı satır.
  static ReceiptInfo parse(String text) {
    final lines = [
      for (final l in text.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    DateTime? date;
    for (final m in _date.allMatches(text)) {
      final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      if (d < 1 || d > 31 || mo < 1 || mo > 12 || y < 1990 || y > 2100) continue;
      date = DateTime(y, mo, d);
      break;
    }
    double? best;
    double? any;
    for (final l in lines) {
      final isTotal = _totalLine.hasMatch(l);
      for (final m in _amount.allMatches(l)) {
        final v = _toDouble(m.group(1)!);
        if (v == null) continue;
        if (any == null || v > any) any = v;
        if (isTotal && (best == null || v > best)) best = v;
      }
    }
    String? merchant;
    for (final l in lines.take(4)) {
      final letters = RegExp(r'\p{L}', unicode: true).allMatches(l).length;
      if (letters >= 3 && letters >= l.length * 0.6) {
        merchant = l;
        break;
      }
    }
    return ReceiptInfo(date: date, total: best ?? any, merchant: merchant);
  }

  static double? _toDouble(String s) {
    final t = s.replaceAll(' ', '');
    final dec = t.length >= 3 ? t[t.length - 3] : '';
    final body = dec == ',' || dec == '.'
        ? '${t.substring(0, t.length - 3).replaceAll(RegExp(r'[.,]'), '')}.${t.substring(t.length - 2)}'
        : t.replaceAll(RegExp(r'[.,]'), '');
    return double.tryParse(body);
  }

  /// CSV satırı (`;` ayraçlı — Türkçe Excel varsayılanı).
  String toCsvRow(String fileName) {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final d = date;
    final day = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}.'
            '${d.month.toString().padLeft(2, '0')}.${d.year}';
    final amount = total == null ? '' : total!.toStringAsFixed(2).replaceAll('.', ',');
    return [q(day), q(merchant ?? ''), q(amount), q(fileName)].join(';');
  }
}

abstract final class ScanActions {
  static const expenseFile = 'Giderler.csv';
  static const expenseHeader = '"Tarih";"Satıcı";"Tutar";"Dosya"';

  /// [dir]/Giderler.csv'ye satır ekler (yoksa başlıkla, UTF-8 BOM'lu kurar);
  /// dosya yolunu döndürür.
  static Future<String> appendExpense(
      String dir, ReceiptInfo info, String fileName) async {
    final path = p.join(dir, expenseFile);
    final file = File(path);
    final row = '${info.toCsvRow(fileName)}\r\n';
    if (!await file.exists()) {
      await file.writeAsBytes(
          [0xEF, 0xBB, 0xBF, ...utf8.encode('$expenseHeader\r\n$row')],
          flush: true);
    } else {
      await file.writeAsString(row, mode: FileMode.append, flush: true);
    }
    return path;
  }
}
