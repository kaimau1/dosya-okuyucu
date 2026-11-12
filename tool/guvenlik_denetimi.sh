#!/usr/bin/env bash
# Güvenlik denetimi (docs/GUVENLIK_PLANI.md Faz G0). Flutter gerektirmez.
# Amaç: kapatılmış açıkların geri gelmesini ve yeni (onaysız) saldırı yüzeyini CI'da yakalamak.
# Kullanım: bash tool/guvenlik_denetimi.sh   (kök dizinden)
# İhlal -> ::error:: + çıkış 1. BEKLEYEN'deki kural numaraları yalnız ::warning:: basar.
set -euo pipefail
cd "$(dirname "$0")/.."

# Henüz kapanmamış kurallar (uyarı kipi). İlgili faz bitince numarayı buradan ÇIKAR:
#   3 -> G2.4 (Gemini anahtarı URL'den çıkınca)   (kural 4 G1 ile kapandı, 2026-11-11)
#   6 -> G9.1 (Actions SHA'ya sabitlenince)
BEKLEYEN=""

# ── İzin listeleri (yeni giriş = bilinçli güvenlik kararı; gerekçe şart) ──────────
# Kural 2: güvenli olmayan Random() kullanabilen dosyalar (sır/kod ÜRETMEZ).
RANDOM_IZIN="
lib/services/fm/audio_playback.dart|karıştırma (shuffle), sır değil
lib/services/docx/docx_media.dart|belge içi şekil kimliği, sır değil
lib/services/pptx/pro/pptx_deck_ops.dart|tohumlu rastgele kimlik, sır değil
lib/services/docx/pro/docx_fonts.dart|tohumlu Random(seed) yalnız seed!=0 (belirlenimli test); varsayılan Random.secure()
"
# Kural 4: dışa açık (exported=true) manifest bileşenleri: ad|gerekçe
EXPORTED_IZIN="
.MainActivity|başlatıcı + VIEW/SEND süzgeçleri (dış uygulamalardan dosya açma); ek doğrulaması G1
.PickerActivity|GET_CONTENT/OPEN_DOCUMENT seçici kipi (diğer uygulamalar dosya ister)
.DosyaProvider|DocumentsProvider; android:permission=MANAGE_DOCUMENTS ile korunur
.StorageWidget|AppWidget alıcısı (APPWIDGET_UPDATE sistemden gelir)
.RecentWidget|AppWidget alıcısı (APPWIDGET_UPDATE sistemden gelir)
.AjanServisi|AppFunctionService; BIND_APP_FUNCTION_SERVICE izniyle korunur
"
# Kural 7: ağ soketi/sunucu açabilen dosyalar: dosya|gerekçe
BIND_IZIN="
lib/services/voice/neural_voices.dart|yalnız 127.0.0.1 (WebView ses dosyaları)
lib/services/fm/remote/http_share_server.dart|yerel ağ HTTP paylaşım (Basic Auth); sertleştirme G4
lib/services/fm/remote/ftp_server.dart|telefon FTP sunucusu (parola); sertleştirme G4
lib/services/fm/remote/qr_transfer.dart|QR ile tek seferlik aktarım; sertleştirme G4
lib/services/fm/remote/peer_share.dart|eşler arası paylaşım + UDP keşif; sertleştirme G4/G5
lib/screens/editors/slideshow/remote.dart|slayt uzaktan kumanda sunucusu; sertleştirme G4
"
# Kural 8: JavaScriptMode.unrestricted kullanabilen dosyalar: dosya|gerekçe
JS_IZIN="
lib/services/voice/neural_engine.dart|yerel ses motoru sayfası (kendi varlıkları); WebView sertleştirme G6
lib/widgets/docx_view.dart|Word görüntüleyici (assets/word/viewer.html); CSP/gezinti kısıtı G6
"

HATA=0
bekleyen_mi() { case " $BEKLEYEN " in *" $1 "*) return 0;; *) return 1;; esac; }
# $1 kural no, $2 mesaj
ihlal() {
  if bekleyen_mi "$1"; then
    echo "::warning::[G0 kural $1 BEKLEYEN] $2"
  else
    echo "::error::[G0 kural $1] $2"; HATA=1
  fi
}
# $1 izin listesi, $2 anahtar -> 0 ise listede (satır başı "anahtar|")
izinli() {
  local satir
  while IFS= read -r satir; do
    [ "${satir%%|*}" = "$2" ] && return 0
  done <<<"$1"
  return 1
}

# 1) Sertifika doğrulamasını kapatan kod yasak.
kural1() {
  local r; r=$(grep -rnE 'badCertificateCallback|onBadCertificate' lib || true)
  [ -z "$r" ] || ihlal 1 "TLS doğrulaması kapatılamaz: $r"
}

# 2) Güvenli olmayan Random() yalnız izin listesinde. Sır/kod üretiyorsan Random.secure().
kural2() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    izinli "$RANDOM_IZIN" "$f" || ihlal 2 "$f: Random() izin listesinde değil — sır/kod üretiyorsan Random.secure() kullan"
  done < <(grep -rlE '(^|[^.A-Za-z_])(math\.)?Random\(' lib || true)
}

