import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/distance_calculator.dart';
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
  final int batteryLevel;
  final bool isCharging;

  const PartnerLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.updatedAt,
    this.batteryLevel = 85,
    this.isCharging = false,
  });
}

class PresenceState extends ChangeNotifier {
  final LocationRepository _locationRepository;
  final String _myUserId;
  final String _coupleId;
  final String _partnerId;

  PartnerLocation? _myLocation;
  PartnerLocation? _partnerLocation;
  MoodType _myMood = MoodType.loving;
  MoodType _partnerMood = MoodType.loving;
  bool _isPartnerOnline = false;
  bool _isLocationSharingEnabled = true;

  ProximityResult _proximity = const ProximityResult(
    distanceInMeters: 0,
    state: ProximityState.longDistance,
    formattedDistance: 'Awaiting Location…',
    emotionalSubtitle: 'Connected across distances.',
    stateColor: AppColors.proximityLong,
  );

  StreamSubscription? _partnerLocationSubscription;
  StreamSubscription? _nativeLocationSubscription;
  Timer? _freshnessTimer;

  PresenceState({
    required LocationRepository locationRepository,
    required String myUserId,
    required String coupleId,
    required String partnerId,
  })  : _locationRepository = locationRepository,
        _myUserId = myUserId,
        _coupleId = coupleId,
        _partnerId = partnerId {
    _startLocationStreaming();
    _listenToPartnerLocation();
    _freshnessTimer = Timer.periodic(const Duration(minutes: 1), (_) => notifyListeners());
  }

  PartnerLocation? get myLocation => _myLocation;
  PartnerLocation? get partnerLocation => _partnerLocation;
  MoodType get myMood => _myMood;
  MoodType get partnerMood => _partnerMood;
  bool get isPartnerOnline => _isPartnerOnline;
  bool get isLocationSharingEnabled => _isLocationSharingEnabled;
  ProximityResult get proximity => _proximity;

  /// Computes human-readable location freshness without deceptive "LIVE" labels on stale data
  String get partnerFreshnessLabel {
    if (!_isLocationSharingEnabled) return 'LOCATION SHARING OFF';
    if (_partnerLocation == null) return 'WAITING FOR LOCATION…';

    final diff = DateTime.now().difference(_partnerLocation!.updatedAt);
    if (diff.inMinutes < 3) {
      return 'LIVE';
    } else if (diff.inMinutes < 60) {
      return 'UPDATED ${diff.inMinutes}M AGO';
    } else if (diff.inHours < 24) {
      return 'UPDATED ${diff.inHours}H AGO';
    } else {
      return 'OFFLINE';
    }
  }

  bool get isPartnerLocationStale {
    if (_partnerLocation == null) return true;
    return DateTime.now().difference(_partnerLocation!.updatedAt).inMinutes >= 15;
  }

  void _startLocationStreaming() async {
    final hasPermission = await NativeLocationService.ensurePermission();
    if (!hasPermission) {
      debugPrint('[Presence] Native location permission denied by user.');
      return;
    }

    // Get initial fix
    final initial = await NativeLocationService.getCurrentPosition();
    if (initial != null) {
      _myLocation = PartnerLocation(
        latitude: initial.latitude,
        longitude: initial.longitude,
        accuracy: initial.accuracy,
        updatedAt: initial.timestamp,
      );
      _locationRepository.updateMyLocation(
        coupleId: _coupleId,
        myUserId: _myUserId,
        reading: initial,
      );
      _recalculateDistance();
    }

    // Start 25m distance-filtered stream
    _nativeLocationSubscription = NativeLocationService.getBatteryAwarePositionStream(
      distanceFilterMeters: 25,
    ).listen((reading) {
      if (!_isLocationSharingEnabled) return;
      _myLocation = PartnerLocation(
        latitude: reading.latitude,
        longitude: reading.longitude,
        accuracy: reading.accuracy,
        updatedAt: reading.timestamp,
      );
      _locationRepository.updateMyLocation(
        coupleId: _coupleId,
        myUserId: _myUserId,
        reading: reading,
      );
      _recalculateDistance();
    });
  }

  void _listenToPartnerLocation() {
    if (_partnerId.isEmpty) return;
    _partnerLocationSubscription = _locationRepository
        .watchPartnerLocation(coupleId: _coupleId, partnerId: _partnerId)
        .listen((loc) {
      if (loc != null) {
        _partnerLocation = loc;
        _isPartnerOnline = DateTime.now().difference(loc.updatedAt).inMinutes < 15;
        _recalculateDistance();
      }
    });
  }

  void _recalculateDistance() {
    if (_myLocation == null || _partnerLocation == null) {
      _proximity = const ProximityResult(
        distanceInMeters: 0,
        state: ProximityState.longDistance,
        formattedDistance: 'Awaiting Location…',
        emotionalSubtitle: 'Connected across distances.',
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
    notifyListeners();
  }

  void setMyMood(MoodType mood) {
    _myMood = mood;
    notifyListeners();
  }

  void setPartnerMood(MoodType mood) {
    _partnerMood = mood;
    notifyListeners();
  }

  @override
  void dispose() {
    _partnerLocationSubscription?.cancel();
    _nativeLocationSubscription?.cancel();
    _freshnessTimer?.cancel();
    super.dispose();
  }
}
