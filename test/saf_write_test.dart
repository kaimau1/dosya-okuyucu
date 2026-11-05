import 'package:dosya_okuyucu/screens/fm/dual_pane_screen.dart';
import 'package:dosya_okuyucu/services/fm/app_storage_service.dart';
import 'package:dosya_okuyucu/services/fm/saf_write.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'content://com.android.externalstorage.documents/tree/';

/// Faz 41 / 1: SD kart SAF yazma eşlemesi + çift bölme kararları.
void main() {
  group('SafWrite', () {
    test('birim yolu ayrıştırma', () {
      final v = SafWrite.splitVolumePath('/storage/1A2B-3C4D/DCIM/Tatil')!;
      expect(v.$1, '1A2B-3C4D');
      expect(v.$2, ['DCIM', 'Tatil']);
      expect(SafWrite.splitVolumePath('/storage/emulated/0/Download'), isNull);
      expect(SafWrite.splitVolumePath('/data/user/0/x'), isNull);
    });

    test('hedef en dar izinli ağaca eşlenir', () {
      const roots = [
        SafRoot(uri: '${_base}1A2B-3C4D%3A', name: 'SD'),
        SafRoot(uri: '${_base}1A2B-3C4D%3ADCIM', name: 'DCIM'),
        SafRoot(uri: '${_base}9999-0000%3A', name: 'USB'),
      ];
      final r = SafWrite.resolve('/storage/1A2B-3C4D/DCIM/Tatil/2026', roots);
      expect(r!.$1, '${_base}1A2B-3C4D%3ADCIM');
      expect(r.$2, ['Tatil', '2026']);
      final root = SafWrite.resolve('/storage/1A2B-3C4D/Muzik', roots);
      expect(root!.$1, '${_base}1A2B-3C4D%3A');
      expect(root.$2, ['Muzik']);
    });

    test('izin yoksa, salt okunur ağaç ya da başka birim → null', () {
      const roots = [
        SafRoot(uri: '${_base}1A2B-3C4D%3AMuzik', name: 'Müzik'),
        SafRoot(uri: '${_base}1A2B-3C4D%3A', name: 'SD', writable: false),
      ];
      expect(SafWrite.resolve('/storage/1A2B-3C4D/DCIM', roots), isNull);
      expect(SafWrite.resolve('/storage/emulated/0/DCIM', roots), isNull);
    });

    test('iç bellekte SAF gerekmez (deneme dosyası yazılmaz)', () async {
      SafWrite.resetForTest();
      expect(await SafWrite.needsSaf('/storage/emulated/0/Download'), isFalse);
    });
  });

  group('çift bölme', () {
    test('seçim yoksa, aynı klasöre ya da kendi içine aktarım yok', () {
      final m = DualPaneModel('/s/a', '/s/b');
      expect(m.canTransfer(), isFalse);
      m.a.selected.add('/s/a/x.txt');
      expect(m.canTransfer(), isTrue);
      m.b.path = '/s/a';
      expect(m.canTransfer(), isFalse);
      m.b.path = '/s/a/klasor/alt';
      m.a.selected
        ..clear()
        ..add('/s/a/klasor');
      expect(m.canTransfer(), isFalse);
    });

    test('değiştir: yollar yer değiştirir, seçim temizlenir', () {
      final m = DualPaneModel('/s/a', '/s/b');
      m.a.selected.add('/s/a/x');
      m.swap();
      expect((m.a.path, m.b.path), ('/s/b', '/s/a'));
      expect(m.a.selected, isEmpty);
    });

    test('üst klasör birim kökünde durur', () {
      expect(FsScanRoots.floorOf('/storage/emulated/0/DCIM/x'),
          '/storage/emulated/0');
      expect(FsScanRoots.floorOf('/storage/1A2B-3C4D/DCIM'),
          '/storage/1A2B-3C4D');
      final pane = PaneState('/storage/emulated/0');
      expect(pane.parent('/storage/emulated/0'), isNull);
      expect(PaneState('/storage/emulated/0/DCIM').parent('/storage/emulated/0'),
          '/storage/emulated/0');
    });
  });
}
