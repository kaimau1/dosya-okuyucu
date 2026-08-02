import 'package:dosya_okuyucu/services/sheet_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shiftFormula', () {
    test('göreli başvuru kayar, mutlak olan durur', () {
      expect(shiftFormula('A1+B1', 0, 1), 'B1+C1');
      expect(shiftFormula('A1+B1', 1, 0), 'A2+B2');
      expect(shiftFormula(r'$A$1+B1', 2, 3), r'$A$1+E3');
      // Karışık kilit: sütun sabit, satır kayar.
      expect(shiftFormula(r'$A1', 1, 5), r'$A2');
      expect(shiftFormula(r'A$1', 1, 5), r'F$1');
    });

    test('aralık ve işlev adı bozulmaz', () {
      expect(shiftFormula('TOPLA(A1:A5)', 1, 0), 'TOPLA(A2:A6)');
      // İşlev adının içindeki harf+rakam başvuru sanılmamalı.
      expect(shiftFormula('LOG10(A1)', 1, 0), 'LOG10(A2)');
      expect(shiftFormula('EĞER(A1>0;A1;0)', 1, 0), 'EĞER(A2>0;A2;0)');
    });

    test('metin sabitinin içine dokunulmaz', () {
      expect(shiftFormula('BİRLEŞTİR("A1";B2)', 1, 0), 'BİRLEŞTİR("A1";B3)');
      // Kaçırılmış tırnak ("") ayrıştırmayı bozmamalı.
      expect(shiftFormula('"a""b"&C1', 0, 1), '"a""b"&D1');
    });

    test('tek tırnaklı sayfa adı korunur, başvurusu kayar', () {
      expect(shiftFormula("'Ocak Ayı'!A1", 1, 0), "'Ocak Ayı'!A2");
    });

    test('sayfayı terk eden başvuru #BAŞV! olur', () {
      expect(shiftFormula('A1', -1, 0), '#BAŞV!');
      expect(shiftFormula('A1', 0, -1), '#BAŞV!');
      // Kilitliyse taşmaz.
      expect(shiftFormula(r'$A$1', -5, -5), r'$A$1');
    });

    test('kaydırma yoksa metin aynen döner', () {
      expect(shiftFormula('A1+B2', 0, 0), 'A1+B2');
    });

    test('kapanmayan tırnakta sonsuz döngüye girmez', () {
      expect(shiftFormula('A1&"açık', 1, 0), 'A2&"açık');
    });
  });

  group('SheetClip / pasteCells', () {
    SheetClip clip(List<List<String>> v,
            {CellRef origin = const CellRef(0, 0), bool cut = false}) =>
        SheetClip(values: v, origin: origin, cut: cut);

    test('TSV gidiş-dönüş', () {
      final c = clip([
        ['a', 'b'],
        ['1', '2'],
      ]);
      expect(c.toTsv(), 'a\tb\n1\t2');
      final back = SheetClip.fromTsv(c.toTsv())!;
      expect(back.values, c.values);
      // Sondaki tek satır sonu ayraçtır, boş satır üretmemeli.
      expect(SheetClip.fromTsv('a\tb\n')!.values, [
        ['a', 'b']
      ]);
      expect(SheetClip.fromTsv(''), isNull);
      // Windows satır sonu.
      expect(SheetClip.fromTsv('a\r\nb')!.values.length, 2);
    });

    test('tek hücre kopyala-yapıştır formülü kaydırır', () {
      final c = clip([
        ['=A1*2']
      ], origin: const CellRef(0, 1)); // B1'den kopyalandı
      final out = pasteCells(c, const CellRange(0, 2, 0, 2)); // C1'e
      expect(out[const CellRef(0, 2)], '=B1*2');
    });

    test('KESME formülü kaydırmaz (taşıma, kopyalama değil)', () {
      final c = clip([
        ['=A1*2']
      ], origin: const CellRef(0, 1), cut: true);
      final out = pasteCells(c, const CellRange(5, 5, 5, 5));
      expect(out[const CellRef(5, 5)], '=A1*2');
    });

    test('blok hedefe sığmıyorsa sol üstten bir kez yazılır', () {
      final c = clip([
        ['a', 'b'],
        ['c', 'd'],
      ]);
      final out = pasteCells(c, const CellRange(1, 1, 1, 1)); // tek hücre seçili
      expect(out.length, 4);
      expect(out[const CellRef(1, 1)], 'a');
      expect(out[const CellRef(2, 2)], 'd');
    });

    test('hedef bloğun TAM KATIYSA blok tekrarlanır (Excel kuralı)', () {
      final c = clip([
        ['a', 'b']
      ]);
      final out = pasteCells(c, const CellRange(0, 0, 0, 3)); // 1x4
      expect(out.length, 4);
      expect(out[const CellRef(0, 0)], 'a');
      expect(out[const CellRef(0, 1)], 'b');
      expect(out[const CellRef(0, 2)], 'a');
      expect(out[const CellRef(0, 3)], 'b');
      // Tam kat DEĞİLSE tekrar yok.
      final tek = pasteCells(c, const CellRange(0, 0, 0, 2));
      expect(tek.length, 2);
    });

    test('düzensiz satır uzunluğu boşla tamamlanır', () {
      final c = clip([
        ['a', 'b'],
        ['c'],
      ]);
      final out = pasteCells(c, const CellRange(0, 0, 0, 0));
      expect(out[const CellRef(1, 1)], '');
    });
  });

  group('FillSeries.extend', () {
    test('boş kaynak boş üretir, count<=0 boş liste', () {
      expect(FillSeries.extend(const [], 3), ['', '', '']);
      expect(FillSeries.extend(const ['1'], 0), isEmpty);
    });

    test('tek sayı KOPYALANIR (Excel davranışı)', () {
      expect(FillSeries.extend(['5'], 3), ['5', '5', '5']);
    });

    test('iki sayı aritmetik seri kurar', () {
      expect(FillSeries.extend(['1', '2'], 3), ['3', '4', '5']);
      expect(FillSeries.extend(['10', '20'], 2), ['30', '40']);
      // Azalan seri.
      expect(FillSeries.extend(['10', '8'], 3), ['6', '4', '2']);
      // Ondalık adım.
      expect(FillSeries.extend(['1', '1.5'], 2), ['2', '2.5']);
    });

    test('sabit fark yoksa blok tekrarlanır', () {
      expect(FillSeries.extend(['1', '5', '2'], 4), ['1', '5', '2', '1']);
    });

    test('geriye doğru seri ızgara sırasında döner', () {
      // A3=3, A4=4 kaynak; yukarı sürüklenince A1,A2 = 1,2 olmalı.
      expect(FillSeries.extend(['3', '4'], 2, backwards: true), ['1', '2']);
    });

    test('ISO tarih gün adımıyla ilerler', () {
      expect(FillSeries.extend(['2026-08-02'], 2), ['2026-08-03', '2026-08-04']);
      expect(FillSeries.extend(['2026-01-01', '2026-01-08'], 2),
          ['2026-01-15', '2026-01-22']);
      // Ay sonu taşması.
      expect(FillSeries.extend(['2026-01-31'], 1), ['2026-02-01']);
    });

    test('ay ve gün adları listede döner (TR + EN)', () {
      expect(FillSeries.extend(['Ocak'], 2), ['Şubat', 'Mart']);
      expect(FillSeries.extend(['Kasım'], 3), ['Aralık', 'Ocak', 'Şubat']);
      expect(FillSeries.extend(['Pazartesi', 'Çarşamba'], 2), ['Cuma', 'Pazar']);
      expect(FillSeries.extend(['Jan'], 2), ['Feb', 'Mar']);
      expect(FillSeries.extend(['Monday'], 1), ['Tuesday']);
      // Büyük/küçük harf duyarsız (Türkçe İ/ı tuzağı dahil).
      expect(FillSeries.extend(['ocak'], 1), ['Şubat']);
      expect(FillSeries.extend(['NİSAN'], 1), ['Mayıs']);
    });

    test('sonu sayıyla biten metin ilerler, sıfır dolgusu korunur', () {
      expect(FillSeries.extend(['Ürün 1'], 2), ['Ürün 2', 'Ürün 3']);
      expect(FillSeries.extend(['Q1', 'Q3'], 2), ['Q5', 'Q7']);
      expect(FillSeries.extend(['Kod-007'], 2), ['Kod-008', 'Kod-009']);
      // Ön ek farklıysa desen yok → tekrar.
      expect(FillSeries.extend(['A1', 'B2'], 2), ['A1', 'B2']);
    });

    test('desensiz metin bloğu tekrarlanır', () {
      expect(FillSeries.extend(['elma', 'armut'], 3),
          ['elma', 'armut', 'elma']);
    });

    test('formül göreli başvuruyla kopyalanır', () {
      // A1 = "=B1*2"; aşağı sürükleyince =B2*2, =B3*2.
      expect(FillSeries.extend(['=B1*2'], 2), ['=B2*2', '=B3*2']);
      // İki hücrelik blok: kaynak 2 satır, üretilenler 2 ve 3 satır kayar.
      expect(FillSeries.extend(['=A1', '=A2'], 2), ['=A3', '=A4']);
      // Mutlak başvuru sabit kalır.
      expect(FillSeries.extend([r'=$B$1*A1'], 2), [r'=$B$1*A2', r'=$B$1*A3']);
    });

    test('formül yatay sürüklemede SÜTUN yönünde kayar', () {
      expect(FillSeries.extend(['=A1'], 2, horizontal: true), ['=B1', '=C1']);
    });

    test('formül geriye sürüklemede ızgara sırasında ve doğru kayar', () {
      // A3 = "=B3"; yukarı iki hücre → A1="=B1", A2="=B2".
      expect(FillSeries.extend(['=B3'], 2, backwards: true), ['=B1', '=B2']);
    });
  });

  group('autoSumRange', () {
    bool numericAt(Set<String> cells) => false; // yer tutucu (kullanılmıyor)

    test('üstteki bitişik sayı bloğunu seçer', () {
      // A1..A3 sayı, A4'e Σ.
      final r = autoSumRange(3, 0, (row, col) => col == 0 && row <= 2);
      expect(r, const CellRange(0, 0, 2, 0));
    });

    test('üstte sayı yoksa SOLDAKİ bloğa bakar', () {
      // B5..D5 sayı, E5'e Σ.
      final r = autoSumRange(4, 4, (row, col) => row == 4 && col >= 1 && col <= 3);
      expect(r, const CellRange(4, 1, 4, 3));
    });

    test('bitişik olmayan blok kesilir', () {
      // A1 sayı, A2 boş, A3 sayı → A4'ten bakınca yalnız A3 alınır.
      final r = autoSumRange(3, 0, (row, col) => col == 0 && (row == 0 || row == 2));
      expect(r, const CellRange(2, 0, 2, 0));
    });

    test('hiç sayı yoksa null', () {
      expect(autoSumRange(0, 0, (_, __) => false), isNull);
      expect(autoSumRange(5, 5, (_, __) => false), isNull);
    });

    test('kenar hücrede taşma yok', () {
      expect(autoSumRange(0, 0, (_, __) => true), isNull);
      expect(numericAt(const {}), isFalse);
    });
  });

  group('SheetUndoStack', () {
    /// Basit bir hücre haritası üzerinde adım kurar.
    (SheetValueStep, Map<String, String>) stepOn(
      Map<String, String> cells,
      Map<CellRef, String> after, {
      String label = 'test',
    }) {
      final before = {
        for (final k in after.keys) k: cells[k.toString()] ?? '',
      };
      return (
        SheetValueStep(
          label: label,
          before: before,
          after: after,
          write: (at, v) => cells[at.toString()] = v,
        ),
        cells
      );
    }

    test('uygula → geri al → yinele döngüsü', () {
      final cells = <String, String>{'A1': 'eski'};
      final (step, _) = stepOn(cells, {const CellRef(0, 0): 'yeni'});
      final stack = SheetUndoStack();

      expect(stack.canUndo, isFalse);
      stack.push(step);
      expect(cells['A1'], 'yeni');
      expect(stack.canUndo, isTrue);

      stack.undo();
      expect(cells['A1'], 'eski');
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isTrue);

      stack.redo();
      expect(cells['A1'], 'yeni');
      expect(stack.canRedo, isFalse);
    });

    test('yeni adım yineleme dalını siler', () {
      final cells = <String, String>{};
      final stack = SheetUndoStack();
      stack.push(stepOn(cells, {const CellRef(0, 0): 'a'}).$1);
      stack.undo();
      expect(stack.canRedo, isTrue);
      stack.push(stepOn(cells, {const CellRef(1, 1): 'b'}).$1);
      expect(stack.canRedo, isFalse);
    });

    test('sınır aşılınca en eski adım düşer', () {
      final cells = <String, String>{};
      final stack = SheetUndoStack(limit: 2);
      for (var i = 0; i < 5; i++) {
        stack.push(stepOn(cells, {CellRef(i, 0): '$i'}).$1);
      }
      expect(stack.depth, 2);
    });

    test('boş yığında geri al/yinele null döner, çökmez', () {
      final stack = SheetUndoStack();
      expect(stack.undo(), isNull);
      expect(stack.redo(), isNull);
    });

    test('çok hücreli adım tek seferde geri alınır', () {
      final cells = <String, String>{'A1': '1', 'B1': '2'};
      final stack = SheetUndoStack();
      stack.push(stepOn(cells, {
        const CellRef(0, 0): '',
        const CellRef(0, 1): '',
      }).$1);
      expect(cells['A1'], '');
      stack.undo();
      expect(cells['A1'], '1');
      expect(cells['B1'], '2');
    });

    test('hiçbir şey değiştirmeyen adım isNoop der', () {
      final cells = <String, String>{'A1': 'x'};
      final (same, _) = stepOn(cells, {const CellRef(0, 0): 'x'});
      expect(same.isNoop, isTrue);
      final (diff, _) = stepOn(cells, {const CellRef(0, 0): 'y'});
      expect(diff.isNoop, isFalse);
    });

    test('clear her iki dalı da boşaltır', () {
      final cells = <String, String>{};
      final stack = SheetUndoStack();
      stack.push(stepOn(cells, {const CellRef(0, 0): 'a'}).$1);
      stack.undo();
      stack.clear();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
    });
  });

  group('CellRef / CellRange', () {
    test('sütun adı 26 sınırını doğru geçer', () {
      expect(CellRef.colName(0), 'A');
      expect(CellRef.colName(25), 'Z');
      expect(CellRef.colName(26), 'AA');
      expect(CellRef.colName(701), 'ZZ');
      expect(CellRef.colName(702), 'AAA');
      expect(const CellRef(0, 2).toString(), 'C1');
    });

    test('aralık köşelerden normalleşir', () {
      final a = CellRange.between(5, 3, 1, 1);
      expect(a, const CellRange(1, 1, 5, 3));
      expect(a.rows, 5);
      expect(a.cols, 3);
      expect(a.cellCount, 15);
      expect(a.contains(3, 2), isTrue);
      expect(a.contains(0, 2), isFalse);
    });
  });
}
