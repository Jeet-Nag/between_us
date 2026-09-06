import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

enum MomentType {
  missYou,
  hug,
  kiss,
  loveNote,
}

class ReceivedMoment {
  final String id;
  final MomentType type;
  final String senderName;
  final String? message;
  final DateTime timestamp;

  const ReceivedMoment({
    required this.id,
    required this.type,
    required this.senderName,
    this.message,
    required this.timestamp,
  });
}

class MomentsEngine extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _coupleId;
  final String _myUserId;
  final String _myName;
  final String _partnerId;

  ReceivedMoment? _activeReceivedMoment;
  StreamSubscription? _subscription;
  final Map<MomentType, DateTime> _lastSentTimestamps = {};

  MomentsEngine({
    required String coupleId,
    required String myUserId,
    required String myName,
    required String partnerId,
  })  : _coupleId = coupleId,
        _myUserId = myUserId,
        _myName = myName,
        _partnerId = partnerId {
    _listenToFirestoreMoments();
  }

  ReceivedMoment? get activeReceivedMoment => _activeReceivedMoment;

  void _listenToFirestoreMoments() {
    _subscription = _firestore
        .collection('couples')
        .doc(_coupleId)
        .collection('moments')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final doc = snapshot.docs.first;
      final data = doc.data();
      final senderId = data['senderId'] as String?;

      // Only display if incoming from partner and written within last 60 seconds
      if (senderId != _myUserId) {
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final isRecent = DateTime.now().difference(createdAt).inSeconds < 60;

        if (isRecent && (_activeReceivedMoment == null || _activeReceivedMoment!.id != doc.id)) {
          _triggerHapticFeedback();
          _activeReceivedMoment = ReceivedMoment(
            id: doc.id,
            type: MomentType.values.firstWhere(
              (t) => t.name == data['type'],
              orElse: () => MomentType.missYou,
            ),
            senderName: data['senderName'] ?? 'Your Partner',
            message: data['message'],
            timestamp: createdAt,
          );
          notifyListeners();
        }
      }
    });
  }

  void _triggerHapticFeedback() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 250, 100, 350]);
      }
    } catch (e) {
      debugPrint('[Moments] Haptic trigger error: $e');
    }
  }

  /// Sends a moment to Firestore with a 30-second spam prevention cooldown
  Future<bool> sendMoment(MomentType type, {String? customMessage}) async {
    final now = DateTime.now();
    final lastSent = _lastSentTimestamps[type];

    if (lastSent != null && now.difference(lastSent).inSeconds < 30) {
      debugPrint('[Moments] Cooldown active for ${type.name}. Please wait.');
      return false;
    }

    _lastSentTimestamps[type] = now;

    try {
      await _firestore.collection('couples').doc(_coupleId).collection('moments').add({
        'type': type.name,
        'senderId': _myUserId,
        'senderName': _myName,
        'recipientId': _partnerId,
        'message': customMessage,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('[Moments] Error writing moment to Firestore: $e');
      return false;
    }
  }

  void dismissActiveMoment() {
    _activeReceivedMoment = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
