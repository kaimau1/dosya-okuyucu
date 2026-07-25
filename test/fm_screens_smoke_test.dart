import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/analysis_screen.dart';
import 'package:dosya_okuyucu/screens/fm/archive_screen.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/fm/category_screen.dart';
import 'package:dosya_okuyucu/screens/fm/dashboard_screen.dart';
import 'package:dosya_okuyucu/screens/fm/search_screen.dart';
import 'package:dosya_okuyucu/screens/fm/trash_screen.dart';
import 'package:dosya_okuyucu/screens/home_screen.dart';
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
      const AnalysisScreen(index: StorageIndex.empty, volumes: []),
    ];
    expect(widgets, everyElement(isA<Widget>()));
  });
}
