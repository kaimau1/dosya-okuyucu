import 'package:dosya_okuyucu/services/voice_note.dart';
import 'package:flutter_test/flutter_test.dart';

/// KALANLAR A10: kişisel sürümde görüntüleyiciden sesli not.
void main() {
  tearDown(() {
    VoiceNote.debugEnabled = null;
    VoiceNote.debugSend = null;
  });

  test('genel derlemede kapalı', () {
    expect(VoiceNote.enabled, isFalse);
  });

  test('not: konuşma, dosya adı, sayfa, alıntı, bağlantı', () {
    final note = VoiceNote.compose(
      spoken: '  bu bölümü yeniden oku ',
      path: '/storage/emulated/0/Download/rapor.pdf',
      page: 12,
      quote: 'Sonuç\n  bölümü   özet',
    );
    expect(note, startsWith('bu bölümü yeniden oku\n\n— rapor.pdf · s. 12'));
    expect(note, contains('“Sonuç bölümü özet”'));
    expect(note,
        endsWith('file:///storage/emulated/0/Download/rapor.pdf#page=12'));
  });

  test('uzun alıntı kesilir, sayfasız belge', () {
    final note = VoiceNote.compose(
        spoken: 'not', path: '/a/b.docx', quote: 'x' * 400);
    expect(note, contains('${'x' * 280}…'));
    expect(note, isNot(contains('s. ')));
    expect(note, endsWith('file:///a/b.docx'));
  });

  test('gönderim Dosyalar konusuyla', () async {
    String? subject;
    VoiceNote.debugSend = (s, b) async => subject = s;
    await VoiceNote.send('x');
    expect(subject, 'Dosyalar');
  });
}
