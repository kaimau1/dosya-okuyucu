import 'dart:math' as math;
import 'dart:ui';

/// `a:avLst` ayar değerleri: `adj`, `adj1`, `adj2`… → ECMA ham tam sayısı
/// (1/100000 oranı, açılarda 1/60000 derece).
typedef Adjust = Map<String, double>;

/// PowerPoint **ön tanımlı şekli** (`a:prstGeom@prst`) → vektör yol.
///
/// **Neden gerekiyor:** slayt çizimi bu modülden önce şekilleri yalnız
/// `BoxDecoration` ile çiziyordu; yani `rect` / `roundRect` / `ellipse`
/// dışındaki HER ön tanımlı şekil (üçgen, elmas, ok, chevron, yıldız,
/// altıgen, artı, akış şeması kutuları…) ekranda **düz dikdörtgen** çıkıyordu.
/// Süreç/akış diyagramı olan bir sunumda bu, sadakat kaybının en görünür
/// biçimi: okun yerinde kutu.
///
/// Yollar ECMA-376 `presetShapeDefinitions.xml` formüllerini izler
/// (`ss = min(w,h)`, ayarlar 1/100000 oranında). Ayar (`a:avLst > a:gd`)
/// verilmemişse şeklin ECMA varsayılanı uygulanır — yani kullanıcı
/// PowerPoint'te sarı tutamağı oynattıysa biz de aynı yerden çizeriz.
///
/// Saf `dart:ui`: Flutter widget'ı ya da dosya G/Ç'si yok, bu yüzden birim
/// testi doğrudan yol geometrisini ölçebiliyor (`test/pptx_geometry_test.dart`).
class PptxPresetShape {
  const PptxPresetShape._();

  /// Dikdörtgen ailesinden şekiller: yol yerine köşe yarıçapıyla çizilirler
  /// (kenarlık ve gölge `BoxDecoration`'da daha temiz çıkar).
  ///
  /// Dönen değer köşe yarıçapı (punto); `null` ise şekil dikdörtgen DEĞİL,
  /// [build] ile yol olarak çizilmelidir.
  static double? rectRadius(String prst, Size size, [Adjust adj = const {}]) {
    switch (prst) {
      case 'rect':
      case 'flowChartProcess':
      // İçteki dikey/yatay ayraç çizgileri çizilmiyor; dış hat dikdörtgen.
      case 'flowChartPredefinedProcess':
      case 'flowChartInternalStorage':
        return 0;
      case 'roundRect':
      case 'flowChartAlternateProcess':
        {
          // ECMA varsayılanı 16667/100000 (kısa kenarın ~1/6'sı).
          final ss = math.min(size.width, size.height);
          return ss * _pin(0, adj['adj'] ?? 16667, 50000) / 100000;
        }
      case 'flowChartTerminator':
        // Stadyum: yarıçap = yüksekliğin yarısı.
        return size.height / 2;
    }
    return null;
  }

  /// [prst] bu modülde tanımlı mı? Değilse çağıran dikdörtgene düşer —
  /// bilmediğimiz şekli yanlış çizmektense kutu çizmek daha az yanıltıcı.
  static bool isSupported(String prst) =>
      rectRadius(prst, const Size(100, 100)) != null ||
      build(prst, const Size(100, 100)) != null;

  /// [prst] için [size] kutusuna oturan kapalı yol; tanımsızsa null.
  static Path? build(String prst, Size size, [Adjust adj = const {}]) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return null;
    final ss = math.min(w, h);
    final hc = w / 2, vc = h / 2;

    /// Ayar değerini kısa kenar oranına (punto) çevirir.
    double sAdj(String name, double def, {double max = 100000}) =>
        ss * _pin(0, adj[name] ?? def, max) / 100000;

