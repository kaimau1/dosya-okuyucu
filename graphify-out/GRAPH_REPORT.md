# Graph Report - dosya okuyucu  (2026-07-22)

## Corpus Check
- 57 files · ~44,256 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1403 nodes · 2276 edges · 67 communities (55 shown, 12 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 111 edges (avg confidence: 0.63)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `96648b64`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_App State Management|App State Management]]
- [[_COMMUNITY_Spreadsheet Editor|Spreadsheet Editor]]
- [[_COMMUNITY_PDF Conversion Service|PDF Conversion Service]]
- [[_COMMUNITY_Document Viewer Screen|Document Viewer Screen]]
- [[_COMMUNITY_Slides Editor Screen|Slides Editor Screen]]
- [[_COMMUNITY_Firebase Authentication Service|Firebase Authentication Service]]
- [[_COMMUNITY_Word Editor Screen|Word Editor Screen]]
- [[_COMMUNITY_Home Screen Navigation|Home Screen Navigation]]
- [[_COMMUNITY_Gemini AI Service|Gemini AI Service]]
- [[_COMMUNITY_Settings and Account|Settings and Account]]
- [[_COMMUNITY_Chat Interface|Chat Interface]]
- [[_COMMUNITY_PowerPoint Parser|PowerPoint Parser]]
- [[_COMMUNITY_Word Document Parser|Word Document Parser]]
- [[_COMMUNITY_UI Theme and Icons|UI Theme and Icons]]
- [[_COMMUNITY_Document Models|Document Models]]
- [[_COMMUNITY_Flutter Widget States|Flutter Widget States]]
- [[_COMMUNITY_Recent Files Data|Recent Files Data]]
- [[_COMMUNITY_UI Components|UI Components]]
- [[_COMMUNITY_App Entry Point|App Entry Point]]
- [[_COMMUNITY_Office File Extraction|Office File Extraction]]
- [[_COMMUNITY_State Change Handlers|State Change Handlers]]
- [[_COMMUNITY_Project Documentation|Project Documentation]]
- [[_COMMUNITY_ue|ue]]
- [[_COMMUNITY_xlsx_editor.dart|xlsx_editor.dart]]
- [[_COMMUNITY_docx-preview.min.js|docx-preview.min.js]]
- [[_COMMUNITY_.elements|.elements]]
- [[_COMMUNITY_r|r]]
- [[_COMMUNITY_s|s]]
- [[_COMMUNITY_slideshow_screen.dart|slideshow_screen.dart]]
- [[_COMMUNITY_.parseDefaultProperties|.parseDefaultProperties]]
- [[_COMMUNITY_.attr|.attr]]
- [[_COMMUNITY_slide_canvas.dart|slide_canvas.dart]]
- [[_COMMUNITY_docx_view.dart|docx_view.dart]]
- [[_COMMUNITY_file_service.dart|file_service.dart]]
- [[_COMMUNITY_pptx_render_test.dart|pptx_render_test.dart]]
- [[_COMMUNITY_.element|.element]]
- [[_COMMUNITY_packagefluttermaterial.dart|package:flutter/material.dart]]
- [[_COMMUNITY_darttyped_data|dart:typed_data]]
- [[_COMMUNITY_Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)|Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)]]
- [[_COMMUNITY_Firebase Kurulumu (bulut giriş + senkron)|Firebase Kurulumu (bulut giriş + senkron)]]
- [[_COMMUNITY_MaterialPageRoute|MaterialPageRoute]]
- [[_COMMUNITY_file_type_icon.dart|file_type_icon.dart]]
- [[_COMMUNITY_Dosya Okuyucu|Dosya Okuyucu]]
- [[_COMMUNITY_APK İmzalama (sabit anahtar = kolay güncelleme)|APK İmzalama (sabit anahtar = kolay güncelleme)]]
- [[_COMMUNITY_ie|ie]]
- [[_COMMUNITY_ee|ee]]
- [[_COMMUNITY_G|G]]
- [[_COMMUNITY_M|M]]
- [[_COMMUNITY_CLAUDE.md Rules|CLAUDE.md Rules]]
- [[_COMMUNITY_AppState|AppState]]
- [[_COMMUNITY_ce|ce]]
- [[_COMMUNITY_KALANLAR — canlı kalan-iş listesi (biten madde silinir)|KALANLAR — canlı kalan-iş listesi (biten madde silinir)]]
- [[_COMMUNITY_.parseXml|.parseXml]]
- [[_COMMUNITY_te|te]]
- [[_COMMUNITY_pinch_zoom_area.dart|pinch_zoom_area.dart]]
- [[_COMMUNITY_xls_legacy.dart|xls_legacy.dart]]
- [[_COMMUNITY_gemini_service.dart|gemini_service.dart]]
- [[_COMMUNITY_legacy_text.dart|legacy_text.dart]]
- [[_COMMUNITY_AppState|AppState]]
- [[_COMMUNITY_pptx_structure_test.dart|pptx_structure_test.dart]]
- [[_COMMUNITY_pptx_gradient_test.dart|pptx_gradient_test.dart]]
- [[_COMMUNITY_legacy_text_test.dart|legacy_text_test.dart]]
- [[_COMMUNITY_Exception|Exception]]
- [[_COMMUNITY_G|G]]
- [[_COMMUNITY_ge|ge]]
- [[_COMMUNITY_.parseXml|.parseXml]]
- [[_COMMUNITY_number_formats_512de8d6|number_formats_512de8d6.md]]

