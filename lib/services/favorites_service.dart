import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritesService {
  FavoritesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> _favorites(String userId) =>
      _firestore.collection('users').doc(userId).collection('favorites');

  Stream<bool> watchIsFavorite(String userId, String itemId) =>
      _favorites(userId)
          .doc(itemId)
          .snapshots()
          .map((snapshot) => snapshot.exists);

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFavorites(String userId) =>
      _favorites(userId).orderBy('createdAt', descending: true).snapshots();

  Future<bool> toggle({
    required String userId,
    required String itemId,
    required Map<String, dynamic> item,
  }) async {
    final reference = _favorites(userId).doc(itemId);
    final snapshot = await reference.get();
    if (snapshot.exists) {
      await reference.delete();
      return false;
    }

    final kind = item['kind']?.toString() == 'product' ? 'product' : 'business';
    await reference.set({
      'userId': userId,
      'itemId': itemId,
      'kind': kind,
      'title': item['title']?.toString() ?? '',
      'image': item['image']?.toString() ?? '',
      'category': item['category']?.toString() ?? '',
      'price': item['price'] is num ? item['price'] : null,
      'businessId': item['businessId']?.toString() ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  Future<void> remove({required String userId, required String itemId}) =>
      _favorites(userId).doc(itemId).delete();
}
