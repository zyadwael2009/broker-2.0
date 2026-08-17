import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class ReportsRepository {
  ReportsRepository(this._api);
  final ApiClient _api;

  Future<ReportDto> submit({
    required String targetType,
    required int targetId,
    required String reason,
    String? note,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/reports',
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (res.statusCode == 201 && res.data != null) {
      return ReportDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not submit report.',
      status: res.statusCode,
    );
  }

  Future<List<ReportDto>> listForAdmin({String status = 'open'}) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/admin/reports',
      queryParameters: {'status': status},
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(ReportDto.fromJson)
          .toList();
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not load reports.',
      status: res.statusCode,
    );
  }

  Future<ReportDto> resolve({
    required int reportId,
    required String action,
    String? note,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/admin/reports/$reportId/resolve',
      data: {'action': action, if (note != null && note.isNotEmpty) 'note': note},
    );
    if (res.statusCode == 200 && res.data != null) {
      return ReportDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not resolve.',
      status: res.statusCode,
    );
  }

  String? _err(Map<String, dynamic>? data) {
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

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});
