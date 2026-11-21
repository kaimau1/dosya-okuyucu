part of 'docx_document.dart';

/// B9 m.3 — Değişiklikleri izle (yazarken).
///
/// Açıkken yazılan metin harf biçimine [DocxRev] işareti olarak girer ve
/// kayıtta `w:ins` içine yazılır; silinen metin modelden çıkar ama XML'de
/// sıfır genişlikli çapa olarak `w:del` (`w:delText`) kalır — dosyadan okunan
/// silmelerle aynı yol (ekranda görünmez, Gözden Geçir'de kabul/ret).
/// Kendi eklemesini silmek iz bırakmaz (Word gibi). Bayrak `settings.xml`
/// `w:trackRevisions`'tan okunur ve oraya yazılır.
///
/// Paragraf işareti de izlenir: Enter sol parçanın işaretini eklenmiş
/// (`w:pPr/w:rPr/w:ins`), paragraf birleştirme öncekinin işaretini silinmiş
/// (`w:pPr/w:rPr/w:del`) yazar — paragraflar ayrı kalır, kabulde Word
/// birleştirir. Kendi eklediği işareti silmek gerçekten birleştirir.
/// Biçim değişikliği (kalın, renk, biçimi temizle, biçim boyacısı) harfe
/// [DocxFmtRev] olarak girer, kayıtta `w:rPrChange` (eski biçimle) olur.

const _settingsRel =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings';
const _settingsCt =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml';

/// `w:settings` şemasında `w:trackRevisions`'tan ÖNCE gelen öğeler.
const _beforeTrackRevisions = {
  'writeProtection', 'view', 'zoom', 'removePersonalInformation',
  'removeDateAndTime', 'doNotDisplayPageBoundaries', 'displayBackgroundShape',
  'printPostScriptOverText', 'printFractionalCharacterWidth', 'printFormsData',
  'embedTrueTypeFonts', 'embedSystemFonts', 'saveSubsetFonts', 'saveFormsData',
  'mirrorMargins', 'alignBordersAndEdges', 'bordersDoNotSurroundHeader',
  'bordersDoNotSurroundFooter', 'gutterAtTop', 'hideSpellingErrors',
  'hideGrammaticalErrors', 'activeWritingStyle', 'proofState', 'formsDesign',
  'attachedTemplate', 'linkStyles', 'stylePaneFormatFilter',
  'stylePaneSortMethod', 'documentType', 'mailMerge', 'revisionView',
};

/// Run'da metin dışı bir şey yoksa (izlenen ekleme düzenlenebilir okunur).
const _plainRunKids = {
  'rPr', 't', 'tab', 'cr', 'noBreakHyphen', 'softHyphen',
  'lastRenderedPageBreak',
};

extension DocxTrack on DocxDocument {
  /// Değişiklikleri izle açık mı (`settings.xml` `w:trackRevisions`).
  bool get trackChanges => _trackOn ??= _readTrackFlag();

  bool _readTrackFlag() {
    final name = _partByRel('/settings');
    if (name == null) return false;
    final x = _parts[name] ?? _partReader?.call(name);
    if (x == null) return false;
    for (final e in x.rootElement.childElements) {
      if (e.name.local != 'trackRevisions') continue;
      final v = DocxDocument._attr(e, 'val');
      return v == null || !const {'0', 'false', 'off'}.contains(v);
    }
    return false;
  }

  /// Bayrağı değiştirir ve `settings.xml`'e yazar (parça yoksa yaratılır).
  void setTrackChanges(bool on) {
    if (on == trackChanges) return;
    _trackOn = on;
    _sessionRev = null;
    final x = _sidePart('/settings', _settingsRel, 'word/settings.xml',
        _settingsCt, '<w:settings ${DocxDocument._wNs}/>');
    final root = x.rootElement;
    root.children.removeWhere(
        (n) => n is XmlElement && n.name.local == 'trackRevisions');
    if (on) {
      var at = 0;
      for (var k = 0; k < root.children.length; k++) {
        final n = root.children[k];
        if (n is XmlElement && _beforeTrackRevisions.contains(n.name.local)) {
          at = k + 1;
        }
      }
      root.children
          .insert(at, XmlElement(const XmlName.qualified('w:trackRevisions')));
    }
    _dirtyParts.add(_sidePartName('/settings', 'word/settings.xml'));
  }

