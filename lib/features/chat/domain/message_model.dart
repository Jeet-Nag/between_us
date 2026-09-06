enum MessageType {
  text,
  photo,
  video,
  voiceNote,
  moment,
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final int? audioDurationMs;
  final DateTime createdAt;
  final bool isRead;
  final bool isDisappearing;
  final DateTime? expiresAt;
  final Map<String, String> reactions;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    this.audioDurationMs,
    required this.createdAt,
    this.isRead = true,
    this.isDisappearing = false,
    this.expiresAt,
    this.reactions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'audioDurationMs': audioDurationMs,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'isDisappearing': isDisappearing,
      'expiresAt': expiresAt?.toIso8601String(),
      'reactions': reactions,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, {String? docId}) {
    return ChatMessage(
      id: docId ?? map['id'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Partner',
      type: MessageType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MessageType.text,
      ),
      content: map['content'] as String? ?? '',
      audioDurationMs: map['audioDurationMs'] as int?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: map['isRead'] as bool? ?? true,
      isDisappearing: map['isDisappearing'] as bool? ?? false,
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
      reactions: map['reactions'] != null
          ? Map<String, String>.from(map['reactions'] as Map)
          : const {},
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    MessageType? type,
    String? content,
    int? audioDurationMs,
    DateTime? createdAt,
    bool? isRead,
    bool? isDisappearing,
    DateTime? expiresAt,
    Map<String, String>? reactions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      content: content ?? this.content,
      audioDurationMs: audioDurationMs ?? this.audioDurationMs,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isDisappearing: isDisappearing ?? this.isDisappearing,
      expiresAt: expiresAt ?? this.expiresAt,
      reactions: reactions ?? this.reactions,
    );
  }
}
