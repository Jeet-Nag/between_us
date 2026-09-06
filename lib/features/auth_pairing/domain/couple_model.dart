enum CoupleStatus {
  unpaired,
  waitingForPartner,
  connected,
  disconnected,
}

class UserProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? initials;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.initials,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'initials': initials,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String,
    displayName: map['displayName'] as String,
    avatarUrl: map['avatarUrl'] as String?,
    initials: map['initials'] as String?,
  );
}

class CoupleModel {
  final String id;
  final String pairingCode;
  final CoupleStatus status;
  final UserProfile user;
  final UserProfile? partner;
  final DateTime createdAt;
  final DateTime? nextMeetingDate;
  final String? nextMeetingTitle;
  final bool locationSharingEnabled;

  const CoupleModel({
    required this.id,
    required this.pairingCode,
    required this.status,
    required this.user,
    this.partner,
    required this.createdAt,
    this.nextMeetingDate,
    this.nextMeetingTitle,
    this.locationSharingEnabled = true,
  });

  CoupleModel copyWith({
    String? id,
    String? pairingCode,
    CoupleStatus? status,
    UserProfile? user,
    UserProfile? partner,
    DateTime? createdAt,
    DateTime? nextMeetingDate,
    String? nextMeetingTitle,
    bool? locationSharingEnabled,
  }) {
    return CoupleModel(
      id: id ?? this.id,
      pairingCode: pairingCode ?? this.pairingCode,
      status: status ?? this.status,
      user: user ?? this.user,
      partner: partner ?? this.partner,
      createdAt: createdAt ?? this.createdAt,
      nextMeetingDate: nextMeetingDate ?? this.nextMeetingDate,
      nextMeetingTitle: nextMeetingTitle ?? this.nextMeetingTitle,
      locationSharingEnabled: locationSharingEnabled ?? this.locationSharingEnabled,
    );
  }
}
