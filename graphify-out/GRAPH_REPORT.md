# Graph Report - dosya okuyucu  (2026-07-22)

## Corpus Check
- 41 files · ~26,925 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1059 nodes · 1879 edges · 54 communities (45 shown, 9 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 111 edges (avg confidence: 0.63)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9c21cc89`
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

## Communities (54 total, 9 thin omitted)

### Community 0 - "App State Management"
Cohesion: 0.05
Nodes (40): addMemory, addRecent, _apiKey, _encodeMap, firebase, firebaseAvailable, hasApiKey, init (+32 more)

### Community 1 - "Spreadsheet Editor"
Cohesion: 0.04
Nodes (49): double get, _applyCell, _badge, _cell, _cellBar, _cellField, _colLabel, _commitZoom (+41 more)

### Community 2 - "PDF Conversion Service"
Cohesion: 0.14
Nodes (13): dart:io, bullets, ConversionService, _Slide, _splitIntoSlides, textToPdf, textToSlidesPdf, title (+5 more)

### Community 3 - "Document Viewer Screen"
Cohesion: 0.07
Nodes (27): _buildBody, controller, _conversion, createState, _dirty, dispose, doc, editable (+19 more)

### Community 4 - "Slides Editor Screen"
Cohesion: 0.07
Nodes (26): _badge, _buildSlides, createState, _dirty, dispose, _editor, _editShape, _error (+18 more)

### Community 5 - "Firebase Authentication Service"
Cohesion: 0.09
Nodes (21): FirebaseAuth?, FirebaseFirestore?, _auth, authState, _available, currentUser, _db, FirebaseService (+13 more)

### Community 6 - "Word Editor Screen"
Cohesion: 0.07
Nodes (26): _buildPage, _bytes, createState, _dirty, _editing, _editor, _error, _export (+18 more)

### Community 7 - "Home Screen Navigation"
Cohesion: 0.11
Nodes (19): chat_screen.dart, editors/slides_editor_screen.dart, editors/spreadsheet_editor_screen.dart, editors/word_editor_screen.dart, createState, _fileService, hasApiKey, HomeScreen (+11 more)

### Community 8 - "Gemini AI Service"
Cohesion: 0.06
Nodes (31): Exception, AppTheme, _base, canvas, dark, excel, forKind, light (+23 more)

### Community 9 - "Settings and Account"
Cohesion: 0.10
Nodes (24): ChangeNotifier, AppState, _saveToMemory, _send, _openPath, _AccountSection, _AccountSectionState, _apiKey (+16 more)

### Community 10 - "Chat Interface"
Cohesion: 0.11
Nodes (19): build, _busy, ChatScreen, _ChatScreenState, controller, createState, dispose, enabled (+11 more)

### Community 11 - "PowerPoint Parser"
Cohesion: 0.09
Nodes (21): _archive, doc, element, fileName, _idx, index, paragraphOf, paragraphs (+13 more)

### Community 12 - "Word Document Parser"
Cohesion: 0.09
Nodes (22): Archive, _appendRun, _archive, _doc, DocxEditor, DocxParagraph, _element, heading (+14 more)

### Community 13 - "UI Theme and Icons"
Cohesion: 0.10
Nodes (19): ../core/theme.dart, dart:async, actions, body, bottomBar, build, bump, dirty (+11 more)

### Community 14 - "Document Models"
Cohesion: 0.18
Nodes (11): bool get, DocKind, DocKindLabel, isEditableText, kind, LoadedDoc, name, path (+3 more)

### Community 16 - "Recent Files Data"
Cohesion: 0.22
Nodes (8): encode, name, openedAtMs, path, RecentFile, sizeBytes, toMap, tryDecode

### Community 17 - "UI Components"
Cohesion: 0.14
Nodes (14): _Bubble, _ChatHint, _Composer, _EmptyState, _RecentList, _AboutSection, _SpreadsheetView, _TextEditor (+6 more)

### Community 18 - "App Entry Point"
Cohesion: 0.17
Nodes (11): ../core/app_state.dart, appState, build, DosyaOkuyucuApp, _enableHighRefreshRate, init, main, setEnabledSystemUIMode (+3 more)

### Community 19 - "Office File Extraction"
Cohesion: 0.25
Nodes (7): extractDocxText, extractPptxText, _fileByName, OfficeReader, _slideIndex, package:archive/archive.dart, package:xml/xml.dart

### Community 20 - "State Change Handlers"
Cohesion: 0.02
Nodes (101): double dx, dy, sx,, double x, y, w,, EdgeInsets, align, AnimTarget, _archive, autofit, background (+93 more)

### Community 21 - "Project Documentation"
Cohesion: 0.29
Nodes (6): Açık Durum / Bekleyenler, Bilinen Riskler / Tuzaklar, Build Geçmişi, Dosya Okuyucu — Proje Hafızası, Sabit Kararlar (tarihli, append-only), Yol Haritası (öncelik kullanıcıyla netleşecek)

### Community 22 - "ue"
Cohesion: 0.07
Nodes (4): c(), ge, l(), ue()

### Community 23 - "xlsx_editor.dart"
Cohesion: 0.05
Nodes (42): Color?, dart:ui, double?, Excel, int rowStart, colStart, rowEnd,, align, background, bold (+34 more)

### Community 24 - "docx-preview.min.js"
Cohesion: 0.09
Nodes (23): a(), b(), D(), de, E(), fe, H(), he (+15 more)

### Community 26 - "r"
Cohesion: 0.19
Nodes (23): F(), G, U, A(), c(), d(), f(), G() (+15 more)

### Community 27 - "s"
Cohesion: 0.12
Nodes (5): je(), ke, n(), s(), ve()

### Community 28 - "slideshow_screen.dart"
Cohesion: 0.09
Nodes (22): int get, _backward, build, createState, dispose, _forward, _go, _index (+14 more)

### Community 30 - ".attr"
Cohesion: 0.15
Nodes (4): ae(), le, ne(), w()

### Community 31 - "slide_canvas.dart"
Cohesion: 0.11
Nodes (18): dart:math, int?, ShapeVM, SlideVM, build, child, _fitScale, _paragraph (+10 more)

### Community 32 - "docx_view.dart"
Cohesion: 0.12
Nodes (16): build, bytes, _controller, createState, _error, format, initState, _loading (+8 more)

### Community 33 - "file_service.dart"
Cohesion: 0.14
Nodes (13): FileService, _imageExts, kindForExtension, load, _loadSpreadsheet, pickFilePath, readBytes, _readTextSafely (+5 more)

### Community 34 - "pptx_render_test.dart"
Cohesion: 0.15
Nodes (12): AnimatedOpacity, package:dosya_okuyucu/services/pptx_editor.dart, package:dosya_okuyucu/widgets/slide_canvas.dart, RichText, add, archive, _autofitPptx, fromList (+4 more)

### Community 35 - ".element"
Cohesion: 0.27
Nodes (10): SlidesEditorScreen, _SlidesEditorScreenState, SlideshowScreen, _SlideshowScreenState, WordEditorScreen, _WordEditorScreenState, DocxView, DocxViewState (+2 more)

### Community 36 - "package:flutter/material.dart"
Cohesion: 0.20
Nodes (8): package:dosya_okuyucu/screens/editors/slideshow_screen.dart, package:dosya_okuyucu/services/pptx_render.dart, package:flutter/material.dart, package:flutter/services.dart, package:flutter_test/flutter_test.dart, main, _slide, main

### Community 37 - "dart:typed_data"
Cohesion: 0.22
Nodes (8): dart:typed_data, package:dosya_okuyucu/services/xlsx_editor.dart, package:excel/excel.dart, excel, fromList, main, _sampleXlsx, sheet

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
Cohesion: 0.22
Nodes (8): dart:convert, package:dosya_okuyucu/services/docx_editor.dart, archive, data, fromList, main, _sampleDocx, xml

### Community 50 - "ce"
Cohesion: 0.22
Nodes (3): ce, k, pe

### Community 51 - "KALANLAR — canlı kalan-iş listesi (biten madde silinir)"
Cohesion: 0.40
Nodes (4): Bilinen eksik-risk, KALANLAR — canlı kalan-iş listesi (biten madde silinir), Sonra yapılacak, Yarım kalan

## Knowledge Gaps
- **538 isolated node(s):** `_kApiKey`, `_kModel`, `_kThemeMode`, `_kRecents`, `_kMemory` (+533 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ue()` connect `ue` to `docx-preview.min.js`, `.elements`, `.parseDefaultProperties`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `AppState` connect `Settings and Account` to `App State Management`, `Document Viewer Screen`, `Home Screen Navigation`, `MaterialPageRoute`, `Chat Interface`, `App Entry Point`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `oe` connect `.elements` to `docx-preview.min.js`, `.parseDefaultProperties`, `.attr`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Are the 23 inferred relationships involving `a()` (e.g. with `d()` and `f()`) actually correct?**
  _`a()` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 24 inferred relationships involving `r()` (e.g. with `.parseXml()` and `je()`) actually correct?**
  _`r()` has 24 INFERRED edges - model-reasoned connections that need verification._
- **What connects `_kApiKey`, `_kModel`, `_kThemeMode` to the rest of the system?**
  _542 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `App State Management` be split into smaller, more focused modules?**
  _Cohesion score 0.04878048780487805 - nodes in this community are weakly interconnected._