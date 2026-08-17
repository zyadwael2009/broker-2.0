// Broker rating DTOs — mirror app/ratings/routes.py responses.

class RatingAggregateDto {
  RatingAggregateDto({
    required this.avg,
    required this.count,
    required this.distribution,
  });

  final double avg;
  final int count;
  /// Map of "1".."5" → count. Kept as string keys because the backend
  /// serializes them that way (JSON keys are strings).
  final Map<String, int> distribution;

  bool get isEmpty => count == 0;

  factory RatingAggregateDto.fromJson(Map<String, dynamic> j) {
    final rawDist = (j['distribution'] as Map?) ?? const {};
    return RatingAggregateDto(
      avg: (j['avg'] as num?)?.toDouble() ?? 0.0,
      count: (j['count'] as num?)?.toInt() ?? 0,
      distribution: {
        for (final s in const ['1', '2', '3', '4', '5'])
          s: (rawDist[s] as num?)?.toInt() ?? 0,
      },
    );
  }

  static RatingAggregateDto empty() =>
      RatingAggregateDto(avg: 0.0, count: 0, distribution: {
        '1': 0, '2': 0, '3': 0, '4': 0, '5': 0,
      });
}

class RatingDto {
  RatingDto({
    required this.id,
    required this.brokerId,
    required this.stars,
    this.note,
    this.createdAt,
    required this.raterDisplay,
  });

  final int id;
  final int brokerId;
  final int stars;
  final String? note;
  final DateTime? createdAt;
  final String raterDisplay;

  factory RatingDto.fromJson(Map<String, dynamic> j) {
    final raw = j['created_at'] as String?;
    return RatingDto(
      id: j['id'] as int,
      brokerId: j['broker_user_id'] as int,
      stars: j['stars'] as int,
      note: j['note'] as String?,
      createdAt: raw == null ? null : DateTime.tryParse(raw),
      raterDisplay: (j['rater_display'] as String?) ?? 'Anonymous',
    );
  }
}
