import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:xml/xml.dart';

import 'pptx_package.dart';

/// Sunumdaki bir medya şekli (oynatma için).
class SlideMediaRef {
  final int shapeId;

  /// Konum (punto, slayt koordinatı).
  final double x, y, w, h;
  final String part;
  final bool video;

  /// Slayta girince kendiliğinden çalar (kayıtlı anlatım).
  final bool autoplay;
  const SlideMediaRef(
      this.shapeId, this.x, this.y, this.w, this.h, this.part, this.video,
      {this.autoplay = false});
}

/// Anlatım sesinin işareti (`p:cNvPr@descr`).
const kNarrationMarker = 'dosya:anlatim';

/// **Faz 38 / madde 4 — ses/video ekleme.** PowerPoint'in yazdığı yapı:
/// `p:pic` + `a:videoFile|a:audioFile r:link` + `p14:media r:embed`, kapak
/// görseli `a:blip`. Medya baytı `ppt/media/`'ya olduğu gibi girer (yeniden
/// kodlama yok).
abstract final class PptxMediaOps {
  static const _relMedia =
      'http://schemas.microsoft.com/office/2007/relationships/media';
  static const _mediaExt = '{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}';

  static const mimes = {
    'mp4': 'video/mp4',
    'm4v': 'video/mp4',
    'mov': 'video/quicktime',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'opus': 'audio/ogg',
  };

  static bool isVideoExt(String ext) => mimes[ext.toLowerCase()]?.startsWith('video') ?? false;
  static bool isMediaExt(String ext) => mimes.containsKey(ext.toLowerCase());

  /// Ses için kapak: hoparlör simgesi (düz PNG, izolatta üretilir).
  static Uint8List audioPoster() {
    final im = img.Image(width: 160, height: 160, numChannels: 4);
    img.fill(im, color: img.ColorRgba8(0, 0, 0, 0));
    img.fillCircle(im, x: 80, y: 80, radius: 76, color: img.ColorRgba8(47, 111, 224, 255));
    final white = img.ColorRgba8(255, 255, 255, 255);
    img.fillRect(im, x1: 42, y1: 62, x2: 66, y2: 98, color: white);
    img.fillPolygon(im, vertices: [
      img.Point(66, 62), img.Point(96, 38), img.Point(96, 122), img.Point(66, 98),
    ], color: white);
    img.drawCircle(im, x: 96, y: 80, radius: 18, color: white);
    img.drawCircle(im, x: 96, y: 80, radius: 30, color: white);
    return img.encodePng(im);
  }

  /// Medyayı slayta ekler. [poster] PNG/JPEG kapak (videoda ilk kare; yoksa
  /// ses simgesi). [emu] null → ortada.
  static PptxOp insert(int slide, Uint8List media, String ext,
          {Uint8List? poster, String posterExt = 'png', String name = '',
          List<int>? emu}) =>
      (pkg) {
        final e = ext.toLowerCase();
        final mime = mimes[e];
        if (mime == null) throw ArgumentError('media');
        final video = mime.startsWith('video');
        final part = pkg.slidePart(slide);
        final doc = pkg.edit(part)!;
        final tree = PptxPackage.spTree(doc)!;
        final mediaPart = pkg.freeName('ppt/media/media', e);
        pkg.putBytes(mediaPart, media);
        pkg.ensureDefault(e, mime);
        final cover = poster ?? audioPoster();
        final pe = poster == null ? 'png' : posterExt.toLowerCase();
        final imgPart = pkg.freeName('ppt/media/image', pe);
        pkg.putBytes(imgPart, cover);
        pkg.ensureDefault(pe, pe == 'png' ? 'image/png' : 'image/jpeg');
        final ridMedia = pkg.addRel(part, _relMedia, mediaPart);
        final ridLink = pkg.addRel(part, video ? 'video' : 'audio', mediaPart);
        final ridImg = pkg.addRel(part, 'image', imgPart);
        final (w, h) = pkg.slideSize();
        final r = emu ??
            (video
                ? [w ~/ 6, h ~/ 6, w * 2 ~/ 3, h * 2 ~/ 3]
                : [w * 5 ~/ 12, h * 5 ~/ 12, w ~/ 12, w ~/ 12]);
        final id = PptxPackage.nextShapeId(doc);
        final label = PptxPackage.esc(name.isEmpty ? mediaPart.split('/').last : name);
        tree.children.add(PptxPackage.frag('<p:pic><p:nvPicPr>'
            '<p:cNvPr id="$id" name="$label"><a:hlinkClick r:id="" action="ppaction://media"/></p:cNvPr>'
            '<p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr>'
            '<p:nvPr><a:${video ? 'videoFile' : 'audioFile'} r:link="$ridLink"/>'
            '<p:extLst><p:ext uri="$_mediaExt"><p14:media xmlns:p14="${PptxPackage.nsP14}" r:embed="$ridMedia"/></p:ext></p:extLst>'
            '</p:nvPr></p:nvPicPr>'
            '<p:blipFill><a:blip r:embed="$ridImg"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>'
            '<p:spPr><a:xfrm><a:off x="${r[0]}" y="${r[1]}"/><a:ext cx="${r[2]}" cy="${r[3]}"/></a:xfrm>'
            '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>'));
      };

