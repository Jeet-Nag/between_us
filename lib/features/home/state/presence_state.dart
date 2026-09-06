import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../battery/service/native_battery_service.dart';
import '../../location/data/location_repository.dart';
import '../../location/service/native_location_service.dart';

enum MoodType {
  happy('😊', 'Happy', 'Feeling joyful and light'),
  loving('🥰', 'Loving', 'Feeling deeply in love'),
  missingYou('🥺', 'Missing You', 'Longing to be together'),
  sad('😔', 'Sad', 'Need some quiet comfort'),
  angry('😡', 'Angry', 'Need gentle understanding'),
  tired('😴', 'Tired', 'Long day, resting now'),
  needAHug('🫂', 'Need a Hug', 'Craving a warm embrace'),
  intimate('🔥', 'Intimate', 'Holding you close in thought');

  final String emoji;
  final String label;
  final String description;
  const MoodType(this.emoji, this.label, this.description);
}

class PartnerLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime updatedAt;
  final int? batteryLevel;
  final bool isCharging;

  const PartnerLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
    this.batteryLevel,
    this.isCharging = false,
  });
}

class PresenceState extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationRepository _locationRepository;
  final String _myUserId;
  final String _coupleId;
  final String _partnerId;

  PartnerLocation? _myLocation;
  PartnerLocation? _partnerLocation;
  int? _myBatteryLevel;
  bool _myIsCharging = false;
  MoodType _myMood = MoodType.loving;
  MoodType _partnerMood = MoodType.loving;
  bool _isPartnerOnline = false;
  bool _isLocationSharingEnabled = true;

  ProximityResult _proximity = const ProximityResult(
    distanceInMeters: 0,
    state: ProximityState.longDistance,
    formattedDistance: 'Location unavailable',
    emotionalSubtitle: 'Connected across distances.',
    stateColor: AppColors.proximityLong,
  );

  StreamSubscription? _partnerLocationSubscription;
  StreamSubscription? _nativeLocationSubscription;
  StreamSubscription? _partnerPresenceSubscription;
  StreamSubscription? _batterySubscription;
  Timer? _freshnessTimer;
  Timer? _batteryPeriodicTimer;

  PresenceState({
    required LocationRepository locationRepository,
    required String myUserId,
    required String coupleId,
    required String partnerId,
  })  : _locationRepository = locationRepository,
        _myUserId = myUserId,
        _coupleId = coupleId,
        _partnerId = partnerId {
    _initBattery();
    _startLocationStreaming();
    _listenToPartnerLocation();
    _listenToPartnerPresence();
    _publishMyPresence();
    _freshnessTimer = Timer.periodic(const Duration(minutes: 1), (_) => notifyListeners());
    _batteryPeriodicTimer = Timer.periodic(const Duration(minutes: 5), (_) => _syncBatteryLevel());
  }

  PartnerLocation? get myLocation => _myLocation;
  PartnerLocation? get partnerLocation => _partnerLocation;
  int? get myBatteryLevel => _myBatteryLevel;
  bool get myIsCharging => _myIsCharging;
  MoodType get myMood => _myMood;
  MoodType get partnerMood => _partnerMood;
  bool get isPartnerOnline => _isPartnerOnline;
  bool get isLocationSharingEnabled => _isLocationSharingEnabled;
  ProximityResult get proximity => _proximity;

  /// Computes accurate, honest location freshness without fake "LIVE" labels
  String get partnerFreshnessLabel {
    if (!_isLocationSharingEnabled) return 'Location sharing is off';
    if (_partnerLocation == null) return 'Waiting for location…';

    final diff = DateTime.now().difference(_partnerLocation!.updatedAt);
    if (diff.inSeconds < 30) {
      return 'Live';
    } else if (diff.inMinutes < 5) {
      return 'Recently updated';
    } else if (diff.inMinutes < 60) {
      return 'Last updated ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Last updated ${diff.inHours}h ago';
    } else {
      return 'Offline';
    }
  }

  bool get isPartnerLocationStale {
    if (_partnerLocation == null) return true;
    return DateTime.now().difference(_partnerLocation!.updatedAt).inMinutes >= 15;
  }

  Future<void> _initBattery() async {
    _myBatteryLevel = await NativeBatteryService.getBatteryLevel();
    _myIsCharging = await NativeBatteryService.isCharging();
    notifyListeners();

    _batterySubscription = NativeBatteryService.onBatteryStateChanged.listen((_) async {
      await _syncBatteryLevel();
    });
  }

  Future<void> _syncBatteryLevel() async {
    final level = await NativeBatteryService.getBatteryLevel();
    final charging = await NativeBatteryService.isCharging();
    _myBatteryLevel = level;
    _myIsCharging = charging;
    notifyListeners();

    if (_coupleId.isNotEmpty && _myUserId.isNotEmpty) {
      _locationRepository.updateBattery(
        coupleId: _coupleId,
        myUserId: _myUserId,
        batteryLevel: level,
        isCharging: charging,
      );
    }
  }

  void _startLocationStreaming() async {
    final hasPermission = await NativeLocationService.ensurePermission();
    if (!hasPermission) {
      debugPrint('[Presence] Location permission unavailable or denied.');
      _recalculateDistance();
      return;
    }

    // Get initial real GPS fix
    final initial = await NativeLocationService.getCurrentPosition();
    if (initial != null) {
      _myLocation = PartnerLocation(
        latitude: initial.latitude,
        longitude: initial.longitude,
        accuracy: initial.accuracy,
        updatedAt: initial.timestamp,
        batteryLevel: _myBatteryLevel,
        isCharging: _myIsCharging,
      );
      _locationRepository.updateMyLocation(
        coupleId: _coupleId,
        myUserId: _myUserId,
        reading: initial,
        batteryLevel: _myBatteryLevel,
        isCharging: _myIsCharging,
      );
      _recalculateDistance();
    }

    // Start battery-aware GPS distance stream
    _nativeLocationSubscription = NativeLocationService.getBatteryAwarePositionStream(
      distanceFilterMeters: 25,
    ).listen((reading) {
      if (!_isLocationSharingEnabled) return;
      _myLocation = PartnerLocation(
        latitude: reading.latitude,
        longitude: reading.longitude,
        accuracy: reading.accuracy,
        updatedAt: reading.timestamp,
        batteryLevel: _myBatteryLevel,
        isCharging: _myIsCharging,
      );
      _locationRepository.updateMyLocation(
        coupleId: _coupleId,
        myUserId: _myUserId,
        reading: reading,
        batteryLevel: _myBatteryLevel,
        isCharging: _myIsCharging,
      );
      _recalculateDistance();
    });
  }

  void _listenToPartnerLocation() {
    if (_partnerId.isEmpty) return;
    _partnerLocationSubscription = _locationRepository
        .watchPartnerLocation(coupleId: _coupleId, partnerId: _partnerId)
        .listen((loc) {
      _partnerLocation = loc;
      if (loc != null) {
        _isPartnerOnline = DateTime.now().difference(loc.updatedAt).inMinutes < 5;
      }
      _recalculateDistance();
    });
  }

  void _listenToPartnerPresence() {
    if (_partnerId.isEmpty || _coupleId.isEmpty) return;
    _partnerPresenceSubscription = _firestore
        .collection('couples')
        .doc(_coupleId)
        .collection('presence')
        .doc(_partnerId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final moodStr = data['mood'] as String?;
      final lastSeen = (data['lastSeenAt'] as Timestamp?)?.toDate();

      if (moodStr != null) {
        _partnerMood = MoodType.values.firstWhere(
          (m) => m.name == moodStr,
          orElse: () => MoodType.loving,
        );
      }
      if (lastSeen != null) {
        _isPartnerOnline = DateTime.now().difference(lastSeen).inMinutes < 5;
      }
      notifyListeners();
    });
  }

  Future<void> _publishMyPresence() async {
    if (_coupleId.isEmpty || _myUserId.isEmpty) return;
    try {
      await _firestore
          .collection('couples')
          .doc(_coupleId)
          .collection('presence')
          .doc(_myUserId)
          .set({
        'mood': _myMood.name,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-fatal
    }
  }

  void _recalculateDistance() {
    if (!_isLocationSharingEnabled) {
      _proximity = const ProximityResult(
        distanceInMeters: 0,
        state: ProximityState.longDistance,
        formattedDistance: 'Location sharing is off',
        emotionalSubtitle: 'Turn on location sharing in settings.',
        stateColor: AppColors.proximityLong,
      );
      notifyListeners();
      return;
    }

    if (_myLocation == null || _partnerLocation == null) {
      _proximity = const ProximityResult(
        distanceInMeters: 0,
        state: ProximityState.longDistance,
        formattedDistance: 'Location unavailable',
        emotionalSubtitle: 'Waiting for partner GPS coordinates…',
        stateColor: AppColors.proximityLong,
      );
      notifyListeners();
      return;
    }

    final distanceMeters = DistanceCalculator.calculateDistanceMeters(
      lat1: _myLocation!.latitude,
      lon1: _myLocation!.longitude,
      lat2: _partnerLocation!.latitude,
      lon2: _partnerLocation!.longitude,
    );

    _proximity = DistanceCalculator.evaluateProximity(
      distanceMeters: distanceMeters,
      accuracyMeters: _partnerLocation!.accuracy,
      previousState: _proximity.state,
    );
    notifyListeners();
  }

  void toggleLocationSharing(bool enabled) {
    _isLocationSharingEnabled = enabled;
    _recalculateDistance();
  }

  void setMyMood(MoodType mood) {
    _myMood = mood;
    notifyListeners();
    _publishMyPresence();
  }

  void setPartnerMood(MoodType mood) {
    _partnerMood = mood;
    notifyListeners();
  }

  @override
  void dispose() {
    _partnerLocationSubscription?.cancel();
    _nativeLocationSubscription?.cancel();
    _partnerPresenceSubscription?.cancel();
    _batterySubscription?.cancel();
    _freshnessTimer?.cancel();
    _batteryPeriodicTimer?.cancel();
    super.dispose();
  }
}
