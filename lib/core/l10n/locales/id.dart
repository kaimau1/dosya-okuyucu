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
      'Tidak lebih kecil ({size}) — file asli tetap disimpan',
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
// ── mp-nas-fmset ──
  'mp.auto_next':
      'Putar berikutnya otomatis',
  'mp.auto_next_on':
      'Putar berikutnya otomatis aktif',
  'mp.auto_next_off':
      'Putar berikutnya otomatis nonaktif',
  'mp.loop_mark_a':
      'Ulang A-B: tandai A',
  'mp.loop_mark_b':
      'Ulang A-B: tandai B',
  'mp.loop_off':
      'Hapus ulang A-B',
  'mp.loop_a_set':
      'Titik awal (A) ditandai',
  'mp.loop_on':
      'Ulang A-B aktif — rentang terus berulang.',
  'mp.loop_cleared':
      'Ulang A-B dihapus',
  'mp.lock':
      'Kunci kontrol',
  'mp.rotate_right':
      'Putar ke kanan',
  'mp.rotate_left':
      'Putar ke kiri',
  'mp.unlock':
      'Buka kunci',
  'mp.sec_player':
      'Pemutar',
  'mp.float_window':
      'Putar dalam gambar-dalam-gambar',
  'mp.float_failed':
      'Perangkat ini tidak mendukung gambar-dalam-gambar.',
  'mp.zoom_fill':
      'Penuhi layar',
  'mp.zoom_fit':
      'Sesuaikan dengan layar',
  'mp.resumed_at':
      'Melanjutkan dari {time}',
  'mp.restart':
      'Mulai dari awal',
  'mp.sleep_timer':
      'Pengatur waktu tidur',
  'mp.sleep_off':
      'Mati',
  'mp.sleep_minutes':
      '{n} menit',
  'mp.sleep_active':
      'Berhenti dalam {time}',
  'mp.audio_failed':
      'Berkas audio ini tidak dapat diputar: {error}',
  'mp.channel_name':
      'Pemutar musik',
  'mp.channel_desc':
      'Notifikasi untuk audio yang diputar di latar belakang',
  'mp.play':
      'Putar',
  'mp.pause':
      'Jeda',
  'mp.next':
      'Berikutnya',
  'mp.previous':
      'Sebelumnya',
  'mp.now_playing':
      'Sedang diputar',
  'mp.speed':
      'Kecepatan',
  'mp.back10':
      'Mundur 10 dtk',
  'mp.forward10':
      'Maju 10 dtk',
  'mp.portrait':
      'Potret',
  'mp.fullscreen':
      'Layar penuh (lanskap)',
  'mp.next_page':
      'Halaman berikutnya',
  'mp.play_speed':
      'Kecepatan pemutaran',
  'mp.speed_reset':
      'Setel ulang ke 1×',
  'mp.subtitles':
      'Subjudul',
  'mp.sub_off':
      'Subjudul mati',
  'mp.engine_mpv':
      'Buka dengan mesin lanjutan (mpv — semua codec)',
  'mp.engine_exo':
      'Kembali ke mesin standar (ExoPlayer)',
  'mp.audio_track_n':
      'Audio {n}',
  'mp.sub_online':
      'Cari online (OpenSubtitles)…',
  'mp.sub_online_none':
      'Subjudul untuk video ini tidak ditemukan.',
  'mp.sub_online_failed':
      'Tidak dapat mengambil subjudul: {error}',
  'mp.sub_exact':
      'Cocok persis dengan berkas ini',
  'mp.sub_bigger':
      'Subjudul lebih besar',
  'mp.sub_smaller':
      'Subjudul lebih kecil',
  'mp.sub_pick':
      'Pilih berkas subjudul…',
  'mp.sub_earlier':
      'Majukan subjudul 0,5 dtk lebih awal',
  'mp.sub_later':
      'Tunda subjudul 0,5 dtk',
  'mp.sub_offset':
      'Offset: {v} dtk',
  'mp.sub_unreadable':
      'Tidak dapat membaca berkas subjudul.',
  'mp.open_with':
      'Buka dengan aplikasi lain',
  'mp.file_ops':
      'Operasi berkas (pindah, salin, bagikan…)',
  'mp.shuffle':
      'Acak',
  'mp.repeat_off':
      'Ulangi: mati',
  'mp.repeat_one':
      'Ulangi: lagu ini',
  'mp.repeat_all':
      'Ulangi: semua',
  'mp.video_failed':
      'Berkas ini tidak dapat diputar. Perangkat Anda mungkin tidak mendukung codec ini — coba “Buka dengan aplikasi lain”.\n\n{error}',
  'nas.ftp_plain_warning':
      'FTP biasa tidak dienkripsi: kata sandi dan berkas Anda dikirim terbuka. Pilih FTPES atau SFTP jika server mendukungnya.',
  'nas.webdav_http_warning':
      'http:// tidak dienkripsi: kata sandi Anda dikirim terbuka. Gunakan hanya di jaringan rumah; pilih https:// di internet.',
  'nas.title':
      'Penyimpanan jaringan',
  'nas.empty':
      'Belum ada koneksi tersimpan. Tambahkan server secara manual atau pindai jaringan.',
  'nas.add':
      'Tambah koneksi',
  'nas.edit':
      'Edit koneksi',
  'nas.scan':
      'Pindai jaringan',
  'nas.scanning':
      'Memindai jaringan…',
  'nas.scan_none':
      'Server tidak ditemukan. Apakah server dan ponsel berada di jaringan Wi-Fi YANG SAMA?',
  'nas.scan_found':
      '{n} server ditemukan',
  'nas.protocol':
      'Protokol',
  'nas.name':
      'Nama',
  'nas.name_hint':
      'NAS Rumah',
  'nas.host':
      'Alamat server',
  'nas.host_hint':
      '192.168.1.10',
  'nas.webdav_host_hint':
      'https://server/dav',
  'nas.port':
      'Port',
  'nas.user':
      'Nama pengguna',
  'nas.password':
      'Kata sandi',
  'nas.domain':
      'Domain / grup kerja',
  'nas.initial_path':
      'Folder awal',
  'nas.save_password':
      'Simpan kata sandi',
  'nas.save_password_note':
      'Kata sandi disimpan terenkripsi dengan kunci yang terikat pada perangkat. Jika dimatikan, kata sandi ditanyakan setiap kali terhubung.',
  'nas.unprotected_note':
      'Penyimpanan kunci aman tidak berfungsi di perangkat ini: kata sandi tersimpan tanpa perlindungan.',
  'nas.password_prompt':
      'Kata sandi untuk “{name}”',
  'nas.test':
      'Uji koneksi',
  'nas.test_ok':
      'Koneksi berhasil.',
  'nas.connecting':
      'Menghubungkan…',
  'nas.delete_confirm':
      'Hapus koneksi “{name}”? (Berkas di server tidak disentuh.)',
  'nas.upload_here':
      'Unggah ke sini',
  'nas.uploading':
      'Mengunggah…',
  'nas.upload_done':
      'Terunggah.',
  'nas.new_folder':
      'Folder baru',
  'nas.folder_name':
      'Nama folder',
  'nas.smb1_title':
      'Protokol SMB1 lawas',
  'nas.smb1_body':
      '{host} hanya mendukung SMB1. SMB1 sudah usang dan tidak aman: kata sandi dan berkas lebih mudah disadap. Izinkan hanya di jaringan rumah tepercaya.',
  'nas.smb1_allow':
      'Tetap hubungkan',
  'nas.copy_to_phone':
      'Salin ke ponsel',
  'nas.copied_to_phone':
      'Disalin ke Download/Dosya Okuyucu',
  'nas.copy_only_files':
      'Hanya berkas yang dapat disalin (sebuah folder dipilih).',
  'nas.copy_skipped_dirs':
      'folder dilewati',
  'nas.copying':
      'Menyalin',
  'nas.filter_hint':
      'Saring folder ini',
  'nas.no_match':
      'Tidak ada berkas yang cocok.',
  'nas.delete_many':
      'Hapus {n} item?',
  'nas.sort_ascending':
      'Menaik',
  'nas.rename':
      'Ganti nama',
  'nas.new_name':
      'Nama baru',
  'nas.empty_folder':
      'Folder ini kosong.',
  'nas.smb_share_root':
      'Berbagi — buka satu berbagi untuk melihat berkasnya.',
  'nas.error_unreachable':
      'Tidak dapat menjangkau server. Periksa alamat, port, dan pastikan Anda berada di jaringan yang sama.',
  'nas.error_auth':
      'Nama pengguna atau kata sandi ditolak.',
  'nas.error_not_found':
      'Folder atau berkas tidak ditemukan.',
  'nas.error_denied':
      'Server menolak akses.',
  'nas.error_unsupported':
      'Server tidak mendukung versi protokol ini. Coba SFTP atau FTP.',
  'nas.error_hostkey':
      'Identitas server tidak dikonfirmasi atau telah berubah. Koneksi diputus.',
  'nas.error_insecure':
      'Koneksi tidak aman diblokir: kata sandi Anda tidak pernah dikirim tanpa enkripsi lewat internet atau ke server pengalihan. Gunakan alamat https://.',
  'nas.hostkey_new_title':
      'Server baru',
  'nas.hostkey_new_body':
      'Anda terhubung ke {host}:{port} untuk pertama kali.\n\n{type}\n{fp}\n\nPercayai jika sidik jarinya sama dengan yang ditampilkan NAS Anda.',
  'nas.hostkey_changed_title':
      'Identitas server BERUBAH',
  'nas.hostkey_changed_body':
      'Kunci {host}:{port} telah berubah. Mungkin ada yang menyadap.\n\nLama: {old}\nBaru: {fp}\n\nJANGAN terhubung kecuali Anda memasang ulang server.',
  'nas.hostkey_trust':
      'Percayai',
  'nas.error_unknown':
      'Kesalahan koneksi.',
  'nas.smb_warning':
      'SMB telah diuji dengan berbagi Samba/Windows (SMB2) dan berfungsi. Server yang hanya mewajibkan SMB3 mungkin tidak terhubung; dalam hal itu coba SFTP atau FTP pada server yang sama. Port selalu 445 dan tidak dapat diubah.',
  'nas.writeback_title':
      'Unggah perubahan ke server?',
  'nas.writeback_body':
      '“{name}” telah diedit. Perubahan baru ada di salinan sementara di ponsel; berkas di server masih yang lama. Mengunggah MENIMPA versi di server.',
  'nas.writeback_upload':
      'Unggah',
  'nas.writeback_keep_local':
      'Jangan unggah dulu',
  'nas.writeback_done':
      'Terunggah ke server.',
  'fmset.folder_sizes':
      'Ukuran folder di daftar',
  'fmset.folder_sizes_sub':
      'Folder yang terlihat diukur di latar belakang; pohon besar butuh waktu lebih lama.',
  'fmset.resume':
      'Lanjutkan dari terakhir dibuka',
  'fmset.resume_sub':
      'Ingat posisi pemutaran dan halaman dokumen.',
  'fmset.audio_bg':
      'Tetap putar audio di latar belakang',
  'fmset.audio_bg_sub':
      'Jika mati, musik berhenti saat Anda keluar dari aplikasi atau mengunci layar.',
  'fmset.start_folder':
      'Folder awal',
  'fmset.start_folder_none':
      'Aplikasi terbuka di dasbor',
  'fmset.start_folder_pick':
      'Buka ini saat mulai',
  'fmset.start_folder_clear':
      'Hapus folder awal',
  'fmset.sec_privacy':
      'Privasi',
  'fmset.sec_delete':
      'Penghapusan',
  'fmset.sec_permissions':
      'Izin',
  'fmset.sec_maintenance':
      'Pemeliharaan',
  'fmset.list_layout':
      'Tata letak daftar berkas',
  'fmset.photo_grid':
      'Kisi foto',
  'fmset.grid_density':
      'Kepadatan kisi',
  'fmset.grouping':
      'pengelompokan',
  'fmset.show_hidden':
      'Tampilkan berkas tersembunyi',
  'fmset.show_hidden_sub':
      'Nama yang diawali titik (seperti .thumbnails)',
  'fmset.thumbnails':
      'Gambar mini',
  'fmset.thumbnails_sub':
      'Pratinjau gambar dan video (matikan di perangkat lambat)',
  'fmset.default_sort':
      'Urutan bawaan',
  'fmset.reverse_dir':
      'Balik arah',
  'fmset.group_photos':
      'Kelompokkan foto',
  'fmset.group_photos_sub':
      'Dikelompokkan menurut {unit}',
  'fmset.media_open_with':
      'Buka video, audio, dan gambar dengan',
  'fmset.index':
      'Indeks pencarian',
  'fmset.index_building':
      'Membangun…',
  'fmset.index_none':
      'Belum dibangun — dibangun saat pencarian pertama atau setelah pemindaian',
  'fmset.index_stale':
      ' · berkas berubah, perlu disegarkan',
  'fmset.index_ready':
      '{n} catatan · {date}{stale}',
  'fmset.index_failed':
      'Indeks tidak dapat dibangun (izin penyimpanan mungkin tidak ada).',
  'fmset.index_built':
      'Indeks pencarian dibangun · {n} catatan.',
  'fmset.pin_change':
      'Ubah PIN kunci folder',
  'fmset.pin_set':
      'Atur PIN kunci folder',
  'fmset.pin_sub_locked':
      '{n} folder terkunci · untuk mengunci, gunakan ⋮ > “Kunci folder” di folder',
  'fmset.pin_sub_unset':
      'Folder terkunci disembunyikan dari daftar dan galeri. Berkas TIDAK dienkripsi — hanya disembunyikan di dalam aplikasi ini.',
  'fmset.pin_remove':
      'Hapus kunci sepenuhnya',
  'fmset.pin_remove_sub':
      'PIN dihapus dan semua folder dibuka kuncinya.',
  'fmset.unlock':
      'Buka kunci',
  'fmset.use_trash':
      'Gunakan tempat sampah',
  'fmset.use_trash_sub':
      'Jika mati, berkas langsung dihapus permanen (tidak dapat dibatalkan)',
  'fmset.confirm_delete':
      'Tanya sebelum menghapus',
  'fmset.trash_auto':
      'Kosongkan tempat sampah otomatis',
  'fmset.trash_auto_off':
      'Mati — tempat sampah dikosongkan manual',
  'fmset.trash_auto_on':
      'Item lebih lama dari {n} hari dihapus',
  'fmset.off':
      'Mati',
  'fmset.days':
      '{n} hari',
  'fmset.empty_trash_now':
      'Kosongkan tempat sampah sekarang',
  'fmset.trash_empty':
      'Tempat sampah kosong',
  'fmset.trash_summary':
      '{n} item · {size}',
  'fmset.empty_confirm_title':
      'Kosongkan tempat sampah?',
  'fmset.empty_confirm_body':
      '{n} item ({size}) akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
  'fmset.empty':
      'Kosongkan',
  'fmset.emptying':
      'Mengosongkan tempat sampah',
  'fmset.empty_partial':
      '{ok} item dihapus, {fail} tidak dapat dihapus.',
  'fmset.empty_cancelled':
      'Dihentikan — {ok} item dihapus.',
// ── fmset-drive-set-sdu ──
  'fmset.empty_done':
      'Tempat sampah dikosongkan · {ok} item · {size} dibebaskan.',
  'fmset.full_access':
      'Akses semua berkas',
  'fmset.usage_access':
      'Akses penggunaan',
  'fmset.usage_access_on':
      'Diberikan — tanggal terakhir dibuka aplikasi terlihat',
  'fmset.usage_access_off':
      'Belum diberikan — tanggal tidak dapat ditampilkan di layar “Aplikasi”',
  'fmset.grant':
      'Berikan',
  'fmset.clear_thumbs':
      'Hapus cache gambar mini',
  'fmset.volumes':
      'Volume',
  'fmset.volumes_none':
      'Tidak ditemukan',
  'drive.title':
      'Google Drive',
  'drive.upload_action':
      'Unggah ke Drive',
  'drive.sign_in':
      'Hubungkan dengan Google',
  'drive.sign_out':
      'Putuskan',
  'drive.sign_in_prompt':
      'Hubungkan akun Google Anda untuk menelusuri Drive di sini, membuka dan mengunggah berkas, serta mengatur folder.',
  'drive.root':
      'Drive Saya',
  'drive.new_folder':
      'Folder baru',
  'drive.new_folder_default':
      'Folder baru',
  'drive.new_folder_failed':
      'Tidak dapat membuat folder.',
  'drive.rename':
      'Ganti nama',
  'drive.rename_failed':
      'Tidak dapat mengganti nama.',
  'drive.empty':
      'Folder ini kosong.',
  'drive.empty_search':
      'Tidak ada berkas yang cocok.',
  'drive.search_hint':
      'Cari di Drive…',
  'drive.exports_as':
      'diunduh sebagai {format}',
  'drive.uploading':
      'Mengunggah ke Drive…',
  'drive.upload_name':
      'Unggah ke Drive',
  'drive.upload_done':
      'Terunggah ke Drive:',
  'drive.upload_failed':
      'Gagal mengunggah ke Drive.',
  'drive.download_failed':
      'Tidak dapat mengunduh berkas.',
  'drive.downloading':
      'Mengunduh dari Drive…',
  'drive.ready_offscreen':
      'Terunduh — ketuk untuk membuka:',
  'drive.download_stopped':
      'Unduhan dihentikan.',
  'drive.delete_confirm':
      'Pindahkan “{name}” ke tempat sampah Drive?',
  'drive.delete_failed':
      'Tidak dapat menghapus.',
  'drive.download':
      'Unduh ke ponsel…',
  'drive.download_here':
      'Unduh ke sini',
  'drive.downloaded':
      'Diunduh ke: {folder}',
  'drive.star':
      'Beri bintang',
  'drive.unstar':
      'Hapus bintang',
  'drive.star_failed':
      'Tidak dapat mengubah bintang.',
  'drive.info':
      'Detail',
  'drive.info_kind':
      'Jenis',
  'drive.info_size':
      'Ukuran',
  'drive.info_modified':
      'Diubah',
  'drive.info_created':
      'Dibuat',
  'drive.info_owner':
      'Pemilik',
  'drive.info_shared':
      'Berbagi',
  'drive.info_starred':
      'Berbintang',
  'drive.shared_yes':
      'Dibagikan ke orang lain',
  'drive.shared_no':
      'Hanya Anda',
  'drive.sort':
      'Urutkan',
  'drive.folder':
      'Folder',
  'drive.share_link':
      'Bagikan tautan',
  'drive.share_file':
      'Bagikan berkas',
  'drive.share_failed':
      'Tidak dapat membuat tautan berbagi.',
  'drive.paste_failed':
      'Tidak dapat menempel.',
  'drive.copy_tag':
      'salinan',
  'drive.error_not_signed_in':
      'Anda belum terhubung ke akun Google.',
  'drive.error_not_configured':
      'Masuk Google tidak diaktifkan untuk APK ini. Akun tidak dapat dihubungkan sebelum tanda tangan aplikasi didaftarkan di Google Cloud sebagai "Android OAuth client" (aturan Google; tidak dapat diperbaiki lewat kode). Pemilih sistem di bawah berfungsi tanpa pendaftaran itu.',
  'drive.setup_title':
      'Nilai penyiapan satu kali',
  'drive.setup_steps':
      'Masukkan dua nilai di bawah di console.cloud.google.com → APIs & Services → Credentials → OAuth client ID (Android). Jika layar persetujuan OAuth dalam mode "Testing", tambahkan akun Anda sebagai penguji. Detail: docs/GOOGLE-DRIVE-KURULUM.md',
  'drive.setup_package':
      'Nama paket',
  'drive.setup_sha1':
      'SHA-1 penandatanganan',
  'drive.setup_copied':
      'Disalin.',
  'drive.error_no_play_services':
      'Google Play Services tidak ada atau usang di perangkat ini, sehingga masuk Google tidak dapat berjalan. Anda dapat memakai pemilih sistem di bawah.',
  'drive.error_sign_in_failed':
      'Masuk Google tidak dapat diselesaikan.',
  'drive.system_picker_hint':
      'Meski masuk tidak berfungsi, Anda tetap dapat mengakses SEMUA isi Drive: pemilih sistem Android mencantumkan Drive sebagai sumber berkas dan tidak meminta izin apa pun.',
  'drive.open_via_system':
      'Buka berkas Drive dengan pemilih sistem',
  'drive.error_forbidden':
      'Drive menolak operasi ini. Berkas mungkin tidak diunggah dengan aplikasi ini.',
  'drive.error_api_not_enabled':
      'Google Drive API tidak diaktifkan untuk proyek ini. Buka Google Cloud Console → APIs & Services → Library → "Google Drive API" → Enable, lalu coba lagi beberapa menit kemudian.',
  'drive.error_insufficient_scope':
      'Akun terhubung tetapi izin Drive belum diberikan. Putuskan, hubungkan lagi, dan setujui akses Drive di dialog persetujuan.',
  'drive.error_not_found':
      'Berkas tidak ditemukan di Drive.',
  'drive.error_temporary':
      'Drive tidak merespons saat ini, coba lagi sebentar lagi.',
  'drive.error_unknown':
      'Kesalahan koneksi Drive.',
  'drive.downloading_name':
      'Unduhan dari Drive',
  'set.sec_documents':
      'Dokumen',
  'set.sec_network':
      'Jaringan & AI',
  'set.kw_offline':
      'offline internet jaringan pesawat',
  'set.rate_app':
      'Beri nilai aplikasi',
  'set.rate_app_sub':
      'Penilaian Anda membantu tim pengembang kecil berkembang',
  'set.key_valid':
      'Kunci valid · {n} model ditemukan',
  'set.key_invalid':
      'Kunci tidak dapat diverifikasi',
  'set.cat_appearance':
      'Tampilan & bahasa',
  'set.cat_appearance_sub':
      'Tema, font, ukuran teks, dan bahasa antarmuka',
  'set.cat_browsing':
      'Daftar berkas',
  'set.cat_browsing_sub':
      'Tata letak, pengurutan, gambar mini, folder awal',
  'set.cat_ai':
      'Kecerdasan buatan',
  'set.cat_ai_sub':
      'Folder pintar, kunci, dan privasi',
  'set.sec_smart':
      'Folder pintar',
  'set.smart_sort_sub':
      'Hidup/mati, kamera, pengaturan di latar belakang, hanya Wi-Fi, batas harian, perbaikan yang dipelajari',
  'set.smart_on':
      'Aktif · {n} berkas diatur — buka folder pintar',
  'set.smart_off':
      'Mati — aktifkan untuk memberi berkas Anda nama kedua dan kategori',
  'set.smart_pin':
      'PIN untuk folder sensitif',
  'set.smart_pin_none':
      'Folder KTP, kesehatan, bank, dan pajak kini terbuka tanpa PIN — ketuk untuk mengatur PIN',
  'set.smart_pin_on':
      'Folder KTP, kesehatan, bank, dan pajak menanyakan PIN sekali per sesi',
  'set.smart_pin_app':
      'Kunci aplikasi aktif: PIN ditanya saat dibuka, folder tidak bertanya lagi',
  'set.cat_privacy':
      'Privasi & izin',
  'set.cat_privacy_sub':
      'Kunci folder dan izin yang dimiliki aplikasi',
  'set.cat_reading':
      'Membaca & suara',
  'set.cat_reading_sub':
      'Suara ucapan, kecepatan, dan baca cerdas',
  'set.cat_storage':
      'Penyimpanan & kinerja',
  'set.cat_storage_sub':
      'Tempat sampah, konfirmasi hapus, kecepatan, dan perawatan',
  'set.sec_tts':
      'Ucapan',
  'set.tts_voice':
      'Suara dan kecepatan',
  'set.tts_voice_sub':
      'Pilih dari suara di perangkat Anda, atur kecepatan dan nada (dengan pratinjau)',
  'set.tts_default_voice':
      'Bawaan perangkat',
  'set.tts_summary':
      'Ucapan {x}x',
  'set.tts_ai_read':
      'Baca cerdas',
  'set.tts_ai_read_sub':
      'Mulai berbicara begitu jawaban tiba',
  'set.sec_advanced':
      'Lanjutan',
  'set.sec_experimental':
      'Eksperimental',
  'set.advanced_hint':
      'Jarang diperlukan — atur sekali',
  'set.trash_off':
      'Hapus permanen',
  'set.refresh_60':
      '60 Hz',
  'set.ai_no_key':
      'Tanpa kunci',
  'set.ai_key_count':
      '{n} kunci',
  'set.api_key_sub':
      'Kunci API Gemini Anda — disimpan di perangkat',
  'set.kw_dark':
      'gelap mode malam',
  'set.kw_font':
      'font jenis huruf ukuran',
  'set.kw_speak':
      'bicara suara tts baca keras',
  'set.kw_gemini':
      'gemini kunci api token',
  'set.kw_days':
      'hari otomatis periode',
  'set.sec_theme':
      'Tema',
  'set.haptics':
      'Umpan balik getar',
  'set.haptics_sub':
      'Getaran ringan saat memilih dan menggulir',
  'set.sec_text':
      'Teks',
  'set.sec_language':
      'Bahasa',
  'set.sec_lists':
      'Daftar',
  'set.sec_photos':
      'Foto',
  'set.sec_opening':
      'Pembukaan',
  'set.sec_key':
      'Akses',
  'set.sec_lock':
      'Kunci folder',
  'set.sec_speed':
      'Kecepatan & baterai',
  'set.sec_ai_scope':
      'Cakupan analisis',
  'set.sec_ai_privacy':
      'Yang keluar dari perangkat',
  'set.hints_reset':
      'Tampilkan tips lagi',
  'set.hints_reset_sub':
      'Tips dan panduan yang ditampilkan sekali akan muncul lagi',
  'set.hints_reset_done':
      'Tips akan ditampilkan lagi',
  'sdu.title':
      'Penyimpanan gabungan dengan kartu SD',
  'sdu.tile_sub':
      'Saat mengisi daya, memindahkan foto dan video lama ke kartu SD untuk mengosongkan penyimpanan internal',
  'sdu.kw':
      'kartu memori microsd pindah cadangan mengisi daya penyimpanan internal penuh ruang kosong',
  'sdu.hero_title':
      'Dua memori, satu penyimpanan',
  'sdu.hero_body':
      'Saat ponsel diisi daya, berkas lama dari folder pilihan Anda dipindahkan ke kartu SD dengan susunan folder yang sama. Berkas tetap tampil bersama di daftar dan galeri, dan penyimpanan internal dikosongkan. Mencabut pengisi daya menghentikan tugas tanpa meninggalkan berkas yang setengah tersalin.',
  'sdu.android_only':
      'Fitur ini hanya berfungsi di Android.',
  'sdu.no_card':
      'Kartu SD tidak terpasang',
  'sdu.no_card_hint':
      'Pasang kartu microSD ke ponsel; kartu akan muncul di sini otomatis.',
  'sdu.card_missing':
      'Kartu SD yang dipilih sedang tidak terpasang. Tugas berlanjut setelah kartu kembali.',
  'sdu.err_readonly':
      'Ponsel ini tidak mengizinkan penulisan langsung ke kartu SD (Android 10 atau lebih lama, atau "Akses semua berkas" mati). Aktifkan izinnya di Pengaturan.',
  'sdu.enable':
      'Jalankan otomatis saat mengisi daya',
  'sdu.enable_sub':
      'Berfungsi meski aplikasi ditutup; tidak menguras baterai dan berhenti saat dicabut.',
  'sdu.sec_status':
      'Status',
  'sdu.sec_target':
      'Target dan mode',
  'sdu.sec_what':
      'Yang dipindahkan',
  'sdu.card_free':
      '{free} kosong · {total}',
  'sdu.mode_move':
      'Pindahkan',
  'sdu.mode_copy':
      'Cadangkan',
  'sdu.mode_move_sub':
      'Berkas pindah ke kartu SD dan mengosongkan penyimpanan internal.',
  'sdu.mode_copy_sub':
      'Berkas tetap di penyimpanan internal dan salinannya disimpan di kartu SD (diperbarui saat berubah).',
  'sdu.folders':
      'Folder',
  'sdu.f_camera':
      'Kamera (DCIM)',
  'sdu.f_pictures':
      'Gambar',
  'sdu.f_movies':
      'Film',
  'sdu.f_music':
      'Musik',
  'sdu.f_download':
      'Unduhan',
  'sdu.f_documents':
      'Dokumen',
  'sdu.f_recordings':
      'Rekaman',
  'sdu.age':
      'Berkas lebih lama dari',
  'sdu.age_all':
      'Semua',
  'sdu.age_days':
      '{n} hari',
  'sdu.preview_wait':
      'Menghitung…',
  'sdu.preview_move':
      '{n} berkas · {size} akan dipindahkan sekarang',
  'sdu.preview_copy':
      '{n} berkas · {size} akan dicadangkan sekarang',
  'sdu.preview_sub':
      'Berkas yang sudah ada di kartu dilewati.',
  'sdu.notify':
      'Beri tahu saat selesai',
  'sdu.rules':
      'Tidak disentuh: folder tersembunyi (.thumbnails), berkas yang diubah dalam 10 menit terakhir, dan media aplikasi obrolan seperti WhatsApp/Telegram — obrolan menyimpan berkas menurut lokasinya sehingga memindahkannya akan merusaknya. Minimal 1 GB dibiarkan kosong di kartu. Jika ada berkas lain dengan nama sama, nama baru dipakai; tidak ada yang ditimpa.',
  'sdu.charging':
      'Mengisi daya',
  'sdu.not_charging':
      'Tidak mengisi daya',
  'sdu.will_run_now':
      'akan segera berjalan',
  'sdu.will_run_charging':
      'berjalan saat dicolok',
  'sdu.never':
      'Belum pernah berjalan.',
  'sdu.running':
      'Memindahkan… {n} berkas · {size} sejauh ini',
  'sdu.last_run':
      'Terakhir berjalan {when}: {n} berkas · {size}',
  'sdu.total':
      'Total: {n} berkas · {size}',
  'sdu.failed_n':
      '{n} berkas tidak dapat dipindahkan (dicoba lagi lain kali).',
  'sdu.err_sd_missing':
      'Kartu SD tidak ditemukan — tugas dilewati.',
  'sdu.err_sd_full':
      'Kartu SD penuh (1 GB dibiarkan kosong) — tugas dihentikan.',
  'sdu.err_stopped':
      'Dijeda karena pengisian daya berhenti atau dihentikan; sisanya dipindahkan nanti.',
  'sdu.run_now_move':
      'Pindahkan sekarang',
  'sdu.run_now_copy':
      'Cadangkan sekarang',
  'sdu.run_started':
      'Dimulai — Anda dapat menutup aplikasi.',
