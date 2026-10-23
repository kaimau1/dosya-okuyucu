part of '../docx_editor.dart';

/// Canlı (sayfa görünümünde) düzenlemenin Dart yarısı — Faz 21a (2026-10-23).
///
/// **W1 kök neden:** düzenleme "DOM'daki `<p>` sırası = `document.xml`deki
/// `w:p` sırası" varsayımına dayanıyordu. Gömülü docx-preview, Word'ün her
/// kayıtta yazdığı `w:lastRenderedPageBreak` işaretinde paragrafı İKİ `<p>`ye
/// bölüyor (sayfa kırma) → sayılar tutmuyor → sigorta düzenlemeyi
/// kapatıyordu. Word'de kaydedilmiş çok sayfalı belgelerin çoğunda "Düzenle"
/// bu yüzden çalışmıyordu.
///
/// Çözüm **kimlik tabanlı eşleme**: WebView'a gönderilen KOPYADA her `w:p`'nin
/// başına görünmez bir yer imi (`_fkp<i>`) konur; docx-preview onu
/// `<span id="_fkp<i>">` olarak çizer, JS indeksi oradan okur. İşaretsiz
/// `<p>` (bölünmüş paragrafın ikinci yarısı) bir öncekinin devamıdır.
/// Kaydedilen dosyaya işaret GİRMEZ (yalnız kopyada).
///
/// **W4 (sessiz veri kaybı):** `setRuns` paragrafı baştan kuruyor, köprü,
/// alan, yer imi, dipnot başvurusu, sekme ve satır içi resmi siliyordu;
/// paragraf içi farklı biçimleri ilk run'ın `rPr`'iyle eziyordu. Şimdi:
/// * run olmayan ya da düz metin dışında şey taşıyan her parça bir
///   **dokunulmaz ada**dır: kopyada `_fkis<k>` … `_fkie<k>` işaretleri
///   arasında durur, JS onu `contenteditable=false` çipe sarar ve parçalarda
///   `￼` + ada kimliği olarak gönderir; XML'de özgün düğüm yerinde kalır.
/// * değişiklik **fark** olarak uygulanır: JS ilk düzenlemede paragrafın
///   önceki hâlini (`base`) de yollar; ortak baş/son el değmeden kalır (run'lar
///   ve `rPr`'leri aynen), yalnız değişen orta kısım yeni run olur ve biçimi
///   komşusundan alıp yalnız FARKLI olan özelliği açıkça yazar (stilden gelen
///   kalın kapatılınca `w:b w:val="0"`).
extension DocxLiveEdit on DocxEditor {
  /// WebView'a gönderilecek işaretli kopya (kaydedilen dosyaya girmez).
  Uint8List viewBytes() {
    final live = _live;
    live.reset();
    final copy = _doc.copy();
    // Gerçek ↔ kopya paragraf eşlemesi belge sırasıyla (kopya yapıyı aynen
    // taşır); model listesi kimlikle bulunur.
    final real = _doc.findAllElements('w:p').toList();
    final copies = copy.findAllElements('w:p').toList();
    final copyOf = <XmlElement, XmlElement>{
      for (var k = 0; k < real.length && k < copies.length; k++)
        real[k]: copies[k],
    };
    var bid = 900000;
    XmlElement mark(String name) => XmlElement(XmlName('w:bookmarkStart'), [
          XmlAttribute(XmlName('w:id'), '${bid++}'),
          XmlAttribute(XmlName('w:name'), name),
        ]);
    for (var i = 0; i < paragraphs.length; i++) {
      final p = copyOf[paragraphs[i]._element];
      if (p == null) continue;
      _splitMixedRuns(p);
      final ids = <int>[];
      final islands = _islandChildren(p);
      for (final node in islands) {
        final id = live.nextIsland++;
        ids.add(id);
        final at = p.children.indexOf(node);
        p.children.insert(at + 1, mark('_fkie$id'));
        p.children.insert(at, mark('_fkis$id'));
      }
      live.viewIds[paragraphs[i]] = ids;
      final pPr = DocxEditor._firstOrNull(p.findElements('w:pPr'));
      p.children.insert(pPr == null ? 0 : p.children.indexOf(pPr) + 1,
          mark('_fkp$i'));
    }
    final out = Archive();
    for (final f in _archive.files) {
      if (f.name == 'word/document.xml') {
        final data = utf8.encode(copy.toXmlString());
        out.addFile(ArchiveFile(f.name, data.length, data));
      } else if (_partEdits.containsKey(f.name)) {
        final data = utf8.encode(_partEdits[f.name]!);
        out.addFile(ArchiveFile(f.name, data.length, data));
      } else {
        out.addFile(f);
      }
    }
    _newMedia.forEach((name, data) {
      out.addFile(ArchiveFile(name, data.length, data));
    });
    return Uint8List.fromList(ZipEncoder().encode(out) ?? const <int>[]);
  }

