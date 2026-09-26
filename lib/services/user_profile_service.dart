import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class BarakahCardProvisionResult {
  const BarakahCardProvisionResult({
    required this.cardNumber,
    this.initialPin,
  });

  final String cardNumber;
  final String? initialPin;
}

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int signupGiftPoints = 50;
  static const _apiBase = 'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  Future<bool> claimSignupGift(User user) async {
    final reference = _firestore.collection('users').doc(user.uid);

    final claimed = await _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data() ?? <String, dynamic>{};

      if (data['signupGiftClaimed'] == true) {
        return false;
      }

      final currentPoints = (data['loyaltyPoints'] as num?)?.toInt() ?? 0;

      transaction.set(
        reference,
        {
          'loyaltyPoints': currentPoints + signupGiftPoints,
          'signupGiftClaimed': true,
          'signupGiftPoints': signupGiftPoints,
          'signupGiftClaimedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return true;
    });

    if (!claimed) return false;

    try {
      await _firestore.collection('loyalty_transactions').add({
        'userId': user.uid,
        'pointsDelta': signupGiftPoints,
        'type': 'signup_gift',
        'title': 'هدية التسجيل',
        'description': '50 نقطة هدية اشتراك في بركة',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // لا نلغي رصيد المستخدم إذا تعذر إنشاء سجل التاريخ.
    }

    return true;
  }

  Future<BarakahCardProvisionResult> _ensureBarakahCard(
    User user,
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic>? existingData,
  ) async {
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw StateError('انتهت جلسة الدخول.');
    final response = await http.post(Uri.parse('$_apiBase/v1/profile/ensure'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'displayName': user.displayName ?? ''}));
    final data = response.body.isEmpty ? const <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || data is! Map) {
      throw StateError('تعذر إعداد بطاقة بركة.');
    }
    return BarakahCardProvisionResult(cardNumber: data['cardNumber']?.toString() ?? '', initialPin: data['initialPin']?.toString());
  }

  Future<BarakahCardProvisionResult> createCustomerProfile(
    User user, {
    String? displayName,
  }) async {
    final reference = _firestore.collection('users').doc(user.uid);

    return _ensureBarakahCard(user, reference, null);
  }

  Future<BarakahCardProvisionResult> ensureCustomerProfile(User user,
      {String? displayName}) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final existing = await reference.get();
    if (existing.exists) {
      final currentData = existing.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      await reference.set(updates, SetOptions(merge: true));
      return _ensureBarakahCard(user, reference, currentData);
    }
    return createCustomerProfile(user, displayName: displayName);
  }

  Future<int> customerCount() async {
    final result = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'customer')
        .count()
        .get();
    return result.count ?? 0;
  }

  Future<bool> isAdmin(String uid) async {
    final profile = await _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    return profile.data()?['role']?.toString() == 'admin';
  }

  Future<void> updateCustomerProfile(String uid, Map<String, dynamic> data) {
    return _firestore.collection('users').doc(uid).set(
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}
