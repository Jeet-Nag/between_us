import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/realtime_client.dart';
import '../domain/message_model.dart';
import '../data/chat_repository.dart';

class ChatState extends ChangeNotifier {
  final RealtimeClient _realtimeClient;
  final ChatRepository _chatRepository;
  final String _myUserId;
  final String _myName;
  final String _coupleId;

  final List<ChatMessage> _messages = [];
  bool _disappearingEnabled = false;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _firestoreSubscription;

  ChatState({
    required RealtimeClient realtimeClient,
    required ChatRepository chatRepository,
    required String myUserId,
    required String myName,
    required String coupleId,
  })  : _realtimeClient = realtimeClient,
        _chatRepository = chatRepository,
        _myUserId = myUserId,
        _myName = myName,
        _coupleId = coupleId {
    _initChat();
    _listenToIncomingMessages();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get disappearingEnabled => _disappearingEnabled;

  void toggleDisappearing() {
    _disappearingEnabled = !_disappearingEnabled;
    notifyListeners();
  }

  Future<void> _initChat() async {
    // 1. Load cached messages for immediate offline viewing
    final cached = await _chatRepository.getCachedMessages(_coupleId);
    if (cached.isNotEmpty && _messages.isEmpty) {
      _messages.addAll(cached);
      notifyListeners();
    }

    // 2. Stream from Firestore
    _firestoreSubscription = _chatRepository.watchMessages(_coupleId).listen((serverMessages) {
      _messages.clear();
      _messages.addAll(serverMessages);
      notifyListeners();
    }, onError: (error) {
      debugPrint('[ChatState] Firestore stream error (offline fallback active): $error');
    });
  }

  void _listenToIncomingMessages() {
    _realtimeSubscription = _realtimeClient.eventStream.listen((event) {
      if (event.senderId == _myUserId) return;

      if (event.type == RealtimeEventType.messageSent) {
        final payload = event.payload;
        final newMsg = ChatMessage(
          id: event.id,
          senderId: event.senderId,
          senderName: payload['senderName'] as String? ?? 'Partner',
          type: MessageType.values.firstWhere(
            (t) => t.name == payload['messageType'],
            orElse: () => MessageType.text,
          ),
          content: payload['content'] as String? ?? '',
          audioDurationMs: payload['audioDurationMs'] as int?,
          createdAt: DateTime.fromMillisecondsSinceEpoch(event.serverTimestampMs),
          isDisappearing: payload['isDisappearing'] as bool? ?? false,
        );

        if (!_messages.any((m) => m.id == newMsg.id)) {
          _messages.add(newMsg);
          notifyListeners();
        }
      } else if (event.type == RealtimeEventType.messageRead) {
        // Handle read receipts
        final msgId = event.payload['messageId'] as String?;
        if (msgId != null) {
          final index = _messages.indexWhere((m) => m.id == msgId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(isRead: true);
            notifyListeners();
          }
        }
      }
    });
  }

  /// Sends a text message
  void sendTextMessage(String text) {
    if (text.trim().isEmpty) return;

    final msgId = const Uuid().v4();
    final message = ChatMessage(
      id: msgId,
      senderId: _myUserId,
      senderName: _myName,
      type: MessageType.text,
      content: text.trim(),
      createdAt: DateTime.now(),
      isDisappearing: _disappearingEnabled,
    );

    _messages.add(message);
    notifyListeners();

    // 1. Broadcast via WebSocket Realtime for instant partner delivery
    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: msgId,
      type: RealtimeEventType.messageSent,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {
        'senderName': _myName,
        'messageType': MessageType.text.name,
        'content': text.trim(),
        'isDisappearing': _disappearingEnabled,
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    // 2. Persist to Firestore
    _chatRepository.sendTextMessage(
      coupleId: _coupleId,
      senderId: _myUserId,
      senderName: _myName,
      content: text.trim(),
      isDisappearing: _disappearingEnabled,
    );
  }

  /// Sends a recorded voice note
  void sendVoiceNote({required int durationMs, String? audioUrl}) {
    final msgId = const Uuid().v4();
    final contentUrl = audioUrl ?? 'voice_note_$msgId';
    final message = ChatMessage(
      id: msgId,
      senderId: _myUserId,
      senderName: _myName,
      type: MessageType.voiceNote,
      content: contentUrl,
      audioDurationMs: durationMs,
      createdAt: DateTime.now(),
      isDisappearing: _disappearingEnabled,
    );

    _messages.add(message);
    notifyListeners();

    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: msgId,
      type: RealtimeEventType.messageSent,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {
        'senderName': _myName,
        'messageType': MessageType.voiceNote.name,
        'content': contentUrl,
        'audioDurationMs': durationMs,
        'isDisappearing': _disappearingEnabled,
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Adds reaction to a message
  void addReaction(String messageId, String emoji) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final msg = _messages[index];
      final newReactions = Map<String, String>.from(msg.reactions);
      newReactions[_myUserId] = emoji;
      _messages[index] = msg.copyWith(reactions: newReactions);
      notifyListeners();

      _chatRepository.addReaction(
        coupleId: _coupleId,
        messageId: messageId,
        userId: _myUserId,
        emoji: emoji,
      );
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
