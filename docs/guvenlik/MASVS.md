# OWASP MASVS v2 eşlemesi (G12.2) — 2026-11-12

Durum: **K** karşılanıyor (kanıt) · **D** kapsam dışı (gerekçe) · **A** açık (plan maddesi).

| Denetim | Durum | Kanıt / gerekçe |
|---|---|---|
| STORAGE-1 hassas veri güvenli saklanır | K | Uzak/FTP parolası, Gemini anahtarı Keystore sarılı (`KeyVault`, G2.1–G2.3); kasa AES-GCM + PBKDF2 600k (`secure_vault.dart`, `test/vault_crypto_kat_test.dart`) |
| STORAGE-2 hassas veri sızmaz | K/A | `allowBackup=false` (G1.1); log temizliği (G2.5); kasa dosyası son açılanlara/kısayollara yazılmaz (`PrivateZone`, `test/private_zone_test.dart`); hassas pano (G2.6). **A:** G10.2 AI maskesi |
| CRYPTO-1 güçlü kripto | K | Yalnız AES-256-GCM, HMAC-SHA256, PBKDF2-SHA256, `Random.secure` (plan kural 9; denetim betiği Random kuralı) |
| CRYPTO-2 anahtar yönetimi | K/A | Keystore + biyometri CryptoObject (G3.4). **A:** G2.7 ana anahtarı kilitte sıfırlama |
| AUTH-1 yerel kimlik doğrulama | K | PIN PBKDF2 + deneme sınırı (G3.2/G3.3); otomatik kilit (G3.5) |
| AUTH-2 uzak kimlik | K/A | Yerel sunucular parola + `AuthThrottle` + sabit zamanlı karşılaştırma (G4.3). **A:** G4.2 belirteç yolu, G4.4 6 hane |
| NETWORK-1 güvenli iletişim | K/A | Gemini başlıkta anahtar (G2.4); güncelleme yalnız GitHub https + SHA-256 (G9.6, `test/app_update_test.dart`); SFTP TOFU (G8.1, `test/sftp_host_keys_test.dart`). **A:** G8.2 FTPS, G8.3 WebDAV http uyarısı |
| NETWORK-2 kimlik sabitleme | D | Sertifika sabitleme yok: yalnız Google/GitHub API'leri, sistem güven deposu yeterli; sabitleme anahtar dönüşünde uygulamayı kırar |
| PLATFORM-1 IPC güvenli | K | Dışa açık bileşen envanteri (`ENVANTER.md`), imzalı kısayol `Extras.pathAccepted` (G1.2), `FLAG_IMMUTABLE` (G1.7), `RECEIVER_NOT_EXPORTED` (G1.8) |
| PLATFORM-2 WebView güvenli | K | CSP, gezinti kilidi, dosya/içerik erişimi kapalı, kanal sınırı (G6.1–G6.4, `test/webview_guard_test.dart`); ses sunucusu Host/Origin (G6.5) |
| PLATFORM-3 arayüz gizliliği | K | `FLAG_SECURE` kasa/kilit ekranlarında (G1.4) |
| CODE-1 güncel platform | K | targetSdk 36, Flutter 3.47.9 |
| CODE-2 güncelleme zorunluluğu | K | `min-guvenli` (G12.4) |
| CODE-3 bağımlılık açıkları | K/A | Dependabot (G9.4), Actions SHA sabit (G9.1). **A:** osv-scanner iş akışı |
| CODE-4 girdi doğrulama | K/A | Arşiv yol kaçışı (G7.2), CSV formül (G7.5), uzantı aldatması (G7.10), sunucu yol kaçışı (G4.10). **A:** G7.1 arşiv bombası, G7.3 Office sınırları, G7.9 fuzz |
| RESILIENCE-1..4 | D | İsteğe bağlı G11: `--obfuscate` + R8 açık; kurcalama/kök tespiti yapılmaz (ücretsiz, açık dağıtımlı uygulamada fayda < bakım) |
| PRIVACY-1 veri en aza | K/A | AI ilk gönderimde rıza (`AiSendConsent`); kasa AI'ya kapalı (G10.3). **A:** G10.2 maske, G10.4 çevrimdışı kip tek kapı |
| PRIVACY-2 kullanıcı denetimi | A | G10.5 "Verilerimi sil" tek düğme |
