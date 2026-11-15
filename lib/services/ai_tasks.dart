/// **Görev başına model** (2026-11-15, kullanıcı isteği: "notlarda yaptığımız
/// gibi her iş için ayrı model ve ona göre seçilmiş otomatik model").
///
/// Notlar uygulamasının `model_catalog.dart` görev zincirlerinin uyarlaması.
/// Uygulamadaki bütün AI istekleri `PooledGemini`nin üç yolundan geçer;
/// her yol bir göreve eşlenir:
/// - [AiTask.chat] — sohbet, özet, soru-cevap (`chat`);
/// - [AiTask.structured] — dosya analizi, adlandırma, etiket, slayt (JSON);
/// - [AiTask.vision] — görsel okuma / karşılaştırma.
///
/// Her görevde seçim "Otomatik" (boş) ya da elle bir model kimliğidir.
/// Otomatik = görevin zinciri, anahtarın model listesinde (katalog) GERÇEKTEN
/// bulunan kimliklerle; kimlik uydurulmaz. Zincirin sonunda kullanıcının
/// genel model sırası yedek olarak durur.
library;

enum AiTask { chat, structured, vision }

/// Zincir satırı: normalize edilmiş kimliğe uyan desen + kota notu.
class AiChainEntry {
  final String pattern;
  final String note;

  /// Yalnız kısa, düz metin işlerde (Gemma: 16K TPM, JSON/görsel yok).
  final bool shortOnly;

  const AiChainEntry(this.pattern, this.note, {this.shortOnly = false});
}

const _fl35 = AiChainEntry(r'gemini 3\.5 flash lite', 'Günde 500 istek — ana model');
const _fl31 =
    AiChainEntry(r'gemini 3\.1 flash lite(?! preview)', 'Günde 500 istek — yedek');
const _gemma31 = AiChainEntry(r'gemma 4 31b( it)?',
    'Günde 14.400 istek — yalnız kısa işler',
    shortOnly: true);
const _gemma26 = AiChainEntry(r'gemma 4 26b( a4b)?( it)?',
    'Günde 14.400 istek — yalnız kısa işler',
    shortOnly: true);
const _f38 = AiChainEntry(r'gemini 3\.8 flash', 'Günde 20 istek — güçlü');
const _f3 = AiChainEntry(r'gemini 3 flash', 'Günde 20 istek');
const _f25 = AiChainEntry(r'gemini 2\.5 flash', 'Günde 20 istek');
const _fl25 = AiChainEntry(r'gemini 2\.5 flash lite', 'Günde 20 istek');
const _f36 = AiChainEntry(r'gemini 3\.6 flash', 'Günde 20 istek — sık doluyor');
const _hydrogen =
    AiChainEntry(r'gemini 4 hydrogen', 'Günde 20 istek — sık doluyor');

/// Görev → deneme sırası. TEK YER: kotalar değişince yalnız burası.
const aiTaskChains = <AiTask, List<AiChainEntry>>{
  AiTask.chat: [
    _fl35, _fl31, _gemma31, _gemma26, //
    _f38, _f3, _f25, _fl25, _f36, _hydrogen,
  ],
  // JSON şeması: Gemma yok.
  AiTask.structured: [_fl35, _fl31, _f38, _f3, _f25, _fl25, _f36, _hydrogen],
  // Görsel: güçlü Flash önce, lite'lar yedek.
  AiTask.vision: [_f38, _f3, _fl35, _fl31, _f25, _fl25, _f36, _hydrogen],
};

/// Gemma'nın denenebileceği en uzun girdi (karakter; ~16K TPM'nin altı).
const aiShortInputChars = 12000;

String _normalize(String s) => s
    .toLowerCase()
    .replaceFirst('models/', '')
    .replaceAll(RegExp(r'[-_\s]+'), ' ')
    .trim();

bool _matches(AiChainEntry e, String id) =>
    RegExp('^(?:${e.pattern})(?: preview| latest| exp| \\d+)*\$')
        .hasMatch(_normalize(id));

/// Sohbet/metin işine uymayan kimlikler (seçicide gösterilmez).
final RegExp _notForText = RegExp(
  r'embed|aqa|tts|imagen|image|veo|lyria|live|native-audio|robotics|computer-use',
  caseSensitive: false,
);

bool isTextModel(String id) => !_notForText.hasMatch(id);

abstract final class AiTaskModels {
  /// Anahtarın son çekilen model listesi (`AppState` yazar).
  static List<String> catalog = const [];

  /// Görev → elle seçilen kimlik; yoksa / boşsa Otomatik.
  static Map<AiTask, String> choices = const {};

  /// [task]ın otomatik zinciri: katalogda bulunan, her satır için en kısa
  /// kimlik (önizlemesiz önce). [shortInput] değilse Gemma atlanır.
  static List<({String id, String note})> autoChain(AiTask task,
      {bool shortInput = true, List<String>? from}) {
    final cat = from ?? catalog;
    final out = <({String id, String note})>[];
    for (final e in aiTaskChains[task]!) {
      if (e.shortOnly && !shortInput) continue;
      final hits = [
        for (final id in cat)
          if (_matches(e, id) && !out.any((o) => o.id == id)) id,
      ]..sort((a, b) => a.length.compareTo(b.length));
      if (hits.isNotEmpty) out.add((id: hits.first, note: e.note));
    }
    return out;
  }

  /// İstekte denenecek model sırası: [elle seçim] → otomatik zincir →
  /// kullanıcının genel sırası ([fallback]). Yinelenen atılır.
  static List<String> resolve(AiTask task, List<String> fallback,
      {bool shortInput = true}) {
    final out = <String>[];
    void add(String id) {
      final t = id.trim();
      if (t.isNotEmpty && !out.contains(t)) out.add(t);
    }

    final chosen = choices[task];
    if (chosen != null && chosen.isNotEmpty) add(chosen);
    for (final m in autoChain(task, shortInput: shortInput)) {
      add(m.id);
    }
    for (final m in fallback) {
      add(m);
    }
    return out;
  }
}
