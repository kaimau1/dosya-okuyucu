import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/edition.dart';
import 'crash_log.dart';

/// Satın alma denemesinin sonucu (arayüz iletisi seçer).
enum ProBuyResult { purchased, pending, canceled, unavailable, failed }

/// **Pro'yu açan tek seferlik uygulama içi satın alım** (K15, 2026-11-27).
///
/// Lite ile Pro aynı uygulama: Lite'ta Pro özellikleri kilitli görünür,
/// Play Billing'deki yönetilen (tüketilmeyen) [productId] ürünü alınınca
/// [ProUnlock.owned] açılır ve `Edition.has` Pro gibi davranır. Yalnız Lite
/// derlemesinde etkindir; Pro ve Kişisel derlemede hiçbir şey yapmaz.
///
/// **Esas kayıt Play'dir:** yerel kayıt yalnız açılışta (Play yanıt verene
/// dek, çevrimdışıyken) geçici açar; [verify] Play'den geçmiş satın almaları
/// sorar — ürün yoksa yerel kayıt silinir ve kilit kapanır (iade/ters ibraz).
// ponytail: sunucu yok → doğrulama istemcide; köklü cihazda prefs + Play'i
// engelleyen biri kilidi açabilir. Gerekirse Play Developer API ile sunucu
// doğrulaması (purchaseToken) eklenir.
abstract final class ProPurchase {
  /// Play Console'daki yönetilen ürün kimliği (👤 PLAN §3 m.7).
  static const productId = 'pro_unlock';

  static const _kRecord = 'pro_purchase_v1';

  static bool get _enabled => Edition.current == Edition.lite;

  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static Completer<ProBuyResult>? _pending;

  /// Yerel kaydı okur (açılışta, Play'i beklemeden). Kayıt Play'in verdiği
  /// satın alma belirteciyle tutulur; belirteçsiz kayıt yok sayılır.
  static Future<void> loadCached() async {
    if (!_enabled) return;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_kRecord);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['product'] == productId && (m['token'] as String? ?? '').isNotEmpty) {
        ProUnlock.owned.value = true;
      }
    } catch (_) {
      return; // Bilinçli: bozuk kayıt → kilitli kalır, [verify] düzeltir.
    }
  }

  static void _listen() {
    _sub ??= InAppPurchase.instance.purchaseStream.listen(
      (list) => unawaited(_onPurchases(list)),
      onError: (Object e) => _finish(ProBuyResult.failed),
    );
  }

  /// Play'den geçmiş satın almaları sorup kilidi Play kaydına eşitler.
  /// Döner: Pro sahipliği; Play'e ulaşılamazsa null (yerel kayıt korunur).
  static Future<bool?> verify() async {
    if (!_enabled) return ProUnlock.owned.value;
    try {
      _listen();
      if (!await InAppPurchase.instance.isAvailable()) return null;
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final res = await addition.queryPastPurchases();
      if (res.error != null) return null;
      final owned = res.pastPurchases.where(isOwnedPro).firstOrNull;
      if (owned == null) {
        await _clear();
        return false;
      }
      await _grant(owned);
      return true;
    } catch (e, st) {
      unawaited(CrashLog.record(e, st, context: 'pro.verify'));
      return null;
    }
  }

  /// Satın alma akışını başlatır; Play'in yanıtını bekler.
  static Future<ProBuyResult> buy() async {
    if (!_enabled) return ProBuyResult.purchased;
    try {
      _listen();
      if (!await InAppPurchase.instance.isAvailable()) {
        return ProBuyResult.unavailable;
      }
      final q = await InAppPurchase.instance.queryProductDetails({productId});
      if (q.productDetails.isEmpty) return ProBuyResult.unavailable;
      _pending = Completer<ProBuyResult>();
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: q.productDetails.first),
      );
      if (!started) _finish(ProBuyResult.failed);
      return await _pending!.future;
    } catch (e, st) {
      unawaited(CrashLog.record(e, st, context: 'pro.buy'));
      // Zaten sahipse Play hata döndürür → kayıttan geri yükle.
      return await verify() == true
          ? ProBuyResult.purchased
          : ProBuyResult.failed;
    }
  }

  /// Play'deki eski satın almayı geri getirir (yeni telefon / yeniden kurulum).
  static Future<bool?> restore() => verify();

  /// Play kaydı gerçekten satın alınmış Pro mu? (Bekleyen/iptal sayılmaz.)
  @visibleForTesting
  static bool isOwnedPro(PurchaseDetails p) {
    if (p.productID != productId) return false;
    if (p is GooglePlayPurchaseDetails) {
      return p.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.purchased;
    }
    return p.status == PurchaseStatus.purchased ||
        p.status == PurchaseStatus.restored;
  }

  static Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list.where((p) => p.productID == productId)) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _finish(ProBuyResult.pending);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (isOwnedPro(p)) {
            await _grant(p);
            _finish(ProBuyResult.purchased);
          } else {
            _finish(ProBuyResult.pending);
          }
        case PurchaseStatus.canceled:
          _finish(ProBuyResult.canceled);
        case PurchaseStatus.error:
          // "Zaten sahip" de buraya düşer → Play kaydına bak.
          _finish(await verify() == true
              ? ProBuyResult.purchased
              : ProBuyResult.failed);
      }
    }
  }

  static void _finish(ProBuyResult r) {
    final c = _pending;
    _pending = null;
    if (c != null && !c.isCompleted) c.complete(r);
  }

  /// Kilidi açar, kaydı saklar ve onaylar (onaylanmayan satın alımı Play
  /// 3 günde iade eder).
  static Future<void> _grant(PurchaseDetails p) async {
    ProUnlock.owned.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kRecord,
        jsonEncode({
          'product': productId,
          'token': p.verificationData.serverVerificationData,
          'order': p.purchaseID,
          'ms': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // Bilinçli: kayıt yazılamazsa bu oturumda açık, sonraki açılışta Play'den.
    }
    if (p.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(p);
    }
  }

  static Future<void> _clear() async {
    ProUnlock.owned.value = false;
    try {
      await (await SharedPreferences.getInstance()).remove(_kRecord);
    } catch (_) {
      return; // Bilinçli: silinemezse kilit yine kapalı; sonraki verify siler.
    }
  }
}
