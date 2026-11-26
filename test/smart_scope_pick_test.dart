import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/smart_scope_pick.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Neyi düzenleyelim?" (Aşama 1, 2026-11-22): tür/yer ayrımı, sayım,
/// seçim filtresi, öncelik sırası ve kredi tahmini.
void main() {
  FsEntry f(String path) => FsEntry(
      path: path, name: path.split('/').last, isDir: false,
      sizeBytes: 10, modifiedMs: 1);

  const root = '/storage/emulated/0';
  final pdf = f('$root/Download/fatura.pdf');
  final shot = f('$root/DCIM/Screenshots/a.png');
  final waImg = f('$root/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/b.jpg');
  final cam = f('$root/DCIM/Camera/c.jpg');
  final vid = f('$root/Download/v.mp4');
  final apk = f('$root/Download/x.apk');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmartScopePick.resetForTest();
  });

  test('tür ve yer', () {
    expect(SmartScopePick.groupOf(pdf.path), SmartGroup.docs);
    expect(SmartScopePick.groupOf(shot.path), SmartGroup.screenshots);
    expect(SmartScopePick.groupOf(waImg.path), SmartGroup.images);
    expect(SmartScopePick.groupOf(vid.path), SmartGroup.videos);
    expect(SmartScopePick.groupOf(apk.path), SmartGroup.packages);
    expect(SmartScopePick.sourceOf(waImg.path), SmartSource.whatsapp);
    expect(SmartScopePick.sourceOf(cam.path), SmartSource.camera);
    expect(SmartScopePick.sourceOf(shot.path), SmartSource.other);
    expect(SmartScopePick.sourceOf(pdf.path), SmartSource.download);
  });

  test('sayım: toplam ve kalan; desteklenmeyen sayılmaz', () {
    final c = SmartScopePick.tally(
      [pdf, shot, waImg, vid, f('$root/Download/kod.exe')],
      (_) => true,
      (e) => SmartScopePick.groupOf(e.path) != null,
      (e) => e != pdf,
    );
    expect(c.sum().total, 4);
    expect(c.sum().remaining, 3);
    expect(c.groupTotal(SmartGroup.docs), 1);
    expect(c.sourceTotal(SmartSource.download), 2);
  });

  test('kapatılan tür ve yer turda sorulmaz', () async {
    await SmartScopePick.read();
    expect(SmartScopePick.allows(pdf.path), isTrue);
    await SmartScopePick.setGroup(SmartGroup.docs, false);
    expect(SmartScopePick.allows(pdf.path), isFalse);
    await SmartScopePick.setSource(SmartSource.whatsapp, false);
    expect(SmartScopePick.allows(waImg.path), isFalse);
    expect(SmartScopePick.allows(vid.path), isTrue);
    // Kalıcı: yeniden okununca aynı.
    SmartScopePick.resetForTest();
    await SmartScopePick.read();
    expect(SmartScopePick.groupOn(SmartGroup.docs), isFalse);
    expect(SmartScopePick.sourceOn(SmartSource.whatsapp), isFalse);
  });

  test('sıra: önce belge ve ekran görüntüsü, video en sonda', () {
    final o = SmartScopePick.ordered([vid, waImg, pdf, shot]);
    expect(o, [pdf, shot, waImg, vid]);
  });

  test('kredi tahmini: 500 ücretsiz, sonra en küçük yeten paket', () {
    expect(SmartCreditDraft.packFor(400), isNull);
    expect(SmartCreditDraft.packFor(1200), (1000, 25));
    expect(SmartCreditDraft.packFor(3000), (5000, 100));
    expect(SmartCreditDraft.packFor(50000), (10000, 200));
  });
}