## God Nodes (most connected - your core abstractions)
1. `ue()` - 87 edges
2. `oe` - 51 edges
3. `a()` - 31 edges
4. `r()` - 28 edges
5. `AppState` - 21 edges
6. `s()` - 18 edges
7. `n()` - 14 edges
8. `j()` - 14 edges
9. `n()` - 13 edges
10. `ke` - 13 edges

## Surprising Connections (you probably didn't know these)
- `a()` --indirect_call--> `d()`  [INFERRED]
  assets/word/docx-preview.min.js → assets/word/jszip.min.js
- `a()` --indirect_call--> `f()`  [INFERRED]
  assets/word/docx-preview.min.js → assets/word/jszip.min.js
- `l()` --indirect_call--> `a()`  [INFERRED]
  assets/word/jszip.min.js → assets/word/docx-preview.min.js
- `n()` --indirect_call--> `a()`  [INFERRED]
  assets/word/jszip.min.js → assets/word/docx-preview.min.js
- `o()` --calls--> `a()`  [INFERRED]
  assets/word/jszip.min.js → assets/word/docx-preview.min.js

## Import Cycles
- None detected.

## Communities (67 total, 12 thin omitted)

### Community 0 - "App State Management"
Cohesion: 0.05
Nodes (40): addMemory, addRecent, _apiKey, _encodeMap, firebase, firebaseAvailable, hasApiKey, init (+32 more)

### Community 1 - "Spreadsheet Editor"
Cohesion: 0.04
Nodes (46): double get, _afterStructural, _applyCell, _cell, _cellBar, _cellField, _colLabel, createState (+38 more)

### Community 2 - "PDF Conversion Service"
Cohesion: 0.10
Nodes (20): BlankDocs, blankDocx, blankXlsx, create, _stamp, _targetDir, _zip, bullets (+12 more)

### Community 3 - "Document Viewer Screen"
Cohesion: 0.04
Nodes (50): FocusNode, _buildBody, _changeFont, _colLabel, controller, _conversion, createState, _dirty (+42 more)

### Community 4 - "Slides Editor Screen"
Cohesion: 0.06
Nodes (31): chat_screen.dart, _buildSlides, _confirmDeleteSlide, createState, _dirty, dispose, _editor, _editShape (+23 more)

### Community 5 - "Firebase Authentication Service"
Cohesion: 0.09
Nodes (21): FirebaseAuth?, FirebaseFirestore?, _auth, authState, _available, currentUser, _db, FirebaseService (+13 more)

### Community 6 - "Word Editor Screen"
Cohesion: 0.06
Nodes (34): _addParagraph, _buildPage, _bytes, createState, _deleteParagraph, _dirty, _editing, _editor (+26 more)

