// Broker verification DTO, mirroring `BrokerProfile.to_public_dict()`.

class VerificationStatusDto {
  VerificationStatusDto({
    required this.status,
    this.goeicRegistrationNumber,
    this.rejectionReason,
    this.verifiedAt,
  });

  final String status; // 'pending' | 'verified' | 'rejected'
  final String? goeicRegistrationNumber;
  final String? rejectionReason;
  final DateTime? verifiedAt;

  factory VerificationStatusDto.fromJson(Map<String, dynamic> j) {
    final rawVerifiedAt = j['verified_at'] as String?;
    return VerificationStatusDto(
      status: j['verification_status'] as String,
      goeicRegistrationNumber: j['goeic_registration_number'] as String?,
      rejectionReason: j['rejection_reason'] as String?,
      verifiedAt: rawVerifiedAt == null ? null : DateTime.tryParse(rawVerifiedAt),
    );
  }
}
