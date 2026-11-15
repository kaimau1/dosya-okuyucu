import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/services/fm/dashboard_layout.dart';
import 'package:dosya_okuyucu/widgets/fm/reorder_hover_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reorderVisible gizli kutuları yuvasında bırakır', () async {
    final layout = DashboardLayout.instance..debugReset();
    final order = layout.tileOrder;
    expect(order.length, greaterThan(3));
    final a = order[0], b = order[1], c = order[2];
    await layout.setTileVisible(b, false);
    // Görünenlerden a ile c yer değiştirir; gizli b ikinci yuvada kalır.
    final visible = [for (final id in order) if (id != b) id];
    final swapped = [c, a, ...visible.skip(2)];
    await layout.reorderVisible(swapped);
    expect(layout.tileOrder.take(3), [c, b, a]);
  });

  test('sürükleme kapısı: durma + kilit (iki hücre arasında zıplama yok)', () {
    var now = DateTime(2026);
    final gate = ReorderHoverGate(clock: () => now);
    expect(gate.offer('x'), isFalse, reason: 'ilk değme durma ister');
    now = now.add(const Duration(milliseconds: 200));
    expect(gate.offer('x'), isTrue);
    now = now.add(const Duration(milliseconds: 500));
    expect(gate.offer('x'), isFalse, reason: 'itilen kart kilitli');
    gate.leave('x');
    expect(gate.offer('x'), isFalse);
  });

  test('tasarım aileleri kendi ana ekran düzenini getirir', () {
    expect(SkinMetrics.of(AppSkin.calm).homeStyle, HomeStyle.calm);
    expect(SkinMetrics.of(AppSkin.bento).homeStyle, HomeStyle.bento);
    expect(SkinMetrics.of(AppSkin.band).homeStyle, HomeStyle.band);
    expect(SkinMetrics.of(AppSkin.sage).homeStyle, HomeStyle.classic);
    expect(Brightness.values, isNotEmpty);
  });
}