# 3) Uri.parse içinde ?key= / &key= / password= (sır URL'ye konmaz). G2.4 ile hata kipinde (2026-11-11).
kural3() {
  local r; r=$(grep -rnE 'Uri\.parse\(.*(\?key=|&key=|password=)' lib || true)
  [ -z "$r" ] || ihlal 3 "Sır URL sorgusunda (vekil/log'a düşer); başlık kullan: $r"
}

# 4) Manifest: allowBackup=false + dışa açık bileşenler izin listesinde (XML yorumları atlanır).
kural4() {
  local m=ci/AndroidManifest.xml out n
  out=$(python3 - "$m" <<'PY'
import sys, xml.etree.ElementTree as ET
A = '{http://schemas.android.com/apk/res/android}'
app = ET.parse(sys.argv[1]).getroot().find('application')
print('BACKUP=' + (app.get(A + 'allowBackup') or 'yok'))
for tag in ('activity', 'activity-alias', 'service', 'receiver', 'provider'):
    for e in app.iter(tag):
        if e.get(A + 'exported') == 'true':
            print('EXP=' + e.get(A + 'name'))
PY
  )
  grep -qx 'BACKUP=false' <<<"$out" || ihlal 4 "$m: android:allowBackup=\"false\" yok (B3)"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    izinli "$EXPORTED_IZIN" "$n" || ihlal 4 "$m: dışa açık bileşen izin listesinde değil: $n (EXPORTED_IZIN'e gerekçeyle ekle)"
  done < <(sed -n 's/^EXP=//p' <<<"$out")
}

# 5) Şifresiz HTTP yalnız 127.0.0.1/localhost.
kural5() {
  local f=ci/res/xml/network_security_config.xml d
  if grep -q '<base-config[^>]*cleartextTrafficPermitted="true"' "$f"; then
    ihlal 5 "$f: base-config şifresiz trafiğe izin veriyor"
  fi
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$d" in 127.0.0.1|localhost) ;; *) ihlal 5 "$f: şifresiz HTTP izinli alan: $d";; esac
  done < <(python3 - "$f" <<'PY'
import sys, xml.etree.ElementTree as ET
for dc in ET.parse(sys.argv[1]).getroot().iter('domain-config'):
    if dc.get('cleartextTrafficPermitted') == 'true':
        for d in dc.iter('domain'):
            print((d.text or '').strip())
PY
  )
}

# 6) Actions `uses:` 40 haneli SHA'ya sabit (yerel ./ ve docker hariç). G9.1'den sonra açılır.
kural6() {
  local r
  r=$(grep -nE '^\s*-?\s*uses:' .github/workflows/*.yml \
      | grep -vE 'uses:\s*(\./|docker://)' \
      | grep -vE 'uses:\s*[^[:space:]@]+@[0-9a-f]{40}(\s|$)' || true)
  [ -z "$r" ] || ihlal 6 "Actions SHA'ya sabit değil: $(printf '%s' "$r" | head -3 | tr '\n' ';') ..."
}

# 7) Ağ dinleyen kod yalnız izin listesindeki dosyalarda.
kural7() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    izinli "$BIND_IZIN" "$f" || ihlal 7 "$f: yeni sunucu/soket (bind) izin listesinde değil — tehdit modeli + gerekçe ekle"
  done < <(grep -rlE 'HttpServer\.bind(Secure)?\(|ServerSocket\.bind\(|RawDatagramSocket\.bind\(|SecureServerSocket\.bind\(' lib || true)
}

# 8) JavaScriptMode.unrestricted yalnız izin listesinde.
kural8() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    izinli "$JS_IZIN" "$f" || ihlal 8 "$f: JavaScriptMode.unrestricted izin listesinde değil"
  done < <(grep -rl 'JavaScriptMode.unrestricted' lib || true)
}

# 9) Depoda anahtar/sır dosyası ve Google API anahtarı deseni yok (izlenen dosyalara bakar).
kural9() {
  local r
  r=$(find . -path ./.git -prune -o -path ./build -prune -o -path ./.dart_tool -prune -o -path ./.claude -prune -o \
        \( -name '*.jks' -o -name '*.keystore' -o -name 'google-services.json' \) -print || true)
  [ -z "$r" ] || ihlal 9 "Depoda anahtar dosyası: $r"
  r=$(grep -rlE 'AIza[0-9A-Za-z_-]{35}' --exclude-dir=.git --exclude-dir=build --exclude-dir=.dart_tool \
        --exclude-dir=.claude --exclude-dir=graphify-out --exclude=guvenlik_denetimi.sh . || true)
  [ -z "$r" ] || ihlal 9 "Google API anahtarı deseni bulundu (içerik gösterilmez): $r"
}

for k in 1 2 3 4 5 6 7 8 9; do "kural$k"; done

if [ "$HATA" -ne 0 ]; then echo "Güvenlik denetimi BAŞARISIZ"; exit 1; fi
echo "Güvenlik denetimi tamam (bekleyen kurallar: ${BEKLEYEN:-yok})"
