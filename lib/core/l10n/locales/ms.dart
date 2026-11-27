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
      'Tidak lebih kecil ({size}) — fail asal dikekalkan',
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
  'xp.agg':
      'Fungsi',
  'xp.agg_header':
      '{agg} bagi {field}',
  'xp.allow_edit':
      'Benarkan suntingan julat',
  'xp.allow_edit_off':
      'Julat dikunci semula',
  'xp.allow_edit_on':
      'Julat dipilih boleh disunting pada helaian yang dilindungi',
  'xp.audit_none':
      'Tiada rujukan untuk dijejak pada helaian ini',
  'xp.blank':
      '(kosong)',
  'xp.chart_combo':
      'Kombo (siri terakhir sebagai garisan)',
  'xp.chart_options':
      'Pilihan carta',
  'xp.chart_secondary':
      'Garisan pada paksi sekunder',
  'xp.chart_share_pdf':
      'Kongsi sebagai PDF',
  'xp.chart_share_png':
      'Kongsi sebagai imej',
  'xp.chart_style':
      'Gaya {n}',
  'xp.chart_trend':
      'Garis arah aliran',
  'xp.collapse':
      'Runtuhkan kumpulan',
  'xp.color_scale':
      'Skala warna',
  'xp.cols':
      'Lajur (pilihan)',
  'xp.cond_formula':
      'Peraturan berdasarkan formula…',
  'xp.cond_formula_hint':
      'Syarat relatif kepada {cell} (cth. ={cell}>100)',
  'xp.cond_manage':
      'Urus peraturan…',
  'xp.cond_none':
      'Tiada peraturan pemformatan bersyarat pada helaian ini',
  'xp.cond_visual':
      'Skala, bar, ikon',
  'xp.cycle_warn':
      'Rujukan bulat: {cell} merujuk dirinya sendiri (secara tidak langsung)',
  'xp.data_bar':
      'Bar data (biru)',
  'xp.data_bar_green':
      'Bar data (hijau)',
  'xp.data_bar_plain':
      'Bar data',
  'xp.delim_auto':
      'Automatik',
  'xp.delim_comma':
      'Koma',
  'xp.delim_pipe':
      'Palang tegak',
  'xp.delim_semi':
      'Koma bertitik',
  'xp.delim_tab':
      'Tab',
  'xp.delimiter':
      'Pembatas',
  'xp.density':
      'Kepadatan',
  'xp.density_comfortable':
      'Selesa',
  'xp.density_compact':
      'Padat',
  'xp.density_normal':
      'Biasa',
  'xp.enc_cp1254':
      'Windows Turki',
  'xp.enc_utf8':
      'UTF-8',
  'xp.encoding':
      'Pengekodan',
  'xp.err_calc':
      '#CALC!: hasilnya kosong (cth. FILTER tidak menemui baris).',
  'xp.err_cycle':
      'Rujukan bulat: formula merujuk dirinya sendiri.',
  'xp.err_div0':
      '#DIV/0!: pembahagian dengan sifar atau dengan sel kosong.',
  'xp.err_na':
      '#N/A: nilai yang dicari tidak ditemui.',
  'xp.err_name':
      '#NAME?: fungsi atau nama tidak dikenali — semak ejaannya.',
  'xp.err_null':
      '#NULL!: kedua-dua julat tidak bersilang.',
  'xp.err_num':
      '#NUM!: nombor tidak sah (terlalu besar, punca nombor negatif…).',
  'xp.err_ref':
      '#REF!: sel yang dirujuk sudah tiada (baris/lajur dipadam).',
  'xp.err_spill':
      '#SPILL!: sel destinasi limpahan tatasusunan tidak kosong — kosongkannya.',
  'xp.err_value':
      '#VALUE!: jenis salah — teks (atau nombor dengan ruang) di tempat yang memerlukan nombor.',
  'xp.err_why':
      'Mengapa ralat ini?',
  'xp.expand':
      'Kembangkan kumpulan',
  'xp.filter':
      'Tapis (pilihan)',
  'xp.fit_width':
      'Muatkan pada lebar halaman',
  'xp.goal_bad_input':
      'Rujukan sel atau nilai tidak sah',
  'xp.goal_by':
      'Dengan menukar sel',
  'xp.goal_done':
      'Penyelesaian: {cell} = {value}',
  'xp.goal_failed':
      'Penyelesaian tidak ditemui',
  'xp.goal_need_formula':
      'Sel yang ditetapkan mesti mengandungi formula',
  'xp.goal_need_value':
      'Sel yang ditukar mesti mengandungi nilai, bukan formula',
  'xp.goal_seek':
      'Pencarian matlamat',
  'xp.goal_set':
      'Tetapkan sel (formula)',
  'xp.goal_to':
      'Kepada nilai',
  'xp.grand_total':
      'Jumlah besar',
  'xp.group':
      'Kumpulkan baris',
  'xp.icon_set':
      'Set ikon: lampu isyarat',
  'xp.icon_set_plain':
      'Set ikon',
  'xp.import':
      'Import (CSV/ODS)',
  'xp.import_done':
      '{n} helaian diimport',
  'xp.import_go':
      'Import ke helaian baharu',
  'xp.import_rows':
      '{n} baris',
  'xp.landscape':
      'Landskap',
  'xp.link':
      'Sisip pautan',
  'xp.link_cell':
      'Sel pada {name}',
  'xp.link_sheet':
      'Dalam buku kerja ini: {name}',
  'xp.link_web':
      'Alamat web',
  'xp.no_group':
      'Baris ini tidak berada dalam kumpulan',
  'xp.none':
      '— tiada —',
  'xp.note_reply':
      'Balas nota',
  'xp.painter':
      'Pengecat format',
  'xp.painter_hint':
      'Ketik sel untuk menggunakan format',
  'xp.password':
      'Kata laluan',
  'xp.password_again':
      'Kata laluan (ulang)',
  'xp.password_cancelled':
      'Kata laluan tidak dimasukkan — fail tidak dibuka',
  'xp.password_mismatch':
      'Kata laluan tidak sepadan',
  'xp.password_open':
      'Buku kerja ini dilindungi kata laluan',
  'xp.password_remove':
      'Buang kata laluan',
  'xp.password_removed':
      'Kata laluan dibuang — disimpan tanpa penyulitan',
  'xp.password_set':
      'Lindungi dengan kata laluan',
  'xp.password_set_done':
      'Fail akan disulitkan apabila disimpan',
  'xp.password_unsupported':
      'Jenis penyulitan ini tidak disokong (Excel lama)',
  'xp.password_wrong':
      'Kata laluan salah',
  'xp.pivot':
      'Jadual pangsi',
  'xp.pivot_create':
      'Cipta',
  'xp.pivot_refresh':
      'Segar semula pangsi',
  'xp.pivot_refreshed':
      'Pangsi disegarkan semula',
  'xp.pivot_sheet':
      'Pangsi {n}',
  'xp.pivot_source_gone':
      'Helaian sumber sudah tiada — tidak dapat disegarkan semula',
  'xp.portrait':
      'Potret',
  'xp.print_area_clear':
      'Kosongkan kawasan cetakan',
  'xp.print_area_cleared':
      'Kawasan cetakan dikosongkan',
  'xp.print_area_set':
      'Kawasan cetakan ditetapkan',
  'xp.print_area_set_btn':
      'Tetapkan pilihan sebagai kawasan cetakan',
  'xp.print_done':
      'PDF sedia',
  'xp.print_empty':
      'Tiada apa untuk dicetak',
  'xp.print_go':
      'Cipta PDF',
  'xp.print_grid':
      'Garis grid',
  'xp.print_group':
      'Cetak dan lindungi',
  'xp.print_page':
      'Halaman {n} / {t}',
  'xp.print_pdf':
      'Susun atur cetakan → PDF',
  'xp.protect_no_pw':
      'Lindungi tanpa kata laluan',
  'xp.protect_sheet':
      'Lindungi helaian',
  'xp.protect_with_pw':
      'Lindungi dengan kata laluan…',
  'xp.protected':
      'Helaian dilindungi',
  'xp.protected_cell':
      'Sel ini dikunci pada helaian yang dilindungi',
  'xp.repeat_rows':
      'Baris pengepala diulang pada setiap halaman',
  'xp.ribbon_full':
      'Reben penuh',
  'xp.ribbon_simple':
      'Reben ringkas',
  'xp.rows':
      'Baris',
  'xp.scale_rg':
      'Skala warna: merah → hijau',
  'xp.scale_ryg':
      'Skala warna: merah → kuning → hijau',
  'xp.scale_wb':
      'Skala warna: putih → biru',
  'xp.sparkline':
      'Sparkline',
  'xp.sparkline_needs_range':
      'Pilih julat data dahulu',
  'xp.std_colors':
      'Warna standard',
  'xp.subtotal':
      'Subjumlah',
  'xp.subtotal_by':
      'Pada setiap perubahan dalam',
  'xp.subtotal_go':
      'Cipta subjumlah',
  'xp.subtotal_sheet':
      'Subjumlah {name}',
  'xp.subtotal_suffix':
      ' Jumlah',
  'xp.subtotal_sum':
      'Tambah subjumlah kepada',
  'xp.theme_colors':
      'Warna tema',
  'xp.toggle_group':
      'Runtuhkan/kembangkan kumpulan',
  'xp.trace_clear':
      'Buang anak panah',
  'xp.trace_dep':
      'Jejak tanggungan',
  'xp.trace_prec':
      'Jejak duluan',
  'xp.undo_sparkline':
      'Sisip sparkline',
  'xp.ungroup':
      'Nyahkumpul',
  'xp.unprotect':
      'Nyahlindung helaian',
  'xp.unprotected':
      'Helaian dinyahlindungi',
  'xp.values':
      'Nilai',
  'sp.add_anim':
      'Tambah animasi',
  'sp.add_ph':
      'Tambah pemegang tempat',
  'sp.add_row':
      'Tambah kategori',
  'sp.add_section':
      'Tambah seksyen',
  'sp.add_series':
      'Tambah siri',
  'sp.add_show':
      'Tambah tayangan',
  'sp.align_hint':
      'Pilih bentuk untuk dijajarkan',
  'sp.anim_order':
      'Susunan animasi',
  'sp.anim_pick_fx':
      'Kesan',
  'sp.anim_pick_shape':
      'Bentuk yang mana?',
  'sp.animations':
      'Animasi',
  'sp.applied':
      'Digunakan',
  'sp.apply':
      'Guna',
  'sp.arrange_title':
      'Slaid {n}',
  'sp.body_size':
      'Saiz isi',
  'sp.chart_data':
      'Data carta',
  'sp.chart_edit':
      'Sunting data carta',
  'sp.chart_from_table':
      'Carta daripada jadual',
  'sp.chart_insert':
      'Sisip carta',
  'sp.chart_title':
      'Tajuk carta',
  'sp.conn_elbow':
      'Siku',
  'sp.conn_straight':
      'Lurus',
  'sp.connect':
      'Penyambung',
  'sp.connect_none':
      'Tiada bentuk lain untuk disambungkan',
  'sp.connect_to':
      'Sambung ke bentuk yang mana?',
  'sp.copy_suffix':
      'salinan',
  'sp.counter':
      'Kira detik langsung',
  'sp.counter_added':
      'Kira detik ditambah',
  'sp.counter_hint':
      'Mengira detik semasa tayangan',
  'sp.counter_minutes':
      'Berapa minit?',
  'sp.crop':
      'Pangkas',
  'sp.crop_b':
      'Bawah',
  'sp.crop_l':
      'Kiri',
  'sp.crop_r':
      'Kanan',
  'sp.crop_shape':
      'Pangkas kepada bentuk',
  'sp.crop_t':
      'Atas',
  'sp.custom_shows':
      'Tayangan tersuai',
  'sp.delete':
      'Padam',
  'sp.draw':
      'Lukis tandatangan anda',
  'sp.font_major':
      'Fon tajuk',
  'sp.font_minor':
      'Fon isi',
  'sp.fx_appear':
      'Muncul',
  'sp.fx_emph':
      'Penekanan',
  'sp.fx_entr':
      'Masuk',
  'sp.fx_exit':
      'Keluar',
  'sp.fx_fade':
      'Pudar',
  'sp.fx_fly':
      'Terbang masuk',
  'sp.fx_other':
      'Animasi',
  'sp.fx_path':
      'Laluan gerakan',
  'sp.fx_spin':
      'Pusing',
  'sp.fx_wipe':
      'Sapu',
  'sp.fx_zoom':
      'Zum',
  'sp.g_arrange':
      'Susun',
  'sp.g_design':
      'Reka bentuk',
  'sp.g_insert':
      'Sisip',
  'sp.g_show':
      'Tayangan & eksport',
  'sp.g_slides':
      'Slaid',
  'sp.glow':
      'Pendar',
  'sp.gradient':
      'Isian kecerunan',
  'sp.hex_input':
      'Taip kod warna (RRGGBB)',
  'sp.hide':
      'Sembunyikan',
  'sp.image_hint':
      'Pilih foto tandatangan atau PNG lutsinar.',
  'sp.inherited':
      'daripada induk',
  'sp.layers':
      'Lapisan',
  'sp.layers_align':
      'Lapisan & penjajaran',
  'sp.layers_hint':
      'Susunan Z, sembunyi, jajar, agih',
  'sp.layout':
      'Susun atur',
  'sp.layout_dup':
      'Gandakan susun atur',
  'sp.layout_hint':
      'Ketik: pilih · seret: alih · sudut kanan bawah: ubah saiz',
  'sp.layouts':
      'Susun atur',
  'sp.link':
      'Pautan / tindakan',
  'sp.link_slide':
      'Slaid tertentu',
  'sp.link_url':
      'Alamat web',
  'sp.master':
      'Induk slaid & tema',
  'sp.master_bg':
      'Warna latar belakang',
  'sp.master_hint':
      'Susun atur, pemegang tempat, warna dan fon tema',
  'sp.master_n':
      'Induk {n}',
  'sp.master_style':
      'Gaya induk',
  'sp.media_added':
      'Media ditambah',
  'sp.media_hint':
      'Dimainkan apabila diketik dalam tayangan',
  'sp.media_insert':
      'Sisip audio / video',
  'sp.media_too_big':
      'Fail terlalu besar (maks 150 MB)',
  'sp.mic_denied':
      'Kebenaran mikrofon ditolak',
  'sp.move_down':
      'Alih ke bawah',
  'sp.move_up':
      'Alih ke atas',
  'sp.no_anims':
      'Tiada animasi pada slaid ini',
  'sp.no_chart':
      'Data carta tidak dapat dibaca',
  'sp.no_sections':
      'Tiada seksyen. Tambah satu bermula daripada sesuatu slaid.',
  'sp.no_shapes':
      'Tiada bentuk pada slaid ini',
  'sp.no_shows':
      'Tiada tayangan tersuai',
  'sp.no_smartart':
      'Tiada SmartArt dalam dek ini',
  'sp.off':
      'Mati',
  'sp.on':
      'Hidup',
  'sp.pick_color':
      'Pilih warna',
  'sp.pick_image':
      'Pilih imej',
  'sp.png_all':
      'Semua slaid sebagai PNG (zip)',
  'sp.png_one':
      'Kongsi slaid ini sebagai PNG',
  'sp.presenter_hint':
      'Nota, slaid seterusnya dan masa bersebelahan',
  'sp.record':
      'Latihan & rakam narasi',
  'sp.record_done':
      'Narasi ditambah',
  'sp.record_hint':
      'Suara dan masa setiap slaid disimpan; tayangan maju sendiri',
  'sp.record_save':
      'Narasi dirakam untuk {n} slaid. Tambah ke dek?',
  'sp.reflection':
      'Pantulan',
  'sp.rehearse':
      'Latih masa',
  'sp.rehearse_done':
      'Masa disimpan',
  'sp.rehearse_hint':
      'Masa pada setiap slaid diukur; tayangan kemudian maju sendiri',
  'sp.rehearse_save':
      'Latihan mengambil masa {t} ({n} slaid). Simpan masanya?',
  'sp.remove_bg':
      'Buang latar belakang',
  'sp.remove_bg_downloading':
      'Model sedang dimuat turun; cuba lagi sebentar lagi',
  'sp.remove_bg_failed':
      'Latar belakang tidak dapat dibuang',
  'sp.remove_bg_hint':
      'Pada peranti (ML Kit); model dimuat turun semasa penggunaan pertama',
  'sp.remove_bg_unavailable':
      'Tidak tersedia pada peranti ini',
  'sp.remove_bg_working':
      'Membuang latar belakang…',
  'sp.remove_row':
      'Buang baris',
  'sp.remove_series':
      'Buang siri',
  'sp.rename':
      'Namakan semula',
  'sp.saved_list':
      'Tandatangan tersimpan',
  'sp.section_default':
      'Seksyen {n}',
  'sp.section_first':
      'Seksyen lalai',
  'sp.section_name':
      'Nama seksyen',
  'sp.section_start':
      'Slaid mana yang memulakan seksyen?',
  'sp.sections':
      'Seksyen',
  'sp.sections_hint':
      'Kumpulkan slaid; tayangkan subset pilihan',
  'sp.sections_title':
      'Seksyen & tayangan tersuai',
  'sp.selected_n':
      '{n} dipilih',
  'sp.shadow':
      'Bayang',
  'sp.shape_library':
      'Pustaka bentuk',
  'sp.shape_library_hint':
      'Asas, anak panah, bintang, petak teks, carta alir, butang tindakan',
  'sp.shape_tools':
      'Alat',
  'sp.show':
      'Tayangkan',
  'sp.show_default':
      'Tayangan {n}',
  'sp.show_name':
      'Nama tayangan',
  'sp.slide_n':
      'Slaid {n}',
  'sp.slides_n':
      '{n} slaid',
  'sp.smartart':
      'Tukar SmartArt kepada bentuk',
  'sp.smartart_done':
      'SmartArt ditukar kepada bentuk',
  'sp.smartart_hint':
      'Menjadi kumpulan bentuk yang boleh disunting',
  'sp.suggested':
      'Dicadangkan',
  'sp.tab_draw':
      'Lukis',
  'sp.tab_image':
      'Imej',
  'sp.tab_type':
      'Taip',
  'sp.table_no_data':
      'Jadual tiada data carta',
  'sp.table_style':
      'Gaya jadual',
  'sp.templates':
      'Galeri templat',
  'sp.templates_hint':
      '8 tema kemas — kandungan dikekalkan',
  'sp.theme_colors':
      'Warna tema',
  'sp.title_size':
      'Saiz tajuk',
  'sp.tools':
      'Alat',
  'sp.tpl_sample':
      'Contoh bulet',
  'sp.type_hint':
      'Nama atau inisial anda',
  'sp.video_encoding':
      'Mengekod video…',
  'sp.video_export':
      'Eksport sebagai video (MP4)',
  'sp.video_hint':
      'Setiap slaid untuk tempoh tertentu; masa rakaman dikekalkan',
  'sp.video_seconds':
      'Saat setiap slaid',
  'sp.video_unavailable':
      'Eksport video tidak tersedia pada peranti ini',
  'near.accept':
      'Terima',
  'near.add_files':
      'Tambah fail',
  'near.add_folder':
      'Tambah folder',
  'near.add_text':
      'Teks',
  'near.asking':
      'Menunggu {name} menerima…',
  'near.bg_ask_body':
      '{name} ingin menghantar {n} fail',
  'near.bg_ask_title':
      'Permintaan fail masuk',
  'near.bg_ch_ask':
      'Permintaan fail masuk',
  'near.bg_ch_quiet':
      'Keterlihatan latar belakang',
  'near.bg_failed':
      'Tidak dapat dihidupkan — adakah Bluetooth hidup dan dibenarkan?',
  'near.bg_note_text':
      'Bluetooth kuasa rendah · permintaan masuk memerlukan kelulusan anda',
  'near.bg_note_title':
      'Kelihatan kepada peranti berdekatan',
  'near.bg_off':
      'Keterlihatan latar belakang dimatikan.',
  'near.bg_on':
      'Peranti berdekatan boleh melihat anda walaupun skrin ini ditutup (Bluetooth kuasa rendah); permintaan ditanya melalui pemberitahuan.',
  'near.bg_switch':
      'Kelihatan di latar belakang',
  'near.bg_waiting':
      '{name} meluluskan — penghantaran akan bermula melalui Wi-Fi',
  'near.bt_denied':
      'Tiada kebenaran Bluetooth · benarkan',
  'near.bt_failed':
      'Bluetooth gagal · cuba lagi',
  'near.bt_none':
      'Tiada Bluetooth LE',
  'near.bt_off':
      'Bluetooth mati · cuba lagi',
  'near.bt_on':
      'Bluetooth',
  'near.bt_wait':
      'Bluetooth…',
  'near.busy_sending':
      'Tunggu penghantaran semasa selesai (atau Henti)',
  'near.clear_sel':
      'Kosongkan',
  'near.clip_files':
      'Tambah {n} fail yang disalin',
  'near.copied':
      'Alamat disalin',
  'near.decline':
      'Tolak',
  'near.dur_lt1':
      'kurang daripada 1 saat',
  'near.dur_ms':
      '{m} min {s} saat',
  'near.dur_s':
      '{s} saat',
  'near.empty_hint':
      'Buka Transfer juga pada peranti lain (Wi-Fi yang sama atau Bluetooth).',
  'near.fail_code':
      'kod pemadanan ditolak',
  'near.fail_identity':
      'identiti penerima berubah, dihentikan demi keselamatan',
  'near.fail_network':
      'sambungan terputus, penerima tidak dapat dicapai',
  'near.fail_receiver':
      'penerima tidak dapat menyimpannya (tiada ruang atau kebenaran)',
  'near.fail_secure':
      'sambungan selamat gagal',
  'near.fail_tile':
      'Tidak dihantar',
  'near.file_done':
      'Selesai',
  'near.folder_files':
      '{n} fail',
  'near.history':
      'Sejarah',
  'near.invite_failed':
      'Tidak dapat mencapai {name}. Dekatkan dan cuba lagi, atau imbas QR.',
  'near.invited':
      'Fail akan dipindahkan selepas {name} menerima — biarkan skrin ini terbuka.',
  'near.inviting':
      'Memberitahu {name}…',
  'near.keep_body':
      'Perkongsian akan ditutup sendiri apabila selesai',
  'near.keep_title':
      'Memindahkan fail',
  'near.missing':
      'sudah tiada',
  'near.network':
      'Rangkaian',
  'near.no_network':
      'Tidak dapat menyediakan rangkaian — hidupkan Wi-Fi atau guna QR.',
  'near.none_received':
      'Belum ada yang diterima.',
  'near.none_sent':
      'Belum ada yang dihantar.',
  'near.offer_dest':
      'Disimpan ke: {dir}',
  'near.offer_more':
      '+{n} lagi',
  'near.offer_sub':
      '{n} item · {size}',
  'near.offer_title':
      '{from} menghantar fail',
  'near.other_ways':
      'Cara lain',
  'near.password':
      'Kata laluan',
  'near.pick_this_folder':
      'Hantar folder ini',
  'near.pick_to_link':
      'Pilih fail & cipta pautan',
  'near.received_tab':
      'Diterima',
  'near.receiving':
      'Menerima',
  'near.receiving_n':
      'Menerima · {n} fail',
  'near.remove_record':
      'Buang daripada senarai',
  'near.reveal':
      'Tunjukkan lokasi',
  'near.searching':
      'Mencari Dosyalarım berdekatan…',
  'near.sec_local':
      'Rangkaian setempat & muat turun',
  'near.sec_prefs':
      'Keutamaan pemindahan',
  'near.selected':
      '{n} item dipilih',
  'near.sending_to':
      'Menghantar kepada {name}',
  'near.sent_fail':
      'Gagal',
  'near.sent_ok':
      'Berjaya',
  'near.sent_partial':
      '{ok} fail dihantar · {bad} tidak dihantar: {why}',
  'near.sent_tab':
      'Dihantar',
  'near.sent_tile':
      'Dihantar',
  'near.sent_to':
      '→ {name}',
  'near.share_apps':
      'Kongsi dengan aplikasi',
  'near.share_no_folder':
      'Folder tidak boleh dikongsi dengan aplikasi; pilih fail di dalamnya.',
  'near.share_sub':
      'Ke telefon berdekatan, atau melalui QR ke mana-mana pelayar — tanpa aplikasi',
  'near.show_all':
      'Tunjukkan semua ({n})',
  'near.starting':
      'Bersiap sedia…',
  'near.step_page':
      '2 · Buka fail',
  'near.step_what':
      '1 · Apa yang dihantar?',
  'near.step_who':
      '2 · Kepada siapa?',
  'near.step_wifi':
      '1 · Sertai rangkaian',
  'near.tap_device':
      'Ketik peranti di bawah untuk menghantar · folder tiba sebagai folder, banyak fail kecil dihantar sebagai satu bungkusan',
  'near.text_copy':
      'Salin',
  'near.text_failed':
      'Teks tidak dapat dihantar — adakah Transfer dibuka dan aplikasinya terkini di sana?',
  'near.text_from':
      '{from} menghantar teks',
  'near.text_hint':
      'Taip atau tampal — muncul pada peranti lain, sedia untuk disalin',
  'near.text_sent':
      'Teks dihantar kepada {name}',
  'near.text_title':
      'Teks untuk dihantar',
  'near.text_wifi_only':
      'Teks hanya dihantar melalui Wi-Fi — kedua-dua peranti mesti berada pada rangkaian yang sama',
  'near.title':
      'Berdekatan',
  'near.trust_this':
      'Percayai peranti ini — jangan tanya lagi',
  'near.trusted':
      'Peranti dipercayai',
  'near.trusted_added':
      '{name} ditambah ke peranti dipercayai',
  'near.trusted_badge':
      'Dipercayai',
  'near.type_address':
      'Jika QR tidak dapat diimbas, taip alamat ini dalam pelayar telefon lain.',
  'near.untrust':
      'Tarik balik kepercayaan',
  'near.via_web':
      'Pelayar (QR)',
  'near.waiting':
      'Sambungan terputus — akan disambung semula dari titik berhenti…',
  'near.web_idle':
      'Muat turun dalam pelayar melalui QR',
  'near.web_idle_sub':
      'Pilih fail dan QR beserta alamat pendek muncul di sini; orang lain mengimbasnya dan memuat turun dalam pelayar.',
  'near.web_same_wifi':
      'Telefon pada Wi-Fi yang sama mengimbasnya dengan kamera — halaman terbuka, satu ketikan untuk memuat turun.',
  'near.web_step1':
      '1. Imbas dengan kamera → sertai rangkaian telefon saya',
  'near.web_step2':
      '2. Sekarang imbas ini → halaman terbuka, fail dimuat turun',
  'near.what_to_send':
      'Apa yang dihantar kepada {name}?',
  'near.wifi_off':
      'Tiada Wi-Fi',
  'near.wifi_on':
      'Wi-Fi',
  'sm.amount_title':
      'Jumlah: {range}',
  'sm.auto':
      'Susun fail baharu secara automatik',
  'sm.auto_sub':
      'Fail baharu disusun secara senyap setiap kali anda kembali ke aplikasi',
  'sm.bg':
      'Hanya semasa mengecas pada Wi-Fi (juga di latar belakang)',
  'sm.bg_sub':
      'Menyusun semasa mengecas pada Wi-Fi, walaupun aplikasi ditutup; paling banyak {n} fail setiap pusingan',
  'sm.camera':
      'Sertakan foto kamera',
  'sm.cap':
      'Paling banyak {cap} fail sehari',
  'sm.cap_day':
      '{d}: {n} fail · {l} amaran kuota',
  'sm.cap_n':
      '{n} fail',
  'sm.cap_none':
      'Tanpa had harian',
  'sm.cap_sub':
      'Hari ini {n}/{cap} · amaran kuota percuma {l}',
  'sm.cap_sub_none':
      'Hari ini {n} fail · amaran kuota percuma {l}',
  'sm.cap_title':
      'Had harian',
  'sm.cap_unlimited':
      'Tanpa had',
  'sm.clutter':
      'Bersihkan',
  'sm.clutter_empty':
      'Tiada yang tidak diperlukan 🎉',
  'sm.clutter_sub':
      'Kad ucapan, meme, foto kabur dan tangkapan tidak sengaja',
  'sm.clutter_title':
      'Bersihkan · {n} tidak diperlukan',
  'sm.delete_sel':
      'Padam ({n})',
  'sm.deselect_one':
      'Nyahpilih',
  'sm.disable':
      'Matikan susunan pintar',
  'sm.done':
      '{n} fail disusun',
  'sm.enable':
      'Hidupkan dan susun',
  'sm.expired':
      'Dokumen tamat tempoh',
  'sm.expiring_soon':
      'Hampir tamat tempoh',
  'sm.fail_blocked':
      'kandungan tidak dijawab atas sebab keselamatan',
  'sm.fail_empty':
      'jawapan kosong, akan dicuba lagi kemudian',
  'sm.failed':
      '{n} fail gagal',
  'sm.filter_title':
      'Kategori pintar',
  'sm.folders':
      'Folder pintar',
  'sm.folders_empty':
      'Belum ada kategori — ketik "Susun sekarang".',
  'sm.group_all':
      'Semua',
  'sm.group_docs':
      'Dokumen',
  'sm.group_finance':
      'Kewangan',
  'sm.group_images':
      'Imej',
  'sm.group_media':
      'Media',
  'sm.hidden_empty':
      'Tiada fail tersembunyi',
  'sm.hidden_n':
      '{n} fail disembunyikan',
  'sm.hide_sel':
      'Sembunyikan ({n})',
  'sm.hold_cap':
      '{n} fail disusun; had hari ini ({cap}) dicapai, selebihnya esok',
  'sm.hold_offline':
      'Mod luar talian dihidupkan — matikan di Tetapan > Privasi untuk menyusun',
  'sm.hold_scope':
      'Tiada folder untuk disusun — semak akses fail dan Tetapan > Kecerdasan buatan > skop',
  'sm.hold_wifi':
      'Menyusun hanya pada Wi-Fi; diteruskan setelah anda berada pada Wi-Fi',
  'sm.inst_title':
      'Penerbit: {name}',
  'sm.intro_body':
      'Susunan pintar memeriksa dokumen baharu (PDF, Word, Excel, slaid, teks), imej, rakaman suara dan video, lalu memberi setiap satu nama kedua dan kategori yang jelas.',
  'sm.intro_pick_sub':
      'Anda bermula dengan kuota {max} fail; tandakan hanya yang anda mahu, bukannya mengimbas semuanya.',
  'sm.intro_pick_title':
      'Fail mana yang perlu diimbas?',
  'sm.intro_title':
      'Biarkan telefon anda menyusun dirinya sendiri',
  'sm.keep':
      'Kekalkan',
  'sm.keep_body':
      'Fail ini keluar daripada senarai Bersihkan dan tidak akan dicadangkan lagi.',
  'sm.keep_title':
      'Bukan yang tidak diperlukan?',
  'sm.local_ready_sub':
      'Invois, resit bank, dokumen rasmi, rekod kesihatan, tangkapan skrin dan APK diasingkan secara luar talian, percuma. Kunci Gemini pilihan turut mengelaskan fail yang kabur.',
  'sm.local_ready_title':
      'Pengasingan pintar setempat sedia (tanpa kunci API)',
  'sm.local_saved':
      '{n} fail dikelaskan secara setempat dengan 0 kredit AI',
  'sm.low_conf':
      'Semak',
  'sm.nothing_new':
      'Tiada fail baharu untuk disusun',
  'sm.overdue':
      'Bil tertunggak',
  'sm.pick_download_folder':
      'Folder Muat Turun',
  'sm.pick_more_sources':
      'Jenis & sumber folder lain',
  'sm.pick_one':
      'Pilih sekurang-kurangnya satu jenis dan sumber untuk diimbas.',
  'sm.point_clean':
      'Kad ucapan, meme, foto kabur dan tangkapan tidak sengaja boleh disembunyikan atau dipadam dengan satu ketikan.',
  'sm.point_name':
      'Nama kedua seperti "Bil elektrik · Oktober 2026"; tapis senarai mengikut kategori pintar, cari dalam apa-apa bahasa.',
  'sm.point_place':
      'Fail kekal di tempat dan namanya — tiada yang dialihkan.',
  'sm.preset_all':
      'Semua',
  'sm.preset_docs':
      'Dokumen sahaja',
  'sm.preset_downloads':
      'Muat turun sahaja',
  'sm.privacy':
      'Skop: Muat Turun, Dokumen, tangkapan skrin, rakaman, WhatsApp dan Telegram. Kamera hanya jika anda menghidupkannya. Fail (untuk Word, Excel dan slaid hanya teksnya; untuk video hanya minit pertama dilihat; untuk APK dan arkib hanya nama, saiz dan folder) dihantar kepada Google Gemini untuk disemak; hasilnya kekal hanya pada telefon anda. Dengan kunci Gemini percuma, Google boleh menggunakan data untuk menambah baik produknya. Folder di luar skop AI tidak pernah dihantar.',
  'sm.progress':
      'Menyusun {done}/{total}',
  'sm.r_all':
      'Semua',
  'sm.restore_sel':
      'Pulihkan ({n})',
  'sm.restored_n':
      '{n} fail dipulihkan',
  'sm.reused_n':
      '{n} salinan setempat digunakan semula (0 unit)',
  'sm.run':
      'Susun sekarang',
  'sm.search_empty':
      'Tiada fail tersusun yang sepadan',
  'sm.search_hint':
      'Cari susunan pintar (nama, penerbit, tahun, jenis…)',
  'sm.search_results':
      '{n} hasil',
  'sm.select_all':
      'Pilih semua',
  'sm.select_one':
      'Pilih',
  'sm.selected':
      '{n} dipilih',
  'sm.sensitive_pin':
      'Dokumen sensitif — PIN',
  'sm.settings':
      'Tetapan',
  'sm.similar':
      'Foto serupa',
  'sm.starter_cap_hit':
      '{n} fail disusun · Kuota permulaan {max} fail dicapai. Gunakan langganan pilihan atau kunci anda sendiri untuk lebih banyak.',
  'sm.starter_usage':
      '{n} / {max} kuota permulaan digunakan',
  'sm.status':
      '{n} fail · {c} kategori',
  'sm.status_sub':
      'Fail kekal di tempatnya; nama kedua dipaparkan dalam senarai dan carian.',
  'sm.stop':
      'Henti',
  'sm.stopped':
      '{n} fail disusun, proses dihentikan. {reason}',
  'sm.sub_all':
      'Semua',
  'sm.tab_clutter':
      'Tidak diperlukan ({n})',
  'sm.tab_hidden':
      'Tersembunyi ({n})',
  'sm.tile':
      'Susunan pintar',
  'sm.tile_off':
      'Hidupkan susunan pintar',
  'sm.tile_on':
      '{n} fail disusun',
  'sm.title':
      'Susunan pintar',
  'sm.upcoming_due':
      'Hampir tamat tempoh bayaran',
  'sm.usage':
      'Pusingan terakhir: {n} fail · ~{t} unit dan {q} soalan setiap fail',
  'sm.waiting':
      'jeda singkat, akan disambung sendiri',
  'sm.wifi':
      'Hanya pada Wi-Fi',
  'sm.wifi_sub':
      'Tiada fail dihantar melalui data mudah alih',
  'sm.year_title':
      'Tahun dokumen: {y}',
  'pe.add_image':
      'Tambah imej',
  'pe.add_initials':
      'Tambah inisial',
  'pe.add_signature':
      'Tambah tandatangan',
  'pe.add_text':
      'Tambah teks',
  'pe.background_failed':
      'Tidak dapat mengimbas item latar belakang: {error}',
  'pe.bold':
      'Tebal',
  'pe.busy_applying':
      'Menggunakan perubahan pada halaman…',
  'pe.busy_background':
      'Mencari item latar belakang…',
  'pe.busy_draw':
      'Menggunakan lukisan…',
  'pe.busy_fix':
      'Membetulkan baris…',
  'pe.busy_fix_ai':
      'Membetulkan baris secara pintar — beberapa saat…',
  'pe.busy_image':
      'Menukar imej…',
  'pe.busy_make_editable':
      'Menukar halaman kepada teks…',
  'pe.busy_reading':
      'Membaca halaman {page} — teks yang boleh disunting akan digariskan sebentar lagi…',
  'pe.busy_redo':
      'Membuat semula: {what}…',
  'pe.busy_refresh':
      'Menyegarkan semula halaman…',
  'pe.busy_rotate':
      'Memutar halaman…',
  'pe.busy_saving':
      'Menyimpan — menulis teks, tandatangan dan imej yang ditambah…',
  'pe.busy_undo':
      'Membuat asal: {what}…',
  'pe.busy_working':
      'Memproses…',
  'pe.clear_selection':
      'Kosongkan pilihan',
  'pe.delete_image':
      'Padam imej',
  'pe.delete_image_body':
      'Imej ini akan dibuang daripada halaman. Anda boleh memulihkannya dengan Buat asal.',
  'pe.draw_initials':
      'Lukis inisial anda',
  'pe.draw_open':
      'Lukis dengan pena',
  'pe.drawn':
      'Lukisan ditambah',
  'pe.field_next':
      'Medan seterusnya',
  'pe.field_prev':
      'Medan sebelumnya',
  'pe.fix_done':
      '{n} baris dibetulkan.',
  'pe.fix_nothing':
      'Tiada yang perlu dibetulkan — halaman sudah kelihatan bersih.',
  'pe.fix_page':
      'Betulkan teks',
  'pe.fix_page_ai':
      'Betulkan teks secara pintar',
  'pe.font_bigger':
      'Lebih besar',
  'pe.font_smaller':
      'Lebih kecil',
  'pe.force_ocr':
      'Sunting dengan OCR',
  'pe.form_filled':
      'Medan diisi',
  'pe.form_locked':
      'Medan ini baca sahaja',
  'pe.form_signature':
      'Medan tandatangan: tambah tandatangan anda daripada tab Tandatangan',
  'pe.hint_background':
      'Item yang berulang pada setiap halaman disenaraikan di bawah. Pilih yang ingin dibuang.',
  'pe.hint_draw':
      'Pen, penyerlah, pemadam dan teks — lukisan menjadi sebahagian daripada satu langkah suntingan ini',
  'pe.hint_failed':
      'Halaman ini tidak dapat dianalisis: {error}',
  'pe.hint_form':
      'Ketik medan dan isi pada halaman',
  'pe.hint_form_loading':
      'Membaca medan borang…',
  'pe.hint_form_none':
      'Dokumen ini tiada medan borang yang boleh diisi',
  'pe.hint_image':
      'Ketik imej untuk memilihnya; seret untuk mengalihkan, ubah saiz dari sudut, atau gunakan bar di bawah untuk memutar dan membalikkannya.',
  'pe.hint_image_locked':
      'Imej pada halaman ini dikunci di tempatnya: dipaparkan tetapi tidak boleh disunting (blok lukisan kongsi atau imej sebaris).',
  'pe.hint_image_none':
      'Tiada imej terbenam pada halaman ini.',
  'pe.hint_page':
      'Putar halaman yang dibuka.',
  'pe.hint_place_text':
      'Ketik tempat teks harus bermula.',
  'pe.hint_sign':
      'Tambah tandatangan atau inisial; seret, ubah saiz dari sudut',
  'pe.hint_text':
      'Ketik perenggan yang ingin diubah.',
  'pe.hint_text_none':
      'Tiada teks yang boleh disunting pada halaman ini. Ketik “Tambah teks” untuk menulis di atasnya.',
  'pe.hint_text_scanned':
      'Halaman imbasan: ketik baris untuk menaip di atasnya (mengenali baris…).',
  'pe.hint_text_unsupported':
      'Teks halaman ini belum boleh disunting terus (susun aturnya tidak dapat dibaca). Ketik "Tambah teks" untuk meletakkan teks baharu.',
  'pe.image_added':
      'Imej ditambah',
  'pe.image_deleted':
      'Imej dipadam',
  'pe.image_mirrored':
      'Imej dibalikkan',
  'pe.image_moved':
      'Imej dialihkan',
  'pe.image_turned':
      'Imej diputar',
  'pe.image_unreadable':
      'Imej tidak dapat dibaca',
  'pe.inline_checking':
      'Menyemak sama ada muat pada halaman…',
  'pe.inline_empty':
      'Perenggan tidak boleh kosong; gunakan "Tulis ganti" tanpa teks untuk membuangnya',
  'pe.inline_fits':
      'Muat — ketik Selesai untuk menggunakan',
  'pe.inline_hint':
      'Ubah teks, gunakan dengan ✓. Anda akan dimaklumkan di sini jika tidak muat.',
  'pe.inline_hint_scanned':
      'Baris imbasan: betulkan teks, ✓ menulis gantinya pada baris.',
  'pe.items_removed':
      'Item dipilih dibuang',
  'pe.make_editable':
      'Jadikan halaman ini boleh disunting',
  'pe.make_editable_done':
      '{n} baris ditukar kepada teks yang boleh disunting.',
  'pe.mirror_h':
      'Balikkan secara mengufuk',
  'pe.mirror_v':
      'Balikkan secara menegak',
  'pe.mode_draw':
      'Lukis',
  'pe.mode_form':
      'Borang',
  'pe.mode_image':
      'Imej',
  'pe.mode_page':
      'Halaman',
  'pe.mode_sign':
      'Tandatangan',
  'pe.mode_text':
      'Teks',
  'pe.mode_watermark':
      'Tera air',
  'pe.no_background':
      'Tiada item latar belakang berulang ditemui.',
  'pe.object_deleted':
      'Objek dipadam',
  'pe.object_locked':
      'Imej ini tidak boleh disunting; hanya kedudukannya dipaparkan.',
  'pe.object_moved':
      'Objek dialihkan',
  'pe.op_failed':
      'Operasi gagal: {error}',
  'pe.outline_failed':
      'Tidak dapat menganalisis halaman: {error}',
  'pe.overwrite':
      'Tulis ganti',
  'pe.overwrite_help':
      'Tutup perenggan dengan warna putih dan tulis teks baharu di tempatnya',
  'pe.overwritten':
      'Perenggan ditulis ganti',
  'pe.page_rotated':
      'Halaman diputar',
  'pe.paragraph_updated':
      'Perenggan dikemas kini',
  'pe.pick_to_remove':
      'Pilih item yang akan dibuang',
  'pe.prepare_failed':
      'Dokumen tidak dapat disediakan: {error}',
  'pe.protected_body':
      'Dokumen ini dikunci daripada penyuntingan tetapi dibuka tanpa meminta kata laluan (kunci kebenaran). Buang perlindungannya dan sunting?\n\nFail asal anda tidak diubah; perlindungan hanya dibuang pada salinan yang disunting.',
  'pe.protected_title':
      'Dokumen dilindungi',
  'pe.protection_removed':
      'Perlindungan dibuang',
  'pe.redone_what':
      'Dibuat semula: {what}',
  'pe.redraw_signature':
      'Lukis semula',
  'pe.remove_picked':
      'Buang yang dipilih ({n})',
  'pe.remove_protection':
      'Buang perlindungan',
  'pe.rot_left':
      '90° kiri',
  'pe.rot_right':
      '90° kanan',
  'pe.save_note':
      'Di mana dokumen yang disunting akan disimpan?',
  'pe.scanned_updated':
      'Baris dikemas kini.',
  'pe.signature_added':
      'Tandatangan ditambah',
  'pe.text_added':
      'Teks ditambah',
  'pe.text_color':
      'Warna teks',
  'pe.text_edited':
      'Teks disunting',
  'pe.undone_what':
      'Dibuat asal: {what}',
  'pe.unlock_failed':
      'Tidak dapat membuang perlindungan kata laluan dokumen: {error}\n\nJika ada kata laluan sebenar, buangnya melalui alat PDF dan cuba lagi.',
  'pe.wait_busy':
      'Sebentar — {what}',
