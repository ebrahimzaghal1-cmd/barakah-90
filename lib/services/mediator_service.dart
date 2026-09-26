import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class MediatorService {
  Future<Map<String, dynamic>> call(
      String action, Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولًا');
    final token = await user.getIdToken();
    final response = await http
        .post(
          Uri.parse(
              'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/mediator/action'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'action': action, ...data}),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw StateError(body['message']?.toString() ?? 'تعذر تنفيذ العملية');
    }
    if (response.statusCode != 200) throw StateError('تعذر الاتصال بالخادم');
    return Map<String, dynamic>.from(body);
  }
}