### Community 7 - "Home Screen Navigation"
Cohesion: 0.06
Nodes (33): editors/slides_editor_screen.dart, editors/spreadsheet_editor_screen.dart, editors/word_editor_screen.dart, _createAndOpen, createState, _cycleTheme, dispose, _fileService (+25 more)

### Community 8 - "Gemini AI Service"
Cohesion: 0.13
Nodes (14): AppTheme, _base, canvas, dark, excel, forKind, light, neutral (+6 more)

### Community 9 - "Settings and Account"
Cohesion: 0.12
Nodes (17): _AccountSection, _AccountSectionState, _apiKey, _busy, createState, dispose, _email, _error (+9 more)

### Community 10 - "Chat Interface"
Cohesion: 0.10
Nodes (21): build, _busy, ChatScreen, _ChatScreenState, controller, createState, dispose, enabled (+13 more)

### Community 11 - "PowerPoint Parser"
Cohesion: 0.04
Nodes (56): _addContentOverride, _addFile, _addPresRel, _addTo, _appendSldId, _archive, canEditStructure, _contentTypes (+48 more)

### Community 12 - "Word Document Parser"
Cohesion: 0.05
Nodes (43): Archive, bool _bold0, _italic0,, addParagraphAfter, align, _align0, _appendRun, _applyFormat, _archive (+35 more)

### Community 13 - "UI Theme and Icons"
Cohesion: 0.10
Nodes (19): ../core/theme.dart, dart:async, actions, body, bottomBar, build, bump, dirty (+11 more)

### Community 14 - "Document Models"
Cohesion: 0.18
Nodes (11): bool get, DocKind, DocKindLabel, isEditableText, kind, LoadedDoc, name, path (+3 more)

### Community 15 - "Flutter Widget States"
Cohesion: 0.05
Nodes (43): int r1, c1, r2,, c2, _callFunc, _cellValue, _compare, displayValue, eng, _eval (+35 more)

### Community 16 - "Recent Files Data"
Cohesion: 0.20
Nodes (9): dart:convert, encode, name, openedAtMs, path, RecentFile, sizeBytes, toMap (+1 more)

### Community 17 - "UI Components"
Cohesion: 0.12
Nodes (16): _Bubble, _ChatHint, _Composer, _EmptyState, _NoMatch, _RecentList, _AboutSection, _SpreadsheetView (+8 more)

### Community 18 - "App Entry Point"
Cohesion: 0.18
Nodes (10): ../core/app_state.dart, appState, DosyaOkuyucuApp, _enableHighRefreshRate, init, main, setEnabledSystemUIMode, package:flutter_displaymode/flutter_displaymode.dart (+2 more)

### Community 19 - "Office File Extraction"
Cohesion: 0.25
Nodes (7): extractDocxText, extractPptxText, _fileByName, OfficeReader, _slideIndex, package:archive/archive.dart, package:xml/xml.dart

### Community 20 - "State Change Handlers"
Cohesion: 0.02
Nodes (107): double dx, dy, sx,, double x, y, w,, EdgeInsets, Gradient?, align, AnimTarget, _archive, autofit (+99 more)

### Community 21 - "Project Documentation"
Cohesion: 0.17
Nodes (11): 2026-07-21 — APK derleme tetikleyicisi (dispatch API yasak!), 2026-07-21 — CI politikası: APK yalnızca istendiğinde (limit tasarrufu), 2026-07-21 — Eski Office (.doc/.xls/.ppt) SALT-OKUNUR görüntüleme, 2026-07-21 — Excel sayı biçimleri (görüntüleme sadakati), 2026-07-21 — TUZAK: commit mesajı işaretiyle CI tetikleme kırılgan, Açık Durum / Bekleyenler, Bilinen Riskler / Tuzaklar, Build Geçmişi (+3 more)

### Community 22 - "ue"
Cohesion: 0.07
Nodes (4): c(), qe(), ue(), Ye()

### Community 23 - "xlsx_editor.dart"
Cohesion: 0.03
Nodes (79): Color?, dart:ui, Excel, int rowStart, colStart, rowEnd,, abs, align, applyNumberFormat, background (+71 more)

### Community 24 - "docx-preview.min.js"
Cohesion: 0.10
Nodes (23): a(), ae(), b(), D(), de, E(), H(), i() (+15 more)

