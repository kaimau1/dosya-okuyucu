part of '../app_strings.dart';

/// Çeviri tablosunun 54. bölümü (2026-11-26, B16): internetsiz Arapça metin
/// tanıma (indirilebilir model) + metin tanıma dili seçeneklerinin alt yazısı.
const Map<String, (String, String, String)> _t54 = {
  'ocr.script_auto_sub': (
    'Cihazda tanır; Latin dışı yazı görürse Arapça modeli ya da akıllı okumayı dener.',
    'Recognises on the device; tries the Arabic model or smart reading for non-Latin text.',
    'يتعرّف على الجهاز؛ ويجرّب النموذج العربي أو القراءة الذكية للنص غير اللاتيني.',
  ),
  'ocr.script_latin_sub': (
    'Yalnız cihazda, internetsiz.',
    'On the device only, offline.',
    'على الجهاز فقط، دون إنترنت.',
  ),
  'ocr.script_arabic_sub': (
    'Arapça, Farsça, Urduca, Osmanlıca: indirilen modelle internetsiz; model yoksa akıllı okuma.',
    'Arabic, Persian, Urdu, Ottoman: offline with the downloaded model; smart reading otherwise.',
    'العربية والفارسية والأردية والعثمانية: دون إنترنت بالنموذج المُنزَّل؛ وإلا فبالقراءة الذكية.',
  ),
  'ocr.ar_model_get': (
    'İnternetsiz Arapça tanımayı indir',
    'Download offline Arabic recognition',
    'تنزيل التعرّف على العربية دون إنترنت',
  ),
  'ocr.ar_model_remove': (
    'İnternetsiz Arapça tanımayı sil',
    'Remove offline Arabic recognition',
    'حذف التعرّف على العربية دون إنترنت',
  ),
  'ocr.ar_model_sub': (
    'Bir kez iner (≈{size}), sonra metin cihazdan çıkmaz.',
    'Downloads once (≈{size}); text then never leaves the device.',
    'يُنزَّل مرة واحدة (≈{size})، ثم لا يغادر النص الجهاز.',
  ),
  'ocr.ar_model_loading': (
    'Arapça modeli iniyor… %{p}',
    'Downloading the Arabic model… {p}%',
    'جارٍ تنزيل النموذج العربي… {p}%',
  ),
  'ocr.ar_model_ready': (
    'İnternetsiz Arapça tanıma hazır.',
    'Offline Arabic recognition is ready.',
    'التعرّف على العربية دون إنترنت جاهز.',
  ),
  'ocr.ar_model_failed': (
    'Arapça modeli indirilemedi. Bağlantını denetleyip yeniden dene; bu arada Arapça tanıma akıllı okumayla (Gemini anahtarı) yapılabilir.',
    'Could not download the Arabic model. Check your connection and try again; meanwhile Arabic can be recognised with smart reading (Gemini key).',
    'تعذّر تنزيل النموذج العربي. تحقّق من الاتصال وأعد المحاولة؛ وفي الأثناء يمكن التعرّف على العربية بالقراءة الذكية (مفتاح Gemini).',
  ),
  'ocr.ar_need_model': (
    'Arapça metin tanıma için Ayarlar → Belgeler → Metin tanıma dili bölümünden internetsiz modeli indir ya da Gemini anahtarı ekle.',
    'For Arabic text recognition, download the offline model in Settings → Documents → Text recognition script, or add a Gemini key.',
    'للتعرّف على النص العربي، نزّل النموذج دون إنترنت من الإعدادات ← المستندات ← لغة التعرّف على النص، أو أضف مفتاح Gemini.',
  ),
};