  /// Canlı görünümde Enter: [index] paragrafını [offset] (atom birimi: harf,
  /// satır sonu ve ada birer) noktasında ikiye böler; yeni paragraf
  /// `index + 1`'e girer. pPr kopyalanır, bölüm sonu (`w:sectPr`) ikinci
  /// yarıya geçer (Word'deki gibi bölüm işareti son paragrafta kalır).
  DocxParagraph? splitParagraph(int index, int offset) {
    if (index < 0 || index >= paragraphs.length) return null;
    final para = paragraphs[index];
    final el = para._element;
    final parent = el.parent;
    if (parent == null) return null;
    _prepare(para);
    final atoms = _atomsOf(el);
    final at = offset.clamp(0, atoms.length);
    final newEl = XmlElement(XmlName('w:p'));
    final pPr = DocxEditor._firstOrNull(el.findElements('w:pPr'));
    if (pPr != null) {
      final copy = pPr.copy();
      newEl.children.add(copy);
      // Bölüm sonu ikinci yarıya taşınır.
      DocxEditor._removeElems(pPr, (e) => e.name.qualified == 'w:sectPr');
      // Başlığın sonunda Enter: yeni paragraf "Normal" (Word'ün `w:next`i).
      if (at >= atoms.length) {
        DocxEditor._removeElems(copy, (e) {
          if (e.name.qualified != 'w:pStyle') return false;
          final v = (e.getAttribute('w:val') ?? '').toLowerCase();
          return v.contains('heading') || v.contains('title') ||
              v.startsWith('baslik') || v.startsWith('başlık');
        });
      }
    }
    _emit(el, atoms.sublist(0, at));
    _emit(newEl, atoms.sublist(at));
    parent.children.insert(parent.children.indexOf(el) + 1, newEl);
    final next = DocxEditor._paraFrom(newEl);
    paragraphs.insert(index + 1, next);
    para.text = _visibleText(el);
    para._markRich();
    next._markRich();
    final last = _live.lastSegs[para];
    if (last != null) {
      final (a, b) = _splitSegs(last, at);
      _live.lastSegs[para] = a;
      _live.lastSegs[next] = b;
    }
    _live.resolved.add(next);
    return next;
  }

  /// Canlı görünümde paragraf başında geri silme: [index] paragrafını bir
  /// öncekine katar. Farklı kaplardaki (tablo hücresi ↔ gövde) paragraflar
  /// birleştirilmez — Word de birleştirmez. Başarıyla birleştiyse true.
  bool mergeWithPrevious(int index) {
    if (index <= 0 || index >= paragraphs.length) return false;
    final prev = paragraphs[index - 1];
    final para = paragraphs[index];
    final a = prev._element, b = para._element;
    if (a.parent == null || !identical(a.parent, b.parent)) return false;
    _prepare(prev);
    _prepare(para);
    final atomsA = _atomsOf(a);
    final atomsB = _atomsOf(b);
    // Kaldırılan paragrafın bölüm sonu öncekine geçer (yoksa bölüm kaybolurdu).
    final sect = DocxEditor._firstOrNull(b.findElements('w:pPr'))
        ?.findElements('w:sectPr')
        .firstOrNull;
    _emit(a, [...atomsA, ...atomsB]);
    if (sect != null) {
      final pPr = _ensurePPr(a);
      if (pPr.findElements('w:sectPr').isEmpty) {
        sect.parent?.children.remove(sect);
        pPr.children.add(sect);
      }
    }
    b.parent!.children.remove(b);
    paragraphs.removeAt(index);
    prev.text = _visibleText(a);
    prev._markRich();
    final la = _live.lastSegs[prev], lb = _live.lastSegs.remove(para);
    _live.lastSegs[prev] = la != null && lb != null ? [...la, ...lb] : null;
    if (_live.lastSegs[prev] == null) _live.lastSegs.remove(prev);
    return true;
  }

