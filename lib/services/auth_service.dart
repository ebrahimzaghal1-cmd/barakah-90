import "package:firebase_auth/firebase_auth.dart";
import 'user_profile_service.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, UserProfileService? profiles})
      : _auth = auth ?? FirebaseAuth.instance,
        _profiles = profiles ?? UserProfileService();

  final FirebaseAuth _auth;
  final UserProfileService _profiles;

  String? _lastIssuedBarakahPin;
  String? _lastBarakahCardNumber;

  String? get lastIssuedBarakahPin => _lastIssuedBarakahPin;
  String? get lastBarakahCardNumber => _lastBarakahCardNumber;

  void clearIssuedBarakahPin() {
    _lastIssuedBarakahPin = null;
  }

  // تسجيل مستخدم جديد
  Future<User?> signUp(String email, String password,
      {String? displayName}) async {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (result.user != null) {
      // نجاح إنشاء حساب Firebase لا يجب أن يتحول إلى فشل تسجيل بسبب
      // تعثر مؤقت في Firestore على الويب. يتم استكمال الملف عند الدخول التالي.
      try {
        await result.user!.updateDisplayName(displayName?.trim());
      } catch (_) {}
      try {
        final card = await _profiles.createCustomerProfile(
          result.user!,
          displayName: displayName,
        );
        _lastIssuedBarakahPin = card.initialPin;
        _lastBarakahCardNumber = card.cardNumber;
      } catch (_) {}

      try {
        await _profiles.claimSignupGift(result.user!);
      } catch (_) {}
    }
    return result.user;
  }

  // تسجيل الدخول
  Future<User?> signIn(String email, String password) async {
    UserCredential result = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (result.user != null) {
      try {
        final card = await _profiles.ensureCustomerProfile(result.user!);
        _lastIssuedBarakahPin = card.initialPin;
        _lastBarakahCardNumber = card.cardNumber;
      } catch (_) {}
    }
    return result.user;
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // المستخدم الحالي
  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
