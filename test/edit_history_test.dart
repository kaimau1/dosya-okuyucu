import 'package:dosya_okuyucu/core/edit/edit_history.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditHistory', () {
    test('ardışık yazım tek adım; kelime sınırında kesilir', () {
      final h = EditHistory();
      var text = const TextEditingValue();
      final t0 = DateTime(2026, 10, 23, 12);
      void type(String s, int ms) {
        final before = text;
        text = TextEditingValue(
            text: s, selection: TextSelection.collapsed(offset: s.length));
        h.record(TextEditStep(
            target: 'p1',
            before: before,
            after: text,
            write: (v) => text = v,
            at: t0.add(Duration(milliseconds: ms))));
      }

      type('M', 0);
      type('Me', 100);
      type('Mer', 200);
      type('Mer ', 300);
      type('Mer h', 400); // yeni kelime → yeni adım
      type('Mer ha', 500);
      expect(h.depth, 2);
      h.undo();
      expect(text.text, 'Mer ');
      expect(text.selection.baseOffset, 4, reason: 'imleç de geri gelir');
      h.undo();
      expect(text.text, '');
      h.redo();
      expect(text.text, 'Mer ');
    });

    test('duraklama ve başka hedef birleşmeyi keser', () {
      final h = EditHistory();
      final t0 = DateTime(2026);
      TextEditStep step(Object target, String a, String b, int ms) =>
          TextEditStep(
              target: target,
              before: TextEditingValue(text: a),
              after: TextEditingValue(text: b),
              write: (_) {},
              at: t0.add(Duration(milliseconds: ms)));
      h.record(step('a', '', 'x', 0));
      h.record(step('a', 'x', 'xy', 2000)); // > 1 sn
      h.record(step('b', '', 'z', 2100)); // başka hedef
      expect(h.depth, 3);
      h.breakMerge();
      h.record(step('b', 'z', 'zz', 2200));
      expect(h.depth, 4);
    });

    test('kirli durum: kaydet, geri al → kirli, yinele → temiz', () {
      final h = EditHistory();
      var v = 0;
      h.push(CallbackEdit('x', () => v = 1, () => v = 0));
      expect(h.isDirty, isTrue);
      h.markSaved();
      expect(h.isDirty, isFalse);
      h.undo();
      expect(v, 0);
      expect(h.isDirty, isTrue);
      h.redo();
      expect(h.isDirty, isFalse);
    });

    test('dinlenebilir canUndo/canRedo', () {
      final h = EditHistory();
      final seen = <bool>[];
      h.canUndoListenable.addListener(() => seen.add(h.canUndo));
      h.push(CallbackEdit('x', () {}, () {}));
      h.undo();
      expect(seen, [true, false]);
      expect(h.canRedoListenable.value, isTrue);
    });

    test('sınır ve bellek tavanı en eski adımları düşürür', () {
      final h = EditHistory(limit: 3);
      for (var i = 0; i < 5; i++) {
        h.push(CallbackEdit('$i', () {}, () {}));
      }
      expect(h.depth, 3);
      final m = EditHistory(maxBytes: 300);
      for (var i = 0; i < 10; i++) {
        m.record(TextEditStep(
            target: i,
            before: const TextEditingValue(),
            after: TextEditingValue(text: 'x' * 50),
            write: (_) {}));
      }
      expect(m.depth, lessThan(10));
      expect(m.depth, greaterThan(0));
    });

    test('CompositeEdit ters sırada geri alır', () {
      final log = <String>[];
      final c = CompositeEdit('c', [
        CallbackEdit('a', () => log.add('+a'), () => log.add('-a')),
        CallbackEdit('b', () => log.add('+b'), () => log.add('-b')),
      ]);
      final h = EditHistory()..push(c);
      h.undo();
      expect(log, ['+a', '+b', '-b', '-a']);
    });
  });

  group('SnapshotHistory', () {
    test('her yol sınırı uygular ve yinele çalışır (IM4)', () {
      final h = SnapshotHistory<int>(limit: 30);
      for (var i = 0; i < 50; i++) {
        h.push(i);
      }
      expect(h.depth, 30);
      expect(h.undo(50), 49);
      expect(h.redo(49), 50);
      h.push(7);
      expect(h.canRedo, isFalse);
    });
  });
}