// ── sdu-ied-rs-ss-fm ──
  'sdu.run_failed':
      'Tidak dapat dimulai. Apakah kartu SD terpasang?',
  'sdu.notify_title_move':
      'Dipindahkan ke kartu SD',
  'sdu.notify_title_copy':
      'Dicadangkan ke kartu SD',
  'sdu.notify_body':
      '{n} berkas · {size}',
  'sdu.job_title':
      'Memindahkan ke kartu SD',
  'sdu.job_title_copy':
      'Mencadangkan ke kartu SD',
  'sdu.job_name':
      'Transfer ke kartu SD',
  'ied.title':
      'Edit',
  'ied.crop':
      'Pangkas',
  'ied.adjust':
      'Sesuaikan',
  'ied.markup':
      'Markah',
  'ied.free':
      'Bebas',
  'ied.rotate':
      'Putar',
  'ied.flip':
      'Balik',
  'ied.reset':
      'Setel ulang',
  'ied.pen':
      'Pena',
  'ied.arrow':
      'Panah',
  'ied.text':
      'Teks',
  'ied.text_hint':
      'Teks yang ditambahkan',
  'ied.tap_for_text':
      'Ketuk di tempat teks akan diletakkan',
  'ied.save_copy':
      'Simpan sebagai salinan',
  'ied.save_copy_sub':
      'Berkas asli tetap seperti semula',
  'ied.overwrite':
      'Timpa berkas asli',
  'ied.overwrite_sub':
      'Gambar asli tidak dapat dipulihkan',
  'ied.as_jpeg':
      'Format ini tidak dapat ditulis; disimpan sebagai salinan JPEG',
  'ied.saved':
      '{name} disimpan',
  'ied.original':
      'Asli',
  'ied.custom_ratio':
      'Rasio kustom',
  'ied.ratio_hint':
      'Rasio (mis. 4:5)',
  'ied.ratio_invalid':
      'Tidak dapat membaca rasio — ketik seperti "4:5".',
  'ied.hold_original':
      'Sebelum / sesudah — ketuk atau tahan',
  'ied.size_now':
      'Sekarang {from} → Disimpan sebagai {to}',
  'ied.size_original':
      'Apa adanya',
  'ied.filters':
      'Filter',
  'ied.f_none':
      'Tidak ada',
  'ied.f_vivid':
      'Cerah',
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
      'Dramatis',
  'ied.f_matte':
      'Mat',
  'ied.f_retro':
      'Retro',
  'ied.f_document':
      'Dokumen',
  'ied.strength':
      'Kekuatan',
  'ied.reset_one':
      'Setel ulang ini',
  'ied.flip_v':
      'Balik vertikal',
  'ied.select':
      'Pilih',
  'ied.highlighter':
      'Stabilo',
  'ied.eraser':
      'Penghapus',
  'ied.line':
      'Garis',
  'ied.rect':
      'Persegi panjang',
  'ied.ellipse':
      'Elips',
  'ied.blur':
      'Buramkan',
  'ied.pixelate':
      'Pikselkan',
  'ied.thickness':
      'Ketebalan',
  'ied.opacity':
      'Opasitas',
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
      'Lukis di atas yang ingin disembunyikan (wajah, pelat nomor, nomor identitas) — tidak dapat dipulihkan dari berkas yang disimpan.',
  'ied.zoom_hint':
      'Cubit untuk memperbesar · ketuk dua kali untuk menyesuaikan',
  'rs.presets':
      'Prasetel',
  'rs.preset_profile':
      'Profil 640×640',
  'rs.preset_form':
      'Unggah formulir ≤ 200 KB',
  'rs.preset_share':
      'Sosial 4:5 · 1080',
  'rs.preset_web':
      'Web 1600 px',
  'rs.lock_on':
      'Rasio terkunci — ketuk untuk membuka',
  'rs.lock_off':
      'Rasio bebas — ketuk untuk mengunci',
  'rs.lock_note':
      'Rasio terkunci: ketik satu nilai, yang lain dihitung. Dengan beberapa berkas, masing-masing mempertahankan rasionya.',
  'rs.unlock_note':
      'Rasio bebas: ketik kedua nilai dan pilih bagaimana gambar mengisi kotak.',
  'rs.fit':
      'Bagaimana pas?',
  'rs.aspect_w':
      'Lebar',
  'rs.aspect_h':
      'Tinggi',
  'rs.custom_value':
      'Kustom',
  'rs.long_edge_note':
      'Sisi terpanjang diperkecil ke nilai ini dengan rasio tetap. Foto yang lebih kecil tidak diperbesar.',
  'rs.file_size_note':
      'Disimpan sebagai JPEG; kualitas (dan ukuran bila perlu) disesuaikan otomatis. Jika target tidak tercapai, ukuran terdekat dilaporkan.',
  'rs.upscale_warning':
      'Foto akan diperbesar: ukuran berkas bertambah tetapi ketajaman tidak membaik.',
  'rs.anchor':
      'Pertahankan bagian ini',
  'rs.video_layout_note':
      'Pada video, pemangkasan berpusat dan tepinya hitam.',
  'rs.video_file_size_note':
      'Untuk video, ukuran target menjadi bitrate; target rendah juga menurunkan resolusi. Ukuran sebenarnya dilaporkan setelah selesai.',
  'rs.save_preset':
      'Simpan pengaturan',
  'rs.preset_name':
      'Nama prasetel',
  'rs.preset_delete':
      'Hapus "{name}"?',
  'rs.preset_hint':
      'Tekan dan tahan pengaturan tersimpan untuk menghapusnya.',
  'rs.preview':
      'Pratinjau',
  'rs.strip_location':
      'Hapus lokasi',
  'rs.strip_location_sub':
      'Tanggal dan info kamera dipertahankan. (Keluaran WebP tidak membawa metadata.)',
  'rs.title':
      'Ubah ukuran ({n} berkas)',
  'rs.now':
      'Sekarang',
  'rs.after':
      'Sesudah',
  'rs.fps_value':
      '{n} fps',
  'rs.bitrate':
      '{n} Mbps',
  'rs.no_audio':
      'tanpa suara',
  'rs.estimate':
      'Perkiraan: {before} → ≈ {after}',
  'rs.estimate_gain':
      '≈ {n}% dihemat',
  'rs.estimate_note':
      'Ukuran sebenarnya bergantung pada isi; hasil pastinya muncul saat tugas selesai.',
  'rs.and_more':
      'dan {n} berkas lagi · total {size}',
  'rs.no_change_warning':
      'Pengaturan ini tidak memperkecil berkas ini: resolusi dan frame rate tetap sama. Pilih resolusi atau frame rate yang lebih rendah.',
  'rs.resolution':
      'Resolusi',
  'rs.width':
      'Lebar (px)',
  'rs.height':
      'Tinggi (px)',
  'rs.jpeg_quality':
      'Kualitas JPEG (foto)',
  'rs.format':
      'Format (foto)',
  'rs.video_quality':
      'Kompresi video',
  'rs.fps':
      'Frame rate (fps)',
  'rs.keep':
      'Biarkan apa adanya',
  'rs.video_note':
      'Video selalu dikodekan ulang (meski hanya kualitas atau audio yang berubah): dikonversi tepat ke ukuran yang diminta memakai encoder perangkat keras (Android Media3). Persentase dan sisa waktu ditampilkan di baris tugas. Pada video panjang ini bisa memakan waktu beberapa menit; tugas berjalan di latar belakang.',
  'rs.strip_audio':
      'Hapus audio',
  'rs.strip_audio_sub':
      'Menghemat ruang yang cukup besar pada video yang audionya tidak dibutuhkan.',
  'rs.trash_original':
      'Pindahkan berkas asli ke tempat sampah',
  'rs.trash_original_sub':
      'Jika mati, salinan yang lebih kecil ditulis di folder yang sama sebagai berkas baru dan berkas asli tidak disentuh.',
  'rs.queue_note':
      'Tugas berjalan dalam antrean latar belakang; Anda dapat pindah ke layar lain. Tugas berhenti jika Anda menutup aplikasi sepenuhnya. Berkas yang lebih kecil disimpan di samping aslinya; Anda dapat membuka hasilnya dan berkas yang dibuat dari kotak “Tugas” di layar beranda.',
  'rs.start':
      'Mulai',
  'ss.tools':
      'Alat presenter',
  'ss.prev':
      'Sebelumnya',
  'ss.next':
      'Berikutnya',
  'ss.laser':
      'Penunjuk laser',
  'ss.pen':
      'Pena',
  'ss.pen_color':
      'Warna pena',
  'ss.clear_ink':
      'Hapus coretan',
  'ss.timer':
      'Pengatur waktu',
  'ss.play':
      'Putar',
  'ss.pause':
      'Jeda',
  'ss.stop':
      'Berhenti',
  'ss.presenter':
      'Tampilan presenter',
  'ss.reset_timer':
      'Setel ulang pengatur waktu',
  'ss.next_slide':
      'Slide berikutnya',
  'ss.slide_time':
      'Slide ini: {t}',
  'ss.end_of_show':
      'Akhir presentasi',
  'ss.notes':
      'Catatan',
  'ss.no_notes':
      'Tidak ada catatan untuk slide ini',
  'ss.volume_keys':
      'Maju dengan tombol volume',
  'ss.web_remote':
      'Remote lewat jaringan lokal',
  'ss.second_screen':
      'Tampilkan di layar kedua',
  'ss.blank_black':
      'Layar hitam',
  'ss.blank_white':
      'Layar putih',
  'ss.all_slides':
      'Semua slide',
  'ss.tool_rotate_left':
      'Putar ke kiri',
  'ss.tool_rotate_right':
      'Putar ke kanan',
  'ss.compare_hold':
      'Asli (tahan)',
  'ss.pages_tab':
      'Halaman ({n})',
  'ss.saved':
      'Disimpan · {folder}',
  'ss.saving':
      'Menyimpan…',
  'ss.save_failed':
      'Tidak tersimpan — ketuk untuk mencoba lagi',
  'ss.finishing':
      'Menyimpan perubahan terakhir…',
  'ss.tool_crop':
      'Pangkas',
  'ss.tool_rotate':
      'Putar',
  'ss.tool_filter':
      'Filter',
  'ss.tool_retake':
      'Ambil ulang',
  'ss.tool_delete':
      'Hapus',
  'ss.page_deleted':
      'Halaman dihapus',
  'ss.working_crop':
      'Memangkas…',
  'ss.working_rotate':
      'Memutar…',
  'ss.working_filter':
      'Menerapkan…',
  'ss.working_straighten':
      'Meluruskan…',
  'ss.moving':
      'Memindahkan…',
  'ss.add_camera':
      'Pindai dengan kamera',
  'ss.add_camera_sub':
      'Tepi halaman ditemukan otomatis',
  'ss.add_gallery':
      'Tambah dari foto',
  'ss.add_gallery_sub':
      'Pilih dari galeri dan atur pangkasan sendiri',
  'ss.filter_clear':
      'Hapus filter',
  'ss.exit':
      'Keluar',
  'ss.step':
      '{n} / {total}  ·  langkah {step}/{max}',
  'ss.no_text':
      '(Tanpa teks)',
  'fm.search_apps':
      'Cari aplikasi…',
  'fm.name_spoof_warn':
      'Peringatan: jenis sebenarnya .{ext}',
  'fm.recent_opened':
      'Riwayat',
  'fm.apk_tab':
      'APK',
  'fm.network_storage':
      'Penyimpanan jaringan',
  'fm.trash':
      'Tempat sampah',
  'fm.trash_count':
      '{n} item',
  'fm.permission_denied':
      'Tidak masalah — Anda tetap dapat membuka berkas satu per satu; tidak perlu izin lain.',
  'fm.internal_storage':
      'Penyimpanan internal',
  'fm.organize':
      'Atur',
  'fm.root':
      'Root',
  'fm.unreadable':
      'Folder ini tidak dapat dibaca.\nMungkin lokasi yang dilindungi Android (seperti Android/data), atau "akses semua berkas" belum diberikan.',
  'fm.sort_name':
      'Urutkan menurut nama',
  'fm.sort_date':
      'Urutkan menurut tanggal',
  'fm.sort_size':
      'Urutkan menurut ukuran',
  'fm.select_none':
      'Hapus pilihan',
  'fm.paste':
      'Tempel',
  'fm.clipboard_ready':
      '{n} item siap untuk {verb}',
  'fm.verb_move':
      'dipindahkan',
  'fm.verb_copy':
      'disalin',
  'fm.compare_digest':
      'Apakah kedua berkas identik?',
  'fm.batch_rename':
      'Ganti nama massal',
// ── fm-ftpd-vault-dl-ab ──
  'fm.compress':
      'Kompres (ZIP/7z)',
  'fm.resize':
      'Perkecil ukuran (resolusi / frame rate)',
  'fm.tag':
      'Tag (orang/grup)',
  'fm.more_actions':
      'Tindakan lainnya',
  'fm.more':
      'Lainnya',
  'fm.clipboard_copied':
      'Disalin ke papan klip. Ketuk “Tempel” di folder tujuan.',
  'fm.clipboard_cut':
      'Dipotong ke papan klip. Ketuk “Tempel” di folder tujuan.',
  'fm.move_here':
      'Pindahkan ke sini',
  'fm.copy_here':
      'Salin ke sini',
  'fm.scan_document':
      'Pindai dokumen',
  'fm.duplicates_title':
      'Berkas duplikat',
  'fm.enter_password':
      'Masukkan kata sandi',
  'fm.clear_finished':
      'Hapus yang selesai',
  'fm.existing_tags':
      'Tag yang ada',
  'fm.pin_enter':
      'Masukkan PIN',
  'fm.pin_new':
      'PIN baru',
  'fm.pin_label':
      'PIN',
  'fm.pin_repeat':
      'PIN (ulangi)',
  'fm.to_background':
      'Jalankan di latar belakang',
  'fm.vol_internal':
      'Penyimpanan internal',
  'fm.vol_sdcard':
      'Kartu SD',
  'fm.vol_usb':
      'Drive USB',
  'fm.quick_untouched':
      'Tidak dibuka dalam {n} bulan',
  'fm.quick_opened_within':
      'Dibuka dalam {n} bulan terakhir',
  'fm.moving_name':
      'Pindahkan',
  'fm.search_all':
      'Cari di semua berkas',
  'ftpd.title':
      'Akses jaringan',
  'ftpd.description':
      'Jangkau berkas di ponsel ini dari komputer di jaringan. Mulai layanan, lalu ketik alamat di bawah ke penjelajah berkas di PC. Ponsel dan PC harus berada di jaringan Wi-Fi YANG SAMA.',
  'ftpd.intro':
      'Mulai layanan untuk menjangkau berkas lewat jaringan.',
  'ftpd.web_label':
      'Buka di peramban',
  'ftpd.web_hint':
      'Ketik alamat ini di peramban PC Anda: klik berkas untuk membuka atau mengunduhnya.',
  'ftpd.ftp_label':
      'Penjelajah berkas (FTP)',
  'ftpd.ftp_hint':
      'Ketik di Explorer untuk menyalin dengan seret dan lepas. Peramban tidak lagi mendukung FTP — gunakan alamat di atas untuk membuka berkas.',
  'ftpd.random_password':
      'Kata sandi acak',
  'ftpd.show_hidden':
      'Tampilkan berkas tersembunyi',
  'ftpd.clients':
      '{n} komputer terhubung',
  'ftpd.folders_hint':
      'Di PC Anda akan melihat kotak yang sama seperti di ponsel: Belgeler, Resimler, Videolar, Ses, Arsivler, Uygulamalar, Indirilenler, Kamera — plus "Telefon" untuk semuanya. Anda dapat memilih mana yang dibagikan di atas, atau hanya membagikan folder "Paylasilan".',
  'ftpd.notification_hint':
      'Tetap terlihat di panel notifikasi saat aktif, dan berhenti sendiri saat Anda menutup aplikasi.',
  'ftpd.open_action':
      'Akses jaringan aktif',
  'ftpd.advanced':
      'Lanjutan',
  'ftpd.start':
      'MULAI',
  'ftpd.stop':
      'HENTIKAN LAYANAN',
  'ftpd.running':
      'Berjalan',
  'ftpd.no_address':
      'Koneksi Wi-Fi tidak ditemukan. Hubungkan ponsel ke jaringan Wi-Fi.',
  'ftpd.allow_write':
      'Izinkan menulis',
  'ftpd.allow_write_note':
      'Saat mati, PC hanya dapat membaca. Jika diaktifkan, PC dapat mengubah dan MENGHAPUS berkas di ponsel.',
  'ftpd.folders_title':
      'Folder yang dibagikan',
  'ftpd.folders_all':
      'Semuanya dibagikan',
  'ftpd.folders_count':
      '{n} folder dibagikan',
  'ftpd.folders_none':
      'Tidak ada folder dipilih',
  'ftpd.folders_none_warning':
      'Tidak ada folder dipilih: meski berbagi aktif, PC tidak akan melihat apa pun.',
  'ftpd.mode_boxes':
      'Folder yang saya pilih',
  'ftpd.mode_boxes_desc':
      'Hanya folder yang Anda centang di bawah yang dibagikan; sisanya tidak terlihat.',
  'ftpd.mode_shared':
      'Hanya folder Dibagikan',
  'ftpd.mode_shared_desc':
      'Letakkan yang ingin dikirim ke folder "Dibagikan"; bagian ponsel lainnya sama sekali tidak terlihat di jaringan.',
  'ftpd.select_all':
      'Pilih semua',
  'ftpd.clear_all':
      'Hapus pilihan',
  'ftpd.box_on_pc':
      'Di PC: {name}',
  'ftpd.box_shared':
      'Dibagikan',
  'ftpd.box_storage':
      'Seluruh ponsel',
  'ftpd.box_downloads':
      'Unduhan',
  'ftpd.box_camera':
      'Kamera',
  'ftpd.box_screenshots':
      'Tangkapan layar',
  'ftpd.box_images':
      'Gambar',
  'ftpd.box_videos':
      'Video',
  'ftpd.box_audio':
      'Audio',
  'ftpd.box_documents':
      'Dokumen',
  'ftpd.box_archives':
      'Arsip',
  'ftpd.box_apps':
      'Aplikasi',
  'ftpd.shared_folder_hint':
      'Folder "Paylaşılan" di ponsel. Gunakan "Salin ke Dibagikan" di menu ⋮ berkas untuk menaruh sesuatu di sini.',
  'ftpd.copied':
      'Alamat disalin.',
  'ftpd.start_failed':
      'Tidak dapat memulai server: {error}',
  'ftpd.qr_hint':
      'Pindai dengan kamera komputer atau ponsel lain — berkas Anda terbuka di peramban.',
  'ftpd.upload_hint':
      'Komputer ke ponsel: berkas yang dikirim dengan "Telefona gönder" di halaman masuk ke Download/Bilgisayardan.',
  'vault.title':
      'Brankas terenkripsi',
  'vault.pin_use_lock':
      'Masukkan PIN kunci folder — brankas memakai PIN yang sama',
  'vault.pin_same_existing':
      'Brankas memakai PIN yang sama dengan kunci folder dan aplikasi: masukkan PIN Anda saat ini.',
  'vault.pin_same_new':
      'PIN ini juga dipakai untuk kunci folder dan aplikasi.',
  'vault.legacy_title':
      '{n} item tersembunyi tidak terenkripsi',
  'vault.legacy_body':
      '"Berkas tersembunyi" lama hanya disimpan di tempat tersembunyi; terlihat saat ponsel dihubungkan ke komputer. Memindahkannya ke brankas mengenkripsinya — setiap berkas dienkripsi dan diverifikasi sebelum aslinya dihapus.',
  'vault.legacy_move':
      'Pindahkan ke brankas',
  'vault.legacy_show':
      'Lihat daftar',
  'vault.move_hint':
      'Isi dienkripsi; hanya terbuka dengan PIN atau sidik jari',
  'vault.move_n':
      'Pindahkan {n} berkas ke brankas',
  'vault.pick_title':
      'Pilih berkas untuk brankas',
  'vault.setup_title':
      'Siapkan brankas terenkripsi',
  'vault.setup_body':
      'Dokumen seperti KTP, sertifikat, dan kontrak disimpan terenkripsi dengan AES-256. Tetap tidak terbaca meski ponsel dihubungkan ke komputer.',
  'vault.pin':
      'PIN brankas',
  'vault.pin_again':
      'Ulangi PIN',
  'vault.pin_short':
      'PIN minimal 4 digit',
  'vault.pin_mismatch':
      'PIN tidak cocok',
  'vault.pin_warning':
      'Penting: jika PIN lupa, berkas TIDAK DAPAT dipulihkan — tak seorang pun, termasuk kami, dapat mendekripsinya. Sidik jari hanya pintasan di ponsel ini; catat PIN Anda di tempat aman.',
  'vault.create':
      'Buat brankas',
  'vault.locked_title':
      'Brankas terkunci',
  'vault.locked_body':
      'Masukkan PIN atau gunakan sidik jari untuk membuka.',
  'vault.unlock':
      'Buka kunci',
  'vault.unlock_bio':
      'Buka dengan sidik jari',
  'vault.bio_prompt':
      'Verifikasi untuk membuka brankas',
  'vault.use_pin':
      'Pakai PIN',
  'vault.bio_failed':
      'Tidak dapat membuka dengan sidik jari — gunakan PIN Anda',
  'vault.bio_toggle':
      'Buka dengan sidik jari',
  'vault.bio_invalidated':
      'Sidik jari baru ditambahkan ke ponsel, sehingga buka kunci sidik jari dimatikan. Buka dengan PIN, lalu aktifkan lagi.',
  'vault.autolock':
      'Kunci di latar belakang',
  'vault.autolock_now':
      'Segera',
  'vault.autolock_secs':
      'Setelah {n} dtk',
  'vault.autolock_mins':
      'Setelah {n} mnt',
  'vault.wrong_pin':
      'PIN salah',
  'vault.lock':
      'Kunci',
  'vault.add':
      'Tambah ke brankas',
  'vault.adding':
      'Mengenkripsi…',
  'vault.added_n':
      '{n} berkas dienkripsi ke brankas',
  'vault.encrypted_note':
      'AES-256 · terkunci saat Anda keluar atau aplikasi ke latar belakang',
  'vault.empty':
      'Brankas kosong. Tambahkan berkas dengan tombol di bawah, atau tekan lama berkas di penjelajah dan pilih "Pindahkan ke brankas terenkripsi".',
  'vault.restore':
      'Keluarkan dari brankas',
  'vault.restore_sub':
      'Didekripsi kembali ke folder aslinya',
  'vault.restored':
      'Dikeluarkan: {path}',
  'vault.delete':
      'Hapus permanen',
  'vault.delete_body':
      'Hapus "{name}" dari brankas secara permanen? Tindakan ini tidak dapat dibatalkan.',
  'vault.open_failed':
      'Tidak dapat membuka: {error}',
  'dl.saved':
      'Disimpan ke Unduhan: {name}',
  'dl.already_saved':
      'Sudah ada di Unduhan: {name}',
  'dl.save_failed':
      'Tidak dapat menyimpan ke Unduhan: {error}',
  'dl.show':
      'Tampilkan',
  'dl.from_browser':
      'Berkas yang dibuka dari peramban disimpan ke Unduhan: {name}',
  'dl.verify':
      'Verifikasi checksum (SHA-256)',
  'dl.verify_paste':
      'Tempel checksum SHA-256 yang diterbitkan sumbernya',
  'dl.verify_running':
      'Membaca berkas…',
  'dl.verify_ok':
      'Checksum COCOK — berkas utuh',
  'dl.verify_bad':
      'Checksum TIDAK cocok — berkas tidak lengkap atau diubah',
  'dl.title':
      'Unduhan',
  'dl.clipboard_download':
      'Unduh tautan di papan klip',
  'dl.how_to':
      'Bagaimana mengunduh dari peramban?',
  'dl.clear_finished':
      'Hapus entri yang selesai',
  'dl.link':
      'Tautan',
  'dl.clipboard_link':
      'Tautan di papan klip',
  'dl.download':
      'Unduh',
  'dl.no_link':
      'Tidak ada tautan di papan klip. Salin tautan di peramban lalu kembali.',
  'dl.from_link':
      'Unduh dari tautan',
  'dl.link_label':
      'Tautan (https://…)',
  'dl.continue':
      'Lanjutkan',
  'dl.empty':
      'Belum ada unduhan',
  'dl.remaining':
      '{time} lagi',
  'dl.link_copied':
      'Tautan disalin ke papan klip.',
  'dl.pause':
      'Jeda',
  'dl.resume':
      'Lanjutkan',
  'dl.cancel_task':
      'Batal',
  'dl.open_folder':
      'Buka foldernya',
  'dl.copy_link':
      'Salin tautan',
  'dl.remove':
      'Hapus dari daftar',
  'dl.download_here':
      'Unduh ke sini',
  'dl.started':
      'Unduhan dimulai: {name}',
  'dl.fetching_release':
      'Mengambil berkas rilis…',
  'dl.asset_count':
      '{n} berkas · {tag}',
  'dl.size_unknown':
      'Ukuran tidak diketahui',
  'dl.step1_title':
      '1) Bagikan (termudah)',
  'dl.step1_body':
      'Tekan lama tautan → “Bagikan tautan” → Dosyalarım. Tombol bagikan milik halaman juga bisa.',
  'dl.step2_title':
      '2) Salin dan tempel',
  'dl.step2_body':
      'Tekan lama tautan → “Salin alamat tautan”, lalu buka layar ini: tautan muncul di atas, ketuk “Unduh”.',
  'dl.step3_title':
      '3) Agar kami muncul saat Anda mengetuk tautan',
  'dl.step3_body':
      'Sejak Android 12, aplikasi tidak dapat membuka tautan situs yang bukan miliknya tanpa izin. Anda dapat memberikannya manual: gunakan tombol di bawah untuk membuka layar info aplikasi, lalu:\n• Android murni / Pixel: “Buka secara default” → “Buka tautan yang didukung”\n• Samsung: “Setel sebagai default” → “Alamat web yang didukung”\n• Xiaomi / Redmi: “Buka secara default” → “Tautan yang didukung”\nCentang alamat seperti github.com di daftar yang muncul.',
  'dl.how_to_note':
      'Menu ini hanya ada di Android 12 ke atas. Jika tidak menemukannya, gunakan cara 1 — tanpa pengaturan dan berfungsi di semua perangkat.',
  'dl.open_app_info':
      'Buka info aplikasi',
  'dl.verify_name':
      'Pemeriksaan checksum',
  'ab.pro_locked_title':
      'Studio Buku Audio adalah Fitur Pro',
  'ab.pro_locked_sub':
      'Tingkatkan ke Pro untuk mengubah dokumen menjadi buku audio (M4A/WAV) dengan jeda alami.',
  'ab.pro_unlock':
      'Lihat Fitur Pro',
  'ab.engine_section':
      'Mesin Ucapan & Suara Sistem',
  'ab.engine_label':
      'Mesin TTS',
  'ab.system_voice_label':
      'Suara Sistem',
  'ab.system_voice_default':
      'Suara sistem bawaan',
  'ab.preview':
      'Pratinjau Suara',
  'ab.preview_sample':
      'Halo. Kalimat ini menguji mesin suara yang dipilih dan jeda alami.',
  'ab.clean_section':
      'Pembersihan Ucapan Alami',
  'ab.clean_pages':
      'Lewati nomor halaman dan header/footer berulang',
  'ab.clean_symbols':
      'Bersihkan simbol, tanda kurung, dan URL berlebih agar ucapan alami',
  'ab.clean_abbr':
      'Perluas singkatan (mis. Dr., dll.)',
  'ab.ai_tidy':
      'Haluskan teks dengan AI (kunci Anda sendiri)',
  'ab.ai_tidy_sub':
      'Memperhalus bab agar ucapan alami memakai kunci Gemini Anda sendiri',
  'ab.title':
      'Buat buku audio',
  'ab.library':
      'Buku audio saya',
  'ab.intro':
      'Dokumen dibagi menjadi bab menurut judulnya; setiap bab menjadi berkas audio terpisah bernama yang disimpan ke Music > Sesli Kitaplar. Bab yang selesai tidak dibuat ulang.',
  'ab.voice':
      'Suara',
  'ab.voice_system':
      'Suara perangkat',
  'ab.voice_system_sub':
      'Mesin ucapan ponsel Anda — tanpa unduhan (pilih di Pengaturan > Membaca)',
  'ab.speed':
      'Kecepatan',
  'ab.chapters':
      'Bab ({n})',
  'ab.chapter_ready':
      'Siap — tidak akan dibuat ulang',
  'ab.chapter_len':
      '~{min} mnt',
  'ab.start':
      'Buat',
  'ab.listen':
      'Dengarkan',
