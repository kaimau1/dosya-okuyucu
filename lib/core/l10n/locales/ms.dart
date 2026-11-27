part of '../app_strings.dart';

/// Malayca (Bahasa Melayu, Malezya) — B17, 2026-11-27.
///
/// Ana tablonun (`strings/`) üstüne bindirilir: burada OLMAYAN anahtar
/// İngilizce gösterilir. Makine destekli ilk çeviri; anadili konuşan gözden
/// geçirmesi 👤 (PLAN §3 m.14). Endonezce ile yakın ama AYRI dil — Malezya
/// sözcükleri: "fail" (berkas değil), "padam", "tetapan", "kongsi", "storan".
/// Arayüz Latin (Rumi) yazıyla; Cavi yalnız içerikte.
///
/// Bekçi: `l10n_test` ve `tool/on_denetim.py`.
const Map<String, String> _ms = {
  // ── Umum ──
  'common.strike': 'Garis lorek',
  'common.paste': 'Tampal',
  'common.insert': 'Sisip',
  'common.ok': 'OK',
  'common.cancel': 'Batal',
  'common.yes': 'Ya',
  'common.no': 'Tidak',
  'common.details': 'Butiran',
  'common.close': 'Tutup',
  'common.save': 'Simpan',
  'common.delete': 'Padam',
  'common.share': 'Kongsi',
  'common.download': 'Muat turun',
  'common.open': 'Buka',
  'common.edit': 'Edit',
  'common.apply': 'Guna',
  'common.search': 'Cari',
  'common.refresh': 'Muat semula',
  'common.settings': 'Tetapan',
  'common.previous': 'Sebelumnya',
  'common.next': 'Seterusnya',
  'common.copy': 'Salin',
  'common.more': 'Lagi',
  'common.stop': 'Henti',
  'common.add': 'Tambah',
  'common.pause': 'Jeda',
  'common.resume': 'Sambung',
  'common.password': 'Kata laluan',
  'common.ignore': 'Abaikan',
  'common.go': 'Pergi',
  'common.saved': 'Disimpan',
  'common.save_failed': 'Tidak dapat menyimpan: {error}',
  'common.translate': 'Terjemah',
  'common.bold': 'Tebal',
  'common.italic': 'Condong',
  'common.underline': 'Garis bawah',
  'common.align_left': 'Jajar kiri',
  'common.align_center': 'Tengah',
  'common.align_right': 'Jajar kanan',
  'common.align_justify': 'Jajar penuh',
  'common.undo': 'Buat asal',
  'common.redo': 'Buat semula',
  'common.retry': 'Cuba lagi',
  'common.rescan': 'Imbas semula',
  'common.clear': 'Kosongkan',
  'common.clear_selection': 'Kosongkan pilihan',
  'common.remove_bookmark': 'Buang penanda buku',
  'common.new': 'Baharu',
  'common.oldest': 'paling lama',
  'common.best': 'terbaik',
  'common.deleting': 'Memadam',
  'common.saved_hint':
      'Disimpan. Guna ⋮ > Kongsi/Eksport untuk lokasi kekal.',
  'common.open_failed': 'Tidak dapat dibuka: {error}',
  'common.done': 'Selesai',

  // ── Laman utama ──
  'home.tab_files': 'Fail',
  'home.new_document_title': 'Cipta dokumen baharu',
  'home.new_word': 'Dokumen Word',
  'home.new_excel': 'Hamparan Excel',
  'home.new_text': 'Fail teks',
  'home.open_file': 'Buka fail',
  'home.open_error': 'Tidak dapat membuka fail: {error}',
  'home.create_error': 'Tidak dapat mencipta dokumen: {error}',
  'home.time_minutes': '{n} min lalu',
  'home.used_short': '{used} / {total} digunakan',
  'home.browse': 'Semak imbas',
  'home.analysis': 'Analisis',
  'home.free_space': 'Kosongkan',
  'home.drag_trash': 'Lepaskan di sini untuk membuang',
  'home.drag_trash_ready': 'Lepaskan untuk membuang dari laman utama',
  'home.tile_removed': '"{name}" dibuang dari laman utama',
  'home.undo': 'Buat asal',

  // ── Tetapan ──
  'settings.title': 'Tetapan',
  'settings.language': 'Bahasa',
  'settings.language_note':
      'Bahasa aplikasi. “Sistem” mengikut peranti anda; bahasa yang tidak '
          'disokong bertukar kepada bahasa Turki. Teks yang belum diterjemah '
          'dipaparkan dalam bahasa Inggeris.',
  'settings.language_system': 'Sistem',
  'settings.api_key': 'Kunci API Gemini',
  'settings.api_key_note':
      'Kunci disimpan pada peranti anda. Anda boleh mendapatkannya secara '
          'percuma di aistudio.google.com.',
  'settings.model_fetched': 'Model (daripada akaun anda)',
  'settings.model_default': 'Model (senarai lalai)',
  'settings.model_refresh': 'Muat semula senarai model',
  'settings.model_none': 'Tiada model ditemui untuk kunci ini.',
  'settings.model_error': '{error} Memaparkan senarai lalai.',
  'settings.theme': 'Tema',
  'settings.ui_font': 'Fon',
  'settings.ui_text_size': 'Saiz teks',
  'settings.size_small': 'Kecil',
  'settings.size_medium': 'Sederhana',
  'settings.size_large': 'Besar',
  'settings.size_xlarge': 'Sangat besar',
  'settings.font_sample': 'Contoh: Pembaca Fail — 0123456789',
  'settings.ui_text_size_note':
      'Fon dan saiz adalah sama pada setiap telefon; tetapan saiz fon sistem '
          'tidak menjejaskan aplikasi — tukar di sini sahaja.',
  'settings.perf_high_refresh': 'Kadar segar semula tinggi',
  'settings.perf_dynamic_refresh': 'Kadar segar semula dinamik',
  'settings.perf_dynamic_refresh_sub':
      'Jimat bateri: 120 Hz semasa menatal, 60 Hz atau lebih rendah apabila '
          'skrin pegun (30 Hz jika disokong).',
  'settings.perf_high_refresh_sub':
      'Tatal lebih lancar pada skrin 120 Hz. Matikan untuk kekal pada 60 Hz '
          'dan jimat bateri.',
  'settings.perf_auto_rescan': 'Imbas semula automatik',
  'settings.perf_auto_rescan_sub':
      'Papan pemuka mengimbas semula seluruh storan setiap 12 jam supaya fail '
          'yang ditambah di luar aplikasi kelihatan. Matikan dan muat semula '
          'senarai sendiri dengan menarik ke bawah.',
  'settings.about_sub': 'Maklumat versi dan lesen',
  'settings.theme_system': 'Sistem',
  'settings.theme_light': 'Cerah',
  'settings.theme_dark': 'Gelap',
  'settings.about': 'Perihal',
  'settings.about_body':
      'Dosyalarım • versi {version}\n'
          'Pembaca/editor fail pelbagai format yang pantas dan ringkas.',
  'settings.privacy_policy': 'Dasar privasi',
  'settings.privacy_policy_sub':
      'Apa yang kekal pada peranti dan bila sesuatu keluar',
  'settings.crash_log': 'Laporan ranap',
  'settings.crash_log_sub':
      'Disimpan pada peranti, tidak pernah dihantar secara automatik',
  'settings.crash_log_count': '{n} laporan',
  'settings.crash_log_empty':
      'Tiada laporan — aplikasi belum pernah gagal pada peranti ini.',
  'settings.crash_log_note':
      'Teks ini kekal pada peranti anda sahaja. Ia dipaparkan sepenuhnya supaya '
          'anda nampak apa yang akan dihantar; mesej ralat mungkin mengandungi '
          'nama fail.',
  'settings.crash_log_cleared': 'Laporan ranap dipadam',
  'settings.oss': 'Komponen sumber terbuka',
  'settings.oss_sub': 'Lesen Media3, Syncfusion dan lain-lain',
  'set.suggested': 'Dicadangkan',
  'set.no_match': 'Tiada tetapan yang sepadan',
  'set.search_all': 'Cari semua tetapan',
  'set.results_count': '{n} hasil',

  // ── Mesej ralat ──
  'uerr.permission': 'Tiada kebenaran — akses ke folder ini belum diberikan.',
  'uerr.no_space': 'Storan penuh — ruang kosong tidak mencukupi.',
  'uerr.not_found': 'Fail tidak ditemui — mungkin telah dialih atau dipadam.',
  'uerr.read_only': 'Storan ini baca sahaja — tidak boleh ditulis.',
  'uerr.exists': 'Fail dengan nama yang sama sudah wujud.',
  'uerr.offline': 'Tiada sambungan — semak internet atau rangkaian anda.',
  'uerr.pdf_damaged': 'PDF tidak dapat dibaca — fail mungkin rosak.',
  'uerr.pdf_locked':
      'PDF dilindungi kata laluan — masukkan kata laluan dahulu.',
  'uerr.ai_key':
      'Kunci AI tidak sah atau tidak dibenarkan — semak Tetapan > Kecerdasan buatan.',
  'uerr.ai_quota': 'Kuota harian telah habis — cuba lagi sebentar nanti.',
  'uerr.cancelled': 'Operasi telah dibatalkan.',
  'uerr.unknown':
      'Berlaku ralat yang tidak dijangka. Butirannya disimpan dalam log ralat.',
  'uerr.details': 'Butiran',
  'uerr.retry': 'Cuba lagi',
  'uerr.notif_off':
      'Pemberitahuan dimatikan: kemajuan hanya dipaparkan dalam aplikasi. Paparkan juga dalam pemberitahuan?',

  // ── Pengenalan ──
  'onb.reader_title': 'Baca apa-apa fail, dengan pantas',
  'onb.reader_body':
      'Membuka PDF, Word, Excel, slaid, foto, video dan arkib tanpa internet. '
          'Menyemak imbas, mencari dan mengemas fail pada telefon anda.',
  'onb.editor_title': 'Edit, tukar, kongsi',
  'onb.editor_body':
      'Edit dokumen, hamparan dan persembahan pada telefon; buat asal/buat '
          'semula berfungsi sama dalam setiap editor dan draf disimpan secara '
          'automatik. Eksport ke PDF dan format lain dari satu helaian.',
  'onb.scan_title': 'Imbas kertas',
  'onb.scan_body':
      'Imbas dokumen dengan kamera: tepi dikesan dan diluruskan, teks dikenal '
          'pasti dan disimpan sebagai PDF yang boleh dicari.',
  'onb.samples': 'Tambah dokumen contoh',
  'onb.samples_done': 'Ditambah: folder {folder}',
  'onb.samples_failed': 'Tidak dapat menulis dokumen contoh',
  'onb.choice_open': 'Buka fail',
  'onb.choice_open_sub':
      'Tiada kebenaran diperlukan: pilih fail dalam pemilih Android dan ia terus dibuka.',
  'onb.choice_manage': 'Urus semua fail pada telefon saya',
  'onb.choice_manage_sub':
      'Semak imbas folder, kosongkan ruang dan susun fail — tanpa iklan, tanpa penjejakan.',
  'onb.skip': 'Langkau',

  // ── Menu sisi ──
  'side.title': 'Menu',
  'side.open': 'Buka menu',
  'side.home': 'Laman utama',
  'side.edit': 'Edit menu',
  'side.show_recents': 'Tunjukkan sejarah',
  'side.show_handle': 'Pemegang tepi',
  'side.show_handle_sub':
      'Bar nipis di kiri setiap skrin; ketik untuk membuka menu',
  'side.handle_right': 'Pemegang di kanan',
  'side.handle_right_sub': 'Menu dibuka dari tepi kanan',
  'side.reorder_hint': 'Tekan lama baris dan seret untuk menyusun semula',
  'side.reset': 'Tetap semula',

  // ── Papan pemuka & senarai ──
  'dash.sec_storage': 'Kad storan',
  'dash.sec_recent': 'Sejarah',
  'dash.sec_categories': 'Jubin kategori',
  'dash.sec_favorites': 'Kegemaran',
  'dash.title': 'Sesuaikan laman utama',
  'ui.smart_new': '+{n} baharu · {t} disusun',
  'ui.history': 'Sejarah',
  'ui.history_sub': 'Dibuka baru-baru ini',
  'ui.split_failed': 'Tidak dapat memisahkan: {error}',
  'ui.tool_nearby': 'Peranti berdekatan',
  'ui.tool_new_doc': 'Dokumen baharu',
  'ui.tool_ftp': 'Akses dari PC',
  'list.sort_folder_only': 'Folder ini sahaja',
  'list.filter_clear': 'Kosongkan penapis',
  'list.no_match': 'Tiada yang sepadan dengan penapis',
  'list.no_match_hint': 'Pilih jenis atau tarikh lain, atau kosongkan penapis.',
  'list.empty_hint': 'Ketik + untuk mencipta folder atau bawa fail ke sini.',
  'list.unreadable_hint':
      'Android mungkin menyembunyikan folder ini daripada aplikasi (cth. Android/data).',
  'create.doc': 'Dokumen baharu',
  'create.scan': 'Imbas ke folder ini',
  'create.import': 'Import ke folder ini',
  'create.paste_n': 'Tampal ({n})',
  'create.imported': '{n} fail diimport',
  'inbox.open': 'Buka',
  'inbox.storage_full': 'Storan {n}% penuh',
  'inbox.trash_full': '{n} item dalam tong sampah',
  'inbox.trash_hint': 'Menggunakan ruang — semak dan kosongkan',
  'lib.title': 'Pustaka',
  'lib.count': '{n} buku',
  'lib.added': '{n} buku ditambah',
  'lib.removed': 'Dibuang dari pustaka',
  'lib.tile_empty': 'Tambah buku',

  // ── Pengurus fail ──
  'fm.photos': 'Foto',
  'fm.media_all': 'Foto & video',
  'fm.all_files': 'Semua fail',
  'fm.quick_folders': 'Folder pantas',
  'fm.tools': 'Alatan',
  'fm.all_tools': 'Semua ({n})',
  'fm.jobs': 'Tugasan',
  'fm.jobs_running': '{n} sedang berjalan',
  'fm.jobs_finished': '{n} selesai',
  'fm.downloads': 'Muat turun',
  'fm.downloads_missing': 'Folder Muat turun tidak ditemui.',
  'fm.hero_percent': '{n}%',
  'fm.hero_used': '{used} daripada {total} digunakan',
  'fm.hero_browse': 'Semak imbas',
  'fm.hero_analysis': 'Analisis',
  'fm.free_space': 'Kosongkan ruang',
  'fm.apk_files': 'Fail APK',
  'fm.apk_archives': 'APK & arkib',
  'fm.scanning': 'Mengimbas…',
  'fm.scanning_storage': 'Mengimbas storan…',
  'fm.new_folder': 'Folder baharu',
  'fm.folder_name': 'Nama folder',
  'fm.create': 'Cipta',
  'fm.folder_create_failed': 'Tidak dapat mencipta folder: {error}',
  'fm.permission_title': 'Tunjukkan semua fail anda di sini?',
  'fm.permission_body':
      'Untuk menyemak imbas folder, mengosongkan ruang dan mengalihkan fail, '
          'Android meminta “akses semua fail”. Fail anda tidak pernah keluar '
          'dari telefon; aplikasi ini tiada iklan atau penjejakan. Anda juga '
          'boleh menambah folder pilihan sahaja.',
  'fm.permission_grant': 'Beri kebenaran',
  'fm.none': 'Tiada',
  'fm.other': 'Lain-lain',
  'fm.empty_folder': 'Folder ini kosong',
  'fm.search_here': 'Cari dalam folder ini',
  'fm.locked_folder': 'Folder berkunci',
  'fm.locked_prompt': 'Folder ini berkunci.\nMasukkan PIN untuk melihatnya.',
  'fm.lock_folder': 'Kunci folder (PIN)',
  'fm.unfavorite': 'Buang daripada kegemaran',
  'fm.favorite': 'Tambah ke kegemaran',
  'fm.show_hidden': 'Tunjukkan fail tersembunyi',
  'fm.layout': 'Susun atur: {name}',
  'fm.select_all': 'Pilih semua',
  'fm.selected_count': '{n} / {total} dipilih',
  'fm.new_name': 'Nama baharu',
  'fm.irreversible': 'Tindakan ini tidak boleh dibuat asal.',
  'fm.new_folder_or_file': 'Folder / fail baharu',
  'fm.new_text_file': 'Fail teks (.txt)',
  'fm.file_name': 'Nama fail',
  'fm.file_create_failed': 'Tidak dapat mencipta fail: {error}',
  'fm.auto_organize': 'Susun automatik…',
  'fm.copying': 'Menyalin',
  'fm.moving': 'Mengalihkan',
  'fm.transfer_partial': 'Sesetengah item tidak dapat dipindahkan: {error}',
  'fm.transfer_cancelled':
      'Operasi dibatalkan (item yang sudah dipindahkan kekal di tempatnya).',
  'fm.ext_changed_title': 'Sambungan fail berubah',
  'fm.ext_changed_body':
      '"{old}" → "{new}". Sambungan menentukan jenis fail; menukarnya mungkin '
          'membuka fail dalam aplikasi yang salah, atau tidak dibuka langsung.',
  'fm.ext_changed_keep': 'Kekalkan sambungan',
  'fm.ext_changed_go': 'Tukar juga',
  'fm.compare_running': 'Membandingkan',
  'fm.compare_same': 'Fail adalah SAMA (SHA-256 sepadan)',
  'fm.compare_diff': 'Fail adalah BERBEZA',
  'fm.empty_folders': 'Bersihkan folder kosong',
  'fm.empty_scanning': 'Mencari folder kosong…',
  'fm.empty_none': 'Tiada folder kosong.',
  'fm.empty_found': '{n} folder kosong ditemui. Padamkan?',
  'fm.empty_deleted': '{n} folder kosong dipadam',
  'fm.export_list': 'Eksport senarai',
  'fm.export_text': 'Teks (.txt)',
  'fm.export_csv': 'Hamparan (.csv)',
  'fm.export_done': '{name} disimpan',
  'fm.copy': 'Salin',
  'fm.clip_copy': 'Salin ke papan keratan',
  'fm.clip_cut': 'Potong ke papan keratan',
  'fm.move': 'Alih',
  'fm.rename': 'Namakan semula',
  'fm.copy_to_important': 'Tandakan penting',
  'fm.copy_to_shared': 'Salin ke Dikongsi',
  'fm.properties': 'Sifat',
  'fm.add_folder': 'Tambah folder',
  'fm.open_one': 'Buka satu fail sahaja',
  'fm.open_with_other': 'Buka dengan aplikasi lain',
  'fm.extract_here': 'Ekstrak di sini',
  'fm.show_archive': 'Tunjukkan kandungan arkib',
  'fm.reveal': 'Tunjukkan lokasi',
  'fm.type': 'Jenis',
  'fm.folder': 'Folder',
  'fm.modified': 'Diubah suai',
  'fm.last_opened': 'Terakhir dibuka',
  'fm.not_computed': 'Belum dikira',
  'fm.computing': 'Mengira…',
  'fm.items_count': '{n} item',
  'fm.delete_permanent_title': 'Padam secara kekal?',
  'fm.delete_trash_title': 'Alih ke tong sampah?',
  'fm.delete_permanent_body':
      '{label} akan dipadam secara KEKAL. Tindakan ini tidak boleh dibuat asal. '
          '(Tong sampah dimatikan dalam tetapan.)',
  'fm.delete_trash_body':
      '{label} akan dialih ke tong sampah. Anda boleh memulihkannya dari Tong Kitar Semula.',
  'fm.delete_permanent_action': 'Padam {what} secara kekal',
  'fm.delete_trash_action': 'Alih {what} ke tong sampah',
  'fm.renamed': 'Dinamakan semula kepada {name}',
  'fm.trashed_n': '{n} item dialih ke tong sampah',
  'fm.undo': 'Dibuat asal.',
  'fm.undo_action': 'Buat asal',
  'fm.deleting': 'Memadam',
  'fm.undo_failed': 'Tidak dapat buat asal: {error}',
  'fm.deleted_n': '{n} item dipadam secara kekal',
  'fm.deleted_partial': '{ok} item dipadam, {fail} tidak dapat dipadam.',
  'fm.trashed_partial':
      '{ok} item dialih ke tong sampah, {fail} tidak dapat dialih: {error}',
  'fm.verb_moved': 'dialihkan',
  'fm.verb_copied': 'disalin',
  'fm.transfer_done': '{n} item telah {verb} ke “{where}”.',
  'fm.transfer_stopped':
      'Dihentikan · {n} item sudah {verb} ke “{where}” '
          '(pemindahan yang sedang berjalan tidak boleh diputuskan).',
  'fm.transfer_errors':
      '{n} item {verb}, {fail} tidak dapat dipindahkan: {error}',
  'fm.important_copied': '{n} item disalin ke “{folder}”.',
  'fm.copy_failed': 'Tidak dapat menyalin: {error}',
  'fm.rename_failed': 'Tidak dapat menamakan semula: {error}',
  'fm.zip_failed': 'Tidak dapat memampatkan: {error}',
  'fm.extract_failed': 'Tidak dapat mengekstrak: {error}',
  'fm.zipping': 'Memampatkan',
  'fm.encrypting': 'Menyulitkan (AES-256)',
  'fm.extracting': 'Mengekstrak',
  'fm.trashing': 'Mengalih ke tong sampah',
  'fm.copying_important': 'Menyalin ke fail penting',
  'fm.copying_shared': 'Menyalin ke folder Dikongsi',
  'fm.extracted_to': 'Diekstrak ke “{name}”.',
  'fm.created_archive': '“{name}” dicipta.',
  'fm.entry_clip_copied':
      '“{name}” disalin ke papan keratan. Ketik “Tampal” dalam folder destinasi.',
  'fm.entry_clip_cut':
      '“{name}” dipotong ke papan keratan. Ketik “Tampal” dalam folder destinasi.',
  'fm.drive_subtitle': 'Fail dalam awan',
  'fm.memory_analysis': 'Analisis storan',
  'fm.new_files': 'Baharu',
  'fm.new_files_note': 'Ketibaan terkini',
  'fm.last_scan': 'Imbasan terakhir: {date} · {n} fail',
  'fm.new_word_doc': 'Dokumen Word (.docx)',
  'fm.search_help': 'Cari & Bantuan',
  'fm.apps': 'Aplikasi',
  'fm.calc_size': 'Kira saiz',
  'fm.copy_path': 'Salin laluan',
  'fm.new_xlsx': 'Hamparan Excel (.xlsx)',
  'fm.external_storage': 'Pemacu luaran',
  'fm.external_count': '{n} pemacu',
  'fm.external_none_short': 'Tidak disambung',
  'fm.external_unusable_short':
      '{name} disambung tetapi Android tidak memberikan laluan fail.',
  'fm.external_unusable_title': 'Tidak dapat membuka {name}',
  'fm.external_unusable':
      '{name} disambung tetapi Android tidak memaparkannya sebagai laluan fail. '
          'Ketik "Pilih folder" dan pilih pemacu untuk akses kekal; jika tiada '
          'dalam pemilih, pilih "Pemindahan fail" dalam pemberitahuan USB.',
  'fm.external_usb_count': '{n} USB',
  'fm.external_card_count': '{n} kad SD',
  'fm.copy_to_external': 'Salin ke pemacu luaran',
  'fm.external_pick_hint': 'USB / kad SD',
  'fm.external_none':
      'Tiada pemacu luaran disambung. Pasang pemacu USB atau kad SD dan cuba lagi.',
  'fm.copying_external': 'Menyalin ke {volume}…',
  'fm.external_copied': '{n} item disalin ke {volume} (folder Dosya Okuyucu).',
  'fm.usb_attached': '{volume} disambung — ketik untuk membuka.',
  'fm.usb_detached': 'Pemacu luaran dikeluarkan.',
  'fm.usb_open': 'Buka',
  'fm.used': 'Digunakan',
  'fm.extracting_name': 'Pengekstrakan',
  'fm.deleting_name': 'Pemadaman',
  'fm.trashing_name': 'Mengalih ke tong sampah',
  'fm.copying_important_name': 'Salin ke fail penting',
  'fm.copying_shared_name': 'Salin ke Dikongsi',
  'fm.copying_name': 'Salin',
  'fm.copying_external_name': 'Salin ke {volume}',
  'fm.zipping_name': 'Pemampatan',
  'fm.free_bytes': '{v} kosong',

  // ── Sifat & tindakan fail ──
  'prop.contents': 'Kandungan',
  'prop.contents_value': '{files} fail, {dirs} folder',
  'prop.encoding': 'Pengekodan',
  'prop.size': 'Saiz',
  'prop.location': 'Lokasi',
  'prop.digest': 'Hasil tambah semak (SHA-256)',
  'prop.compute_digest': 'Kira hasil tambah semak',
  'prop.computing_digest': 'Mengira…',
  'prop.digest_copied': 'Hasil tambah semak disalin',
  'prop.photo_info': 'Butiran foto',
  'prop.taken_at': 'Diambil',
  'prop.camera': 'Kamera',
  'prop.lens': 'Kanta',
  'prop.resolution': 'Resolusi',
  'prop.iso': 'ISO',
  'prop.exposure': 'Dedahan',
  'prop.aperture': 'Bukaan',
  'prop.focal': 'Panjang fokus',
  'prop.flash': 'Denyar',
  'prop.flash_on': 'Menyala',
  'prop.flash_off': 'Tidak menyala',
  'prop.software': 'Perisian',
  'prop.copy_name': 'Salin nama',
  'ea.rotate': 'Putar',
  'ea.rotate_hint': '90° ke kanan · fail baharu',
  'ea.split': 'Pisahkan kepada bahagian',
  'ea.split_hint': 'Had FAT32 / e-mel',
  'ea.join': 'Cantumkan bahagian',
  'ea.join_hint': '.001 .002 …',
  'ea.sec_open': 'Buka & kongsi',
  'ea.sec_name': 'Nama kedua & kategori',
  'ea.sec_move': 'Papan keratan & tempat lain',
  'ea.sec_file': 'Tindakan fail',
  'ea.sec_this': 'Fail ini',
  'ea.compress': 'Mampatkan',
  'ea.compress_hint': 'ZIP · 7z · kata laluan',
  'ea.resize': 'Kecilkan saiz',
  'ea.resize_hint': 'resolusi / kadar bingkai',
  'ea.tag': 'Tag',
  'ea.tag_hint': 'orang / kumpulan',
  'ea.clip_hint': 'untuk ditampal kemudian',
  'ea.shared_hint': 'dikongsi melalui rangkaian',
  'ea.quick_share': 'Hantar berdekatan',
  'ea.shortcut': 'Tambah ke skrin utama',
  'ea.shortcut_hint': 'pintasan pada skrin utama telefon anda',
  'ea.shortcut_unsupported':
      'Pelancar telefon ini tidak menyokong penambahan pintasan.',
  'ea.shortcut_requested':
      'Pintasan untuk “{name}” diminta — sahkan dalam gesaan skrin utama.',
  'ea.shortcut_failed': 'Tidak dapat menambah pintasan.',
  'ea.shortcut_missing':
      'Item yang dituju pintasan ini tidak ditemui (mungkin telah dialih atau dipadam).',
  'ea.hide': 'Sembunyikan',
  'split.pick_size': 'Saiz bahagian',
  'split.working': 'Memisahkan',
  'split.done': '{n} bahagian dicipta',
  'split.cancelled': 'Pemisahan dihentikan',
  'split.too_small':
      'Fail lebih kecil daripada saiz bahagian — tidak perlu dipisahkan.',
  'join.working': 'Mencantumkan',
  'join.done': '{name} dicipta',
  'join.failed': 'Tidak dapat mencantumkan: {error}',
  'join.name': 'Pencantuman',
  'important.delete_title': 'Memadam fail penting',
  'important.delete_mixed': 'Pilihan mengandungi {n} item penting: {names}',
  'important.delete_anyway': 'Padam juga',
  'important.keep_delete_rest': 'Simpan yang penting, padam {n} yang lain',
  'important.delete_all_too': 'Padam kesemua {n} item, termasuk yang penting',
  'important.pick_category': 'Kategori mana?',
  'important.general': 'Umum (tiada kategori)',
  'important.new_category': 'Kategori baharu',
  'qf.make_shortcut': 'Cipta pintasan',
  'qf.make_shortcut_hint': 'Kad saya atau folder pantas',
  'qf.card_hint': 'sebagai kad pada laman utama',
  'qf.quick_remove': 'Buang daripada folder pantas',
  'qf.quick_hint': 'dengan ikon folder di bawah laman utama',
  'qf.card_added': '"{name}" ditambah ke Kad saya',
  'qf.card_removed': '"{name}" dibuang daripada Kad saya',
  'qf.quick_added': '"{name}" ditambah ke folder pantas',
  'qf.quick_removed': '"{name}" dibuang daripada folder pantas',
  'qf.add': 'Tambah',
  'qf.add_here': 'Tambah ke folder pantas',
  'qf.empty': 'Tiada folder pantas — ketik "Tambah"',

  // ── Pemacu luaran ──
  'saf.title': 'Akses pemacu dengan kebenaran folder',
  'saf.body':
      'Pada peranti ini Android tidak memaparkan pemacu yang disambung sebagai '
          'laluan fail, jadi ia tidak muncul dalam senarai. Jika anda memilih '
          'pemacu (atau folder di dalamnya) daripada pemilih folder Android, '
          'aplikasi mendapat akses kekal: menyemak imbas, membuka, menyalin, '
          'memadam dan menamakan semula semuanya berfungsi.\n\n'
          'Jika pemacu juga tiada dalam pemilih, Android belum melekapkannya — '
          'semak pemberitahuan USB.',
  'saf.pick': 'Pilih folder',
  'saf.granted': 'Melalui kebenaran folder',
  'usb.eject_mounted_hint':
      'Aplikasi tidak dapat menyahlekap pemacu yang dilekap oleh Android (tiada '
          'API awam). Guna butang "Keluarkan" dalam pemberitahuan USB/SD; untuk '
          'pemacu yang dikendalikan aplikasi, guna "Tanggalkan dengan selamat" '
          'dalam menu ⋮.',
  'usb.eject': 'Tanggalkan dengan selamat',
  'usb.diag_title': 'Diagnostik USB',
  'usb.open_raw': 'Buka pemacu secara terus',
  'usb.multi_volume': 'Pemacu ini mempunyai {n} volum; yang pertama dibuka.',
  'usb.pick_volume': 'Pilih volum',
  'usb.open_raw_failed':
      'Tidak dapat membuka pemacu secara terus: kebenaran ditolak atau format '
          'tidak dikenali (FAT, exFAT, NTFS dan ext2/3/4 disokong).',

  // ── Pemapar (PDF, dokumen, teks) ──
  'pdfm.resume': 'Buka semula di tempat terakhir',
  'legacy.done': 'Salinan dicipta: {name}',
  'code.tab_width': 'Lebar inden',
  'md.edit': 'Edit',
  'md.preview': 'Pratonton',
  'shell.pages': '{n} halaman',
  'dm.page': 'Halaman',
  'dm.text': 'Teks',
  'dm.convert': 'Tukar & cetak',
  'dm.listen': 'Dengar',
  'dm.image': 'Imej',
  'vw.reading_settings': 'Tetapan bacaan',
  'vw.text_size': 'Saiz teks',
  'vw.font_default': 'Lalai',
  'vw.layout': 'Susun atur',
  'vw.speak_part': 'Bahagian {n} daripada {total}',
  'find.none': 'Tiada hasil',
  'vw.prettify_done': 'Diformat',
  'vw.prettify_failed':
      'Fail ini tidak dapat dihuraikan — teks dibiarkan seperti asal',
  'vw.wrap_on': 'Balut baris',
  'vw.replace_with': 'Ganti dengan',
  'vw.replace_one': 'Ganti',
  'vw.replace_all': 'Ganti semua',
  'vw.replaced': '{n} penggantian dibuat',
  'vw.replace_none': 'Tiada apa untuk diganti',
  'vw.show_replace': 'Tunjuk/sembunyi ganti',
  'vw.goto_line': 'Pergi ke baris',
  'vw.line_number': 'Nombor baris (1-{max})',
  'vw.line_numbers': 'Nombor baris',
  'vw.line_ending': 'Penghujung baris',
  'code.line_spacing': 'Jarak baris',
  'pp.book_view': 'Buku',
  'pp.sepia': 'Warna kertas (sepia)',
  'pp.sepia_hint': 'Melembutkan putih; dimatikan semasa mod malam',
  'pp.scroll_lock': 'Kunci tatal',
  'pp.scroll_lock_hint': 'Tatal menegak sahaja, zum dimatikan',
  'pp.notes_booklet': 'Buku sorotan dan nota',
  'pp.notes_booklet_sub': 'Kongsi semua tanda dalam satu senarai (Markdown)',
  'pp.find_list': 'Senarai hasil',
  'pp.image_zoom': 'Besarkan imej',
  'pp.image_zoom_hint': 'Skrin penuh berlatar hitam; tarik ke bawah untuk menutup',
  'pp.crop_margins': 'Pangkas jidar',
  'pp.paged': 'Halaman demi halaman',
  'pp.hide_status': 'Sembunyikan juga bar status semasa membaca',
  'pp.hide_status_hint':
      'Jam dan bateri hilang semasa menatal; satu ketikan memaparkannya semula',
  'pp.crop_none': 'Tiada jidar untuk dipangkas',
  'vn.prompt': 'Bercakap — nota masuk ke Nota',
  'wp.dictate_unavailable': 'Tiada pengecam pertuturan pada peranti ini',
  'vw.fullscreen': 'Skrin penuh',
  'pp.keep_awake': 'Kekalkan skrin menyala',
  'pp.keep_awake_hint': 'Skrin tidak malap semasa anda membaca',
  'pp.volume_keys': 'Selak halaman dengan butang kelantangan',
  'pp.volume_keys_hint': 'Turun: halaman seterusnya · Naik: sebelumnya',
  'pp.auto_scroll': 'Tatal automatik',
  'pp.auto_scroll_hint': 'Berhenti semasa anda menyentuh skrin',
  'pp.as_off': 'Mati',
  'pp.as_slow': 'Perlahan',
  'pp.as_mid': 'Sederhana',
  'pp.as_fast': 'Pantas',
  'vw.fullscreen_hint': 'Menyembunyikan bar status dan navigasi',
  'vw.rotate': 'Putar',
  'vw.text_bigger': 'Teks lebih besar',
  'vw.text_smaller': 'Teks lebih kecil',
  'vw.one_column': 'Satu lajur',
  'vw.two_columns': '2 lajur',
  'vw.four_columns': '4 lajur',
  'vw.night_on': 'Mod malam',
  'vw.image_to_pdf': 'Imej ke PDF',
  'vw.image_to_pdf_body':
      'Imej akan dibenamkan dalam PDF pada resolusi penuh, tanpa dipangkas.\n\n',
  'vw.still_loading': 'Dokumen masih dimuatkan…',
  'vw.page_jump_failed_total':
      'Tidak dapat melompat ke halaman {target}; kekal di halaman {landed} (daripada {total}).',
  'vw.goto_page_short': 'pergi ke halaman',
  'vw.find_in_doc': 'Cari dalam dokumen…',
  'vw.find_in_doc_short': 'Cari dalam dokumen',
  'vw.image_only': 'Imej sahaja',
  'vw.doc_info': 'Maklumat dokumen',
  'vw.speak': 'Baca dengan kuat',
  'vw.toc': 'Kandungan',
  'vw.side_panel': 'Lakaran kecil halaman',
  'vw.fill_form': 'Isi borang',
  'vw.to_pdf': 'Tukar ke PDF',
  'vw.ocr_short': 'Kenal pasti teks',
  'vw.ocr_running': 'Mengenal pasti teks…',
  'vw.image_pdf_job_name': 'Imej ke PDF',
  'vw.ocr_text': 'Teks yang dikenal pasti',
  'vw.ocr_selected_n': '{n} aksara dipilih',
  'vw.ocr_overlay_hint': 'Tekan lama untuk memilih teks',
  'vw.ocr_show_list': 'Tunjukkan teks secara berasingan',
  'vw.ocr_overlay_close': 'Sembunyikan lapisan teks',
  'vw.ocr_overlay_open': 'Pilih teks pada imej',
  'vw.ocr_in_pdf':
      'Adakah teks di dalamnya juga perlu boleh dicari/disalin dalam PDF? '
          '(Pengecaman teks mengambil beberapa saat dan tidak mengubah imej.)',
  'vw.ocr_also': 'Kenal pasti teks juga',
  'vw.scanning_text': 'Mengimbas teks…',
  'vw.copy_all': 'Salin semua',
  'vw.copied_all': 'Semua disalin',
  'vw.copied_chars': 'Disalin ({n} aksara)',
  'vw.no_text_to_translate': 'Tiada teks untuk diterjemah.',
  'vw.highlighted': 'Disorot',
  'vw.highlight_remove': 'Buang sorotan',
  'vw.highlight_removed': '{n} sorotan dibuang.',
  'vw.highlight_none_here': 'Tiada sorotan di tempat yang anda pilih.',
  'vw.highlight_hint': 'Sorot',
  'vw.highlight_failed': 'Gagal menyorot: {error}',
  'vw.word': 'Perkataan',
  'vw.line': 'Baris',
  'vw.chars': 'Aksara',
  'vw.chars_nospace': 'Aksara (tanpa ruang)',
  'vw.paragraph': 'Perenggan',
  'vw.doc_content': 'Kandungan dokumen…',
  'vw.pdf_preparing': 'Menyediakan PDF…',
  'vw.pdf_loading': 'PDF masih dimuatkan; cuba lagi sebentar.',
  'vw.pdf_exported': 'Dieksport sebagai PDF',
  'vw.pdf_failed': 'Tidak dapat mencipta PDF: {error}',
  'vw.image_failed': 'Imej tidak dapat dipaparkan.',
  'vw.table_empty': 'Jadual kosong atau tidak boleh dibaca.',
  'vw.no_viewer':
      'Tiada pemapar terbina dalam untuk jenis fail ini.\nAnda boleh membukanya dengan aplikasi lain.',
  'vw.link_title': 'Buka pautan',
  'vw.link_body':
      'Dokumen ini mahu membawa anda ke:\n\n{url}\n\n'
          'Berhati-hati dengan alamat yang anda tidak kenali.',
  'vw.link_failed': 'Tidak dapat membuka pautan',
  'vw.link_failed_e': 'Tidak dapat membuka pautan: {error}',
  'vw.save_edits': 'Simpan suntingan',
  'vw.edits_applied': 'Suntingan anda telah digunakan pada dokumen ini.',
  'vw.searching': 'mencari…',
  'vw.no_readable_text':
      'Tiada teks yang boleh dibaca. Pada dokumen imbasan, jalankan “Kenal pasti teks (OCR)” dahulu.',
  'vw.sel_count': '{chars} aksara · {words} perkataan',
  'vw.sel_expand': 'Tunjukkan keseluruhan pilihan',
  'vw.sel_collapse': 'Kecilkan pratonton',
  'word.font_family': 'Fon',
  'ps.act_edited': 'Disunting',
  'tts.voice_settings': 'Tetapan suara',
  'pt.locked_title': 'Dokumen ini mempunyai kata laluan',
  'pt.enter_password': 'Masukkan kata laluan',
  'pdf.sec_look': 'Rupa & susun atur',
  'pdf.sec_comfort': 'Keselesaan membaca',
  'pdf.sec_screen': 'Skrin & sesi',
  'reader.open': 'Paparan bacaan',
  'tf.page_reading': 'Membaca halaman {n} / {total}…',
  'tf.page_ocr': 'Mengimbas halaman {n} / {total} (pengecaman teks)…',
  'tf.mode_title': 'Bagaimana hasil terjemahan dipaparkan?',
  'tf.mode_inplace': 'Dokumen itu sendiri (susun atur sama)',
  'tf.mode_inplace_hint':
      'Fon, saiz dan susun atur halaman kekal; hanya perkataan berubah. '
          'Hasilnya disimpan sebagai PDF baharu.',
  'tf.mode_text': 'Sebagai teks biasa (untuk dibaca atau disalin)',
  'tf.mode_text_hint':
      'Halaman imbasan turut disertakan (melalui OCR), tetapi hasilnya teks biasa.',
  'vw.saving_wait': 'Menyimpan, sebentar…',
  'vw.find_selection': 'Cari dalam dokumen',
  'vw.highlight_color': 'Warna sorotan',
  'vw.pdf_error_title': 'PDF ini tidak dapat dibuka',
  'vw.pdf_error_empty':
      'Fail kosong (0 bait). Kemungkinan muat turun atau simpanan terganggu.',
  'vw.pdf_error_broken':
      'Fail mungkin rosak atau tidak dimuat turun sepenuhnya.',
  'vw.pdf_error_restore': 'Pulihkan asal',
  'uix.no_text': 'Tiada apa untuk dibaca',
  // ── Kitaplık, temizlik, Pro, PDF araçları (m.3) ──
  'lib.add':
      'Tambah buku',
  'lib.already':
      'Sudah ada dalam perpustakaan anda',
  'lib.remove':
      'Alih keluar daripada perpustakaan',
  'lib.missing':
      'Fail tidak ditemui (dialih atau dipadam)',
  'lib.search':
      'Cari dalam perpustakaan',
  'lib.continue':
      'Sambung membaca',
  'lib.shelf':
      'Rak',
  'lib.no_match':
      'Tiada buku yang sepadan',
  'lib.pin_home':
      'Tambah ke skrin utama',
  'lib.empty_title':
      'Perpustakaan anda kosong',
  'lib.find':
      'Cari buku dalam telefon ini',
  'lib.find_none':
      'Tiada buku baharu ditemui',
  'lib.find_title':
      '{n} buku ditemui',
  'lib.add_selected':
      'Tambah yang dipilih ({n})',
  'lib.stats':
      '{r} sedang dibaca · {d} selesai · {u} belum dimulakan',
  'lib.show_folder':
      'Tunjukkan dalam folder',
  'lib.share':
      'Kongsi',
  'lib.clean_missing':
      'Alih keluar yang hilang ({n})',
  'lib.page_of':
      '{p}% dibaca',
  'lib.audiobooks_sub':
      'Dengar buku audio daripada dokumen anda',
  'clean.shrink_this':
      'Kecilkan saiz',
  'clean.shrink_this_est':
      'Kecilkan saiz · ≈ {to}',
  'clean.dup_groups':
      'Semak mengikut kumpulan',
  'clean.deep_title':
      'CARI LEBIH BANYAK RUANG',
  'clean.deep_note':
      'Imbasan ini memeriksa kandungan fail; mungkin mengambil beberapa minit dan berjalan di latar belakang.',
  'clean.deep_running':
      'Mengimbas…',
  'clean.deep_found':
      '{n} fail · {size} boleh dibebaskan',
  'clean.deep_none':
      'Siap diimbas · tiada apa untuk dibersihkan',
  'clean.deep_similar':
      'Foto serupa',
  'clean.deep_content':
      'Imbasan kandungan imej',
  'clean.deep_content_note':
      'Gambar ucapan, meme, poster, serta foto kabur dan gelap',
  'clean.confirm_title':
      'Bersihkan?',
  'clean.title':
      'Bebaskan ruang',
  'clean.analyzing':
      'Bebaskan ruang: menganalisis storan',
  'clean.analyzing_name':
      'Bebaskan ruang: analisis storan',
  'clean.reading_index':
      'Membaca storan…',
  'clean.nothing':
      'Tiada apa yang jelas perlu dibersihkan',
  'clean.nothing_body':
      'Tiada apa yang jelas perlu dibersihkan 🎉\nStoran anda nampak kemas.',
  'clean.recoverable':
      '{size} boleh dibebaskan',
  'clean.suggestions':
      '{n} cadangan',
  'clean.pick_one':
      'Pilih satu cadangan',
  'clean.personal_warning':
      'Berhati-hati: ini mungkin fail peribadi',
  'clean.cleaning':
      'Bebaskan ruang: membersihkan {size}',
  'clean.cleaning_name':
      'Bebaskan ruang: pembersihan {size}',
  'clean.cleaned_detail':
      '{size} dibebaskan · {n} cadangan digunakan',
  'clean.reanalyze':
      'Analisis semula',
  'clean.open_trash':
      'Buka tong sampah',
  'clean.show_hidden':
      'Pulihkan {n} cadangan tersembunyi',
  'clean.dupes_note':
      'Imbasan pendua membandingkan fail bait demi bait; mungkin mengambil sedikit masa.',
  'clean.badge_safe':
      'Selamat',
  'clean.badge_review':
      'Semak',
  'clean.inspect_files':
      'Periksa {n} fail',
  'clean.hide_files':
      'Sembunyikan',
  'clean.show_all_more':
      'Tunjukkan semua (+{n})',
  'clean.summary_line':
      'Sehingga {total} boleh dibebaskan · Dipilih: {selected}',
  'clean.select_safe':
      'Pilih yang selamat',
  'clean.deselect_all':
      'Kosongkan pilihan',
  'clean.original_kept':
      'Asalnya kekal: {loc} · {size}',
  'clean.view_original':
      'Lihat asal',
  'clean.copy_will_go':
      'Dibuang: salinan ini sahaja',
  'clean.clean_this':
      'Bersihkan ini · {size}',
  'clean.clean_this_dirs':
      'Bersihkan {n} folder',
  'clean.confirm_copies':
      'Untuk salinan, hanya salinan dibuang; setiap fail asal kekal pada peranti.',
  'clean.empty_trash_now':
      'Kosongkan sekarang',
  'clean.done_failed':
      'Pembersihan tidak dapat diselesaikan',
  'clean.filter_all':
      'Semua',
  'clean.filter_safe':
      'Selamat',
  'clean.filter_review':
      'Semak',
  'clean.selected_partial':
      '{sel}/{total} dipilih',
  'clean.select_all_in':
      'Pilih semua',
  'clean.clear_in':
      'Tiada',
  'clean.free_items':
      'Bebaskan {size} · {n} item',
  'clean.empty_folders_only':
      'Bersihkan {n} folder kosong',
  'clean.chat_tool':
      'Pembersihan media sembang',
  'clean.chat_tool_sub':
      'Pelekat, GIF dan media lama WhatsApp & Telegram',
  'clean.disk_used_line':
      '{used} / {total} digunakan · Kosong: {free}',
  'clean.disk_after_line':
      'Ruang kosong selepas pembersihan: {before} → {after}',
  'clean.trust_no_personal':
      'Foto & dokumen tidak disentuh',
  'clean.trust_trash_undo':
      'Dialih ke tong sampah, boleh dipulihkan',
  'clean.trust_important':
      'Fail penting kekal dilindungi',
  'clean.trust_important_n':
      '{n} fail penting dilindungi',
  'clean.quick_clean_safe':
      'Bersihkan yang selamat · {size}',
  'clean.sec_safe_title':
      'Bersihkan dengan Selamat (Tanpa Risiko)',
  'clean.sec_safe_sub':
      'Hanya sampah, pendua tepat, cache dan sisa pemasang. Fail peribadi tidak disentuh.',
  'clean.sec_review_title':
      'Semak untuk Lebih Banyak Ruang (Keputusan Anda)',
  'clean.sec_review_sub':
      'Tiada apa dipilih terlebih dahulu. Periksa item atau kecilkan video besar tanpa memadamnya.',
  'clean.done_card_title':
      '{size} dibebaskan!',
  'clean.confirm_safe_only':
      'Foto, dokumen dan fail penting anda tidak akan disentuh.',
  'clean.shrink_without_delete':
      'Bebaskan ruang tanpa memadam',
  'clean.need_permission_title':
      'Akses folder diperlukan untuk mengimbas',
  'clean.need_permission_body':
      'Beri kebenaran untuk mencari sampah, pendua dan fail besar. Foto dan dokumen anda tidak pernah dipadam secara automatik.',
  'clean.need_permission_btn':
      'Beri kebenaran & imbas',
  'clean.confirm_lead':
      '{n} cadangan · {size} akan dibebaskan.\n\n',
  'clean.confirm_tail':
      'Fail dialihkan ke tong sampah; anda boleh memulihkannya dari sana.',
  'pro.title':
      'Versi Pro',
  'pro.row_sub':
      'Folder pintar, editor PDF, buku audio & pengecil video · Sekali bayar',
  'pro.one_time_badge':
      'Pembelian sekali · Tanpa iklan',
  'pro.price_one_time':
      '{p} · Sekali bayar',
  'pro.smart_limit_note':
      'Pro termasuk kuota permulaan 500 fail untuk Folder Pintar; analisis awan tambahan adalah pilihan melalui langganan atau kunci anda sendiri.',
  'pro.locked_title':
      '{f} ada dalam Pro',
  'pro.locked_sub':
      'Alat ini dibuka dalam versi Pro sekali bayar. Semua pengurusan fail dan bacaan asas kekal percuma dalam Lite.',
  'pro.feature_title':
      '{f} ada dalam versi Pro',
  'pro.lead':
      'Lite merangkumi bacaan percuma, pengurus fail, penyuntingan asas, pengisian borang dan tandatangan. Pro membuka:',
  'pro.later':
      'Bukan sekarang',
  'pro.trust':
      'Semua ciri teras dalam Lite kekal percuma dan bebas iklan selama-lamanya.',
  'pro.smart_locked_title':
      'Folder Pintar ada dalam Pro',
  'pro.smart_locked_sub':
      'Naik taraf ke Pro untuk menyusun fail anda ke dalam kategori pintar dan pertanyaan tersimpan.',
  'pro.saved_locked_title':
      'Folder Pintar Tersimpan ada dalam Pro',
  'pro.saved_locked_sub':
      'Naik taraf ke Pro untuk mencipta folder yang dikemas kini secara automatik daripada pertanyaan tersimpan anda.',
  'pro.f.pdfAdvanced':
      'Penyuntingan & alat PDF',
  'pt.page_numbers':
      'Tambah nombor halaman',
  'pt.pn_skip_first':
      'Langkau halaman muka depan',
  'pt.pn_skip_first_sub':
      'Halaman pertama tidak bernombor; penomboran bermula dari 2',
  'pt.pn_with_total':
      'Guna format "3 / 12"',
  'pt.pn_right':
      'Jajarkan ke kanan bawah',
  'pt.op_page_numbers':
      'Menambah nombor halaman',
  'pt.export_images':
      'Eksport halaman sebagai imej (PNG)',
  'pt.op_export_images':
      'Mencipta imej',
  'pt.export_images_count':
      '{n} imej halaman',
  'pt.export_images_limit':
      'Paling banyak {n} halaman sekali gus: pilih halaman dahulu.',
  'pt.export_images_failed':
      'Gagal mencipta imej halaman',
  'pt.watermark':
      'Tambah tera air',
  'pt.watermark_hint':
      'cth. DRAF, SALINAN',
  'pt.op_watermark':
      'Menambah tera air',
  'pt.move_to':
      'Alihkan halaman ke…',
  'pt.move_to_hint':
      'Nombor halaman sasaran (1-{n})',
  'pt.op_duplicate':
      'Gandakan halaman',
  'pt.op_insert_blank':
      'Sisipkan halaman kosong',
  'pt.op_reverse':
      'Terbalikkan susunan halaman',
  'pt.op_split':
      'Memisahkan',
  'pt.split_every':
      'Pisahkan kepada beberapa bahagian…',
  'pt.split_size':
      'Bahagian setiap {n} halaman',
  'pt.split_done':
      '{n} fail ditulis di sebelah dokumen.',
  'pt.split_too_short':
      'Pemisahan memerlukan sekurang-kurangnya dua halaman.',
  'pt.select_all':
      'Pilih semua',
  'pt.job_name':
      'Operasi PDF ({label})',
  'pt.op_failed':
      '{label} gagal: {error}',
  'pt.op_stopped':
      '{label} dihentikan',
  'pt.op_rotate':
      'Memutar',
  'pt.op_delete':
      'Memadam',
  'pt.op_move':
      'Mengalihkan',
  'pt.op_move_page':
      'Mengalihkan halaman',
  'pt.op_merge':
      'Menggabungkan',
  'pt.op_scan_append':
      'Menambah imbasan',
  'pt.op_compress':
      'Memampatkan',
  'pt.op_set_password':
      'Menetapkan kata laluan',
  'pt.op_remove_password':
      'Mengalih keluar kata laluan',
  'pt.cannot_delete_all':
      'Anda tidak boleh memadam semua halaman',
  'pt.annot_title':
      'Penyerlahan akan hilang',
  'pt.continue':
      'Teruskan',
  'pt.extracting':
      'Mengekstrak halaman…',
  'pt.extracted':
      'Halaman yang dipilih diekstrak sebagai PDF berasingan',
  'pt.extract_failed':
      'Pengekstrakan gagal: {error}',
  'pt.merged':
      '{n} PDF ditambah',
  'pt.compress_title':
      'Mampatkan dokumen',
  'pt.compress':
      'Mampat',
  'pt.size_change':
      'Saiz {before} → {after}',
  'pt.already_compact':
      'Dokumen ini sudah padat ({size}) — tiada apa yang boleh dijimatkan',
  'pt.set_password':
      'Tetapkan kata laluan',
  'pt.new_password':
      'Kata laluan baharu',
  'pt.remove_password':
      'Alih keluar kata laluan',
  'pt.unsaved_title':
      'Perubahan belum disimpan',
  'pt.unsaved_body':
      'Jika anda keluar, suntingan anda akan hilang.',
  'pt.stay':
      'Kekal di sini',
  'pt.leave':
      'Keluar',
  'pt.scan_append':
      'Imbas dan tambah halaman',
  'pt.merge_other':
      'Tambah PDF lain (gabung)',
  'pt.compress_menu':
      'Mampat (kecilkan saiz)',
  'pt.open_failed':
      'Tidak dapat dibuka: {error}',
  'pt.extract':
      'Ekstrak',
  'pt.forward':
      'Ke hadapan',
  'pt.backward':
      'Ke belakang',
  // ── PDF pro araçları pp (m.3) ──
  'pp.menu':
      'Alat Pro…',
  'pp.title':
      'Alat pro PDF',
  'pp.dsign':
      'Tandatangan digital (sijil)',
  'pp.dsign_source':
      'Sijil',
  'pp.dsign_self':
      'Identiti aplikasi (ditandatangani sendiri)',
  'pp.dsign_pfx':
      'Fail sijil (.pfx/.p12)',
  'pp.dsign_name':
      'Nama penandatangan',
  'pp.dsign_reason':
      'Sebab (pilihan)',
  'pp.dsign_location':
      'Lokasi (pilihan)',
  'pp.dsign_visible':
      'Kotak tandatangan kelihatan',
  'pp.dsign_last_page':
      'Letakkan di halaman terakhir',
  'pp.dsign_go':
      'Tandatangani',
  'pp.dsign_working':
      'Tandatangan digital',
  'pp.dsign_creating':
      'Mencipta kunci tandatangan',
  'pp.dsign_pfx_password':
      'Kata laluan sijil',
  'pp.dsign_done':
      'Sudah ditandatangani. Jangan ubah apa-apa sebelum menyimpan — itu akan membatalkan tandatangan.',
  'pp.dsign_list':
      'Tandatangan',
  'pp.dsign_none':
      'Dokumen tiada tandatangan',
  'pp.dsign_empty_field':
      'Medan tandatangan kosong',
  'pp.dsign_export_cert':
      'Kongsi sijil saya (.cer)',
  'pp.dsign_name_needed':
      'Nama penandatangan diperlukan',
  'pp.region_title':
      'Pilih kawasan',
  'pp.region_status':
      'Halaman {page}/{count} · {n} kotak',
  'pp.prev_page':
      'Halaman sebelumnya',
  'pp.next_page':
      'Halaman seterusnya',
  'pp.redact':
      'Penyuntingan hitam kekal',
  'pp.redact_terms_hint':
      'Istilah untuk dicari (asingkan dengan koma) — kosong: tandakan secara manual',
  'pp.redact_find':
      'Cari',
  'pp.redact_searching':
      'Mencari',
  'pp.redact_no_match':
      'Tiada padanan — anda boleh menandakan secara manual',
  'pp.redact_confirm':
      '{n} kawasan pada {pages} halaman akan dibuang secara kekal. Halaman ini menjadi imej (teks di luar kotak kekal boleh dicari); anotasi, borang dan kata laluan dibuang. Buat asal hanya berfungsi sebelum menyimpan.',
  'pp.redact_apply':
      'Hitamkan',
  'pp.redact_done':
      'Dihitamkan dan disahkan: tiada teks tersisa di dalam kotak.',
  'pp.saved_as':
      'Disimpan: {name}',
  'pp.sheet_prefix':
      'Halaman',
  'pp.to_xlsx':
      'Eksport jadual ke Excel',
  'pp.to_docx':
      'Eksport ke Word (kekalkan susun atur)',
  'pp.pdfa':
      'Simpan sebagai PDF/A',
  'pp.pdfa_image_sub':
      'Setiap halaman menjadi imej + teks boleh dicari (PDF/A-2b); fail mungkin membesar, pautan dan borang tidak dikekalkan.',
  'pp.too_many_pages':
      'Paling banyak {n} halaman — pilih halaman atau pisahkan dahulu',
  'pp.compare':
      'Bandingkan dua PDF',
  'pp.compare_text':
      'Teks',
  'pp.compare_visual':
      'Visual',
  'pp.compare_names':
      '{a} → {b}',
  'pp.compare_summary':
      '{pages} halaman berubah · +{added} / −{removed} perkataan',
  'pp.compare_only_changed':
      'Perubahan sahaja',
  'pp.compare_same':
      'Tiada perbezaan teks',
  'pp.compare_page':
      'Halaman {n}',
  'pp.compare_visual_page':
      'Halaman {n} · {pct}% berbeza',
  'pp.compare_progress':
      '{done}/{total} halaman dibandingkan',
  'pp.compare_visual_note':
      'Perbandingan visual meliputi paling banyak {n} halaman',
  'pp.permissions':
      'Kebenaran dan kata laluan',
  'pp.owner_password':
      'Kata laluan pemilik (mengubah kebenaran)',
  'pp.user_password':
      'Kata laluan buka (pilihan)',
  'pp.user_password_hint':
      'Biarkan kosong untuk membuka tanpa kata laluan',
  'pp.owner_needed':
      'Kata laluan pemilik diperlukan',
  'pp.permissions_done':
      'Kebenaran digunakan',
  'pp.outline':
      'Penanda buku (kerangka)',
  'pp.outline_add':
      'Tambah penanda buku',
  'pp.outline_title':
      'Tajuk',
  'pp.outline_page':
      'Halaman (1–{count})',
  'pp.outline_empty':
      'Tiada penanda buku — tambah dengan +',
  'pp.outline_indent':
      'Inden',
  'pp.outline_outdent':
      'Kurangkan inden',
  'pp.stamp':
      'Templat setem / tera air',
  'pp.stamp_text':
      'Teks setem',
  'pp.stamp_as_watermark':
      'Sebagai tera air (pepenjuru, pudar)',
  'pp.stamp_date':
      'Tambah tarikh ({date})',
  'pp.stamp_apply':
      'Guna',
  'pp.selected_pages_only':
      'Halaman dipilih sahaja',
  'pp.place':
      'Kedudukan',
  'pp.numbering':
      'Penomboran lanjutan',
  'pp.number_style':
      'Gaya',
  'pp.number_start':
      'Nombor mula',
  'pp.number_prefix':
      'Awalan',
  'pp.number_digits':
      'Digit',
  'pp.page_word':
      'Halaman',
  'pp.preview':
      'Pratonton: {text}',
  'pp.notes_empty':
      'Dokumen tiada penyerlahan atau nota',
  'pp.notes_count':
      '{n} markah',
  'pp.find_results':
      '{n} hasil',
  'pp.find_ocr_hit':
      'Padanan pada halaman imbasan (OCR)',
  'pp.compress_hard':
      'Pemampatan agresif',
  'pp.compress_hard_warn':
      'Halaman ditukar menjadi imej: ketajaman vektor, pautan, borang dan anotasi hilang. Teks boleh kekal boleh dicari dalam lapisan tidak kelihatan.',
  'pp.resolution':
      'Resolusi',
  'pp.quality':
      'Kualiti',
  'pp.quality_low':
      'Rendah',
  'pp.quality_mid':
      'Sederhana',
  'pp.quality_high':
      'Tinggi',
  'pp.grayscale':
      'Skala kelabu',
  'pp.keep_text':
      'Kekalkan teks (boleh dicari)',
  'pp.keep_text_sub':
      'Lapisan teks tidak kelihatan ditulis',
  'pp.compress_hard_bigger':
      'Tidak lebih kecil ({size}) — guna Buat asal untuk kembali',
  'pp.studio':
      'Studio halaman',
  'pp.studio_insert':
      'Sisipkan halaman',
  'pp.studio_extract':
      'Ekstrak yang dipilih ke PDF baharu',
  'pp.studio_split':
      'Pisahkan pada halaman dipilih',
  'pp.studio_split_hint':
      'Untuk memisahkan, pilih sekurang-kurangnya satu halaman selain halaman pertama',
  'pp.studio_need_page':
      'Pilihan memerlukan sekurang-kurangnya satu halaman yang tidak kosong',
  'pp.studio_file_failed':
      'Tidak dapat membuka PDF ini (mungkin disulitkan atau rosak)',
  'pp.studio_hint':
      'Ketik untuk memilih · tekan lama dan seret untuk mengalih',
  'pp.studio_selected':
      '{n} dipilih',
  'pp.rotate_left':
      'Putar ke kiri',
  'pp.rotate_right':
      'Putar ke kanan',
  'pp.blank':
      'Cari dan padam halaman kosong',
  'pp.blank_finding':
      'Mencari halaman kosong',
  'pp.blank_none':
      'Tiada halaman kosong ditemui',
  'pp.blank_all':
      'Semua halaman kelihatan kosong — tiada yang dipadam',
  'pp.blank_found':
      '{n} halaman kosong dipilih: {pages}. Padam?',
  'pp.crop':
      'Pangkas halaman',
  'pp.fit_a4':
      'Muatkan ke A4',
  'pp.autofill':
      'Isi daripada profil',
  'pp.autofill_none':
      'Tiada medan kosong yang sepadan dengan profil',
  'pp.autofill_done':
      '{n} medan diisi — semak dan simpan',
  'pp.profile':
      'Profil isian automatik',
  'pp.profile_privacy':
      'Disimpan hanya pada peranti ini, tidak pernah dihantar ke mana-mana.',
  'pp.form_create':
      'Tambah medan borang',
  'pp.field_text':
      'Medan teks',
  'pp.ocr_layer':
      'Jadikan boleh dicari (OCR)',
  'pp.ocr_layer_none':
      'Tiada halaman imbasan dengan teks yang boleh dikenali ditemui',
  'pp.ocr_layer_done':
      '{n} halaman kini boleh dicari',
  'pp.field_detect':
      'Cari tempat isian',
  'pp.field_detect_sub':
      'Menukar ruang kosong, titik dan kotak menjadi medan',
  'pp.field_detect_none':
      'Tiada tempat isian ditemui',
  'pp.images_to_pdf':
      'PDF daripada imej',
  'pp.images_a4_q':
      '{n} imej. Jadikan setiap halaman A4? (Tidak: setiap halaman mengikut imejnya)',
  'pp.images_a4':
      'Guna A4',
  'pp.pdf_to_images':
      'PDF ke imej (kelompok)',
  'pp.images_saved':
      '{n} imej disimpan: {dir}',
  'pp.web_to_pdf':
      'PDF daripada laman web',
  'pp.web_url':
      'Alamat halaman',
  'pp.web_bad_url':
      'Masukkan alamat http(s) yang sah',
  'pp.office_to_pdf':
      'Word/Excel/PowerPoint → PDF',
  'pp.signatures':
      'Tandatangan dan parap',
  'pp.my_signature':
      'Tandatangan saya',
  'pp.my_initials':
      'Parap saya',
  'pp.none':
      'Tiada',
  'pp.initial_all':
      'Parap setiap halaman',
  'pp.initial_with_date':
      'Tarikh di bawah parap',
  'pp.initials_missing':
      'Lukis parap anda dahulu',
  'pp.date_stamp':
      'Setem tarikh',
  'pp.sign_here':
      'Letakkan tandatangan pada halaman',
  'pp.save_first':
      'Simpan perubahan anda dahulu',
  'pp.image_zoom_failed':
      'Tidak dapat membuka imej',
  'pp.meta':
      'Sifat dokumen',
  'pp.meta_strip':
      'Buang semua metadata',
  'pp.meta_strip_body':
      'Tajuk, pengarang, aplikasi pencipta, tarikh ubah suai dan butiran yang tertinggal dalam semakan lama dibuang. Halaman kekal sama; anda boleh buat asal sebelum menyimpan.',
  'pp.meta_strip_ok':
      'Buang',
  'pp.layers':
      'Lapisan',
  'pp.layers_none':
      'Dokumen ini tiada lapisan',
  'pp.layers_failed':
      'Tidak dapat membaca lapisan',
  'pp.layers_unnamed':
      'Lapisan {n}',
  'pp.meta_failed':
      'Tidak dapat membaca sifat dokumen',
  'pp.xfdf_out':
      'Eksport anotasi (XFDF)',
  'pp.xfdf_in':
      'Import anotasi (XFDF)',
  // ── PDF yerinde düzenleme (pse, m.3) ──
  'pse.editing':
      'Menyunting',
  'pse.unsaved_n':
      'Belum disimpan · {n} perubahan',
  'pse.saved':
      'Disimpan',
  'pse.undo_named':
      'Buat asal: {name}',
  'pse.redo_named':
      'Buat semula: {name}',
  'pse.step_detail':
      '{name}: “{detail}”',
  'pse.hint_tap':
      'Ketik teks untuk menaip; tekan lama untuk mengalih atau menggayakannya.',
  'pse.hint_scanned':
      'Halaman ini ialah imej imbasan tanpa teks yang boleh dipilih. Ketik “Kotak teks” untuk menambah teks atau “Kenali teks (OCR)” untuk mengesannya.',
  'pse.open_elsewhere':
      'PDF ini sedang disunting di tetingkap lain — perubahan yang belum disimpan ada di sana.',
  'pse.edit_title':
      'Sunting perenggan',
  'pse.edit_hint':
      'Teks perenggan',
  'pse.busy_wait':
      'Memproses halaman, sila tunggu beberapa saat…',
  'pse.save_how':
      'Bagaimanakah ia hendak disimpan?',
  'pse.save_keep_original':
      'Simpan sebagai salinan (asal dikekalkan)',
  'pse.save_overwrite':
      'Tulis ganti fail asal',
  'pse.save_as':
      'Simpan sebagai',
  'pse.save_as_same':
      'Salinan dalam folder yang sama',
  'pse.saved_copy':
      'Salinan disimpan: {name}',
  'pse.finish':
      'Selesai menyunting',
  'pse.versions':
      'Sejarah versi',
  'pse.versions_empty':
      'Belum ada versi disimpan. Setiap kali anda menyimpan, versi sebelumnya disimpan di sini selama 14 hari.',
  'pse.versions_note':
      'Versi sebelumnya disimpan selama 14 hari.',
  'pse.version_restore':
      'Pulihkan versi ini',
  'pse.version_restore_q':
      'Pulihkan versi dari {when}? Keadaan semasa juga ditambah ke sejarah.',
  'pse.version_restore_unsaved':
      'Perubahan yang belum disimpan akan dibuang.',
  'pse.version_restored':
      'Versi sebelumnya dipulihkan',
  'pse.recover_title':
      'Suntingan belum disimpan ditemui',
  'pse.recover_body':
      'Dokumen ini mempunyai {n} perubahan yang belum disimpan semasa aplikasi ditutup.',
  'pse.recover_body_copy':
      'Dokumen ini mempunyai perubahan yang belum disimpan semasa aplikasi ditutup. Fail telah berubah sejak itu, jadi keadaan yang disunting boleh dipulihkan sebagai salinan.',
  'pse.recover_restore':
      'Pulihkan suntingan yang belum disimpan',
  'pse.recover_copy':
      'Simpan salinan yang dipulihkan',
  'pse.recover_discard':
      'Buang',
  'pse.recover_done':
      '{n} perubahan dipulihkan (belum disimpan)',
  'pse.recover_partial':
      '{n} daripada {total} perubahan dipulihkan',
  'pse.locked_title':
      'Dokumen ini dilindungi daripada penyuntingan',
  'pse.locked_open':
      'Buka dengan kata laluan pemilik',
  'pse.owner_title':
      'Kata laluan pemilik',
  'pse.owner_body':
      'Masukkan kata laluan yang menanggalkan sekatan penyuntingan.',
  'pse.al_center':
      'Tengah',
  'pse.al_justify':
      'Rata kiri dan kanan',
  'pse.al_left':
      'Jajar kiri',
  'pse.al_right':
      'Jajar kanan',
  'pse.comment_edit':
      'Sunting nota',
  'pse.comment_page':
      'Halaman {n}',
  'pse.comment_reply':
      'Balas',
  'pse.comments':
      'Komen',
  'pse.comments_all':
      'Semua',
  'pse.comments_none':
      'Tiada anotasi dalam dokumen ini.',
  'pse.comments_open':
      'Terbuka',
  'pse.comments_resolved':
      'Diselesaikan',
  'pse.context_bar':
      'Pilihan alat',
  'pse.copied':
      'Disalin',
  'pse.copy':
      'Salin',
  'pse.cut':
      'Potong',
  'pse.delete_pull':
      'Padam dan tarik ke atas yang di bawah',
  'pse.done':
      'Selesai',
  'pse.duplicate':
      'Gandakan',
  'pse.find_case':
      'Padankan huruf besar/kecil',
  'pse.find_count':
      '{n} padanan · memaparkan {i}',
  'pse.find_hint':
      'Mencari dalam seluruh dokumen; teks itu sendiri yang diubah.',
  'pse.find_next':
      'Seterusnya',
  'pse.find_none':
      'Tiada padanan.',
  'pse.find_replace_all':
      'Ganti semua',
  'pse.find_replace_one':
      'Ganti',
  'pse.find_replaced':
      '{n} padanan diganti.',
  'pse.find_replaced_partial':
      '{n} padanan diganti; {m} blok tidak dapat diubah.',
  'pse.find_title':
      'Cari dan ganti',
  'pse.find_what':
      'Cari',
  'pse.find_with':
      'Ganti dengan',
  'pse.find_word':
      'Perkataan penuh',
  'pse.flatten':
      'Ratakan anotasi',
  'pse.flatten_q':
      'Anotasi dan medan borang pada halaman ini menjadi sebahagian daripada halaman dan tidak boleh lagi disunting secara berasingan.',
  'pse.fmt_align':
      'Penjajaran',
  'pse.fmt_bold':
      'Tebal',
  'pse.fmt_color':
      'Warna',
  'pse.fmt_highlight':
      'Warna penyerlahan',
  'pse.fmt_italic':
      'Condong',
  'pse.fmt_larger':
      'Teks lebih besar',
  'pse.fmt_size':
      'Saiz fon',
  'pse.fmt_smaller':
      'Teks lebih kecil',
  'pse.fmt_strike':
      'Garis lorek',
  'pse.fmt_underline':
      'Garis bawah',
  'pse.font_doc':
      'dokumen',
  'pse.font_fallback':
      'sandaran',
  'pse.overflow':
      'Teks bertindih dengan teks di bawahnya.',
  'pse.overflow_shrink':
      'Kecilkan',
  'pse.overflow_push':
      'Tolak ke bawah',
  'pse.overflow_widen':
      'Lebarkan',
  'pse.link':
      'Pautan',
  'pse.link_web':
      'Pautkan ke alamat web',
  'pse.link_web_hint':
      'Alamat atau e-mel',
  'pse.link_page':
      'Pautkan ke halaman dalam dokumen ini',
  'pse.link_page_hint':
      'Nombor halaman (1–{n})',
  'pse.link_to_page':
      'Kini menuju ke halaman {n}',
  'pse.link_remove':
      'Buang pautan',
  'pse.link_bad':
      'Alamat atau halaman ini tidak boleh digunakan.',
  'pse.font_pick':
      'Fon',
  'pse.image_exported':
      'Imej disimpan ke Dokumen: {name}',
  'pse.img_add':
      'Tambah imej',
  'pse.img_from_files':
      'Daripada galeri atau fail',
  'pse.img_from_camera':
      'Ambil dengan kamera',
  'pse.obj_lasso':
      'Pilih dengan lasso',
  'pse.img_back':
      'Hantar ke belakang',
  'pse.img_crop':
      'Pangkas',
  'pse.img_export':
      'Eksport',
  'pse.img_front':
      'Bawa ke hadapan',
  'pse.img_replace':
      'Ganti',
  'pse.img_rotate':
      'Putar',
  'pse.list_bullets':
      'Senarai berbulet',
  'pse.list_numbers':
      'Senarai bernombor',
  'pse.locked_box':
      'Tambah kotak teks di atasnya',
  'pse.locked_line':
      'Tukar ke mod garis',
  'pse.locked_replace':
      'Ganti tulisan',
  'pse.locked_ai':
      'Baca dengan AI dan ganti',
  'pse.ocr_ai_reading':
      'AI sedang membaca tulisan…',
  'pse.locked_why':
      'Mengapa ini tidak boleh disunting?',
  'pse.mk_stamp':
      'Setem',
  'pse.mk_freetext':
      'Teks bebas',
  'pse.stamp_approved':
      'DILULUSKAN',
  'pse.stamp_rejected':
      'DITOLAK',
  'pse.stamp_confidential':
      'SULIT',
  'pse.stamp_custom':
      'Setem tersuai…',
  'pse.mk_note':
      'Nota',
  'pse.page_rotate':
      'Putar halaman ini',
  'pse.page_studio':
      'Studio halaman',
  'pse.page_studio_hint':
      'Susun semula, sisip, padam, pisah, gabung',
  'pse.paste':
      'Tampal',
  'pse.select_all':
      'Pilih semua',
  'pse.style_copy':
      'Salin gaya',
  'pse.style_paste':
      'Tampal gaya',
  'pse.tool_all':
      'Semua alat PDF',
  'pse.tool_all_hint':
      'Penyuntingan hitam, kata laluan, mampat, tukar…',
  'pse.tool_form':
      'Borang',
  'pse.tool_pages':
      'Halaman',
  'pse.tool_sign':
      'Tandatangan',
  'pse.kvkk_apply':
      'Hitamkan {n} item',
  'pse.kvkk_custom_hint':
      'Perkataan tambahan (asingkan dengan koma)',
  'pse.kvkk_done':
      '{n} item dihitamkan. Dokumen ditulis semula apabila anda menyimpan.',
  'pse.kvkk_none':
      'Tiada corak data peribadi ditemui.',
  'pse.kvkk_title':
      'Cari data peribadi',
  'pse.mk_redact':
      'Hitamkan',
  'pse.redact_q':
      'Teks yang dihitamkan dibuang secara kekal daripada dokumen; selepas disimpan ia tidak boleh dipulihkan dan versi lama turut dipadam.',
  'pse.ocr_run':
      'Kenali teks (OCR)',
  'pse.tool_legacy':
      'Penyunting klasik',
  'pse.tool_legacy_hint':
      'Tera air, pembetulan garis imbasan',
  'pse.edit_text':
      'Sunting teks',
  'pse.style':
      'Gaya',
  'pse.add_text':
      'Tambah teks',
  'pse.textbox_guide':
      'Ketik di tempat anda mahu menambah teks',
  'pse.lasso_guide':
      'Lukis mengelilingi item yang hendak dipilih',
  'pse.draw_guide':
      '{tool} aktif · Cubit dengan 2 jari untuk zum',
  'pse.stroke_title':
      'Warna & ketebalan',
  'pse.stroke_width':
      'Ketebalan garis',
  'pse.align_group':
      'Jajar & agihkan',
  'pse.order':
      'Susunan',
  'pse.block_more':
      'Tindakan blok',
  'pse.style_sheet_title':
      'Pemformatan teks',
  'pse.font_size_pt':
      '{n} pt',
  'pse.obj_guide':
      'Imej & bentuk yang boleh dipilih diserlahkan · ketik untuk menyunting',
  'pse.obj_count':
      '{n} item boleh dipilih',
  'pse.obj_none_hint':
      'Tiada imej yang boleh dipilih pada halaman ini · tambah imej baharu di bawah',
  'pse.obj_badge_image':
      'Imej',
  'pse.obj_badge_shape':
      'Bentuk',
  'pse.resize':
      'Ubah saiz',
  'pse.resize_title':
      'Saiz & skala imej',
  'pse.scale_pct':
      'Skala: {n}%',
  'pse.size_small':
      'Kecil',
  'pse.size_fit':
      'Muat halaman',
  'pse.size_large':
      'Besar',
  'pse.apply_size':
      'Guna saiz',
  'pse.text_guide_rich':
      'Ketik mana-mana kotak teks untuk menyunting · seret pemegang untuk mengalih atau melebarkan',
  'excel.act_saved':
      'Disunting',
  'excel.add_sheet':
      'Tambah helaian',
  'excel.alignment':
      'Penjajaran',
  'excel.autosum':
      'Jumlah automatik',
  'excel.autosum_empty':
      'Tiada nombor bersebelahan untuk dijumlahkan — taip julatnya sendiri.',
  'excel.border_all':
      'Semua sempadan',
  'excel.border_bottom':
      'Sempadan bawah',
  'excel.border_none':
      'Tanpa sempadan',
  'excel.border_outline':
      'Garis luar',
  'excel.border_top':
      'Sempadan atas',
  'excel.borders':
      'Sempadan',
  'excel.cell_content':
      'Kandungan sel',
  'excel.cell_label':
      'Sel {ref}',
  'excel.cell_menu':
      'Menu sel',
  'excel.cell_reference':
      'Rujukan sel',
  'excel.cell_reference_hint':
      'cth. C15',
  'excel.cell_styles':
      'Gaya sel',
  'excel.clear_contents':
      'Kosongkan kandungan',
  'excel.clear_formats':
      'Kosongkan format',
  'excel.clipboard_empty':
      'Papan keratan kosong.',
  'excel.col_left_short':
      'Lajur +←',
  'excel.col_right_short':
      'Lajur +→',
  'excel.color_auto':
      'Automatik',
  'excel.color_none':
      'Tanpa warna',
  'excel.column':
      'Lajur',
  'excel.column_n':
      'Lajur {c}',
  'excel.column_width':
      'Lebar lajur…',
  'excel.column_width_of':
      'Lebar lajur {col}',
  'excel.cond_contains':
      'Teks mengandungi',
  'excel.cond_equal':
      'Sama dengan',
  'excel.cond_format':
      'Pemformatan bersyarat',
  'excel.cond_greater':
      'Lebih besar daripada',
  'excel.cond_less':
      'Lebih kecil daripada',
  'excel.cond_text':
      'Teks',
  'excel.cond_value':
      'Nilai',
  'excel.copied_stat':
      'Disalin: {v}',
  'excel.copy_done':
      '{n} sel disalin',
  'excel.csv_encoding':
      'Pengekodan CSV',
  'excel.csv_failed':
      'Eksport CSV gagal: {error}',
  'excel.csv_format_lost':
      'Format tidak disimpan dalam CSV — hanya nilai disimpan',
  'excel.csv_formula_guard':
      'Perlindungan formula',
  'excel.csv_formula_guard_sub':
      'Teks yang bermula dengan = + - @ diberi tanda \' di hadapan supaya tidak dijalankan sebagai arahan',
  'excel.csv_legacy':
      'Excel Turki lama / Notepad',
  'excel.csv_save_xlsx':
      'Simpan sebagai XLSX',
  'excel.csv_utf8':
      'UTF-8 (disyorkan)',
  'excel.csv_utf8_sub':
      'Excel moden / Google Sheets',
  'excel.custom_sort':
      'Isihan tersuai',
  'excel.cut':
      'Potong',
  'excel.cut_done':
      '{n} sel dipotong',
  'excel.decimal_less':
      'Kurangkan perpuluhan',
  'excel.decimal_more':
      'Tambah perpuluhan',
  'excel.default_value':
      'Lalai ({value})',
  'excel.delete_col':
      'Padam lajur',
  'excel.delete_row':
      'Padam baris',
  'excel.delete_sheet':
      'Padam helaian',
  'excel.delete_sheet_confirm':
      'Padam helaian “{name}” beserta semua kandungannya?',
  'excel.dup_done':
      '{n} baris pendua dipadam; {m} baris unik kekal',
  'excel.dup_has_header':
      'Data saya mempunyai pengepala',
  'excel.dup_needs_range':
      'Pilih julat beberapa baris',
  'excel.dup_none':
      'Tiada baris pendua',
  'excel.dup_run':
      'Buang pendua',
  'excel.dup_title':
      'Buang pendua',
  'excel.duplicate_sheet':
      'Gandakan',
  'excel.fc_bottom':
      'Bawah',
  'excel.fc_category':
      'Kategori',
  'excel.fc_code':
      'Kod format',
  'excel.fc_control':
      'Kawalan teks',
  'excel.fc_decimals':
      'Tempat perpuluhan',
  'excel.fc_general':
      'Am',
  'excel.fc_horizontal':
      'Mengufuk',
  'excel.fc_indent':
      'Inden',
  'excel.fc_line':
      'Garis',
  'excel.fc_line_color':
      'Warna garis',
  'excel.fc_middle':
      'Tengah',
  'excel.fc_negative':
      'Nombor negatif',
  'excel.fc_presets':
      'Pratetap',
  'excel.fc_rotation':
      'Orientasi',
  'excel.fc_sample':
      'Sampel',
  'excel.fc_style':
      'Gaya fon',
  'excel.fc_symbol':
      'Simbol',
  'excel.fc_symbol_pos':
      'Kedudukan simbol',
  'excel.fc_tab_fill':
      'Isian',
  'excel.fc_tab_font':
      'Fon',
  'excel.fc_tab_number':
      'Nombor',
  'excel.fc_thousands':
      'Pemisah ribuan',
  'excel.fc_top':
      'Atas',
  'excel.fc_type':
      'Jenis',
  'excel.fc_vertical':
      'Menegak',
  'excel.fill_color':
      'Warna isian',
  'excel.fill_down':
      'Isi ke bawah',
  'excel.fill_no_neighbour':
      'Lajur bersebelahan kosong — tiada yang boleh diisi ke bawah',
  'excel.fill_right':
      'Isi ke kanan',
  'excel.fill_sort_group':
      'Isi & isih',
  'excel.filter':
      'Tapis',
  'excel.filter_all':
      'Pilih semua',
  'excel.filter_blank':
      '(Kosong)',
  'excel.filter_bottom10':
      '10 terbawah',
  'excel.filter_by_color':
      'Mengikut warna',
  'excel.filter_clear':
      'Kosongkan tapisan',
  'excel.filter_column':
      'Tapis lajur {col}',
  'excel.filter_contains':
      'Mengandungi…',
  'excel.filter_create':
      'Cipta tapisan',
  'excel.filter_created':
      'Tapisan dicipta — gunakan anak panah pada pengepala',
  'excel.filter_needs_table':
      'Tiada tapisan pada lajur ini. Penapisan berfungsi pada julat jadual yang ditakrifkan dalam fail.',
  'excel.filter_remove':
      'Buang tapisan',
  'excel.filter_removed':
      'Tapisan dibuang',
  'excel.filter_top10':
      '10 teratas',
  'excel.find_in_sheet':
      'Cari dalam helaian ini',
  'excel.flash_done':
      '{n} sel diisi',
  'excel.flash_fill':
      'Isi pantas',
  'excel.flash_need_data':
      'Pilih sel di sebelah lajur yang mempunyai data',
  'excel.flash_need_example':
      'Taip contoh dalam lajur ini dahulu',
  'excel.flash_none':
      'Corak tidak ditemui — taip satu contoh lagi dan cuba semula',
  'excel.fmt_currency':
      'Mata wang (₺)',
  'excel.fmt_date':
      'Tarikh',
  'excel.fmt_general':
      'Am',
  'excel.fmt_number':
      'Nombor (1,234.50)',
  'excel.fmt_percent':
      'Peratus (15%)',
  'excel.fmt_text':
      'Teks',
  'excel.fmt_thousands':
      'Ribuan (1,234)',
  'excel.fmt_time':
      'Masa',
  'excel.fn_average':
      'Purata',
  'excel.fn_count':
      'Bilangan',
  'excel.fn_max':
      'Maks',
  'excel.fn_min':
      'Min',
  'excel.fn_sum_short':
      'Jumlah',
  'excel.font_color':
      'Warna fon',
  'excel.font_default':
      'Fon',
  'excel.form_new':
      'Rekod baharu',
  'excel.form_next':
      'Rekod seterusnya',
  'excel.form_prev':
      'Rekod sebelumnya',
  'excel.form_record':
      'Rekod {n} daripada {total}',
  'excel.form_view':
      'Paparan borang',
  'excel.format_as_table':
      'Format sebagai jadual',
  'excel.format_cells':
      'Format sel',
  'excel.formula_english':
      'Excel: papar formula dalam bahasa Inggeris',
  'excel.formula_english_sub':
      'SUM, IF … dan pemisah koma walaupun antara muka dalam bahasa Turki',
  'excel.freeze_cell':
      'Bekukan bahagian atas dan kiri pilihan',
  'excel.freeze_col':
      'Bekukan lajur pertama',
  'excel.freeze_menu':
      'Bekukan anak tetingkap',
  'excel.freeze_off_view':
      'Matikan anak tetingkap beku pada skrin ini',
  'excel.freeze_on_view':
      'Hidupkan anak tetingkap beku pada skrin ini',
  'excel.freeze_row':
      'Bekukan baris teratas',
  'excel.fx_library':
      'Pustaka fungsi',
  'excel.go':
      'Pergi',
  'excel.goto_cell':
      'Pergi ke sel',
  'excel.goto_cell_menu':
      'Pergi ke sel…',
  'excel.goto_last_cell':
      'Sel terakhir digunakan',
  'excel.goto_last_row':
      'Baris terakhir digunakan',
  'excel.goto_quick':
      'Lokasi pantas',
  'excel.goto_start':
      'Permulaan (A1)',
  'excel.grid_label':
      'Grid sel — tekan lama dan seret untuk memilih julat',
  'excel.gridlines':
      'Garis grid',
  'excel.group_clipboard':
      'Papan keratan',
  'excel.group_format':
      'Format',
  'excel.group_number':
      'Nombor',
  'excel.hidden':
      'Tersembunyi',
  'excel.hide_col':
      'Sembunyikan lajur',
  'excel.hide_row':
      'Sembunyikan baris',
  'excel.hide_sheet':
      'Sembunyikan helaian',
  'excel.hide_show':
      'Sembunyi / tunjuk',
  'excel.input_kept_text':
      'Disimpan sebagai teks (tidak ditukar kepada tarikh)',
  'excel.insert_col':
      'Sisip lajur',
  'excel.insert_col_left':
      'Sisip lajur di kiri',
  'excel.insert_col_right':
      'Sisip lajur di kanan',
  'excel.insert_row':
      'Sisip baris',
  'excel.insert_row_above':
      'Sisip baris di atas',
  'excel.insert_row_below':
      'Sisip baris di bawah',
  'excel.key_enter':
      'Enter dan turun',
  'excel.key_tab':
      'Sel seterusnya (kanan)',
  'excel.keyboard_123':
      'Papan kekunci nombor',
  'excel.keyboard_abc':
      'Papan kekunci huruf',
  'excel.last_sheet':
      'Helaian terakhir tidak boleh dipadam',
  'excel.last_visible_sheet':
      'Helaian terakhir yang kelihatan tidak boleh disembunyikan',
  'excel.merge':
      'Gabung sel',
  'excel.merge_center':
      'Gabung & tengahkan',
  'excel.merge_needs_range':
      'Pilih sekurang-kurangnya dua sel untuk digabungkan',
  'excel.move_sheet_left':
      'Alih ke kiri',
  'excel.move_sheet_right':
      'Alih ke kanan',
  'excel.no_sheet':
      'Tiada helaian.',
  'excel.note_author':
      'Pembaca Fail',
  'excel.note_delete':
      'Padam nota',
  'excel.note_edit':
      'Sunting nota',
  'excel.note_hint':
      'Nota (percubaan — semak dalam Excel desktop)',
  'excel.note_new':
      'Nota baharu',
  'excel.nothing_hidden':
      'Tiada yang tersembunyi di sebelah pilihan',
  'excel.nothing_to_paste':
      'Salin julat dahulu',
  'excel.number_format':
      'Format nombor',
  'excel.opening_preview':
      'Sedang dibuka — penyuntingan akan sedia sebentar lagi; memaparkan baris pertama',
  'excel.panes_trimmed':
      'Anak tetingkap beku dalam fail tidak muat pada skrin, jadi lajur tersebut dibuat boleh tatal. Anda boleh mematikannya sepenuhnya melalui ⋮ > Nyahbeku anak tetingkap.',
  'excel.paste':
      'Tampal',
  'excel.paste_formats':
      'Tampal format sahaja',
  'excel.paste_formulas':
      'Tampal formula sahaja',
  'excel.paste_special_group':
      'Tampal khas',
  'excel.paste_transpose':
      'Tampal transposisi',
  'excel.paste_values':
      'Tampal nilai sahaja',
  'excel.pick_from_list':
      'Pilih daripada senarai',
  'excel.quick_actions':
      'Tindakan pantas',
  'excel.redo':
      'Buat semula',
  'excel.redone':
      'Dibuat semula: {what}',
  'excel.rename_sheet':
      'Namakan semula helaian',
  'excel.replace':
      'Ganti',
  'excel.replace_all':
      'Ganti semua',
  'excel.replace_none':
      'Tiada padanan untuk diganti.',
  'excel.replace_with':
      'Ganti dengan',
  'excel.replaced_count':
      '{n} sel diganti',
  'excel.ribbon_hide':
      'Sembunyikan reben',
  'excel.ribbon_show':
      'Tunjukkan reben',
  'excel.row':
      'Baris',
  'excel.row_above_short':
      'Baris +↑',
  'excel.row_below_short':
      'Baris +↓',
  'excel.row_height':
      'Tinggi baris…',
  'excel.row_height_of':
      'Tinggi baris {row}',
  'excel.rows_cols_group':
      'Baris & lajur',
  'excel.save_csv':
      'Eksport sebagai CSV',
  'excel.saved_as_xlsx':
      'Disimpan sebagai {name} (fail .xls asal anda tidak diubah)',
  'excel.selection_cells':
      'Dipilih: {n} sel',
  'excel.selection_filled':
      'Dipilih: {n} sel  ·  Berisi: {filled}',
  'excel.sheet_name':
      'Helaian{n}',
  'excel.sheet_name_label':
      'Nama helaian',
  'excel.sheet_name_taken':
      'Nama itu sudah digunakan',
  'excel.sheet_pos':
      'Helaian {n} / {total}',
  'excel.sheet_rtl':
      'Helaian kanan-ke-kiri',
  'excel.sheet_rtl_off':
      'Helaian akan disusun kiri-ke-kanan (lajur A di kiri).',
  'excel.sheet_rtl_on':
      'Helaian akan disusun kanan-ke-kiri (lajur A di kanan).',
  'excel.show_cols':
      'Tunjukkan lajur',
  'excel.show_rows':
      'Tunjukkan baris',
  'excel.sort':
      'Isih',
  'excel.sort_add_level':
      'Tambah peringkat',
  'excel.sort_asc':
      'Isih A → Z',
  'excel.sort_asc_short':
      'A→Z',
  'excel.sort_by':
      'Isih mengikut',
  'excel.sort_desc':
      'Isih Z → A',
  'excel.sort_desc_short':
      'Z→A',
  'excel.sort_has_header':
      'Data saya mempunyai pengepala',
  'excel.sort_needs_range':
      'Untuk mengisih, pilih baris dahulu (tekan dan seret) atau tambah tapisan pada jadual.',
  'excel.sort_then_by':
      'Kemudian mengikut',
  'excel.split_comma':
      'Koma',
  'excel.split_custom':
      'Pembatas lain',
  'excel.split_done':
      'Dipecahkan kepada {n} lajur',
  'excel.split_merge':
      'Anggap pembatas berturutan sebagai satu',
  'excel.split_none':
      'Tiada yang dipecahkan',
  'excel.split_run':
      'Pisahkan',
  'excel.split_semi':
      'Koma bertitik',
  'excel.split_space':
      'Ruang',
  'excel.split_tab':
      'Tab',
  'excel.split_title':
      'Teks ke lajur',
  'excel.start_formula':
      'Mulakan formula',
  'excel.stat_avg_short':
      'Purata: {v}',
  'excel.stat_count_short':
      'Bilangan: {v}',
  'excel.stat_max_short':
      'Maks: {v}',
  'excel.stat_min_short':
      'Min: {v}',
  'excel.stat_sum_short':
      'Jumlah: {v}',
  'excel.tab_color':
      'Warna tab',
  'excel.tab_data':
      'Data',
  'excel.tab_formulas':
      'Formula',
  'excel.tab_home':
      'Laman Utama',
  'excel.tab_insert':
      'Sisip',
  'excel.tab_view':
      'Paparan',
  'excel.table_needs_range':
      'Pilih jadual termasuk baris pengepalanya dahulu',
  'excel.truncated':
      'Buku kerja ini terlalu besar: hanya {rows} baris dan {cols} lajur pertama dibuka. Penyimpanan dimatikan supaya selebihnya tidak hilang — anda boleh membacanya atau mengeksport CSV.',
  'excel.truncated_no_save':
      'Penyimpanan dimatikan: buku kerja dipotong pada had bacaan; menyimpan akan memadam selebihnya.',
  'excel.undo':
      'Buat asal',
  'excel.undo_autosum':
      'Jumlah automatik',
  'excel.undo_border':
      'sempadan',
  'excel.undo_cell_style':
      'Gaya sel',
  'excel.undo_clear':
      'kosongkan',
  'excel.undo_cond_format':
      'pemformatan bersyarat',
  'excel.undo_dedup':
      'Buang pendua',
  'excel.undo_delete_col':
      'padam lajur',
  'excel.undo_delete_row':
      'padam baris',
  'excel.undo_duplicate_sheet':
      'Gandakan helaian',
  'excel.undo_fill':
      'isi',
  'excel.undo_fill_color':
      'warna isian',
  'excel.undo_filter':
      'tapisan',
  'excel.undo_filter_off':
      'Buang tapisan',
  'excel.undo_filter_on':
      'Cipta tapisan',
  'excel.undo_font':
      'fon',
  'excel.undo_font_color':
      'warna fon',
  'excel.undo_form':
      'Borang',
  'excel.undo_format':
      'pemformatan',
  'excel.undo_freeze':
      'Bekukan anak tetingkap',
  'excel.undo_gridlines':
      'Garis grid',
  'excel.undo_hide':
      'Sembunyikan',
  'excel.undo_hide_sheet':
      'Sembunyikan helaian',
  'excel.undo_insert_col':
      'sisip lajur',
  'excel.undo_insert_row':
      'sisip baris',
  'excel.undo_merge':
      'gabung sel',
  'excel.undo_note':
      'Nota',
  'excel.undo_number_format':
      'format nombor',
  'excel.undo_paste':
      'tampal',
  'excel.undo_replace':
      'ganti',
  'excel.undo_sort':
      'isih',
  'excel.undo_split':
      'Teks ke lajur',
  'excel.undo_tab_color':
      'Warna tab',
  'excel.undo_table_format':
      'Format jadual',
  'excel.undo_typing':
      'menaip',
  'excel.undo_unhide':
      'Tunjukkan',
  'excel.undo_unhide_sheet':
      'Tunjukkan helaian',
  'excel.undo_unmerge':
      'nyahgabung sel',
  'excel.undo_validation':
      'Pengesahan data',
  'excel.undo_wrap':
      'balut teks',
  'excel.undone':
      'Dibuat asal: {what}',
  'excel.unfreeze_panes':
      'Nyahbeku anak tetingkap (baris/lajur tetap)',
  'excel.unhide_sheet':
      'Tunjukkan helaian',
  'excel.unit_chars':
      'aksara',
  'excel.unit_points':
      'mata',
  'excel.unmerge':
      'Nyahgabung sel',
  'excel.val_bad_bound':
      'Masukkan nilai had yang sah',
  'excel.val_clear':
      'Kosongkan peraturan',
  'excel.val_continue':
      'Masukkan juga?',
  'excel.val_date_hint':
      'Tarikh (dd.mm.yyyy)',
  'excel.val_error':
      'Mesej ralat (pilihan)',
  'excel.val_formula_hint':
      'Formula (cth. =ISTEXT(A1))',
  'excel.val_invalid':
      'Nilai ini tidak sepadan dengan peraturan yang ditetapkan untuk sel ini',
  'excel.val_invalid_title':
      'Entri tidak sah',
  'excel.val_list_empty':
      'Masukkan sekurang-kurangnya satu pilihan',
  'excel.val_list_hint':
      'Pilihan (dipisahkan koma)',
  'excel.val_list_none':
      'Sumber senarai tiada nilai',
  'excel.val_list_source':
      'Atau julat: =Senarai!A1:A9',
  'excel.val_max':
      'Maksimum',
  'excel.val_min':
      'Minimum',
  'excel.val_prompt':
      'Mesej input (pilihan)',
  'excel.val_prompt_title':
      'Tajuk mesej input (pilihan)',
  'excel.val_value':
      'Nilai',
  'excel.validation':
      'Pengesahan data',
  'excel.wrap_text':
      'Balut teks',
  'excel.zoom_in':
      'Zum masuk',
  'excel.zoom_out':
      'Zum keluar',
  'excel.zoom_reset':
      'Tetapkan semula zum (100%)',
  'word.add_paragraph':
      'Tambah perenggan',
  'word.add_paragraph_below':
      'Tambah perenggan di bawah',
  'word.align_cycle':
      'Penjajaran',
  'word.auto_color':
      'Automatik',
  'word.autoformat':
      'Word: Format automatik semasa menaip',
  'word.autoformat_sub':
      'Huruf besar awal ayat, -- → —, ruang berganda jadi satu, "- " atau "1. " memulakan senarai',
  'word.bullet_list':
      'Senarai berbulet',
  'word.bullets':
      'Bulet',
  'word.clear_format':
      'Kosongkan format',
  'word.color_pick':
      'Warna teks',
  'word.columns':
      'Lajur',
  'word.columns_n':
      '{n} lajur',
  'word.comment_author':
      'Nama anda',
  'word.comment_author_hint':
      'Dipaparkan sebagai penulis komen anda',
  'word.comment_new':
      'Komen baharu',
  'word.comment_post':
      'Hantar',
  'word.comment_reopen':
      'Buka semula',
  'word.comment_replies':
      '{n} balasan',
  'word.comment_reply':
      'Balas',
  'word.comment_resolve':
      'Selesaikan',
  'word.comment_text':
      'Komen anda',
  'word.comments':
      'Komen',
  'word.comments_none':
      'Tiada komen dalam dokumen',
  'word.control_fill':
      'Isi medan',
  'word.control_no_items':
      'Senarai ini tiada pilihan',
  'word.control_value':
      'Nilai',
  'word.count_chars':
      'Aksara (dengan ruang)',
  'word.count_chars_ns':
      'Aksara (tanpa ruang)',
  'word.count_paras':
      'Perenggan',
  'word.count_words':
      'Perkataan',
  'word.cut':
      'Potong',
  'word.delete_image':
      'Padam gambar',
  'word.delete_paragraph':
      'Padam perenggan',
  'word.done':
      'Selesai',
  'word.edit_link':
      'Sunting pautan',
  'word.edit_on_page':
      'Sunting pada halaman',
  'word.edit_page':
      'Sunting pada halaman (lama)',
  'word.endnote_edit':
      'Nota hujung {n}',
  'word.find':
      'Cari dan ganti',
  'word.find_hint':
      'Cari dalam dokumen',
  'word.font_grow':
      'Besarkan saiz fon',
  'word.font_shrink':
      'Kecilkan saiz fon',
  'word.font_size':
      'Saiz',
  'word.footnote_edit':
      'Nota kaki {n}',
  'word.footnote_rich':
      'Nota kaki ini mengandungi kandungan kaya dan tidak boleh disunting di sini',
  'word.footnote_text':
      'Teks nota kaki',
  'word.format_painter':
      'Pengecat format',
  'word.format_painter_hint':
      'Format disalin — pilih teks untuk menggunakannya',
  'word.format_painter_locked':
      'Pengecat format dikunci — ketik ✕ untuk selesai',
  'word.goto_page':
      'Pergi ke halaman',
  'word.goto_page_hint':
      'Antara 1 dan {total}',
  'word.hf_apply':
      'Guna',
  'word.hf_footer':
      'Pengaki',
  'word.hf_header':
      'Pengepala',
  'word.hf_page':
      'Tambah nombor halaman',
  'word.hf_rich':
      'Pengepala/pengaki ini mengandungi gambar atau tab jadi tidak boleh disunting di sini.',
  'word.hf_saved':
      'Pengepala/pengaki dikemas kini',
  'word.highlight':
      'Sorot',
  'word.highlight_pick':
      'Warna sorotan',
  'word.img_alt':
      'Teks alternatif',
  'word.img_alt_hint':
      'Perihalan ringkas untuk orang yang tidak dapat melihat gambar',
  'word.img_failed':
      'Gambar tidak dapat dibaca',
  'word.img_large':
      'Lebar halaman (6 inci)',
  'word.img_medium':
      'Sederhana (4 inci)',
  'word.img_replace':
      'Tukar',
  'word.img_resize_title':
      'Saiz gambar',
  'word.img_size':
      'Saiz',
  'word.img_small':
      'Kecil (2 inci)',
  'word.img_width_pct':
      'Lebar: {n}%',
  'word.insert_break':
      'Pemisah halaman',
  'word.insert_date':
      'Tarikh & masa',
  'word.insert_endnote':
      'Nota hujung',
  'word.insert_footnote':
      'Nota kaki',
  'word.insert_hf':
      'Pengepala & pengaki',
  'word.insert_image':
      'Sisip gambar',
  'word.insert_link':
      'Pautan',
  'word.insert_rule':
      'Garis mengufuk',
  'word.insert_symbol':
      'Simbol',
  'word.insert_table':
      'Jadual',
  'word.landscape':
      'Landskap',
  'word.line_spacing':
      'Jarak baris',
  'word.link_bad':
      'Pautan tidak dapat dibuka',
  'word.link_insert':
      'Sisip pautan',
  'word.link_open':
      'Buka',
  'word.link_remove':
      'Buang',
  'word.link_text':
      'Teks untuk dipaparkan',
  'word.link_url':
      'Alamat (https://…)',
  'word.list_gallery':
      'Gaya senarai',
  'word.live_edit_unsafe':
      'Penyuntingan langsung tidak selamat dalam dokumen ini (perenggan tidak sepadan: {web}/{ours}). Gunakan ⋮ > Penyunting teks.',
  'word.margins':
      'Margin',
  'word.mobile_flow':
      'Paparan mudah alih',
  'word.mobile_view':
      'Paparan mudah alih',
  'word.month_names':
      'Januari,Februari,Mac,April,Mei,Jun,Julai,Ogos,September,Oktober,November,Disember',
  'word.multilevel':
      'Senarai pelbagai peringkat',
  'word.navigation':
      'Navigasi',
  'word.no_headings':
      'Tiada tajuk. Perenggan bergaya tajuk disenaraikan di sini.',
  'word.no_highlight':
      'Tanpa sorotan',
  'word.no_image_here':
      'Tiada gambar dalam perenggan pada kursor. Ketik di sebelah gambar dahulu.',
  'word.numbered_list':
      'Senarai bernombor',
  'word.numbering':
      'Penomboran',
  'word.opening_preview':
      'Sedang dibuka — penyuntingan akan sedia sebentar lagi; memaparkan perenggan pertama',
  'word.orientation':
      'Orientasi',
  'word.page_break':
      'Pemisah halaman',
  'word.page_layout':
      'Paparan halaman',
  'word.page_of':
      'Halaman {n} / {total}',
  'word.page_view':
      'Paparan halaman',
  'word.paper_size':
      'Saiz',
  'word.paste':
      'Tampal',
  'word.portrait':
      'Potret',
  'word.recent_colors':
      'Warna terkini',
  'word.recent_symbols':
      'Baru digunakan',
  'word.redo':
      'Buat semula',
  'word.redone':
      'Dibuat semula: {what}',
  'word.replace_hint':
      'Ganti dengan',
  'word.replace_n':
      '{n} diganti',
  'word.replace_needs_edit':
      'Beralih ke mod sunting untuk mengganti',
  'word.review_page':
      'Paparan halaman',
  'word.rtl':
      'Kanan-ke-kiri',
  'word.save_failed':
      'Gagal menyimpan: {error}',
  'word.saved_as_docx':
      'Disimpan sebagai {name} (fail UDF asal anda tidak diubah)',
  'word.search_short':
      'Cari',
  'word.select_text_first':
      'Pilih teks dalam dokumen dahulu',
  'word.space_after':
      'Jarak selepas perenggan',
  'word.space_before':
      'Jarak sebelum perenggan',
  'word.spellcheck':
      'Word: semakan ejaan dan pembetulan automatik',
  'word.spellcheck_sub':
      'Garis beralun merah, cadangan papan kekunci, huruf besar awal ayat',
  'word.st_h1':
      'Tajuk 1',
  'word.st_h2':
      'Tajuk 2',
  'word.st_h3':
      'Tajuk 3',
  'word.st_list':
      'Perenggan senarai',
  'word.st_normal':
      'Biasa',
  'word.st_quote':
      'Petikan',
  'word.st_subtitle':
      'Subtajuk',
  'word.st_title':
      'Tajuk',
  'word.standard_colors':
      'Warna standard',
  'word.subscript':
      'Subskrip',
  'word.superscript':
      'Superskrip',
  'word.tab_home':
      'Laman Utama',
  'word.tab_insert':
      'Sisip',
  'word.tab_layout':
      'Susun atur',
  'word.tab_picture':
      'Gambar',
  'word.tab_review':
      'Semak',
  'word.tab_table':
      'Jadual',
  'word.tab_view':
      'Paparan',
  'word.table_failed':
      'Jadual tidak dapat disisipkan di sini',
  'word.table_insert':
      'Sisip jadual',
  'word.table_size':
      'Jadual {r} × {c}',
  'word.tbl_banded':
      'Baris berjalur',
  'word.tbl_banded_short':
      'Berjalur',
  'word.tbl_col_left':
      'Sisip lajur di kiri',
  'word.tbl_col_left_short':
      'Lajur +←',
  'word.tbl_col_right':
      'Sisip lajur di kanan',
  'word.tbl_col_right_short':
      'Lajur +→',
  'word.tbl_del':
      'Padam jadual',
  'word.tbl_del_col':
      'Padam lajur',
  'word.tbl_del_col_short':
      'Pdm lajur',
  'word.tbl_del_row':
      'Padam baris',
  'word.tbl_del_row_short':
      'Pdm baris',
  'word.tbl_del_short':
      'Pdm jadual',
  'word.tbl_header':
      'Baris pengepala',
  'word.tbl_header_short':
      'Pengepala',
  'word.tbl_row_above':
      'Sisip baris di atas',
  'word.tbl_row_below':
      'Sisip baris di bawah',
  'word.tbl_row_down_short':
      'Baris +↓',
  'word.tbl_row_up_short':
      'Baris +↑',
  'word.tbl_shade':
      'Lorekan sel',
  'word.tbl_shade_none':
      'Tanpa lorekan',
  'word.text_color':
      'Warna teks',
  'word.text_editor':
      'Paparan teks biasa',
  'word.theme_colors':
      'Warna tema',
  'word.track_accept':
      'Terima semua perubahan',
  'word.track_changes':
      'Jejak perubahan',
  'word.track_confirm_accept':
      '{n} perubahan terjejak akan diterima. Tindakan ini tidak boleh dibuat asal.',
  'word.track_confirm_reject':
      '{n} perubahan terjejak akan ditolak. Tindakan ini tidak boleh dibuat asal.',
  'word.track_none':
      'Tiada perubahan terjejak',
  'word.track_off':
      'Penjejakan perubahan dimatikan',
  'word.track_on':
      'Penjejakan perubahan dihidupkan: sisipan dan pemadaman anda akan ditandakan',
  'word.track_reject':
      'Tolak semua perubahan',
  'word.translate_selection':
      'Terjemah pilihan',
  'word.undo':
      'Buat asal',
  'word.undo_add_paragraph':
      'tambah perenggan',
  'word.undo_delete_paragraph':
      'padam perenggan',
  'word.undone':
      'Dibuat asal: {what}',
  'word.word_count':
      'Bilangan perkataan',
  'word.words_n':
      '{n} perkataan',
  'word.zoom_in':
      'Zum masuk',
  'word.zoom_out':
      'Zum keluar',
  'sl.actions':
      'Tindakan slaid',
  'sl.add_slide_short':
      'Slaid',
  'sl.align':
      'Penjajaran',
  'sl.background':
      'Warna latar belakang',
  'sl.bg_default':
      'Lalai susun atur',
  'sl.bring_front':
      'Bawa ke hadapan',
  'sl.bullets':
      'Bulet',
  'sl.change_layout':
      'Tukar susun atur',
  'sl.copied':
      'Bentuk disalin',
  'sl.cut':
      'Potong',
  'sl.delete':
      'Padam slaid',
  'sl.delete_body':
      'Padam slaid {n}? Tindakan ini tidak boleh dibuat asal (fail tidak berubah sehingga anda menyimpan).',
  'sl.delete_shape':
      'Padam bentuk',
  'sl.design':
      'Reka bentuk',
  'sl.done':
      'Selesai',
  'sl.duplicate':
      'Gandakan slaid',
  'sl.duplicate_shape':
      'Gandakan',
  'sl.duplicated':
      'Slaid digandakan.',
  'sl.edit_text':
      'Sunting teks',
  'sl.fill':
      'Isian',
  'sl.fullscreen':
      'Tayangan slaid skrin penuh',
  'sl.go_to_title':
      'Pergi ke slaid',
  'sl.goto_hint':
      'Antara 1 dan {total}',
  'sl.hidden':
      'Tersembunyi',
  'sl.hidden_tip':
      'Dilangkau dalam tayangan slaid',
  'sl.hide':
      'Sembunyikan slaid',
  'sl.image_added':
      'Gambar ditambah — alihkan atau ubah saiznya dalam PowerPoint. Jangan lupa simpan.',
  'sl.indent_less':
      'Kurangkan inden',
  'sl.indent_more':
      'Tambah inden',
  'sl.insert':
      'Sisip',
  'sl.insert_image':
      'Sisip gambar',
  'sl.line':
      'Garis',
  'sl.line_dashed':
      'Putus-putus',
  'sl.line_width':
      'Lebar: {pt} pt',
  'sl.match_pos':
      '{n} / {total}',
  'sl.move_down':
      'Alih ke bawah',
  'sl.move_shape':
      'Alihkan bentuk',
  'sl.move_up':
      'Alih ke atas',
  'sl.new_slide':
      'Slaid baharu',
  'sl.next_cell':
      'Sel seterusnya',
  'sl.no_fill':
      'Tanpa isian',
  'sl.no_line':
      'Tanpa garis',
  'sl.no_match':
      'Tiada padanan',
  'sl.no_structure':
      'Struktur slaid tidak boleh disunting dalam fail ini (data pembentangan tiada).',
  'sl.none':
      'Tiada slaid ditemui.',
  'sl.notes_edit':
      'Nota penceramah',
  'sl.notes_hint':
      'Taip nota yang hanya anda lihat semasa pembentangan',
  'sl.notes_next':
      'Slaid seterusnya dengan nota',
  'sl.notes_prev':
      'Slaid sebelumnya dengan nota',
  'sl.notes_title':
      'Slaid {n} · nota',
  'sl.notes_toggle':
      'Nota penceramah',
  'sl.nothing_to_play':
      'Tiada slaid untuk ditayangkan dalam fail ini.',
  'sl.numbering':
      'Penomboran',
  'sl.open_failed':
      'Gagal dibuka: {error}',
  'sl.opening_preview':
      'Sedang dibuka — penyuntingan akan sedia sebentar lagi; memaparkan slaid pertama',
  'sl.outline':
      'Rangka',
  'sl.paste':
      'Tampal',
  'sl.pdf_failed':
      'PDF tidak dapat dibuat: {error}',
  'sl.pdf_progress':
      'Memaparkan slaid {n}/{total}…',
  'sl.pdf_share':
      'Pembentangan (PDF)',
  'sl.play':
      'Main',
  'sl.prev_cell':
      'Sel sebelumnya',
  'sl.prompt_body':
      'Ketik untuk menambah teks',
  'sl.prompt_subtitle':
      'Ketik untuk menambah subtajuk',
  'sl.prompt_title':
      'Ketik untuk menambah tajuk',
  'sl.quick_arrange':
      'Susun',
  'sl.quick_style':
      'Gaya',
  'sl.search_hint':
      'Cari dalam slaid',
  'sl.send_back':
      'Hantar ke belakang',
  'sl.shape':
      'Tambah bentuk',
  'sl.slide_of':
      'Slaid {n} / {total}',
  'sl.sorter':
      'Penyusun slaid',
  'sl.tab_font':
      'Fon',
  'sl.tab_paragraph':
      'Perenggan',
  'sl.table':
      'Jadual',
  'sl.table_added':
      'Jadual disisipkan — ketik sel untuk menaip.',
  'sl.table_insert':
      'Sisip jadual',
  'sl.table_size':
      '{r} baris × {c} lajur',
  'sl.text_box':
      'Kotak teks',
  'sl.text_box_default':
      'Teks',
  'sl.thumbnails':
      'Imej kecil',
  'sl.to_pdf':
      'PDF',
  'sl.tr_preview':
      'Pratonton',
  'sl.transition':
      'Peralihan',
  'sl.transparency':
      'Ketelusan',
  'sl.transparency_needs_fill':
      'Beri bentuk isian pepejal dahulu.',
  'sl.undo_notes':
      'Suntingan nota',
  'sl.undo_outline':
      'Suntingan rangka',
  'sl.undo_text':
      'Suntingan teks',
  'sl.unhide':
      'Tunjukkan slaid',
};
