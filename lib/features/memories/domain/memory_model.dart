enum MemoryType {
  photo,
  voice,
  note,
}

class CoupleMemory {
  final String id;
  final MemoryType type;
  final String title;
  final String? caption;
  final String? imageUrl;
  final String? locationName;
  final DateTime memoryDate;
  final String createdByName;
  final DateTime createdAt;

  const CoupleMemory({
    required this.id,
    required this.type,
    required this.title,
    this.caption,
    this.imageUrl,
    this.locationName,
    required this.memoryDate,
    required this.createdByName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'caption': caption,
      'imageUrl': imageUrl,
      'locationName': locationName,
      'memoryDate': memoryDate.toIso8601String(),
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CoupleMemory.fromMap(Map<String, dynamic> map, {String? docId}) {
    return CoupleMemory(
      id: docId ?? map['id'] as String? ?? '',
      type: MemoryType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MemoryType.note,
      ),
      title: map['title'] as String? ?? '',
      caption: map['caption'] as String?,
      imageUrl: map['imageUrl'] as String?,
      locationName: map['locationName'] as String?,
      memoryDate: map['memoryDate'] != null
          ? DateTime.tryParse(map['memoryDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      createdByName: map['createdByName'] as String? ?? 'Partner',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CoupleMemory copyWith({
    String? id,
    MemoryType? type,
    String? title,
    String? caption,
    String? imageUrl,
    String? locationName,
    DateTime? memoryDate,
    String? createdByName,
    DateTime? createdAt,
  }) {
    return CoupleMemory(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      imageUrl: imageUrl ?? this.imageUrl,
      locationName: locationName ?? this.locationName,
      memoryDate: memoryDate ?? this.memoryDate,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
