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
  static const IconData notes = Icons.sticky_note_2_rounded;
  static const IconData voice = Icons.record_voice_over_rounded;
  static const IconData audiobook = Icons.headphones_rounded;
  static const IconData qr = Icons.qr_code_2_rounded;
  static const IconData greeting = Icons.local_florist_rounded;
  static const IconData blur = Icons.blur_on_rounded;
  static const IconData dark = Icons.dark_mode_rounded;
  static const IconData screenshot = Icons.screenshot_rounded;
  static const IconData openFull = Icons.open_in_full_rounded;
  static const IconData slideshow = Icons.slideshow_rounded;
  static const IconData fullscreen = Icons.fullscreen_rounded;
  static const IconData brightness = Icons.brightness_6_rounded;
  static const IconData rewind = Icons.fast_rewind_rounded;
  static const IconData fastForward = Icons.fast_forward_rounded;

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
  static const IconData hotspot = Icons.wifi_tethering_rounded;
  static const IconData textSnippet = Icons.text_snippet_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData help = Icons.help_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData editNote = Icons.edit_note_rounded;

  // ── boyutlandırma / görsel düzenleyici (Faz 14b, 2026-10-23) ─────────
  static const IconData bookmark = Icons.bookmark_rounded;
  static const IconData link = Icons.link_rounded;
  static const IconData linkOff = Icons.link_off_rounded;
  static const IconData crop = Icons.crop_rounded;
  static const IconData compare = Icons.compare_rounded;
  static const IconData draw = Icons.draw_rounded;
  static const IconData rotateRight = Icons.rotate_right_rounded;
  static const IconData reset = Icons.restart_alt_rounded;
  static const IconData arrowTool = Icons.north_east_rounded;
  static const IconData addPhoto = Icons.add_photo_alternate_rounded;
  static const IconData shrink = Icons.compress_rounded;

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

  // ── ekranlardan taşınanlar (Faz 15b, 2026-10-23) ─────────────────────
  static const IconData abc = Icons.abc_rounded;
  static const IconData accountCircle = Icons.account_circle_rounded;
  static const IconData accountTree = Icons.account_tree_rounded;
  static const IconData addCircleOutline = Icons.add_circle_outline_rounded;
  static const IconData addLink = Icons.add_link_rounded;
  static const IconData album = Icons.album_rounded;
  static const IconData alignHorizontalLeft = Icons.align_horizontal_left_rounded;
  static const IconData analytics = Icons.analytics_rounded;
  static const IconData android = Icons.android_rounded;
  static const IconData arrowDropDownCircle = Icons.arrow_drop_down_circle_rounded;
  static const IconData arrowDropDown = Icons.arrow_drop_down_rounded;
  static const IconData arrowForward = Icons.arrow_forward_rounded;
  static const IconData arrowRightAlt = Icons.arrow_right_alt_rounded;
  static const IconData assignment = Icons.assignment_rounded;
  static const IconData attachFile = Icons.attach_file_rounded;
  static const IconData audiotrack = Icons.audiotrack_rounded;
  static const IconData autoAwesomeMosaic = Icons.auto_awesome_mosaic_rounded;
  static const IconData autoAwesomeMotion = Icons.auto_awesome_motion_rounded;
  static const IconData autoDelete = Icons.auto_delete_rounded;
  static const IconData autoFixNormal = Icons.auto_fix_normal_rounded;
  static const IconData autoStories = Icons.auto_stories_rounded;
  static const IconData autorenew = Icons.autorenew_rounded;
  static const IconData backspace = Icons.backspace_rounded;
  static const IconData keyboardTab = Icons.keyboard_tab_rounded;
  static const IconData keyboardReturn = Icons.keyboard_return_rounded;
  static const IconData backup = Icons.backup_rounded;
  static const IconData badge = Icons.badge_rounded;
  static const IconData balance = Icons.balance_rounded;
  static const IconData barChart = Icons.bar_chart_rounded;
  static const IconData batteryChargingFull = Icons.battery_charging_full_rounded;
  static const IconData batteryStd = Icons.battery_std_rounded;
  static const IconData bedtime = Icons.bedtime_rounded;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData bookmarkOutline = Icons.bookmark_outline_rounded;
  static const IconData bookmarks = Icons.bookmarks_rounded;
  static const IconData borderAll = Icons.border_all_rounded;
  static const IconData borderBottom = Icons.border_bottom_rounded;
  static const IconData borderClear = Icons.border_clear_rounded;
  static const IconData borderColor = Icons.border_color_rounded;
  static const IconData borderOuter = Icons.border_outer_rounded;
  static const IconData borderTop = Icons.border_top_rounded;
  static const IconData brightnessAuto = Icons.brightness_auto_rounded;
  static const IconData brokenImage = Icons.broken_image_rounded;
  static const IconData bugReport = Icons.bug_report_rounded;
  static const IconData burstMode = Icons.burst_mode_rounded;
  static const IconData cake = Icons.cake_rounded;
  static const IconData calendarMonth = Icons.calendar_month_rounded;
  static const IconData cameraAlt = Icons.camera_alt_rounded;
  static const IconData campaign = Icons.campaign_rounded;
  static const IconData chat = Icons.chat_rounded;
  static const IconData chatBubbleOutline = Icons.chat_bubble_outline_rounded;
  static const IconData checkCircleOutline = Icons.check_circle_outline_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData childCare = Icons.child_care_rounded;
  static const IconData chromeReaderMode = Icons.chrome_reader_mode_rounded;
  static const IconData dot = Icons.circle_rounded;
  static const IconData clearAll = Icons.clear_all_rounded;
  static const IconData closedCaption = Icons.closed_caption_rounded;
  static const IconData closedCaptionOff = Icons.closed_caption_off_rounded;
  static const IconData cloud = Icons.cloud_rounded;
  static const IconData cloudDone = Icons.cloud_done_rounded;
  static const IconData cloudOff = Icons.cloud_off_rounded;
  static const IconData code = Icons.code_rounded;
  static const IconData computer = Icons.computer_rounded;
  static const IconData construction = Icons.construction_rounded;
  static const IconData contactPage = Icons.contact_page_rounded;
  static const IconData contentPasteGo = Icons.content_paste_go_rounded;
  static const IconData contrast = Icons.contrast_rounded;
  static const IconData copyAll = Icons.copy_all_rounded;
  static const IconData copyPlain = Icons.copy_rounded;
  static const IconData cropFree = Icons.crop_free_rounded;
  static const IconData dashboardCustomize = Icons.dashboard_customize_rounded;
  static const IconData dataObject = Icons.data_object_rounded;
  static const IconData dataUsage = Icons.data_usage_rounded;
  static const IconData deleteForever = Icons.delete_forever_rounded;
  static const IconData deleteSweep = Icons.delete_sweep_rounded;
  static const IconData developerMode = Icons.developer_mode_rounded;
  static const IconData dns = Icons.dns_rounded;
  static const IconData donutLarge = Icons.donut_large_rounded;
  static const IconData donutSmall = Icons.donut_small_rounded;
  static const IconData downloadForOffline = Icons.download_for_offline_rounded;
  static const IconData dragHandle = Icons.drag_handle_rounded;
  static const IconData dragIndicator = Icons.drag_indicator_rounded;
  static const IconData eject = Icons.eject_rounded;
  static const IconData emojiEmotions = Icons.emoji_emotions_rounded;
  static const IconData equalizer = Icons.equalizer_rounded;
  static const IconData eventNote = Icons.event_note_rounded;
  static const IconData expandLess = Icons.expand_less_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData filterAlt = Icons.filter_alt_rounded;
  static const IconData filterNone = Icons.filter_none_rounded;
  static const IconData findReplace = Icons.find_replace_rounded;
  static const IconData fingerprint = Icons.fingerprint_rounded;
  static const IconData firstPage = Icons.first_page_rounded;
  static const IconData fitScreen = Icons.fit_screen_rounded;
  static const IconData flipCameraAndroid = Icons.flip_camera_android_rounded;
  static const IconData flipToBack = Icons.flip_to_back_rounded;
  static const IconData flipToFront = Icons.flip_to_front_rounded;
  static const IconData formatIndentDecrease =
      Icons.format_indent_decrease_rounded;
  static const IconData formatIndentIncrease =
      Icons.format_indent_increase_rounded;
  static const IconData outline = Icons.view_headline_rounded;
  static const IconData folderCopy = Icons.folder_copy_rounded;
  static const IconData folderOff = Icons.folder_off_rounded;
  static const IconData folderSpecial = Icons.folder_special_rounded;
  static const IconData fontDownload = Icons.font_download_rounded;
  static const IconData formatAlignCenter = Icons.format_align_center_rounded;
  static const IconData formatAlignJustify = Icons.format_align_justify_rounded;
  static const IconData formatAlignLeft = Icons.format_align_left_rounded;
  static const IconData formatAlignRight = Icons.format_align_right_rounded;
  static const IconData formatBold = Icons.format_bold_rounded;
  static const IconData formatPaint = Icons.format_paint_rounded;
  static const IconData superscript = Icons.superscript_rounded;
  static const IconData subscript = Icons.subscript_rounded;
  static const IconData formatLineSpacing = Icons.format_line_spacing_rounded;
  static const IconData formatClear = Icons.format_clear_rounded;
  static const IconData formatColorFill = Icons.format_color_fill_rounded;
  static const IconData formatColorReset = Icons.format_color_reset_rounded;
  static const IconData formatColorText = Icons.format_color_text_rounded;
  static const IconData formatItalic = Icons.format_italic_rounded;
  static const IconData formatListBulleted = Icons.format_list_bulleted_rounded;
  static const IconData formatListNumbered = Icons.format_list_numbered_rounded;
  static const IconData formatQuote = Icons.format_quote_rounded;
  static const IconData formatSize = Icons.format_size_rounded;
  static const IconData formatTextdirectionRToL = Icons.format_textdirection_r_to_l_rounded;
  static const IconData formatUnderlined = Icons.format_underlined_rounded;
  static const IconData forum = Icons.forum_rounded;
  static const IconData forward10 = Icons.forward_10_rounded;
  static const IconData fullscreenExit = Icons.fullscreen_exit_rounded;
  static const IconData functions = Icons.functions_rounded;
  static const IconData gTranslate = Icons.g_translate_rounded;
  static const IconData gesture = Icons.gesture_rounded;
  static const IconData gifBox = Icons.gif_box_rounded;
  static const IconData graphicEq = Icons.graphic_eq_rounded;
  static const IconData gridOn = Icons.grid_on_rounded;
  static const IconData handyman = Icons.handyman_rounded;
  static const IconData height = Icons.height_rounded;
  static const IconData hideImage = Icons.hide_image_rounded;
  static const IconData historyEdu = Icons.history_edu_rounded;
  static const IconData historyToggleOff = Icons.history_toggle_off_rounded;
  static const IconData home = Icons.home_rounded;
  static const IconData hourglassEmpty = Icons.hourglass_empty_rounded;
  static const IconData inbox = Icons.inbox_rounded;
  static const IconData insertChart = Icons.insert_chart_rounded;
  static const IconData insertDriveFile = Icons.insert_drive_file_rounded;
  static const IconData insights = Icons.insights_rounded;
  static const IconData installMobile = Icons.install_mobile_rounded;
  static const IconData iosShare = Icons.ios_share_rounded;
  static const IconData key = Icons.key_rounded;
  static const IconData keyboardArrowDown = Icons.keyboard_arrow_down_rounded;
  static const IconData keyboard = Icons.keyboard_alt_rounded;
  static const IconData spellcheck = Icons.spellcheck_rounded;
  static const IconData draftRestore = Icons.restore_page_rounded;
  static const IconData keyboardArrowLeft = Icons.keyboard_arrow_left_rounded;
  static const IconData keyboardArrowRight = Icons.keyboard_arrow_right_rounded;
  static const IconData keyboardArrowUp = Icons.keyboard_arrow_up_rounded;
  static const IconData labelOutline = Icons.label_outline_rounded;
  static const IconData lan = Icons.lan_rounded;
  static const IconData lastPage = Icons.last_page_rounded;
  static const IconData layers = Icons.layers_rounded;
  static const IconData layersClear = Icons.layers_clear_rounded;
  static const IconData libraryMusic = Icons.library_music_rounded;
  static const IconData lightMode = Icons.light_mode_rounded;
  static const IconData lightbulbOutline = Icons.lightbulb_outline_rounded;
  static const IconData listAlt = Icons.list_alt_rounded;
  static const IconData login = Icons.login_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData lowPriority = Icons.low_priority_rounded;
  static const IconData manageSearch = Icons.manage_search_rounded;
  static const IconData memory = Icons.memory_rounded;
  static const IconData menuBook = Icons.menu_book_rounded;
  static const IconData mergeType = Icons.merge_type_rounded;
  static const IconData micNone = Icons.mic_none_rounded;
  static const IconData moveToInbox = Icons.move_to_inbox_rounded;
  static const IconData networkCheck = Icons.network_check_rounded;
  static const IconData noteAdd = Icons.note_add_rounded;
  static const IconData lines = Icons.notes_rounded;
  static const IconData notificationsNone = Icons.notifications_none_rounded;
  static const IconData numbers = Icons.numbers_rounded;
  static const IconData offlineBolt = Icons.offline_bolt_rounded;
  static const IconData dragMove = Icons.open_with_rounded;
  static const IconData palette = Icons.palette_rounded;
  static const IconData panTool = Icons.pan_tool_rounded;
  static const IconData password = Icons.password_rounded;
  static const IconData pauseCircle = Icons.pause_circle_rounded;
  static const IconData pauseCircleOutline = Icons.pause_circle_outline_rounded;
  static const IconData phonelink = Icons.phonelink_rounded;
  static const IconData phonelinkLock = Icons.phonelink_lock_rounded;
  static const IconData photoCamera = Icons.photo_camera_rounded;
  static const IconData photoSizeSelectSmall = Icons.photo_size_select_small_rounded;
  static const IconData pictureInPictureAlt = Icons.picture_in_picture_alt_rounded;
  static const IconData pieChartOutline = Icons.pie_chart_outline_rounded;
  static const IconData pinch = Icons.pinch_rounded;
  static const IconData place = Icons.place_rounded;
  static const IconData playCircle = Icons.play_circle_rounded;
  static const IconData playCircleFill = Icons.play_circle_fill_rounded;
  static const IconData playCircleOutline = Icons.play_circle_outline_rounded;
  static const IconData playlistAdd = Icons.playlist_add_rounded;
  static const IconData playlistAddCheckCircle = Icons.playlist_add_check_circle_rounded;
  static const IconData playlistPlay = Icons.playlist_play_rounded;
  static const IconData podcasts = Icons.podcasts_rounded;
  static const IconData postAdd = Icons.post_add_rounded;
  static const IconData powerSettingsNew = Icons.power_settings_new_rounded;
  static const IconData print = Icons.print_rounded;
  static const IconData privacyTip = Icons.privacy_tip_rounded;
  static const IconData pushPin = Icons.push_pin_rounded;
  static const IconData queryStats = Icons.query_stats_rounded;
  static const IconData receiptLong = Icons.receipt_long_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData removeCircleOutline = Icons.remove_circle_outline_rounded;
  static const IconData repeat = Icons.repeat_rounded;
  static const IconData repeatOn = Icons.repeat_on_rounded;
  static const IconData repeatOne = Icons.repeat_one_rounded;
  static const IconData replay10 = Icons.replay_10_rounded;
  static const IconData restore = Icons.restore_rounded;
  static const IconData rotate90DegreesCcw = Icons.rotate_90_degrees_ccw_rounded;
  static const IconData rotateLeft = Icons.rotate_left_rounded;
  static const IconData rule = Icons.rule_rounded;
  static const IconData savedSearch = Icons.saved_search_rounded;
  static const IconData schedule = Icons.schedule_rounded;
  static const IconData sdCardAlert = Icons.sd_card_alert_rounded;
  static const IconData searchOff = Icons.search_off_rounded;
  static const IconData sendToMobile = Icons.send_to_mobile_rounded;
  static const IconData settingsBackupRestore = Icons.settings_backup_restore_rounded;
  static const IconData shield = Icons.shield_rounded;
  static const IconData shortText = Icons.short_text_rounded;
  static const IconData showChart = Icons.show_chart_rounded;
  static const IconData shuffle = Icons.shuffle_rounded;
  static const IconData skipNext = Icons.skip_next_rounded;
  static const IconData skipPrevious = Icons.skip_previous_rounded;
  static const IconData smartToy = Icons.smart_toy_rounded;
  static const IconData spaceDashboard = Icons.space_dashboard_rounded;
  static const IconData speed = Icons.speed_rounded;
  static const IconData starOutline = Icons.star_outline_rounded;
  static const IconData stop = Icons.stop_rounded;
  static const IconData database = Icons.storage_rounded;
  static const IconData straighten = Icons.straighten_rounded;
  static const IconData strikethroughS = Icons.strikethrough_s_rounded;
  static const IconData style = Icons.style_rounded;
  static const IconData subject = Icons.subject_rounded;
  static const IconData summarize = Icons.summarize_rounded;
  static const IconData swapHoriz = Icons.swap_horiz_rounded;
  static const IconData swapVert = Icons.swap_vert_rounded;
  static const IconData swapVertCircle = Icons.swap_vert_circle_rounded;
  static const IconData tableRows = Icons.table_rows_rounded;
  static const IconData tableView = Icons.table_view_rounded;
  static const IconData textDecrease = Icons.text_decrease_rounded;
  static const IconData textFormat = Icons.text_format_rounded;
  static const IconData textIncrease = Icons.text_increase_rounded;
  static const IconData title = Icons.title_rounded;
  static const IconData toc = Icons.toc_rounded;
  static const IconData touchApp = Icons.touch_app_rounded;
  static const IconData trendingDown = Icons.trending_down_rounded;
  static const IconData trendingUp = Icons.trending_up_rounded;
  static const IconData troubleshoot = Icons.troubleshoot_rounded;
  static const IconData unfoldMore = Icons.unfold_more_rounded;
  static const IconData uploadFile = Icons.upload_file_rounded;
  static const IconData uploadArrow = Icons.upload_rounded;
  static const IconData verified = Icons.verified_rounded;
  static const IconData vibration = Icons.vibration_rounded;
  static const IconData videoLibrary = Icons.video_library_rounded;
  static const IconData viewColumn = Icons.view_column_rounded;
  static const IconData viewComfy = Icons.view_comfy_rounded;
  static const IconData volumeDown = Icons.volume_down_rounded;
  static const IconData volumeOff = Icons.volume_off_rounded;
  static const IconData volumeUp = Icons.volume_up_rounded;
  static const IconData vpnKey = Icons.vpn_key_rounded;
  static const IconData wifiFind = Icons.wifi_find_rounded;
  static const IconData wifiTetheringOff = Icons.wifi_tethering_off_rounded;
  static const IconData wrapText = Icons.wrap_text_rounded;
  static const IconData zoomIn = Icons.zoom_in_rounded;
  static const IconData zoomOut = Icons.zoom_out_rounded;

  // ── 2026-10-28 turu ──────────────────────────────────────────────────
  /// Tür seçici hapı (tüm türler).
  static const IconData typeAll = Icons.category_rounded;
  /// "Görüntüler" — fotoğraf + video birleşik ekran.
  static const IconData mediaAll = Icons.perm_media_rounded;
  /// Fotoğraflar (yalnız görsel) kutusu.
  static const IconData photos = Icons.photo_library_rounded;
  /// QR ile al (tarayıcı).
  static const IconData qrScan = Icons.qr_code_scanner_rounded;
  /// Gelen dosya isteği.
  static const IconData incoming = Icons.call_received_rounded;
}
