import 'video_trim.dart';

/// **Video düzenleme planı** (2026-11-14, kullanıcı: *"ara kırpmalar da
/// yapılabilsin istendiği kadar, ses ekleme çıkarma, ara bölgelerde ses ekleme
/// çıkarma"*) — saf model, birim testli.
///
/// Bütün aralıklar KAYNAK zamanında (özgün videonun ms'si) tutulur; böylece
/// bir bölüm silindiğinde öteki düzenlemelerin yeri kaymaz. Yerel tarafa
/// giden plan ([pieces], [audioTrack]) çıktı zamanına burada çevrilir:
/// - [keep]: baştan/sondan kırpma (dış tutamaçlar).
/// - [cuts]: aradan silinen bölümler (istendiği kadar).
/// - [mutes]: sesi kapatılan bölümler.
/// - [inserts]: bölgeye eklenen ses (müzik / kayıt); `replace` açıksa o
///   bölgede videonun kendi sesi kısılır.
/// - [muteAll]: videonun kendi sesi tümden kaldırılır.
/// - [quarterTurns]: saat yönünde 90°'lik dönüş sayısı (0–3, Ferrari H8.5).
class VideoEdit {
  const VideoEdit({
    required this.durationMs,
    required this.keep,
    this.cuts = const [],
    this.mutes = const [],
    this.inserts = const [],
    this.muteAll = false,
    this.quarterTurns = 0,
  });

  factory VideoEdit.whole(int durationMs) =>
      VideoEdit(durationMs: durationMs, keep: TrimRange(0, durationMs));

  final int durationMs;
  final TrimRange keep;
  final List<TrimRange> cuts;
  final List<TrimRange> mutes;
  final List<AudioInsert> inserts;
  final bool muteAll;
  final int quarterTurns;

  /// Yerel tarafa giden dönüş: saat yönünde derece (0/90/180/270).
  int get rotationDegrees => quarterTurns % 4 * 90;

  /// Saat yönünde bir çeyrek daha döndürür (dört dokunuşta başa döner).
  VideoEdit rotated() => copyWith(quarterTurns: (quarterTurns + 1) % 4);

  /// Kesilecek parça çok kısa olmasın (anahtar kare payı; 0,3 sn altı
  /// çıktıda hissedilmez, kodlayıcıyı boşuna böler).
  static const minPieceMs = 300;

  VideoEdit copyWith({
    TrimRange? keep,
    List<TrimRange>? cuts,
    List<TrimRange>? mutes,
    List<AudioInsert>? inserts,
    bool? muteAll,
    int? quarterTurns,
  }) =>
      VideoEdit(
        durationMs: durationMs,
        keep: keep ?? this.keep,
        cuts: cuts ?? this.cuts,
        mutes: mutes ?? this.mutes,
        inserts: inserts ?? this.inserts,
        muteAll: muteAll ?? this.muteAll,
        quarterTurns: quarterTurns ?? this.quarterTurns,
      );

  /// Hiçbir şey değişmedi mi (Kaydet kapalı kalır)?
  bool get isUnchanged =>
      keep.isWhole(durationMs) &&
      cuts.isEmpty &&
      mutes.isEmpty &&
      inserts.isEmpty &&
      !muteAll &&
      rotationDegrees == 0;

  /// Yalnız baş/son kırpma + (isteğe bağlı) tüm sesi kaldırma mı? Öyleyse
  /// yerelde hızlı, yeniden kodlamasız kesim yolu kullanılır. Döndürme
  /// kareleri yeniden kodlatır → düzenleme yolu.
  bool get isSimpleTrim =>
      cuts.isEmpty && mutes.isEmpty && inserts.isEmpty && rotationDegrees == 0;

  // ── Düzenleme ───────────────────────────────────────────────────────────

  /// [r] bölümünü siler. Mevcut silmelerle birleşir; [keep] dışına taşan kısım
  /// atılır. Geriye en az [minPieceMs] kalmazsa değişmez.
  VideoEdit addCut(TrimRange r) {
    final clipped = _clip(r, keep);
    if (clipped == null) return this;
    final merged = mergeRanges([...cuts, clipped]);
    final next = copyWith(cuts: merged);
    return next.outputMs < minPieceMs ? this : next;
  }

  VideoEdit addMute(TrimRange r) {
    final clipped = _clip(r, TrimRange(0, durationMs));
    if (clipped == null) return this;
    return copyWith(mutes: mergeRanges([...mutes, clipped]));
  }