### Community 25 - ".elements"
Cohesion: 0.15
Nodes (3): l(), oe, r()

### Community 26 - "r"
Cohesion: 0.23
Nodes (22): F(), U, A(), c(), d(), f(), G(), h() (+14 more)

### Community 27 - "s"
Cohesion: 0.12
Nodes (5): je(), ke, n(), s(), ve()

### Community 28 - "slideshow_screen.dart"
Cohesion: 0.08
Nodes (24): int get, _backward, build, createState, dispose, _forward, _go, _index (+16 more)

### Community 29 - ".parseDefaultProperties"
Cohesion: 0.15
Nodes (3): he, xe(), ze

### Community 31 - "slide_canvas.dart"
Cohesion: 0.11
Nodes (18): dart:math, int?, ShapeVM, SlideVM, build, child, _fitScale, _paragraph (+10 more)

### Community 32 - "docx_view.dart"
Cohesion: 0.09
Nodes (22): IconData, build, bytes, _controller, createState, DocxView, DocxViewState, _error (+14 more)

### Community 33 - "file_service.dart"
Cohesion: 0.10
Nodes (19): legacy_text.dart, FileService, _imageExts, isLegacyOffice, kindForExtension, _legacyOffice, load, _loadLegacy (+11 more)

### Community 34 - "pptx_render_test.dart"
Cohesion: 0.12
Nodes (16): AnimatedOpacity, package:dosya_okuyucu/screens/editors/slideshow_screen.dart, package:dosya_okuyucu/services/pptx_render.dart, package:dosya_okuyucu/widgets/slide_canvas.dart, package:flutter/material.dart, RichText, add, archive (+8 more)

### Community 35 - ".element"
Cohesion: 0.23
Nodes (12): SlidesEditorScreen, _SlidesEditorScreenState, SlideshowScreen, _SlideshowScreenState, SpreadsheetEditorScreen, _SpreadsheetEditorScreenState, WordEditorScreen, _WordEditorScreenState (+4 more)

### Community 36 - "package:flutter/material.dart"
Cohesion: 0.14
Nodes (14): dart:io, dart:typed_data, package:dosya_okuyucu/models/document.dart, package:dosya_okuyucu/services/file_service.dart, package:dosya_okuyucu/services/formula_engine.dart, package:dosya_okuyucu/services/ole_cfb.dart, package:dosya_okuyucu/services/xls_legacy.dart, package:flutter_test/flutter_test.dart (+6 more)

### Community 37 - "dart:typed_data"
Cohesion: 0.22
Nodes (8): package:dosya_okuyucu/services/xlsx_editor.dart, package:excel/excel.dart, excel, fromList, main, _sampleXlsx, sheet, main

### Community 38 - "Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md)"
Cohesion: 0.25
Nodes (7): 1) Amaç, 2) Mimari / Dosya Haritası, 3) CI/CD (.github/workflows/build-apk.yml), 4) Çalışma Kuralları, 5) Bağlantılar, Dosya Okuyucu — Çalışma Kuralları (CLAUDE.md), Hafıza (usta koordineli — 3 katman)

### Community 39 - "Firebase Kurulumu (bulut giriş + senkron)"
Cohesion: 0.25
Nodes (7): 1. Firebase projesi oluştur, 2. FlutterFire CLI ile bağla (önerilen), 3. Kimlik doğrulama sağlayıcılarını aç, 4. Firestore’u aç, 5. CI (GitHub Actions) için, Firebase Kurulumu (bulut giriş + senkron), Veri modeli

### Community 40 - "MaterialPageRoute"
Cohesion: 0.25
Nodes (8): _promptForKey, build, _play, build, build, build, _openChat, MaterialPageRoute

### Community 41 - "file_type_icon.dart"
Cohesion: 0.29
Nodes (6): build, FileTypeIcon, kind, size, _style, ../models/document.dart

### Community 42 - "Dosya Okuyucu"
Cohesion: 0.29
Nodes (6): Derleme (CI), Dosya Okuyucu, Yapay zeka anahtarı, Yerel geliştirme, Yol haritası (sonraki sürümler), Özellikler (MVP – build 1)

