import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Ayarların **tek satır biçimi**.
///
/// KÖK NEDEN (2026-08-09 kullanıcı: *"ayarlar kısmımız çok karıştı, her yer her
/// yerde, tamamen sıfırdan tasarlanmalı ve yerleştirilmeli"*): eski iki ayar
/// ekranında beş ayrı satır tipi vardı — `SwitchListTile`, `ListTile` +
/// `PopupMenuButton`, kart içinde gömülü `SegmentedButton`, çıplak `TextField`,
/// başlıksız `Column`. Aynı işi yapan iki ayar iki farklı şekilde görünüyor,
/// göz her satırda yeniden "bu ne tipi bir şey" diye çözmek zorunda kalıyordu.
///
/// Artık **üç** biçim var ve hepsi buradan gelir: [SettingTile] (bir değeri
/// olan satır), [SettingSwitch] (açık/kapalı) ve [SettingChoice] (2-4 seçenek).
class SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Ne işe yaradığını söyleyen tek satır. Ayarın DEĞERİ değil.
  final String? subtitle;

  /// Satırın sağındaki **mevcut değer** ("Koyu", "Tarih ↓", "30 gün").
  /// Değerin alt satırda saklanması eski ekranların en sık hatasıydı: kullanıcı
  /// neyin seçili olduğunu görmek için her satırı açmak zorunda kalıyordu.
  final String? value;

  /// Değer yerine konan serbest bileşen (düğme, ilerleme çemberi).
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Alt satır uzunsa kırpma yerine sarma (yol, uzun açıklama).
  final bool wrapSubtitle;

  const SettingTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.wrapSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final faint = Paper.faint(context);
    return ListTile(
      // Kart içindeki satırlar: yatay boşluk 16, dikey 6 — grup kartının
      // kenarıyla hizalı (2026-08-29 tasarımı; ListTile varsayılanı kartın
      // içinde sola yapışık duruyordu).
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: wrapSubtitle ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              // Sabit punto YOK: kullanıcının uygulama içi yazı ölçeği
              // (Ayarlar > Yazı boyutu) burada da geçerli olmalı.
              style: theme.textTheme.bodySmall?.copyWith(color: faint),
            ),
      trailing: trailing ??
          (value == null
              ? (onTap == null ? null : const Icon(Icons.chevron_right))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        value!,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: faint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(Icons.chevron_right, color: faint, size: 20),
                  ],
                )),
      onTap: onTap,
    );
  }
}

/// Açık/kapalı ayar satırı — [SettingTile] ile aynı hizada durur.
class SettingSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingSwitch({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
        secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Paper.faint(context))),
        value: value,
        onChanged: onChanged,
      );
}

/// Az sayıda seçenek arasından seçim (tema, yazı boyutu, dil).
///
/// Ayrı bir açılır menü/alt sayfa DEĞİL: iki dokunuş uzaktaki bir tema seçimi
/// denenmeden bırakılıyordu. Etiketler dar ekranda taşabildiği için satır
/// yatayda kaydırılabilir.
class SettingChoice<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<(T value, String label)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const SettingChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 22 + 16 + 18 = 56: `ListTile`ın metin sütunuyla birebir
                // aynı hiza. Bir dp'lik kayma bile alt alta dizilen satırlarda
                // "hizasız" görünüyordu (2026-08-29).
                Icon(icon,
                    size: 22, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: Gap.md + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.bodyLarge),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Paper.faint(context))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<T>(
                showSelectedIcon: false,
                segments: [
                  for (final (value, label) in options)
                    ButtonSegment(value: value, label: Text(label)),
                ],
                selected: {selected},
                onSelectionChanged: (s) => onChanged(s.first),
              ),
            ),
          ],
        ),
      );
}
