import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/edition.dart';
import 'crash_log.dart';
import 'offline_mode.dart';

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
  static const _kPrice = 'pro_price_v1';

  /// Google Play'deki bölgesel ürün fiyatı (ör. `₺29,99`, `$0.79`, `Rp 12.000`).
  static final ValueNotifier<String?> storePrice = ValueNotifier<String?>(null);

  static bool get _enabled => Edition.current == Edition.lite;

  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static Completer<ProBuyResult>? _pending;
  static Future<String?>? _priceFuture;

  /// Yerel kaydı okur (açılışta, Play'i beklemeden). Kayıt Play'in verdiği
  /// satın alma belirteciyle tutulur; belirteçsiz kayıt yok sayılır.
  static Future<void> loadCached() async {
    if (!_enabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPrice = prefs.getString(_kPrice);
      if (cachedPrice != null && cachedPrice.trim().isNotEmpty) {
        storePrice.value = cachedPrice.trim();
      }
      final raw = prefs.getString(_kRecord);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['product'] == productId &&
          (m['token'] as String? ?? '').isNotEmpty) {
        ProUnlock.owned.value = true;
      }
    } catch (_) {
      return; // Bilinçli: bozuk kayıt → kilitli kalır, [verify] düzeltir.
    }
  }

  /// Google Play'deki bölgesel ürün fiyatını okur ve önbelleğe alır.
  static Future<String?> loadPrice() {
    if (!_enabled) return Future<String?>.value(storePrice.value);
    return _priceFuture ??= _fetchPrice().whenComplete(() {
      _priceFuture = null;
    });
  }

  static Future<String?> _fetchPrice() async {
    if (OfflineMode.enabled) return storePrice.value;
    try {
      if (!await InAppPurchase.instance
          .isAvailable()
          .timeout(const Duration(seconds: 10), onTimeout: () => false)) {
        return storePrice.value;
      }
      final q = await InAppPurchase.instance
          .queryProductDetails({productId})
          .timeout(const Duration(seconds: 15));
      final detail = q.productDetails.firstOrNull;
      if (detail != null) await _savePrice(detail.price);
    } catch (_) {
      return storePrice.value; // Bilinçli: mağaza fiyatına ulaşılamazsa sessiz kalır.
    }
    return storePrice.value;
  }

  static Future<void> _savePrice(String raw) async {
    final price = raw.trim();
    if (price.isEmpty) return;
    if (storePrice.value != price) storePrice.value = price;
    try {
      await (await SharedPreferences.getInstance()).setString(_kPrice, price);
    } catch (_) {
      return; // Bilinçli: fiyat yazılamasa da bu oturumda bellekte kalır.
    }
  }

  @visibleForTesting
  static void resetPriceForTest() {
    storePrice.value = null;
    _priceFuture = null;
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
    if (OfflineMode.enabled) return null;
    try {
      _listen();
      if (!await InAppPurchase.instance
          .isAvailable()
          .timeout(const Duration(seconds: 10), onTimeout: () => false)) {
        return null;
      }
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final res = await addition
          .queryPastPurchases()
          .timeout(const Duration(seconds: 25));
      if (res.error != null) return null;
      final owned = res.pastPurchases.where(isOwnedPro).firstOrNull;
      if (owned == null) {
        await _clear();
        unawaited(loadPrice());
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
    if (OfflineMode.enabled) return ProBuyResult.unavailable;
    try {
      _listen();
      if (!await InAppPurchase.instance
          .isAvailable()
          .timeout(const Duration(seconds: 10), onTimeout: () => false)) {
        return ProBuyResult.unavailable;
      }
      final q = await InAppPurchase.instance
          .queryProductDetails({productId})
          .timeout(const Duration(seconds: 25));
      if (q.productDetails.isEmpty) return ProBuyResult.unavailable;
      unawaited(_savePrice(q.productDetails.first.price));
      _pending = Completer<ProBuyResult>();
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: q.productDetails.first),
      );
      if (!started) _finish(ProBuyResult.failed);
      return await _pending!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _finish(ProBuyResult.failed);
          return ProBuyResult.failed;
        },
      );
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
