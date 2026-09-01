import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'admin_submission_notification_service.dart';

class CustomerServiceService {
  static const _supportMessagesEndpoint =
      'https://barakah-secure-api.ebrahimzaghal1.workers.dev/v1/support/messages';

  CustomerServiceService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> get _settings =>
      _firestore.collection('app_settings').doc('customer_service_recruitment');

  Stream<DocumentSnapshot<Map<String, dynamic>>> recruitmentSettings() =>
      _settings.snapshots();

  Future<void> apply({
    required String fullName,
    required String phone,
    required String email,
    required String city,
    required String experience,
    required String availability,
    required String motivation,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');

    final settings = await _settings.get();
    if (settings.data()?['hiringOpen'] != true) {
      throw StateError('التقديم لخدمة العملاء مغلق حالياً.');
    }

    await _firestore
        .collection('customer_service_applications')
        .doc(user.uid)
        .set({
      'userId': user.uid,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'city': city.trim(),
      'experience': experience.trim(),
      'availability': availability,
      'motivation': motivation.trim(),
      'status': 'pending',
      'source': 'barakah_app',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await AdminSubmissionNotificationService.notify(
      type: 'customer_service_application',
      documentId: user.uid,
    );
  }

  Future<DocumentReference<Map<String, dynamic>>> ensureCustomerThread() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');

    final reference = _firestore.collection('support_threads').doc(user.uid);
    final snapshot = await reference.get();
    if (snapshot.exists &&
        (snapshot.data()?['assignedAgentId']?.toString() ?? '').isEmpty) {
      final availableAgents = await _firestore
          .collection('customer_service_presence')
          .where('isAvailable', isEqualTo: true)
          .limit(1)
          .get();
      if (availableAgents.docs.isNotEmpty) {
        final agent = availableAgents.docs.first;
        await reference.update({
          'assignedAgentId': agent.id,
          'assignedAgentName':
              agent.data()['displayName']?.toString() ?? 'موظف بركة',
          'status': 'assigned',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    if (!snapshot.exists) {
      String assignedAgentId = '';
      String assignedAgentName = '';
      final availableAgents = await _firestore
          .collection('customer_service_presence')
          .where('isAvailable', isEqualTo: true)
          .limit(1)
          .get();
      if (availableAgents.docs.isNotEmpty) {
        final agent = availableAgents.docs.first;
        assignedAgentId = agent.id;
        assignedAgentName =
            agent.data()['displayName']?.toString() ?? 'موظف بركة';
      }
      await reference.set({
        'customerId': user.uid,
        'customerName': (user.displayName ?? '').trim().isEmpty
            ? 'عميل بركة'
            : user.displayName!.trim(),
        'customerEmail': user.email ?? '',
        'status': assignedAgentId.isEmpty ? 'open' : 'assigned',
        'assignedAgentId': assignedAgentId,
        'assignedAgentName': assignedAgentName,
        'lastMessage': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return reference;
  }

  Future<void> sendCustomerMessage(String text) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    final message = text.trim();
    if (message.isEmpty) return;
    final thread = await ensureCustomerThread();
    await _postSupportMessage(thread.id, message);
  }

  Future<void> claimThread(String threadId, String displayName) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    final reference = _firestore.collection('support_threads').doc(threadId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final assigned = snapshot.data()?['assignedAgentId']?.toString() ?? '';
      if (assigned.isNotEmpty && assigned != user.uid) {
        throw StateError('هذه المحادثة استلمها موظف آخر.');
      }
      transaction.update(reference, {
        'assignedAgentId': user.uid,
        'assignedAgentName': displayName.trim(),
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setAgentAvailability(String displayName, bool value) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    await _firestore.collection('customer_service_presence').doc(user.uid).set({
      'displayName':
          displayName.trim().isEmpty ? 'موظف بركة' : displayName.trim(),
      'isAvailable': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> acceptEmploymentContract() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    await _firestore.collection('employment_contracts').doc(user.uid).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
      'acceptedBy': user.uid,
    });
  }

  Future<void> sendAgentMessage(String threadId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    if (data['role'] != 'customer_service' ||
        data['customerServiceEnabled'] != true) {
      throw StateError('لا تملك صلاحية موظف خدمة العملاء.');
    }
    final message = text.trim();
    if (message.isEmpty) return;
    await _postSupportMessage(threadId, message);
  }

  Future<void> sendAdminMessage(String threadId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    final profile = await _firestore.collection('users').doc(user.uid).get();
    final data = profile.data() ?? const <String, dynamic>{};
    if (data['role'] != 'admin' && data['isAdmin'] != true) {
      throw StateError('هذه المحادثات متاحة للأدمن فقط.');
    }
    final message = text.trim();
    if (message.isEmpty) return;
    await _postSupportMessage(threadId, message);
  }

  Future<void> _postSupportMessage(String threadId, String message) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('انتهت جلسة الدخول. سجّل الدخول مجددًا.');
    }
    final response = await http
        .post(
          Uri.parse(_supportMessagesEndpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'threadId': threadId,
            'text': message,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String? errorMessage;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) errorMessage = decoded['message']?.toString();
    } catch (_) {}
    throw StateError(errorMessage ?? 'تعذر إرسال الرسالة الآن.');
  }
}