// ── enum ──
  'enum.res_long_edge':
      'Sisi terpanjang',
  'enum.res_aspect':
      'Nisbah bidang',
  'enum.res_file_size':
      'Saiz fail',
  'enum.layout_list':
      'Senarai',
  'enum.layout_detail':
      'Senarai besar',
  'enum.layout_grid2':
      '2 lajur',
  'enum.layout_grid3':
      '3 lajur',
  'enum.layout_grid4':
      '4 lajur',
  'enum.layout_grid5':
      '5 lajur',
  'enum.layout_list_desc':
      'Satu baris · nama, saiz dan tarikh',
  'enum.layout_detail_desc':
      'Satu baris · pratonton besar',
  'enum.layout_grid2_desc':
      'Jubin terbesar',
  'enum.layout_grid3_desc':
      'Seimbang — lalai',
  'enum.layout_grid4_desc':
      'Muat lebih banyak fail',
  'enum.layout_grid5_desc':
      'Paparan terpadat',
  'enum.photo_group_day':
      'Hari',
  'enum.photo_group_month':
      'Bulan',
  'enum.photo_group_year':
      'Tahun',
  'enum.open_with_ask':
      'Tanya setiap kali',
  'enum.open_with_in_app':
      'Pemain dalam aplikasi',
  'enum.open_with_external':
      'Aplikasi lain',
  'enum.open_with_ask_desc':
      'Anda akan ditanya aplikasi mana yang digunakan semasa membuka video/audio/imej',
  'enum.open_with_in_app_desc':
      'Fail dibuka dalam pemain aplikasi ini',
  'enum.open_with_external_desc':
      'Pemain/galeri lalai telefon anda akan dibuka',
  'enum.cat_folder':
      'Folder',
  'enum.cat_image':
      'Foto',
  'enum.cat_video':
      'Video',
  'enum.cat_audio':
      'Audio',
  'enum.cat_document':
      'Dokumen',
  'enum.cat_archive':
      'Arkib',
  'enum.cat_apk':
      'Fail pemasang',
  'enum.cat_other':
      'Lain-lain',
  'enum.sort_name':
      'Mengikut nama',
  'enum.sort_date':
      'Mengikut tarikh',
  'enum.sort_size':
      'Mengikut saiz',
  'enum.sort_type':
      'Mengikut jenis',
  'enum.doc_pdf':
      'PDF',
  'enum.doc_text':
      'Teks',
  'enum.doc_spreadsheet':
      'Excel',
  'enum.doc_word':
      'Word',
  'enum.doc_slides':
      'Slaid',
  'enum.doc_image':
      'Imej',
  'enum.doc_unknown':
      'Tidak diketahui',
  'enum.bucket_camera':
      'Kamera',
  'enum.bucket_screenshot':
      'Tangkapan skrin',
  'enum.bucket_whatsapp':
      'WhatsApp',
  'enum.bucket_telegram':
      'Telegram',
  'enum.bucket_instagram':
      'Instagram',
  'enum.bucket_download':
      'Muat turun',
  'enum.bucket_bluetooth':
      'Bluetooth',
  'enum.bucket_other':
      'Lain-lain',
  'enum.dl_queued':
      'Dalam baris gilir',
  'enum.dl_running':
      'Memuat turun',
  'enum.dl_paused':
      'Dijeda',
  'enum.dl_completed':
      'Selesai',
  'enum.dl_failed':
      'Gagal',
  'enum.dl_canceled':
      'Dibatalkan',
  'enum.age_fresh':
      'baharu',
  'enum.age_recent':
      'bulan ini',
  'enum.age_old':
      'lama',
  'enum.age_ancient':
      'sangat lama',
  'enum.age_unknown':
      'tidak diketahui',
  'enum.date_any':
      'Bila-bila masa',
  'enum.date_today':
      'Hari ini',
  'enum.date_week':
      '7 hari lepas',
  'enum.date_month':
      '30 hari lepas',
  'enum.date_year':
      'Tahun lepas',
  'enum.date_custom':
      'Julat tersuai',
  'enum.size_any':
      'Semua',
  'enum.size_tiny':
      'Di bawah 1 MB',
  'enum.size_small':
      '1 – 10 MB',
  'enum.size_medium':
      '10 – 100 MB',
  'enum.size_large':
      'Melebihi 100 MB',
  'enum.chat_image':
      'Imej',
  'enum.chat_video':
      'Video',
  'enum.chat_document':
      'Dokumen',
  'enum.chat_audio':
      'Audio',
  'enum.chat_voice':
      'Mesej suara',
  'enum.chat_sticker':
      'Pelekat',
  'enum.chat_gif':
      'Animasi (GIF)',
  'enum.chat_other':
      'Lain-lain',
  'enum.chat_dir_any':
      'Semua',
  'enum.chat_dir_received':
      'Diterima',
  'enum.chat_dir_sent':
      'Dihantar',
  'enum.res_keep':
      'Kekalkan seperti sedia ada',
  'enum.res_480':
      '480p',
  'enum.res_540':
      '540p',
  'enum.res_720':
      '720p (HD)',
  'enum.res_1080':
      '1080p (Full HD)',
  'enum.res_percent':
      'Peratus',
  'enum.res_custom':
      'Piksel (lebar × tinggi)',
  'enum.imgfmt_keep':
      'Kekal sama',
  'enum.imgfmt_jpeg':
      'JPEG (kecil)',
  'enum.imgfmt_png':
      'PNG (tanpa kehilangan)',
  'enum.imgfmt_webp':
      'WebP (terkecil)',
  'enum.vq_very_low':
      'Fail terkecil',
  'enum.vq_low':
      'Kecil',
  'enum.vq_medium':
      'Seimbang',
  'enum.vq_high':
      'Kualiti tinggi',
  'enum.doc_invoice':
      'Invois',
  'enum.doc_receipt':
      'Resit',
  'enum.doc_id':
      'Kad pengenalan / dokumen rasmi',
  'enum.doc_health':
      'Dokumen kesihatan',
  'enum.doc_bank':
      'Bank / kewangan',
  'enum.doc_contract':
      'Kontrak',
  'enum.doc_education':
      'Pendidikan / nota',
  'enum.doc_screenshot':
      'Tangkapan skrin',
  'enum.doc_ticket':
      'Tiket / tempahan',
  'enum.doc_other':
      'Lain-lain',
  'enum.org_type':
      'Mengikut jenis',
  'enum.org_date':
      'Mengikut tarikh',
  'enum.org_source':
      'Mengikut sumber',
  'enum.org_type_desc':
      'Imej, Video, Dokumen…',
  'enum.org_date_desc':
      '2026-07, 2026-06…',
  'enum.org_source_desc':
      'Kamera, WhatsApp, Muat turun…',
  'enum.job_queued':
      'Dalam baris gilir',
  'enum.job_running':
      'Sedang berjalan',
  'enum.job_done':
      'Selesai',
  'enum.job_failed':
      'Gagal',
  'enum.job_cancelled':
      'Dibatalkan',
  'enum.job_interrupted':
      'Terganggu',
  'enum.sim_strict':
      'Sangat ketat',
  'enum.sim_normal':
      'Normal',
  'enum.sim_loose':
      'Longgar',
  'enum.sim_strict_desc':
      'Imej yang hampir serupa (salinan dimampatkan semula).',
  'enum.sim_normal_desc':
      'Imej yang sama dengan saiz diubah, dikodkan semula atau dipangkas sedikit.',
  'enum.sim_loose_desc':
      'Turut memadankan bidikan berturut-turut daripada babak yang sama; padanan palsu mungkin berlaku.',
  'enum.op_move':
      'Alih',
  'enum.op_copy':
      'Salin',
  'enum.op_delete':
      'Padam',
  'enum.op_rename':
      'Namakan semula',
  'enum.op_organize':
      'Susun secara automatik',
  'wp.tab':
      'Alat',
  'wp.failed':
      'Tidak dapat diselesaikan: {error}',
  'wp.style_update':
      'Kemas kini gaya',
  'wp.style_updated':
      'Gaya dikemas kini supaya sepadan dengan pilihan',
  'wp.theme':
      'Tema dokumen',
  'wp.theme_applied':
      'Tema digunakan',
  'wp.page_setup':
      'Penyediaan halaman',
  'wp.page_applied':
      'Penyediaan halaman digunakan',
// ── wp-pse-mp ──
  'wp.print_preview':
      'Pratonton cetakan',
  'wp.custom':
      'Tersuai',
  'wp.title_page':
      'Muka surat pertama berbeza',
  'wp.equation':
      'Persamaan',
  'wp.equation_edit':
      'Edit persamaan',
  'wp.equation_latex':
      'Persamaan (LaTeX)',
  'wp.tbl_merge':
      'Gabung',
  'wp.tbl_merge_right':
      'Dengan sel di sebelah kanan',
  'wp.tbl_merge_down':
      'Dengan sel di bawah',
  'wp.tbl_borders':
      'Sempadan',
  'wp.tbl_b_all':
      'Semua sempadan',
  'wp.tbl_b_outer':
      'Sempadan luar',
  'wp.tbl_b_inner':
      'Sempadan dalam',
  'wp.tbl_b_none':
      'Tiada sempadan',
  'wp.tbl_autofit':
      'Suai muat automatik',
  'wp.tbl_fit_content':
      'Suai muat kandungan',
  'wp.tbl_fit_window':
      'Suai muat tetingkap',
  'wp.tbl_fit_fixed':
      'Lajur sama lebar tetap',
  'wp.tbl_sort':
      'Isih',
  'wp.tbl_sort_asc_h':
      'A→Z (kekalkan baris pengepala)',
  'wp.tbl_sort_desc_h':
      'Z→A (kekalkan baris pengepala)',
  'wp.tbl_sort_asc':
      'A→Z (semua baris)',
  'wp.tbl_sort_desc':
      'Z→A (semua baris)',
  'wp.tbl_err_no_table':
      'Kursor tidak berada dalam sel jadual',
  'wp.compare_done':
      'Perbezaan daripada versi lama ditandakan sebagai perubahan yang dijejaki',
  'wp.compare_encrypted':
      'Dokumen yang dipilih dilindungi kata laluan',
  'wp.combine_done':
      'Dokumen disisipkan selepas kursor',
  'wp.review_none':
      'Tiada komen atau perubahan yang dijejaki',
  'wp.review_comment':
      'Komen',
  'wp.review_prev':
      'Sebelumnya',
  'wp.review_next':
      'Seterusnya',
  'wp.password':
      'Kata laluan dokumen',
  'wp.password_change':
      'Tukar kata laluan',
  'wp.password_open':
      'Dokumen ini dilindungi kata laluan',
  'wp.password_unsupported':
      'Jenis penyulitan ini tidak disokong (Word lama)',
  'wp.dictate_prompt':
      'Bertutur — teks dimasukkan pada kedudukan kursor',
  'wp.export':
      'Eksport',
  'wp.textbox':
      'Kotak teks',
  'wp.shape':
      'Bentuk',
  'wp.cover':
      'Muka surat kulit',
  'wp.toc_title':
      'Kandungan',
  'wp.toc_none':
      'Tiada tajuk — gunakan gaya Tajuk 1–3 untuk jadual kandungan',
  'wp.toc_done':
      'Jadual kandungan dikemas kini',
  'wp.section_break':
      'Pemisah bahagian',
  'wp.field':
      'Medan',
  'wp.cross_ref':
      'Rujukan silang',
  'wp.bibliography':
      'Bibliografi',
  'wp.para_border':
      'Sempadan',
  'wp.outline':
      'Anak tetingkap navigasi',
  'wp.thumbnails':
      'Lakaran kecil muka surat',
  'wp.stats':
      'Bilangan dan masa bacaan',
  'wp.export_pdf':
      'PDF (fon dibenamkan)',
  'wp.export_docx_fonts':
      'Word dengan fon terbenam (.docx)',
  'wp.export_save':
      'Simpan ke Muat turun',
  'wp.stats_pages':
      'Muka surat (anggaran)',
  'wp.stats_headings':
      'Tajuk',
  'wp.stats_reading':
      'Masa bacaan',
  'wp.stats_speaking':
      'Masa pertuturan',
  'wp.stats_selection':
      'Perkataan dalam pilihan',
  'wp.stats_min':
      '{n} min',
  'wp.stats_under_min':
      'Kurang daripada 1 min',
  'wp.bdr_box':
      'Kotak',
  'wp.bdr_top':
      'Sempadan atas',
  'wp.bdr_bottom':
      'Sempadan bawah',
  'wp.bdr_shade':
      'Lorekan kelabu',
  'wp.bdr_none':
      'Tiada sempadan',
  'wp.textbox_text':
      'Teks dalam kotak',
  'wp.img_wrap':
      'Balut teks',
  'wp.cover_title':
      'Tajuk',
  'wp.cover_subtitle':
      'Subtajuk',
  'wp.cover_author':
      'Penulis',
  'wp.cover_date':
      'Tarikh',
  'wp.cover_done':
      'Muka surat kulit ditambah di permulaan',
  'wp.sb_next':
      'Muka surat seterusnya',
  'wp.sb_cont':
      'Berterusan',
  'wp.sb_even':
      'Muka surat genap',
  'wp.sb_odd':
      'Muka surat ganjil',
  'wp.sb_done':
      'Pemisah bahagian disisipkan',
  'wp.xref_text':
      'Teks tajuk',
  'wp.xref_page':
      'Nombor muka surat',
  'wp.xref_above':
      'Atas / bawah',
  'wp.xref_is_above':
      'di atas',
  'wp.xref_is_below':
      'di bawah',
  'wp.src_author':
      'Penulis (Nama akhir, Nama pertama)',
  'wp.src_year':
      'Tahun',
  'wp.src_title':
      'Tajuk',
  'wp.src_publisher':
      'Penerbit / URL',
  'wp.export_odt':
      'Teks OpenDocument (.odt)',
  'wp.export_rtf':
      'Teks kaya (.rtf)',
  'wp.export_md':
      'Markdown (.md)',
  'wp.export_txt':
      'Teks biasa (.txt)',
  'wp.reader_theme':
      'Latar belakang',
  'wp.outline_fold':
      'Kembangkan / runtuhkan',
  'pse.step_paragraph':
      'Perenggan diedit',
  'pse.refused_glyph':
      'Fon dokumen tidak mempunyai sebahagian huruf ini; perenggan tidak diubah.',
  'pse.refused':
      'Perenggan ini tidak dapat diedit dalam versi ini; dokumen tidak diubah.',
  'pse.undo_failed':
      'Tidak dapat dibatalkan; dokumen tidak berubah.',
  'pse.save_as_docs':
      'Salinan dalam Dokumen',
  'pse.readonly_fallback':
      'Lokasi ini tidak boleh ditulis. Satu salinan disimpan dalam Dokumen: {name}',
  'pse.save_failed':
      'Tidak dapat menyimpan: {error}',
  'pse.version_failed':
      'Tidak dapat memulihkan versi: {error}',
  'pse.recover_none':
      'Suntingan tidak dapat digunakan semula pada dokumen ini.',
  'pse.locked_body':
      'Pemilik dokumen telah menyekat perubahan pada kandungannya. Pengeditan memerlukan kata laluan pemilik.',
  'pse.owner_wrong':
      'Itu bukan kata laluan pemilik dokumen ini.',
  'pse.comment_reopen':
      'Buka semula',
  'pse.comment_resolve':
      'Tandakan selesai',
  'pse.crop_bottom':
      'Bawah',
  'pse.crop_left':
      'Kiri',
  'pse.crop_right':
      'Kanan',
  'pse.crop_top':
      'Atas',
  'pse.step_push':
      'Teks di bawah ditolak ke bawah',
  'pse.step_link':
      'Pautan diubah',
  'pse.font_kind_doc':
      'Fon dalam dokumen ini',
  'pse.font_kind_match':
      'Paling hampir dengan fon dokumen',
  'pse.font_kind_pkg':
      'Fon dalam aplikasi',
  'pse.obj_align_left':
      'Jajar kiri',
  'pse.obj_align_hcenter':
      'Tengah secara mendatar',
  'pse.obj_align_right':
      'Jajar kanan',
  'pse.obj_align_top':
      'Jajar atas',
  'pse.obj_align_vcenter':
      'Tengah secara menegak',
  'pse.obj_align_bottom':
      'Jajar bawah',
  'pse.obj_distribute_h':
      'Agihkan secara mendatar',
  'pse.obj_distribute_v':
      'Agihkan secara menegak',
  'pse.step_align':
      'Dijajarkan',
  'pse.locked_ocr':
      'Teks ini ialah lapisan pengecaman tidak kelihatan bagi muka surat yang diimbas; tulisannya sendiri berupa imej. Jika anda menggantinya, tulisan lama ditutup dengan warna kertas dan teks yang dikenali dimasukkan ke dalam kotak yang boleh diedit.',
  'pse.ocr_ai_failed':
      'AI tidak dapat membacanya; teks hasil pengecaman pada peranti digunakan.',
  'pse.step_ocr_replace':
      'Tulisan hasil imbasan diganti',
  'pse.locked_rtl':
      'Teks kanan-ke-kiri (Arab, Ibrani) belum boleh diedit terus: penyambungan huruf akan rosak. Anda boleh menambah kotak teks di atasnya.',
  'pse.mk_arrow':
      'Anak panah',
  'pse.mk_ellipse':
      'Elips',
  'pse.mk_eraser':
      'Pemadam',
  'pse.mk_highlight':
      'Serlah',
  'pse.mk_ink':
      'Pen',
  'pse.mk_marker':
      'Penanda',
  'pse.mk_cloud':
      'Awan',
  'pse.step_stamp':
      'Cop ditambah',
  'pse.step_freetext':
      'Teks ditambah',
  'pse.step_cloud':
      'Awan ditambah',
  'pse.mk_line':
      'Garisan',
  'pse.mk_other':
      'Anotasi',
  'pse.mk_rect':
      'Segi empat tepat',
  'pse.mk_squiggly':
      'Beralun',
  'pse.mk_strikeout':
      'Garis lorek',
  'pse.mk_underline':
      'Garis bawah',
  'pse.mode_line':
      'Mod baris',
  'pse.mode_paragraph':
      'Mod perenggan',
  'pse.step_crop':
      'Imej dipangkas',
  'pse.step_delete':
      'Dipadam',
  'pse.step_duplicate':
      'Diduplikasi',
  'pse.step_flatten':
      'Anotasi diratakan',
  'pse.step_format':
      'Pemformatan diubah',
  'pse.step_image':
      'Imej ditambah',
  'pse.step_image_replace':
      'Imej diganti',
  'pse.step_ink':
      'Lukisan ditambah',
  'pse.step_list':
      'Senarai diubah',
  'pse.step_markup':
      'Penanda',
  'pse.step_markup_remove':
      'Penanda dialih keluar',
  'pse.step_move':
      'Dialihkan',
  'pse.step_note':
      'Nota',
  'pse.step_order':
      'Susunan diubah',
  'pse.step_paste':
      'Ditampal',
  'pse.step_replace':
      'Cari dan ganti',
  'pse.step_resize':
      'Saiz diubah',
  'pse.step_rotate':
      'Diputar',
  'pse.step_shape':
      'Bentuk ditambah',
  'pse.step_textbox':
      'Kotak teks ditambah',
  'pse.tool_image':
      'Imej',
  'pse.tool_markup':
      'Penanda',
  'pse.tool_text':
      'Teks',
  'pse.kvkk_custom':
      'Perkataan tersuai',
  'pse.kvkk_email':
      'E-mel',
  'pse.kvkk_iban':
      'IBAN',
  'pse.kvkk_phone':
      'Telefon',
  'pse.kvkk_tckn':
      'Nombor ID Turki',
  'pse.step_redact':
      'Disamarkan',
  'pse.shapes':
      'Bentuk',
  'pse.text_lines':
      'Baris teks',
  'pse.stroke_thin':
      'Nipis',
  'pse.stroke_medium':
      'Sederhana',
  'pse.stroke_thick':
      'Tebal',
  'pse.stroke_bold':
      'Sangat tebal',
  'pse.mode_label_para':
      'Mod: Perenggan',
  'pse.mode_label_line':
      'Mod: Baris',
  'pse.size_reset':
      'Asal',
  'mp.playlist_save':
      'Simpan senarai main',
  'mp.playlist_open':
      'Buka senarai main',
  'mp.playlist_saved':
      '{name} disimpan',
  'mp.playlist_loaded':
      '{n} lagu dimuatkan ({missing} hilang)',
  'mp.playlist_empty':
      'Tiada fail yang boleh dimainkan dalam senarai',
  'mp.playlist_name':
      'Nama senarai main',
// ── mp-nas-fmset ──
  'mp.auto_next':
      'Main seterusnya secara automatik',
  'mp.auto_next_on':
      'Main seterusnya automatik dihidupkan',
  'mp.auto_next_off':
      'Main seterusnya automatik dimatikan',
  'mp.loop_mark_a':
      'Ulang A-B: tanda A',
  'mp.loop_mark_b':
      'Ulang A-B: tanda B',
  'mp.loop_off':
      'Kosongkan ulang A-B',
  'mp.loop_a_set':
      'Titik mula (A) ditandakan',
  'mp.loop_on':
      'Ulang A-B dihidupkan — julat terus diulang.',
  'mp.loop_cleared':
      'Ulang A-B dikosongkan',
  'mp.lock':
      'Kunci kawalan',
  'mp.rotate_right':
      'Putar ke kanan',
  'mp.rotate_left':
      'Putar ke kiri',
  'mp.unlock':
      'Buka kunci',
  'mp.sec_player':
      'Pemain',
  'mp.float_window':
      'Main dalam gambar-dalam-gambar',
  'mp.float_failed':
      'Peranti ini tidak menyokong gambar-dalam-gambar.',
  'mp.zoom_fill':
      'Penuhi skrin',
  'mp.zoom_fit':
      'Muatkan pada skrin',
  'mp.resumed_at':
      'Menyambung dari {time}',
  'mp.restart':
      'Mula dari awal',
  'mp.sleep_timer':
      'Pemasa tidur',
  'mp.sleep_off':
      'Mati',
  'mp.sleep_minutes':
      '{n} minit',
  'mp.sleep_active':
      'Berhenti dalam {time}',
  'mp.audio_failed':
      'Fail audio ini tidak dapat dimainkan: {error}',
  'mp.channel_name':
      'Pemain muzik',
  'mp.channel_desc':
      'Pemberitahuan untuk audio yang dimainkan di latar belakang',
  'mp.play':
      'Main',
  'mp.pause':
      'Jeda',
  'mp.next':
      'Seterusnya',
  'mp.previous':
      'Sebelumnya',
  'mp.now_playing':
      'Sedang dimainkan',
  'mp.speed':
      'Kelajuan',
  'mp.back10':
      'Undur 10 saat',
  'mp.forward10':
      'Maju 10 saat',
  'mp.portrait':
      'Potret',
  'mp.fullscreen':
      'Skrin penuh (landskap)',
  'mp.next_page':
      'Muka surat seterusnya',
  'mp.play_speed':
      'Kelajuan main balik',
  'mp.speed_reset':
      'Set semula kepada 1×',
  'mp.subtitles':
      'Sari kata',
  'mp.sub_off':
      'Sari kata dimatikan',
  'mp.engine_mpv':
      'Buka dengan enjin lanjutan (mpv — semua codec)',
  'mp.engine_exo':
      'Kembali ke enjin standard (ExoPlayer)',
  'mp.audio_track_n':
      'Audio {n}',
  'mp.sub_online':
      'Cari dalam talian (OpenSubtitles)…',
  'mp.sub_online_none':
      'Sari kata untuk video ini tidak ditemui.',
  'mp.sub_online_failed':
      'Tidak dapat mendapatkan sari kata: {error}',
  'mp.sub_exact':
      'Padanan tepat dengan fail ini',
  'mp.sub_bigger':
      'Sari kata lebih besar',
  'mp.sub_smaller':
      'Sari kata lebih kecil',
  'mp.sub_pick':
      'Pilih fail sari kata…',
  'mp.sub_earlier':
      'Lewatkan sari kata 0.5 saat lebih awal',
  'mp.sub_later':
      'Lengahkan sari kata 0.5 saat',
  'mp.sub_offset':
      'Ofset: {v} saat',
  'mp.sub_unreadable':
      'Tidak dapat membaca fail sari kata.',
  'mp.open_with':
      'Buka dengan aplikasi lain',
  'mp.file_ops':
      'Operasi fail (alih, salin, kongsi…)',
  'mp.shuffle':
      'Rombak',
  'mp.repeat_off':
      'Ulang: mati',
  'mp.repeat_one':
      'Ulang: lagu ini',
  'mp.repeat_all':
      'Ulang: semua',
  'mp.video_failed':
      'Fail ini tidak dapat dimainkan. Peranti anda mungkin tidak menyokong codec ini — cuba “Buka dengan aplikasi lain”.\n\n{error}',
  'nas.ftp_plain_warning':
      'FTP biasa tidak disulitkan: kata laluan dan fail anda dihantar secara terbuka. Pilih FTPES atau SFTP jika pelayan menyokongnya.',
  'nas.webdav_http_warning':
      'http:// tidak disulitkan: kata laluan anda dihantar secara terbuka. Gunakan hanya pada rangkaian rumah; pilih https:// di internet.',
  'nas.title':
      'Storan rangkaian',
  'nas.empty':
      'Tiada sambungan disimpan. Tambah pelayan secara manual atau imbas rangkaian.',
  'nas.add':
      'Tambah sambungan',
  'nas.edit':
      'Edit sambungan',
  'nas.scan':
      'Imbas rangkaian',
  'nas.scanning':
      'Mengimbas rangkaian…',
  'nas.scan_none':
      'Pelayan tidak ditemui. Adakah pelayan dan telefon berada pada rangkaian Wi-Fi YANG SAMA?',
  'nas.scan_found':
      '{n} pelayan ditemui',
  'nas.protocol':
      'Protokol',
  'nas.name':
      'Nama',
  'nas.name_hint':
      'NAS Rumah',
  'nas.host':
      'Alamat pelayan',
  'nas.host_hint':
      '192.168.1.10',
  'nas.webdav_host_hint':
      'https://server/dav',
  'nas.port':
      'Port',
  'nas.user':
      'Nama pengguna',
  'nas.password':
      'Kata laluan',
  'nas.domain':
      'Domain / kumpulan kerja',
  'nas.initial_path':
      'Folder permulaan',
  'nas.save_password':
      'Simpan kata laluan',
  'nas.save_password_note':
      'Kata laluan disimpan secara tersulit dengan kunci yang terikat pada peranti. Jika dimatikan, kata laluan ditanya setiap kali bersambung.',
  'nas.unprotected_note':
      'Storan kunci selamat tidak berfungsi pada peranti ini: kata laluan disimpan tanpa perlindungan.',
  'nas.password_prompt':
      'Kata laluan untuk “{name}”',
  'nas.test':
      'Uji sambungan',
  'nas.test_ok':
      'Sambungan berjaya.',
  'nas.connecting':
      'Menyambung…',
  'nas.delete_confirm':
      'Padam sambungan “{name}”? (Fail pada pelayan tidak disentuh.)',
  'nas.upload_here':
      'Muat naik ke sini',
  'nas.uploading':
      'Memuat naik…',
  'nas.upload_done':
      'Dimuat naik.',
  'nas.new_folder':
      'Folder baharu',
  'nas.folder_name':
      'Nama folder',
  'nas.smb1_title':
      'Protokol SMB1 lama',
  'nas.smb1_body':
      '{host} hanya menyokong SMB1. SMB1 sudah lapuk dan tidak selamat: kata laluan dan fail lebih mudah dipintas. Benarkan hanya pada rangkaian rumah yang dipercayai.',
  'nas.smb1_allow':
      'Sambung juga',
  'nas.copy_to_phone':
      'Salin ke telefon',
  'nas.copied_to_phone':
      'Disalin ke Download/Dosya Okuyucu',
  'nas.copy_only_files':
      'Hanya fail yang boleh disalin (satu folder dipilih).',
  'nas.copy_skipped_dirs':
      'folder dilangkau',
  'nas.copying':
      'Menyalin',
  'nas.filter_hint':
      'Tapis folder ini',
  'nas.no_match':
      'Tiada fail yang sepadan.',
  'nas.delete_many':
      'Padam {n} item?',
  'nas.sort_ascending':
      'Menaik',
  'nas.rename':
      'Namakan semula',
  'nas.new_name':
      'Nama baharu',
  'nas.empty_folder':
      'Folder ini kosong.',
  'nas.smb_share_root':
      'Perkongsian — buka satu perkongsian untuk melihat failnya.',
  'nas.error_unreachable':
      'Tidak dapat mencapai pelayan. Semak alamat, port dan pastikan anda berada pada rangkaian yang sama.',
  'nas.error_auth':
      'Nama pengguna atau kata laluan ditolak.',
  'nas.error_not_found':
      'Folder atau fail tidak ditemui.',
  'nas.error_denied':
      'Pelayan menafikan akses.',
  'nas.error_unsupported':
      'Pelayan tidak menyokong versi protokol ini. Cuba SFTP atau FTP.',
  'nas.error_hostkey':
      'Identiti pelayan tidak disahkan atau telah berubah. Sambungan diputuskan.',
  'nas.error_insecure':
      'Sambungan tidak selamat disekat: kata laluan anda tidak pernah dihantar tanpa penyulitan melalui internet atau ke pelayan ubah hala. Gunakan alamat https://.',
  'nas.hostkey_new_title':
      'Pelayan baharu',
  'nas.hostkey_new_body':
      'Anda bersambung ke {host}:{port} buat pertama kali.\n\n{type}\n{fp}\n\nPercayai jika cap jarinya sama dengan yang dipaparkan NAS anda.',
  'nas.hostkey_changed_title':
      'Identiti pelayan BERUBAH',
  'nas.hostkey_changed_body':
      'Kunci {host}:{port} telah berubah. Mungkin ada yang memintas.\n\nLama: {old}\nBaharu: {fp}\n\nJANGAN bersambung kecuali anda memasang semula pelayan.',
  'nas.hostkey_trust':
      'Percayai',
  'nas.error_unknown':
      'Ralat sambungan.',
  'nas.smb_warning':
      'SMB telah diuji dengan perkongsian Samba/Windows (SMB2) dan berfungsi. Pelayan yang hanya mewajibkan SMB3 mungkin tidak bersambung; dalam hal itu cuba SFTP atau FTP pada pelayan yang sama. Port sentiasa 445 dan tidak boleh diubah.',
  'nas.writeback_title':
      'Muat naik perubahan ke pelayan?',
  'nas.writeback_body':
      '“{name}” telah diedit. Perubahan hanya ada pada salinan sementara di telefon; fail pada pelayan masih yang lama. Memuat naik MENIMPA versi pada pelayan.',
  'nas.writeback_upload':
      'Muat naik',
  'nas.writeback_keep_local':
      'Jangan muat naik dahulu',
  'nas.writeback_done':
      'Dimuat naik ke pelayan.',
  'fmset.folder_sizes':
      'Saiz folder dalam senarai',
  'fmset.folder_sizes_sub':
      'Folder yang kelihatan diukur di latar belakang; pepohon besar mengambil masa lebih lama.',
  'fmset.resume':
      'Sambung dari tempat terakhir',
  'fmset.resume_sub':
      'Ingat kedudukan main balik dan muka surat dokumen.',
  'fmset.audio_bg':
      'Teruskan main audio di latar belakang',
  'fmset.audio_bg_sub':
      'Jika mati, muzik berhenti apabila anda keluar dari aplikasi atau mengunci skrin.',
  'fmset.start_folder':
      'Folder permulaan',
  'fmset.start_folder_none':
      'Aplikasi dibuka pada papan pemuka',
  'fmset.start_folder_pick':
      'Buka ini semasa permulaan',
  'fmset.start_folder_clear':
      'Kosongkan folder permulaan',
  'fmset.sec_privacy':
      'Privasi',
  'fmset.sec_delete':
      'Pemadaman',
  'fmset.sec_permissions':
      'Kebenaran',
  'fmset.sec_maintenance':
      'Penyelenggaraan',
  'fmset.list_layout':
      'Reka letak senarai fail',
  'fmset.photo_grid':
      'Grid foto',
  'fmset.grid_density':
      'Ketumpatan grid',
  'fmset.grouping':
      'pengumpulan',
  'fmset.show_hidden':
      'Tunjukkan fail tersembunyi',
  'fmset.show_hidden_sub':
      'Nama yang bermula dengan titik (seperti .thumbnails)',
  'fmset.thumbnails':
      'Lakaran kecil',
  'fmset.thumbnails_sub':
      'Pratonton imej dan video (matikan pada peranti perlahan)',
  'fmset.default_sort':
      'Isihan lalai',
  'fmset.reverse_dir':
      'Songsangkan arah',
  'fmset.group_photos':
      'Kumpulkan foto',
  'fmset.group_photos_sub':
      'Dikumpulkan mengikut {unit}',
  'fmset.media_open_with':
      'Buka video, audio dan imej dengan',
  'fmset.index':
      'Indeks carian',
  'fmset.index_building':
      'Membina…',
  'fmset.index_none':
      'Belum dibina — dibina semasa carian pertama atau selepas imbasan',
  'fmset.index_stale':
      ' · fail berubah, perlu disegarkan',
  'fmset.index_ready':
      '{n} rekod · {date}{stale}',
  'fmset.index_failed':
      'Indeks tidak dapat dibina (kebenaran storan mungkin tiada).',
  'fmset.index_built':
      'Indeks carian dibina · {n} rekod.',
  'fmset.pin_change':
      'Tukar PIN kunci folder',
  'fmset.pin_set':
      'Tetapkan PIN kunci folder',
  'fmset.pin_sub_locked':
      '{n} folder dikunci · untuk mengunci, gunakan ⋮ > “Kunci folder” dalam folder',
  'fmset.pin_sub_unset':
      'Folder berkunci disembunyikan daripada senarai dan galeri. Fail TIDAK disulitkan — hanya disembunyikan dalam aplikasi ini.',
  'fmset.pin_remove':
      'Alih keluar kunci sepenuhnya',
  'fmset.pin_remove_sub':
      'PIN dipadam dan semua folder dibuka kuncinya.',
  'fmset.unlock':
      'Buka kunci',
  'fmset.use_trash':
      'Gunakan tong sampah',
  'fmset.use_trash_sub':
      'Jika mati, fail terus dipadam secara kekal (tidak boleh dibatalkan)',
  'fmset.confirm_delete':
      'Tanya sebelum memadam',
  'fmset.trash_auto':
      'Kosongkan tong sampah secara automatik',
  'fmset.trash_auto_off':
      'Mati — tong sampah dikosongkan secara manual',
  'fmset.trash_auto_on':
      'Item lebih lama daripada {n} hari dipadam',
  'fmset.off':
      'Mati',
  'fmset.days':
      '{n} hari',
  'fmset.empty_trash_now':
      'Kosongkan tong sampah sekarang',
  'fmset.trash_empty':
      'Tong sampah kosong',
  'fmset.trash_summary':
      '{n} item · {size}',
  'fmset.empty_confirm_title':
      'Kosongkan tong sampah?',
  'fmset.empty_confirm_body':
      '{n} item ({size}) akan dipadam secara kekal. Tindakan ini tidak boleh dibatalkan.',
  'fmset.empty':
      'Kosongkan',
  'fmset.emptying':
      'Mengosongkan tong sampah',
  'fmset.empty_partial':
      '{ok} item dipadam, {fail} tidak dapat dipadam.',
  'fmset.empty_cancelled':
      'Dihentikan — {ok} item dipadam.',
