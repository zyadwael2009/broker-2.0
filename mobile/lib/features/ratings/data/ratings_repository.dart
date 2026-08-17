import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class RatingsRepository {
  RatingsRepository(this._api);
  final ApiClient _api;

  Future<({RatingAggregateDto aggregate, List<RatingDto> reviews})> list(
      int brokerId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/brokers/$brokerId/ratings',
    );
    if (res.statusCode == 200 && res.data != null) {
      final data = res.data!;
      final agg = RatingAggregateDto.fromJson(
        data['aggregate'] as Map<String, dynamic>? ?? {},
      );
      final reviews = ((data['reviews'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(RatingDto.fromJson)
          .toList();
      return (aggregate: agg, reviews: reviews);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not load reviews.',
      status: res.statusCode,
    );
  }

  Future<RatingDto> submit({
    required int brokerId,
    required int stars,
    String? note,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/brokers/$brokerId/ratings',
      data: {'stars': stars, if (note != null && note.isNotEmpty) 'note': note},
    );
    if ((res.statusCode == 200 || res.statusCode == 201) && res.data != null) {
      return RatingDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not submit rating.',
      status: res.statusCode,
    );
  }

  /// Returns null when the caller has no rating for this broker.
  Future<RatingDto?> myRating(int brokerId) async {
    final res = await _api.dio.get<dynamic>(
      '/brokers/$brokerId/ratings/mine',
    );
    if (res.statusCode == 200) {
      final data = res.data;
      if (data is Map<String, dynamic>) return RatingDto.fromJson(data);
      return null;
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not load rating.',
      status: res.statusCode,
    );
  }

  Future<void> deleteMine(int brokerId) async {
    await _api.dio.delete('/brokers/$brokerId/ratings/mine');
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

final ratingsRepositoryProvider = Provider<RatingsRepository>((ref) {
  return RatingsRepository(ref.watch(apiClientProvider));
});
