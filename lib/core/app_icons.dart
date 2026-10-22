import 'package:flutter/material.dart';

/// Uygulamanın **eylem simgeleri** — tek tablo, tek glif ailesi
/// (Faz 6 / U9, 2026-10-21).
///
/// KÖK NEDEN: gezgin, dosya menüsü ve seçim çubuğu ham `Icons.*` kullanıyordu;
/// aynı ekranda dolu (`content_cut`), çizgi (`copy_outlined`) ve yuvarlak
/// (`star_rounded`) glifler yan yana duruyordu, "Taşı" bir ekranda
/// `drive_file_move_outline` öbüründe başka bir şeydi. Artık:
/// * **tek aile** — yalnız `*_rounded` glifler (bekçi: `app_icons_test`);
/// * **anlamsal adlar** — çağıran "hangi resim" değil "hangi eylem" der
///   (`AppIcons.move`); glif değişirse tek yer değişir;
/// * **üç boy** — [small] (yoğun satır, çip), [medium] (araç çubuğu),
///   [large] (boş durum, levha başlığı).
///
/// Dosya TÜRÜ simgeleri ve renkleri burada değil `FmColors` / `FmEntryIcon`
/// içinde: onlar içerik gösterir, eylem değil.
abstract final class AppIcons {
  // ── boylar ────────────────────────────────────────────────────────────
  static const double small = 20;
  static const double medium = 24;
  static const double large = 32;

  // ── gezinme / çubuk ───────────────────────────────────────────────────
  static const IconData search = Icons.search_rounded;
  static const IconData more = Icons.more_vert_rounded;
  static const IconData moreHoriz = Icons.more_horiz_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData chevron = Icons.chevron_right_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData filter = Icons.filter_list_rounded;
  static const IconData sort = Icons.sort_rounded;
  static const IconData arrowUp = Icons.arrow_upward_rounded;
  static const IconData arrowDown = Icons.arrow_downward_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData circle = Icons.radio_button_unchecked_rounded;
  static const IconData dropDown = Icons.arrow_drop_down_rounded;
  static const IconData history = Icons.history_rounded;

  // ── görünüm ───────────────────────────────────────────────────────────
  static const IconData layoutList = Icons.view_list_rounded;
  static const IconData layoutDetail = Icons.view_agenda_rounded;
  static const IconData layoutGrid = Icons.grid_view_rounded;
  static const IconData layoutGallery = Icons.photo_library_rounded;
  static const IconData hidden = Icons.visibility_rounded;
  static const IconData hiddenOff = Icons.visibility_off_rounded;

  // ── seçim ─────────────────────────────────────────────────────────────
  static const IconData selectAll = Icons.select_all_rounded;
  static const IconData selectNone = Icons.deselect_rounded;
  static const IconData selectInvert = Icons.flip_rounded;
  static const IconData selectAbove = Icons.vertical_align_top_rounded;
  static const IconData selectBelow = Icons.vertical_align_bottom_rounded;

  // ── dosya eylemleri ───────────────────────────────────────────────────
  static const IconData open = Icons.open_in_new_rounded;
  static const IconData openWith = Icons.apps_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData move = Icons.drive_file_move_rounded;
  static const IconData copy = Icons.file_copy_rounded;
  static const IconData clipCopy = Icons.content_copy_rounded;
  static const IconData cut = Icons.content_cut_rounded;
  static const IconData paste = Icons.content_paste_rounded;
  static const IconData rename = Icons.drive_file_rename_outline_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData starEmpty = Icons.star_border_rounded;
  static const IconData important = Icons.bookmark_add_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData unlock = Icons.lock_open_rounded;
  static const IconData vault = Icons.enhanced_encryption_rounded;
  static const IconData reveal = Icons.my_location_rounded;
  static const IconData homeShortcut = Icons.add_to_home_screen_rounded;
  static const IconData upload = Icons.cloud_upload_rounded;
  static const IconData shareFolder = Icons.folder_shared_rounded;
  static const IconData external = Icons.usb_rounded;
  static const IconData sdCard = Icons.sd_card_rounded;
  static const IconData archiveView = Icons.folder_zip_rounded;
  static const IconData extract = Icons.unarchive_rounded;
  static const IconData compress = Icons.archive_rounded;
  static const IconData tag = Icons.sell_rounded;
  static const IconData hashtag = Icons.tag_rounded;
  static const IconData rotate = Icons.rotate_90_degrees_cw_rounded;
  static const IconData split = Icons.call_split_rounded;
  static const IconData join = Icons.merge_rounded;
  static const IconData ai = Icons.auto_awesome_rounded;
  static const IconData ocr = Icons.document_scanner_rounded;
  static const IconData resize = Icons.photo_size_select_large_rounded;
  static const IconData organize = Icons.auto_fix_high_rounded;
  static const IconData cleanEmpty = Icons.cleaning_services_rounded;
  static const IconData exportList = Icons.playlist_add_check_rounded;

  // ── genel eylemler (Faz 15, 2026-10-22) ──────────────────────────────
  static const IconData save = Icons.save_rounded;
  static const IconData download = Icons.download_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData undo = Icons.undo_rounded;
  static const IconData redo = Icons.redo_rounded;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData translate = Icons.translate_rounded;
  static const IconData tune = Icons.tune_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData textFields = Icons.text_fields_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData help = Icons.help_outline_rounded;

  // ── içerik türleri (eylem düğmesinde; liste satırı FmEntryIcon'dan) ───
  static const IconData image = Icons.image_rounded;
  static const IconData video = Icons.movie_rounded;
  static const IconData audio = Icons.music_note_rounded;
  static const IconData pdf = Icons.picture_as_pdf_rounded;

  // ── oluşturma ("+" levhası) ──────────────────────────────────────────
  static const IconData newFolder = Icons.create_new_folder_rounded;
  static const IconData newWord = Icons.description_rounded;
  static const IconData newSheet = Icons.table_chart_rounded;
  static const IconData newText = Icons.article_rounded;
  static const IconData scanHere = Icons.document_scanner_rounded;
  static const IconData importHere = Icons.download_rounded;

  // ── durumlar ──────────────────────────────────────────────────────────
  static const IconData emptyFolder = Icons.folder_open_rounded;
  static const IconData noMatch = Icons.filter_alt_off_rounded;
  static const IconData unreadable = Icons.block_rounded;
  static const IconData locked = Icons.lock_rounded;
  static const IconData device = Icons.smartphone_rounded;
  static const IconData folder = Icons.folder_rounded;
  static const IconData storage = Icons.sd_storage_rounded;
}