// ── fmset-drive-set-sdu ──
  'fmset.empty_done':
      'Tong sampah dikosongkan · {ok} item · {size} dibebaskan.',
  'fmset.full_access':
      'Akses semua fail',
  'fmset.usage_access':
      'Akses penggunaan',
  'fmset.usage_access_on':
      'Diberikan — tarikh terakhir dibuka aplikasi kelihatan',
  'fmset.usage_access_off':
      'Belum diberikan — tarikh tidak dapat dipaparkan pada skrin “Aplikasi”',
  'fmset.grant':
      'Berikan',
  'fmset.clear_thumbs':
      'Kosongkan cache lakaran kecil',
  'fmset.volumes':
      'Volum',
  'fmset.volumes_none':
      'Tidak ditemui',
  'drive.title':
      'Google Drive',
  'drive.upload_action':
      'Muat naik ke Drive',
  'drive.sign_in':
      'Sambung dengan Google',
  'drive.sign_out':
      'Putuskan sambungan',
  'drive.sign_in_prompt':
      'Sambungkan akaun Google anda untuk menyemak imbas Drive di sini, membuka dan memuat naik fail, serta menyusun folder.',
  'drive.root':
      'Drive Saya',
  'drive.new_folder':
      'Folder baharu',
  'drive.new_folder_default':
      'Folder baharu',
  'drive.new_folder_failed':
      'Tidak dapat mencipta folder.',
  'drive.rename':
      'Namakan semula',
  'drive.rename_failed':
      'Tidak dapat menamakan semula.',
  'drive.empty':
      'Folder ini kosong.',
  'drive.empty_search':
      'Tiada fail yang sepadan ditemui.',
  'drive.search_hint':
      'Cari dalam Drive…',
  'drive.exports_as':
      'dimuat turun sebagai {format}',
  'drive.uploading':
      'Memuat naik ke Drive…',
  'drive.upload_name':
      'Muat naik ke Drive',
  'drive.upload_done':
      'Dimuat naik ke Drive:',
  'drive.upload_failed':
      'Gagal memuat naik ke Drive.',
  'drive.download_failed':
      'Tidak dapat memuat turun fail.',
  'drive.downloading':
      'Memuat turun daripada Drive…',
  'drive.ready_offscreen':
      'Dimuat turun — ketik untuk membuka:',
  'drive.download_stopped':
      'Muat turun dihentikan.',
  'drive.delete_confirm':
      'Alihkan “{name}” ke tong sampah Drive?',
  'drive.delete_failed':
      'Tidak dapat memadam.',
  'drive.download':
      'Muat turun ke telefon…',
  'drive.download_here':
      'Muat turun ke sini',
  'drive.downloaded':
      'Dimuat turun ke: {folder}',
  'drive.star':
      'Tambah bintang',
  'drive.unstar':
      'Buang bintang',
  'drive.star_failed':
      'Tidak dapat menukar bintang.',
  'drive.info':
      'Butiran',
  'drive.info_kind':
      'Jenis',
  'drive.info_size':
      'Saiz',
  'drive.info_modified':
      'Diubah suai',
  'drive.info_created':
      'Dicipta',
  'drive.info_owner':
      'Pemilik',
  'drive.info_shared':
      'Perkongsian',
  'drive.info_starred':
      'Berbintang',
  'drive.shared_yes':
      'Dikongsi dengan orang lain',
  'drive.shared_no':
      'Hanya anda',
  'drive.sort':
      'Isih',
  'drive.folder':
      'Folder',
  'drive.share_link':
      'Kongsi pautan',
  'drive.share_file':
      'Kongsi fail',
  'drive.share_failed':
      'Tidak dapat mencipta pautan perkongsian.',
  'drive.paste_failed':
      'Tidak dapat menampal.',
  'drive.copy_tag':
      'salinan',
  'drive.error_not_signed_in':
      'Anda belum bersambung ke akaun Google.',
  'drive.error_not_configured':
      'Log masuk Google tidak diaktifkan untuk APK ini. Akaun tidak dapat disambungkan sebelum tandatangan aplikasi didaftarkan dalam Google Cloud sebagai "Android OAuth client" (peraturan Google; tidak boleh dibaiki melalui kod). Pemilih sistem di bawah berfungsi tanpa pendaftaran itu.',
  'drive.setup_title':
      'Nilai persediaan sekali sahaja',
  'drive.setup_steps':
      'Masukkan dua nilai di bawah pada console.cloud.google.com → APIs & Services → Credentials → OAuth client ID (Android). Jika skrin persetujuan OAuth berada dalam mod "Testing", tambah akaun anda sebagai penguji. Butiran: docs/GOOGLE-DRIVE-KURULUM.md',
  'drive.setup_package':
      'Nama pakej',
  'drive.setup_sha1':
      'SHA-1 tandatangan',
  'drive.setup_copied':
      'Disalin.',
  'drive.error_no_play_services':
      'Google Play Services tiada atau lapuk pada peranti ini, jadi log masuk Google tidak dapat berjalan. Anda boleh menggunakan pemilih sistem di bawah.',
  'drive.error_sign_in_failed':
      'Log masuk Google tidak dapat diselesaikan.',
  'drive.system_picker_hint':
      'Walaupun log masuk tidak berfungsi, anda masih boleh mengakses SEMUA kandungan Drive: pemilih sistem Android menyenaraikan Drive sebagai sumber fail dan tidak meminta sebarang kebenaran.',
  'drive.open_via_system':
      'Buka fail Drive dengan pemilih sistem',
  'drive.error_forbidden':
      'Drive menafikan operasi ini. Fail mungkin tidak dimuat naik dengan aplikasi ini.',
  'drive.error_api_not_enabled':
      'Google Drive API tidak diaktifkan untuk projek ini. Pergi ke Google Cloud Console → APIs & Services → Library → "Google Drive API" → Enable, kemudian cuba lagi dalam beberapa minit.',
  'drive.error_insufficient_scope':
      'Akaun bersambung tetapi kebenaran Drive belum diberikan. Putuskan sambungan, sambung semula dan luluskan akses Drive dalam dialog persetujuan.',
  'drive.error_not_found':
      'Fail tidak ditemui di Drive.',
  'drive.error_temporary':
      'Drive tidak bertindak balas buat masa ini, cuba lagi sebentar nanti.',
  'drive.error_unknown':
      'Ralat sambungan Drive.',
  'drive.downloading_name':
      'Muat turun daripada Drive',
  'set.sec_documents':
      'Dokumen',
  'set.sec_network':
      'Rangkaian & AI',
  'set.kw_offline':
      'luar talian internet rangkaian pesawat',
  'set.rate_app':
      'Nilaikan aplikasi',
  'set.rate_app_sub':
      'Penilaian anda membantu pasukan pembangun kecil berkembang',
  'set.key_valid':
      'Kunci sah · {n} model ditemui',
  'set.key_invalid':
      'Kunci tidak dapat disahkan',
  'set.cat_appearance':
      'Penampilan & bahasa',
  'set.cat_appearance_sub':
      'Tema, fon, saiz teks dan bahasa antara muka',
  'set.cat_browsing':
      'Senarai fail',
  'set.cat_browsing_sub':
      'Reka letak, isihan, lakaran kecil, folder permulaan',
  'set.cat_ai':
      'Kecerdasan buatan',
  'set.cat_ai_sub':
      'Folder pintar, kunci dan privasi',
  'set.sec_smart':
      'Folder pintar',
  'set.smart_sort_sub':
      'Hidup/mati, kamera, penyusunan di latar belakang, Wi-Fi sahaja, had harian, pembetulan yang dipelajari',
  'set.smart_on':
      'Hidup · {n} fail disusun — buka folder pintar',
  'set.smart_off':
      'Mati — hidupkan untuk memberi fail anda nama kedua dan kategori',
  'set.smart_pin':
      'PIN untuk folder sensitif',
  'set.smart_pin_none':
      'Folder ID, kesihatan, bank dan cukai kini dibuka tanpa PIN — ketik untuk menetapkan PIN',
  'set.smart_pin_on':
      'Folder ID, kesihatan, bank dan cukai meminta PIN sekali setiap sesi',
  'set.smart_pin_app':
      'Kunci aplikasi dihidupkan: PIN diminta semasa dibuka, folder tidak bertanya lagi',
  'set.cat_privacy':
      'Privasi & kebenaran',
  'set.cat_privacy_sub':
      'Kunci folder dan kebenaran yang dipegang aplikasi',
  'set.cat_reading':
      'Bacaan & pertuturan',
  'set.cat_reading_sub':
      'Suara pertuturan, kelajuan dan bacaan pintar',
  'set.cat_storage':
      'Storan & prestasi',
  'set.cat_storage_sub':
      'Tong sampah, pengesahan padam, kelajuan dan penyelenggaraan',
  'set.sec_tts':
      'Pertuturan',
  'set.tts_voice':
      'Suara dan kelajuan',
  'set.tts_voice_sub':
      'Pilih daripada suara pada peranti anda, tetapkan kelajuan dan nada (dengan pratonton)',
  'set.tts_default_voice':
      'Lalai peranti',
  'set.tts_summary':
      'Pertuturan {x}x',
  'set.tts_ai_read':
      'Bacaan pintar',
  'set.tts_ai_read_sub':
      'Mula bertutur sebaik jawapan tiba',
  'set.sec_advanced':
      'Lanjutan',
  'set.sec_experimental':
      'Eksperimen',
  'set.advanced_hint':
      'Jarang diperlukan — tetapkan sekali',
  'set.trash_off':
      'Padam secara kekal',
  'set.refresh_60':
      '60 Hz',
  'set.ai_no_key':
      'Tiada kunci',
  'set.ai_key_count':
      '{n} kunci',
  'set.api_key_sub':
      'Kunci API Gemini anda — disimpan pada peranti',
  'set.kw_dark':
      'gelap mod malam',
  'set.kw_font':
      'fon jenis huruf saiz',
  'set.kw_speak':
      'bertutur suara tts baca kuat',
  'set.kw_gemini':
      'gemini kunci api token',
  'set.kw_days':
      'hari automatik tempoh',
  'set.sec_theme':
      'Tema',
  'set.haptics':
      'Maklum balas haptik',
  'set.haptics_sub':
      'Getaran ringan semasa memilih dan menatal',
  'set.sec_text':
      'Teks',
  'set.sec_language':
      'Bahasa',
  'set.sec_lists':
      'Senarai',
  'set.sec_photos':
      'Foto',
  'set.sec_opening':
      'Pembukaan',
  'set.sec_key':
      'Akses',
  'set.sec_lock':
      'Kunci folder',
  'set.sec_speed':
      'Kelajuan & bateri',
  'set.sec_ai_scope':
      'Skop analisis',
  'set.sec_ai_privacy':
      'Apa yang keluar daripada peranti',
  'set.hints_reset':
      'Tunjukkan petua lagi',
  'set.hints_reset_sub':
      'Petua dan panduan yang dipaparkan sekali akan muncul semula',
  'set.hints_reset_done':
      'Petua akan dipaparkan semula',
  'sdu.title':
      'Storan gabungan dengan kad SD',
  'sdu.tile_sub':
      'Semasa mengecas, mengalihkan foto dan video lama ke kad SD untuk mengosongkan storan dalaman',
  'sdu.kw':
      'kad memori microsd alih sandaran mengecas storan dalaman penuh ruang kosong',
  'sdu.hero_title':
      'Dua memori, satu storan',
  'sdu.hero_body':
      'Apabila telefon sedang dicas, fail lama daripada folder pilihan anda dialihkan ke kad SD dengan susunan folder yang sama. Fail masih dipaparkan bersama dalam senarai dan galeri, dan storan dalaman dikosongkan. Mencabut pengecas menghentikan tugas tanpa meninggalkan fail yang separuh disalin.',
  'sdu.android_only':
      'Ciri ini hanya berfungsi pada Android.',
  'sdu.no_card':
      'Tiada kad SD dimasukkan',
  'sdu.no_card_hint':
      'Masukkan kad microSD ke dalam telefon; kad akan muncul di sini secara automatik.',
  'sdu.card_missing':
      'Kad SD yang dipilih tidak dimasukkan buat masa ini. Tugas diteruskan setelah kad kembali.',
  'sdu.err_readonly':
      'Telefon ini tidak membenarkan penulisan terus ke kad SD (Android 10 atau lebih lama, atau "Akses semua fail" dimatikan). Hidupkan kebenaran itu dalam Tetapan.',
  'sdu.enable':
      'Jalankan secara automatik semasa mengecas',
  'sdu.enable_sub':
      'Berfungsi walaupun aplikasi ditutup; tidak menghabiskan bateri dan berhenti apabila dicabut.',
  'sdu.sec_status':
      'Status',
  'sdu.sec_target':
      'Sasaran dan mod',
  'sdu.sec_what':
      'Apa yang dialihkan',
  'sdu.card_free':
      '{free} kosong · {total}',
  'sdu.mode_move':
      'Alih',
  'sdu.mode_copy':
      'Sandarkan',
  'sdu.mode_move_sub':
      'Fail dialihkan ke kad SD dan mengosongkan storan dalaman.',
  'sdu.mode_copy_sub':
      'Fail kekal dalam storan dalaman dan salinannya disimpan pada kad SD (dikemas kini apabila berubah).',
  'sdu.folders':
      'Folder',
  'sdu.f_camera':
      'Kamera (DCIM)',
  'sdu.f_pictures':
      'Gambar',
  'sdu.f_movies':
      'Filem',
  'sdu.f_music':
      'Muzik',
  'sdu.f_download':
      'Muat turun',
  'sdu.f_documents':
      'Dokumen',
  'sdu.f_recordings':
      'Rakaman',
  'sdu.age':
      'Fail lebih lama daripada',
  'sdu.age_all':
      'Semua',
  'sdu.age_days':
      '{n} hari',
  'sdu.preview_wait':
      'Mengira…',
  'sdu.preview_move':
      '{n} fail · {size} akan dialihkan sekarang',
  'sdu.preview_copy':
      '{n} fail · {size} akan disandarkan sekarang',
  'sdu.preview_sub':
      'Fail yang sudah ada pada kad dilangkau.',
  'sdu.notify':
      'Beritahu apabila selesai',
  'sdu.rules':
      'Tidak disentuh: folder tersembunyi (.thumbnails), fail yang diubah dalam 10 minit lepas dan media aplikasi sembang seperti WhatsApp/Telegram — sembang menyimpan fail mengikut lokasinya jadi mengalihkannya akan merosakkannya. Sekurang-kurangnya 1 GB dibiarkan kosong pada kad. Jika ada fail lain dengan nama sama, nama baharu digunakan; tiada apa yang ditimpa.',
  'sdu.charging':
      'Mengecas',
  'sdu.not_charging':
      'Tidak mengecas',
  'sdu.will_run_now':
      'akan berjalan sebentar lagi',
  'sdu.will_run_charging':
      'berjalan apabila dipalamkan',
  'sdu.never':
      'Belum pernah dijalankan.',
  'sdu.running':
      'Mengalihkan… {n} fail · {size} setakat ini',
  'sdu.last_run':
      'Terakhir dijalankan {when}: {n} fail · {size}',
  'sdu.total':
      'Jumlah: {n} fail · {size}',
  'sdu.failed_n':
      '{n} fail tidak dapat dialihkan (dicuba lagi lain kali).',
  'sdu.err_sd_missing':
      'Kad SD tidak ditemui — tugas dilangkau.',
  'sdu.err_sd_full':
      'Kad SD penuh (1 GB dibiarkan kosong) — tugas dihentikan.',
  'sdu.err_stopped':
      'Dijeda kerana pengecasan berhenti atau dihentikan; selebihnya dialihkan kemudian.',
  'sdu.run_now_move':
      'Alih sekarang',
  'sdu.run_now_copy':
      'Sandarkan sekarang',
  'sdu.run_started':
      'Dimulakan — anda boleh menutup aplikasi.',
// ── sdu-ied-rs-ss-fm ──
  'sdu.run_failed':
      'Tidak dapat dimulakan. Adakah kad SD dimasukkan?',
  'sdu.notify_title_move':
      'Dialihkan ke kad SD',
  'sdu.notify_title_copy':
      'Disandarkan ke kad SD',
  'sdu.notify_body':
      '{n} fail · {size}',
  'sdu.job_title':
      'Mengalihkan ke kad SD',
  'sdu.job_title_copy':
      'Menyandarkan ke kad SD',
  'sdu.job_name':
      'Pemindahan ke kad SD',
  'ied.title':
      'Edit',
  'ied.crop':
      'Pangkas',
  'ied.adjust':
      'Laras',
  'ied.markup':
      'Penanda',
  'ied.free':
      'Bebas',
  'ied.rotate':
      'Putar',
  'ied.flip':
      'Balikkan',
  'ied.reset':
      'Set semula',
  'ied.pen':
      'Pen',
  'ied.arrow':
      'Anak panah',
  'ied.text':
      'Teks',
  'ied.text_hint':
      'Teks untuk ditambah',
  'ied.tap_for_text':
      'Ketik di tempat teks hendak diletakkan',
  'ied.save_copy':
      'Simpan sebagai salinan',
  'ied.save_copy_sub':
      'Fail asal kekal seperti sedia ada',
  'ied.overwrite':
      'Tulis ganti fail asal',
  'ied.overwrite_sub':
      'Imej asal tidak dapat dipulihkan',
  'ied.as_jpeg':
      'Format ini tidak boleh ditulis; disimpan sebagai salinan JPEG',
  'ied.saved':
      '{name} disimpan',
  'ied.original':
      'Asal',
  'ied.custom_ratio':
      'Nisbah tersuai',
  'ied.ratio_hint':
      'Nisbah (cth. 4:5)',
  'ied.ratio_invalid':
      'Tidak dapat membaca nisbah — taip seperti "4:5".',
  'ied.hold_original':
      'Sebelum / selepas — ketik atau tahan',
  'ied.size_now':
      'Sekarang {from} → Disimpan sebagai {to}',
  'ied.size_original':
      'Seperti sedia ada',
  'ied.filters':
      'Penapis',
  'ied.f_none':
      'Tiada',
  'ied.f_vivid':
      'Terang',
  'ied.f_warm':
      'Hangat',
  'ied.f_cool':
      'Sejuk',
  'ied.f_mono':
      'Mono',
  'ied.f_sepia':
      'Sepia',
  'ied.f_fade':
      'Pudar',
  'ied.f_drama':
      'Dramatik',
  'ied.f_matte':
      'Matte',
  'ied.f_retro':
      'Retro',
  'ied.f_document':
      'Dokumen',
  'ied.strength':
      'Kekuatan',
  'ied.reset_one':
      'Set semula ini',
  'ied.flip_v':
      'Balikkan menegak',
  'ied.select':
      'Pilih',
  'ied.highlighter':
      'Penyerlah',
  'ied.eraser':
      'Pemadam',
  'ied.line':
      'Garisan',
  'ied.rect':
      'Segi empat tepat',
  'ied.ellipse':
      'Elips',
  'ied.blur':
      'Kaburkan',
  'ied.pixelate':
      'Piksel',
  'ied.thickness':
      'Ketebalan',
  'ied.opacity':
      'Kelegapan',
  'ied.edit_text':
      'Edit teks',
  'ied.text_box':
      'Latar belakang',
  'ied.font_sans':
      'Sans',
  'ied.font_serif':
      'Serif',
  'ied.font_mono':
      'Mono',
  'ied.blur_hint':
      'Lukis di atas apa yang ingin disembunyikan (muka, plat nombor, nombor pengenalan) — tidak boleh dipulihkan daripada fail yang disimpan.',
  'ied.zoom_hint':
      'Cubit untuk zum · ketik dua kali untuk muat',
  'rs.presets':
      'Pratetap',
  'rs.preset_profile':
      'Profil 640×640',
  'rs.preset_form':
      'Muat naik borang ≤ 200 KB',
  'rs.preset_share':
      'Sosial 4:5 · 1080',
  'rs.preset_web':
      'Web 1600 px',
  'rs.lock_on':
      'Nisbah dikunci — ketik untuk membuka kunci',
  'rs.lock_off':
      'Nisbah bebas — ketik untuk mengunci',
  'rs.lock_note':
      'Nisbah dikunci: taip satu nilai, yang lain dikira. Dengan beberapa fail, setiap satu mengekalkan nisbahnya.',
  'rs.unlock_note':
      'Nisbah bebas: taip kedua-dua nilai dan pilih cara imej memenuhi kotak.',
  'rs.fit':
      'Bagaimana ia dimuatkan?',
  'rs.aspect_w':
      'Lebar',
  'rs.aspect_h':
      'Tinggi',
  'rs.custom_value':
      'Tersuai',
  'rs.long_edge_note':
      'Sisi terpanjang dikecilkan kepada nilai ini dengan nisbah dikekalkan. Foto yang lebih kecil tidak dibesarkan.',
  'rs.file_size_note':
      'Disimpan sebagai JPEG; kualiti (dan saiz jika perlu) dilaraskan secara automatik. Jika sasaran tidak dapat dicapai, saiz terdekat dilaporkan.',
  'rs.upscale_warning':
      'Foto akan dibesarkan: saiz fail bertambah tetapi ketajaman tidak bertambah baik.',
  'rs.anchor':
      'Kekalkan bahagian ini',
  'rs.video_layout_note':
      'Pada video, pemangkasan berpusat dan sempadan berwarna hitam.',
  'rs.video_file_size_note':
      'Untuk video, saiz sasaran menjadi kadar bit; sasaran rendah turut menurunkan resolusi. Saiz sebenar dilaporkan apabila selesai.',
  'rs.save_preset':
      'Simpan tetapan',
  'rs.preset_name':
      'Nama pratetap',
  'rs.preset_delete':
      'Padam "{name}"?',
  'rs.preset_hint':
      'Tekan dan tahan tetapan tersimpan untuk memadamnya.',
  'rs.preview':
      'Pratonton',
  'rs.strip_location':
      'Buang lokasi',
  'rs.strip_location_sub':
      'Tarikh dan maklumat kamera dikekalkan. (Output WebP tidak membawa metadata.)',
  'rs.title':
      'Ubah saiz ({n} fail)',
  'rs.now':
      'Sekarang',
  'rs.after':
      'Selepas',
  'rs.fps_value':
      '{n} fps',
  'rs.bitrate':
      '{n} Mbps',
  'rs.no_audio':
      'senyap',
  'rs.estimate':
      'Anggaran: {before} → ≈ {after}',
  'rs.estimate_gain':
      '≈ {n}% dijimatkan',
  'rs.estimate_note':
      'Saiz sebenar bergantung pada kandungan; hasil tepat muncul apabila tugas selesai.',
  'rs.and_more':
      'dan {n} fail lagi · jumlah {size}',
  'rs.no_change_warning':
      'Tetapan ini tidak mengecilkan fail ini: resolusi dan kadar bingkai kekal sama. Pilih resolusi atau kadar bingkai yang lebih rendah.',
  'rs.resolution':
      'Resolusi',
  'rs.width':
      'Lebar (px)',
  'rs.height':
      'Tinggi (px)',
  'rs.jpeg_quality':
      'Kualiti JPEG (foto)',
  'rs.format':
      'Format (foto)',
  'rs.video_quality':
      'Pemampatan video',
  'rs.fps':
      'Kadar bingkai (fps)',
  'rs.keep':
      'Kekalkan seperti sedia ada',
  'rs.video_note':
      'Video sentiasa dikodkan semula (walaupun hanya kualiti atau audio yang berubah): ditukar tepat kepada saiz yang diminta menggunakan pengekod perkakasan peranti (Android Media3). Peratusan dan baki masa dipaparkan pada baris tugas. Pada video panjang ini boleh mengambil masa beberapa minit; tugas berjalan di latar belakang.',
  'rs.strip_audio':
      'Buang audio',
  'rs.strip_audio_sub':
      'Menjimatkan ruang yang ketara pada video yang audionya tidak diperlukan.',
  'rs.trash_original':
      'Alihkan fail asal ke tong sampah',
  'rs.trash_original_sub':
      'Jika mati, salinan yang lebih kecil ditulis dalam folder yang sama sebagai fail baharu dan fail asal tidak disentuh.',
  'rs.queue_note':
      'Tugas berjalan dalam baris gilir latar belakang; anda boleh beralih ke skrin lain. Tugas berhenti jika anda menutup aplikasi sepenuhnya. Fail yang lebih kecil disimpan di sebelah fail asal; anda boleh membuka hasilnya dan fail yang dicipta daripada kotak “Tugas” pada skrin utama.',
  'rs.start':
      'Mula',
  'ss.tools':
      'Alat penyampai',
  'ss.prev':
      'Sebelumnya',
  'ss.next':
      'Seterusnya',
  'ss.laser':
      'Penuding laser',
  'ss.pen':
      'Pen',
  'ss.pen_color':
      'Warna pen',
  'ss.clear_ink':
      'Kosongkan conteng',
  'ss.timer':
      'Pemasa',
  'ss.play':
      'Main',
  'ss.pause':
      'Jeda',
  'ss.stop':
      'Henti',
  'ss.presenter':
      'Paparan penyampai',
  'ss.reset_timer':
      'Set semula pemasa',
  'ss.next_slide':
      'Slaid seterusnya',
  'ss.slide_time':
      'Slaid ini: {t}',
  'ss.end_of_show':
      'Akhir persembahan',
  'ss.notes':
      'Nota',
  'ss.no_notes':
      'Tiada nota untuk slaid ini',
  'ss.volume_keys':
      'Maju dengan butang kelantangan',
  'ss.web_remote':
      'Alat kawalan jauh melalui rangkaian setempat',
  'ss.second_screen':
      'Paparkan pada skrin kedua',
  'ss.blank_black':
      'Skrin hitam',
  'ss.blank_white':
      'Skrin putih',
  'ss.all_slides':
      'Semua slaid',
  'ss.tool_rotate_left':
      'Putar ke kiri',
  'ss.tool_rotate_right':
      'Putar ke kanan',
  'ss.compare_hold':
      'Asal (tahan)',
  'ss.pages_tab':
      'Muka surat ({n})',
  'ss.saved':
      'Disimpan · {folder}',
  'ss.saving':
      'Menyimpan…',
  'ss.save_failed':
      'Tidak disimpan — ketik untuk cuba lagi',
  'ss.finishing':
      'Menyimpan perubahan terakhir…',
  'ss.tool_crop':
      'Pangkas',
  'ss.tool_rotate':
      'Putar',
  'ss.tool_filter':
      'Penapis',
  'ss.tool_retake':
      'Ambil semula',
  'ss.tool_delete':
      'Padam',
  'ss.page_deleted':
      'Muka surat dipadam',
  'ss.working_crop':
      'Memangkas…',
  'ss.working_rotate':
      'Memutar…',
  'ss.working_filter':
      'Menggunakan…',
  'ss.working_straighten':
      'Meluruskan…',
  'ss.moving':
      'Mengalihkan…',
  'ss.add_camera':
      'Imbas dengan kamera',
  'ss.add_camera_sub':
      'Tepi muka surat ditemui secara automatik',
  'ss.add_gallery':
      'Tambah daripada foto',
  'ss.add_gallery_sub':
      'Pilih daripada galeri dan tetapkan pangkasan sendiri',
  'ss.filter_clear':
      'Buang penapis',
  'ss.exit':
      'Keluar',
  'ss.step':
      '{n} / {total}  ·  langkah {step}/{max}',
  'ss.no_text':
      '(Tiada teks)',
  'fm.search_apps':
      'Cari aplikasi…',
  'fm.name_spoof_warn':
      'Amaran: jenis sebenar .{ext}',
  'fm.recent_opened':
      'Sejarah',
  'fm.apk_tab':
      'APK',
  'fm.network_storage':
      'Storan rangkaian',
  'fm.trash':
      'Tong sampah',
  'fm.trash_count':
      '{n} item',
  'fm.permission_denied':
      'Tiada masalah — anda masih boleh membuka fail satu demi satu; tiada kebenaran lain diperlukan.',
  'fm.internal_storage':
      'Storan dalaman',
  'fm.organize':
      'Susun',
  'fm.root':
      'Root',
  'fm.unreadable':
      'Folder ini tidak dapat dibaca.\nMungkin lokasi yang dilindungi Android (seperti Android/data), atau "akses semua fail" belum diberikan.',
  'fm.sort_name':
      'Isih mengikut nama',
  'fm.sort_date':
      'Isih mengikut tarikh',
  'fm.sort_size':
      'Isih mengikut saiz',
  'fm.select_none':
      'Kosongkan pilihan',
  'fm.paste':
      'Tampal',
  'fm.clipboard_ready':
      '{n} item sedia untuk {verb}',
  'fm.verb_move':
      'dialihkan',
  'fm.verb_copy':
      'disalin',
  'fm.compare_digest':
      'Adakah kedua-dua fail serupa?',
  'fm.batch_rename':
      'Namakan semula secara pukal',
