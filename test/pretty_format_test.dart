import 'package:dosya_okuyucu/core/pretty_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-06 denetim turu: `.json`/`.xml` dosyaları gerçek hayatta TEK
/// SATIR geliyor (API cevabı, yedek dökümü) ve ekranda upuzun tek bir satır
/// olarak görünüyordu.
void main() {
  test('tek satır JSON girintilenir', () {
    const raw = '{"ad":"Fatih","liste":[1,2],"ic":{"a":true}}';
    final out = PrettyFormat.json(raw);
    expect(out.split('\n').length, greaterThan(5));
    expect(out, contains('  "ad": "Fatih"'));
  });

  test('Türkçe karakterler bozulmaz', () {
    final out = PrettyFormat.json('{"şehir":"İstanbul"}');
    expect(out, contains('İstanbul'));
    expect(out, contains('şehir'));
  });

  test('BOZUK JSON aynen döner (veri kaybı yok)', () {
    const broken = '{"ad": "yarım kal';
    expect(PrettyFormat.json(broken), broken);
  });

  test('XML etiketleri satırlara ayrılır ve girintilenir', () {
    const raw = '<kok><cocuk a="1">metin</cocuk><bos/></kok>';
    final out = PrettyFormat.xml(raw);
    final lines = out.split('\n');
    expect(lines.first, '<kok>');
    expect(lines.any((l) => l.startsWith('  <cocuk')), isTrue);
    expect(lines.any((l) => l.trim() == 'metin'), isTrue);
    expect(lines.last, '</kok>');
  });

  test('XML bildirimi derinliği artırmaz', () {
    final out = PrettyFormat.xml('<?xml version="1.0"?><a><b/></a>');
    final lines = out.split('\n');
    expect(lines[0], '<?xml version="1.0"?>');
    expect(lines[1], '<a>');
    expect(lines[2], '  <b/>');
  });

  test('KAPANMAMIŞ etiket çökmez', () {
    expect(() => PrettyFormat.xml('<a><b>'), returnsNormally);
    expect(() => PrettyFormat.xml('<'), returnsNormally);
  });

  test('XML olmayan metne dokunulmaz', () {
    expect(PrettyFormat.xml('düz metin'), 'düz metin');
  });

  test('desteklenen uzantılar', () {
    expect(PrettyFormat.supports('.json'), isTrue);
    expect(PrettyFormat.supports('xml'), isTrue);
    expect(PrettyFormat.supports('.SVG'), isTrue);
    expect(PrettyFormat.supports('.txt'), isFalse);
    expect(PrettyFormat.supports('.pdf'), isFalse);
  });

  test('uzantıya göre doğru biçimlendirici seçilir', () {
    expect(PrettyFormat.pretty('{"a":1}', '.json'), contains('\n'));
    expect(PrettyFormat.pretty('<a><b/></a>', '.xml'), contains('\n'));
  });
}
