import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomerServiceService {
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
    final batch = _firestore.batch();
    batch.set(thread.collection('messages').doc(), {
      'senderId': user.uid,
      'senderRole': 'customer',
      'senderName': user.displayName ?? 'عميل بركة',
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(thread, {
      'lastMessage': message,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
    await batch.commit();
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
    final thread = _firestore.collection('support_threads').doc(threadId);
    final batch = _firestore.batch();
    batch.set(thread.collection('messages').doc(), {
      'senderId': user.uid,
      'senderRole': 'customer_service',
      'senderName': data['displayName']?.toString() ?? 'خدمة عملاء بركة',
      'text': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(thread, {
      'lastMessage': message,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
    await batch.commit();
  }
}