  /// Ses ekler; başka bir eklenen sesle çakışan kısım kırpılır (aynı anda iki
  /// eklenen ses yok — karışıklık olmasın). Sesin kendi süresinden uzun
  /// bölgeye konursa bölge sesin süresine kısalır.
  VideoEdit addInsert(AudioInsert a) {
    final clipped = _clip(a.at, TrimRange(0, durationMs));
    if (clipped == null) return this;
    var at = clipped;
    if (a.audioMs > 0 && at.lengthMs > a.audioMs) {
      at = TrimRange(at.startMs, at.startMs + a.audioMs);
    }
    for (final o in inserts) {
      if (o.at.endMs <= at.startMs || o.at.startMs >= at.endMs) continue;
      if (o.at.startMs <= at.startMs) {
        at = TrimRange(o.at.endMs, at.endMs);
      } else {
        at = TrimRange(at.startMs, o.at.startMs);
      }
      if (at.lengthMs < minPieceMs) return this;
    }
    final list = [...inserts, a.withRange(at)]
      ..sort((x, y) => x.at.startMs.compareTo(y.at.startMs));
    return copyWith(inserts: list);
  }

  VideoEdit removeCut(int i) => copyWith(cuts: [...cuts]..removeAt(i));
  VideoEdit removeMute(int i) => copyWith(mutes: [...mutes]..removeAt(i));
  VideoEdit removeInsert(int i) =>
      copyWith(inserts: [...inserts]..removeAt(i));
  VideoEdit toggleReplace(int i) {
    final list = [...inserts];
    list[i] = list[i].copyWith(replace: !list[i].replace);
    return copyWith(inserts: list);
  }

  // ── Zaman çevirisi ──────────────────────────────────────────────────────

  /// Çıktıda kalan kaynak aralıkları (sırayla).
  List<TrimRange> get keptRanges {
    final out = <TrimRange>[];
    var cursor = keep.startMs;
    for (final c in cuts) {
      if (c.endMs <= keep.startMs || c.startMs >= keep.endMs) continue;
      if (c.startMs > cursor) out.add(TrimRange(cursor, c.startMs));
      if (c.endMs > cursor) cursor = c.endMs;
    }
    if (keep.endMs > cursor) out.add(TrimRange(cursor, keep.endMs));
    return [
      for (final r in out)
        if (r.lengthMs >= minPieceMs) r,
    ];
  }

  /// Çıktının süresi.
  int get outputMs =>
      keptRanges.fold(0, (sum, r) => sum + r.lengthMs);

  /// Kaynak zamanı → çıktı zamanı. Silinen bölümün içindeyse bölümün
  /// başladığı yere düşer.
  int toOutput(int sourceMs) {
    var out = 0;
    for (final r in keptRanges) {
      if (sourceMs <= r.startMs) return out;
      if (sourceMs < r.endMs) return out + sourceMs - r.startMs;
      out += r.lengthMs;
    }
    return out;
  }

  /// [sourceMs] silinen (ya da kırpılan) bir yerde mi? Öyleyse önizlemenin
  /// atlayacağı bir sonraki kalan noktayı döndürür; çıktı sonundaysa null.
  int? nextKeptFrom(int sourceMs) {
    for (final r in keptRanges) {
      if (sourceMs < r.startMs) return r.startMs;
      if (sourceMs < r.endMs) return sourceMs;
    }
    return null;
  }

  /// [sourceMs]'de videonun kendi sesi duyulur mu (önizleme ses düzeyi)?
  bool originalAudibleAt(int sourceMs) {
    if (muteAll) return false;
    for (final m in mutes) {
      if (sourceMs >= m.startMs && sourceMs < m.endMs) return false;
    }
    for (final a in inserts) {
      if (a.replace && sourceMs >= a.at.startMs && sourceMs < a.at.endMs) {
        return false;
      }
    }
    return true;
  }

