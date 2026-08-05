import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/pdf/pdf_text_replace.dart';

/// **Kademeli eşleşme + konumla hedefleme** (2026-08-05 "isabet" turu).
///
/// Kullanıcı bulgusu: *"yazıları değiştirirken şu an yeterli değil, büyük
/// küçük yazım"* — pdfium'un çıkardığı (seçilen) metin ile akışın çözümü
/// harf büyüklüğünde/tipografik karakterlerde ayrışınca "bulunamadı" çıkıyor,
/// aynı kelime iki kez geçince de yanlış olan değişebiliyordu.
void main() {
  List<int> content(String s) => latin1.encode(s);
  String decoded(List<int> c) => latin1.decode(c, allowInvalid: true);

  test('büyük/küçük harf ayrışması 3. geçişte yakalanır (Türkçe I→ı)', () {
    // Akışta BÜYÜK, kullanıcının seçtiği metin küçük.
    final r = replaceTextInContent(
      content('BT /F1 10 Tf 1 0 0 1 50 700 Tm (ISTANBUL RAPORU) Tj ET'),
      'ıstanbul',
      'Ankara',
    );
    expect(decoded(r.content), contains('(Ankara RAPORU)'));
    expect(r.matchCount, 1);
  });

  test('birebir eşleşme varken harf-duyarsız geçiş devreye GİRMEZ', () {
    // Hem 'Nakit' hem 'NAKİT' var; kullanıcı 'Nakit' seçti → birebir olan
    // değişmeli, harf katlaması diğerini ezmemeli.
    final r = replaceTextInContent(
      content('BT /F1 10 Tf 1 0 0 1 50 700 Tm (NAKIT) Tj '
          '1 0 0 1 50 600 Tm (Nakit) Tj ET'),
      'Nakit',
      'Kart',
    );
    final out = decoded(r.content);
    expect(out, contains('(NAKIT)'), reason: 'büyük olan dokunulmamalı');
    expect(out, contains('(Kart)'));
  });

  test('tipografik kesme işareti katlanır (WinAnsi ’ = seçimdeki \')', () {
    // 0x92: WinAnsi'de U+2019 (’). Kullanıcı klavyeden düz ' yazar/seçer.
    final bytes = [
      ...latin1.encode('BT /F1 10 Tf 1 0 0 1 50 700 Tm (Ali'),
      0x92,
      ...latin1.encode('nin) Tj ET'),
    ];
    final r = replaceTextInContent(bytes, "Ali'nin", "Veli'nin");
    expect(r.encoding, 'WinAnsi');
    expect(decoded(r.content), contains("(Veli'nin)"),
        reason: 'yeni metin kullanıcının yazdığı gibi (düz kesme) girer');
  });

  test('aynı kelime iki kez: seçimin KONUMUNA yakın olan değişir', () {
    final src = content('BT /F1 10 Tf 1 0 0 1 50 700 Tm (fatura) Tj '
        '1 0 0 1 50 100 Tm (fatura) Tj ET');
    final r = replaceTextInContent(
      src,
      'fatura',
      'makbuz',
      nearX: 60,
      nearY: 102, // alttaki satırın hizası
    );
    final out = decoded(r.content);
    expect(out, contains('1 0 0 1 50 700 Tm (fatura)'),
        reason: 'üstteki (uzak) eşleşme olduğu gibi kalmalı');
    expect(out, contains('1 0 0 1 50 100 Tm (makbuz)'));
    expect(r.matchCount, 2, reason: 'belirsizlik çağırana bildirilmeli');
  });

  test('konum verilmezse ilk eşleşme değişir (eski davranış korunur)', () {
    final r = replaceTextInContent(
      content('BT /F1 10 Tf 1 0 0 1 50 700 Tm (fatura) Tj '
          '1 0 0 1 50 100 Tm (fatura) Tj ET'),
      'fatura',
      'makbuz',
    );
    final out = decoded(r.content);
    expect(out, contains('1 0 0 1 50 700 Tm (makbuz)'));
    expect(out, contains('1 0 0 1 50 100 Tm (fatura)'));
  });

  test('bağlam öneki konumdan da önce gelir', () {
    // Kullanıcı "onay fatura"daki fatura'yı seçti; parmağı alttaki kopyaya
    // daha yakın olsa bile bağlam kazanır (bağlam daha güçlü kanıttır).
    final r = replaceTextInContent(
      content('BT /F1 10 Tf 1 0 0 1 50 700 Tm (onay fatura) Tj '
          '1 0 0 1 50 100 Tm (ret fatura) Tj ET'),
      'fatura',
      'makbuz',
      precedingText: 'onay',
      nearX: 50,
      nearY: 100,
    );
    final out = decoded(r.content);
    expect(out, contains('(onay makbuz)'));
    expect(out, contains('(ret fatura)'));
  });

  test('harf-duyarsız geçişte de bağlam çalışır', () {
    final r = replaceTextInContent(
      content('BT /F1 10 Tf 1 0 0 1 50 700 Tm (ONAY FATURA) Tj '
          '1 0 0 1 50 100 Tm (RET FATURA) Tj ET'),
      'fatura',
      'Makbuz',
      precedingText: 'ret',
    );
    final out = decoded(r.content);
    expect(out, contains('(ONAY FATURA)'));
    expect(out, contains('(RET Makbuz)'));
  });
}