// ── fm-ftpd-vault-dl-ab ──
  'fm.compress':
      'Mampat (ZIP/7z)',
  'fm.resize':
      'Kecilkan saiz (resolusi / kadar bingkai)',
  'fm.tag':
      'Tag (orang/kumpulan)',
  'fm.more_actions':
      'Tindakan lain',
  'fm.more':
      'Lagi',
  'fm.clipboard_copied':
      'Disalin ke papan keratan. Ketik “Tampal” dalam folder destinasi.',
  'fm.clipboard_cut':
      'Dipotong ke papan keratan. Ketik “Tampal” dalam folder destinasi.',
  'fm.move_here':
      'Alih ke sini',
  'fm.copy_here':
      'Salin ke sini',
  'fm.scan_document':
      'Imbas dokumen',
  'fm.duplicates_title':
      'Fail pendua',
  'fm.enter_password':
      'Masukkan kata laluan',
  'fm.clear_finished':
      'Kosongkan yang selesai',
  'fm.existing_tags':
      'Tag sedia ada',
  'fm.pin_enter':
      'Masukkan PIN',
  'fm.pin_new':
      'PIN baharu',
  'fm.pin_label':
      'PIN',
  'fm.pin_repeat':
      'PIN (sekali lagi)',
  'fm.to_background':
      'Jalankan di latar belakang',
  'fm.vol_internal':
      'Storan dalaman',
  'fm.vol_sdcard':
      'Kad SD',
  'fm.vol_usb':
      'Pemacu USB',
  'fm.quick_untouched':
      'Tidak dibuka dalam {n} bulan',
  'fm.quick_opened_within':
      'Dibuka dalam {n} bulan lepas',
  'fm.moving_name':
      'Alih',
  'fm.search_all':
      'Cari dalam semua fail',
  'ftpd.title':
      'Akses rangkaian',
  'ftpd.description':
      'Capai fail pada telefon ini daripada komputer dalam rangkaian. Mulakan perkhidmatan, kemudian taip alamat di bawah ke dalam penjelajah fail pada PC. Telefon dan PC mesti berada pada rangkaian Wi-Fi YANG SAMA.',
  'ftpd.intro':
      'Mulakan perkhidmatan untuk mencapai fail melalui rangkaian.',
  'ftpd.web_label':
      'Buka dalam penyemak imbas',
  'ftpd.web_hint':
      'Taip alamat ini dalam penyemak imbas PC anda: klik fail untuk membuka atau memuat turunnya.',
  'ftpd.ftp_label':
      'Penjelajah fail (FTP)',
  'ftpd.ftp_hint':
      'Taip dalam Explorer untuk menyalin dengan seret dan lepas. Penyemak imbas tidak lagi menyokong FTP — gunakan alamat di atas untuk membuka fail.',
  'ftpd.random_password':
      'Kata laluan rawak',
  'ftpd.show_hidden':
      'Tunjukkan fail tersembunyi',
  'ftpd.clients':
      '{n} komputer bersambung',
  'ftpd.folders_hint':
      'Pada PC anda akan melihat kotak yang sama seperti pada telefon: Belgeler, Resimler, Videolar, Ses, Arsivler, Uygulamalar, Indirilenler, Kamera — serta "Telefon" untuk semuanya. Anda boleh memilih yang dikongsi di atas, atau hanya berkongsi folder "Paylasilan".',
  'ftpd.notification_hint':
      'Kekal kelihatan dalam panel pemberitahuan semasa aktif, dan berhenti sendiri apabila anda menutup aplikasi.',
  'ftpd.open_action':
      'Akses rangkaian dihidupkan',
  'ftpd.advanced':
      'Lanjutan',
  'ftpd.start':
      'MULA',
  'ftpd.stop':
      'HENTIKAN PERKHIDMATAN',
  'ftpd.running':
      'Sedang berjalan',
  'ftpd.no_address':
      'Sambungan Wi-Fi tidak ditemui. Sambungkan telefon ke rangkaian Wi-Fi.',
  'ftpd.allow_write':
      'Benarkan penulisan',
  'ftpd.allow_write_note':
      'Semasa dimatikan, PC hanya boleh membaca. Jika dihidupkan, PC boleh mengubah dan MEMADAM fail pada telefon.',
  'ftpd.folders_title':
      'Folder untuk dikongsi',
  'ftpd.folders_all':
      'Semuanya dikongsi',
  'ftpd.folders_count':
      '{n} folder dikongsi',
  'ftpd.folders_none':
      'Tiada folder dipilih',
  'ftpd.folders_none_warning':
      'Tiada folder dipilih: walaupun perkongsian dihidupkan, PC tidak akan melihat apa-apa.',
  'ftpd.mode_boxes':
      'Folder yang saya pilih',
  'ftpd.mode_boxes_desc':
      'Hanya folder yang anda tandakan di bawah dikongsi; selebihnya tidak kelihatan.',
  'ftpd.mode_shared':
      'Hanya folder Dikongsi',
  'ftpd.mode_shared_desc':
      'Letakkan apa yang hendak dihantar ke folder "Dikongsi"; bahagian telefon yang lain langsung tidak kelihatan pada rangkaian.',
  'ftpd.select_all':
      'Pilih semua',
  'ftpd.clear_all':
      'Kosongkan pilihan',
  'ftpd.box_on_pc':
      'Pada PC: {name}',
  'ftpd.box_shared':
      'Dikongsi',
  'ftpd.box_storage':
      'Seluruh telefon',
  'ftpd.box_downloads':
      'Muat turun',
  'ftpd.box_camera':
      'Kamera',
  'ftpd.box_screenshots':
      'Tangkapan skrin',
  'ftpd.box_images':
      'Imej',
  'ftpd.box_videos':
      'Video',
  'ftpd.box_audio':
      'Audio',
  'ftpd.box_documents':
      'Dokumen',
  'ftpd.box_archives':
      'Arkib',
  'ftpd.box_apps':
      'Aplikasi',
  'ftpd.shared_folder_hint':
      'Folder "Paylaşılan" pada telefon. Gunakan "Salin ke Dikongsi" dalam menu ⋮ fail untuk meletakkan sesuatu di sini.',
  'ftpd.copied':
      'Alamat disalin.',
  'ftpd.start_failed':
      'Tidak dapat memulakan pelayan: {error}',
  'ftpd.qr_hint':
      'Imbas dengan kamera komputer atau telefon lain — fail anda dibuka dalam penyemak imbas.',
  'ftpd.upload_hint':
      'Komputer ke telefon: fail yang dihantar dengan "Telefona gönder" pada halaman masuk ke Download/Bilgisayardan.',
  'vault.title':
      'Peti besi disulitkan',
  'vault.pin_use_lock':
      'Masukkan PIN kunci folder — peti besi menggunakan PIN yang sama',
  'vault.pin_same_existing':
      'Peti besi menggunakan PIN yang sama dengan kunci folder dan aplikasi: masukkan PIN semasa anda.',
  'vault.pin_same_new':
      'PIN ini juga digunakan untuk kunci folder dan aplikasi.',
  'vault.legacy_title':
      '{n} item tersembunyi tidak disulitkan',
  'vault.legacy_body':
      '"Fail tersembunyi" lama hanya disimpan di tempat tersembunyi; ia kelihatan apabila telefon disambungkan ke komputer. Mengalihkannya ke peti besi akan menyulitkannya — setiap fail disulitkan dan disahkan sebelum fail asal dipadam.',
  'vault.legacy_move':
      'Alih ke peti besi',
  'vault.legacy_show':
      'Lihat senarai',
  'vault.move_hint':
      'Kandungan disulitkan; hanya dibuka dengan PIN atau cap jari',
  'vault.move_n':
      'Alihkan {n} fail ke peti besi',
  'vault.pick_title':
      'Pilih fail untuk peti besi',
  'vault.setup_title':
      'Sediakan peti besi disulitkan',
  'vault.setup_body':
      'Dokumen seperti kad pengenalan, surat hak milik dan kontrak disimpan secara tersulit dengan AES-256. Ia kekal tidak boleh dibaca walaupun telefon disambungkan ke komputer.',
  'vault.pin':
      'PIN peti besi',
  'vault.pin_again':
      'Ulang PIN',
  'vault.pin_short':
      'PIN mesti sekurang-kurangnya 4 digit',
  'vault.pin_mismatch':
      'PIN tidak sepadan',
  'vault.pin_warning':
      'Penting: jika PIN dilupakan, fail TIDAK BOLEH dipulihkan — tiada sesiapa, termasuk kami, dapat menyahsulitnya. Cap jari hanyalah pintasan pada telefon ini; catat PIN anda di tempat selamat.',
  'vault.create':
      'Cipta peti besi',
  'vault.locked_title':
      'Peti besi dikunci',
  'vault.locked_body':
      'Masukkan PIN atau gunakan cap jari untuk membuka.',
  'vault.unlock':
      'Buka kunci',
  'vault.unlock_bio':
      'Buka dengan cap jari',
  'vault.bio_prompt':
      'Sahkan untuk membuka peti besi',
  'vault.use_pin':
      'Guna PIN',
  'vault.bio_failed':
      'Tidak dapat membuka dengan cap jari — gunakan PIN anda',
  'vault.bio_toggle':
      'Buka dengan cap jari',
  'vault.bio_invalidated':
      'Cap jari baharu ditambah pada telefon, jadi buka kunci cap jari dimatikan. Buka dengan PIN, kemudian hidupkan semula.',
  'vault.autolock':
      'Kunci di latar belakang',
  'vault.autolock_now':
      'Serta-merta',
  'vault.autolock_secs':
      'Selepas {n} saat',
  'vault.autolock_mins':
      'Selepas {n} min',
  'vault.wrong_pin':
      'PIN salah',
  'vault.lock':
      'Kunci',
  'vault.add':
      'Tambah ke peti besi',
  'vault.adding':
      'Menyulitkan…',
  'vault.added_n':
      '{n} fail disulitkan ke dalam peti besi',
  'vault.encrypted_note':
      'AES-256 · dikunci apabila anda keluar atau aplikasi ke latar belakang',
  'vault.empty':
      'Peti besi kosong. Tambah fail dengan butang di bawah, atau tekan lama fail dalam penjelajah dan pilih "Alih ke peti besi disulitkan".',
  'vault.restore':
      'Keluarkan daripada peti besi',
  'vault.restore_sub':
      'Dinyahsulit semula ke folder asalnya',
  'vault.restored':
      'Dikeluarkan: {path}',
  'vault.delete':
      'Padam secara kekal',
  'vault.delete_body':
      'Padam "{name}" daripada peti besi secara kekal? Tindakan ini tidak boleh dibatalkan.',
  'vault.open_failed':
      'Tidak dapat membuka: {error}',
  'dl.saved':
      'Disimpan ke Muat turun: {name}',
  'dl.already_saved':
      'Sudah ada dalam Muat turun: {name}',
  'dl.save_failed':
      'Tidak dapat menyimpan ke Muat turun: {error}',
  'dl.show':
      'Tunjukkan',
  'dl.from_browser':
      'Fail yang dibuka daripada penyemak imbas disimpan ke Muat turun: {name}',
  'dl.verify':
      'Sahkan checksum (SHA-256)',
  'dl.verify_paste':
      'Tampal checksum SHA-256 yang diterbitkan oleh sumber',
  'dl.verify_running':
      'Membaca fail…',
  'dl.verify_ok':
      'Checksum SEPADAN — fail utuh',
  'dl.verify_bad':
      'Checksum TIDAK sepadan — fail tidak lengkap atau diubah',
  'dl.title':
      'Muat turun',
  'dl.clipboard_download':
      'Muat turun pautan dalam papan keratan',
  'dl.how_to':
      'Bagaimana memuat turun daripada penyemak imbas?',
  'dl.clear_finished':
      'Kosongkan entri yang selesai',
  'dl.link':
      'Pautan',
  'dl.clipboard_link':
      'Pautan dalam papan keratan',
  'dl.download':
      'Muat turun',
  'dl.no_link':
      'Tiada pautan dalam papan keratan. Salin pautan dalam penyemak imbas dan kembali.',
  'dl.from_link':
      'Muat turun daripada pautan',
  'dl.link_label':
      'Pautan (https://…)',
  'dl.continue':
      'Teruskan',
  'dl.empty':
      'Belum ada muat turun',
  'dl.remaining':
      '{time} lagi',
  'dl.link_copied':
      'Pautan disalin ke papan keratan.',
  'dl.pause':
      'Jeda',
  'dl.resume':
      'Sambung semula',
  'dl.cancel_task':
      'Batal',
  'dl.open_folder':
      'Buka foldernya',
  'dl.copy_link':
      'Salin pautan',
  'dl.remove':
      'Buang daripada senarai',
  'dl.download_here':
      'Muat turun ke sini',
  'dl.started':
      'Muat turun dimulakan: {name}',
  'dl.fetching_release':
      'Mendapatkan fail keluaran…',
  'dl.asset_count':
      '{n} fail · {tag}',
  'dl.size_unknown':
      'Saiz tidak diketahui',
  'dl.step1_title':
      '1) Kongsi (paling mudah)',
  'dl.step1_body':
      'Tekan lama pautan → “Kongsi pautan” → Dosyalarım. Butang kongsi milik halaman juga boleh digunakan.',
  'dl.step2_title':
      '2) Salin dan tampal',
  'dl.step2_body':
      'Tekan lama pautan → “Salin alamat pautan”, kemudian buka skrin ini: pautan muncul di atas, ketik “Muat turun”.',
  'dl.step3_title':
      '3) Supaya kami muncul apabila anda mengetik pautan',
  'dl.step3_body':
      'Sejak Android 12, aplikasi tidak boleh membuka pautan tapak yang bukan miliknya tanpa kebenaran. Anda boleh memberikannya secara manual: gunakan butang di bawah untuk membuka skrin maklumat aplikasi, kemudian:\n• Android tulen / Pixel: “Buka secara lalai” → “Buka pautan yang disokong”\n• Samsung: “Tetapkan sebagai lalai” → “Alamat web yang disokong”\n• Xiaomi / Redmi: “Buka secara lalai” → “Pautan yang disokong”\nTandakan alamat seperti github.com dalam senarai yang muncul.',
  'dl.how_to_note':
      'Menu ini hanya wujud pada Android 12 ke atas. Jika tidak menjumpainya, gunakan cara 1 — tanpa tetapan dan berfungsi pada semua peranti.',
  'dl.open_app_info':
      'Buka maklumat aplikasi',
  'dl.verify_name':
      'Semakan checksum',
  'ab.pro_locked_title':
      'Studio Buku Audio ialah Ciri Pro',
  'ab.pro_locked_sub':
      'Naik taraf ke Pro untuk menukar dokumen kepada buku audio (M4A/WAV) dengan jeda semula jadi.',
  'ab.pro_unlock':
      'Lihat Ciri Pro',
  'ab.engine_section':
      'Enjin Pertuturan & Suara Sistem',
  'ab.engine_label':
      'Enjin TTS',
  'ab.system_voice_label':
      'Suara Sistem',
  'ab.system_voice_default':
      'Suara sistem lalai',
  'ab.preview':
      'Pratonton Suara',
  'ab.preview_sample':
      'Helo. Ayat ini menguji enjin suara yang dipilih dan jeda semula jadi.',
  'ab.clean_section':
      'Pembersihan Pertuturan Semula Jadi',
  'ab.clean_pages':
      'Langkau nombor muka surat dan pengepala/pengaki berulang',
  'ab.clean_symbols':
      'Bersihkan simbol, kurungan dan URL berlebihan supaya pertuturan semula jadi',
  'ab.clean_abbr':
      'Kembangkan singkatan (cth. Dr., dsb.)',
  'ab.ai_tidy':
      'Murnikan teks dengan AI (kunci anda sendiri)',
  'ab.ai_tidy_sub':
      'Memurnikan bab supaya pertuturan semula jadi menggunakan kunci Gemini anda sendiri',
  'ab.title':
      'Cipta buku audio',
  'ab.library':
      'Buku audio saya',
  'ab.intro':
      'Dokumen dibahagikan kepada bab mengikut tajuknya; setiap bab menjadi fail audio berasingan bernama yang disimpan ke Music > Sesli Kitaplar. Bab yang selesai tidak dijana semula.',
  'ab.voice':
      'Suara',
  'ab.voice_system':
      'Suara peranti',
  'ab.voice_system_sub':
      'Enjin pertuturan telefon anda — tanpa muat turun (pilih dalam Tetapan > Bacaan)',
  'ab.speed':
      'Kelajuan',
  'ab.chapters':
      'Bab ({n})',
  'ab.chapter_ready':
      'Siap — tidak akan dijana semula',
  'ab.chapter_len':
      '~{min} min',
  'ab.start':
      'Cipta',
  'ab.listen':
      'Dengar',
// ── ab-ph-skin-pf-jr-pp ──
  'ab.running':
      'Mencipta bab {n}/{total} — hentikan',
  'ab.preparing':
      'Menyediakan suara: {voice}',
  'ab.done':
      '{n} bab siap ({folder})',
  'ab.stopped':
      'Dihentikan — {n} bab siap; boleh disambung kemudian',
  'ab.failed':
      'Tidak dapat mencipta buku audio: {error}',
  'ab.job_running':
      'Buku audio: {name}',
  'ab.job_name':
      'Buku audio ({name})',
  'ab.background':
      'Mencipta di latar belakang',
  'ab.background_sub':
      'Anda boleh meninggalkan skrin ini atau beralih aplikasi; kemajuan dipaparkan dalam pemberitahuan.',
  'ab.make':
      'Cipta buku audio',
  'ab.make_hint':
      'Fail bab dengan tajuk',
  'ab.library_empty':
      'Belum ada buku audio',
  'ab.library_empty_hint':
      'Pilih "Cipta buku audio" dalam menu ⋮ fail PDF, Word, slaid atau teks.',
  'ab.book_sub':
      '{n} bab · {size}',
  'ab.play_all':
      'Main dari awal',
  'ab.delete_q':
      'Padam buku audio "{name}"?',
  'ph.pin_home':
      'Tambah ke skrin utama',
  'ph.pin_home_hint':
      'Halaman ini mendapat ikonnya sendiri pada skrin utama',
  'ph.albums':
      'Album',
  'ph.show_all':
      'Tunjukkan semua',
  'ph.on_this_day':
      'Pada hari ini',
  'ph.on_this_day_sub':
      'Hari ini pada tahun-tahun lepas · {n}',
  'ph.loading':
      'Memuatkan fail…',
  'ph.empty':
      'Tiada fail untuk dipaparkan di sini.',
  'ph.no_match':
      'Tiada fail yang sepadan dengan carian/penapis anda.',
  'ph.verifying':
      'Mengesahkan salinan bait demi bait…',
  'ph.not_identical':
      'Pengesahan bait demi bait tidak menemui salinan tepat — tiada apa yang dipadam.',
  'ph.show':
      'Tunjukkan',
  'ph.search_in':
      'Cari dalam {title}',
  'ph.search_in_hint':
      'Cari dalam {title}…',
  'ph.layout':
      'Reka letak: {name}',
  'ph.selected_of':
      '{n} / {total} dipilih',
  'ph.select_above':
      'Pilih juga yang di atas',
  'ph.select_below':
      'Pilih juga yang di bawah',
  'ph.clear_selection':
      'Kosongkan pilihan',
  'ph.select_all':
      'Pilih semua',
  'ph.cat_empty':
      'Tiada fail dalam kategori ini.',
  'ph.group_deselect':
      'Nyahpilih kumpulan',
  'ph.group_select':
      'Pilih kumpulan',
  'ph.delete_dupes_title':
      'Padam salinan itu?',
  'ph.delete_dupes_body':
      '{n} salinan tambahan ({size}) {fate}. Fail tertua dalam setiap kumpulan dikekalkan.',
  'ph.fate_trash':
      'akan dialihkan ke tong sampah',
  'ph.fate_permanent':
      'akan dipadam SECARA KEKAL (tong sampah dimatikan dalam tetapan)',
  'ph.hidden_dupes_short':
      '{n} pendua disembunyikan',
  'ph.clean':
      'Bersihkan',
  'ph.similar_title':
      'Serupa: {title}',
  'ph.similar_short':
      'Cari yang serupa',
  'ph.sorted_header':
      '{n} fail · {sort}',
  'ph.view':
      'Paparan',
  'ph.view_scale':
      'Skala masa',
  'ph.view_columns':
      'Lajur',
  'ph.albums_hide':
      'Sembunyikan kawasan album',
  'ph.albums_show':
      'Tunjukkan kawasan album',
  'ph.pinch_hint':
      'Petua: cubit grid dengan dua jari untuk mengecilkan, renggangkan untuk membesarkan.',
  'ph.empty_hint':
      'Foto dan video baharu muncul di sini sebaik sahaja diambil.',
  'ph.no_match_hint':
      'Cuba kosongkan penapis.',
  'ph.clear_filters':
      'Kosongkan penapis',
  'ph.fast_scroll':
      'Pemegang tatal pantas',
  'skin.sage':
      'Sage',
  'skin.sage_sub':
      'Meja dan kertas: latar hijau-kelabu lembut, kad cerah, aksen teal',
  'skin.classic':
      'Klasik',
  'skin.classic_sub':
      'Folder kuning, ikon halaman biasa — pengurus fail gaya lama',
  'skin.ledger':
      'Lejar',
  'skin.ledger_sub':
      'Latar krim, folder manila, ikon biasa',
  'skin.calm':
      'Tenang',
  'skin.calm_sub':
      'Kad putih, aksen terakota, ikon berbingkai',
  'skin.bento':
      'Bento',
  'skin.bento_sub':
      'Kad storan berwarna, jubin besar dan kecil',
  'skin.band':
      'Pengepala gelap',
  'skin.band_sub':
      'Pengepala berwarna, jubin sebagai senarai',
  'skin.g_layout':
      'Baharu · dengan reka letak utama',
  'skin.g_color':
      'Tema warna',
  'skin.g_classic':
      'Ikon klasik',
  'skin.g_special':
      'Malam & sistem',
  'skin.title':
      'Gaya tema',
  'skin.clay':
      'Tanah liat',
  'skin.clay_sub':
      'Latar krim-merah jambu hangat, aksen plum, kad putih kertas',
  'skin.lavender':
      'Lavender',
  'skin.lavender_sub':
      'Latar kelabu lilac, aksen ungu plum',
  'skin.olive':
      'Zaitun',
  'skin.olive_sub':
      'Latar batu zaitun, aksen hijau zaitun',
  'skin.white':
      'Putih klasik',
  'skin.white_sub':
      'Latar kelabu cerah, kad putih bersih, aksen biru',
  'skin.straw':
      'Kertas jerami',
  'skin.straw_sub':
      'Latar jerami, kad krim, dakwat sepia',
  'skin.cream':
      'Krim',
  'skin.cream_sub':
      'Latar krim cerah, kad gading, aksen ambar',
  'skin.peach':
      'Pic',
  'skin.peach_sub':
      'Latar pastel hangat yang selesa di mata untuk bacaan panjang',
  'skin.mint':
      'Pudina',
  'skin.mint_sub':
      'Latar hijau-biru tenang, aksen hijau laut',
  'skin.porcelain':
      'Porselin',
  'skin.porcelain_sub':
      'Latar kelabu biru sejuk, aksen biru tua, kad putih kertas',
  'skin.modern':
      'Moden',
  'skin.modern_sub':
      'Aksen ungu terang, sudut bulat, ikon besar',
  'skin.system':
      'Warna sistem',
  'skin.system_sub':
      'Mengambil warna kertas dinding anda (Android 12+)',
  'skin.night':
      'Malam (OLED)',
  'skin.night_sub':
      'Latar hitam pekat: jimat bateri, selesa pada waktu malam',
  'skin.forces_dark':
      'Tema ini sentiasa kekal gelap',
  'pf.tab_form':
      'Borang',
  'pf.tab_sign':
      'Tandatangan',
  'pf.tab_digital':
      'Digital',
  'pf.title_unified':
      'Borang & tandatangan — {name}',
  'pf.pick_date':
      'Pilih tarikh',
  'pf.go_sign':
      'Tandatangani dokumen / tambah tarikh',
  'pf.add_signature':
      'Tandatangan',
  'pf.add_initials':
      'Paraf',
  'pf.add_date_stamp':
      'Cop tarikh',
  'pf.sign_empty_hint':
      'Tambah Tandatangan, Paraf atau Cop tarikh di atas untuk diletakkan pada muka surat.',
  'pf.sign_drag_hint':
      'Seret untuk meletakkan; ubah saiz dengan peluncur di bawah.',
  'pf.save_all':
      'Simpan',
  'pf.signed_warn':
      'Dokumen ini ditandatangani secara digital. Menimpanya akan membatalkan tandatangan sedia ada; disyorkan menyimpan salinan.',
  'pf.dsig_verify_title':
      'Pengesahan tandatangan',
  'pf.dsig_valid':
      'Sah — dokumen tidak berubah sejak ditandatangani',
  'pf.dsig_valid_partial':
      'Sah — kemas kini tambahan ditambah selepas penandatanganan',
  'pf.dsig_invalid':
      'Tidak sah — dokumen diubah selepas ditandatangani',
  'pf.dsig_self_signed':
      'Sijil tandatangan sendiri',
  'pf.dsig_issuer':
      'Pengeluar: {name}',
  'pf.dsig_sign_title':
      'Tambah tandatangan digital (PAdES)',
  'pf.dsig_self_opt':
      'Identiti tandatangan sendiri',
  'pf.dsig_pfx_opt':
      'Import sijil (.pfx / .p12)',
  'pf.dsig_signer_name':
      'Nama penandatangan',
  'pf.dsig_reason':
      'Sebab (pilihan)',
  'pf.dsig_location':
      'Lokasi (pilihan)',
  'pf.dsig_visible':
      'Kotak tandatangan kelihatan',
  'pf.dsig_last_page':
      'Letakkan pada muka surat terakhir',
  'pf.dsig_pick_pfx':
      'Pilih fail sijil',
  'pf.save':
      'Isi dan simpan',
  'pf.page':
      'Muka surat {n}',
  'pf.other_fields':
      'Medan lain',
  'pf.read_only':
      'baca sahaja',
  'pf.sign_tap':
      'Ketik untuk menandatangani',
  'pf.signed':
      'Ditandatangani — dicop pada medan semasa disimpan',
  'pf.flatten':
      'Kunci selepas diisi',
  'pf.flatten_sub':
      'Nilai dilukis pada muka surat; tiada sesiapa boleh mengubahnya selepas itu. Tindakan ini tidak boleh dibatalkan.',
  'pf.note':
      'Borang diisi',
  'pf.note_flat':
      'Borang diisi dan dikunci',
  'pf.no_fields':
      'PDF ini tidak mempunyai medan borang yang boleh diisi.',
  'pf.no_fields_hint':
      'Untuk menambah teks gunakan alat teks dalam editor PDF; untuk menandatangani gunakan ⋮ → Tandatangan.',
  'pf.failed':
      'Tidak dapat mengisi borang: {error}',
  'jr.undo_move':
      'Buat asal pengalihan',
  'jr.moved_back':
      '{n} fail dikembalikan',
  'jr.untrash':
      'Pulihkan',
  'jr.restored':
      '{n} fail dipulihkan',
  'jr.trash_created':
      'Alih ke tong sampah',
  'jr.trashed':
      '{n} item dialihkan ke tong sampah',
  'jr.undo_rename':
      'Buat asal penamaan semula',
  'jr.renamed_back':
      '{n} fail mendapat semula nama lamanya',
  'jr.headline_tags':
      'Penandaan pintar memeriksa {files} fail dan mencadangkan {groups} tag ({n} cadangan)',
  'jr.headline':
      '{n} perubahan pada {files} fail',
  'jr.status_none':
      'Belum ada yang digunakan — fail belum bertag. Ketik cadangan yang salah untuk membuangnya (✕), kemudian "Gunakan semua".',
  'jr.status_all':
      'Selesai: {n} tag ditulis pada fail · {x} dibuang. Ketik mana-mana untuk menukar fikiran.',
  'jr.status_some':
      '{n} digunakan · {p} belum selesai · {x} dibuang.',
  'jr.hint':
      'Ketik lakaran kecil: buang ✕ / kekal ✓ · Tekan lama: buka fail',
  'jr.by_tag':
      'Mengikut tag',
  'jr.by_file':
      'Mengikut fail',
  'jr.all_tags':
      'Semua',
  'jr.show_all':
      'Tunjukkan semua ({n})',
  'jr.apply_n':
      'Gunakan ({n})',
  'jr.n_files':
      '{n} fail',
  'jr.n_applied':
      '{n} digunakan',
  'jr.n_pending':
      '{n} dicadangkan',
  'jr.n_rejected':
      '{n} dibuang',
  'jr.state_applied':
      'bertag',
  'jr.state_pending':
      'dicadangkan — belum digunakan',
  'jr.state_rejected':
      'dibuang',
  'jr.remove_one_hint':
      'Cadangan dipadam daripada senarai ini; fail dikekalkan',
  'jr.empty':
      'Tugas ini tidak meninggalkan perubahan yang direkodkan pada fail.',
  'jr.summary':
      '{groups} kumpulan · {files} fail · {applied} digunakan · {pending} belum selesai',
  'jr.apply_all':
      'Gunakan semua ({n})',
  'jr.undo_all':
      'Buat asal semua',
  'jr.apply':
      'Gunakan',
  'jr.rename_tag':
      'Namakan semula tag',
  'jr.remove_tag':
      'Buang tag',
  'jr.remove_tag_body':
      'Buang tag "{tag}" daripada {n} fail tugas ini? Fail tidak dipadam.',
  'jr.remove_one':
      'Buang daripada fail ini',
  'jr.move_files':
      'Alihkan fail ke folder',
  'jr.moved':
      '{n} fail dialihkan',
  'jr.nothing_to_move':
      'Tiada fail yang tinggal untuk dialihkan',
  'jr.missing':
      'Fail sudah tidak wujud',
  'pp.dsign_sub':
      'Tandatangan PKCS#7; disahkan oleh Adobe/Chrome',
  'pp.region_hint':
      'Seret untuk melukis kotak; ketik kotak untuk membuangnya',
  'pp.region_hint_crop':
      'Seret untuk melukis kawasan yang dikekalkan',
  'pp.redact_sub':
      'Benar-benar membuang teks dan imej',
  'pp.to_xlsx_sub':
      'Baris/lajur dikesan; muka surat terpilih atau semua',
  'pp.to_docx_sub':
      'Baris, inden, saiz fon dan pemisah muka surat',
  'pp.pdfa_sub':
      'Arkib jangka panjang (PDF/A-2b)',
  'pp.compare_sub':
      'Perbezaan teks dan visual',
  'pp.permissions_sub':
      'Hadkan cetak/salin/edit',
  'pp.outline_sub':
      'Tambah, namakan semula, susun semula, inden',
  'pp.outline_rename':
      'Edit penanda buku',
  'pp.stamp_sub':
      'Diluluskan, Draf, Sulit, Salinan diperakui…',
  'pp.numbering_sub':
      'Muka surat n / N, Rom, nombor Bates',
  'pp.compress_hard_sub':
      'Penjimatan besar pada PDF imbasan/imej',
  'pp.studio_sub':
      'Pilih, putar, padam, gandakan dan susun semula muka surat',
  'pp.studio_insert_file':
      'Sisipkan muka surat daripada fail',
  'pp.studio_insert_image':
      'Sisipkan muka surat daripada imej',
  'pp.studio_insert_scan':
      'Imbas dan sisipkan muka surat',
  'pp.blank_sub':
      'Belakang kosong dalam imbasan',
