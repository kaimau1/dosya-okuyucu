import 'dart:convert';

/// Bir GitHub sürümündeki indirilebilir dosya.
class GithubAsset {
  final String name;
  final int sizeBytes;
  final String downloadUrl;
  const GithubAsset({
    required this.name,
    required this.sizeBytes,
    required this.downloadUrl,
  });
}

/// Bir GitHub sürümü (etiket + dosyalar).
class GithubRelease {
  final String tag;
  final String title;
  final List<GithubAsset> assets;
  const GithubRelease({
    required this.tag,
    required this.title,
    required this.assets,
  });
}

/// **GitHub sürüm bağlantısı desteği.**
///
/// Kullanıcı tarayıcıdan bir sürüm sayfasının adresini kopyalayıp yapıştırdığında
/// (`github.com/kaimau1/dosya-okuyucu/releases/latest`) o adres bir HTML
/// sayfasıdır — indirilirse elde 200 KB'lık işe yaramaz bir `.html` kalır.
/// Doğru davranış: adresi API'ye çevirip **dosya listesini** getirmek ve
/// kullanıcıya hangisini indireceğini sormak.
///
/// Saf fonksiyonlar (ağ yok) → adres kalıpları birim testiyle sabitlenir.

/// Adres bir GitHub **doğrudan dosya** bağlantısı mı?
/// (`.../releases/download/<etiket>/<dosya>` — API'ye gerek yok.)
bool isGithubAssetUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  if (host != 'github.com' && host != 'objects.githubusercontent.com') {
    return false;
  }
  final segments = uri.pathSegments;
  final index = segments.indexOf('releases');
  return index >= 0 &&
      index + 1 < segments.length &&
      segments[index + 1] == 'download';
}

/// GitHub sürüm/depo adresini **API adresine** çevirir; GitHub adresi değilse
/// ya da doğrudan dosya bağlantısıysa null.
///
/// Desteklenen kalıplar:
/// - `github.com/<sahip>/<depo>` → en son sürüm
/// - `github.com/<sahip>/<depo>/releases` → en son sürüm
/// - `github.com/<sahip>/<depo>/releases/latest` → en son sürüm
/// - `github.com/<sahip>/<depo>/releases/tag/<etiket>` → o sürüm
String? githubReleaseApiUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.toLowerCase() != 'github.com') return null;
  if (isGithubAssetUrl(url)) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return null;
  final owner = segments[0];
  final repo = segments[1].replaceAll(RegExp(r'\.git$'), '');
  const base = 'https://api.github.com/repos';

  if (segments.length == 2) return '$base/$owner/$repo/releases/latest';
  if (segments[2] != 'releases') return null;
  if (segments.length == 3) return '$base/$owner/$repo/releases/latest';
  if (segments[3] == 'latest') return '$base/$owner/$repo/releases/latest';
  if (segments[3] == 'tag' && segments.length >= 5) {
    return '$base/$owner/$repo/releases/tags/${Uri.encodeComponent(segments[4])}';
  }
  return null;
}

/// API yanıtını çözer. Yanıt bir liste ise (`/releases`) ilk sürüm alınır.
/// Çözülemezse null → çağıran "sürüm bilgisi alınamadı" der ve adresi
/// olduğu gibi indirmeyi önerir.
GithubRelease? parseGithubRelease(String body) {
  try {
    final data = jsonDecode(body);
    final map = data is List
        ? (data.isEmpty ? null : data.first)
        : (data is Map ? data : null);
    if (map is! Map) return null;

    final assets = <GithubAsset>[];
    final rawAssets = map['assets'];
    if (rawAssets is List) {
      for (final item in rawAssets) {
        if (item is! Map) continue;
        final name = item['name'];
        final url = item['browser_download_url'];
        if (name is! String || url is! String) continue;
        assets.add(GithubAsset(
          name: name,
          sizeBytes: (item['size'] as num?)?.toInt() ?? -1,
          downloadUrl: url,
        ));
      }
    }
    // Kaynak arşivleri her sürümde vardır ama listede görünmez; kullanıcı
    // "kaynak kodu" istiyorsa zaten tarayıcıdan indirir. Gürültü yapmıyoruz.
    final tag = (map['tag_name'] as String?) ?? '';
    return GithubRelease(
      tag: tag,
      title: (map['name'] as String?)?.trim().isNotEmpty == true
          ? map['name'] as String
          : (tag.isEmpty ? 'Sürüm' : tag),
      assets: assets,
    );
  } catch (_) {
    return null;
  }
}