  /// JS'in gönderdiği "önceki hâl" (ilk düzenlemede).
  void setLiveBase(int index, List<RunSeg> base) {
    if (index < 0 || index >= paragraphs.length) return;
    _live.lastSegs[paragraphs[index]] = base;
  }

  /// Paragrafın son bilinen canlı parçaları (test/tanı).
  List<RunSeg>? liveSegsOf(int index) =>
      index < 0 || index >= paragraphs.length
          ? null
          : _live.lastSegs[paragraphs[index]];

  /// Canlı görünümde imlece eklenecek satır içi resim: run üretilir, ada
  /// olarak kaydedilir; JS onu imlece koyup parçaları yollayınca belgeye
  /// girer (yeniden çizim yok — W9).
  int imageIsland(List<int> bytes,
          {required String ext, required int widthPx, required int heightPx}) =>
      registerIsland(
          imageRun(bytes, ext: ext, widthPx: widthPx, heightPx: heightPx));

  /// Bir resim adasını canlı görünüme kaydeder (resim ekleme sonrası JS'e
  /// verilecek kimlik).
  int registerIsland(XmlNode node) {
    final id = _live.nextIsland++;
    _live.islands[id] = node;
    return id;
  }
}

/// Canlı düzenlemenin durumu (editör başına).
class _LiveState {
  /// Görünüm üretiminde paragraf başına verilen ada kimlikleri (sırayla).
  final viewIds = Expando<List<int>>();
  final Map<int, XmlNode> islands = {};
  final Set<DocxParagraph> resolved = {};
  final Map<DocxParagraph, List<RunSeg>?> lastSegs = {};

  /// Yapısal işlemlerin önce/sonra anlık görüntüleri (JS jetonu → …).
  final Map<int, (int, List<_ParaSnap>, List<_ParaSnap>)> structural = {};
  int nextIsland = 1;

  void reset() {
    structural.clear();
    islands.clear();
    resolved.clear();
    lastSegs.clear();
    nextIsland = 1;
  }
}

/// Paragrafın tek bir birimi: düz bir harf (kaynak run'ı ve run içindeki
/// sırasıyla), satır sonu (`\n`) ya da bir ada.
class _Atom {
  final String ch;
  final XmlElement? run;
  final int idx;
  final XmlNode? island;
  final int? islandId;

  /// Yeni yazılan harf: biçim + şablon run'ı.
  final RunSeg? fmt;
  final RunSeg? templateFmt;

  const _Atom.char(this.ch, this.run, this.idx)
      : island = null,
        islandId = null,
        fmt = null,
        templateFmt = null;
  const _Atom.island(this.island, this.islandId)
      : ch = '￼',
        run = null,
        idx = -1,
        fmt = null,
        templateFmt = null;
  const _Atom.fresh(this.ch, this.run, this.fmt, this.templateFmt)
      : idx = -1,
        island = null,
        islandId = null;
  bool get isIsland => island != null;
}

/// Düz run'ın taşıyabileceği çocuklar (gerisi ada sayılır).
const _plainRunChildren = {'w:rPr', 'w:t', 'w:br', 'w:cr', 'w:lastRenderedPageBreak'};

bool _isPlainPart(XmlElement e) {
  final q = e.name.qualified;
  if (q == 'w:br') {
    final t = e.getAttribute('w:type');
    return t == null || t == 'textWrapping';
  }
  return _plainRunChildren.contains(q);
}

bool _isPlainRun(XmlElement r) =>
    r.name.qualified == 'w:r' && r.childElements.every(_isPlainPart);