  /// Bu oturumun ekleme işareti (yazar + ilk düzenleme anı).
  DocxRev _currentRev() {
    final name = revAuthor.trim().isEmpty ? 'Yazar' : revAuthor.trim();
    final have = _sessionRev;
    if (have != null && have.author == name) return have;
    final now = DateTime.now().toUtc();
    final iso = '${now.toIso8601String().split('.').first.replaceAll('Z', '')}Z';
    return _sessionRev = DocxRev(name, iso);
  }

  /// Düzenleyicinin metin yazma/silme yolu: izle kapalıysa düz
  /// [DocxPara.replace] (yazılan harfe eski ekleme işareti geçmez); açıksa
  /// yazılan `w:ins`, silinen `w:del` olur.
  DocxPara editText(
      DocxPara p, int from, int to, String insert, DocxCharStyle style) {
    if (!trackChanges) return p.replace(from, to, insert, style.withRev(null));
    final a = from.clamp(0, p.length), b = to.clamp(a, p.length);
    final rev = _currentRev();
    _liveTracked = true;
    final dels = a < b ? _deletionNodes(p, a, b, rev.author) : const <XmlElement>[];
    final next = p.replace(a, b, insert, style.withRev(rev));
    if (dels.isEmpty) return next;
    // Silinenin XML yeri: [a]'daki eski çapalardan sonra, [b]'den kayanlardan
    // önce — art arda geri silmede metin sırası korunur.
    final delta = insert.length - (b - a);
    final before = <(int, XmlElement)>[], after = <(int, XmlElement)>[];
    for (final (o, e) in p.anchors) {
      if (o <= a) {
        before.add((o, e));
      } else {
        after.add((o >= b ? o + delta : a, e));
      }
    }
    final mine = [for (final d in dels) (a, d)];
    // Bitişik kendi silmemizle birleştir (kopya: geri al eski düğümü tutar).
    if (insert.isEmpty && mine.length == 1 && mine.single.$2.name.local == 'del') {
      final d = mine.single.$2;
      if (after.isNotEmpty && after.first.$1 == a && _ownDel(after.first.$2)) {
        final merged = _ownDelCopy(after.first.$2)
          ..children.insertAll(0, d.children.map((c) => c.copy()));
        after[0] = (a, merged);
        mine.clear();
      } else if (before.isNotEmpty &&
          before.last.$1 == a &&
          _ownDel(before.last.$2)) {
        final merged = _ownDelCopy(before.last.$2)
          ..children.addAll(d.children.map((c) => c.copy()));
        before[before.length - 1] = (a, merged);
        mine.clear();
      }
    }
    return next.copyWith(anchors: [...before, ...mine, ...after]);
  }

  static final _own = Expando<bool>('docxOwnDel');

  bool _ownDel(XmlElement e) =>
      e.name.local == 'del' &&
      _own[e] == true &&
      DocxDocument._attr(e, 'author') == _currentRev().author;

  XmlElement _ownDelCopy(XmlElement e) {
    final c = e.copy();
    _own[c] = true;
    return c;
  }

  XmlElement _delBox(String author) {
    final d = XmlElement(const XmlName.qualified('w:del'), [
      XmlAttribute(const XmlName.qualified('w:id'), '${_nextRevId()}'),
      XmlAttribute(const XmlName.qualified('w:author'), author),
      XmlAttribute(const XmlName.qualified('w:date'), _currentRev().date),
    ]);
    _own[d] = true;
    return d;
  }

