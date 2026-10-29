import 'package:flutter/material.dart';

import 'remote/nearby_screen.dart';

/// **Aktar** — panodaki kapı. 2026-10-29'dan beri doğrudan birleşik
/// **Yakındakiler** ekranını açar (kullanıcı: *"aktarım ekranlarını tek
/// birleşik, anlaşılır, pratik bir ekrana indirgeyelim"*): telefonlar arası
/// gönderme/alma, QR/tarayıcı, geçmiş ve "Diğer yollar" (bilgisayar, ağ
/// depolama, indirmeler) aynı sayfada.
class TransferScreen extends StatelessWidget {
  /// Testte ağ/Bluetooth başlatılmasın.
  final bool services;

  const TransferScreen({super.key, this.services = true});

  @override
  Widget build(BuildContext context) => NearbyScreen(services: services);
}
