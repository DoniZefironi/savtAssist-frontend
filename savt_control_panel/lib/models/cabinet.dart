class Cabinet {
  final int cabinetId;
  final String type;
  final String objectNumber;
  final String customName;
  final bool isPrimary;
  final int unreadCount;
  final String warrantyStatus;
  final String? warrantyEndsAt;

  Cabinet({
    required this.cabinetId,
    required this.type,
    required this.objectNumber,
    required this.customName,
    required this.isPrimary,
    required this.unreadCount,
    required this.warrantyStatus,
    this.warrantyEndsAt,
  });

  factory Cabinet.fromJson(Map<String, dynamic> json) {
    return Cabinet(
      cabinetId: json['cabinet_id'],
      type: json['type'],
      objectNumber: json['object_number'],
      customName: json['custom_name'] ?? '',
      isPrimary: json['is_primary'] ?? false,
      unreadCount: json['unread_count'] ?? 0,
      warrantyStatus: json['warranty_status'] ?? 'unknown',
      warrantyEndsAt: json['warranty_ends_at'],
    );
  }
}
