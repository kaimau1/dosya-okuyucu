part of '../app_strings.dart';

/// Çeviri tablosunun 12. bölümü: görsel/kullanım fazları (Faz 13–) — ortak
/// tür süzgeci, Son açılanlar.
const Map<String, (String, String, String)> _t12 = {
  // ── Ortak tür süzgeci (Faz 13) ────────────────────────────────────────────
  'type.text': ('Metin', 'Text', 'نص'),
  'type.ebook': ('E-kitap', 'E-book', 'كتاب إلكتروني'),
  'type.doc_other': ('Diğer belge', 'Other document', 'مستند آخر'),
  // ── Son açılanlar (Faz 13) ────────────────────────────────────────────────
  'oh.remove': ('Geçmişten kaldır', 'Remove from history', 'إزالة من السجل'),
  'oh.removed_n': (
    '{n} dosya geçmişten kaldırıldı',
    '{n} files removed from history',
    'أُزيل {n} ملف من السجل',
  ),

  // ── Görsel boyutlandırma 2.0 (Faz 14) ─────────────────────────────────────
  'enum.res_long_edge': ('Uzun kenar', 'Long edge', 'الحافة الطويلة'),
  'enum.res_aspect': ('En-boy oranı', 'Aspect ratio', 'نسبة العرض إلى الارتفاع'),
  'enum.res_file_size': ('Dosya boyutu', 'File size', 'حجم الملف'),
  'gal.resize': ('Boyut', 'Resize', 'تغيير الحجم'),
  'rs.presets': ('Hazır ayarlar', 'Presets', 'إعدادات جاهزة'),
  'rs.preset_profile': ('Profil 640×640', 'Profile 640×640', 'ملف شخصي 640×640'),
  'rs.preset_form': ('Başvuru ≤ 200 KB', 'Form upload ≤ 200 KB', 'نموذج ≤ 200 ك.ب'),
  'rs.preset_share': ('Paylaşım 4:5 · 1080', 'Social 4:5 · 1080', 'مشاركة 4:5 · 1080'),
  'rs.preset_web': ('Web 1600 px', 'Web 1600 px', 'ويب 1600 بكسل'),
  'rs.lock_on': ('Oran kilitli — dokun: kilidi aç', 'Aspect locked — tap to unlock', 'النسبة مقفلة — اضغط لفتحها'),
  'rs.lock_off': ('Oran serbest — dokun: kilitle', 'Aspect free — tap to lock', 'النسبة حرة — اضغط للقفل'),
  'rs.lock_note': (
    'Oran kilitli: birini yazın, öteki kendiliğinden hesaplanır. Birden çok dosyada her biri kendi oranını korur.',
    'Aspect locked: type one value, the other is calculated. With several files each keeps its own ratio.',
    'النسبة مقفلة: اكتب قيمة واحدة وتُحسب الأخرى. مع عدة ملفات يحتفظ كل ملف بنسبته.',
  ),
  'rs.unlock_note': (
    'Oran serbest: iki ölçüyü de yazın ve görüntünün kutuya nasıl yerleşeceğini seçin.',
    'Aspect free: type both values and choose how the picture fits the box.',
    'النسبة حرة: اكتب القيمتين واختر كيف تتسع الصورة في الإطار.',
  ),
  'rs.fit': ('Kutuya nasıl sığsın?', 'How should it fit?', 'كيف تتسع الصورة؟'),
  'rs.fit_contain': ('Sığdır', 'Fit inside', 'احتواء'),
  'rs.fit_cover': ('Doldur ve kırp', 'Fill and crop', 'ملء وقص'),
  'rs.fit_pad': ('Kenar boşluğu ekle', 'Add borders', 'إضافة حواف'),
  'rs.fit_stretch': ('Esnet (oran bozulur)', 'Stretch (distorts)', 'مط (يشوه النسبة)'),
  'rs.pad_white': ('Beyaz', 'White', 'أبيض'),
  'rs.pad_black': ('Siyah', 'Black', 'أسود'),
  'rs.pad_blur': ('Bulanık arka plan', 'Blurred background', 'خلفية ضبابية'),
  'rs.pad_transparent': ('Saydam', 'Transparent', 'شفاف'),
  'rs.aspect_cover': ('Kırp', 'Crop', 'قص'),
  'rs.aspect_pad': ('Kenar boşluğu ekle', 'Add borders', 'إضافة حواف'),
  'rs.aspect_w': ('En', 'Width', 'العرض'),
  'rs.aspect_h': ('Boy', 'Height', 'الارتفاع'),
  'rs.custom_value': ('Özel', 'Custom', 'مخصص'),
  'rs.long_edge_note': (
    'Uzun kenar bu değere iner, oran korunur. Zaten küçük olan fotoğraf büyütülmez.',
    'The long edge shrinks to this value, keeping the ratio. Smaller photos are not enlarged.',
    'تنكمش الحافة الطويلة إلى هذه القيمة مع الحفاظ على النسبة. لا تُكبَّر الصور الأصغر.',
  ),
  'rs.file_size_note': (
    'JPEG olarak kaydedilir; kalite (gerekirse ölçü) kendiliğinden ayarlanır. Hedefe inilemezse en yakın boyut bildirilir.',
    'Saved as JPEG; quality (and size if needed) is adjusted automatically. If the target cannot be reached, the closest size is reported.',
    'يُحفظ بصيغة JPEG؛ تُضبط الجودة (والأبعاد عند الحاجة) تلقائيًا. إن تعذّر بلوغ الهدف يُبلَّغ بأقرب حجم.',
  ),
  'rs.upscale_warning': (
    'Fotoğraf büyütülecek: dosya büyür ama netlik artmaz.',
    'The photo will be enlarged: the file grows but sharpness does not improve.',
    'سيُكبَّر الصورة: يزداد حجم الملف دون زيادة الوضوح.',
  ),
};