/// Karışık run'ları (düz metin + sekme/resim/alan karakteri …) ayrı run'lara
/// böler — her özel parça kendi run'ında, `rPr` kopyasıyla. Belirleyici:
/// kopyada ve gerçek belgede aynı sonucu verir (ada sırası tutar).
void _splitMixedRuns(XmlElement p) {
  for (final r in p.childElements.where((e) => e.name.qualified == 'w:r').toList()) {
    if (_isPlainRun(r)) continue;
    final kids = r.childElements.where((e) => e.name.qualified != 'w:rPr').toList();
    final specialCount = kids.where((e) => !_isPlainPart(e)).length;
    if (specialCount == 1 && kids.length == 1) continue; // zaten tek ada
    final rPr = DocxEditor._firstOrNull(r.findElements('w:rPr'));
    final groups = <List<XmlElement>>[];
    for (final k in kids) {
      final plain = _isPlainPart(k);
      if (plain && groups.isNotEmpty && groups.last.every(_isPlainPart)) {
        groups.last.add(k);
      } else {
        groups.add([k]);
      }
    }
    final parent = r.parent!;
    var at = parent.children.indexOf(r);
    parent.children.removeAt(at);
    for (final g in groups) {
      final nr = XmlElement(XmlName('w:r'));
      if (rPr != null) nr.children.add(rPr.copy());
      for (final k in g) {
        nr.children.add(k.copy());
      }
      parent.children.insert(at++, nr);
    }
  }
}

/// Paragrafın ada olan doğrudan çocukları (sırayla).
List<XmlElement> _islandChildren(XmlElement p) => [
      for (final c in p.childElements)
        if (c.name.qualified != 'w:pPr' && !_isPlainRun(c)) c,
    ];

/// Görünür metin — `parse` ile aynı ölçüt (tüm `w:t`'ler).
String _visibleText(XmlElement p) =>
    p.findAllElements('w:t').map((e) => e.innerText).join();

extension _DocxLiveInternals on DocxEditor {
  _LiveState get _live => _liveStates[this] ??= _LiveState();

  /// İlk dokunuşta: run'lar görünüm kopyasındaki gibi bölünür ve görünümde
  /// verilen ada kimlikleri GERÇEK düğümlere bağlanır.
  void _prepare(DocxParagraph para) {
    final live = _live;
    if (live.resolved.contains(para)) return;
    _splitMixedRuns(para._element);
    final ids = live.viewIds[para];
    if (ids != null) {
      final islands = _islandChildren(para._element);
      for (var k = 0; k < ids.length && k < islands.length; k++) {
        live.islands[ids[k]] = islands[k];
      }
    }
    live.resolved.add(para);
  }

  /// XML'deki atomlar. Ada kimliği kayıttan bulunur (bilinmiyorsa null).
  List<_Atom> _atomsOf(XmlElement p) {
    final idOf = <XmlNode, int>{
      for (final e in _live.islands.entries) e.value: e.key,
    };
    final out = <_Atom>[];
    for (final c in p.childElements) {
      final q = c.name.qualified;
      if (q == 'w:pPr') continue;
      if (_isPlainRun(c)) {
        var idx = 0;
        for (final k in c.childElements) {
          switch (k.name.qualified) {
            case 'w:t':
              for (final ch in k.innerText.split('')) {
                out.add(_Atom.char(ch, c, idx++));
              }
            case 'w:br':
            case 'w:cr':
              out.add(_Atom.char('\n', c, idx++));
          }
        }
      } else {
        out.add(_Atom.island(c, idOf[c]));
      }
    }
    return out;
  }

