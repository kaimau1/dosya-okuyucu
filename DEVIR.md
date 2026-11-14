# DEVIR — faz-oto-P15-guvenlik (P15 güvenlik kod artıkları)

Yapılanlar:
- G6.5 ses sunucusu rastgele yol öneki (`VoiceServer.prefix`, `base`; EMA çalışanı sunarken önek eklenir) — test `test/neural_voices_test.dart`
- G1(c) imzasız kısayol: API 26+ yalnız sistemde kayıtlı kendi kısayolumuzun yolu (`Extras.pathAccepted(ownShortcuts)`, `MainActivity.ownShortcutPaths`); Android 7 eski kol

Şu an: G7.1/G7.3 artıkları
Sıradaki: G7.1/G7.3 artıkları, G7.4 makro, G9.9 ses motoru özetleri, G10.2 tek belgelik kapatma, 👤 → KONTROL_LISTEM
Doğrulama: CI (`gh run list -b faz-oto-P15-guvenlik -L 1`)
