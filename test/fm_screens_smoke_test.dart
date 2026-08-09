import 'package:dosya_okuyucu/screens/fm/analysis_screen.dart';
import 'package:dosya_okuyucu/screens/fm/archive_screen.dart';
import 'package:dosya_okuyucu/screens/fm/audio_player_screen.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/fm/category_screen.dart';
import 'package:dosya_okuyucu/screens/fm/dashboard_screen.dart';
import 'package:dosya_okuyucu/screens/fm/downloads_screen.dart';
import 'package:dosya_okuyucu/screens/fm/duplicates_screen.dart';
import 'package:dosya_okuyucu/screens/fm/image_gallery_screen.dart';
import 'package:dosya_okuyucu/screens/fm/installed_apps_screen.dart';
import 'package:dosya_okuyucu/screens/fm/jobs_screen.dart';
import 'package:dosya_okuyucu/screens/fm/media_player_screen.dart';
import 'package:dosya_okuyucu/screens/fm/photos_screen.dart';
import 'package:dosya_okuyucu/screens/fm/search_screen.dart';
import 'package:dosya_okuyucu/screens/fm/trash_screen.dart';
import 'package:dosya_okuyucu/screens/home_screen.dart';
import 'package:dosya_okuyucu/screens/settings/settings_catalog.dart';
import 'package:dosya_okuyucu/screens/settings/settings_category_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** CI'ın ucuz `test` işi yalnızca testlerden ERİŞİLEN
/// dosyaları derler. Ekranlar hiçbir testten import edilmezse, bir ekranda
/// kalan derleme hatası ancak ~20 dakikalık APK derlemesinde ortaya çıkar.
/// Bu duman testi ekranları import edip kurucularını çağırır → hata feature
/// dalındaki hızlı test koşusunda yakalanır. (Widget'lar pump EDİLMEZ:
/// path_provider/permission_handler gibi eklentiler test ortamında yok.)
void main() {
  test('dosya yöneticisi ekranları derlenir ve kurulabilir', () {
    final widgets = <Widget>[
      const HomeScreen(),
      const DashboardScreen(),
      const BrowserScreen(path: '/tmp'),
      const ArchiveScreen(path: '/tmp/a.rar'),
      const TrashScreen(),
      const SearchScreen(root: '/tmp'),
      const CategoryScreen(title: 'Görüntüler', files: []),
      const CategoryScreen(title: 'Belgeler', files: [], showDocKinds: true),
      const PhotosScreen(title: 'Görüntüler', files: []),
      const AnalysisScreen(index: StorageIndex.empty, volumes: []),
      const MediaPlayerScreen(path: '/tmp/a.mp4'),
      const AudioPlayerScreen(path: '/tmp/a.mp3'),
      const ImageGalleryScreen(paths: ['/tmp/a.jpg']),
      const DuplicatesScreen(roots: ['/tmp']),
      const InstalledAppsScreen(),
      const DownloadsScreen(path: '/tmp'),
      // Ayrı bir "dosya yöneticisi ayarları" ekranı KALMADI (2026-08-09):
      // hepsi tek Ayarlar ekranında, sekiz kategoride. Kategori sayfalarının
      // hepsi burada kuruluyor — yoksa çöp/izin/bakım satırlarındaki bir
      // derleme hatası ancak APK derlemesinde görülürdü.
      const SettingsScreen(),
      for (final category in settingsCategories())
        SettingsCategoryScreen(category: category),
      const JobsScreen(),
    ];
    expect(widgets, everyElement(isA<Widget>()));
  });
}