// ── ab-ph-skin-pf-jr-pp ──
  'ab.running':
      'Membuat bab {n}/{total} — hentikan',
  'ab.preparing':
      'Menyiapkan suara: {voice}',
  'ab.done':
      '{n} bab siap ({folder})',
  'ab.stopped':
      'Dihentikan — {n} bab siap; dapat dilanjutkan nanti',
  'ab.failed':
      'Tidak dapat membuat buku audio: {error}',
  'ab.job_running':
      'Buku audio: {name}',
  'ab.job_name':
      'Buku audio ({name})',
  'ab.background':
      'Membuat di latar belakang',
  'ab.background_sub':
      'Anda dapat meninggalkan layar ini atau berpindah aplikasi; kemajuan ditampilkan di notifikasi.',
  'ab.make':
      'Buat buku audio',
  'ab.make_hint':
      'Berkas bab dengan judul',
  'ab.library_empty':
      'Belum ada buku audio',
  'ab.library_empty_hint':
      'Pilih "Buat buku audio" di menu ⋮ berkas PDF, Word, slide, atau teks.',
  'ab.book_sub':
      '{n} bab · {size}',
  'ab.play_all':
      'Putar dari awal',
  'ab.delete_q':
      'Hapus buku audio "{name}"?',
  'ph.pin_home':
      'Tambah ke layar utama',
  'ph.pin_home_hint':
      'Halaman ini mendapat ikonnya sendiri di layar utama',
  'ph.albums':
      'Album',
  'ph.show_all':
      'Tampilkan semua',
  'ph.on_this_day':
      'Pada hari ini',
  'ph.on_this_day_sub':
      'Hari ini di tahun-tahun lalu · {n}',
  'ph.loading':
      'Memuat berkas…',
  'ph.empty':
      'Tidak ada berkas untuk ditampilkan di sini.',
  'ph.no_match':
      'Tidak ada berkas yang cocok dengan pencarian/filter Anda.',
  'ph.verifying':
      'Memverifikasi salinan byte demi byte…',
  'ph.not_identical':
      'Verifikasi byte demi byte tidak menemukan salinan persis — tidak ada yang dihapus.',
  'ph.show':
      'Tampilkan',
  'ph.search_in':
      'Cari di {title}',
  'ph.search_in_hint':
      'Cari di {title}…',
  'ph.layout':
      'Tata letak: {name}',
  'ph.selected_of':
      '{n} / {total} dipilih',
  'ph.select_above':
      'Pilih juga yang di atas',
  'ph.select_below':
      'Pilih juga yang di bawah',
  'ph.clear_selection':
      'Hapus pilihan',
  'ph.select_all':
      'Pilih semua',
  'ph.cat_empty':
      'Tidak ada berkas di kategori ini.',
  'ph.group_deselect':
      'Batalkan pilihan grup',
  'ph.group_select':
      'Pilih grup',
  'ph.delete_dupes_title':
      'Hapus salinannya?',
  'ph.delete_dupes_body':
      '{n} salinan tambahan ({size}) {fate}. Berkas tertua di setiap grup dipertahankan.',
  'ph.fate_trash':
      'akan dipindahkan ke tempat sampah',
  'ph.fate_permanent':
      'akan dihapus PERMANEN (tempat sampah dimatikan di pengaturan)',
  'ph.hidden_dupes_short':
      '{n} duplikat disembunyikan',
  'ph.clean':
      'Bersihkan',
  'ph.similar_title':
      'Serupa: {title}',
  'ph.similar_short':
      'Cari yang serupa',
  'ph.sorted_header':
      '{n} berkas · {sort}',
  'ph.view':
      'Tampilan',
  'ph.view_scale':
      'Skala waktu',
  'ph.view_columns':
      'Kolom',
  'ph.albums_hide':
      'Sembunyikan area album',
  'ph.albums_show':
      'Tampilkan area album',
  'ph.pinch_hint':
      'Tips: cubit kisi dengan dua jari untuk memperkecil, rentangkan untuk memperbesar.',
  'ph.empty_hint':
      'Foto dan video baru muncul di sini begitu diambil.',
  'ph.no_match_hint':
      'Coba hapus filter.',
  'ph.clear_filters':
      'Hapus filter',
  'ph.fast_scroll':
      'Gagang gulir cepat',
  'skin.sage':
      'Sage',
  'skin.sage_sub':
      'Meja dan kertas: dasar hijau-abu lembut, kartu terang, aksen teal',
  'skin.classic':
      'Klasik',
  'skin.classic_sub':
      'Folder kuning, ikon halaman polos — pengelola berkas gaya lama',
  'skin.ledger':
      'Buku besar',
  'skin.ledger_sub':
      'Latar krem, folder manila, ikon polos',
  'skin.calm':
      'Tenang',
  'skin.calm_sub':
      'Kartu putih, aksen terakota, ikon berbingkai',
  'skin.bento':
      'Bento',
  'skin.bento_sub':
      'Kartu penyimpanan berwarna, ubin besar dan kecil',
  'skin.band':
      'Header gelap',
  'skin.band_sub':
      'Header berwarna, ubin sebagai daftar',
  'skin.g_layout':
      'Baru · dengan tata letak beranda',
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
      'Dasar krem-merah muda hangat, aksen plum, kartu putih kertas',
  'skin.lavender':
      'Lavender',
  'skin.lavender_sub':
      'Dasar abu-abu lilac, aksen ungu plum',
  'skin.olive':
      'Zaitun',
  'skin.olive_sub':
      'Dasar batu zaitun, aksen hijau zaitun',
  'skin.white':
      'Putih klasik',
  'skin.white_sub':
      'Dasar abu-abu muda, kartu putih bersih, aksen biru',
  'skin.straw':
      'Kertas jerami',
  'skin.straw_sub':
      'Dasar jerami, kartu krem, tinta sepia',
  'skin.cream':
      'Krem',
  'skin.cream_sub':
      'Dasar krem muda, kartu gading, aksen ambar',
  'skin.peach':
      'Persik',
  'skin.peach_sub':
      'Dasar pastel hangat yang nyaman di mata untuk membaca lama',
  'skin.mint':
      'Mint',
  'skin.mint_sub':
      'Dasar hijau-biru tenang, aksen hijau laut',
  'skin.porcelain':
      'Porselen',
  'skin.porcelain_sub':
      'Dasar abu-abu biru sejuk, aksen biru tua, kartu putih kertas',
  'skin.modern':
      'Modern',
  'skin.modern_sub':
      'Aksen ungu cerah, sudut bulat, ikon besar',
  'skin.system':
      'Warna sistem',
  'skin.system_sub':
      'Mengambil warna wallpaper Anda (Android 12+)',
  'skin.night':
      'Malam (OLED)',
  'skin.night_sub':
      'Dasar hitam pekat: hemat baterai, nyaman di malam hari',
  'skin.forces_dark':
      'Tema ini selalu tetap gelap',
  'pf.tab_form':
      'Formulir',
  'pf.tab_sign':
      'Tanda tangan',
  'pf.tab_digital':
      'Digital',
  'pf.title_unified':
      'Formulir & tanda tangan — {name}',
  'pf.pick_date':
      'Pilih tanggal',
  'pf.go_sign':
      'Tanda tangani dokumen / tambah tanggal',
  'pf.add_signature':
      'Tanda tangan',
  'pf.add_initials':
      'Paraf',
  'pf.add_date_stamp':
      'Cap tanggal',
  'pf.sign_empty_hint':
      'Tambahkan Tanda tangan, Paraf, atau Cap tanggal di atas untuk diletakkan di halaman.',
  'pf.sign_drag_hint':
      'Seret untuk memosisikan; ubah ukuran dengan penggeser di bawah.',
  'pf.save_all':
      'Simpan',
  'pf.signed_warn':
      'Dokumen ini ditandatangani secara digital. Menimpanya akan membatalkan tanda tangan yang ada; disarankan menyimpan salinan.',
  'pf.dsig_verify_title':
      'Verifikasi tanda tangan',
  'pf.dsig_valid':
      'Valid — dokumen tidak berubah sejak ditandatangani',
  'pf.dsig_valid_partial':
      'Valid — pembaruan tambahan ditambahkan setelah penandatanganan',
  'pf.dsig_invalid':
      'Tidak valid — dokumen diubah setelah ditandatangani',
  'pf.dsig_self_signed':
      'Sertifikat tanda tangan sendiri',
  'pf.dsig_issuer':
      'Penerbit: {name}',
  'pf.dsig_sign_title':
      'Tambah tanda tangan digital (PAdES)',
  'pf.dsig_self_opt':
      'Identitas tanda tangan sendiri',
  'pf.dsig_pfx_opt':
      'Impor sertifikat (.pfx / .p12)',
  'pf.dsig_signer_name':
      'Nama penandatangan',
  'pf.dsig_reason':
      'Alasan (opsional)',
  'pf.dsig_location':
      'Lokasi (opsional)',
  'pf.dsig_visible':
      'Kotak tanda tangan terlihat',
  'pf.dsig_last_page':
      'Letakkan di halaman terakhir',
  'pf.dsig_pick_pfx':
      'Pilih berkas sertifikat',
  'pf.save':
      'Isi dan simpan',
  'pf.page':
      'Halaman {n}',
  'pf.other_fields':
      'Bidang lain',
  'pf.read_only':
      'hanya-baca',
  'pf.sign_tap':
      'Ketuk untuk menandatangani',
  'pf.signed':
      'Ditandatangani — dicap ke bidang saat disimpan',
  'pf.flatten':
      'Kunci setelah diisi',
  'pf.flatten_sub':
      'Nilai digambar ke halaman; tidak ada yang dapat mengubahnya setelahnya. Tindakan ini tidak dapat dibatalkan.',
  'pf.note':
      'Formulir terisi',
  'pf.note_flat':
      'Formulir terisi dan terkunci',
  'pf.no_fields':
      'PDF ini tidak memiliki bidang formulir yang dapat diisi.',
  'pf.no_fields_hint':
      'Untuk menambah teks gunakan alat teks di editor PDF; untuk menandatangani gunakan ⋮ → Tanda tangani.',
  'pf.failed':
      'Tidak dapat mengisi formulir: {error}',
  'jr.undo_move':
      'Urungkan pemindahan',
  'jr.moved_back':
      '{n} berkas dikembalikan',
  'jr.untrash':
      'Pulihkan',
  'jr.restored':
      '{n} berkas dipulihkan',
  'jr.trash_created':
      'Pindahkan ke tempat sampah',
  'jr.trashed':
      '{n} item dipindahkan ke tempat sampah',
  'jr.undo_rename':
      'Urungkan penggantian nama',
  'jr.renamed_back':
      '{n} berkas mendapatkan nama lamanya kembali',
  'jr.headline_tags':
      'Penandaan pintar memeriksa {files} berkas dan menyarankan {groups} tag ({n} saran)',
  'jr.headline':
      '{n} perubahan pada {files} berkas',
  'jr.status_none':
      'Belum ada yang diterapkan — berkas belum bertag. Ketuk saran yang salah untuk membuangnya (✕), lalu "Terapkan semua".',
  'jr.status_all':
      'Selesai: {n} tag ditulis ke berkas · {x} dibuang. Ketuk mana saja untuk berubah pikiran.',
  'jr.status_some':
      '{n} diterapkan · {p} tertunda · {x} dibuang.',
  'jr.hint':
      'Ketuk gambar mini: buang ✕ / simpan ✓ · Tekan lama: buka berkas',
  'jr.by_tag':
      'Menurut tag',
  'jr.by_file':
      'Menurut berkas',
  'jr.all_tags':
      'Semua',
  'jr.show_all':
      'Tampilkan semua ({n})',
  'jr.apply_n':
      'Terapkan ({n})',
  'jr.n_files':
      '{n} berkas',
  'jr.n_applied':
      '{n} diterapkan',
  'jr.n_pending':
      '{n} disarankan',
  'jr.n_rejected':
      '{n} dibuang',
  'jr.state_applied':
      'bertag',
  'jr.state_pending':
      'disarankan — belum diterapkan',
  'jr.state_rejected':
      'dibuang',
  'jr.remove_one_hint':
      'Saran dihapus dari daftar ini; berkas tetap ada',
  'jr.empty':
      'Tugas ini tidak meninggalkan perubahan tercatat pada berkas.',
  'jr.summary':
      '{groups} grup · {files} berkas · {applied} diterapkan · {pending} tertunda',
  'jr.apply_all':
      'Terapkan semua ({n})',
  'jr.undo_all':
      'Urungkan semua',
  'jr.apply':
      'Terapkan',
  'jr.rename_tag':
      'Ganti nama tag',
  'jr.remove_tag':
      'Hapus tag',
  'jr.remove_tag_body':
      'Hapus tag "{tag}" dari {n} berkas tugas ini? Berkas tidak dihapus.',
  'jr.remove_one':
      'Hapus dari berkas ini',
  'jr.move_files':
      'Pindahkan berkas ke folder',
  'jr.moved':
      '{n} berkas dipindahkan',
  'jr.nothing_to_move':
      'Tidak ada berkas yang tersisa untuk dipindahkan',
  'jr.missing':
      'Berkas sudah tidak ada',
  'pp.dsign_sub':
      'Tanda tangan PKCS#7; diverifikasi oleh Adobe/Chrome',
  'pp.region_hint':
      'Seret untuk menggambar kotak; ketuk kotak untuk menghapusnya',
  'pp.region_hint_crop':
      'Seret untuk menggambar area yang dipertahankan',
  'pp.redact_sub':
      'Benar-benar menghapus teks dan gambar',
  'pp.to_xlsx_sub':
      'Baris/kolom terdeteksi; halaman terpilih atau semua',
  'pp.to_docx_sub':
      'Baris, indentasi, ukuran font, dan pemisah halaman',
  'pp.pdfa_sub':
      'Arsip jangka panjang (PDF/A-2b)',
  'pp.compare_sub':
      'Perbedaan teks dan visual',
  'pp.permissions_sub':
      'Batasi cetak/salin/edit',
  'pp.outline_sub':
      'Tambah, ganti nama, susun ulang, indentasi',
  'pp.outline_rename':
      'Edit penanda',
  'pp.stamp_sub':
      'Disetujui, Draf, Rahasia, Salinan tersertifikasi…',
  'pp.numbering_sub':
      'Halaman n / N, Romawi, nomor Bates',
  'pp.compress_hard_sub':
      'Penghematan besar pada PDF hasil pindai/gambar',
  'pp.studio_sub':
      'Pilih, putar, hapus, gandakan, dan susun ulang halaman',
  'pp.studio_insert_file':
      'Sisipkan halaman dari berkas',
  'pp.studio_insert_image':
      'Sisipkan halaman dari gambar',
  'pp.studio_insert_scan':
      'Pindai dan sisipkan halaman',
  'pp.blank_sub':
      'Sisi belakang kosong pada hasil pindai',
