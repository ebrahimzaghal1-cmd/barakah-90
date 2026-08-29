import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'order_service.dart';

class DriverService {
  static const _apiBase =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  DriverService({
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

    await _firestore.collection('driver_applications').doc(user.uid).set({
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
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myOrders() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: uid)
        .snapshots();
  }

  Future<void> setAvailable(bool available) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    Position? position;

    if (available) {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('يجب السماح بالموقع لاختيار أقرب سائق.');
      }

      position = await Geolocator.getCurrentPosition();
    }

    await _firestore.collection('users').doc(user.uid).update({
      'driverAvailable': available,
      'driverBusy': !available,
      if (position != null) 'driverLatitude': position.latitude,
      if (position != null) 'driverLongitude': position.longitude,
      'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('سجّل الدخول أولًا.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت جلسة الدخول. سجّل الدخول مجددًا.');
    }

    final uri = Uri.parse('$_apiBase$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=utf-8',
    };

    late final http.Response response;

    if (method == 'GET') {
      response = await http.get(uri, headers: headers);
    } else {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body ?? const <String, dynamic>{}),
      );
    }

    Map<String, dynamic> data = const <String, dynamic>{};

    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    }

    print('===== DRIVER API DEBUG =====');
    print('method: $method');
    print('path: $path');
    print('status: ${response.statusCode}');
    print('body: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        data['message']?.toString() ?? 'تعذر تنفيذ العملية الآن.',
      );
    }

    return data;
  }

  Future<List<Map<String, dynamic>>> availableOrders() async {
    final data = await _request(
      'GET',
      '/v1/driver/orders/available',
    );

    final raw = data['orders'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> claimOrder(String orderId) async {
    await _request(
      'POST',
      '/v1/orders/${Uri.encodeComponent(orderId)}/claim-driver',
    );
  }

  Future<void> updateDeliveryStatus(
    String orderId,
    String status,
  ) async {
    await OrderService(
      firestore: _firestore,
      auth: _auth,
    ).updateStatus(orderId, status);

    if (status == 'delivered') {
      final user = _auth.currentUser;

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'driverAvailable': true,
          'driverBusy': false,
          'activeOrderId': FieldValue.delete(),
          'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
