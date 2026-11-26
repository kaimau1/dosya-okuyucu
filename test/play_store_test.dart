import 'package:dosya_okuyucu/services/play_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KALANLAR A6.6: Play İçi Değerlendirme + Uygulama İçi Güncelleme kuralları.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const day = Duration.millisecondsPerDay;

  tearDown(() {
    PlayStore.debugBuild = null;
    PlayStore.debugResetSession();
  });

  group('değerlendirme kuralı', () {
    test('az açılış, tek gün ya da yeni kurulumda sorulmaz', () {
      expect(
          PlayStore.shouldAskReview(
              opens: 3, firstMs: 0, lastAskMs: null, nowMs: 30 * day),
          isFalse);
      expect(
          PlayStore.shouldAskReview(
              opens: 50,
              firstMs: 0,
              lastAskMs: null,
              nowMs: 10 * day,
              activeDays: 2),
          isFalse);
      expect(
          PlayStore.shouldAskReview(
              opens: 50, firstMs: 0, lastAskMs: null, nowMs: 2 * day),
          isFalse);
    });

    test('çökme, sürtünme ve görülmemiş hata soğutma uygular', () {
      expect(
          PlayStore.shouldAskReview(
              opens: 20,
              firstMs: 0,
              lastAskMs: null,
              nowMs: 10 * day,
              unseenCrashes: 1),
          isFalse);
      expect(
          PlayStore.shouldAskReview(
              opens: 20,
              firstMs: 0,
              lastAskMs: null,
              nowMs: 10 * day,
              lastCrashMs: 5 * day),
          isFalse);
      expect(
          PlayStore.shouldAskReview(
              opens: 20,
              firstMs: 0,
              lastAskMs: null,
              nowMs: 10 * day,
              lastFrictionMs: 8 * day),
          isFalse);
      expect(
          PlayStore.shouldAskReview(
              opens: 20,
              firstMs: 0,
              lastAskMs: null,
              nowMs: 10 * day,
              lastCrashMs: 1 * day,
              lastFrictionMs: 6 * day),
          isTrue);
    });

    test('eşik geçince sorulur, sonra 120 gün sorulmaz', () {
      expect(
          PlayStore.shouldAskReview(
              opens: 15, firstMs: 0, lastAskMs: null, nowMs: 6 * day),
          isTrue);
      expect(
          PlayStore.shouldAskReview(
              opens: 99, firstMs: 0, lastAskMs: 6 * day, nowMs: 60 * day),
          isFalse);
      expect(
          PlayStore.shouldAskReview(
              opens: 99, firstMs: 0, lastAskMs: 6 * day, nowMs: 130 * day),
          isTrue);
    });

    test('GitHub derlemesinde sayaç bile tutulmaz', () async {
      SharedPreferences.setMockInitialValues({});
      PlayStore.debugBuild = false;
      await PlayStore.noteFileOpened();
      await PlayStore.noteFriction();
      await PlayStore.noteCrash();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('güncelleme kararı', () {
    test('yanıt yok / güncelleme yok', () {
      expect(PlayStore.updatePlanOf(null), PlayUpdatePlan.none);
      expect(PlayStore.updatePlanOf({'available': false}), PlayUpdatePlan.none);
    });

    test('indirilmiş → yeniden başlat; yarım kalan → hemen', () {
      expect(PlayStore.updatePlanOf({'downloaded': true}),
          PlayUpdatePlan.restart);
      expect(PlayStore.updatePlanOf({'inProgress': true}),
          PlayUpdatePlan.immediate);
    });

    test('normalde esnek, acilse hemen', () {
      final base = {'available': true, 'flexible': true, 'immediate': true};
      expect(PlayStore.updatePlanOf({...base, 'priority': 1, 'staleDays': 2}),
          PlayUpdatePlan.flexible);
      expect(PlayStore.updatePlanOf({...base, 'priority': 4}),
          PlayUpdatePlan.immediate);
      // 14+ günlük eski sürüm bile yalnız düşük öncelikliyse kullanıcıyı tam ekranla kilitlemez.
      expect(PlayStore.updatePlanOf({...base, 'staleDays': 20}),
          PlayUpdatePlan.flexible);
      expect(
          PlayStore.updatePlanOf(
              {'available': true, 'flexible': false, 'immediate': true}),
          PlayUpdatePlan.immediate);
    });
  });
}
