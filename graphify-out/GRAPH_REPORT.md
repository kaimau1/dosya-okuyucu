# Graph Report - dosya okuyucu  (2026-07-21)

## Corpus Check
- 37 files · ~21,243 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 953 nodes · 1740 edges · 49 communities (41 shown, 8 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 111 edges (avg confidence: 0.63)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7bf3fd9a`
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

## Communities (49 total, 8 thin omitted)

### Community 0 - "App State Management"
Cohesion: 0.05
Nodes (40): addMemory, addRecent, _apiKey, _encodeMap, firebase, firebaseAvailable, hasApiKey, init (+32 more)

### Community 1 - "Spreadsheet Editor"
Cohesion: 0.06
Nodes (33): _applyCell, _cell, _cellBar, _cellField, _colLabel, createState, _dirty, dispose (+25 more)

### Community 2 - "PDF Conversion Service"
Cohesion: 0.14
Nodes (13): dart:io, bullets, ConversionService, _Slide, _splitIntoSlides, textToPdf, textToSlidesPdf, title (+5 more)

### Community 3 - "Document Viewer Screen"
Cohesion: 0.07
Nodes (27): _buildBody, controller, _conversion, createState, _dirty, dispose, doc, editable (+19 more)

### Community 4 - "Slides Editor Screen"
Cohesion: 0.10
Nodes (21): _buildSlides, createState, _dirty, _editor, _editShape, _error, _export, _fallbackText (+13 more)

### Community 5 - "Firebase Authentication Service"
Cohesion: 0.09
Nodes (21): FirebaseAuth?, FirebaseFirestore?, _auth, authState, _available, currentUser, _db, FirebaseService (+13 more)

### Community 6 - "Word Editor Screen"
Cohesion: 0.10
Nodes (21): chat_screen.dart, _buildPage, _bytes, createState, _dirty, _editor, _error, _export (+13 more)

### Community 7 - "Home Screen Navigation"
Cohesion: 0.11
Nodes (19): editors/slides_editor_screen.dart, editors/spreadsheet_editor_screen.dart, editors/word_editor_screen.dart, createState, _fileService, hasApiKey, HomeScreen, _HomeScreenState (+11 more)

### Community 8 - "Gemini AI Service"
Cohesion: 0.11
Nodes (17): Exception, apiKey, _base, chat, ChatTurn, _endpoint, fromUser, GeminiException (+9 more)

### Community 9 - "Settings and Account"
Cohesion: 0.12
Nodes (20): ChatScreen, _ChatScreenState, _AccountSection, _AccountSectionState, _apiKey, _busy, createState, dispose (+12 more)

### Community 10 - "Chat Interface"
Cohesion: 0.12
Nodes (16): build, _busy, controller, createState, dispose, enabled, fileContext, fileName (+8 more)

### Community 11 - "PowerPoint Parser"
Cohesion: 0.09
Nodes (21): _archive, doc, element, fileName, _idx, index, paragraphOf, paragraphs (+13 more)

### Community 12 - "Word Document Parser"
Cohesion: 0.12
Nodes (16): Archive, _appendRun, _archive, _doc, DocxEditor, DocxParagraph, _element, heading (+8 more)

### Community 13 - "UI Theme and Icons"
Cohesion: 0.29
Nodes (6): AppTheme, _base, dark, light, _seed, static const Color

### Community 14 - "Document Models"
Cohesion: 0.18
Nodes (11): bool get, DocKind, DocKindLabel, isEditableText, kind, LoadedDoc, name, path (+3 more)

### Community 16 - "Recent Files Data"
Cohesion: 0.20
Nodes (9): dart:convert, encode, name, openedAtMs, path, RecentFile, sizeBytes, toMap (+1 more)

### Community 17 - "UI Components"
Cohesion: 0.17
Nodes (12): _Bubble, _ChatHint, _Composer, _EmptyState, _RecentList, _AboutSection, _SpreadsheetView, _TextEditor (+4 more)

### Community 18 - "App Entry Point"
Cohesion: 0.12
Nodes (17): ChangeNotifier, ../core/app_state.dart, core/theme.dart, AppState, appState, build, DosyaOkuyucuApp, init (+9 more)

### Community 19 - "Office File Extraction"
Cohesion: 0.25
Nodes (7): extractDocxText, extractPptxText, _fileByName, OfficeReader, _slideIndex, package:archive/archive.dart, package:xml/xml.dart

### Community 20 - "State Change Handlers"
Cohesion: 0.02
Nodes (100): double dx, dy, sx,, double x, y, w,, EdgeInsets, align, AnimTarget, _archive, background, backgroundImage (+92 more)

### Community 21 - "Project Documentation"
Cohesion: 0.29
Nodes (6): Açık Durum / Bekleyenler, Bilinen Riskler / Tuzaklar, Build Geçmişi, Dosya Okuyucu — Proje Hafızası, Sabit Kararlar (tarihli, append-only), Yol Haritası (öncelik kullanıcıyla netleşecek)

### Community 22 - "ue"
Cohesion: 0.07
Nodes (6): c(), ge, l(), qe(), ue(), Ye()

### Community 23 - "xlsx_editor.dart"
Cohesion: 0.05
Nodes (41): Color?, dart:ui, double?, Excel, int rowStart, colStart, rowEnd,, align, background, bold (+33 more)

### Community 24 - "docx-preview.min.js"
Cohesion: 0.09
Nodes (22): a(), b(), be, D(), de, E(), H(), i() (+14 more)

### Community 26 - "r"
Cohesion: 0.23
Nodes (24): F(), je(), U, A(), c(), d(), f(), G() (+16 more)

### Community 27 - "s"
Cohesion: 0.13
Nodes (4): ke, n(), s(), ve()

### Community 28 - "slideshow_screen.dart"
Cohesion: 0.08
Nodes (24): int get, _backward, build, createState, dispose, _forward, _go, _index (+16 more)

### Community 30 - ".attr"
Cohesion: 0.14
Nodes (5): ce, fe, k, pe, xe()

### Community 31 - "slide_canvas.dart"
Cohesion: 0.12
Nodes (16): dart:math, int?, ShapeVM, SlideVM, build, child, _paragraph, paraVisible (+8 more)

### Community 32 - "docx_view.dart"
Cohesion: 0.13
Nodes (15): build, bytes, _controller, createState, DocxView, _DocxViewState, _error, initState (+7 more)

### Community 33 - "file_service.dart"
Cohesion: 0.14
Nodes (13): FileService, _imageExts, kindForExtension, load, _loadSpreadsheet, pickFilePath, readBytes, _readTextSafely (+5 more)

### Community 34 - "pptx_render_test.dart"
Cohesion: 0.18
Nodes (10): AnimatedOpacity, package:dosya_okuyucu/services/pptx_editor.dart, package:dosya_okuyucu/widgets/slide_canvas.dart, add, archive, fromList, main, _samplePptx (+2 more)

### Community 35 - ".element"
Cohesion: 0.27
Nodes (3): ae(), le, o()

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

## Knowledge Gaps
- **462 isolated node(s):** `_kApiKey`, `_kModel`, `_kThemeMode`, `_kRecents`, `_kMemory` (+457 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ue()` connect `ue` to `docx-preview.min.js`, `.elements`, `.attr`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Why does `AppState` connect `App Entry Point` to `App State Management`, `Document Viewer Screen`, `Home Screen Navigation`, `MaterialPageRoute`, `Settings and Account`, `Chat Interface`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **Why does `oe` connect `.elements` to `docx-preview.min.js`, `.element`, `.parseDefaultProperties`, `.attr`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Are the 23 inferred relationships involving `a()` (e.g. with `d()` and `f()`) actually correct?**
  _`a()` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 24 inferred relationships involving `r()` (e.g. with `.parseXml()` and `je()`) actually correct?**
  _`r()` has 24 INFERRED edges - model-reasoned connections that need verification._
- **What connects `_kApiKey`, `_kModel`, `_kThemeMode` to the rest of the system?**
  _462 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `App State Management` be split into smaller, more focused modules?**
  _Cohesion score 0.04878048780487805 - nodes in this community are weakly interconnected._