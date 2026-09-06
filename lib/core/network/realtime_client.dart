import 'dart:async';
import 'package:flutter/foundation.dart';

/// Supported realtime event types between the couple
enum RealtimeEventType {
  locationUpdated,
  moodChanged,
  missYouSent,
  hugSent,
  kissSent,
  loveNoteSent,
  musicPlay,
  musicPause,
  musicSeek,
  musicTrackChanged,
  messageSent,
  messageRead,
  presenceChanged,
  countdownUpdated,
  memoryAdded,
}

class RealtimeEvent {
  final String id;
  final RealtimeEventType type;
  final String senderId;
  final String coupleId;
  final Map<String, dynamic> payload;
  final int serverTimestampMs;
  final int revision;

  const RealtimeEvent({
    required this.id,
    required this.type,
    required this.senderId,
    required this.coupleId,
    required this.payload,
    required this.serverTimestampMs,
    this.revision = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'senderId': senderId,
      'coupleId': coupleId,
      'payload': payload,
      'serverTimestampMs': serverTimestampMs,
      'revision': revision,
    };
  }

  factory RealtimeEvent.fromMap(Map<String, dynamic> map) {
    return RealtimeEvent(
      id: map['id'] as String,
      type: RealtimeEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RealtimeEventType.presenceChanged,
      ),
      senderId: map['senderId'] as String,
      coupleId: map['coupleId'] as String,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      serverTimestampMs: map['serverTimestampMs'] as int,
      revision: map['revision'] as int? ?? 1,
    );
  }
}

/// Abstract Realtime Sync Client supporting Firestore, WebSockets, or local Mock Relay
abstract class RealtimeClient {
  Stream<RealtimeEvent> get eventStream;
  bool get isConnected;
  
  Future<void> connect({required String coupleId, required String userId});
  Future<void> disconnect();
  Future<void> broadcastEvent(RealtimeEvent event);
}

/// In-Memory / Local Stream Realtime Relay for instant peer-to-peer & cross-instance communication
class LocalBroadcastRealtimeClient implements RealtimeClient {
  static final LocalBroadcastRealtimeClient _instance = LocalBroadcastRealtimeClient._internal();
  factory LocalBroadcastRealtimeClient() => _instance;
  LocalBroadcastRealtimeClient._internal();

  final _controller = StreamController<RealtimeEvent>.broadcast();
  bool _connected = false;
  String? _coupleId;
  String? _userId;

  String? get currentCoupleId => _coupleId;
  String? get currentUserId => _userId;

  @override
  Stream<RealtimeEvent> get eventStream => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect({required String coupleId, required String userId}) async {
    _coupleId = coupleId;
    _userId = userId;
    _connected = true;
    debugPrint('[RealtimeClient] Connected to couple space: $coupleId for user: $userId');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _coupleId = null;
    _userId = null;
    debugPrint('[RealtimeClient] Disconnected');
  }

  @override
  Future<void> broadcastEvent(RealtimeEvent event) async {
    if (!_connected) {
      debugPrint('[RealtimeClient] Warning: broadcasting while offline, caching event ${event.id}');
    }
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }
}
