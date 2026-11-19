# DEVIR — faz-oto-U3-ana-ekran (U3)
Yapılanlar (her madde ayrı commit): m.8 seçili değer görünür · m.6 araçlar · m.5 tek Düzenle ·
m.2 hız çubuğu (speed_sheet.dart) · m.4/m.11 Akıllı düzen → SmartInbox, 3 showSnackBar → ortak kart,
kalıcı silme bildirimi · m.3 karışık şerit + sekmeler + StripPrefs + yan menü aynı şerit ·
kasma-kontrol (bildirim dinleyicisi statik).
Kök nedenler: lib/screens/settings/settings_widgets.dart SettingTile (trailing varken value çizilmiyordu);
lib/screens/fm/entry_actions/file_ops.dart deleteEntries kalıcı silmede başarı mesajı yoktu.
Şu anki adım: CI. Sıradaki: CI yeşilse yürütücü birleştirir; cihaz turu CIHAZ_TESTI U3, ölçüm C2.
Ölçüm: yok (cihazsız). Test: test/speed_sheet_test.dart, test/recent_strip_test.dart (CI).
