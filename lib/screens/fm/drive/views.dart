part of '../drive_screen.dart';

extension _DriveScreenViewsPart on _DriveScreenState {
  /// Panodaki öğeyi bulunulan klasöre yapıştırma çubuğu — yerel gezgindeki
  /// çubuğun aynısı (`browser_screen`), kullanıcı iki ekranda aynı şeyi görsün.
  Widget _pasteBar() {
    final clip = _clip!;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              Icon(clip.cut ? Icons.content_cut : Icons.copy_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t('fm.clipboard_ready', {
                    'n': 1,
                    'verb': context
                        .t(clip.cut ? 'fm.verb_move' : 'fm.verb_copy'),
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _partSetState(() => _clip = null),
                child: Text(context.t('common.cancel')),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _paste,
                icon: const Icon(Icons.content_paste),
                label: Text(context.t('fm.paste')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kırıntı yolu: kökten bulunulan klasöre. Herhangi bir parçaya dokunmak
  /// oraya döner — derin klasörde tek tek geri gitmek zorunda kalınmasın.
  Widget _breadcrumb() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // derin yolda SON parça görünür kalsın
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < _path.length; i++) ...[
              if (i > 0)
                Icon(Icons.chevron_right,
                    size: 16, color: scheme.onSurfaceVariant),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: i == _path.length - 1 || _busy
                    ? null
                    : () {
                        _partSetState(() => _path.removeRange(i + 1, _path.length));
                        _refresh();
                      },
                child: Text(
                  i == 0 ? context.t('drive.root') : _path[i].$2,
                  style: TextStyle(
                    fontWeight: i == _path.length - 1
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorBar() {
    final scheme = Theme.of(context).colorScheme;
    final detail = _errorDetail;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t(_error!),
              style: TextStyle(color: scheme.onErrorContainer)),
          // Ham platform hatası: yalnız sınıflandıramadığımızda. Kullanıcıya
          // anlamsız gelebilir ama bildirebileceği TEK ipucu bu; gizlemek
          // "olmadı"dan başka bir şey söyleyemez hâle getiriyordu.
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              detail,
              style: TextStyle(
                  fontSize: 11,
                  color: scheme.onErrorContainer.withValues(alpha: 0.8)),
            ),
          ],
        ],
      ),
    );
  }

  /// Google Cloud kaydı için gereken İKİ değeri telefondan kopyalatır.
  ///
  /// "Kayıt yap" demek yetmiyordu: kullanıcının elinde ne paket adı ne de
  /// imza SHA-1 vardı ("google drive girmiyorum", 2026-08-05). SHA-1 kurulu
  /// APK'nın KENDİ imza sertifikasından okunur (`AppSignature`), yani hangi
  /// derleme kurulmuş olursa olsun kayıt için doğru değerdir.
  Widget _setupCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('drive.setup_title'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(context.t('drive.setup_steps'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          _setupValue(
              context.t('drive.setup_package'), AppSignature.packageName),
          // SHA-1 asenkron okunur; gelene kadar satır hiç çizilmez (yanlış ya
          // da yarım değer göstermekten iyidir).
          if (_sha1 != null) _setupValue(context.t('drive.setup_sha1'), _sha1!),
        ],
      ),
    );
  }

