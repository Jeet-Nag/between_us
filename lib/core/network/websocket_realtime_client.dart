import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'realtime_client.dart';
import '../storage/local_storage_service.dart';

/// Low-latency best-effort WebSocket Realtime Client for between-us backend.
/// Connects to Render WebSocket server with zero Blaze costs, auto-reconnect,
/// heartbeat keep-alive, offline message queueing, and persistent revision reconciliation.
class WebSocketRealtimeClient implements RealtimeClient {
  static final WebSocketRealtimeClient _instance = WebSocketRealtimeClient._internal();
  factory WebSocketRealtimeClient() => _instance;
  WebSocketRealtimeClient._internal();

  final _eventController = StreamController<RealtimeEvent>.broadcast();
  final _statusController = StreamController<bool>.broadcast();
  final LocalStorageService _storage = LocalStorageService();

  WebSocket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manuallyClosed = false;

  String? _coupleId;
  String? _userId;
  String? _token;
  String _serverUrl = _resolveServerUrl();

  static const String defaultHttpBackendUrl = 'https://between-us-backend-xnur.onrender.com';
  static const String defaultWsBackendUrl = 'wss://between-us-backend-xnur.onrender.com';

  static String resolveHttpBackendUrl() {
    const httpUrl = String.fromEnvironment('BACKEND_URL');
    if (httpUrl.isNotEmpty) return httpUrl;

    const wsUrl = String.fromEnvironment('BACKEND_WS_URL');
    if (wsUrl.isNotEmpty) {
      if (wsUrl.startsWith('wss://')) {
        return wsUrl.replaceFirst('wss://', 'https://');
      } else if (wsUrl.startsWith('ws://')) {
        return wsUrl.replaceFirst('ws://', 'http://');
      }
      return wsUrl;
    }

    return defaultHttpBackendUrl;
  }

  static String _resolveServerUrl() {
    const wsUrl = String.fromEnvironment('BACKEND_WS_URL');
    if (wsUrl.isNotEmpty) return wsUrl;

    const httpUrl = String.fromEnvironment('BACKEND_URL');
    if (httpUrl.isNotEmpty) {
      if (httpUrl.startsWith('https://')) {
        return httpUrl.replaceFirst('https://', 'wss://');
      } else if (httpUrl.startsWith('http://')) {
        return httpUrl.replaceFirst('http://', 'ws://');
      }
      return httpUrl;
    }

    return defaultWsBackendUrl;
  }

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  int _lastKnownRevision = 0;

  @override
  Stream<RealtimeEvent> get eventStream => _eventController.stream;
  Stream<bool> get connectionStatusStream => _statusController.stream;

  @override
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String get serverUrl => _serverUrl;

  String? get coupleId => _coupleId;
  String? get userId => _userId;

  void setServerUrl(String url) {
    _serverUrl = url;
  }

  @override
  Future<void> connect({
    required String coupleId,
    required String userId,
    String? token,
  }) async {
    _coupleId = coupleId;
    _userId = userId;
    _token = token ?? 'local_spark_token_$userId';
    _manuallyClosed = false;
    _reconnectAttempts = 0;
    _lastKnownRevision = await _storage.getLastRevision();

    await _initSocket();
  }

