import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/bills.dart';
import '../../services/fm/entry_opener.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/native_extras.dart';
import '../../widgets/fm/fm_entry_icon.dart';

/// **Faturalar ve giderler** ekranı (bkz. [Bills]).
///
/// Üstte: bu ayın toplamı ve son ödemesi yaklaşanlar (kırmızı = geçmiş).
/// Altta: ay ay faturalar — kurum, tutar, son ödeme, "ödendi" kutusu.
class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  ({int done, int total})? _progress;

  @override
  void initState() {
    super.initState();
    Future.wait([Bills.instance.ensureLoaded(), AiIndex.ensureLoaded()])
        .then((_) {
      if (!mounted) return;
      setState(() {});
      // İlk açılışta bekleyen faturalar kendiliğinden okunur — kullanıcıya
      // "oku" düğmesi aratmayalım.
      if (Bills.instance.pending().isNotEmpty) _refresh();
    });
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    final strings = AppStrings.of(context);
    final n = await Bills.instance.refresh(
      gemini: state.hasApiKey ? state.gemini : null,
      onProgress: (done, total) {
        if (mounted) setState(() => _progress = (done: done, total: total));
      },
    );
    // Hatırlatma listesi yerel işe yazıldı; iş kurulu değilse kurulur.
    await NativeExtras.syncDailyJob();
    if (!mounted) return;
    setState(() => _progress = null);
    if (n > 0) showSnack(context, strings.t('bills.read_n', {'n': n}));
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _monthLabel(BuildContext context, int year, int month) =>
      '${context.t('bills.month_$month')} $year';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasKey = context.watch<AppState>().hasApiKey;
    return ListenableBuilder(
      listenable: Listenable.merge([Bills.instance, AiIndex.revision]),
      builder: (context, _) {
        final bills = Bills.instance;
        final months = bills.months();
        final upcoming = bills.upcoming();
        final pending = bills.pending().length;
        final now = DateTime.now();
        final thisMonth = months
            .where((m) => m.year == now.year && m.month == now.month)
            .firstOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.t('bills.title')),
            actions: [
              IconButton(
                tooltip: context.t('bills.refresh'),
                icon: const Icon(AppIcons.refresh),
                onPressed: bills.busy ? null : _refresh,
              ),
            ],
          ),
          body: ListView(
            padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
            children: [
              if (_progress != null) ...[
                Text(context.t('bills.reading', {
                  'n': _progress!.done + 1,
                  'total': _progress!.total,
                })),
                const SizedBox(height: Gap.xs),
                LinearProgressIndicator(
                  value: _progress!.total == 0
                      ? null
                      : _progress!.done / _progress!.total,
                ),
                const SizedBox(height: Gap.md),
              ],
              // Bu ayın özeti.
              Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.t('bills.this_month'),
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer)),
                      const SizedBox(height: Gap.xs),
                      Text(
                        thisMonth == null || thisMonth.totals.isEmpty
                            ? '—'
                            : thisMonth.totals.entries
                                .map((e) =>
                                    Bills.formatAmount(e.value, e.key))
                                .join(' + '),
                        style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer),
                      ),
                      Text(
                        context.t('bills.count_month',
                            {'n': thisMonth?.bills.length ?? 0}),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),
              if (!hasKey) ...[
                const SizedBox(height: Gap.sm),
                Text(context.t('bills.no_key'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
              if (pending > 0 && _progress == null) ...[
                const SizedBox(height: Gap.sm),
                FilledButton.tonalIcon(
                  onPressed: bills.busy ? null : _refresh,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text(context.t('bills.read_pending', {'n': pending})),
                ),
              ],
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: Gap.lg),
                Text(context.t('bills.upcoming'),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: scheme.error)),
                const SizedBox(height: Gap.xs),
                for (final b in upcoming) _row(context, b, highlight: true),
              ],
              if (months.isEmpty && _progress == null) ...[
                const SizedBox(height: Gap.xl),
                Icon(Icons.receipt_long_rounded,
                    size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: Gap.sm),
                Text(context.t('bills.empty'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium),
              ],
              for (final m in months) ...[
                const SizedBox(height: Gap.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(_monthLabel(context, m.year, m.month),
                          style: theme.textTheme.titleMedium),
                    ),
                    Text(
                      m.totals.entries
                          .map((e) => Bills.formatAmount(e.value, e.key))
                          .join(' + '),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                for (final b in m.bills) _row(context, b),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, Bill b, {bool highlight = false}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = FsEntry.ofPath(b.path);
    final overdue = !b.paid &&
        b.dueMs != null &&
        b.dueMs! < DateTime.now().millisecondsSinceEpoch;
    final dueText = b.dueMs == null
        ? null
        : context.t(overdue ? 'bills.overdue' : 'bills.due',
            {'date': _date(b.dueMs!)});
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.xs),
      color: highlight ? scheme.errorContainer : null,
      child: ListTile(
        onTap: () => EntryOpener.open(context, b.path),
        leading: entry == null
            ? const Icon(Icons.receipt_long_rounded)
            : FmEntryIcon(entry: entry, size: 44),
        title: Text(b.issuer.isEmpty ? context.t('bills.unknown') : b.issuer,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            b.amount == null
                ? context.t('bills.no_amount')
                : Bills.formatAmount(b.amount!, b.currency),
            if (dueText != null) dueText,
          ].join(' · '),
          style: TextStyle(
              color: overdue ? scheme.error : null,
              decoration: b.paid ? TextDecoration.lineThrough : null),
        ),
        trailing: Tooltip(
          message: context.t('bills.paid'),
          child: Checkbox(
            value: b.paid,
            onChanged: (v) async {
              await Bills.instance.setPaid(b.path, v ?? false);
              await NativeExtras.syncDailyJob();
            },
          ),
        ),
      ),
    );
  }
}
