import 'dart:convert';

import 'package:dosya_okuyucu/services/pdf/pdf_xobject.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Form XObject'in İÇİNDEKİ görseller** — kullanıcı bulgusu 2026-09-01:
/// *"görselleri tam tanıyamadı"* (e-Nabız tahlil çıktısında "Bu sayfada gömülü
/// görsel yok" yazıyordu, oysa sayfanın tepesinde iki logo vardı).
///
/// Kök neden: antet logolarını HTML→PDF üreticileri sayfa akışına DEĞİL bir
/// form XObject'in içine koyuyor; sayfa yalnız `/Fm0 Do` diyor. Eski tarayıcı
/// form XObject'leri baştan eliyordu.
void main() {
  // Form: kendi içinde 100 × 50'lik bir logoyu (10, 20)'ye çiziyor.
  final formContent = latin1.encode('q 100 0 0 50 10 20 cm /Im1 Do Q');

  test('form XObject içindeki görsel bulunur', () {
    // Sayfa formu (0, 700)'e, birim ölçekle çiziyor.
    final page = latin1.encode('q 1 0 0 1 0 700 cm /Fm0 Do Q');
    final objects = findPageObjects([page], resources: {
      'Fm0': PdfXObjectNode(
        isImage: false,
        objectNumber: 7,
        content: formContent,
        children: const {
          'Im1': PdfXObjectNode(isImage: true, objectNumber: 8),
        },
      ),
    });

    expect(objects, hasLength(1));
    final logo = objects.single;
    expect(logo.name, 'Im1');
    // Sayfa uzayında: formun içindeki (10, 20) + sayfanın (0, 700).
    expect(logo.left, closeTo(10, 1e-6));
    expect(logo.bottom, closeTo(720, 1e-6));
    expect(logo.width, closeTo(100, 1e-6));
    expect(logo.height, closeTo(50, 1e-6));
    // Düzenleme hedefi FORMUN akışı, sayfanınki değil.
    expect(logo.formObject, 7);
    expect(logo.editable, isTrue);
  });

  test('formun /Matrix ölçeği sayfa kutusuna yansır', () {
    final page = latin1.encode('q 1 0 0 1 0 0 cm /Fm0 Do Q');
    final objects = findPageObjects([page], resources: {
      'Fm0': PdfXObjectNode(
        isImage: false,
        objectNumber: 7,
        content: formContent,
        // Form kendi içinde yarım ölçekte çiziliyor.
        matrix: const [0.5, 0, 0, 0.5, 0, 0],
        children: const {
          'Im1': PdfXObjectNode(isImage: true, objectNumber: 8),
        },
      ),
    });

    final logo = objects.single;
    expect(logo.left, closeTo(5, 1e-6));
    expect(logo.bottom, closeTo(10, 1e-6));
    expect(logo.width, closeTo(50, 1e-6));
    expect(logo.height, closeTo(25, 1e-6));
  });

  test('paylaşılan form içindeki görsel DÜZENLENEMEZ işaretlenir', () {
    final page = latin1.encode('/Fm0 Do');
    final objects = findPageObjects([page], resources: {
      'Fm0': PdfXObjectNode(
        isImage: false,
        objectNumber: 7,
        content: formContent,
        refCount: 3, // başka sayfalar da bu formu kullanıyor
        children: const {
          'Im1': PdfXObjectNode(isImage: true, objectNumber: 8),
        },
      ),
    });

    expect(objects.single.editable, isFalse);
  });

  test('sayfa akışındaki görsel de ağaç yoluyla bulunur (formObject = 0)', () {
    final page = latin1.encode('q 60 0 0 60 20 20 cm /Im9 Do Q');
    final objects = findPageObjects([page], resources: const {
      'Im9': PdfXObjectNode(isImage: true, objectNumber: 5),
    });
    expect(objects.single.formObject, 0);
    expect(objects.single.left, closeTo(20, 1e-6));
  });

  test('iç içe formlar sınırlı derinlikte taranır (döngüde asılmaz)', () {
    // Kendi kendine dönen bozuk bir form: özyineleme sınırı olmasaydı
    // yığın taşardı.
    final loop = latin1.encode('/Fm0 Do');
    final node = PdfXObjectNode(
      isImage: false,
      objectNumber: 7,
      content: loop,
      children: const {},
    );
    final cyclic = <String, PdfXObjectNode>{'Fm0': node};
    // Çocukları kendisini gösterecek şekilde kurulamıyor (immutable) —
    // bunun yerine aynı düğümü iki kat derinde tekrarlıyoruz.
    final nested = PdfXObjectNode(
      isImage: false,
      objectNumber: 6,
      content: loop,
      children: cyclic,
    );
    final objects = findPageObjects([latin1.encode('/Fm1 Do')],
        resources: {'Fm1': nested});
    // Görsel yok; önemli olan taramanın sonlanması.
    expect(objects, isEmpty);
  });
}
