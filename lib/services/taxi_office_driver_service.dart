import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class TaxiOfficeDriverRecord {
  const TaxiOfficeDriverRecord({
    required this.id,
    required Map<String, dynamic> data,
  }) : _data = data;

  final String id;
  final Map<String, dynamic> _data;

  Map<String, dynamic> data() => Map<String, dynamic>.from(_data);
}

class TaxiOfficeDriverService {
  TaxiOfficeDriverService._();

  static final TaxiOfficeDriverService instance = TaxiOfficeDriverService._();

  static const String _baseUrl =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev';

  Future<List<TaxiOfficeDriverRecord>> listDrivers({
    required String businessId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'يجب تسجيل الدخول أولًا.',
      );
    }

    final id = businessId.trim();

    if (id.isEmpty) {
      throw ArgumentError(
        'رقم مكتب التكسي مطلوب.',
      );
    }

    final token = await user.getIdToken();

    final response = await http.post(
      Uri.parse(
        '$_baseUrl/v1/taxi/drivers/list',
      ),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        <String, dynamic>{
          'businessId': id,
        },
      ),
    );

    dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? (decoded['message'] ?? decoded['error'] ?? '').toString()
          : '';

      throw Exception(
        message.isEmpty ? 'تعذر تحميل سائقي مكتب التكسي.' : message,
      );
    }

    if (decoded is! Map) {
      return const [];
    }

    final rawDrivers = decoded['drivers'];

    if (rawDrivers is! List) {
      return const [];
    }

    final result = <TaxiOfficeDriverRecord>[];

    for (final raw in rawDrivers) {
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);

      final uid = (map['uid'] ?? '').toString().trim();

      if (uid.isEmpty) continue;

      result.add(
        TaxiOfficeDriverRecord(
          id: uid,
          data: <String, dynamic>{
            'displayName': map['name'],
            'name': map['name'],
            'vehicleInfo': map['vehicle'],
            'vehicle': map['vehicle'],
            'plateNumber': map['plateNumber'],
            'vehicleColor': map['vehicleColor'],
          },
        ),
      );
    }

    return result;
  }
}
