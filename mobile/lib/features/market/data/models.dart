// Price transparency DTOs — mirror /market/* responses.

class PriceStatsDto {
  PriceStatsDto({
    required this.count,
    required this.unit,
    this.median,
    this.min,
    this.max,
    this.p25,
    this.p75,
  });

  final int count;
  final String unit;
  final double? median;
  final double? min;
  final double? max;
  final double? p25;
  final double? p75;

  bool get isEmpty => count == 0;

  factory PriceStatsDto.fromJson(Map<String, dynamic> j) => PriceStatsDto(
        count: j['count'] as int,
        unit: j['unit'] as String? ?? 'EGP/m2',
        median: (j['median'] as num?)?.toDouble(),
        min: (j['min'] as num?)?.toDouble(),
        max: (j['max'] as num?)?.toDouble(),
        p25: (j['p25'] as num?)?.toDouble(),
        p75: (j['p75'] as num?)?.toDouble(),
      );
}

class PriceTrendPoint {
  PriceTrendPoint({
    required this.month,
    required this.count,
    required this.median,
  });

  /// `YYYY-MM` as returned by the backend.
  final String month;
  final int count;
  final double median;

  factory PriceTrendPoint.fromJson(Map<String, dynamic> j) => PriceTrendPoint(
        month: j['month'] as String,
        count: j['count'] as int,
        median: (j['median'] as num).toDouble(),
      );
}

class MarketFiltersDto {
  MarketFiltersDto({
    required this.governorates,
    required this.citiesByGovernorate,
  });

  final List<String> governorates;
  final Map<String, List<String>> citiesByGovernorate;

  factory MarketFiltersDto.fromJson(Map<String, dynamic> j) {
    final rawCities = (j['cities_by_governorate'] as Map<String, dynamic>?) ?? {};
    return MarketFiltersDto(
      governorates:
          ((j['governorates'] as List?) ?? const []).cast<String>(),
      citiesByGovernorate: rawCities.map(
        (gov, list) => MapEntry(gov, (list as List).cast<String>()),
      ),
    );
  }
}