// ── pp-cj-sb-clean-apk-suc-apps ──
  'pp.crop_sub':
      'Muka surat terpilih atau semua',
  'pp.fit_a4_sub':
      'Menyamakan saiz muka surat yang bercampur',
  'pp.profile_sub':
      'Nama, e-mel, telefon, alamat',
  'pp.form_create_sub':
      'Teks, kotak semak, medan tandatangan',
  'pp.ocr_layer_sub':
      'Menambah lapisan teks tidak kelihatan pada muka surat yang diimbas',
  'pp.images_to_pdf_sub':
      'Pilih banyak imej → satu PDF',
  'pp.pdf_to_images_sub':
      'Muka surat terpilih atau semua ke dalam folder JPEG',
  'pp.web_to_pdf_sub':
      'Masukkan alamat, simpan sebagai PDF A4',
  'pp.office_to_pdf_sub':
      'Teks, tajuk dan jadual dikekalkan',
  'pp.signatures_sub':
      'Tandatangan/paraf tersimpan, paraf setiap muka surat, tarikh, cop',
  'pp.crop_margins_hint':
      'Teks memenuhi skrin; diingati untuk dokumen ini',
  'pp.crop_one_column':
      'Hanya dalam paparan satu lajur',
  'pp.paged_hint':
      'Muka surat muat pada skrin; ketik tepi atau leret',
  'pp.meta_sub':
      'Tajuk, penulis, subjek, kata kunci',
  'pp.meta_title':
      'Tajuk',
  'pp.meta_author':
      'Penulis',
  'pp.meta_subject':
      'Subjek',
  'pp.meta_keywords':
      'Kata kunci',
  'pp.layers_sub':
      'Tunjukkan atau sembunyikan lapisan',
  'pp.xfdf_out_sub':
      'Alihkan serlahan dan nota ke aplikasi lain',
  'pp.xfdf_in_sub':
      'Tambah serlahan dan nota daripada aplikasi lain',
  'cj.title':
      'Pembersihan media sembang',
  'cj.job_title':
      'Mengimbas media sembang',
  'cj.job_name':
      'Imbasan media sembang',
  'cj.rescan':
      'Imbas semula',
  'cj.step_listing':
      'Menyenaraikan fail…',
  'cj.step_found':
      'Ditemui {n} fail sembang',
  'cj.step_duplicates':
      'Mencari salinan serupa…',
  'cj.step_sorting':
      'Mengisih…',
  'cj.step_none':
      'Tiada media sembang ditemui',
  'cj.step_clean':
      'Tiada yang kelihatan tidak perlu',
  'cj.step_summary':
      '{n} fail · {size} boleh dibebaskan',
  'cj.scanned':
      '{n} fail sembang · {size}',
  'cj.summary':
      '{n} daripadanya ({percent}%) kelihatan tidak perlu · {size}',
  'cj.summary_none':
      'Tiada longgokan yang tidak perlu.',
  'cj.disclaimer':
      '“Tidak perlu” hanyalah andaian: siapa penghantar fail atau maknanya bagi anda tidak boleh dibaca daripada fail. Tiada apa yang dipadam sendiri — anda yang memutuskan.',
  'cj.tiny_threshold':
      'Had imej kecil (di bawah ini dianggap “dimajukan”)',
  'cj.empty_no_media':
      'Folder WhatsApp/Telegram tidak ditemui pada telefon ini.',
  'cj.empty_clean':
      'Tiada longgokan tidak perlu dalam media sembang anda 🎉',
  'cj.kind_duplicate':
      'Salinan serupa',
  'cj.kind_sticker':
      'Pelekat',
  'cj.kind_gif':
      'Animasi (GIF)',
  'cj.kind_profile':
      'Foto profil',
  'cj.kind_tiny':
      'Imej kecil',
  'cj.kind_sent':
      'Fail yang saya hantar',
  'cj.kind_stale':
      'Lama tidak dibuka',
  'cj.why_duplicate':
      'Salinan tambahan fail yang sama. Salinan tertua dalam setiap set DIKEKALKAN.',
  'cj.why_sticker':
      'Hiasan sembang, bukan kenangan yang patut disimpan.',
  'cj.why_gif':
      'Biasanya jenaka atau animasi yang dimajukan.',
  'cj.why_profile':
      'Cache foto profil yang dimuat turun oleh aplikasi.',
  'cj.why_tiny':
      'Imej sekecil ini kebanyakannya poster, meme atau gambar “selamat pagi” yang dimajukan; foto yang diambil dengan telefon lebih besar.',
  'cj.why_sent':
      'Salinan kedua fail yang anda hantar; fail asal mungkin masih ada dalam galeri atau muat turun.',
  'cj.why_stale':
      'Tidak dibuka mahupun disentuh selama beberapa bulan.',
  'cj.select_all':
      'Pilih semua',
  'cj.select_none':
      'Kosongkan pilihan',
  'cj.nothing_selected':
      'Pilih fail untuk dipadam',
  'cj.selected_summary':
      '{n} fail dipilih · {size}',
  'cj.bucket_empty':
      'Tiada fail tinggal dalam kumpulan ini.',
  'cj.similar_title':
      'Bidikan serupa (WhatsApp)',
  'cj.similar_body':
      'Longgokan yang tidak dapat ditemui kumpulan: lima bidikan detik yang sama, salinan dimampatkan semula. Ia menyahkod imej, jadi mengambil masa.',
  'sb.title':
      'Ujian ketepatan',
  'sb.sub':
      'Ukur ketepatan penyusunan pintar dengan fail anda sendiri',
  'sb.intro':
      'Labelkan sehingga {n} fail dengan kategori yang betul; ia dibandingkan dengan jawapan Penyusunan pintar. Label kekal pada telefon ini dan laporan tidak mengandungi nama fail.',
  'sb.category':
      'Kategori',
  'sb.subtype':
      'Subjenis',
  'sb.date':
      'Tarikh (bulan + tahun)',
  'sb.gate':
      'get {g}',
  'sb.no_data':
      'tiada data',
  'sb.measured':
      '{m} daripada {n} fail mempunyai jawapan Penyusunan pintar',
  'sb.threshold':
      'Ambang keyakinan yang disyorkan: {t}',
  'sb.threshold_none':
      'Jawapan betul belum mencukupi untuk mencadangkan ambang',
  'sb.ask_missing':
      'Tanya yang belum ({n})',
  'sb.ask_all':
      'Tanya semua semula',
  'sb.asking':
      'Bertanya {done}/{total}',
  'sb.stop':
      'Henti',
  'sb.asked':
      '{ok} jawapan diterima, {failed} gagal',
  'sb.stopped':
      'Dihentikan: {reason}',
  'sb.add':
      'Labelkan fail',
  'sb.full':
      'Anda boleh melabel paling banyak {n} fail',
  'sb.labelled':
      'Berlabel',
  'sb.empty':
      'Belum ada label. Mulakan dengan "Labelkan fail".',
  'sb.pick_title':
      'Fail untuk dilabel',
  'sb.pick_empty':
      'Tiada fail dalam skop penyusunan pintar',
  'sb.row':
      'Betul: {truth} · Pintar: {model}',
  'sb.row_none':
      'tiada jawapan',
  'sb.label_title':
      'Label yang betul',
  'sb.sub_skip':
      'Jangan beri skor',
  'sb.sub_other':
      'Tiada / lain-lain',
  'sb.date_label':
      'Beri skor tarikh dokumen',
  'sb.month':
      'Bulan',
  'sb.year':
      'Tahun',
  'sb.no_date':
      'Tiada',
  'sb.year_none':
      'Tiada / lebih lama',
  'sb.save':
      'Simpan',
  'sb.remove':
      'Buang label',
  'sb.copy':
      'Salin laporan',
  'sb.copied':
      'Laporan disalin (tanpa nama fail)',
  'sb.clear':
      'Padam semua label',
  'sb.clear_ask':
      'Padam semua label? Fail anda tidak disentuh.',
  'clean.trash':
      'Kosongkan tong sampah',
  'clean.trash_detail':
      '{n} item · fail yang sudah dipadam',
  'clean.duplicates':
      'Bersihkan fail pendua',
  'clean.duplicates_detail':
      '{n} salinan tambahan · satu daripada setiap kumpulan dikekalkan',
  'clean.stale_downloads':
      'Muat turun lama',
  'clean.stale_downloads_detail':
      '{n} fail · tidak dibuka 180+ hari',
  'clean.apk':
      'Fail pemasang (APK)',
  'clean.apk_detail':
      '{n} fail · tidak diperlukan setelah aplikasi dipasang',
  'clean.big_videos':
      'Video besar',
  'clean.big_videos_detail':
      '{n} video · melebihi 100 MB (pilih satu demi satu)',
  'clean.finding_dupes':
      'Mencari fail pendua (bait demi bait)…',
  'clean.never_suggest':
      'Jangan cadangkan lagi',
  'clean.never_suggest_file':
      'Jangan cadangkan fail ini lagi',
  'clean.app_backup':
      'Sandaran aplikasi',
  'clean.app_backup_detail':
      '{n} fail sandaran (.bak). Aplikasi TIDAK memerlukannya untuk berjalan — ini salinan yang dibuat oleh alat sandaran. Memadamnya tidak merosakkan aplikasi yang dipasang; anda hanya kehilangan keupayaan memulihkan daripada sandaran ini.',
  'clean.verifying_sent':
      'Mengesahkan fail asal media yang dihantar…',
  'clean.trash_copy_only':
      'Alihkan hanya salinan ini ke tong sampah (fail asal kekal)',
  'clean.bg_safe_apply':
      'Pembersihan diteruskan di latar belakang jika anda keluar',
  'clean.done_freed':
      '{size} dibebaskan · {n} item',
  'clean.done_trash':
      '{size} dibersihkan · {n} item dialihkan ke tong sampah (boleh dipulihkan)',
  'clean.sort_size':
      'Saiz',
  'clean.sort_date':
      'Tarikh',
  'clean.bg_safe':
      'Imbasan diteruskan di latar belakang jika anda keluar',
  'clean.done_card_sub_trash':
      '{n} item dibersihkan. Apa-apa yang dialihkan ke tong sampah boleh dipulihkan pada bila-bila masa.',
  'clean.done_card_sub_perm':
      '{n} item tidak perlu dibersihkan dengan selamat.',
  'clean.why_trash':
      'Item yang sudah anda padam; mengosongkannya terus membebaskan ruang.',
  'clean.why_duplicates':
      'Fail asal tertua dalam setiap kumpulan tidak disentuh; hanya salinan tambahan yang dibuang.',
  'clean.why_temp_junk':
      'Muat turun tidak lengkap & sisa sementara; memadamnya tidak merosakkan aplikasi atau dokumen.',
  'clean.why_app_cache':
      'Lakaran kecil dijana semula apabila perlu; tiada fail peribadi disentuh.',
  'clean.why_apk':
      'Hanya pakej pemasang; aplikasi dan data yang sudah dipasang kekal utuh.',
  'clean.why_app_backup':
      'Hanya arkib sandaran lama; aplikasi yang dipasang terus berjalan seperti biasa.',
  'clean.why_empty_folders':
      'Hanya folder yang benar-benar kosong; dilangkau jika ada fail di dalamnya.',
  'clean.why_chat_sent':
      'Salinan sembang yang dihantar; foto/video asal pada peranti telah disahkan dan kekal selamat.',
  'clean.why_big_videos':
      'Tidak dipilih awal. Anda boleh mengecilkan saiz tanpa memadam supaya video anda kekal.',
  'clean.why_stale_downloads':
      'Muat turun tidak dibuka selama 6 bulan; semak satu demi satu sebelum membuang.',
  'clean.why_old_screenshots':
      'Tangkapan skrin tidak disentuh selama 3 bulan; semak dan pilih satu demi satu.',
  'clean.why_old_large':
      'Fail besar tidak dibuka selama 1 tahun; hanya item yang anda tandakan dialihkan ke tong sampah.',
  'apk.share':
      'Kongsi / simpan sebagai APK',
  'apk.share_sub':
      'Format, lokasi simpan dan pilihan perkongsian',
  'apk.save':
      'Simpan APK terus',
  'apk.save_sub':
      'Tanpa soalan, ke Downloads/APK',
  'apk.sheet_title':
      'Eksport APK',
  'apk.dest':
      'Lokasi simpan',
  'apk.change':
      'Tukar',
  'apk.save_here':
      'Simpan di sini',
  'apk.do_both':
      'Simpan dan kongsi',
  'apk.do_share':
      'Kongsi sahaja',
  'apk.do_save':
      'Simpan sahaja',
  'apk.saved_in':
      '{name} → {dir}',
  'apk.split_base_note':
      'Lebih kecil, tetapi mungkin gagal dipasang atau ranap pada telefon lain.',
  'apk.extracting':
      'Menyediakan APK…',
  'apk.not_found':
      'Fail APK aplikasi ini tidak dapat dibaca.',
  'apk.failed':
      'Tidak dapat mengekstrak APK: {error}',
  'apk.split_title':
      'Aplikasi ini dipasang dalam beberapa bahagian',
  'apk.split_body':
      'Aplikasi yang dipasang daripada Play disimpan sebagai base.apk serta bahagian skrin/bahasa/CPU ({n} bahagian). Kod ada dalam base.apk tetapi pustaka dan sumber ada dalam bahagian lain: base.apk sahaja mungkin gagal dipasang atau ranap semasa dibuka.',
  'apk.split_all':
      'Semua bahagian (.apks — disyorkan)',
  'apk.split_base':
      'base.apk sahaja',
  'apk.split_note':
      'Semua bahagian dalam satu fail. Dipasang dengan satu ketikan dalam aplikasi ini; alat seperti SAI juga boleh membukanya.',
  'apk.installing':
      'Menyediakan pemasangan…',
  'apk.installed':
      'Aplikasi dipasang',
  'apk.install_aborted':
      'Pemasangan dibatalkan',
  'apk.install_permission':
      'Benarkan pemasangan aplikasi tidak diketahui, kemudian ketik fail itu semula.',
  'apk.install_no_apk':
      'Tiada APK dalam pakej',
  'apk.check_title':
      'Pasang pakej ini?',
  'apk.check_app':
      'Aplikasi: {name}\n{pkg}',
  'apk.check_version':
      'Versi: {v}',
  'apk.check_installed':
      'Versi terpasang: {v}',
  'apk.check_sha':
      'Tandatangan (SHA-256):\n{fp}',
  'apk.check_same':
      'Tandatangan sepadan dengan aplikasi yang dipasang.',
  'apk.check_unreadable':
      'Tidak dapat membaca butiran pakej. Pasang pakej hanya daripada sumber yang dipercayai.',
  'apk.check_install':
      'Pasang',
  'apk.install_failed':
      'Pemasangan gagal: {error}',
  'apk.extracting_name':
      'Penyediaan APK',
  'suc.section':
      'Kategori saya',
  'suc.sub':
      'Huraikan kategori anda sendiri; Penyusunan pintar bertanya tentang setiap fail secara berasingan. Satu fail boleh berada dalam beberapa kategori.',
  'suc.empty':
      'Belum ada kategori. Contoh: "Sewa" — kontrak sewa, resit sewa dan yuran penyelenggaraan.',
  'suc.add':
      'Tambah kategori',
  'suc.full':
      'Anda boleh menambah paling banyak {n} kategori',
  'suc.new_title':
      'Kategori baharu',
  'suc.edit_title':
      'Edit kategori',
  'suc.name':
      'Nama',
  'suc.name_hint':
      'cth. Sewa',
  'suc.about':
      'Apa skopnya? (satu ayat)',
  'suc.about_hint':
      'cth. Kontrak sewa, resit sewa dan slip yuran penyelenggaraan',
  'suc.icon':
      'Ikon',
  'suc.color':
      'Warna',
  'suc.try':
      'Cuba',
  'suc.try_sub':
      'Sebelum menyimpan, ia dicuba pada {n} fail terakhir anda; padanan akan kelihatan.',
  'suc.trying':
      'Mencuba… {done}/{total}',
  'suc.try_none':
      'Tiada yang sepadan dalam {n} fail terakhir. Laraskan ayat dan cuba lagi.',
  'suc.try_hits':
      '{m} daripada {n} fail sepadan',
  'suc.try_stale':
      'Nama atau ayat berubah — cuba lagi.',
  'suc.no_files':
      'Tiada fail untuk dicuba',
  'suc.matched':
      'Sepadan',
  'suc.not_matched':
      'Tidak sepadan',
  'suc.confirm':
      'Hasilnya betul',
  'suc.confirm_sub':
      'Adakah yang sepadan benar-benar tergolong di sini? Jika tidak, laraskan ayat.',
  'suc.save':
      'Simpan',
  'suc.save_need':
      'Untuk menyimpan, cuba dahulu, lihat sekurang-kurangnya satu padanan, dan sahkan hasilnya.',
  'suc.apply':
      'Gunakan pada fail terdahulu ({n})',
  'suc.applying':
      'Menggunakan… {done}/{total}',
  'suc.applied':
      '{n} fail disemak, {m} sepadan',
  'suc.stopped':
      'Dihentikan: {reason}',
  'suc.stop':
      'Henti',
  'suc.count':
      '{n} fail',
  'suc.pending':
      '{n} fail · {p} belum disemak',
  'suc.menu':
      'Pilihan kategori',
  'suc.edit':
      'Edit',
  'suc.delete_q':
      'Padam kategori "{name}"? Fail kekal di tempatnya.',
  'apps.not_found':
      'Tiada aplikasi ditemui',
  'apps.sort_name':
      'Mengikut nama',
  'ct.analysis':
      'Analisis penuh',
  'ct.analysis_hint':
      'Mengikut bulan, terbesar, yang boleh dibersihkan',
  'ct.bulk_tag':
      'Tag semua',
  'ct.bulk_tag_hint':
      'Tambah tag pada {n} fail yang dipaparkan',
  'ct.by_month':
      '12 bulan lepas',
  'ct.by_source':
      'Asal fail',
  'ct.by_type':
      'Jenis',
  'ct.cleanable':
      'Boleh dibersihkan',
  'ct.copies':
      'Fail bernama salinan ("(1)", "copy")',
  'ct.copies_title':
      '{title} · salinan',
  'ct.empty':
      'Tiada fail dalam senarai ini.',
  'ct.group_analysis':
      'Analisis',
  'ct.group_quick_create':
      'Cipta pantas',
  'ct.group_tags':
      'Kategori & tag',
  'ct.largest':
      'Fail terbesar',
  'ct.manage_tags':
      'Urus tag',
  'ct.manage_tags_hint':
      'Namakan semula atau padam',
  'ct.no_tags':
      'Belum ada tag — cuba "Nama kedua pintar" atau "Tag semua".',
  'ct.no_tags_yet':
      'Belum ada tag.',
  'ct.stale':
      'Tidak dibuka lebih daripada {days} hari',
  'ct.stale_title':
      '{title} · lama tidak dibuka',
  'ct.stat_files':
      'fail',
  'ct.stat_month':
      'bulan ini',
  'ct.stat_size':
      'jumlah',
  'ct.subtitle':
      '{title} · {n} fail dipaparkan',
  'ct.summary':
      'Ringkasan',
  'ct.summary_hint':
      'Bilangan, saiz, jenis, asal',
  'ct.tag_delete':
      'Padam tag',
  'ct.tag_delete_body':
      'Tag "{tag}" akan dibuang daripada {n} fail. Fail tidak dipadam.',
  'ct.tag_rename':
      'Namakan semula tag',
  'ct.tags_heading':
      'Tag',
  'ct.title':
      'Analisis & susun',
  'ocr_studio.ai_done':
      'Teks diperhalusi dengan kunci Gemini anda.',
  'ocr_studio.ai_fix':
      'Pembetulan AI',
  'ocr_studio.all_pages':
      'Semua ({n})',
  'ocr_studio.clean':
      'Kemaskan',
  'ocr_studio.clean_done':
      'Huruf, tanda sengkang & tanda baca dibetulkan.',
  'ocr_studio.editor_hint':
      'Edit teks yang dicam di sini…',
  'ocr_studio.empty_result':
      'Tiada teks boleh dibaca pada halaman ini. Cuba mod Dipertingkat atau Visi AI.',
  'ocr_studio.mode_ai':
      'Visi AI (Gemini)',
  'ocr_studio.mode_ai_sub':
      'Tulisan tangan, jadual & halaman rumit · dengan kunci Gemini anda',
  'ocr_studio.mode_enhanced':
      'Dipertingkat (Imbasan)',
  'ocr_studio.mode_enhanced_sub':
      'Peningkatan tanpa kehilangan 2400 px · pembersihan bayang + susunan perenggan',
  'ocr_studio.mode_fast':
      'Pantas',
  'ocr_studio.mode_fast_sub':
      'Imej mentah · imbasan pantas pada peranti',
  'ocr_studio.page_chip':
      'Halaman {n}',
  'ocr_studio.pages':
      'Julat halaman',
  'ocr_studio.pages_batch':
      '{n} halaman pertama',
  'ocr_studio.pages_current':
      'Halaman semasa ({n})',
  'ocr_studio.pages_custom':
      'Julat tersuai',
  'ocr_studio.preview':
      'Tunjuk / sembunyi pratonton sumber',
  'ocr_studio.progress_page':
      'Mengimbas halaman {done} / {total}…',
  'ocr_studio.quality':
      'Kualiti pengecaman',
  'ocr_studio.range_empty':
      'Masukkan julat halaman yang sah.',
  'ocr_studio.range_hint':
      'cth. 1-5, 8 (jumlah {total} halaman)',
  'ocr_studio.read':
      'Dengar',
  'ocr_studio.rescan':
      'Imbas semula',
  'ocr_studio.save_txt':
      'Simpan TXT',
  'ocr_studio.saved_txt':
      'Teks disimpan: {name}',
  'ocr_studio.select_on_image':
      'Pilih pada imej',
  'ocr_studio.start':
      'Cam teks',
  'ocr_studio.stats':
      '{words} perkataan · {chars} aksara',
  'ocr_studio.stop_read':
      'Henti',
  'ocr_studio.title':
      'Studio pengecaman teks',
  'foot.apk_note':
      'Aplikasi itu sendiri (~95 MB) kebanyakannya enjin pada peranti: pengecaman teks (OCR), terjemahan, video, PDF. Semuanya terdapat dalam pakej supaya berfungsi tanpa internet.',
  'foot.clean':
      'Kosongkan cache ({size})',
  'foot.clean_note':
      'Salinan, imej kecil, fail sementara dan cache Drive dipadam. Dokumen anda tidak disentuh; item yang dibuka dalam 10 minit lepas dilangkau.',
  'foot.delete_models':
      'Padam model bahasa',
  'foot.docs':
      'Dokumen dalam aplikasi',
  'foot.docs_sub':
      'Imbasan lama dan dokumen baharu — fail ANDA, tidak pernah dikosongkan. Dipadam jika aplikasi dinyahpasang; ketik dan alihkan ke Dokumen',
  'foot.drive':
      'Cache Google Drive',
  'foot.drive_sub':
      'Salinan setempat fail yang dibuka dari Drive — dimuat turun semula apabila dibuka semula',
  'foot.empty':
      'Tiada apa untuk diukur.',
  'foot.freed':
      '{size} dibebaskan.',
  'foot.kw_cache':
      'cache saiz ruang',
  'foot.models':
      'Model bahasa terjemahan',
  'foot.models_deleted':
      '{n} model bahasa dipadam; akan dimuat turun semula apabila diperlukan.',
  'foot.models_sub':
      'Model yang dimuat turun untuk terjemahan pada peranti (~30 MB setiap bahasa)',
  'foot.nothing_freed':
      'Tiada lagi yang boleh dibebaskan.',
  'foot.other':
      'Tetapan dan indeks',
  'foot.other_sub':
      'Indeks carian, sejarah, tetapan, data WebView',
  'foot.picker':
      'Salinan pemilih fail',
  'foot.picker_sub':
      'Salinan fail yang dipilih dengan pemilih; dipadam secara automatik selepas 7 hari',
  'foot.section':
      'Storan aplikasi',
  'foot.shared':
      'Salinan kongsi',
  'foot.shared_sub':
      'Salinan fail yang dibuka dengan “Buka dengan” atau disediakan untuk dikongsi; dipadam secara automatik selepas 7 hari',
  'foot.system':
      'Menurut Android: aplikasi {app} · data {data}',
  'foot.system_settings':
      'Buka tetapan aplikasi Android',
  'foot.temp':
      'Fail sementara',
  'foot.temp_sub':
      'Hasil perantaraan imbasan, pratonton arkib, cache WebView',
  'foot.thumbs':
      'Imej kecil',
  'foot.thumbs_sub':
      'Pratonton video, PDF dan APK — dijana semula apabila diperlukan',
  'foot.tile_sub':
      'Lihat apa yang menggunakan berapa ruang; kosongkan cache dan salinan',
  'foot.title':
      'Storan yang digunakan aplikasi',
  'foot.total_sub':
      'Dalam folder milik aplikasi (data + cache). Aplikasi itu sendiri (APK) tidak termasuk.',
  'smp.excel_name':
      'Contoh bajet',
  'smp.folder':
      'Contoh',
  'smp.note_1':
      'Nota dan fail Markdown dibuka dalam editor teks biasa',
  'smp.note_2':
      'Tajuk, senarai dan teks tebal diformat dalam pratonton',
  'smp.note_3':
      'Fail ini selamat untuk dipadam',
  'smp.note_name':
      'Nota contoh',
  'smp.note_title':
      'Nota contoh',
  'smp.sl_edit':
      'Edit',
  'smp.sl_edit1':
      'Tambah teks, bentuk dan gambar',
  'smp.sl_edit2':
      'Pilih tema daripada tab Reka Bentuk',
  'smp.sl_notes':
      'Nota penceramah muncul dalam mod pembentangan.',
  'smp.sl_read':
      'Baca',
  'smp.sl_read1':
      'Leret dalam mod pembentangan',
  'smp.sl_read2':
      'Lompat ke mana-mana slaid daripada imej kecil',
  'smp.sl_sub':
      'Ketik slaid untuk mengedit',
  'smp.sl_title':
      'Pembentangan contoh',
  'smp.slides_name':
      'Pembentangan contoh',
  'smp.word_name':
      'Dokumen contoh',
  'smp.word_p1':
      'Ubah dokumen ini sesuka hati anda: ketik teks dan mula menaip.',
  'smp.word_p2':
      'Simpan, Buat Asal dan Buat Semula berada di tempat yang sama pada bar atas setiap editor.',
  'smp.word_p3':
      'Gunakan "Kongsi / Eksport" dalam menu ⋮ untuk mengeksport ke PDF atau format lain.',
  'smp.word_title':
      'Selamat datang!',
  'smp.xl_actual':
      'Sebenar',
  'smp.xl_food':
      'Barangan dapur',
  'smp.xl_item':
      'Item',
  'smp.xl_other':
      'Lain-lain',
  'smp.xl_plan':
      'Rancangan',
  'smp.xl_rent':
      'Sewa',
  'smp.xl_sheet':
      'Bajet',
  'smp.xl_total':
      'Jumlah',
  'smp.xl_transport':
      'Pengangkutan',
  'apps.app_info':
      'Maklumat aplikasi (tetapan sistem)',
  'apps.copy_package':
      'Salin nama pakej',
  'apps.count':
      '{n} aplikasi',
  'apps.days_ago':
      '{n} hari lalu',
  'apps.filter_unused':
      'Tidak digunakan {n}+ hari',
  'apps.installed_on':
      'Dipasang',
  'apps.long_ago':
      'lebih 2 tahun',
  'apps.never_opened':
      'tidak pernah dibuka',
  'apps.no_unused':
      'Tiada aplikasi yang lama tidak digunakan.',
  'apps.package_copied':
      'Nama pakej disalin',
  'apps.show_system':
      'Tunjuk aplikasi sistem',
  'apps.size_app':
      'Aplikasi',
  'apps.size_data':
      'Data',
  'apps.sort_idle':
      'Paling lama tidak digunakan dahulu',
  'apps.sort_installed':
      'Mengikut tarikh pemasangan',
  'apps.sort_menu':
      'Isih dan tunjuk',
  'apps.sort_size':
      'Mengikut saiz',
  'apps.stat_cache':
      'Cache',
  'apps.stat_unused':
      'Tidak dibuka {n}+ hari',
  'apps.stat_unused_size':
      'tidak digunakan · {size}',
  'apps.storage_settings':
      'Storan & cache',
  'apps.tip_cache':
      'Petua: cache {name} sebanyak {size} dan boleh dikosongkan',
  'apps.tip_clear_cache':
      'Kosongkan cache',
  'apps.tip_restore':
      'Pulihkan {n} petua yang disembunyikan',
  'apps.tip_unused':
      'Petua: {name} sudah {n} hari tidak dibuka dan menggunakan {size}',
  'apps.tip_unused_long':
      'Petua: {name} sudah lama tidak dibuka dan menggunakan {size}',
  'apps.today':
      'hari ini',
  'apps.uninstall':
      'Nyahpasang',
  'apps.uninstalled':
      '{name} dinyahpasang',
  'apps.usage_needed':
      'Kebenaran diperlukan untuk tarikh terakhir dibuka',
  'ved.apply_audio':
      'Tambah bunyi',
  'ved.apply_cut':
      'Potong',
  'ved.apply_mute':
      'Senyapkan',
  'ved.audio_overlap':
      'Di sini sudah ada bunyi yang ditambah',
  'ved.cut_too_much':
      'Keseluruhan video tidak boleh dipotong',
  'ved.frame_failed':
      'Tidak dapat menyimpan bingkai',
  'ved.frame_saved':
      'Foto disimpan: {name}',
  'ved.frame_suffix':
      'bingkai',
  'ved.remove':
      'Buang',
  'ved.replace_off':
      'Campuran',
  'ved.replace_on':
      'Bunyi asal disenyapkan',
  'ved.result':
      'Hasil {t}',
  'ved.row_cut':
      'Potong {start}–{end}',
  'ved.row_mute':
      'Disenyapkan {start}–{end}',
  'ved.save_frame':
      'Simpan bingkai sebagai foto',
  'ved.sel_audio':
      'Pilih di mana bunyi dimainkan',
  'ved.sel_cut':
      'Pilih bahagian yang hendak dipotong dengan pemegang',
  'ved.sel_mute':
      'Pilih bahagian yang hendak disenyapkan',
  'ved.set_end':
      'Tamat di sini',
  'ved.set_start':
      'Mula di sini',
  'ved.sound_off':
      'Tanpa bunyi',
  'ved.sound_on':
      'Bunyi dihidupkan',
  'ved.step_back':
      'Undur satu langkah',
  'ved.step_fwd':
      'Maju satu langkah',
  'ved.title':
      'Edit video',
  'ved.tool_audio':
      'Tambah bunyi',
  'ved.tool_cut':
      'Potong bahagian',
  'ved.tool_mute':
      'Senyapkan bahagian',
  'ved.tool_rotate':
      'Putar',
  'ved.undo':
      'Buat asal',
  'link.bad':
      'Ini bukan pautan Dosya Okuyucu',
  'link.bad_key':
      'Tidak dapat dinyahsulit — pautan tidak lengkap atau rosak',
  'link.copied':
      'Pautan disalin',
  'link.copy':
      'Salin',
  'link.drive_error':
      'Google Drive tidak dapat menyelesaikannya sekarang',
  'link.gone':
      'Pautan telah ditarik balik atau tamat tempoh',
  'link.need_drive':
      'Tidak dapat memuat turun tanpa log masuk — sambungkan Google dalam tab Drive dan cuba lagi',
  'link.need_selection':
      'Pilih fail dalam Hantar pantas dahulu',
  'link.need_signin':
      'Anda perlu menyambungkan Google Drive',
  'link.note_key':
      'Kunci berada selepas # dalam pautan dan tidak pernah sampai ke Google. Sesiapa yang mempunyai pautan boleh membuka fail — kongsi hanya dengan orang yang anda percayai dan tarik balik selepas selesai.',
  'link.offline':
      'Mod luar talian aktif — perkongsian pautan dimatikan',
  'link.open':
      'Buka pautan',
  'link.open_go':
      'Muat turun dan nyahsulit',
  'link.open_hint':
      'Tampal pautan yang anda terima',
  'link.peer':
      'Pautan',
  'link.ready':
      'Pautan sedia',
  'link.received':
      'Diterima daripada pautan: {name}',
  'link.receiving':
      'Menerima daripada pautan',
  'link.revoke':
      'Tarik balik pautan',
  'link.revoke_body':
      'Fail yang disulitkan dipadam daripada Drive anda; pautan berhenti berfungsi.',
  'link.revoke_q':
      'Tarik balik pautan ini?',
  'link.revoked':
      'Pautan ditarik balik',
  'link.send':
      'Hantar pilihan sebagai pautan ({n})',
  'link.sending':
      'Menyulitkan dan memuat naik ke Drive',
  'link.sent_list':
      'Pautan dihantar',
  'link.share':
      'Kongsi',
  'link.share_text':
      'Fail disulitkan melalui Dosya Okuyucu ({name}): {url}',
  'link.sub':
      'Tidak perlu Wi-Fi bersama: fail disulitkan pada telefon dan dimuat naik ke Google Drive anda sendiri; penerima membuka pautan dalam Dosya Okuyucu',
  'link.title':
      'Hantar sebagai pautan (internet)',
  'upd.auto':
      'Beritahu tentang versi baharu',
  'upd.auto_sub':
      'Versi baharu muncul pada skrin utama. Muat turun dan pemasangan hanya bermula apabila anda mengetik; aplikasi dibuka semula sendiri selepas itu.',
  'upd.b_downloading':
      'Memuat turun · {p}%',
  'upd.b_install':
      'Pasang',
  'upd.b_one':
      '{t} · v{v}',
  'upd.b_ready_title':
      'Kemas kini dimuat turun',
  'upd.b_title':
      'Versi baharu tersedia',
  'upd.b_update':
      'Kemas kini',
  'upd.check':
      'Semak kemas kini',
  'upd.checking':
      'Menyemak…',
  'upd.current':
      'Versi dipasang v{v}',
  'upd.download_failed':
      'Muat turun gagal.',
  'upd.downloading':
      'Memuat turun v{v}… {p}%',
  'upd.failed':
      'Tidak dapat menyemak — semak sambungan anda.',
  'upd.found':
      'Versi baharu v{v} tersedia',
  'upd.install_now':
      'Kemas kini sekarang',
  'upd.latest':
      'Anda menggunakan versi terkini (v{v}).',
  'upd.permission':
      'Benarkan "Pasang aplikasi tidak dikenali", kemudian cuba lagi.',
  'upd.play_ready':
      'Kemas kini dimuat turun.',
  'upd.ready':
      'Versi baharu v{v} sedia.',
  'upd.reopen':
      'Buka semula selepas kemas kini',
  'upd.reopen_off':
      'Mati — ketik dan benarkan "Paparkan di atas aplikasi lain". Tanpa itu anda mendapat pemberitahuan selepas pemasangan.',
  'upd.reopen_on':
      'Aktif — aplikasi dibuka semula apabila pemasangan selesai.',
  'upd.restart':
      'Mula semula',
  'upd.security_body':
      'Isu keselamatan telah dibaiki. Sila kemas kini sekurang-kurangnya ke v{v}.',
  'upd.security_title':
      'Kemas kini keselamatan diperlukan',
  'upd.title':
      'Kemas kini',
  'upd.unsupported':
      'Kemas kini automatik tidak tersedia dalam binaan ini.',
  'upd.whats_new':
      'v{v} — Apa yang baharu',
  'vw.dont_save':
      'Jangan simpan',
  'vw.goto_page':
      'Pergi ke halaman…',
  'vw.ocr':
      'Cam teks (OCR)',
  'vw.ocr_copied':
      'Teks dipilih disalin',
  'vw.ocr_failed':
      'OCR gagal: {error}',
  'vw.ocr_none':
      'Tiada teks ditemui (OCR).',
  'vw.preparing':
      'Menyediakan…',
  'vw.prettify':
      'Format (JSON/XML)',
  'vw.print':
      'Cetak',
  'vw.restart_doc':
      'Mula dari awal',
  'vw.resumed_page':
      'Menyambung dari halaman {n}',
  'vw.resumed_slide':
      'Menyambung dari slaid {n}',
  'vw.rotate_failed':
      'Tidak dapat memutar: {error}',
  'vw.rotate_left':
      'Putar 90° ke kiri',
  'vw.rotate_right':
      'Putar 90° ke kanan',
  'vw.rotated_left':
      'Halaman {n} diputar ke kiri',
  'vw.rotated_right':
      'Halaman {n} diputar ke kanan',
  'vw.select_ocr_none':
      'Tiada teks yang boleh dipilih pada halaman ini',
  'vw.select_ocr_running':
      'Mencam teks…',
  'vw.selected_text':
      'Teks dipilih',
  'vw.slides_no_text':
      'Dokumen ini tidak mempunyai teks untuk dijadikan slaid.',
  'vw.slides_share':
      'Pembentangan (.pptx)',
  'vw.to_slides':
      'Tukar kepada slaid',
  'vw.toc_all':
      'Semua',
  'vw.toc_no_match':
      'Tiada tajuk yang sepadan',
  'vw.toc_search':
      'Cari tajuk',
  'vw.word_count':
      'Bilangan perkataan',
  'vw.zoom_in':
      'Zum masuk',
  'vw.zoom_out':
      'Zum keluar',
  'srch.ai_error':
      'Tindakan pintar gagal: {error}',
  'srch.capped':
      ' · 1000 hasil pertama',
  'srch.clear_history':
      'Kosongkan sejarah',
  'srch.content_hits':
      '{n} padanan · baris {line}',
  'srch.in_content':
      'Cari di dalam fail',
  'srch.in_filter_hint':
      'Cari dalam {n} fail yang ditapis…',
  'srch.in_hint':
      'Cari dalam {name}…',
  'srch.index_building':
      'Membina indeks carian — ini hanya sekali; carian seterusnya serta-merta.',
  'srch.index_stale':
      'Fail berubah — indeks sedang dikemas kini di latar belakang.',
  'srch.mode_content':
      'Di dalam fail',
  'srch.mode_found':
      '{n} hasil · {total} fail dicari',
  'srch.mode_name':
      'Pada nama',
  'srch.mode_press':
      'Taip dan tekan "Cari" · mencari dalam {n} fail pada penapis semasa',
  'srch.mode_reading':
      'Membaca {n} / {total} fail…',
  'srch.mode_scope':
      'Mencari nama {n} fail pada penapis semasa',
  'srch.no_result':
      'Tiada hasil ditemui.',
  'srch.opened':
      'Dibuka daripada carian',
  'srch.options':
      'Pilihan carian',
  'srch.rebuild_index':
      'Bina semula indeks',
  'srch.recent':
      'Carian terkini',
  'srch.scope_everywhere':
      'Di mana-mana',
  'srch.scope_here':
      'Dalam folder ini',
  'srch.scope_title':
      'Skop carian',
  'srch.searching':
      'Mencari…',
  'srch.smart_off':
      'Matikan carian pintar',
  'srch.smart_on':
      'Hidupkan carian pintar',
  'srch.understood':
      'Difahami:',
  'card.add':
      'Tambah',
  'card.add_files':
      'Pilih fail',
  'card.add_to':
      'Tambah ke {name}',
  'card.color':
      'Warna',
  'card.edit':
      'Edit kad',
  'card.empty':
      'Kad ini kosong',
  'card.empty_kinds':
      'Hanya jenis ini yang boleh masuk ke kad ini: {kinds}.',
  'card.empty_sub':
      'Ketik “Tambah” untuk memilih fail, atau salin fail dan tampal di sini.',
  'card.icon':
      'Ikon',
  'card.in_important':
      'Dalam Fail Penting',
  'card.in_important_sub':
      'Jika aktif, fail diberi bintang dan dilindungi daripada pemadaman.',
  'card.kind_all':
      'Semuanya',
  'card.name':
      'Nama kad',
  'card.name_hint':
      'cth. Kesihatan, Bil, Anak',
  'card.new':
      'Kad baharu',
  'card.none_fit':
      'Tiada item dipilih yang sepadan dengan jenis kad ini.',
  'card.on_home':
      'Tunjuk pada skrin utama',
  'card.remove':
      'Buang kad',
  'card.remove_msg':
      'Buang kad “{name}”? Folder dan failnya TIDAK dipadam.',
  'card.section':
      'Kad saya',
  'card.skipped':
      '{n} fail dilangkau (jenis tidak dibenarkan dalam kad ini).',
  'card.tile_sub_empty':
      'Kosong',
  'card.view':
      'Paparan',
  'card.view_folder':
      'Folder',
  'card.view_gallery':
      'Galeri',
  'card.what_goes':
      'Apa yang masuk?',
  'chart.add':
      'Sisip',
  'chart.added':
      'Carta ditambah — ditulis ke fail semasa menyimpan',
  'chart.approx':
      '≈ anggaran',
  'chart.area':
      'Kawasan',
  'chart.bar':
      'Palang',
  'chart.barPercent':
      'Palang bertindan 100%',
  'chart.barStacked':
      'Palang bertindan',
  'chart.column':
      'Lajur',
  'chart.columnPercent':
      'Lajur bertindan 100%',
  'chart.columnStacked':
      'Lajur bertindan',
  'chart.doughnut':
      'Donat',
  'chart.file_chart':
      'Carta',
  'chart.group_insert':
      'Sisip',
  'chart.hint':
      'Baris pertama menjadi nama siri, lajur pertama menjadi kategori. Carta ditulis semasa menyimpan dan dipaparkan dalam Excel dan Google Sheets.',
  'chart.insert':
      'Sisip carta',
  'chart.line':
      'Garis',
  'chart.no_numbers':
      'Tiada nombor dalam pilihan',
  'chart.pie':
      'Pai',
  'chart.radar':
      'Radar',
  'chart.scatter':
      'Serakan (XY)',
  'chart.select_range':
      'Pilih dahulu data beserta tajuknya (sekurang-kurangnya dua baris).',
  'chart.title':
      'Tajuk (pilihan)',
  'chart.type':
      'Jenis carta',
  'chart.undo_add':
      'sisip carta',
  'chart.undo_delete':
      'padam carta',
  'chart.undo_edit':
      'edit carta',
  'smo.arrange':
      'Susun semula dan namakan semula',
  'smo.arrange_sub':
      'Seret pada pemegang, ketik pensel untuk menamakan semula',
  'smo.cols':
      '{n} lajur',
  'smo.default_name':
      'Namakan semula kepada "{name}"',
  'smo.hint':
      'Tekan lama: nama dan susunan · Cubit: bilangan lajur',
  'smo.layout':
      'Susun atur',
  'smo.learn_n':
      'Dipelajari daripada {n} pembetulan',
  'smo.learn_none':
      'Pada fail yang salah isih, ketik ⋮ → "Kategori salah?"; fail yang serupa tidak akan mendapat kesilapan yang sama.',
  'smo.learn_reset':
      'Set semula',
  'smo.learn_reset_body':
      'Fail yang anda betulkan kekal betul; hanya pembelajaran untuk fail baharu dibuang.',
  'smo.learn_reset_title':
      'Lupakan yang dipelajari?',
  'smo.learn_title':
      'Pembelajaran',
  'smo.move_first':
      'Alih ke atas',
  'smo.rename':
      'Namakan semula',
  'smo.rename_label':
      'Nama asal: {name}',
  'smo.rename_title':
      'Nama folder',
  'smo.reset':
      'Set semula nama dan susunan',
  'smo.rule':
      'Peraturan pemindahan…',
  'smo.rule_body':
      'Fail yang dikelompokkan ke "{cat}" akan dialihkan ke "{folder}" — {n} sekarang, yang baharu kemudian. Setiap pemindahan boleh dibuat asal; matikan peraturan daripada menu ini.',
  'smo.rule_failed':
      '{n} fail dialihkan, {fail} gagal: {error}',
  'smo.rule_moved':
      '{n} fail dialihkan mengikut peraturan',
  'smo.rule_off':
      'Matikan peraturan pemindahan',
  'smo.rule_ok':
      'Hidupkan',
  'smo.rule_on':
      'Peraturan pemindahan: {folder}',
  'smo.rule_pick':
      'Tetapkan peraturan di sini',
  'smo.rule_title':
      'Peraturan pemindahan',
  'gal.enh_ai':
      'Besarkan 4× dan pulihkan dengan AI',
  'gal.enh_ai_download':
      'Memuat turun model ~5 MB sekali, kemudian berfungsi luar talian',
  'gal.enh_ai_hint':
      'Berjalan pada peranti; foto besar mungkin mengambil satu atau dua minit',
  'gal.enh_already':
      'Imej ini sedang dipertingkat',
  'gal.enh_auto':
      'Peningkatan automatik',
  'gal.enh_auto_hint':
      'Pengurangan hingar + kontras + ketajaman',
  'gal.enh_compare':
      'Sebelum / selepas',
  'gal.enh_denoise':
      'Kurangkan hingar / bijian',
  'gal.enh_job':
      'Peningkatan imej',
  'gal.enh_running':
      'Meningkatkan · {n}%',
  'gal.enh_saved':
      'Salinan disimpan: {name}',
  'gal.enh_sharpen':
      'Tajamkan (kabur)',
  'gal.enh_started':
      'Meningkatkan di latar belakang — teruskan menyemak imbas, anda akan dimaklumkan',
  'gal.enh_working':
      'Meningkatkan…',
  'gal.enhance':
      'Tingkatkan',
  'gal.multi_select':
      'Pilih beberapa foto',
  'gal.repaired':
      'Imej rosak — memaparkan bahagian yang boleh dipulihkan',
  'gal.resize':
      'Ubah saiz',
  'gal.save_rotation':
      'Simpan salinan yang diputar',
  'gal.slideshow':
      'Tayangan slaid',
  'gal.slideshow_every':
      'Setiap {n} saat',
  'gal.tools':
      'Teks & PDF',
  'gal.use_as':
      'Gunakan sebagai…',
  'gal.use_as_failed':
      'Tiada aplikasi yang boleh menggunakan foto ini.',
  'ks.bold':
      'Tebal',
  'ks.copy':
      'Salin',
  'ks.cut':
      'Potong',
  'ks.escape':
      'Tutup / batal',
  'ks.find':
      'Cari',
  'ks.help':
      'Halaman ini',
  'ks.italic':
      'Condong',
  'ks.paste':
      'Tampal',
  'ks.redo':
      'Buat semula',
  'ks.s_tab':
      'Antara sel jadual (⇧ ke belakang)',
  'ks.save':
      'Simpan',
  'ks.select_all':
      'Pilih semua',
  'ks.title':
      'Pintasan papan kekunci',
  'ks.underline':
      'Garis bawah',
  'ks.undo':
      'Buat asal',
  'ks.x_delete':
      'Kosongkan kandungan',
  'ks.x_edge':
      'Lompat ke tepi data (⇧ untuk memilih)',
  'ks.x_enter':
      'Sel di bawah / atas',
  'ks.x_f2':
      'Edit dalam sel',
  'ks.x_home':
      'Permulaan baris · A1',
  'ks.x_move':
      'Alih sel (⇧ untuk melanjutkan)',
  'ks.x_page':
      '20 baris ke atas / bawah',
  'ks.x_tab':
      'Sel seterusnya / sebelumnya',
  'ks.x_type':
      'Mula menaip: menggantikan sel',
  'edit.autosave':
      'Simpan automatik',
  'edit.autosave_sub':
      'Perubahan ditulis ke fail dalam beberapa saat. Draf sentiasa disimpan.',
  'edit.changed_elsewhere':
      'Fail diubah di tempat lain',
  'edit.dont_save':
      'Jangan simpan',
  'edit.draft_discard':
      'Buang',
  'edit.draft_found':
      'Perubahan belum disimpan ditemui ({time})',
  'edit.draft_restore':
      'Pulihkan',
  'edit.draft_restored':
      'Perubahan yang belum disimpan dipulihkan',
  'edit.format_panel':
      'Format',
  'edit.hide_keyboard':
      'Sembunyikan papan kekunci',
  'edit.perf_overlay':
      'Pembilang kependaman pengeditan',
  'edit.perf_overlay_sub':
      'Memaparkan masa dari tekanan kekunci ke skrin di sudut (pembangun)',
  'edit.save_failed_short':
      'Tidak disimpan',
  'edit.saved_at':
      'Disimpan {time}',
  'edit.saving':
      'Menyimpan…',
  'edit.show_keyboard':
      'Papan kekunci',
  'edit.tab_paragraph':
      'Perenggan',
  'edit.tab_styles':
      'Gaya',
  'edit.tab_text':
      'Teks',
  'edit.typing':
      'Menaip',
  'edit.unsaved_body':
      'Dokumen ini mempunyai perubahan yang belum disimpan. Perubahan akan hilang jika anda keluar tanpa menyimpan.',
  'edit.unsaved_title':
      'Simpan perubahan anda?',
  'tf.auto_detect':
      'Kesan bahasa',
  'tf.auto_short':
      'auto',
  'tf.copied':
      'Terjemahan disalin',
  'tf.downloading':
      'Memuat turun model bahasa {lang}…',
  'tf.empty_result':
      'Hasil terjemahan kosong.',
  'tf.first_use':
      'Ini hanya diperlukan kali pertama.',
  'tf.inplace_done':
      '{n} perenggan diterjemahkan pada {pages} halaman.',
  'tf.job_done':
      '{n} halaman diterjemahkan',
  'tf.job_title':
      'Menterjemah dokumen',
  'tf.lang_title':
      'Bahasa terjemahan',
  'tf.no_text':
      'Tiada teks untuk diterjemah.',
  'tf.page_header':
      '— Halaman {n} —',
  'tf.page_translating':
      'Menterjemah halaman {n} / {total}…',
  'tf.partial':
      'Dihentikan — {n} daripada {total} halaman diterjemahkan.',
  'tf.preparing':
      'Menyediakan…',
  'tf.source_lang':
      'Bahasa sumber',
  'tf.stopped':
      'Terjemahan dihentikan.',
  'tf.stopping':
      'Menghentikan…',
  'tf.swap':
      'Tukar bahasa',
  'tf.target_lang':
      'Bahasa sasaran',
  'tf.title':
      'Terjemahan',
  'tf.working':
      'Menterjemah…',
  'pa.add_to':
      'Tambah ke album',
  'pa.added':
      '{n} fail ditambah ke “{name}”',
  'pa.already':
      'Sudah ada dalam “{name}”',
  'pa.area_hidden':
      'Kawasan album disembunyikan. Untuk memaparkannya semula: Analisis dan lagi › Paparan',
  'pa.create':
      'Cipta',
  'pa.delete':
      'Padam album',
  'pa.delete_dir':
      'Padam album beserta failnya',
  'pa.delete_dir_hint':
      '{n} fail dalam folder ini dipadam',
  'pa.delete_hint':
      'Fail dikekalkan',
  'pa.delete_msg':
      'Padam album “{name}”? Failnya dikekalkan.',
  'pa.hidden_done':
      '“{name}” disembunyikan',
  'pa.hide':
      'Sembunyikan album',
  'pa.hide_hidden':
      'Sembunyikan yang tersembunyi',
  'pa.mine':
      'Album saya',
  'pa.name':
      'Nama album',
  'pa.new':
      'Album baharu',
  'pa.remove_from':
      'Keluarkan daripada album',
  'pa.removed':
      '{n} fail dikeluarkan daripada album (tidak dipadam)',
  'pa.rename':
      'Namakan semula',
  'pa.show_hidden':
      'Album tersembunyi ({n})',
  'pa.unhide':
      'Tunjukkan album',
  'voice.ahmet_sub':
      'Microsoft Ahmet · suara lelaki Turki · tanpa muat turun · menggunakan kunci Azure Speech anda sendiri (peringkat percuma: 500 ribu aksara sebulan) · perlukan INTERNET: teks dihantar ke Microsoft; kembali kepada suara peranti apabila luar talian',
  'voice.antalia_sub':
      'Antalia-2 Mini · suara lelaki · 7.6 juta parameter · Apache-2.0 · membaca nombor, tarikh dan jumlah wang dengan betul',
  'voice.azure_bad_region':
      'Rantau terdiri daripada huruf kecil dan angka (cth. westeurope)',
  'voice.azure_help':
      'portal.azure.com → cipta sumber "Speech", peringkat harga Free F0. Salin Key 1 dan Location/Region (cth. westeurope) daripada "Keys and Endpoint". Kunci disimpan disulitkan hanya pada telefon ini.',
  'voice.azure_key':
      'Kunci',
  'voice.azure_region':
      'Rantau (cth. westeurope)',
  'voice.azure_remove':
      'Buang kunci',
  'voice.azure_setup':
      'Masukkan kunci',
  'voice.azure_title':
      'Kunci Azure Speech',
  'voice.ema_sub':
      'EMA Lightning · 8.6 juta parameter · Apache-2.0 · kadar ralat terendah pada penanda aras bahasa Turki',
  'voice.install':
      'Muat turun ({size})',
  'voice.install_failed':
      'Tidak dapat memuat turun suara: {error}',
  'voice.installed':
      '{name} dipasang',
  'voice.installed_size':
      'Dipasang · {size}',
  'voice.intro':
      'Suara Turki semula jadi berjalan pada peranti anda tanpa internet; teks tidak pernah keluar daripada telefon. Suara dimuat turun semasa kali pertama digunakan (supaya aplikasi kekal kecil) dan boleh dibuang bila-bila masa.',
  'voice.kokoro_en_sub':
      'Kokoro English · suara perempuan Inggeris (Heart) · 82 juta parameter · untuk teks Inggeris',
  'voice.kokoro_tr_sub':
      'Kokoro Turkish · suara perempuan (Elif) · 82 juta parameter · suara Turki paling semula jadi; lebih besar dan lebih perlahan · sebutan: eSpeak NG (GPL-3.0)',
  'voice.online':
      'Dalam talian · tanpa muat turun',
  'voice.reading_selected':
      'Digunakan untuk baca kuat',
  'voice.tap_to_use':
      'Ketik untuk digunakan membaca kuat',
  'voice.title':
      'Suara AI',
  'pn.back_to':
      'Kembali ke halaman {n}',
  'pn.bookmarks':
      'Halaman bertanda buku ({n})',
  'pn.bookmarks_empty':
      'Belum ada penanda buku. Semasa membaca, tekan lama lencana halaman atau gunakan butang di sini.',
  'pn.chip_label':
      'Halaman {n} daripada {total}. Ketik untuk ke halaman, tekan lama untuk menanda.',
  'pn.field_hint':
      'Halaman (1–{total})',
  'pn.filmstrip':
      'Jalur halaman',
  'pn.first':
      'Halaman pertama',
  'pn.last':
      'Halaman terakhir',
  'pn.next':
      'Halaman seterusnya (tahan: lebih pantas)',
  'pn.next_page':
      'Halaman seterusnya',
  'pn.position':
      'Halaman {n} daripada {total} · {p}%',
  'pn.prev':
      'Halaman sebelumnya (tahan: lebih pantas)',
  'pn.prev_page':
      'Halaman sebelumnya',
  'pn.progress_pct':
      '{n}% dibaca',
  'pn.quick_jump':
      'Lompat pantas',
  'pn.star':
      'Tanda buku halaman ini',
  'pn.starred':
      'Halaman {n} ditanda buku',
  'pn.title':
      'Pergi ke halaman',
  'pn.unstar':
      'Buang tanda buku',
  'pn.unstarred':
      'Tanda buku dibuang daripada halaman {n}',
  'rc.after':
      'Selepas',
  'rc.before':
      'Sebelum',
  'rc.confirm_all':
      '{n} fail lama akan dialihkan ke tong sampah. Fail yang diubah saiz kekal.',
  'rc.done_snack':
      '{n} fail lama dialihkan ke tong sampah',
  'rc.empty':
      'Tiada apa untuk dibandingkan',
  'rc.keep_all':
      'Simpan semua',
  'rc.keep_both':
      'Simpan kedua-duanya',
  'rc.new':
      'Baharu',
  'rc.new_trashed':
      'Fail baharu dipadam',
  'rc.old':
      'Lama',
  'rc.old_trashed':
      'Fail lama berada dalam tong sampah',
  'rc.open_new':
      'Buka yang baharu',
  'rc.open_old':
      'Buka yang lama',
  'rc.title':
      'Bandingkan lama ↔ baharu',
  'rc.title_enhance':
      'Sebelum / selepas',
  'rc.trash_all_old':
      'Padam semua yang lama',
  'rc.trash_new':
      'Padam yang baharu',
  'rc.trash_old':
      'Padam yang lama',
  'rc.view_side':
      'Bersebelahan',
  'rc.view_slider':
      'Peluncur',
  'sf.building_pdf':
      'Menyediakan PDF…',
  'sf.default_prefix':
      'Imbas',
  'sf.job_name':
      'Imbas dokumen',
  'sf.ocr_progress':
      'Mengimbas teks… ({n} / {total} halaman)',
  'sf.save_failed':
      'Tidak dapat menyimpan imbasan: {error}',
  'sf.saved_n':
      '{n} halaman disimpan sebagai PDF',
  'sf.scanner_failed':
      'Tidak dapat membuka pengimbas: {error}\nKebenaran kamera mungkin belum diberikan.',
  'sf.skip_ocr':
      'Langkau teks',
  'sf.tip1_body':
      'Letakkan dokumen secara rata; tepinya dikesan secara automatik.',
  'sf.tip1_title':
      '1 · Tangkap halaman',
  'sf.tip2_body':
      'Ketik ikon halaman-dengan-tambah biru di kanan bawah: kamera dibuka semula untuk halaman seterusnya. Ulang untuk setiap halaman.',
  'sf.tip2_title':
      '2 · Guna butang halaman ➕ untuk halaman lain',
  'sf.tip3_body':
      'Ketik selepas semua halaman ditangkap. Terlupa satu? Tambah kemudian dengan "Tambah halaman" dalam studio dokumen.',
  'sf.tip3_title':
      '3 · "Seterusnya" MENAMATKAN imbasan',
  'sf.tip_next_label':
      'Seterusnya',
  'sf.tips_never':
      'Faham, jangan tunjuk lagi',
  'sf.tips_start':
      'Mula mengimbas',
  'sf.tips_sub':
      'Tiga butang penting pada skrin pengimbas yang dibuka seterusnya:',
  'sf.tips_title':
      'Cara mengimbas',
  'sf.title':
      'Menyediakan dokumen',
  'pick.all':
      'Semua',
  'pick.browse_folders':
      'Semak imbas folder',
  'pick.empty':
      'Tiada fail yang sepadan dalam folder ini.',
  'pick.failed':
      'Fail tidak dapat diserahkan kepada aplikasi yang meminta.',
  'pick.filter_hint':
      'Cari fail {kind}…',
  'pick.for_caller':
      'Untuk {app}',
  'pick.last_folder':
      'Folder terakhir digunakan',
  'pick.matches_count':
      '{n} fail',
  'pick.need_permission':
      'Kebenaran storan diperlukan untuk menyenaraikan fail.',
  'pick.no_filter_matches':
      'Tiada fail yang sepadan dengan carian.',
  'pick.no_matches':
      'Tiada fail jenis ini ditemui. Semak imbas folder atau gunakan "Lain-lain" untuk Drive/Galeri.',
  'pick.other_sources':
      'Lain-lain',
  'pick.search_hint':
      'Cari semua fail…',
  'pick.select_all':
      'Pilih semua',
  'pick.select_n':
      'Pilih ({n})',
  'pick.sort_name':
      'Mengikut nama',
  'pick.sort_newest':
      'Terkini',
  'pick.title':
      'Pilih fail',
  'pick.unreadable':
      'Folder ini tidak dapat dibaca.',
  'sa.card_sub':
      'Melihat ISI imej: imej ucapan selamat pagi, meme teks dan poster, foto kabur dan gelap; dokumen pendua dan terlupa',
  'sa.clean':
      'Tiada yang tidak perlu ditemui',
  'sa.expense_do':
      'Tambah perbelanjaan',
  'sa.expense_done':
      'Ditambah ke Giderler.csv',
  'sa.expense_hint':
      'Resit/invois: anda boleh menambah jumlahnya ke senarai perbelanjaan',
  'sa.expense_none':
      'Tiada tarikh atau jumlah pada resit',
  'sa.intro':
      'Analisis berjalan sepenuhnya pada telefon anda (pengecaman teks tanpa internet). 1,500 imej sembang terkini dibaca; larian kedua hanya melihat yang baharu. Tiada apa dipadam secara automatik: semak setiap kumpulan dan alihkan pilihan anda ke tong sampah.',
  'sa.job_name':
      'Imej dan dokumen',
  'sa.job_title':
      'Analisis pintar',
  'sa.rescan':
      'Analisis semula',
  'sa.start':
      'Mula analisis',
  'sa.step_docs':
      'Menyemak dokumen',
  'sa.step_done':
      '{n} fail · {size} boleh dibersihkan',
  'sa.step_images':
      'Membaca imej: {n}/{total}',
  'sa.title':
      'Analisis pembersihan pintar',
  'sa.trash_sub':
      '{n} item · {size} — kosongkan untuk mendapatkan ruang',
  'sa.trash_title':
      'Tong sampah',
  'sa.vault_do':
      'Alih ke peti besi',
  'sa.vault_hint':
      'Dokumen pengenalan: disyorkan disimpan dalam peti besi yang disulitkan',
  'trash.auto_days':
      'Dipadam secara automatik selepas {n} hari',
  'trash.auto_off':
      'Pembersihan automatik mati',
  'trash.delete_forever':
      'Padam kekal',
  'trash.delete_one_body':
      '“{name}” akan dipadam dan tidak boleh dipulihkan.',
  'trash.deleted_one':
      '“{name}” dipadam secara kekal.',
  'trash.empty':
      'Tong sampah kosong',
  'trash.empty_action':
      'Kosongkan',
  'trash.empty_confirm_title':
      'Kosongkan tong sampah?',
  'trash.emptying':
      'Mengosongkan tong sampah',
  'trash.emptying_name':
      'Mengosongkan tong sampah',
  'trash.filtered':
      '{n} / {total} item',
  'trash.restore':
      'Pulihkan',
  'trash.restore_all':
      'Pulihkan semua',
  'trash.restore_all_done':
      '{n} item dipulihkan',
  'trash.restore_all_name':
      'Memulihkan daripada tong sampah',
  'trash.restore_failed':
      'Tidak dapat memulihkan: {error}',
  'trash.search':
      'Cari dalam tong sampah',
  'trash.search_hint':
      'Cari dalam tong sampah…',
  'trash.title':
      'Tong sampah',
  'ana.by_type':
      'Mengikut jenis',
  'ana.cache_total':
      '{v} daripadanya ialah cache — selamat dikosongkan',
  'ana.filter_count':
      '{n} penapis',
  'ana.free_space':
      'Bebaskan ruang (cadangan pembersihan)',
  'ana.free_space_note':
      'Tong sampah, pendua, imej serupa, media sembang dan bersepah — semuanya di satu tempat',
  'ana.largest':
      'Fail terbesar',
  'ana.no_files':
      'Tiada fail untuk dipaparkan.',
  'ana.no_result':
      'Tiada hasil ditemui.',
  'ana.no_scan':
      'Belum ada hasil imbasan.',
  'ana.result_count':
      '{n} hasil',
  'ana.results':
      'Hasil carian',
  'ana.scope_all':
      'Semua',
  'ana.search_all':
      'Cari semua fail…',
  'ana.searching':
      'Mencari…',
  'ana.similar_note':
      'Bidikan berturut-turut dan foto yang hampir serupa',
  'ana.total_summary':
      '{n} fail · {size}',
  'ana.usage_unreadable':
      'Penggunaan storan tidak dapat dibaca.',
  'ana.used_free':
      '{used} digunakan · {free} bebas',
  'help.ftitle':
      'Ciri & bantuan',
  'help.hint':
      'Cari ciri: pangkas, kata laluan, gabung…',
  'help.how':
      'Caranya',
  'help.more':
      '{n} ciri lagi',
  'help.none':
      'Tiada ciri untuk "{q}". Anda boleh memintanya di bawah.',
  'help.open':
      'Bantuan: semua ciri',
  'help.report':
      'Laporkan masalah',
  'help.report_body':
      'Terangkan masalah secara ringkas (apa yang anda lakukan, apa yang dijangka, apa yang berlaku):',
  'help.req_field':
      'Permintaan anda…',
  'help.req_hint':
      'Terangkan apa yang anda mahukan daripada aplikasi. Permintaan disimpan pada peranti ini dan dibuka dalam pelayar untuk dihantar kepada pembangun.',
  'help.req_mine':
      'Permintaan saya',
  'help.req_saved':
      'Permintaan disimpan pada peranti ini (pelayar tidak dapat dibuka)',
  'help.req_send':
      'Hantar',
  'help.req_sent':
      'Permintaan disimpan dan dibuka',
  'help.request':
      'Minta ciri',
  'help.tile_sub':
      'Kebenaran, PIN peti besi, perkongsian rangkaian, kunci AI',
  'help.title':
      'Bantuan & Soalan Lazim',
  'help.where':
      'Di mana',
  'important.badge':
      'Fail penting',
  'important.by_type':
      'Mengikut jenis',
  'important.create_folder':
      'Cipta folder',
  'important.delete_body_permanent':
      '{n} item penting ({names}) akan dipadam SECARA KEKAL. Anda pasti?',
  'important.delete_body_trash':
      '{n} item penting ({names}) akan dialihkan ke tong sampah. Anda pasti?',
  'important.delete_category':
      'Padam kategori',
  'important.delete_category_msg':
      'Padam kekal kategori “{name}” beserta {n} failnya?',
  'important.delete_category_msg_trash':
      'Alihkan kategori “{name}” beserta {n} failnya ke tong sampah?',
  'important.gallery':
      'Galeri',
  'important.gallery_all':
      'Semua',
  'important.gallery_empty':
      'Tiada fail penting jenis ini.',
  'important.missing':
      'Folder fail penting tidak wujud',
  'important.new_subfolder':
      'Kategori baharu',
  'important.open_in_browser':
      'Buka folder dalam pelayar',
  'important.rename_category':
      'Namakan semula',
  'important.search':
      'Cari fail penting',
  'important.subfolders':
      'Kategori',
  'important.title':
      'Fail penting',
  'ink.eraser':
      'Pemadam',
  'ink.eraser_hint':
      'Leret pada coretan untuk memadam',
  'ink.failed':
      'Tidak dapat menyimpan: {error}',
  'ink.hand':
      'Alih',
  'ink.hand_hint':
      'Seret untuk mengalih · leret atas/bawah untuk menukar halaman. Dengan pen, guna dua jari.',
  'ink.highlighter':
      'Penyerlah',
  'ink.pen':
      'Pen',
  'ink.redo':
      'Buat semula',
  'ink.save_note':
      'Lukisan dan teks ditambah secara kekal pada halaman.',
  'ink.size_l':
      'Besar',
  'ink.size_m':
      'Sederhana',
  'ink.size_s':
      'Kecil',
  'ink.text':
      'Teks',
  'ink.text_hint':
      'Teks yang akan diletakkan',
  'ink.text_title':
      'Tambah teks',
  'ink.title':
      'Lukis & anotasi',
  'ink.unsaved_body':
      'Simpan lukisan dan teks anda?',
  'ink.unsaved_title':
      'Coretan belum disimpan',
  'job.channel_desc':
      'Kemajuan tugas yang berjalan seperti membebaskan ruang, mencari pendua, menyalin dan mengubah saiz.',
  'job.channel_name':
      'Operasi fail',
  'job.error_generic':
      'Sesuatu telah berlaku.',
  'job.eta':
      'baki ~{time}',
  'job.finished':
      'Selesai.',
  'job.more_running':
      '+{n} lagi',
  'job.op_created':
      'Siap: {name}',
  'job.op_done_n':
      '{n} item selesai',
  'job.op_errors':
      '{n} ralat',
  'job.op_items':
      '{n} item',
  'job.op_skipped':
      '{n} dilangkau',
  'job.step':
      'Langkah {n}/{total} · {text}',
  'job.stopped_detail':
      'Dihentikan · {detail}',
  'job.title_cancelled':
      '{name} dihentikan',
  'job.title_done':
      '{name} selesai',
  'job.title_failed':
      '{name} gagal',
  'job.title_interrupted':
      '{name} terganggu',
  'job.took':
      'mengambil masa {time}',
  'aiset.budget':
      'Bajet fail harian',
  'aiset.budget_unlimited':
      'Tanpa had',
  'aiset.excerpt':
      'Teks yang dihantar',
  'aiset.excerpt_sub':
      'Teks maksimum yang dihantar ke awan bagi setiap fail.',
  'aiset.exclude_add':
      'Kecualikan folder',
  'aiset.exclude_pick':
      'Kecualikan folder ini',
  'aiset.excluded':
      'Folder yang dikecualikan',
  'aiset.forget':
      'Kosongkan memori AI',
  'aiset.forget_confirm':
      'Padam hasil analisis (tag, ringkasan, cadangan)? Fail anda kekal.',
  'aiset.forget_sub':
      'Memadam semua rekod analisis. Fail anda tidak disentuh.',
  'aiset.hidden':
      'Fail tersembunyi',
  'aiset.hidden_sub':
      'Analisis juga fail dan folder berawalan titik?',
  'aiset.include_again':
      'Sertakan semula',
  'aiset.send_images':
      'Hantar imej',
  'aiset.send_text':
      'Hantar petikan teks',
  'aiset.types':
      'Jenis yang dianalisis',
  'aiset.types_sub':
      'Jenis yang ditinggalkan tidak pernah dibaca.',
  'br.done':
      '{n} fail dinamakan semula.',
  'br.file_count':
      '{n} fail',
  'br.find':
      'Cari (dalam nama lama)',
  'br.more_files':
      '… dan {n} fail lagi',
  'br.partial':
      '{n} fail dinamakan semula, {fail} ralat: {first}',
  'br.pattern':
      'Corak nama',
  'br.preset_date_name':
      'Tarikh + nama lama',
  'br.preset_date_seq':
      'Tarikh + nombor',
  'br.preset_name_seq':
      'Nama lama + nombor',
  'br.preset_prefix':
      'Cuti-1, Cuti-2…',
  'br.preview':
      'Pratonton',
  'br.replace':
      'Ganti',
  'br.save_template':
      'Simpan corak',
  'br.start':
      'Mula',
  'br.title':
      'Namakan semula secara kelompok',
  'br.will_change':
      '{n} fail akan berubah',
  'br.will_change_problems':
      '{n} fail akan berubah · {problems} nama bermasalah akan dilangkau',
  'dock.ai':
      'Pintar',
  'dock.apps':
      'Aplikasi',
  'dock.downloads':
      'Muat turun',
  'dock.drive':
      'Drive',
  'dock.edit_body':
      'Sampah, Pindah dan Imbas kekal. Anda boleh menambah sehingga 2 butang tambahan pada setiap sisi (Drive juga tambahan).',
  'dock.edit_title':
      'Edit panel bawah',
  'dock.extra_left':
      'Butang tambahan (kiri)',
  'dock.extra_right':
      'Butang tambahan (kanan)',
  'dock.free_space':
      'Bebaskan',
  'dock.history':
      'Sejarah',
  'dock.jobs':
      'Tugas',
  'dock.library':
      'Pustaka',
  'dock.long_press':
      'Tekan lama: edit panel bawah',
  'dock.new_doc':
      'Dokumen baharu',
  'dock.scan':
      'Imbas',
  'dock.trash':
      'Sampah',
  'dock.vault':
      'Peti besi',
  'flt.active_count':
      '{n} penapis aktif',
  'flt.all':
      'Semua',
  'flt.asc':
      'Menaik',
  'flt.chat_kind':
      'Jenis fail pemesejan',
  'flt.clear':
      'Kosongkan',
  'flt.date':
      'Tarikh',
  'flt.desc':
      'Menurun',
  'flt.direction':
      'Diterima / dihantar',
  'flt.file_type':
      'Jenis fail',
  'flt.hide_dupes':
      'Sembunyikan salinan pendua',
  'flt.none_left':
      'Tiada fail berbaki',
  'flt.pick_range':
      'Pilih julat tarikh',
  'flt.size':
      'Saiz',
  'flt.sort':
      'Pengisihan',
  'flt.source':
      'Sumber (boleh pilih beberapa)',
  'flt.tag':
      'Tag (orang / kumpulan)',
  'flt.title':
      'Tapis dan isih',
  'ig.clear_all':
      'Kosongkan semua penapis',
  'ig.empty':
      'Belum ada fail dalam Fail Penting. Gunakan ⋮ › Tambah ke penting pada mana-mana fail untuk mengumpulkannya di sini.',
  'ig.folder_root':
      'Umum',
  'ig.no_match':
      'Tiada fail yang sepadan dengan penapis ini.',
  'ig.result':
      '{n} fail',
  'ig.search_hint':
      'Cari fail penting…',
  'ig.sec_folder':
      'Kategori (subfolder)',
  'ig.sec_size':
      'Saiz',
  'ig.sec_tags':
      'Tag',
  'ig.sec_time':
      'Bila',
  'ig.sec_topic':
      'Topik dokumen',
  'ig.sort':
      'Isih',
  'ig.tile_empty':
      'Belum ada fail',
  'ig.title':
      'Galeri penting',
  'ig.topic':
      'Topik & folder',
  'ig.type':
      'Jenis',
  'ig.when':
      'Masa & saiz',
  'sx.pdf_quality':
      'Kualiti PDF',
  'sx.q_high':
      'Tinggi',
  'sx.q_medium':
      'Sederhana',
  'sx.q_small':
      'Kecil',
  'sx.save_pdf':
      'Simpan PDF dengan kualiti ini',
  'sx.saved':
      'Disimpan: {name}',
  'sx.sheet':
      'Halaman',
  'sx.title':
      'Eksport',
  'sx.to_excel':
      'Jadual Excel',
  'sx.to_excel_sub':
      'Jadual dikesan dan dipecahkan kepada sel',
  'sx.to_image_sub':
      'Setiap halaman disimpan sebagai fail imej berasingan',
  'sx.to_jpg':
      'Simpan sebagai imej (JPEG)',
  'sx.to_png':
      'Simpan sebagai imej (PNG)',
  'sx.to_txt':
      'Teks biasa (TXT)',
  'sx.to_word':
      'Dokumen Word (boleh diedit)',
  'sx.to_word_sub':
      'Teks yang dicam, perenggan demi perenggan',
  'sx.working':
      'Mengeksport…',
  'alias.action':
      'Nama kedua pintar',
  'alias.action_hint':
      'AI mencadangkan nama dan kategori; nama fail kekal',
  'alias.batch_done':
      '{n} fail mendapat nama kedua',
  'alias.batch_failed':
      '{n} fail gagal',
  'alias.batch_hint':
      'Cadangkan nama dan kategori untuk semua yang dipilih dengan AI',
  'alias.batch_name':
      '{n} fail',
  'alias.batch_started':
      'Memberi nama kedua pada {n} fail; diteruskan walaupun anda keluar daripada aplikasi',
  'alias.batch_title':
      'Memberi nama kedua pintar',
  'alias.change':
      'Ubah',
  'alias.done':
      'Saya menamakannya: {name}',
  'alias.done_tag':
      'Saya menamakannya: {name} · Tag: {tag}',
  'alias.failed':
      'Nama kedua tidak ditemui; anda boleh memasukkannya sendiri.',
  'alias.label':
      'Nama kedua (nama fail kekal)',
  'alias.manual':
      'Beri nama kedua',
  'alias.saved':
      'Nama kedua: {name}',
  'alias.started':
      'Menyediakan nama kedua pintar… Nama fail tidak diubah.',
  'org.action':
      'Susun {n} fail',
  'org.all_placed':
      'Semuanya sudah kelihatan pada tempatnya ({n} fail sudah dalam folder yang betul.)',
  'org.already_placed':
      '{n} fail sudah dalam folder yang betul.',
  'org.by_what':
      'Kumpulkan mengikut apa?',
  'org.confirm_title':
      'Susun?',
  'org.done':
      '{n} fail disusun.',
  'org.include_sub':
      'Sertakan subfolder',
  'org.nothing':
      'Tiada apa untuk disusun',
  'org.nothing_body':
      'Tiada fail untuk disusun dalam folder ini.',
  'org.open_folder':
      'Buka folder',
  'org.partial':
      'Beberapa fail tidak dapat dialihkan: {error}',
  'org.plan':
      '{files} fail → {folders} folder',
  'org.preview':
      'Pratonton',
  'org.title':
      'Susun automatik',
  'org.working':
      'Menyusun',
  'org.working_name':
      'Menyusun automatik',
  'scp.credit_free':
      'Kredit Pro (tidak lama lagi): {free} fail pertama percuma — pilihan ini muat.',
  'scp.credit_pack':
      'Kredit Pro (tidak lama lagi): {free} fail pertama percuma; selebihnya memerlukan pakej {n} fail ≈ {tl} TL.',
  'scp.done_left':
      'Disusun {d} · berbaki {r}',
  'scp.files':
      '{n} fail',
  'scp.g_docs':
      'Dokumen',
  'scp.g_images':
      'Foto',
  'scp.g_screenshots':
      'Tangkapan skrin',
  'scp.g_videos':
      'Video (bingkai muka)',
  'scp.note':
      'Susunan: dokumen dan tangkapan skrin dahulu, video terakhir. Jenis atau tempat yang dimatikan dilangkau; fail yang sudah disusun kekal.',
  'scp.own_key':
      'Tanpa had dan percuma dengan kunci Gemini anda sendiri.',
  'scp.selected':
      'Dipilih: {n} fail',
  'scp.sources':
      'Tempat',
  'scp.src_other':
      'Folder lain',
  'scp.tile_sub':
      '{g}/{gt} jenis · {s}/{st} tempat dipilih',
  'scp.title':
      'Apa yang perlu kita susun?',
  'scp.types':
      'Jenis',
  'sk.applied':
      'Mod {type} dilaksanakan',
  'sk.book':
      'Buku',
  'sk.book_split':
      'Dipecahkan kepada {n} halaman',
  'sk.business_card':
      'Kad nama',
  'sk.card_none':
      'Tiada butiran hubungan pada kad',
  'sk.card_preview_title':
      'Simpan kad kenalan',
  'sk.card_save_action':
      'Simpan kenalan (.vcf)',
  'sk.card_saved':
      'Kad kenalan disimpan: {name}',
  'sk.document':
      'Dokumen',
  'sk.id_card':
      'Kad pengenalan',
  'sk.id_combined':
      'Depan dan belakang digabungkan dalam satu halaman',
  'sk.id_need_two':
      'Imbas depan dan belakang untuk kad pengenalan (2 halaman)',
  'sk.photo':
      'Foto',
  'sk.receipt':
      'Resit',
  'sk.whiteboard':
      'Papan putih',
  'sk.working':
      'Melaksanakan jenis…',
  'bills.count_month':
      '{n} bil/resit',
  'bills.due':
      'akhir bayar {date}',
  'bills.empty':
      'Belum ada bil ditemui. Apabila analisis pintar mengenali bil dan resit, ringkasan bulanan muncul di sini.',
  'bills.no_amount':
      'jumlah tidak ditemui',
  'bills.no_key':
      'Tanpa kunci API Gemini, jumlah dan tarikh diteka pada peranti; tambah kunci untuk pembacaan yang lebih tepat.',
  'bills.overdue':
      'LEWAT TEMPOH ({date})',
  'bills.paid':
      'Dibayar',
  'bills.read_n':
      '{n} bil dibaca',
  'bills.read_pending':
      'Baca {n} bil baharu',
  'bills.reading':
      'Membaca bil… {n}/{total}',
  'bills.refresh':
      'Baca semula bil',
  'bills.this_month':
      'Perbelanjaan bulan ini',
  'bills.title':
      'Bil dan perbelanjaan',
  'bills.unknown':
      'Penerbit tidak dikenali',
  'bills.upcoming':
      'Hampir akhir bayar',
  'dro.conflict_body':
      '{name} berubah pada telefon dan juga pada Drive. Yang mana perlu dikekalkan?',
  'dro.conflict_title':
      'Dua versi',
  'dro.keep_both':
      'Simpan kedua-duanya',
  'dro.local_body':
      '{name} diedit pada telefon tetapi belum dimuat naik ke Drive.',
  'dro.local_title':
      'Salinan telefon berubah',
  'dro.phone_suffix':
      'telefon',
  'dro.pin':
      'Sediakan luar talian',
  'dro.pinned':
      '{name} tersedia luar talian',
  'dro.pinned_label':
      'Luar talian',
  'dro.sync_failed':
      'Tidak dapat menyegerak',
  'dro.unpin':
      'Buang salinan luar talian',
  'dro.unpinned':
      '{name} kini boleh dikosongkan untuk menjimatkan ruang',
  'dro.uploaded':
      '{name} dimuat naik ke Drive',
  'dro.use_drive':
      'Guna versi Drive',
  'dro.use_phone':
      'Muat naik versi telefon ke Drive',
  'qrf.connected_next':
      'Disambungkan → langkah 2',
  'qrf.err_hotspot':
      'Tidak dapat mencipta rangkaian sementara — jika tempat liputan hidup, matikan dan cuba lagi.',
  'qrf.err_location':
      'Hidupkan Lokasi untuk rangkaian sementara.',
  'qrf.err_perm':
      'Rangkaian sementara memerlukan kebenaran "Peranti berdekatan"/lokasi.',
  'qrf.err_unsupported':
      'Telefon ini tidak dapat mencipta rangkaian sementara (perlu Android 8+).',
  'qrf.join_failed':
      'Tidak dapat menyertai rangkaian penghantar.',
  'qrf.no_address':
      'Alamat rangkaian tidak ditemui; tutup dan cuba lagi.',
  'qrf.no_common_wifi':
      'Tiada Wi-Fi yang sama?',
  'qrf.preparing':
      'Menyediakan…',
  'qrf.scan':
      'Imbas kod QR',
  'qrf.scan_sub':
      'Kod pada skrin penghantar — fail masuk ke folder ini',
  'qrf.scan_unavailable':
      'Tidak dapat membuka pengimbas kod (perlu perkhidmatan Google Play).',
  'qrf.scan_unknown':
      'Ini bukan kod perkongsian Dosyalarım.',
  'qrf.scan_wifi_only':
      'Itu kod 1 (rangkaian). Imbas kod ke-2 pada skrin penghantar.',
  'qrf.served':
      'Dimuat turun: {n}',
  'scr.add_failed':
      'Tidak dapat menambah halaman: {error}',
  'scr.add_pages':
      'Tambah halaman',
  'scr.add_pages_hint':
      'Kamera atau galeri',
  'scr.change_location':
      'Ubah lokasi',
  'scr.class_hint':
      'Nampaknya {type} — alihkan ke "Önemli Dosyalar/{folder}"?',
  'scr.class_move':
      'Alihkan',
  'scr.move_failed':
      'Tidak dapat mengalihkan: {error}',
  'scr.moved':
      'Dialihkan · {folder}',
  'scr.open_pdf':
      'Buka PDF',
  'scr.pages_added':
      '{n} halaman ditambah',
  'scr.rename':
      'Namakan semula',
  'scr.rename_failed':
      'Tidak dapat menamakan semula: {error}',
  'scr.save_here':
      'Simpan di sini',
  'scr.saved_here':
      '{name} disimpan — dipaparkan dalam foldernya',
  'scr.tab_text':
      'Teks',
  'smart.count':
      '{n} fail',
  'smart.create':
      'Carian pintar baharu',
  'smart.delete':
      'Padam carian pintar',
  'smart.delete_body':
      'Hanya carian tersimpan yang dipadam; fail anda tidak disentuh.',
  'smart.empty':
      'Belum ada carian pintar',
  'smart.empty_sub':
      'Simpan carian (cth. invois, kad pengenalan, kontrak): padanan daripada susunan pintar terkumpul di sini, yang baharu diberi lencana.',
  'smart.entry_n':
      '{n} carian tersimpan',
  'smart.entry_sub':
      'Simpan carian; fail baharu yang sepadan terkumpul sendiri',
  'smart.header':
      'Cari "{query}" · {n} fail · {size} — padanan daripada susunan pintar dan analisis fail, dikemas kini secara automatik.',
  'smart.new_badge':
      'Baharu',
  'smart.new_n':
      '{n} baharu',
  'smart.no_items':
      'Belum ada fail yang sepadan. Akan muncul apabila susunan pintar mengisih fail baharu.',
  'smart.query_hint':
      'Cari apa? (cth. invois, kad pengenalan, kontrak)',
  'smart.rename':
      'Namakan semula',
  'smart.title':
      'Carian pintar',
  'smf.action':
      'Kategori salah?',
  'smf.action_hint':
      'sekarang: {cat}',
  'smf.body':
      'Pilih yang betul: fail beralih ke sana dan Susunan pintar mempelajarinya, supaya fail yang serupa tidak mendapat kesilapan yang sama.',
  'smf.docs':
      'Dokumen',
  'smf.images':
      'Imej',
  'smf.kept':
      'Baik, ditandakan betul',
  'smf.learned':
      'Dipelajari: dibetulkan kepada "{cat}"',
  'smf.learned_n':
      'Dipelajari: fail ini dan {n} fail serupa kini "{cat}"',
  'smf.list_hint':
      'Fail di tempat yang salah? Menu ⋮ → "Kategori salah?" — Susunan pintar belajar.',
  'smf.now':
      'Susunan pintar menyatakan "{cat}"',
  'smf.similar_body':
      '{n} fail serupa juga dikelaskan sebagai "{from}". Jadikan "{to}" juga?',
  'smf.similar_go':
      'Ya, betulkan',
  'smf.similar_title':
      'Betulkan fail serupa juga?',
  'smf.title':
      'Sepatutnya apa?',
  'smf.was_right':
      'Memang betul',
  'usb.diag_copied':
      'Laporan disalin',
  'usb.diag_devices':
      'Peranti disambungkan',
  'usb.diag_drivable':
      'boleh dikendalikan',
  'usb.diag_host':
      'Hos USB (OTG)',
  'usb.diag_mass':
      'storan massa',
  'usb.diag_no_device':
      'Tiada peranti disambungkan',
  'usb.diag_permission':
      'kebenaran',
  'usb.diag_readable':
      'boleh dibaca',
  'usb.diag_saf':
      'Kebenaran folder',
  'usb.diag_sub':
      'Mengukur saluran mana yang melihat pemacu disambungkan dan mencadangkan langkahnya.',
  'usb.diag_usable':
      'Volum yang boleh disemak imbas',
  'usb.eject_done':
      'Pemacu dilepaskan — anda boleh mencabutnya sekarang.',
  'usb.format_read_only':
      '{fmt} dibuka baca sahaja — anda boleh menyalin fail ke telefon.',
  'usb.open_raw_failed_title':
      'Tidak dapat membuka pemacu',
  'usb.write_protected':
      'Pemacu dilindungi tulis secara perkakasan — baca sahaja.',
  'fb.attach_logs':
      'Lampirkan log ralat terkini',
  'fb.attach_logs_sub':
      'Membantu kami menemui masalah',
  'fb.copied':
      'Teks disalin ke papan klip',
  'fb.copy':
      'Salin teks',
  'fb.failed':
      'Tidak dapat menghantar, cuba lagi',
  'fb.idea_hint':
      'Apa yang anda mahukan? Pada skrin mana, dan bagaimana?',
  'fb.more':
      'Analisis & lagi',
  'fb.preview':
      'Pratonton',
  'fb.privacy':
      'Hanya teks anda, versi aplikasi dan versi Android yang dihantar. Nama fail, kandungan fail dan kunci API anda tidak pernah dihantar. Ketik "Pratonton" untuk melihat teks penuh sebelum menghantar.',
  'fb.send':
      'Hantar',
  'fb.thanks':
      'Terima kasih, laporan anda sedia',
  'fb.tile_sub':
      'Hantar masalah atau cadangan kepada kami',
  'fb.title':
      'Laporkan pepijat / permintaan',
  'fb.type':
      'Jenis',
  'peer.ask_switch':
      'Sahkan fail masuk',
  'peer.change_folder':
      'Tukar folder',
  'peer.channel_desc':
      'Apabila fail diterima daripada peranti berdekatan.',
  'peer.channel_name':
      'Peranti berdekatan',
  'peer.declined_by_peer':
      'Peranti lain menolak fail',
  'peer.device_name':
      'Nama peranti ini',
  'peer.notify_title':
      'Fail diterima',
  'peer.other_apps':
      'WhatsApp, Bluetooth, e-mel…',
  'peer.other_apps_title':
      'Dengan aplikasi lain',
  'peer.save_to':
      'Disimpan ke: {path}',
  'peer.send_failed':
      'Tidak dapat menghantar: {error}',
  'peer.send_stopped':
      'Dihentikan ({n} fail dihantar)',
  'peer.sent':
      '{n} fail dihantar ke {name}',
  'peer.speed':
      '{done} / {total} · {speed}/s',
  'tts.ai_needs_key':
      'Bacaan pintar memerlukan kunci API Gemini (Tetapan).',
  'tts.ai_read':
      'Bacaan pintar',
  'tts.ai_read_off':
      'Bacaan pintar mati.',
  'tts.ai_read_on':
      'Bacaan pintar aktif: teks dikemaskan sebelum setiap halaman dibaca.',
  'tts.default_voice':
      'Lalai peranti',
  'tts.engine':
      'Enjin suara',
  'tts.engine_default':
      'Lalai sistem',
  'tts.neural_get':
      'Ketik untuk memuat turun',
  'tts.neural_sub':
      'Suara AI · pada peranti, luar talian',
  'tts.pitch':
      'Nada',
  'tts.rate':
      'Kelajuan',
  'tts.sample':
      'Beginilah suara ini membaca. Suka?',
  'tts.settings':
      'Baca kuat',
  'tts.try':
      'Cuba',
  'ux47.clip_empty':
      'Papan klip tiada teks',
  'ux47.clutter_select_hint':
      'Pilih item untuk disembunyikan atau dipadam',
  'ux47.imp_add_file':
      'Tambah fail',
  'ux47.imp_empty_folders':
      'Folder kosong ({n})',
  'ux47.imp_location':
      'Storan dalaman › Fail Penting',
  'ux47.imp_open_folder':
      'Buka folder',
  'ux47.internal_root':
      'Storan dalaman',
  'ux47.near_visible':
      'Kelihatan berdekatan · sedia menerima',
  'ux47.paste_clipboard':
      'Tampal daripada papan klip',
  'ux47.privacy_lock_off':
      '{n} folder dikunci · Kunci mati',
  'ux47.privacy_lock_on':
      '{n} folder dikunci · Kunci aktif',
  'ux47.privacy_unset':
      'Tanpa PIN · tidak dikunci',
  'ux47.set_pin_now':
      'Tetapkan PIN',
  'ux47.text_or_clip':
      'Teks / Papan klip',
  'bgc.black':
      'Hitam',
  'bgc.default':
      'Lalai tema',
  'bgc.grey':
      'Kelabu',
  'bgc.ice':
      'Biru ais',
  'bgc.lilac':
      'Ungu muda',
  'bgc.mint':
      'Pudina',
  'bgc.navy':
      'Biru tua',
  'bgc.olive':
      'Zaitun',
  'bgc.paper':
      'Kertas',
  'bgc.rose':
      'Mawar',
  'bgc.sand':
      'Pasir',
  'bgc.title':
      'Warna latar belakang',
  'bgc.white':
      'Putih',
  'nx.bill_body':
      '{amount} · baki {days} hari',
  'nx.bill_overdue':
      '{amount} · lewat tempoh',
  'nx.bill_title':
      'Bil akhir bayar: {title}',
  'nx.bill_today':
      '{amount} · akhir bayar HARI INI',
  'nx.channel':
      'Peringatan dan cadangan',
  'nx.clean_body':
      'Storan penuh {pct}% — ketik untuk menyemak fail yang tidak perlu',
  'nx.clean_body_found':
      'Storan penuh {pct}% · {size} fail tidak perlu ditemui kali terakhir',
  'nx.clean_title':
      'Masa pembersihan mingguan',
  'nx.w_empty':
      'Belum ada fail yang dibuka',
  'nx.w_free':
      '{v} bebas',
  'nx.w_scan':
      'Imbas',
  'nx.weekly':
      'Cadangan pembersihan mingguan',
  'nx.weekly_sub':
      'Pemberitahuan mingguan apabila storan hampir penuh (walaupun aplikasi ditutup)',
  'ocr.ar_model_failed':
      'Tidak dapat memuat turun model Arab. Semak sambungan dan cuba lagi; sementara itu bahasa Arab boleh dicam dengan bacaan pintar (kunci Gemini).',
  'ocr.ar_model_get':
      'Muat turun pengecaman Arab luar talian',
  'ocr.ar_model_loading':
      'Memuat turun model Arab… {p}%',
  'ocr.ar_model_ready':
      'Pengecaman Arab luar talian sedia.',
  'ocr.ar_model_remove':
      'Buang pengecaman Arab luar talian',
  'ocr.ar_model_sub':
      'Dimuat turun sekali (≈{size}); teks kemudian tidak pernah keluar daripada peranti.',
  'ocr.no_play_services':
      'Perkhidmatan Google Play tiada pada peranti ini, jadi pengecaman teks pada peranti tidak boleh digunakan. Untuk teks Arab, muat turun model luar talian dalam Tetapan → Dokumen → Skrip pengecaman teks, atau gunakan bacaan pintar dengan kunci Gemini.',
  'ocr.ar_need_model':
      'Untuk pengecaman teks Arab, muat turun model luar talian dalam Tetapan → Dokumen → Skrip pengecaman teks, atau tambah kunci Gemini.',
  'ocr.cloud_need_key':
      'Pengecaman teks Arab menggunakan bacaan pintar: tambah kunci API Gemini dalam Tetapan → Kecerdasan buatan.',
  'ocr.model_downloading':
      'Model pengecaman teks sedang dimuat turun oleh perkhidmatan Google Play. Kekal dalam talian dan cuba lagi dalam beberapa minit.',
  'ocr.script':
      'Skrip pengecaman teks',
  'ocr.script_arabic':
      'Arab (pada peranti atau bacaan pintar)',
  'ocr.script_auto':
      'Automatik',
  'ocr.script_latin':
      'Latin sahaja (pada peranti)',
  'open.in_app_hint':
      'Dibuka pantas, anda kekal dalam aplikasi',
  'open.in_app_player':
      'Pemain terbina dalam',
  'open.kind_audio':
      'Fail audio',
  'open.kind_image':
      'Imej',
  'open.macro_info':
      'Fail ini mungkin mengandungi makro — makro tidak pernah dijalankan; menyimpan membiarkannya tidak berubah dalam fail.',
  'open.no_app':
      'Tiada aplikasi yang boleh membuka jenis fail ini.',
  'open.not_found':
      'Fail tidak ditemui (mungkin telah dialihkan atau dipadam).',
  'open.opening':
      'Membuka fail…',
  'open.other_app':
      'Aplikasi lain',
  'open.other_app_hint':
      'Pemain media / galeri anda sendiri',
  'open.remember':
      'Ingat pilihan ini',
  'open.remember_hint':
      'Boleh diubah dalam Tetapan',
  'open.with_what':
      'Buka {kind} dengan?',
  'ps.act_form':
      'Borang diisi',
  'ps.act_ink':
      'Lukisan ditambah',
  'ps.act_signed':
      'Ditandatangani',
  'ps.act_translated':
      'Diterjemahkan',
  'ps.copy':
      'Simpan salinan',
  'ps.copy_sub':
      'Ke folder yang sama sebagai “… (copy).pdf”',
  'ps.open':
      'BUKA',
  'ps.overwrite':
      'Tulis ganti',
  'ps.overwrite_sub':
      '{name} berubah — tidak boleh dibuat asal',
  'ps.pick_folder':
      'Simpan ke folder pilihan…',
  'ps.pick_folder_sub':
      'Anda yang menentukan destinasinya',
  'ps.saved_as':
      'Disimpan: {name}',
  'ps.title':
      'Bagaimana hendak menyimpannya?',
  'ra.failed_count':
      '{n} fail tidak dapat dikecilkan',
  'ra.frame_losing_kept':
      'fail asal bagi {n} fail animasi/berbilang halaman dikekalkan',
  'ra.job_many':
      'Mengecilkan saiz {n} fail',
  'ra.job_many_name':
      'Pengecilan saiz {n} fail',
  'ra.job_one':
      'Mengecilkan saiz: {name}',
  'ra.job_one_name':
      'Pengecilan saiz: {name}',
  'ra.media_only':
      'Pengecilan saiz hanya berfungsi pada foto dan video.',
  'ra.no_gain':
      'Tiada penjimatan',
  'ra.originals_trashed':
      '{n} fail asal dalam tong sampah',
  'ra.saved_bytes':
      '{size} dijimatkan',
  'ra.saved_into':
      'Disimpan ke: {name}',
  'ra.saved_to':
      'Disimpan ke {n} folder',
  'ra.stopped_at':
      'dihentikan ({n}/{total})',
  'scan.apply_to_all':
      'Laksanakan pada semua halaman',
  'scan.filter_auto':
      'Tajamkan (warna)',
  'scan.filter_bw':
      'Hitam putih',
  'scan.filter_gray':
      'Kelabu',
  'scan.filter_original':
      'Asal',
  'scan.filter_shadowless':
      'Buang bayang',
  'scan.filter_vivid':
      'Warna terang',
  'scan.short_auto':
      'Tajamkan',
  'scan.short_bw':
      'H/P',
  'scan.short_gray':
      'Kelabu',
  'scan.short_original':
      'Asal',
  'scan.short_shadowless':
      'Tanpa bayang',
  'scan.short_vivid':
      'Terang',
  'acc.amber':
      'Ambar',
  'acc.berry':
      'Beri',
  'acc.blue':
      'Biru',
  'acc.default':
      'Lalai tema',
  'acc.forest':
      'Hutan',
  'acc.indigo':
      'Indigo',
  'acc.ocean':
      'Lautan',
  'acc.plum':
      'Plum',
  'acc.rust':
      'Karat',
  'acc.slate':
      'Batu loh',
  'acc.teal':
      'Teal',
  'acc.title':
      'Warna aksen',
  'cln.app_cache':
      'Cache imej kecil & pratonton aplikasi',
  'cln.app_cache_detail':
      'Imej kecil & pratonton sementara · dijana semula secara automatik apabila diperlukan',
  'cln.chat_sent':
      'Salinan sembang dihantar',
  'cln.chat_sent_detail':
      '{n} salinan · Hanya salinan yang dihantar dipadam, yang asal kekal',
  'cln.empty_folders':
      'Folder kosong',
  'cln.empty_folders_detail':
      '{n} folder · tiada kandungan',
  'cln.old_large':
      'Fail besar tidak dibuka selama setahun',
  'cln.old_large_detail':
      '{n} fail · 50 MB atau lebih',
  'cln.old_screenshots':
      'Tangkapan skrin lama',
  'cln.old_screenshots_detail':
      '{n} imej · tidak dilihat selama 3 bulan',
  'cln.temp_junk':
      'Fail sementara & separa',
  'cln.temp_junk_detail':
      '{n} fail · .tmp, .part, muat turun separa & sampah',
  'dash.backup':
      'Simpan susun atur · alih ke peranti baharu',
  'dash.hint':
      'Seret untuk menyusun semula, gunakan suis untuk menunjuk/menyembunyikan. Perubahan berkuat kuasa serta-merta.',
  'dash.reset':
      'Set semula',
  'dash.sections':
      'Bahagian',
  'dash.strip_all':
      'Tunjuk semua',
  'dash.strip_auto':
      'Automatik',
  'dash.strip_default':
      'Fail terkini dibuka pada',
  'dash.strip_fresh':
      'Baharu',
  'dash.strip_new':
      'Baharu',
  'dash.strip_opened':
      'Sejarah',
  'dash.strip_title':
      'Fail terkini',
  'dash.tiles':
      'Jubin',
  'jb.cancelled':
      'Dibatalkan.',
  'jb.cancelled_detail':
      'Dibatalkan · {detail}',
  'jb.file_missing':
      'Fail tidak ditemui · {folder}',
  'jb.interrupted_detail':
      'Terganggu · {detail} · ketik untuk memulakan semula',
  'jb.open_folder':
      'Buka folder',
  'jb.outputs':
      'Fail yang dicipta ({n})',
  'jb.resume':
      'Sambung',
  'jb.resume_failed':
      'Tugas ini tidak dapat disambung; mulakan semula.',
  'jb.resume_started':
      'Menyambung dari titik terakhir.',
  'jb.running_for':
      'Berjalan selama {time}',
  'jb.title':
      'Tugas',
  'jb.took':
      '{status} · mengambil masa {time}',
  'aipool.add_key':
      'Tambah kunci',
  'aipool.add_model':
      'Tambah model',
  'aipool.backup_keys':
      'Sandarkan kunci API',
  'aipool.key_n':
      'Kunci {n}',
  'aipool.model_chain':
      'Susunan model',
  'aipool.model_gone':
      'Model ini tidak lagi tersedia — dihentikan atau tidak didayakan untuk kunci anda.',
  'aipool.move_up':
      'Naikkan',
  'aipool.reset':
      'Set semula',
  'aipool.show_keys':
      'Tunjuk/sembunyi kunci',
  'aipool.status':
      'Status kuota',
  'aipool.status_sub':
      '{total} kumpulan kuota (kunci × model) · {cooling} sedang habis.',
  'arc.encrypted':
      'disulitkan',
  'arc.extract_all':
      'Ekstrak semua',
  'arc.extract_one':
      'Ekstrak fail ini',
  'arc.extracted_file':
      '{name} diekstrak',
  'arc.multipart':
      'berbilang bahagian',
  'arc.no_match':
      'Tiada fail yang sepadan',
  'arc.open_failed':
      'Tidak dapat membuka arkib: {error}',
  'arc.opening':
      'Membuka',
  'arc.opening_name':
      'Membuka arkib',
  'arc.ratio':
      '{pct}% dimampatkan',
  'arc.search':
      'Cari dalam arkib…',
  'dup.comparing':
      'Membandingkan fail bait demi bait…',
  'dup.comparing_short':
      'Membandingkan fail…',
  'dup.job_summary':
      '{n} kumpulan · {size} boleh dibebaskan',
  'dup.n_copies':
      '{n} salinan',
  'dup.no_match':
      'Tiada hasil untuk “{query}”.',
  'dup.none':
      'Tiada fail pendua ditemui 🎉',
  'dup.none_short':
      'Tiada fail pendua',
  'dup.scanning_name':
      'Carian fail pendua',
  'dup.scanning_title':
      'Mencari fail pendua',
  'dup.tile_summary':
      '{n} salinan · {size} · {waste} boleh dibebaskan',
  'dup.visible_summary':
      '{shown} / {total} kumpulan · {size} terbazir',
  'list.date':
      'Tarikh',
  'list.filter':
      'Tapis',
  'list.filter_n':
      'Tapis ({n})',
  'list.folders':
      'Folder',
  'list.size':
      'Saiz',
  'list.sort':
      'Isih',
  'list.sort_by':
      'Isih: {name}',
  'list.sort_dir_asc':
      'Menaik (A→Z, lama→baharu)',
  'list.sort_dir_desc':
      'Menurun (Z→A, baharu→lama)',
  'list.summary':
      '{n} item',
  'list.summary_size':
      '{n} item · {size}',
  'sel.above':
      'Pilih semua di atas',
  'sel.all':
      'Pilih semua',
  'sel.below':
      'Pilih semua di bawah',
  'sel.group_copy':
      'Salin & hantar',
  'sel.group_more':
      'Lagi',
  'sel.group_organize':
      'Susun',
  'sel.hide_hint':
      'Dialihkan ke peti besi yang disulitkan',
  'sel.invert':
      'Songsangkan',
  'sel.menu':
      'Pilihan',
  'sel.none':
      'Nyahpilih semua',
  'sel.sheet_title':
      '{n} dipilih',
  'sim.group_summary':
      '{n} serupa · {size} boleh dibebaskan',
  'sim.groups_summary':
      '{n} kumpulan serupa · {size} boleh dibebaskan',
  'sim.n_files':
      '{n} fail',
  'sim.none':
      'Tiada imej serupa ditemui 🎉',
  'sim.preparing_list':
      'Menyediakan senarai fail…',
  'sim.scan_failed':
      'Imbasan tidak dapat diselesaikan',
  'sim.scanning':
      'Mengimbas…',
  'sim.scanning_name':
      'Carian imej serupa ({level})',
  'sim.scanning_title':
      'Mencari imej serupa ({level})',
  'sim.select_extras':
      'Pilih yang berlebihan',
  'sim.title':
      'Imej serupa',
  'ui.clutter_tile':
      'Kemaskan',
  'ui.ct_docs':
      'Dokumen',
  'ui.ct_list':
      'Senarai ini',
  'ui.ct_select_all':
      'Pilih semua',
  'ui.ct_share_all':
      'Kongsi yang dipaparkan ({n})',
  'ui.ct_smart_hint':
      'Kelaskan dokumen ke dalam kategori, beri nama kedua',
  'ui.ct_zip_all':
      'Mampatkan yang dipaparkan ({n})',
  'ui.ct_zip_hint':
      'Arkib disimpan ke Muat Turun',
  'ui.dock_new':
      'Baharu',
  'ui.dock_opened':
      'Dibuka',
  'ui.sel_group_move':
      'Alih & salin',
  'wipe.ai':
      'AI: ringkasan, analisis tag, nota memori',
  'wipe.confirm':
      'Rekod yang dipilih akan dipadam secara kekal. Ini tidak boleh dibuat asal.',
  'wipe.done':
      'Data dipadam.',
  'wipe.go':
      'Padam',
  'wipe.history':
      'Sejarah: fail terkini, carian, sejarah operasi dan pemindahan',
  'wipe.indexes':
      'Indeks carian (nama dan kandungan; dibina semula kemudian)',
  'wipe.logs':
      'Log ralat',
  'wipe.note':
      'Yang anda pilih akan dipadam. Fail, sambungan tersimpan, kunci API, peti besi dan tetapan KEKAL.',
  'wipe.partial':
      'Dipadam; {n} rekod tidak dapat dibuang.',
  'wipe.sub':
      'Sejarah, rekod AI, indeks carian dan log ralat. Fail anda tidak disentuh.',
  'wipe.title':
      'Padam data saya',
  'act.all':
      'Semua ({n})',
  'act.clear':
      'Kosongkan sejarah',
  'act.kind_convert':
      'Fail yang ditukar',
  'act.kind_doc':
      'Dokumen yang diedit',
  'act.kind_image':
      'Foto yang dikecilkan',
  'act.kind_other':
      'Lain-lain',
  'act.kind_pdf':
      'PDF yang diedit',
  'act.kind_scan':
      'Dokumen yang diimbas',
  'act.kind_video':
      'Video yang dikecilkan',
  'act.title':
      'Dibuat',
  'cat.add':
      'Tambah kategori',
  'cat.add_body':
      '{n} fail · muncul dalam Susunan pintar, penapis dan carian',
  'cat.add_hint':
      'Dikongsi dengan kategori pintar; anda juga boleh menambah sendiri',
  'cat.added':
      '{n} fail ditambah ke "{cat}"',
  'cat.full':
      'Paling banyak {n} kategori boleh ditambah',
  'cat.mine':
      'Kategori saya',
  'cat.new':
      'Kategori baharu',
  'cat.new_label':
      'Nama kategori',
  'cat.new_title':
      'Kategori baharu',
  'cat.removed':
      'Dikeluarkan daripada "{cat}"',
  'cmp.hide_names':
      'Sembunyikan juga nama fail',
  'cmp.hide_names_sub':
      'Arkib tidak boleh dibuka tanpa kata laluan',
  'cmp.set_password':
      'Tetapkan kata laluan',
  'cmp.split':
      'Pecahkan kepada volum',
  'cmp.title':
      'Mampat',
  'cmp.vol_100':
      '100 MB',
  'cmp.vol_25':
      '25 MB (e-mel)',
  'cmp.vol_4g':
      '4 GB (FAT32)',
  'cmp.vol_700':
      '700 MB',
  'cmp.vol_none':
      'Satu fail',
  'code.bad_regex':
      'Ungkapan tidak sah',
  'code.cursor_left':
      'Kursor ke kiri',
  'code.cursor_right':
      'Kursor ke kanan',
  'code.eol':
      'Tukar akhir baris',
  'code.eol_changed':
      'Akhir baris: {name} — dilaksanakan semasa menyimpan',
  'code.find':
      'Cari',
  'code.redo':
      'Buat semula',
  'code.tab':
      'Inden (Tab)',
  'code.undo':
      'Buat asal',
  'code.whole_word':
      'Perkataan penuh',
  'lib.add_one':
      'Tambah ke pustaka',
  'lib.f_all':
      'Semua',
  'lib.f_done':
      'Selesai',
  'lib.f_reading':
      'Sedang dibaca',
  'lib.f_unread':
      'Belum dimulakan',
  'lib.sort_added':
      'Baru ditambah',
  'lib.sort_name':
      'Mengikut nama',
  'lib.sort_progress':
      'Mengikut kemajuan pembacaan',
  'lib.view_list':
      'Paparan senarai',
  'lib.view_shelf':
      'Paparan rak',
  'md.bold':
      'Tebal',
  'md.bullets':
      'Senarai berpeluru',
  'md.code':
      'kod',
  'md.heading':
      'Tajuk',
  'md.italic':
      'Condong',
  'md.link':
      'Pautan',
  'md.numbered':
      'Senarai bernombor',
  'md.quote':
      'Petikan',
  'md.table':
      'Jadual',
  'md.task':
      'Kotak semak',
  'menu.look_bento':
      'Bento',
  'menu.look_sub':
      'Susun atur menu fail dan dokumen',
  'menu.look_tabbed':
      'Bertab',
  'menu.look_title':
      'Gaya menu',
  'menu.search_empty':
      'Tiada tindakan yang sepadan',
  'menu.search_hint':
      'Cari menu atau mengikut tindakan…',
  'menu.search_hits':
      '{n} hasil',
  'menu.search_intent':
      'Mengikut fungsi',
  'menu.tab_common':
      'Kerap digunakan',
  'menu.tab_more':
      'Lagi',
  'picker.here_folder':
      'Ke folder ini',
  'picker.home':
      'Utama',
  'picker.parent':
      'Folder induk',
  'picker.places':
      'Hendak disimpan di mana?',
  'picker.source_itself':
      'Sumber itu sendiri',
  'picker.storage':
      'Storan',
  'picker.summary':
      '{n} item · {name}',
  'picker.title':
      'Folder destinasi',
  'picker.to_downloads':
      'Masuk ke Muat Turun',
  'picker.unreadable':
      'Folder ini tidak dapat dibaca (tiada kebenaran).',
  'qr.auto':
      'Auto',
  'qr.hint_many':
      'Nota panjang: imbas {n} kod QR mengikut urutan (masing-masing bermula dengan 1/{n}, 2/{n}…). Dengan "Auto" kod bergerak sendiri.',
  'qr.hint_one':
      'Minta orang lain mengimbasnya dengan kamera telefon — keseluruhan nota muncul pada skrin mereka dan boleh disalin.',
  'qr.next':
      'Kod seterusnya',
  'qr.prev':
      'Kod sebelumnya',
  'qr.privacy':
      'Tanpa internet, rangkaian kongsi atau aplikasi; nota tidak dimuat naik ke mana-mana.',
  'qr.stop':
      'Henti',
  'qr.text_choice':
      'Tunjuk teks sebagai kod QR',
  'qr.text_choice_sub':
      'Teks berada dalam QR — tanpa rangkaian atau aplikasi',
  'qr.title':
      'Kongsi sebagai kod QR',
  'toc.create':
      'Cipta kandungan',
  'toc.create_body':
      'PDF ini tiada kandungan. Imbas tajuk dan tambah ke PDF sebagai penanda buku? Anda akan melihat senarainya sebelum menyimpan.',
  'toc.create_go':
      'Cari tajuk',
  'toc.none_found':
      'Tiada tajuk ditemui',
  'toc.preview':
      '{n} tajuk ditemui',
  'toc.save':
      'Tambah ke PDF',
  'toc.saved':
      'Kandungan ditambah ke PDF',
  'toc.scanned_warn':
      'PDF ini hasil imbasan (halaman berupa imej). Teks pada {n} halaman akan dicam (OCR) untuk mencari tajuk; buku besar mungkin mengambil beberapa minit. Anda akan melihat senarainya sebelum menyimpan.',
  'toc.scanning':
      'Mencari tajuk…',
  'toc.scanning_ocr':
      'Mencam teks, mencari tajuk…',
  'ux.copy_details':
      'Salin butiran',
  'ux.error_body':
      'Fail mungkin rosak, dalam versi yang tidak disokong atau dikunci oleh aplikasi lain.',
  'ux.error_title':
      'Tidak dapat dibuka',
  'ux.group_format':
      'Format',
  'ux.group_send':
      'Hantar',
  'ux.loading':
      'Memuatkan',
  'ux.selection':
      'Pilihan',
  'ux.send_nearby':
      'Hantar ke peranti berdekatan',
  'ux.send_nearby_hint':
      'Versi tersimpan · QR atau rangkaian setempat',
  'ux.share_export':
      'Kongsi dalam format lain',
  'vtr.end':
      'Tamat',
  'vtr.hint':
      'pangkas, potong bahagian, tambah / senyapkan bunyi',
  'vtr.job':
      'Mengedit video: {name}',
  'vtr.job_name':
      'Klip {name}',
  'vtr.no_preview':
      'Pratonton tidak tersedia; video masih boleh dipangkas.',
  'vtr.range':
      '{start} – {end} · {n} s',
  'vtr.start':
      'Mula',
  'vtr.suffix':
      'klip',
  'vtr.title':
      'Edit video',
  'vtr.whole':
      'Seret pemegang di bawah untuk memangkas',
  'dp.copied':
      '{n} item disalin',
  'dp.copy_to':
      'Salin ke sebelah lagi',
  'dp.failed':
      'Beberapa item tidak dapat dipindahkan',
  'dp.move_to':
      'Alih ke sebelah lagi',
  'dp.moved':
      '{n} item dialihkan',
  'dp.selected':
      '{n} dipilih',
  'dp.swap':
      'Tukar panel',
  'dp.title':
      'Panel dua',
  'dp.up':
      'Folder induk',
  'hv.confirm_body':
      'Item akan disulitkan dan dialihkan ke Peti Besi; kekal tidak boleh dibaca walaupun telefon disambungkan ke komputer. Keluarkan daripada Peti Besi.',
  'hv.confirm_title':
      'Sembunyikan {n} item?',
  'hv.empty':
      'Tiada fail tersembunyi. Tekan lama fail dan pilih “Sembunyikan”.',
  'hv.note':
      'Fail tersembunyi dialihkan ke folder tersembunyi; tidak muncul dalam galeri atau senarai aplikasi ini. Ini bukan penyulitan.',
  'hv.restore':
      'Pulihkan',
  'hv.restore_name':
      'Memulihkan fail tersembunyi',
  'hv.restored_n':
      '{n} item dipulihkan',
  'hv.restoring':
      'Memulihkan',
  'hv.title':
      'Fail tersembunyi',
  'oh.clear':
      'Kosongkan sejarah',
  'oh.clear_body':
      'Hanya rekod “bila dibuka” yang dipadam; failnya tidak.',
  'oh.clear_title':
      'Kosongkan sejarah?',
  'oh.empty':
      'Belum ada fail yang dibuka.\nApabila anda membukanya, fail muncul di sini.',
  'oh.no_match':
      'Tiada hasil untuk “{query}”.',
  'oh.remove':
      'Buang daripada sejarah',
  'oh.removed_n':
      '{n} fail dibuang daripada sejarah',
  'oh.search':
      'Cari sejarah…',
  'oh.title':
      'Sejarah',
  'perf.auto':
      'Automatik',
  'perf.auto_is':
      'Automatik — telefon ini: {tier}',
  'perf.full':
      'Penuh',
  'perf.light':
      'Ringan',
  'perf.mode':
      'Prestasi',
  'perf.mode_sub':
      'Ringan: kurang memori dan bateri pada telefon lama/RAM kecil — satu imej kecil pada satu masa, kesan dimatikan, 60 Hz.',
  'perf.tier_high':
      'berkuasa',
  'perf.tier_low':
      'ringan',
  'perf.tier_mid':
      'sederhana',
  'se.apply_crop':
      'Pangkas',
  'se.crop_hint':
      'Seret sudut atau tepinya',
  'se.crop_title':
      'Pangkas halaman',
  'se.failed':
      'Tidak dapat membetulkannya: {error}',
  'se.find_edges':
      'Cari tepi',
  'se.full_page':
      'Keseluruhan halaman',
  'se.invalid_quad':
      'Sudut tidak membentuk segi empat yang sah',
  'se.not_found':
      'Tepi kertas tidak ditemui — seret tepinya secara manual.',
  'se.open_failed':
      'Tidak dapat membuka imej: {error}',
  'sync.add':
      'Tambah folder',
  'sync.done':
      '{n} fail baharu disegerakkan ke {name}',
  'sync.explain':
      'Apabila aktif, fail yang ditambah ke folder pilihan mulai SEKARANG dihantar secara automatik apabila peranti ini berada pada Wi-Fi yang sama — disulitkan, dan hanya kepada kunci peranti ini.',
  'sync.menu':
      'Segerak automatik',
  'sync.on':
      'Segerak automatik aktif',
  'sync.pick':
      'Segerakkan folder ini',
  'sync.remove':
      'Buang folder',
  'sync.title':
      'Segerak automatik dengan {name}',
  'sync.when':
      'Penyegerakan berjalan apabila aplikasi dibuka atau dibawa ke depan, dan semasa Pindah dibuka; tiada imbasan latar belakang (bateri).',
  'aisend.body':
      'Untuk ini, teks (atau imej) fail dihantar ke Google Gemini dan diproses dengan kunci API anda. Dengan kunci percuma, Google mungkin menggunakan data ini untuk melatih modelnya. Tiada yang lain keluar daripada telefon. Anda tidak akan ditanya lagi pada sesi ini.',
  'aisend.cancelled':
      'Tidak dihantar kepada AI.',
  'aisend.private':
      'Fail dalam peti besi tidak pernah dihantar kepada AI.',
  'aisend.remember':
      'Jangan tanya lagi',
  'aisend.send':
      'Hantar',
  'aisend.setting':
      'Tanya sebelum menghantar kepada AI',
  'aisend.setting_sub':
      'Bertanya sebelum teks fail dihantar ke Google Gemini. Mati bermakna anda sudah bersetuju sekali.',
  'aisend.title':
      'Hantar fail kepada Google?',
  'downloads.empty':
      'Folder muat turun kosong',
  'downloads.folder_view':
      'Paparan folder (semak imbas subfolder)',
  'downloads.no_result':
      'Tiada hasil untuk “{q}”.',
  'downloads.search':
      'Cari muat turun',
  'downloads.search_hint':
      'Cari muat turun…',
  'downloads.select_old':
      'Pilih yang lama',
  'downloads.selected':
      '{n} / {total} dipilih',
  'downloads.title':
      'Muat Turun',
  'dsv.downloaded':
      'Dimuat turun',
  'dsv.downloading':
      'Memuat turun…',
  'dsv.downloading_live':
      'Memuat turun · {progress} · {networkSpeed} · baki {timeRemaining}',
  'dsv.failed':
      'Muat turun gagal',
  'dsv.job_name':
      'Muat turun',
  'dsv.paused':
      'Dijeda',
  'dsv.speed':
      '{speed}/s',
  'dsv.start_failed':
      'Tidak dapat memulakan muat turun',
  'paste.conflict_more':
      '{names} dan {n} lagi',
  'paste.conflict_title':
      '{n} fail sudah ada di sini',
  'paste.keep_both':
      'Simpan kedua-duanya',
  'paste.keep_both_sub':
      'Yang baharu mendapat “(1)”; tiada apa dipadam',
  'paste.overwrite':
      'Tulis ganti',
  'paste.overwrite_sub':
      'Fail yang sudah ada diganti — tidak boleh dibuat asal',
  'paste.skip':
      'Langkau fail ini',
  'paste.skip_sub':
      'Fail yang sudah ada kekal seperti asal',
  'perm.allow':
      'Benarkan',
  'perm.camera_title':
      'Kamera',
  'perm.granted':
      'Dibenarkan',
  'perm.location_title':
      'Lokasi',
  'perm.notifications_title':
      'Pemberitahuan',
  'perm.open_settings':
      'Buka tetapan',
  'perm.overlay_title':
      'Paparkan di atas aplikasi lain',
  'perm.revoke':
      'Tarik balik',
  'aiterms.accept':
      'Terima',
  'aiterms.body':
      'Ciri AI berjalan dengan kunci API Google Gemini milik anda sendiri. Teks atau imej fail yang anda pilih dihantar kepada Google untuk diproses; terma dan dasar privasi Google sendiri terpakai. Jawapan dijana secara automatik dan mungkin salah, tidak lengkap atau lapuk. Jangan bergantung padanya semata-mata untuk keputusan perubatan, undang-undang, kewangan atau keputusan penting lain; semak sendiri hasilnya. Aplikasi tidak bertanggungjawab atas akibat daripada jawapan AI. Kami menasihati supaya tidak menghantar fail yang mengandungi maklumat peribadi atau sulit.',
  'aiterms.c_accuracy':
      'Saya faham jawapan boleh salah dan saya perlu menyemaknya.',
  'aiterms.c_data':
      'Saya bersetuju kandungan yang saya hantar diteruskan kepada Google untuk diproses.',
  'aiterms.c_key':
      'Saya menggunakan kunci API sendiri dan sebarang kuota atau caj adalah tanggungan saya.',
  'aiterms.pro_only':
      'Ciri AI terdapat dalam edisi Pro.',
  'aiterms.title':
      'AI — notis dan persetujuan',
  'an.free_headline':
      '{size} bebas',
  'an.other_used':
      'Sistem & lain-lain',
  'an.tools':
      'Alat',
  'an.tools_clean':
      'Bersihkan & susun',
  'an.top_growing':
      'Berkembang paling pantas: {category}',
  'an.trend_days':
      'Dalam {n} hari lepas',
  'an.used_of':
      '{used} / {total} digunakan',
  'backup.failed':
      'Sandaran gagal: {error}',
  'backup.restore':
      'Pulihkan daripada sandaran',
  'backup.restore_failed':
      'Pemulihan gagal: {error}',
  'backup.restore_sub':
      'Tetapan daripada sandaran dipulihkan; yang tiada di dalamnya kekal seperti asal.',
  'backup.restored':
      '{n} tetapan dipulihkan. Sebahagian berkuat kuasa selepas aplikasi dimulakan semula.',
  'backup.saved':
      'Sandaran disimpan: {name}',
  'backup.title':
      'Sandarkan tetapan',
  'inbox.all':
      'Semua tugas',
  'inbox.clear_done':
      'Kosongkan yang selesai',
  'inbox.hour_ago':
      '{n} j lalu',
  'inbox.just_now':
      'baru sebentar tadi',
  'inbox.min_ago':
      '{n} min lalu',
  'inbox.more':
      '+{n} lagi · Semua',
  'inbox.running':
      'Berjalan…',
  'lock.app_needs_pin':
      'Tetapkan PIN dahulu (Privasi > PIN kunci folder).',
  'lock.app_prompt':
      'Masukkan PIN',
  'lock.app_sub_off':
      'Mati — aplikasi dibuka terus.',
  'lock.app_sub_on':
      'PIN ditanya apabila aplikasi dibuka.',
  'lock.app_title':
      'Kunci aplikasi',
  'lock.app_wait':
      'Terlalu banyak percubaan — tunggu {n} saat',
  'lock.app_wrong':
      'PIN salah',
  'tile.body':
      'Peranti dipercayai boleh menghantar fail yang disulitkan · mati selepas 30 minit tidak aktif',
  'tile.channel':
      'Menerima fail',
  'tile.got':
      'Fail diterima',
  'tile.open':
      'Buka Pindah untuk menerima',
  'tile.refused':
      'Permintaan daripada peranti tidak dipercayai ditolak',
  'tile.stop':
      'Matikan',
  'tile.title':
      'Penerimaan aktif',
  'whatsnew.add_folder':
      'Gunakan "Tambah folder" untuk bekerja hanya dengan folder pilihan anda, tanpa akses semua fail.',
  'whatsnew.ai_ask':
      'Anda ditanya sebelum fail dihantar kepada AI.',
  'whatsnew.faster':
      'Flutter dan pakej baharu: tatal PDF lebih lancar, SFTP lebih pantas.',
  'whatsnew.offline':
      'Mod luar talian: apabila aktif, aplikasi tidak pernah dalam talian.',
  'whatsnew.privacy':
      'Tetapan › Privasi & kebenaran: mengapa setiap kebenaran diminta, statusnya, tarik balik dengan satu ketikan.',
  'whatsnew.reading':
      'Alat bantu baca dalam PDF; Word/Slaid dibuka semula di tempat terakhir, Excel pada helaian tersimpannya.',
  'whatsnew.title':
      'Apa yang baharu — {v}',
  'atr.action_hint':
      'Pangkas permulaan dan penghujung, simpan sebagai fail baharu',
  'atr.failed':
      'Fail audio ini tidak dapat dibuka.',
  'atr.hint':
      'Seret pemegang; bahagian pendek dimainkan dari titik itu semasa menyeret.',
  'atr.job':
      'Memangkas audio: {name}',
  'atr.result':
      'Hasil {t}',
  'atr.title':
      'Pangkas audio',
  'lc.clear_all':
      'Kosongkan',
  'lc.count':
      '{n} item',
  'lc.count_of':
      '{n} / {total} item',
  'lc.filter':
      'Tapis',
  'lc.filter_n':
      'Tapis · {n}',
  'lc.no_dupes':
      'Pendua disembunyikan',
  'lnk.expired_renew':
      'Pautan tamat tempoh · baharui',
  'lnk.forever':
      'Selagi terbuka',
  'lnk.hour1':
      '1 jam',
  'lnk.min15':
      '15 min',
  'lnk.once':
      'Sekali muat turun',
  'lnk.until':
      'Pautan sah sehingga {time}',
  'more.asc':
      'Menaik',
  'more.desc':
      'Menurun',
  'more.filter':
      'Tapis',
  'more.folder':
      'Folder ini',
  'more.tags':
      'Tag',
  'more.tools':
      'Analisis',
  'pp.hf_empty':
      'Pilih nombor halaman, pengepala atau pengaki',
  'pp.hf_footer':
      'Pengaki',
  'pp.hf_header':
      'Pengepala',
  'pp.hf_none':
      'Tiada pengepala atau pengaki untuk dibuang (hanya yang ditambah dengan aplikasi ini boleh dibuang)',
  'pp.hf_numbers':
      'Nombor halaman',
  'pp.hf_remove':
      'Buang',
  'sg.failed':
      'Penandatanganan gagal: {error}',
  'sg.grid':
      'Semua halaman (grid)',
  'sg.note':
      'Tandatangan dicap secara kekal pada dokumen.',
  'sg.prev_page':
      'Halaman sebelumnya',
  'sg.redraw':
      'Lukis semula tandatangan',
  'sg.single':
      'Paparan satu halaman',
  'tr.cancelled':
      'Dihentikan — {n} item dipadam.',
  'tr.count_size':
      '{n} item · {size}',
  'tr.delete_body':
      '{n} item ({size}) akan dipadam secara kekal. Ini tidak boleh dibuat asal.',
  'tr.emptied':
      'Tong sampah dikosongkan · {n} item · {size} dibebaskan.',
  'tr.partial':
      '{n} item dipadam, {fail} tidak dapat dipadam: {first}',
  'tr.restored':
      '“{name}” dipulihkan → {folder}',
  'xfer.computer':
      'Dengan komputer',
  'xfer.computer_note':
      'Daripada pelayar atau FTP, sambung dengan kod QR',
  'xfer.downloads':
      'Muat Turun',
  'xfer.downloads_note':
      'Muat turun fail daripada pautan',
  'xfer.nas_note':
      'Sambungan FTP, SFTP, SMB, WebDAV',
  'xfer.title':
      'Pindah',
  'ais.as_pdf':
      'Dek (PDF)',
  'ais.as_pdf_hint':
      'Dibuka di mana-mana, susun atur kekal',
  'ais.as_pptx':
      'Pembentangan (.pptx)',
  'ais.as_pptx_hint':
      'Boleh diedit — dibuka juga dalam PowerPoint',
  'ais.failed':
      'Tidak dapat membina pembentangan: {error}',
  'dev.enabled':
      'Menu pembangun diaktifkan — di bahagian bawah Tetapan',
  'dev.on':
      'Aktif',
  'dev.sub':
      'Alat diagnostik',
  'dev.title':
      'Pembangun',
  'dev.turn_off':
      'Matikan menu pembangun',
  'dg.consent':
      'Ringkasan tanpa nama di bawah akan dikongsi: versi, bilangan ranap/ANR, baris pertama ralat dan taburan masa bingkai. Nama fail, laluan, e-mel dan nombor panjang disamarkan; tiada kandungan dokumen disertakan. Aplikasi tidak menghantar apa-apa sendiri — anda yang memilih untuk berkongsi.',
  'dg.frames':
      'Kumpulkan masa bingkai',
  'dg.frames_hint':
      'Hanya taburan berangka bingkai perlahan, pada peranti; tanpa skrin atau nama fail.',
  'dg.send':
      'Kongsi',
  'dg.title':
      'Laporkan masalah',
  'g5.encrypted':
      'Disulitkan',
  'g5.encrypted_code':
      'Disulitkan · semak {code}',
  'g5.resume_hint':
      'menghantar semula akan menyambung dari titik berhenti',
  'g5.trusted_keyed':
      'Dikenali melalui kuncinya · disulitkan',
  'g5.unencrypted':
      'Tidak disulitkan (pihak lain versi lama)',
  'pin.mismatch':
      'Kedua-dua PIN tidak sepadan.',
  'pin.repeat_empty':
      'Taip PIN yang sama sekali lagi dalam kotak "PIN (ulang)" di bawah.',
  'pin.too_short':
      'PIN mestilah sekurang-kurangnya 4 digit.',
  'pin.wait':
      'Terlalu banyak kesilapan — tunggu {t}',
  'pin.wrong':
      'PIN salah.',
  'pro.b1':
      'Pengeditan PDF dan alat PDF lanjutan + alat Word dan Slaid lanjutan',
  'pro.b2':
      'Folder pintar, penghasilan buku audio dan pemampatan video',
  'pro.b3':
      'Gemini AI pilihan dengan kunci anda sendiri untuk folder pintar, OCR imbasan dan pembersihan buku audio',
  'pro.card_title':
      'Apa yang ada dalam Pro?',
  'pro.store':
      'Lihat di Play',
  'reader.page_empty':
      'Tiada teks boleh dibaca pada halaman ini.',
  'reader.theme':
      'Latar belakang',
  'reader.theme_dark':
      'Gelap',
  'reader.theme_light':
      'Cerah',
  'reader.theme_sepia':
      'Sepia',
  'sr.last_page':
      'Anda tidak boleh memadam halaman terakhir — batalkan imbasan sahaja.',
  'sr.page_failed':
      'Tidak dapat memaparkan halaman',
  'sr.straighten':
      'Luruskan',
  'sr.straighten_noop':
      'Halaman sudah kelihatan lurus — tiada apa berubah.',
  'sr.straightened':
      'Halaman telah diluruskan.',
  'st.edit_page':
      'Edit teks halaman {n}',
  'st.fix_done':
      'Teks dibetulkan ({n} baris)',
  'st.fix_noop':
      'Tiada ralat OCR untuk dibetulkan',
  'st.fix_text':
      'Betulkan OCR',
  'st.re_recognize':
      'Cam semula',
  'tp.new_tag':
      'Tag baharu (nama orang / kumpulan)',
  'tp.new_tag_hint':
      'Ali, Kumpulan kerja, Invois…',
  'tp.partial':
      '{tag} (pada sebahagian)',
  'tp.title':
      'Tag',
  'tp.title_n':
      'Tag ({n} fail)',
  'typ.all_types':
      'Semua jenis',
  'typ.hint':
      'Anda boleh memilih beberapa jenis; senarai terus ditapis.',
  'typ.more_n':
      '{name} +{n}',
  'typ.show_n':
      'Tunjuk {n} fail',
  'typ.title':
      'Jenis fail',
  'aikey.add':
      'Tambah kunci',
  'aikey.body':
      'Susunan pintar, nama kedua pintar, terjemahan dan pengeditan pintar berjalan pada Google Gemini. Dapatkan kunci percuma dan tampal dalam Tetapan > Kecerdasan buatan; itu sahaja.',
  'aikey.privacy':
      'Hanya teks/fail yang anda pilih dihantar, dan hanya apabila anda memintanya.',
  'aikey.title':
      'Hidupkan ciri pintar',
  'ci.clear':
      'Padam indeks kandungan',
  'ci.cleared':
      'Indeks kandungan dipadam',
  'ci.ocr':
      'Cari juga teks dalam imej (OCR)',
  'ci.ocr_sub':
      'Indeks kandungan mengecam teks imej pada telefon; berhenti semasa penjimat bateri',
  'count.files':
      '{n} fail',
  'count.files_size':
      '{n} fail · {size}',
  'count.more_files':
      '… dan {n} fail lagi',
  'count.of_files':
      '{shown} / {total} fail',
  'eco.dismiss':
      'Sembunyikan cadangan selama 30 hari',
  'eco.notlar_cta':
      'Dapatkan / buka Notlar',
  'eco.notlar_sub':
      'Hantar petikan ke nota anda dengan satu ketikan dan kongsi satu kumpulan kredit AI merentas kedua-dua aplikasi.',
  'eco.notlar_title':
      'Temui Notlar',
  'err.go_back':
      'Kembali',
  'err.go_home':
      'Utama',
  'err.render_failed':
      'Skrin ini tidak dapat dilukis',
  'err.report':
      'Laporkan masalah',
  'fmap.empty':
      'Tiada fail untuk diukur dalam folder ini.',
  'fmap.note':
      'Menyusun folder mengikut saiz; masuk lebih dalam untuk mencari ke mana ruang pergi',
  'fmap.summary':
      '{n} fail · {size}',
  'fmap.title':
      'Peta folder',
  'grp.month':
      'Bulan ini',
  'grp.older':
      'Lebih lama',
  'grp.today':
      'Hari ini',
  'grp.week':
      'Minggu ini',
  'hist.incoming':
      'Baharu',
  'hist.jobs':
      'Tugas',
  'hist.opened':
      'Sejarah',
  'hist.produced':
      'Dibuat',
  'jp.cancel':
      'Batal',
  'jp.cancelling':
      'Menghentikan…',
  'jp.show':
      'Tunjuk',
  'jp.title_queued':
      '{title} (+{n} lagi)',
  'lab.word_banner':
      'Eksperimen — perubahan tidak disimpan',
  'lab.word_flag':
      'Editor Word baharu (eksperimen)',
  'lab.word_flag_sub':
      'Ujian menaip teras nipis dalam menu Word ⋮ — tidak menyimpan',
  'lab.word_open':
      'Cuba dalam editor baharu',
  'lcol.color':
      'Warna',
  'lcol.folder':
      'Warna folder',
  'lcol.none':
      'Tiada warna',
  'lcol.tag':
      'Warna tag "{tag}"',
  'offline.blocked':
      'Mod luar talian aktif — tiada sambungan internet dibuat. Matikan dalam Tetapan › Privasi & kebenaran.',
  'offline.on':
      'AKTIF — tiada apa pergi ke internet. AI, Drive, sari kata dan muat turun dimatikan; rangkaian setempat berfungsi.',
  'offline.sub':
      'Apabila aktif, aplikasi tidak pernah dalam talian: AI, Google Drive, sari kata dan muat turun berhenti. Rangkaian setempat (NAS, peranti berdekatan) masih berfungsi. Diagnostik tidak pernah menghantar apa-apa.',
  'offline.title':
      'Mod luar talian',
  'onb.next':
      'Seterusnya',
  'onb.privacy_note':
      'Fail anda kekal pada telefon; tanpa iklan, tanpa penjejakan. AI adalah pilihan dan hanya berjalan apabila anda memulakannya, dengan kunci anda sendiri.',
  'onb.privacy_note_lite':
      'Fail anda kekal pada telefon; tanpa akaun, tanpa iklan, tanpa penjejakan.',
  'onb.start':
      'Mulakan',
  'oph.clear':
      'Kosongkan sejarah',
  'oph.clear_title':
      'Kosongkan sejarah?',
  'oph.title':
      'Operasi terkini',
  'oph.undone':
      '{n} item dikembalikan.',
  'pdf.discard_body':
      'Perubahan yang belum disimpan akan hilang.',
  'pdf.discard_confirm':
      'Keluar',
  'pdf.discard_title':
      'Buang perubahan?',
  'pdf.exit_edit':
      'Keluar daripada pengeditan',
  'qrimg.chip':
      'QR ({n})',
  'qrimg.open':
      'Buka pautan',
  'qrimg.open_failed':
      'Tidak dapat membuka pautan',
  'qrimg.title':
      'QR dalam imej',
  'qrr.declined':
      'Penerimaan dibatalkan',
  'qrr.done_title':
      '{n} fail diterima',
  'qrr.open_folder':
      'Buka folder',
  'qrr.receiving':
      'Menerima',
  'sdw.grant':
      'Benarkan menulis ke kad SD',
  'sdw.granted':
      'Akses tulis kad SD diberikan',
  'sdw.needs_grant':
      'Kebenaran diperlukan untuk menulis ke kad SD',
  'sdw.not_granted':
      'Kebenaran tidak diberikan',
  'simf.inspected':
      '{n} / {total} fail disemak',
  'simf.matching':
      'Mengekstrak padanan…',
  'simf.none':
      'Tiada fail serupa ditemui',
  'simf.preparing':
      'Menyediakan…',
  'svs.name':
      'Nama',
  'svs.save':
      'Simpan carian',
  'svs.saved':
      '"{name}" disimpan',
  'svs.title':
      'Carian tersimpan',
  'vt.engine_preparing':
      'menyediakan {engine}…',
  'vt.failed':
      'Tidak dapat menukar video: {error}',
  'vt.hw_encoder':
      'pengekod perkakasan',
  'vt.unsupported':
      'Video tidak dapat dimampatkan (formatnya mungkin tidak disokong).',
  'ap.body':
      'Arkib ini dilindungi kata laluan.',
  'ap.title':
      'Kata laluan arkib',
  'ap.wrong':
      'Kata laluan salah. Cuba lagi.',
  'dm.sheet':
      'Hamparan',
  'dm.slides':
      'Pembentangan',
  'dm.word':
      'Dokumen Word',
  'dur.hour':
      '{n} j',
  'dur.min':
      '{n} min',
  'dur.sec':
      '{n} s',
  'imp.recent':
      'Baru ditambah',
  'imp.tab_folder':
      'Folder',
  'imp.tab_gallery':
      'Galeri',
  'legacy.body':
      'Format {ext} lama: hanya teks dipaparkan, pemformatan hilang.',
  'legacy.convert':
      'Tukar kepada {ext} & edit',
  'legacy.read_only':
      'BACA SAHAJA',
  'ops.active':
      'Berjalan',
  'ops.finished':
      'Selesai',
  'ops.tab_organize':
      'Susun',
  'qf.card_add':
      'Tambah ke Kad saya',
  'qf.card_remove':
      'Buang daripada Kad saya',
  'qf.quick_add':
      'Tambah ke folder pantas',
  'report.folder':
      'Folder',
  'report.header':
      'Nama;Jenis;Saiz (bait);Diubah',
  'report.summary':
      '{dirs} folder, {files} fail',
  'rotate.done':
      'Disimpan {name}',
  'rotate.failed':
      'Tidak dapat memutar: {error}',
  'rotate.working':
      'Memutar…',
  'saf.folders_none':
      'Belum ada. Jika tidak mahu membenarkan semua fail, gunakan "Tambah folder" pada skrin utama untuk menambah hanya folder pilihan anda.',
  'saf.folders_sub':
      'Anda hanya membenarkan folder ini; dipaparkan sebagai kad pada skrin utama. "Tarik balik" membuang akses, fail kekal.',
  'saf.folders_title':
      'Folder yang ditambah',
  'shell.sheets':
      '{n} helaian',
  'shell.slides':
      '{n} slaid',
  'shell.unsaved':
      'Belum disimpan',
  'sq.blurry':
      'Halaman kelihatan kabur — disyorkan mengambil semula',
  'sq.dark':
      'Cahaya malap — hidupkan denyar dan ambil semula',
  'sq.skewed':
      'Halaman kelihatan condong',
  'src.title':
      'Sumber & masa',
  'src.when':
      'Masa & saiz',
  'src.where':
      'Di mana',
  'thp.amoled':
      'Hitam AMOLED',
  'thp.paper':
      'Kertas',
  'thp.size_max':
      '2×',
  'type.doc_other':
      'Dokumen lain',
  'type.ebook':
      'E-buku',
  'type.text':
      'Teks',
  'uix.item_n':
      'Item {n}',
  'uix.video':
      'Video',
  'uix.view':
      'Paparan',
  'xft.qr_title':
      'Kongsi dengan QR',
  'xft.scan_short':
      'Imbas',
  'xft.tab_quick':
      'Hantar pantas',
  'a11y.deselect':
      'Nyahpilih',
  'a11y.select':
      'Pilih',
  'aia.move_failed':
      'Tidak dapat mengalihkannya: {error}',
  'aia.moved':
      '“{name}” → Önemli Dosyalar/{folder}',
  'crash.notice':
      'Aplikasi mengalami ralat ({n} laporan)',
  'crash.notice_hint':
      'Buka laporan untuk mengongsikannya',
  'dls.selected':
      '{n} fail dipilih ·',
  'dls.untouched':
      '{n} fail tidak disentuh selama 6 bulan ·',
  'dv.fallback':
      'Tidak dapat membuka paparan halaman: {error}\n\nBeralih kepada editor teks.',
  'dv.too_big':
      'dokumen terlalu besar ({mb} MB)',
  'fav.drag':
      'Seret untuk mengalih',
  'fav.reorder':
      'Susun semula kegemaran',
  'lf.pdf_too_big':
      'PDF ini ({mb} MB) terlalu besar untuk alat (had {max} MB). Pemapar menstrimnya; untuk alat cuba Tetapan › Storan & kelajuan › Prestasi › Penuh.',
  'lf.xlsx_stream':
      'Fail besar ({mb} MB): dibuka sebagai pratonton strim untuk menjimatkan memori — nilai sahaja, baca sahaja. Penyimpanan dimatikan.',
  'lt.banner':
      'Fail besar — baca sahaja, dipaparkan sebahagian-sebahagian · {n} baris · {enc}',
  'lt.indexing':
      'Menyediakan fail besar…',
  'pane.favorites':
      'Kegemaran',
  'pane.places':
      'Tempat',
  'pd.cancel':
      'Batal',
  'pd.preparing':
      'Menyediakan…',
  'pii.setting':
      'Sembunyikan data peribadi',
  'pii.setting_sub':
      'Nombor pengenalan, IBAN, kad, nombor telefon dan e-mel dihantar kepada AI sebagai [TC], [IBAN]….',
  'qc.scope_off':
      'Fail ini berada di luar skop ciri pintar (Tetapan → Kecerdasan buatan).',
  'qc.too_large':
      'Fail terlalu besar untuk tindakan pintar (maks 14 MB).',
  'udf.corrupt':
      'Fail UYAP (.udf) ini kelihatan rosak atau tidak lengkap dan tidak dapat dibuka. Muat turun semula daripada UYAP atau minta salinan baharu daripada penghantar.',
  'udf.encrypted':
      'Fail UYAP (.udf) ini disulitkan dan tidak boleh dibuka di sini. Buka dalam UYAP Document Editor dan simpan tanpa kata laluan, atau dapatkan sebagai PDF.',
  'vsp.shrink':
      'Kecilkan',
  'vsp.tooltip':
      'Kecilkan saiz: {from} → kira-kira {to}',
  'ai.answer_language':
      'Malay',
  'fp.create_failed':
      'Tidak dapat mencipta folder: {error}',
  'fresh.new':
      'Baharu',
  'ia.reader_off':
      'Edisi ini tidak dapat menyenaraikan aplikasi yang dipasang. Edisi penuh memaparkannya.',
  'jobs.files_progress':
      '{done}/{total} fail',
  'nav.section':
      'Navigasi',
  'oss.all':
      'Semua lesen',
  'pt.invert_selection':
      'Songsangkan pilihan',
  'vn.title':
      'Nota suara',
  'wt.title':
      'Dokumen Word baharu',
  'act.clear_confirm':
      'Kosongkan senarai ini? Fail anda TIDAK dipadam — hanya rekod log dikosongkan.',
  'act.empty':
      'Belum ada rekod.\nKecilkan saiz video, sunting PDF atau imbas dokumen supaya fail hasilnya disenaraikan di sini mengikut jenis.',
  'aipool.backup_keys_sub':
      'Apabila semua model bagi kunci pertama kehabisan kuota, kunci seterusnya digunakan. Sehingga 5 kunci.',
  'aipool.model_chain_sub':
      'Gemini mengira kuota mengikut model. Apabila satu model habis, permintaan beralih ke model seterusnya. Sehingga 6 model.',
  'aiset.budget_sub':
      'Tiada had secara lalai supaya analisis tidak berhenti sendiri. Apabila kuota benar-benar habis, kumpulan beralih ke model/kunci seterusnya.',
  'aiset.excluded_sub':
      'Folder ini tidak pernah dianalisis dan kandungannya tidak pernah meninggalkan peranti. Folder kamera dikecualikan secara lalai.',
  'aiset.send_images_sub':
      'Apabila dimatikan, imej itu sendiri tidak pernah dimuat naik; hanya teks OCR pada peranti digunakan.',
  'aiset.send_text_sub':
      '{kb} KB teks pertama dihantar ke Gemini. Apabila dimatikan, hanya nama dan saiz fail dihantar.',
  'apps.usage_body':
      'Jika anda memberikan kebenaran “Akses penggunaan” Android, anda boleh melihat bila kali terakhir setiap aplikasi dibuka dan yang lama tidak digunakan ditandakan. Tiada data keluar dari peranti.',
  'backup.sub':
      'Tema, bahasa, penanda halaman dan keutamaan dalam satu fail. Kunci API dan PIN TIDAK disertakan.',
  'cmp.7z_note':
      'Fail lebih kecil. Dengan kata laluan, menggunakan AES-256; nama fail juga boleh disembunyikan.',
  'cmp.password_warning':
      'Jika terlupa kata laluan, arkib TIDAK BOLEH dibuka — tiada cara pemulihan.',
  'cmp.zip_note':
      'Dibuka di mana-mana sahaja. Dengan kata laluan, disulitkan dengan AES-256 (nama fail kekal kelihatan).',
  'err.render_logged':
      'Ralat direkodkan (Tetapan > Log ralat).\nAnda boleh kembali ke skrin sebelumnya.',
  'flt.direction_note':
      'Fail dihantar dibaca daripada folder “Sent” WhatsApp. Telegram tidak membuat pemisahan ini jadi failnya dikira sebagai “diterima”.',
  'flt.hide_dupes_sub':
      'Fail dengan nama dan saiz yang sama dipaparkan sekali sahaja (WhatsApp menulis imej yang sama ke beberapa folder).',
  'fp.no_subfolders':
      'Folder ini tiada subfolder.\nGunakan butang di bawah untuk meletakkan di sini, atau cipta dengan “folder baharu” di atas.',
  'ia.permission_hint':
      'Berikan kebenaran kepada “Dosyalarım” pada halaman tetapan yang dibuka, kembali semula, kemudian muat semula.',
  'important.explain':
      'Simpan fail yang tidak boleh hilang — kad pengenalan, bil, kontrak — di satu tempat. Folder dicipta dalam storan dalaman.\n\nUntuk menambah fail: tekan lama sebarang fail → “Alih” atau “Salin” → “Fail penting”. Anda juga boleh mencipta subfolder mengikut topik.',
  'important.no_subfolder':
      'Belum ada subfolder. Gunakan “Baharu” untuk mencipta topik (Bil, Pengenalan, Kontrak…). Untuk menambah fail, tekan lama mana-mana fail dan pilih “Alih”/“Salin”.',
  'jb.background_note':
      'Tugas terus berjalan di latar belakang dan kemajuan ditunjukkan dalam pemberitahuan. Jika anda menutup aplikasi daripada senarai tugas, proses akan berhenti.',
  'jb.empty':
      'Belum ada tugas.\nTugas seperti pengecilan saiz, pengosongan ruang dan imbasan pendua akan muncul di sini.',
  'jb.interrupted':
      'Tergendala kerana aplikasi ditutup. Ketik untuk memulakannya semula.',
  'lib.empty_body':
      'Tambah fail PDF, EPUB, MOBI, FB2, DJVU dan komik (CBZ). Anda juga boleh gunakan “Tambah ke pustaka” pada menu fail; fail asal kekal di tempatnya.',
  'ocr.script_arabic_sub':
      'Arab, Parsi, Urdu, Uthmaniyah: luar talian dengan model muat turun; jika tiada guna bacaan pintar.',
  'ocr.script_auto_sub':
      'Mengenal pasti pada peranti; mencuba model Arab atau bacaan pintar untuk teks bukan Latin.',
  'ocr.script_latin_sub':
      'Pada peranti sahaja, luar talian.',
  'oph.clear_body':
      'Hanya rekod operasi dipadamkan; tiada apa berlaku pada fail anda. Namun anda hilang keupayaan untuk membuat asal.',
  'oph.empty':
      'Belum ada operasi direkodkan.\nPemindahan dan penyusunan automatik dikumpul di sini dan boleh dibuat asal dari sini.',
  'oph.undo_partial':
      '{n}/{total} item berjaya dibuat asal; bakinya tidak dapat dialihkan. Rekod disimpan supaya anda boleh cuba semula.',
  'org.confirm_body':
      '{files} fail akan dialihkan ke {folders} folder. Fail disusun semula di dalam folder yang sama; tiada apa dipadamkan dan boleh dibuat asal daripada sejarah.',
  'org.include_sub_note':
      'Apabila dimatikan, hanya fail dalam folder ini disusun; subfolder sedia ada tidak disentuh.',
  'oss.body':
      'Pengecilan dan main balik video menggunakan Android Media3 (Apache 2.0); H.264 menggunakan pengekod perkakasan peranti. Main balik kodeks sandaran menggunakan libmpv/FFmpeg (media_kit, LGPL v2.1+, .so dinamik).\n\nSyncfusion Flutter PDF — Syncfusion Community License (BUKAN sumber terbuka; penggunaan percuma tertakluk pada syarat).\n\nKomponen lain (Flutter, PDFium/pdfrx, Google ML Kit, archive, image, video_player, flutter_local_notifications …) berlesen BSD/MIT/Apache 2.0. Senarai penuh: “Semua lesen”.',
  'pin.not_encrypted':
      'Kunci ini TIDAK menyulitkan fail: ia hanya menyembunyikannya daripada senarai dalam aplikasi ini. Jika telefon disambungkan ke komputer atau pengurus fail lain digunakan, fail masih kelihatan.',
  'pp.allow_annotate':
      'Benarkan anotasi',
  'pp.allow_assemble':
      'Benarkan susunan halaman',
  'pp.allow_copy':
      'Benarkan salinan teks',
  'pp.allow_edit':
      'Benarkan suntingan kandungan',
  'pp.allow_print':
      'Benarkan cetakan',
  'pp.dsign_signed':
      'Ditandatangani',
  'pro.buy':
      'Beli',
  'pro.canceled':
      'Pembelian dibatalkan.',
  'pro.done':
      'Pro dibuka — terima kasih!',
  'pro.f.ai':
      'AI',
  'pro.f.audiobook':
      'Buku audio',
  'pro.f.cleanup':
      'Kosongkan ruang',
  'pro.f.convert':
      'Penukaran',
  'pro.f.extras':
      'Alat tambahan',
  'pro.f.labs':
      'Ciri eksperimen',
  'pro.f.media':
      'Media & galeri',
  'pro.f.remote':
      'Sambungan jauh',
  'pro.f.scan':
      'Imbasan dokumen',
  'pro.f.transfer':
      'Pemindahan',
  'pro.f.vault':
      'Peti besi & kunci',
  'pro.failed':
      'Pembelian tidak dapat dilengkapkan; sila cuba lagi nanti.',
  'pro.owned_sub':
      'Sudah dibeli · Semua ciri Pro dibuka',
  'pro.pending':
      'Pembayaran tertunda; Pro akan dibuka secara automatik selepas diluluskan.',
  'pro.price':
      'Harga: {p}',
  'pro.restore':
      'Pulihkan pembelian',
  'pro.restore_none':
      'Tiada pembelian Pro ditemui pada akaun Google ini.',
  'pro.restored':
      'Pembelian dipulihkan — Pro aktif.',
  'pro.unavailable':
      'Tidak dapat mencapai Google Play. Semak sambungan internet dan pastikan anda log masuk ke Play Store.',
  'pt.annot_body':
      'Dokumen ini mempunyai {n} serlahan/nota. Operasi “{action}” membina semula halaman sehingga nota tersebut akan dipadamkan.\n\nJika mahu memadamkan halaman, butang “Padam” mengekalkan serlahan.',
  'pt.compress_body':
      'Dokumen ({size}) ditulis semula agar lebih kecil: aliran data dimampatkan semaksimum mungkin dan sisa semakan lama dibuang. Kualiti imej TIDAK berubah.\n\nOleh itu penjimatan lebih kecil pada dokumen imbasan (banyak imej). Bagi dokumen besar ini boleh mengambil masa seminit dan berjalan di latar belakang.',
  'ra.already_running':
      'Tugas ini sedang berjalan. Anda boleh memantaunya daripada bar di bawah atau skrin “Tugas”.',
  'ra.queued':
      'Tugas dimasukkan ke baris gilir; akan bermula selepas tugas semasa selesai. Pantau di skrin “Tugas”.',
  'ra.started':
      'Tugas bermula di latar belakang. Status dan fail hasilnya dapat dilihat pada bar di bawah atau skrin “Tugas”.',
  'scr.no_text_yet':
      'Imbasan ini dibuat tanpa pengecaman teks. Anda boleh mengenal pasti teks pada halaman sekarang.',
  'sim.background_note':
      'Anda boleh menutup skrin ini — imbasan diteruskan di latar belakang dan hasilnya sedia apabila anda kembali.',
  'srch.empty_hint':
      'Taip sebahagian nama fail atau folder.\n\nPetua: anda juga boleh menaip ayat seperti “video whatsapp bulan lepas”, “pdf minggu ini” atau “foto tahun 2024”.',
  'tf.failed':
      'Terjemahan gagal: {error}\nJika model bahasa belum dimuat turun, semak sambungan internet anda.',
  'tf.inplace_none':
      'Tiada perenggan dapat ditulis semula ({n} dicuba): fon terbenam dalam dokumen ini mungkin tidak menyokong huruf bahasa sasaran. “Terjemah sebagai teks” berfungsi untuk dokumen ini.',
  'tf.inplace_partial':
      '{n} perenggan diterjemahkan; {skipped} tidak dapat ditulis semula (fon terbenam kekurangan huruf bahasa sasaran atau teks tidak muat) dan dikekalkan seperti asal.',
  'tp.note':
      'Tag tidak ditulis di dalam fail; ia disimpan dalam rekod aplikasi ini sendiri. Tag mengikut fail apabila anda mengalih, menamakan semula atau memulihkannya dengan aplikasi ini, tetapi tidak jika dialihkan dengan aplikasi lain.',
  'tts.no_voices':
      'Peranti tidak melaporkan senarai suara; kelajuan dan pic masih boleh dilaraskan. Suara lebih baik boleh dimuat turun melalui tetapan pertuturan sistem.',
  'usb.diag_cbi_only':
      'Pemacu ini melaporkan protokol lama (CBI) — pemacu aplikasi menggunakan Bulk-Only.',
  'usb.diag_uas_only':
      'Pemacu ini hanya melaporkan pengangkutan UAS (USB 3) — pemacu aplikasi menggunakan Bulk-Only. Kebenaran folder (Pilih folder) masih berfungsi.',
  'usb.open_raw_hint':
      'Aplikasi memacu peranti secara terus walaupun Android tidak melekapkannya. FAT16/FAT32 dan exFAT boleh dibaca dan ditulis; NTFS dan ext2/3/4 hanya baca.',
  'vt.truncated':
      'Penukaran terpotong: output {out} s, sumber {src} s. Fail asal tidak disentuh.',
  'vt.unreadable_output':
      'Video yang ditukar tidak dapat dibaca (output rosak) — fail asal tidak disentuh.',
  'clean.safe_main':
      'Selamat dibebaskan',
  'clean.review_line':
      'Wajar disemak: {size}',
  'clean.free_after':
      'Ruang kosong selepas pilihan dibersihkan: {before} → {after} (+{delta})',
  'clean.groups_n':
      '{n} kumpulan',
  'clean.files_n':
      '{n} fail',
  'clean.similar_detail':
      'Gambar yang hampir sama dalam {n} kumpulan. Gambar terbaik setiap kumpulan disimpan; hanya lebihannya dicadangkan.',
  'clean.chat_media':
      'Media sembang',
  'clean.chat_media_detail':
      '{n} fail yang mungkin tidak diperlukan dalam folder WhatsApp dan Telegram: pelekat, GIF, media lama dan pendua.',
  'clean.why_similar':
      'Tiada yang dipilih terlebih dahulu; ketik untuk menyemak mengikut kumpulan. Gambar terbaik tidak pernah dipadam.',
  'clean.why_chat_media':
      'Tiada yang dipilih terlebih dahulu; ketik untuk menyemak mengikut jenis. Dipindah ke tong sampah, boleh dipulihkan.',
};
