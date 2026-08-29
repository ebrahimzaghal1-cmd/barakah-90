import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  String _generateCardNumber() {
    final random = Random.secure();
    String block() => List.generate(4, (_) => random.nextInt(10)).join();
    return 'BRK-${block()}-${block()}-${block()}';
  }

  String _generatePin() {
    final random = Random.secure();
    return random.nextInt(10000).toString().padLeft(4, '0');
  }

  String _hashPin({
    required String uid,
    required String salt,
    required String pin,
  }) {
    return sha256.convert(utf8.encode('$uid:$salt:$pin')).toString();
  }

  Future<BarakahCardProvisionResult> _ensureBarakahCard(
    User user,
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic>? existingData,
  ) async {
    final existingCard =
        (existingData?['barakahCardNumber'] ?? '').toString().trim();

    if (existingCard.isNotEmpty) {
      return BarakahCardProvisionResult(cardNumber: existingCard);
    }

    final pin = _generatePin();
    final salt =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 31)}';
    final cardNumber = _generateCardNumber();

    await reference.set({
      'barakahCardNumber': cardNumber,
      'barakahPinHash': _hashPin(
        uid: user.uid,
        salt: salt,
        pin: pin,
      ),
      'barakahPinSalt': salt,
      'barakahCardActive': true,
      'barakahCardCreatedAt': FieldValue.serverTimestamp(),
      'loyaltyPoints': (existingData?['loyaltyPoints'] as num?)?.toInt() ?? 0,
    }, SetOptions(merge: true));

    return BarakahCardProvisionResult(
      cardNumber: cardNumber,
      initialPin: pin,
    );
  }

  Future<BarakahCardProvisionResult> createCustomerProfile(
    User user, {
    String? displayName,
  }) async {
    final reference = _firestore.collection('users').doc(user.uid);

    await reference.set({
      'email': user.email,
      'phone': user.phoneNumber ?? '',
      'displayName': displayName?.trim() ?? '',
      'address': '',
      'gender': '',
      'agentNumber': '',
      'agentLocation': '',
      'agentLatitude': null,
      'agentLongitude': null,
      'facebookUrl': '',
      'instagramUrl': '',
      'tiktokUrl': '',
      'language': 'ar',
      'role': 'customer',
      'loyaltyPoints': signupGiftPoints,
      'signupGiftClaimed': true,
      'signupGiftPoints': signupGiftPoints,
      'signupGiftClaimedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final createdSnapshot = await reference.get();
    final createdData = createdSnapshot.data() ?? <String, dynamic>{};

    return _ensureBarakahCard(
      user,
      reference,
      createdData,
    );
  }

  Future<BarakahCardProvisionResult> ensureCustomerProfile(User user,
      {String? displayName}) async {
    final reference = _firestore.collection('users').doc(user.uid);
    final existing = await reference.get();
    if (existing.exists) {
      final currentData = existing.data() ?? <String, dynamic>{};
      final authenticatedName = (displayName ?? user.displayName ?? '').trim();
      final updates = <String, dynamic>{
        // مزامنة بيانات Firebase Auth للحسابات القديمة التي أُنشئت قبل
        // إضافة حقول البريد والهاتف إلى مجموعة users.
        if ((user.email ?? '').trim().isNotEmpty) 'email': user.email!.trim(),
        if ((user.phoneNumber ?? '').trim().isNotEmpty)
          'phone': user.phoneNumber!.trim(),
        if (authenticatedName.isNotEmpty &&
            (currentData['displayName'] ?? '').toString().trim().isEmpty)
          'displayName': authenticatedName,
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
