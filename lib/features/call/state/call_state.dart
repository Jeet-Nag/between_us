import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/realtime_client.dart';

enum CallStatus {
  idle,
  outgoingRinging,
  incomingRinging,
  connected,
  ended,
}

class CallState extends ChangeNotifier {
  final RealtimeClient _realtimeClient;
  final String _coupleId;
  final String _myUserId;
  final String _myName;
  final String _partnerName;

  CallStatus _status = CallStatus.idle;
  String? _activeCallId;
  String _callContext = '❤️ Just See You';
  bool _isVideo = true;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  StreamSubscription? _realtimeSubscription;

  CallState({
    required RealtimeClient realtimeClient,
    required String coupleId,
    required String myUserId,
    required String myName,
    required String partnerName,
  })  : _realtimeClient = realtimeClient,
        _coupleId = coupleId,
        _myUserId = myUserId,
        _myName = myName,
        _partnerName = partnerName {
    _listenToSignalingEvents();
  }

  CallStatus get status => _status;
  bool get isInCall => _status != CallStatus.idle && _status != CallStatus.ended;
  bool get isConnected => _status == CallStatus.connected;
  bool get isOutgoing => _status == CallStatus.outgoingRinging;
  bool get isIncoming => _status == CallStatus.incomingRinging;
  String get callContext => _callContext;
  bool get isVideo => _isVideo;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isFrontCamera => _isFrontCamera;
  int get callDurationSeconds => _callDurationSeconds;
  String get partnerName => _partnerName;

  void _listenToSignalingEvents() {
    _realtimeSubscription = _realtimeClient.eventStream.listen((event) {
      if (event.senderId == _myUserId) return;

      if (event.type == RealtimeEventType.callOffer) {
        if (_status == CallStatus.idle) {
          _activeCallId = event.payload['callId'] as String? ?? const Uuid().v4();
          _callContext = event.payload['context'] as String? ?? '❤️ Just See You';
          _isVideo = event.payload['isVideo'] as bool? ?? true;
          _status = CallStatus.incomingRinging;
          notifyListeners();
        }
      } else if (event.type == RealtimeEventType.callAnswer) {
        if (_status == CallStatus.outgoingRinging) {
          _status = CallStatus.connected;
          _startDurationTimer();
          notifyListeners();
        }
      } else if (event.type == RealtimeEventType.callEnd) {
        if (_status != CallStatus.idle) {
          _cleanupCallState();
          _status = CallStatus.ended;
          notifyListeners();
          Future.delayed(const Duration(milliseconds: 1500), () {
            _status = CallStatus.idle;
            notifyListeners();
          });
        }
      }
    });
  }

  /// Initiates an outgoing call to the partner
  void startCall({required String mode, bool isVideo = true}) {
    _activeCallId = const Uuid().v4();
    _callContext = mode;
    _isVideo = isVideo;
    _status = CallStatus.outgoingRinging;
    _callDurationSeconds = 0;
    notifyListeners();

    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: const Uuid().v4(),
      type: RealtimeEventType.callOffer,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {
        'callId': _activeCallId,
        'callerName': _myName,
        'context': mode,
        'isVideo': isVideo,
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    // Auto-timeout after 45 seconds if no answer
    Future.delayed(const Duration(seconds: 45), () {
      if (_status == CallStatus.outgoingRinging) {
        endCall();
      }
    });
  }

  /// Answers an incoming call
  void acceptCall() {
    if (_status != CallStatus.incomingRinging) return;
    _status = CallStatus.connected;
    _startDurationTimer();
    notifyListeners();

    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: const Uuid().v4(),
      type: RealtimeEventType.callAnswer,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {
        'callId': _activeCallId,
        'status': 'accepted',
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Declines an incoming call
  void declineCall() {
    endCall();
  }

  /// Terminates or cancels the active call
  void endCall() {
    if (_status == CallStatus.idle) return;

    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: const Uuid().v4(),
      type: RealtimeEventType.callEnd,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {
        'callId': _activeCallId,
        'durationSeconds': _callDurationSeconds,
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    _cleanupCallState();
    _status = CallStatus.ended;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 1500), () {
      _status = CallStatus.idle;
      notifyListeners();
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
  }

  void _cleanupCallState() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _activeCallId = null;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void toggleVideo() {
    _isVideoOff = !_isVideoOff;
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    notifyListeners();
  }

  void flipCamera() {
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }
}
