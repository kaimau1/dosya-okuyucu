import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../models/document.dart';

/// Tüm belge ekranlarının ortak Office kabuğu: dosya türü renginde üst şerit,
/// kaydedilmemiş değişiklik (•) göstergesi, Fluent kanvas zemini ve alt bar
/// için SafeArea. Alt sistem çubuğu (geri/ana menü) çakışmaları tek yerden
/// çözülür; ekranlar kendi Scaffold'unu kurmaz.
class OfficeShell extends StatelessWidget {
  final DocKind kind;
  final String title;
  final bool dirty;
  final List<Widget> actions;
  final PreferredSizeWidget? tabBar;
  final Widget body;
  final Widget? bottomBar;
  final Widget? fab;

  const OfficeShell({
    super.key,
    required this.kind,
    required this.title,
    required this.body,
    this.dirty = false,
    this.actions = const [],
    this.tabBar,
    this.bottomBar,
    this.fab,
  });

  @override
  Widget build(BuildContext context) {
    final brand = OfficeColors.forKind(kind);
    return Scaffold(
      backgroundColor: OfficeColors.canvas(context),
      appBar: AppBar(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text('$title${dirty ? ' •' : ''}',
            overflow: TextOverflow.ellipsis),
        actions: actions,
        bottom: tabBar,
      ),
      body: body,
      bottomNavigationBar: bottomBar == null
          ? null
          : Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(top: false, child: bottomBar!),
            ),
      floatingActionButton: fab,
    );
  }
}

/// Pinch sırasında görünen zoom yüzdesi rozeti. Widget ağaçta hep durur
/// (örtük animasyon tuzağı: yapı değişirse geçiş oynamaz), sadece opaklığı değişir.
class ZoomBadge extends StatelessWidget {
  final double zoom;
  final bool visible;
  const ZoomBadge({super.key, required this.zoom, required this.visible});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '%${(zoom * 100).round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Zoom rozetini kısa süre gösterip söndüren küçük yardımcı durum.
/// Kullanım: pinch güncellemesinde [bump], build'de [visible] + [zoom].
class ZoomBadgeController {
  final void Function(void Function()) _setState;
  Timer? _timer;
  bool visible = false;
  double zoom = 1;

  ZoomBadgeController(this._setState);

  void bump(double value) {
    _timer?.cancel();
    _setState(() {
      zoom = value;
      visible = true;
    });
    _timer = Timer(const Duration(milliseconds: 900), () {
      _setState(() => visible = false);
    });
  }

  void dispose() => _timer?.cancel();
}