// ── pp-cj-sb-clean-apk-suc-apps ──
  'pp.crop_sub':
      'Halaman terpilih atau semua',
  'pp.fit_a4_sub':
      'Menyamakan ukuran halaman yang bercampur',
  'pp.profile_sub':
      'Nama, email, telepon, alamat',
  'pp.form_create_sub':
      'Teks, kotak centang, bidang tanda tangan',
  'pp.ocr_layer_sub':
      'Menambahkan lapisan teks tak terlihat pada halaman hasil pindai',
  'pp.images_to_pdf_sub':
      'Pilih banyak gambar → satu PDF',
  'pp.pdf_to_images_sub':
      'Halaman terpilih atau semua ke folder JPEG',
  'pp.web_to_pdf_sub':
      'Masukkan alamat, simpan sebagai PDF A4',
  'pp.office_to_pdf_sub':
      'Teks, judul, dan tabel dipertahankan',
  'pp.signatures_sub':
      'Tanda tangan/paraf tersimpan, paraf tiap halaman, tanggal, stempel',
  'pp.crop_margins_hint':
      'Teks memenuhi layar; diingat untuk dokumen ini',
  'pp.crop_one_column':
      'Hanya dalam tampilan satu kolom',
  'pp.paged_hint':
      'Halaman pas di layar; ketuk tepi atau geser',
  'pp.meta_sub':
      'Judul, penulis, subjek, kata kunci',
  'pp.meta_title':
      'Judul',
  'pp.meta_author':
      'Penulis',
  'pp.meta_subject':
      'Subjek',
  'pp.meta_keywords':
      'Kata kunci',
  'pp.layers_sub':
      'Tampilkan atau sembunyikan lapisan',
  'pp.xfdf_out_sub':
      'Pindahkan sorotan dan catatan ke aplikasi lain',
  'pp.xfdf_in_sub':
      'Tambahkan sorotan dan catatan dari aplikasi lain',
  'cj.title':
      'Pembersihan media obrolan',
  'cj.job_title':
      'Memindai media obrolan',
  'cj.job_name':
      'Pemindaian media obrolan',
  'cj.rescan':
      'Pindai lagi',
  'cj.step_listing':
      'Mendaftar berkas…',
  'cj.step_found':
      'Ditemukan {n} berkas obrolan',
  'cj.step_duplicates':
      'Mencari salinan identik…',
  'cj.step_sorting':
      'Mengurutkan…',
  'cj.step_none':
      'Tidak ada media obrolan ditemukan',
  'cj.step_clean':
      'Tidak ada yang tampak tidak perlu',
  'cj.step_summary':
      '{n} berkas · {size} dapat dibebaskan',
  'cj.scanned':
      '{n} berkas obrolan · {size}',
  'cj.summary':
      '{n} di antaranya ({percent}%) tampak tidak perlu · {size}',
  'cj.summary_none':
      'Tidak ada tumpukan yang tidak perlu.',
  'cj.disclaimer':
      '“Tidak perlu” hanyalah dugaan: siapa pengirim berkas atau artinya bagi Anda tidak dapat dibaca dari berkas. Tidak ada yang dihapus sendiri — Anda yang memutuskan.',
  'cj.tiny_threshold':
      'Batas gambar kecil (di bawah ini dianggap “diteruskan”)',
  'cj.empty_no_media':
      'Folder WhatsApp/Telegram tidak ditemukan di ponsel ini.',
  'cj.empty_clean':
      'Tidak ada tumpukan tidak perlu di media obrolan Anda 🎉',
  'cj.kind_duplicate':
      'Salinan identik',
  'cj.kind_sticker':
      'Stiker',
  'cj.kind_gif':
      'Animasi (GIF)',
  'cj.kind_profile':
      'Foto profil',
  'cj.kind_tiny':
      'Gambar kecil',
  'cj.kind_sent':
      'Berkas yang saya kirim',
  'cj.kind_stale':
      'Lama tidak dibuka',
  'cj.why_duplicate':
      'Salinan tambahan dari berkas yang sama. Salinan tertua di setiap set DIPERTAHANKAN.',
  'cj.why_sticker':
      'Hiasan obrolan, bukan kenangan yang layak disimpan.',
  'cj.why_gif':
      'Biasanya lelucon atau animasi yang diteruskan.',
  'cj.why_profile':
      'Cache foto profil yang diunduh aplikasi.',
  'cj.why_tiny':
      'Gambar sekecil ini kebanyakan poster, meme, atau gambar “selamat pagi” yang diteruskan; foto yang diambil dengan ponsel lebih besar.',
  'cj.why_sent':
      'Salinan kedua dari berkas yang Anda kirim; aslinya mungkin masih ada di galeri atau unduhan.',
  'cj.why_stale':
      'Tidak dibuka maupun disentuh selama berbulan-bulan.',
  'cj.select_all':
      'Pilih semua',
  'cj.select_none':
      'Hapus pilihan',
  'cj.nothing_selected':
      'Pilih berkas yang akan dihapus',
  'cj.selected_summary':
      '{n} berkas dipilih · {size}',
  'cj.bucket_empty':
      'Tidak ada berkas tersisa di kelompok ini.',
  'cj.similar_title':
      'Jepretan serupa (WhatsApp)',
  'cj.similar_body':
      'Tumpukan yang tidak dapat ditemukan kelompok: lima jepretan dari momen yang sama, salinan terkompresi ulang. Ini mendekode gambar, jadi butuh waktu.',
  'sb.title':
      'Uji akurasi',
  'sb.sub':
      'Ukur akurasi penataan pintar dengan berkas Anda sendiri',
  'sb.intro':
      'Beri label hingga {n} berkas dengan kategori yang benar; label dibandingkan dengan jawaban Penataan pintar. Label tetap di ponsel ini dan laporan tidak memuat nama berkas.',
  'sb.category':
      'Kategori',
  'sb.subtype':
      'Subjenis',
  'sb.date':
      'Tanggal (bulan + tahun)',
  'sb.gate':
      'gerbang {g}',
  'sb.no_data':
      'tidak ada data',
  'sb.measured':
      '{m} dari {n} berkas memiliki jawaban Penataan pintar',
  'sb.threshold':
      'Ambang keyakinan yang disarankan: {t}',
  'sb.threshold_none':
      'Jawaban benar belum cukup untuk menyarankan ambang',
  'sb.ask_missing':
      'Tanyakan yang belum ({n})',
  'sb.ask_all':
      'Tanya semua lagi',
  'sb.asking':
      'Bertanya {done}/{total}',
  'sb.stop':
      'Berhenti',
  'sb.asked':
      '{ok} jawaban diterima, {failed} gagal',
  'sb.stopped':
      'Dihentikan: {reason}',
  'sb.add':
      'Beri label berkas',
  'sb.full':
      'Anda dapat memberi label paling banyak {n} berkas',
  'sb.labelled':
      'Berlabel',
  'sb.empty':
      'Belum ada label. Mulai dengan "Beri label berkas".',
  'sb.pick_title':
      'Berkas yang diberi label',
  'sb.pick_empty':
      'Tidak ada berkas dalam cakupan penataan pintar',
  'sb.row':
      'Benar: {truth} · Pintar: {model}',
  'sb.row_none':
      'tanpa jawaban',
  'sb.label_title':
      'Label yang benar',
  'sb.sub_skip':
      'Jangan beri skor',
  'sb.sub_other':
      'Tidak ada / lainnya',
  'sb.date_label':
      'Beri skor tanggal dokumen',
  'sb.month':
      'Bulan',
  'sb.year':
      'Tahun',
  'sb.no_date':
      'Tidak ada',
  'sb.year_none':
      'Tidak ada / lebih lama',
  'sb.save':
      'Simpan',
  'sb.remove':
      'Hapus label',
  'sb.copy':
      'Salin laporan',
  'sb.copied':
      'Laporan disalin (tanpa nama berkas)',
  'sb.clear':
      'Hapus semua label',
  'sb.clear_ask':
      'Hapus semua label? Berkas Anda tidak disentuh.',
  'clean.trash':
      'Kosongkan tempat sampah',
  'clean.trash_detail':
      '{n} item · berkas yang sudah dihapus',
  'clean.duplicates':
      'Bersihkan berkas duplikat',
  'clean.duplicates_detail':
      '{n} salinan tambahan · satu dari tiap grup dipertahankan',
  'clean.stale_downloads':
      'Unduhan lama',
  'clean.stale_downloads_detail':
      '{n} berkas · tidak dibuka 180+ hari',
  'clean.apk':
      'Berkas pemasang (APK)',
  'clean.apk_detail':
      '{n} berkas · tidak perlu setelah aplikasi terpasang',
  'clean.big_videos':
      'Video besar',
  'clean.big_videos_detail':
      '{n} video · di atas 100 MB (pilih satu per satu)',
  'clean.finding_dupes':
      'Mencari berkas duplikat (byte demi byte)…',
  'clean.never_suggest':
      'Jangan sarankan lagi',
  'clean.never_suggest_file':
      'Jangan sarankan berkas ini lagi',
  'clean.app_backup':
      'Cadangan aplikasi',
  'clean.app_backup_detail':
      '{n} berkas cadangan (.bak). Aplikasi TIDAK membutuhkannya untuk berjalan — ini salinan yang dibuat alat pencadangan. Menghapusnya tidak merusak aplikasi terpasang; Anda hanya kehilangan kemampuan memulihkan dari cadangan ini.',
  'clean.verifying_sent':
      'Memverifikasi berkas asli media terkirim…',
  'clean.trash_copy_only':
      'Pindahkan hanya salinan ini ke tempat sampah (aslinya tetap)',
  'clean.bg_safe_apply':
      'Pembersihan berlanjut di latar belakang jika Anda keluar',
  'clean.done_freed':
      '{size} dibebaskan · {n} item',
  'clean.done_trash':
      '{size} dibersihkan · {n} item dipindahkan ke tempat sampah (dapat dipulihkan)',
  'clean.sort_size':
      'Ukuran',
  'clean.sort_date':
      'Tanggal',
  'clean.bg_safe':
      'Pemindaian berlanjut di latar belakang jika Anda keluar',
  'clean.done_card_sub_trash':
      '{n} item dibersihkan. Apa pun yang dipindahkan ke tempat sampah dapat dipulihkan kapan saja.',
  'clean.done_card_sub_perm':
      '{n} item tidak perlu dibersihkan dengan aman.',
  'clean.why_trash':
      'Item yang sudah Anda hapus; mengosongkannya langsung membebaskan ruang.',
  'clean.why_duplicates':
      'Salinan asli tertua di setiap grup tidak disentuh; hanya salinan tambahan yang dihapus.',
  'clean.why_temp_junk':
      'Unduhan tidak lengkap & sisa sementara; menghapusnya tidak merusak aplikasi atau dokumen.',
  'clean.why_app_cache':
      'Gambar mini dibuat ulang saat diperlukan; tidak ada berkas pribadi yang disentuh.',
  'clean.why_apk':
      'Hanya paket pemasang; aplikasi dan data yang sudah terpasang tetap utuh.',
  'clean.why_app_backup':
      'Hanya arsip cadangan lama; aplikasi terpasang tetap berjalan normal.',
  'clean.why_empty_folders':
      'Hanya folder yang benar-benar kosong; dilewati jika ada berkas di dalamnya.',
  'clean.why_chat_sent':
      'Salinan obrolan terkirim; foto/video asli di perangkat sudah diverifikasi dan tetap aman.',
  'clean.why_big_videos':
      'Tidak dipilih sebelumnya. Anda dapat memperkecil ukuran tanpa menghapus agar video tetap ada.',
  'clean.why_stale_downloads':
      'Unduhan tidak dibuka selama 6 bulan; periksa satu per satu sebelum menghapus.',
  'clean.why_old_screenshots':
      'Tangkapan layar tidak disentuh selama 3 bulan; tinjau dan pilih satu per satu.',
  'clean.why_old_large':
      'Berkas besar tidak dibuka selama 1 tahun; hanya item yang Anda centang dipindahkan ke tempat sampah.',
  'apk.share':
      'Bagikan / simpan sebagai APK',
  'apk.share_sub':
      'Format, lokasi simpan, dan opsi berbagi',
  'apk.save':
      'Simpan APK langsung',
  'apk.save_sub':
      'Tanpa pertanyaan, ke Downloads/APK',
  'apk.sheet_title':
      'Ekspor APK',
  'apk.dest':
      'Lokasi simpan',
  'apk.change':
      'Ubah',
  'apk.save_here':
      'Simpan di sini',
  'apk.do_both':
      'Simpan dan bagikan',
  'apk.do_share':
      'Bagikan saja',
  'apk.do_save':
      'Simpan saja',
  'apk.saved_in':
      '{name} → {dir}',
  'apk.split_base_note':
      'Lebih kecil, tetapi mungkin gagal dipasang atau mogok di ponsel lain.',
  'apk.extracting':
      'Menyiapkan APK…',
  'apk.not_found':
      'Berkas APK aplikasi ini tidak dapat dibaca.',
  'apk.failed':
      'Tidak dapat mengekstrak APK: {error}',
  'apk.split_title':
      'Aplikasi ini dipasang dalam beberapa bagian',
  'apk.split_body':
      'Aplikasi yang dipasang dari Play disimpan sebagai base.apk ditambah bagian layar/bahasa/CPU ({n} bagian). Kode ada di base.apk tetapi pustaka dan sumber daya ada di bagian lain: base.apk saja mungkin gagal dipasang atau mogok saat dibuka.',
  'apk.split_all':
      'Semua bagian (.apks — disarankan)',
  'apk.split_base':
      'Hanya base.apk',
  'apk.split_note':
      'Semua bagian dalam satu berkas. Dipasang dengan satu ketukan di aplikasi ini; alat seperti SAI juga dapat membukanya.',
  'apk.installing':
      'Menyiapkan pemasangan…',
  'apk.installed':
      'Aplikasi terpasang',
  'apk.install_aborted':
      'Pemasangan dibatalkan',
  'apk.install_permission':
      'Izinkan pemasangan aplikasi tidak dikenal, lalu ketuk berkas lagi.',
  'apk.install_no_apk':
      'Tidak ada APK di dalam paket',
  'apk.check_title':
      'Pasang paket ini?',
  'apk.check_app':
      'Aplikasi: {name}\n{pkg}',
  'apk.check_version':
      'Versi: {v}',
  'apk.check_installed':
      'Versi terpasang: {v}',
  'apk.check_sha':
      'Tanda tangan (SHA-256):\n{fp}',
  'apk.check_same':
      'Tanda tangan cocok dengan aplikasi terpasang.',
  'apk.check_unreadable':
      'Tidak dapat membaca detail paket. Pasang paket hanya dari sumber tepercaya.',
  'apk.check_install':
      'Pasang',
  'apk.install_failed':
      'Pemasangan gagal: {error}',
  'apk.extracting_name':
      'Persiapan APK',
  'suc.section':
      'Kategori saya',
  'suc.sub':
      'Jelaskan kategori Anda sendiri; Penataan pintar menanyakan setiap berkas secara terpisah. Satu berkas dapat berada di beberapa kategori.',
  'suc.empty':
      'Belum ada kategori. Contoh: "Sewa" — kontrak sewa, kuitansi sewa, dan biaya pemeliharaan.',
  'suc.add':
      'Tambah kategori',
  'suc.full':
      'Anda dapat menambah paling banyak {n} kategori',
  'suc.new_title':
      'Kategori baru',
  'suc.edit_title':
      'Edit kategori',
  'suc.name':
      'Nama',
  'suc.name_hint':
      'mis. Sewa',
  'suc.about':
      'Apa cakupannya? (satu kalimat)',
  'suc.about_hint':
      'mis. Kontrak sewa, kuitansi sewa, dan slip biaya pemeliharaan',
  'suc.icon':
      'Ikon',
  'suc.color':
      'Warna',
  'suc.try':
      'Coba',
  'suc.try_sub':
      'Sebelum menyimpan, dicoba pada {n} berkas terakhir Anda; kecocokan akan terlihat.',
  'suc.trying':
      'Mencoba… {done}/{total}',
  'suc.try_none':
      'Tidak ada yang cocok di {n} berkas terakhir. Sesuaikan kalimat dan coba lagi.',
  'suc.try_hits':
      '{m} dari {n} berkas cocok',
  'suc.try_stale':
      'Nama atau kalimat berubah — coba lagi.',
  'suc.no_files':
      'Tidak ada berkas untuk dicoba',
  'suc.matched':
      'Cocok',
  'suc.not_matched':
      'Tidak cocok',
  'suc.confirm':
      'Hasilnya benar',
  'suc.confirm_sub':
      'Apakah yang cocok benar-benar termasuk di sini? Jika tidak, sesuaikan kalimat.',
  'suc.save':
      'Simpan',
  'suc.save_need':
      'Untuk menyimpan, coba dulu, lihat minimal satu kecocokan, dan konfirmasi hasilnya.',
  'suc.apply':
      'Terapkan ke berkas sebelumnya ({n})',
  'suc.applying':
      'Menerapkan… {done}/{total}',
  'suc.applied':
      '{n} berkas diperiksa, {m} cocok',
  'suc.stopped':
      'Dihentikan: {reason}',
  'suc.stop':
      'Berhenti',
  'suc.count':
      '{n} berkas',
  'suc.pending':
      '{n} berkas · {p} belum diperiksa',
  'suc.menu':
      'Opsi kategori',
  'suc.edit':
      'Edit',
  'suc.delete_q':
      'Hapus kategori "{name}"? Berkas tetap di tempatnya.',
  'apps.not_found':
      'Tidak ada aplikasi ditemukan',
  'apps.sort_name':
      'Menurut nama',
  'ct.analysis':
      'Analisis lengkap',
  'ct.analysis_hint':
      'Menurut bulan, terbesar, yang bisa dibersihkan',
  'ct.bulk_tag':
      'Beri tag semua',
  'ct.bulk_tag_hint':
      'Tambahkan tag ke {n} berkas yang ditampilkan',
  'ct.by_month':
      '12 bulan terakhir',
  'ct.by_source':
      'Asal berkas',
  'ct.by_type':
      'Jenis',
  'ct.cleanable':
      'Bisa dibersihkan',
  'ct.copies':
      'Berkas bernama salinan ("(1)", "copy")',
  'ct.copies_title':
      '{title} · salinan',
  'ct.empty':
      'Tidak ada berkas dalam daftar ini.',
  'ct.group_analysis':
      'Analisis',
  'ct.group_quick_create':
      'Buat cepat',
  'ct.group_tags':
      'Kategori & tag',
  'ct.largest':
      'Berkas terbesar',
  'ct.manage_tags':
      'Kelola tag',
  'ct.manage_tags_hint':
      'Ganti nama atau hapus',
  'ct.no_tags':
      'Belum ada tag — coba "Nama kedua pintar" atau "Beri tag semua".',
  'ct.no_tags_yet':
      'Belum ada tag.',
  'ct.stale':
      'Tidak dibuka lebih dari {days} hari',
  'ct.stale_title':
      '{title} · lama tidak dibuka',
  'ct.stat_files':
      'berkas',
  'ct.stat_month':
      'bulan ini',
  'ct.stat_size':
      'total',
  'ct.subtitle':
      '{title} · {n} berkas ditampilkan',
  'ct.summary':
      'Ringkasan',
  'ct.summary_hint':
      'Jumlah, ukuran, jenis, asal',
  'ct.tag_delete':
      'Hapus tag',
  'ct.tag_delete_body':
      'Tag "{tag}" akan dihapus dari {n} berkas. Berkas tidak dihapus.',
  'ct.tag_rename':
      'Ganti nama tag',
  'ct.tags_heading':
      'Tag',
  'ct.title':
      'Analisis & atur',
  'ocr_studio.ai_done':
      'Teks diperhalus dengan kunci Gemini Anda.',
  'ocr_studio.ai_fix':
      'Perbaikan AI',
  'ocr_studio.all_pages':
      'Semua ({n})',
  'ocr_studio.clean':
      'Rapikan',
  'ocr_studio.clean_done':
      'Huruf, tanda hubung & tanda baca diperbaiki.',
  'ocr_studio.editor_hint':
      'Edit teks yang dikenali di sini…',
  'ocr_studio.empty_result':
      'Tidak ada teks terbaca di halaman ini. Coba mode Ditingkatkan atau Visi AI.',
  'ocr_studio.mode_ai':
      'Visi AI (Gemini)',
  'ocr_studio.mode_ai_sub':
      'Tulisan tangan, tabel & halaman rumit · dengan kunci Gemini Anda',
  'ocr_studio.mode_enhanced':
      'Ditingkatkan (Pindaian)',
  'ocr_studio.mode_enhanced_sub':
      'Peningkatan tanpa kehilangan 2400 px · pembersihan bayangan + urutan paragraf',
  'ocr_studio.mode_fast':
      'Cepat',
  'ocr_studio.mode_fast_sub':
      'Gambar mentah · pindai cepat di perangkat',
  'ocr_studio.page_chip':
      'Halaman {n}',
  'ocr_studio.pages':
      'Rentang halaman',
  'ocr_studio.pages_batch':
      '{n} halaman pertama',
  'ocr_studio.pages_current':
      'Halaman ini ({n})',
  'ocr_studio.pages_custom':
      'Rentang khusus',
  'ocr_studio.preview':
      'Tampilkan / sembunyikan pratinjau sumber',
  'ocr_studio.progress_page':
      'Memindai halaman {done} / {total}…',
  'ocr_studio.quality':
      'Kualitas pengenalan',
  'ocr_studio.range_empty':
      'Masukkan rentang halaman yang valid.',
  'ocr_studio.range_hint':
      'mis. 1-5, 8 (total {total} halaman)',
  'ocr_studio.read':
      'Dengarkan',
  'ocr_studio.rescan':
      'Pindai ulang',
  'ocr_studio.save_txt':
      'Simpan TXT',
  'ocr_studio.saved_txt':
      'Teks disimpan: {name}',
  'ocr_studio.select_on_image':
      'Pilih pada gambar',
  'ocr_studio.start':
      'Kenali teks',
  'ocr_studio.stats':
      '{words} kata · {chars} karakter',
  'ocr_studio.stop_read':
      'Berhenti',
  'ocr_studio.title':
      'Studio pengenalan teks',
  'foot.apk_note':
      'Aplikasi itu sendiri (~95 MB) sebagian besar berisi mesin di perangkat: pengenalan teks (OCR), terjemahan, video, PDF. Semuanya ada di dalam paket sehingga berfungsi tanpa internet.',
  'foot.clean':
      'Bersihkan cache ({size})',
  'foot.clean_note':
      'Salinan, gambar mini, berkas sementara, dan cache Drive dihapus. Dokumen Anda tidak disentuh; item yang dibuka dalam 10 menit terakhir dilewati.',
  'foot.delete_models':
      'Hapus model bahasa',
  'foot.docs':
      'Dokumen di dalam aplikasi',
  'foot.docs_sub':
      'Pindaian lama dan dokumen baru — berkas ANDA, tidak pernah dibersihkan. Dihapus jika aplikasi dicopot; ketuk lalu pindahkan ke Dokumen',
  'foot.drive':
      'Cache Google Drive',
  'foot.drive_sub':
      'Salinan lokal berkas yang dibuka dari Drive — diunduh lagi saat dibuka ulang',
  'foot.empty':
      'Tidak ada yang bisa diukur.',
  'foot.freed':
      '{size} dibebaskan.',
  'foot.kw_cache':
      'cache ukuran ruang',
  'foot.models':
      'Model bahasa terjemahan',
  'foot.models_deleted':
      '{n} model bahasa dihapus; akan diunduh lagi saat diperlukan.',
  'foot.models_sub':
      'Model yang diunduh untuk terjemahan di perangkat (~30 MB per bahasa)',
  'foot.nothing_freed':
      'Tidak ada lagi yang bisa dibebaskan.',
  'foot.other':
      'Pengaturan dan indeks',
  'foot.other_sub':
      'Indeks pencarian, riwayat, pengaturan, data WebView',
  'foot.picker':
      'Salinan pemilih berkas',
  'foot.picker_sub':
      'Salinan berkas yang dipilih dengan pemilih; dihapus otomatis setelah 7 hari',
  'foot.section':
      'Penyimpanan aplikasi',
  'foot.shared':
      'Salinan berbagi',
  'foot.shared_sub':
      'Salinan berkas yang dibuka dengan “Buka dengan” atau disiapkan untuk dibagikan; dihapus otomatis setelah 7 hari',
  'foot.system':
      'Menurut Android: aplikasi {app} · data {data}',
  'foot.system_settings':
      'Buka pengaturan aplikasi Android',
  'foot.temp':
      'Berkas sementara',
  'foot.temp_sub':
      'Hasil antara pindaian, pratinjau arsip, cache WebView',
  'foot.thumbs':
      'Gambar mini',
  'foot.thumbs_sub':
      'Pratinjau video, PDF, dan APK — dibuat ulang saat diperlukan',
  'foot.tile_sub':
      'Lihat apa yang memakan berapa ruang; bersihkan cache dan salinan',
  'foot.title':
      'Penyimpanan yang dipakai aplikasi',
  'foot.total_sub':
      'Di folder milik aplikasi (data + cache). Aplikasi itu sendiri (APK) tidak termasuk.',
  'smp.excel_name':
      'Contoh anggaran',
  'smp.folder':
      'Contoh',
  'smp.note_1':
      'Catatan dan berkas Markdown dibuka di editor teks biasa',
  'smp.note_2':
      'Judul, daftar, dan teks tebal diformat di pratinjau',
  'smp.note_3':
      'Berkas ini aman untuk dihapus',
  'smp.note_name':
      'Catatan contoh',
  'smp.note_title':
      'Catatan contoh',
  'smp.sl_edit':
      'Edit',
  'smp.sl_edit1':
      'Tambahkan teks, bentuk, dan gambar',
  'smp.sl_edit2':
      'Pilih tema dari tab Desain',
  'smp.sl_notes':
      'Catatan pembicara muncul di mode presentasi.',
  'smp.sl_read':
      'Baca',
  'smp.sl_read1':
      'Geser di mode presentasi',
  'smp.sl_read2':
      'Lompat ke slide mana pun dari gambar mini',
  'smp.sl_sub':
      'Ketuk slide untuk mengedit',
  'smp.sl_title':
      'Presentasi contoh',
  'smp.slides_name':
      'Presentasi contoh',
  'smp.word_name':
      'Dokumen contoh',
  'smp.word_p1':
      'Ubah dokumen ini sesuka Anda: ketuk teks lalu mulai mengetik.',
  'smp.word_p2':
      'Simpan, Urungkan, dan Ulangi ada di tempat yang sama pada bilah atas setiap editor.',
  'smp.word_p3':
      'Gunakan "Bagikan / Ekspor" di menu ⋮ untuk mengekspor ke PDF atau format lain.',
  'smp.word_title':
      'Selamat datang!',
  'smp.xl_actual':
      'Aktual',
  'smp.xl_food':
      'Bahan makanan',
  'smp.xl_item':
      'Item',
  'smp.xl_other':
      'Lainnya',
  'smp.xl_plan':
      'Rencana',
  'smp.xl_rent':
      'Sewa',
  'smp.xl_sheet':
      'Anggaran',
  'smp.xl_total':
      'Total',
  'smp.xl_transport':
      'Transportasi',
  'apps.app_info':
      'Info aplikasi (pengaturan sistem)',
  'apps.copy_package':
      'Salin nama paket',
  'apps.count':
      '{n} aplikasi',
  'apps.days_ago':
      '{n} hari lalu',
  'apps.filter_unused':
      'Tidak dipakai {n}+ hari',
  'apps.installed_on':
      'Dipasang',
  'apps.long_ago':
      'lebih dari 2 tahun',
  'apps.never_opened':
      'tidak pernah dibuka',
  'apps.no_unused':
      'Tidak ada aplikasi yang lama tidak dipakai.',
  'apps.package_copied':
      'Nama paket disalin',
  'apps.show_system':
      'Tampilkan aplikasi sistem',
  'apps.size_app':
      'Aplikasi',
  'apps.size_data':
      'Data',
  'apps.sort_idle':
      'Paling lama tidak dipakai dulu',
  'apps.sort_installed':
      'Menurut tanggal pemasangan',
  'apps.sort_menu':
      'Urutkan dan tampilkan',
  'apps.sort_size':
      'Menurut ukuran',
  'apps.stat_cache':
      'Cache',
  'apps.stat_unused':
      'Tidak dibuka {n}+ hari',
  'apps.stat_unused_size':
      'tidak dipakai · {size}',
  'apps.storage_settings':
      'Penyimpanan & cache',
  'apps.tip_cache':
      'Tips: cache {name} sebesar {size} dan bisa dibersihkan',
  'apps.tip_clear_cache':
      'Bersihkan cache',
  'apps.tip_restore':
      'Pulihkan {n} tips yang disembunyikan',
  'apps.tip_unused':
      'Tips: {name} sudah {n} hari tidak dibuka dan memakai {size}',
  'apps.tip_unused_long':
      'Tips: {name} sudah lama tidak dibuka dan memakai {size}',
  'apps.today':
      'hari ini',
  'apps.uninstall':
      'Copot pemasangan',
  'apps.uninstalled':
      '{name} dicopot',
  'apps.usage_needed':
      'Izin diperlukan untuk tanggal terakhir dibuka',
  'ved.apply_audio':
      'Tambah suara',
  'ved.apply_cut':
      'Potong',
  'ved.apply_mute':
      'Bisukan',
  'ved.audio_overlap':
      'Di sini sudah ada suara yang ditambahkan',
  'ved.cut_too_much':
      'Seluruh video tidak bisa dipotong',
  'ved.frame_failed':
      'Tidak bisa menyimpan bingkai',
  'ved.frame_saved':
      'Foto disimpan: {name}',
  'ved.frame_suffix':
      'bingkai',
  'ved.remove':
      'Hapus',
  'ved.replace_off':
      'Campuran',
  'ved.replace_on':
      'Suara asli dibisukan',
  'ved.result':
      'Hasil {t}',
  'ved.row_cut':
      'Potong {start}–{end}',
  'ved.row_mute':
      'Dibisukan {start}–{end}',
  'ved.save_frame':
      'Simpan bingkai sebagai foto',
  'ved.sel_audio':
      'Pilih di mana suara diputar',
  'ved.sel_cut':
      'Pilih bagian yang akan dipotong dengan pegangan',
  'ved.sel_mute':
      'Pilih bagian yang akan dibisukan',
  'ved.set_end':
      'Akhiri di sini',
  'ved.set_start':
      'Mulai di sini',
  'ved.sound_off':
      'Tanpa suara',
  'ved.sound_on':
      'Suara menyala',
  'ved.step_back':
      'Mundur satu langkah',
  'ved.step_fwd':
      'Maju satu langkah',
  'ved.title':
      'Edit video',
  'ved.tool_audio':
      'Tambah suara',
  'ved.tool_cut':
      'Potong bagian',
  'ved.tool_mute':
      'Bisukan bagian',
  'ved.tool_rotate':
      'Putar',
  'ved.undo':
      'Urungkan',
  'link.bad':
      'Ini bukan tautan Dosya Okuyucu',
  'link.bad_key':
      'Tidak bisa didekripsi — tautan tidak lengkap atau rusak',
  'link.copied':
      'Tautan disalin',
  'link.copy':
      'Salin',
  'link.drive_error':
      'Google Drive tidak dapat menyelesaikan ini sekarang',
  'link.gone':
      'Tautan telah dicabut atau kedaluwarsa',
  'link.need_drive':
      'Tidak bisa mengunduh tanpa masuk — hubungkan Google di tab Drive lalu coba lagi',
  'link.need_selection':
      'Pilih berkas di Kirim cepat dulu',
  'link.need_signin':
      'Anda perlu menghubungkan Google Drive',
  'link.note_key':
      'Kunci ada setelah # di tautan dan tidak pernah sampai ke Google. Siapa pun yang memiliki tautan dapat membuka berkas — bagikan hanya kepada orang yang Anda percaya dan cabut setelah selesai.',
  'link.offline':
      'Mode luring aktif — berbagi tautan dimatikan',
  'link.open':
      'Buka tautan',
  'link.open_go':
      'Unduh dan dekripsi',
  'link.open_hint':
      'Tempel tautan yang Anda terima',
  'link.peer':
      'Tautan',
  'link.ready':
      'Tautan siap',
  'link.received':
      'Diterima dari tautan: {name}',
  'link.receiving':
      'Menerima dari tautan',
  'link.revoke':
      'Cabut tautan',
  'link.revoke_body':
      'Berkas terenkripsi dihapus dari Drive Anda; tautan berhenti berfungsi.',
  'link.revoke_q':
      'Cabut tautan ini?',
  'link.revoked':
      'Tautan dicabut',
  'link.send':
      'Kirim pilihan sebagai tautan ({n})',
  'link.sending':
      'Mengenkripsi dan mengunggah ke Drive',
  'link.sent_list':
      'Tautan terkirim',
  'link.share':
      'Bagikan',
  'link.share_text':
      'Berkas terenkripsi lewat Dosya Okuyucu ({name}): {url}',
  'link.sub':
      'Tidak perlu Wi-Fi bersama: berkas dienkripsi di ponsel dan diunggah ke Google Drive Anda sendiri; penerima membuka tautan di Dosya Okuyucu',
  'link.title':
      'Kirim sebagai tautan (internet)',
  'upd.auto':
      'Beri tahu tentang versi baru',
  'upd.auto_sub':
      'Versi baru muncul di layar utama. Unduh dan pasang hanya dimulai saat Anda mengetuk; aplikasi terbuka kembali sendiri setelahnya.',
  'upd.b_downloading':
      'Mengunduh · {p}%',
  'upd.b_install':
      'Pasang',
  'upd.b_one':
      '{t} · v{v}',
  'upd.b_ready_title':
      'Pembaruan diunduh',
  'upd.b_title':
      'Versi baru tersedia',
  'upd.b_update':
      'Perbarui',
  'upd.check':
      'Periksa pembaruan',
  'upd.checking':
      'Memeriksa…',
  'upd.current':
      'Versi terpasang v{v}',
  'upd.download_failed':
      'Unduhan gagal.',
  'upd.downloading':
      'Mengunduh v{v}… {p}%',
  'upd.failed':
      'Tidak bisa memeriksa — periksa koneksi Anda.',
  'upd.found':
      'Versi baru v{v} tersedia',
  'upd.install_now':
      'Perbarui sekarang',
  'upd.latest':
      'Anda memakai versi terbaru (v{v}).',
  'upd.permission':
      'Izinkan "Pasang aplikasi tidak dikenal", lalu coba lagi.',
  'upd.play_ready':
      'Pembaruan diunduh.',
  'upd.ready':
      'Versi baru v{v} siap.',
  'upd.reopen':
      'Buka kembali setelah pembaruan',
  'upd.reopen_off':
      'Mati — ketuk dan izinkan "Tampilkan di atas aplikasi lain". Tanpa itu Anda mendapat notifikasi setelah pemasangan.',
  'upd.reopen_on':
      'Aktif — aplikasi terbuka kembali saat pemasangan selesai.',
  'upd.restart':
      'Mulai ulang',
  'upd.security_body':
      'Masalah keamanan telah diperbaiki. Harap perbarui ke setidaknya v{v}.',
  'upd.security_title':
      'Pembaruan keamanan diperlukan',
  'upd.title':
      'Pembaruan',
  'upd.unsupported':
      'Pembaruan otomatis tidak tersedia di build ini.',
  'upd.whats_new':
      'v{v} — Yang baru',
  'vw.dont_save':
      'Jangan simpan',
  'vw.goto_page':
      'Ke halaman…',
  'vw.ocr':
      'Kenali teks (OCR)',
  'vw.ocr_copied':
      'Teks terpilih disalin',
  'vw.ocr_failed':
      'OCR gagal: {error}',
  'vw.ocr_none':
      'Tidak ada teks ditemukan (OCR).',
  'vw.preparing':
      'Menyiapkan…',
  'vw.prettify':
      'Format (JSON/XML)',
  'vw.print':
      'Cetak',
  'vw.restart_doc':
      'Mulai dari awal',
  'vw.resumed_page':
      'Melanjutkan dari halaman {n}',
  'vw.resumed_slide':
      'Melanjutkan dari slide {n}',
  'vw.rotate_failed':
      'Tidak bisa memutar: {error}',
  'vw.rotate_left':
      'Putar 90° ke kiri',
  'vw.rotate_right':
      'Putar 90° ke kanan',
  'vw.rotated_left':
      'Halaman {n} diputar ke kiri',
  'vw.rotated_right':
      'Halaman {n} diputar ke kanan',
  'vw.select_ocr_none':
      'Tidak ada teks yang bisa dipilih di halaman ini',
  'vw.select_ocr_running':
      'Mengenali teks…',
  'vw.selected_text':
      'Teks terpilih',
  'vw.slides_no_text':
      'Dokumen ini tidak memiliki teks untuk dijadikan slide.',
  'vw.slides_share':
      'Presentasi (.pptx)',
  'vw.to_slides':
      'Ubah menjadi slide',
  'vw.toc_all':
      'Semua',
  'vw.toc_no_match':
      'Tidak ada judul yang cocok',
  'vw.toc_search':
      'Cari judul',
  'vw.word_count':
      'Jumlah kata',
  'vw.zoom_in':
      'Perbesar',
  'vw.zoom_out':
      'Perkecil',
  'srch.ai_error':
      'Aksi pintar gagal: {error}',
  'srch.capped':
      ' · 1000 hasil pertama',
  'srch.clear_history':
      'Hapus riwayat',
  'srch.content_hits':
      '{n} kecocokan · baris {line}',
  'srch.in_content':
      'Cari di dalam berkas',
  'srch.in_filter_hint':
      'Cari di {n} berkas yang difilter…',
  'srch.in_hint':
      'Cari di {name}…',
  'srch.index_building':
      'Membangun indeks pencarian — ini hanya sekali; pencarian berikutnya instan.',
  'srch.index_stale':
      'Berkas berubah — indeks sedang diperbarui di latar belakang.',
  'srch.mode_content':
      'Di dalam berkas',
  'srch.mode_found':
      '{n} hasil · {total} berkas dicari',
  'srch.mode_name':
      'Di nama',
  'srch.mode_press':
      'Ketik lalu tekan "Cari" · mencari di {n} berkas pada filter saat ini',
  'srch.mode_reading':
      'Membaca {n} / {total} berkas…',
  'srch.mode_scope':
      'Mencari nama dari {n} berkas pada filter saat ini',
  'srch.no_result':
      'Tidak ada hasil.',
  'srch.opened':
      'Dibuka dari pencarian',
  'srch.options':
      'Opsi pencarian',
  'srch.rebuild_index':
      'Bangun ulang indeks',
  'srch.recent':
      'Pencarian terakhir',
  'srch.scope_everywhere':
      'Di mana saja',
  'srch.scope_here':
      'Di folder ini',
  'srch.scope_title':
      'Cakupan pencarian',
  'srch.searching':
      'Mencari…',
  'srch.smart_off':
      'Matikan pencarian pintar',
  'srch.smart_on':
      'Nyalakan pencarian pintar',
  'srch.understood':
      'Dipahami:',
  'card.add':
      'Tambah',
  'card.add_files':
      'Pilih berkas',
  'card.add_to':
      'Tambahkan ke {name}',
  'card.color':
      'Warna',
  'card.edit':
      'Edit kartu',
  'card.empty':
      'Kartu ini kosong',
  'card.empty_kinds':
      'Hanya jenis ini yang bisa masuk ke kartu ini: {kinds}.',
  'card.empty_sub':
      'Ketuk “Tambah” untuk memilih berkas, atau salin berkas dan tempel di sini.',
  'card.icon':
      'Ikon',
  'card.in_important':
      'Di dalam Berkas Penting',
  'card.in_important_sub':
      'Jika aktif, berkas diberi bintang dan dilindungi dari penghapusan.',
  'card.kind_all':
      'Semuanya',
  'card.name':
      'Nama kartu',
  'card.name_hint':
      'mis. Kesehatan, Tagihan, Anak',
  'card.new':
      'Kartu baru',
  'card.none_fit':
      'Tidak ada item terpilih yang cocok dengan jenis kartu ini.',
  'card.on_home':
      'Tampilkan di layar utama',
  'card.remove':
      'Hapus kartu',
  'card.remove_msg':
      'Hapus kartu “{name}”? Folder dan berkasnya TIDAK dihapus.',
  'card.section':
      'Kartu saya',
  'card.skipped':
      '{n} berkas dilewati (jenis tidak diizinkan di kartu ini).',
  'card.tile_sub_empty':
      'Kosong',
  'card.view':
      'Tampilan',
  'card.view_folder':
      'Folder',
  'card.view_gallery':
      'Galeri',
  'card.what_goes':
      'Apa yang masuk?',
  'chart.add':
      'Sisipkan',
  'chart.added':
      'Bagan ditambahkan — ditulis ke berkas saat disimpan',
  'chart.approx':
      '≈ perkiraan',
  'chart.area':
      'Area',
  'chart.bar':
      'Batang',
  'chart.barPercent':
      'Batang bertumpuk 100%',
  'chart.barStacked':
      'Batang bertumpuk',
  'chart.column':
      'Kolom',
  'chart.columnPercent':
      'Kolom bertumpuk 100%',
  'chart.columnStacked':
      'Kolom bertumpuk',
  'chart.doughnut':
      'Donat',
  'chart.file_chart':
      'Bagan',
  'chart.group_insert':
      'Sisipkan',
  'chart.hint':
      'Baris pertama menjadi nama seri, kolom pertama menjadi kategori. Bagan ditulis saat disimpan dan tampil di Excel dan Google Sheets.',
  'chart.insert':
      'Sisipkan bagan',
  'chart.line':
      'Garis',
  'chart.no_numbers':
      'Tidak ada angka pada pilihan',
  'chart.pie':
      'Pai',
  'chart.radar':
      'Radar',
  'chart.scatter':
      'Sebar (XY)',
  'chart.select_range':
      'Pilih dulu data beserta judul kolomnya (minimal dua baris).',
  'chart.title':
      'Judul (opsional)',
  'chart.type':
      'Jenis bagan',
  'chart.undo_add':
      'sisipkan bagan',
  'chart.undo_delete':
      'hapus bagan',
  'chart.undo_edit':
      'edit bagan',
  'smo.arrange':
      'Urutkan ulang dan ganti nama',
  'smo.arrange_sub':
      'Seret pada pegangan, ketuk pensil untuk mengganti nama',
  'smo.cols':
      '{n} kolom',
  'smo.default_name':
      'Ganti nama menjadi "{name}"',
  'smo.hint':
      'Tekan lama: nama dan urutan · Cubit: jumlah kolom',
  'smo.layout':
      'Tata letak',
  'smo.learn_n':
      'Dipelajari dari {n} koreksi',
  'smo.learn_none':
      'Pada berkas yang salah urut, ketuk ⋮ → "Kategori salah?"; berkas serupa tidak akan mengalami kesalahan yang sama.',
  'smo.learn_reset':
      'Atur ulang',
  'smo.learn_reset_body':
      'Berkas yang Anda koreksi tetap benar; hanya pembelajaran untuk berkas baru yang dihapus.',
  'smo.learn_reset_title':
      'Lupakan yang dipelajari?',
  'smo.learn_title':
      'Pembelajaran',
  'smo.move_first':
      'Pindahkan ke atas',
  'smo.rename':
      'Ganti nama',
  'smo.rename_label':
      'Nama asli: {name}',
  'smo.rename_title':
      'Nama folder',
  'smo.reset':
      'Atur ulang nama dan urutan',
  'smo.rule':
      'Aturan pemindahan…',
  'smo.rule_body':
      'Berkas yang dikelompokkan ke "{cat}" akan dipindahkan ke "{folder}" — {n} sekarang, yang baru nanti. Setiap pemindahan bisa diurungkan; matikan aturan dari menu ini.',
  'smo.rule_failed':
      '{n} berkas dipindahkan, {fail} gagal: {error}',
  'smo.rule_moved':
      '{n} berkas dipindahkan menurut aturan',
  'smo.rule_off':
      'Matikan aturan pemindahan',
  'smo.rule_ok':
      'Nyalakan',
  'smo.rule_on':
      'Aturan pemindahan: {folder}',
  'smo.rule_pick':
      'Atur aturan di sini',
  'smo.rule_title':
      'Aturan pemindahan',
  'gal.enh_ai':
      'Perbesar 4× dan pulihkan dengan AI',
  'gal.enh_ai_download':
      'Mengunduh model ~5 MB sekali, lalu berfungsi luring',
  'gal.enh_ai_hint':
      'Berjalan di perangkat; foto besar bisa memakan satu atau dua menit',
  'gal.enh_already':
      'Gambar ini sedang ditingkatkan',
  'gal.enh_auto':
      'Peningkatan otomatis',
  'gal.enh_auto_hint':
      'Pengurangan noise + kontras + ketajaman',
  'gal.enh_compare':
      'Sebelum / sesudah',
  'gal.enh_denoise':
      'Kurangi noise / grain',
  'gal.enh_job':
      'Peningkatan gambar',
  'gal.enh_running':
      'Meningkatkan · {n}%',
  'gal.enh_saved':
      'Salinan disimpan: {name}',
  'gal.enh_sharpen':
      'Pertajam (buram)',
  'gal.enh_started':
      'Meningkatkan di latar belakang — silakan lanjut menjelajah, Anda akan diberi tahu',
  'gal.enh_working':
      'Meningkatkan…',
  'gal.enhance':
      'Tingkatkan',
  'gal.multi_select':
      'Pilih beberapa foto',
  'gal.repaired':
      'Gambar rusak — menampilkan bagian yang bisa dipulihkan',
  'gal.resize':
      'Ubah ukuran',
  'gal.save_rotation':
      'Simpan salinan yang diputar',
  'gal.slideshow':
      'Tayangan slide',
  'gal.slideshow_every':
      'Setiap {n} detik',
  'gal.tools':
      'Teks & PDF',
  'gal.use_as':
      'Gunakan sebagai…',
  'gal.use_as_failed':
      'Tidak ada aplikasi yang bisa memakai foto ini.',
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
      'Miring',
  'ks.paste':
      'Tempel',
  'ks.redo':
      'Ulangi',
  'ks.s_tab':
      'Antar sel tabel (⇧ mundur)',
  'ks.save':
      'Simpan',
  'ks.select_all':
      'Pilih semua',
  'ks.title':
      'Pintasan keyboard',
  'ks.underline':
      'Garis bawah',
  'ks.undo':
      'Urungkan',
  'ks.x_delete':
      'Hapus isi',
  'ks.x_edge':
      'Lompat ke tepi data (⇧ untuk memilih)',
  'ks.x_enter':
      'Sel di bawah / atas',
  'ks.x_f2':
      'Edit di dalam sel',
  'ks.x_home':
      'Awal baris · A1',
  'ks.x_move':
      'Pindahkan sel (⇧ untuk memperluas)',
  'ks.x_page':
      '20 baris ke atas / bawah',
  'ks.x_tab':
      'Sel berikutnya / sebelumnya',
  'ks.x_type':
      'Mulai mengetik: menggantikan sel',
  'edit.autosave':
      'Simpan otomatis',
  'edit.autosave_sub':
      'Perubahan ditulis ke berkas dalam hitungan detik. Draf selalu disimpan.',
  'edit.changed_elsewhere':
      'Berkas diubah di tempat lain',
  'edit.dont_save':
      'Jangan simpan',
  'edit.draft_discard':
      'Buang',
  'edit.draft_found':
      'Perubahan belum disimpan ditemukan ({time})',
  'edit.draft_restore':
      'Pulihkan',
  'edit.draft_restored':
      'Perubahan yang belum disimpan dipulihkan',
  'edit.format_panel':
      'Format',
  'edit.hide_keyboard':
      'Sembunyikan keyboard',
  'edit.perf_overlay':
      'Penghitung latensi pengeditan',
  'edit.perf_overlay_sub':
      'Menampilkan waktu dari ketukan tombol ke layar di sudut (pengembang)',
  'edit.save_failed_short':
      'Tidak tersimpan',
  'edit.saved_at':
      'Disimpan {time}',
  'edit.saving':
      'Menyimpan…',
  'edit.show_keyboard':
      'Keyboard',
  'edit.tab_paragraph':
      'Paragraf',
  'edit.tab_styles':
      'Gaya',
  'edit.tab_text':
      'Teks',
  'edit.typing':
      'Mengetik',
  'edit.unsaved_body':
      'Dokumen ini memiliki perubahan yang belum disimpan. Perubahan akan hilang jika Anda keluar tanpa menyimpan.',
  'edit.unsaved_title':
      'Simpan perubahan Anda?',
  'tf.auto_detect':
      'Deteksi bahasa',
  'tf.auto_short':
      'otomatis',
  'tf.copied':
      'Terjemahan disalin',
  'tf.downloading':
      'Mengunduh model bahasa {lang}…',
  'tf.empty_result':
      'Hasil terjemahan kosong.',
  'tf.first_use':
      'Ini hanya diperlukan pertama kali.',
  'tf.inplace_done':
      '{n} paragraf diterjemahkan di {pages} halaman.',
  'tf.job_done':
      '{n} halaman diterjemahkan',
  'tf.job_title':
      'Menerjemahkan dokumen',
  'tf.lang_title':
      'Bahasa terjemahan',
  'tf.no_text':
      'Tidak ada teks untuk diterjemahkan.',
  'tf.page_header':
      '— Halaman {n} —',
  'tf.page_translating':
      'Menerjemahkan halaman {n} / {total}…',
  'tf.partial':
      'Dihentikan — {n} dari {total} halaman diterjemahkan.',
  'tf.preparing':
      'Menyiapkan…',
  'tf.source_lang':
      'Bahasa sumber',
  'tf.stopped':
      'Terjemahan dihentikan.',
  'tf.stopping':
      'Menghentikan…',
  'tf.swap':
      'Tukar bahasa',
  'tf.target_lang':
      'Bahasa tujuan',
  'tf.title':
      'Terjemahan',
  'tf.working':
      'Menerjemahkan…',
  'pa.add_to':
      'Tambahkan ke album',
  'pa.added':
      '{n} berkas ditambahkan ke “{name}”',
  'pa.already':
      'Sudah ada di “{name}”',
  'pa.area_hidden':
      'Area album disembunyikan. Untuk menampilkannya lagi: Analisis dan lainnya › Tampilan',
  'pa.create':
      'Buat',
  'pa.delete':
      'Hapus album',
  'pa.delete_dir':
      'Hapus album beserta berkasnya',
  'pa.delete_dir_hint':
      '{n} berkas di folder ini dihapus',
  'pa.delete_hint':
      'Berkas tetap disimpan',
  'pa.delete_msg':
      'Hapus album “{name}”? Berkasnya tetap disimpan.',
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
      'Album baru',
  'pa.remove_from':
      'Keluarkan dari album',
  'pa.removed':
      '{n} berkas dikeluarkan dari album (tidak dihapus)',
  'pa.rename':
      'Ganti nama',
  'pa.show_hidden':
      'Album tersembunyi ({n})',
  'pa.unhide':
      'Tampilkan album',
  'voice.ahmet_sub':
      'Microsoft Ahmet · suara pria Turki · tanpa unduhan · memakai kunci Azure Speech Anda sendiri (tingkat gratis: 500 ribu karakter sebulan) · butuh INTERNET: teks dikirim ke Microsoft; kembali ke suara perangkat saat luring',
  'voice.antalia_sub':
      'Antalia-2 Mini · suara pria · 7,6 juta parameter · Apache-2.0 · membaca angka, tanggal, dan jumlah uang dengan benar',
  'voice.azure_bad_region':
      'Wilayah berupa huruf kecil dan angka (mis. westeurope)',
  'voice.azure_help':
      'portal.azure.com → buat sumber daya "Speech", tingkat harga Free F0. Salin Key 1 dan Location/Region (mis. westeurope) dari "Keys and Endpoint". Kunci disimpan terenkripsi hanya di ponsel ini.',
  'voice.azure_key':
      'Kunci',
  'voice.azure_region':
      'Wilayah (mis. westeurope)',
  'voice.azure_remove':
      'Hapus kunci',
  'voice.azure_setup':
      'Masukkan kunci',
  'voice.azure_title':
      'Kunci Azure Speech',
  'voice.ema_sub':
      'EMA Lightning · 8,6 juta parameter · Apache-2.0 · tingkat kesalahan terendah pada tolok ukur bahasa Turki',
  'voice.install':
      'Unduh ({size})',
  'voice.install_failed':
      'Tidak bisa mengunduh suara: {error}',
  'voice.installed':
      '{name} terpasang',
  'voice.installed_size':
      'Terpasang · {size}',
  'voice.intro':
      'Suara Turki alami berjalan di perangkat Anda tanpa internet; teks tidak pernah keluar dari ponsel. Suara diunduh saat pertama dipakai (agar aplikasi tetap kecil) dan bisa dihapus kapan saja.',
  'voice.kokoro_en_sub':
      'Kokoro English · suara wanita Inggris (Heart) · 82 juta parameter · untuk teks Inggris',
  'voice.kokoro_tr_sub':
      'Kokoro Turkish · suara wanita (Elif) · 82 juta parameter · suara Turki paling alami; lebih besar dan lebih lambat · pelafalan: eSpeak NG (GPL-3.0)',
  'voice.online':
      'Dalam jaringan · tanpa unduhan',
  'voice.reading_selected':
      'Dipakai untuk bacakan',
  'voice.tap_to_use':
      'Ketuk untuk dipakai membacakan',
  'voice.title':
      'Suara AI',
  'pn.back_to':
      'Kembali ke halaman {n}',
  'pn.bookmarks':
      'Halaman bertanda ({n})',
  'pn.bookmarks_empty':
      'Belum ada penanda. Saat membaca, tekan lama lencana halaman atau gunakan tombol di sini.',
  'pn.chip_label':
      'Halaman {n} dari {total}. Ketuk untuk ke halaman, tekan lama untuk menandai.',
  'pn.field_hint':
      'Halaman (1–{total})',
  'pn.filmstrip':
      'Strip halaman',
  'pn.first':
      'Halaman pertama',
  'pn.last':
      'Halaman terakhir',
  'pn.next':
      'Halaman berikutnya (tahan: lebih cepat)',
  'pn.next_page':
      'Halaman berikutnya',
  'pn.position':
      'Halaman {n} dari {total} · {p}%',
  'pn.prev':
      'Halaman sebelumnya (tahan: lebih cepat)',
  'pn.prev_page':
      'Halaman sebelumnya',
  'pn.progress_pct':
      '{n}% terbaca',
  'pn.quick_jump':
      'Lompat cepat',
  'pn.star':
      'Tandai halaman ini',
  'pn.starred':
      'Halaman {n} ditandai',
  'pn.title':
      'Ke halaman',
  'pn.unstar':
      'Hapus penanda',
  'pn.unstarred':
      'Penanda dihapus dari halaman {n}',
  'rc.after':
      'Sesudah',
  'rc.before':
      'Sebelum',
  'rc.confirm_all':
      '{n} berkas lama akan dipindahkan ke tempat sampah. Berkas yang diubah ukurannya tetap ada.',
  'rc.done_snack':
      '{n} berkas lama dipindahkan ke tempat sampah',
  'rc.empty':
      'Tidak ada yang dibandingkan',
  'rc.keep_all':
      'Simpan semua',
  'rc.keep_both':
      'Simpan keduanya',
  'rc.new':
      'Baru',
  'rc.new_trashed':
      'Berkas baru dihapus',
  'rc.old':
      'Lama',
  'rc.old_trashed':
      'Berkas lama ada di tempat sampah',
  'rc.open_new':
      'Buka yang baru',
  'rc.open_old':
      'Buka yang lama',
  'rc.title':
      'Bandingkan lama ↔ baru',
  'rc.title_enhance':
      'Sebelum / sesudah',
  'rc.trash_all_old':
      'Hapus semua yang lama',
  'rc.trash_new':
      'Hapus yang baru',
  'rc.trash_old':
      'Hapus yang lama',
  'rc.view_side':
      'Berdampingan',
  'rc.view_slider':
      'Penggeser',
  'sf.building_pdf':
      'Menyiapkan PDF…',
  'sf.default_prefix':
      'Pindai',
  'sf.job_name':
      'Pindai dokumen',
  'sf.ocr_progress':
      'Memindai teks… ({n} / {total} halaman)',
  'sf.save_failed':
      'Tidak bisa menyimpan hasil pindai: {error}',
  'sf.saved_n':
      '{n} halaman disimpan sebagai PDF',
  'sf.scanner_failed':
      'Tidak bisa membuka pemindai: {error}\nIzin kamera mungkin belum diberikan.',
  'sf.skip_ocr':
      'Lewati teks',
  'sf.tip1_body':
      'Letakkan dokumen secara datar; tepinya ditemukan otomatis.',
  'sf.tip1_title':
      '1 · Ambil halaman',
  'sf.tip2_body':
      'Ketuk ikon halaman-dengan-plus biru di kanan bawah: kamera terbuka lagi untuk halaman berikutnya. Ulangi untuk setiap halaman.',
  'sf.tip2_title':
      '2 · Pakai tombol halaman ➕ untuk halaman lain',
  'sf.tip3_body':
      'Ketuk setelah semua halaman diambil. Ada yang terlewat? Tambahkan nanti dengan "Tambah halaman" di studio dokumen.',
  'sf.tip3_title':
      '3 · "Berikutnya" MENYELESAIKAN pemindaian',
  'sf.tip_next_label':
      'Berikutnya',
  'sf.tips_never':
      'Mengerti, jangan tampilkan lagi',
  'sf.tips_start':
      'Mulai memindai',
  'sf.tips_sub':
      'Tiga tombol penting di layar pemindai yang terbuka berikutnya:',
  'sf.tips_title':
      'Cara memindai',
  'sf.title':
      'Menyiapkan dokumen',
  'pick.all':
      'Semua',
  'pick.browse_folders':
      'Jelajahi folder',
  'pick.empty':
      'Tidak ada berkas yang cocok di folder ini.',
  'pick.failed':
      'Berkas tidak bisa diserahkan ke aplikasi yang meminta.',
  'pick.filter_hint':
      'Cari berkas {kind}…',
  'pick.for_caller':
      'Untuk {app}',
  'pick.last_folder':
      'Folder terakhir dipakai',
  'pick.matches_count':
      '{n} berkas',
  'pick.need_permission':
      'Izin penyimpanan diperlukan untuk menampilkan daftar berkas.',
  'pick.no_filter_matches':
      'Tidak ada berkas yang cocok dengan pencarian.',
  'pick.no_matches':
      'Tidak ada berkas jenis ini. Jelajahi folder atau gunakan "Lainnya" untuk Drive/Galeri.',
  'pick.other_sources':
      'Lainnya',
  'pick.search_hint':
      'Cari semua berkas…',
  'pick.select_all':
      'Pilih semua',
  'pick.select_n':
      'Pilih ({n})',
  'pick.sort_name':
      'Menurut nama',
  'pick.sort_newest':
      'Terbaru',
  'pick.title':
      'Pilih berkas',
  'pick.unreadable':
      'Folder ini tidak bisa dibaca.',
  'sa.card_sub':
      'Melihat ISI gambar: gambar ucapan selamat pagi, meme teks dan poster, foto buram dan gelap; dokumen ganda dan terlupakan',
  'sa.clean':
      'Tidak ditemukan yang tidak perlu',
  'sa.expense_do':
      'Tambah pengeluaran',
  'sa.expense_done':
      'Ditambahkan ke Giderler.csv',
  'sa.expense_hint':
      'Struk/faktur: Anda bisa menambahkan jumlahnya ke daftar pengeluaran',
  'sa.expense_none':
      'Tidak ada tanggal atau jumlah pada struk',
  'sa.intro':
      'Analisis berjalan sepenuhnya di ponsel Anda (pengenalan teks tanpa internet). 1.500 gambar obrolan terbaru dibaca; proses kedua hanya melihat yang baru. Tidak ada yang dihapus otomatis: tinjau setiap kelompok dan pindahkan pilihan Anda ke tempat sampah.',
  'sa.job_name':
      'Gambar dan dokumen',
  'sa.job_title':
      'Analisis pintar',
  'sa.rescan':
      'Analisis lagi',
  'sa.start':
      'Mulai analisis',
  'sa.step_docs':
      'Memeriksa dokumen',
  'sa.step_done':
      '{n} berkas · {size} bisa dibersihkan',
  'sa.step_images':
      'Membaca gambar: {n}/{total}',
  'sa.title':
      'Analisis pembersihan pintar',
  'sa.trash_sub':
      '{n} item · {size} — kosongkan untuk mendapat ruang',
  'sa.trash_title':
      'Tempat sampah',
  'sa.vault_do':
      'Pindahkan ke brankas',
  'sa.vault_hint':
      'Dokumen identitas: disarankan disimpan di brankas terenkripsi',
  'trash.auto_days':
      'Dihapus otomatis setelah {n} hari',
  'trash.auto_off':
      'Pembersihan otomatis mati',
  'trash.delete_forever':
      'Hapus permanen',
  'trash.delete_one_body':
      '“{name}” akan dihapus tanpa bisa dikembalikan.',
  'trash.deleted_one':
      '“{name}” dihapus permanen.',
  'trash.empty':
      'Tempat sampah kosong',
  'trash.empty_action':
      'Kosongkan',
  'trash.empty_confirm_title':
      'Kosongkan tempat sampah?',
  'trash.emptying':
      'Mengosongkan tempat sampah',
  'trash.emptying_name':
      'Mengosongkan tempat sampah',
  'trash.filtered':
      '{n} / {total} item',
  'trash.restore':
      'Pulihkan',
  'trash.restore_all':
      'Pulihkan semua',
  'trash.restore_all_done':
      '{n} item dipulihkan',
  'trash.restore_all_name':
      'Memulihkan dari tempat sampah',
  'trash.restore_failed':
      'Tidak bisa memulihkan: {error}',
  'trash.search':
      'Cari di tempat sampah',
  'trash.search_hint':
      'Cari di tempat sampah…',
  'trash.title':
      'Tempat sampah',
  'ana.by_type':
      'Menurut jenis',
  'ana.cache_total':
      '{v} di antaranya adalah cache — aman dibersihkan',
  'ana.filter_count':
      '{n} filter',
  'ana.free_space':
      'Kosongkan ruang (saran pembersihan)',
  'ana.free_space_note':
      'Tempat sampah, duplikat, gambar mirip, media obrolan, dan berkas tak berguna — semua di satu tempat',
  'ana.largest':
      'Berkas terbesar',
  'ana.no_files':
      'Tidak ada berkas untuk ditampilkan.',
  'ana.no_result':
      'Tidak ada hasil.',
  'ana.no_scan':
      'Belum ada hasil pemindaian.',
  'ana.result_count':
      '{n} hasil',
  'ana.results':
      'Hasil pencarian',
  'ana.scope_all':
      'Semua',
  'ana.search_all':
      'Cari semua berkas…',
  'ana.searching':
      'Mencari…',
  'ana.similar_note':
      'Jepretan beruntun dan foto yang hampir sama',
  'ana.total_summary':
      '{n} berkas · {size}',
  'ana.usage_unreadable':
      'Penggunaan penyimpanan tidak bisa dibaca.',
  'ana.used_free':
      '{used} terpakai · {free} bebas',
  'help.ftitle':
      'Fitur & bantuan',
  'help.hint':
      'Cari fitur: pangkas, kata sandi, gabung…',
  'help.how':
      'Caranya',
  'help.more':
      '{n} fitur lagi',
  'help.none':
      'Tidak ada fitur untuk "{q}". Anda bisa memintanya di bawah.',
  'help.open':
      'Bantuan: semua fitur',
  'help.report':
      'Laporkan masalah',
  'help.report_body':
      'Jelaskan masalah secara singkat (apa yang Anda lakukan, apa yang diharapkan, apa yang terjadi):',
  'help.req_field':
      'Permintaan Anda…',
  'help.req_hint':
      'Jelaskan apa yang Anda inginkan dari aplikasi. Permintaan disimpan di perangkat ini dan dibuka di browser untuk dikirim ke pengembang.',
  'help.req_mine':
      'Permintaan saya',
  'help.req_saved':
      'Permintaan disimpan di perangkat ini (browser tidak bisa dibuka)',
  'help.req_send':
      'Kirim',
  'help.req_sent':
      'Permintaan disimpan dan dibuka',
  'help.request':
      'Minta fitur',
  'help.tile_sub':
      'Izin, PIN brankas, berbagi jaringan, kunci AI',
  'help.title':
      'Bantuan & FAQ',
  'help.where':
      'Di mana',
  'important.badge':
      'Berkas penting',
  'important.by_type':
      'Menurut jenis',
  'important.create_folder':
      'Buat folder',
  'important.delete_body_permanent':
      '{n} item penting ({names}) akan dihapus PERMANEN. Anda yakin?',
  'important.delete_body_trash':
      '{n} item penting ({names}) akan dipindahkan ke tempat sampah. Anda yakin?',
  'important.delete_category':
      'Hapus kategori',
  'important.delete_category_msg':
      'Hapus permanen kategori “{name}” beserta {n} berkasnya?',
  'important.delete_category_msg_trash':
      'Pindahkan kategori “{name}” beserta {n} berkasnya ke tempat sampah?',
  'important.gallery':
      'Galeri',
  'important.gallery_all':
      'Semua',
  'important.gallery_empty':
      'Tidak ada berkas penting jenis ini.',
  'important.missing':
      'Folder berkas penting tidak ada',
  'important.new_subfolder':
      'Kategori baru',
  'important.open_in_browser':
      'Buka folder di peramban',
  'important.rename_category':
      'Ganti nama',
  'important.search':
      'Cari berkas penting',
  'important.subfolders':
      'Kategori',
  'important.title':
      'Berkas penting',
  'ink.eraser':
      'Penghapus',
  'ink.eraser_hint':
      'Gesek di atas goresan untuk menghapus',
  'ink.failed':
      'Tidak bisa menyimpan: {error}',
  'ink.hand':
      'Pindahkan',
  'ink.hand_hint':
      'Seret untuk memindahkan · gesek atas/bawah untuk membalik halaman. Dengan pena, pakai dua jari.',
  'ink.highlighter':
      'Penanda sorot',
  'ink.pen':
      'Pena',
  'ink.redo':
      'Ulangi',
  'ink.save_note':
      'Gambar dan teks ditambahkan secara permanen ke halaman.',
  'ink.size_l':
      'Besar',
  'ink.size_m':
      'Sedang',
  'ink.size_s':
      'Kecil',
  'ink.text':
      'Teks',
  'ink.text_hint':
      'Teks yang akan ditempatkan',
  'ink.text_title':
      'Tambah teks',
  'ink.title':
      'Gambar & anotasi',
  'ink.unsaved_body':
      'Simpan gambar dan teks Anda?',
  'ink.unsaved_title':
      'Coretan belum disimpan',
  'job.channel_desc':
      'Kemajuan tugas yang berjalan seperti mengosongkan ruang, mencari duplikat, menyalin, dan mengubah ukuran.',
  'job.channel_name':
      'Operasi berkas',
  'job.error_generic':
      'Terjadi kesalahan.',
  'job.eta':
      'sisa ~{time}',
  'job.finished':
      'Selesai.',
  'job.more_running':
      '+{n} lagi',
  'job.op_created':
      'Siap: {name}',
  'job.op_done_n':
      '{n} item selesai',
  'job.op_errors':
      '{n} kesalahan',
  'job.op_items':
      '{n} item',
  'job.op_skipped':
      '{n} dilewati',
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
      '{name} terputus',
  'job.took':
      'memakan waktu {time}',
  'aiset.budget':
      'Anggaran berkas harian',
  'aiset.budget_unlimited':
      'Tanpa batas',
  'aiset.excerpt':
      'Teks yang dikirim',
  'aiset.excerpt_sub':
      'Teks maksimum yang dikirim ke cloud per berkas.',
  'aiset.exclude_add':
      'Kecualikan folder',
  'aiset.exclude_pick':
      'Kecualikan folder ini',
  'aiset.excluded':
      'Folder yang dikecualikan',
  'aiset.forget':
      'Hapus memori AI',
  'aiset.forget_confirm':
      'Hapus hasil analisis (tag, ringkasan, saran)? Berkas Anda tetap ada.',
  'aiset.forget_sub':
      'Menghapus semua catatan analisis. Berkas Anda tidak disentuh.',
  'aiset.hidden':
      'Berkas tersembunyi',
  'aiset.hidden_sub':
      'Analisis juga berkas dan folder berawalan titik?',
  'aiset.include_again':
      'Sertakan lagi',
  'aiset.send_images':
      'Kirim gambar',
  'aiset.send_text':
      'Kirim kutipan teks',
  'aiset.types':
      'Jenis yang dianalisis',
  'aiset.types_sub':
      'Jenis yang dimatikan tidak pernah dibaca.',
  'br.done':
      '{n} berkas diganti namanya.',
  'br.file_count':
      '{n} berkas',
  'br.find':
      'Cari (di nama lama)',
  'br.more_files':
      '… dan {n} berkas lagi',
  'br.partial':
      '{n} berkas diganti namanya, {fail} kesalahan: {first}',
  'br.pattern':
      'Pola nama',
  'br.preset_date_name':
      'Tanggal + nama lama',
  'br.preset_date_seq':
      'Tanggal + nomor',
  'br.preset_name_seq':
      'Nama lama + nomor',
  'br.preset_prefix':
      'Liburan-1, Liburan-2…',
  'br.preview':
      'Pratinjau',
  'br.replace':
      'Ganti',
  'br.save_template':
      'Simpan pola',
  'br.start':
      'Mulai',
  'br.title':
      'Ganti nama massal',
  'br.will_change':
      '{n} berkas akan berubah',
  'br.will_change_problems':
      '{n} berkas akan berubah · {problems} nama bermasalah akan dilewati',
  'dock.ai':
      'Pintar',
  'dock.apps':
      'Aplikasi',
  'dock.downloads':
      'Unduhan',
  'dock.drive':
      'Drive',
  'dock.edit_body':
      'Sampah, Transfer, dan Pindai tetap ada. Anda bisa menambah hingga 2 tombol ekstra di tiap sisi (Drive juga termasuk tambahan).',
  'dock.edit_title':
      'Edit panel bawah',
  'dock.extra_left':
      'Tombol tambahan (kiri)',
  'dock.extra_right':
      'Tombol tambahan (kanan)',
  'dock.free_space':
      'Kosongkan',
  'dock.history':
      'Riwayat',
  'dock.jobs':
      'Tugas',
  'dock.library':
      'Pustaka',
  'dock.long_press':
      'Tekan lama: edit panel bawah',
  'dock.new_doc':
      'Dokumen baru',
  'dock.scan':
      'Pindai',
  'dock.trash':
      'Sampah',
  'dock.vault':
      'Brankas',
  'flt.active_count':
      '{n} filter aktif',
  'flt.all':
      'Semua',
  'flt.asc':
      'Menaik',
  'flt.chat_kind':
      'Jenis berkas perpesanan',
  'flt.clear':
      'Hapus',
  'flt.date':
      'Tanggal',
  'flt.desc':
      'Menurun',
  'flt.direction':
      'Diterima / dikirim',
  'flt.file_type':
      'Jenis berkas',
  'flt.hide_dupes':
      'Sembunyikan salinan duplikat',
  'flt.none_left':
      'Tidak ada berkas tersisa',
  'flt.pick_range':
      'Pilih rentang tanggal',
  'flt.size':
      'Ukuran',
  'flt.sort':
      'Pengurutan',
  'flt.source':
      'Sumber (bisa memilih beberapa)',
  'flt.tag':
      'Tag (orang / grup)',
  'flt.title':
      'Filter dan urutkan',
  'ig.clear_all':
      'Hapus semua filter',
  'ig.empty':
      'Belum ada berkas di Berkas Penting. Gunakan ⋮ › Tambahkan ke penting pada berkas mana pun untuk mengumpulkannya di sini.',
  'ig.folder_root':
      'Umum',
  'ig.no_match':
      'Tidak ada berkas yang cocok dengan filter ini.',
  'ig.result':
      '{n} berkas',
  'ig.search_hint':
      'Cari berkas penting…',
  'ig.sec_folder':
      'Kategori (subfolder)',
  'ig.sec_size':
      'Ukuran',
  'ig.sec_tags':
      'Tag',
  'ig.sec_time':
      'Kapan',
  'ig.sec_topic':
      'Topik dokumen',
  'ig.sort':
      'Urutkan',
  'ig.tile_empty':
      'Belum ada berkas',
  'ig.title':
      'Galeri penting',
  'ig.topic':
      'Topik & folder',
  'ig.type':
      'Jenis',
  'ig.when':
      'Waktu & ukuran',
  'sx.pdf_quality':
      'Kualitas PDF',
  'sx.q_high':
      'Tinggi',
  'sx.q_medium':
      'Sedang',
  'sx.q_small':
      'Kecil',
  'sx.save_pdf':
      'Simpan PDF dengan kualitas ini',
  'sx.saved':
      'Disimpan: {name}',
  'sx.sheet':
      'Halaman',
  'sx.title':
      'Ekspor',
  'sx.to_excel':
      'Tabel Excel',
  'sx.to_excel_sub':
      'Tabel dideteksi dan dipecah menjadi sel',
  'sx.to_image_sub':
      'Setiap halaman disimpan sebagai berkas gambar terpisah',
  'sx.to_jpg':
      'Simpan sebagai gambar (JPEG)',
  'sx.to_png':
      'Simpan sebagai gambar (PNG)',
  'sx.to_txt':
      'Teks biasa (TXT)',
  'sx.to_word':
      'Dokumen Word (bisa diedit)',
  'sx.to_word_sub':
      'Teks yang dikenali, paragraf demi paragraf',
  'sx.working':
      'Mengekspor…',
  'alias.action':
      'Nama kedua pintar',
  'alias.action_hint':
      'AI menyarankan nama dan kategori; nama berkas tetap',
  'alias.batch_done':
      '{n} berkas mendapat nama kedua',
  'alias.batch_failed':
      '{n} berkas gagal',
  'alias.batch_hint':
      'Sarankan nama dan kategori untuk semua yang dipilih dengan AI',
  'alias.batch_name':
      '{n} berkas',
  'alias.batch_started':
      'Memberi nama kedua pada {n} berkas; berlanjut meski Anda keluar dari aplikasi',
  'alias.batch_title':
      'Memberi nama kedua pintar',
  'alias.change':
      'Ubah',
  'alias.done':
      'Saya menamainya: {name}',
  'alias.done_tag':
      'Saya menamainya: {name} · Tag: {tag}',
  'alias.failed':
      'Nama kedua tidak ditemukan; Anda bisa memasukkannya sendiri.',
  'alias.label':
      'Nama kedua (nama berkas tetap)',
  'alias.manual':
      'Beri nama kedua',
  'alias.saved':
      'Nama kedua: {name}',
  'alias.started':
      'Menyiapkan nama kedua pintar… Nama berkas tidak diubah.',
  'org.action':
      'Atur {n} berkas',
  'org.all_placed':
      'Semuanya sudah tampak pada tempatnya ({n} berkas sudah di folder yang benar.)',
  'org.already_placed':
      '{n} berkas sudah di folder yang benar.',
  'org.by_what':
      'Kelompokkan menurut apa?',
  'org.confirm_title':
      'Atur?',
  'org.done':
      '{n} berkas diatur.',
  'org.include_sub':
      'Sertakan subfolder',
  'org.nothing':
      'Tidak ada yang diatur',
  'org.nothing_body':
      'Tidak ada berkas untuk diatur di folder ini.',
  'org.open_folder':
      'Buka folder',
  'org.partial':
      'Beberapa berkas tidak bisa dipindahkan: {error}',
  'org.plan':
      '{files} berkas → {folders} folder',
  'org.preview':
      'Pratinjau',
  'org.title':
      'Atur otomatis',
  'org.working':
      'Mengatur',
  'org.working_name':
      'Mengatur otomatis',
  'scp.credit_free':
      'Kredit Pro (segera): {free} berkas pertama gratis — pilihan ini muat.',
  'scp.credit_pack':
      'Kredit Pro (segera): {free} berkas pertama gratis; sisanya butuh paket {n} berkas ≈ {tl} TL.',
  'scp.done_left':
      'Diatur {d} · tersisa {r}',
  'scp.files':
      '{n} berkas',
  'scp.g_docs':
      'Dokumen',
  'scp.g_images':
      'Foto',
  'scp.g_screenshots':
      'Tangkapan layar',
  'scp.g_videos':
      'Video (bingkai sampul)',
  'scp.note':
      'Urutan: dokumen dan tangkapan layar dulu, video terakhir. Jenis atau tempat yang dimatikan dilewati; berkas yang sudah diatur tetap.',
  'scp.own_key':
      'Tanpa batas dan gratis dengan kunci Gemini Anda sendiri.',
  'scp.selected':
      'Dipilih: {n} berkas',
  'scp.sources':
      'Tempat',
  'scp.src_other':
      'Folder lain',
  'scp.tile_sub':
      '{g}/{gt} jenis · {s}/{st} tempat dipilih',
  'scp.title':
      'Apa yang harus kita atur?',
  'scp.types':
      'Jenis',
  'sk.applied':
      'Mode {type} diterapkan',
  'sk.book':
      'Buku',
  'sk.book_split':
      'Dipecah menjadi {n} halaman',
  'sk.business_card':
      'Kartu nama',
  'sk.card_none':
      'Tidak ada detail kontak pada kartu',
  'sk.card_preview_title':
      'Simpan kartu kontak',
  'sk.card_save_action':
      'Simpan kontak (.vcf)',
  'sk.card_saved':
      'Kartu kontak disimpan: {name}',
  'sk.document':
      'Dokumen',
  'sk.id_card':
      'Kartu identitas',
  'sk.id_combined':
      'Depan dan belakang digabung dalam satu halaman',
  'sk.id_need_two':
      'Pindai depan dan belakang untuk kartu identitas (2 halaman)',
  'sk.photo':
      'Foto',
  'sk.receipt':
      'Struk',
  'sk.whiteboard':
      'Papan tulis',
  'sk.working':
      'Menerapkan jenis…',
  'bills.count_month':
      '{n} tagihan/struk',
  'bills.due':
      'jatuh tempo {date}',
  'bills.empty':
      'Belum ada tagihan ditemukan. Seiring analisis pintar mengenali tagihan dan struk, ringkasan bulanan muncul di sini.',
  'bills.no_amount':
      'jumlah tidak ditemukan',
  'bills.no_key':
      'Tanpa kunci API Gemini, jumlah dan tanggal ditebak di perangkat; tambahkan kunci agar pembacaan lebih akurat.',
  'bills.overdue':
      'TERLAMBAT ({date})',
  'bills.paid':
      'Lunas',
  'bills.read_n':
      '{n} tagihan dibaca',
  'bills.read_pending':
      'Baca {n} tagihan baru',
  'bills.reading':
      'Membaca tagihan… {n}/{total}',
  'bills.refresh':
      'Baca ulang tagihan',
  'bills.this_month':
      'Pengeluaran bulan ini',
  'bills.title':
      'Tagihan dan pengeluaran',
  'bills.unknown':
      'Penerbit tidak dikenal',
  'bills.upcoming':
      'Segera jatuh tempo',
  'dro.conflict_body':
      '{name} berubah baik di ponsel maupun di Drive. Mana yang harus dipertahankan?',
  'dro.conflict_title':
      'Dua versi',
  'dro.keep_both':
      'Simpan keduanya',
  'dro.local_body':
      '{name} diedit di ponsel tetapi belum diunggah ke Drive.',
  'dro.local_title':
      'Salinan ponsel berubah',
  'dro.phone_suffix':
      'ponsel',
  'dro.pin':
      'Sediakan luring',
  'dro.pinned':
      '{name} tersedia luring',
  'dro.pinned_label':
      'Luring',
  'dro.sync_failed':
      'Tidak bisa menyinkronkan',
  'dro.unpin':
      'Hapus salinan luring',
  'dro.unpinned':
      '{name} kini boleh dibersihkan untuk menghemat ruang',
  'dro.uploaded':
      '{name} diunggah ke Drive',
  'dro.use_drive':
      'Pakai versi Drive',
  'dro.use_phone':
      'Unggah versi ponsel ke Drive',
  'qrf.connected_next':
      'Terhubung → langkah 2',
  'qrf.err_hotspot':
      'Tidak bisa membuat jaringan sementara — jika hotspot menyala, matikan lalu coba lagi.',
  'qrf.err_location':
      'Nyalakan Lokasi untuk jaringan sementara.',
  'qrf.err_perm':
      'Jaringan sementara memerlukan izin "Perangkat terdekat"/lokasi.',
  'qrf.err_unsupported':
      'Ponsel ini tidak bisa membuat jaringan sementara (perlu Android 8+).',
  'qrf.join_failed':
      'Tidak bisa bergabung ke jaringan pengirim.',
  'qrf.no_address':
      'Alamat jaringan tidak ditemukan; tutup dan coba lagi.',
  'qrf.no_common_wifi':
      'Tidak ada Wi-Fi bersama?',
  'qrf.preparing':
      'Menyiapkan…',
  'qrf.scan':
      'Pindai kode QR',
  'qrf.scan_sub':
      'Kode di layar pengirim — berkas masuk ke folder ini',
  'qrf.scan_unavailable':
      'Tidak bisa membuka pemindai kode (perlu layanan Google Play).',
  'qrf.scan_unknown':
      'Ini bukan kode berbagi Dosyalarım.',
  'qrf.scan_wifi_only':
      'Itu kode 1 (jaringan). Pindai kode ke-2 di layar pengirim.',
  'qrf.served':
      'Diunduh: {n}',
  'scr.add_failed':
      'Tidak bisa menambahkan halaman: {error}',
  'scr.add_pages':
      'Tambah halaman',
  'scr.add_pages_hint':
      'Kamera atau galeri',
  'scr.change_location':
      'Ubah lokasi',
  'scr.class_hint':
      'Tampaknya {type} — pindahkan ke "Önemli Dosyalar/{folder}"?',
  'scr.class_move':
      'Pindahkan',
  'scr.move_failed':
      'Tidak bisa memindahkan: {error}',
  'scr.moved':
      'Dipindahkan · {folder}',
  'scr.open_pdf':
      'Buka PDF',
  'scr.pages_added':
      '{n} halaman ditambahkan',
  'scr.rename':
      'Ganti nama',
  'scr.rename_failed':
      'Tidak bisa mengganti nama: {error}',
  'scr.save_here':
      'Simpan di sini',
  'scr.saved_here':
      '{name} disimpan — ditampilkan di foldernya',
  'scr.tab_text':
      'Teks',
  'smart.count':
      '{n} berkas',
  'smart.create':
      'Pencarian pintar baru',
  'smart.delete':
      'Hapus pencarian pintar',
  'smart.delete_body':
      'Hanya pencarian tersimpan yang dihapus; berkas Anda tidak disentuh.',
  'smart.empty':
      'Belum ada pencarian pintar',
  'smart.empty_sub':
      'Simpan pencarian (mis. faktur, KTP, kontrak): kecocokan dari pengaturan pintar terkumpul di sini, yang baru diberi lencana.',
  'smart.entry_n':
      '{n} pencarian tersimpan',
  'smart.entry_sub':
      'Simpan pencarian; berkas baru yang cocok terkumpul sendiri',
  'smart.header':
      'Cari "{query}" · {n} berkas · {size} — kecocokan dari pengaturan pintar dan analisis berkas, diperbarui otomatis.',
  'smart.new_badge':
      'Baru',
  'smart.new_n':
      '{n} baru',
  'smart.no_items':
      'Belum ada berkas yang cocok. Akan muncul saat pengaturan pintar menyortir berkas baru.',
  'smart.query_hint':
      'Cari apa? (mis. faktur, KTP, kontrak)',
  'smart.rename':
      'Ganti nama',
  'smart.title':
      'Pencarian pintar',
  'smf.action':
      'Kategori salah?',
  'smf.action_hint':
      'sekarang: {cat}',
  'smf.body':
      'Pilih yang benar: berkas pindah ke sana dan Pengaturan pintar mempelajarinya, sehingga berkas serupa tidak akan mengalami kesalahan yang sama.',
  'smf.docs':
      'Dokumen',
  'smf.images':
      'Gambar',
  'smf.kept':
      'Oke, ditandai benar',
  'smf.learned':
      'Dipelajari: dikoreksi menjadi "{cat}"',
  'smf.learned_n':
      'Dipelajari: berkas ini dan {n} berkas serupa kini "{cat}"',
  'smf.list_hint':
      'Berkas di tempat yang salah? Menu ⋮ → "Kategori salah?" — Pengaturan pintar belajar.',
  'smf.now':
      'Pengaturan pintar menyebut "{cat}"',
  'smf.similar_body':
      '{n} berkas serupa juga dikelompokkan sebagai "{from}". Jadikan "{to}" juga?',
  'smf.similar_go':
      'Ya, perbaiki',
  'smf.similar_title':
      'Perbaiki berkas serupa juga?',
  'smf.title':
      'Seharusnya apa?',
  'smf.was_right':
      'Sudah benar',
  'usb.diag_copied':
      'Laporan disalin',
  'usb.diag_devices':
      'Perangkat terhubung',
  'usb.diag_drivable':
      'bisa dikendalikan',
  'usb.diag_host':
      'Host USB (OTG)',
  'usb.diag_mass':
      'penyimpanan massal',
  'usb.diag_no_device':
      'Tidak ada perangkat terhubung',
  'usb.diag_permission':
      'izin',
  'usb.diag_readable':
      'bisa dibaca',
  'usb.diag_saf':
      'Izin folder',
  'usb.diag_sub':
      'Mengukur saluran mana yang melihat drive terhubung dan menyarankan langkahnya.',
  'usb.diag_usable':
      'Volume yang bisa dijelajahi',
  'usb.eject_done':
      'Drive dilepas — Anda bisa mencabutnya sekarang.',
  'usb.format_read_only':
      '{fmt} dibuka hanya-baca — Anda bisa menyalin berkas ke ponsel.',
  'usb.open_raw_failed_title':
      'Tidak bisa membuka drive',
  'usb.write_protected':
      'Drive terlindung tulis secara perangkat keras — hanya-baca.',
  'fb.attach_logs':
      'Lampirkan log kesalahan terbaru',
  'fb.attach_logs_sub':
      'Membantu kami menemukan masalah',
  'fb.copied':
      'Teks disalin ke papan klip',
  'fb.copy':
      'Salin teks',
  'fb.failed':
      'Tidak bisa mengirim, coba lagi',
  'fb.idea_hint':
      'Apa yang Anda inginkan? Di layar mana, dan bagaimana?',
  'fb.more':
      'Analisis & lainnya',
  'fb.preview':
      'Pratinjau',
  'fb.privacy':
      'Hanya teks Anda, versi aplikasi, dan versi Android yang dikirim. Nama berkas, isi berkas, dan kunci API Anda tidak pernah dikirim. Ketuk "Pratinjau" untuk melihat teks lengkap sebelum mengirim.',
  'fb.send':
      'Kirim',
  'fb.thanks':
      'Terima kasih, laporan Anda siap',
  'fb.tile_sub':
      'Kirim masalah atau saran kepada kami',
  'fb.title':
      'Laporkan bug / permintaan',
  'fb.type':
      'Jenis',
  'peer.ask_switch':
      'Konfirmasi berkas masuk',
  'peer.change_folder':
      'Ubah folder',
  'peer.channel_desc':
      'Saat berkas diterima dari perangkat terdekat.',
  'peer.channel_name':
      'Perangkat terdekat',
  'peer.declined_by_peer':
      'Perangkat lain menolak berkas',
  'peer.device_name':
      'Nama perangkat ini',
  'peer.notify_title':
      'Berkas diterima',
  'peer.other_apps':
      'WhatsApp, Bluetooth, email…',
  'peer.other_apps_title':
      'Dengan aplikasi lain',
  'peer.save_to':
      'Disimpan di: {path}',
  'peer.send_failed':
      'Tidak bisa mengirim: {error}',
  'peer.send_stopped':
      'Dihentikan ({n} berkas terkirim)',
  'peer.sent':
      '{n} berkas terkirim ke {name}',
  'peer.speed':
      '{done} / {total} · {speed}/dtk',
  'tts.ai_needs_key':
      'Bacaan pintar memerlukan kunci API Gemini (Pengaturan).',
  'tts.ai_read':
      'Bacaan pintar',
  'tts.ai_read_off':
      'Bacaan pintar mati.',
  'tts.ai_read_on':
      'Bacaan pintar aktif: teks dirapikan sebelum setiap halaman dibaca.',
  'tts.default_voice':
      'Default perangkat',
  'tts.engine':
      'Mesin suara',
  'tts.engine_default':
      'Default sistem',
  'tts.neural_get':
      'Ketuk untuk mengunduh',
  'tts.neural_sub':
      'Suara AI · di perangkat, luring',
  'tts.pitch':
      'Nada',
  'tts.rate':
      'Kecepatan',
  'tts.sample':
      'Beginilah suara ini membaca. Suka?',
  'tts.settings':
      'Bacakan',
  'tts.try':
      'Coba',
  'ux47.clip_empty':
      'Papan klip tidak berisi teks',
  'ux47.clutter_select_hint':
      'Pilih item untuk disembunyikan atau dihapus',
  'ux47.imp_add_file':
      'Tambah berkas',
  'ux47.imp_empty_folders':
      'Folder kosong ({n})',
  'ux47.imp_location':
      'Penyimpanan internal › Berkas Penting',
  'ux47.imp_open_folder':
      'Buka folder',
  'ux47.internal_root':
      'Penyimpanan internal',
  'ux47.near_visible':
      'Terlihat di sekitar · siap menerima',
  'ux47.paste_clipboard':
      'Tempel dari papan klip',
  'ux47.privacy_lock_off':
      '{n} folder terkunci · Kunci mati',
  'ux47.privacy_lock_on':
      '{n} folder terkunci · Kunci aktif',
  'ux47.privacy_unset':
      'Tanpa PIN · tidak terkunci',
  'ux47.set_pin_now':
      'Atur PIN',
  'ux47.text_or_clip':
      'Teks / Papan klip',
  'bgc.black':
      'Hitam',
  'bgc.default':
      'Default tema',
  'bgc.grey':
      'Abu-abu',
  'bgc.ice':
      'Biru es',
  'bgc.lilac':
      'Ungu muda',
  'bgc.mint':
      'Mint',
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
      'Warna latar',
  'bgc.white':
      'Putih',
  'nx.bill_body':
      '{amount} · sisa {days} hari',
  'nx.bill_overdue':
      '{amount} · lewat jatuh tempo',
  'nx.bill_title':
      'Tagihan jatuh tempo: {title}',
  'nx.bill_today':
      '{amount} · jatuh tempo HARI INI',
  'nx.channel':
      'Pengingat dan saran',
  'nx.clean_body':
      'Penyimpanan penuh {pct}% — ketuk untuk meninjau berkas yang tidak perlu',
  'nx.clean_body_found':
      'Penyimpanan penuh {pct}% · {size} berkas tidak perlu ditemukan terakhir kali',
  'nx.clean_title':
      'Waktunya bersih-bersih mingguan',
  'nx.w_empty':
      'Belum ada berkas yang dibuka',
  'nx.w_free':
      '{v} bebas',
  'nx.w_scan':
      'Pindai',
  'nx.weekly':
      'Saran pembersihan mingguan',
  'nx.weekly_sub':
      'Notifikasi mingguan saat penyimpanan hampir penuh (meski aplikasi ditutup)',
  'ocr.ar_model_failed':
      'Tidak bisa mengunduh model Arab. Periksa koneksi dan coba lagi; sementara itu bahasa Arab bisa dikenali dengan bacaan pintar (kunci Gemini).',
  'ocr.ar_model_get':
      'Unduh pengenalan Arab luring',
  'ocr.ar_model_loading':
      'Mengunduh model Arab… {p}%',
  'ocr.ar_model_ready':
      'Pengenalan Arab luring siap.',
  'ocr.ar_model_remove':
      'Hapus pengenalan Arab luring',
  'ocr.ar_model_sub':
      'Diunduh sekali (≈{size}); teks lalu tidak pernah keluar dari perangkat.',
  'ocr.no_play_services':
      'Layanan Google Play tidak tersedia di perangkat ini, jadi pengenalan teks di perangkat tidak dapat digunakan. Untuk teks Arab, unduh model luring di Pengaturan → Dokumen → Aksara pengenalan teks, atau gunakan bacaan pintar dengan kunci Gemini.',
  'ocr.ar_need_model':
      'Untuk pengenalan teks Arab, unduh model luring di Pengaturan → Dokumen → Aksara pengenalan teks, atau tambahkan kunci Gemini.',
  'ocr.cloud_need_key':
      'Pengenalan teks Arab memakai bacaan pintar: tambahkan kunci API Gemini di Pengaturan → Kecerdasan buatan.',
  'ocr.model_downloading':
      'Model pengenalan teks sedang diunduh oleh layanan Google Play. Tetap daring dan coba lagi beberapa menit lagi.',
  'ocr.script':
      'Aksara pengenalan teks',
  'ocr.script_arabic':
      'Arab (di perangkat atau bacaan pintar)',
  'ocr.script_auto':
      'Otomatis',
  'ocr.script_latin':
      'Hanya Latin (di perangkat)',
  'open.in_app_hint':
      'Terbuka cepat, Anda tetap di aplikasi',
  'open.in_app_player':
      'Pemutar bawaan',
  'open.kind_audio':
      'Berkas audio',
  'open.kind_image':
      'Gambar',
  'open.macro_info':
      'Berkas ini mungkin berisi makro — makro tidak pernah dijalankan; menyimpan membiarkannya tidak berubah di dalam berkas.',
  'open.no_app':
      'Tidak ada aplikasi yang bisa membuka jenis berkas ini.',
  'open.not_found':
      'Berkas tidak ditemukan (mungkin sudah dipindahkan atau dihapus).',
  'open.opening':
      'Membuka berkas…',
  'open.other_app':
      'Aplikasi lain',
  'open.other_app_hint':
      'Pemutar media / galeri Anda sendiri',
  'open.remember':
      'Ingat pilihan ini',
  'open.remember_hint':
      'Bisa diubah di Pengaturan',
  'open.with_what':
      'Buka {kind} dengan?',
  'ps.act_form':
      'Formulir diisi',
  'ps.act_ink':
      'Gambar ditambahkan',
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
      'Timpa',
  'ps.overwrite_sub':
      '{name} berubah — tidak bisa diurungkan',
  'ps.pick_folder':
      'Simpan ke folder pilihan…',
  'ps.pick_folder_sub':
      'Anda yang menentukan tujuannya',
  'ps.saved_as':
      'Disimpan: {name}',
  'ps.title':
      'Bagaimana menyimpannya?',
  'ra.failed_count':
      '{n} berkas tidak bisa diperkecil',
  'ra.frame_losing_kept':
      'berkas asli dari {n} berkas animasi/multi-halaman dipertahankan',
  'ra.job_many':
      'Memperkecil ukuran {n} berkas',
  'ra.job_many_name':
      'Pengecilan ukuran {n} berkas',
  'ra.job_one':
      'Memperkecil ukuran: {name}',
  'ra.job_one_name':
      'Pengecilan ukuran: {name}',
  'ra.media_only':
      'Pengecilan ukuran hanya berfungsi pada foto dan video.',
  'ra.no_gain':
      'Tidak ada penghematan',
  'ra.originals_trashed':
      '{n} berkas asli di tempat sampah',
  'ra.saved_bytes':
      '{size} dihemat',
  'ra.saved_into':
      'Disimpan di: {name}',
  'ra.saved_to':
      'Disimpan ke {n} folder',
  'ra.stopped_at':
      'dihentikan ({n}/{total})',
  'scan.apply_to_all':
      'Terapkan ke semua halaman',
  'scan.filter_auto':
      'Pertajam (warna)',
  'scan.filter_bw':
      'Hitam putih',
  'scan.filter_gray':
      'Abu-abu',
  'scan.filter_original':
      'Asli',
  'scan.filter_shadowless':
      'Hilangkan bayangan',
  'scan.filter_vivid':
      'Warna cerah',
  'scan.short_auto':
      'Pertajam',
  'scan.short_bw':
      'H/P',
  'scan.short_gray':
      'Abu-abu',
  'scan.short_original':
      'Asli',
  'scan.short_shadowless':
      'Tanpa bayangan',
  'scan.short_vivid':
      'Cerah',
  'acc.amber':
      'Ambar',
  'acc.berry':
      'Beri',
  'acc.blue':
      'Biru',
  'acc.default':
      'Default tema',
  'acc.forest':
      'Hutan',
  'acc.indigo':
      'Nila',
  'acc.ocean':
      'Laut',
  'acc.plum':
      'Prem',
  'acc.rust':
      'Karat',
  'acc.slate':
      'Batu tulis',
  'acc.teal':
      'Hijau kebiruan',
  'acc.title':
      'Warna aksen',
  'cln.app_cache':
      'Cache gambar mini & pratinjau aplikasi',
  'cln.app_cache_detail':
      'Gambar mini & pratinjau sementara · dibuat ulang otomatis saat diperlukan',
  'cln.chat_sent':
      'Salinan obrolan terkirim',
  'cln.chat_sent_detail':
      '{n} salinan · Hanya salinan terkirim yang dihapus, aslinya tetap',
  'cln.empty_folders':
      'Folder kosong',
  'cln.empty_folders_detail':
      '{n} folder · tidak ada isinya',
  'cln.old_large':
      'Berkas besar tidak dibuka selama setahun',
  'cln.old_large_detail':
      '{n} berkas · 50 MB atau lebih',
  'cln.old_screenshots':
      'Tangkapan layar lama',
  'cln.old_screenshots_detail':
      '{n} gambar · tidak dilihat selama 3 bulan',
  'cln.temp_junk':
      'Berkas sementara & parsial',
  'cln.temp_junk_detail':
      '{n} berkas · .tmp, .part, unduhan parsial & sampah',
  'dash.backup':
      'Simpan tata letak · pindah ke perangkat baru',
  'dash.hint':
      'Seret untuk mengurutkan, gunakan sakelar untuk menampilkan/menyembunyikan. Perubahan langsung berlaku.',
  'dash.reset':
      'Atur ulang',
  'dash.sections':
      'Bagian',
  'dash.strip_all':
      'Tampilkan semua',
  'dash.strip_auto':
      'Otomatis',
  'dash.strip_default':
      'Berkas terbaru terbuka di',
  'dash.strip_fresh':
      'Baru',
  'dash.strip_new':
      'Baru',
  'dash.strip_opened':
      'Riwayat',
  'dash.strip_title':
      'Berkas terbaru',
  'dash.tiles':
      'Ubin',
  'jb.cancelled':
      'Dibatalkan.',
  'jb.cancelled_detail':
      'Dibatalkan · {detail}',
  'jb.file_missing':
      'Berkas tidak ditemukan · {folder}',
  'jb.interrupted_detail':
      'Terputus · {detail} · ketuk untuk memulai lagi',
  'jb.open_folder':
      'Buka folder',
  'jb.outputs':
      'Berkas yang dibuat ({n})',
  'jb.resume':
      'Lanjutkan',
  'jb.resume_failed':
      'Tugas ini tidak bisa dilanjutkan; mulai lagi.',
  'jb.resume_started':
      'Melanjutkan dari titik terakhir.',
  'jb.running_for':
      'Berjalan selama {time}',
  'jb.title':
      'Tugas',
  'jb.took':
      '{status} · memakan waktu {time}',
  'aipool.add_key':
      'Tambah kunci',
  'aipool.add_model':
      'Tambah model',
  'aipool.backup_keys':
      'Cadangkan kunci API',
  'aipool.key_n':
      'Kunci {n}',
  'aipool.model_chain':
      'Urutan model',
  'aipool.model_gone':
      'Model ini tidak lagi tersedia — dihentikan atau tidak diaktifkan untuk kunci Anda.',
  'aipool.move_up':
      'Naikkan',
  'aipool.reset':
      'Atur ulang',
  'aipool.show_keys':
      'Tampilkan/sembunyikan kunci',
  'aipool.status':
      'Status kuota',
  'aipool.status_sub':
      '{total} kumpulan kuota (kunci × model) · {cooling} sedang habis.',
  'arc.encrypted':
      'terenkripsi',
  'arc.extract_all':
      'Ekstrak semua',
  'arc.extract_one':
      'Ekstrak berkas ini',
  'arc.extracted_file':
      '{name} diekstrak',
  'arc.multipart':
      'multi-bagian',
  'arc.no_match':
      'Tidak ada berkas yang cocok',
  'arc.open_failed':
      'Tidak bisa membuka arsip: {error}',
  'arc.opening':
      'Membuka',
  'arc.opening_name':
      'Membuka arsip',
  'arc.ratio':
      '{pct}% terkompresi',
  'arc.search':
      'Cari di arsip…',
  'dup.comparing':
      'Membandingkan berkas byte demi byte…',
  'dup.comparing_short':
      'Membandingkan berkas…',
  'dup.job_summary':
      '{n} grup · {size} bisa dibebaskan',
  'dup.n_copies':
      '{n} salinan',
  'dup.no_match':
      'Tidak ada hasil untuk “{query}”.',
  'dup.none':
      'Tidak ditemukan berkas duplikat 🎉',
  'dup.none_short':
      'Tidak ada berkas duplikat',
  'dup.scanning_name':
      'Pencarian berkas duplikat',
  'dup.scanning_title':
      'Mencari berkas duplikat',
  'dup.tile_summary':
      '{n} salinan · {size} · {waste} bisa dibebaskan',
  'dup.visible_summary':
      '{shown} / {total} grup · {size} terbuang',
  'list.date':
      'Tanggal',
  'list.filter':
      'Filter',
  'list.filter_n':
      'Filter ({n})',
  'list.folders':
      'Folder',
  'list.size':
      'Ukuran',
  'list.sort':
      'Urutkan',
  'list.sort_by':
      'Urutkan: {name}',
  'list.sort_dir_asc':
      'Menaik (A→Z, lama→baru)',
  'list.sort_dir_desc':
      'Menurun (Z→A, baru→lama)',
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
      'Salin & kirim',
  'sel.group_more':
      'Lainnya',
  'sel.group_organize':
      'Atur',
  'sel.hide_hint':
      'Dipindahkan ke brankas terenkripsi',
  'sel.invert':
      'Balikkan',
  'sel.menu':
      'Pilihan',
  'sel.none':
      'Batalkan pilihan',
  'sel.sheet_title':
      '{n} dipilih',
  'sim.group_summary':
      '{n} mirip · {size} bisa dibebaskan',
  'sim.groups_summary':
      '{n} grup mirip · {size} bisa dibebaskan',
  'sim.n_files':
      '{n} berkas',
  'sim.none':
      'Tidak ditemukan gambar mirip 🎉',
  'sim.preparing_list':
      'Menyiapkan daftar berkas…',
  'sim.scan_failed':
      'Pemindaian tidak bisa selesai',
  'sim.scanning':
      'Memindai…',
  'sim.scanning_name':
      'Pencarian gambar mirip ({level})',
  'sim.scanning_title':
      'Mencari gambar mirip ({level})',
  'sim.select_extras':
      'Pilih yang berlebih',
  'sim.title':
      'Gambar mirip',
  'ui.clutter_tile':
      'Rapikan',
  'ui.ct_docs':
      'Dokumen',
  'ui.ct_list':
      'Daftar ini',
  'ui.ct_select_all':
      'Pilih semua',
  'ui.ct_share_all':
      'Bagikan yang ditampilkan ({n})',
  'ui.ct_smart_hint':
      'Kelompokkan dokumen ke kategori, beri nama kedua',
  'ui.ct_zip_all':
      'Kompres yang ditampilkan ({n})',
  'ui.ct_zip_hint':
      'Arsip disimpan ke Unduhan',
  'ui.dock_new':
      'Baru',
  'ui.dock_opened':
      'Dibuka',
  'ui.sel_group_move':
      'Pindah & salin',
  'wipe.ai':
      'AI: ringkasan, analisis tag, catatan memori',
  'wipe.confirm':
      'Catatan yang dipilih akan dihapus permanen. Ini tidak bisa diurungkan.',
  'wipe.done':
      'Data dihapus.',
  'wipe.go':
      'Hapus',
  'wipe.history':
      'Riwayat: berkas terbaru, pencarian, riwayat operasi dan transfer',
  'wipe.indexes':
      'Indeks pencarian (nama dan isi; dibangun ulang nanti)',
  'wipe.logs':
      'Log kesalahan',
  'wipe.note':
      'Yang Anda pilih akan dihapus. Berkas, koneksi tersimpan, kunci API, brankas, dan pengaturan TETAP ADA.',
  'wipe.partial':
      'Dihapus; {n} catatan tidak bisa dihapus.',
  'wipe.sub':
      'Riwayat, catatan AI, indeks pencarian, dan log kesalahan. Berkas Anda tidak disentuh.',
  'wipe.title':
      'Hapus data saya',
  'act.all':
      'Semua ({n})',
  'act.clear':
      'Hapus riwayat',
  'act.kind_convert':
      'Berkas yang dikonversi',
  'act.kind_doc':
      'Dokumen yang diedit',
  'act.kind_image':
      'Foto yang diperkecil',
  'act.kind_other':
      'Lainnya',
  'act.kind_pdf':
      'PDF yang diedit',
  'act.kind_scan':
      'Dokumen yang dipindai',
  'act.kind_video':
      'Video yang diperkecil',
  'act.title':
      'Dibuat',
  'cat.add':
      'Tambah kategori',
  'cat.add_body':
      '{n} berkas · muncul di Pengaturan pintar, filter, dan pencarian',
  'cat.add_hint':
      'Dibagikan dengan kategori pintar; Anda juga bisa menambah sendiri',
  'cat.added':
      '{n} berkas ditambahkan ke "{cat}"',
  'cat.full':
      'Paling banyak {n} kategori yang bisa ditambahkan',
  'cat.mine':
      'Kategori saya',
  'cat.new':
      'Kategori baru',
  'cat.new_label':
      'Nama kategori',
  'cat.new_title':
      'Kategori baru',
  'cat.removed':
      'Dikeluarkan dari "{cat}"',
  'cmp.hide_names':
      'Sembunyikan juga nama berkas',
  'cmp.hide_names_sub':
      'Arsip tidak bisa dibuka tanpa kata sandi',
  'cmp.set_password':
      'Atur kata sandi',
  'cmp.split':
      'Pecah menjadi volume',
  'cmp.title':
      'Kompres',
  'cmp.vol_100':
      '100 MB',
  'cmp.vol_25':
      '25 MB (email)',
  'cmp.vol_4g':
      '4 GB (FAT32)',
  'cmp.vol_700':
      '700 MB',
  'cmp.vol_none':
      'Satu berkas',
  'code.bad_regex':
      'Ekspresi tidak valid',
  'code.cursor_left':
      'Kursor ke kiri',
  'code.cursor_right':
      'Kursor ke kanan',
  'code.eol':
      'Ubah akhir baris',
  'code.eol_changed':
      'Akhir baris: {name} — diterapkan saat disimpan',
  'code.find':
      'Cari',
  'code.redo':
      'Ulangi',
  'code.tab':
      'Indentasi (Tab)',
  'code.undo':
      'Urungkan',
  'code.whole_word':
      'Kata utuh',
  'lib.add_one':
      'Tambahkan ke pustaka',
  'lib.f_all':
      'Semua',
  'lib.f_done':
      'Selesai',
  'lib.f_reading':
      'Sedang dibaca',
  'lib.f_unread':
      'Belum dimulai',
  'lib.sort_added':
      'Baru ditambahkan',
  'lib.sort_name':
      'Menurut nama',
  'lib.sort_progress':
      'Menurut kemajuan membaca',
  'lib.view_list':
      'Tampilan daftar',
  'lib.view_shelf':
      'Tampilan rak',
  'md.bold':
      'Tebal',
  'md.bullets':
      'Daftar berpoin',
  'md.code':
      'kode',
  'md.heading':
      'Judul',
  'md.italic':
      'Miring',
  'md.link':
      'Tautan',
  'md.numbered':
      'Daftar bernomor',
  'md.quote':
      'Kutipan',
  'md.table':
      'Tabel',
  'md.task':
      'Kotak centang',
  'menu.look_bento':
      'Bento',
  'menu.look_sub':
      'Tata letak menu berkas dan dokumen',
  'menu.look_tabbed':
      'Bertab',
  'menu.look_title':
      'Gaya menu',
  'menu.search_empty':
      'Tidak ada aksi yang cocok',
  'menu.search_hint':
      'Cari menu atau menurut aksi…',
  'menu.search_hits':
      '{n} hasil',
  'menu.search_intent':
      'Menurut fungsi',
  'menu.tab_common':
      'Sering dipakai',
  'menu.tab_more':
      'Lainnya',
  'picker.here_folder':
      'Ke folder ini',
  'picker.home':
      'Beranda',
  'picker.parent':
      'Folder induk',
  'picker.places':
      'Mau disimpan di mana?',
  'picker.source_itself':
      'Sumbernya sendiri',
  'picker.storage':
      'Penyimpanan',
  'picker.summary':
      '{n} item · {name}',
  'picker.title':
      'Folder tujuan',
  'picker.to_downloads':
      'Masuk ke Unduhan',
  'picker.unreadable':
      'Folder ini tidak bisa dibaca (tanpa izin).',
  'qr.auto':
      'Otomatis',
  'qr.hint_many':
      'Catatan panjang: pindai {n} kode QR secara berurutan (masing-masing diawali 1/{n}, 2/{n}…). Dengan "Otomatis" kodenya maju sendiri.',
  'qr.hint_one':
      'Minta orang lain memindainya dengan kamera ponsel — seluruh catatan muncul di layar mereka dan bisa disalin.',
  'qr.next':
      'Kode berikutnya',
  'qr.prev':
      'Kode sebelumnya',
  'qr.privacy':
      'Tanpa internet, jaringan bersama, atau aplikasi; catatan tidak diunggah ke mana pun.',
  'qr.stop':
      'Berhenti',
  'qr.text_choice':
      'Tampilkan teks sebagai kode QR',
  'qr.text_choice_sub':
      'Teks ada di dalam QR — tanpa jaringan atau aplikasi',
  'qr.title':
      'Bagikan sebagai kode QR',
  'toc.create':
      'Buat daftar isi',
  'toc.create_body':
      'PDF ini tidak memiliki daftar isi. Pindai judul dan tambahkan ke PDF sebagai penanda? Anda akan melihat daftarnya sebelum menyimpan.',
  'toc.create_go':
      'Cari judul',
  'toc.started':
      'Mencari judul di latar belakang; Anda akan diberi tahu saat selesai dan dapat meninjau daftarnya saat membuka dokumen.',
  'toc.running':
      'Pencarian judul untuk dokumen ini sedang berjalan',
  'toc.ready':
      '{n} judul ditemukan — buka dokumen untuk meninjau',
  'toc.none_found':
      'Tidak ada judul ditemukan',
  'toc.preview':
      '{n} judul ditemukan',
  'toc.save':
      'Tambahkan ke PDF',
  'toc.saved':
      'Daftar isi ditambahkan ke PDF',
  'toc.scanned_warn':
      'PDF ini hasil pindaian (halaman berupa gambar). Teks di {n} halaman akan dikenali (OCR) untuk mencari judul; buku besar bisa memakan beberapa menit. Anda akan melihat daftarnya sebelum menyimpan.',
  'toc.scanning':
      'Mencari judul…',
  'toc.scanning_ocr':
      'Mengenali teks, mencari judul…',
  'ux.copy_details':
      'Salin detail',
  'ux.error_body':
      'Berkas mungkin rusak, dalam versi yang tidak didukung, atau dikunci aplikasi lain.',
  'ux.error_title':
      'Tidak bisa dibuka',
  'ux.group_format':
      'Format',
  'ux.group_send':
      'Kirim',
  'ux.loading':
      'Memuat',
  'ux.selection':
      'Pilihan',
  'ux.send_nearby':
      'Kirim ke perangkat terdekat',
  'ux.send_nearby_hint':
      'Versi tersimpan · QR atau jaringan lokal',
  'ux.share_export':
      'Bagikan dalam format lain',
  'vtr.end':
      'Akhir',
  'vtr.hint':
      'pangkas, potong bagian, tambah / bisukan suara',
  'vtr.job':
      'Mengedit video: {name}',
  'vtr.job_name':
      'Klip {name}',
  'vtr.no_preview':
      'Pratinjau tidak tersedia; video tetap bisa dipangkas.',
  'vtr.range':
      '{start} – {end} · {n} dtk',
  'vtr.start':
      'Mulai',
  'vtr.suffix':
      'klip',
  'vtr.title':
      'Edit video',
  'vtr.whole':
      'Seret pegangan di bawah untuk memangkas',
  'dp.copied':
      '{n} item disalin',
  'dp.copy_to':
      'Salin ke sisi lain',
  'dp.failed':
      'Beberapa item tidak bisa dipindahkan',
  'dp.move_to':
      'Pindahkan ke sisi lain',
  'dp.moved':
      '{n} item dipindahkan',
  'dp.selected':
      '{n} dipilih',
  'dp.swap':
      'Tukar panel',
  'dp.title':
      'Panel ganda',
  'dp.up':
      'Folder induk',
  'hv.confirm_body':
      'Item akan dienkripsi dan dipindahkan ke Brankas; tetap tidak terbaca meski ponsel terhubung ke komputer. Keluarkan dari Brankas.',
  'hv.confirm_title':
      'Sembunyikan {n} item?',
  'hv.empty':
      'Tidak ada berkas tersembunyi. Tekan lama berkas dan pilih “Sembunyikan”.',
  'hv.note':
      'Berkas tersembunyi dipindahkan ke folder tersembunyi; tidak muncul di galeri atau daftar aplikasi ini. Ini bukan enkripsi.',
  'hv.restore':
      'Pulihkan',
  'hv.restore_name':
      'Memulihkan berkas tersembunyi',
  'hv.restored_n':
      '{n} item dipulihkan',
  'hv.restoring':
      'Memulihkan',
  'hv.title':
      'Berkas tersembunyi',
  'oh.clear':
      'Hapus riwayat',
  'oh.clear_body':
      'Hanya catatan “kapan dibuka” yang dihapus; berkasnya tidak.',
  'oh.clear_title':
      'Hapus riwayat?',
  'oh.empty':
      'Belum ada berkas yang dibuka.\nSaat Anda membukanya, berkas muncul di sini.',
  'oh.no_match':
      'Tidak ada hasil untuk “{query}”.',
  'oh.remove':
      'Hapus dari riwayat',
  'oh.removed_n':
      '{n} berkas dihapus dari riwayat',
  'oh.search':
      'Cari riwayat…',
  'oh.title':
      'Riwayat',
  'perf.auto':
      'Otomatis',
  'perf.auto_is':
      'Otomatis — ponsel ini: {tier}',
  'perf.full':
      'Penuh',
  'perf.light':
      'Ringan',
  'perf.mode':
      'Kinerja',
  'perf.mode_sub':
      'Ringan: lebih sedikit memori dan baterai pada ponsel lama/RAM kecil — satu gambar mini sekali waktu, efek mati, 60 Hz.',
  'perf.tier_high':
      'bertenaga',
  'perf.tier_low':
      'ringan',
  'perf.tier_mid':
      'menengah',
  'se.apply_crop':
      'Pangkas',
  'se.crop_hint':
      'Seret sudut atau tepinya',
  'se.crop_title':
      'Pangkas halaman',
  'se.failed':
      'Tidak bisa memperbaikinya: {error}',
  'se.find_edges':
      'Temukan tepi',
  'se.full_page':
      'Seluruh halaman',
  'se.invalid_quad':
      'Sudut tidak membentuk segi empat yang valid',
  'se.not_found':
      'Tepi kertas tidak ditemukan — seret tepinya secara manual.',
  'se.open_failed':
      'Tidak bisa membuka gambar: {error}',
  'sync.add':
      'Tambah folder',
  'sync.done':
      '{n} berkas baru disinkronkan ke {name}',
  'sync.explain':
      'Saat aktif, berkas yang ditambahkan ke folder pilihan mulai SEKARANG dikirim otomatis saat perangkat ini berada di Wi-Fi yang sama — terenkripsi, dan hanya ke kunci perangkat ini.',
  'sync.menu':
      'Sinkron otomatis',
  'sync.on':
      'Sinkron otomatis aktif',
  'sync.pick':
      'Sinkronkan folder ini',
  'sync.remove':
      'Hapus folder',
  'sync.title':
      'Sinkron otomatis dengan {name}',
  'sync.when':
      'Sinkronisasi berjalan saat aplikasi dibuka atau tampil di depan, dan saat Transfer terbuka; tidak ada pemindaian latar belakang (baterai).',
  'aisend.body':
      'Untuk ini, teks (atau gambar) berkas dikirim ke Google Gemini dan diproses dengan kunci API Anda. Dengan kunci gratis, Google dapat memakai data ini untuk melatih modelnya. Tidak ada yang lain yang keluar dari ponsel. Anda tidak akan ditanya lagi pada sesi ini.',
  'aisend.cancelled':
      'Tidak dikirim ke AI.',
  'aisend.private':
      'Berkas di brankas tidak pernah dikirim ke AI.',
  'aisend.remember':
      'Jangan tanya lagi',
  'aisend.send':
      'Kirim',
  'aisend.setting':
      'Tanya sebelum mengirim ke AI',
  'aisend.setting_sub':
      'Bertanya sebelum teks berkas masuk ke Google Gemini. Mati berarti Anda sudah setuju sekali.',
  'aisend.title':
      'Kirim berkas ke Google?',
  'downloads.empty':
      'Folder unduhan kosong',
  'downloads.folder_view':
      'Tampilan folder (jelajahi subfolder)',
  'downloads.no_result':
      'Tidak ada hasil untuk “{q}”.',
  'downloads.search':
      'Cari unduhan',
  'downloads.search_hint':
      'Cari unduhan…',
  'downloads.select_old':
      'Pilih yang lama',
  'downloads.selected':
      '{n} / {total} dipilih',
  'downloads.title':
      'Unduhan',
  'dsv.downloaded':
      'Terunduh',
  'dsv.downloading':
      'Mengunduh…',
  'dsv.downloading_live':
      'Mengunduh · {progress} · {networkSpeed} · sisa {timeRemaining}',
  'dsv.failed':
      'Unduhan gagal',
  'dsv.job_name':
      'Unduhan',
  'dsv.paused':
      'Dijeda',
  'dsv.speed':
      '{speed}/dtk',
  'dsv.start_failed':
      'Tidak bisa memulai unduhan',
  'paste.conflict_more':
      '{names} dan {n} lainnya',
  'paste.conflict_title':
      '{n} berkas sudah ada di sini',
  'paste.keep_both':
      'Simpan keduanya',
  'paste.keep_both_sub':
      'Yang baru mendapat “(1)”; tidak ada yang dihapus',
  'paste.overwrite':
      'Timpa',
  'paste.overwrite_sub':
      'Berkas yang sudah ada diganti — tidak bisa diurungkan',
  'paste.skip':
      'Lewati berkas ini',
  'paste.skip_sub':
      'Berkas yang sudah ada tetap seperti semula',
  'perm.allow':
      'Izinkan',
  'perm.camera_title':
      'Kamera',
  'perm.granted':
      'Diizinkan',
  'perm.location_title':
      'Lokasi',
  'perm.notifications_title':
      'Notifikasi',
  'perm.open_settings':
      'Buka pengaturan',
  'perm.overlay_title':
      'Tampil di atas aplikasi lain',
  'perm.revoke':
      'Cabut',
  'aiterms.accept':
      'Setuju',
  'aiterms.body':
      'Fitur AI berjalan dengan kunci API Google Gemini milik Anda sendiri. Teks atau gambar berkas yang Anda pilih dikirim ke Google untuk diproses; berlaku ketentuan dan kebijakan privasi Google sendiri. Jawaban dibuat otomatis dan bisa salah, tidak lengkap, atau usang. Jangan mengandalkannya saja untuk keputusan medis, hukum, keuangan, atau keputusan penting lainnya; periksa sendiri hasilnya. Aplikasi tidak bertanggung jawab atas akibat dari jawaban AI. Kami menyarankan agar tidak mengirim berkas yang berisi informasi pribadi atau rahasia.',
  'aiterms.c_accuracy':
      'Saya mengerti jawaban bisa salah dan saya harus memeriksanya.',
  'aiterms.c_data':
      'Saya setuju konten yang saya kirim diteruskan ke Google untuk diproses.',
  'aiterms.c_key':
      'Saya memakai kunci API sendiri dan kuota atau biaya apa pun menjadi tanggungan saya.',
  'aiterms.pro_only':
      'Fitur AI ada di edisi Pro.',
  'aiterms.title':
      'AI — pemberitahuan dan persetujuan',
  'an.free_headline':
      '{size} bebas',
  'an.other_used':
      'Sistem & lainnya',
  'an.tools':
      'Alat',
  'an.tools_clean':
      'Bersihkan & atur',
  'an.top_growing':
      'Tumbuh tercepat: {category} ',
  'an.trend_days':
      'Dalam {n} hari terakhir ',
  'an.used_of':
      '{used} / {total} terpakai',
  'backup.failed':
      'Pencadangan gagal: {error}',
  'backup.restore':
      'Pulihkan dari cadangan',
  'backup.restore_failed':
      'Pemulihan gagal: {error}',
  'backup.restore_sub':
      'Pengaturan dari cadangan dipulihkan; yang tidak ada di dalamnya tetap seperti semula.',
  'backup.restored':
      '{n} pengaturan dipulihkan. Sebagian berlaku setelah aplikasi dimulai ulang.',
  'backup.saved':
      'Cadangan disimpan: {name}',
  'backup.title':
      'Cadangkan pengaturan',
  'inbox.all':
      'Semua tugas',
  'inbox.clear_done':
      'Hapus yang selesai',
  'inbox.hour_ago':
      '{n} j lalu',
  'inbox.just_now':
      'baru saja',
  'inbox.min_ago':
      '{n} mnt lalu',
  'inbox.more':
      '+{n} lagi · Semua',
  'inbox.running':
      'Berjalan…',
  'lock.app_needs_pin':
      'Atur PIN dulu (Privasi > PIN kunci folder).',
  'lock.app_prompt':
      'Masukkan PIN',
  'lock.app_sub_off':
      'Mati — aplikasi langsung terbuka.',
  'lock.app_sub_on':
      'PIN ditanyakan saat aplikasi dibuka.',
  'lock.app_title':
      'Kunci aplikasi',
  'lock.app_wait':
      'Terlalu banyak percobaan — tunggu {n} detik',
  'lock.app_wrong':
      'PIN salah',
  'tile.body':
      'Perangkat tepercaya dapat mengirim berkas terenkripsi · mati setelah 30 menit tidak aktif',
  'tile.channel':
      'Menerima berkas',
  'tile.got':
      'Berkas diterima',
  'tile.open':
      'Buka Transfer untuk menerima',
  'tile.refused':
      'Permintaan dari perangkat tidak tepercaya ditolak',
  'tile.stop':
      'Matikan',
  'tile.title':
      'Penerimaan aktif',
  'whatsnew.add_folder':
      'Gunakan "Tambah folder" untuk bekerja hanya dengan folder pilihan Anda, tanpa akses semua berkas.',
  'whatsnew.ai_ask':
      'Anda ditanya sebelum berkas dikirim ke AI.',
  'whatsnew.faster':
      'Flutter dan paket baru: gulir PDF lebih mulus, SFTP lebih cepat.',
  'whatsnew.offline':
      'Mode luring: saat aktif, aplikasi tidak pernah online.',
  'whatsnew.privacy':
      'Pengaturan › Privasi & izin: mengapa setiap izin diminta, statusnya, cabut dengan satu ketukan.',
  'whatsnew.reading':
      'Alat bantu baca di PDF; Word/Slide dibuka kembali di tempat terakhir, Excel pada lembar tersimpannya.',
  'whatsnew.title':
      'Yang baru — {v}',
  'atr.action_hint':
      'Pangkas awal dan akhir, simpan sebagai berkas baru',
  'atr.failed':
      'Berkas audio ini tidak bisa dibuka.',
  'atr.hint':
      'Seret pegangan; bagian pendek diputar dari titik itu saat menyeret.',
  'atr.job':
      'Memangkas audio: {name}',
  'atr.result':
      'Hasil {t}',
  'atr.title':
      'Pangkas audio',
  'lc.clear_all':
      'Hapus',
  'lc.count':
      '{n} item',
  'lc.count_of':
      '{n} / {total} item',
  'lc.filter':
      'Filter',
  'lc.filter_n':
      'Filter · {n}',
  'lc.no_dupes':
      'Duplikat disembunyikan',
  'lnk.expired_renew':
      'Tautan kedaluwarsa · perbarui',
  'lnk.forever':
      'Selama terbuka',
  'lnk.hour1':
      '1 jam',
  'lnk.min15':
      '15 mnt',
  'lnk.once':
      'Sekali unduh',
  'lnk.until':
      'Tautan berlaku sampai {time}',
  'more.asc':
      'Menaik',
  'more.desc':
      'Menurun',
  'more.filter':
      'Filter',
  'more.folder':
      'Folder ini',
  'more.tags':
      'Tag',
  'more.tools':
      'Analisis',
  'pp.hf_empty':
      'Pilih nomor halaman, header, atau footer',
  'pp.hf_footer':
      'Footer',
  'pp.hf_header':
      'Header',
  'pp.hf_none':
      'Tidak ada header atau footer untuk dihapus (hanya yang ditambahkan dengan aplikasi ini yang bisa dihapus)',
  'pp.hf_numbers':
      'Nomor halaman',
  'pp.hf_remove':
      'Hapus',
  'sg.failed':
      'Penandatanganan gagal: {error}',
  'sg.grid':
      'Semua halaman (kisi)',
  'sg.note':
      'Tanda tangan dicap permanen pada dokumen.',
  'sg.prev_page':
      'Halaman sebelumnya',
  'sg.redraw':
      'Gambar ulang tanda tangan',
  'sg.single':
      'Tampilan satu halaman',
  'tr.cancelled':
      'Dihentikan — {n} item dihapus.',
  'tr.count_size':
      '{n} item · {size}',
  'tr.delete_body':
      '{n} item ({size}) akan dihapus permanen. Ini tidak bisa diurungkan.',
  'tr.emptied':
      'Tempat sampah dikosongkan · {n} item · {size} dibebaskan.',
  'tr.partial':
      '{n} item dihapus, {fail} tidak bisa dihapus: {first}',
  'tr.restored':
      '“{name}” dipulihkan → {folder}',
  'xfer.computer':
      'Dengan komputer',
  'xfer.computer_note':
      'Dari browser atau FTP, sambungkan dengan kode QR',
  'xfer.downloads':
      'Unduhan',
  'xfer.downloads_note':
      'Unduh berkas dari tautan',
  'xfer.nas_note':
      'Koneksi FTP, SFTP, SMB, WebDAV',
  'xfer.title':
      'Transfer',
  'ais.as_pdf':
      'Dek (PDF)',
  'ais.as_pdf_hint':
      'Terbuka di mana saja, tata letak tetap',
  'ais.as_pptx':
      'Presentasi (.pptx)',
  'ais.as_pptx_hint':
      'Bisa diedit — terbuka juga di PowerPoint',
  'ais.failed':
      'Tidak bisa membuat presentasi: {error}',
  'dev.enabled':
      'Menu pengembang aktif — di bagian bawah Pengaturan',
  'dev.on':
      'Aktif',
  'dev.sub':
      'Alat diagnostik',
  'dev.title':
      'Pengembang',
  'dev.turn_off':
      'Matikan menu pengembang',
  'dg.consent':
      'Ringkasan anonim di bawah akan dibagikan: versi, jumlah crash/ANR, baris pertama kesalahan, dan distribusi waktu bingkai. Nama berkas, jalur, email, dan angka panjang disamarkan; tidak ada isi dokumen. Aplikasi tidak mengirim apa pun sendiri — Anda yang memilih untuk membagikan.',
  'dg.frames':
      'Kumpulkan waktu bingkai',
  'dg.frames_hint':
      'Hanya distribusi numerik bingkai lambat, di perangkat; tanpa layar atau nama berkas.',
  'dg.send':
      'Bagikan',
  'dg.title':
      'Laporkan masalah',
  'g5.encrypted':
      'Terenkripsi',
  'g5.encrypted_code':
      'Terenkripsi · periksa {code}',
  'g5.resume_hint':
      'mengirim ulang akan melanjutkan dari titik berhenti',
  'g5.trusted_keyed':
      'Dikenal lewat kuncinya · terenkripsi',
  'g5.unencrypted':
      'Tidak terenkripsi (pihak lain versi lama)',
  'pin.mismatch':
      'Kedua PIN tidak cocok.',
  'pin.repeat_empty':
      'Ketik PIN yang sama lagi di kotak "PIN (ulangi)" di bawah.',
  'pin.too_short':
      'PIN minimal 4 digit.',
  'pin.wait':
      'Terlalu banyak kesalahan — tunggu {t}',
  'pin.wrong':
      'PIN salah.',
  'pro.b1':
      'Pengeditan PDF dan alat PDF lanjutan + alat Word dan Slide lanjutan',
  'pro.b2':
      'Folder pintar, pembuatan buku audio, dan kompresi video',
  'pro.b3':
      'Gemini AI opsional dengan kunci Anda sendiri untuk folder pintar, OCR pindaian, dan pembersihan buku audio',
  'pro.card_title':
      'Apa isi Pro?',
  'pro.store':
      'Lihat di Play',
  'reader.page_empty':
      'Tidak ada teks terbaca di halaman ini.',
  'reader.theme':
      'Latar belakang',
  'reader.theme_dark':
      'Gelap',
  'reader.theme_light':
      'Terang',
  'reader.theme_sepia':
      'Sepia',
  'sr.last_page':
      'Anda tidak bisa menghapus halaman terakhir — batalkan pemindaian saja.',
  'sr.page_failed':
      'Tidak bisa menampilkan halaman',
  'sr.straighten':
      'Luruskan',
  'sr.straighten_noop':
      'Halaman sudah tampak lurus — tidak ada yang berubah.',
  'sr.straightened':
      'Halaman telah diluruskan.',
  'st.edit_page':
      'Edit teks halaman {n}',
  'st.fix_done':
      'Teks diperbaiki ({n} baris)',
  'st.fix_noop':
      'Tidak ada kesalahan OCR untuk diperbaiki',
  'st.fix_text':
      'Perbaiki OCR',
  'st.re_recognize':
      'Kenali ulang',
  'tp.new_tag':
      'Tag baru (nama orang / grup)',
  'tp.new_tag_hint':
      'Budi, Grup kerja, Faktur…',
  'tp.partial':
      '{tag} (pada sebagian)',
  'tp.title':
      'Tag',
  'tp.title_n':
      'Tag ({n} berkas)',
  'typ.all_types':
      'Semua jenis',
  'typ.hint':
      'Anda bisa memilih beberapa jenis; daftar langsung difilter.',
  'typ.more_n':
      '{name} +{n}',
  'typ.show_n':
      'Tampilkan {n} berkas',
  'typ.title':
      'Jenis berkas',
  'aikey.add':
      'Tambah kunci',
  'aikey.body':
      'Pengaturan pintar, nama kedua pintar, terjemahan, dan pengeditan pintar berjalan di Google Gemini. Dapatkan kunci gratis dan tempel di Pengaturan > Kecerdasan buatan; itu saja.',
  'aikey.privacy':
      'Hanya teks/berkas yang Anda pilih yang dikirim, dan hanya saat Anda memintanya.',
  'aikey.title':
      'Aktifkan fitur pintar',
  'ci.clear':
      'Hapus indeks isi',
  'ci.cleared':
      'Indeks isi dihapus',
  'ci.ocr':
      'Cari juga teks di gambar (OCR)',
  'ci.ocr_sub':
      'Indeks isi mengenali teks gambar di ponsel; berhenti saat penghemat baterai',
  'count.files':
      '{n} berkas',
  'count.files_size':
      '{n} berkas · {size}',
  'count.more_files':
      '… dan {n} berkas lagi',
  'count.of_files':
      '{shown} / {total} berkas',
  'eco.dismiss':
      'Sembunyikan saran selama 30 hari',
  'eco.notlar_cta':
      'Dapatkan / buka Notlar',
  'eco.notlar_sub':
      'Kirim kutipan ke catatan Anda dengan satu ketukan dan bagikan satu kolam kredit AI di kedua aplikasi.',
  'eco.notlar_title':
      'Temukan Notlar',
  'err.go_back':
      'Kembali',
  'err.go_home':
      'Beranda',
  'err.render_failed':
      'Layar ini tidak bisa digambar',
  'err.report':
      'Laporkan masalah',
  'fmap.empty':
      'Tidak ada berkas untuk diukur di folder ini.',
  'fmap.note':
      'Mengurutkan folder menurut ukuran; masuk lebih dalam untuk mencari ke mana ruang pergi',
  'fmap.summary':
      '{n} berkas · {size}',
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
      'Baru',
  'hist.jobs':
      'Tugas',
  'hist.opened':
      'Riwayat',
  'hist.produced':
      'Dibuat',
  'jp.cancel':
      'Batal',
  'jp.cancelling':
      'Menghentikan…',
  'jp.show':
      'Tampilkan',
  'jp.title_queued':
      '{title} (+{n} lagi)',
  'lab.word_banner':
      'Eksperimen — perubahan tidak disimpan',
  'lab.word_flag':
      'Editor Word baru (eksperimen)',
  'lab.word_flag_sub':
      'Uji ketik inti tipis di menu Word ⋮ — tidak menyimpan',
  'lab.word_open':
      'Coba di editor baru',
  'lcol.color':
      'Warna',
  'lcol.folder':
      'Warna folder',
  'lcol.none':
      'Tanpa warna',
  'lcol.tag':
      'Warna tag "{tag}"',
  'offline.blocked':
      'Mode luring aktif — tidak ada koneksi internet yang dibuat. Matikan di Pengaturan › Privasi & izin.',
  'offline.on':
      'AKTIF — tidak ada yang masuk ke internet. AI, Drive, subtitel, dan unduhan mati; jaringan lokal tetap berfungsi.',
  'offline.sub':
      'Saat aktif, aplikasi tidak pernah online: AI, Google Drive, subtitel, dan unduhan berhenti. Jaringan lokal (NAS, perangkat terdekat) tetap berfungsi. Diagnostik tidak pernah mengirim apa pun.',
  'offline.title':
      'Mode luring',
  'onb.next':
      'Berikutnya',
  'onb.privacy_note':
      'Berkas Anda tetap di ponsel; tanpa iklan, tanpa pelacakan. AI bersifat opsional dan hanya berjalan saat Anda memulainya, dengan kunci Anda sendiri.',
  'onb.privacy_note_lite':
      'Berkas Anda tetap di ponsel; tanpa akun, tanpa iklan, tanpa pelacakan.',
  'onb.start':
      'Mulai',
  'oph.clear':
      'Hapus riwayat',
  'oph.clear_title':
      'Hapus riwayat?',
  'oph.title':
      'Operasi terbaru',
  'oph.undone':
      '{n} item dikembalikan.',
  'pdf.discard_body':
      'Perubahan yang belum disimpan akan hilang.',
  'pdf.discard_confirm':
      'Keluar',
  'pdf.discard_title':
      'Buang perubahan?',
  'pdf.exit_edit':
      'Keluar dari pengeditan',
  'qrimg.chip':
      'QR ({n})',
  'qrimg.open':
      'Buka tautan',
  'qrimg.open_failed':
      'Tidak bisa membuka tautan',
  'qrimg.title':
      'QR di dalam gambar',
  'qrr.declined':
      'Penerimaan dibatalkan',
  'qrr.done_title':
      '{n} berkas diterima',
  'qrr.open_folder':
      'Buka folder',
  'qrr.receiving':
      'Menerima',
  'sdw.grant':
      'Izinkan menulis ke kartu SD',
  'sdw.granted':
      'Akses tulis kartu SD diberikan',
  'sdw.needs_grant':
      'Izin diperlukan untuk menulis ke kartu SD',
  'sdw.not_granted':
      'Izin tidak diberikan',
  'simf.inspected':
      '{n} / {total} berkas diperiksa',
  'simf.matching':
      'Mengekstrak kecocokan…',
  'simf.none':
      'Tidak ditemukan berkas serupa',
  'simf.preparing':
      'Menyiapkan…',
  'svs.name':
      'Nama',
  'svs.save':
      'Simpan pencarian',
  'svs.saved':
      '"{name}" disimpan',
  'svs.title':
      'Pencarian tersimpan',
  'vt.engine_preparing':
      'menyiapkan {engine}…',
  'vt.failed':
      'Tidak bisa mengonversi video: {error}',
  'vt.hw_encoder':
      'encoder perangkat keras',
  'vt.unsupported':
      'Video tidak bisa dikompres (formatnya mungkin tidak didukung).',
  'ap.body':
      'Arsip ini dilindungi kata sandi.',
  'ap.title':
      'Kata sandi arsip',
  'ap.wrong':
      'Kata sandi salah. Coba lagi.',
  'dm.sheet':
      'Lembar kerja',
  'dm.slides':
      'Presentasi',
  'dm.word':
      'Dokumen Word',
  'dur.hour':
      '{n} j',
  'dur.min':
      '{n} mnt',
  'dur.sec':
      '{n} dtk',
  'imp.recent':
      'Baru ditambahkan',
  'imp.tab_folder':
      'Folder',
  'imp.tab_gallery':
      'Galeri',
  'legacy.body':
      'Format {ext} lama: hanya teks yang ditampilkan, format hilang.',
  'legacy.convert':
      'Konversi ke {ext} & edit',
  'legacy.read_only':
      'HANYA-BACA',
  'ops.active':
      'Berjalan',
  'ops.finished':
      'Selesai',
  'ops.tab_organize':
      'Atur',
  'qf.card_add':
      'Tambahkan ke Kartu saya',
  'qf.card_remove':
      'Hapus dari Kartu saya',
  'qf.quick_add':
      'Tambahkan ke folder cepat',
  'report.folder':
      'Folder',
  'report.header':
      'Nama;Jenis;Ukuran (byte);Diubah',
  'report.summary':
      '{dirs} folder, {files} berkas',
  'rotate.done':
      'Disimpan {name}',
  'rotate.failed':
      'Tidak bisa memutar: {error}',
  'rotate.working':
      'Memutar…',
  'saf.folders_none':
      'Belum ada. Jika tidak ingin mengizinkan semua berkas, gunakan "Tambah folder" di layar utama untuk menambahkan hanya folder pilihan Anda.',
  'saf.folders_sub':
      'Anda hanya mengizinkan folder ini; tampil sebagai kartu di layar utama. "Cabut" menghapus akses, berkas tetap ada.',
  'saf.folders_title':
      'Folder yang ditambahkan',
  'shell.sheets':
      '{n} lembar',
  'shell.slides':
      '{n} slide',
  'shell.unsaved':
      'Belum disimpan',
  'sq.blurry':
      'Halaman tampak buram — disarankan memotret ulang',
  'sq.dark':
      'Cahaya redup — nyalakan lampu kilat dan potret ulang',
  'sq.skewed':
      'Halaman tampak miring',
  'src.title':
      'Sumber & waktu',
  'src.when':
      'Waktu & ukuran',
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
      'E-book',
  'type.text':
      'Teks',
  'uix.item_n':
      'Item {n}',
  'uix.video':
      'Video',
  'uix.view':
      'Tampilan',
  'xft.qr_title':
      'Bagikan dengan QR',
  'xft.scan_short':
      'Pindai',
  'xft.tab_quick':
      'Kirim cepat',
  'a11y.deselect':
      'Batalkan pilihan',
  'a11y.select':
      'Pilih',
  'aia.move_failed':
      'Tidak bisa memindahkannya: {error}',
  'aia.moved':
      '“{name}” → Önemli Dosyalar/{folder}',
  'crash.notice':
      'Aplikasi mengalami kesalahan ({n} laporan)',
  'crash.notice_hint':
      'Buka laporan untuk membagikannya',
  'dls.selected':
      '{n} berkas dipilih · ',
  'dls.untouched':
      '{n} berkas tidak disentuh selama 6 bulan · ',
  'dv.fallback':
      'Tidak bisa membuka tampilan halaman: {error}\n\nBeralih ke editor teks.',
  'dv.too_big':
      'dokumen terlalu besar ({mb} MB)',
  'fav.drag':
      'Seret untuk memindahkan',
  'fav.reorder':
      'Urutkan favorit',
  'lf.pdf_too_big':
      'PDF ini ({mb} MB) terlalu besar untuk alat (batas {max} MB). Penampil memutarnya secara streaming; untuk alat coba Pengaturan › Penyimpanan & kecepatan › Kinerja › Penuh.',
  'lf.xlsx_stream':
      'Berkas besar ({mb} MB): dibuka sebagai pratinjau streaming untuk menghemat memori — hanya nilai, hanya-baca. Penyimpanan dimatikan.',
  'lt.banner':
      'Berkas besar — hanya-baca, ditampilkan sebagian-sebagian · {n} baris · {enc}',
  'lt.indexing':
      'Menyiapkan berkas besar…',
  'pane.favorites':
      'Favorit',
  'pane.places':
      'Tempat',
  'pd.cancel':
      'Batal',
  'pd.preparing':
      'Menyiapkan…',
  'pii.setting':
      'Sembunyikan data pribadi',
  'pii.setting_sub':
      'Nomor identitas, IBAN, kartu, nomor telepon, dan email dikirim ke AI sebagai [TC], [IBAN]….',
  'qc.scope_off':
      'Berkas ini di luar cakupan fitur pintar (Pengaturan → Kecerdasan buatan).',
  'qc.too_large':
      'Berkas terlalu besar untuk aksi pintar (maks 14 MB).',
  'udf.corrupt':
      'Berkas UYAP (.udf) ini tampak rusak atau tidak lengkap dan tidak bisa dibuka. Unduh ulang dari UYAP atau minta salinan baru dari pengirim.',
  'udf.encrypted':
      'Berkas UYAP (.udf) ini terenkripsi dan tidak bisa dibuka di sini. Buka di UYAP Document Editor dan simpan tanpa kata sandi, atau dapatkan sebagai PDF.',
  'vsp.shrink':
      'Perkecil',
  'vsp.tooltip':
      'Perkecil ukuran: {from} → sekitar {to}',
  'ai.answer_language':
      'Indonesian',
  'fp.create_failed':
      'Tidak bisa membuat folder: {error}',
  'fresh.new':
      'Baru',
  'ia.reader_off':
      'Edisi ini tidak bisa mendaftar aplikasi terpasang. Edisi lengkap menampilkannya.',
  'jobs.files_progress':
      '{done}/{total} berkas',
  'nav.section':
      'Navigasi',
  'oss.all':
      'Semua lisensi',
  'pt.invert_selection':
      'Balikkan pilihan',
  'vn.title':
      'Catatan suara',
  'wt.title':
      'Dokumen Word baru',
  'act.clear_confirm':
      'Bersihkan daftar ini? Berkas Anda TIDAK dihapus — hanya riwayat catatan yang dikosongkan.',
  'act.empty':
      'Belum ada catatan.\nPerkecil ukuran video, sunting PDF, atau pindai dokumen agar berkas hasilnya tercantum di sini menurut jenisnya.',
  'aipool.backup_keys_sub':
      'Jika semua model pada kunci pertama kehabisan kuota, kunci berikutnya digunakan. Maksimal 5 kunci.',
  'aipool.model_chain_sub':
      'Gemini menghitung kuota per model. Saat satu model habis, permintaan pindah ke model berikutnya. Maksimal 6 model.',
  'aiset.budget_sub':
      'Tidak dibatasi secara bawaan agar analisis tidak berhenti sendiri. Saat kuota benar-benar habis, kumpulan pindah ke model/kunci berikutnya.',
  'aiset.excluded_sub':
      'Folder ini tidak pernah dianalisis dan isinya tidak pernah keluar dari perangkat. Folder kamera dikecualikan secara bawaan.',
  'aiset.send_images_sub':
      'Saat nonaktif, gambar itu sendiri tidak pernah diunggah; hanya teks OCR di perangkat yang digunakan.',
  'aiset.send_text_sub':
      '{kb} KB teks pertama dikirim ke Gemini. Saat nonaktif, hanya nama dan ukuran berkas yang dikirim.',
  'apps.usage_body':
      'Jika Anda memberi izin “Akses penggunaan” Android, Anda dapat melihat kapan terakhir kali membuka tiap aplikasi dan yang lama tidak dipakai akan ditandai. Data tidak keluar dari perangkat.',
  'backup.sub':
      'Tema, bahasa, markah, dan preferensi dalam satu berkas. Kunci API dan PIN TIDAK disertakan.',
  'cmp.7z_note':
      'Berkas lebih kecil. Dengan kata sandi, memakai AES-256; nama berkas juga dapat disembunyikan.',
  'cmp.password_warning':
      'Jika lupa kata sandi, arsip TIDAK DAPAT dibuka — tidak ada cara pemulihan.',
  'cmp.zip_note':
      'Bisa dibuka di mana saja. Dengan kata sandi, dienkripsi memakai AES-256 (nama berkas tetap terlihat).',
  'err.render_logged':
      'Kesalahan dicatat (Setelan > Catatan kesalahan).\nAnda dapat kembali ke layar sebelumnya.',
  'flt.direction_note':
      'Berkas terkirim dibaca dari folder “Sent” WhatsApp. Telegram tidak memisahkan ini sehingga berkasnya dihitung sebagai “diterima”.',
  'flt.hide_dupes_sub':
      'Berkas dengan nama dan ukuran yang sama ditampilkan sekali (WhatsApp menyimpan gambar yang sama di beberapa folder).',
  'fp.no_subfolders':
      'Folder ini belum memiliki subfolder.\nGunakan tombol di bawah untuk menaruh di sini, atau buat dengan “folder baru” di atas.',
  'ia.permission_hint':
      'Berikan izin untuk “Dosyalarım” pada halaman setelan yang terbuka, lalu kembali dan muat ulang.',
  'important.explain':
      'Simpan berkas yang tidak boleh hilang — KTP, tagihan, kontrak — di satu tempat. Folder dibuat di penyimpanan internal.\n\nCara menambah berkas: tekan lama berkas apa saja → “Pindah” atau “Salin” → “Berkas penting”. Anda juga bisa membuat subfolder per topik.',
  'important.no_subfolder':
      'Belum ada subfolder. Gunakan “Baru” untuk membuat topik (Tagihan, KTP, Kontrak…). Untuk menambah berkas, tekan lama berkas lalu pilih “Pindah”/“Salin”.',
  'jb.background_note':
      'Tugas tetap berjalan di latar belakang dan kemajuannya tampil di notifikasi. Jika aplikasi ditutup paksa dari daftar tugas, proses akan berhenti.',
  'jb.empty':
      'Belum ada tugas.\nTugas seperti perkecil ukuran, kosongkan ruang, dan pemindaian duplikat akan tampil di sini.',
  'jb.interrupted':
      'Terhenti karena aplikasi ditutup. Ketuk untuk memulai lagi.',
  'lib.empty_body':
      'Tambahkan berkas PDF, EPUB, MOBI, FB2, DJVU, dan komik (CBZ). Anda juga bisa memakai “Tambah ke pustaka” di menu berkas; berkas asli tidak dipindahkan.',
  'ocr.script_arabic_sub':
      'Arab, Persia, Urdu, Turki Utsmani: luring dengan model unduhan; jika belum ada memakai bacaan pintar.',
  'ocr.script_auto_sub':
      'Mengenali di perangkat; mencoba model Arab atau bacaan pintar untuk teks non-Latin.',
  'ocr.script_latin_sub':
      'Hanya di perangkat, luring.',
  'oph.clear_body':
      'Hanya catatan riwayat operasi yang dihapus; berkas Anda tetap aman. Namun Anda tidak lagi bisa membatalkannya.',
  'oph.empty':
      'Belum ada operasi tercatat.\nPemindahan dan penataan otomatis terkumpul di sini dan dapat dibatalkan dari sini.',
  'oph.undo_partial':
      '{n}/{total} item berhasil dibatalkan; sisanya tidak dapat dipindahkan. Catatan tetap disimpan agar Anda bisa mencoba lagi.',
  'org.confirm_body':
      '{files} berkas akan dipindahkan ke {folders} folder. Berkas ditata di dalam folder yang sama; tidak ada yang dihapus dan bisa dibatalkan dari riwayat.',
  'org.include_sub_note':
      'Saat nonaktif, hanya berkas di folder ini yang ditata; subfolder yang ada tidak disentuh.',
  'oss.body':
      'Perkecil ukuran dan pemutaran video memakai Android Media3 (Apache 2.0); H.264 memakai encoder perangkat keras ponsel. Pemutaran codec cadangan memakai libmpv/FFmpeg (media_kit, LGPL v2.1+, .so dinamis).\n\nSyncfusion Flutter PDF — Syncfusion Community License (BUKAN sumber terbuka; pemakaian gratis tunduk pada syarat).\n\nKomponen lain (Flutter, PDFium/pdfrx, Google ML Kit, archive, image, video_player, flutter_local_notifications …) berlisensi BSD/MIT/Apache 2.0. Daftar lengkap: “Semua lisensi”.',
  'pin.not_encrypted':
      'Kunci ini TIDAK mengenkripsi berkas: hanya menyembunyikannya dari daftar di aplikasi ini. Jika ponsel disambungkan ke komputer atau memakai pengelola berkas lain, berkas tetap terlihat.',
  'pp.allow_annotate':
      'Izinkan anotasi',
  'pp.allow_assemble':
      'Izinkan susun halaman',
  'pp.allow_copy':
      'Izinkan salin teks',
  'pp.allow_edit':
      'Izinkan sunting isi',
  'pp.allow_print':
      'Izinkan cetak',
  'pp.dsign_signed':
      'Ditandatangani',
  'pro.buy':
      'Beli',
  'pro.canceled':
      'Pembelian dibatalkan.',
  'pro.done':
      'Pro aktif — terima kasih!',
  'pro.f.ai':
      'AI',
  'pro.f.audiobook':
      'Buku audio',
  'pro.f.cleanup':
      'Kosongkan ruang',
  'pro.f.convert':
      'Konversi',
  'pro.f.extras':
      'Alat tambahan',
  'pro.f.labs':
      'Fitur eksperimental',
  'pro.f.media':
      'Media & galeri',
  'pro.f.remote':
      'Koneksi jarak jauh',
  'pro.f.scan':
      'Pemindaian dokumen',
  'pro.f.transfer':
      'Transfer',
  'pro.f.vault':
      'Brankas & kunci',
  'pro.failed':
      'Pembelian tidak dapat diselesaikan; silakan coba lagi nanti.',
  'pro.owned_sub':
      'Sudah dibeli · Semua fitur Pro terbuka',
  'pro.pending':
      'Menunggu pembayaran; Pro akan terbuka otomatis setelah disetujui.',
  'pro.price':
      'Harga: {p}',
  'pro.restore':
      'Pulihkan pembelian',
  'pro.restore_none':
      'Tidak ditemukan pembelian Pro di akun Google ini.',
  'pro.restored':
      'Pembelian dipulihkan — Pro aktif.',
  'pro.unavailable':
      'Tidak dapat menghubungi Google Play. Periksa koneksi internet dan pastikan Anda masuk ke Play Store.',
  'pt.annot_body':
      'Dokumen ini memiliki {n} sorotan/catatan. Operasi “{action}” membangun ulang halaman sehingga catatan tersebut akan terhapus.\n\nJika ingin menghapus halaman, tombol “Hapus” menjaga sorotan tetap aman.',
  'pt.compress_body':
      'Dokumen ({size}) ditulis ulang agar lebih kecil: aliran data dikompresi maksimal dan sisa revisi lama dibuang. Kualitas gambar TIDAK berubah.\n\nKarena itu penghematan lebih kecil pada dokumen hasil pindai (banyak gambar). Untuk berkas besar proses ini bisa memakan waktu semenit dan berjalan di latar belakang.',
  'ra.already_running':
      'Tugas ini sudah berjalan. Anda dapat memantaunya dari bilah bawah atau layar “Tugas”.',
  'ra.queued':
      'Tugas masuk antrean; akan mulai setelah tugas yang berjalan selesai. Pantau di layar “Tugas”.',
  'ra.started':
      'Tugas dimulai di latar belakang. Status dan berkas hasilnya dapat dilihat di bilah bawah atau layar “Tugas”.',
  'scr.no_text_yet':
      'Pemindaian ini dibuat tanpa pengenalan teks. Anda dapat mengenali teks pada halaman sekarang.',
  'sim.background_note':
      'Anda dapat menutup layar ini — pemindaian berlanjut di latar belakang dan hasilnya siap saat Anda kembali.',
  'srch.empty_hint':
      'Ketik sebagian nama berkas atau folder.\n\nTips: Anda juga bisa mengetik kalimat seperti “video whatsapp bulan lalu”, “pdf minggu ini”, atau “foto tahun 2024”.',
  'tf.failed':
      'Terjemahan gagal: {error}\nJika model bahasa belum terunduh, periksa koneksi internet Anda.',
  'tf.inplace_none':
      'Tidak ada paragraf yang bisa ditulis kembali ({n} dicoba): fon yang tertanam di dokumen mungkin tidak mendukung huruf bahasa tujuan. “Terjemahkan sebagai teks” tetap berfungsi.',
  'tf.inplace_partial':
      '{n} paragraf diterjemahkan; {skipped} tidak bisa ditulis kembali (fon tertanam kekurangan huruf bahasa tujuan atau teks tidak muat) dan dibiarkan tetap asli.',
  'tp.note':
      'Label tidak ditulis ke dalam berkas; label disimpan di catatan aplikasi ini. Label ikut terbawa saat Anda memindah, mengganti nama, atau memulihkannya lewat aplikasi ini, tetapi tidak ikut jika dipindah lewat aplikasi lain.',
  'tts.no_voices':
      'Perangkat tidak melaporkan daftar suara; kecepatan dan nada tetap dapat diatur. Suara lebih baik bisa diunduh lewat setelan ucapan sistem.',
  'usb.diag_cbi_only':
      'Drive ini melaporkan protokol lama (CBI) — penggerak aplikasi memakai Bulk-Only.',
  'usb.diag_uas_only':
      'Drive ini hanya melaporkan transport UAS (USB 3) — penggerak aplikasi memakai Bulk-Only. Izin folder (Pilih folder) tetap berfungsi.',
  'usb.open_raw_hint':
      'Aplikasi mengakses perangkat langsung meski Android tidak memasangnya. FAT16/FAT32 dan exFAT bisa dibaca dan ditulis; NTFS serta ext2/3/4 hanya-baca.',
  'vt.truncated':
      'Konversi terpotong: keluaran {out} dtk, sumber {src} dtk. Berkas asli tidak disentuh.',
  'vt.unreadable_output':
      'Video hasil konversi tidak dapat dibaca (keluaran rusak) — berkas asli tidak disentuh.',
  'clean.safe_main':
      'Aman dibebaskan',
  'clean.review_line':
      'Layak ditinjau: {size}',
  'clean.free_after':
      'Ruang kosong setelah pilihan dibersihkan: {before} → {after} (+{delta})',
  'clean.groups_n':
      '{n} grup',
  'clean.files_n':
      '{n} berkas',
  'clean.similar_detail':
      'Foto yang sangat mirip dalam {n} grup. Foto terbaik tiap grup disimpan; hanya sisanya yang disarankan.',
  'clean.chat_media':
      'Media obrolan',
  'clean.chat_media_detail':
      '{n} berkas yang mungkin tidak diperlukan di folder WhatsApp dan Telegram: stiker, GIF, media lama dan duplikat.',
  'clean.why_similar':
      'Tidak ada yang dipilih sebelumnya; ketuk untuk meninjau per grup. Foto terbaik tidak pernah dihapus.',
  'clean.why_chat_media':
      'Tidak ada yang dipilih sebelumnya; ketuk untuk meninjau per jenis. Dipindah ke tempat sampah, dapat dipulihkan.',
  'ink.swap':
      'Pena ⇄ penghapus',
  'ink.eraser_stroke':
      'Hapus goresan',
  'ink.eraser_area':
      'Hapus area',
  'ink.clear_all':
      'Hapus semua',
  'ink.width':
      'Ketebalan',
  'ink.color':
      'Warna',
  'ink.tray_hint':
      'Ketuk pena yang dipilih lagi untuk pengaturan. Tombol stylus atau ujung belakangnya menghapus.',
};
