import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class BrokerRepository {
  BrokerRepository(this._api);
  final ApiClient _api;

  Future<VerificationStatusDto> fetchMyStatus() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/brokers/me/verification',
    );
    if (res.statusCode == 200 && res.data != null) {
      return VerificationStatusDto.fromJson(res.data!);
    }
    throw AuthException(
      _extractError(res.data) ?? 'Could not load verification status.',
      status: res.statusCode,
    );
  }

  /// Multipart POST: GOEIC number + registration document file.
  ///
  /// On native platforms file_picker returns a filesystem path
  /// ([documentPath]); on web it returns bytes ([documentBytes]) instead
  /// because there is no path to reach. Callers should pass whichever the
  /// picker gave them.
  Future<VerificationStatusDto> submit({
    required String goeicRegistrationNumber,
    required String documentFilename,
    String? documentPath,
    Uint8List? documentBytes,
  }) async {
    assert(
      documentPath != null || documentBytes != null,
      'Either documentPath (native) or documentBytes (web) is required.',
    );

    final MultipartFile document = documentBytes != null
        ? MultipartFile.fromBytes(documentBytes, filename: documentFilename)
        : await MultipartFile.fromFile(documentPath!, filename: documentFilename);

    final form = FormData.fromMap({
      'goeic_registration_number': goeicRegistrationNumber,
      'document': document,
    });
    // Do NOT override contentType — Dio 5 sets `multipart/form-data;
    // boundary=<random>` automatically when data is FormData. Setting
    // it manually strips the boundary and the server rejects with 400.
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/brokers/me/verification',
      data: form,
    );
    if (res.statusCode == 200 && res.data != null) {
      return VerificationStatusDto.fromJson(res.data!);
    }
    throw AuthException(
      _extractError(res.data) ?? 'Submission failed.',
      status: res.statusCode,
    );
  }

  String? _extractError(Map<String, dynamic>? data) {
    if (data == null) return null;
    final fields = data['fields'];
    if (fields is Map && fields.isNotEmpty) {
      final entry = fields.entries.first;
      final val = entry.value;
      final msg = val is List && val.isNotEmpty ? val.first : val;
      return '${entry.key}: $msg';
    }
    if (fields is List && fields.isNotEmpty) return '${fields.first}';
    final err = data['error'];
    return err is String ? err : null;
  }
}

final brokerRepositoryProvider = Provider<BrokerRepository>((ref) {
  return BrokerRepository(ref.watch(apiClientProvider));
});
