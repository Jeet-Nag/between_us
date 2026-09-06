import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:between_us/core/security/encryption_service.dart';
import 'package:between_us/core/network/realtime_client.dart';
import '../../couple_pairing/data/couple_repository.dart';
import '../domain/couple_model.dart';

class CoupleState extends ChangeNotifier {
  final RealtimeClient _realtimeClient;
  final CoupleRepository? _coupleRepository;
  
  CoupleModel? _couple;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription? _coupleSubscription;
  StreamSubscription? _realtimeSubscription;

  CoupleState({
    required RealtimeClient realtimeClient,
    CoupleRepository? coupleRepository,
  })  : _realtimeClient = realtimeClient,
        _coupleRepository = coupleRepository;

  CoupleModel? get couple => _couple;
  bool get isLoading => _isLoading;
  bool get isConnected => _couple?.status == CoupleStatus.connected;
  String? get errorMessage => _errorMessage;

  /// Automatically attaches to an existing couple space for a signed-in user
  Future<void> initForUser({
    required String myUserId,
    required String myDisplayName,
    String? coupleId,
  }) async {
    if (coupleId != null && coupleId.isNotEmpty && _coupleRepository != null) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _coupleSubscription?.cancel();
      _coupleSubscription = _coupleRepository!.watchCouple(coupleId, myUserId).listen((model) {
        if (model != null) {
          _couple = model;
          notifyListeners();
        }
      }, onError: (e) {
        debugPrint('[CoupleState] Error watching couple space: $e');
        _errorMessage = 'Unable to sync couple space: $e';
        notifyListeners();
      });

      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new Couple Space and generates a 6-character pairing code
  Future<void> createSpace({
    required String myName,
    String? myUserId,
  }) async {
    // If we already have an active space with a valid pairing code, do not re-create
    if (_couple != null && _couple!.pairingCode.isNotEmpty && _couple!.status == CoupleStatus.waitingForPartner && !_isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final uid = myUserId ?? const Uuid().v4();
    final localPairingCode = EncryptionService.generatePairingCode();
    final localCoupleId = 'couple_${const Uuid().v4().substring(0, 8)}';

    final localUser = UserProfile(
      id: uid,
      displayName: myName,
      initials: myName.isNotEmpty ? myName.substring(0, 1).toUpperCase() : 'U',
    );

    // Populate local model immediately so user sees invitation code without blocking on network
    _couple = CoupleModel(
      id: localCoupleId,
      pairingCode: localPairingCode,
      status: CoupleStatus.waitingForPartner,
      user: localUser,
      createdAt: DateTime.now(),
    );
    notifyListeners();

    try {
      if (_coupleRepository != null) {
        final created = await _coupleRepository!.createCoupleSpace(
          myUserId: uid,
          myDisplayName: myName,
        ).timeout(const Duration(seconds: 10));

        _couple = created;
        _subscribeToCouple(created.id, uid);
      }

      await _realtimeClient.connect(coupleId: _couple!.id, userId: uid);
      _listenToRealtimeEvents(uid);
    } on TimeoutException {
      debugPrint('[CoupleState] Cloud space creation timed out; retaining local pairing code.');
    } catch (e) {
      debugPrint('[CoupleState] Create space error: $e');
      _errorMessage = 'Notice: Invitation code active locally, syncing to cloud: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Joins an existing space with a verified 6-character code
  Future<bool> joinSpace({
    required String myName,
    required String code,
    String? myUserId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.length != 6) {
      _errorMessage = 'Please enter a valid 6-character code.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final uid = myUserId ?? const Uuid().v4();

    try {
      if (_coupleRepository != null) {
        final joined = await _coupleRepository!.joinCoupleSpace(
          myUserId: uid,
          myDisplayName: myName,
          pairingCode: normalizedCode,
        );

        if (joined == null) {
          _errorMessage = 'Code "$normalizedCode" not found or already paired. Please verify with your partner.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        _couple = joined;
        _subscribeToCouple(joined.id, uid);
      } else {
        // In-memory test environment fallback
        final coupleId = 'couple_shared_$normalizedCode';
        final user = UserProfile(
          id: uid,
          displayName: myName,
          initials: myName.isNotEmpty ? myName.substring(0, 1).toUpperCase() : 'U',
        );
        _couple = CoupleModel(
          id: coupleId,
          pairingCode: normalizedCode,
          status: CoupleStatus.connected,
          user: user,
          partner: const UserProfile(id: 'partner_test', displayName: 'Partner', initials: 'P'),
          createdAt: DateTime.now(),
        );
      }

      await _realtimeClient.connect(coupleId: _couple!.id, userId: uid);
      _listenToRealtimeEvents(uid);

      // Broadcast join event over WebSocket to immediately notify creator
      _realtimeClient.broadcastEvent(RealtimeEvent(
        id: const Uuid().v4(),
        type: RealtimeEventType.presenceChanged,
        senderId: uid,
        coupleId: _couple!.id,
        payload: {'action': 'partner_joined', 'displayName': myName},
        serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
      ));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[CoupleState] Join space error: $e');
      _errorMessage = 'Connection error while joining space: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _subscribeToCouple(String coupleId, String myUserId) {
    _coupleSubscription?.cancel();
    _coupleSubscription = _coupleRepository?.watchCouple(coupleId, myUserId).listen((updated) {
      if (updated != null) {
        _couple = updated;
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('[CoupleState] Couple watch error: $e');
    });
  }

  void _listenToRealtimeEvents(String myUserId) {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _realtimeClient.eventStream.listen((event) {
      if (event.senderId == myUserId) return;

      if (event.type == RealtimeEventType.presenceChanged &&
          event.payload['action'] == 'partner_joined') {
        final partnerName = event.payload['displayName'] as String? ?? 'Partner';
        final partnerInitials = partnerName.isNotEmpty ? partnerName.substring(0, 1).toUpperCase() : 'P';
        
        if (_couple != null) {
          _couple = _couple!.copyWith(
            status: CoupleStatus.connected,
            partner: UserProfile(
              id: event.senderId,
              displayName: partnerName,
              initials: partnerInitials,
            ),
          );
          notifyListeners();
        }

        if (_couple != null && _coupleRepository != null) {
          _subscribeToCouple(_couple!.id, myUserId);
        }
      }
    });
  }

  /// Updates relationship countdown meeting
  void updateMeetingCountdown({required DateTime date, required String title}) {
    if (_couple == null) return;
    _couple = _couple!.copyWith(
      nextMeetingDate: date,
      nextMeetingTitle: title,
    );
    notifyListeners();

    _coupleRepository?.updateCountdown(
      coupleId: _couple!.id,
      targetDate: date,
      title: title,
    );

    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: const Uuid().v4(),
      type: RealtimeEventType.countdownUpdated,
      senderId: _couple!.user.id,
      coupleId: _couple!.id,
      payload: {
        'date': date.toIso8601String(),
        'title': title,
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Unpairs the couple space and securely resets
  Future<void> unpairSpace() async {
    if (_couple != null && _coupleRepository != null) {
      await _coupleRepository!.unpairSpace(_couple!.id);
    }
    await _realtimeClient.disconnect();
    _coupleSubscription?.cancel();
    _realtimeSubscription?.cancel();
    _couple = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _coupleSubscription?.cancel();
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
