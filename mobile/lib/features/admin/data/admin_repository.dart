import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<List<AdminBrokerDto>> listBrokers({String status = 'pending'}) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/admin/brokers',
      queryParameters: {'status': status},
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(AdminBrokerDto.fromJson)
          .toList();
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not load brokers.',
      status: res.statusCode,
    );
  }

  Future<AdminBrokerDto> detail(int brokerUserId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/admin/brokers/$brokerUserId',
    );
    if (res.statusCode == 200 && res.data != null) {
      return AdminBrokerDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Broker not found.',
      status: res.statusCode,
    );
  }

  Future<AdminBrokerDto> approve(int brokerUserId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/admin/brokers/$brokerUserId/approve',
    );
    if (res.statusCode == 200 && res.data != null) {
      return AdminBrokerDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Approve failed.',
      status: res.statusCode,
    );
  }

  Future<AdminBrokerDto> reject(int brokerUserId, String reason) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/admin/brokers/$brokerUserId/reject',
      data: {'reason': reason},
    );
    if (res.statusCode == 200 && res.data != null) {
      return AdminBrokerDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Reject failed.',
      status: res.statusCode,
    );
  }

  // Phase 3: flagged listings queue

  Future<List<Map<String, dynamic>>> listFlaggedListings() async {
    final res = await _api.dio.get<List<dynamic>>('/admin/listings/flagged');
    if (res.statusCode == 200 && res.data != null) {
      return res.data!.cast<Map<String, dynamic>>();
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ??
          'Could not load flagged listings.',
      status: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> unflagListing(int listingId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/admin/listings/$listingId/unflag',
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!;
    }
    throw AuthException(
      _err(res.data) ?? 'Could not unflag.',
      status: res.statusCode,
    );
  }

  String? _err(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Backend `errors.py` wraps Marshmallow errors as either
    //   {"error": "Validation failed", "fields": {"reason": ["..."]}}
    // or (when a non-schema helper raises a bare ValidationError)
    //   {"error": "Validation failed", "fields": ["..."]}
    // Surface whichever is most specific.
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

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(apiClientProvider));
});
