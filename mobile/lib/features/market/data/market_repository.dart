import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/data/models.dart' show AuthException;
import 'models.dart';

class MarketRepository {
  MarketRepository(this._api);
  final ApiClient _api;

  Future<PriceStatsDto> stats({
    String? governorate,
    String? city,
    String? propertyType,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/market/price-per-m2',
      queryParameters: _params(governorate, city, propertyType),
    );
    if (res.statusCode == 200 && res.data != null) {
      return PriceStatsDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not load market stats.',
      status: res.statusCode,
    );
  }

  Future<List<PriceTrendPoint>> trend({
    String? governorate,
    String? city,
    String? propertyType,
    int months = 12,
  }) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/market/price-per-m2/trend',
      queryParameters: {
        ..._params(governorate, city, propertyType),
        'months': months,
      },
    );
    if (res.statusCode == 200 && res.data != null) {
      return res.data!
          .cast<Map<String, dynamic>>()
          .map(PriceTrendPoint.fromJson)
          .toList();
    }
    throw AuthException(
      _err(res.data as Map<String, dynamic>?) ?? 'Could not load trend.',
      status: res.statusCode,
    );
  }

  Future<MarketFiltersDto> filters() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/market/filters');
    if (res.statusCode == 200 && res.data != null) {
      return MarketFiltersDto.fromJson(res.data!);
    }
    throw AuthException(
      _err(res.data) ?? 'Could not load filters.',
      status: res.statusCode,
    );
  }

  Map<String, dynamic> _params(String? gov, String? city, String? pType) => {
        if (gov != null) 'governorate': gov,
        if (city != null) 'city': city,
        if (pType != null) 'property_type': pType,
      };

  String? _err(Map<String, dynamic>? data) {
    if (data == null) return null;
    final err = data['error'];
    return err is String ? err : null;
  }
}

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  return MarketRepository(ref.watch(apiClientProvider));
});
