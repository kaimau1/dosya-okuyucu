# Graph Report - C:\Users\sena\Desktop\dosya okuyucu  (2026-07-21)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 390 nodes · 522 edges · 22 communities (21 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 1 edges (avg confidence: 0.9)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d58fa947`
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

## God Nodes (most connected - your core abstractions)
1. `AppState` - 21 edges
2. `_ChatScreenState` - 4 edges
3. `_HomeScreenState` - 4 edges
4. `_SettingsScreenState` - 4 edges
5. `_AccountSectionState` - 4 edges
6. `_ViewerScreenState` - 4 edges
7. `DosyaOkuyucuApp` - 3 edges
8. `DocKind` - 3 edges
9. `ChatScreen` - 3 edges
10. `SlidesEditorScreen` - 3 edges

## Surprising Connections (you probably didn't know these)
- `build` --references--> `AppState`  [EXTRACTED]
  lib/main.dart → lib/core/app_state.dart
- `CLAUDE.md Rules` --conceptually_related_to--> `Project Memory (HAFIZA.md)`  [EXTRACTED]
  CLAUDE.md → HAFIZA.md
- `DosyaOkuyucuApp` --references--> `AppState`  [EXTRACTED]
  lib/main.dart → lib/core/app_state.dart
- `_ChatScreenState` --references--> `AppState`  [EXTRACTED]
  lib/screens/chat_screen.dart → lib/core/app_state.dart
- `_saveToMemory` --references--> `AppState`  [EXTRACTED]
  lib/screens/chat_screen.dart → lib/core/app_state.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Office Document Editing Flow** — lib_services_docx_editor, lib_services_pptx_editor, lib_services_xlsx_editor, lib_screens_editors_word_editor_screen, lib_screens_editors_slides_editor_screen, lib_screens_editors_spreadsheet_editor_screen [EXTRACTED 0.95]

## Communities (22 total, 1 thin omitted)

### Community 0 - "App State Management"
Cohesion: 0.05
Nodes (40): addMemory, addRecent, _apiKey, _encodeMap, firebase, firebaseAvailable, hasApiKey, init (+32 more)

### Community 1 - "Spreadsheet Editor"
Cohesion: 0.05
Nodes (36): Excel, int get, _buildSheet, _cell, _cellH, _cellW, _colLabel, createState (+28 more)

### Community 2 - "PDF Conversion Service"
Cohesion: 0.07
Nodes (26): dart:io, bullets, ConversionService, _Slide, _splitIntoSlides, textToPdf, textToSlidesPdf, title (+18 more)

### Community 3 - "Document Viewer Screen"
Cohesion: 0.08
Nodes (25): _buildBody, controller, _conversion, createState, _dirty, dispose, doc, editable (+17 more)

### Community 4 - "Slides Editor Screen"
Cohesion: 0.08
Nodes (24): _promptForKey, build, _buildSlides, createState, _dirty, _editor, _error, _export (+16 more)

### Community 5 - "Firebase Authentication Service"
Cohesion: 0.09
Nodes (22): Firebase Setup Guide, FirebaseAuth?, FirebaseFirestore?, _auth, authState, _available, currentUser, _db (+14 more)

### Community 6 - "Word Editor Screen"
Cohesion: 0.11
Nodes (18): ../chat_screen.dart, _buildPage, createState, _dirty, _editor, _error, _export, initState (+10 more)

### Community 7 - "Home Screen Navigation"
Cohesion: 0.11
Nodes (17): editors/slides_editor_screen.dart, editors/spreadsheet_editor_screen.dart, editors/word_editor_screen.dart, createState, _fileService, hasApiKey, _loading, onOpen (+9 more)

### Community 8 - "Gemini AI Service"
Cohesion: 0.11
Nodes (17): Exception, apiKey, _base, chat, ChatTurn, _endpoint, fromUser, GeminiException (+9 more)

### Community 9 - "Settings and Account"
Cohesion: 0.12
Nodes (17): _AccountSection, _AccountSectionState, _apiKey, _busy, createState, dispose, _email, _error (+9 more)

### Community 10 - "Chat Interface"
Cohesion: 0.12
Nodes (16): build, _busy, controller, createState, dispose, enabled, fileContext, fileName (+8 more)

### Community 11 - "PowerPoint Parser"
Cohesion: 0.12
Nodes (15): Archive, _archive, _doc, _element, _fileName, _idx, index, paragraphs (+7 more)

### Community 12 - "Word Document Parser"
Cohesion: 0.12
Nodes (15): _appendRun, _archive, _doc, DocxEditor, DocxParagraph, _element, heading, level (+7 more)

### Community 13 - "UI Theme and Icons"
Cohesion: 0.13
Nodes (13): AppTheme, _base, dark, light, _seed, build, FileTypeIcon, kind (+5 more)

### Community 14 - "Document Models"
Cohesion: 0.18
Nodes (11): bool get, DocKind, DocKindLabel, isEditableText, kind, LoadedDoc, name, path (+3 more)

### Community 15 - "Flutter Widget States"
Cohesion: 0.23
Nodes (12): ChatScreen, _ChatScreenState, SlidesEditorScreen, _SlidesEditorScreenState, SpreadsheetEditorScreen, _SpreadsheetEditorScreenState, HomeScreen, _HomeScreenState (+4 more)

### Community 16 - "Recent Files Data"
Cohesion: 0.20
Nodes (9): dart:convert, encode, name, openedAtMs, path, RecentFile, sizeBytes, toMap (+1 more)

### Community 17 - "UI Components"
Cohesion: 0.20
Nodes (10): DosyaOkuyucuApp, _Bubble, _ChatHint, _Composer, _EmptyState, _RecentList, _AboutSection, _SpreadsheetView (+2 more)

### Community 18 - "App Entry Point"
Cohesion: 0.22
Nodes (8): core/app_state.dart, core/theme.dart, appState, build, init, main, package:provider/provider.dart, screens/home_screen.dart

### Community 19 - "Office File Extraction"
Cohesion: 0.22
Nodes (8): dart:typed_data, extractDocxText, extractPptxText, _fileByName, OfficeReader, _slideIndex, package:archive/archive.dart, package:xml/xml.dart

### Community 20 - "State Change Handlers"
Cohesion: 0.25
Nodes (8): ChangeNotifier, AppState, _saveToMemory, _send, _openPath, build, initState, build

## Knowledge Gaps
- **251 isolated node(s):** `_kApiKey`, `_kModel`, `_kThemeMode`, `_kRecents`, `_kMemory` (+246 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppState` connect `State Change Handlers` to `App State Management`, `Document Viewer Screen`, `Slides Editor Screen`, `Home Screen Navigation`, `Settings and Account`, `Chat Interface`, `Flutter Widget States`, `UI Components`, `App Entry Point`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Why does `RecentFile` connect `Recent Files Data` to `App State Management`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `_kApiKey`, `_kModel`, `_kThemeMode` to the rest of the system?**
  _251 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `App State Management` be split into smaller, more focused modules?**
  _Cohesion score 0.04878048780487805 - nodes in this community are weakly interconnected._
- **Should `Spreadsheet Editor` be split into smaller, more focused modules?**
  _Cohesion score 0.05405405405405406 - nodes in this community are weakly interconnected._
- **Should `PDF Conversion Service` be split into smaller, more focused modules?**
  _Cohesion score 0.07407407407407407 - nodes in this community are weakly interconnected._
- **Should `Document Viewer Screen` be split into smaller, more focused modules?**
  _Cohesion score 0.07692307692307693 - nodes in this community are weakly interconnected._