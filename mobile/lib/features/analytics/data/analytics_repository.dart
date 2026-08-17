import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._api);
  final ApiClient _api;

  /// Fetches /brokers/me/analytics — everything the analytics screen
  /// renders in one call. Throws AuthException on non-200 so the UI
  /// can show a specific message.
  Future<AnalyticsPayloadDto> fetchMyAnalytics() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/brokers/me/analytics',
    );
    if (res.statusCode == 200 && res.data != null) {
      return AnalyticsPayloadDto.fromJson(res.data!);
    }
    throw AuthException(
      (res.data?['error'] as String?) ?? 'Could not load analytics.',
      status: res.statusCode,
    );
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(apiClientProvider));
});
