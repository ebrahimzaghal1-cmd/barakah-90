import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_submission_notification_service.dart';

class AgentRegistrationService {
  AgentRegistrationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> apply({
    required String fullName,
    required String email,
    required String phone,
    required String nationalId,
    required String area,
    required String locationLabel,
    required double latitude,
    required double longitude,
    required String payoutMethod,
    required String payoutAccount,
    required bool acceptedAgentTerms,
    required bool acceptedPrivacyPolicy,
    required String agreementVersion,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    if (!acceptedAgentTerms || !acceptedPrivacyPolicy) {
      throw StateError('يجب الموافقة على الشروط وسياسة الخصوصية.');
    }

    final cleanName = fullName.trim();
    final cleanEmail = email.trim();
    final cleanPhone = phone.trim();
    final cleanNationalId = nationalId.trim();
    final cleanArea = area.trim();
    final cleanLocationLabel = locationLabel.trim();
    final cleanPayoutMethod = payoutMethod.trim();
    final cleanPayoutAccount = payoutAccount.trim();

    if (cleanName.isEmpty ||
        cleanEmail.isEmpty ||
        cleanPhone.isEmpty ||
        cleanNationalId.isEmpty ||
        cleanArea.isEmpty) {
      throw StateError('يرجى تعبئة جميع البيانات المطلوبة.');
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw StateError('إحداثيات الموقع غير صحيحة.');
    }

    await _firestore.collection('agent_applications').doc(user.uid).set({
      'userId': user.uid,
      'fullName': cleanName,
      'email': cleanEmail,
      'phone': cleanPhone,
      'nationalId': cleanNationalId,
      'area': cleanArea,
      'locationLabel': cleanLocationLabel,
      'latitude': latitude,
      'longitude': longitude,
      'location': GeoPoint(latitude, longitude),
      'payoutMethod': cleanPayoutMethod,
      'payoutAccount': cleanPayoutAccount,
      'acceptedAgentTerms': true,
      'acceptedPrivacyPolicy': true,
      'agreementVersion': agreementVersion,
      'agreementAcceptedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'identityVerified': false,
      'locationVerified': false,
      'payoutVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminSubmissionNotificationService.notify(
      type: 'agent_application',
      documentId: user.uid,
    );
  }
}