  /// Slayttaki medya şekilleri (sunum sırasıyla bir slayt).
  static List<SlideMediaRef> mediaOf(PptxPackage pkg, String slide) {
    final d = pkg.xml(slide);
    if (d == null) return const [];
    final out = <SlideMediaRef>[];
    for (final pic in d.findAllElements('p:pic')) {
      final nv = pic.getElement('p:nvPicPr')?.getElement('p:nvPr');
      if (nv == null) continue;
      final file = nv.getElement('a:videoFile') ?? nv.getElement('a:audioFile');
      final p14 = nv.findAllElements('p14:media').firstOrNull;
      final rid = p14?.getAttribute('r:embed') ?? file?.getAttribute('r:link');
      if (rid == null) continue;
      final target = pkg.relTarget(slide, rid);
      if (target == null || !pkg.has(target)) continue; // dış bağlantı
      final xf = pic.getElement('p:spPr')?.getElement('a:xfrm');
      double v(String tag, String a) =>
          (int.tryParse(xf?.getElement(tag)?.getAttribute(a) ?? '') ?? 0) / 12700;
      final ext = target.split('.').last;
      out.add(SlideMediaRef(
        int.tryParse(pic.findAllElements('p:cNvPr').firstOrNull?.getAttribute('id') ?? '') ?? 0,
        v('a:off', 'x'),
        v('a:off', 'y'),
        v('a:ext', 'cx'),
        v('a:ext', 'cy'),
        target,
        file?.name.local == 'videoFile' || (file == null && isVideoExt(ext)),
        autoplay: pic.findAllElements('p:cNvPr').firstOrNull?.getAttribute('descr') ==
            kNarrationMarker,
      ));
    }
    return out;
  }

