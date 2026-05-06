import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  FollowService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String userId) {
    return _db.collection('users').doc(userId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> followStream({
    required String currentUserId,
    required String targetUserId,
  }) {
    if (currentUserId.isEmpty || targetUserId.isEmpty) {
      return const Stream.empty();
    }
    return _followRef(currentUserId, targetUserId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followersStream(String userId) {
    return _db
        .collection('follows')
        .where('targetId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> followingStream(String userId) {
    return _db
        .collection('follows')
        .where('followerId', isEqualTo: userId)
        .snapshots();
  }

  Future<bool> toggleFollow({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId.isEmpty ||
        targetUserId.isEmpty ||
        currentUserId == targetUserId) {
      return false;
    }

    final followRef = _followRef(currentUserId, targetUserId);
    final followSnap = await followRef.get();
    if (followSnap.exists) {
      await followRef.delete();
      return false;
    }

    final currentUserSnap =
        await _db.collection('users').doc(currentUserId).get();
    final targetUserSnap =
        await _db.collection('users').doc(targetUserId).get();
    final currentUserData = currentUserSnap.data() ?? {};
    final targetUserData = targetUserSnap.data() ?? {};
    final batch = _db.batch();

    batch.set(followRef, {
      'followerId': currentUserId,
      'targetId': targetUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (targetUserData['notificationsEnabled'] != false) {
      final notificationRef = _db.collection('notifications').doc();
      final followerName = _displayName(currentUserData);
      batch.set(notificationRef, {
        'toUserId': targetUserId,
        'fromUserId': currentUserId,
        'fromUserName': followerName,
        'type': 'follow',
        'message': '$followerName started following you.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return true;
  }

  DocumentReference<Map<String, dynamic>> _followRef(
    String currentUserId,
    String targetUserId,
  ) {
    return _db.collection('follows').doc('${currentUserId}_$targetUserId');
  }

  String _displayName(Map<String, dynamic> userData) {
    final username = userData['username'] ?? userData['displayName'];
    if (username is String && username.trim().isNotEmpty) {
      return username.trim();
    }
    final email = userData['email'];
    if (email is String && email.trim().contains('@')) {
      return email.trim().split('@').first;
    }
    return 'Someone';
  }
}
