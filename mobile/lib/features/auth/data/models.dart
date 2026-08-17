// DTOs mirroring the Flask /auth response shapes. Hand-written for now;
// we can swap to json_serializable if the payloads grow.

class UserDto {
  UserDto({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.role,
    this.email,
    this.phoneVerified = false,
    this.referralCode,
  });

  final int id;
  final String phone;
  final String? email;
  final String fullName;
  final String role; // 'buyer' | 'broker' | 'admin'
  final bool phoneVerified;
  final String? referralCode;

  factory UserDto.fromJson(Map<String, dynamic> j) => UserDto(
        id: j['id'] as int,
        phone: j['phone'] as String,
        email: j['email'] as String?,
        fullName: j['full_name'] as String,
        role: j['role'] as String,
        phoneVerified: (j['phone_verified'] as bool?) ?? false,
        referralCode: j['referral_code'] as String?,
      );

  UserDto copyWith({bool? phoneVerified, String? referralCode}) => UserDto(
        id: id,
        phone: phone,
        email: email,
        fullName: fullName,
        role: role,
        phoneVerified: phoneVerified ?? this.phoneVerified,
        referralCode: referralCode ?? this.referralCode,
      );
}

class BrokerProfileDto {
  BrokerProfileDto({
    required this.verificationStatus,
    this.goeicRegistrationNumber,
    this.rejectionReason,
  });

  final String verificationStatus; // 'pending' | 'verified' | 'rejected'
  final String? goeicRegistrationNumber;
  final String? rejectionReason;

  factory BrokerProfileDto.fromJson(Map<String, dynamic> j) => BrokerProfileDto(
        verificationStatus: j['verification_status'] as String,
        goeicRegistrationNumber: j['goeic_registration_number'] as String?,
        rejectionReason: j['rejection_reason'] as String?,
      );
}

class TokenPair {
  TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory TokenPair.fromJson(Map<String, dynamic> j) => TokenPair(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
      );
}

class AuthResult {
  AuthResult({required this.user, required this.tokens, this.brokerProfile});

  final UserDto user;
  final BrokerProfileDto? brokerProfile;
  final TokenPair tokens;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        user: UserDto.fromJson(j['user'] as Map<String, dynamic>),
        brokerProfile: j['broker_profile'] == null
            ? null
            : BrokerProfileDto.fromJson(
                j['broker_profile'] as Map<String, dynamic>),
        tokens: TokenPair.fromJson(j['tokens'] as Map<String, dynamic>),
      );
}

/// Request payloads.
class RegisterRequest {
  RegisterRequest({
    required this.phone,
    required this.password,
    required this.fullName,
    required this.role,
    this.email,
  });

  final String phone; // full E.164 e.g. +201012345678
  final String password;
  final String fullName;
  final String role; // 'buyer' | 'broker'
  final String? email;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'role': role,
        if (email != null && email!.isNotEmpty) 'email': email,
      };
}

class LoginRequest {
  LoginRequest({required this.phone, required this.password});

  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {'phone': phone, 'password': password};
}

/// Thrown by the repository so the UI can show a message.
class AuthException implements Exception {
  AuthException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}