### Community 43 - "APK İmzalama (sabit anahtar = kolay güncelleme)"
Cohesion: 0.33
Nodes (5): Anahtar parmak izi (fingerprint), APK İmzalama (sabit anahtar = kolay güncelleme), Kalıcı imzayı etkinleştirme (bir kerelik, ~2 dk), Parola, Önemli

### Community 46 - "G"
Cohesion: 0.22
Nodes (14): _blend(), draw_glyph(), fill_bg_gradient(), _lerp(), _line_seg_coverage(), main(), new_buffer(), src (r,g,b) rengini dst pikseline a kapsamayla karıştırır (alpha over). (+6 more)

### Community 49 - "AppState"
Cohesion: 0.15
Nodes (11): package:dosya_okuyucu/services/blank_docs.dart, package:dosya_okuyucu/services/docx_editor.dart, main, archive, data, doc, _docXml, fromList (+3 more)

### Community 51 - "KALANLAR — canlı kalan-iş listesi (biten madde silinir)"
Cohesion: 0.40
Nodes (4): Bilinen eksik-risk, KALANLAR — canlı kalan-iş listesi (biten madde silinir), Sonra yapılacak, Yarım kalan

### Community 54 - "pinch_zoom_area.dart"
Cohesion: 0.06
Nodes (35): double?, _DirEntry, firstOf, looksLikeOle, name, OleFile, _parse, read (+27 more)

### Community 55 - "xls_legacy.dart"
Cohesion: 0.09
Nodes (22): _Bound, _chars, data, name, _numStr, offset, _parse, _parseSheet (+14 more)

### Community 56 - "gemini_service.dart"
Cohesion: 0.13
Nodes (14): apiKey, _base, chat, ChatTurn, _endpoint, fromUser, GeminiService, message (+6 more)

### Community 57 - "legacy_text.dart"
Cohesion: 0.14
Nodes (13): _accept, _best, _cp1252Runs, extractFromStream, fromDoc, fromPpt, _isLetter, LegacyText (+5 more)

### Community 58 - "AppState"
Cohesion: 0.18
Nodes (11): ChangeNotifier, AppState, build, _saveToMemory, _send, _openPath, build, initState (+3 more)

### Community 59 - "pptx_structure_test.dart"
Cohesion: 0.18
Nodes (10): package:dosya_okuyucu/services/pptx_editor.dart, add, archive, _firstText, fromList, main, pkgRel, rel (+2 more)

### Community 60 - "pptx_gradient_test.dart"
Cohesion: 0.33
Nodes (5): LinearGradient, package:flutter/painting.dart, RadialGradient, main, _ns

### Community 61 - "legacy_text_test.dart"
Cohesion: 0.33
Nodes (5): package:dosya_okuyucu/services/legacy_text.dart, fromList, main, out, _utf16le

### Community 62 - "Exception"
Cohesion: 0.50
Nodes (4): Exception, _CycleError, _ValueError, GeminiException

## Knowledge Gaps
- **832 isolated node(s):** `_kApiKey`, `_kModel`, `_kThemeMode`, `_kRecents`, `_kMemory` (+827 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ue()` connect `ue` to `docx-preview.min.js`, `.elements`, `.parseDefaultProperties`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **Why does `AppState` connect `AppState` to `App State Management`, `.element`, `Document Viewer Screen`, `Home Screen Navigation`, `MaterialPageRoute`, `Settings and Account`, `Chat Interface`, `App Entry Point`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `PptxEditor` connect `Slides Editor Screen` to `PowerPoint Parser`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **Are the 23 inferred relationships involving `a()` (e.g. with `d()` and `f()`) actually correct?**
  _`a()` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 24 inferred relationships involving `r()` (e.g. with `.parseXml()` and `je()`) actually correct?**
  _`r()` has 24 INFERRED edges - model-reasoned connections that need verification._
- **What connects `_kApiKey`, `_kModel`, `_kThemeMode` to the rest of the system?**
  _836 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `App State Management` be split into smaller, more focused modules?**
  _Cohesion score 0.04878048780487805 - nodes in this community are weakly interconnected._