  /// Atom listesini paragrafa yazar: pPr korunur; bütün hâlde kalan özgün
  /// run'lar AYNEN geri konur, bölünenler kopyalanır, yeni harfler biçimine
  /// göre gruplanıp yeni run olur, adalar özgün düğüm olarak taşınır.
  void _emit(XmlElement p, List<_Atom> atoms) {
    // Özgün run'ların harf sayısı (bütün mü kaldı?).
    final runLen = <XmlElement, int>{};
    for (final c in p.childElements) {
      if (_isPlainRun(c)) runLen[c] = _runAtomCount(c);
    }
    for (final a in atoms) {
      final r = a.run;
      if (r != null && a.fmt == null && !runLen.containsKey(r)) {
        runLen[r] = _runAtomCount(r);
      }
    }
    final nodes = <XmlNode>[];
    var k = 0;
    while (k < atoms.length) {
      final a = atoms[k];
      if (a.isIsland) {
        a.island!.parent?.children.remove(a.island!);
        nodes.add(a.island!);
        k++;
        continue;
      }
      if (a.fmt == null && a.run != null) {
        // Aynı run'dan ardışık harfler.
        var j = k;
        while (j + 1 < atoms.length &&
            atoms[j + 1].fmt == null &&
            identical(atoms[j + 1].run, a.run) &&
            atoms[j + 1].idx == atoms[j].idx + 1) {
          j++;
        }
        final whole = a.idx == 0 && j - k + 1 == runLen[a.run];
        final run = a.run!;
        if (whole && !nodes.contains(run)) {
          run.parent?.children.remove(run);
          // Sayfa kırma ipucu artık konumunu yitirdi (Word yeniden yazar).
          DocxEditor._removeElems(
              run, (e) => e.name.qualified == 'w:lastRenderedPageBreak');
          nodes.add(run);
        } else {
          final rPr = DocxEditor._firstOrNull(run.findElements('w:rPr'));
          nodes.add(_buildRun(rPr?.copy(),
              atoms.sublist(k, j + 1).map((x) => x.ch).join()));
        }
        k = j + 1;
        continue;
      }
      // Yeni harfler: aynı şablon + aynı biçim bir run.
      var j = k;
      while (j + 1 < atoms.length &&
          atoms[j + 1].fmt != null &&
          identical(atoms[j + 1].run, a.run) &&
          _sameFmt(atoms[j + 1].fmt!, a.fmt!)) {
        j++;
      }
      final tmplRPr = a.run == null
          ? null
          : DocxEditor._firstOrNull(a.run!.findElements('w:rPr'));
      final rPr = tmplRPr?.copy() ?? XmlElement(XmlName('w:rPr'));
      _adjust(rPr, a.fmt!, a.templateFmt);
      nodes.add(_buildRun(rPr.children.isEmpty ? null : rPr,
          atoms.sublist(k, j + 1).map((x) => x.ch).join()));
      k = j + 1;
    }
    final keep = p.childElements.where((e) => e.name.qualified == 'w:pPr').toList();
    p.children
      ..clear()
      ..addAll(keep)
      ..addAll(nodes.map((n) {
        n.parent?.children.remove(n);
        return n;
      }));
  }

  int _runAtomCount(XmlElement run) {
    var n = 0;
    for (final k in run.childElements) {
      final q = k.name.qualified;
      if (q == 'w:t') n += k.innerText.length;
      if (q == 'w:br' || q == 'w:cr') n++;
    }
    return n;
  }

