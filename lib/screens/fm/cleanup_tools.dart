import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/chat_junk.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/image_hash.dart';
import '../../services/fm/similar_finder.dart';
import 'chat_cleanup_screen.dart' show ChatJunkLive;
import 'similar_screen.dart';
import 'smart_cleanup_screen.dart';

/// Panodan açılan tüm-medya benzer taramasının kapsamı (iş kimliği bundan
/// türer: `SimilarFinder.jobIdFor`).
const String similarAllMediaScope = 'tum-medya';

/// **Daha fazla yer bul** — Yer aç'ın derin taramaları (2026-11-25).
///
/// KÖK (kullanıcı: *"Yer aç'a sadece içine konma yapılmış, mantık
/// çerçevesinde birleştirilmemiş; klasör haritası da iki yerde"*): önceki
/// "Temizlik araçları" kartı beş aracı alt alta diziyordu; ikisi Yer aç'ın
/// zaten yaptığı işin kopyasıydı. Artık:
/// - **Kopyalar** ayrı satır DEĞİL — Yer aç kopyaları kendisi buluyor; kopya
///   önerisinin kartındaki "Grupları tek tek incele" aynı grupları açar.
/// - **Klasör haritası** yalnız Bellek Analizi'nde (yer açmaz, yeri gösterir).
/// - Kalan üç tarama Yer aç'ın hızlı taramasının YAPAMADIĞI işi yapar
///   (görselin içine bakar, dakikalar sürer) ve her biri **bulduğunu
///   yazar** ("312 dosya · 1,4 GB temizlenebilir"): sonuç iş kuyruğundan
///   okunur, ekran kapansa da kaybolmaz; kullanıcı neyin kaldığını Yer aç'tan
///   çıkmadan görür.
class DeepScanCard extends StatelessWidget {
  /// Panonun hazır indeksi (benzer görseller anında açılsın); yoksa liste
  /// arka planda yüklenir.
  final StorageIndex? index;

  /// Taramalardan birinin ekranından dönülünce (orada dosya silinmiş
  /// olabilir — Yer aç önerilerini tazelesin).
  final VoidCallback? onReturn;

  const DeepScanCard({super.key, this.index, this.onReturn});

  /// Bir derin taramanın kuyruktaki durumu: (sürüyor mu, bulunan dosya,
  /// bulunan bayt). Hiç taranmadıysa null.
  static ({bool running, int files, int bytes})? statusOf(String jobId) {
    final job = JobQueue.instance.find(jobId);
    if (job == null) return null;
    if (job.status.isActive) return (running: true, files: 0, bytes: 0);
    final r = job.result;
    if (r is ChatJunkReport) {
      return (running: false, files: r.junkFiles, bytes: r.junkBytes);
    }
    if (r is List<SimilarGroup>) {
      var files = 0;
      var bytes = 0;
      for (final g in r) {
        files += g.files.length - 1;
        bytes += g.wastedBytes;
      }
      return (running: false, files: files, bytes: bytes);
    }
    if (r is SmartReport) {
      final unique = <String, int>{
        for (final b in r.buckets)
          for (final f in b.files) f.path: f.sizeBytes,
      };
      return (
        running: false,
        files: unique.length,
        bytes: unique.values.fold(0, (a, b) => a + b),
      );
    }
    // Sonucu olmayan bitmiş iş (iptal/hata): taranmamış sayılır.
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // B18: benzer kareler ve sohbet medyası artık Yer aç listesinin kendi
    // satırları (arka planda taranır); burada yalnız görselin İÇİNE bakan,
    // dakikalar süren içerik taraması kalır.
    final st = statusOf(SmartCleanupScreen.jobId);
    final found = st != null && !st.running && st.files > 0;
    final String sub;
    if (st == null) {
      sub = context.t('clean.deep_content_note');
    } else if (st.running) {
      sub = context.t('clean.deep_running');
    } else if (found) {
      sub = context.t('clean.deep_found', {
        'n': st.files,
        'size': FsPaths.humanSize(st.bytes),
      });
    } else {
      sub = context.t('clean.deep_none');
    }
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Material(
        key: const ValueKey('clean-deep'),
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const ValueKey('clean-deep-content'),
          leading: const Icon(AppIcons.ai, color: AppHues.violet),
          title: Text(context.t('clean.deep_content'),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(
            sub,
            style: found
                ? theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w700)
                : null,
          ),
          trailing: const Icon(AppIcons.chevron),
          onTap: () async {
            await Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => const SmartCleanupScreen()));
            onReturn?.call();
          },
        ),
      ),
    );
  }
}

/// Tüm-medya benzer taramasının dosya listesi ve tam liste yükleyicisi.
({List<FsEntry> files, Future<List<FsEntry>> Function() loadAll})
    _similarSource(BuildContext context, StorageIndex? index) {
  var locked = const <String>[];
  try {
    locked = context.read<AppState>().fmLockedFolders.toList();
  } catch (_) {
    // Testte AppState yok: kilitli klasör yok sayılır.
  }
  return (
    files: [
      ...?index?.files(FmCategory.image),
      ...?index?.files(FmCategory.video),
    ],
    loadAll: () async => [
          ...await MediaLibrary.categoryFiles(FmCategory.image,
              lockedFolders: locked),
          ...await MediaLibrary.categoryFiles(FmCategory.video,
              lockedFolders: locked),
        ],
  );
}

/// Yer aç'ın derin taramalarını **arka planda** başlatır (B18): benzer
/// kareler (Normal kademe) ve sohbet medyası. Kuyruk işleri SIRAYLA koştuğu
/// için hızlı taramanın arkasında beklerler — önce hızlı sonuçlar görünür.
/// Sonucu duran ya da süren tarama yeniden YAPILMAZ; yalnız "Gevşek" ile
/// üretilmiş benzer sonucu (ilgisiz görselleri gruplayabiliyor) Normal'le
/// yenilenir.
void startDeepScans(BuildContext context, StorageIndex? index) {
  final simId = SimilarFinder.jobIdFor(similarAllMediaScope);
  final sim = JobQueue.instance.find(simId);
  final simOk = sim != null &&
      (sim.status.isActive ||
          (sim.result is List<SimilarGroup> &&
              SimilarScreen.levelOf(similarAllMediaScope) !=
                  SimilarityLevel.loose));
  if (!simOk) {
    final src = _similarSource(context, index);
    SimilarScreen.startScan(
        scopeId: similarAllMediaScope,
        files: src.files,
        loadAll: src.loadAll);
  }
  final chat = JobQueue.instance.find(ChatJunkLive.jobId);
  if (chat == null ||
      (!chat.status.isActive && chat.result is! ChatJunkReport)) {
    ChatJunkLive.start(AppStrings.current);
  }
  ChatJunkLive.ensure();
}

/// Benzer görseller: hazır indeks varsa anında açılır, kilitli klasörler
/// hariç eksiksiz liste arka planda gelir. [picks] verilirse seçim Yer aç'la
/// paylaşılır (B18).
Future<void> openSimilarMedia(BuildContext context, StorageIndex? index,
    {Set<String>? picks}) {
  final src = _similarSource(context, index);
  return Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => SimilarScreen(
      scopeId: similarAllMediaScope,
      files: src.files,
      loadAll: src.loadAll,
      picks: picks,
    ),
  ));
}
