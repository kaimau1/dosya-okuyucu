/// **Evrensel menü içi arama motoru** (2026-11-24).
///
/// İki katmanda çalışır:
/// 1. **Normal metin / harf / kelime araması:** Türkçe harf eşleştirmesi
///    (`İ/i/I/ı`, `ş/s`, `ğ/g`, `ü/u`, `ö/o`, `ç/c`) ve Arapça hareke/harf
///    sadeleştirmesi ile birebir ön ek, sözcük başı ve alt dize puanlaması.
/// 2. **Geniş işlev / eşanlamlı sözlüğü:** Kullanıcının menü başlığını ezbere
///    bilmeden *ne yapmak istediğini* yazarak doğru eylemi bulması için
///    80+ kavramsal işlev kümesi (Türkçe, İngilizce, Arapça karşılıklar ve
///    gündelik ifadeler: ör. "paraf" → İmzala, "mb düşür" → Boyutu düşür,
///    "tercüme" → Çevir, "fosfor" → Vurgula, "kilit" → Kasa / Parola,
///    "çıktı" → Yazdır, "topla" → Formüller / TOPLA, "sabitle" → Dondur).
///
/// Saf Dart: Flutter bağımlılığı yok, birim testiyle sabitlenir ve tüm
/// menülerde ([MenuSections], [SideMenuView], [showFmMoreSheet] vb.) ortak
/// kullanılır.
abstract final class MenuSearch {
  /// Metni arama için sadeleştirir: küçük harf, Türkçe/Arapça işaret
  /// sadeleştirmesi, noktalama → tek boşluk.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final sb = StringBuffer();
    var lastSpace = true;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      final mapped = _foldChar(ch);
      if (mapped == ' ') {
        if (!lastSpace) {
          sb.write(' ');
          lastSpace = true;
        }
      } else if (mapped.isNotEmpty) {
        sb.write(mapped);
        lastSpace = false;
      }
    }
    return sb.toString().trim();
  }

  static String _foldChar(String ch) => switch (ch) {
        'I' || 'İ' || 'ı' || 'i' || 'Î' || 'î' || 'Í' || 'í' => 'i',
        'Ş' || 'ş' => 's',
        'Ğ' || 'ğ' => 'g',
        'Ü' || 'ü' || 'Û' || 'û' => 'u',
        'Ö' || 'ö' || 'Ô' || 'ô' => 'o',
        'Ç' || 'ç' => 'c',
        'Â' || 'â' || 'Á' || 'á' || 'À' || 'à' => 'a',
        'É' || 'é' || 'È' || 'è' || 'Ê' || 'ê' => 'e',
        'أ' || 'إ' || 'آ' => 'ا',
        'ة' => 'ه',
        'ى' => 'ي',
        // Arapça harekeler atılır.
        '\u064B' ||
        '\u064C' ||
        '\u064D' ||
        '\u064E' ||
        '\u064F' ||
        '\u0650' ||
        '\u0651' ||
        '\u0652' =>
          '',
        _ => _isWordChar(ch) ? ch.toLowerCase() : ' ',
      };

  static bool _isWordChar(String ch) {
    final code = ch.codeUnitAt(0);
    if ((code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122) || // a-z
        (code >= 0x0600 && code <= 0x06FF) || // Arabic
        code == 37 || // %
        code == 43 || // +
        code == 61) { // =
      return true;
    }
    return false;
  }

  /// Aday listeyi [query] için normal + işlev sözlüğü puanına göre süzüp
  /// en iyi eşleşmeden başlayarak sıralar. Boş sorguda girdiyi değiştirmez.
  static List<MenuSearchHit<T>> filter<T>(
    List<T> items,
    String query, {
    required String Function(T item) labelOf,
    String? Function(T item)? hintOf,
    String? Function(T item)? groupOf,
    Iterable<String> Function(T item)? keywordsOf,
  }) {
    final normQuery = normalize(query);
    if (normQuery.isEmpty) {
      return [
        for (final item in items) MenuSearchHit(item: item, score: 100),
      ];
    }
    final qTokens = normQuery.split(' ').where((t) => t.isNotEmpty).toList();
    if (qTokens.isEmpty) {
      return [
        for (final item in items) MenuSearchHit(item: item, score: 100),
      ];
    }

    // Sorgu belirteçlerinin eşleştiği işlev kümelerini bir kez çıkar.
    final queryClustersPerToken = <Set<int>>[
      for (final qt in qTokens) _clustersMatchingQueryToken(qt),
    ];

    final hits = <MenuSearchHit<T>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final label = normalize(labelOf(item));
      final hint = normalize(hintOf?.call(item) ?? '');
      final group = normalize(groupOf?.call(item) ?? '');
      final extra = keywordsOf == null
          ? ''
          : normalize(keywordsOf(item).join(' '));
      final combined = '$label $hint $group $extra'.trim();
      final labelWords = label.split(' ').where((w) => w.isNotEmpty).toList();

      // Tam ifade bonusu
      var totalScore = 0;
      var matchedByIntent = false;
      var allMatched = true;

      if (label == normQuery) {
        totalScore += 160;
      } else if (label.startsWith(normQuery)) {
        totalScore += 120;
      } else if (label.contains(normQuery)) {
        totalScore += 90;
      }

      Set<int>? itemClusters;

      for (var ti = 0; ti < qTokens.length; ti++) {
        final qt = qTokens[ti];
        var tokenScore = 0;

        if (label == qt) {
          tokenScore = 100;
        } else if (label.startsWith(qt)) {
          tokenScore = 90;
        } else if (labelWords.any((w) => w.startsWith(qt))) {
          tokenScore = 82;
        } else if (label.contains(qt)) {
          tokenScore = 72;
        } else if (hint.contains(qt) ||
            group.contains(qt) ||
            extra.contains(qt)) {
          tokenScore = 58;
        } else {
          // Normal eşleşme yok → işlev sözlüğüne bak.
          final qClusters = queryClustersPerToken[ti];
          if (qClusters.isNotEmpty) {
            itemClusters ??= _clustersForText(combined);
            final overlap = qClusters.any(itemClusters.contains);
            if (overlap) {
              tokenScore = 44;
              matchedByIntent = true;
            }
          }
        }

        if (tokenScore == 0) {
          allMatched = false;
          break;
        }
        totalScore += tokenScore;
      }

      if (allMatched && totalScore > 0) {
        hits.add(MenuSearchHit(
          item: item,
          score: totalScore,
          byIntent: matchedByIntent,
          order: i,
        ));
      }
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });
    return hits;
  }

  /// Bir öğenin doğrudan veya işlev sözlüğüyle eşleşip eşleşmediğini döner.
  static bool matches(
    String query, {
    required String label,
    String? hint,
    String? group,
    Iterable<String> keywords = const [],
  }) {
    if (normalize(query).isEmpty) return true;
    return filter<int>(
      const [0],
      query,
      labelOf: (_) => label,
      hintOf: (_) => hint,
      groupOf: (_) => group,
      keywordsOf: (_) => keywords,
    ).isNotEmpty;
  }

  // ── İşlev / Eşanlamlı Sözlüğü İndeksi (tembel, tek seferlik) ──────────────

  static Map<String, List<int>>? _wordToClusters;
  static List<List<String>>? _normClusters;

  static void _ensureIndex() {
    if (_wordToClusters != null) return;
    final map = <String, List<int>>{};
    final normList = <List<String>>[];
    for (var ci = 0; ci < _kIntentClusters.length; ci++) {
      final terms = <String>[];
      for (final raw in _kIntentClusters[ci]) {
        final n = normalize(raw);
        if (n.isEmpty) continue;
        terms.add(n);
        (map[n] ??= []).add(ci);
        // Çok kelimeli ifadelerdeki belirgin sözcükleri de bağla.
        if (n.contains(' ')) {
          for (final w in n.split(' ')) {
            if (w.length >= 3) {
              final list = map[w] ??= [];
              if (!list.contains(ci)) list.add(ci);
            }
          }
        }
      }
      normList.add(terms);
    }
    _wordToClusters = map;
    _normClusters = normList;
  }

  /// Sorgu belirtecinin (en az 2 harf) eşleştiği işlev kümeleri.
  static Set<int> _clustersMatchingQueryToken(String qt) {
    if (qt.length < 2) return const {};
    _ensureIndex();
    final map = _wordToClusters!;
    final out = <int>{};
    final exact = map[qt];
    if (exact != null) out.addAll(exact);
    // Ön ek / kök eşleşmesi (ör. "imz" → "imza", "sikist" → "sikistir").
    for (final entry in map.entries) {
      final term = entry.key;
      if (term.startsWith(qt) ||
          (qt.length >= 4 && term.length >= 4 && qt.startsWith(term))) {
        out.addAll(entry.value);
      }
    }
    return out;
  }

  /// Menü metninin ait olduğu işlev kümeleri.
  static Set<int> _clustersForText(String normalizedText) {
    if (normalizedText.isEmpty) return const {};
    _ensureIndex();
    final map = _wordToClusters!;
    final clusters = _normClusters!;
    final out = <int>{};
    final words = normalizedText.split(' ').where((w) => w.isNotEmpty).toList();
    for (final w in words) {
      final direct = map[w];
      if (direct != null) out.addAll(direct);
      if (w.length >= 4) {
        for (final entry in map.entries) {
          final term = entry.key;
          if (term.length >= 4 &&
              !term.contains(' ') &&
              (w.startsWith(term) || term.startsWith(w))) {
            out.addAll(entry.value);
          }
        }
      }
    }
    // Çok kelimeli ifade eşleşmeleri (ör. "sesli oku", "sayfa numarasi").
    for (var ci = 0; ci < clusters.length; ci++) {
      if (out.contains(ci)) continue;
      for (final term in clusters[ci]) {
        if (term.contains(' ') && normalizedText.contains(term)) {
          out.add(ci);
          break;
        }
      }
    }
    return out;
  }

  /// **Geniş İşlev ve Eşanlamlı Sözlüğü** (80+ kavramsal küme; TR + EN + AR).
  static const List<List<String>> _kIntentClusters = [
    // ── Dosya temel işlemleri ──────────────────────────────────────────────
    ['aç', 'görüntüle', 'bak', 'incele', 'göster', 'open', 'view', 'preview', 'فتح', 'عرض'],
    ['paylaş', 'gönder', 'yolla', 'ilet', 'aktar', 'whatsapp', 'telegram', 'share', 'send', 'مشاركة', 'إرسال'],
    ['kopyala', 'çoğalt', 'ikile', 'yedekle', 'pano', 'copy', 'duplicate', 'clone', 'نسخ', 'تكرار'],
    ['kes', 'taşı', 'naklet', 'klasör değiştir', 'yerini değiştir', 'cut', 'move', 'relocate', 'قص', 'نقل'],
    ['yapıştır', 'özel yapıştır', 'değerleri yapıştır', 'paste', 'clipboard', 'لصق'],
    ['sil', 'kaldır', 'çöp', 'temizle', 'yok et', 'at', 'boşalt', 'delete', 'remove', 'trash', 'clear', 'حذف', 'سلة'],
    ['yeniden adlandır', 'ad değiştir', 'isim değiştir', 'toplu adlandır', 'rename', 'name', 'إعادة تسمية'],
    ['bilgi', 'özellikler', 'ayrıntı', 'detay', 'boyut', 'konum', 'yol', 'exif', 'meta', 'info', 'properties', 'details', 'معلومات', 'خصائص'],
    ['önemli', 'yıldız', 'favori', 'sabitle', 'işaretli', 'pin', 'star', 'favorite', 'important', 'bookmark', 'مهم', 'مفضلة'],
    ['etiket', 'etiketle', 'renk', 'renklendir', 'kategori', 'tag', 'label', 'category', 'وسم', 'تصنيف'],
    ['sıkıştır', 'zip', 'arşiv', 'arşivle', 'paketle', 'rar', '7z', 'tar', 'compress', 'archive', 'zip', 'ضغط', 'أرشيف'],
    ['çıkar', 'arşivden çıkar', 'unzip', 'aç', 'extract', 'unpack', 'استخراج'],
    ['gizle', 'gizli', 'görünmez', 'sakla', 'bir daha önerme', 'hide', 'hidden', 'ignore', 'إخفاء'],
    ['kasa', 'kilitle', 'şifrele', 'parola', 'güvenli', 'özel', 'koru', 'kilit', 'vault', 'lock', 'password', 'encrypt', 'protect', 'private', 'خزنة', 'قفل', 'كلمة مرور'],
    ['kısayol', 'ana ekran', 'masaüstü', 'shortcut', 'home screen', 'اختصار'],
    ['başka uygulamayla aç', 'birlikte aç', 'harici', 'dış uygulama', 'open with', 'external', 'فتح بواسطة'],

    // ── Depolama, temizlik ve düzenleme ────────────────────────────────────
    ['yer aç', 'temizlik', 'gereksiz', 'hafıza', 'depolama', 'alan kazan', 'free up', 'cleanup', 'storage', 'space', 'تحرير', 'تنظيف'],
    ['kopya', 'yinelenen', 'benzer', 'çift', 'aynı dosya', 'duplicate', 'similar', 'مكرر', 'مشابه'],
    ['analiz', 'harita', 'klasör haritası', 'büyük dosya', 'grafik', 'dağılım', 'analysis', 'folder map', 'disk', 'تحليل'],
    ['akıllı düzen', 'otomatik düzenle', 'sınıflandır', 'ayıkla', 'fatura', 'belgeler', 'smart sort', 'organize', 'bills', 'تنظيم ذكي'],
    ['çöp kutusu', 'geri yükle', 'kurtar', 'geri al', 'undo', 'restore', 'recover', 'trash', 'استعادة', 'تراجع'],
    ['yinele', 'ileri al', 'redo', 'إعادة'],
    ['sırala', 'düzen', 'a-z', 'z-a', 'artan', 'azalan', 'boyuta göre', 'tarihe göre', 'sort', 'order', 'ascending', 'descending', 'فرز', 'ترتيب'],
    ['süz', 'süzgeç', 'filtre', 'filtrele', 'daralt', 'seç', 'filter', 'sift', 'تصفية', 'فلتر'],
    ['görünüm', 'ızgara', 'liste', 'sütun', 'kompakt', 'küçük resim', 'layout', 'grid', 'list', 'view', 'thumbnail', 'تخطيط', 'شبكة'],

    // ── Aktarım, ağ ve paylaşım ────────────────────────────────────────────
    ['aktar', 'yakındaki', 'wifi', 'bluetooth', 'qr', 'kod tara', 'bağlantı', 'link', 'transfer', 'nearby', 'hotspot', 'نقل', 'قريب'],
    ['bilgisayar', 'pc', 'ftp', 'ağ', 'smb', 'webdav', 'sunucu', 'uzak', 'computer', 'network', 'remote', 'server', 'كمبيوتر', 'شبكة'],
    ['bulut', 'drive', 'google drive', 'yedek', 'senkron', 'cloud', 'sync', 'backup', 'سحابة'],
    ['indir', 'indirmeler', 'download', 'downloads', 'تنزيل', 'التنزيلات'],

    // ── Görsel ve video araçları ───────────────────────────────────────────
    ['boyut düşür', 'küçült', 'mb düşür', 'hafiflet', 'kalite', 'yeniden boyutlandır', 'resize', 'shrink', 'optimize', 'reduce size', 'تصغير', 'تقليل الحجم'],
    ['döndür', 'çevir', 'yatay', 'dikey', 'sağa', 'sola', '90 derece', 'rotate', 'turn', 'orientation', 'تدوير'],
    ['kırp', 'kes', 'biç', 'kenar kes', 'trim', 'crop', 'clip', 'قص', 'اقتصاص'],
    ['iyileştir', 'netleştir', 'parlat', 'otomatik düzelt', 'onar', 'enhance', 'sharpen', 'fix', 'repair', 'تحسين'],
    ['slayt gösterisi', 'otomatik oynat', 'slideshow', 'عرض شرائح'],
    ['altyazı', 'ses kanalı', 'hız', 'yavaşlat', 'hızlandır', 'ekranı doldur', 'döngü', 'subtitle', 'audio track', 'speed', 'loop', 'ترجمة', 'سرعة'],

    // ── Belge ortak: kaydet, yazdır, dışa aktar, ara, çevir, sesli oku ────
    ['kaydet', 'farklı kaydet', 'dışa aktar', 'export', 'save', 'save as', 'حفظ', 'تصدير'],
    ['pdf yap', 'pdf olarak kaydet', 'pdf dönüştür', 'belgeye çevir', 'to pdf', 'export pdf', 'تحويل إلى PDF'],
    ['yazdır', 'çıktı', 'yazıcı', 'baskı', 'baskı önizleme', 'kağıt', 'print', 'printer', 'print preview', 'طباعة'],
    ['ara', 'bul', 'değiştir', 'kelime ara', 'metin ara', 'find', 'search', 'replace', 'بحث', 'استبدال'],
    ['çevir', 'tercüme', 'dil', 'ingilizce', 'türkçe', 'arapça', 'translate', 'translation', 'language', 'ترجمة'],
    ['sesli oku', 'dinle', 'konuş', 'sesli kitap', 'sesli not', 'okut', 'tts', 'read aloud', 'speak', 'listen', 'audiobook', 'voice', 'قراءة صوتية', 'استماع'],
    ['ocr', 'metin çıkar', 'yazı tanı', 'resimden yazı', 'aranabilir', 'tara', 'tarayıcı', 'scan', 'extract text', 'searchable', 'مسح', 'استخراج نص'],
    ['gece', 'karanlık', 'sepya', 'göz koruma', 'sarı', 'tema', 'okuma kipi', 'e-kitap', 'night', 'dark', 'sepia', 'reading', 'reader', 'ليلي', 'قراءة'],
    ['tam ekran', 'durum çubuğu', 'uyuma', 'ekran açık', 'otomatik kaydır', 'fullscreen', 'immersive', 'auto scroll', 'keep awake', 'ملء الشاشة'],
    ['sürüm', 'geçmiş', 'eski sürüm', 'geri dön', 'version', 'history', 'سجل', 'إصدار'],

    // ── PDF özel işlemleri ─────────────────────────────────────────────────
    ['imza', 'imzala', 'paraf', 'onayla', 'dijital imza', 'sertifika', 'sign', 'signature', 'initial', 'توقيع'],
    ['form', 'doldur', 'alan', 'onay kutusu', 'form alanı', 'fill', 'form', 'field', 'نموذج'],
    ['işaretle', 'kalem', 'çiz', 'serbest çizim', 'vurgula', 'fosfor', 'altını çiz', 'üstü çizili', 'not', 'damga', 'sansürle', 'karala', 'silgi', 'annotate', 'markup', 'draw', 'pen', 'highlight', 'redact', 'stamp', 'eraser', 'تمييز', 'رسم', 'قلم'],
    ['birleştir', 'pdf birleştir', 'ekle', 'topla', 'merge', 'combine', 'join', 'دمج'],
    ['böl', 'ayır', 'parçala', 'sayfa çıkar', 'sayfalar', 'sayfa sırala', 'sayfa ekle', 'sayfa sil', 'split', 'extract pages', 'reorder', 'pages', 'تقسيم', 'صفحات'],
    ['filigran', 'sayfa numarası', 'üst bilgi', 'alt bilgi', 'bates', 'kenar boşluğu', 'watermark', 'page number', 'header', 'footer', 'margin', 'علامة مائية'],
    ['içindekiler', 'anahat', 'yer imi', 'sayfaya git', 'atla', 'toc', 'outline', 'contents', 'goto', 'bookmark', 'فهرس', 'إشارة مرجعية'],
    ['yorum', 'yorumlar', 'notlar', 'not kitapçığı', 'kvkk', 'hassas veri', 'comment', 'notes', 'sensitive', 'تعليق', 'ملاحظات'],
    ['düzleştir', 'katmanları birleştir', 'flatten', 'تسطيح'],

    // ── Word özel işlemleri ────────────────────────────────────────────────
    ['kalın', 'koyu', 'italik', 'eğik', 'altı çizili', 'üstü çizili', 'biçim', 'biçimlendir', 'biçim boyacısı', 'bold', 'italic', 'underline', 'strike', 'format', 'style', 'عريض', 'مائل', 'تسطير'],
    ['yazı tipi', 'font', 'punto', 'yazı boyutu', 'büyüt', 'küçült', 'yazı rengi', 'vurgu rengi', 'font', 'size', 'color', 'text', 'خط', 'حجم', 'لون'],
    ['hizala', 'ortala', 'yasla', 'sola', 'sağa', 'paragraf', 'satır aralığı', 'girinti', 'align', 'center', 'justify', 'paragraph', 'spacing', 'indent', 'محاذاة', 'فقرة'],
    ['madde', 'liste', 'numaralı', 'madde işareti', 'bullet', 'numbered', 'list', 'قائمة', 'تعداد'],
    ['tablo', 'satır', 'sütun', 'hücre', 'başlık satırı', 'table', 'row', 'column', 'cell', 'جدول', 'صف', 'عمود'],
    ['resim', 'görsel', 'fotoğraf', 'ekle', 'koy', 'yerleştir', 'image', 'photo', 'picture', 'insert', 'صورة', 'إدراج'],
    ['bağlantı', 'köprü', 'url', 'dipnot', 'sonnot', 'simge', 'sembol', 'denklem', 'tarih', 'link', 'hyperlink', 'footnote', 'symbol', 'equation', 'رابط', 'حاشية'],
    ['değişiklikleri izle', 'karşılaştır', 'kabul', 'reddet', 'sözcük sayısı', 'kelime sayısı', 'istatistik', 'track changes', 'compare', 'word count', 'stats', 'مراجعة', 'إحصائيات'],
    ['sayfa düzeni', 'yatay', 'dikey', 'sayfa boyutu', 'a4', 'kenar boşluğu', 'kapak', 'page setup', 'landscape', 'portrait', 'margins', 'إعداد الصفحة'],
    ['akıllı yaz', 'yeniden yaz', 'düzelt', 'yazım denetimi', 'ai', 'rewrite', 'proofread', 'smart', 'ذكي'],

    // ── Excel özel işlemleri ───────────────────────────────────────────────
    ['formül', 'işlev', 'fx', 'hesapla', 'topla', 'ortalama', 'say', 'en büyük', 'en küçük', 'eğer', 'düşeyara', 'formula', 'function', 'sum', 'average', 'count', 'max', 'min', 'صيغة', 'دالة', 'مجموع'],
    ['sayı biçimi', 'para', 'tl', 'dolar', 'yüzde', 'ondalık', 'tarih biçimi', 'hücre biçimi', 'number format', 'currency', 'percent', 'decimal', 'تنسيق الأرقام'],
    ['grafik', 'pasta', 'çubuk', 'sütun', 'çizgi', 'alan', 'dağılım', 'halka', 'chart', 'graph', 'pie', 'bar', 'line', 'مخطط', 'رسم بياني'],
    ['dondur', 'sabitle', 'bölmeleri dondur', 'ilk satır', 'ilk sütun', 'freeze', 'panes', 'pin', 'تجميد'],
    ['birleştir', 'hücre birleştir', 'metni kaydır', 'sığdır', 'merge cells', 'wrap text', 'autofit', 'دمج الخلايا', 'التفاف'],
    ['doğrulama', 'veri doğrulama', 'açılır liste', 'kural', 'koşullu biçim', 'validation', 'conditional', 'dropdown', 'التحقق', 'شرطي'],
    ['yinelenenleri kaldır', 'tekilleştir', 'sütunlara böl', 'hızlı doldurma', 'seri doldur', 'özet tablo', 'pivot', 'alt toplam', 'grupla', 'deduplicate', 'split', 'flash fill', 'subtotal', 'group', 'محوري'],
    ['csv', 'sekme', 'çalışma sayfası', 'yeni sayfa', 'sheet', 'tab', 'worksheet', 'ورقة'],

    // ── Slayt / Sunum özel işlemleri ───────────────────────────────────────
    ['slayt', 'yeni slayt', 'sunum', 'sıralayıcı', 'slayt sıralayıcı', 'slide', 'presentation', 'sorter', 'شريحة', 'عرض تقديمي'],
    ['oynat', 'sun', 'başlat', 'sunucu görünümü', 'prova', 'anlatım kaydet', 'play', 'present', 'presenter', 'rehearse', 'record', 'تشغيل', 'تقديم'],
    ['tasarım', 'şablon', 'tema', 'arka plan', 'düzen', 'ana slayt', 'master', 'design', 'template', 'background', 'layout', 'تصميم', 'قالب'],
    ['şekil', 'metin kutusu', 'ok', 'kare', 'daire', 'çizgi', 'smartart', 'dolgu', 'kenarlık', 'saydamlık', 'katman', 'öne getir', 'arkaya gönder', 'shape', 'text box', 'fill', 'opacity', 'layer', 'bring front', 'send back', 'شكل', 'مربع نص'],
    ['geçiş', 'animasyon', 'efekt', 'hareket', 'biçim değiştir', 'transition', 'animation', 'morph', 'effect', 'انتقال', 'حركة'],
    ['konuşmacı notu', 'not ekle', 'video dışa aktar', 'mp4', 'png', 'speaker notes', 'export video', 'ملاحظات المتحدث'],

    // ── Uygulama genel & ayarlar ───────────────────────────────────────────
    ['ayarlar', 'tercihler', 'görünüm', 'yazı boyutu', 'dil', 'titreşim', 'hakkında', 'yardım', 'geri bildirim', 'hata bildir', 'settings', 'preferences', 'appearance', 'help', 'feedback', 'إعدادات', 'مساعدة'],
    ['ana sayfa', 'pano', 'başlangıç', 'home', 'dashboard', 'الرئيسية'],
    ['konumlar', 'dahili', 'sd kart', 'usb', 'bellek', 'depolama', 'internal', 'sd card', 'usb', 'places', 'التخزين'],
  ];
}

/// Arama eşleşme sonucu.
class MenuSearchHit<T> {
  final T item;
  final int score;

  /// Yalnız işlev/eşanlamlı sözlüğü üzerinden eşleştiyse `true`.
  final bool byIntent;
  final int order;

  const MenuSearchHit({
    required this.item,
    required this.score,
    this.byIntent = false,
    this.order = 0,
  });
}
