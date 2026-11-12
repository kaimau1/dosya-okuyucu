import 'package:dosya_okuyucu/services/fm/remote/smb_legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// G8.4: SMB1 yalnız açık onayla; onay ana makine başına saklanır.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SmbLegacy.prompt = null;
  });

  test('paketin SMB1-yalnız hatası tanınır', () {
    expect(SmbLegacy.isSmb1Only('SmbConnectException: Server does not support SMB2'),
        isTrue);
    expect(SmbLegacy.isSmb1Only("Can't connect to nas"), isFalse);
  });

  test('kanca yokken reddedilir', () async {
    expect(await SmbLegacy.confirm('nas.local'), isFalse);
  });

  test('onay bir kez sorulur ve saklanır', () async {
    var asked = 0;
    SmbLegacy.prompt = (_) async {
      asked++;
      return true;
    };
    expect(await SmbLegacy.confirm('NAS.local'), isTrue);
    expect(await SmbLegacy.confirm('nas.local'), isTrue);
    expect(asked, 1);
    expect(await SmbLegacy.isAllowed('başka'), isFalse);
  });

  test('reddedilen onay saklanmaz', () async {
    SmbLegacy.prompt = (_) async => false;
    expect(await SmbLegacy.confirm('nas'), isFalse);
    expect(await SmbLegacy.isAllowed('nas'), isFalse);
  });
}
