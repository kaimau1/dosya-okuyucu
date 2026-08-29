import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Çizilen dosya/klasör simgelerinin KARAR tablosu (2026-08-29 — kullanıcı:
/// *"simgeler çok yapmacık"*). Çizimin kendisi göze bakar; burada kilitlenen
/// şey, hangi girdinin hangi biçim/renk/yazıyla çizileceği.
void main() {
  FsEntry file(String name) => FsEntry(
        path: '/depo/$name',
        name: name,
        isDir: false,
        sizeBytes: 1,
        modifiedMs: 0,
      );

  FsEntry dir(String name) => FsEntry(
        path: '/depo/$name',
        name: name,
        isDir: true,
        sizeBytes: 0,
        modifiedMs: 0,
      );

  group('şerit yazısı', () {
    test('kısa uzantı olduğu gibi, büyük harfle', () {
      expect(FmColors.labelForExtension('pdf'), 'PDF');
      expect(FmColors.labelForExtension('DOCX'), 'DOCX');
    });

    test('uzun uzantı üç harfe kısaltılır', () {
      expect(FmColors.labelForExtension('torrent'), 'TOR');
    });

    test('uzantı olmayan "uzantı" ŞERİDE YAZILMAZ', () {
      // `yedek.backup2024` ya da `film.part-001` gerçek bir tür değil;
      // şeride yazılırsa bilgi değil gürültü olur.
      expect(FmColors.labelForExtension(''), '');
      expect(FmColors.labelForExtension('part-001'), '');
      expect(FmColors.labelForExtension('backup20241'), '');
    });
  });

  group('çizim reçetesi', () {
    test('klasör klasör olarak çizilir, bilinen ad glifi ÜSTÜNE biner', () {
      final spec = FmColors.glyphFor(dir('Download'));
      expect(spec.folder, isTrue);
      expect(spec.color, FmColors.folder);
      // Glif klasörün YERİNE geçmiyor: biçim hâlâ klasör.
      expect(spec.overlay, Icons.download_rounded);
      expect(spec.label, isEmpty);
    });

    test('bilinmeyen klasörde glif yok', () {
      expect(FmColors.glyphFor(dir('Faturalar')).overlay, isNull);
    });

    test('belge marka rengini ve uzantısını taşır', () {
      final spec = FmColors.glyphFor(file('rapor.docx'));
      expect(spec.folder, isFalse);
      expect(spec.color, OfficeColors.word);
      expect(spec.label, 'DOCX');
      // Şeritte uzantı yazılıyken glif gereksiz: aynı bilgi iki kez.
      expect(spec.overlay, isNull);
    });

    test('eski biçim (.xls) da kendi markasıyla', () {
      expect(FmColors.glyphFor(file('bütçe.xls')).color, OfficeColors.excel);
    });

    test('uzantıya özel renk kategori renginden ÖNCE gelir', () {
      expect(FmColors.glyphFor(file('uygulama.apk')).color, FmColors.apk);
      expect(FmColors.glyphFor(file('arşiv.zip')).color, FmColors.archive);
    });

    test('uzantısız dosyada kategori glifi kağıdın ortasına konur', () {
      final spec = FmColors.glyphFor(file('IMG-20260829-WA0001'));
      expect(spec.label, isEmpty);
      expect(spec.overlay, isNotNull);
    });

    test('çizgi glifli tema ailesinde kontur bayrağı taşınır', () {
      expect(FmColors.glyphFor(dir('X'), outlined: true).outlined, isTrue);
      expect(FmColors.glyphFor(file('a.pdf'), dark: true).dark, isTrue);
    });
  });
}