  XmlElement _buildRun(XmlElement? rPr, String text) {
    final run = XmlElement(XmlName('w:r'));
    if (rPr != null) run.children.add(rPr);
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) run.children.add(XmlElement(XmlName('w:br')));
      if (parts[i].isEmpty) continue;
      run.children.add(XmlElement(XmlName('w:t'),
          [XmlAttribute(XmlName('xml:space'), 'preserve')], [XmlText(parts[i])]));
    }
    return run;
  }

  /// Şablon run'ın biçimiyle YENİ biçim arasında farklı olan özellikleri
  /// açıkça yazar. Şablon bilinmiyorsa (fmt yok) yalnız açık olanlar yazılır.
  void _adjust(XmlElement rPr, RunSeg f, RunSeg? t) {
    void toggle(String name, bool now, bool? was) {
      if (was != null && now == was) return;
      DocxEditor._removeElems(rPr, (e) => e.name.qualified == name);
      if (now) {
        DocxEditor._putOrdered(rPr, XmlElement(XmlName(name)));
      } else if (was == true) {
        DocxEditor._putOrdered(rPr,
            XmlElement(XmlName(name), [XmlAttribute(XmlName('w:val'), '0')]));
      }
    }

    toggle('w:b', f.bold, t?.bold);
    toggle('w:i', f.italic, t?.italic);
    toggle('w:strike', f.strike, t?.strike);
    if (t == null || f.underline != t.underline) {
      DocxEditor._removeElems(rPr, (e) => e.name.qualified == 'w:u');
      if (f.underline) {
        DocxEditor._putOrdered(rPr,
            XmlElement(XmlName('w:u'), [XmlAttribute(XmlName('w:val'), 'single')]));
      } else if (t?.underline == true) {
        DocxEditor._putOrdered(rPr,
            XmlElement(XmlName('w:u'), [XmlAttribute(XmlName('w:val'), 'none')]));
      }
    }
    if (f.font != null && f.font != t?.font) _setFont(rPr, f.font!);
    if (f.sizePt != null && f.sizePt != t?.sizePt) _setSize(rPr, f.sizePt!);
    if (f.color != t?.color) {
      if (f.color != null) {
        _setColor(rPr, f.color!);
      } else if (t != null) {
        DocxEditor._removeElems(rPr, (e) => e.name.qualified == 'w:color');
      }
    }
    if (f.highlight != t?.highlight) {
      if (f.highlight != null) {
        _setHighlight(rPr, f.highlight!);
      } else if (t != null) {
        DocxEditor._removeElems(rPr, (e) =>
            e.name.qualified == 'w:highlight' || e.name.qualified == 'w:shd');
      }
    }
  }

  /// Parça listesini [at] atomunda ikiye böler.
  (List<RunSeg>, List<RunSeg>) _splitSegs(List<RunSeg> segs, int at) {
    final a = <RunSeg>[], b = <RunSeg>[];
    var n = 0;
    for (final s in segs) {
      final len = s.island != null ? 1 : s.text.length;
      if (n + len <= at) {
        a.add(s);
      } else if (n >= at) {
        b.add(s);
      } else {
        final cut = at - n;
        a.add(s.withText(s.text.substring(0, cut)));
        b.add(s.withText(s.text.substring(cut)));
      }
      n += len;
    }
    return (a, b);
  }

  /// Fark tabanlı yazım (bkz. dosya başı). [base] verilmezse son bilinen
  /// parçalar kullanılır; o da yoksa ya da XML ile uyuşmuyorsa yedek yol.
  void _applySegs(DocxParagraph para, List<RunSeg> segs, List<RunSeg>? base) {
    _prepare(para);
    final el = para._element;
    final live = _live;
    final b = base ?? live.lastSegs[para];
    final atoms = _atomsOf(el);
    final newChars = _flatten(segs);
    if (b != null) {
      final oldChars = _flatten(b);
      final xmlText = atoms.map((a) => a.ch).join();
      final baseText = oldChars.map((c) => c.$1).join();
      if (xmlText == baseText) {
        var pre = 0;
        final maxPre = oldChars.length < newChars.length
            ? oldChars.length
            : newChars.length;
        while (pre < maxPre && _sameChar(oldChars[pre], newChars[pre])) {
          pre++;
        }
        var suf = 0;
        while (suf < maxPre - pre &&
            _sameChar(oldChars[oldChars.length - 1 - suf],
                newChars[newChars.length - 1 - suf])) {
          suf++;
        }
        final out = <_Atom>[...atoms.sublist(0, pre)];
        // Şablon: değişen bölgenin solundaki harf, yoksa sağındaki.
        int? tIdx;
        for (var k = pre - 1; k >= 0; k--) {
          if (!atoms[k].isIsland) {
            tIdx = k;
            break;
          }
        }
        if (tIdx == null) {
          for (var k = pre; k < atoms.length; k++) {
            if (!atoms[k].isIsland) {
              tIdx = k;
              break;
            }
          }
        }
        final tRun = tIdx == null ? _firstPlainRun(el) : atoms[tIdx].run;
        final tFmt = tIdx == null ? null : oldChars[tIdx].$2;
        for (var k = pre; k < newChars.length - suf; k++) {
          final c = newChars[k];
          if (c.$3 != null) {
            final node = live.islands[c.$3];
            if (node != null) out.add(_Atom.island(node, c.$3));
          } else {
            out.add(_Atom.fresh(c.$1, tRun, c.$2, tFmt));
          }
        }
        out.addAll(atoms.sublist(atoms.length - suf));
        _emit(el, out);
        _finishApply(para, segs);
        return;
      }
    }
    // Yedek yol: şablon ilk run; adalar kimlikleriyle korunur.
    final tRun = _firstPlainRun(el);
    final out = <_Atom>[];
    for (final c in newChars) {
      if (c.$3 != null) {
        final node = live.islands[c.$3];
        if (node != null) out.add(_Atom.island(node, c.$3));
      } else {
        out.add(_Atom.fresh(c.$1, tRun, c.$2, null));
      }
    }
    _emit(el, out);
    _finishApply(para, segs);
  }

  void _finishApply(DocxParagraph para, List<RunSeg> segs) {
    para.text = _visibleText(para._element);
    para._markRich();
    _live.lastSegs[para] = segs;
  }

  XmlElement? _firstPlainRun(XmlElement p) {
    for (final c in p.childElements) {
      if (_isPlainRun(c)) return c;
    }
    return null;
  }

  /// Parçalar → (harf, biçim, ada kimliği) dizisi.
  List<(String, RunSeg, int?)> _flatten(List<RunSeg> segs) {
    final out = <(String, RunSeg, int?)>[];
    for (final s in segs) {
      if (s.island != null) {
        out.add(('￼', s, s.island));
        continue;
      }
      for (final ch in s.text.split('')) {
        out.add((ch, s, null));
      }
    }
    return out;
  }

  bool _sameChar((String, RunSeg, int?) a, (String, RunSeg, int?) b) =>
      a.$1 == b.$1 && a.$3 == b.$3 && (a.$3 != null || _sameFmt(a.$2, b.$2));

  bool _sameFmt(RunSeg a, RunSeg b) =>
      a.bold == b.bold &&
      a.italic == b.italic &&
      a.underline == b.underline &&
      a.strike == b.strike &&
      a.font == b.font &&
      a.sizePt == b.sizePt &&
      a.color == b.color &&
      a.highlight == b.highlight;
}

