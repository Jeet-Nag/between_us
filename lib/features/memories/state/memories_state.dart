import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/realtime_client.dart';
import '../domain/memory_model.dart';
import '../data/memories_repository.dart';

class MemoriesState extends ChangeNotifier {
  final RealtimeClient _realtimeClient;
  final MemoriesRepository _memoriesRepository;
  final String _myUserId;
  final String _myName;
  final String _coupleId;

  final List<CoupleMemory> _memories = [];
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _firestoreSubscription;

  MemoriesState({
    required RealtimeClient realtimeClient,
    required MemoriesRepository memoriesRepository,
    required String myUserId,
    required String myName,
    required String coupleId,
  })  : _realtimeClient = realtimeClient,
        _memoriesRepository = memoriesRepository,
        _myUserId = myUserId,
        _myName = myName,
        _coupleId = coupleId {
    _initMemories();
    _listenToRealtimeEvents();
  }

  List<CoupleMemory> get memories => List.unmodifiable(_memories);

  /// Resurfaces memories created on this day in past years
  List<CoupleMemory> get onThisDayMemories {
    final now = DateTime.now();
    return _memories.where((m) => m.memoryDate.month == now.month && m.memoryDate.day == now.day).toList();
  }

  Future<void> _initMemories() async {
    // 1. Load local cache first for instant UI display
    final cached = await _memoriesRepository.getCachedMemories(_coupleId);
    if (cached.isNotEmpty && _memories.isEmpty) {
      _memories.addAll(cached);
      notifyListeners();
    }

    // 2. Stream from Firestore
    _firestoreSubscription = _memoriesRepository.watchMemories(_coupleId).listen((serverMemories) {
      _memories.clear();
      _memories.addAll(serverMemories);
      notifyListeners();
    }, onError: (error) {
      debugPrint('[MemoriesState] Firestore stream error (offline fallback active): $error');
    });
  }

  void _listenToRealtimeEvents() {
    _realtimeSubscription = _realtimeClient.eventStream.listen((event) {
      if (event.senderId == _myUserId) return;

      if (event.type == RealtimeEventType.memoryAdded) {
        final p = event.payload;
        final mem = CoupleMemory(
          id: event.id,
          type: MemoryType.values.firstWhere(
            (t) => t.name == p['type'],
            orElse: () => MemoryType.note,
          ),
          title: p['title'] as String? ?? '',
          caption: p['caption'] as String?,
          locationName: p['locationName'] as String?,
          memoryDate: p['memoryDate'] != null
              ? DateTime.tryParse(p['memoryDate'] as String) ?? DateTime.now()
              : DateTime.now(),
          createdByName: p['createdByName'] as String? ?? 'Partner',
          createdAt: DateTime.now(),
        );

        if (!_memories.any((m) => m.id == mem.id)) {
          _memories.insert(0, mem);
          notifyListeners();
        }
      }
    });
  }

  Future<void> addMemory({
    required String title,
    required String caption,
    required String locationName,
    required DateTime memoryDate,
    MemoryType type = MemoryType.note,
    String? imageUrl,
  }) async {
    final memId = const Uuid().v4();
    final mem = CoupleMemory(
      id: memId,
      type: type,
      title: title,
      caption: caption.isNotEmpty ? caption : null,
      locationName: locationName.isNotEmpty ? locationName : null,
      imageUrl: imageUrl,
      memoryDate: memoryDate,
      createdByName: _myName,
      createdAt: DateTime.now(),
    );

    // Instant local state update
    _memories.insert(0, mem);
    notifyListeners();

    // Broadcast via Realtime WebSocket
    _realtimeClient.broadcastEvent(RealtimeEvent(
      id: memId,
      type: RealtimeEventType.memoryAdded,
      senderId: _myUserId,
      coupleId: _coupleId,
      payload: {
        'title': title,
        'caption': caption,
        'locationName': locationName,
        'memoryDate': memoryDate.toIso8601String(),
        'type': type.name,
        'imageUrl': imageUrl,
        'createdByName': _myName,
      },
      serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    // Persist to Firestore
    await _memoriesRepository.addMemory(coupleId: _coupleId, memory: mem);
  }

  Future<void> deleteMemory(String memoryId) async {
    _memories.removeWhere((m) => m.id == memoryId);
    notifyListeners();
    await _memoriesRepository.deleteMemory(coupleId: _coupleId, memoryId: memoryId);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
