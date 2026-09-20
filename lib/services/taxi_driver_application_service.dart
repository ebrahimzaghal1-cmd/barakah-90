import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_submission_notification_service.dart';

class TaxiDriverApplicationService {
  TaxiDriverApplicationService({
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
    required String vehicle,
    required String driverLicenseNumber,
    required String vehicleLicenseNumber,
    required String vehicleInsuranceNumber,
    required String payoutMethod,
    required String payoutAccount,
    required bool acceptedDriverTerms,
    required bool acceptedPrivacyPolicy,
    required String agreementVersion,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    if (!acceptedDriverTerms || !acceptedPrivacyPolicy) {
      throw StateError('يجب الموافقة على الشروط وسياسة الخصوصية.');
    }

    await _firestore.collection('taxi_driver_applications').doc(user.uid).set({
      'userId': user.uid,
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'nationalId': nationalId.trim(),
      'vehicle': vehicle.trim(),
      'driverLicenseNumber': driverLicenseNumber.trim(),
      'vehicleLicenseNumber': vehicleLicenseNumber.trim(),
      'vehicleInsuranceNumber': vehicleInsuranceNumber.trim(),
      'payoutMethod': payoutMethod.trim(),
      'payoutAccount': payoutAccount.trim(),
      'acceptedDriverTerms': true,
      'acceptedPrivacyPolicy': true,
      'agreementVersion': agreementVersion,
      'agreementAcceptedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
      'identityVerified': false,
      'driverLicenseVerified': false,
      'vehicleDocumentsVerified': false,
      'payoutVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await AdminSubmissionNotificationService.notify(
      type: 'taxi_driver_application',
      documentId: user.uid,
    );
  }
}