  /// **Faz 38 / madde 9 — kayıtlı anlatım.** Slaytın önceki anlatımını
  /// kaldırır, yeni sesi (M4A) sağ alt köşeye küçük simgeyle ekler, slayta
  /// girince çalmasını (PowerPoint `playFrom` komutu) ve [ms] sonra sonraki
  /// slayta geçmeyi (`p:transition@advTm`) yazar.
  static PptxOp setNarration(int slide, Uint8List audio, int ms) => (pkg) {
        final part = pkg.slidePart(slide);
        final d = pkg.edit(part)!;
        // Eski anlatım: şekil + oynatma düğümleri.
        final old = [
          for (final c in d.findAllElements('p:cNvPr'))
            if (c.getAttribute('descr') == kNarrationMarker) c.getAttribute('id'),
        ];
        for (final id in old) {
          final sh = PptxPackage.shapeById(d, int.tryParse(id ?? '') ?? -1);
          sh?.parent?.children.remove(sh);
        }
        final timing = d.rootElement.getElement('p:timing');
        if (timing != null && old.isNotEmpty) {
          for (final t in timing.findAllElements('p:spTgt').toList()) {
            if (!old.contains(t.getAttribute('spid'))) continue;
            // Hedefi gidenin en dış düğümü: mainSeq'teki par ya da p:audio.
            XmlElement? n = t;
            while (n != null &&
                !(n.name.qualified == 'p:audio' ||
                    (n.name.qualified == 'p:par' &&
                        n.parentElement?.parentElement?.getAttribute('nodeType') == 'mainSeq'))) {
              n = n.parentElement;
            }
            n?.parent?.children.remove(n);
          }
        }
        final (w, h) = pkg.slideSize();
        final side = h ~/ 14;
        insert(slide, audio, 'm4a',
            name: 'Anlatım',
            emu: [w - side * 3 ~/ 2, h - side * 3 ~/ 2, side, side])(pkg);
        final id = PptxPackage.nextShapeId(d) - 1;
        PptxPackage.shapeById(d, id)
            ?.findAllElements('p:cNvPr')
            .first
            .setAttribute('descr', kNarrationMarker);
        // Geçiş: advTm (ECMA sırası cSld, clrMapOvr, transition, timing).
        var tr = d.rootElement.getElement('p:transition');
        if (tr == null) {
          tr = XmlElement(XmlName.fromString('p:transition'));
          final after = d.rootElement.getElement('p:clrMapOvr') ??
              d.rootElement.getElement('p:cSld');
          final kids = d.rootElement.children;
          kids.insert(after == null ? 0 : kids.indexOf(after) + 1, tr);
        }
        tr.setAttribute('advTm', '${ms.clamp(500, 86400000)}');
        // Zamanlama: slayt başında oynat.
        var t = d.rootElement.getElement('p:timing');
        if (t == null || t.findAllElements('p:cTn').where((c) => c.getAttribute('nodeType') == 'mainSeq').isEmpty) {
          t?.parent?.children.remove(t);
          t = PptxPackage.frag('<p:timing><p:tnLst><p:par>'
              '<p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot"><p:childTnLst>'
              '<p:seq concurrent="1" nextAc="seek"><p:cTn id="2" dur="indefinite" nodeType="mainSeq"><p:childTnLst/></p:cTn>'
              '<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>'
              '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>'
              '</p:seq></p:childTnLst></p:cTn></p:par></p:tnLst></p:timing>');
          final ext = d.rootElement.getElement('p:extLst');
          final kids = d.rootElement.children;
          kids.insert(ext == null ? kids.length : kids.indexOf(ext), t);
        }
        final main = t.findAllElements('p:cTn').firstWhere((c) => c.getAttribute('nodeType') == 'mainSeq');
        main.getElement('p:childTnLst')!.children.insert(
            0,
            PptxPackage.frag('<p:par><p:cTn id="0" fill="hold"><p:stCondLst><p:cond delay="indefinite"/>'
                '<p:cond evt="onBegin" delay="0"><p:tn val="2"/></p:cond></p:stCondLst><p:childTnLst>'
                '<p:par><p:cTn id="0" fill="hold"><p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>'
                '<p:par><p:cTn id="0" presetID="1" presetClass="mediacall" presetSubtype="0" fill="hold" nodeType="afterEffect">'
                '<p:stCondLst><p:cond delay="0"/></p:stCondLst><p:childTnLst>'
                '<p:cmd type="call" cmd="playFrom(0.0)"><p:cBhvr><p:cTn id="0" dur="$ms" fill="hold"/>'
                '<p:tgtEl><p:spTgt spid="$id"/></p:tgtEl></p:cBhvr></p:cmd>'
                '</p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par></p:childTnLst></p:cTn></p:par>'));
        main.parentElement!.parentElement!.children.add(PptxPackage.frag(
            '<p:audio><p:cMediaNode vol="80000"><p:cTn id="0" display="0" fill="hold">'
            '<p:stCondLst><p:cond delay="indefinite"/></p:stCondLst>'
            '<p:endCondLst><p:cond evt="onStopAudio" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:endCondLst>'
            '</p:cTn><p:tgtEl><p:spTgt spid="$id"/></p:tgtEl></p:cMediaNode></p:audio>'));
        var n = 1;
        for (final c in t.findAllElements('p:cTn')) {
          c.setAttribute('id', '${n++}');
        }
      };
}
