import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local persistent cache engine supporting offline-first operations.
/// Keeps chat messages, memories, partner presence, and pending mutations locally.
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('[LocalStorageService] Error initializing SharedPreferences: $e');
    }
  }

  Future<SharedPreferences?> _getPrefs() async {
    if (_prefs == null) {
      await init();
    }
    return _prefs;
  }

  // --- Auth & Couple Metadata ---

  Future<void> saveCoupleInfo({
    required String coupleId,
    required String partnerId,
    required String partnerName,
  }) async {
    final prefs = await _getPrefs();
    await prefs?.setString('current_couple_id', coupleId);
    await prefs?.setString('current_partner_id', partnerId);
    await prefs?.setString('current_partner_name', partnerName);
  }

  Future<String?> getCoupleId() async {
    final prefs = await _getPrefs();
    return prefs?.getString('current_couple_id');
  }

  Future<String?> getPartnerId() async {
    final prefs = await _getPrefs();
    return prefs?.getString('current_partner_id');
  }

  Future<String?> getPartnerName() async {
    final prefs = await _getPrefs();
    return prefs?.getString('current_partner_name');
  }

  Future<void> clearCoupleInfo() async {
    final prefs = await _getPrefs();
    await prefs?.remove('current_couple_id');
    await prefs?.remove('current_partner_id');
    await prefs?.remove('current_partner_name');
  }

  // --- Revision Tracker for Realtime Sync ---

  Future<void> saveLastRevision(int revision) async {
    final prefs = await _getPrefs();
    await prefs?.setInt('last_server_revision', revision);
  }

  Future<int> getLastRevision() async {
    final prefs = await _getPrefs();
    return prefs?.getInt('last_server_revision') ?? 0;
  }

  // --- Local Messages Cache ---

  Future<void> saveCachedMessages(String coupleId, List<Map<String, dynamic>> rawMessages) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(rawMessages);
      await prefs?.setString('cached_msgs_$coupleId', jsonStr);
    } catch (e) {
      debugPrint('[LocalStorageService] Failed to cache messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedMessages(String coupleId) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs?.getString('cached_msgs_$coupleId');
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[LocalStorageService] Failed to load cached messages: $e');
      return [];
    }
  }

  // --- Local Memories Cache ---

  Future<void> saveCachedMemories(String coupleId, List<Map<String, dynamic>> rawMemories) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(rawMemories);
      await prefs?.setString('cached_memories_$coupleId', jsonStr);
    } catch (e) {
      debugPrint('[LocalStorageService] Failed to cache memories: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedMemories(String coupleId) async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs?.getString('cached_memories_$coupleId');
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[LocalStorageService] Failed to load cached memories: $e');
      return [];
    }
  }

  // --- Pending Offline Outbound Events ---

  Future<void> queuePendingEvent(Map<String, dynamic> eventMap) async {
    try {
      final prefs = await _getPrefs();
      final existing = await getPendingEvents();
      existing.add(eventMap);
      await prefs?.setString('pending_offline_events', jsonEncode(existing));
    } catch (e) {
      debugPrint('[LocalStorageService] Failed to queue pending event: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs?.getString('pending_offline_events');
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('[LocalStorageService] Failed to load pending events: $e');
      return [];
    }
  }

  Future<void> clearPendingEvents() async {
    final prefs = await _getPrefs();
    await prefs?.remove('pending_offline_events');
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs?.clear();
  }
}