  Widget _setupValue(String label, String value) {
    final copied = context.t('drive.setup_copied');
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            '$label: $value',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        IconButton(
          tooltip: context.t('common.copy'),
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            // Yalnız DEĞER kopyalanır: Cloud formu "Paket adı: com…" gibi
            // etiketli bir yapıştırmayı reddederdi.
            await Clipboard.setData(ClipboardData(text: value));
            _snack(copied);
          },
        ),
      ],
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            isDense: true,
            hintText: context.t('drive.search_hint'),
            prefixIcon: const Icon(Icons.search),
            // Aramayı bitirmenin görünür bir yolu olmalı: yoksa kullanıcı
            // metni tek tek silmeden bulunduğu klasöre dönemezdi.
            suffixIcon: _searching
                ? IconButton(
                    tooltip: context.t('common.clear'),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      _partSetState(() => _query = '');
                      _refresh();
                    },
                  )
                : null,
          ),
          onChanged: (v) => _partSetState(() => _query = v),
          onSubmitted: (_) => _refresh(),
        ),
      );

  Widget _body() {
    if (_busy) return const FmListSkeleton();
    if (!_signedIn) {
      // Kaydırılabilir: hata şeridi + kurulum kartı açıkken (ya da küçük
      // ekranda) sabit Column dikeyde taşıyordu.
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_outlined, size: 56),
              const SizedBox(height: 16),
              Text(context.t('drive.sign_in_prompt'),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login),
                label: Text(context.t('drive.sign_in')),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              // Giriş çalışmasa bile Drive'a ulaşmanın ÇALIŞAN yolu.
              Text(context.t('drive.system_picker_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openViaSystemPicker,
                icon: const Icon(Icons.folder_open_outlined),
                label: Text(context.t('drive.open_via_system')),
              ),
            ],
          ),
        ),
      );
    }
    // Hata varken "henüz yüklemediniz" YAZILMAZ: liste boş çünkü çağrı
    // başarısız oldu, kullanıcı bir şey yüklemediği için değil. İkisini birden
    // göstermek kullanıcıyı "yükleme yapayım da dolsun" diye yanlış yola
    // sokuyordu (ekran görüntüsü 2026-08-05).
    if (_files.isEmpty) {
      if (_error != null) return const SizedBox.shrink();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.t(_searching ? 'drive.empty_search' : 'drive.empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final f = _files[i];
          return ListTile(
            leading: _driveIcon(f),
            title: Row(
              children: [
                if (f.starred) ...[
                  const Icon(Icons.star, size: 16, color: Color(0xFFF9A825)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(f.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            subtitle: Text(_subtitle(f),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'download' => _downloadToFolder(f),
                'share_link' => _shareLink(f),
                'share_file' => _shareFile(f),
                'copy' => _clipSet(f, cut: false),
                'cut' => _clipSet(f, cut: true),
                'star' => _toggleStar(f),
                'info' => _info(f),
                'rename' => _rename(f),
                'delete' => _delete(f),
                _ => null,
              },
              itemBuilder: (_) => [
                // Klasör indirilemez: Drive'da klasörün baytı yok, içeriğinin
                // tek tek inmesi gerekirdi — ayrı bir iş.
                if (!f.isFolder)
                  PopupMenuItem(
                    value: 'download',
                    child: Text(context.t('drive.download')),
                  ),
                PopupMenuItem(
                  value: 'share_link',
                  child: Text(context.t('drive.share_link')),
                ),
                // Klasörün "dosyası" yok: indirilip eklenecek tek bir şey
                // olmadığı için yalnız bağlantısı paylaşılabilir.
                if (!f.isFolder)
                  PopupMenuItem(
                    value: 'share_file',
                    child: Text(context.t('drive.share_file')),
                  ),
                // Kopyala/Taşı aramada YOK: kaynak klasör bilinmeden taşıma
                // yapılamaz (arama Drive'ın tamamını tarar). Klasör kopyalama
                // ise Drive API'sinde hiç yok.
                if (!_searching && !f.isFolder)
                  PopupMenuItem(
                    value: 'copy',
                    child: Text(context.t('fm.copy')),
                  ),
                if (!_searching)
                  PopupMenuItem(
                    value: 'cut',
                    child: Text(context.t('fm.move')),
                  ),
                PopupMenuItem(
                  value: 'star',
                  child: Text(context
                      .t(f.starred ? 'drive.unstar' : 'drive.star')),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Text(context.t('drive.info')),
                ),
                PopupMenuItem(
                  value: 'rename',
                  child: Text(context.t('drive.rename')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.t('common.delete')),
                ),
              ],
            ),
            // Klasöre dokunmak İÇİNE girer; arama sonucundaysa da girilebilir
            // (arama temizlenip o klasör açılır).
            onTap: f.isFolder ? () => _enter(f) : () => _open(f),
          );
        },
      ),
    );
  }

  /// Satırın simgesi — yerel gezginle AYNI kural (`FmEntryIcon`).
  ///
  /// Belgelerde `FileTypeIcon`: **PDF kırmızı PDF simgesi, Excel yeşil tablo,
  /// Word mavi belge** (2026-08-07 kullanıcı: *"şu an hepsi aynı belge işareti
  /// var"* — kategori ikonu bütün belgeleri tek tip gösteriyordu). Belge
  /// olmayanlarda kategori paleti: APK yeşil android, görüntü mor, arşiv…
  ///
  /// Google biçimlerinde adın uzantısı yoktur; `DriveFile.extension` dışa
  /// aktarım uzantısına düştüğü için Google E-Tablolar da Excel simgesiyle
  /// görünür — indirilince gerçekten .xlsx olacak.
  Widget _driveIcon(DriveFile f) {
    const size = 34.0;
    if (f.category == FmCategory.document) {
      return SizedBox(
        width: size,
        height: size,
        child: FileTypeIcon(
          kind: FileService.iconKindForExtension(f.extension),
          size: size,
        ),
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = FmColors.forCategory(f.category);
    return SizedBox(
      width: size,
      height: size,
      child: Icon(
        FmColors.iconFor(f.category),
        // Koyu temada marka renkleri sönüyor — gezgindeki aynı düzeltme.
        color: dark ? Color.lerp(base, Colors.white, 0.25) : base,
        size: size * 0.92,
      ),
    );
  }

  /// Satırın alt yazısı: **boyut · son değiştirilme** — yerel gezgindeki
  /// düzenin aynısı (`browser_screen`).
  ///
  /// Tarih 2026-08-07'de eklendi (kullanıcı ekran görüntüsü: listede yalnız
  /// "24 MB" yazıyordu, aynı adın iki sürümünden hangisinin yeni olduğu
  /// anlaşılmıyordu). Klasörde boyut yazılmaz — Drive klasörün baytını
  /// vermez, "—" göstermek satırı gereksiz doldururdu.
  ///
  /// Boyut bilinmiyorsa "—". "0 B" yazmak yanlış olurdu: Google Dokümanları'nın
  /// bayt karşılığı YOKTUR, boş oldukları anlamına gelmez.
  String _subtitle(DriveFile f) {
    final when = FsPaths.humanDate(f.modifiedAtMs);
    if (f.isFolder) return when;
    final size = f.sizeBytes > 0 ? FsPaths.humanSize(f.sizeBytes) : '—';
    if (f.isGoogleDoc) {
      final ext = f.exportAs?.$2;
      return ext == null
          ? '$size · $when'
          : '$size · ${context.t('drive.exports_as', {
                  'format': ext.toUpperCase()
                })} · $when';
    }
    return '$size · $when';
  }
}
