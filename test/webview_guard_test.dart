import 'dart:io';

import 'package:dosya_okuyucu/core/webview_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Güvenlik G6.1–G6.4: WebView gezinti kilidi, dış bağlantı şemaları,
/// kanal mesajı sınırı, Word kabuğunda CSP.
void main() {
  const shell = '/assets/word/viewer.html';

  test('Word kabuğu: yalnız kendi sayfası', () {
    expect(
        WebViewGuard.allowNavigation(
            'file:///android_asset/flutter_assets/assets/word/viewer.html', shell),
        isTrue);
    expect(WebViewGuard.allowNavigation('about:blank', shell), isTrue);
    expect(WebViewGuard.allowNavigation('https://evil.example/', shell), isFalse);
    expect(WebViewGuard.allowNavigation('file:///sdcard/Download/x.html', shell),
        isFalse);
    expect(
        WebViewGuard.allowNavigation(
            'file:///sdcard/Download/assets/word/viewer.html', shell),
        isFalse);
    expect(WebViewGuard.allowNavigation('javascript:alert(1)', shell), isFalse);
    expect(WebViewGuard.allowNavigation('intent://x#Intent;end', shell), isFalse);
  });

  test('ses motoru: yalnız yerel sunucu kökeni', () {
    const origin = 'http://127.0.0.1:4567/';
    expect(WebViewGuard.allowNavigation('http://127.0.0.1:4567/engine.html', origin),
        isTrue);
    expect(WebViewGuard.allowNavigation('http://127.0.0.1:4568/engine.html', origin),
        isFalse);
    expect(WebViewGuard.allowNavigation('http://localhost.evil/engine.html', origin),
        isFalse);
    expect(WebViewGuard.allowNavigation('https://127.0.0.1:4567/', origin), isFalse);
  });

  test('dışarıda açılabilen bağlantı: yalnız http/https/mailto', () {
    expect(WebViewGuard.externalLink('https://example.com/a')?.host, 'example.com');
    expect(WebViewGuard.externalLink('mailto:a@example.com'), isNotNull);
    for (final bad in [
      'file:///sdcard/a.html',
      'content://x/y',
      'intent://scan#Intent;end',
      'javascript:alert(1)',
      'data:text/html,<b>x</b>',
      'https:///nohost',
    ]) {
      expect(WebViewGuard.externalLink(bad), isNull, reason: bad);
    }
  });

  test('kanal mesajı 256 KB sınırı', () {
    expect(WebViewGuard.acceptMessage('x' * WebViewGuard.maxChannelMessage), isTrue);
    expect(WebViewGuard.acceptMessage('x' * (WebViewGuard.maxChannelMessage + 1)),
        isFalse);
  });

  test('Word kabuğunda ağı kapatan CSP var', () {
    final html = File('assets/word/viewer.html').readAsStringSync();
    final m = RegExp(r'http-equiv="Content-Security-Policy" content="([^"]+)"')
        .firstMatch(html);
    expect(m, isNotNull);
    final csp = m!.group(1)!;
    expect(csp, contains("default-src 'none'"));
    expect(csp, contains("connect-src 'none'"));
    expect(csp, isNot(contains('http:')));
    expect(csp, isNot(contains('https:')));
    expect(csp, isNot(contains("'unsafe-eval'")));
    // CSP, betiklerden ÖNCE gelmeli.
    expect(html.indexOf('Content-Security-Policy'),
        lessThan(html.indexOf('<script')));
  });
}
