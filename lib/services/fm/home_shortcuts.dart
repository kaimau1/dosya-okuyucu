import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **Telefonun ana ekranına kısayol** (2026-09-27).
///
/// Kullanıcı: *"PDF'ler veya klasörler için 'kısayol oluştur' seçeneği ile
/// telefon ana ekranına kısayol koyabilmeliyiz; basılı tutunca çıkan menüde
/// olsun."*
///
/// Android 8+ `ShortcutManager.requestPinShortcut` (başlatıcı kullanıcıya
/// "ana ekrana ekle" onayını kendisi sorar), 7 ve öncesi başlatıcının eski
/// yayını. Kısayolun simgesi burada, dosya türünün renginde ÇİZİLİR
/// (uyarlanabilir simge: zemin tam kaplar, glif güvenli bölgede) — her
/// kısayol uygulama simgesi olsaydı ana ekranda ayırt edilemezdi.
abstract final class HomeShortcuts {
  static const _channel = MethodChannel('dosya_okuyucu/shortcuts');

  /// Uygulama açıkken kısayola dokunulunca çağrılır.
  static void Function(String path)? _onOpen;

  /// Açık uygulamada kısayoldan gelen yolları dinle.
  static void listen(void Function(String path) onOpen) {
    _onOpen = onOpen;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open' && call.arguments is String) {
        _onOpen?.call(call.arguments as String);
      }
      return null;
    });
  }

  /// Uygulama bir kısayolla AÇILDIYSA o yol (okununca temizlenir).
  static Future<String?> takeLaunchPath() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('take');
    } catch (_) {
      return null;
    }
  }

  /// Başlatıcı kısayol sabitlemeyi destekliyor mu?
  static Future<bool> supported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [path] için ana ekran kısayolu ister. Başlatıcı onay penceresini
  /// kendisi gösterir; istek iletildiyse true.
  static Future<bool> pin({
    required String path,
    required String label,
    required IconData icon,
    required Color color,
  }) async {
    if (!Platform.isAndroid) return false;
    Uint8List? png;
    try {
      png = await renderIcon(icon, color);
    } catch (_) {
      png = null; // simge çizilemedi: uygulama simgesi kullanılır
    }
    try {
      return await _channel.invokeMethod<bool>('pin', {
            'path': path,
            'label': label,
            'icon': png,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Uyarlanabilir simge: 432 px (108 dp × 4), zemin [color] degrade, glif
  /// ortadaki 72 dp güvenli bölgenin içinde, beyaz.
  static Future<Uint8List> renderIcon(IconData icon, Color color) async {
    const size = 432.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = const Offset(0, 0) & const Size(size, size);
    final hsl = HSLColor.fromColor(color);
    final light =
        hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    final dark =
        hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            ui.Gradient.linear(rect.topLeft, rect.bottomRight, [light, dark]),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.40,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }
}
