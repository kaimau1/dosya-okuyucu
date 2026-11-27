part of '../app_strings.dart';

/// Endonezce (Bahasa Indonesia) — B17, 2026-11-27.
///
/// Ana tablonun (`strings/`) üstüne bindirilir: burada OLMAYAN anahtar
/// İngilizce gösterilir. Makine destekli ilk çeviri; ana ekran, dosya
/// yöneticisi, ayarlar ve hata metinleri önce. Anadili konuşan gözden
/// geçirmesi 👤 (PLAN §3 m.14). Malayca ayrı dosyada — biri ötekine
/// KOPYALANMAZ (Endonezya "berkas", Malezya "fail").
///
/// Bekçi: `l10n_test` (anahtar ana tabloda, yer tutucular Türkçeyle aynı) ve
/// `tool/on_denetim.py`.
const Map<String, String> _id = {
  // ── Ortak ──
  'common.strike': 'Coret',
  'common.paste': 'Tempel',
  'common.insert': 'Sisipkan',
  'common.ok': 'OK',
  'common.cancel': 'Batal',
  'common.yes': 'Ya',
  'common.no': 'Tidak',
  'common.details': 'Detail',
  'common.close': 'Tutup',
  'common.save': 'Simpan',
  'common.delete': 'Hapus',
  'common.share': 'Bagikan',
  'common.download': 'Unduh',
  'common.open': 'Buka',
  'common.edit': 'Edit',
  'common.apply': 'Terapkan',
  'common.search': 'Cari',
  'common.refresh': 'Muat ulang',
  'common.settings': 'Pengaturan',
  'common.previous': 'Sebelumnya',
  'common.next': 'Berikutnya',
  'common.copy': 'Salin',
  'common.more': 'Lainnya',
  'common.stop': 'Hentikan',
  'common.add': 'Tambah',
  'common.pause': 'Jeda',
  'common.resume': 'Lanjutkan',
  'common.password': 'Kata sandi',
  'common.ignore': 'Abaikan',
  'common.go': 'Buka',
  'common.saved': 'Tersimpan',
  'common.save_failed': 'Gagal menyimpan: {error}',
  'common.translate': 'Terjemahkan',
  'common.bold': 'Tebal',
  'common.italic': 'Miring',
  'common.underline': 'Garis bawah',
  'common.align_left': 'Rata kiri',
  'common.align_center': 'Tengah',
  'common.align_right': 'Rata kanan',
  'common.align_justify': 'Rata kiri-kanan',
  'common.undo': 'Urungkan',
  'common.redo': 'Ulangi',
  'common.retry': 'Coba lagi',
  'common.rescan': 'Pindai ulang',
  'common.clear': 'Bersihkan',
  'common.clear_selection': 'Hapus pilihan',
  'common.remove_bookmark': 'Hapus penanda',
  'common.new': 'Baru',
  'common.oldest': 'terlama',
  'common.best': 'terbaik',
  'common.deleting': 'Menghapus',
  'common.saved_hint':
      'Tersimpan. Gunakan ⋮ > Bagikan/Ekspor untuk lokasi permanen.',
  'common.open_failed': 'Gagal membuka: {error}',
  'common.done': 'Selesai',

  // ── Beranda ──
  'home.tab_files': 'Berkas',
  'home.new_document_title': 'Buat dokumen baru',
  'home.new_word': 'Dokumen Word',
  'home.new_excel': 'Lembar kerja Excel',
  'home.new_text': 'Berkas teks',
  'home.open_file': 'Buka berkas',
  'home.open_error': 'Gagal membuka berkas: {error}',
  'home.create_error': 'Gagal membuat dokumen: {error}',
  'home.time_minutes': '{n} menit lalu',
  'home.used_short': '{used} / {total} terpakai',
  'home.browse': 'Jelajahi',
  'home.analysis': 'Analisis',
  'home.free_space': 'Kosongkan',
  'home.drag_trash': 'Lepas di sini untuk menghapus',
  'home.drag_trash_ready': 'Lepaskan untuk menghapus dari beranda',
  'home.tile_removed': '"{name}" dihapus dari beranda',
  'home.undo': 'Urungkan',

  // ── Pengaturan ──
  'settings.title': 'Pengaturan',
  'settings.language': 'Bahasa',
  'settings.language_note':
      'Bahasa aplikasi. “Sistem” mengikuti perangkat Anda; bahasa yang tidak '
          'didukung beralih ke bahasa Turki. Teks yang belum diterjemahkan '
          'ditampilkan dalam bahasa Inggris.',
  'settings.language_system': 'Sistem',
  'settings.api_key': 'Kunci API Gemini',
  'settings.api_key_note':
      'Kunci disimpan di perangkat Anda. Anda bisa mendapatkannya gratis di '
          'aistudio.google.com.',
  'settings.model_fetched': 'Model (dari akun Anda)',
  'settings.model_default': 'Model (daftar bawaan)',
  'settings.model_refresh': 'Muat ulang daftar model',
  'settings.model_none': 'Tidak ada model untuk kunci ini.',
  'settings.model_error': '{error} Menampilkan daftar bawaan.',
  'settings.theme': 'Tema',
  'settings.ui_font': 'Fon',
  'settings.ui_text_size': 'Ukuran teks',
  'settings.size_small': 'Kecil',
  'settings.size_medium': 'Sedang',
  'settings.size_large': 'Besar',
  'settings.size_xlarge': 'Sangat besar',
  'settings.font_sample': 'Contoh: Pembaca Berkas — 0123456789',
  'settings.ui_text_size_note':
      'Fon dan ukuran sama di semua ponsel; pengaturan ukuran fon sistem tidak '
          'memengaruhi aplikasi — ubah hanya di sini.',
  'settings.perf_high_refresh': 'Kecepatan refresh tinggi',
  'settings.perf_dynamic_refresh': 'Kecepatan refresh dinamis',
  'settings.perf_dynamic_refresh_sub':
      'Hemat baterai: 120 Hz saat menggulir, 60 Hz atau lebih rendah saat layar '
          'diam (30 Hz jika didukung).',
  'settings.perf_high_refresh_sub':
      'Gulir lebih mulus di layar 120 Hz. Matikan agar tetap 60 Hz dan lebih '
          'hemat baterai.',
  'settings.perf_auto_rescan': 'Pindai ulang otomatis',
  'settings.perf_auto_rescan_sub':
      'Dasbor memindai ulang seluruh penyimpanan setiap 12 jam agar berkas yang '
          'ditambahkan di luar aplikasi terlihat. Matikan dan muat ulang daftar '
          'sendiri dengan menarik ke bawah.',
  'settings.about_sub': 'Info versi dan lisensi',
  'settings.theme_system': 'Sistem',
  'settings.theme_light': 'Terang',
  'settings.theme_dark': 'Gelap',
  'settings.about': 'Tentang',
  'settings.about_body':
      'Dosyalarım • versi {version}\n'
          'Pembaca/editor berkas multiformat yang cepat dan sederhana.',
  'settings.privacy_policy': 'Kebijakan privasi',
  'settings.privacy_policy_sub':
      'Apa yang tetap di perangkat dan kapan ada yang keluar',
  'settings.crash_log': 'Laporan error',
  'settings.crash_log_sub': 'Disimpan di perangkat, tidak pernah dikirim otomatis',
  'settings.crash_log_count': '{n} laporan',
  'settings.crash_log_empty':
      'Tidak ada laporan — aplikasi belum pernah gagal di perangkat ini.',
  'settings.crash_log_note':
      'Teks ini hanya ada di perangkat Anda. Ditampilkan lengkap agar Anda tahu '
          'apa yang akan dikirim; pesan error bisa berisi nama berkas.',
  'settings.crash_log_cleared': 'Laporan error dihapus',
  'settings.oss': 'Komponen sumber terbuka',
  'settings.oss_sub': 'Lisensi Media3, Syncfusion, dan lainnya',
  'set.suggested': 'Disarankan',
  'set.no_match': 'Tidak ada pengaturan yang cocok',
  'set.search_all': 'Cari semua pengaturan',
  'set.results_count': '{n} hasil',

  // ── Pesan error ──
  'uerr.permission': 'Tidak ada izin — akses ke folder ini belum diberikan.',
  'uerr.no_space': 'Penyimpanan penuh — ruang kosong tidak cukup.',
  'uerr.not_found': 'Berkas tidak ditemukan — mungkin sudah dipindah atau dihapus.',
  'uerr.read_only': 'Penyimpanan ini hanya-baca — tidak bisa ditulisi.',
  'uerr.exists': 'Sudah ada berkas dengan nama yang sama.',
  'uerr.offline': 'Tidak ada koneksi — periksa internet atau jaringan Anda.',
  'uerr.pdf_damaged': 'PDF tidak bisa dibaca — berkas mungkin rusak.',
  'uerr.pdf_locked': 'PDF dilindungi kata sandi — masukkan kata sandi dulu.',
  'uerr.ai_key':
      'Kunci AI tidak valid atau tidak diizinkan — periksa Pengaturan > Kecerdasan buatan.',
  'uerr.ai_quota': 'Kuota harian habis — coba lagi nanti.',
  'uerr.cancelled': 'Operasi dibatalkan.',
  'uerr.unknown':
      'Terjadi kesalahan tak terduga. Detailnya disimpan di log error.',
  'uerr.details': 'Detail',
  'uerr.retry': 'Coba lagi',
  'uerr.notif_off':
      'Notifikasi mati: progres hanya terlihat di dalam aplikasi. Tampilkan juga di notifikasi?',

  // ── Pengenalan ──
  'onb.reader_title': 'Baca berkas apa pun, dengan cepat',
  'onb.reader_body':
      'Membuka PDF, Word, Excel, slide, foto, video, dan arsip tanpa internet. '
          'Menjelajahi, mencari, dan merapikan berkas di ponsel Anda.',
  'onb.editor_title': 'Edit, konversi, bagikan',
  'onb.editor_body':
      'Edit dokumen, lembar kerja, dan presentasi di ponsel; urungkan/ulangi '
          'bekerja sama di setiap editor dan draf disimpan otomatis. Ekspor ke '
          'PDF dan format lain dari satu lembar.',
  'onb.scan_title': 'Pindai kertas',
  'onb.scan_body':
      'Pindai dokumen dengan kamera: tepi dikenali dan diluruskan, teks '
          'dikenali dan disimpan sebagai PDF yang bisa dicari.',
  'onb.samples': 'Tambahkan dokumen contoh',
  'onb.samples_done': 'Ditambahkan: folder {folder}',
  'onb.samples_failed': 'Gagal menulis dokumen contoh',
  'onb.choice_open': 'Buka berkas',
  'onb.choice_open_sub':
      'Tanpa izin: pilih berkas di pemilih Android dan langsung terbuka.',
  'onb.choice_manage': 'Kelola semua berkas di ponsel saya',
  'onb.choice_manage_sub':
      'Jelajahi folder, kosongkan ruang, dan rapikan berkas — tanpa iklan, tanpa pelacakan.',
  'onb.skip': 'Lewati',

  // ── Menu samping ──
  'side.title': 'Menu',
  'side.open': 'Buka menu',
  'side.home': 'Beranda',
  'side.edit': 'Edit menu',
  'side.show_recents': 'Tampilkan riwayat',
  'side.show_handle': 'Pegangan tepi',
  'side.show_handle_sub':
      'Bilah tipis di kiri setiap layar; ketuk untuk membuka menu',
  'side.handle_right': 'Pegangan di kanan',
  'side.handle_right_sub': 'Menu terbuka dari tepi kanan',
  'side.reorder_hint': 'Tekan lama baris lalu seret untuk mengurutkan',
  'side.reset': 'Atur ulang',

  // ── Dasbor & daftar ──
  'dash.sec_storage': 'Kartu penyimpanan',
  'dash.sec_recent': 'Riwayat',
  'dash.sec_categories': 'Ubin kategori',
  'dash.sec_favorites': 'Favorit',
  'dash.title': 'Sesuaikan beranda',
  'ui.smart_new': '+{n} baru · {t} dirapikan',
  'ui.history': 'Riwayat',
  'ui.history_sub': 'Baru dibuka',
  'ui.split_failed': 'Gagal membagi: {error}',
  'ui.tool_nearby': 'Perangkat terdekat',
  'ui.tool_new_doc': 'Dokumen baru',
  'ui.tool_ftp': 'Akses dari PC',
  'list.sort_folder_only': 'Hanya folder ini',
  'list.filter_clear': 'Hapus filter',
  'list.no_match': 'Tidak ada yang cocok dengan filter',
  'list.no_match_hint': 'Pilih jenis atau tanggal lain, atau hapus filter.',
  'list.empty_hint': 'Ketuk + untuk membuat folder atau membawa berkas ke sini.',
  'list.unreadable_hint':
      'Android bisa menyembunyikan folder ini dari aplikasi (mis. Android/data).',
  'create.doc': 'Dokumen baru',
  'create.scan': 'Pindai ke folder ini',
  'create.import': 'Impor ke folder ini',
  'create.paste_n': 'Tempel ({n})',
  'create.imported': '{n} berkas diimpor',
  'inbox.open': 'Buka',
  'inbox.storage_full': 'Penyimpanan {n}% penuh',
  'inbox.trash_full': '{n} item di sampah',
  'inbox.trash_hint': 'Memakan ruang — tinjau dan kosongkan',
  'lib.title': 'Pustaka',
  'lib.count': '{n} buku',
  'lib.added': '{n} buku ditambahkan',
  'lib.removed': 'Dihapus dari pustaka',
  'lib.tile_empty': 'Tambah buku',

  // ── Pengelola berkas ──
  'fm.photos': 'Foto',
  'fm.media_all': 'Foto & video',
  'fm.all_files': 'Semua berkas',
  'fm.quick_folders': 'Folder cepat',
  'fm.tools': 'Alat',
  'fm.all_tools': 'Semua ({n})',
  'fm.jobs': 'Tugas',
  'fm.jobs_running': '{n} berjalan',
  'fm.jobs_finished': '{n} selesai',
  'fm.downloads': 'Unduhan',
  'fm.downloads_missing': 'Folder Unduhan tidak ditemukan.',
  'fm.hero_percent': '{n}%',
  'fm.hero_used': '{used} dari {total} terpakai',
  'fm.hero_browse': 'Jelajahi',
  'fm.hero_analysis': 'Analisis',
  'fm.free_space': 'Kosongkan ruang',
  'fm.apk_files': 'Berkas APK',
  'fm.apk_archives': 'APK & arsip',
  'fm.scanning': 'Memindai…',
  'fm.scanning_storage': 'Memindai penyimpanan…',
  'fm.new_folder': 'Folder baru',
  'fm.folder_name': 'Nama folder',
  'fm.create': 'Buat',
  'fm.folder_create_failed': 'Gagal membuat folder: {error}',
  'fm.permission_title': 'Tampilkan semua berkas Anda di sini?',
  'fm.permission_body':
      'Untuk menjelajahi folder, mengosongkan ruang, dan memindahkan berkas, '
          'Android meminta “akses semua berkas”. Berkas Anda tidak pernah keluar '
          'dari ponsel; aplikasi ini tanpa iklan atau pelacakan. Anda juga bisa '
          'menambahkan folder pilihan saja.',
  'fm.permission_grant': 'Beri izin',
  'fm.none': 'Tidak ada',
  'fm.other': 'Lainnya',
  'fm.empty_folder': 'Folder ini kosong',
  'fm.search_here': 'Cari di folder ini',
  'fm.locked_folder': 'Folder terkunci',
  'fm.locked_prompt': 'Folder ini terkunci.\nMasukkan PIN untuk melihatnya.',
  'fm.lock_folder': 'Kunci folder (PIN)',
  'fm.unfavorite': 'Hapus dari favorit',
  'fm.favorite': 'Tambah ke favorit',
  'fm.show_hidden': 'Tampilkan berkas tersembunyi',
  'fm.layout': 'Tata letak: {name}',
  'fm.select_all': 'Pilih semua',
  'fm.selected_count': '{n} / {total} dipilih',
  'fm.new_name': 'Nama baru',
  'fm.irreversible': 'Tindakan ini tidak bisa dibatalkan.',
  'fm.new_folder_or_file': 'Folder / berkas baru',
  'fm.new_text_file': 'Berkas teks (.txt)',
  'fm.file_name': 'Nama berkas',
  'fm.file_create_failed': 'Gagal membuat berkas: {error}',
  'fm.auto_organize': 'Rapikan otomatis…',
  'fm.copying': 'Menyalin',
  'fm.moving': 'Memindahkan',
  'fm.transfer_partial': 'Beberapa item gagal dipindahkan: {error}',
  'fm.transfer_cancelled':
      'Operasi dibatalkan (item yang sudah dipindahkan tetap di tempatnya).',
  'fm.ext_changed_title': 'Ekstensi berubah',
  'fm.ext_changed_body':
      '"{old}" → "{new}". Ekstensi menentukan jenis berkas; mengubahnya bisa '
          'membuat berkas terbuka di aplikasi yang salah, atau tidak terbuka sama sekali.',
  'fm.ext_changed_keep': 'Pertahankan ekstensi',
  'fm.ext_changed_go': 'Tetap ubah',
  'fm.compare_running': 'Membandingkan',
  'fm.compare_same': 'Berkas IDENTIK (SHA-256 cocok)',
  'fm.compare_diff': 'Berkas BERBEDA',
  'fm.empty_folders': 'Bersihkan folder kosong',
  'fm.empty_scanning': 'Mencari folder kosong…',
  'fm.empty_none': 'Tidak ada folder kosong.',
  'fm.empty_found': '{n} folder kosong ditemukan. Hapus?',
  'fm.empty_deleted': '{n} folder kosong dihapus',
  'fm.export_list': 'Ekspor daftar',
  'fm.export_text': 'Teks (.txt)',
  'fm.export_csv': 'Lembar kerja (.csv)',
  'fm.export_done': '{name} tersimpan',
  'fm.copy': 'Salin',
  'fm.clip_copy': 'Salin ke papan klip',
  'fm.clip_cut': 'Potong ke papan klip',
  'fm.move': 'Pindahkan',
  'fm.rename': 'Ganti nama',
  'fm.copy_to_important': 'Tandai penting',
  'fm.copy_to_shared': 'Salin ke Bersama',
  'fm.properties': 'Properti',
  'fm.add_folder': 'Tambah folder',
  'fm.open_one': 'Buka satu berkas saja',
  'fm.open_with_other': 'Buka dengan aplikasi lain',
  'fm.extract_here': 'Ekstrak di sini',
  'fm.show_archive': 'Tampilkan isi arsip',
  'fm.reveal': 'Tampilkan lokasi',
  'fm.type': 'Jenis',
  'fm.folder': 'Folder',
  'fm.modified': 'Diubah',
  'fm.last_opened': 'Terakhir dibuka',
  'fm.not_computed': 'Belum dihitung',
  'fm.computing': 'Menghitung…',
  'fm.items_count': '{n} item',
  'fm.delete_permanent_title': 'Hapus permanen?',
  'fm.delete_trash_title': 'Pindahkan ke sampah?',
  'fm.delete_permanent_body':
      '{label} akan dihapus PERMANEN. Tindakan ini tidak bisa dibatalkan. '
          '(Sampah dinonaktifkan di pengaturan.)',
  'fm.delete_trash_body':
      '{label} akan dipindahkan ke sampah. Anda bisa memulihkannya dari Sampah.',
  'fm.delete_permanent_action': 'Hapus {what} secara permanen',
  'fm.delete_trash_action': 'Pindahkan {what} ke sampah',
  'fm.renamed': 'Nama diganti menjadi {name}',
  'fm.trashed_n': '{n} item dipindahkan ke sampah',
  'fm.undo': 'Dibatalkan.',
  'fm.undo_action': 'Urungkan',
  'fm.deleting': 'Menghapus',
  'fm.undo_failed': 'Gagal mengurungkan: {error}',
  'fm.deleted_n': '{n} item dihapus permanen',
  'fm.deleted_partial': '{ok} item dihapus, {fail} gagal dihapus.',
  'fm.trashed_partial':
      '{ok} item dipindahkan ke sampah, {fail} gagal dipindahkan: {error}',
  'fm.verb_moved': 'dipindahkan',
  'fm.verb_copied': 'disalin',
  'fm.transfer_done': '{n} item telah {verb} ke “{where}”.',
  'fm.transfer_stopped':
      'Dihentikan · {n} item sudah {verb} ke “{where}” '
          '(pemindahan yang sedang berjalan tidak bisa dipotong).',
  'fm.transfer_errors': '{n} item {verb}, {fail} gagal dipindahkan: {error}',
  'fm.important_copied': '{n} item disalin ke “{folder}”.',
  'fm.copy_failed': 'Gagal menyalin: {error}',
  'fm.rename_failed': 'Gagal mengganti nama: {error}',
  'fm.zip_failed': 'Gagal mengompres: {error}',
  'fm.extract_failed': 'Gagal mengekstrak: {error}',
  'fm.zipping': 'Mengompres',
  'fm.encrypting': 'Mengenkripsi (AES-256)',
  'fm.extracting': 'Mengekstrak',
  'fm.trashing': 'Memindahkan ke sampah',
  'fm.copying_important': 'Menyalin ke berkas penting',
  'fm.copying_shared': 'Menyalin ke folder Bersama',
  'fm.extracted_to': 'Diekstrak ke “{name}”.',
  'fm.created_archive': '“{name}” dibuat.',
  'fm.entry_clip_copied':
      '“{name}” disalin ke papan klip. Ketuk “Tempel” di folder tujuan.',
  'fm.entry_clip_cut':
      '“{name}” dipotong ke papan klip. Ketuk “Tempel” di folder tujuan.',
  'fm.drive_subtitle': 'Berkas di cloud',
  'fm.memory_analysis': 'Analisis penyimpanan',
  'fm.new_files': 'Baru',
  'fm.new_files_note': 'Kedatangan terbaru',
  'fm.last_scan': 'Pindaian terakhir: {date} · {n} berkas',
  'fm.new_word_doc': 'Dokumen Word (.docx)',
  'fm.search_help': 'Cari & Bantuan',
  'fm.apps': 'Aplikasi',
  'fm.calc_size': 'Hitung ukuran',
  'fm.copy_path': 'Salin jalur',
  'fm.new_xlsx': 'Lembar kerja Excel (.xlsx)',
  'fm.external_storage': 'Drive eksternal',
  'fm.external_count': '{n} drive',
  'fm.external_none_short': 'Tidak terpasang',
  'fm.external_unusable_short':
      '{name} terpasang tetapi Android tidak memberikan jalur berkas.',
  'fm.external_unusable_title': 'Tidak bisa membuka {name}',
  'fm.external_unusable':
      '{name} terpasang tetapi Android tidak menampilkannya sebagai jalur berkas. '
          'Ketuk "Pilih folder" dan pilih drive untuk akses permanen; jika tidak '
          'ada di pemilih, pilih "Transfer berkas" di notifikasi USB.',
  'fm.external_usb_count': '{n} USB',
  'fm.external_card_count': '{n} kartu SD',
  'fm.copy_to_external': 'Salin ke drive eksternal',
  'fm.external_pick_hint': 'USB / kartu SD',
  'fm.external_none':
      'Tidak ada drive eksternal terpasang. Colokkan flashdisk USB atau kartu SD '
          'lalu coba lagi.',
  'fm.copying_external': 'Menyalin ke {volume}…',
  'fm.external_copied': '{n} item disalin ke {volume} (folder Dosya Okuyucu).',
  'fm.usb_attached': '{volume} terpasang — ketuk untuk membuka.',
  'fm.usb_detached': 'Drive eksternal dilepas.',
  'fm.usb_open': 'Buka',
  'fm.used': 'Terpakai',
  'fm.extracting_name': 'Ekstraksi',
  'fm.deleting_name': 'Penghapusan',
  'fm.trashing_name': 'Memindahkan ke sampah',
  'fm.copying_important_name': 'Salin ke berkas penting',
  'fm.copying_shared_name': 'Salin ke Bersama',
  'fm.copying_name': 'Salin',
  'fm.copying_external_name': 'Salin ke {volume}',
  'fm.zipping_name': 'Kompresi',
  'fm.free_bytes': '{v} kosong',

  // ── Properti & tindakan berkas ──
  'prop.contents': 'Isi',
  'prop.contents_value': '{files} berkas, {dirs} folder',
  'prop.encoding': 'Pengodean',
  'prop.size': 'Ukuran',
  'prop.location': 'Lokasi',
  'prop.digest': 'Checksum (SHA-256)',
  'prop.compute_digest': 'Hitung checksum',
  'prop.computing_digest': 'Menghitung…',
  'prop.digest_copied': 'Checksum disalin',
  'prop.photo_info': 'Detail foto',
  'prop.taken_at': 'Diambil',
  'prop.camera': 'Kamera',
  'prop.lens': 'Lensa',
  'prop.resolution': 'Resolusi',
  'prop.iso': 'ISO',
  'prop.exposure': 'Eksposur',
  'prop.aperture': 'Bukaan',
  'prop.focal': 'Panjang fokus',
  'prop.flash': 'Lampu kilat',
  'prop.flash_on': 'Menyala',
  'prop.flash_off': 'Tidak menyala',
  'prop.software': 'Perangkat lunak',
  'prop.copy_name': 'Salin nama',
  'ea.rotate': 'Putar',
  'ea.rotate_hint': '90° ke kanan · berkas baru',
  'ea.split': 'Bagi menjadi beberapa bagian',
  'ea.split_hint': 'Batas FAT32 / email',
  'ea.join': 'Gabungkan bagian',
  'ea.join_hint': '.001 .002 …',
  'ea.sec_open': 'Buka & bagikan',
  'ea.sec_name': 'Nama kedua & kategori',
  'ea.sec_move': 'Papan klip & tempat lain',
  'ea.sec_file': 'Tindakan berkas',
  'ea.sec_this': 'Berkas ini',
  'ea.compress': 'Kompres',
  'ea.compress_hint': 'ZIP · 7z · kata sandi',
  'ea.resize': 'Kecilkan ukuran',
  'ea.resize_hint': 'resolusi / frame rate',
  'ea.tag': 'Tag',
  'ea.tag_hint': 'orang / grup',
  'ea.clip_hint': 'untuk ditempel nanti',
  'ea.shared_hint': 'dibagikan lewat jaringan',
  'ea.quick_share': 'Kirim ke sekitar',
  'ea.shortcut': 'Tambah ke layar utama',
  'ea.shortcut_hint': 'pintasan di layar utama ponsel',
  'ea.shortcut_unsupported': 'Peluncur ponsel ini tidak mendukung pintasan.',
  'ea.shortcut_requested':
      'Pintasan untuk “{name}” diminta — konfirmasikan di layar utama.',
  'ea.shortcut_failed': 'Gagal menambahkan pintasan.',
  'ea.shortcut_missing':
      'Item tujuan pintasan tidak ditemukan (mungkin sudah dipindah atau dihapus).',
  'ea.hide': 'Sembunyikan',
  'split.pick_size': 'Ukuran bagian',
  'split.working': 'Membagi',
  'split.done': '{n} bagian dibuat',
  'split.cancelled': 'Pembagian dihentikan',
  'split.too_small':
      'Berkas lebih kecil dari ukuran bagian — tidak perlu dibagi.',
  'join.working': 'Menggabungkan',
  'join.done': '{name} dibuat',
  'join.failed': 'Gagal menggabungkan: {error}',
  'join.name': 'Penggabungan',
  'important.delete_title': 'Menghapus berkas penting',
  'important.delete_mixed': 'Pilihan berisi {n} item penting: {names}',
  'important.delete_anyway': 'Tetap hapus',
  'important.keep_delete_rest': 'Simpan yang penting, hapus {n} lainnya',
  'important.delete_all_too': 'Hapus semua {n} item, termasuk yang penting',
  'important.pick_category': 'Kategori apa?',
  'important.general': 'Umum (tanpa kategori)',
  'important.new_category': 'Kategori baru',
  'qf.make_shortcut': 'Buat pintasan',
  'qf.make_shortcut_hint': 'Kartu saya atau folder cepat',
  'qf.card_hint': 'sebagai kartu di beranda',
  'qf.quick_remove': 'Hapus dari folder cepat',
  'qf.quick_hint': 'dengan ikon folder di bawah beranda',
  'qf.card_added': '"{name}" ditambahkan ke Kartu saya',
  'qf.card_removed': '"{name}" dihapus dari Kartu saya',
  'qf.quick_added': '"{name}" ditambahkan ke folder cepat',
  'qf.quick_removed': '"{name}" dihapus dari folder cepat',
  'qf.add': 'Tambah',
  'qf.add_here': 'Tambah ke folder cepat',
  'qf.empty': 'Belum ada folder cepat — ketuk "Tambah"',

  // ── Drive eksternal ──
  'saf.title': 'Akses drive dengan izin folder',
  'saf.body':
      'Di perangkat ini Android tidak menampilkan drive yang terpasang sebagai '
          'jalur berkas, jadi drive tidak muncul di daftar. Jika Anda memilih '
          'drive (atau folder di dalamnya) di pemilih folder Android, aplikasi '
          'mendapat akses permanen: menjelajah, membuka, menyalin, menghapus, '
          'dan mengganti nama semuanya bisa.\n\n'
          'Jika drive juga tidak ada di pemilih, Android belum memasangnya — '
          'periksa notifikasi USB.',
  'saf.pick': 'Pilih folder',
  'saf.granted': 'Lewat izin folder',
  'usb.eject_mounted_hint':
      'Aplikasi tidak bisa melepas drive yang dipasang Android (tidak ada API '
          'publik). Gunakan tombol "Keluarkan" di notifikasi USB/SD; untuk drive '
          'yang dikelola aplikasi, gunakan "Lepas dengan aman" di menu ⋮.',
  'usb.eject': 'Lepas dengan aman',
  'usb.diag_title': 'Diagnostik USB',
  'usb.open_raw': 'Buka drive secara langsung',
  'usb.multi_volume': 'Drive ini punya {n} volume; yang pertama dibuka.',
  'usb.pick_volume': 'Pilih volume',
  'usb.open_raw_failed':
      'Gagal membuka drive secara langsung: izin ditolak atau format tidak '
          'dikenal (FAT, exFAT, NTFS, dan ext2/3/4 didukung).',

  // ── Penampil (PDF, dokumen, teks) ──
  'pdfm.resume': 'Buka lagi di tempat terakhir',
  'legacy.done': 'Salinan dibuat: {name}',
  'code.tab_width': 'Lebar indentasi',
  'md.edit': 'Edit',
  'md.preview': 'Pratinjau',
  'shell.pages': '{n} halaman',
  'dm.page': 'Halaman',
  'dm.text': 'Teks',
  'dm.convert': 'Konversi & cetak',
  'dm.listen': 'Dengarkan',
  'dm.image': 'Gambar',
  'vw.reading_settings': 'Pengaturan baca',
  'vw.text_size': 'Ukuran teks',
  'vw.font_default': 'Bawaan',
  'vw.layout': 'Tata letak',
  'vw.speak_part': 'Bagian {n} dari {total}',
  'find.none': 'Tidak ada hasil',
  'vw.prettify_done': 'Diformat',
  'vw.prettify_failed':
      'Berkas ini tidak bisa diurai — teks dibiarkan apa adanya',
  'vw.wrap_on': 'Bungkus baris',
  'vw.replace_with': 'Ganti dengan',
  'vw.replace_one': 'Ganti',
  'vw.replace_all': 'Ganti semua',
  'vw.replaced': '{n} penggantian dilakukan',
  'vw.replace_none': 'Tidak ada yang diganti',
  'vw.show_replace': 'Tampilkan/sembunyikan ganti',
  'vw.goto_line': 'Ke baris',
  'vw.line_number': 'Nomor baris (1-{max})',
  'vw.line_numbers': 'Nomor baris',
  'vw.line_ending': 'Akhir baris',
  'code.line_spacing': 'Spasi baris',
  'pp.book_view': 'Buku',
  'pp.sepia': 'Warna kertas (sepia)',
  'pp.sepia_hint': 'Melembutkan warna putih; mati saat mode malam aktif',
  'pp.scroll_lock': 'Kunci gulir',
  'pp.scroll_lock_hint': 'Hanya gulir vertikal, zoom mati',
  'pp.notes_booklet': 'Buku sorotan dan catatan',
  'pp.notes_booklet_sub': 'Bagikan semua tanda dalam satu daftar (Markdown)',
  'pp.find_list': 'Daftar hasil',
  'pp.image_zoom': 'Perbesar gambar',
  'pp.image_zoom_hint': 'Layar penuh berlatar hitam; tarik ke bawah untuk menutup',
  'pp.crop_margins': 'Potong margin',
  'pp.paged': 'Per halaman',
  'pp.hide_status': 'Sembunyikan juga bilah status saat membaca',
  'pp.hide_status_hint':
      'Jam dan baterai menghilang saat menggulir; satu ketukan memunculkannya lagi',
  'pp.crop_none': 'Tidak ada margin untuk dipotong',
  'vn.prompt': 'Bicaralah — catatan masuk ke Catatan',
  'wp.dictate_unavailable': 'Tidak ada pengenal suara di perangkat ini',
  'vw.fullscreen': 'Layar penuh',
  'pp.keep_awake': 'Layar tetap menyala',
  'pp.keep_awake_hint': 'Layar tidak meredup saat Anda membaca',
  'pp.volume_keys': 'Balik halaman dengan tombol volume',
  'pp.volume_keys_hint': 'Turun: halaman berikutnya · Naik: sebelumnya',
  'pp.auto_scroll': 'Gulir otomatis',
  'pp.auto_scroll_hint': 'Berhenti saat Anda menyentuh layar',
  'pp.as_off': 'Mati',
  'pp.as_slow': 'Lambat',
  'pp.as_mid': 'Sedang',
  'pp.as_fast': 'Cepat',
  'vw.fullscreen_hint': 'Menyembunyikan bilah status dan navigasi',
  'vw.rotate': 'Putar',
  'vw.text_bigger': 'Teks lebih besar',
  'vw.text_smaller': 'Teks lebih kecil',
  'vw.one_column': 'Satu kolom',
  'vw.two_columns': '2 kolom',
  'vw.four_columns': '4 kolom',
  'vw.night_on': 'Mode malam',
  'vw.image_to_pdf': 'Gambar ke PDF',
  'vw.image_to_pdf_body':
      'Gambar akan disematkan ke PDF dengan resolusi penuh, tanpa dipotong.\n\n',
  'vw.still_loading': 'Dokumen masih dimuat…',
  'vw.page_jump_failed_total':
      'Tidak bisa melompat ke halaman {target}; tetap di halaman {landed} (dari {total}).',
  'vw.goto_page_short': 'ke halaman',
  'vw.find_in_doc': 'Cari di dokumen…',
  'vw.find_in_doc_short': 'Cari di dokumen',
  'vw.image_only': 'Hanya gambar',
  'vw.doc_info': 'Info dokumen',
  'vw.speak': 'Bacakan',
  'vw.toc': 'Daftar isi',
  'vw.side_panel': 'Gambar mini halaman',
  'vw.fill_form': 'Isi formulir',
  'vw.to_pdf': 'Konversi ke PDF',
  'vw.ocr_short': 'Kenali teks',
  'vw.ocr_running': 'Mengenali teks…',
  'vw.image_pdf_job_name': 'Gambar ke PDF',
  'vw.ocr_text': 'Teks yang dikenali',
  'vw.ocr_selected_n': '{n} karakter dipilih',
  'vw.ocr_overlay_hint': 'Tekan lama untuk memilih teks',
  'vw.ocr_show_list': 'Tampilkan teks terpisah',
  'vw.ocr_overlay_close': 'Sembunyikan lapisan teks',
  'vw.ocr_overlay_open': 'Pilih teks pada gambar',
  'vw.ocr_in_pdf':
      'Apakah teks di dalamnya juga perlu bisa dicari/disalin di PDF? '
          '(Pengenalan teks butuh beberapa detik dan tidak mengubah gambar.)',
  'vw.ocr_also': 'Kenali teks juga',
  'vw.scanning_text': 'Memindai teks…',
  'vw.copy_all': 'Salin semua',
  'vw.copied_all': 'Semua disalin',
  'vw.copied_chars': 'Disalin ({n} karakter)',
  'vw.no_text_to_translate': 'Tidak ada teks untuk diterjemahkan.',
  'vw.highlighted': 'Disorot',
  'vw.highlight_remove': 'Hapus sorotan',
  'vw.highlight_removed': '{n} sorotan dihapus.',
  'vw.highlight_none_here': 'Tidak ada sorotan di bagian yang Anda pilih.',
  'vw.highlight_hint': 'Sorot',
  'vw.highlight_failed': 'Gagal menyorot: {error}',
  'vw.word': 'Kata',
  'vw.line': 'Baris',
  'vw.chars': 'Karakter',
  'vw.chars_nospace': 'Karakter (tanpa spasi)',
  'vw.paragraph': 'Paragraf',
  'vw.doc_content': 'Isi dokumen…',
  'vw.pdf_preparing': 'Menyiapkan PDF…',
  'vw.pdf_loading': 'PDF masih dimuat; coba lagi sebentar.',
  'vw.pdf_exported': 'Diekspor sebagai PDF',
  'vw.pdf_failed': 'Gagal membuat PDF: {error}',
  'vw.image_failed': 'Gambar tidak bisa ditampilkan.',
  'vw.table_empty': 'Tabel kosong atau tidak terbaca.',
  'vw.no_viewer':
      'Tidak ada penampil bawaan untuk jenis berkas ini.\nAnda bisa membukanya dengan aplikasi lain.',
  'vw.link_title': 'Buka tautan',
  'vw.link_body':
      'Dokumen ini ingin membawa Anda ke:\n\n{url}\n\n'
          'Hati-hati dengan alamat yang tidak Anda kenal.',
  'vw.link_failed': 'Gagal membuka tautan',
  'vw.link_failed_e': 'Gagal membuka tautan: {error}',
  'vw.save_edits': 'Simpan perubahan',
  'vw.edits_applied': 'Perubahan Anda telah diterapkan ke dokumen ini.',
  'vw.searching': 'mencari…',
  'vw.no_readable_text':
      'Tidak ada teks yang terbaca. Pada dokumen hasil pindaian, jalankan “Kenali teks (OCR)” dulu.',
  'vw.sel_count': '{chars} karakter · {words} kata',
  'vw.sel_expand': 'Tampilkan seluruh pilihan',
  'vw.sel_collapse': 'Ciutkan pratinjau',
  'word.font_family': 'Fon',
  'ps.act_edited': 'Diedit',
  'tts.voice_settings': 'Pengaturan suara',
  'pt.locked_title': 'Dokumen ini berkata sandi',
  'pt.enter_password': 'Masukkan kata sandi',
  'pdf.sec_look': 'Tampilan & tata letak',
  'pdf.sec_comfort': 'Kenyamanan membaca',
  'pdf.sec_screen': 'Layar & sesi',
  'reader.open': 'Tampilan baca',
  'tf.page_reading': 'Membaca halaman {n} / {total}…',
  'tf.page_ocr': 'Memindai halaman {n} / {total} (pengenalan teks)…',
  'tf.mode_title': 'Hasil terjemahan ingin seperti apa?',
  'tf.mode_inplace': 'Dokumen itu sendiri (tata letak sama)',
  'tf.mode_inplace_hint':
      'Fon, ukuran, dan tata letak halaman tetap; hanya kata-katanya yang berubah. '
          'Hasilnya disimpan sebagai PDF baru.',
  'tf.mode_text': 'Sebagai teks biasa (untuk dibaca atau disalin)',
  'tf.mode_text_hint':
      'Halaman hasil pindaian ikut disertakan (lewat OCR), tetapi hasilnya teks biasa.',
  'vw.saving_wait': 'Menyimpan, tunggu sebentar…',
  'vw.find_selection': 'Cari di dokumen',
  'vw.highlight_color': 'Warna sorotan',
  'vw.pdf_error_title': 'PDF ini tidak bisa dibuka',
  'vw.pdf_error_empty':
      'Berkas kosong (0 byte). Kemungkinan unduhan atau penyimpanan terputus.',
  'vw.pdf_error_broken': 'Berkas mungkin rusak atau belum terunduh lengkap.',
  'vw.pdf_error_restore': 'Pulihkan yang asli',
  'uix.no_text': 'Tidak ada yang bisa dibaca',
  // ── Kitaplık, temizlik, Pro, PDF araçları (m.3) ──
  'lib.add':
      'Tambah buku',
  'lib.already':
      'Sudah ada di perpustakaan Anda',
  'lib.remove':
      'Hapus dari perpustakaan',
  'lib.missing':
      'Berkas tidak ditemukan (dipindahkan atau dihapus)',
  'lib.search':
      'Cari di perpustakaan',
  'lib.continue':
      'Lanjutkan membaca',
  'lib.shelf':
      'Rak',
  'lib.no_match':
      'Tidak ada buku yang cocok',
  'lib.pin_home':
      'Tambah ke layar utama',
  'lib.empty_title':
      'Perpustakaan Anda kosong',
  'lib.find':
      'Cari buku di ponsel ini',
  'lib.find_none':
      'Tidak ada buku baru ditemukan',
  'lib.find_title':
      '{n} buku ditemukan',
  'lib.add_selected':
      'Tambah yang dipilih ({n})',
  'lib.stats':
      '{r} dibaca · {d} selesai · {u} belum dimulai',
  'lib.show_folder':
      'Tampilkan di folder',
  'lib.share':
      'Bagikan',
  'lib.clean_missing':
      'Hapus yang hilang ({n})',
  'lib.page_of':
      '{p}% dibaca',
  'lib.audiobooks_sub':
      'Dengarkan buku audio dari dokumen Anda',
  'clean.shrink_this':
      'Perkecil ukuran',
  'clean.shrink_this_est':
      'Perkecil ukuran · ≈ {to}',
  'clean.dup_groups':
      'Tinjau per kelompok',
  'clean.deep_title':
      'CARI RUANG LEBIH BANYAK',
  'clean.deep_note':
      'Pemindaian ini memeriksa isi berkas; bisa memakan beberapa menit dan berjalan di latar belakang.',
  'clean.deep_running':
      'Memindai…',
  'clean.deep_found':
      '{n} berkas · {size} dapat dibebaskan',
  'clean.deep_none':
      'Selesai dipindai · tidak ada yang perlu dibersihkan',
  'clean.deep_similar':
      'Foto serupa',
  'clean.deep_content':
      'Pemindaian isi gambar',
  'clean.deep_content_note':
      'Gambar ucapan, meme, poster, serta foto buram dan gelap',
  'clean.confirm_title':
      'Bersihkan?',
  'clean.title':
      'Bebaskan ruang',
  'clean.analyzing':
      'Bebaskan ruang: menganalisis penyimpanan',
  'clean.analyzing_name':
      'Bebaskan ruang: analisis penyimpanan',
  'clean.reading_index':
      'Membaca penyimpanan…',
  'clean.nothing':
      'Tidak ada yang jelas perlu dibersihkan',
  'clean.nothing_body':
      'Tidak ada yang jelas perlu dibersihkan 🎉\nPenyimpanan Anda tampak rapi.',
  'clean.recoverable':
      '{size} dapat dibebaskan',
  'clean.suggestions':
      '{n} saran',
  'clean.pick_one':
      'Pilih satu saran',
  'clean.personal_warning':
      'Hati-hati: ini mungkin berkas pribadi',
  'clean.cleaning':
      'Bebaskan ruang: membersihkan {size}',
  'clean.cleaning_name':
      'Bebaskan ruang: pembersihan {size}',
  'clean.cleaned_detail':
      '{size} dibebaskan · {n} saran diterapkan',
  'clean.reanalyze':
      'Analisis ulang',
  'clean.open_trash':
      'Buka tempat sampah',
  'clean.show_hidden':
      'Tampilkan {n} saran tersembunyi',
  'clean.dupes_note':
      'Pemindaian duplikat membandingkan berkas byte demi byte; mungkin butuh waktu.',
  'clean.badge_safe':
      'Aman',
  'clean.badge_review':
      'Tinjau',
  'clean.inspect_files':
      'Periksa {n} berkas',
  'clean.hide_files':
      'Sembunyikan',
  'clean.show_all_more':
      'Tampilkan semua (+{n})',
  'clean.summary_line':
      'Hingga {total} dapat dibebaskan · Dipilih: {selected}',
  'clean.select_safe':
      'Pilih yang aman',
  'clean.deselect_all':
      'Hapus pilihan',
  'clean.original_kept':
      'Aslinya tetap ada: {loc} · {size}',
  'clean.view_original':
      'Lihat aslinya',
  'clean.copy_will_go':
      'Dihapus: hanya salinan ini',
  'clean.clean_this':
      'Bersihkan ini · {size}',
  'clean.clean_this_dirs':
      'Bersihkan {n} folder',
  'clean.confirm_copies':
      'Untuk salinan, hanya salinannya yang dihapus; setiap berkas asli tetap ada di perangkat.',
  'clean.empty_trash_now':
      'Kosongkan sekarang',
  'clean.done_failed':
      'Pembersihan tidak dapat diselesaikan',
  'clean.filter_all':
      'Semua',
  'clean.filter_safe':
      'Aman',
  'clean.filter_review':
      'Tinjau',
  'clean.selected_partial':
      '{sel}/{total} dipilih',
  'clean.select_all_in':
      'Pilih semua',
  'clean.clear_in':
      'Tidak ada',
  'clean.free_items':
      'Bebaskan {size} · {n} item',
  'clean.empty_folders_only':
      'Bersihkan {n} folder kosong',
  'clean.chat_tool':
      'Pembersihan media obrolan',
  'clean.chat_tool_sub':
      'Stiker, GIF, dan media lama WhatsApp & Telegram',
  'clean.disk_used_line':
      '{used} / {total} terpakai · Kosong: {free}',
  'clean.disk_after_line':
      'Ruang kosong setelah pembersihan: {before} → {after}',
  'clean.trust_no_personal':
      'Foto & dokumen tidak disentuh',
  'clean.trust_trash_undo':
      'Dipindah ke tempat sampah, dapat dipulihkan',
  'clean.trust_important':
      'Berkas penting tetap terlindungi',
  'clean.trust_important_n':
      '{n} berkas penting dilindungi',
  'clean.quick_clean_safe':
      'Bersihkan yang aman · {size}',
  'clean.sec_safe_title':
      'Bersihkan dengan Aman (Tanpa Risiko)',
  'clean.sec_safe_sub':
      'Hanya sampah, duplikat persis, cache, dan sisa penginstal. Berkas pribadi tidak disentuh.',
  'clean.sec_review_title':
      'Tinjau untuk Ruang Lebih Banyak (Keputusan Anda)',
  'clean.sec_review_sub':
      'Tidak ada yang dipilih sebelumnya. Periksa item atau perkecil video besar tanpa menghapusnya.',
  'clean.done_card_title':
      '{size} dibebaskan!',
  'clean.confirm_safe_only':
      'Foto, dokumen, dan berkas penting Anda tidak akan disentuh.',
  'clean.shrink_without_delete':
      'Bebaskan ruang tanpa menghapus',
  'clean.need_permission_title':
      'Perlu akses folder untuk memindai',
  'clean.need_permission_body':
      'Beri izin untuk menemukan sampah, duplikat, dan berkas besar. Foto dan dokumen Anda tidak pernah dihapus otomatis.',
  'clean.need_permission_btn':
      'Beri izin & pindai',
  'clean.confirm_lead':
      '{n} saran · {size} akan dibebaskan.\n\n',
  'clean.confirm_tail':
      'Berkas dipindahkan ke tempat sampah; Anda dapat memulihkannya dari sana.',
  'pro.title':
      'Versi Pro',
  'pro.row_sub':
      'Folder pintar, editor PDF, buku audio & pengecil video · Sekali bayar',
  'pro.one_time_badge':
      'Pembelian sekali · Tanpa iklan',
  'pro.price_one_time':
      '{p} · Sekali bayar',
  'pro.smart_limit_note':
      'Pro menyertakan jatah awal 500 berkas untuk Folder Pintar; analisis cloud tambahan bersifat opsional lewat langganan atau kunci Anda sendiri.',
  'pro.locked_title':
      '{f} ada di Pro',
  'pro.locked_sub':
      'Alat ini terbuka di versi Pro sekali bayar. Semua pengelolaan berkas dan pembacaan dasar tetap gratis di Lite.',
  'pro.feature_title':
      '{f} ada di versi Pro',
  'pro.lead':
      'Lite mencakup membaca gratis, pengelola berkas, penyuntingan dasar, pengisian formulir, dan tanda tangan. Pro membuka:',
  'pro.later':
      'Nanti saja',
  'pro.trust':
      'Semua fitur inti di Lite tetap gratis dan bebas iklan selamanya.',
  'pro.smart_locked_title':
      'Folder Pintar ada di Pro',
  'pro.smart_locked_sub':
      'Tingkatkan ke Pro untuk menata berkas Anda ke kategori pintar dan kueri tersimpan.',
  'pro.saved_locked_title':
      'Folder Pintar Tersimpan ada di Pro',
  'pro.saved_locked_sub':
      'Tingkatkan ke Pro untuk membuat folder yang diperbarui otomatis dari kueri tersimpan Anda.',
  'pro.f.pdfAdvanced':
      'Pengeditan & alat PDF',
  'pt.page_numbers':
      'Tambah nomor halaman',
  'pt.pn_skip_first':
      'Lewati halaman sampul',
  'pt.pn_skip_first_sub':
      'Halaman pertama tidak diberi nomor; penomoran mulai dari 2',
  'pt.pn_with_total':
      'Gunakan format "3 / 12"',
  'pt.pn_right':
      'Rata ke kanan bawah',
  'pt.op_page_numbers':
      'Menambahkan nomor halaman',
  'pt.export_images':
      'Ekspor halaman sebagai gambar (PNG)',
  'pt.op_export_images':
      'Membuat gambar',
  'pt.export_images_count':
      '{n} gambar halaman',
  'pt.export_images_limit':
      'Paling banyak {n} halaman sekaligus: pilih halaman terlebih dahulu.',
  'pt.export_images_failed':
      'Gagal membuat gambar halaman',
  'pt.watermark':
      'Tambah watermark',
  'pt.watermark_hint':
      'mis. DRAF, SALINAN',
  'pt.op_watermark':
      'Menambahkan watermark',
  'pt.move_to':
      'Pindahkan halaman ke…',
  'pt.move_to_hint':
      'Nomor halaman tujuan (1-{n})',
  'pt.op_duplicate':
      'Gandakan halaman',
  'pt.op_insert_blank':
      'Sisipkan halaman kosong',
  'pt.op_reverse':
      'Balik urutan halaman',
  'pt.op_split':
      'Memecah',
  'pt.split_every':
      'Pecah menjadi beberapa bagian…',
  'pt.split_size':
      'Bagian berisi {n} halaman',
  'pt.split_done':
      '{n} berkas ditulis di samping dokumen.',
  'pt.split_too_short':
      'Pemecahan butuh minimal dua halaman.',
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
      'Menghapus',
  'pt.op_move':
      'Memindahkan',
  'pt.op_move_page':
      'Memindahkan halaman',
  'pt.op_merge':
      'Menggabungkan',
  'pt.op_scan_append':
      'Menambahkan pindaian',
  'pt.op_compress':
      'Mengompresi',
  'pt.op_set_password':
      'Mengatur kata sandi',
  'pt.op_remove_password':
      'Menghapus kata sandi',
  'pt.cannot_delete_all':
      'Anda tidak dapat menghapus semua halaman',
  'pt.annot_title':
      'Sorotan akan hilang',
  'pt.continue':
      'Lanjutkan',
  'pt.extracting':
      'Mengekstrak halaman…',
  'pt.extracted':
      'Halaman yang dipilih diekstrak sebagai PDF terpisah',
  'pt.extract_failed':
      'Ekstraksi gagal: {error}',
  'pt.merged':
      '{n} PDF ditambahkan',
  'pt.compress_title':
      'Kompres dokumen',
  'pt.compress':
      'Kompres',
  'pt.size_change':
      'Ukuran {before} → {after}',
  'pt.already_compact':
      'Dokumen ini sudah ringkas ({size}) — tidak ada yang bisa dihemat',
  'pt.set_password':
      'Atur kata sandi',
  'pt.new_password':
      'Kata sandi baru',
  'pt.remove_password':
      'Hapus kata sandi',
  'pt.unsaved_title':
      'Perubahan belum disimpan',
  'pt.unsaved_body':
      'Jika Anda keluar, suntingan Anda akan hilang.',
  'pt.stay':
      'Tetap di sini',
  'pt.leave':
      'Keluar',
  'pt.scan_append':
      'Pindai dan tambahkan halaman',
  'pt.merge_other':
      'Tambah PDF lain (gabungkan)',
  'pt.compress_menu':
      'Kompres (perkecil ukuran)',
  'pt.open_failed':
      'Tidak dapat dibuka: {error}',
  'pt.extract':
      'Ekstrak',
  'pt.forward':
      'Maju',
  'pt.backward':
      'Mundur',
  // ── PDF pro araçları pp (m.3) ──
  'pp.menu':
      'Alat Pro…',
  'pp.title':
      'Alat pro PDF',
  'pp.dsign':
      'Tanda tangan digital (sertifikat)',
  'pp.dsign_source':
      'Sertifikat',
  'pp.dsign_self':
      'Identitas aplikasi (ditandatangani sendiri)',
  'pp.dsign_pfx':
      'Berkas sertifikat (.pfx/.p12)',
  'pp.dsign_name':
      'Nama penandatangan',
  'pp.dsign_reason':
      'Alasan (opsional)',
  'pp.dsign_location':
      'Lokasi (opsional)',
  'pp.dsign_visible':
      'Kotak tanda tangan terlihat',
  'pp.dsign_last_page':
      'Tempatkan di halaman terakhir',
  'pp.dsign_go':
      'Tandatangani',
  'pp.dsign_working':
      'Tanda tangan digital',
  'pp.dsign_creating':
      'Membuat kunci tanda tangan',
  'pp.dsign_pfx_password':
      'Kata sandi sertifikat',
  'pp.dsign_done':
      'Sudah ditandatangani. Jangan ubah apa pun sebelum menyimpan — itu akan membatalkan tanda tangan.',
  'pp.dsign_list':
      'Tanda tangan',
  'pp.dsign_none':
      'Dokumen tidak memiliki tanda tangan',
  'pp.dsign_empty_field':
      'Kolom tanda tangan kosong',
  'pp.dsign_export_cert':
      'Bagikan sertifikat saya (.cer)',
  'pp.dsign_name_needed':
      'Nama penandatangan wajib diisi',
  'pp.region_title':
      'Pilih area',
  'pp.region_status':
      'Halaman {page}/{count} · {n} kotak',
  'pp.prev_page':
      'Halaman sebelumnya',
  'pp.next_page':
      'Halaman berikutnya',
  'pp.redact':
      'Penyensoran permanen',
  'pp.redact_terms_hint':
      'Istilah yang dicari (pisahkan dengan koma) — kosong: tandai manual',
  'pp.redact_find':
      'Cari',
  'pp.redact_searching':
      'Mencari',
  'pp.redact_no_match':
      'Tidak ada yang cocok — Anda bisa menandai manual',
  'pp.redact_confirm':
      '{n} area di {pages} halaman akan dihapus permanen. Halaman ini menjadi gambar (teks di luar kotak tetap bisa dicari); anotasi, formulir, dan kata sandi dihapus. Urungkan hanya berlaku sebelum menyimpan.',
  'pp.redact_apply':
      'Sensor',
  'pp.redact_done':
      'Disensor dan diverifikasi: tidak ada teks tersisa di dalam kotak.',
  'pp.saved_as':
      'Disimpan: {name}',
  'pp.sheet_prefix':
      'Halaman',
  'pp.to_xlsx':
      'Ekspor tabel ke Excel',
  'pp.to_docx':
      'Ekspor ke Word (pertahankan tata letak)',
  'pp.pdfa':
      'Simpan sebagai PDF/A',
  'pp.pdfa_image_sub':
      'Setiap halaman menjadi gambar + teks yang bisa dicari (PDF/A-2b); ukuran berkas bisa membesar, tautan dan formulir tidak dipertahankan.',
  'pp.too_many_pages':
      'Paling banyak {n} halaman — pilih halaman atau pecah dulu',
  'pp.compare':
      'Bandingkan dua PDF',
  'pp.compare_text':
      'Teks',
  'pp.compare_visual':
      'Visual',
  'pp.compare_names':
      '{a} → {b}',
  'pp.compare_summary':
      '{pages} halaman berubah · +{added} / −{removed} kata',
  'pp.compare_only_changed':
      'Hanya perubahan',
  'pp.compare_same':
      'Tidak ada perbedaan teks',
  'pp.compare_page':
      'Halaman {n}',
  'pp.compare_visual_page':
      'Halaman {n} · {pct}% berbeda',
  'pp.compare_progress':
      '{done}/{total} halaman dibandingkan',
  'pp.compare_visual_note':
      'Perbandingan visual mencakup paling banyak {n} halaman',
  'pp.permissions':
      'Izin dan kata sandi',
  'pp.owner_password':
      'Kata sandi pemilik (mengubah izin)',
  'pp.user_password':
      'Kata sandi buka (opsional)',
  'pp.user_password_hint':
      'Kosongkan untuk membuka tanpa kata sandi',
  'pp.owner_needed':
      'Kata sandi pemilik wajib diisi',
  'pp.permissions_done':
      'Izin diterapkan',
  'pp.outline':
      'Markah (daftar isi)',
  'pp.outline_add':
      'Tambah markah',
  'pp.outline_title':
      'Judul',
  'pp.outline_page':
      'Halaman (1–{count})',
  'pp.outline_empty':
      'Belum ada markah — tambahkan dengan +',
  'pp.outline_indent':
      'Menjorok',
  'pp.outline_outdent':
      'Kurangi menjorok',
  'pp.stamp':
      'Templat stempel / watermark',
  'pp.stamp_text':
      'Teks stempel',
  'pp.stamp_as_watermark':
      'Sebagai watermark (diagonal, samar)',
  'pp.stamp_date':
      'Tambah tanggal ({date})',
  'pp.stamp_apply':
      'Terapkan',
  'pp.selected_pages_only':
      'Hanya halaman terpilih',
  'pp.place':
      'Posisi',
  'pp.numbering':
      'Penomoran lanjutan',
  'pp.number_style':
      'Gaya',
  'pp.number_start':
      'Nomor awal',
  'pp.number_prefix':
      'Awalan',
  'pp.number_digits':
      'Digit',
  'pp.page_word':
      'Halaman',
  'pp.preview':
      'Pratinjau: {text}',
  'pp.notes_empty':
      'Dokumen tidak memiliki sorotan atau catatan',
  'pp.notes_count':
      '{n} markah',
  'pp.find_results':
      '{n} hasil',
  'pp.find_ocr_hit':
      'Cocok di halaman hasil pindai (OCR)',
  'pp.compress_hard':
      'Kompresi agresif',
  'pp.compress_hard_warn':
      'Halaman diubah menjadi gambar: ketajaman vektor, tautan, formulir, dan anotasi hilang. Teks dapat tetap bisa dicari di lapisan tak terlihat.',
  'pp.resolution':
      'Resolusi',
  'pp.quality':
      'Kualitas',
  'pp.quality_low':
      'Rendah',
  'pp.quality_mid':
      'Sedang',
  'pp.quality_high':
      'Tinggi',
  'pp.grayscale':
      'Skala abu-abu',
  'pp.keep_text':
      'Pertahankan teks (bisa dicari)',
  'pp.keep_text_sub':
      'Lapisan teks tak terlihat ditulis',
  'pp.compress_hard_bigger':
      'Tidak lebih kecil ({size}) — gunakan Urungkan untuk kembali',
  'pp.studio':
      'Studio halaman',
  'pp.studio_insert':
      'Sisipkan halaman',
  'pp.studio_extract':
      'Ekstrak yang dipilih ke PDF baru',
  'pp.studio_split':
      'Pecah di halaman terpilih',
  'pp.studio_split_hint':
      'Untuk memecah, pilih setidaknya satu halaman selain halaman pertama',
  'pp.studio_need_page':
      'Pilihan harus berisi setidaknya satu halaman tidak kosong',
  'pp.studio_file_failed':
      'Tidak dapat membuka PDF ini (mungkin terenkripsi atau rusak)',
  'pp.studio_hint':
      'Ketuk untuk memilih · tekan lama dan seret untuk memindahkan',
  'pp.studio_selected':
      '{n} dipilih',
  'pp.rotate_left':
      'Putar ke kiri',
  'pp.rotate_right':
      'Putar ke kanan',
  'pp.blank':
      'Cari dan hapus halaman kosong',
  'pp.blank_finding':
      'Mencari halaman kosong',
  'pp.blank_none':
      'Tidak ada halaman kosong',
  'pp.blank_all':
      'Semua halaman tampak kosong — tidak ada yang dihapus',
  'pp.blank_found':
      '{n} halaman kosong dipilih: {pages}. Hapus?',
  'pp.crop':
      'Pangkas halaman',
  'pp.fit_a4':
      'Sesuaikan ke A4',
  'pp.autofill':
      'Isi dari profil',
  'pp.autofill_none':
      'Tidak ada kolom kosong yang cocok dengan profil',
  'pp.autofill_done':
      '{n} kolom terisi — periksa dan simpan',
  'pp.profile':
      'Profil isi otomatis',
  'pp.profile_privacy':
      'Disimpan hanya di perangkat ini, tidak pernah dikirim ke mana pun.',
  'pp.form_create':
      'Tambah kolom formulir',
  'pp.field_text':
      'Kolom teks',
  'pp.ocr_layer':
      'Buat bisa dicari (OCR)',
  'pp.ocr_layer_none':
      'Tidak ditemukan halaman pindaian dengan teks yang dapat dikenali',
  'pp.ocr_layer_done':
      '{n} halaman kini bisa dicari',
  'pp.field_detect':
      'Temukan tempat pengisian',
  'pp.field_detect_sub':
      'Mengubah ruang kosong, titik-titik, dan kotak menjadi kolom',
  'pp.field_detect_none':
      'Tidak ada tempat pengisian ditemukan',
  'pp.images_to_pdf':
      'PDF dari gambar',
  'pp.images_a4_q':
      '{n} gambar. Jadikan setiap halaman A4? (Tidak: setiap halaman mengikuti gambarnya)',
  'pp.images_a4':
      'Gunakan A4',
  'pp.pdf_to_images':
      'PDF ke gambar (massal)',
  'pp.images_saved':
      '{n} gambar disimpan: {dir}',
  'pp.web_to_pdf':
      'PDF dari halaman web',
  'pp.web_url':
      'Alamat halaman',
  'pp.web_bad_url':
      'Masukkan alamat http(s) yang valid',
  'pp.office_to_pdf':
      'Word/Excel/PowerPoint → PDF',
  'pp.signatures':
      'Tanda tangan dan paraf',
  'pp.my_signature':
      'Tanda tangan saya',
  'pp.my_initials':
      'Paraf saya',
  'pp.none':
      'Tidak ada',
  'pp.initial_all':
      'Paraf setiap halaman',
  'pp.initial_with_date':
      'Tanggal di bawah paraf',
  'pp.initials_missing':
      'Gambar paraf Anda terlebih dahulu',
  'pp.date_stamp':
      'Stempel tanggal',
  'pp.sign_here':
      'Tempatkan tanda tangan di halaman',
  'pp.save_first':
      'Simpan perubahan Anda terlebih dahulu',
  'pp.image_zoom_failed':
      'Tidak dapat membuka gambar',
  'pp.meta':
      'Properti dokumen',
  'pp.meta_strip':
      'Hapus semua metadata',
  'pp.meta_strip_body':
      'Judul, penulis, aplikasi pembuat, tanggal modifikasi, dan detail yang tersisa di revisi lama dihapus. Halaman tetap sama; Anda bisa mengurungkan sebelum menyimpan.',
  'pp.meta_strip_ok':
      'Hapus',
  'pp.layers':
      'Lapisan',
  'pp.layers_none':
      'Dokumen ini tidak memiliki lapisan',
  'pp.layers_failed':
      'Tidak dapat membaca lapisan',
  'pp.layers_unnamed':
      'Lapisan {n}',
  'pp.meta_failed':
      'Tidak dapat membaca properti dokumen',
  'pp.xfdf_out':
      'Ekspor anotasi (XFDF)',
  'pp.xfdf_in':
      'Impor anotasi (XFDF)',
  // ── PDF yerinde düzenleme (pse, m.3) ──
  'pse.editing':
      'Mengedit',
  'pse.unsaved_n':
      'Belum disimpan · {n} perubahan',
  'pse.saved':
      'Tersimpan',
  'pse.undo_named':
      'Urungkan: {name}',
  'pse.redo_named':
      'Ulangi: {name}',
  'pse.step_detail':
      '{name}: “{detail}”',
  'pse.hint_tap':
      'Ketuk teks untuk mengetik; tekan lama untuk memindahkan atau menata gayanya.',
  'pse.hint_scanned':
      'Halaman ini adalah gambar hasil pindai tanpa teks yang dapat dipilih. Ketuk “Kotak teks” untuk menambah teks atau “Kenali teks (OCR)” untuk mendeteksinya.',
  'pse.open_elsewhere':
      'PDF ini sedang diedit di jendela lain — perubahan yang belum disimpan ada di sana.',
  'pse.edit_title':
      'Edit paragraf',
  'pse.edit_hint':
      'Teks paragraf',
  'pse.busy_wait':
      'Memproses halaman, harap tunggu beberapa detik…',
  'pse.save_how':
      'Bagaimana cara menyimpannya?',
  'pse.save_keep_original':
      'Simpan sebagai salinan (aslinya dipertahankan)',
  'pse.save_overwrite':
      'Timpa berkas asli',
  'pse.save_as':
      'Simpan sebagai',
  'pse.save_as_same':
      'Salinan di folder yang sama',
  'pse.saved_copy':
      'Salinan disimpan: {name}',
  'pse.finish':
      'Selesai mengedit',
  'pse.versions':
      'Riwayat versi',
  'pse.versions_empty':
      'Belum ada versi tersimpan. Setiap kali Anda menyimpan, versi sebelumnya disimpan di sini selama 14 hari.',
  'pse.versions_note':
      'Versi sebelumnya disimpan selama 14 hari.',
  'pse.version_restore':
      'Pulihkan versi ini',
  'pse.version_restore_q':
      'Pulihkan versi dari {when}? Keadaan saat ini juga ditambahkan ke riwayat.',
  'pse.version_restore_unsaved':
      'Perubahan yang belum disimpan akan dibuang.',
  'pse.version_restored':
      'Versi sebelumnya dipulihkan',
  'pse.recover_title':
      'Suntingan belum disimpan ditemukan',
  'pse.recover_body':
      'Dokumen ini memiliki {n} perubahan yang belum disimpan saat aplikasi ditutup.',
  'pse.recover_body_copy':
      'Dokumen ini memiliki perubahan yang belum disimpan saat aplikasi ditutup. Berkas telah berubah sejak itu, jadi keadaan yang diedit dapat dipulihkan sebagai salinan.',
  'pse.recover_restore':
      'Pulihkan suntingan yang belum disimpan',
  'pse.recover_copy':
      'Simpan salinan yang dipulihkan',
  'pse.recover_discard':
      'Buang',
  'pse.recover_done':
      '{n} perubahan dipulihkan (belum disimpan)',
  'pse.recover_partial':
      '{n} dari {total} perubahan dipulihkan',
  'pse.locked_title':
      'Dokumen ini dilindungi dari pengeditan',
  'pse.locked_open':
      'Buka dengan kata sandi pemilik',
  'pse.owner_title':
      'Kata sandi pemilik',
  'pse.owner_body':
      'Masukkan kata sandi yang mencabut pembatasan pengeditan.',
  'pse.al_center':
      'Tengah',
  'pse.al_justify':
      'Rata kiri-kanan',
  'pse.al_left':
      'Rata kiri',
  'pse.al_right':
      'Rata kanan',
  'pse.comment_edit':
      'Edit catatan',
  'pse.comment_page':
      'Halaman {n}',
  'pse.comment_reply':
      'Balas',
  'pse.comments':
      'Komentar',
  'pse.comments_all':
      'Semua',
  'pse.comments_none':
      'Tidak ada anotasi di dokumen ini.',
  'pse.comments_open':
      'Terbuka',
  'pse.comments_resolved':
      'Terselesaikan',
  'pse.context_bar':
      'Opsi alat',
  'pse.copied':
      'Disalin',
  'pse.copy':
      'Salin',
  'pse.cut':
      'Potong',
  'pse.delete_pull':
      'Hapus dan tarik ke atas yang di bawah',
  'pse.done':
      'Selesai',
  'pse.duplicate':
      'Gandakan',
  'pse.find_case':
      'Cocokkan huruf besar/kecil',
  'pse.find_count':
      '{n} kecocokan · menampilkan {i}',
  'pse.find_hint':
      'Mencari di seluruh dokumen; teksnya sendiri yang diubah.',
  'pse.find_next':
      'Berikutnya',
  'pse.find_none':
      'Tidak ada yang cocok.',
  'pse.find_replace_all':
      'Ganti semua',
  'pse.find_replace_one':
      'Ganti',
  'pse.find_replaced':
      '{n} kecocokan diganti.',
  'pse.find_replaced_partial':
      '{n} kecocokan diganti; {m} blok tidak dapat diubah.',
  'pse.find_title':
      'Cari dan ganti',
  'pse.find_what':
      'Cari',
  'pse.find_with':
      'Ganti dengan',
  'pse.find_word':
      'Kata utuh',
  'pse.flatten':
      'Ratakan anotasi',
  'pse.flatten_q':
      'Anotasi dan kolom formulir di halaman ini menjadi bagian dari halaman dan tidak dapat lagi diedit secara terpisah.',
  'pse.fmt_align':
      'Perataan',
  'pse.fmt_bold':
      'Tebal',
  'pse.fmt_color':
      'Warna',
  'pse.fmt_highlight':
      'Warna sorotan',
  'pse.fmt_italic':
      'Miring',
  'pse.fmt_larger':
      'Teks lebih besar',
  'pse.fmt_size':
      'Ukuran huruf',
  'pse.fmt_smaller':
      'Teks lebih kecil',
  'pse.fmt_strike':
      'Coret',
  'pse.fmt_underline':
      'Garis bawah',
  'pse.font_doc':
      'dokumen',
  'pse.font_fallback':
      'cadangan',
  'pse.overflow':
      'Teks menabrak teks di bawahnya.',
  'pse.overflow_shrink':
      'Perkecil',
  'pse.overflow_push':
      'Dorong ke bawah',
  'pse.overflow_widen':
      'Perlebar',
  'pse.link':
      'Tautan',
  'pse.link_web':
      'Tautkan ke alamat web',
  'pse.link_web_hint':
      'Alamat atau email',
  'pse.link_page':
      'Tautkan ke halaman di dokumen ini',
  'pse.link_page_hint':
      'Nomor halaman (1–{n})',
  'pse.link_to_page':
      'Sekarang menuju ke halaman {n}',
  'pse.link_remove':
      'Hapus tautan',
  'pse.link_bad':
      'Alamat atau halaman ini tidak dapat digunakan.',
  'pse.font_pick':
      'Huruf',
  'pse.image_exported':
      'Gambar disimpan ke Dokumen: {name}',
  'pse.img_add':
      'Tambah gambar',
  'pse.img_from_files':
      'Dari galeri atau berkas',
  'pse.img_from_camera':
      'Ambil dengan kamera',
  'pse.obj_lasso':
      'Pilih dengan lasso',
  'pse.img_back':
      'Kirim ke belakang',
  'pse.img_crop':
      'Pangkas',
  'pse.img_export':
      'Ekspor',
  'pse.img_front':
      'Bawa ke depan',
  'pse.img_replace':
      'Ganti',
  'pse.img_rotate':
      'Putar',
  'pse.list_bullets':
      'Daftar berpoin',
  'pse.list_numbers':
      'Daftar bernomor',
  'pse.locked_box':
      'Tambahkan kotak teks di atasnya',
  'pse.locked_line':
      'Beralih ke mode garis',
  'pse.locked_replace':
      'Ganti tulisan',
  'pse.locked_ai':
      'Baca dengan AI dan ganti',
  'pse.ocr_ai_reading':
      'AI sedang membaca tulisan…',
  'pse.locked_why':
      'Mengapa ini tidak dapat diedit?',
  'pse.mk_stamp':
      'Stempel',
  'pse.mk_freetext':
      'Teks bebas',
  'pse.stamp_approved':
      'DISETUJUI',
  'pse.stamp_rejected':
      'DITOLAK',
  'pse.stamp_confidential':
      'RAHASIA',
  'pse.stamp_custom':
      'Stempel kustom…',
  'pse.mk_note':
      'Catatan',
  'pse.page_rotate':
      'Putar halaman ini',
  'pse.page_studio':
      'Studio halaman',
  'pse.page_studio_hint':
      'Susun ulang, sisipkan, hapus, pecah, gabung',
  'pse.paste':
      'Tempel',
  'pse.select_all':
      'Pilih semua',
  'pse.style_copy':
      'Salin gaya',
  'pse.style_paste':
      'Tempel gaya',
  'pse.tool_all':
      'Semua alat PDF',
  'pse.tool_all_hint':
      'Penyensoran, kata sandi, kompres, konversi…',
  'pse.tool_form':
      'Formulir',
  'pse.tool_pages':
      'Halaman',
  'pse.tool_sign':
      'Tanda tangan',
  'pse.kvkk_apply':
      'Sensor {n} item',
  'pse.kvkk_custom_hint':
      'Kata tambahan (pisahkan dengan koma)',
  'pse.kvkk_done':
      '{n} item disensor. Dokumen ditulis ulang saat Anda menyimpan.',
  'pse.kvkk_none':
      'Tidak ditemukan pola data pribadi.',
  'pse.kvkk_title':
      'Temukan data pribadi',
  'pse.mk_redact':
      'Sensor',
  'pse.redact_q':
      'Teks yang disensor dihapus permanen dari dokumen; setelah disimpan tidak dapat dipulihkan dan versi lama juga dihapus.',
  'pse.ocr_run':
      'Kenali teks (OCR)',
  'pse.tool_legacy':
      'Editor klasik',
  'pse.tool_legacy_hint':
      'Watermark, perbaikan garis hasil pindai',
  'pse.edit_text':
      'Edit teks',
  'pse.style':
      'Gaya',
  'pse.add_text':
      'Tambah teks',
  'pse.textbox_guide':
      'Ketuk di tempat Anda ingin menambah teks',
  'pse.lasso_guide':
      'Gambar lingkaran di sekitar item yang akan dipilih',
  'pse.draw_guide':
      '{tool} aktif · Cubit dengan 2 jari untuk memperbesar',
  'pse.stroke_title':
      'Warna & ketebalan',
  'pse.stroke_width':
      'Ketebalan garis',
  'pse.align_group':
      'Ratakan & distribusikan',
  'pse.order':
      'Urutan',
  'pse.block_more':
      'Aksi blok',
  'pse.style_sheet_title':
      'Pemformatan teks',
  'pse.font_size_pt':
      '{n} pt',
  'pse.obj_guide':
      'Gambar & bentuk yang dapat dipilih disorot · ketuk untuk mengedit',
  'pse.obj_count':
      '{n} item dapat dipilih',
  'pse.obj_none_hint':
      'Tidak ada gambar yang dapat dipilih di halaman ini · tambahkan gambar baru di bawah',
  'pse.obj_badge_image':
      'Gambar',
  'pse.obj_badge_shape':
      'Bentuk',
  'pse.resize':
      'Ubah ukuran',
  'pse.resize_title':
      'Ukuran & skala gambar',
  'pse.scale_pct':
      'Skala: {n}%',
  'pse.size_small':
      'Kecil',
  'pse.size_fit':
      'Pas halaman',
  'pse.size_large':
      'Besar',
  'pse.apply_size':
      'Terapkan ukuran',
  'pse.text_guide_rich':
      'Ketuk kotak teks mana pun untuk mengedit · seret gagang untuk memindahkan atau melebarkan',
  'excel.act_saved':
      'Diedit',
  'excel.add_sheet':
      'Tambah lembar',
  'excel.alignment':
      'Perataan',
  'excel.autosum':
      'Jumlah otomatis',
  'excel.autosum_empty':
      'Tidak ada angka di sebelahnya untuk dijumlahkan — ketik rentangnya sendiri.',
  'excel.border_all':
      'Semua garis tepi',
  'excel.border_bottom':
      'Garis tepi bawah',
  'excel.border_none':
      'Tanpa garis tepi',
  'excel.border_outline':
      'Garis luar',
  'excel.border_top':
      'Garis tepi atas',
  'excel.borders':
      'Garis tepi',
  'excel.cell_content':
      'Isi sel',
  'excel.cell_label':
      'Sel {ref}',
  'excel.cell_menu':
      'Menu sel',
  'excel.cell_reference':
      'Referensi sel',
  'excel.cell_reference_hint':
      'mis. C15',
  'excel.cell_styles':
      'Gaya sel',
  'excel.clear_contents':
      'Hapus isi',
  'excel.clear_formats':
      'Hapus format',
  'excel.clipboard_empty':
      'Papan klip kosong.',
  'excel.col_left_short':
      'Kol +←',
  'excel.col_right_short':
      'Kol +→',
  'excel.color_auto':
      'Otomatis',
  'excel.color_none':
      'Tanpa warna',
  'excel.column':
      'Kolom',
  'excel.column_n':
      'Kolom {c}',
  'excel.column_width':
      'Lebar kolom…',
  'excel.column_width_of':
      'Lebar kolom {col}',
  'excel.cond_contains':
      'Teks berisi',
  'excel.cond_equal':
      'Sama dengan',
  'excel.cond_format':
      'Pemformatan bersyarat',
  'excel.cond_greater':
      'Lebih besar dari',
  'excel.cond_less':
      'Lebih kecil dari',
  'excel.cond_text':
      'Teks',
  'excel.cond_value':
      'Nilai',
  'excel.copied_stat':
      'Disalin: {v}',
  'excel.copy_done':
      '{n} sel disalin',
  'excel.csv_encoding':
      'Pengodean CSV',
  'excel.csv_failed':
      'Ekspor CSV gagal: {error}',
  'excel.csv_format_lost':
      'Format tidak disimpan di CSV — hanya nilai yang disimpan',
  'excel.csv_formula_guard':
      'Perlindungan rumus',
  'excel.csv_formula_guard_sub':
      'Teks yang diawali = + - @ diberi tanda \' di depan agar tidak berjalan sebagai perintah',
  'excel.csv_legacy':
      'Excel Turki lama / Notepad',
  'excel.csv_save_xlsx':
      'Simpan sebagai XLSX',
  'excel.csv_utf8':
      'UTF-8 (disarankan)',
  'excel.csv_utf8_sub':
      'Excel modern / Google Sheets',
  'excel.custom_sort':
      'Urutan kustom',
  'excel.cut':
      'Potong',
  'excel.cut_done':
      '{n} sel dipotong',
  'excel.decimal_less':
      'Kurangi desimal',
  'excel.decimal_more':
      'Tambah desimal',
  'excel.default_value':
      'Bawaan ({value})',
  'excel.delete_col':
      'Hapus kolom',
  'excel.delete_row':
      'Hapus baris',
  'excel.delete_sheet':
      'Hapus lembar',
  'excel.delete_sheet_confirm':
      'Hapus lembar “{name}” beserta seluruh isinya?',
  'excel.dup_done':
      '{n} baris duplikat dihapus; tersisa {m} baris unik',
  'excel.dup_has_header':
      'Data saya punya judul kolom',
  'excel.dup_needs_range':
      'Pilih rentang beberapa baris',
  'excel.dup_none':
      'Tidak ada baris duplikat',
  'excel.dup_run':
      'Hapus duplikat',
  'excel.dup_title':
      'Hapus duplikat',
  'excel.duplicate_sheet':
      'Gandakan',
  'excel.fc_bottom':
      'Bawah',
  'excel.fc_category':
      'Kategori',
  'excel.fc_code':
      'Kode format',
  'excel.fc_control':
      'Kontrol teks',
  'excel.fc_decimals':
      'Tempat desimal',
  'excel.fc_general':
      'Umum',
  'excel.fc_horizontal':
      'Horizontal',
  'excel.fc_indent':
      'Indentasi',
  'excel.fc_line':
      'Garis',
  'excel.fc_line_color':
      'Warna garis',
  'excel.fc_middle':
      'Tengah',
  'excel.fc_negative':
      'Angka negatif',
  'excel.fc_presets':
      'Preset',
  'excel.fc_rotation':
      'Orientasi',
  'excel.fc_sample':
      'Contoh',
  'excel.fc_style':
      'Gaya huruf',
  'excel.fc_symbol':
      'Simbol',
  'excel.fc_symbol_pos':
      'Posisi simbol',
  'excel.fc_tab_fill':
      'Isian',
  'excel.fc_tab_font':
      'Huruf',
  'excel.fc_tab_number':
      'Angka',
  'excel.fc_thousands':
      'Pemisah ribuan',
  'excel.fc_top':
      'Atas',
  'excel.fc_type':
      'Jenis',
  'excel.fc_vertical':
      'Vertikal',
  'excel.fill_color':
      'Warna isian',
  'excel.fill_down':
      'Isi ke bawah',
  'excel.fill_no_neighbour':
      'Kolom di sebelahnya kosong — tidak ada yang bisa diisi ke bawah',
  'excel.fill_right':
      'Isi ke kanan',
  'excel.fill_sort_group':
      'Isi & urutkan',
  'excel.filter':
      'Filter',
  'excel.filter_all':
      'Pilih semua',
  'excel.filter_blank':
      '(Kosong)',
  'excel.filter_bottom10':
      '10 terbawah',
  'excel.filter_by_color':
      'Menurut warna',
  'excel.filter_clear':
      'Hapus filter',
  'excel.filter_column':
      'Filter kolom {col}',
  'excel.filter_contains':
      'Berisi…',
  'excel.filter_create':
      'Buat filter',
  'excel.filter_created':
      'Filter dibuat — gunakan panah pada judul',
  'excel.filter_needs_table':
      'Tidak ada filter pada kolom ini. Penyaringan berlaku pada rentang tabel yang ditentukan di berkas.',
  'excel.filter_remove':
      'Hapus filter',
  'excel.filter_removed':
      'Filter dihapus',
  'excel.filter_top10':
      '10 teratas',
  'excel.find_in_sheet':
      'Cari di lembar ini',
  'excel.flash_done':
      '{n} sel terisi',
  'excel.flash_fill':
      'Isi kilat',
  'excel.flash_need_data':
      'Pilih sel di samping kolom berisi data',
  'excel.flash_need_example':
      'Ketik contoh di kolom ini terlebih dahulu',
  'excel.flash_none':
      'Pola tidak ditemukan — ketik satu contoh lagi lalu coba lagi',
  'excel.fmt_currency':
      'Mata uang (₺)',
  'excel.fmt_date':
      'Tanggal',
  'excel.fmt_general':
      'Umum',
  'excel.fmt_number':
      'Angka (1,234.50)',
  'excel.fmt_percent':
      'Persen (15%)',
  'excel.fmt_text':
      'Teks',
  'excel.fmt_thousands':
      'Ribuan (1,234)',
  'excel.fmt_time':
      'Waktu',
  'excel.fn_average':
      'Rata-rata',
  'excel.fn_count':
      'Jumlah data',
  'excel.fn_max':
      'Maks',
  'excel.fn_min':
      'Min',
  'excel.fn_sum_short':
      'Jumlah',
  'excel.font_color':
      'Warna huruf',
  'excel.font_default':
      'Huruf',
  'excel.form_new':
      'Catatan baru',
  'excel.form_next':
      'Catatan berikutnya',
  'excel.form_prev':
      'Catatan sebelumnya',
  'excel.form_record':
      'Catatan {n} dari {total}',
  'excel.form_view':
      'Tampilan formulir',
  'excel.format_as_table':
      'Format sebagai tabel',
  'excel.format_cells':
      'Format sel',
  'excel.formula_english':
      'Excel: tampilkan rumus dalam bahasa Inggris',
  'excel.formula_english_sub':
      'SUM, IF … dan pemisah koma meskipun antarmuka berbahasa Turki',
  'excel.freeze_cell':
      'Bekukan bagian atas dan kiri pilihan',
  'excel.freeze_col':
      'Bekukan kolom pertama',
  'excel.freeze_menu':
      'Bekukan panel',
  'excel.freeze_off_view':
      'Matikan panel beku di layar ini',
  'excel.freeze_on_view':
      'Aktifkan panel beku di layar ini',
  'excel.freeze_row':
      'Bekukan baris teratas',
  'excel.fx_library':
      'Pustaka fungsi',
  'excel.go':
      'Pergi',
  'excel.goto_cell':
      'Ke sel',
  'excel.goto_cell_menu':
      'Ke sel…',
  'excel.goto_last_cell':
      'Sel terakhir yang dipakai',
  'excel.goto_last_row':
      'Baris terakhir yang dipakai',
  'excel.goto_quick':
      'Lokasi cepat',
  'excel.goto_start':
      'Awal (A1)',
  'excel.grid_label':
      'Kisi sel — tekan lama dan seret untuk memilih rentang',
  'excel.gridlines':
      'Garis kisi',
  'excel.group_clipboard':
      'Papan klip',
  'excel.group_format':
      'Format',
  'excel.group_number':
      'Angka',
  'excel.hidden':
      'Tersembunyi',
  'excel.hide_col':
      'Sembunyikan kolom',
  'excel.hide_row':
      'Sembunyikan baris',
  'excel.hide_sheet':
      'Sembunyikan lembar',
  'excel.hide_show':
      'Sembunyikan / tampilkan',
  'excel.input_kept_text':
      'Disimpan sebagai teks (tidak diubah menjadi tanggal)',
  'excel.insert_col':
      'Sisipkan kolom',
  'excel.insert_col_left':
      'Sisipkan kolom di kiri',
  'excel.insert_col_right':
      'Sisipkan kolom di kanan',
  'excel.insert_row':
      'Sisipkan baris',
  'excel.insert_row_above':
      'Sisipkan baris di atas',
  'excel.insert_row_below':
      'Sisipkan baris di bawah',
  'excel.key_enter':
      'Enter dan turun',
  'excel.key_tab':
      'Sel berikutnya (kanan)',
  'excel.keyboard_123':
      'Tombol angka',
  'excel.keyboard_abc':
      'Papan ketik huruf',
  'excel.last_sheet':
      'Lembar terakhir tidak dapat dihapus',
  'excel.last_visible_sheet':
      'Lembar terakhir yang terlihat tidak dapat disembunyikan',
  'excel.merge':
      'Gabungkan sel',
  'excel.merge_center':
      'Gabung & tengahkan',
  'excel.merge_needs_range':
      'Pilih minimal dua sel untuk digabungkan',
  'excel.move_sheet_left':
      'Pindah ke kiri',
  'excel.move_sheet_right':
      'Pindah ke kanan',
  'excel.no_sheet':
      'Tidak ada lembar.',
  'excel.note_author':
      'Pembaca Berkas',
  'excel.note_delete':
      'Hapus catatan',
  'excel.note_edit':
      'Ubah catatan',
  'excel.note_hint':
      'Catatan (eksperimental — periksa di Excel desktop)',
  'excel.note_new':
      'Catatan baru',
  'excel.nothing_hidden':
      'Tidak ada yang tersembunyi di samping pilihan',
  'excel.nothing_to_paste':
      'Salin rentang terlebih dahulu',
  'excel.number_format':
      'Format angka',
  'excel.opening_preview':
      'Sedang dibuka — pengeditan segera siap; menampilkan baris pertama',
  'excel.panes_trimmed':
      'Panel beku di berkas tidak muat di layar, sehingga kolom tersebut dibuat bisa digulir. Anda dapat mematikannya sepenuhnya lewat ⋮ > Lepas panel beku.',
  'excel.paste':
      'Tempel',
  'excel.paste_formats':
      'Tempel format saja',
  'excel.paste_formulas':
      'Tempel rumus saja',
  'excel.paste_special_group':
      'Tempel khusus',
  'excel.paste_transpose':
      'Tempel transposisi',
  'excel.paste_values':
      'Tempel nilai saja',
  'excel.pick_from_list':
      'Pilih dari daftar',
  'excel.quick_actions':
      'Tindakan cepat',
  'excel.redo':
      'Ulangi',
  'excel.redone':
      'Diulangi: {what}',
  'excel.rename_sheet':
      'Ganti nama lembar',
  'excel.replace':
      'Ganti',
  'excel.replace_all':
      'Ganti semua',
  'excel.replace_none':
      'Tidak ada yang cocok untuk diganti.',
  'excel.replace_with':
      'Ganti dengan',
  'excel.replaced_count':
      '{n} sel diganti',
  'excel.ribbon_hide':
      'Sembunyikan pita',
  'excel.ribbon_show':
      'Tampilkan pita',
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
      'Baris & kolom',
  'excel.save_csv':
      'Ekspor sebagai CSV',
  'excel.saved_as_xlsx':
      'Disimpan sebagai {name} (berkas .xls asli Anda tidak diubah)',
  'excel.selection_cells':
      'Dipilih: {n} sel',
  'excel.selection_filled':
      'Dipilih: {n} sel  ·  Terisi: {filled}',
  'excel.sheet_name':
      'Lembar{n}',
  'excel.sheet_name_label':
      'Nama lembar',
  'excel.sheet_name_taken':
      'Nama itu sudah dipakai',
  'excel.sheet_pos':
      'Lembar {n} / {total}',
  'excel.sheet_rtl':
      'Lembar kanan-ke-kiri',
  'excel.sheet_rtl_off':
      'Lembar akan ditata kiri-ke-kanan (kolom A di kiri).',
  'excel.sheet_rtl_on':
      'Lembar akan ditata kanan-ke-kiri (kolom A di kanan).',
  'excel.show_cols':
      'Tampilkan kolom',
  'excel.show_rows':
      'Tampilkan baris',
  'excel.sort':
      'Urutkan',
  'excel.sort_add_level':
      'Tambah tingkat',
  'excel.sort_asc':
      'Urutkan A → Z',
  'excel.sort_asc_short':
      'A→Z',
  'excel.sort_by':
      'Urutkan menurut',
  'excel.sort_desc':
      'Urutkan Z → A',
  'excel.sort_desc_short':
      'Z→A',
  'excel.sort_has_header':
      'Data saya punya judul kolom',
  'excel.sort_needs_range':
      'Untuk mengurutkan, pilih dulu baris (tekan dan seret) atau tambahkan filter pada tabel.',
  'excel.sort_then_by':
      'Kemudian menurut',
  'excel.split_comma':
      'Koma',
  'excel.split_custom':
      'Pemisah lain',
  'excel.split_done':
      'Dipecah menjadi {n} kolom',
  'excel.split_merge':
      'Anggap pemisah berurutan sebagai satu',
  'excel.split_none':
      'Tidak ada yang dipecah',
  'excel.split_run':
      'Pecah',
  'excel.split_semi':
      'Titik koma',
  'excel.split_space':
      'Spasi',
  'excel.split_tab':
      'Tab',
  'excel.split_title':
      'Teks ke kolom',
  'excel.start_formula':
      'Mulai rumus',
  'excel.stat_avg_short':
      'Rata-rata: {v}',
  'excel.stat_count_short':
      'Jumlah data: {v}',
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
      'Rumus',
  'excel.tab_home':
      'Beranda',
  'excel.tab_insert':
      'Sisipkan',
  'excel.tab_view':
      'Tampilan',
  'excel.table_needs_range':
      'Pilih tabel termasuk baris judulnya terlebih dahulu',
  'excel.truncated':
      'Buku kerja ini terlalu besar: hanya {rows} baris dan {cols} kolom pertama yang dibuka. Penyimpanan dimatikan agar sisanya tidak hilang — Anda dapat membacanya atau mengekspor CSV.',
  'excel.truncated_no_save':
      'Penyimpanan dimatikan: buku kerja terpotong pada batas baca; menyimpan akan menghapus sisanya.',
  'excel.undo':
      'Urungkan',
  'excel.undo_autosum':
      'Jumlah otomatis',
  'excel.undo_border':
      'garis tepi',
  'excel.undo_cell_style':
      'Gaya sel',
  'excel.undo_clear':
      'hapus',
  'excel.undo_cond_format':
      'pemformatan bersyarat',
  'excel.undo_dedup':
      'Hapus duplikat',
  'excel.undo_delete_col':
      'hapus kolom',
  'excel.undo_delete_row':
      'hapus baris',
  'excel.undo_duplicate_sheet':
      'Gandakan lembar',
  'excel.undo_fill':
      'isi',
  'excel.undo_fill_color':
      'warna isian',
  'excel.undo_filter':
      'filter',
  'excel.undo_filter_off':
      'Hapus filter',
  'excel.undo_filter_on':
      'Buat filter',
  'excel.undo_font':
      'huruf',
  'excel.undo_font_color':
      'warna huruf',
  'excel.undo_form':
      'Formulir',
  'excel.undo_format':
      'pemformatan',
  'excel.undo_freeze':
      'Bekukan panel',
  'excel.undo_gridlines':
      'Garis kisi',
  'excel.undo_hide':
      'Sembunyikan',
  'excel.undo_hide_sheet':
      'Sembunyikan lembar',
  'excel.undo_insert_col':
      'sisipkan kolom',
  'excel.undo_insert_row':
      'sisipkan baris',
  'excel.undo_merge':
      'gabungkan sel',
  'excel.undo_note':
      'Catatan',
  'excel.undo_number_format':
      'format angka',
  'excel.undo_paste':
      'tempel',
  'excel.undo_replace':
      'ganti',
  'excel.undo_sort':
      'urutkan',
  'excel.undo_split':
      'Teks ke kolom',
  'excel.undo_tab_color':
      'Warna tab',
  'excel.undo_table_format':
      'Format tabel',
  'excel.undo_typing':
      'mengetik',
  'excel.undo_unhide':
      'Tampilkan',
  'excel.undo_unhide_sheet':
      'Tampilkan lembar',
  'excel.undo_unmerge':
      'pisahkan sel',
  'excel.undo_validation':
      'Validasi data',
  'excel.undo_wrap':
      'bungkus teks',
  'excel.undone':
      'Diurungkan: {what}',
  'excel.unfreeze_panes':
      'Lepas panel beku (baris/kolom tetap)',
  'excel.unhide_sheet':
      'Tampilkan lembar',
  'excel.unit_chars':
      'karakter',
  'excel.unit_points':
      'poin',
  'excel.unmerge':
      'Pisahkan sel',
  'excel.val_bad_bound':
      'Masukkan nilai batas yang valid',
  'excel.val_clear':
      'Hapus aturan',
  'excel.val_continue':
      'Tetap masukkan?',
  'excel.val_date_hint':
      'Tanggal (dd.mm.yyyy)',
  'excel.val_error':
      'Pesan kesalahan (opsional)',
  'excel.val_formula_hint':
      'Rumus (mis. =ISTEXT(A1))',
  'excel.val_invalid':
      'Nilai ini tidak sesuai dengan aturan yang ditetapkan untuk sel ini',
  'excel.val_invalid_title':
      'Entri tidak valid',
  'excel.val_list_empty':
      'Masukkan minimal satu opsi',
  'excel.val_list_hint':
      'Opsi (dipisahkan koma)',
  'excel.val_list_none':
      'Sumber daftar tidak memiliki nilai',
  'excel.val_list_source':
      'Atau rentang: =Daftar!A1:A9',
  'excel.val_max':
      'Maksimum',
  'excel.val_min':
      'Minimum',
  'excel.val_prompt':
      'Pesan masukan (opsional)',
  'excel.val_prompt_title':
      'Judul pesan masukan (opsional)',
  'excel.val_value':
      'Nilai',
  'excel.validation':
      'Validasi data',
  'excel.wrap_text':
      'Bungkus teks',
  'excel.zoom_in':
      'Perbesar',
  'excel.zoom_out':
      'Perkecil',
  'excel.zoom_reset':
      'Setel ulang zum (100%)',
  'word.add_paragraph':
      'Tambah paragraf',
  'word.add_paragraph_below':
      'Tambah paragraf di bawah',
  'word.align_cycle':
      'Perataan',
  'word.auto_color':
      'Otomatis',
  'word.autoformat':
      'Word: Format otomatis saat mengetik',
  'word.autoformat_sub':
      'Huruf kapital awal kalimat, -- → —, spasi ganda jadi satu, "- " atau "1. " memulai daftar',
  'word.bullet_list':
      'Daftar berpoin',
  'word.bullets':
      'Poin',
  'word.clear_format':
      'Hapus format',
  'word.color_pick':
      'Warna teks',
  'word.columns':
      'Kolom',
  'word.columns_n':
      '{n} kolom',
  'word.comment_author':
      'Nama Anda',
  'word.comment_author_hint':
      'Ditampilkan sebagai penulis komentar Anda',
  'word.comment_new':
      'Komentar baru',
  'word.comment_post':
      'Kirim',
  'word.comment_reopen':
      'Buka lagi',
  'word.comment_replies':
      '{n} balasan',
  'word.comment_reply':
      'Balas',
  'word.comment_resolve':
      'Selesaikan',
  'word.comment_text':
      'Komentar Anda',
  'word.comments':
      'Komentar',
  'word.comments_none':
      'Tidak ada komentar di dokumen',
  'word.control_fill':
      'Isi kolom isian',
  'word.control_no_items':
      'Daftar ini tidak punya opsi',
  'word.control_value':
      'Nilai',
  'word.count_chars':
      'Karakter (dengan spasi)',
  'word.count_chars_ns':
      'Karakter (tanpa spasi)',
  'word.count_paras':
      'Paragraf',
  'word.count_words':
      'Kata',
  'word.cut':
      'Potong',
  'word.delete_image':
      'Hapus gambar',
  'word.delete_paragraph':
      'Hapus paragraf',
  'word.done':
      'Selesai',
  'word.edit_link':
      'Ubah tautan',
  'word.edit_on_page':
      'Edit di halaman',
  'word.edit_page':
      'Edit di halaman (lama)',
  'word.endnote_edit':
      'Catatan akhir {n}',
  'word.find':
      'Cari dan ganti',
  'word.find_hint':
      'Cari di dokumen',
  'word.font_grow':
      'Perbesar ukuran huruf',
  'word.font_shrink':
      'Perkecil ukuran huruf',
  'word.font_size':
      'Ukuran',
  'word.footnote_edit':
      'Catatan kaki {n}',
  'word.footnote_rich':
      'Catatan kaki ini berisi konten kaya dan tidak dapat diedit di sini',
  'word.footnote_text':
      'Teks catatan kaki',
  'word.format_painter':
      'Kuas format',
  'word.format_painter_hint':
      'Format disalin — pilih teks untuk menerapkannya',
  'word.format_painter_locked':
      'Kuas format terkunci — ketuk ✕ untuk selesai',
  'word.goto_page':
      'Ke halaman',
  'word.goto_page_hint':
      'Antara 1 dan {total}',
  'word.hf_apply':
      'Terapkan',
  'word.hf_footer':
      'Footer',
  'word.hf_header':
      'Header',
  'word.hf_page':
      'Tambah nomor halaman',
  'word.hf_rich':
      'Header/footer ini berisi gambar atau tab sehingga tidak dapat diedit di sini.',
  'word.hf_saved':
      'Header/footer diperbarui',
  'word.highlight':
      'Sorot',
  'word.highlight_pick':
      'Warna sorotan',
  'word.img_alt':
      'Teks alternatif',
  'word.img_alt_hint':
      'Deskripsi singkat untuk orang yang tidak dapat melihat gambar',
  'word.img_failed':
      'Gambar tidak dapat dibaca',
  'word.img_large':
      'Lebar halaman (6 inci)',
  'word.img_medium':
      'Sedang (4 inci)',
  'word.img_replace':
      'Ganti',
  'word.img_resize_title':
      'Ukuran gambar',
  'word.img_size':
      'Ukuran',
  'word.img_small':
      'Kecil (2 inci)',
  'word.img_width_pct':
      'Lebar: {n}%',
  'word.insert_break':
      'Pemisah halaman',
  'word.insert_date':
      'Tanggal & waktu',
  'word.insert_endnote':
      'Catatan akhir',
  'word.insert_footnote':
      'Catatan kaki',
  'word.insert_hf':
      'Header & footer',
  'word.insert_image':
      'Sisipkan gambar',
  'word.insert_link':
      'Tautan',
  'word.insert_rule':
      'Garis horizontal',
  'word.insert_symbol':
      'Simbol',
  'word.insert_table':
      'Tabel',
  'word.landscape':
      'Lanskap',
  'word.line_spacing':
      'Spasi baris',
  'word.link_bad':
      'Tautan tidak dapat dibuka',
  'word.link_insert':
      'Sisipkan tautan',
  'word.link_open':
      'Buka',
  'word.link_remove':
      'Hapus',
  'word.link_text':
      'Teks yang ditampilkan',
  'word.link_url':
      'Alamat (https://…)',
  'word.list_gallery':
      'Gaya daftar',
  'word.live_edit_unsafe':
      'Pengeditan langsung tidak aman di dokumen ini (paragraf tidak cocok: {web}/{ours}). Gunakan ⋮ > Editor teks.',
  'word.margins':
      'Margin',
  'word.mobile_flow':
      'Tampilan ponsel',
  'word.mobile_view':
      'Tampilan ponsel',
  'word.month_names':
      'Januari,Februari,Maret,April,Mei,Juni,Juli,Agustus,September,Oktober,November,Desember',
  'word.multilevel':
      'Daftar bertingkat',
  'word.navigation':
      'Navigasi',
  'word.no_headings':
      'Tidak ada judul. Paragraf bergaya judul tercantum di sini.',
  'word.no_highlight':
      'Tanpa sorotan',
  'word.no_image_here':
      'Tidak ada gambar di paragraf pada kursor. Ketuk di samping gambar terlebih dahulu.',
  'word.numbered_list':
      'Daftar bernomor',
  'word.numbering':
      'Penomoran',
  'word.opening_preview':
      'Sedang dibuka — pengeditan segera siap; menampilkan paragraf pertama',
  'word.orientation':
      'Orientasi',
  'word.page_break':
      'Pemisah halaman',
  'word.page_layout':
      'Tampilan halaman',
  'word.page_of':
      'Halaman {n} / {total}',
  'word.page_view':
      'Tampilan halaman',
  'word.paper_size':
      'Ukuran',
  'word.paste':
      'Tempel',
  'word.portrait':
      'Potret',
  'word.recent_colors':
      'Warna terbaru',
  'word.recent_symbols':
      'Baru digunakan',
  'word.redo':
      'Ulangi',
  'word.redone':
      'Diulangi: {what}',
  'word.replace_hint':
      'Ganti dengan',
  'word.replace_n':
      '{n} diganti',
  'word.replace_needs_edit':
      'Beralih ke mode edit untuk mengganti',
  'word.review_page':
      'Tampilan halaman',
  'word.rtl':
      'Kanan-ke-kiri',
  'word.save_failed':
      'Gagal menyimpan: {error}',
  'word.saved_as_docx':
      'Disimpan sebagai {name} (berkas UDF asli Anda tidak diubah)',
  'word.search_short':
      'Cari',
  'word.select_text_first':
      'Pilih teks di dokumen terlebih dahulu',
  'word.space_after':
      'Spasi setelah paragraf',
  'word.space_before':
      'Spasi sebelum paragraf',
  'word.spellcheck':
      'Word: pemeriksa ejaan dan koreksi otomatis',
  'word.spellcheck_sub':
      'Garis bergelombang merah, saran papan ketik, huruf kapital awal kalimat',
  'word.st_h1':
      'Judul 1',
  'word.st_h2':
      'Judul 2',
  'word.st_h3':
      'Judul 3',
  'word.st_list':
      'Paragraf daftar',
  'word.st_normal':
      'Normal',
  'word.st_quote':
      'Kutipan',
  'word.st_subtitle':
      'Subjudul',
  'word.st_title':
      'Judul',
  'word.standard_colors':
      'Warna standar',
  'word.subscript':
      'Subskrip',
  'word.superscript':
      'Superskrip',
  'word.tab_home':
      'Beranda',
  'word.tab_insert':
      'Sisipkan',
  'word.tab_layout':
      'Tata letak',
  'word.tab_picture':
      'Gambar',
  'word.tab_review':
      'Tinjau',
  'word.tab_table':
      'Tabel',
  'word.tab_view':
      'Tampilan',
  'word.table_failed':
      'Tabel tidak dapat disisipkan di sini',
  'word.table_insert':
      'Sisipkan tabel',
  'word.table_size':
      'Tabel {r} × {c}',
  'word.tbl_banded':
      'Baris berselang-seling',
  'word.tbl_banded_short':
      'Selang-seling',
  'word.tbl_col_left':
      'Sisipkan kolom di kiri',
  'word.tbl_col_left_short':
      'Kol +←',
  'word.tbl_col_right':
      'Sisipkan kolom di kanan',
  'word.tbl_col_right_short':
      'Kol +→',
  'word.tbl_del':
      'Hapus tabel',
  'word.tbl_del_col':
      'Hapus kolom',
  'word.tbl_del_col_short':
      'Hps kol',
  'word.tbl_del_row':
      'Hapus baris',
  'word.tbl_del_row_short':
      'Hps baris',
  'word.tbl_del_short':
      'Hps tabel',
  'word.tbl_header':
      'Baris judul',
  'word.tbl_header_short':
      'Judul',
  'word.tbl_row_above':
      'Sisipkan baris di atas',
  'word.tbl_row_below':
      'Sisipkan baris di bawah',
  'word.tbl_row_down_short':
      'Baris +↓',
  'word.tbl_row_up_short':
      'Baris +↑',
  'word.tbl_shade':
      'Arsiran sel',
  'word.tbl_shade_none':
      'Tanpa arsiran',
  'word.text_color':
      'Warna teks',
  'word.text_editor':
      'Tampilan teks biasa',
  'word.theme_colors':
      'Warna tema',
  'word.track_accept':
      'Terima semua perubahan',
  'word.track_changes':
      'Lacak perubahan',
  'word.track_confirm_accept':
      '{n} perubahan terlacak akan diterima. Tindakan ini tidak dapat dibatalkan.',
  'word.track_confirm_reject':
      '{n} perubahan terlacak akan ditolak. Tindakan ini tidak dapat dibatalkan.',
  'word.track_none':
      'Tidak ada perubahan terlacak',
  'word.track_off':
      'Pelacakan perubahan mati',
  'word.track_on':
      'Pelacakan perubahan aktif: penyisipan dan penghapusan Anda akan ditandai',
  'word.track_reject':
      'Tolak semua perubahan',
  'word.translate_selection':
      'Terjemahkan pilihan',
  'word.undo':
      'Urungkan',
  'word.undo_add_paragraph':
      'tambah paragraf',
  'word.undo_delete_paragraph':
      'hapus paragraf',
  'word.undone':
      'Diurungkan: {what}',
  'word.word_count':
      'Jumlah kata',
  'word.words_n':
      '{n} kata',
  'word.zoom_in':
      'Perbesar',
  'word.zoom_out':
      'Perkecil',
  'sl.actions':
      'Tindakan slide',
  'sl.add_slide_short':
      'Slide',
  'sl.align':
      'Perataan',
  'sl.background':
      'Warna latar',
  'sl.bg_default':
      'Bawaan tata letak',
  'sl.bring_front':
      'Bawa ke depan',
  'sl.bullets':
      'Poin',
  'sl.change_layout':
      'Ubah tata letak',
  'sl.copied':
      'Bentuk disalin',
  'sl.cut':
      'Potong',
  'sl.delete':
      'Hapus slide',
  'sl.delete_body':
      'Hapus slide {n}? Tindakan ini tidak dapat dibatalkan (berkas tidak berubah sampai Anda menyimpan).',
  'sl.delete_shape':
      'Hapus bentuk',
  'sl.design':
      'Desain',
  'sl.done':
      'Selesai',
  'sl.duplicate':
      'Gandakan slide',
  'sl.duplicate_shape':
      'Gandakan',
  'sl.duplicated':
      'Slide digandakan.',
  'sl.edit_text':
      'Edit teks',
  'sl.fill':
      'Isian',
  'sl.fullscreen':
      'Tayangan slide layar penuh',
  'sl.go_to_title':
      'Ke slide',
  'sl.goto_hint':
      'Antara 1 dan {total}',
  'sl.hidden':
      'Tersembunyi',
  'sl.hidden_tip':
      'Dilewati dalam tayangan slide',
  'sl.hide':
      'Sembunyikan slide',
  'sl.image_added':
      'Gambar ditambahkan — pindahkan atau ubah ukurannya di PowerPoint. Jangan lupa menyimpan.',
  'sl.indent_less':
      'Kurangi indentasi',
  'sl.indent_more':
      'Tambah indentasi',
  'sl.insert':
      'Sisipkan',
  'sl.insert_image':
      'Sisipkan gambar',
  'sl.line':
      'Garis',
  'sl.line_dashed':
      'Putus-putus',
  'sl.line_width':
      'Lebar: {pt} pt',
  'sl.match_pos':
      '{n} / {total}',
  'sl.move_down':
      'Turunkan',
  'sl.move_shape':
      'Pindahkan bentuk',
  'sl.move_up':
      'Naikkan',
  'sl.new_slide':
      'Slide baru',
  'sl.next_cell':
      'Sel berikutnya',
  'sl.no_fill':
      'Tanpa isian',
  'sl.no_line':
      'Tanpa garis',
  'sl.no_match':
      'Tidak ada yang cocok',
  'sl.no_structure':
      'Struktur slide tidak dapat diedit di berkas ini (data presentasi hilang).',
  'sl.none':
      'Slide tidak ditemukan.',
  'sl.notes_edit':
      'Catatan pembicara',
  'sl.notes_hint':
      'Ketik catatan yang hanya Anda lihat saat presentasi',
  'sl.notes_next':
      'Slide berikutnya dengan catatan',
  'sl.notes_prev':
      'Slide sebelumnya dengan catatan',
  'sl.notes_title':
      'Slide {n} · catatan',
  'sl.notes_toggle':
      'Catatan pembicara',
  'sl.nothing_to_play':
      'Tidak ada slide untuk ditayangkan di berkas ini.',
  'sl.numbering':
      'Penomoran',
  'sl.open_failed':
      'Gagal dibuka: {error}',
  'sl.opening_preview':
      'Sedang dibuka — pengeditan segera siap; menampilkan slide pertama',
  'sl.outline':
      'Kerangka',
  'sl.paste':
      'Tempel',
  'sl.pdf_failed':
      'PDF tidak dapat dibuat: {error}',
  'sl.pdf_progress':
      'Merender slide {n}/{total}…',
  'sl.pdf_share':
      'Presentasi (PDF)',
  'sl.play':
      'Putar',
  'sl.prev_cell':
      'Sel sebelumnya',
  'sl.prompt_body':
      'Ketuk untuk menambah teks',
  'sl.prompt_subtitle':
      'Ketuk untuk menambah subjudul',
  'sl.prompt_title':
      'Ketuk untuk menambah judul',
  'sl.quick_arrange':
      'Susun',
  'sl.quick_style':
      'Gaya',
  'sl.search_hint':
      'Cari di slide',
  'sl.send_back':
      'Kirim ke belakang',
  'sl.shape':
      'Tambah bentuk',
  'sl.slide_of':
      'Slide {n} / {total}',
  'sl.sorter':
      'Penyortir slide',
  'sl.tab_font':
      'Huruf',
  'sl.tab_paragraph':
      'Paragraf',
  'sl.table':
      'Tabel',
  'sl.table_added':
      'Tabel disisipkan — ketuk sel untuk mengetik.',
  'sl.table_insert':
      'Sisipkan tabel',
  'sl.table_size':
      '{r} baris × {c} kolom',
  'sl.text_box':
      'Kotak teks',
  'sl.text_box_default':
      'Teks',
  'sl.thumbnails':
      'Gambar mini',
  'sl.to_pdf':
      'PDF',
  'sl.tr_preview':
      'Pratinjau',
  'sl.transition':
      'Transisi',
  'sl.transparency':
      'Transparansi',
  'sl.transparency_needs_fill':
      'Beri bentuk isian solid terlebih dahulu.',
  'sl.undo_notes':
      'Edit catatan',
  'sl.undo_outline':
      'Edit kerangka',
  'sl.undo_text':
      'Edit teks',
  'sl.unhide':
      'Tampilkan slide',
  'xp.agg':
      'Fungsi',
  'xp.agg_header':
      '{agg} dari {field}',
  'xp.allow_edit':
      'Izinkan edit rentang',
  'xp.allow_edit_off':
      'Rentang dikunci kembali',
  'xp.allow_edit_on':
      'Rentang terpilih dapat diedit di lembar yang dilindungi',
  'xp.audit_none':
      'Tidak ada referensi untuk dilacak di lembar ini',
  'xp.blank':
      '(kosong)',
  'xp.chart_combo':
      'Kombinasi (seri terakhir sebagai garis)',
  'xp.chart_options':
      'Opsi bagan',
  'xp.chart_secondary':
      'Garis pada sumbu sekunder',
  'xp.chart_share_pdf':
      'Bagikan sebagai PDF',
  'xp.chart_share_png':
      'Bagikan sebagai gambar',
  'xp.chart_style':
      'Gaya {n}',
  'xp.chart_trend':
      'Garis tren',
  'xp.collapse':
      'Ciutkan grup',
  'xp.color_scale':
      'Skala warna',
  'xp.cols':
      'Kolom (opsional)',
  'xp.cond_formula':
      'Aturan berdasarkan rumus…',
  'xp.cond_formula_hint':
      'Kondisi relatif terhadap {cell} (mis. ={cell}>100)',
  'xp.cond_manage':
      'Kelola aturan…',
  'xp.cond_none':
      'Tidak ada aturan pemformatan bersyarat di lembar ini',
  'xp.cond_visual':
      'Skala, batang, ikon',
  'xp.cycle_warn':
      'Referensi melingkar: {cell} merujuk dirinya sendiri (secara tidak langsung)',
  'xp.data_bar':
      'Batang data (biru)',
  'xp.data_bar_green':
      'Batang data (hijau)',
  'xp.data_bar_plain':
      'Batang data',
  'xp.delim_auto':
      'Otomatis',
  'xp.delim_comma':
      'Koma',
  'xp.delim_pipe':
      'Garis tegak',
  'xp.delim_semi':
      'Titik koma',
  'xp.delim_tab':
      'Tab',
  'xp.delimiter':
      'Pemisah',
  'xp.density':
      'Kerapatan',
  'xp.density_comfortable':
      'Lega',
  'xp.density_compact':
      'Padat',
  'xp.density_normal':
      'Normal',
  'xp.enc_cp1254':
      'Windows Turki',
  'xp.enc_utf8':
      'UTF-8',
  'xp.encoding':
      'Pengodean',
  'xp.err_calc':
      '#CALC!: hasilnya kosong (mis. FILTER tidak menemukan baris).',
  'xp.err_cycle':
      'Referensi melingkar: rumus merujuk dirinya sendiri.',
  'xp.err_div0':
      '#DIV/0!: pembagian dengan nol atau dengan sel kosong.',
  'xp.err_na':
      '#N/A: nilai yang dicari tidak ditemukan.',
  'xp.err_name':
      '#NAME?: fungsi atau nama tidak dikenali — periksa ejaannya.',
  'xp.err_null':
      '#NULL!: kedua rentang tidak berpotongan.',
  'xp.err_num':
      '#NUM!: angka tidak valid (terlalu besar, akar bilangan negatif…).',
  'xp.err_ref':
      '#REF!: sel yang dirujuk sudah tidak ada (baris/kolom dihapus).',
  'xp.err_spill':
      '#SPILL!: sel tujuan limpahan larik tidak kosong — kosongkan.',
  'xp.err_value':
      '#VALUE!: tipe salah — teks (atau angka dengan spasi) di tempat yang butuh angka.',
  'xp.err_why':
      'Mengapa galat ini?',
  'xp.expand':
      'Perluas grup',
  'xp.filter':
      'Filter (opsional)',
  'xp.fit_width':
      'Sesuaikan lebar halaman',
  'xp.goal_bad_input':
      'Referensi sel atau nilai tidak valid',
  'xp.goal_by':
      'Dengan mengubah sel',
  'xp.goal_done':
      'Solusi: {cell} = {value}',
  'xp.goal_failed':
      'Solusi tidak ditemukan',
  'xp.goal_need_formula':
      'Sel yang ditetapkan harus berisi rumus',
  'xp.goal_need_value':
      'Sel yang diubah harus berisi nilai, bukan rumus',
  'xp.goal_seek':
      'Pencarian target',
  'xp.goal_set':
      'Tetapkan sel (rumus)',
  'xp.goal_to':
      'Ke nilai',
  'xp.grand_total':
      'Total keseluruhan',
  'xp.group':
      'Kelompokkan baris',
  'xp.icon_set':
      'Set ikon: lampu lalu lintas',
  'xp.icon_set_plain':
      'Set ikon',
  'xp.import':
      'Impor (CSV/ODS)',
  'xp.import_done':
      '{n} lembar diimpor',
  'xp.import_go':
      'Impor ke lembar baru',
  'xp.import_rows':
      '{n} baris',
  'xp.landscape':
      'Lanskap',
  'xp.link':
      'Sisipkan tautan',
  'xp.link_cell':
      'Sel di {name}',
  'xp.link_sheet':
      'Di buku kerja ini: {name}',
  'xp.link_web':
      'Alamat web',
  'xp.no_group':
      'Baris ini tidak berada dalam grup',
  'xp.none':
      '— tidak ada —',
  'xp.note_reply':
      'Balas catatan',
  'xp.painter':
      'Kuas format',
  'xp.painter_hint':
      'Ketuk sel untuk menerapkan format',
  'xp.password':
      'Kata sandi',
  'xp.password_again':
      'Kata sandi (ulangi)',
  'xp.password_cancelled':
      'Kata sandi tidak dimasukkan — berkas tidak dibuka',
  'xp.password_mismatch':
      'Kata sandi tidak cocok',
  'xp.password_open':
      'Buku kerja ini dilindungi kata sandi',
  'xp.password_remove':
      'Hapus kata sandi',
  'xp.password_removed':
      'Kata sandi dihapus — disimpan tanpa enkripsi',
  'xp.password_set':
      'Lindungi dengan kata sandi',
  'xp.password_set_done':
      'Berkas akan dienkripsi saat disimpan',
  'xp.password_unsupported':
      'Jenis enkripsi ini tidak didukung (Excel lama)',
  'xp.password_wrong':
      'Kata sandi salah',
  'xp.pivot':
      'Tabel pivot',
  'xp.pivot_create':
      'Buat',
  'xp.pivot_refresh':
      'Segarkan pivot',
  'xp.pivot_refreshed':
      'Pivot disegarkan',
  'xp.pivot_sheet':
      'Pivot {n}',
  'xp.pivot_source_gone':
      'Lembar sumber sudah tidak ada — tidak dapat menyegarkan',
  'xp.portrait':
      'Potret',
  'xp.print_area_clear':
      'Hapus area cetak',
  'xp.print_area_cleared':
      'Area cetak dihapus',
  'xp.print_area_set':
      'Area cetak ditetapkan',
  'xp.print_area_set_btn':
      'Tetapkan pilihan sebagai area cetak',
  'xp.print_done':
      'PDF siap',
  'xp.print_empty':
      'Tidak ada yang dicetak',
  'xp.print_go':
      'Buat PDF',
  'xp.print_grid':
      'Garis kisi',
  'xp.print_group':
      'Cetak dan lindungi',
  'xp.print_page':
      'Halaman {n} / {t}',
  'xp.print_pdf':
      'Tata letak cetak → PDF',
  'xp.protect_no_pw':
      'Lindungi tanpa kata sandi',
  'xp.protect_sheet':
      'Lindungi lembar',
  'xp.protect_with_pw':
      'Lindungi dengan kata sandi…',
  'xp.protected':
      'Lembar dilindungi',
  'xp.protected_cell':
      'Sel ini terkunci di lembar yang dilindungi',
  'xp.repeat_rows':
      'Baris judul diulang di setiap halaman',
  'xp.ribbon_full':
      'Pita lengkap',
  'xp.ribbon_simple':
      'Pita ringkas',
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
      'Pilih rentang data terlebih dahulu',
  'xp.std_colors':
      'Warna standar',
  'xp.subtotal':
      'Subtotal',
  'xp.subtotal_by':
      'Pada setiap perubahan di',
  'xp.subtotal_go':
      'Buat subtotal',
  'xp.subtotal_sheet':
      'Subtotal {name}',
  'xp.subtotal_suffix':
      ' Total',
  'xp.subtotal_sum':
      'Tambahkan subtotal ke',
  'xp.theme_colors':
      'Warna tema',
  'xp.toggle_group':
      'Ciutkan/perluas grup',
  'xp.trace_clear':
      'Hapus panah',
  'xp.trace_dep':
      'Lacak dependen',
  'xp.trace_prec':
      'Lacak preseden',
  'xp.undo_sparkline':
      'Sisipkan sparkline',
  'xp.ungroup':
      'Pisahkan grup',
  'xp.unprotect':
      'Buka perlindungan lembar',
  'xp.unprotected':
      'Perlindungan lembar dibuka',
  'xp.values':
      'Nilai',
  'sp.add_anim':
      'Tambah animasi',
  'sp.add_ph':
      'Tambah placeholder',
  'sp.add_row':
      'Tambah kategori',
  'sp.add_section':
      'Tambah bagian',
  'sp.add_series':
      'Tambah seri',
  'sp.add_show':
      'Tambah tayangan',
  'sp.align_hint':
      'Pilih bentuk untuk diratakan',
  'sp.anim_order':
      'Urutan animasi',
  'sp.anim_pick_fx':
      'Efek',
  'sp.anim_pick_shape':
      'Bentuk yang mana?',
  'sp.animations':
      'Animasi',
  'sp.applied':
      'Diterapkan',
  'sp.apply':
      'Terapkan',
  'sp.arrange_title':
      'Slide {n}',
  'sp.body_size':
      'Ukuran isi',
  'sp.chart_data':
      'Data bagan',
  'sp.chart_edit':
      'Edit data bagan',
  'sp.chart_from_table':
      'Bagan dari tabel',
  'sp.chart_insert':
      'Sisipkan bagan',
  'sp.chart_title':
      'Judul bagan',
  'sp.conn_elbow':
      'Siku',
  'sp.conn_straight':
      'Lurus',
  'sp.connect':
      'Konektor',
  'sp.connect_none':
      'Tidak ada bentuk lain untuk dihubungkan',
  'sp.connect_to':
      'Hubungkan ke bentuk yang mana?',
  'sp.copy_suffix':
      'salinan',
  'sp.counter':
      'Hitung mundur langsung',
  'sp.counter_added':
      'Hitung mundur ditambahkan',
  'sp.counter_hint':
      'Menghitung mundur selama tayangan',
  'sp.counter_minutes':
      'Berapa menit?',
  'sp.crop':
      'Pangkas',
  'sp.crop_b':
      'Bawah',
  'sp.crop_l':
      'Kiri',
  'sp.crop_r':
      'Kanan',
  'sp.crop_shape':
      'Pangkas ke bentuk',
  'sp.crop_t':
      'Atas',
  'sp.custom_shows':
      'Tayangan kustom',
  'sp.delete':
      'Hapus',
  'sp.draw':
      'Gambar tanda tangan Anda',
  'sp.font_major':
      'Huruf judul',
  'sp.font_minor':
      'Huruf isi',
  'sp.fx_appear':
      'Muncul',
  'sp.fx_emph':
      'Penekanan',
  'sp.fx_entr':
      'Masuk',
  'sp.fx_exit':
      'Keluar',
  'sp.fx_fade':
      'Memudar',
  'sp.fx_fly':
      'Terbang masuk',
  'sp.fx_other':
      'Animasi',
  'sp.fx_path':
      'Jalur gerak',
  'sp.fx_spin':
      'Putar',
  'sp.fx_wipe':
      'Sapu',
  'sp.fx_zoom':
      'Zum',
  'sp.g_arrange':
      'Susun',
  'sp.g_design':
      'Desain',
  'sp.g_insert':
      'Sisipkan',
  'sp.g_show':
      'Tayangan & ekspor',
  'sp.g_slides':
      'Slide',
  'sp.glow':
      'Cahaya',
  'sp.gradient':
      'Isian gradien',
  'sp.hex_input':
      'Ketik kode warna (RRGGBB)',
  'sp.hide':
      'Sembunyikan',
  'sp.image_hint':
      'Pilih foto tanda tangan atau PNG transparan.',
  'sp.inherited':
      'dari master',
  'sp.layers':
      'Lapisan',
  'sp.layers_align':
      'Lapisan & perataan',
  'sp.layers_hint':
      'Urutan Z, sembunyikan, ratakan, distribusikan',
  'sp.layout':
      'Tata letak',
  'sp.layout_dup':
      'Gandakan tata letak',
  'sp.layout_hint':
      'Ketuk: pilih · seret: pindah · sudut kanan bawah: ubah ukuran',
  'sp.layouts':
      'Tata letak',
  'sp.link':
      'Tautan / tindakan',
  'sp.link_slide':
      'Slide tertentu',
  'sp.link_url':
      'Alamat web',
  'sp.master':
      'Master slide & tema',
  'sp.master_bg':
      'Warna latar',
  'sp.master_hint':
      'Tata letak, placeholder, warna dan huruf tema',
  'sp.master_n':
      'Master {n}',
  'sp.master_style':
      'Gaya master',
  'sp.media_added':
      'Media ditambahkan',
  'sp.media_hint':
      'Diputar saat diketuk dalam tayangan',
  'sp.media_insert':
      'Sisipkan audio / video',
  'sp.media_too_big':
      'Berkas terlalu besar (maks 150 MB)',
  'sp.mic_denied':
      'Izin mikrofon ditolak',
  'sp.move_down':
      'Turunkan',
  'sp.move_up':
      'Naikkan',
  'sp.no_anims':
      'Tidak ada animasi di slide ini',
  'sp.no_chart':
      'Data bagan tidak dapat dibaca',
  'sp.no_sections':
      'Tidak ada bagian. Tambahkan satu mulai dari sebuah slide.',
  'sp.no_shapes':
      'Tidak ada bentuk di slide ini',
  'sp.no_shows':
      'Tidak ada tayangan kustom',
  'sp.no_smartart':
      'Tidak ada SmartArt di dek ini',
  'sp.off':
      'Mati',
  'sp.on':
      'Hidup',
  'sp.pick_color':
      'Pilih warna',
  'sp.pick_image':
      'Pilih gambar',
  'sp.png_all':
      'Semua slide sebagai PNG (zip)',
  'sp.png_one':
      'Bagikan slide ini sebagai PNG',
  'sp.presenter_hint':
      'Catatan, slide berikutnya, dan waktu berdampingan',
  'sp.record':
      'Latihan & rekam narasi',
  'sp.record_done':
      'Narasi ditambahkan',
  'sp.record_hint':
      'Suara dan waktu tiap slide disimpan; tayangan maju sendiri',
  'sp.record_save':
      'Narasi direkam untuk {n} slide. Tambahkan ke dek?',
  'sp.reflection':
      'Pantulan',
  'sp.rehearse':
      'Latih waktu',
  'sp.rehearse_done':
      'Waktu disimpan',
  'sp.rehearse_hint':
      'Waktu di tiap slide diukur; tayangan lalu maju sendiri',
  'sp.rehearse_save':
      'Latihan berlangsung {t} ({n} slide). Simpan waktunya?',
  'sp.remove_bg':
      'Hapus latar belakang',
  'sp.remove_bg_downloading':
      'Model sedang diunduh; coba lagi sebentar lagi',
  'sp.remove_bg_failed':
      'Latar belakang tidak dapat dihapus',
  'sp.remove_bg_hint':
      'Di perangkat (ML Kit); model diunduh saat pertama dipakai',
  'sp.remove_bg_unavailable':
      'Tidak tersedia di perangkat ini',
  'sp.remove_bg_working':
      'Menghapus latar belakang…',
  'sp.remove_row':
      'Hapus baris',
  'sp.remove_series':
      'Hapus seri',
  'sp.rename':
      'Ganti nama',
  'sp.saved_list':
      'Tanda tangan tersimpan',
  'sp.section_default':
      'Bagian {n}',
  'sp.section_first':
      'Bagian bawaan',
  'sp.section_name':
      'Nama bagian',
  'sp.section_start':
      'Slide mana yang memulai bagian?',
  'sp.sections':
      'Bagian',
  'sp.sections_hint':
      'Kelompokkan slide; tayangkan subset pilihan',
  'sp.sections_title':
      'Bagian & tayangan kustom',
  'sp.selected_n':
      '{n} dipilih',
  'sp.shadow':
      'Bayangan',
  'sp.shape_library':
      'Pustaka bentuk',
  'sp.shape_library_hint':
      'Dasar, panah, bintang, balon teks, diagram alir, tombol aksi',
  'sp.shape_tools':
      'Alat',
  'sp.show':
      'Tayangkan',
  'sp.show_default':
      'Tayangan {n}',
  'sp.show_name':
      'Nama tayangan',
  'sp.slide_n':
      'Slide {n}',
  'sp.slides_n':
      '{n} slide',
  'sp.smartart':
      'Ubah SmartArt menjadi bentuk',
  'sp.smartart_done':
      'SmartArt diubah menjadi bentuk',
  'sp.smartart_hint':
      'Menjadi grup bentuk yang dapat diedit',
  'sp.suggested':
      'Disarankan',
  'sp.tab_draw':
      'Gambar',
  'sp.tab_image':
      'Gambar',
  'sp.tab_type':
      'Ketik',
  'sp.table_no_data':
      'Tabel tidak memiliki data bagan',
  'sp.table_style':
      'Gaya tabel',
  'sp.templates':
      'Galeri templat',
  'sp.templates_hint':
      '8 tema bersih — konten tetap dipertahankan',
  'sp.theme_colors':
      'Warna tema',
  'sp.title_size':
      'Ukuran judul',
  'sp.tools':
      'Alat',
  'sp.tpl_sample':
      'Contoh poin',
  'sp.type_hint':
      'Nama atau inisial Anda',
  'sp.video_encoding':
      'Mengodekan video…',
  'sp.video_export':
      'Ekspor sebagai video (MP4)',
  'sp.video_hint':
      'Tiap slide selama waktu tertentu; waktu rekaman dipertahankan',
  'sp.video_seconds':
      'Detik per slide',
  'sp.video_unavailable':
      'Ekspor video tidak tersedia di perangkat ini',
  'near.accept':
      'Terima',
  'near.add_files':
      'Tambah berkas',
  'near.add_folder':
      'Tambah folder',
  'near.add_text':
      'Teks',
  'near.asking':
      'Menunggu {name} menerima…',
  'near.bg_ask_body':
      '{name} ingin mengirim {n} berkas',
  'near.bg_ask_title':
      'Permintaan berkas masuk',
  'near.bg_ch_ask':
      'Permintaan berkas masuk',
  'near.bg_ch_quiet':
      'Visibilitas latar belakang',
  'near.bg_failed':
      'Tidak dapat diaktifkan — apakah Bluetooth menyala dan diizinkan?',
  'near.bg_note_text':
      'Bluetooth berdaya rendah · permintaan masuk perlu persetujuan Anda',
  'near.bg_note_title':
      'Terlihat oleh perangkat di sekitar',
  'near.bg_off':
      'Visibilitas latar belakang dimatikan.',
  'near.bg_on':
      'Perangkat di sekitar dapat melihat Anda bahkan saat layar ini ditutup (Bluetooth berdaya rendah); permintaan ditanyakan lewat notifikasi.',
  'near.bg_switch':
      'Terlihat di latar belakang',
  'near.bg_waiting':
      '{name} menyetujui — pengiriman akan dimulai lewat Wi-Fi',
  'near.bt_denied':
      'Tidak ada izin Bluetooth · izinkan',
  'near.bt_failed':
      'Bluetooth gagal · coba lagi',
  'near.bt_none':
      'Tidak ada Bluetooth LE',
  'near.bt_off':
      'Bluetooth mati · coba lagi',
  'near.bt_on':
      'Bluetooth',
  'near.bt_wait':
      'Bluetooth…',
  'near.busy_sending':
      'Tunggu pengiriman saat ini selesai (atau Berhenti)',
  'near.clear_sel':
      'Hapus',
  'near.clip_files':
      'Tambahkan {n} berkas yang disalin',
  'near.copied':
      'Alamat disalin',
  'near.decline':
      'Tolak',
  'near.dur_lt1':
      'kurang dari 1 dtk',
  'near.dur_ms':
      '{m} mnt {s} dtk',
  'near.dur_s':
      '{s} dtk',
  'near.empty_hint':
      'Buka Transfer juga di perangkat lain (Wi-Fi yang sama atau Bluetooth).',
  'near.fail_code':
      'kode pemasangan ditolak',
  'near.fail_identity':
      'identitas penerima berubah, dihentikan demi keamanan',
  'near.fail_network':
      'koneksi terputus, penerima tidak terjangkau',
  'near.fail_receiver':
      'penerima tidak dapat menyimpannya (tidak ada ruang atau izin)',
  'near.fail_secure':
      'koneksi aman gagal',
  'near.fail_tile':
      'Tidak terkirim',
  'near.file_done':
      'Selesai',
  'near.folder_files':
      '{n} berkas',
  'near.history':
      'Riwayat',
  'near.invite_failed':
      'Tidak dapat menjangkau {name}. Dekatkan dan coba lagi, atau pindai QR.',
  'near.invited':
      'Berkas akan ditransfer setelah {name} menerima — biarkan layar ini terbuka.',
  'near.inviting':
      'Memberi tahu {name}…',
  'near.keep_body':
      'Berbagi akan menutup sendiri setelah selesai',
  'near.keep_title':
      'Mentransfer berkas',
  'near.missing':
      'sudah tidak ada',
  'near.network':
      'Jaringan',
  'near.no_network':
      'Tidak dapat menyiapkan jaringan — nyalakan Wi-Fi atau gunakan QR.',
  'near.none_received':
      'Belum ada yang diterima.',
  'near.none_sent':
      'Belum ada yang dikirim.',
  'near.offer_dest':
      'Disimpan ke: {dir}',
  'near.offer_more':
      '+{n} lagi',
  'near.offer_sub':
      '{n} item · {size}',
  'near.offer_title':
      '{from} mengirim berkas',
  'near.other_ways':
      'Cara lain',
  'near.password':
      'Kata sandi',
  'near.pick_this_folder':
      'Kirim folder ini',
  'near.pick_to_link':
      'Pilih berkas & buat tautan',
  'near.received_tab':
      'Diterima',
  'near.receiving':
      'Menerima',
  'near.receiving_n':
      'Menerima · {n} berkas',
  'near.remove_record':
      'Hapus dari daftar',
  'near.reveal':
      'Tampilkan lokasi',
  'near.searching':
      'Mencari Dosyalarım di sekitar…',
  'near.sec_local':
      'Jaringan lokal & unduhan',
  'near.sec_prefs':
      'Preferensi transfer',
  'near.selected':
      '{n} item dipilih',
  'near.sending_to':
      'Mengirim ke {name}',
  'near.sent_fail':
      'Gagal',
  'near.sent_ok':
      'Berhasil',
  'near.sent_partial':
      '{ok} berkas terkirim · {bad} tidak terkirim: {why}',
  'near.sent_tab':
      'Terkirim',
  'near.sent_tile':
      'Terkirim',
  'near.sent_to':
      '→ {name}',
  'near.share_apps':
      'Bagikan dengan aplikasi',
  'near.share_no_folder':
      'Folder tidak dapat dibagikan dengan aplikasi; pilih berkas di dalamnya.',
  'near.share_sub':
      'Ke ponsel di sekitar, atau lewat QR ke browser mana pun — tanpa aplikasi',
  'near.show_all':
      'Tampilkan semua ({n})',
  'near.starting':
      'Bersiap…',
  'near.step_page':
      '2 · Buka berkas',
  'near.step_what':
      '1 · Apa yang dikirim?',
  'near.step_who':
      '2 · Kepada siapa?',
  'near.step_wifi':
      '1 · Gabung jaringan',
  'near.tap_device':
      'Ketuk perangkat di bawah untuk mengirim · folder tiba sebagai folder, banyak berkas kecil dikirim sebagai satu paket',
  'near.text_copy':
      'Salin',
  'near.text_failed':
      'Teks tidak dapat dikirim — apakah Transfer terbuka dan aplikasinya mutakhir di sana?',
  'near.text_from':
      '{from} mengirim teks',
  'near.text_hint':
      'Ketik atau tempel — muncul di perangkat lain, siap disalin',
  'near.text_sent':
      'Teks dikirim ke {name}',
  'near.text_title':
      'Teks untuk dikirim',
  'near.text_wifi_only':
      'Teks hanya dikirim lewat Wi-Fi — kedua perangkat harus berada di jaringan yang sama',
  'near.title':
      'Di sekitar',
  'near.trust_this':
      'Percayai perangkat ini — jangan tanya lagi',
  'near.trusted':
      'Perangkat tepercaya',
  'near.trusted_added':
      '{name} ditambahkan ke perangkat tepercaya',
  'near.trusted_badge':
      'Tepercaya',
  'near.type_address':
      'Jika QR tidak terpindai, ketik alamat ini di browser ponsel lain.',
  'near.untrust':
      'Cabut kepercayaan',
  'near.via_web':
      'Browser (QR)',
  'near.waiting':
      'Koneksi terputus — akan dilanjutkan dari titik berhenti…',
  'near.web_idle':
      'Unduh di browser lewat QR',
  'near.web_idle_sub':
      'Pilih berkas dan QR beserta alamat singkat muncul di sini; orang lain memindainya dan mengunduh di browser.',
  'near.web_same_wifi':
      'Ponsel di Wi-Fi yang sama memindainya dengan kamera — halaman terbuka, satu ketukan untuk mengunduh.',
  'near.web_step1':
      '1. Pindai dengan kamera → gabung ke jaringan ponsel saya',
  'near.web_step2':
      '2. Sekarang pindai ini → halaman terbuka, berkas terunduh',
  'near.what_to_send':
      'Apa yang dikirim ke {name}?',
  'near.wifi_off':
      'Tidak ada Wi-Fi',
  'near.wifi_on':
      'Wi-Fi',
  'sm.amount_title':
      'Jumlah: {range}',
  'sm.auto':
      'Atur berkas baru secara otomatis',
  'sm.auto_sub':
      'Berkas baru diatur diam-diam setiap kali Anda kembali ke aplikasi',
  'sm.bg':
      'Hanya saat mengisi daya di Wi-Fi (juga di latar belakang)',
  'sm.bg_sub':
      'Mengatur saat mengisi daya di Wi-Fi, bahkan dengan aplikasi tertutup; paling banyak {n} berkas per putaran',
  'sm.camera':
      'Sertakan foto kamera',
  'sm.cap':
      'Paling banyak {cap} berkas sehari',
  'sm.cap_day':
      '{d}: {n} berkas · {l} peringatan kuota',
  'sm.cap_n':
      '{n} berkas',
  'sm.cap_none':
      'Tanpa batas harian',
  'sm.cap_sub':
      'Hari ini {n}/{cap} · peringatan kuota gratis {l}',
  'sm.cap_sub_none':
      'Hari ini {n} berkas · peringatan kuota gratis {l}',
  'sm.cap_title':
      'Batas harian',
  'sm.cap_unlimited':
      'Tanpa batas',
  'sm.clutter':
      'Bersihkan',
  'sm.clutter_empty':
      'Tidak ada yang tidak diperlukan 🎉',
  'sm.clutter_sub':
      'Kartu ucapan, meme, foto buram, dan jepretan tidak sengaja',
  'sm.clutter_title':
      'Bersihkan · {n} tidak diperlukan',
  'sm.delete_sel':
      'Hapus ({n})',
  'sm.deselect_one':
      'Batalkan pilihan',
  'sm.disable':
      'Matikan atur pintar',
  'sm.done':
      '{n} berkas diatur',
  'sm.enable':
      'Aktifkan dan atur',
  'sm.expired':
      'Dokumen kedaluwarsa',
  'sm.expiring_soon':
      'Segera kedaluwarsa',
  'sm.fail_blocked':
      'konten tidak dijawab karena alasan keamanan',
  'sm.fail_empty':
      'jawaban kosong, akan dicoba lagi nanti',
  'sm.failed':
      '{n} berkas gagal',
  'sm.filter_title':
      'Kategori pintar',
  'sm.folders':
      'Folder pintar',
  'sm.folders_empty':
      'Belum ada kategori — ketuk "Atur sekarang".',
  'sm.group_all':
      'Semua',
  'sm.group_docs':
      'Dokumen',
  'sm.group_finance':
      'Keuangan',
  'sm.group_images':
      'Gambar',
  'sm.group_media':
      'Media',
  'sm.hidden_empty':
      'Tidak ada berkas tersembunyi',
  'sm.hidden_n':
      '{n} berkas disembunyikan',
  'sm.hide_sel':
      'Sembunyikan ({n})',
  'sm.hold_cap':
      '{n} berkas diatur; batas hari ini ({cap}) tercapai, sisanya besok',
  'sm.hold_offline':
      'Mode luring aktif — matikan di Pengaturan > Privasi untuk mengatur',
  'sm.hold_scope':
      'Tidak ada folder untuk diatur — periksa akses berkas dan Pengaturan > Kecerdasan buatan > cakupan',
  'sm.hold_wifi':
      'Mengatur hanya di Wi-Fi; dilanjutkan setelah Anda di Wi-Fi',
  'sm.inst_title':
      'Penerbit: {name}',
  'sm.intro_body':
      'Atur pintar memeriksa dokumen baru (PDF, Word, Excel, slide, teks), gambar, rekaman suara, dan video, lalu memberi masing-masing nama kedua dan kategori yang jelas.',
  'sm.intro_pick_sub':
      'Anda mulai dengan jatah {max} berkas; centang hanya yang Anda mau, bukan memindai semuanya.',
  'sm.intro_pick_title':
      'Berkas mana yang harus dipindai?',
  'sm.intro_title':
      'Biarkan ponsel Anda mengatur dirinya sendiri',
  'sm.keep':
      'Pertahankan',
  'sm.keep_body':
      'Berkas ini keluar dari daftar Bersihkan dan tidak akan disarankan lagi.',
  'sm.keep_title':
      'Bukan yang tidak diperlukan?',
  'sm.local_ready_sub':
      'Faktur, bukti bank, dokumen resmi, catatan kesehatan, tangkapan layar, dan APK dipilah secara luring, gratis. Kunci Gemini opsional juga mengklasifikasikan berkas yang ambigu.',
  'sm.local_ready_title':
      'Pemilahan pintar lokal siap (tanpa kunci API)',
  'sm.local_saved':
      '{n} berkas diklasifikasikan secara lokal dengan 0 kredit AI',
  'sm.low_conf':
      'Tinjau',
  'sm.nothing_new':
      'Tidak ada berkas baru untuk diatur',
  'sm.overdue':
      'Tagihan terlambat',
  'sm.pick_download_folder':
      'Folder Unduhan',
  'sm.pick_more_sources':
      'Jenis & sumber folder lainnya',
  'sm.pick_one':
      'Pilih minimal satu jenis dan sumber untuk dipindai.',
  'sm.point_clean':
      'Kartu ucapan, meme, foto buram, dan jepretan tidak sengaja dapat disembunyikan atau dihapus dengan satu ketukan.',
  'sm.point_name':
      'Nama kedua seperti "Tagihan listrik · Oktober 2026"; saring daftar menurut kategori pintar, cari dalam bahasa apa pun.',
  'sm.point_place':
      'Berkas tetap di tempat dan namanya — tidak ada yang dipindahkan.',
  'sm.preset_all':
      'Semua',
  'sm.preset_docs':
      'Hanya dokumen',
  'sm.preset_downloads':
      'Hanya unduhan',
  'sm.privacy':
      'Cakupan: Unduhan, Dokumen, tangkapan layar, rekaman, WhatsApp, dan Telegram. Kamera hanya jika Anda mengaktifkannya. Berkas (untuk Word, Excel, dan slide hanya teksnya; untuk video hanya menit pertama yang dilihat; untuk APK dan arsip hanya nama, ukuran, dan folder) dikirim ke Google Gemini untuk ditinjau; hasilnya tetap hanya di ponsel Anda. Dengan kunci Gemini gratis, Google dapat menggunakan data untuk meningkatkan produknya. Folder di luar cakupan AI tidak pernah dikirim.',
  'sm.progress':
      'Menyusun {done}/{total}',
  'sm.r_all':
      'Semua',
  'sm.restore_sel':
      'Pulihkan ({n})',
  'sm.restored_n':
      '{n} berkas dipulihkan',
  'sm.reused_n':
      '{n} salinan lokal digunakan ulang (0 unit)',
  'sm.run':
      'Atur sekarang',
  'sm.search_empty':
      'Tidak ada berkas teratur yang cocok',
  'sm.search_hint':
      'Cari atur pintar (nama, penerbit, tahun, jenis…)',
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
      'Pengaturan',
  'sm.similar':
      'Foto serupa',
  'sm.starter_cap_hit':
      '{n} berkas diatur · Jatah awal {max} berkas tercapai. Gunakan langganan opsional atau kunci Anda sendiri untuk lebih banyak.',
  'sm.starter_usage':
      '{n} / {max} jatah awal terpakai',
  'sm.status':
      '{n} berkas · {c} kategori',
  'sm.status_sub':
      'Berkas tetap di tempatnya; nama kedua tampil di daftar dan pencarian.',
  'sm.stop':
      'Berhenti',
  'sm.stopped':
      '{n} berkas diatur, proses dihentikan. {reason}',
  'sm.sub_all':
      'Semua',
  'sm.tab_clutter':
      'Tidak diperlukan ({n})',
  'sm.tab_hidden':
      'Tersembunyi ({n})',
  'sm.tile':
      'Atur pintar',
  'sm.tile_off':
      'Aktifkan atur pintar',
  'sm.tile_on':
      '{n} berkas diatur',
  'sm.title':
      'Atur pintar',
  'sm.upcoming_due':
      'Segera jatuh tempo',
  'sm.usage':
      'Putaran terakhir: {n} berkas · ~{t} unit dan {q} pertanyaan per berkas',
  'sm.waiting':
      'jeda singkat, akan berlanjut sendiri',
  'sm.wifi':
      'Hanya di Wi-Fi',
  'sm.wifi_sub':
      'Tidak ada berkas yang dikirim lewat data seluler',
  'sm.year_title':
      'Tahun dokumen: {y}',
  'pe.add_image':
      'Tambah gambar',
  'pe.add_initials':
      'Tambah inisial',
  'pe.add_signature':
      'Tambah tanda tangan',
  'pe.add_text':
      'Tambah teks',
  'pe.background_failed':
      'Tidak dapat memindai item latar belakang: {error}',
  'pe.bold':
      'Tebal',
  'pe.busy_applying':
      'Menerapkan perubahan ke halaman…',
  'pe.busy_background':
      'Mencari item latar belakang…',
  'pe.busy_draw':
      'Menerapkan gambar…',
  'pe.busy_fix':
      'Memperbaiki baris…',
  'pe.busy_fix_ai':
      'Memperbaiki baris secara pintar — beberapa detik…',
  'pe.busy_image':
      'Mengubah gambar…',
  'pe.busy_make_editable':
      'Mengubah halaman menjadi teks…',
  'pe.busy_reading':
      'Membaca halaman {page} — teks yang dapat diedit segera diberi garis…',
  'pe.busy_redo':
      'Mengulangi: {what}…',
  'pe.busy_refresh':
      'Menyegarkan halaman…',
  'pe.busy_rotate':
      'Memutar halaman…',
  'pe.busy_saving':
      'Menyimpan — menulis teks, tanda tangan, dan gambar yang ditambahkan…',
  'pe.busy_undo':
      'Mengurungkan: {what}…',
  'pe.busy_working':
      'Memproses…',
  'pe.clear_selection':
      'Hapus pilihan',
  'pe.delete_image':
      'Hapus gambar',
  'pe.delete_image_body':
      'Gambar ini akan dihapus dari halaman. Anda dapat mengembalikannya dengan Urungkan.',
  'pe.draw_initials':
      'Gambar inisial Anda',
  'pe.draw_open':
      'Gambar dengan pena',
  'pe.drawn':
      'Gambar ditambahkan',
  'pe.field_next':
      'Kolom berikutnya',
  'pe.field_prev':
      'Kolom sebelumnya',
  'pe.fix_done':
      '{n} baris dikoreksi.',
  'pe.fix_nothing':
      'Tidak ada yang perlu dikoreksi — halaman sudah tampak bersih.',
  'pe.fix_page':
      'Perbaiki teks',
  'pe.fix_page_ai':
      'Perbaiki teks secara pintar',
  'pe.font_bigger':
      'Lebih besar',
  'pe.font_smaller':
      'Lebih kecil',
  'pe.force_ocr':
      'Edit dengan OCR',
  'pe.form_filled':
      'Kolom terisi',
  'pe.form_locked':
      'Kolom ini hanya-baca',
  'pe.form_signature':
      'Kolom tanda tangan: tambahkan tanda tangan Anda dari tab Tanda tangan',
  'pe.hint_background':
      'Item yang berulang di setiap halaman tercantum di bawah. Pilih yang ingin dihapus.',
  'pe.hint_draw':
      'Pena, stabilo, penghapus, dan teks — gambar menjadi bagian dari satu langkah edit ini',
  'pe.hint_failed':
      'Halaman ini tidak dapat dianalisis: {error}',
  'pe.hint_form':
      'Ketuk kolom dan isi di halaman',
  'pe.hint_form_loading':
      'Membaca kolom formulir…',
  'pe.hint_form_none':
      'Dokumen ini tidak memiliki kolom formulir yang dapat diisi',
  'pe.hint_image':
      'Ketuk gambar untuk memilihnya; seret untuk memindahkan, ubah ukuran dari sudut, atau gunakan bilah di bawah untuk memutar dan membalikkannya.',
  'pe.hint_image_locked':
      'Gambar di halaman ini terkunci di tempatnya: ditampilkan tetapi tidak dapat diedit (blok gambar bersama atau gambar sebaris).',
  'pe.hint_image_none':
      'Tidak ada gambar tertanam di halaman ini.',
  'pe.hint_page':
      'Putar halaman yang terbuka.',
  'pe.hint_place_text':
      'Ketuk tempat teks harus dimulai.',
  'pe.hint_sign':
      'Tambahkan tanda tangan atau inisial; seret, ubah ukuran dari sudut',
  'pe.hint_text':
      'Ketuk paragraf yang ingin diubah.',
  'pe.hint_text_none':
      'Tidak ada teks yang dapat diedit di halaman ini. Ketuk “Tambah teks” untuk menulis di atasnya.',
  'pe.hint_text_scanned':
      'Halaman hasil pindai: ketuk baris untuk mengetik di atasnya (mengenali baris…).',
  'pe.hint_text_unsupported':
      'Teks halaman ini belum dapat diedit langsung (tata letaknya tidak terbaca). Ketuk "Tambah teks" untuk menaruh teks baru.',
  'pe.image_added':
      'Gambar ditambahkan',
  'pe.image_deleted':
      'Gambar dihapus',
  'pe.image_mirrored':
      'Gambar dibalik',
  'pe.image_moved':
      'Gambar dipindahkan',
  'pe.image_turned':
      'Gambar diputar',
  'pe.image_unreadable':
      'Gambar tidak dapat dibaca',
  'pe.inline_checking':
      'Memeriksa apakah muat di halaman…',
  'pe.inline_empty':
      'Paragraf tidak boleh kosong; gunakan "Timpa" tanpa teks untuk menghapusnya',
  'pe.inline_fits':
      'Muat — ketuk Selesai untuk menerapkan',
  'pe.inline_hint':
      'Ubah teks, terapkan dengan ✓. Anda akan diberi tahu di sini jika tidak muat.',
  'pe.inline_hint_scanned':
      'Baris hasil pindai: perbaiki teks, ✓ menimpanya pada baris.',
  'pe.items_removed':
      'Item terpilih dihapus',
  'pe.make_editable':
      'Jadikan halaman ini dapat diedit',
  'pe.make_editable_done':
      '{n} baris diubah menjadi teks yang dapat diedit.',
  'pe.mirror_h':
      'Balik horizontal',
  'pe.mirror_v':
      'Balik vertikal',
  'pe.mode_draw':
      'Gambar',
  'pe.mode_form':
      'Formulir',
  'pe.mode_image':
      'Gambar',
  'pe.mode_page':
      'Halaman',
  'pe.mode_sign':
      'Tanda tangan',
  'pe.mode_text':
      'Teks',
  'pe.mode_watermark':
      'Tanda air',
  'pe.no_background':
      'Tidak ditemukan item latar belakang yang berulang.',
  'pe.object_deleted':
      'Objek dihapus',
  'pe.object_locked':
      'Gambar ini tidak dapat diedit; hanya posisinya yang ditampilkan.',
  'pe.object_moved':
      'Objek dipindahkan',
  'pe.op_failed':
      'Operasi gagal: {error}',
  'pe.outline_failed':
      'Tidak dapat menganalisis halaman: {error}',
  'pe.overwrite':
      'Timpa',
  'pe.overwrite_help':
      'Tutup paragraf dengan warna putih dan tulis teks baru di tempatnya',
  'pe.overwritten':
      'Paragraf ditimpa',
  'pe.page_rotated':
      'Halaman diputar',
  'pe.paragraph_updated':
      'Paragraf diperbarui',
  'pe.pick_to_remove':
      'Pilih item yang akan dihapus',
  'pe.prepare_failed':
      'Dokumen tidak dapat disiapkan: {error}',
  'pe.protected_body':
      'Dokumen ini dikunci dari pengeditan tetapi terbuka tanpa meminta kata sandi (kunci izin). Hapus perlindungannya dan edit?\n\nBerkas asli Anda tidak diubah; perlindungan hanya dihapus pada salinan yang diedit.',
  'pe.protected_title':
      'Dokumen dilindungi',
  'pe.protection_removed':
      'Perlindungan dihapus',
  'pe.redone_what':
      'Diulangi: {what}',
  'pe.redraw_signature':
      'Gambar ulang',
  'pe.remove_picked':
      'Hapus yang dipilih ({n})',
  'pe.remove_protection':
      'Hapus perlindungan',
  'pe.rot_left':
      '90° kiri',
  'pe.rot_right':
      '90° kanan',
  'pe.save_note':
      'Di mana dokumen yang diedit akan disimpan?',
  'pe.scanned_updated':
      'Baris diperbarui.',
  'pe.signature_added':
      'Tanda tangan ditambahkan',
  'pe.text_added':
      'Teks ditambahkan',
  'pe.text_color':
      'Warna teks',
  'pe.text_edited':
      'Teks diedit',
  'pe.undone_what':
      'Diurungkan: {what}',
  'pe.unlock_failed':
      'Tidak dapat menghapus perlindungan kata sandi dokumen: {error}\n\nJika ada kata sandi sungguhan, hapus lewat alat PDF lalu coba lagi.',
  'pe.wait_busy':
      'Sebentar — {what}',
// ── enum ──
  'enum.res_long_edge':
      'Sisi terpanjang',
  'enum.res_aspect':
      'Rasio aspek',
  'enum.res_file_size':
      'Ukuran berkas',
  'enum.layout_list':
      'Daftar',
  'enum.layout_detail':
      'Daftar besar',
  'enum.layout_grid2':
      '2 kolom',
  'enum.layout_grid3':
      '3 kolom',
  'enum.layout_grid4':
      '4 kolom',
  'enum.layout_grid5':
      '5 kolom',
  'enum.layout_list_desc':
      'Satu baris · nama, ukuran, dan tanggal',
  'enum.layout_detail_desc':
      'Satu baris · pratinjau besar',
  'enum.layout_grid2_desc':
      'Ubin terbesar',
  'enum.layout_grid3_desc':
      'Seimbang — bawaan',
  'enum.layout_grid4_desc':
      'Muat lebih banyak berkas',
  'enum.layout_grid5_desc':
      'Tampilan terpadat',
  'enum.photo_group_day':
      'Hari',
  'enum.photo_group_month':
      'Bulan',
  'enum.photo_group_year':
      'Tahun',
  'enum.open_with_ask':
      'Tanya setiap kali',
  'enum.open_with_in_app':
      'Pemutar dalam aplikasi',
  'enum.open_with_external':
      'Aplikasi lain',
  'enum.open_with_ask_desc':
      'Anda akan ditanya aplikasi mana yang dipakai saat membuka video/audio/gambar',
  'enum.open_with_in_app_desc':
      'Berkas dibuka di pemutar aplikasi ini',
  'enum.open_with_external_desc':
      'Pemutar/galeri bawaan ponsel Anda akan terbuka',
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
      'Arsip',
  'enum.cat_apk':
      'Berkas pemasang',
  'enum.cat_other':
      'Lainnya',
  'enum.sort_name':
      'Menurut nama',
  'enum.sort_date':
      'Menurut tanggal',
  'enum.sort_size':
      'Menurut ukuran',
  'enum.sort_type':
      'Menurut jenis',
  'enum.doc_pdf':
      'PDF',
  'enum.doc_text':
      'Teks',
  'enum.doc_spreadsheet':
      'Excel',
  'enum.doc_word':
      'Word',
  'enum.doc_slides':
      'Slide',
  'enum.doc_image':
      'Gambar',
  'enum.doc_unknown':
      'Tidak dikenal',
  'enum.bucket_camera':
      'Kamera',
  'enum.bucket_screenshot':
      'Tangkapan layar',
  'enum.bucket_whatsapp':
      'WhatsApp',
  'enum.bucket_telegram':
      'Telegram',
  'enum.bucket_instagram':
      'Instagram',
  'enum.bucket_download':
      'Unduhan',
  'enum.bucket_bluetooth':
      'Bluetooth',
  'enum.bucket_other':
      'Lainnya',
  'enum.dl_queued':
      'Antre',
  'enum.dl_running':
      'Mengunduh',
  'enum.dl_paused':
      'Dijeda',
  'enum.dl_completed':
      'Selesai',
  'enum.dl_failed':
      'Gagal',
  'enum.dl_canceled':
      'Dibatalkan',
  'enum.age_fresh':
      'baru',
  'enum.age_recent':
      'bulan ini',
  'enum.age_old':
      'lama',
  'enum.age_ancient':
      'sangat lama',
  'enum.age_unknown':
      'tidak diketahui',
  'enum.date_any':
      'Kapan saja',
  'enum.date_today':
      'Hari ini',
  'enum.date_week':
      '7 hari terakhir',
  'enum.date_month':
      '30 hari terakhir',
  'enum.date_year':
      'Tahun lalu',
  'enum.date_custom':
      'Rentang kustom',
  'enum.size_any':
      'Semua',
  'enum.size_tiny':
      'Di bawah 1 MB',
  'enum.size_small':
      '1 – 10 MB',
  'enum.size_medium':
      '10 – 100 MB',
  'enum.size_large':
      'Di atas 100 MB',
  'enum.chat_image':
      'Gambar',
  'enum.chat_video':
      'Video',
  'enum.chat_document':
      'Dokumen',
  'enum.chat_audio':
      'Audio',
  'enum.chat_voice':
      'Pesan suara',
  'enum.chat_sticker':
      'Stiker',
  'enum.chat_gif':
      'Animasi (GIF)',
  'enum.chat_other':
      'Lainnya',
  'enum.chat_dir_any':
      'Semua',
  'enum.chat_dir_received':
      'Diterima',
  'enum.chat_dir_sent':
      'Terkirim',
  'enum.res_keep':
      'Biarkan apa adanya',
  'enum.res_480':
      '480p',
  'enum.res_540':
      '540p',
  'enum.res_720':
      '720p (HD)',
  'enum.res_1080':
      '1080p (Full HD)',
  'enum.res_percent':
      'Persen',
  'enum.res_custom':
      'Piksel (lebar × tinggi)',
  'enum.imgfmt_keep':
      'Tetap sama',
  'enum.imgfmt_jpeg':
      'JPEG (kecil)',
  'enum.imgfmt_png':
      'PNG (tanpa kehilangan)',
  'enum.imgfmt_webp':
      'WebP (terkecil)',
  'enum.vq_very_low':
      'Berkas terkecil',
  'enum.vq_low':
      'Kecil',
  'enum.vq_medium':
      'Seimbang',
  'enum.vq_high':
      'Kualitas tinggi',
  'enum.doc_invoice':
      'Faktur',
  'enum.doc_receipt':
      'Kuitansi',
  'enum.doc_id':
      'KTP / dokumen resmi',
  'enum.doc_health':
      'Dokumen kesehatan',
  'enum.doc_bank':
      'Bank / keuangan',
  'enum.doc_contract':
      'Kontrak',
  'enum.doc_education':
      'Pendidikan / catatan',
  'enum.doc_screenshot':
      'Tangkapan layar',
  'enum.doc_ticket':
      'Tiket / pemesanan',
  'enum.doc_other':
      'Lainnya',
  'enum.org_type':
      'Menurut jenis',
  'enum.org_date':
      'Menurut tanggal',
  'enum.org_source':
      'Menurut sumber',
  'enum.org_type_desc':
      'Gambar, Video, Dokumen…',
  'enum.org_date_desc':
      '2026-07, 2026-06…',
  'enum.org_source_desc':
      'Kamera, WhatsApp, Unduhan…',
  'enum.job_queued':
      'Antre',
  'enum.job_running':
      'Berjalan',
  'enum.job_done':
      'Selesai',
  'enum.job_failed':
      'Gagal',
  'enum.job_cancelled':
      'Dibatalkan',
  'enum.job_interrupted':
      'Terputus',
  'enum.sim_strict':
      'Sangat ketat',
  'enum.sim_normal':
      'Normal',
  'enum.sim_loose':
      'Longgar',
  'enum.sim_strict_desc':
      'Gambar yang hampir identik (salinan dikompresi ulang).',
  'enum.sim_normal_desc':
      'Gambar yang sama dengan ukuran diubah, dikodekan ulang, atau dipangkas ringan.',
  'enum.sim_loose_desc':
      'Juga mencocokkan jepretan berturut-turut dari adegan yang sama; kecocokan palsu mungkin terjadi.',
  'enum.op_move':
      'Pindahkan',
  'enum.op_copy':
      'Salin',
  'enum.op_delete':
      'Hapus',
  'enum.op_rename':
      'Ganti nama',
  'enum.op_organize':
      'Atur otomatis',
  'wp.tab':
      'Alat',
  'wp.failed':
      'Tidak dapat menyelesaikan: {error}',
  'wp.style_update':
      'Perbarui gaya',
  'wp.style_updated':
      'Gaya diperbarui agar sesuai dengan pilihan',
  'wp.theme':
      'Tema dokumen',
  'wp.theme_applied':
      'Tema diterapkan',
  'wp.page_setup':
      'Pengaturan halaman',
  'wp.page_applied':
      'Pengaturan halaman diterapkan',
// ── wp-pse-mp ──
  'wp.print_preview':
      'Pratinjau cetak',
  'wp.custom':
      'Kustom',
  'wp.title_page':
      'Halaman pertama berbeda',
  'wp.equation':
      'Persamaan',
  'wp.equation_edit':
      'Edit persamaan',
  'wp.equation_latex':
      'Persamaan (LaTeX)',
  'wp.tbl_merge':
      'Gabungkan',
  'wp.tbl_merge_right':
      'Dengan sel di kanan',
  'wp.tbl_merge_down':
      'Dengan sel di bawah',
  'wp.tbl_borders':
      'Garis tepi',
  'wp.tbl_b_all':
      'Semua garis tepi',
  'wp.tbl_b_outer':
      'Garis tepi luar',
  'wp.tbl_b_inner':
      'Garis tepi dalam',
  'wp.tbl_b_none':
      'Tanpa garis tepi',
  'wp.tbl_autofit':
      'Sesuaikan otomatis',
  'wp.tbl_fit_content':
      'Sesuaikan dengan isi',
  'wp.tbl_fit_window':
      'Sesuaikan dengan jendela',
  'wp.tbl_fit_fixed':
      'Kolom sama lebar tetap',
  'wp.tbl_sort':
      'Urutkan',
  'wp.tbl_sort_asc_h':
      'A→Z (pertahankan baris judul)',
  'wp.tbl_sort_desc_h':
      'Z→A (pertahankan baris judul)',
  'wp.tbl_sort_asc':
      'A→Z (semua baris)',
  'wp.tbl_sort_desc':
      'Z→A (semua baris)',
  'wp.tbl_err_no_table':
      'Kursor tidak berada di dalam sel tabel',
  'wp.compare_done':
      'Perbedaan dari versi lama ditandai sebagai perubahan terlacak',
  'wp.compare_encrypted':
      'Dokumen yang dipilih dilindungi kata sandi',
  'wp.combine_done':
      'Dokumen disisipkan setelah kursor',
  'wp.review_none':
      'Tidak ada komentar atau perubahan terlacak',
  'wp.review_comment':
      'Komentar',
  'wp.review_prev':
      'Sebelumnya',
  'wp.review_next':
      'Berikutnya',
  'wp.password':
      'Kata sandi dokumen',
  'wp.password_change':
      'Ubah kata sandi',
  'wp.password_open':
      'Dokumen ini dilindungi kata sandi',
  'wp.password_unsupported':
      'Jenis enkripsi ini tidak didukung (Word lama)',
  'wp.dictate_prompt':
      'Bicaralah — teks masuk di posisi kursor',
  'wp.export':
      'Ekspor',
  'wp.textbox':
      'Kotak teks',
  'wp.shape':
      'Bentuk',
  'wp.cover':
      'Halaman sampul',
  'wp.toc_title':
      'Daftar isi',
  'wp.toc_none':
      'Tidak ada judul — gunakan gaya Judul 1–3 untuk daftar isi',
  'wp.toc_done':
      'Daftar isi diperbarui',
  'wp.section_break':
      'Pemisah bagian',
  'wp.field':
      'Bidang',
  'wp.cross_ref':
      'Referensi silang',
  'wp.bibliography':
      'Daftar pustaka',
  'wp.para_border':
      'Garis tepi',
  'wp.outline':
      'Panel navigasi',
  'wp.thumbnails':
      'Gambar mini halaman',
  'wp.stats':
      'Jumlah dan waktu baca',
  'wp.export_pdf':
      'PDF (font disematkan)',
  'wp.export_docx_fonts':
      'Word dengan font tersemat (.docx)',
  'wp.export_save':
      'Simpan ke Unduhan',
  'wp.stats_pages':
      'Halaman (perkiraan)',
  'wp.stats_headings':
      'Judul',
  'wp.stats_reading':
      'Waktu baca',
  'wp.stats_speaking':
      'Waktu bicara',
  'wp.stats_selection':
      'Kata dalam pilihan',
  'wp.stats_min':
      '{n} mnt',
  'wp.stats_under_min':
      'Kurang dari 1 mnt',
  'wp.bdr_box':
      'Kotak',
  'wp.bdr_top':
      'Garis atas',
  'wp.bdr_bottom':
      'Garis bawah',
  'wp.bdr_shade':
      'Arsiran abu-abu',
  'wp.bdr_none':
      'Tanpa garis tepi',
  'wp.textbox_text':
      'Teks dalam kotak',
  'wp.img_wrap':
      'Bungkus teks',
  'wp.cover_title':
      'Judul',
  'wp.cover_subtitle':
      'Subjudul',
  'wp.cover_author':
      'Penulis',
  'wp.cover_date':
      'Tanggal',
  'wp.cover_done':
      'Halaman sampul ditambahkan di awal',
  'wp.sb_next':
      'Halaman berikutnya',
  'wp.sb_cont':
      'Berkelanjutan',
  'wp.sb_even':
      'Halaman genap',
  'wp.sb_odd':
      'Halaman ganjil',
  'wp.sb_done':
      'Pemisah bagian disisipkan',
  'wp.xref_text':
      'Teks judul',
  'wp.xref_page':
      'Nomor halaman',
  'wp.xref_above':
      'Atas / bawah',
  'wp.xref_is_above':
      'di atas',
  'wp.xref_is_below':
      'di bawah',
  'wp.src_author':
      'Penulis (Belakang, Depan)',
  'wp.src_year':
      'Tahun',
  'wp.src_title':
      'Judul',
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
      'Luaskan / ciutkan',
  'pse.step_paragraph':
      'Paragraf diedit',
  'pse.refused_glyph':
      'Font dokumen tidak memiliki sebagian huruf ini; paragraf tidak diubah.',
  'pse.refused':
      'Paragraf ini tidak dapat diedit di versi ini; dokumen tidak diubah.',
  'pse.undo_failed':
      'Tidak dapat mengurungkan; dokumen tidak berubah.',
  'pse.save_as_docs':
      'Salinan di Dokumen',
  'pse.readonly_fallback':
      'Lokasi ini tidak dapat ditulis. Salinan disimpan di Dokumen: {name}',
  'pse.save_failed':
      'Tidak dapat menyimpan: {error}',
  'pse.version_failed':
      'Tidak dapat memulihkan versi: {error}',
  'pse.recover_none':
      'Suntingan tidak dapat diterapkan ulang pada dokumen ini.',
  'pse.locked_body':
      'Pemilik dokumen membatasi perubahan pada isinya. Pengeditan memerlukan kata sandi pemilik.',
  'pse.owner_wrong':
      'Itu bukan kata sandi pemilik dokumen ini.',
  'pse.comment_reopen':
      'Buka kembali',
  'pse.comment_resolve':
      'Tandai selesai',
  'pse.crop_bottom':
      'Bawah',
  'pse.crop_left':
      'Kiri',
  'pse.crop_right':
      'Kanan',
  'pse.crop_top':
      'Atas',
  'pse.step_push':
      'Teks di bawah digeser ke bawah',
  'pse.step_link':
      'Tautan diubah',
  'pse.font_kind_doc':
      'Font di dokumen ini',
  'pse.font_kind_match':
      'Paling mirip dengan font dokumen',
  'pse.font_kind_pkg':
      'Font di aplikasi',
  'pse.obj_align_left':
      'Rata kiri',
  'pse.obj_align_hcenter':
      'Tengah secara horizontal',
  'pse.obj_align_right':
      'Rata kanan',
  'pse.obj_align_top':
      'Rata atas',
  'pse.obj_align_vcenter':
      'Tengah secara vertikal',
  'pse.obj_align_bottom':
      'Rata bawah',
  'pse.obj_distribute_h':
      'Distribusikan horizontal',
  'pse.obj_distribute_v':
      'Distribusikan vertikal',
  'pse.step_align':
      'Diratakan',
  'pse.locked_ocr':
      'Teks ini adalah lapisan pengenalan tak terlihat dari halaman hasil pindai; tulisannya sendiri berupa gambar. Jika Anda menggantinya, tulisan lama ditutup dengan warna kertas dan teks yang dikenali masuk ke kotak yang dapat diedit.',
  'pse.ocr_ai_failed':
      'AI tidak dapat membacanya; teks hasil pengenalan di perangkat dipakai.',
  'pse.step_ocr_replace':
      'Tulisan hasil pindai diganti',
  'pse.locked_rtl':
      'Teks kanan-ke-kiri (Arab, Ibrani) belum dapat diedit langsung: penyambungan huruf akan rusak. Anda dapat menambahkan kotak teks di atasnya.',
  'pse.mk_arrow':
      'Panah',
  'pse.mk_ellipse':
      'Elips',
  'pse.mk_eraser':
      'Penghapus',
  'pse.mk_highlight':
      'Sorot',
  'pse.mk_ink':
      'Pena',
  'pse.mk_marker':
      'Spidol',
  'pse.mk_cloud':
      'Awan',
  'pse.step_stamp':
      'Stempel ditambahkan',
  'pse.step_freetext':
      'Teks ditambahkan',
  'pse.step_cloud':
      'Awan ditambahkan',
  'pse.mk_line':
      'Garis',
  'pse.mk_other':
      'Anotasi',
  'pse.mk_rect':
      'Persegi panjang',
  'pse.mk_squiggly':
      'Bergelombang',
  'pse.mk_strikeout':
      'Coret',
  'pse.mk_underline':
      'Garis bawah',
  'pse.mode_line':
      'Mode baris',
  'pse.mode_paragraph':
      'Mode paragraf',
  'pse.step_crop':
      'Gambar dipangkas',
  'pse.step_delete':
      'Dihapus',
  'pse.step_duplicate':
      'Diduplikasi',
  'pse.step_flatten':
      'Anotasi diratakan',
  'pse.step_format':
      'Pemformatan diubah',
  'pse.step_image':
      'Gambar ditambahkan',
  'pse.step_image_replace':
      'Gambar diganti',
  'pse.step_ink':
      'Gambar tangan ditambahkan',
  'pse.step_list':
      'Daftar diubah',
  'pse.step_markup':
      'Markah',
  'pse.step_markup_remove':
      'Markah dihapus',
  'pse.step_move':
      'Dipindahkan',
  'pse.step_note':
      'Catatan',
  'pse.step_order':
      'Urutan diubah',
  'pse.step_paste':
      'Ditempel',
  'pse.step_replace':
      'Cari dan ganti',
  'pse.step_resize':
      'Ukuran diubah',
  'pse.step_rotate':
      'Diputar',
  'pse.step_shape':
      'Bentuk ditambahkan',
  'pse.step_textbox':
      'Kotak teks ditambahkan',
  'pse.tool_image':
      'Gambar',
  'pse.tool_markup':
      'Markah',
  'pse.tool_text':
      'Teks',
  'pse.kvkk_custom':
      'Kata kustom',
  'pse.kvkk_email':
      'Email',
  'pse.kvkk_iban':
      'IBAN',
  'pse.kvkk_phone':
      'Telepon',
  'pse.kvkk_tckn':
      'Nomor KTP Turki',
  'pse.step_redact':
      'Disamarkan',
  'pse.shapes':
      'Bentuk',
  'pse.text_lines':
      'Baris teks',
  'pse.stroke_thin':
      'Tipis',
  'pse.stroke_medium':
      'Sedang',
  'pse.stroke_thick':
      'Tebal',
  'pse.stroke_bold':
      'Sangat tebal',
  'pse.mode_label_para':
      'Mode: Paragraf',
  'pse.mode_label_line':
      'Mode: Baris',
  'pse.size_reset':
      'Asli',
  'mp.playlist_save':
      'Simpan daftar putar',
  'mp.playlist_open':
      'Buka daftar putar',
  'mp.playlist_saved':
      '{name} disimpan',
  'mp.playlist_loaded':
      '{n} lagu dimuat ({missing} hilang)',
  'mp.playlist_empty':
      'Tidak ada berkas yang dapat diputar dalam daftar',
  'mp.playlist_name':
      'Nama daftar putar',
};
