# Olay müdahalesi (G12.3)

Sakin ol, sırayla ilerle, her adımı tarihle `HAFIZA.md`'ye yaz (KVKK: sır/değer YAZMA).

## (a) İmza anahtarı sızdı
1. GitHub → Settings → Secrets → `ANDROID_KEYSTORE_B64` / parolaları **sil** (yeni derleme sızan anahtarla imzalanmasın).
2. Play'de ise: Play App Signing kullanılıyorsa yalnız **yükleme anahtarı** sızmıştır → Play Console → Uygulama bütünlüğü → "Yükleme anahtarını sıfırla". Değilse uygulama anahtarı değiştirilemez → yeni paket adıyla yeniden yayın (kullanıcıya duyuru).
3. GitHub dağıtımı: yeni anahtar → kullanıcılar eski APK'nın üstüne KURAMAZ (imza uyuşmaz) → README + Release notunda "kaldırıp yeniden kurun" duyurusu; eski sürümler budanır.
4. `SIGNING.md`'ye ne olduğu ve yeni anahtarın yedekleri.

## (b) Depoya sır commit edildi
1. Sırrı kaynağında **hemen iptal et** (Gemini anahtarını Google AI Studio'dan sil, belirteci GitHub'dan iptal et) — geçmişten silmek tek başına YETMEZ (klonlar/önbellekler).
2. Yenisini yalnız GitHub Secrets'a koy.
3. Geçmişten temizle (`git filter-repo --replace-text`), zorla it — yalnız kullanıcı onayıyla (tek dal main, CLAUDE.md §4).
4. Settings → Code security → Secret scanning + push protection açık mı bak (G9.5).

## (c) Yayındaki sürümde güvenlik açığı
1. Düzelt → commit başlığında `[apk]`, gövdede `Düzeltme: güvenlik düzeltmesi — …` (ayrıntı yazma; istismar tarifi olmasın).
2. Yeni sürüm yayınlanınca `ci/min_guvenli_surum.txt`'ye o sürümü yaz → `[apk]` → eski kurulumlar her açılışta "Güvenlik güncellemesi gerekli" görür (G12.4, `AppUpdate`).
3. Açığı bildiren varsa 90 gün içinde teşekkür + bilgi (`SECURITY.md`).
4. `docs/GUVENLIK_PLANI.md` bulgular tablosuna B-N satırı + düzeltme commit'i.

## (d) Bağımlılıkta açık
1. Dependabot/osv uyarısındaki paket ve sürüm aralığı → `pubspec.lock`'ta bizim sürüm etkileniyor mu?
2. Etkileniyorsa yükselt (override/sabit varsa gerekçesini oku — `pubspec.yaml` yorumları); yükseltilemiyorsa etkilenen özelliği bayrakla kapat.
3. PDFium/pdfrx (yerel kod) açıklarında beklemeden (c) yolu: güncelle + `min_guvenli`.