/// Editör başına canlı durum (DocxEditor'ın alanlarına dokunmadan).
final _liveStates = Expando<_LiveState>();

/// JS köprüsünden gelen mesajlar (Faz 21a). Ayrı tutuldu: Playwright'ta
/// kaydedilen gerçek mesaj dizileri Dart testinde aynen yeniden oynatılabilir.
extension DocxLiveMessages on DocxEditor {
  /// JS parçası → [RunSeg]: `[metin, b, i, u, font, punto, renk, vurgu,
  /// üstüÇizili, ada]`.
  static RunSeg segFromJson(List seg) {
    String? str(int at) {
      if (seg.length <= at) return null;
      final v = seg[at];
      return v is String && v.isNotEmpty ? v : null;
    }

    final island = seg.length > 9 && seg[9] is num ? (seg[9] as num).toInt() : null;
    return RunSeg(
      '${seg[0]}',
      seg.length > 1 && seg[1] == true,
      seg.length > 2 && seg[2] == true,
      seg.length > 3 && seg[3] == true,
      font: str(4),
      sizePt: seg.length > 5 && seg[5] is num && (seg[5] as num) > 0
          ? (seg[5] as num).toDouble()
          : null,
      color: str(6),
      highlight: str(7),
      strike: seg.length > 8 && seg[8] == true,
      island: island,
    );
  }

  static List<RunSeg> segsFromJson(Object? v) => [
        if (v is List)
          for (final s in v)
            if (s is List && s.isNotEmpty) segFromJson(s),
      ];

