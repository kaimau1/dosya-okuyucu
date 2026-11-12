# Sürüm güvenlik kontrolü (G12.1)

Her `v*` etiketinden ÖNCE işaretlenir (kopyala → Release taslağına yapıştır).

- [ ] `bash tool/guvenlik_denetimi.sh` yeşil (CI `Doğrulama (0/3)` adımı) — bekleyen kural yok
- [ ] Bağımlılık taraması temiz: Dependabot güvenlik uyarısı açık değil (Security → Dependabot);
      `bagimlilik-raporu.yml` son koşusunda yeni yüksek bulgu yok
- [ ] (G9.10 kurulduysa) MobSF raporunda yeni **yüksek** bulgu yok
- [ ] İzin tabanı değişmedi ya da değişiklik commit gövdesinde gerekçeli (`ci/AndroidManifest.xml`)
- [ ] `docs/guvenlik/ENVANTER.md` güncel (yeni dışa açık bileşen / ağ dinleyen / sır yok ya da eklendi)
- [ ] `docs/CIHAZ_TESTI.md` "Güvenlik" bölümleri bu sürümde koşuldu (en az G1, G3, G4, G6)
- [ ] Gizlilik metni (`docs/GIZLILIK.md`, `assets/privacy`) güncel
- [ ] Release gövdesinde her APK için `<!-- sha256:… -->` satırı var (G9.6 — CI yazar; elle düzeltme yok)
- [ ] Yayındaki bir sürümde güvenlik açığı düzeltildiyse `ci/min_guvenli_surum.txt` bu sürüme ayarlandı (G12.4)
- [ ] İmza parmak izi beklenen değer (`apksigner verify --print-certs` — CI günlüğü "APK denetimi")
