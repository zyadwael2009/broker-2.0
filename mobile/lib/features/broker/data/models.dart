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

/// The public view of a broker, as a buyer sees it before deciding to
/// call. Mirrors `GET /brokers/<id>` in `backend/app/brokers/routes.py`.
///
/// [goeicRegistrationNumber] is null until an admin has actually checked
/// the uploaded document — the backend withholds it for pending brokers
/// so an unverified number can never be paraded as proof.
class BrokerPublicProfileDto {
  BrokerPublicProfileDto({
    required this.id,
    required this.fullName,
    required this.verificationStatus,
    required this.activeListingCount,
    this.phone,
    this.goeicRegistrationNumber,
    this.verifiedAt,
    this.memberSince,
  });

  final int id;
  final String fullName;
  final String verificationStatus;
  final int activeListingCount;
  final String? phone;
  final String? goeicRegistrationNumber;
  final DateTime? verifiedAt;
  final DateTime? memberSince;

  bool get isVerified => verificationStatus == 'verified';

  factory BrokerPublicProfileDto.fromJson(Map<String, dynamic> j) =>
      BrokerPublicProfileDto(
        id: (j['id'] as num).toInt(),
        fullName: (j['full_name'] as String?) ?? '',
        verificationStatus: (j['verification_status'] as String?) ?? 'pending',
        activeListingCount: (j['active_listing_count'] as num?)?.toInt() ?? 0,
        phone: j['phone'] as String?,
        goeicRegistrationNumber: j['goeic_registration_number'] as String?,
        verifiedAt: _date(j['verified_at']),
        memberSince: _date(j['member_since']),
      );

  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;
}
