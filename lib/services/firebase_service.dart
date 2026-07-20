import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase giriş + bulut senkron sarmalayıcısı.
///
/// Firebase yapılandırılmamışsa (google-services.json / firebase_options yoksa)
/// [available] false döner ve uygulama sorunsuz şekilde "yerel mod"da çalışır.
class FirebaseService {
  bool _available = false;
  bool get available => _available;

  FirebaseAuth? _auth;
  FirebaseFirestore? _db;

  /// Firebase'i güvenli şekilde başlatır. Config yoksa sessizce yerel moda düşer.
  Future<bool> init() async {
    try {
      await Firebase.initializeApp();
      _auth = FirebaseAuth.instance;
      _db = FirebaseFirestore.instance;
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  Stream<User?> authState() =>
      _auth?.authStateChanges() ?? const Stream<User?>.empty();

  User? get currentUser => _auth?.currentUser;

  Future<String?> signInWithEmail(String email, String password) async {
    return _guard(() async {
      await _auth!.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    });
  }

  Future<String?> registerWithEmail(String email, String password) async {
    return _guard(() async {
      await _auth!.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    });
  }

  Future<String?> signInWithGoogle() async {
    return _guard(() async {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
            code: 'cancelled', message: 'Google girişi iptal edildi.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth!.signInWithCredential(credential);
    });
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth?.signOut();
  }

  /// Bulut verisini çeker: { 'recents': [...], 'memory': [...] }.
  Future<Map<String, dynamic>?> pull(String uid) async {
    if (!_available) return null;
    try {
      final snap = await _db!.collection('users').doc(uid).get();
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  /// Bulut verisini yazar (merge).
  Future<void> push(
    String uid, {
    required List<Map<String, dynamic>> recents,
    required List<String> memory,
  }) async {
    if (!_available) return;
    try {
      await _db!.collection('users').doc(uid).set({
        'recents': recents,
        'memory': memory,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// İşlemi çalıştırır; hata mesajını (varsa) döndürür, başarıda null.
  Future<String?> _guard(Future<void> Function() action) async {
    if (!_available || _auth == null) {
      return 'Firebase yapılandırılmamış. Ayarlar’daki kurulum adımlarını izleyin.';
    }
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    } catch (e) {
      return '$e';
    }
  }
}