    switch (prst) {
      // ── üçgenler / dört köşeliler ────────────────────────────────────────
      case 'triangle':
      case 'flowChartExtract':
        {
          final apex = w * _pin(0, adj['adj'] ?? 50000, 100000) / 100000;
          return _poly([Offset(apex, 0), Offset(w, h), Offset(0, h)]);
        }
      case 'flowChartMerge':
        return _poly([Offset.zero, Offset(w, 0), Offset(hc, h)]);

      case 'rtTriangle':
        return _poly([Offset.zero, Offset(0, h), Offset(w, h)]);

      case 'diamond':
      case 'flowChartDecision':
      case 'flowChartSort':
        return _poly(
            [Offset(hc, 0), Offset(w, vc), Offset(hc, h), Offset(0, vc)]);

      case 'parallelogram':
      case 'flowChartInputOutput':
        {
          // Akış şemasındaki paralelkenar sabit 1/5 eğimlidir (ayarı yok).
          final d = prst == 'parallelogram'
              ? math.min(sAdj('adj', 25000), w)
              : w / 5;
          return _poly(
              [Offset(d, 0), Offset(w, 0), Offset(w - d, h), Offset(0, h)]);
        }

      case 'trapezoid':
        {
          final d = math.min(sAdj('adj', 25000), hc);
          return _poly(
              [Offset(0, h), Offset(d, 0), Offset(w - d, 0), Offset(w, h)]);
        }
      case 'flowChartManualOperation':
        {
          // Ters trapez: geniş kenar üstte.
          final d = w / 5;
          return _poly(
              [Offset.zero, Offset(w, 0), Offset(w - d, h), Offset(d, h)]);
        }
      case 'flowChartManualInput':
        return _poly([
          Offset(0, h / 5),
          Offset(w, 0),
          Offset(w, h),
          Offset(0, h),
        ]);

      // ── çokgenler ────────────────────────────────────────────────────────
      case 'hexagon':
      case 'flowChartPreparation':
        {
          final d = prst == 'hexagon' ? math.min(sAdj('adj', 25000), hc) : w / 5;
          return _poly([
            Offset(d, 0),
            Offset(w - d, 0),
            Offset(w, vc),
            Offset(w - d, h),
            Offset(d, h),
            Offset(0, vc),
          ]);
        }

      case 'octagon':
        {
          final d = math.min(sAdj('adj', 29289), math.min(hc, vc));
          return _poly([
            Offset(d, 0),
            Offset(w - d, 0),
            Offset(w, d),
            Offset(w, h - d),
            Offset(w - d, h),
            Offset(d, h),
            Offset(0, h - d),
            Offset(0, d),
          ]);
        }

      case 'pentagon':
        return _regularPolygon(size, 5);
      case 'heptagon':
        return _regularPolygon(size, 7);
      case 'decagon':
        return _regularPolygon(size, 10);
      case 'dodecagon':
        return _regularPolygon(size, 12);

      case 'flowChartOffpageConnector':
        return _poly([
          Offset.zero,
          Offset(w, 0),
          Offset(w, h * 0.8),
          Offset(hc, h),
          Offset(0, h * 0.8),
        ]);

      case 'homePlate':
        {
          final d = math.min(sAdj('adj', 50000), w);
          return _poly([
            Offset.zero,
            Offset(w - d, 0),
            Offset(w, vc),
            Offset(w - d, h),
            Offset(0, h),
          ]);
        }

      case 'chevron':
        {
          final d = math.min(sAdj('adj', 50000), w);
          return _poly([
            Offset.zero,
            Offset(w - d, 0),
            Offset(w, vc),
            Offset(w - d, h),
            Offset(0, h),
            Offset(d, vc),
          ]);
        }

      case 'plus':
      case 'mathPlus':
        {
          final d = math.min(sAdj('adj', prst == 'plus' ? 25000 : 23520),
              math.min(hc, vc));
          return _poly([
            Offset(d, 0),
            Offset(w - d, 0),
            Offset(w - d, d),
            Offset(w, d),
            Offset(w, h - d),
            Offset(w - d, h - d),
            Offset(w - d, h),
            Offset(d, h),
            Offset(d, h - d),
            Offset(0, h - d),
            Offset(0, d),
            Offset(d, d),
          ]);
        }

      case 'corner':
        {
          final dx = math.min(sAdj('adj1', 50000), w);
          final dy = math.min(sAdj('adj2', 50000), h);
          return _poly([
            Offset.zero,
            Offset(dx, 0),
            Offset(dx, h - dy),
            Offset(w, h - dy),
            Offset(w, h),
            Offset(0, h),
          ]);
        }

      // ── oklar ────────────────────────────────────────────────────────────
      case 'rightArrow':
      case 'leftArrow':
      case 'notchedRightArrow':
        {
          final dy = math.min(sAdj('adj1', 50000) / 2, vc); // gövde yarı yük.
          final head = math.min(sAdj('adj2', 50000), w);
          final pts = <Offset>[
            Offset(0, vc - dy),
            Offset(w - head, vc - dy),
            Offset(w - head, 0),
            Offset(w, vc),
            Offset(w - head, h),
            Offset(w - head, vc + dy),
            Offset(0, vc + dy),
            // Çentikli okun kuyruğu içeri girer; düz okta bu nokta kenarda kalır.
            if (prst == 'notchedRightArrow')
              Offset(math.min(head * (dy * 2) / math.max(h, 0.01), w - head), vc),
          ];
          return _poly(prst == 'leftArrow' ? _mirrorX(pts, w) : pts);
        }

      case 'upArrow':
      case 'downArrow':
        {
          final dx = math.min(sAdj('adj1', 50000) / 2, hc);
          final head = math.min(sAdj('adj2', 50000), h);
          final pts = <Offset>[
            Offset(hc - dx, h),
            Offset(hc - dx, head),
            Offset(0, head),
            Offset(hc, 0),
            Offset(w, head),
            Offset(hc + dx, head),
            Offset(hc + dx, h),
          ];
          return _poly(prst == 'upArrow' ? pts : _mirrorY(pts, h));
        }

      case 'leftRightArrow':
        {
          final dy = math.min(sAdj('adj1', 50000) / 2, vc);
          final head = math.min(sAdj('adj2', 50000), hc);
          return _poly([
            Offset(0, vc),
            Offset(head, 0),
            Offset(head, vc - dy),
            Offset(w - head, vc - dy),
            Offset(w - head, 0),
            Offset(w, vc),
            Offset(w - head, h),
            Offset(w - head, vc + dy),
            Offset(head, vc + dy),
            Offset(head, h),
          ]);
        }

      case 'upDownArrow':
        {
          final dx = math.min(sAdj('adj1', 50000) / 2, hc);
          final head = math.min(sAdj('adj2', 50000), vc);
          return _poly([
            Offset(hc, 0),
            Offset(w, head),
            Offset(hc + dx, head),
            Offset(hc + dx, h - head),
            Offset(w, h - head),
            Offset(hc, h),
            Offset(0, h - head),
            Offset(hc - dx, h - head),
            Offset(hc - dx, head),
            Offset(0, head),
          ]);
        }

      // ── yıldızlar ────────────────────────────────────────────────────────
      case 'star4':
        return _star(size, 4, adj['adj'] ?? 12500);
      case 'star5':
        return _star(size, 5, adj['adj'] ?? 19098);
      case 'star6':
        return _star(size, 6, adj['adj'] ?? 28868);
      case 'star7':
        return _star(size, 7, adj['adj'] ?? 34601);
      case 'star8':
        return _star(size, 8, adj['adj'] ?? 37500);
      case 'star10':
        return _star(size, 10, adj['adj'] ?? 42533);
      case 'star12':
        return _star(size, 12, adj['adj'] ?? 45000);
      case 'star16':
        return _star(size, 16, adj['adj'] ?? 46875);
      case 'star24':
        return _star(size, 24, adj['adj'] ?? 47917);
      case 'star32':
        return _star(size, 32, adj['adj'] ?? 48438);

      // ── eğrisel ──────────────────────────────────────────────────────────
      case 'ellipse':
      case 'flowChartConnector':
        return Path()..addOval(Offset.zero & size);

      case 'donut':
      case 'flowChartMagneticDrum':
        {
          final t = math.min(sAdj('adj', 25000), math.min(hc, vc) - 0.5);
          // Çift halka: dış ve iç elips; `evenOdd` ortayı boş bırakır.
          return Path()
            ..fillType = PathFillType.evenOdd
            ..addOval(Offset.zero & size)
            ..addOval(Rect.fromLTRB(t, t, w - t, h - t));
        }

      case 'pie':
      case 'chord':
      case 'blockArc':
        return _wedge(prst, size, adj);

      case 'can':
      case 'flowChartMagneticDisk':
        return _can(
            size, prst == 'can' ? sAdj('adj', 25000, max: 50000) / 2 : h / 6);

      case 'cube':
        return _cube(size, math.min(sAdj('adj', 25000), math.min(hc, vc)));

      case 'flowChartDocument':
        return _document(size);

      case 'flowChartDelay':
        return Path()
          ..moveTo(0, 0)
          ..lineTo(hc, 0)
          ..arcToPoint(Offset(hc, h), radius: Radius.elliptical(hc, vc))
          ..lineTo(0, h)
          ..close();

      case 'teardrop':
        {
          // Sol üst çeyreği köşeye çekilmiş daire.
          final r = math.min(sAdj('adj', 100000, max: 200000), ss);
          return Path()
            ..moveTo(hc, 0)
            ..arcToPoint(Offset(w, vc), radius: Radius.elliptical(hc, vc))
            ..arcToPoint(Offset(hc, h), radius: Radius.elliptical(hc, vc))
            ..arcToPoint(Offset(0, vc), radius: Radius.elliptical(hc, vc))
            ..lineTo(0, math.max(vc - r / 2, 0))
            ..lineTo(math.min(r / 2, hc), 0)
            ..close();
        }

      case 'cloud':
      case 'cloudCallout':
        return _cloud(size);

      // ── balonlar (konuşma kutusu) ────────────────────────────────────────
      case 'wedgeRectCallout':
      case 'wedgeRoundRectCallout':
      case 'wedgeEllipseCallout':
        return _callout(prst, size, adj);
    }
    return null;
  }

  // ── yardımcılar ──────────────────────────────────────────────────────────

  static double _pin(double lo, double v, double hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  static Path _poly(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  static List<Offset> _mirrorX(List<Offset> pts, double w) =>
      [for (final o in pts) Offset(w - o.dx, o.dy)];

  static List<Offset> _mirrorY(List<Offset> pts, double h) =>
      [for (final o in pts) Offset(o.dx, h - o.dy)];

  /// Kutuya oturan düzgün çokgen; ilk köşe TEPEDE (PowerPoint de öyle çizer).
  static Path _regularPolygon(Size size, int n) {
    final rx = size.width / 2, ry = size.height / 2;
    return _poly([
      for (var i = 0; i < n; i++)
        Offset(
          rx + rx * math.cos(-math.pi / 2 + 2 * math.pi * i / n),
          ry + ry * math.sin(-math.pi / 2 + 2 * math.pi * i / n),
        ),
    ]);
  }

  /// [n] uçlu yıldız. [adjRaw] iç yarıçapın 100000'lik oranı; dış yarıçap
  /// daima 50000 (kutunun yarısı) olduğu için iç oran `adjRaw / 50000`.
  static Path _star(Size size, int n, double adjRaw) {
    final rx = size.width / 2, ry = size.height / 2;
    final inner = _pin(0, adjRaw, 50000) / 50000;
    final pts = <Offset>[];
    for (var i = 0; i < 2 * n; i++) {
      final a = -math.pi / 2 + math.pi * i / n;
      final k = i.isEven ? 1.0 : inner;
      pts.add(Offset(rx + rx * k * math.cos(a), ry + ry * k * math.sin(a)));
    }
    return _poly(pts);
  }

  /// Silindir: üst elips + gövde. [ry] üst elipsin yarı yüksekliği.
  static Path _can(Size size, double ry) {
    final w = size.width, h = size.height;
    final r = _pin(0.5, ry, h / 2);
    return Path()
      ..moveTo(0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.elliptical(w / 2, r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(0, h - r),
          radius: Radius.elliptical(w / 2, r), clockwise: false)
      ..close();
  }

  /// Küp: ön yüzle üst/sağ yüzü kapsayan tek dış hat.
  static Path _cube(Size size, double d) {
    final w = size.width, h = size.height;
    return _poly([
      Offset(0, d),
      Offset(d, 0),
      Offset(w, 0),
      Offset(w, h - d),
      Offset(w - d, h),
      Offset(0, h),
    ]);
  }

  /// Akış şeması "belge": alt kenarı dalgalı dikdörtgen. Dalga kutunun
  /// İÇİNDE kalır (Bézier denetim noktaları taban çizgisinin ±0.9 dalgası).
  static Path _document(Size size) {
    final w = size.width, h = size.height;
    final wave = h * 0.14;
    final base = h - wave;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, base)
      ..cubicTo(w * 0.75, base - wave * 0.9, w * 0.25, base + wave * 0.9, 0,
          base - wave * 0.35)
      ..close();
  }

  /// Dilim (`pie`), kiriş (`chord`) ve halka dilimi (`blockArc`).
  ///
  /// Açılar OOXML'de 1/60000 derece ve saat yönünde ölçülür — kanvasın açı
  /// yönüyle aynı (y aşağı), o yüzden doğrudan radyana çevrilir.
  static Path _wedge(String prst, Size size, Adjust adj) {
    final rect = Offset.zero & size;
    final start = (adj['adj1'] ?? (prst == 'chord' ? 2700000 : 0)) /
        60000 *
        math.pi /
        180;
    final end = (adj['adj2'] ?? 16200000) / 60000 * math.pi / 180;
    var sweep = end - start;
    // Tam tur 0'a inmesin: 360° verilmişse tüm elips çizilmeli.
    while (sweep <= 0) {
      sweep += 2 * math.pi;
    }
    if (prst == 'chord') {
      return Path()
        ..addArc(rect, start, sweep)
        ..close();
    }
    if (prst == 'blockArc') {
      final t = math.min(size.width, size.height) *
          _pin(0, adj['adj3'] ?? 25000, 50000) /
          100000;
      return Path()
        ..addArc(rect, start, sweep)
        ..arcTo(rect.deflate(t), start + sweep, -sweep, false)
        ..close();
    }
    final c = rect.center;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(rect, start, sweep, false)
      ..close();
  }

  /// Bulut: elips çevresine dizilmiş kabarcıkların BİRLEŞİMİ. PowerPoint'in
  /// 11 yaylı tanımının yaklaşığı — dış hat aynı hissi verir, kabarcık
  /// sayısı ve oranı yakın tutuldu. Birleşim alınmazsa kenarlık iç
  /// kabarcıkları da çizer ve şekil "üst üste daireler" gibi görünür.
  static Path _cloud(Size size) {
    const bumps = 11;
    final rx = size.width / 2, ry = size.height / 2;
    final br = math.min(size.width, size.height) * 0.19;
    var path = Path();
    for (var i = 0; i < bumps; i++) {
      final a = 2 * math.pi * i / bumps - math.pi / 2;
      final c =
          Offset(rx + (rx - br) * math.cos(a), ry + (ry - br) * math.sin(a));
      final bubble = Path()
        ..addOval(
            Rect.fromCircle(center: c, radius: br * (i.isEven ? 1.0 : 0.85)));
      path = i == 0 ? bubble : Path.combine(PathOperation.union, path, bubble);
    }
    // Ortayı doldur: kabarcıklar arasında delik kalmasın.
    final core = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(rx, ry),
        width: math.max(size.width - br * 1.6, 1),
        height: math.max(size.height - br * 1.6, 1),
      ));
    return Path.combine(PathOperation.union, path, core);
  }

  /// Konuşma balonu: gövde + kuyruk. Kuyruk ucu `adj1`/`adj2` ile verilir
  /// (merkeze göre genişlik/yükseklik oranı; ECMA varsayılanı sol alt dışı).
  static Path _callout(String prst, Size size, Adjust adj) {
    final w = size.width, h = size.height;
    final body = Offset.zero & size;
    final tip = Offset(
      w / 2 + w * (adj['adj1'] ?? -20833) / 100000,
      h / 2 + h * (adj['adj2'] ?? 62500) / 100000,
    );
    final Path shell;
    switch (prst) {
      case 'wedgeRoundRectCallout':
        shell = Path()
          ..addRRect(RRect.fromRectAndRadius(
              body, Radius.circular(math.min(w, h) * 0.16667)));
        break;
      case 'wedgeEllipseCallout':
        shell = Path()..addOval(body);
        break;
      default:
        shell = Path()..addRect(body);
    }
    final dir = tip - body.center;
    final len = dir.distance;
    if (len < 0.01) return shell;
    final u = dir / len;
    final perp = Offset(-u.dy, u.dx) * (math.min(w, h) * 0.11);
    final tail = _poly([body.center + perp, tip, body.center - perp]);
    return Path.combine(PathOperation.union, shell, tail);
  }
}
