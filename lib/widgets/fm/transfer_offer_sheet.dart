import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../app_dialog.dart';
import 'fm_entry_icon.dart';

/// Kabul penceresinde gösterilen tek öğe.
class OfferRow {
  final String name;
  final int size;

  /// Klasörse içindeki dosya sayısı.
  final int? folderFiles;

  /// Hazır küçük resim (Wi-Fi gönderiminde teklifle gelir).
  final Uint8List? thumb;

  /// Sonradan gelecek küçük resim (QR/tarayıcı sunucusundan çekilir).
  final Future<Uint8List?>? thumbLater;

  const OfferRow({
    required this.name,
    required this.size,
    this.folderFiles,
    this.thumb,
    this.thumbLater,
  });

  bool get isFolder => folderFiles != null;

  /// Klasör paketi `Ad.zip` olarak sunulur; kullanıcıya `Ad` görünür.
  String get displayName => folderFiles != null && name.toLowerCase().endsWith('.zip')
      ? name.substring(0, name.length - 4)
      : name;
}

/// **Gelen dosyalar — kabul ekranı** (2026-10-29 kullanıcı isteği: *"alıcıya
/// dosya gelmeden önce dosya adı, boyutu ve türünü (resim/video ise küçük
/// önizlemesini) gösteren bir kabul ekranı sunun"*).
///
/// Wi-Fi gönderimi, QR ve Bluetooth daveti AYNI pencereyi kullanır: kim
/// gönderiyor, kaç öğe, toplam ne kadar, nereye kaydedilecek ve küçük resimli
/// ızgara. Reddet = hiçbir bayt yazılmaz.
Future<bool> showTransferOffer(
  BuildContext context, {
  required String from,
  required List<OfferRow> items,
  required int count,
  required int totalBytes,
  required String saveDir,
}) async {
  AppHaptics.step();
  final ok = await showAppSheet<bool>(
    context,
    builder: (ctx) => _OfferBody(
      from: from,
      items: items,
      count: count,
      totalBytes: totalBytes,
      saveDir: saveDir,
    ),
  );
  return ok ?? false;
}

class _OfferBody extends StatelessWidget {
  final String from;
  final List<OfferRow> items;
  final int count;
  final int totalBytes;
  final String saveDir;

  const _OfferBody({
    required this.from,
    required this.items,
    required this.count,
    required this.totalBytes,
    required this.saveDir,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = items.take(12).toList();
    final more = (items.isEmpty ? count : items.length) - shown.length;
    final initial = from.trim().isEmpty ? '?' : from.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(initial, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('near.offer_title', {'from': from}),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('near.offer_sub', {
                        'n': count,
                        'size': FsPaths.humanSize(totalBytes),
                      }),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          if (shown.isNotEmpty)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Gap.sm,
              crossAxisSpacing: Gap.sm,
              childAspectRatio: 0.82,
              children: [for (final it in shown) _Tile(row: it)],
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: Text(context.t('near.offer_more', {'n': more}),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Icon(AppIcons.folder, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  context.t('near.offer_dest', {'dir': p.basename(saveDir)}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('offer-decline'),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(context.t('near.decline')),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const ValueKey('offer-accept'),
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(AppIcons.download),
                  label: Text(context.t('near.accept')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final OfferRow row;

  const _Tile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget icon() {
      if (row.folderFiles != null) {
        return const Icon(AppIcons.folder, size: 36, color: FmColors.folder);
      }
      final ext = p.extension(row.name).replaceFirst('.', '').toLowerCase();
      final c = FsEntry.categoryForExtension(ext);
      final (glyph, color) =
          FmColors.forExtension(ext) ?? (FmColors.iconFor(c), FmColors.forCategory(c));
      return Icon(glyph, size: 36, color: color);
    }

    Widget image(Uint8List bytes) => Image.memory(bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Center(child: icon()));

    final Widget media;
    if (row.thumb != null) {
      media = image(row.thumb!);
    } else if (row.thumbLater != null) {
      media = FutureBuilder<Uint8List?>(
        future: row.thumbLater,
        builder: (_, snap) => snap.data == null
            ? Center(child: icon())
            : image(snap.data!),
      );
    } else {
      media = Center(child: icon());
    }
    final sub = row.folderFiles != null
        ? context.t('near.folder_files', {'n': row.folderFiles})
        : FsPaths.humanSize(row.size);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.card),
            child: ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: media,
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(row.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall),
        Text(sub,
            maxLines: 1,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