  /// [a, b) aralığının silinmiş XML'i (belge sırasıyla). Kendi eklememiz
  /// iz bırakmaz; başkasının eklemesi `w:ins > w:del` olur.
  List<XmlElement> _deletionNodes(DocxPara p, int a, int b, String author) {
    final out = <XmlElement>[];
    XmlElement? box;
    DocxRev? boxRev;
    XmlElement open(DocxRev? rev) {
      final cur = box;
      if (cur != null && identical(boxRev, rev)) return cur;
      final d = _delBox(author);
      if (rev == null) {
        out.add(d);
      } else {
        final ins = _insElement(rev)..children.add(d);
        out.add(ins);
      }
      boxRev = rev;
      return box = d;
    }

    var k = a;
    while (k < b) {
      final atom = p.atoms[k];
      final style = p.styles[k];
      final rev = style.rev;
      if (rev != null && rev.author == author) {
        k++; // kendi eklememiz: yalnız kalkar
        continue;
      }
      if (atom != null) {
        for (final n in atom.nodes) {
          if (n.name.local == 'r') {
            open(rev).children.add(_deletedRun(n.copy()));
          } else {
            box = null;
            out.add(_deleteInside(n.copy(), author));
          }
        }
        k++;
        continue;
      }
      var j = k + 1;
      while (j < b &&
          p.atoms[j] == null &&
          DocxDocument._sameWrite(p.styles[j], style)) {
        j++;
      }
      open(rev).children.add(
          _deletedRun(DocxDocument._newRun(style, p.text.substring(k, j))));
      k = j;
    }
    return out;
  }

  /// Run içindeki metni silinmiş metne çevirir (`w:t` → `w:delText`).
  static XmlElement _deletedRun(XmlElement r) {
    for (final d in r.descendantElements.toList()) {
      final to = switch (d.name.local) {
        't' => 'w:delText',
        'instrText' => 'w:delInstrText',
        _ => null,
      };
      if (to == null) continue;
      final repl = XmlElement(XmlName.qualified(to),
          d.attributes.map((x) => x.copy()), d.children.map((c) => c.copy()));
      d.parent!.children[d.parent!.children.indexOf(d)] = repl;
    }
    return r;
  }

  /// Run olmayan kap (köprü, alan, denetim, eklenmiş metin): içindeki her
  /// run `w:del` ile sarılır; kap yerinde kalır.
  XmlElement _deleteInside(XmlElement n, String author) {
    final runs = n.descendantElements.where((e) {
      if (e.name.local != 'r') return false;
      for (var up = e.parent; up != null && !identical(up, n); up = up.parent) {
        if (up is XmlElement &&
            const {'del', 'moveFrom', 'r'}.contains(up.name.local)) {
          return false;
        }
      }
      return true;
    }).toList();
    for (final r in runs) {
      final parent = r.parent!;
      final at = parent.children.indexOf(r);
      parent.children.removeAt(at);
      final d = _delBox(author)..children.add(_deletedRun(r));
      parent.children.insert(at, d);
    }
    return n;
  }

  /// Bu oturumda izlenerek yazıldı/silindi mi (henüz kaydedilmemiş olabilir).
  bool get hasLiveRevisions => _liveTracked;

  // ── biçim değişikliği ───────────────────────────────────────────────────

  /// İzle açıkken [before] → [after] biçim değişikliğinde değişen harfler
  /// [DocxFmtRev] alır (kayıtta `w:rPrChange` + eski `w:rPr`). Kendi
  /// eklememizdeki harf işaretlenmez (Word gibi); zaten işaretliyse ilk eski
  /// biçim korunur.
  DocxPara trackFormat(DocxPara before, DocxPara after) {
    if (!trackChanges || identical(before, after)) return after;
    final rev = _currentRev();
    final st = [...after.styles];
    final fmts = Map<DocxCharStyle, DocxFmtRev>.identity();
    final made = Map<DocxFmtRev, Map<DocxCharStyle, DocxCharStyle>>.identity();
    var any = false;
    for (var k = 0; k < st.length && k < before.styles.length; k++) {
      final b = before.styles[k];
      if (identical(b, st[k]) || after.atoms[k] != null) continue;
      if (b.rev != null && b.rev!.author == rev.author) continue;
      final f = b.fmt ?? (fmts[b] ??= DocxFmtRev(rev, _oldRPr(b)));
      st[k] = (made[f] ??= Map.identity())[st[k]] ??= st[k].withFmt(f);
      any = true;
    }
    if (!any) return after;
    _liveTracked = true;
    return after.copyWith(styles: st);
  }

