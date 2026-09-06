import 'package:flutter_test/flutter_test.dart';
import 'package:between_us/features/chat/domain/message_model.dart';
import 'package:between_us/features/memories/domain/memory_model.dart';
import 'package:between_us/features/home/state/presence_state.dart';

void main() {
  group('Domain Models & Local Cache Data Integrity Tests', () {
    test('ChatMessage model roundtrip serialization and reaction updates', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg_987',
        senderId: 'user_a',
        senderName: 'Jeet',
        type: MessageType.text,
        content: 'Thinking about you always ❤️',
        createdAt: now,
        isDisappearing: false,
        reactions: {'user_b': '❤️'},
      );

      final map = msg.toMap();
      expect(map['id'], 'msg_987');
      expect(map['senderId'], 'user_a');
      expect(map['content'], 'Thinking about you always ❤️');
      expect(map['reactions']['user_b'], '❤️');

      final reconstructed = ChatMessage.fromMap(map);
      expect(reconstructed.id, msg.id);
      expect(reconstructed.senderName, msg.senderName);
      expect(reconstructed.content, msg.content);
      expect(reconstructed.reactions['user_b'], '❤️');

      // Test copyWith reaction addition
      final updated = reconstructed.copyWith(reactions: {
        ...reconstructed.reactions,
        'user_a': '🥰',
      });
      expect(updated.reactions.length, 2);
      expect(updated.reactions['user_a'], '🥰');
      expect(updated.reactions['user_b'], '❤️');
    });

    test('CoupleMemory model roundtrip serialization', () {
      final now = DateTime.now();
      final memory = CoupleMemory(
        id: 'mem_456',
        type: MemoryType.photo,
        title: 'Sunset at Marine Drive',
        caption: 'The sky turned golden pink',
        imageUrl: 'https://storage.local/sunset.jpg',
        locationName: 'Marine Drive, Mumbai',
        memoryDate: DateTime(2025, 9, 6),
        createdByName: 'Jeet',
        createdAt: now,
      );

      final map = memory.toMap();
      expect(map['id'], 'mem_456');
      expect(map['title'], 'Sunset at Marine Drive');
      expect(map['locationName'], 'Marine Drive, Mumbai');

      final reconstructed = CoupleMemory.fromMap(map);
      expect(reconstructed.id, memory.id);
      expect(reconstructed.title, memory.title);
      expect(reconstructed.imageUrl, memory.imageUrl);
      expect(reconstructed.memoryDate.year, 2025);
      expect(reconstructed.memoryDate.month, 9);
      expect(reconstructed.memoryDate.day, 6);
    });

    test('MoodType contains all 8 non-negotiable emotional states with exact labels', () {
      expect(MoodType.values.length, 8);
      final names = MoodType.values.map((m) => m.name).toSet();
      expect(names.contains('happy'), isTrue);
      expect(names.contains('loving'), isTrue);
      expect(names.contains('missingYou'), isTrue);
      expect(names.contains('sad'), isTrue);
      expect(names.contains('angry'), isTrue);
      expect(names.contains('tired'), isTrue);
      expect(names.contains('needAHug'), isTrue);
      expect(names.contains('intimate'), isTrue);

      expect(MoodType.happy.label, 'Happy');
      expect(MoodType.loving.label, 'Loving');
      expect(MoodType.missingYou.label, 'Missing You');
      expect(MoodType.sad.label, 'Sad');
      expect(MoodType.angry.label, 'Angry');
      expect(MoodType.tired.label, 'Tired');
      expect(MoodType.needAHug.label, 'Need a Hug');
      expect(MoodType.intimate.label, 'Intimate');
    });
  });
}