  Future<void> _initSocket() async {
    if (_isConnecting || _isConnected) return;
    _isConnecting = true;

    try {
      debugPrint('[WebSocketClient] Connecting to $_serverUrl...');
      final uri = Uri.parse(_serverUrl);
      _socket = await WebSocket.connect(uri.toString()).timeout(
        const Duration(seconds: 10),
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _statusController.add(true);
      debugPrint('[WebSocketClient] Connected successfully.');

      _startListening();
      _startHeartbeat();
      _authenticate();
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _statusController.add(false);
      debugPrint('[WebSocketClient] Connection failed: $e. Scheduling retry...');
      _scheduleReconnect();
    }
  }

  void _startListening() {
    _socket?.listen(
      (dynamic data) {
        _handleIncomingMessage(data);
      },
      onDone: () {
        debugPrint('[WebSocketClient] Socket closed.');
        _handleDisconnect();
      },
      onError: (error) {
        debugPrint('[WebSocketClient] Socket error: $error');
        _handleDisconnect();
      },
      cancelOnError: true,
    );
  }

  void _handleIncomingMessage(dynamic data) {
    try {
      final Map<String, dynamic> json = jsonDecode(data as String);
      final type = json['type'] as String?;

      switch (type) {
        case 'AUTHENTICATED':
          debugPrint('[WebSocketClient] Authenticated on server. Requesting sync from revision $_lastKnownRevision');
          _sendSyncRequest();
          _flushPendingQueue();
          break;

        case 'HEARTBEAT':
        case 'ACK':
          // Keep-alive acknowledgement
          break;

        case 'SYNC_RESPONSE':
          final missed = json['missedEvents'] as List<dynamic>? ?? [];
          final latestRev = json['latestRevision'] as int? ?? _lastKnownRevision;
          _lastKnownRevision = latestRev;
          _storage.saveLastRevision(latestRev);

          for (final rawEvent in missed) {
            _dispatchEvent(rawEvent as Map<String, dynamic>);
          }
          break;

        case 'ERROR':
          debugPrint('[WebSocketClient] Server error: ${json['message']}');
          break;

        default:
          // Incoming event broadcast
          final revision = json['revision'] as int?;
          if (revision != null && revision > _lastKnownRevision) {
            _lastKnownRevision = revision;
            _storage.saveLastRevision(revision);
          }
          _dispatchEvent(json);

          // Send ACK back
          final eventId = json['id'] as String?;
          if (eventId != null) {
            _sendRaw({'type': 'ACK', 'eventId': eventId});
          }
          break;
      }
    } catch (e) {
      debugPrint('[WebSocketClient] Error parsing incoming message: $e');
    }
  }

  void _dispatchEvent(Map<String, dynamic> rawEvent) {
    try {
      final event = RealtimeEvent.fromMap(rawEvent);
      _eventController.add(event);
    } catch (e) {
      debugPrint('[WebSocketClient] Failed to convert event: $e');
    }
  }

  void _authenticate() {
    _sendRaw({
      'type': 'AUTHENTICATE',
      'token': _token,
      'coupleId': _coupleId,
      'userId': _userId,
    });
  }

  void _sendSyncRequest() {
    _sendRaw({
      'type': 'SYNC_REQUEST',
      'coupleId': _coupleId,
      'lastKnownRevision': _lastKnownRevision,
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected) {
        _sendRaw({'type': 'HEARTBEAT', 'timestamp': DateTime.now().millisecondsSinceEpoch});
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _statusController.add(false);
    _heartbeatTimer?.cancel();
    _socket?.close();
    _socket = null;

    if (!_manuallyClosed) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_manuallyClosed) return;

    _reconnectAttempts++;
    final backoffSec = math.min(15, math.pow(2, _reconnectAttempts).toInt());
    debugPrint('[WebSocketClient] Reconnecting in ${backoffSec}s (attempt #$_reconnectAttempts)...');

    _reconnectTimer = Timer(Duration(seconds: backoffSec), () {
      if (!_manuallyClosed && !_isConnected) {
        _initSocket();
      }
    });
  }

  @override
  Future<void> broadcastEvent(RealtimeEvent event) async {
    final map = event.toMap();

    // Always dispatch to local stream so sender UI is instantly updated
    _eventController.add(event);

    if (_isConnected) {
      _sendRaw(map);
    } else {
      // Store in local ring buffer for auto-flush on reconnect
      await _storage.queuePendingEvent(map);
    }
  }

  Future<void> _flushPendingQueue() async {
    final pending = await _storage.getPendingEvents();
    if (pending.isEmpty) return;

    debugPrint('[WebSocketClient] Flushing ${pending.length} pending offline events...');
    for (final eventMap in pending) {
      _sendRaw(eventMap);
    }
    await _storage.clearPendingEvents();
  }

  void _sendRaw(Map<String, dynamic> data) {
    try {
      if (_socket != null && _isConnected) {
        _socket!.add(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('[WebSocketClient] Send error: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _isConnected = false;
    _statusController.add(false);
    await _socket?.close();
    _socket = null;
    _coupleId = null;
    _userId = null;
    debugPrint('[WebSocketClient] Disconnected cleanly.');
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _statusController.close();
  }
}