  /// Harfin değişiklikten önce yazılacak `w:rPr`'si. Dosyada zaten izlenen
  /// biçim değişikliği varsa onun eski hâli (ilk durum).
  static XmlElement _oldRPr(DocxCharStyle s) {
    final prev = DocxDocument._child(DocxDocument._child(s.rPr, 'rPrChange'), 'rPr');
    if (prev != null) return prev.copy();
    return DocxDocument._child(DocxDocument._newRun(s, ''), 'rPr') ??
        XmlElement(const XmlName.qualified('w:rPr'));
  }

  // ── paragraf işareti ────────────────────────────────────────────────────

  /// Paragraf işaretinin izleme öğesi (`w:pPr/w:rPr/w:ins|del`), yoksa null.
  static XmlElement? _paraMark(XmlElement? pPr, String local) =>
      DocxDocument._child(DocxDocument._child(pPr, 'rPr'), local);

  /// [pPr]'nin kopyası, işaretine [mark] eklenmiş (`w:ins` başa, `w:del`
  /// varsa `w:ins`ten sonra — CT_ParaRPr sırası).
  static XmlElement _withParaMark(XmlElement? pPr, XmlElement mark) {
    final out = pPr?.copy() ?? XmlElement(const XmlName.qualified('w:pPr'));
    var rPr = DocxDocument._child(out, 'rPr');
    if (rPr == null) {
      rPr = XmlElement(const XmlName.qualified('w:rPr'));
      // pPr şemasında rPr'den sonra yalnız sectPr ve pPrChange gelir.
      final at = out.children.indexWhere((n) =>
          n is XmlElement && const {'sectPr', 'pPrChange'}.contains(n.name.local));
      out.children.insert(at < 0 ? out.children.length : at, rPr);
    }
    final ins = DocxDocument._child(rPr, 'ins');
    rPr.children.insert(
        mark.name.local == 'del' && ins != null ? rPr.children.indexOf(ins) + 1 : 0,
        mark);
    return out;
  }

  /// İzle açıkken Enter: sol parçanın paragraf işareti eklenmiştir.
  DocxPara markParaInserted(DocxPara p) {
    if (!trackChanges || _paraMark(p.pPr, 'ins') != null) return p;
    _liveTracked = true;
    return p.copyWith(pPr: _withParaMark(p.pPr, _insElement(_currentRev())));
  }

  /// İzle açıkken [p] ile sonrakinin birleştirilmesi: [p]'nin işareti
  /// silinmiş işaretlenir (paragraflar ayrı kalır). İşareti bu yazarın
  /// eklemesiyse null — çağıran gerçekten birleştirir ([withoutParaIns]).
  DocxPara? markParaDeleted(DocxPara p) {
    final ins = _paraMark(p.pPr, 'ins');
    if (ins != null && DocxDocument._attr(ins, 'author') == _currentRev().author) {
      return null;
    }
    if (_paraMark(p.pPr, 'del') != null) return p;
    _liveTracked = true;
    return p.copyWith(
        pPr: _withParaMark(p.pPr, _delBox(_currentRev().author)));
  }

  /// İşaretin eklenme izi kalkmış [p] (kendi eklememiz geri silindi).
  DocxPara withoutParaIns(DocxPara p) {
    if (_paraMark(p.pPr, 'ins') == null) return p;
    final pPr = p.pPr!.copy();
    final rPr = DocxDocument._child(pPr, 'rPr')!;
    rPr.children.removeWhere((n) => n is XmlElement && n.name.local == 'ins');
    if (rPr.children.whereType<XmlElement>().isEmpty) pPr.children.remove(rPr);
    return p.copyWith(pPr: pPr);
  }
}

/// `w:ins` yalnız düz metin run'larından mı oluşuyor.
bool _plainIns(XmlElement e) {
  var runs = 0;
  for (final n in e.children) {
    if (n is XmlText && n.value.trim().isEmpty) continue;
    if (n is! XmlElement) {
      if (n is XmlText) return false;
      continue;
    }
    if (n.name.local != 'r') return false;
    runs++;
    for (final c in n.childElements) {
      final l = c.name.local;
      if (_plainRunKids.contains(l)) continue;
      if (l == 'br') {
        final t = DocxDocument._attr(c, 'type');
        if (t == null || t == 'textWrapping') continue;
      }
      return false;
    }
  }
  return runs > 0;
}