  /// Bir köprü mesajını modele uygular. false → model ile görünüm
  /// ayrıştı (çağıran canlı düzenlemeyi kapatır).
  bool applyLiveMessage(Map data) {
    final live = _live;
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    if (data['split'] != null) {
      final i = asInt(data['split']);
      final at = asInt(data['at']);
      if (i == null || at == null || i < 0 || i >= paragraphs.length) {
        return false;
      }
      if (data['base'] != null) setLiveBase(i, segsFromJson(data['base']));
      final tok = asInt(data['tok']);
      final before = tok == null ? null : _snapshot(i, 1);
      if (splitParagraph(i, at) == null) return false;
      setRuns(i, segsFromJson(data['a']));
      setRuns(i + 1, segsFromJson(data['b']));
      if (tok != null) live.structural[tok] = (i, before!, _snapshot(i, 2));
      return true;
    }
    if (data['merge'] != null) {
      final i = asInt(data['merge']);
      if (i == null || i <= 0 || i >= paragraphs.length) return false;
      if (data['baseA'] != null) setLiveBase(i - 1, segsFromJson(data['baseA']));
      if (data['baseB'] != null) setLiveBase(i, segsFromJson(data['baseB']));
      final tok = asInt(data['tok']);
      final before = tok == null ? null : _snapshot(i - 1, 2);
      if (!mergeWithPrevious(i)) return false;
      if (data['segs'] != null) setRuns(i - 1, segsFromJson(data['segs']));
      if (tok != null) live.structural[tok] = (i - 1, before!, _snapshot(i - 1, 1));
      return true;
    }
    if (data['mrange'] is List) {
      final r = data['mrange'] as List;
      final a = asInt(r.isNotEmpty ? r[0] : null);
      final b = asInt(r.length > 1 ? r[1] : null);
      if (a == null || b == null || a < 0 || b >= paragraphs.length || b <= a) {
        return false;
      }
      final bases = data['bases'];
      if (bases is List) {
        for (var k = 0; k < bases.length && a + k <= b; k++) {
          if (bases[k] != null) setLiveBase(a + k, segsFromJson(bases[k]));
        }
      }
      final tok = asInt(data['tok']);
      final before = tok == null ? null : _snapshot(a, b - a + 1);
      for (var k = b; k > a; k--) {
        if (!mergeWithPrevious(a + 1)) return false;
      }
      setRuns(a, segsFromJson(data['segs']));
      if (tok != null) live.structural[tok] = (a, before!, _snapshot(a, 1));
      return true;
    }
    if (data['restore'] != null) {
      final tok = asInt(data['restore']);
      final entry = tok == null ? null : live.structural[tok];
      if (entry == null) return false;
      final undo = data['undo'] == true;
      final (i, before, after) = entry;
      final from = undo ? after : before;
      final to = undo ? before : after;
      final segs = data['segs'] is List ? data['segs'] as List : const [];
      return _replaceRange(i, from.length, to, [
        for (final s in segs) segsFromJson(s),
      ]);
    }
    if (data['i'] != null && data['segs'] != null) {
      final i = asInt(data['i']);
      if (i == null || i < 0 || i >= paragraphs.length) return false;
      final base = data['base'] == null ? null : segsFromJson(data['base']);
      setRuns(i, segsFromJson(data['segs']), base: base);
      return true;
    }
    return true;
  }
}

/// Yapısal işlem anlık görüntüsü: paragrafın XML kopyası + son parçaları.
typedef _ParaSnap = (XmlElement, List<RunSeg>?);

extension _DocxLiveStructural on DocxEditor {
  List<_ParaSnap> _snapshot(int i, int count) => [
        for (var k = i; k < i + count && k < paragraphs.length; k++)
          (paragraphs[k]._element.copy(), _live.lastSegs[paragraphs[k]]),
      ];

  /// [i]'den başlayan [count] paragrafı anlık görüntüdeki paragraflarla
  /// değiştirir (yapısal geri al / yinele). Görüntü KOPYALANARAK konur; ada
  /// kimlikleri JS'in gönderdiği parçalara göre yeni düğümlere bağlanır.
  bool _replaceRange(int i, int count, List<_ParaSnap> items,
      List<List<RunSeg>> segs) {
    if (i < 0 || i + count > paragraphs.length || count == 0) return false;
    final first = paragraphs[i]._element;
    final parent = first.parent;
    if (parent == null) return false;
    var at = parent.children.indexOf(first);
    for (var k = i; k < i + count; k++) {
      final el = paragraphs[k]._element;
      el.parent?.children.remove(el);
      _live.lastSegs.remove(paragraphs[k]);
    }
    paragraphs.removeRange(i, i + count);
    for (var k = 0; k < items.length; k++) {
      final el = items[k].$1.copy();
      parent.children.insert(at++, el);
      final para = DocxEditor._paraFrom(el);
      para._markRich();
      paragraphs.insert(i + k, para);
      _live.resolved.add(para);
      final s = k < segs.length ? segs[k] : items[k].$2;
      if (s != null) {
        _live.lastSegs[para] = s;
        // Ada kimlikleri sırayla yeni (kopya) düğümlere.
        final ids = [for (final x in s) if (x.island != null) x.island!];
        final islands = _islandChildren(el);
        for (var j = 0; j < ids.length && j < islands.length; j++) {
          _live.islands[ids[j]] = islands[j];
        }
      }
    }
    return true;
  }
}
