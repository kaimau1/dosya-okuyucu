# Güvenlik envanteri (Faz G0.3, 2026-11-11)

Kaynak: `docs/GUVENLIK_PLANI.md` §2 + kod okuması. Satır numarası yerine dosya/ad verilir (kayar).
Bu envanter `tool/guvenlik_denetimi.sh` izin listeleriyle **aynı tutulur**: yeni dışa açık bileşen,
sunucu veya WebView JS eklenince önce burası ve betikteki liste, gerekçesiyle güncellenir.
`Not / Faz` sütunu: kapatacak faz (açıksa) ya da "—" (kabul edilmiş).

## (a) Dışa açık bileşenler (`ci/AndroidManifest.xml`, `exported="true"`)

| Bileşen | Tür | Koruma | Not / Faz |
|---|---|---|---|
| `.MainActivity` | activity | Yok (başlatıcı + VIEW/SEND süzgeçleri; `http/https` `host="*"` ve `file://` VIEW dahil) | Dış uygulama `dosya_link` / kısayol yolu eki gönderebilir (B4); süzgeç gereksinimi B15. **G1** |
| `.PickerActivity` | activity | Yok (GET_CONTENT/OPEN_DOCUMENT; seçici kipi) | Dosya verme yalnız kullanıcı seçince, geçici URI izniyle |
| `.DosyaProvider` | provider | `android:permission=MANAGE_DOCUMENTS` (yalnız sistem belge seçicisi) | `grantUriPermissions=true`; DocumentsProvider kalıbı. — |
| `.StorageWidget` | receiver | Yok (APPWIDGET_UPDATE yalnız sistemden gelir) | Dokunuşlar MainActivity'yi bağlantı ekiyle açar. — |
| `.RecentWidget` | receiver | Aynı | Aynı. — |
| `.AjanServisi` | service | `android:permission=BIND_APP_FUNCTION_SERVICE` | Android 16+ AppFunctions. — |

Manifest düzeyi: `android:allowBackup` **ayarsız** (varsayılan açık) — B3, **G1**. `FLAG_SECURE` yok — B10, **G1**.
Ağ güvenliği (`ci/res/xml/network_security_config.xml`): şifresiz HTTP yalnız `127.0.0.1`/`localhost` (denetim kural 5).

## (b) Açılan ağ portları

Hepsi `0.0.0.0` (tüm arayüzler; mobil veri dahil) üzerinde, **şifresiz** — B5, **G4**. Denetim kural 7 izin listesinde.

| Hizmet | Dosya | Port | Kimlik doğrulama | Not / Faz |
|---|---|---|---|---|
| HTTP dosya paylaşımı | `fm/remote/http_share_server.dart` | 8080 (ayarlı) | HTTP Basic (kullanıcı adı boşsa anonim) | `==` karşılaştırma, deneme sınırı yok (B17). **G4** |
| FTP sunucusu | `fm/remote/ftp_server.dart` (+ `ftp_service.dart`) | kontrol portu ayarlı; PASV için rastgele port | USER/PASS (kullanıcı adı boşsa anonim) | Düz FTP; yazma izni ayarlı. **G4** |
| QR aktarımı | `fm/remote/qr_transfer.dart` | 8080 tercih, olmazsa rastgele | URL'deki 6 karakterlik `Random.secure()` belirteç (`/q/<token>/`) | Tek seferlik oturum. **G4** |
| Eşler arası paylaşım (HTTP) | `fm/remote/peer_share.dart` | 8770 | Eşleştirme kodu: 4 hane, `Random()`, **isteğe bağlı**, deneme sınırı yok (B6) | **G4** (G5 şifreleme isteğe bağlı) |
| Eşler arası keşif (UDP) | `fm/remote/peer_share.dart` | 8769 + istemci için rastgele UDP | Yok (kimlik bilgisi yayınlanır) | **G4** |
| Slayt uzaktan kumanda | `screens/editors/slideshow/remote.dart` | rastgele | URL yolundaki rastgele belirteç | **G4** |
| Yerel ses dosyaları | `services/voice/neural_voices.dart` | rastgele, yalnız `127.0.0.1` | Yok (yalnız döngü arayüzü) | — |

## (c) Diske yazılan sırlar

| Sır | Nerede | Nasıl saklanıyor | Bulgu / Faz |
|---|---|---|---|
| Gemini API anahtarı(ları) | SharedPreferences `gemini_api_keys_sealed` (`core/app_state.dart`, `services/key_vault.dart`) | Android Keystore ile sarılı (AES-GCM). Kanal yoksa eski düz anahtar yedeği `gemini_api_key(s)` | İyi. Ağda anahtar URL `?key=` ile gidiyor (B8). **G2** |
| Uzak sunucu parolaları (SMB/FTP/SFTP/WebDAV) | SharedPreferences, kayıtlı bağlantı JSON'u (`models/remote_connection.dart`, `app_state.dart`) | **Düz metin** (`savePassword` açıksa) | B1, **G2** |
| Telefon FTP sunucusu parolası | SharedPreferences `ftpd_password` (+ `ftpd_user`, `ftpd_random_password`) (`fm/remote/ftp_service.dart`) | **Düz metin** | B2, **G2** |
| Kasa ana anahtarı | `.DosyaOkuyucuKasa/vault.json` (PIN'den PBKDF2 ile türetilen anahtarla sarılı; tuz dosyada) | AES-256-CTR+HMAC; PBKDF2 120.000 tur (B9). Uygulama silinse de dosya kalır | B9, **G3** |
| Kasa parmak izi kopyası | SharedPreferences `vault_bio_key` (`fm/secure_vault.dart`) | Ana anahtarın Android Keystore ile sarılmış kopyası | İyi |
| Uygulama kilidi PIN özeti | SharedPreferences `fm_lock_pin` (`core/app_state.dart`) | Özet (algoritma/tur **G3'te doğrulanacak**) | **G3** |
| İmza anahtarı (APK) | Yalnız GitHub Secrets; depoda yok | Denetim kural 9 | B12, **G9** |
| Ayar yedeği | `services/settings_backup.dart` | `secretPrefixes` ile sırlar dışarıda bırakılıyor | İyi |
| Tanı raporu | `services/diag_report.dart` | `scrub` ile kişisel veri maskeleniyor | İyi |

Not: `android:allowBackup` açıkken yukarıdaki SharedPreferences sırları bulut/ADB yedeğine girebilir (B3, G1).
