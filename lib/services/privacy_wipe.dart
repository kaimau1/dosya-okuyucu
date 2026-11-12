import 'dart:io';

import 'ai_summary_store.dart';
import 'crash_log.dart';
import 'fm/activity_log.dart';
import 'fm/ai_apply_log.dart';
import 'fm/ai_index.dart';
import 'fm/content_indexer.dart';
import 'fm/op_history.dart';
import 'fm/open_history.dart';
import 'fm/remote/transfer_history.dart';
import 'fm/saved_searches.dart';
import 'fm/search_history.dart';
import 'fm/search_index.dart';

/// "Verilerimi sil" kategorileri (GUVENLIK_PLANI G10.5, 2026-11-12).
///
/// DOSYALARA DOKUNULMAZ; yalnız uygulamanın dosyalar HAKKINDA tuttuğu kayıtlar
/// silinir. Kayıtlı bağlantılar, API anahtarları, kasa ve ayarlar BİLEREK
/// dışarıda (yanlışlıkla silinmesi geri getirilemez emek; kendi ekranlarından).
enum WipeCategory {
  /// Son açılanlar, açılış geçmişi, arama geçmişi + kayıtlı aramalar,
  /// işlem/etkinlik/aktarım geçmişi.
  history,

  /// AI özetleri, AI etiket/analiz dizini, AI uygulama kaydı, AI hafıza notları.
  ai,

  /// Dosya adı ve içerik (OCR dahil) arama dizinleri — yeniden kurulur.
  indexes,

  /// Hata kayıtları (yerel; zaten hiçbir yere gönderilmez).
  logs,
}

abstract final class PrivacyWipe {
  /// Seçili kategorileri siler; başarısız adım sayısını döner (0 = tamamı).
  /// [clearAppLists] AppState'teki son belgeler + AI notları (UI'dan verilir;
  /// servis AppState'e bağımlı olmasın diye).
  static Future<int> run(
    Set<WipeCategory> categories, {
    Future<void> Function()? clearAppLists,
  }) async {
    var failed = 0;
    Future<void> step(Future<void> Function() f) async {
      try {
        await f();
      } catch (_) {
        // Bilinçli: bir deponun silinememesi ötekileri durdurmaz; sayı döner.
        failed++;
      }
    }

    final history = categories.contains(WipeCategory.history);
    final ai = categories.contains(WipeCategory.ai);
    if ((history || ai) && clearAppLists != null) await step(clearAppLists);
    if (history) {
      await step(OpenHistory.clearAll);
      await step(SearchHistory.clear);
      await step(SearchHistory.clearOpened);
      await step(() => SavedSearches.store(const []));
      await step(OpHistory.clear);
      await step(ActivityLog.clear);
      await step(() => TransferHistory.instance.clear(incoming: true));
      await step(() => TransferHistory.instance.clear(incoming: false));
    }
    if (ai) {
      await step(() async {
        final dir = Directory(AiSummaryStore.root);
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      await step(AiIndex.clear);
      await step(AiApplyLog.clear);
    }
    if (categories.contains(WipeCategory.indexes)) {
      await step(SearchIndex.clear);
      await step(ContentIndexer.clear);
    }
    if (categories.contains(WipeCategory.logs)) {
      await step(CrashLog.clear);
    }
    return failed;
  }
}
