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
};