  /// Videonun parçaları (kaynak zamanı), her biri sessiz mi değil mi.
  /// Kalan aralıklar sessiz bölge sınırlarında bölünür; komşu aynı türden
  /// parçalar (kesintisiz kaynak) birleşir.
  List<VideoPiece> get pieces {
    final silent = mergeRanges([
      ...mutes,
      for (final a in inserts)
        if (a.replace) a.at,
    ]);
    final out = <VideoPiece>[];
    void add(int s, int e, bool mute) {
      if (e - s <= 0) return;
      if (out.isNotEmpty &&
          out.last.endMs == s &&
          out.last.mute == mute) {
        out[out.length - 1] = VideoPiece(out.last.startMs, e, mute: mute);
      } else {
        out.add(VideoPiece(s, e, mute: mute));
      }
    }

    for (final r in keptRanges) {
      var cursor = r.startMs;
      for (final m in silent) {
        if (m.endMs <= cursor || m.startMs >= r.endMs) continue;
        if (m.startMs > cursor) add(cursor, m.startMs, false);
        final end = m.endMs < r.endMs ? m.endMs : r.endMs;
        add(m.startMs > cursor ? m.startMs : cursor, end, true);
        cursor = end;
      }
      add(cursor, r.endMs, false);
    }
    // Çok kısa parça komşusuna katılır (ses farkı 0,3 sn'den kısa sürede
    // duyulmaz; kodlayıcıya ufak parça vermek kesik üretir).
    final merged = <VideoPiece>[];
    for (final pc in out) {
      if (merged.isNotEmpty &&
          merged.last.endMs == pc.startMs &&
          pc.lengthMs < minPieceMs) {
        final l = merged.removeLast();
        merged.add(VideoPiece(l.startMs, pc.endMs, mute: l.mute));
      } else {
        merged.add(pc);
      }
    }
    return merged;
  }

  /// Eklenen seslerin çıktı zamanındaki yerleşimi: her biri bir boşluk
  /// ([AudioPlacement.gapMs] — önceki sesin bitişinden itibaren) ve ses
  /// dosyasının baştan [AudioPlacement.lengthMs]'lik kısmı.
  List<AudioPlacement> get audioTrack {
    final out = <AudioPlacement>[];
    var cursor = 0;
    for (final a in inserts) {
      final start = toOutput(a.at.startMs);
      var len = toOutput(a.at.endMs) - start;
      if (a.audioMs > 0 && len > a.audioMs) len = a.audioMs;
      if (len < minPieceMs || start < cursor) continue;
      out.add(AudioPlacement(a.path, gapMs: start - cursor, lengthMs: len));
      cursor = start + len;
    }
    return out;
  }

  static TrimRange? _clip(TrimRange r, TrimRange within) {
    final s = r.startMs < within.startMs ? within.startMs : r.startMs;
    final e = r.endMs > within.endMs ? within.endMs : r.endMs;
    return e - s >= minPieceMs ? TrimRange(s, e) : null;
  }
}

/// Aralıkları sıralar, çakışan/değen olanları birleştirir.
List<TrimRange> mergeRanges(List<TrimRange> list) {
  final sorted = [...list]..sort((a, b) => a.startMs.compareTo(b.startMs));
  final out = <TrimRange>[];
  for (final r in sorted) {
    if (out.isNotEmpty && r.startMs <= out.last.endMs) {
      final l = out.removeLast();
      out.add(TrimRange(l.startMs, r.endMs > l.endMs ? r.endMs : l.endMs));
    } else {
      out.add(r);
    }
  }
  return out;
}

/// Bölgeye eklenen ses.
class AudioInsert {
  const AudioInsert({
    required this.path,
    required this.at,
    this.audioMs = 0,
    this.replace = true,
  });

  final String path;

  /// Kaynak zamanındaki bölge.
  final TrimRange at;

  /// Ses dosyasının süresi (bilinmiyorsa 0).
  final int audioMs;

  /// Bu bölgede videonun kendi sesi kısılsın mı (varsayılan evet: "sesi
  /// değiştir"); kapalıysa iki ses karışır.
  final bool replace;

  AudioInsert withRange(TrimRange r) =>
      AudioInsert(path: path, at: r, audioMs: audioMs, replace: replace);

  AudioInsert copyWith({bool? replace}) => AudioInsert(
      path: path, at: at, audioMs: audioMs, replace: replace ?? this.replace);
}

/// Yerel tarafa giden video parçası (kaynak zamanı).
class VideoPiece {
  const VideoPiece(this.startMs, this.endMs, {this.mute = false});
  final int startMs;
  final int endMs;
  final bool mute;
  int get lengthMs => endMs - startMs;

  Map<String, Object> toMap() =>
      {'startMs': startMs, 'endMs': endMs, 'mute': mute};

  @override
  bool operator ==(Object other) =>
      other is VideoPiece &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.mute == mute;

  @override
  int get hashCode => Object.hash(startMs, endMs, mute);

  @override
  String toString() => 'VideoPiece($startMs–$endMs${mute ? ' sessiz' : ''})';
}

/// Yerel tarafa giden eklenen ses yerleşimi (çıktı zamanı).
class AudioPlacement {
  const AudioPlacement(this.path, {required this.gapMs, required this.lengthMs});
  final String path;
  final int gapMs;
  final int lengthMs;

  Map<String, Object> toMap() =>
      {'path': path, 'gapMs': gapMs, 'lengthMs': lengthMs};
}
