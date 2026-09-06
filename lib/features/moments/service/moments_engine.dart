import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import '../../../core/network/realtime_client.dart';

enum MomentType {
  missYou,
  hug,
  kiss,
  loveNote,
  holdHands,
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
  final RealtimeClient? _realtimeClient;
  final String _coupleId;
  final String _myUserId;
  final String _myName;
  final String _partnerId;

  ReceivedMoment? _activeReceivedMoment;
  StreamSubscription? _subscription;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _presenceSubscription;

  final Map<MomentType, DateTime> _lastSentTimestamps = {};

  // Hold Hands State
  bool _isHoldingHandsLocal = false;
  bool _isHoldingHandsPartner = false;
  int _holdingDurationSeconds = 0;
  Timer? _holdingDurationTimer;
  Timer? _heartbeatHapticTimer;

  MomentsEngine({
    required String coupleId,
    required String myUserId,
    required String myName,
    required String partnerId,
    RealtimeClient? realtimeClient,
  })  : _coupleId = coupleId,
        _myUserId = myUserId,
        _myName = myName,
        _partnerId = partnerId,
        _realtimeClient = realtimeClient {
    _listenToFirestoreMoments();
    _listenToRealtimeEvents();
    _listenToPartnerHoldPresence();
  }

  ReceivedMoment? get activeReceivedMoment => _activeReceivedMoment;
  bool get isHoldingHandsLocal => _isHoldingHandsLocal;
  bool get isHoldingHandsPartner => _isHoldingHandsPartner;
  bool get bothHoldingHands => _isHoldingHandsLocal && _isHoldingHandsPartner;
  int get holdingDurationSeconds => _holdingDurationSeconds;

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

  void _listenToRealtimeEvents() {
    if (_realtimeClient == null) return;
    _realtimeSubscription = _realtimeClient!.eventStream.listen((event) {
      if (event.senderId == _myUserId) return;

      if (event.type == RealtimeEventType.holdHandsStart) {
        _isHoldingHandsPartner = true;
        _checkHoldingState();
        notifyListeners();
      } else if (event.type == RealtimeEventType.holdHandsStop) {
        _isHoldingHandsPartner = false;
        _checkHoldingState();
        notifyListeners();
      }
    });
  }

  void _listenToPartnerHoldPresence() {
    if (_partnerId.isEmpty || _coupleId.isEmpty) return;
    _presenceSubscription = _firestore
        .collection('couples')
        .doc(_coupleId)
        .collection('presence')
        .doc(_partnerId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final isHolding = data['isHoldingHands'] as bool? ?? false;
      if (_isHoldingHandsPartner != isHolding) {
        _isHoldingHandsPartner = isHolding;
        _checkHoldingState();
        notifyListeners();
      }
    });
  }

  /// User touches and holds hand
  void startHoldingHands() {
    if (_isHoldingHandsLocal) return;
    _isHoldingHandsLocal = true;
    _triggerSingleHaptic();
    notifyListeners();

    // Broadcast over WebSocket
    _realtimeClient?.broadcastEvent(RealtimeEvent(
      id: const Uuid().v4(),
      type: RealtimeEventType.holdHandsStart,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {'holding': true},
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    // Update presence doc
    _firestore.collection('couples').doc(_coupleId).collection('presence').doc(_myUserId).set({
      'isHoldingHands': true,
      'lastHoldingAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});

    _checkHoldingState();
  }

  /// User releases hand
  void stopHoldingHands() {
    if (!_isHoldingHandsLocal) return;

    final durationHeld = _holdingDurationSeconds;
    _isHoldingHandsLocal = false;
    _checkHoldingState();
    notifyListeners();

    // Broadcast over WebSocket
    _realtimeClient?.broadcastEvent(RealtimeEvent(
      id: const Uuid().v4(),
      type: RealtimeEventType.holdHandsStop,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {'holding': false, 'durationSeconds': durationHeld},
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    // Update presence doc
    _firestore.collection('couples').doc(_coupleId).collection('presence').doc(_myUserId).set({
      'isHoldingHands': false,
    }, SetOptions(merge: true)).catchError((_) {});

    // If held together for >= 3 seconds, record memorable moment to Firestore
    if (durationHeld >= 3) {
      try {
        _firestore.collection('couples').doc(_coupleId).collection('moments').add({
          'type': MomentType.holdHands.name,
          'senderId': _myUserId,
          'senderName': _myName,
          'recipientId': _partnerId,
          'message': 'Held hands together for $durationHeld seconds 🫶',
          'durationSeconds': durationHeld,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    _holdingDurationSeconds = 0;
  }

  void _checkHoldingState() {
    if (bothHoldingHands) {
      // Start duration timer and synchronized heartbeat haptics
      _holdingDurationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _holdingDurationSeconds++;
        notifyListeners();
      });

      _startHeartbeatHaptics();
    } else {
      _holdingDurationTimer?.cancel();
      _holdingDurationTimer = null;
      _stopHeartbeatHaptics();
    }
  }

  void _startHeartbeatHaptics() {
    _heartbeatHapticTimer?.cancel();
    _heartbeatHapticTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (bothHoldingHands) {
        _triggerHeartbeatHaptic();
      }
    });
    _triggerHeartbeatHaptic();
  }

  void _stopHeartbeatHaptics() {
    _heartbeatHapticTimer?.cancel();
    _heartbeatHapticTimer = null;
  }

  void _triggerSingleHaptic() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 60, amplitude: 128);
      }
    } catch (_) {}
  }

  void _triggerHeartbeatHaptic() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Double-beat heartbeat cadence (lub-dub)
        Vibration.vibrate(pattern: [0, 70, 100, 90]);
      }
    } catch (_) {}
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
    _realtimeSubscription?.cancel();
    _presenceSubscription?.cancel();
    _holdingDurationTimer?.cancel();
    _heartbeatHapticTimer?.cancel();
    super.dispose();
  }
}
