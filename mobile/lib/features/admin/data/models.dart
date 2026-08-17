// Admin-side broker DTO — mirrors admin_routes `_profile_admin_view`.

class AdminBrokerDto {
  AdminBrokerDto({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.verificationStatus,
    this.goeicRegistrationNumber,
    this.documentUrl,
    this.rejectionReason,
    this.updatedAt,
  });

  final int userId;
  final String fullName;
  final String phone;
  final String verificationStatus; // 'pending' | 'verified' | 'rejected'
  final String? goeicRegistrationNumber;
  final String? documentUrl;
  final String? rejectionReason;
  final DateTime? updatedAt;

  factory AdminBrokerDto.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>;
    final rawUpdated = j['updated_at'] as String?;
    return AdminBrokerDto(
      userId: user['id'] as int,
      fullName: user['full_name'] as String,
      phone: user['phone'] as String,
      verificationStatus: j['verification_status'] as String,
      goeicRegistrationNumber: j['goeic_registration_number'] as String?,
      documentUrl: j['document_url'] as String?,
      rejectionReason: j['rejection_reason'] as String?,
      updatedAt: rawUpdated == null ? null : DateTime.tryParse(rawUpdated),
    );
  }

  bool get isImageDoc {
    final url = documentUrl?.toLowerCase();
    if (url == null) return false;
    return url.endsWith('.jpg') ||
        url.endsWith('.jpeg') ||
        url.endsWith('.png') ||
        url.endsWith('.webp');
  }

  bool get isPdfDoc =>
      documentUrl?.toLowerCase().endsWith('.pdf') ?? false;
}
